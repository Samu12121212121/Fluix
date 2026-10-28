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
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import Stripe from "stripe";
import { enviarDescargaEbook } from "./resend_service";
import { enviarNotificacionEmpresa } from "./utils/notificaciones";

const db = admin.firestore();
const REGION = "europe-west1";
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3"; // Editorial Nazarí empresa ID
const BASE_URL = "https://www.editorialnazari.com";

const stripeKey = () => process.env.STRIPE_SECRET_KEY_NAZARI ?? process.env.STRIPE_SECRET_KEY ?? "";
const webhookSecret = () => process.env.STRIPE_WEBHOOK_SECRET ?? "";

const IBAN_TRANSFERENCIA = (process.env.IBAN_TRANSFERENCIA ?? "ES86 3058 3007 1127 2030 7780") as string;
const TITULAR_CUENTA     = (process.env.TITULAR_CUENTA    ?? "Editorial Nazarí") as string;
const BIZUM_NUMERO       = (process.env.BIZUM_NUMERO       ?? "+34 620 32 75 27") as string;

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
}): Promise<{ entregados: number; omitidos: number }> {
  const { email, nombre, items, referencia } = opts;
  if (!email || !items.length) return { entregados: 0, omitidos: 0 };
  let entregados = 0, omitidos = 0;

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
      omitidos++;
      continue;
    }

    const token = genToken();
    const expiracion = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 días

    try {
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
          max_descargas: 3,
          descargas_realizadas: 0,
          fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
          fecha_expiracion: admin.firestore.Timestamp.fromDate(expiracion),
          referencia,
          activo: true,
        });
    } catch (e) {
      console.error(`_entregarEbooks: error guardando token para ${slugId}:`, e);
      omitidos++;
      continue;
    }

    // La URL del email apunta a descarga.html (página con botón bonito)
    // que a su vez enlaza directamente al CF para la descarga del binario
    const downloadUrl = `${BASE_URL}/descarga.html?token=${token}`
      + `&titulo=${encodeURIComponent(libroTitulo)}`
      + `&autor=${encodeURIComponent(libroAutor)}`;
    try {
      await enviarDescargaEbook({
        to: email,
        clienteNombre: nombre || email,
        libroTitulo,
        libroAutor,
        downloadUrl,
        fechaExpiracion: expiracion.toLocaleDateString("es-ES"),
        maxDescargas: 3,
      });
      entregados++;
      console.log(`✅ Token generado para ${email} — ${libroTitulo}`);
    } catch (e) {
      console.error(`Error enviando email descarga a ${email}:`, e);
      omitidos++;
    }
  }
  return { entregados, omitidos };
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

/** Lee precio + peso de un producto. Lanza error si no existe o está inactivo. */
async function _resolverPrecioNazari(catalogoId: string, pedirEbook = false): Promise<{
  nombre: string;
  imagenUrl: string;
  precioEuros: number;
  pesoGramos: number;
  esEbook: boolean;
  esPreventa: boolean;
}> {
  // Slug ebook_XXX → strip prefijo y forzar pedirEbook=true
  const isEbookSlug = catalogoId.startsWith("ebook_");
  const realId = isEbookSlug ? catalogoId.slice(6) : catalogoId;
  const pedirEbookFinal = pedirEbook || isEbookSlug;

  const col = db.collection("empresas").doc(EID).collection("catalogo_web");
  let snap = await col.doc(realId).get();

  if (!snap.exists) {
    const bySlug = await col.where("slug", "==", realId).limit(1).get();
    if (!bySlug.empty) snap = bySlug.docs[0] as any;
  }

  if (!snap.exists) throw new Error(`Producto no encontrado: ${realId}`);
  const d = snap.data()!;
  if (d.activo === false) throw new Error(`Producto no disponible: ${realId}`);

  const esEbook    = pedirEbookFinal || !!((d.ebook_storage_path as string | undefined) ?? "").trim();
  const esPreventa = d.preventa === true;

  // Si es ebook y tiene precio_digital, usarlo; si no, usar precio físico
  const precioFuente = esEbook && (d.precio_digital || d.precioEbook)
    ? String(d.precio_digital ?? d.precioEbook ?? "")
    : String(d.precio ?? "");
  const precioRaw   = precioFuente.replace(",", ".").replace(/[^0-9.]/g, "");
  const precioEuros = parseFloat(precioRaw || "0");
  if (isNaN(precioEuros) || precioEuros <= 0) {
    throw new Error(`Precio inválido en ${catalogoId}: "${precioFuente}"`);
  }

  const esEbookReal = !!((d.ebook_storage_path as string | undefined) ?? "").trim();
  const pesoRaw = d.campo_peso ?? d.peso ?? "300";
  // Sin peso para ebooks y preventa
  const pesoGramos = (esEbook || esPreventa)
    ? 0
    : Math.max(1, parseInt(String(pesoRaw).replace(/[^0-9]/g, ""), 10) || 300);

  return {
    nombre: (d.nombre ?? d.titulo ?? "Libro") as string,
    imagenUrl: (d.imagen_url ?? "") as string,
    precioEuros,
    pesoGramos,
    esEbook: esEbook || esEbookReal,
    esPreventa,
  };
}

