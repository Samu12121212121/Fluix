/**
 * nazariEbooks.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Sistema de entrega de ebooks para Editorial Nazarí.
 *
 * Flujo:
 *   1. crearCheckoutNazari   → crea sesión Stripe + guarda orden en Firestore
 *   2. stripeWebhookNazari   → escucha checkout.session.completed → entrega tokens
 *   3. verificarDescargaEbook → valida token, devuelve signed URL de Storage
 *   4. onPedidoNazariPagado  → trigger para transferencias bancarias confirmadas
 *
 * Firestore:
 *   empresas/{EID}/pedidos_web_nazari/{pedidoId}
 *   empresas/{EID}/descargas_ebook/{tokenId}
 *
 * Storage:
 *   ebooks/{slug}.epub  (o .pdf)
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import Stripe from "stripe";
import { enviarDescargaEbook } from "./resend_service";

const db = admin.firestore();
const REGION = "europe-west1";
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3"; // Editorial Nazarí empresa ID
const BASE_URL = "https://www.editorialnazari.com";

const stripeKey = () => process.env.STRIPE_SECRET_KEY ?? "";
const webhookSecret = () => process.env.STRIPE_WEBHOOK_SECRET ?? "";

// ── HELPERS ───────────────────────────────────────────────────────────────────

function genToken(): string {
  return Array.from(
    crypto.getRandomValues(new Uint8Array(20)),
    (b) => b.toString(16).padStart(2, "0")
  ).join("");
}

async function _entregarEbooks(opts: {
  email: string;
  nombre: string;
  items: Array<{ catalogo_id: string; titulo?: string }>;
  referencia: string; // session_id o pedido_id
}) {
  const { email, nombre, items, referencia } = opts;
  if (!email || !items.length) return;

  for (const item of items) {
    const slugId = item.catalogo_id;
    if (!slugId) continue;

    // Leer datos del libro en Firestore (campo ebook_storage_path)
    let ebookPath = "";
    let libroTitulo = item.titulo || "";
    let libroAutor = "";

    try {
      const libroSnap = await db
        .collection("empresas").doc(EID)
        .collection("catalogo_web").doc(slugId)
        .get();
      if (libroSnap.exists) {
        const l = libroSnap.data()!;
        ebookPath = (l.ebook_storage_path as string) || (l.ebook_url as string) || "";
        libroTitulo = libroTitulo || (l.titulo as string) || (l.nombre as string) || slugId;
        libroAutor = (l.autor as string) || (l.campo_autor as string) || "";
      }
    } catch (e) {
      console.warn(`_entregarEbooks: error leyendo libro ${slugId}`, e);
    }

    if (!ebookPath) {
      console.log(`Libro ${slugId} sin ebook_storage_path — omitiendo`);
      continue;
    }

    const token = genToken();
    const expiracion = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 días

    await db.collection("empresas").doc(EID)
      .collection("descargas_ebook")
      .add({
        token,
        libro_slug: slugId,
        libro_titulo: libroTitulo,
        libro_autor: libroAutor,
        email_comprador: email,
        nombre_comprador: nombre || email,
        storage_path: ebookPath,
        max_descargas: 5,
        descargas_realizadas: 0,
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        fecha_expiracion: admin.firestore.Timestamp.fromDate(expiracion),
        referencia,
        activo: true,
      });

    const downloadUrl = `https://europe-west1-planeaapp-4bea4.cloudfunctions.net/verificarDescargaEbook?token=${token}`;
    try {
      await enviarDescargaEbook({
        to: email,
        clienteNombre: nombre || email,
        libroTitulo,
        libroAutor,
        downloadUrl,
        fechaExpiracion: expiracion.toLocaleDateString("es-ES"),
        maxDescargas: 5,
      });
    } catch (e) {
      console.error(`Error enviando email descarga a ${email}:`, e);
    }

    console.log(`✅ Token generado para ${email} — ${libroTitulo}`);
  }
}

// ── 1. CREAR CHECKOUT EBOOK (sustituye al Cloud Run para ebooks) ───────────────
const _NAZARI_CORS = [
  "https://www.editorialnazari.com",
  "https://editorialnazari.com",
  "https://seashell-boar-580681.hostingersite.com",
  /^https?:\/\/.*\.hostingersite\.com$/,
  /^http:\/\/localhost(:\d+)?$/,
  "null", // origen file:// para pruebas locales
] as const;

/** Lee el precio real de un producto desde Firestore. Lanza error si no existe o está inactivo. */
async function _resolverPrecioNazari(catalogoId: string): Promise<{
  nombre: string;
  imagenUrl: string;
  precioEuros: number;
}> {
  const col = db.collection("empresas").doc(EID).collection("catalogo_web");
  let snap = await col.doc(catalogoId).get();

  if (!snap.exists) {
    const bySlug = await col.where("slug", "==", catalogoId).limit(1).get();
    if (!bySlug.empty) snap = bySlug.docs[0] as any;
  }

  if (!snap.exists) throw new Error(`Producto no encontrado: ${catalogoId}`);
  const d = snap.data()!;
  if (d.activo === false) throw new Error(`Producto no disponible: ${catalogoId}`);

  const precioRaw = String(d.precio ?? "").replace(",", ".").replace(/[^0-9.]/g, "");
  const precioEuros = parseFloat(precioRaw || "0");
  if (isNaN(precioEuros) || precioEuros <= 0) {
    throw new Error(`Precio inválido en ${catalogoId}: "${d.precio}"`);
  }

  return {
    nombre: (d.nombre ?? d.titulo ?? "Libro") as string,
    imagenUrl: (d.imagen_url ?? "") as string,
    precioEuros,
  };
}