/** Opciones de envío para Stripe según zona, total de productos y peso */
/** Coste de envío para Bizum / Transferencia (sin Stripe) — mismas reglas que _shippingOptions */
function _calcEnvioEuros(zona: string, totalEuros: number, pesoGramos: number, soloSinEnvio: boolean): number {
  if (soloSinEnvio) return 0;
  const z = (zona || "ES").toUpperCase();
  if (z === "ES") {
    if (totalEuros >= 30) return 0;
    if (pesoGramos <= 100) return 1.50;
    if (pesoGramos <= 500) return 2.50;
    return 3.00;
  }
  if (z === "EU")    return 15.00;
  if (z === "LATAM") return 20.00;
  return 30.00; // WORLD
}

function _shippingOptions(zona: string, totalEuros: number, pesoGramos: number) {
  const urgente = {
    shipping_rate_data: {
      type: "fixed_amount" as const,
      fixed_amount: { amount: 600, currency: "eur" },
      display_name: "Envío urgente (24-48h)",
      delivery_estimate: {
        minimum: { unit: "business_day" as const, value: 1 },
        maximum: { unit: "business_day" as const, value: 2 },
      },
    },
  };

  if (zona === "ES") {
    if (totalEuros >= 30) {
      return [
        {
          shipping_rate_data: {
            type: "fixed_amount" as const,
            fixed_amount: { amount: 0, currency: "eur" },
            display_name: "Envío gratuito · Ordinario (3-5 días laborables)",
            delivery_estimate: {
              minimum: { unit: "business_day" as const, value: 3 },
              maximum: { unit: "business_day" as const, value: 5 },
            },
          },
        },
        urgente,
      ];
    }
    let ordinarioCents: number;
    if (pesoGramos <= 100) ordinarioCents = 150;
    else if (pesoGramos <= 500) ordinarioCents = 250;
    else ordinarioCents = 300;
    const precioStr = (ordinarioCents / 100).toFixed(2).replace(".", ",");
    return [
      {
        shipping_rate_data: {
          type: "fixed_amount" as const,
          fixed_amount: { amount: ordinarioCents, currency: "eur" },
          display_name: `Envío ordinario (3-5 días laborables) — ${precioStr} €`,
          delivery_estimate: {
            minimum: { unit: "business_day" as const, value: 3 },
            maximum: { unit: "business_day" as const, value: 5 },
          },
        },
      },
      urgente,
    ];
  }
  if (zona === "EU") {
    return [{
      shipping_rate_data: {
        type: "fixed_amount" as const,
        fixed_amount: { amount: 1500, currency: "eur" },
        display_name: "Envío Europa (7-14 días laborables)",
        delivery_estimate: {
          minimum: { unit: "business_day" as const, value: 7 },
          maximum: { unit: "business_day" as const, value: 14 },
        },
      },
    }];
  }
  if (zona === "LATAM") {
    return [{
      shipping_rate_data: {
        type: "fixed_amount" as const,
        fixed_amount: { amount: 2000, currency: "eur" },
        display_name: "Envío Latinoamérica (14-21 días laborables)",
        delivery_estimate: {
          minimum: { unit: "business_day" as const, value: 14 },
          maximum: { unit: "business_day" as const, value: 21 },
        },
      },
    }];
  }
  // WORLD
  return [{
    shipping_rate_data: {
      type: "fixed_amount" as const,
      fixed_amount: { amount: 3000, currency: "eur" },
      display_name: "Envío internacional (14-30 días laborables)",
      delivery_estimate: {
        minimum: { unit: "business_day" as const, value: 14 },
        maximum: { unit: "business_day" as const, value: 30 },
      },
    },
  }];
}

export const crearCheckoutNazari = onRequest(
  { region: REGION, cors: _NAZARI_CORS as unknown as string[], secrets: ["STRIPE_SECRET_KEY_NAZARI"] },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }

    // El cliente envía catalogo_id y cantidad. El precio se lee SIEMPRE desde Firestore.
    const { items, email, nombre, telefono, zona, metodo_pago, direccion, pack_mode } = req.body as {
      items: Array<{
        catalogo_id?: string;
        slug?: string;
        cantidad?: number;
        titulo?: string;
        precio?: number;
        imagen?: string;
        es_ebook?: boolean;  // true = pedir versión digital (usa precio_digital)
      }>;
      email: string;
      nombre?: string;
      telefono?: string;
      zona?: string;
      metodo_pago?: string;
      pack_mode?: boolean;  // true = aplicar descuento del pack desde configuracion/pack_seleccion
      direccion?: {
        nombre?: string;
        linea1?: string;
        linea2?: string;
        cp?: string;
        ciudad?: string;
        pais?: string;
      };
    };
    // Normalizar dirección de envío si viene en el body
    const dirEnvio = (direccion?.linea1 || direccion?.ciudad) ? {
      nombre:   direccion.nombre   || nombre || "",
      telefono: telefono || "",
      linea1:   direccion.linea1   || "",
      linea2:   direccion.linea2   || "",
      cp:       direccion.cp       || "",
      ciudad:   direccion.ciudad   || "",
      pais:     direccion.pais     || zona   || "ES",
    } : null;

    if (!email || !items?.length) {
      res.status(400).json({ error: "email e items son obligatorios" });
      return;
    }

    try {
      // Resolver precios + peso desde Firestore — el cliente no puede influir en el importe
      const resolvedItems = await Promise.all(
        items.map(async (i) => {
          const id = (i.catalogo_id || i.slug || "").trim();
          if (!id) throw new Error("Item sin catalogo_id");
          const { nombre: titulo, imagenUrl, precioEuros, pesoGramos, esEbook, esPreventa } = await _resolverPrecioNazari(id, i.es_ebook === true);
          return {
            catalogo_id: id,
            titulo,
            imagenUrl,
            precioEuros,
            pesoGramos,
            esEbook,
            esPreventa,
            cantidad: Math.max(1, Math.floor(Number(i.cantidad) || 1)),
          };
        })
      );

      const totalBruto = resolvedItems.reduce((sum, i) => sum + i.precioEuros * i.cantidad, 0);
      const pesoTotal = resolvedItems.reduce((sum, i) => sum + i.pesoGramos * i.cantidad, 0);
      // soloSinEnvio: solo ebooks no necesitan dirección
      const soloSinEnvio = resolvedItems.every(i => i.esEbook);
      // todosPreventa: recogen dirección pero sin coste de envío (se cobra cuando salga el libro)
      const todosPreventa = !soloSinEnvio && resolvedItems.every(i => i.esPreventa);
      const sinCostoEnvio = soloSinEnvio || todosPreventa;

      // Descuento pack: si pack_mode=true, leer porcentaje desde Firestore
      let packDescuentoPct = 0;
      if (pack_mode === true) {
        const packSnap = await db.collection("empresas").doc(EID)
          .collection("configuracion").doc("pack_seleccion").get();
        const packData = packSnap.data() ?? {};
        if (packData.activo !== true) {
          res.status(400).json({ error: "El pack no está activo" });
          return;
        }
        packDescuentoPct = typeof packData.descuento_porcentaje === "number" ? packData.descuento_porcentaje : 0;
      }
      const total = packDescuentoPct > 0
        ? Math.round(totalBruto * (1 - packDescuentoPct / 100) * 100) / 100
        : totalBruto;

      const ordenRef = db.collection("empresas").doc(EID)
        .collection("pedidos_web_nazari").doc();

      const itemsGuardados = resolvedItems.map((i) => {
        const precioConDesc = packDescuentoPct > 0
          ? Math.round(i.precioEuros * (1 - packDescuentoPct / 100) * 100) / 100
          : i.precioEuros;
        return {
          catalogo_id: i.catalogo_id,
          titulo: i.titulo,
          precio: precioConDesc,
          cantidad: i.cantidad,
          es_ebook: i.esEbook || false,
          imagen_url: i.imagenUrl || "",
        };
      });
      const tieneEbook   = resolvedItems.some(i => i.esEbook);
      const tieneLibro   = resolvedItems.some(i => !i.esEbook);

      // Calcular envío — preventa: 0€ (se cobrará cuando salga el libro)
      const envioEuros = _calcEnvioEuros(zona || "ES", total, pesoTotal, sinCostoEnvio);
      const totalConEnvio = Math.round((total + envioEuros) * 100) / 100;

      // ── Rama: Bizum directo (pago al número de teléfono) ─────────────────
      if (metodo_pago === "bizum") {
        await ordenRef.set({
          email, nombre: nombre || "", zona: zona || "ES",
          metodo_pago: "bizum", estado: "pendiente_pago", estado_pago: "pendiente",
          items: itemsGuardados,
          subtotal: Math.round(total * 100) / 100,
          envio: envioEuros,
          total: totalConEnvio,
          fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
          origen: "web_nazari",
          tiene_ebook: tieneEbook, tiene_libro: tieneLibro,
          ...(dirEnvio ? { direccion_envio: dirEnvio } : {}),
        });
        const totalStr    = totalConEnvio.toFixed(2).replace(".", ",") + " €";
        const envioStr    = envioEuros > 0 ? envioEuros.toFixed(2).replace(".", ",") + " €" : "Gratis";
        const conceptoCorto = ordenRef.id.slice(0, 8).toUpperCase();
        res.json({
          tipo: "bizum", pedido_id: ordenRef.id, total: totalStr, envio: envioStr,
          bizum_numero: BIZUM_NUMERO,
          redirect_url: `${BASE_URL}/gracias.html?tipo=bizum&pedido=${ordenRef.id}&total=${encodeURIComponent(totalStr)}&concepto=${conceptoCorto}`,
        });
        return;
      }

      // ── Rama: transferencia bancaria ─────────────────────────────────────
      if (metodo_pago === "transferencia") {
        await ordenRef.set({
          email,
          nombre: nombre || "",
          zona: zona || "ES",
          metodo_pago: "transferencia",
          estado: "pendiente_pago",
          estado_pago: "pendiente",
          items: itemsGuardados,
          subtotal: Math.round(total * 100) / 100,
          envio: envioEuros,
          total: totalConEnvio,
          fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
          origen: "web_nazari",
          tiene_ebook: tieneEbook, tiene_libro: tieneLibro,
          ...(dirEnvio ? { direccion_envio: dirEnvio } : {}),
        });

        const totalStr = totalConEnvio.toFixed(2).replace(".", ",") + " €";
        const envioStr = envioEuros > 0 ? envioEuros.toFixed(2).replace(".", ",") + " €" : "Gratis";
        const conceptoCorto = ordenRef.id.slice(0, 8).toUpperCase();
        res.json({
          tipo: "transferencia",
          pedido_id: ordenRef.id,
          total: totalStr,
          envio: envioStr,
          iban: IBAN_TRANSFERENCIA,
          titular: TITULAR_CUENTA,
          redirect_url: `${BASE_URL}/gracias.html?tipo=transferencia&pedido=${ordenRef.id}&total=${encodeURIComponent(totalStr)}&concepto=${conceptoCorto}`,
        });
        return;
      }

      // ── Rama: Stripe (tarjeta + Bizum + métodos habilitados en dashboard) ──
      const stripe = new Stripe(stripeKey(), { apiVersion: "2024-06-20" as any });

      // Envío estimado para Stripe — el webhook lo corregirá con el valor real
      // elegido por el cliente en Stripe Checkout (puede ser ordinario o urgente).
      const envioEstimadoStripe = envioEuros;
      const totalEstimadoStripe = Math.round((total + envioEstimadoStripe) * 100) / 100;

      await ordenRef.set({
        email,
        nombre: nombre || "",
        zona: zona || "ES",
        metodo_pago: "stripe",
        estado: "pendiente_pago",
        estado_pago: "pendiente",
        items: itemsGuardados,
        subtotal: Math.round(total * 100) / 100,
        envio: envioEstimadoStripe,
        total: totalEstimadoStripe,
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        origen: "web_nazari",
        tiene_ebook: tieneEbook, tiene_libro: tieneLibro,
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

      const zonaFinal = (zona || "ES").toUpperCase();
      const zonaFinal2 = zonaFinal; // alias para legibilidad
      const shipping = soloSinEnvio || todosPreventa ? [] : _shippingOptions(zonaFinal2, total, pesoTotal);

      const sessionParams: Record<string, unknown> = {
        mode: "payment",
        customer_email: email,
        line_items: lineItems,
      };
      if (!soloSinEnvio) {
        // Preventa: recoge dirección pero sin opciones de envío (se gestionará al publicarse)
        sessionParams.shipping_address_collection = {
          allowed_countries: zonaFinal === "ES"
            ? ["ES"]
            : zonaFinal === "EU"
              ? ["AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR","HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE"]
              : undefined,
        };
        if (!todosPreventa) sessionParams.shipping_options = shipping;
      }

      const session = await (stripe.checkout.sessions.create as Function)({
        ...sessionParams,
        phone_number_collection: { enabled: false },
        metadata: {
          orden_id: ordenRef.id,
          empresa_id: EID,
          email,
          zona: zonaFinal,
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
  { region: REGION, cors: false, secrets: ["RESEND_API_KEY", "STRIPE_SECRET_KEY_NAZARI"] },
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

        // shipping_details (API ≥2022-08-01) o shipping (API legacy) — cast para compatibilidad de tipos
        const _s = session as any;
        let shippingRaw = _s.shipping_details || _s.shipping;
        if (!shippingRaw?.address) {
          // Fallback: recuperar sesión completa de Stripe API por si el webhook
          // usa una versión antigua que no incluye shipping_details en el payload.
          try {
            const fullSess = await stripe.checkout.sessions.retrieve(session.id) as any;
            shippingRaw = fullSess.shipping_details || fullSess.shipping;
          } catch (_e) {
            console.warn("No se pudo recuperar sesión completa:", _e);
          }
        }
        const dir = shippingRaw?.address ? {
          nombre:  shippingRaw.name || nombre,
          linea1:  shippingRaw.address.line1  || "",
          linea2:  shippingRaw.address.line2  || "",
          ciudad:  shippingRaw.address.city   || "",
          cp:      shippingRaw.address.postal_code || "",
          pais:    shippingRaw.address.country || "",
        } : null;

        // Extraer totales reales de Stripe (incluye envío elegido por el cliente)
        const _s2 = session as any;
        const amountTotalCents    = typeof _s2.amount_total    === "number" ? _s2.amount_total    : null;
        const amountSubtotalCents = typeof _s2.amount_subtotal === "number" ? _s2.amount_subtotal : null;
        const totalPagado    = amountTotalCents    != null ? Math.round(amountTotalCents    / 100 * 100) / 100 : undefined;
        const subtotalPagado = amountSubtotalCents != null ? Math.round(amountSubtotalCents / 100 * 100) / 100 : undefined;

        // Envío: leer shipping_cost.amount_total (campo dedicado de Stripe, más fiable
        // que amount_total - amount_subtotal que puede incluir impuestos o descuentos).
        // Fallback: diferencia total - subtotal si shipping_cost no está disponible.
        const shippingCostCents: number | null =
          typeof _s2.shipping_cost?.amount_total === "number"
            ? _s2.shipping_cost.amount_total
            : null;
        const envioPagado: number | undefined =
          shippingCostCents != null
            ? Math.round(shippingCostCents / 100 * 100) / 100
            : (totalPagado != null && subtotalPagado != null)
              ? Math.round((totalPagado - subtotalPagado) * 100) / 100
              : undefined;

        console.log(`[Nazarí Webhook] total=${totalPagado} subtotal=${subtotalPagado} shipping_cost_cents=${shippingCostCents} envioPagado=${envioPagado}`);

        await ordenRef.update({
          estado: "pagado",
          estado_pago: "pagado",
          stripe_session_id: session.id,
          email,
          nombre_comprador: nombre,
          ...(dir ? { direccion_envio: dir } : {}),
          fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
          ...(totalPagado    != null ? { total:    totalPagado    } : {}),
          ...(subtotalPagado != null ? { subtotal: subtotalPagado } : {}),
          ...(envioPagado    != null ? { envio:    envioPagado    } : {}),
        });

        const orden = ordenSnap.data()!;
        await _entregarEbooks({
          email,
          nombre,
          items: orden.items || [],
          referencia: session.id,
        });

        // ── Mirror a `pedidos` para que aparezca en Fluix ─────────────────────
        // Los pedidos web viven en pedidos_web_nazari; Fluix lee de pedidos.
        // Evitar duplicado si ya fue migrado anteriormente.
        try {
          if (!orden.pedido_fluix_id) {
            const total = totalPagado ?? (orden.total as number | undefined) ?? 0;
            const subtotal = subtotalPagado ?? (orden.subtotal as number | undefined) ?? 0;
            const envio = envioPagado ?? (orden.envio as number | undefined) ?? 0;
            const lineas = ((orden.items || []) as Array<{ catalogo_id?: string; titulo?: string; cantidad?: number; precio?: number }>).map(i => ({
              libro_id:        i.catalogo_id || "",
              producto_nombre: i.titulo || "",
              descripcion:     i.titulo || "",
              cantidad:        i.cantidad || 1,
              precio_unitario: i.precio || 0,
              porcentaje_iva:  4,
            }));
            const pedidoFluixRef = await db.collection("empresas").doc(EID).collection("pedidos").add({
              empresa_id:            EID,
              cliente_nombre:        nombre || email,
              cliente_correo:        email,
              origen:                "web_nazari",
              estado:                "pendiente",
              estado_pago:           "pagado",
              metodo_pago:           "tarjeta",
              lineas,
              total,
              subtotal,
              gastos_envio:          envio,
              stripe_session_id:     session.id,
              pedido_web_id:         ordenId,
              ...(dir ? { direccion_envio: dir } : {}),
              fecha_creacion:        admin.firestore.FieldValue.serverTimestamp(),
              fecha_pedido:          admin.firestore.FieldValue.serverTimestamp(),
              fecha_actualizacion:   admin.firestore.FieldValue.serverTimestamp(),
              notas_internas:        `Compra online via Stripe. Web ID: ${ordenId}`,
            });
            // Guardar referencia cruzada para no duplicar
            await ordenRef.update({ pedido_fluix_id: pedidoFluixRef.id });
            console.log(`✅ Pedido web ${ordenId} → pedidos/${pedidoFluixRef.id}`);
          }
        } catch (mirrorErr) {
          console.warn("Mirror a pedidos fallido (no crítico):", mirrorErr);
        }

        // Notificar a Fluix — igual que Bizum/Transferencia en onNuevoPedidoWeb
        try {
          const total = totalPagado ?? (orden.total as number | undefined) ?? 0;
          const items = (orden.items as { titulo?: string }[]) ?? [];
          const primerTitulo = items[0]?.titulo ?? "artículo web";
          const cuerpo = `${nombre || email} — ${total.toFixed(2)} € por tarjeta/Bizum · ${primerTitulo}`;
          await db.collection("notificaciones").doc(EID).collection("items").add({
            titulo:          "✅ Pedido pagado (tarjeta/Bizum)",
            cuerpo,
            tipo:            "pedidoNuevo",
            timestamp:       admin.firestore.FieldValue.serverTimestamp(),
            leida:           false,
            modulo_destino:  "pedidos",
            entidad_id:      ordenId,
            remitente_email: email,
          });
          await enviarNotificacionEmpresa(
            EID,
            "✅ Pedido pagado (tarjeta/Bizum)",
            cuerpo,
            { tipo: "nuevo_pedido", pedido_id: ordenId, origen: "web_nazari" }
          );
        } catch (notifErr) {
          console.warn("Notificación Fluix fallida (no crítico):", notifErr);
        }
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

      // Comprobar límite de descargas (1 descarga por enlace)
      const realizadas = (data.descargas_realizadas as number) || 0;
      const maxDesc = (data.max_descargas as number) || 1;
      if (realizadas >= maxDesc) {
        res.status(403).json({ ok: false, error: "Este enlace ya ha sido utilizado. Contacta con info@editorialnazari.com si necesitas ayuda." });
        return;
      }

      const storagePath = data.storage_path as string;
      const titulo = (data.libro_titulo as string) || "ebook";
      const ext = (storagePath.split(".").pop() || "epub").toLowerCase();
      const mimeType = ext === "epub" ? "application/epub+zip" : "application/pdf";

      // Usar el bucket explícito para evitar problemas de configuración
      const bucket = admin.storage().bucket("planeaapp-4bea4.firebasestorage.app");
      const file = bucket.file(storagePath);
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).json({ ok: false, error: "Archivo no disponible. Contacta con info@editorialnazari.com" });
        return;
      }

      // Incrementar contador ANTES de servir (evita descargas repetidas si el stream falla)
      await docRef.update({
        descargas_realizadas: admin.firestore.FieldValue.increment(1),
        ultima_descarga: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Servir el archivo directamente desde el Cloud Function (sin signed URL)
      // Evita dependencia de permisos IAM para signBlob
      const nombreArchivo = titulo.replace(/[^a-zA-Z0-9\s\-_]/g, "").trim().replace(/\s+/g, "_") || "ebook";
      res.setHeader("Content-Type", mimeType);
      res.setHeader("Content-Disposition", `attachment; filename="${nombreArchivo}.${ext}"`);
      res.setHeader("Cache-Control", "no-store");

      const stream = file.createReadStream();
      stream.on("error", (err) => {
        console.error("Stream error:", err);
        if (!res.headersSent) {
          res.status(500).json({ ok: false, error: "Error al servir el archivo." });
        }
      });
      stream.pipe(res);
    } catch (err: any) {
      console.error("verificarDescargaEbook error:", err.message);
      res.status(500).json({ ok: false, error: "Error interno. Inténtalo de nuevo." });
    }
  }
);

// ── 4. TRIGGER TRANSFERENCIAS: admin confirma pago manualmente ─────────────────
// Cuando en Fluix el admin marca estado_pago → "pagado" en un pedido web
export const onPedidoNazariPagado = onDocumentUpdated(
  { document: `empresas/${EID}/pedidos_web_nazari/{pedidoId}`, region: REGION, secrets: ["RESEND_API_KEY"] },
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

    // Mirror a `pedidos` para que aparezca en Fluix (mismo patrón que Stripe)
    if (!despues.pedido_fluix_id) {
      try {
        const total = (despues.total as number | undefined) ?? 0;
        const subtotal = (despues.subtotal as number | undefined) ?? 0;
        const envio = (despues.envio as number | undefined) ?? 0;
        const lineas = (items as Array<{ catalogo_id?: string; titulo?: string; cantidad?: number; precio?: number }>).map(i => ({
          libro_id:        i.catalogo_id || "",
          producto_nombre: i.titulo || "",
          descripcion:     i.titulo || "",
          cantidad:        i.cantidad || 1,
          precio_unitario: i.precio || 0,
          porcentaje_iva:  4,
        }));
        const metodo = (despues.metodo_pago as string) ?? "transferencia";
        const pedidoFluixRef = await db.collection("empresas").doc(EID).collection("pedidos").add({
          empresa_id:          EID,
          cliente_nombre:      nombre || email,
          cliente_correo:      email,
          origen:              "web_nazari",
          estado:              "pendiente",
          estado_pago:         "pagado",
          metodo_pago:         metodo,
          lineas,
          total,
          subtotal,
          gastos_envio:        envio,
          pedido_web_id:       event.params.pedidoId,
          fecha_creacion:      admin.firestore.FieldValue.serverTimestamp(),
          fecha_pedido:        admin.firestore.FieldValue.serverTimestamp(),
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          notas_internas:      `Compra online via ${metodo}. Web ID: ${event.params.pedidoId}`,
        });
        await event.data?.after.ref.update({ pedido_fluix_id: pedidoFluixRef.id });
        console.log(`✅ Pedido web ${event.params.pedidoId} → pedidos/${pedidoFluixRef.id}`);
      } catch (mirrorErr) {
        console.warn("Mirror a pedidos (transferencia) fallido:", mirrorErr);
      }
    }

    console.log(`✅ Ebooks entregados por transferencia — pedido ${event.params.pedidoId}`);
  }
);

// ── Notificación a Fluix para pedidos web manuales (Bizum / Transferencia) ────
// Los pedidos Stripe NO se notifican aquí: el webhook stripeWebhookNazari ya
// envía "✅ Pedido pagado" cuando Stripe confirma el cobro. Si notificásemos
// también al crear el pedido pendiente, el equipo recibiría avisos de pedidos
// que pueden quedar sin pagar (usuario abandonó el checkout de Stripe).
export const onNuevoPedidoWeb = onDocumentCreated(
  { document: `empresas/${EID}/pedidos_web_nazari/{pedidoId}`, region: REGION },
  async (event) => {
    const pedido = event.data?.data();
    if (!pedido) return;

    const metodo = (pedido.metodo_pago as string) ?? "";
    if (metodo === "" || metodo === "stripe" || metodo === "simulacion") return;

    const total  = (pedido.total as number | undefined) ?? 0;
    const email  = (pedido.email as string)  || "cliente";
    const nombre = (pedido.nombre as string) || email;
    const items  = (pedido.items as { titulo?: string }[]) ?? [];
    const primerTitulo = items[0]?.titulo ?? "artículo web";

    const metodoLabel = metodo === "bizum" ? "Bizum directo" : "Transferencia";
    const cuerpo = `${nombre} — ${total.toFixed(2)} € por ${metodoLabel} · ${primerTitulo} · PENDIENTE de confirmación`;

    // Notificación in-app
    await db.collection("notificaciones").doc(EID).collection("items").add({
      titulo:          `⏳ Pedido pendiente (${metodoLabel})`,
      cuerpo,
      tipo:            "pedidoNuevo",
      timestamp:       admin.firestore.FieldValue.serverTimestamp(),
      leida:           false,
      modulo_destino:  "pedidos",
      entidad_id:      event.params.pedidoId,
      remitente_email: email,
    });

    // Push a todos los dispositivos de la empresa
    await enviarNotificacionEmpresa(
      EID,
      `⏳ Pedido pendiente (${metodoLabel})`,
      cuerpo,
      { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId, origen: "web_nazari" }
    );
  }
);

// ── Simulación de compra (solo propietario Fluix) ─────────────────────────────
export const simularCompraEbook = onRequest(
  { region: REGION, cors: _NAZARI_CORS as unknown as string[], secrets: ["RESEND_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }

    // Verificar que el llamador es plataforma_admin
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ ok: false, error: "No autorizado" });
      return;
    }
    try {
      const decoded = await admin.auth().verifyIdToken(authHeader.split(" ")[1]);
      if (!decoded.plataforma_admin) {
        res.status(403).json({ ok: false, error: "Acceso denegado" });
        return;
      }
    } catch {
      res.status(401).json({ ok: false, error: "Token inválido" });
      return;
    }

    const { catalogo_id, email, nombre } = req.body as {
      catalogo_id?: string; email?: string; nombre?: string;
    };

    if (!catalogo_id || !email) {
      res.status(400).json({ ok: false, error: "catalogo_id y email son obligatorios" });
      return;
    }

    try {
      const pedidoRef = db
        .collection("empresas").doc(EID)
        .collection("pedidos_web_nazari").doc();

      await pedidoRef.set({
        email,
        nombre: nombre || "Simulación Propietario",
        items: [{ catalogo_id }],
        estado: "pagado",
        estado_pago: "pagado",
        metodo_pago: "simulacion",
        simulacion: true,
        total: 0,
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
        origen: "simulacion_fluix",
      });

      const { entregados, omitidos } = await _entregarEbooks({
        email,
        nombre: nombre || "Simulación Propietario",
        items: [{ catalogo_id }],
        referencia: `simulacion_${pedidoRef.id}`,
      });

      res.json({
        ok: true,
        pedido_id: pedidoRef.id,
        email_enviado: entregados > 0,
        sin_ebook: omitidos > 0 && entregados === 0,
      });
    } catch (err: any) {
      console.error("simularCompraEbook error:", err.message);
      res.status(500).json({ ok: false, error: err.message });
    }
  }
);