export const crearCheckoutNazari = onRequest(
  { region: REGION, cors: _NAZARI_CORS as unknown as string[] },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }

    // El cliente envía catalogo_id y cantidad. El precio se lee SIEMPRE desde Firestore.
    const { items, email, nombre, zona } = req.body as {
      items: Array<{
        catalogo_id?: string;
        slug?: string;
        cantidad?: number;
        // titulo/precio/imagen del cliente se ignoran para el cobro
        titulo?: string;
        precio?: number;
        imagen?: string;
      }>;
      email: string;
      nombre?: string;
      zona?: string;
    };

    if (!email || !items?.length) {
      res.status(400).json({ error: "email e items son obligatorios" });
      return;
    }

    const stripe = new Stripe(stripeKey());

    try {
      // Resolver precios desde Firestore — el cliente no puede influir en el importe
      const resolvedItems = await Promise.all(
        items.map(async (i) => {
          const id = (i.catalogo_id || i.slug || "").trim();
          if (!id) throw new Error("Item sin catalogo_id");
          const { nombre: titulo, imagenUrl, precioEuros } = await _resolverPrecioNazari(id);
          return {
            catalogo_id: id,
            titulo,
            imagenUrl,
            precioEuros,
            cantidad: Math.max(1, Math.floor(Number(i.cantidad) || 1)),
          };
        })
      );

      // Guardar orden con precios validados
      const ordenRef = db.collection("empresas").doc(EID)
        .collection("pedidos_web_nazari").doc();

      await ordenRef.set({
        email,
        nombre: nombre || "",
        zona: zona || "ES",
        metodo_pago: "stripe",
        estado: "pendiente_pago",
        estado_pago: "pendiente",
        items: resolvedItems.map((i) => ({
          catalogo_id: i.catalogo_id,
          titulo: i.titulo,
          precio: i.precioEuros,
          cantidad: i.cantidad,
        })),
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        origen: "web_nazari",
      });

      const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = resolvedItems.map((i) => ({
        price_data: {
          currency: "eur",
          product_data: {
            name: i.titulo,
            images: i.imagenUrl ? [i.imagenUrl] : [],
          },
          unit_amount: Math.round(i.precioEuros * 100),
        },
        quantity: i.cantidad,
      }));

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        customer_email: email,
        line_items: lineItems,
        metadata: {
          orden_id: ordenRef.id,
          empresa_id: EID,
          email,
          zona: zona || "ES",
        },
        success_url: `${BASE_URL}/gracias.html?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${BASE_URL}/catalogo.html`,
        locale: "es",
      });

      await ordenRef.update({ stripe_session_id: session.id });

      res.json({ url: session.url });
    } catch (err: any) {
      console.error("crearCheckoutNazari error:", err.message);
      res.status(500).json({ error: err.message });
    }
  }
);

// ── 2. STRIPE WEBHOOK ──────────────────────────────────────────────────────────
export const stripeWebhookNazari = onRequest(
  { region: REGION, cors: false },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }

    const sig = req.headers["stripe-signature"] as string;
    const secret = webhookSecret();
    if (!secret || !sig) { res.status(400).send("Missing signature"); return; }

    const stripe = new Stripe(stripeKey());
    let event: Stripe.Event;

    try {
      const rawBody = (req as any).rawBody as Buffer;
      event = stripe.webhooks.constructEvent(rawBody, sig, secret);
    } catch (err: any) {
      console.error("Webhook signature error:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const ordenId = session.metadata?.orden_id;
      const email = session.customer_email || session.customer_details?.email || "";
      const nombre = session.customer_details?.name || "";

      if (!ordenId || !email) {
        console.warn("Webhook sin orden_id o email — sesión:", session.id);
        res.json({ received: true });
        return;
      }

      try {
        const ordenRef = db.collection("empresas").doc(EID)
          .collection("pedidos_web_nazari").doc(ordenId);
        const ordenSnap = await ordenRef.get();

        if (!ordenSnap.exists) {
          console.warn("Orden no encontrada:", ordenId);
          res.json({ received: true });
          return;
        }

        await ordenRef.update({
          estado: "pagado",
          estado_pago: "pagado",
          stripe_session_id: session.id,
          email,
          nombre_comprador: nombre,
          fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
        });

        const orden = ordenSnap.data()!;
        await _entregarEbooks({
          email,
          nombre,
          items: orden.items || [],
          referencia: session.id,
        });
      } catch (e) {
        console.error("Error procesando checkout.session.completed:", e);
      }
    }

    res.json({ received: true });
  }
);

// ── 3. VERIFICAR TOKEN Y DEVOLVER SIGNED URL ───────────────────────────────────
export const verificarDescargaEbook = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    const token = (req.query.token as string) || req.body?.token;

    if (!token) {
      res.status(400).json({ ok: false, error: "Token requerido" });
      return;
    }

    try {
      const snap = await db.collection("empresas").doc(EID)
        .collection("descargas_ebook")
        .where("token", "==", token)
        .where("activo", "==", true)
        .limit(1)
        .get();

      if (snap.empty) {
        res.status(404).json({ ok: false, error: "Enlace de descarga no válido" });
        return;
      }

      const docRef = snap.docs[0].ref;
      const data = snap.docs[0].data();

      // Comprobar expiración
      const expira = (data.fecha_expiracion as admin.firestore.Timestamp)?.toDate();
      if (expira && new Date() > expira) {
        res.status(410).json({ ok: false, error: "El enlace de descarga ha expirado (7 días)" });
        return;
      }

      // Comprobar límite de descargas
      const realizadas = (data.descargas_realizadas as number) || 0;
      const maxDesc = (data.max_descargas as number) || 5;
      if (realizadas >= maxDesc) {
        res.status(403).json({ ok: false, error: `Límite de ${maxDesc} descargas alcanzado` });
        return;
      }

      // Generar signed URL (válida 2 horas)
      const storagePath = data.storage_path as string;
      const titulo = (data.libro_titulo as string) || "ebook";
      const ext = storagePath.split(".").pop() || "epub";

      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).json({ ok: false, error: "Archivo no disponible aún" });
        return;
      }

      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 2 * 60 * 60 * 1000,
        responseDisposition: `attachment; filename="${titulo.replace(/[^a-z0-9]/gi, "_")}.${ext}"`,
      });

      // Incrementar contador
      await docRef.update({
        descargas_realizadas: admin.firestore.FieldValue.increment(1),
        ultima_descarga: admin.firestore.FieldValue.serverTimestamp(),
      });

      const restantes = maxDesc - realizadas - 1;

      // Si es una petición de navegador (Accept: text/html), redirigir directamente al archivo
      const acceptsHtml = (req.headers.accept || '').includes('text/html');
      if (acceptsHtml || req.method === 'GET') {
        res.redirect(302, signedUrl);
        return;
      }

      // Para peticiones AJAX (descarga.html), devolver JSON
      res.json({ ok: true, downloadUrl: signedUrl, titulo, descargas_restantes: restantes });
    } catch (err: any) {
      console.error("verificarDescargaEbook error:", err.message);
      res.status(500).json({ ok: false, error: "Error interno. Inténtalo de nuevo." });
    }
  }
);

// ── 4. TRIGGER TRANSFERENCIAS: admin confirma pago manualmente ─────────────────
// Cuando en Fluix el admin marca estado_pago → "pagado" en un pedido web
export const onPedidoNazariPagado = onDocumentUpdated(
  { document: `empresas/${EID}/pedidos_web_nazari/{pedidoId}`, region: REGION },
  async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    if (antes.estado_pago === "pagado") return;       // ya estaba pagado
    if (despues.estado_pago !== "pagado") return;      // no es pago nuevo
    if (despues.metodo_pago === "stripe") return;      // ya lo maneja el webhook

    const email = (despues.email || despues.cliente_email || "") as string;
    const nombre = (despues.nombre || despues.cliente_nombre || "") as string;
    const items = (despues.items || []) as Array<{ catalogo_id: string; titulo?: string }>;

    if (!email) {
      console.warn("onPedidoNazariPagado: sin email", event.params.pedidoId);
      return;
    }

    await _entregarEbooks({
      email,
      nombre,
      items,
      referencia: `transferencia_${event.params.pedidoId}`,
    });

    console.log(`✅ Ebooks entregados por transferencia — pedido ${event.params.pedidoId}`);
  }
);