/** Recupera la dirección de envío de Stripe para un pedido web de Nazarí sin dirección.
 *  Acepta pedidoWebId (ID en pedidos_web_nazari) o pedidoId (ID en pedidos). */
export const recuperarDireccionPedidoNazari = onCall(
  { region: REGION, secrets: ["STRIPE_SECRET_KEY_NAZARI"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const { pedidoId, pedidoWebId, empresaId } = request.data as {
      pedidoId?: string; pedidoWebId?: string; empresaId: string;
    };
    if (!empresaId || (!pedidoId && !pedidoWebId))
      throw new HttpsError("invalid-argument", "Faltan parámetros");

    const db2 = admin.firestore();
    let stripeSessionId = "";
    let fluixPedidoRef: admin.firestore.DocumentReference | null = null;
    let webPedidoRef: admin.firestore.DocumentReference | null = null;

    // Rama 1: viene de pedidos_web_nazari
    if (pedidoWebId) {
      webPedidoRef = db2.collection("empresas").doc(EID)
        .collection("pedidos_web_nazari").doc(pedidoWebId);
      const webSnap = await webPedidoRef.get();
      if (!webSnap.exists) throw new HttpsError("not-found", "Pedido web no encontrado");
      const wData = webSnap.data()!;
      stripeSessionId = (wData.stripe_session_id as string) || "";
      const fluixId = (wData.pedido_fluix_id as string) || "";
      if (fluixId) {
        fluixPedidoRef = db2.collection("empresas").doc(EID).collection("pedidos").doc(fluixId);
      }
    }

    // Rama 2: viene de pedidos (Fluix)
    if (pedidoId && !stripeSessionId) {
      fluixPedidoRef = db2.collection("empresas").doc(empresaId).collection("pedidos").doc(pedidoId);
      const fluixSnap = await fluixPedidoRef.get();
      if (!fluixSnap.exists) throw new HttpsError("not-found", "Pedido no encontrado");
      const fData = fluixSnap.data()!;
      stripeSessionId = (fData.stripe_session_id as string) || "";
      const webId = (fData.pedido_web_id as string) || "";
      if (!stripeSessionId && webId) {
        const wSnap = await db2.collection("empresas").doc(EID)
          .collection("pedidos_web_nazari").doc(webId).get();
        if (wSnap.exists) stripeSessionId = (wSnap.data()!.stripe_session_id as string) || "";
        webPedidoRef = db2.collection("empresas").doc(EID)
          .collection("pedidos_web_nazari").doc(webId);
      }
    }

    if (!stripeSessionId) throw new HttpsError("not-found", "No se encontró el ID de sesión de Stripe");

    const stripe = new Stripe(stripeKey());
    const session = await stripe.checkout.sessions.retrieve(stripeSessionId) as any;
    const nombre = session.customer_details?.name || "";
    const shippingRaw = session.shipping_details || session.shipping;
    if (!shippingRaw?.address) throw new HttpsError("not-found", "Este pedido no tiene dirección en Stripe");

    // Guardar como Map (para pedidos_web_nazari) y como String (para pedidos Fluix)
    const dirMap = {
      nombre: shippingRaw.name || nombre,
      linea1: shippingRaw.address.line1 || "",
      linea2: shippingRaw.address.line2 || "",
      ciudad: shippingRaw.address.city || "",
      cp:     shippingRaw.address.postal_code || "",
      pais:   shippingRaw.address.country || "",
    };
    const dirStr = [dirMap.nombre, dirMap.linea1, dirMap.linea2,
      `${dirMap.cp} ${dirMap.ciudad}`.trim(), dirMap.pais].filter(Boolean).join(", ");

    if (webPedidoRef) await webPedidoRef.update({ direccion_envio: dirMap });
    if (fluixPedidoRef) await fluixPedidoRef.update({ direccion_envio: dirStr });
    return { direccion: dirStr, dir: dirMap };
  }
);
