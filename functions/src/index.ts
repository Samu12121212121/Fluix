import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import Stripe from "stripe";
import { enviarPdfGenerico, enviarConfirmacionReserva, enviarCancelacionReserva, enviarNotificacionContactoWeb, enviarRespuestaContactoWeb, enviarNotificacionPedidoEnviado } from "./resend_service";
import { enviarRecordatoriosCitas } from "./recordatoriosCitas";
import { onTareaAsignada } from "./notificacionesTareas";
import {
  scheduledGenerarTareasRecurrentes,
  scheduledRecordatoriosTareas,
  scheduledTareasVencenHoy,
  onNuevaSugerencia,
  onNuevoContactoSoporte,
} from "./tareasFunciones";
import { scheduledAlertaCertificado } from "./alertaCertificado";
import { verificarAuth, verificarAuthYEmpresa, verificarPropietarioPlataforma } from "./utils/authGuard";
import { verificarLoginIntento } from "./auth/fuerzaBruta";
import { expirarFlashSlots, onNuevoFlashSlot } from "./flashSlots";
import fetch from "node-fetch";
export { cerrarCaja } from "./cerrarCaja";
export { processInvoice } from "./fiscal/processInvoice";
export { calculateFiscalModel } from "./fiscal/models/calculateModel";
export {
  whatsappWebhook,
  enviarPlantillaWhatsApp,
  enviarMensajeAdminWhatsApp,
  cambiarEstadoChatBot,
} from "./whatsappBot";

export { generarThumbnailCatalogo, scheduledAlertaPreciosAntiguos } from "./catalogoFunciones";
export { scheduledAlertaCertificado };
export { expirarFlashSlots, onNuevoFlashSlot };
export { verificarLoginIntento };
export {
  onCitaCompletadaTrofeos,
  onResenaCreadaTrofeos,
  onPerfilActualizadoTrofeos,
  evaluarTrofeosFidelidad,
  fanNumero1Job,
} from "./trofeos";
export { onInvitacionCreada } from "./invitaciones";
export { sendResetPasswordEmail } from "./resetPassword";
export { crearEmpleadoConCredenciales } from "./crearEmpleado";
export { asignarAdminPlataforma } from "./adminClaims";
export {
  onNuevaReservaEmail,
  onNuevaNotificacionReserva,
  confirmarReserva,
  rechazarReserva,
} from "./notificacionesReservas";
export {
  onReservaPublicaCreada,
  gestionarReservaPublica,
  expirarReservasPublicas,
} from "./reservasPublicas";
export {
  onReservaCompletada,
  onValoracionWrite,
  onValoracionBaja,
  eliminarValoracion,
} from "./valoraciones";
export {
  onCheckinFidelizacion,
  onCanjeRecompensa,
  marcarQRsExpirados,
  verificarCaducidadSellos,
} from "./fidelizacion";
export {
  onReservaConfirmadaCliente,
  onReservaCanceladaCliente,
  recordatorioReservaCliente,
  onFlashSlotClienteNotif,
  onPromocionClienteNotif,
  onReservaCompletadaValoracion,
  procesarSolicitudesValoracion,
  onSelloFidelizacionInApp,
  onBienvenidaClienteNuevo,
} from "./notificaciones_cliente";
export {
  onNuevoClienteCRM,
  onReservaCreatedCRM,
  onReservaCRM,
  onPedidoCRM,
  onPedidoWhatsAppCRM,
  onFacturaCRM,
  onFacturaAnuladaCRM,
  recalcularStatsCliente,
} from "./automaciones_clientes";
export {
  purgeEventoCdn,
  purgeBlogCdn,
  purgeCatalogoCdn,
} from "./cdnPurge";
export {
  pushNuevoEvento,
  pushNuevoPost,
  pushNuevoCatalogo,
} from "./webPush";
export {
  buscarArchivoNazari,
  importarContenidoNazari,
  migrarDatosNazariDesdeWeb,
} from "./nazariMigracion";

export {
  crearCheckoutNazari,
  stripeWebhookNazari,
  verificarDescargaEbook,
  onPedidoNazariPagado,
} from "./nazariEbooks";

export { onJuanitaReservaEstadoCambiado } from "./juanitaReservasEmail";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

const REGION = "europe-west1";

// ── Resumen diario TPV automático ─────────────────────────────────────────────
// Ejecuta cada día a las 23:30 hora de Madrid
// Genera facturas resumen para empresas con generarAutomaticamente = true
export const generarFacturasResumenTpv = onSchedule(
  { schedule: "30 23 * * *", timeZone: "Europe/Madrid", region: REGION },
  async (_event) => {
    const hoy = new Date();
    const inicioHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 0, 0, 0);
    const finHoy    = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);

    // Buscar empresas con resumen diario automático activado
    const configSnap = await db
      .collectionGroup("configuracion")
      .where("modo", "==", "resumenDiario")
      .where("generar_automaticamente", "==", true)
      .get();

    let procesadas = 0;
    for (const configDoc of configSnap.docs) {
      const empresaId = configDoc.ref.parent.parent?.id;
      if (!empresaId) continue;

      try {
        // Pedidos TPV del día sin facturar
        const pedidosSnap = await db
          .collection(`empresas/${empresaId}/pedidos`)
          .where("origen", "in", ["presencial", "tpvExterno"])
          .where("estado_pago", "==", "pagado")
          .where("factura_id", "==", null)
          .where("fecha_creacion", ">=", admin.firestore.Timestamp.fromDate(inicioHoy))
          .where("fecha_creacion", "<=", admin.firestore.Timestamp.fromDate(finHoy))
          .get();

        if (pedidosSnap.empty) {
          console.log(`ℹ️ Sin pedidos TPV pendientes para empresa ${empresaId}`);
          continue;
        }

        const totalVentas = pedidosSnap.docs.reduce((sum, doc) => {
          return sum + ((doc.data()["total"] as number) ?? 0);
        }, 0);

        const fechaStr = `${String(hoy.getDate()).padStart(2,"0")}/${String(hoy.getMonth()+1).padStart(2,"0")}/${hoy.getFullYear()}`;

        // Obtener configuración de facturación (serie, vencimiento, etc.)
        const config = configDoc.data();
        const diasVencimiento = (config["dias_vencimiento"] as number) ?? 0;

        // Crear contador de facturas (serie tpv)
        const contadorRef = db.doc(`empresas/${empresaId}/configuracion/facturacion`);
        const anioActual = hoy.getFullYear();
        let numeroFactura = "";

        await db.runTransaction(async (tx) => {
          const snap = await tx.get(contadorRef);
          const data = snap.exists ? (snap.data() ?? {}) : {};
          const anioGuardado = (data["anio_ultimo_tpv"] as number) ?? 0;
          let contador = anioGuardado === anioActual
            ? ((data["ultimo_numero_tpv"] as number) ?? 0) + 1
            : 1;
          tx.set(contadorRef, {
            ultimo_numero_tpv: contador,
            anio_ultimo_tpv: anioActual,
          }, { merge: true });
          numeroFactura = `TPV-${anioActual}-${String(contador).padStart(4,"0")}`;
        });

        // Crear documento de factura
        const facturaRef = db.collection(`empresas/${empresaId}/facturas`).doc();
        const lineas = pedidosSnap.docs.flatMap((pedidoDoc) => {
          const lineasPedido = (pedidoDoc.data()["lineas"] as any[]) ?? [];
          return lineasPedido.map((l: any) => ({
            descripcion: l.producto_nombre ?? "Venta TPV",
            precio_unitario: l.precio_unitario ?? 0,
            cantidad: l.cantidad ?? 1,
            porcentaje_iva: 10,
            descuento: 0,
            recargo_equivalencia: 0,
          }));
        });

        const subtotal = lineas.reduce((s, l) => s + l.precio_unitario * l.cantidad, 0);
        const totalIva  = lineas.reduce((s, l) => s + (l.precio_unitario * l.cantidad * l.porcentaje_iva / 100), 0);

        await facturaRef.set({
          empresa_id: empresaId,
          numero_factura: numeroFactura,
          serie: "tpv",
          tipo: "venta_directa",
          estado: "pagada",
          cliente_nombre: `Ventas TPV — ${fechaStr}`,
          lineas,
          subtotal,
          total_iva: totalIva,
          total: subtotal + totalIva,
          descuento_global: 0,
          importe_descuento_global: 0,
          porcentaje_irpf: 0,
          retencion_irpf: 0,
          total_recargo_equivalencia: 0,
          dias_vencimiento: diasVencimiento,
          notas_internas: `Resumen diario TPV autom.: ${pedidosSnap.docs.length} ventas · ${totalVentas.toFixed(2)}€`,
          historial: [{
            usuario_id: "",
            usuario_nombre: "TPV Auto",
            accion: "creada",
            descripcion: "Factura resumen diario TPV generada automáticamente",
            fecha: admin.firestore.FieldValue.serverTimestamp(),
          }],
          fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
          fecha_vencimiento: admin.firestore.Timestamp.fromDate(
            new Date(hoy.getTime() + diasVencimiento * 86400000)
          ),
          pedidos_incluidos: pedidosSnap.docs.map(d => d.id),
        });

        // Marcar pedidos como facturados
        const batch = db.batch();
        pedidosSnap.docs.forEach(doc => {
          batch.update(doc.ref, {
            factura_id: facturaRef.id,
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await batch.commit();

        procesadas++;
        console.log(`✅ Factura resumen TPV ${numeroFactura} generada para empresa ${empresaId} (${pedidosSnap.docs.length} ventas)`);
      } catch (error) {
        console.error(`❌ Error generando factura resumen TPV para empresa ${empresaId}:`, error);
      }
    }
    console.log(`✅ generarFacturasResumenTpv finalizado: ${procesadas} empresas procesadas`);
  }
);

// ── Planes V2: migración, actualización y recálculo de módulos ────────────────
export {
  migracionPlanesV2,
  actualizarPlanEmpresaV2,
  actualizarModulosSegunPlan,
} from "./planesConfigV2";

// ── GMB: Google Business Profile ──────────────────────────────────────────────
export {
  storeGmbToken,
  obtenerFichasNegocio,
  guardarFichaSeleccionada,
  desconectarGoogleBusiness,
} from "./gmbTokens";
export {
  publicarRespuestaGoogle,
  procesarRespuestasPendientes,
  scheduledSincronizarResenas,
  alertaResenasNegativasAcumuladas,
  resumenSemanalResenas,
} from "./gmbRespuestas";

// ── SECRETS via variables de entorno (.env o Firebase env config) ─────────
// Valores reales: edita functions/.env (no subir a git)
const stripeSecretKey             = { value: () => process.env.STRIPE_SECRET_KEY          ?? "" };
const stripeSecretKeyTest         = { value: () => process.env.STRIPE_SECRET_KEY_TEST     ?? "" };
const stripeWebhookSecret         = { value: () => process.env.STRIPE_WEBHOOK_SECRET      ?? "" };
const stripeWebhookSecretTest     = { value: () => process.env.STRIPE_WEBHOOK_SECRET_TEST ?? "" };
// Secret para webhooks de tiendas de clientes — puede ser el mismo o uno propio
const stripeTiendaWebhookSecret   = { value: () => process.env.STRIPE_TIENDA_WEBHOOK_SECRET ?? process.env.STRIPE_WEBHOOK_SECRET ?? "" };
// Resend API key — configurado en functions/.env como RESEND_API_KEY

// ── UTILIDADES ────────────────────────────────────────────────────────────────
import { enviarNotificacionEmpresa } from "./utils/notificaciones";

// ── CLOUD FUNCTIONS (v2 API) ──────────────────────────────────────────────────

export { onTareaAsignada }; // Export it
export {
  scheduledGenerarTareasRecurrentes,
  scheduledRecordatoriosTareas,
  scheduledTareasVencenHoy,
  onNuevaSugerencia,
  onNuevoContactoSoporte,
};

// ── Sitemap.xml dinámico por empresa ─────────────────────────────────────────
// GET /generarSitemap?empresa={empresaId}&base={baseUrl}
// Devuelve un sitemap.xml con blog posts publicados + páginas estáticas.

export const generarSitemap = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    const empresaId = req.query.empresa as string;
    const baseUrl   = ((req.query.base as string) || '').replace(/\/$/, '');

    if (!empresaId) {
      res.status(400).send("Parámetro ?empresa=ID requerido");
      return;
    }

    try {
      // Posts del blog publicados
      const blogSnap = await db
        .collection("empresas").doc(empresaId)
        .collection("blog")
        .where("estado", "==", "publicado")
        .get();

      // Info empresa para schema
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      const dominio = baseUrl || (empresaDoc.data()?.dominio_web as string | undefined) || "";

      const ahora = new Date().toISOString().split("T")[0];

      // Páginas estáticas
      const paginas = [
        { loc: `${dominio}/index.html`,     priority: "1.0", changefreq: "weekly" },
        { loc: `${dominio}/catalogo.html`,  priority: "0.9", changefreq: "weekly" },
        { loc: `${dominio}/blog.html`,      priority: "0.9", changefreq: "daily"  },
        { loc: `${dominio}/autores.html`,   priority: "0.7", changefreq: "monthly" },
        { loc: `${dominio}/eventos.html`,   priority: "0.8", changefreq: "weekly" },
        { loc: `${dominio}/conocenos.html`, priority: "0.6", changefreq: "monthly" },
        { loc: `${dominio}/contacto.html`,  priority: "0.5", changefreq: "monthly" },
      ];

      // Blog posts
      const blogsUrls = blogSnap.docs.map((d) => {
        const data = d.data();
        const slug = (data.slug as string) || d.id;
        const fechaTs = data.fecha_publicacion;
        const fechaStr = fechaTs?.toDate
          ? (fechaTs.toDate() as Date).toISOString().split("T")[0]
          : ahora;
        return {
          loc: `${dominio}/blog-post.html?slug=${encodeURIComponent(slug)}`,
          lastmod: fechaStr,
          priority: "0.8",
          changefreq: "monthly",
        };
      });

      const toUrl = (u: {loc:string; lastmod?:string; priority:string; changefreq:string}) =>
        `  <url>\n    <loc>${u.loc}</loc>\n    <lastmod>${u.lastmod || ahora}</lastmod>\n    <changefreq>${u.changefreq}</changefreq>\n    <priority>${u.priority}</priority>\n  </url>`;

      const xml = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        ...paginas.map(toUrl),
        ...blogsUrls.map(toUrl),
        '</urlset>',
      ].join("\n");

      res.set("Content-Type", "application/xml; charset=utf-8");
      res.set("Cache-Control", "public, max-age=3600");
      res.status(200).send(xml);
    } catch (err) {
      console.error("Error generarSitemap:", err);
      res.status(500).send("Error generando sitemap");
    }
  }
);

// ── Publicación programada de blogs ──────────────────────────────────────────
// Ejecuta cada 10 minutos. Busca blogs con estado='programado' cuya
// fecha_publicacion ya haya llegado y los cambia a 'publicado'.

export const publicarBlogsProgramados = onSchedule(
  { schedule: "*/10 * * * *", timeZone: "Europe/Madrid", region: REGION },
  async (_event) => {
    const ahora = admin.firestore.Timestamp.now();

    const snap = await db
      .collectionGroup("blog")
      .where("estado", "==", "programado")
      .where("fecha_publicacion", "<=", ahora)
      .get();

    if (snap.empty) return;

    const batchSize = 500;
    let batch = db.batch();
    let ops = 0;
    let total = 0;

    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        estado: "publicado",
        publicada: true,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      });
      ops++;
      total++;
      if (ops === batchSize) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();

    console.log(`publicarBlogsProgramados: ${total} blog(s) publicado(s)`);
  }
);

/**
 * Helper compartido: procesa reserva/cita nueva → bandeja + push
 */
async function procesarNuevaReservaOCita(
  empresaId: string,
  entidadId: string,
  reserva: FirebaseFirestore.DocumentData,
  coleccion: "reservas" | "citas"
): Promise<void> {
  const cliente    = reserva.nombre_cliente || reserva.cliente || "Cliente";
  const telefonoVal = (reserva.telefono_cliente || reserva.telefono) as string | undefined;
  const emailVal   = reserva.email_cliente || reserva.correo_cliente || reserva.email || (null as string | null);
  const telefono   = telefonoVal ? ` · ${telefonoVal}` : "";

  // Personas / comensales
  const personas    = reserva.numero_personas || reserva.comensales || reserva.personas;
  const personasStr = personas ? ` · ${personas} pers.` : "";

  // Ubicación / zona
  const ubicacion    = reserva.ubicacion || reserva.zona || "";
  const ubicacionStr = ubicacion
    ? ` · ${ubicacion === "terraza" ? "🌿 Terraza" : ubicacion === "salon" ? "🏠 Salón" : ubicacion}`
    : "";

  // Alérgenos — acepta bool true o string "si"
  const alergenosRaw  = reserva.alergenos;
  const tieneAlergenos = alergenosRaw === true || alergenosRaw === "si";
  const alergenosDetalle = (reserva.alergenos_detalle || reserva.detalle_alergenos || "") as string;
  const alergenosStr = tieneAlergenos
    ? ` · ⚠️ Alérgenos${alergenosDetalle ? ": " + alergenosDetalle : ""}`
    : "";

  const servicio = reserva.servicio || "";

  // Campos adicionales genéricos: cualquier campo extra del documento
  const extraCampos: string[] = [];
  const camposGenericosCandidatos = ["zona_mesa", "tipo_menu", "ocasion", "habitacion", "preferencias"];
  for (const c of camposGenericosCandidatos) {
    const v = reserva[c];
    if (v && typeof v === "string" && v.trim()) extraCampos.push(v.trim());
  }
  const extrasStr = extraCampos.length ? ` · ${extraCampos.join(" · ")}` : "";

  const fechaHoraRaw = reserva.fecha_hora;
  let fechaHora = "Fecha pendiente";
  if (fechaHoraRaw) {
    if (typeof fechaHoraRaw === "string") {
      fechaHora = fechaHoraRaw.replace("T", " a las ").substring(0, 19);
    } else if (typeof fechaHoraRaw.toDate === "function") {
      fechaHora = fechaHoraRaw.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
    } else if (fechaHoraRaw._seconds !== undefined) {
      fechaHora = new Date(fechaHoraRaw._seconds * 1000).toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
    }
  } else if (reserva.fecha?.toDate) {
    fechaHora = reserva.fecha.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  }

  const emoji = coleccion === "citas" ? "💈" : "📅";
  const label = coleccion === "citas" ? "Nueva Cita" : "Nueva Reserva";
  const titulo = `${emoji} ${label}`;
  const cuerpo = `${cliente}${telefono}${personasStr}${ubicacionStr} — ${fechaHora}${servicio ? " · " + servicio : ""}${alergenosStr}${extrasStr}`;

  // 1. Guardar en bandeja in-app (con todos los campos extra)
  await db.collection("notificaciones").doc(empresaId).collection("items").add({
    titulo,
    cuerpo,
    tipo: "reservaNueva",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    leida: false,
    modulo_destino: coleccion,
    entidad_id: entidadId,
    remitente_nombre:    cliente !== "Cliente" ? cliente : null,
    remitente_telefono:  telefonoVal || null,
    remitente_email:     emailVal,
    // Campos extra para la bandeja
    ubicacion:           ubicacion || null,
    personas:            personas !== undefined && personas !== null ? String(personas) : null,
    alergenos:           tieneAlergenos,
    alergenos_detalle:   tieneAlergenos && alergenosDetalle ? alergenosDetalle : null,
  });

  // 2. Enviar push FCM
  await enviarNotificacionEmpresa(
    empresaId,
    titulo,
    cuerpo,
    { tipo: "nueva_reserva", reserva_id: entidadId, coleccion }
  );

  console.log(`✅ ${label} guardada en bandeja y push enviado — empresa ${empresaId}`);
}

/**
 * 1. NUEVA RESERVA — Unificada (cubre tanto citas TPV como reservas B2C)
 */
export const onNuevaReserva = onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const reserva = event.data?.data();
    if (!reserva) return;

    // Determinar el tipo de notificación según el origen
    const coleccion = reserva.origen === 'tpv_peluqueria' ? 'citas' : 'reservas';

    await procesarNuevaReservaOCita(
      event.params.empresaId,
      event.params.reservaId,
      reserva,
      coleccion
    );
  }
);

// ⛔ onNuevaCita ELIMINADA — ahora todo se maneja en reservas/ unificadas

// ── HELPER: formatea fecha de reserva para emails ─────────────────────────────
function _formatearFechaReserva(reserva: FirebaseFirestore.DocumentData): string {
  const raw = reserva.fecha_hora || reserva.fecha;
  if (!raw) return "Fecha pendiente";
  if (typeof raw === "string") {
    return raw.replace("T", " a las ").substring(0, 16);
  }
  if (typeof raw.toDate === "function") {
    return raw.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  }
  if (raw._seconds !== undefined) {
    return new Date(raw._seconds * 1000).toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  }
  return "Fecha pendiente";
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE CONTACTO WEB
// ─────────────────────────────────────────────────────────────────────────────

/**
 * NUEVO MENSAJE DE CONTACTO WEB
 * - Envía push notification a todos los dispositivos de la empresa
 * - Envía email al empresario si tiene email_notificaciones configurado
 */
export const onNuevoMensajeContacto = onDocumentCreated(
  { document: "empresas/{empresaId}/contacto_web/{mensajeId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const msg = event.data?.data();
    if (!msg) return;

    const empresa = await _getDatosEmpresa(empresaId);
    const nombre  = msg.nombre || "Visitante";
    const asunto  = msg.asunto || "Sin asunto";
    const cuerpo  = `De: ${nombre} — ${asunto}`;

    // ── 1. Push notification ──────────────────────────────────────────────────
    try {
      const tokensDocs = await db
        .collection(`empresas/${empresaId}/dispositivos`)
        .get();
      const tokens: string[] = tokensDocs.docs
        .map((d) => d.data().token as string)
        .filter((t) => !!t);

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: "💬 Nuevo mensaje de contacto",
            body: cuerpo,
          },
          data: {
            tipo: "contacto_web",
            empresaId,
            mensajeId: event.params.mensajeId,
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
          android: {
            notification: { sound: "default", channelId: "fluix_general" },
          },
        });
      }
    } catch (e) {
      console.error("onNuevoMensajeContacto push error:", e);
    }

    // ── 2. Notificación en colección (para Windows polling) ──────────────────
    try {
      await db.collection(`empresas/${empresaId}/notificaciones`).add({
        titulo: "💬 Nuevo mensaje de contacto",
        cuerpo,
        tipo: "contacto_web",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        datos: { mensajeId: event.params.mensajeId, tipo: "contacto_web", empresaId },
      });
    } catch (e) {
      console.error("onNuevoMensajeContacto notificacion error:", e);
    }

    // ── 3. Email al empresario ────────────────────────────────────────────────
    if (empresa.email) {
      try {
        await enviarNotificacionContactoWeb({
          emailEmpresario: empresa.email,
          empresaNombre: empresa.nombre,
          nombreRemitente: nombre,
          emailRemitente: msg.email || "",
          telefonoRemitente: msg.telefono || "",
          asunto,
          mensajeTexto: msg.mensaje || "",
        });
      } catch (e) {
        console.error("onNuevoMensajeContacto email error:", e);
      }
    }
  }
);

/**
 * MENSAJE RESPONDIDO
 * Cuando el empresario escribe su respuesta en la app, se envía un email
 * automáticamente al visitante usando Resend.
 * Trigger: campos `respondido` (false→true) y `respuesta` (nuevo) en el doc.
 */
export const onMensajeContactoRespondido = onDocumentUpdated(
  { document: "empresas/{empresaId}/contacto_web/{mensajeId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const antes   = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    // Solo disparar cuando pasa de no-respondido a respondido y hay respuesta
    if (antes.respondido === true) return;
    if (despues.respondido !== true) return;
    const respuesta = (despues.respuesta || "").trim();
    if (!respuesta) return;

    const emailRemitente = despues.email;
    if (!emailRemitente) {
      console.log("onMensajeContactoRespondido: sin email del remitente, omitiendo");
      return;
    }

    const empresa = await _getDatosEmpresa(empresaId);

    try {
      await enviarRespuestaContactoWeb({
        emailRemitente,
        nombreRemitente: despues.nombre || "Visitante",
        empresaNombre: empresa.nombre,
        asunto: despues.asunto || "Tu consulta",
        mensajeOriginal: despues.mensaje || "",
        respuestaTexto: respuesta,
      });
      console.log(`✅ Respuesta enviada a ${emailRemitente}`);
    } catch (e) {
      console.error("onMensajeContactoRespondido email error:", e);
    }
  }
);

// ── TEST EMAIL (temporal — quitar tras diagnosticar) ──────────────────────────
export const testEmail = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }
    const to = req.body?.to || "sacoor80@gmail.com";
    try {
      const apiKey = process.env.RESEND_API_KEY || "";
      if (!apiKey) { res.json({ ok: false, error: "RESEND_API_KEY not set" }); return; }
      const result = await enviarPdfGenerico({
        from: "Editorial Nazarí <noreply@fluixtech.com>",
        to,
        subject: "Test email desde Cloud Functions",
        html: `<p>Email de prueba enviado desde la función. API Key presente: ${apiKey.length > 0 ? 'SÍ ('+apiKey.slice(0,8)+'...)' : 'NO'}</p>`,
      });
      res.json({ ok: result.exito, id: result.id, error: result.error });
    } catch (e: any) {
      res.json({ ok: false, error: e.message });
    }
  }
);

// ── ENVÍO DE CAMPAÑAS DE EMAIL ─────────────────────────────────────────────────
//
// Trigger: campanas_email/{campanaId} pasa a estado 'enviando'
// 1. Recoge la lista de destinatarios según segmento
// 2. Envía con Resend en lotes de 10 (evita rate-limit)
// 3. Actualiza estado → 'enviada' | 'fallida' + total_enviados

export const enviarCampanaEmail = onDocumentUpdated(
  { document: "empresas/{empresaId}/campanas_email/{campanaId}", region: REGION },
  async (event) => {
    const antes   = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "enviando") return;
    if (despues.estado !== "enviando") return;

    const empresaId = event.params.empresaId;
    const campanaId = event.params.campanaId;
    const campanaRef = db.collection(`empresas/${empresaId}/campanas_email`).doc(campanaId);

    const asunto       = (despues.asunto        as string) || "(Sin asunto)";
    const contenidoRaw  = (despues.contenido_html as string) || "";
    const segmento      = (despues.segmento       as string) || "todos";
    const destinatariosManual: string[] = (despues.destinatarios_manual as string[]) || [];

    const empresa = await _getDatosEmpresa(empresaId);
    const fromEmail = `${empresa.nombre} <noreply@fluixtech.com>`;

    // Convertir saltos de línea a <br> si el contenido no tiene tags HTML
    const tieneHtml = /<[a-z][\s\S]*>/i.test(contenidoRaw);
    const contenidoProcessed = tieneHtml
      ? contenidoRaw
      : contenidoRaw.replace(/\n/g, "<br>");

    // Envolver en template HTML profesional
    const anio = new Date().getFullYear();
    const contenidoHtml = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${asunto}</title>
</head>
<body style="margin:0;padding:0;background:#f0f0f0;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f0f0;padding:32px 16px;">
    <tr><td align="center">
      <table width="620" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border-radius:10px;overflow:hidden;max-width:620px;box-shadow:0 2px 12px rgba(0,0,0,.08);">
        <!-- HEADER -->
        <tr>
          <td style="background:#1a1a2e;padding:28px 40px;text-align:center;">
            <span style="color:#ffffff;font-size:24px;font-weight:bold;letter-spacing:.5px;">${empresa.nombre}</span>
          </td>
        </tr>
        <!-- ASUNTO -->
        <tr>
          <td style="padding:28px 40px 0;border-bottom:1px solid #e8eaed;">
            <h2 style="margin:0 0 16px;font-size:20px;color:#1a1a2e;font-weight:700;line-height:1.3;">${asunto}</h2>
          </td>
        </tr>
        <!-- CONTENIDO -->
        <tr>
          <td style="padding:28px 40px;font-size:15px;color:#374151;line-height:1.7;">
            ${contenidoProcessed}
          </td>
        </tr>
        <!-- FOOTER -->
        <tr>
          <td style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #e8eaed;">
            <p style="margin:0;font-size:12px;color:#9ca3af;">
              © ${anio} ${empresa.nombre}. Todos los derechos reservados.<br>
              Para dejar de recibir este tipo de comunicaciones responde con "BAJA".
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    // Construir lista de destinatarios
    let emails: string[] = [];
    try {
      if (segmento === "manual") {
        emails = destinatariosManual.filter(e => e.includes("@"));
      } else {
        // Segmento 'todos' o 'clientes_activos': leer de colección clientes
        const corte = segmento === "clientes_activos"
          ? new Date(Date.now() - 90 * 24 * 3600 * 1000)
          : null;
        let q = db.collection(`empresas/${empresaId}/clientes`)
          .where("activo", "!=", false) as FirebaseFirestore.Query;
        if (corte) {
          q = db.collection(`empresas/${empresaId}/clientes`)
            .where("fecha_creacion", ">=", admin.firestore.Timestamp.fromDate(corte));
        }
        const snap = await q.get();
        snap.docs.forEach(d => {
          const email = d.data().email || d.data().correo || "";
          if (email.includes("@")) emails.push(email);
        });
        // También leer de colección 'clientes_web' si existe
        try {
          const snapWeb = await db.collection(`empresas/${empresaId}/contacto_web`)
            .where("origen", "!=", "manuscrito").get();
          snapWeb.docs.forEach(d => {
            const email = d.data().email || "";
            if (email.includes("@") && !emails.includes(email)) emails.push(email);
          });
        } catch (_) {}
      }
    } catch (e) {
      console.error("❌ [Campaña] Error obteniendo destinatarios:", e);
      await campanaRef.update({ estado: "fallida", error_mensaje: "Error obteniendo destinatarios" });
      return;
    }

    if (emails.length === 0) {
      console.warn(`⚠️ [Campaña] ${campanaId} — sin destinatarios`);
      await campanaRef.update({ estado: "enviada", total_enviados: 0, fecha_envio: admin.firestore.FieldValue.serverTimestamp() });
      return;
    }

    // Envío en lotes de 10
    let enviados = 0;
    const LOTE = 10;
    for (let i = 0; i < emails.length; i += LOTE) {
      const lote = emails.slice(i, i + LOTE);
      await Promise.allSettled(lote.map(to =>
        enviarPdfGenerico({ from: fromEmail, to, subject: asunto, html: contenidoHtml })
          .then(r => { if (r.exito) enviados++; })
          .catch(() => {})
      ));
      // Pausa breve entre lotes para no saturar Resend
      if (i + LOTE < emails.length) await new Promise(r => setTimeout(r, 500));
    }

    await campanaRef.update({
      estado:          "enviada",
      total_enviados:  enviados,
      fecha_envio:     admin.firestore.FieldValue.serverTimestamp(),
      fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ [Campaña] ${campanaId} enviada — ${enviados}/${emails.length} emails`);
  }
);

// ── HELPER: obtiene nombre e email de la empresa ───────────────────────────────
async function _getDatosEmpresa(empresaId: string): Promise<{ nombre: string; email: string | null }> {  try {
    const doc = await db.collection("empresas").doc(empresaId).get();
    const d = doc.data() || {};
    return {
      nombre: (d.nombre as string) || "El establecimiento",
      email: (d.email_notificaciones || d.correo || d.email || null) as string | null,
    };
  } catch (_) {
    return { nombre: "El establecimiento", email: null };
  }
}

/**
 * 2a. RESERVA CONFIRMADA — envía push a la empresa + email de confirmación al cliente
 */
export const onReservaConfirmada = onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION, secrets: ["RESEND_API_KEY"] },
  async (event) => {
    const empresaId = event.params.empresaId;
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    // Solo cuando cambia a CONFIRMADA
    if (antes.estado === despues.estado || despues.estado !== "CONFIRMADA") return;

    const cliente   = despues.nombre_cliente || despues.cliente || "Cliente";
    const fechaHora = _formatearFechaReserva(despues);
    const servicio  = despues.servicio || "";
    const emailCliente = despues.email_cliente || despues.correo_cliente || despues.email || null;

    // 1. Push a la empresa (confirmación interna)
    const cuerpo = `${cliente} — ${fechaHora}${servicio ? " · " + servicio : ""}`;
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo: "✅ Reserva Confirmada",
      cuerpo,
      tipo: "reservaConfirmada",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      leida: false,
      modulo_destino: "reservas",
      entidad_id: event.params.reservaId,
      remitente_nombre: cliente !== "Cliente" ? cliente : null,
      remitente_telefono: despues.telefono_cliente || null,
      remitente_email: emailCliente,
    });

    await enviarNotificacionEmpresa(
      empresaId,
      "✅ Reserva Confirmada",
      cuerpo,
      { tipo: "reserva_confirmada", reserva_id: event.params.reservaId }
    );

    // 2. Email al cliente si tiene correo
    if (emailCliente) {
      try {
        const empresa = await _getDatosEmpresa(empresaId);
        const personas = despues.numero_personas || despues.personas;
        const zona = despues.zona || "";

        await enviarConfirmacionReserva({
          to: emailCliente,
          clienteNombre: cliente,
          empresaNombre: empresa.nombre,
          fechaHora,
          personas: personas ? String(personas) : undefined,
          servicio: servicio || undefined,
          zona: zona || undefined,
          notas: despues.notas || undefined,
          fromEmail: empresa.email || undefined,
        });
        console.log(`✅ Email confirmación reserva enviado a ${emailCliente}`);
      } catch (emailErr: any) {
        console.error("❌ Error enviando email confirmación reserva:", emailErr.message);
      }
    } else {
      console.log(`ℹ️ Reserva ${event.params.reservaId} confirmada sin email de cliente`);
    }
  }
);

/**
 * 2b. RESERVA CANCELADA — notifica a la empresa + email de cancelación al cliente
 */
export const onReservaCancelada = onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION, secrets: ["RESEND_API_KEY"] },
  async (event) => {
    const empresaId = event.params.empresaId;
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    if (antes.estado === despues.estado || despues.estado !== "CANCELADA") {
      return;
    }

    const cliente   = despues.nombre_cliente || despues.cliente || "Cliente";
    const servicio  = despues.servicio || "";
    const fechaHora = _formatearFechaReserva(despues);
    const cuerpo    = `${cliente} — ${fechaHora}${servicio ? " · " + servicio : ""}`;
    const emailCliente = despues.email_cliente || despues.correo_cliente || despues.email || null;

    // 1. Bandeja + push a la empresa
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo: "❌ Reserva Cancelada",
      cuerpo,
      tipo: "reservaCancelada",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      leida: false,
      modulo_destino: "reservas",
      entidad_id: event.params.reservaId,
      remitente_nombre: cliente !== "Cliente" ? cliente : null,
      remitente_telefono: despues.telefono_cliente || null,
      remitente_email: emailCliente,
    });

    await enviarNotificacionEmpresa(
      empresaId,
      "❌ Reserva Cancelada",
      cuerpo,
      { tipo: "reserva_cancelada", reserva_id: event.params.reservaId }
    );

    // 2. Email al cliente si tiene correo
    if (emailCliente) {
      try {
        const empresa = await _getDatosEmpresa(empresaId);
        const personas = despues.numero_personas || despues.personas;

        await enviarCancelacionReserva({
          to: emailCliente,
          clienteNombre: cliente,
          empresaNombre: empresa.nombre,
          fechaHora,
          personas: personas ? String(personas) : undefined,
          servicio: servicio || undefined,
          motivoCancelacion: despues.motivo_cancelacion || undefined,
          fromEmail: empresa.email || undefined,
        });
        console.log(`✅ Email cancelación reserva enviado a ${emailCliente}`);
      } catch (emailErr: any) {
        console.error("❌ Error enviando email cancelación reserva:", emailErr.message);
      }
    } else {
      console.log(`ℹ️ Reserva ${event.params.reservaId} cancelada sin email de cliente`);
    }
  }
);

/**
 * 2c. REENVÍO MANUAL de confirmación de reserva (callable desde la app)
 */
export const reenviarConfirmacionReserva = onCall(
  { region: REGION, secrets: ["RESEND_API_KEY"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado");
    }
    const { empresaId, reservaId } = request.data as { empresaId: string; reservaId: string };
    if (!empresaId || !reservaId) {
      throw new HttpsError("invalid-argument", "Faltan empresaId o reservaId");
    }

    const snap = await db
      .collection("empresas").doc(empresaId)
      .collection("reservas").doc(reservaId).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Reserva no encontrada");
    }
    const d = snap.data()!;
    const emailCliente = d.email_cliente || d.correo_cliente || d.email || null;
    if (!emailCliente) {
      throw new HttpsError("failed-precondition", "La reserva no tiene email de cliente");
    }

    const cliente = d.nombre_cliente || d.cliente || "Cliente";
    const empresa = await _getDatosEmpresa(empresaId);

    await enviarConfirmacionReserva({
      to: emailCliente,
      clienteNombre: cliente,
      empresaNombre: empresa.nombre,
      fechaHora: _formatearFechaReserva(d),
      personas: (d.numero_personas || d.personas) ? String(d.numero_personas || d.personas) : undefined,
      servicio: d.servicio || undefined,
      zona: d.zona || undefined,
      notas: d.notas || undefined,
      fromEmail: empresa.email || undefined,
    });

    return { exito: true };
  }
);

/**
 * 3. NUEVA VALORACIÓN — con alertas diferenciadas por rating
 */
export const onNuevaValoracion = onDocumentCreated(
  { document: "empresas/{empresaId}/valoraciones/{valoracionId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const valoracion = event.data?.data();
    if (!valoracion) return;

    const cliente = valoracion.cliente || "Cliente";
    const estrellas = valoracion.calificacion || valoracion.estrellas || 5;
    const comentario = valoracion.comentario || "";
    const origen = valoracion.origen || "app";

    // Leer umbral de alerta configurado por el empresario (defecto: 3)
    let umbralAlerta = 3;
    try {
      const prefSnap = await db
        .collection("empresas").doc(empresaId)
        .collection("configuracion").doc("alertas_resenas")
        .get();
      if (prefSnap.exists) {
        umbralAlerta = (prefSnap.data()?.umbral_alerta as number) ?? 3;
      }
    } catch (_) {}

    const esNegativa = estrellas <= umbralAlerta;

    const titulo = esNegativa
      ? `⚠️ Nueva reseña de ${estrellas} ${estrellas === 1 ? "estrella" : "estrellas"}`
      : `⭐ Nueva reseña positiva${origen === "google" ? " en Google" : ""}`;

    const cuerpo = `${cliente}: "${comentario.substring(0, 80)}${comentario.length > 80 ? "..." : ""}"`;

    const mensaje: admin.messaging.MulticastMessage = {
      tokens: [],
      notification: { title: titulo, body: cuerpo },
      data: {
        empresa_id: empresaId,
        tipo: esNegativa ? "resena_negativa" : "resena_positiva",
        valoracion_id: event.params.valoracionId,
        calificacion: String(estrellas),
      },
      android: {
        priority: "high",
        notification: {
          channelId: esNegativa
            ? "fluixcrm_resenas_negativas"
            : "fluixcrm_canal_principal",
          priority: esNegativa ? "max" : "high",
          sound: "default",
          visibility: "public",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "interruption-level": esNegativa ? "time-sensitive" : "active",
          },
        },
      },
    };

    await enviarNotificacionEmpresa(
      empresaId,
      titulo,
      cuerpo,
      mensaje.data as Record<string, string>
    );
  }
);

/**
 * 4. NUEVO PEDIDO
 */
export const onNuevoPedido = onDocumentCreated(
  { document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const pedido = event.data?.data();
    if (!pedido) return;

    // El widget web guarda 'cliente_nombre'; la app guarda 'cliente'
    const cliente = pedido.cliente_nombre || pedido.cliente || pedido.nombre_cliente || "Cliente";
    const telefono = pedido.cliente_telefono || pedido.telefono || null;
    const email    = pedido.cliente_correo   || pedido.email   || null;
    const total    = pedido.precio_total || pedido.total || 0;
    const origen   = pedido.origen || "app";

    // Las funciones Stripe crean la notificación directamente para garantizar entrega.
    // Evitar duplicados saltando sus orígenes aquí.
    if (origen === "web_nazari" || origen === "tienda_online") return;

    const cuerpo   = `${cliente} — €${(total as number).toFixed(2)} (vía ${origen})`;

    // Guardar en bandeja in-app
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo:             "📦 Nuevo Pedido",
      cuerpo,
      tipo:               "pedidoNuevo",
      timestamp:          admin.firestore.FieldValue.serverTimestamp(),
      leida:              false,
      modulo_destino:     "pedidos",
      entidad_id:         event.params.pedidoId,
      remitente_nombre:   cliente !== "Cliente" ? cliente : null,
      remitente_telefono: telefono,
      remitente_email:    email,
    });

    await enviarNotificacionEmpresa(
      empresaId,
      "📦 Nuevo Pedido",
      cuerpo,
      { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId }
    );
  }
);

/**
 * 4b. PEDIDO ENVIADO → email al cliente con resumen de envío
 */
export const onPedidoEstadoCambiado = onDocumentUpdated(
  { document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION },
  async (event) => {
    const antes  = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    // Solo cuando cambia de otro estado a 'enviado'
    if (antes.estado === despues.estado) return;
    if (despues.estado !== "enviado") return;

    const correo = despues.cliente_correo || despues.cliente_email || null;
    if (!correo) {
      console.log(`ℹ️ Pedido ${event.params.pedidoId} enviado, sin correo del cliente`);
      return;
    }

    const empresaId = event.params.empresaId;
    const empresa   = await _getDatosEmpresa(empresaId);

    const lineas = ((despues.lineas || []) as Array<Record<string, unknown>>).map((l) => ({
      nombre:   String(l.producto_nombre || l.nombre || "Producto"),
      cantidad: Number(l.cantidad        || 1),
      precio:   Number(l.precio_unitario || l.precio || 0),
    }));

    try {
      await enviarNotificacionPedidoEnviado({
        to:            correo,
        clienteNombre: String(despues.cliente_nombre || "Cliente"),
        empresaNombre: empresa.nombre,
        fromEmail:     empresa.email || undefined,
        numeroTicket:  Number(despues.numero_ticket || 0),
        lineas,
        total:         Number(despues.total || 0),
        direccionEnvio: (despues.direccion_envio as string | null) || null,
        notasEnvio:    String(despues.notas_envio || ""),
      });
      console.log(`📧 Email de envío enviado a ${correo} (pedido ${event.params.pedidoId})`);
    } catch (e) {
      console.warn("⚠️ Error enviando email de envío:", e);
    }
  }
);

/**
 * 5. NUEVO PEDIDO → GENERAR FACTURA AUTOMÁTICAMENTE
 */
export const onNuevoPedidoGenerarFactura = onDocumentCreated(
  { document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const pedidoId = event.params.pedidoId;
    const snap = event.data;
    if (!snap) return;
    const pedido = snap.data();

    try {
      const configRef = db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("facturacion");

      let numeroFactura = "";
      await db.runTransaction(async (tx) => {
        const configSnap = await tx.get(configRef);
        let contador = 1;
        if (configSnap.exists) {
          contador = ((configSnap.data()?.ultimo_numero_factura as number) ?? 0) + 1;
        }
        tx.set(configRef, { ultimo_numero_factura: contador }, { merge: true });
        const anio = new Date().getFullYear();
        numeroFactura = `FAC-${anio}-${String(contador).padStart(4, "0")}`;
      });

      const lineasPedido = (pedido.lineas as Array<Record<string, unknown>>) || [];
      const lineasFactura = lineasPedido.map((l) => ({
        descripcion: (l.producto_nombre || l.descripcion || "Producto") as string,
        precio_unitario: (l.precio_unitario as number) || 0,
        cantidad: (l.cantidad as number) || 1,
        // Usar el IVA real de la línea del pedido; si no existe, 21% por defecto
        porcentaje_iva: (l.porcentaje_iva as number) || (l.iva as number) || 21.0,
        descuento: (l.descuento as number) || 0,
        recargo_equivalencia: (l.recargo_equivalencia as number) || 0,
        referencia: (l.producto_id || l.referencia || null) as string | null,
      }));

      const subtotal = lineasFactura.reduce(
        (sum, l) => sum + l.precio_unitario * l.cantidad * (1 - l.descuento / 100),
        0
      );
      const totalIva = lineasFactura.reduce(
        (sum, l) =>
          sum + l.precio_unitario * l.cantidad * (1 - l.descuento / 100) * (l.porcentaje_iva / 100),
        0
      );
      const total = subtotal + totalIva;

      const metodoPagoMap: Record<string, string> = {
        tarjeta: "tarjeta",
        paypal: "paypal",
        bizum: "bizum",
        efectivo: "efectivo",
        transferencia: "transferencia",
        stripe: "tarjeta",
      };
      const metodoPago = metodoPagoMap[pedido.metodo_pago as string] ?? null;

      // Si el pedido ya está pagado (origen Stripe, etc.), la factura nace directamente como "pagada"
      const estadoPago = pedido.estado_pago as string || "";
      const estadoFactura = (estadoPago === "pagado" || estadoPago === "paid") ? "pagada" : "pendiente";

      const facturaData = {
        empresa_id: empresaId,
        numero_factura: numeroFactura,
        serie: "fac",
        tipo: "pedido",
        estado: estadoFactura,
        cliente_nombre: pedido.cliente_nombre || "Cliente",
        cliente_telefono: (pedido.cliente_telefono as string) || null,
        cliente_correo: (pedido.cliente_correo as string) || null,
        datos_fiscales: (pedido.datos_fiscales as object) || null,
        lineas: lineasFactura,
        subtotal: subtotal,
        total_iva: totalIva,
        total: total,
        descuento_global: 0,
        importe_descuento_global: 0,
        porcentaje_irpf: 0,
        retencion_irpf: 0,
        total_recargo_equivalencia: 0,
        dias_vencimiento: 30,
        metodo_pago: metodoPago,
        pedido_id: pedidoId,
        notas_internas: null,
        notas_cliente: (pedido.notas_cliente as string) || null,
        // Si ya está pagada, registrar fecha_pago
        fecha_pago: estadoFactura === "pagada"
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
        historial: [
          {
            usuario_id: "",
            usuario_nombre: "Sistema",
            accion: "creada",
            descripcion: `Factura generada automáticamente desde pedido ${pedidoId.substring(0, 8).toUpperCase()}`,
            fecha: admin.firestore.FieldValue.serverTimestamp(),
          },
        ],
        fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
        fecha_vencimiento: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        ),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      };

      const facturaRef = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("facturas")
        .add(facturaData);

      await snap.ref.update({ factura_id: facturaRef.id });

      console.log(
        `✅ Factura ${numeroFactura} generada automáticamente para pedido ${pedidoId} (empresa ${empresaId})`
      );
    } catch (error) {
      console.error(`❌ Error generando factura para pedido ${pedidoId}:`, error);
    }
  }
);

// onNuevaFactura ELIMINADA — todas las facturas se generan automáticamente
// desde pedidos de la web, por lo que la notificación de "nuevo pedido" (onNuevoPedido)
// ya cubre el aviso. Tener una notificación extra por factura era redundante.

/**
 * 7. SUSCRIPCIÓN POR VENCER — Cron diario (v2 scheduler)
 */
export const verificarSuscripciones = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Europe/Madrid",
    region: REGION,
  },
  async () => {
    console.log("🔍 Verificando suscripciones próximas a vencer...");

    const ahora = new Date();
    const empresasSnap = await db.collection("empresas").get();

    for (const empresaDoc of empresasSnap.docs) {
      try {
        const suscripcionDoc = await empresaDoc.ref
          .collection("suscripcion")
          .doc("actual")
          .get();

        if (!suscripcionDoc.exists) continue;

        const suscripcion = suscripcionDoc.data()!;
        const fechaFin = suscripcion.fecha_fin?.toDate
          ? suscripcion.fecha_fin.toDate()
          : null;

        if (!fechaFin || suscripcion.estado === "VENCIDA") continue;

        const diasRestantes = Math.ceil(
          (fechaFin.getTime() - ahora.getTime()) / (1000 * 60 * 60 * 24)
        );

        const empresaId = empresaDoc.id;

        // ── AUTO-VENCIMIENTO: marcar como VENCIDA si pasó la fecha ──
        if (diasRestantes < -7 && suscripcion.estado === "ACTIVA") {
          // Pasaron más de 7 días de gracia → bloquear
          await suscripcionDoc.ref.update({
            estado: "VENCIDA",
            fecha_vencimiento_real: admin.firestore.FieldValue.serverTimestamp(),
          });
          await enviarNotificacionEmpresa(
            empresaId,
            "🔒 Suscripción Vencida",
            "Tu suscripción ha expirado. Renueva en fluixtech.com para seguir usando la app.",
            { tipo: "suscripcion_vencida" }
          );
          console.log(`🔒 Suscripción VENCIDA para empresa ${empresaId}`);
          continue;
        }

        if (diasRestantes < 0 && diasRestantes >= -7 && suscripcion.estado === "ACTIVA") {
          // Periodo de gracia (0-7 días tras vencimiento): avisar pero no bloquear
          if (!suscripcion.aviso_gracia_enviado) {
            await enviarNotificacionEmpresa(
              empresaId,
              "⚠️ Suscripción expirada — periodo de gracia",
              `Tu suscripción venció hace ${Math.abs(diasRestantes)} día(s). Renueva antes de ${7 + diasRestantes} días para no perder acceso.`,
              { tipo: "suscripcion_gracia", dias_restantes: String(diasRestantes) }
            );
            await suscripcionDoc.ref.update({
              aviso_gracia_enviado: true,
              ultimo_aviso: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`⚠️ Periodo de gracia para empresa ${empresaId} (día ${Math.abs(diasRestantes)} de 7)`);
          }
          continue;
        }

        // ── AVISOS PRE-VENCIMIENTO: 7, 3 y 1 día antes ──
        if ([7, 3, 1].includes(diasRestantes)) {
          await enviarNotificacionEmpresa(
            empresaId,
            "⚠️ Suscripción por Vencer",
            `Tu suscripción vence en ${diasRestantes} día${diasRestantes !== 1 ? "s" : ""}. ¡Renueva para continuar!`,
            {
              tipo: "suscripcion_por_vencer",
              dias_restantes: String(diasRestantes),
            }
          );

          await suscripcionDoc.ref.update({
            aviso_enviado: true,
            aviso_gracia_enviado: false,
            ultimo_aviso: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(
            `✅ Aviso suscripción enviado para empresa ${empresaId} (${diasRestantes} días)`
          );
        }
      } catch (error) {
        console.error(`❌ Error procesando empresa ${empresaDoc.id}:`, error);
      }
    }
  }
);

/**
 * 8. PEDIDO WHATSAPP NUEVO
 */
export const onNuevoPedidoWhatsApp = onDocumentCreated(
  { document: "empresas/{empresaId}/pedidos_whatsapp/{pedidoId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const pedido = event.data?.data();
    if (!pedido) return;

    const cliente = pedido.nombre_cliente || pedido.telefono || "Cliente WhatsApp";
    const total = pedido.total || 0;

    await enviarNotificacionEmpresa(
      empresaId,
      "💬 Pedido por WhatsApp",
      `${cliente} — €${total.toFixed(2)}`,
      { tipo: "pedido_whatsapp", pedido_id: event.params.pedidoId }
    );
  }
);

// ── GENERADOR DE SCRIPTS DINÁMICOS ────────────────────────────────────────────
// ⛔ generarScriptEmpresa ELIMINADA — causaba doble push al tener formulario de
//    reservas propio que disparaba onNuevaReserva. Usar script_hostinger_v2.txt
//    (data-fluix-seccion) directamente en la web.

/* generarScriptHTML — ELIMINADO (ver comentario en bloque superior) */
// @ts-ignore — función eliminada, mantenida solo como referencia
function _generarScriptHTML_ELIMINADO(
  empresaId: string,
  nombreEmpresa: string,
  dominio: string
): string {
  return `<!-- ============================================================
     🔥 FLUIX CRM - SCRIPT COMPLETO: CONTENIDO DINÁMICO + ANALYTICS
     Web: ${dominio}
     Empresa: ${nombreEmpresa}
     Versión: SEGURA (no bloquea la web si Firebase falla)
     ============================================================ -->

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- ② PON ESTOS DIVS DONDE QUIERAS EN TU WEB                      -->
<!-- TIP: añade style="display:none" si quieres ocultar al inicio.  -->
<!--      Se revelarán automáticamente al activarlos en la app.      -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- Ejemplo: <div id="fluixcrm_SECCION_ID"></div>                  -->
<!-- Las secciones que crees en la app se inyectarán aquí.           -->
<!-- También puedes añadir estos divs especiales:                    -->
<!-- <div id="fluixcrm_contacto"></div>   → Formulario de contacto   -->
<!-- <div id="fluixcrm_reservas"></div>   → Formulario de reservas   -->
<!-- <div id="fluixcrm_blog"></div>       → Blog / Noticias          -->

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- ③ PEGA ESTO ANTES DEL </body>                                  -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- Firebase SDK -->
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js"></script>

<script>
(function () {
  'use strict';

  var FIREBASE_CONFIG = {
    apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  var EMPRESA_ID = "${empresaId}";
  var DOMINIO_WEB = "${dominio}";
  var NOMBRE_EMPRESA = "${nombreEmpresa}";

  window.addEventListener('load', function () {
    try {
      inicializar();
    } catch (e) {
      console.warn('Fluix CRM: error al inicializar (la web funciona igualmente)', e);
    }
  });

  function inicializar() {
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }

    var db = firebase.firestore();

    // ── ANALYTICS: registrar visitas y eventos ───────────────────────
    registrarVisita(db).catch(function (e) {
      console.warn('Fluix CRM: error registrando visita', e);
    });
    rastrearEventos(db).catch(function (e) {
      console.warn('Fluix CRM: error rastreando eventos', e);
    });

    // ── CONTENIDO DINÁMICO: secciones editadas desde la app ──────────
    cargarContenidoDinamico(db);

    // ── FORMULARIO DE CONTACTO ───────────────────────────────────────
    cargarFormularioContacto(db);

    // ── FORMULARIO DE RESERVAS ───────────────────────────────────────
    cargarFormularioReservas(db);

    // ── BLOG / NOTICIAS ──────────────────────────────────────────────
    cargarBlog(db);
  }

  // ── HELPER: renderizar div ─────────────────────────────────────────
  function render(id, html, show) {
    var el = document.getElementById("fluixcrm_" + id);
    if (!el) return;
    el.innerHTML = html;
    el.style.display = (show === false) ? "none" : "";
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENIDO DINÁMICO — lee secciones en tiempo real desde Firestore
  // ═══════════════════════════════════════════════════════════════════
  function cargarContenidoDinamico(db) {
    db.collection("empresas").doc(EMPRESA_ID)
      .collection("contenido_web").onSnapshot(function(snap) {

      // Detectar secciones eliminadas → ocultar el div
      snap.docChanges().forEach(function(ch) {
        if (ch.type === "removed") render(ch.doc.id, "", false);
      });

      // Renderizar cada sección activa
      snap.forEach(function(doc) {
        var d = doc.data();
        var tipo = d.tipo || "texto";
        var c = d.contenido || {};

        // Si la sección está desactivada → ocultar
        if (!d.activa) { render(doc.id, "", false); return; }

        var html = "";

        if (tipo === "texto") {
          html = '<h3>' + (c.titulo || '') + '</h3>'
               + '<p>' + (c.texto || '') + '</p>'
               + (c.imagen_url ? '<img src="' + c.imagen_url + '" style="max-width:100%;border-radius:8px">' : '');
        }

        else if (tipo === "carta") {
          var items = (c.items_carta || []).filter(function(p){ return p.disponible !== false; });
          html = items.map(function(p) {
            return '<div style="border-bottom:1px solid #eee;padding:10px 0;display:flex;gap:12px;align-items:start">'
              + (p.imagen_url ? '<img src="' + p.imagen_url + '" style="width:70px;height:70px;object-fit:cover;border-radius:8px">' : '')
              + '<div style="flex:1"><div><strong style="font-size:15px">' + p.nombre + '</strong>'
              + '<span style="float:right;font-weight:bold;color:#e65100">' + p.precio + '€</span></div>'
              + '<p style="margin:4px 0 0;color:#666;font-size:13px;line-height:1.4">' + (p.descripcion || '') + '</p></div></div>';
          }).join("");
        }

        else if (tipo === "galeria") {
          var imgs = c.imagenes_galeria || [];
          html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px">'
            + imgs.map(function(i) {
                return '<img src="' + i.url + '" style="width:100%;border-radius:8px;object-fit:cover;aspect-ratio:1" loading="lazy">';
              }).join("")
            + '</div>';
        }

        else if (tipo === "ofertas") {
          var ofertas = (c.ofertas || []).filter(function(o){ return o.activa; });
          html = ofertas.map(function(o) {
            return '<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:12px">'
              + (o.imagen_url ? '<img src="' + o.imagen_url + '" style="width:100%;border-radius:6px;margin-bottom:8px">' : '')
              + '<h4 style="margin:0 0 6px">' + o.titulo + '</h4>'
              + '<p style="color:#666;font-size:13px">' + (o.descripcion || '') + '</p>'
              + (o.precio_original ? '<s style="color:#999">' + o.precio_original + '€</s> ' : '')
              + (o.precio_oferta ? '<strong style="color:#e53935;font-size:18px">' + o.precio_oferta + '€</strong>' : '')
              + '</div>';
          }).join("");
        }

        else if (tipo === "horarios") {
          var filas = (c.horarios || []).map(function(h) {
            return '<tr style="border-bottom:1px solid #f5f5f5">'
              + '<td style="padding:8px 12px;font-weight:bold">' + h.dia + '</td>'
              + '<td style="padding:8px 12px;color:' + (h.cerrado ? '#e53935' : '#2e7d32') + '">'
              + (h.cerrado ? 'Cerrado' : h.apertura + ' – ' + h.cierre) + '</td></tr>';
          }).join("");
          html = '<table style="width:100%;border-collapse:collapse">' + filas + '</table>';
        }

        render(doc.id, html, true);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // FORMULARIO DE CONTACTO — se inyecta en #fluixcrm_contacto
  // ═══════════════════════════════════════════════════════════════════
  function cargarFormularioContacto(db) {
    var el = document.getElementById("fluixcrm_contacto");
    if (!el) return;
    el.innerHTML = '<div style="max-width:480px">'
      + '<h3>Contáctanos</h3>'
      + '<form id="fluixcrm_form_contacto" style="display:flex;flex-direction:column;gap:12px">'
      + '<input name="nombre" placeholder="Tu nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="email" type="email" placeholder="Tu email" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      + '<textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:10px;border:1px solid #ddd;border-radius:8px;resize:vertical"></textarea>'
      + '<button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button>'
      + '</form></div>';

    document.getElementById("fluixcrm_form_contacto").addEventListener("submit", function(e) {
      e.preventDefault();
      var fd = new FormData(e.target);
      db.collection("empresas").doc(EMPRESA_ID).collection("contacto_web").add({
        nombre: fd.get("nombre"),
        email: fd.get("email"),
        mensaje: fd.get("mensaje"),
        fecha: firebase.firestore.FieldValue.serverTimestamp(),
        leido: false
      }).then(function() {
        e.target.innerHTML = '<p style="color:green;font-weight:bold">✅ Mensaje enviado correctamente.</p>';
      }).catch(function(err) {
        alert("Error: " + err.message);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // FORMULARIO DE RESERVAS — se inyecta en #fluixcrm_reservas
  // ═══════════════════════════════════════════════════════════════════
  function cargarFormularioReservas(db) {
    var el = document.getElementById("fluixcrm_reservas");
    if (!el) return;
    el.innerHTML = '<div style="max-width:480px;border:1px solid #eee;padding:24px;border-radius:12px">'
      + '<h3>📅 Reservar Mesa / Cita</h3>'
      + '<form id="fluixcrm_form_reservas" style="display:flex;flex-direction:column;gap:14px">'
      + '<input name="nombre" placeholder="Tu nombre *" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="telefono" type="tel" placeholder="Tu teléfono *" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="email" type="email" placeholder="Tu email (para confirmación)" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<div style="display:flex;gap:10px">'
      + '<input name="fecha" type="date" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1">'
      + '<input name="hora" type="time" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1">'
      + '</div>'
      + '<input name="personas" type="number" min="1" placeholder="Nº Personas" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="servicio" placeholder="Tipo de servicio / cita (opcional)" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<button type="submit" style="background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:16px">Solicitar Reserva</button>'
      + '</form></div>';

    document.getElementById("fluixcrm_form_reservas").addEventListener("submit", function(e) {
      e.preventDefault();
      var fd = new FormData(e.target);
      var fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";
      var fecha = new Date(fechaStr);
      db.collection("empresas").doc(EMPRESA_ID).collection("reservas").add({
        nombre_cliente:   fd.get("nombre"),
        telefono_cliente: fd.get("telefono"),
        email_cliente:    fd.get("email") || null,
        servicio:         fd.get("servicio") || null,
        personas:         fd.get("personas") ? parseInt(fd.get("personas")) : 1,
        fecha:            firebase.firestore.Timestamp.fromDate(fecha),
        fecha_hora:       fecha.toISOString(),
        estado:           "PENDIENTE",
        origen:           "web",
        fecha_creacion:   firebase.firestore.FieldValue.serverTimestamp()
      }).then(function() {
        e.target.innerHTML = '<div style="text-align:center;padding:20px"><h3 style="color:green">✅ ¡Solicitud enviada!</h3><p>Te confirmaremos pronto.</p></div>';
      }).catch(function(err) {
        alert("Error: " + err.message);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // BLOG / NOTICIAS — se inyecta en #fluixcrm_blog
  // ═══════════════════════════════════════════════════════════════════
  function cargarBlog(db) {
    var el = document.getElementById("fluixcrm_blog");
    if (!el) return;
    db.collection("empresas").doc(EMPRESA_ID)
      .collection("blog")
      .where("publicada", "==", true)
      .orderBy("fecha_publicacion", "desc")
      .limit(6)
      .onSnapshot(function(snap) {
        if (snap.empty) {
          el.innerHTML = "<p>Sin noticias por el momento.</p>";
          return;
        }
        el.innerHTML = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px">'
          + snap.docs.map(function(d) {
              var b = d.data();
              var fechaPub = b.fecha_publicacion && b.fecha_publicacion.toDate
                ? b.fecha_publicacion.toDate().toLocaleDateString("es-ES")
                : "";
              return '<article style="border:1px solid #eee;border-radius:10px;overflow:hidden">'
                + (b.imagen_url ? '<img src="' + b.imagen_url + '" style="width:100%;height:160px;object-fit:cover">' : '<div style="height:6px;background:#1976D2"></div>')
                + '<div style="padding:14px"><h4 style="margin:0 0 8px">' + b.titulo + '</h4>'
                + '<p style="color:#666;font-size:13px;margin:0 0 10px">' + (b.resumen || '') + '</p>'
                + '<small style="color:#999">' + fechaPub + '</small></div></article>';
            }).join("")
          + '</div>';
      });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICS — registrar visitas
  // ═══════════════════════════════════════════════════════════════════
  async function registrarVisita(db) {
    var fechaHoy = new Date().toISOString().substring(0, 10);
    var paginaActual = window.location.pathname || '/';
    var hora = new Date().getHours();
    var referrer = document.referrer || 'Directo';

    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc('web_resumen')
      .set({
        visitas_totales: firebase.firestore.FieldValue.increment(1),
        visitas_mes: firebase.firestore.FieldValue.increment(1),
        ultima_visita: firebase.firestore.FieldValue.serverTimestamp(),
        sitio_web: DOMINIO_WEB,
        nombre_empresa: NOMBRE_EMPRESA,
        pagina_actual: paginaActual,
        referrer_actual: referrer
      }, { merge: true });

    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc(\`visitas_\${fechaHoy}\`)
      .set({
        fecha: fechaHoy,
        sitio: DOMINIO_WEB,
        visitas: firebase.firestore.FieldValue.increment(1),
        paginas_vistas: firebase.firestore.FieldValue.arrayUnion(paginaActual),
        referrers: firebase.firestore.FieldValue.arrayUnion(referrer),
        [\`visitas_hora_\${hora}\`]: firebase.firestore.FieldValue.increment(1),
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    console.log('✅ Visita registrada para ' + NOMBRE_EMPRESA + ' en ' + fechaHoy);
  }

  // ═══════════════════════════════════════════════════════════════════
  // RASTREAR EVENTOS (llamadas, formularios, WhatsApp)
  // ═══════════════════════════════════════════════════════════════════
  async function rastrearEventos(db) {
    var telefonos = document.querySelectorAll('a[href^="tel:"], .telefono, .phone');
    telefonos.forEach(function(tel) {
      tel.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "llamada_telefonica",
            sitio: DOMINIO_WEB,
            numero: tel.textContent || tel.href,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📞 Llamada registrada');
      });
    });

    var formularios = document.querySelectorAll('form[id*="contact"], form[class*="contact"], .contact-form');
    formularios.forEach(function(form) {
      form.addEventListener('submit', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "formulario_contacto",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📧 Formulario registrado');
      });
    });

    var whatsapps = document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"], .whatsapp-btn');
    whatsapps.forEach(function(btn) {
      btn.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "whatsapp_click",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('💬 WhatsApp click registrado');
      });
    });
  }

})();
</script>

<!--
🎯 INSTRUCCIONES DE INSTALACIÓN:

1. 📋 COPIA este código completo
2. 📝 En tu HTML, añade los DIVs donde quieras que aparezca el contenido:
   - <div id="fluixcrm_SECCION_ID"></div>  → para cada sección (el ID lo ves en la app)
   - <div id="fluixcrm_contacto"></div>    → formulario de contacto
   - <div id="fluixcrm_reservas"></div>    → formulario de reservas
   - <div id="fluixcrm_blog"></div>        → blog / noticias
3. 📝 PEGA el bloque <script> antes del </body>
4. ✅ GUARDA los cambios
5. 🔄 Todo se actualiza en TIEMPO REAL desde la app

📊 QUE HARÁ ESTE SCRIPT:
✓ Muestra la carta/menú editada desde la app
✓ Muestra horarios, ofertas, galerías, textos
✓ Muestra el blog/noticias
✓ Formulario de contacto → llega a la app
✓ Formulario de reservas → llega a la app
✓ Registra visitas y estadísticas web
✓ Rastrea llamadas, formularios y WhatsApp clicks
✓ Sincroniza todo en tiempo real con Fluix CRM

🌐 VERÁS LOS DATOS EN:
✅ Dashboard principal
✅ Módulo Contenido Web (secciones)
✅ Módulo Reservas (reservas web)
✅ Módulo Estadísticas (tráfico web)
-->`;
}

// ⛔ obtenerScriptJSON ELIMINADA — mismo motivo que generarScriptEmpresa

/**
 * 10. INICIALIZAR EMPRESA (v2 onCall)
 */
export const inicializarEmpresa = onCall(
  { region: REGION },
  async (request) => {
    try {
      // ── AUTH GUARD ──
      verificarAuth(request);

      const { empresaId, nombre, dominio, telefono, direccion } = request.data;

      if (!empresaId) {
        throw new HttpsError("invalid-argument", "empresaId es requerido");
      }

      const empresaRef = db.collection("empresas").doc(empresaId);

      const empresaData = {
        nombre: nombre || "Mi Negocio",
        dominio: dominio || "midominio.com",
        sitio_web: dominio || "midominio.com",
        telefono: telefono || "",
        direccion: direccion || "",
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      };

      await empresaRef.set(empresaData, { merge: true });

      await empresaRef.collection("estadisticas").doc("web_resumen").set({
        visitas_totales: 0,
        visitas_mes: 0,
        ultima_visita: null,
        sitio_web: dominio || "midominio.com",
        nombre_empresa: nombre || "Mi Negocio",
      });

      await empresaRef.collection("configuracion").doc("general").set({
        fecha_instalacion_script: null,
        script_activo: false,
        dominio: dominio || "midominio.com",
      });

      console.log(`✅ Empresa ${empresaId} inicializada correctamente`);

      return {
        exito: true,
        mensaje: `Empresa "${nombre}" creada exitosamente`,
        empresaId,
      };
    } catch (error) {
      console.error("❌ Error inicializando empresa:", error);
      throw new HttpsError(
        "internal",
        `Error: ${error instanceof Error ? error.message : "Desconocido"}`
      );
    }
  }
);

/**
 * 11. CREAR EMPRESA HTTP — ⛔ DESHABILITADA POR SEGURIDAD
 * Esta función HTTP no tiene autenticación. Usar inicializarEmpresa (callable) en su lugar.
 */
export const crearEmpresaHTTP = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    res.status(410).json({
      error: "Esta función ha sido deshabilitada por seguridad. Usa inicializarEmpresa (callable).",
    });
  }
);

// ── STRIPE WEBHOOK (v2 onRequest) ─────────────────────────────────────────────

export const stripeWebhook = onRequest(
  { region: REGION },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const liveKey: string  = stripeSecretKey.value()         || "";
    const testKey: string  = stripeSecretKeyTest.value()     || "";
    const liveSec: string  = stripeWebhookSecret.value()     || "";
    const testSec: string  = stripeWebhookSecretTest.value() || "";

    if (!liveKey && !testKey) {
      console.error("❌ STRIPE_SECRET_KEY no configurada");
      res.status(500).json({ error: "Stripe no configurado en el servidor" });
      return;
    }

    const sig     = req.headers["stripe-signature"] as string;
    const rawBody = (req as unknown as { rawBody: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));

    if (!sig) {
      res.status(400).json({ error: "Firma de Stripe ausente" });
      return;
    }

    // Intentar verificar con LIVE secret primero, luego con TEST secret
    let event!: Stripe.Event;
    let isTestEvent = false;
    const stripeVerifier = new Stripe(liveKey || testKey, { apiVersion: "2024-06-20" });
    let verified = false;
    if (liveSec) {
      try {
        event = stripeVerifier.webhooks.constructEvent(rawBody, sig, liveSec);
        verified = true;
      } catch (_) { /* probar con TEST */ }
    }
    if (!verified && testSec) {
      try {
        event = stripeVerifier.webhooks.constructEvent(rawBody, sig, testSec);
        verified = true;
        isTestEvent = true;
      } catch (_) { /* ninguno funcionó */ }
    }
    if (!verified) {
      console.error("❌ Firma Stripe inválida — comprueba STRIPE_WEBHOOK_SECRET y STRIPE_WEBHOOK_SECRET_TEST");
      res.status(400).json({ error: "Firma inválida" });
      return;
    }

    console.log(`📥 Stripe evento: ${event.type} [${event.id}] modo=${isTestEvent ? "TEST" : "LIVE"}`);

    // ── IDEMPOTENCIA: evitar procesar el mismo evento dos veces ──────────────
    // Stripe puede reenviar eventos ante timeouts o fallos de red.
    const eventDocRef = db.collection("stripe_processed_events").doc(event.id);
    const eventDoc = await eventDocRef.get();
    if (eventDoc.exists) {
      console.log(`⏭️ Evento Stripe ${event.id} ya procesado. Ignorando duplicado.`);
      res.status(200).json({ received: true, skipped: true, reason: "already_processed" });
      return;
    }
    // Marcar como procesado ANTES de ejecutar la lógica (evita race conditions)
    await eventDocRef.set({
      event_id: event.id,
      event_type: event.type,
      processed_at: new Date().toISOString(),
    });

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object as Stripe.Checkout.Session;
          if (session.metadata?.tipo === "pedido_nazari") {
            await _procesarPedidoNazari(session, db);
          } else {
            await _procesarCheckoutCompletado(session, db);
          }
          break;
        }
        case "payment_intent.succeeded": {
          const pi = event.data.object as Stripe.PaymentIntent;
          if (pi.metadata?.empresa_id) {
            await _procesarPaymentIntentExitoso(pi, db);
          }
          break;
        }
        case "invoice.paid": {
          // Renovación de suscripción pagada — marcar empresa como activa
          const invoice = event.data.object as Stripe.Invoice;
          await _procesarInvoicePagado(invoice, db);
          break;
        }
        case "customer.subscription.deleted": {
          // Suscripción cancelada o impagada — desactivar empresa
          const subscription = event.data.object as Stripe.Subscription;
          await _procesarSuscripcionCancelada(subscription, db);
          break;
        }
        case "customer.subscription.updated": {
          // Cambio de plan, renovación, etc.
          const subscription = event.data.object as Stripe.Subscription;
          await _procesarSuscripcionActualizada(subscription, db);
          break;
        }
        default:
          console.log(`ℹ️ Evento Stripe ignorado: ${event.type}`);
      }

      res.status(200).json({ received: true, tipo: event.type });
    } catch (error) {
      console.error(`❌ Error procesando evento Stripe ${event.type}:`, error);
      res.status(500).json({ error: "Error interno procesando evento" });
    }
  }
);

// ── ENVÍO DE EMAIL CON PDF ADJUNTO (v2 onCall) ───────────────────────────────

/**
 * 12. ENVIAR EMAIL — Envía factura/nómina en PDF por email
 *
 * CONFIGURACIÓN REQUERIDA:
 *   RESEND_API_KEY en functions/.env
 *   Dominio verificado en https://resend.com/domains
 */
export const enviarEmailConPdf = onCall(
  { region: REGION },
  async (request) => {
    const { destinatario, asunto, cuerpoHtml, pdfBase64, nombreArchivo, empresaId } = request.data;

    if (empresaId) {
      await verificarAuthYEmpresa(request, empresaId);
    } else {
      verificarAuth(request);
    }

    if (!destinatario || !asunto || !pdfBase64) {
      throw new HttpsError("invalid-argument", "destinatario, asunto y pdfBase64 son requeridos");
    }

    // Obtener nombre de empresa para el remitente
    let nombreEmpresa = "Fluix CRM";
    if (empresaId) {
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      if (empresaDoc.exists) {
        nombreEmpresa = empresaDoc.data()?.nombre || "Fluix CRM";
      }
    }

    const resultado = await enviarPdfGenerico({
      from: `${nombreEmpresa} <noreply@fluixtech.com>`,
      to: destinatario,
      subject: asunto,
      html: cuerpoHtml || `<p style="font-family:Arial,sans-serif;">Adjuntamos el documento solicitado.</p><p>— ${nombreEmpresa}</p>`,
      pdf: Buffer.from(pdfBase64, "base64"),
      nombreArchivo: nombreArchivo || "documento.pdf",
    });

    if (!resultado.exito) {
      throw new HttpsError("internal", `Error enviando email: ${resultado.error}`);
    }

    console.log(`✅ Email enviado a ${destinatario} — ${asunto}`);
    return { exito: true, mensaje: `Email enviado a ${destinatario}` };
  }
);

// ── FUNCIONES HELPER STRIPE ───────────────────────────────────────────────────

// ── Pedido de libro Editorial Nazarí (via Payment Link o Checkout) ────────────
async function _procesarPedidoNazari(
  session: Stripe.Checkout.Session,
  db: admin.firestore.Firestore
): Promise<void> {
  const modoLabel   = session.livemode ? "LIVE" : "TEST";
  const libroId     = session.metadata?.libro_id    || "";
  const totalEuros  = (session.amount_total ?? 0) / 100;

  // Envío: shipping_cost viene incluido en amount_total
  const gastosEnvioEuros    = (session.shipping_cost?.amount_total ?? 0) / 100;
  const totalProductosEuros = parseFloat((totalEuros - gastosEnvioEuros).toFixed(2));

  // Zona y opción de envío derivadas del país del destinatario y el importe
  const paisDestinatario = session.shipping_details?.address?.country ?? "ES";
  const zonaEnvio        = _zonaDesde(paisDestinatario);
  let opcionEnvio: string;
  if (zonaEnvio !== "es") {
    opcionEnvio = zonaEnvio;                    // "europa" | "latam" | "mundo"
  } else if (gastosEnvioEuros === 0) {
    opcionEnvio = "gratuito";
  } else if (gastosEnvioEuros >= 6) {
    opcionEnvio = "urgente";
  } else {
    opcionEnvio = "ordinario";
  }

  const clienteNombre   = session.customer_details?.name  || "Cliente web";
  const clienteEmail    = session.customer_details?.email || null;
  const clienteTelefono = session.customer_details?.phone || null;
  const direccionEnvio  = _formatearDireccion(session.shipping_details);

  // ── Line items desde Stripe (expande nombre real, cantidad, precio) ──────────
  const stripeKey = session.livemode ? stripeSecretKey.value() : stripeSecretKeyTest.value();
  const stripeInst = new Stripe(stripeKey, { apiVersion: "2024-06-20" });

  type LineaNazari = { libro_id: string; producto_nombre: string; descripcion: string; cantidad: number; precio_unitario: number; porcentaje_iva: number; };
  let lineas: LineaNazari[] = [];
  try {
    const items = await stripeInst.checkout.sessions.listLineItems(session.id, { limit: 100, expand: ["data.price.product"] });
    lineas = items.data.map(item => {
      const prod    = item.price?.product as Stripe.Product | undefined;
      const catId   = (prod as any)?.metadata?.catalogo_id || libroId;
      const titulo  = prod?.name || item.description || session.metadata?.libro_titulo || "Libro";
      const precioUnitario = ((item.price?.unit_amount ?? 0) / 100) / 1.04;
      return {
        libro_id:        catId,
        producto_nombre: titulo,
        descripcion:     `${titulo} — venta online Editorial Nazarí`,
        cantidad:        item.quantity ?? 1,
        precio_unitario: parseFloat(precioUnitario.toFixed(2)),
        porcentaje_iva:  4, // IVA superreducido libros España
      };
    });
  } catch (_) {
    // Fallback: usar metadata del payment link
    const titulo = session.metadata?.libro_titulo || "Libro";
    lineas = [{
      libro_id:        libroId,
      producto_nombre: titulo,
      descripcion:     `${titulo} — venta online Editorial Nazarí`,
      cantidad:        1,
      precio_unitario: parseFloat((totalEuros / 1.04).toFixed(2)),
      porcentaje_iva:  4,
    }];
  }

  const baseImponible = parseFloat(lineas.reduce((s, l) => s + l.precio_unitario * l.cantidad, 0).toFixed(2));
  // importeIva solo sobre los libros (IVA 4% superreducido); no incluye el envío
  const importeIva    = parseFloat((totalProductosEuros - baseImponible).toFixed(2));

  // ── Número de ticket correlativo ──────────────────────────────────────────
  const contadorRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("contadores").doc("tickets");
  let numTicket = 1;
  const contSnap = await contadorRef.get();
  numTicket = contSnap.exists ? ((contSnap.data()?.ultimo as number) ?? 0) + 1 : 1;
  await contadorRef.set({ ultimo: numTicket }, { merge: true });

  // ── Crear pedido ──────────────────────────────────────────────────────────
  const pedidoData = {
    empresa_id:            NAZARI_EMPRESA_ID,
    numero_ticket:         numTicket,
    cliente_nombre:        clienteNombre,
    cliente_correo:        clienteEmail,
    cliente_telefono:      clienteTelefono,
    direccion_envio:       direccionEnvio,
    origen:                "web_nazari",
    estado:                "pendiente",
    estado_pago:           "pagado",
    metodo_pago:           "tarjeta",
    lineas,
    subtotal:              baseImponible,
    importe_iva:           importeIva,
    total_productos:       totalProductosEuros,
    gastos_envio:          gastosEnvioEuros,
    opcion_envio:          opcionEnvio,
    zona_envio:            zonaEnvio,
    pais_destino:          paisDestinatario,
    es_preventa:           session.metadata?.es_preventa === "true",
    total:                 totalEuros,
    stripe_session_id:     session.id,
    stripe_payment_intent: typeof session.payment_intent === "string" ? session.payment_intent : null,
    livemode:              session.livemode,
    notas_internas:        `Compra online via Stripe ${modoLabel}. Session: ${session.id}`,
    fecha_creacion:        admin.firestore.FieldValue.serverTimestamp(),
    fecha_pedido:          admin.firestore.FieldValue.serverTimestamp(),
    fecha_actualizacion:   admin.firestore.FieldValue.serverTimestamp(),
  };

  const pedidoRef = await db
    .collection("empresas").doc(NAZARI_EMPRESA_ID)
    .collection("pedidos").add(pedidoData);

  console.log(`✅ [NAZARI-${modoLabel}] Pedido #${numTicket} (${pedidoRef.id}) — ${clienteNombre} — €${totalEuros}`);

  // ── Notificación en bandeja + push FCM ────────────────────────────────────
  const cuerpoNotif = `${clienteNombre} — €${totalEuros.toFixed(2)} (web Editorial Nazarí)`;
  try {
    await db.collection("notificaciones").doc(NAZARI_EMPRESA_ID).collection("items").add({
      titulo:             "📦 Nuevo Pedido Web",
      cuerpo:             cuerpoNotif,
      tipo:               "pedidoNuevo",
      timestamp:          admin.firestore.FieldValue.serverTimestamp(),
      leida:              false,
      modulo_destino:     "pedidos",
      entidad_id:         pedidoRef.id,
      remitente_nombre:   clienteNombre !== "Cliente online" ? clienteNombre : null,
      remitente_email:    clienteEmail,
    });
    await enviarNotificacionEmpresa(
      NAZARI_EMPRESA_ID,
      "📦 Nuevo Pedido Web",
      cuerpoNotif,
      { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "web_nazari" }
    );
  } catch (e) {
    console.warn(`⚠️ [NAZARI-${modoLabel}] Error enviando notificación:`, e);
  }

  // ── Descontar stock en colección libros ───────────────────────────────────
  for (const linea of lineas) {
    if (!linea.libro_id) continue;
    try {
      await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("libros").doc(linea.libro_id)
        .update({ stock: admin.firestore.FieldValue.increment(-linea.cantidad) });
      console.log(`📦 [NAZARI-${modoLabel}] Stock decrementado: ${linea.producto_nombre} -${linea.cantidad}`);
    } catch (_) { /* libro sin campo stock — ignorar */ }
  }

  // ── Email de confirmación al cliente ──────────────────────────────────────
  if (clienteEmail) {
    try {
      const lineasHtml = lineas.map(l =>
        `<tr><td style="padding:6px 0;">${l.producto_nombre}</td><td style="text-align:right;padding:6px 0;">${l.cantidad}x ${l.precio_unitario.toFixed(2)} €</td></tr>`
      ).join("");
      await enviarPdfGenerico({
        from: "Editorial Nazarí <noreply@fluixtech.com>",
        to: clienteEmail,
        subject: `✅ Pedido #${numTicket} confirmado — Editorial Nazarí`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
            <h2 style="color:#1B5E20;">¡Pedido recibido!</h2>
            <p>Hola ${clienteNombre}, hemos recibido tu pedido correctamente.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0;">${lineasHtml}</table>
            <p style="font-size:18px;font-weight:bold;text-align:right;">Total: ${totalEuros.toFixed(2)} €</p>
            <p style="color:#555;">IVA incluido (4% libros). Te enviaremos el libro a la dirección indicada.</p>
            <p style="color:#999;font-size:11px;">— Editorial Nazarí · noreply@fluixtech.com</p>
          </div>`,
      });
      console.log(`📧 [NAZARI-${modoLabel}] Email enviado a ${clienteEmail}`);
    } catch (e) {
      console.warn(`⚠️ [NAZARI-${modoLabel}] No se pudo enviar email:`, e);
    }
  }
}

async function _procesarCheckoutCompletado(
  session: Stripe.Checkout.Session,
  db: admin.firestore.Firestore
): Promise<void> {
  const empresaClienteId: string = session.metadata?.empresa_id || "";
  const paquete: string = session.metadata?.paquete || "Paquete Fluix";
  const FLUIXTECH_ID = "fluixtech";

  const clienteNombre = session.customer_details?.name || "Cliente Web";
  const clienteEmail  = session.customer_details?.email || null;
  const clienteTelefono = session.customer_details?.phone || null;

  const totalEuros   = (session.amount_total ?? 0) / 100;
  const baseImponible = parseFloat((totalEuros / 1.21).toFixed(2));
  const importeIva    = parseFloat((totalEuros - baseImponible).toFixed(2));

  const lineasIngreso = [
    {
      producto_nombre: paquete,
      descripcion: `${paquete} — Pago online vía Stripe`,
      cantidad: 1,
      precio_unitario: baseImponible,
      porcentaje_iva: 21,
      referencia: session.id,
    },
  ];

  const pedidoFluixtech = {
    empresa_id: FLUIXTECH_ID,
    cliente_nombre: clienteNombre,
    cliente_correo: clienteEmail,
    cliente_telefono: clienteTelefono,
    empresa_cliente_id: empresaClienteId || null,
    origen: "web",
    estado: "confirmado",
    estado_pago: "pagado",
    metodo_pago: "tarjeta",
    lineas: lineasIngreso,
    subtotal: baseImponible,
    total: totalEuros,
    notas_cliente: `Venta de "${paquete}" a ${clienteNombre}. Stripe Session: ${session.id}`,
    stripe_session_id: session.id,
    stripe_payment_intent: session.payment_intent,
    fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };

  const pedidoRef = await db
    .collection("empresas")
    .doc(FLUIXTECH_ID)
    .collection("pedidos")
    .add(pedidoFluixtech);

  console.log(
    `✅ [INGRESO] Pedido ${pedidoRef.id} creado en fluixtech — ${clienteNombre} — €${totalEuros}`
  );
  console.log(`   ➡️  Factura de ingreso se generará automáticamente via onNuevoPedidoGenerarFactura`);

  if (empresaClienteId && empresaClienteId !== FLUIXTECH_ID) {
    const configRef = db
      .collection("empresas")
      .doc(FLUIXTECH_ID)
      .collection("configuracion")
      .doc("facturacion");

    let numeroFactura = "";
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(configRef);
      // NOTA: onNuevoPedidoGenerarFactura incrementará este contador más tarde.
      // Aquí solo leemos el valor ACTUAL + 1 para que el numero_factura_proveedor
      // coincida con la factura que se generará automáticamente.
      const contador = ((snap.data()?.ultimo_numero_factura as number) ?? 0) + 1;
      const anio = new Date().getFullYear();
      numeroFactura = `FAC-${anio}-${String(contador).padStart(4, "0")}`;
    });

    const gastoData = {
      empresa_id: empresaClienteId,
      concepto: `Suscripción Fluix CRM — ${paquete}`,
      categoria: "software",
      proveedor_nombre: "FluxTech",
      proveedor_id: null,
      numero_factura_proveedor: numeroFactura || `STRIPE-${session.id.substring(3, 11).toUpperCase()}`,
      stripe_session_id: session.id,
      base_imponible: baseImponible,
      porcentaje_iva: 21,
      importe_iva: importeIva,
      total: totalEuros,
      iva_deducible: true,
      estado: "pagado",
      fecha_gasto: admin.firestore.FieldValue.serverTimestamp(),
      fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
      metodo_pago: "tarjeta",
      notas: `Pago automático vía Stripe. Paquete: "${paquete}". Proveedor: FluxTech (fluixtech.com)`,
      creado_por: "sistema_stripe",
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    };

    const gastoRef = await db
      .collection("empresas")
      .doc(empresaClienteId)
      .collection("gastos")
      .add(gastoData);

    const ahora = new Date();
    const cacheId = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;
    await db
      .collection("empresas")
      .doc(empresaClienteId)
      .collection("cache_contable")
      .doc(cacheId)
      .set({
        gastos_base: admin.firestore.FieldValue.increment(baseImponible),
        gastos_iva_soportado: admin.firestore.FieldValue.increment(importeIva),
        gastos_total: admin.firestore.FieldValue.increment(totalEuros),
        num_gastos: admin.firestore.FieldValue.increment(1),
        ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log(
      `✅ [GASTO] Gasto ${gastoRef.id} creado en empresa "${empresaClienteId}" — €${totalEuros} — "${paquete}"`
    );
  } else if (!empresaClienteId) {
    console.log(`ℹ️  Sin empresa_id en metadata de Stripe → no se crea gasto en empresa cliente`);
  }
}

async function _procesarPaymentIntentExitoso(
  pi: Stripe.PaymentIntent,
  db: admin.firestore.Firestore
): Promise<void> {
  const empresaClienteId: string = pi.metadata?.empresa_id || "";
  const paquete: string = pi.metadata?.paquete || "Pago directo Stripe";
  const FLUIXTECH_ID = "fluixtech";

  const totalEuros    = pi.amount / 100;
  const baseImponible = parseFloat((totalEuros / 1.21).toFixed(2));
  const importeIva    = parseFloat((totalEuros - baseImponible).toFixed(2));

  const pedidoData = {
    empresa_id: FLUIXTECH_ID,
    cliente_nombre: pi.metadata?.cliente_nombre || "Cliente",
    cliente_correo: pi.receipt_email || null,
    empresa_cliente_id: empresaClienteId || null,
    origen: "web",
    estado: "confirmado",
    estado_pago: "pagado",
    metodo_pago: "tarjeta",
    lineas: [
      {
        producto_nombre: paquete,
        cantidad: 1,
        precio_unitario: baseImponible,
        porcentaje_iva: 21,
        referencia: pi.id,
      },
    ],
    subtotal: baseImponible,
    total: totalEuros,
    notas_cliente: `Pago directo Stripe. PaymentIntent: ${pi.id}`,
    stripe_payment_intent: pi.id,
    fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };

  const pedidoRef = await db
    .collection("empresas")
    .doc(FLUIXTECH_ID)
    .collection("pedidos")
    .add(pedidoData);

  console.log(`✅ [INGRESO] Pedido ${pedidoRef.id} creado en fluixtech via PaymentIntent — €${totalEuros}`);

  if (empresaClienteId && empresaClienteId !== FLUIXTECH_ID) {
    const gastoData = {
      empresa_id: empresaClienteId,
      concepto: `Suscripción Fluix CRM — ${paquete}`,
      categoria: "software",
      proveedor_nombre: "FluxTech",
      proveedor_id: null,
      numero_factura_proveedor: `STRIPE-${pi.id.substring(3, 11).toUpperCase()}`,
      stripe_payment_intent: pi.id,
      base_imponible: baseImponible,
      porcentaje_iva: 21,
      importe_iva: importeIva,
      total: totalEuros,
      iva_deducible: true,
      estado: "pagado",
      fecha_gasto: admin.firestore.FieldValue.serverTimestamp(),
      fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
      metodo_pago: "tarjeta",
      notas: `Pago automático vía Stripe. Paquete: "${paquete}". PaymentIntent: ${pi.id}`,
      creado_por: "sistema_stripe",
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    };

    const gastoRef = await db
      .collection("empresas")
      .doc(empresaClienteId)
      .collection("gastos")
      .add(gastoData);

    const ahora = new Date();
    const cacheId = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;
    await db
      .collection("empresas")
      .doc(empresaClienteId)
      .collection("cache_contable")
      .doc(cacheId)
      .set({
        gastos_base: admin.firestore.FieldValue.increment(baseImponible),
        gastos_iva_soportado: admin.firestore.FieldValue.increment(importeIva),
        gastos_total: admin.firestore.FieldValue.increment(totalEuros),
        num_gastos: admin.firestore.FieldValue.increment(1),
        ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log(`✅ [GASTO] Gasto ${gastoRef.id} creado en empresa "${empresaClienteId}" — €${totalEuros}`);
  }
}

// ── HELPERS STRIPE: SUSCRIPCIONES ────────────────────────────────────────────

/**
 * invoice.paid — Se dispara en cada renovación de suscripción pagada con éxito.
 * Actualiza la empresa en Firestore como activa y registra la fecha de próximo vencimiento.
 */
async function _procesarInvoicePagado(
  invoice: Stripe.Invoice,
  db: admin.firestore.Firestore
): Promise<void> {
  const customerId = invoice.customer as string;
  if (!customerId) return;

  // Buscar empresa por stripe_customer_id
  const snap = await db
    .collectionGroup("empresas")
    .where("stripe_customer_id", "==", customerId)
    .limit(1)
    .get();

  // Si no está en collectionGroup, buscar en raíz
  const rootSnap = snap.empty
    ? await db.collection("empresas").where("stripe_customer_id", "==", customerId).limit(1).get()
    : snap;

  if (rootSnap.empty) {
    console.warn(`⚠️ invoice.paid: No se encontró empresa con stripe_customer_id=${customerId}`);
    return;
  }

  const empresaRef = rootSnap.docs[0].ref;
  const empresaId = rootSnap.docs[0].id;

  const periodEnd = invoice.lines?.data?.[0]?.period?.end;
  const proximoVencimiento = periodEnd
    ? admin.firestore.Timestamp.fromDate(new Date(periodEnd * 1000))
    : null;

  await empresaRef.update({
    suscripcion_activa: true,
    suscripcion_estado: "active",
    suscripcion_proximo_pago: proximoVencimiento,
    suscripcion_ultima_factura_stripe: invoice.id,
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ [SUSCRIPCIÓN] invoice.paid — empresa ${empresaId} renovada hasta ${proximoVencimiento?.toDate()?.toISOString() ?? "—"}`);
}

/**
 * customer.subscription.deleted — Suscripción cancelada por impago o por el usuario.
 * Marca la empresa como inactiva en Firestore.
 */
async function _procesarSuscripcionCancelada(
  subscription: Stripe.Subscription,
  db: admin.firestore.Firestore
): Promise<void> {
  const customerId = subscription.customer as string;
  if (!customerId) return;

  const snap = await db
    .collection("empresas")
    .where("stripe_customer_id", "==", customerId)
    .limit(1)
    .get();

  if (snap.empty) {
    console.warn(`⚠️ subscription.deleted: No se encontró empresa con stripe_customer_id=${customerId}`);
    return;
  }

  const empresaRef = snap.docs[0].ref;
  const empresaId = snap.docs[0].id;

  await empresaRef.update({
    suscripcion_activa: false,
    suscripcion_estado: "canceled",
    suscripcion_cancelada_en: admin.firestore.FieldValue.serverTimestamp(),
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`🔴 [SUSCRIPCIÓN] subscription.deleted — empresa ${empresaId} DESACTIVADA`);
}

/**
 * customer.subscription.updated — Cambio de plan, pausa, renovación automática.
 * Sincroniza el estado de la suscripción con Firestore.
 */
async function _procesarSuscripcionActualizada(
  subscription: Stripe.Subscription,
  db: admin.firestore.Firestore
): Promise<void> {
  const customerId = subscription.customer as string;
  if (!customerId) return;

  const snap = await db
    .collection("empresas")
    .where("stripe_customer_id", "==", customerId)
    .limit(1)
    .get();

  if (snap.empty) return;

  const empresaRef = snap.docs[0].ref;
  const empresaId = snap.docs[0].id;
  const estado = subscription.status; // "active" | "past_due" | "canceled" | "trialing" | etc.

  await empresaRef.update({
    suscripcion_activa: estado === "active" || estado === "trialing",
    suscripcion_estado: estado,
    suscripcion_proximo_pago: subscription.current_period_end
      ? admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000))
      : null,
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`🔄 [SUSCRIPCIÓN] subscription.updated — empresa ${empresaId} estado=${estado}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRAR VISITA WEB — endpoint HTTP llamado desde el script embebido
// ═══════════════════════════════════════════════════════════════════════════════
export const registrarVisita = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "Método no permitido" });
        return;
      }

      const { empresaId, dominio, pagina, referrer } = req.body;

      if (!empresaId || typeof empresaId !== "string") {
        res.status(400).json({ error: "empresaId es requerido" });
        return;
      }

      const ahora = new Date();
      const fechaHoy = ahora.toISOString().substring(0, 10);
      const hora = ahora.getHours();
      const paginaActual = pagina || "/";
      const referrerActual = referrer || "directo";
      const dominioActual = dominio || "desconocido";

      // 1. Actualizar resumen general
      await db
        .collection('empresas').doc(empresaId)
        .collection('estadisticas').doc('web_resumen')
        .set({
          visitas_totales: admin.firestore.FieldValue.increment(1),
          visitas_mes: admin.firestore.FieldValue.increment(1),
          ultima_visita: admin.firestore.FieldValue.serverTimestamp(),
          sitio_web: dominioActual,
          pagina_actual: paginaActual,
          referrer_actual: referrerActual,
        }, { merge: true });

      // 2. Actualizar estadísticas del día
      await db
        .collection('empresas').doc(empresaId)
        .collection('estadisticas').doc(`visitas_${fechaHoy}`)
        .set({
          fecha: fechaHoy,
          sitio: dominioActual,
          visitas: admin.firestore.FieldValue.increment(1),
          paginas_vistas: admin.firestore.FieldValue.arrayUnion(paginaActual),
          referrers: admin.firestore.FieldValue.arrayUnion(referrerActual),
          [`visitas_hora_${hora}`]: admin.firestore.FieldValue.increment(1),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      console.log(`✅ Visita registrada: ${empresaId} — ${dominioActual} — ${fechaHoy}`);
      res.status(200).json({ ok: true });
    } catch (error: any) {
      console.error("❌ Error registrando visita:", error);
      res.status(500).json({ error: "Error registrando visita" });
    }
  }
);

export { enviarRecordatoriosCitas };

// ── VERIFACTU: Firma XAdES + Remisión AEAT ──────────────────────────────────
export { firmarXMLVerifactu } from "./firmarXMLVerifactu";
export { remitirVerifactu } from "./remitirVerifactu";

// ── BLOG: Publicar posts programados (cada 15 min) ────────────────────────────
export { publicarPostsProgramados } from "./schedulerBlog";
export { getBlogEntry, getBlogLista } from "./blogApi";

// ── GESTIÓN DE CUENTAS Y SUSCRIPCIONES (sin pasar por Apple/Google) ──────────
export {
  crearCuentaConPlan,
  actualizarPlanEmpresa,
  listarCuentasClientes,
  webhookPagoWeb,
} from "./gestionCuentas";

// ── CATÁLOGO PÚBLICO — endpoint para webs de clientes ────────────────────────
//
// La web del cliente (ej: Nazari) puede llamar a:
//   GET https://europe-west1-planeaapp-4bea4.cloudfunctions.net/catalogoPublico?empresa_id=XXX
// para obtener el catálogo en JSON, respetando precio_web si existe.
// Respeta CORS para dominios configurados en Firestore (empresa.sitio_web).
//
export const catalogoPublico = onRequest(
  { region: REGION },
  async (req, res) => {
    const empresaId = req.query.empresa_id as string | undefined;
    if (!empresaId) {
      res.status(400).json({ error: "empresa_id requerido" });
      return;
    }

    // Verificar empresa y dominios permitidos
    try {
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      if (!empresaDoc.exists) {
        res.status(404).json({ error: "Empresa no encontrada" });
        return;
      }
      const sitioWeb = empresaDoc.data()?.sitio_web as string | undefined;
      const origen = req.headers.origin as string | undefined;
      if (sitioWeb && origen) {
        // Permitir solo el dominio configurado + localhost para desarrollo
        const dominioPermitido = sitioWeb.replace(/^https?:\/\//, '').split('/')[0];
        if (!origen.includes(dominioPermitido) && !origen.includes('localhost')) {
          res.setHeader("Access-Control-Allow-Origin", sitioWeb);
        } else {
          res.setHeader("Access-Control-Allow-Origin", origen);
        }
      } else {
        res.setHeader("Access-Control-Allow-Origin", "*");
      }
    } catch (_) {
      res.setHeader("Access-Control-Allow-Origin", "*");
    }

    if (req.method === "OPTIONS") {
      res.setHeader("Access-Control-Allow-Methods", "GET");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return;
    }

    try {
      const snap = await db
        .collection("empresas").doc(empresaId)
        .collection("catalogo")
        .where("activo", "==", true)
        .get();

      const productos = snap.docs.map(d => {
        const data = d.data();
        const precioTienda = data.precio as number ?? 0;
        const precioWeb    = data.precio_web as number | undefined;
        return {
          id:            d.id,
          nombre:        data.nombre ?? "",
          descripcion:   data.descripcion ?? "",
          categoria:     data.categoria ?? "",
          precio:        precioWeb ?? precioTienda,  // precio_web tiene prioridad
          precio_tienda: precioTienda,
          tiene_precio_web: !!precioWeb,
          imagen_url:    data.imagen_url ?? data.thumbnail_url ?? null,
          iva_porcentaje: data.iva_porcentaje ?? 21,
          stock:         data.stock ?? null,
          codigo_barras: data.codigo_barras ?? null,
          destacado:     data.destacado ?? false,
          // catalogo_id incluido para que el checkout de Stripe pueda descuentar stock
          catalogo_id:   d.id,
        };
      });

      res.setHeader("Cache-Control", "public, max-age=60"); // cache 1 min
      res.status(200).json({ productos, total: productos.length });
    } catch (e) {
      console.error("Error obteniendo catálogo público:", e);
      res.status(500).json({ error: "Error interno" });
    }
  }
);

// ── ALERTA DE STOCK BAJO ──────────────────────────────────────────────────────
//
// Se dispara cuando se actualiza el campo `stock` de un producto del catálogo.
// Si el stock nuevo <= stock_minimo, envía email al propietario de la empresa.
// Se ignora si stock_minimo es 0 (sin control de stock configurado).
//
export const alertaStockBajo = onDocumentUpdated(
  "empresas/{empresaId}/catalogo/{productoId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();

    const stockAntes  = (before?.stock  as number | undefined) ?? -1;
    const stockAhora  = (after?.stock   as number | undefined) ?? -1;
    const stockMinimo = (after?.stock_minimo as number | undefined) ?? 0;

    // Solo actuar si el stock bajó y hay stock_minimo configurado
    if (stockAhora < 0 || stockMinimo <= 0) return;
    if (stockAhora >= stockMinimo || stockAhora >= stockAntes) return;
    // Solo enviar la primera vez que cruce el umbral (no en cada venta)
    if (stockAntes <= stockMinimo) return;

    const empresaId  = event.params.empresaId;
    const nombreProd = (after?.nombre as string | undefined) ?? "Producto";
    const categoria  = (after?.categoria as string | undefined) ?? "";

    // Obtener email del propietario
    let emailPropietario: string | null = null;
    let nombreEmpresa = "Tu tienda";
    try {
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      const eData = empresaDoc.data() ?? {};
      nombreEmpresa = eData.nombre ?? nombreEmpresa;
      // Buscar el propietario en la empresa
      const usuariosSnap = await db.collection("usuarios")
        .where("empresa_id", "==", empresaId)
        .where("rol", "in", ["propietario", "admin"])
        .limit(1).get();
      if (!usuariosSnap.empty) {
        emailPropietario = usuariosSnap.docs[0].data().email ?? null;
      }
    } catch (_) {}

    if (!emailPropietario) {
      console.warn(`⚠️ alertaStockBajo: no se encontró email para empresa ${empresaId}`);
      return;
    }

    const alertaHtml = `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;">
        <div style="background:#FFF3E0;border-left:4px solid #FF9800;padding:16px;border-radius:8px;">
          <h2 style="color:#E65100;margin:0 0 8px;">⚠️ Stock bajo: ${nombreProd}</h2>
          <p style="margin:4px 0;color:#333;">
            <strong>Stock actual:</strong> ${stockAhora} unidades (mínimo: ${stockMinimo})
          </p>
          ${categoria ? `<p style="margin:4px 0;color:#666;font-size:13px;">Categoría: ${categoria}</p>` : ""}
        </div>
        <p style="margin:16px 0;color:#555;">
          Es posible que necesites reponer existencias pronto.
          Puedes actualizar el stock desde el TPV de ${nombreEmpresa}.
        </p>
        <p style="color:#999;font-size:11px;">— ${nombreEmpresa} · Alertas automáticas PlaneaG</p>
      </div>
    `;

    try {
      await enviarPdfGenerico({
        from: `${nombreEmpresa} <noreply@fluixtech.com>`,
        to: emailPropietario,
        subject: `⚠️ Stock bajo: ${nombreProd} (${stockAhora} uds.) — ${nombreEmpresa}`,
        html: alertaHtml,
      });
      console.log(`📉 Alerta stock bajo enviada: ${nombreProd} (${stockAhora}) → ${emailPropietario}`);
    } catch (e) {
      console.error("Error enviando alerta de stock:", e);
    }
  }
);

// ── STRIPE WEBHOOK — PEDIDOS DE TIENDA DE CLIENTES ────────────────────────────
//
// Cómo funciona:
//  1. La web del cliente (ej: Editorial Nazari) crea un Stripe Checkout Session
//     incluyendo en metadata: { empresa_id: "ID_EN_PLANEAG", tipo: "pedido_tienda" }
//  2. Stripe llama a este endpoint al completarse el pago
//  3. La función crea el pedido en Firestore y descuenta el stock del catálogo
//
// Configuración (una sola vez por cliente):
//  a) En el dashboard de Stripe del cliente: Developers → Webhooks → Add endpoint
//     URL: https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhookTienda
//     Events: checkout.session.completed
//  b) Copiar el "Signing secret" del webhook y guardarlo en functions/.env como
//     STRIPE_TIENDA_WEBHOOK_SECRET (o reutilizar STRIPE_WEBHOOK_SECRET)
//  c) En la web del cliente añadir empresa_id y tipo a los metadatos del session:
//     metadata: { empresa_id: "XXXXX", tipo: "pedido_tienda" }
//
export const stripeWebhookTienda = onRequest(
  { region: REGION },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const liveKey: string  = stripeSecretKey.value()         || "";
    const testKey: string  = stripeSecretKeyTest.value()     || "";
    const liveSec: string  = stripeTiendaWebhookSecret.value() || "";
    const testSec: string  = stripeWebhookSecretTest.value() || "";

    const sig     = req.headers["stripe-signature"] as string;
    const rawBody = (req as unknown as { rawBody: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));

    if (!sig) { res.status(400).json({ error: "Firma ausente" }); return; }

    let event!: Stripe.Event;
    let isTestEvent = false;
    const verifier = new Stripe(liveKey || testKey, { apiVersion: "2024-06-20" });
    let verified = false;
    if (liveSec) { try { event = verifier.webhooks.constructEvent(rawBody, sig, liveSec); verified = true; } catch (_) {} }
    if (!verified && testSec) { try { event = verifier.webhooks.constructEvent(rawBody, sig, testSec); verified = true; isTestEvent = true; } catch (_) {} }
    if (!verified) {
      console.error("❌ Firma inválida en stripeWebhookTienda");
      res.status(400).json({ error: "Firma inválida" }); return;
    }

    const stripe = new Stripe(isTestEvent ? (testKey || liveKey) : liveKey, { apiVersion: "2024-06-20" });
    console.log(`📥 [stripeWebhookTienda] ${event.type} modo=${isTestEvent ? "TEST" : "LIVE"}`);

    // ── IDEMPOTENCIA ATÓMICA ───────────────────────────────────────────────────
    // Usamos create() (no set/get) para "reclamar" el evento. Firestore garantiza
    // que solo UNA petición concurrente puede crear el documento; las demás reciben
    // ALREADY_EXISTS (código gRPC 6) y terminan sin crear pedido duplicado.
    const eventDocRef = db.collection("stripe_processed_events").doc(`tienda_${event.id}`);
    try {
      await eventDocRef.create({
        event_id:      event.id,
        event_type:    event.type,
        claimed_at:    new Date().toISOString(),
      });
    } catch (claimErr: any) {
      if (claimErr?.code === 6) {
        // ALREADY_EXISTS — otro proceso ya reclamó este evento
        console.log(`⏭️ Evento tienda ${event.id} ya reclamado/procesado`);
        res.status(200).json({ received: true, duplicado: true });
        return;
      }
      // Error inesperado al reclamar — dejar que Stripe reintente
      console.error("❌ Error reclamando evento tienda:", claimErr);
      res.status(500).json({ error: "Error interno" });
      return;
    }

    try {
      if (event.type === "checkout.session.completed") {
        const session = event.data.object as Stripe.Checkout.Session;
        const empresaId: string = session.metadata?.empresa_id || "";
        const tipo: string      = session.metadata?.tipo        || "";

        if (tipo === "pedido_nazari" || empresaId === NAZARI_EMPRESA_ID) {
          await _procesarPedidoNazari(session, db);
        } else if (empresaId && tipo === "pedido_tienda") {
          await _procesarPedidoTienda(session, stripe, empresaId, db);
        } else {
          // Sin metadata → Payment Link de Nazarí sin tipo configurado.
          // Este webhook es exclusivo de Nazarí, por lo que tratamos la sesión como suya.
          console.log(`ℹ️ [stripeWebhookTienda] Sin metadata tipo/empresa — procesando como pedido Nazarí. Session: ${session.id}`);
          await _procesarPedidoNazari(session, db);
        }
      }

      // Marcar como completado (el claim ya existe; update para añadir ts de fin)
      await eventDocRef.update({ procesado: true, ts: admin.firestore.FieldValue.serverTimestamp() });
      res.status(200).json({ received: true, tipo: event.type });
    } catch (error) {
      console.error("❌ Error en stripeWebhookTienda:", error);
      res.status(500).json({ error: "Error interno procesando pedido de tienda" });
    }
  }
);

async function _procesarPedidoTienda(
  session: Stripe.Checkout.Session,
  stripe: Stripe,
  empresaId: string,
  db: admin.firestore.Firestore
): Promise<void> {
  // ── Datos del cliente ──────────────────────────────────────────────────────
  const clienteNombre    = session.customer_details?.name  || "Cliente online";
  const clienteEmail     = session.customer_details?.email || null;
  const clienteTelefono  = session.customer_details?.phone || null;
  const direccionEnvio   = _formatearDireccion(session.shipping_details);

  // ── Importe total ──────────────────────────────────────────────────────────
  const totalEuros = (session.amount_total ?? 0) / 100;

  // ── Line items de Stripe ──────────────────────────────────────────────────
  // Expandimos para obtener la info completa de cada ítem
  let lineas: Array<{ productoId: string; nombre: string; cantidad: number; precioUnitario: number; stripeProductId?: string; }> = [];
  try {
    const lineItems = await stripe.checkout.sessions.listLineItems(session.id, { limit: 100, expand: ["data.price.product"] });
    lineas = lineItems.data.map((item) => {
      const prod = item.price?.product as Stripe.Product | undefined;
      const stripeProductId = prod?.id ?? "";
      // El metadata del producto puede incluir el catalogo_id de PlaneaG
      const catalogoId: string = (prod as Stripe.Product & { metadata?: Record<string, string> })?.metadata?.catalogo_id ?? "";
      return {
        productoId: catalogoId || `stripe_${stripeProductId}`,
        nombre: prod?.name || item.description || "Producto",
        cantidad: item.quantity ?? 1,
        precioUnitario: ((item.price?.unit_amount ?? 0) / 100),
        stripeProductId,
      };
    });
  } catch (e) {
    console.warn("⚠️ No se pudieron obtener line items de Stripe:", e);
    // Fallback: creamos una línea resumen con el total
    lineas = [{
      productoId: `stripe_${session.id}`,
      nombre: "Pedido online",
      cantidad: 1,
      precioUnitario: totalEuros,
    }];
  }

  // ── Calcular número de ticket correlativo ─────────────────────────────────
  const contadorRef = db.collection("empresas").doc(empresaId).collection("contadores").doc("tickets");
  let numTicket = 1;
  const contSnap = await contadorRef.get();
  numTicket = contSnap.exists ? ((contSnap.data()?.ultimo as number) ?? 0) + 1 : 1;
  await contadorRef.set({ ultimo: numTicket }, { merge: true });

  // ── Crear pedido en Firestore ─────────────────────────────────────────────
  const pedidoData = {
    empresa_id: empresaId,
    numero_ticket: numTicket,
    cliente_nombre: clienteNombre,
    cliente_email: clienteEmail,
    cliente_telefono: clienteTelefono,
    direccion_envio: direccionEnvio,
    origen: "tienda_online",
    estado: "pendiente",
    estado_pago: "pagado",
    metodo_pago: "tarjeta",
    lineas: lineas.map((l) => ({
      producto_id: l.productoId,
      producto_nombre: l.nombre,
      cantidad: l.cantidad,
      precio_unitario: l.precioUnitario,
      iva_porcentaje: 21,
    })),
    subtotal: parseFloat((totalEuros / 1.21).toFixed(2)),
    importe_iva: parseFloat((totalEuros - totalEuros / 1.21).toFixed(2)),
    total: totalEuros,
    stripe_session_id: session.id,
    stripe_payment_intent: session.payment_intent as string | null,
    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };

  const pedidoRef = await db
    .collection("empresas")
    .doc(empresaId)
    .collection("pedidos")
    .add(pedidoData);

  console.log(`✅ [TIENDA] Pedido #${numTicket} creado para empresa ${empresaId} — ${clienteNombre} — €${totalEuros} — id: ${pedidoRef.id}`);

  // ── Notificación en bandeja + push FCM ────────────────────────────────────
  const cuerpoNotifTienda = `${clienteNombre} — €${totalEuros.toFixed(2)} (tienda online)`;
  try {
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo:             "📦 Nuevo Pedido Web",
      cuerpo:             cuerpoNotifTienda,
      tipo:               "pedidoNuevo",
      timestamp:          admin.firestore.FieldValue.serverTimestamp(),
      leida:              false,
      modulo_destino:     "pedidos",
      entidad_id:         pedidoRef.id,
      remitente_nombre:   clienteNombre !== "Cliente online" ? clienteNombre : null,
      remitente_email:    clienteEmail,
    });
    await enviarNotificacionEmpresa(
      empresaId,
      "📦 Nuevo Pedido Web",
      cuerpoNotifTienda,
      { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "tienda_online" }
    );
  } catch (e) {
    console.warn("⚠️ [TIENDA] Error enviando notificación:", e);
  }

  // ── Descontar stock (catalogo, catalogo_web y libros) ────────────────────
  for (const linea of lineas) {
    if (!linea.productoId || linea.productoId.startsWith("stripe_")) continue;
    const decremento = admin.firestore.FieldValue.increment(-linea.cantidad);
    const base = db.collection("empresas").doc(empresaId);
    // Intentar en las tres colecciones posibles; cada una puede o no existir
    for (const col of ["catalogo", "catalogo_web", "libros"]) {
      try {
        await base.collection(col).doc(linea.productoId).update({ stock: decremento });
        console.log(`📦 Stock ${col} decrementado: ${linea.nombre} -${linea.cantidad}`);
      } catch (_) { /* no existe en esta colección — silencioso */ }
    }
  }

  // ── Email de confirmación al cliente ─────────────────────────────────────
  if (clienteEmail) {
    try {
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      const nombreEmpresa = empresaDoc.data()?.nombre || "La tienda";
      const lineasHtml = lineas.map((l) =>
        `<tr><td style="padding:6px 0;">${l.nombre}</td><td style="text-align:right;padding:6px 0;">${l.cantidad}x ${l.precioUnitario.toFixed(2)} €</td></tr>`
      ).join("");
      await enviarPdfGenerico({
        from: `${nombreEmpresa} <noreply@fluixtech.com>`,
        to: clienteEmail,
        subject: `✅ Pedido #${numTicket} confirmado — ${nombreEmpresa}`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
            <h2 style="color:#1B5E20;">¡Pedido recibido!</h2>
            <p>Hola ${clienteNombre}, hemos recibido tu pedido correctamente.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0;">${lineasHtml}</table>
            <p style="font-size:18px;font-weight:bold;">Total: ${totalEuros.toFixed(2)} €</p>
            ${direccionEnvio ? `<p>📦 Envío a: ${direccionEnvio}</p>` : ""}
            <p>Te avisaremos cuando tu pedido esté preparado.</p>
            <p style="color:#999;font-size:12px;">Pedido #${numTicket} · ${nombreEmpresa}</p>
          </div>
        `,
      });
    } catch (e) {
      console.warn("⚠️ Error enviando email de confirmación:", e);
    }
  }
}

function _formatearDireccion(shipping: Stripe.Checkout.Session.ShippingDetails | null): string | null {
  if (!shipping?.address) return null;
  const a = shipping.address;
  return [shipping.name, a.line1, a.line2, a.postal_code, a.city, a.country]
    .filter(Boolean)
    .join(", ");
}

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO DE VACACIONES — Cloud Functions
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Importar festivos de España desde la API Nager.Date.
 * onCall: { anio: number, empresaId: string, codigoComunidad?: string }
 */
export const importarFestivosEspana = onCall(
  { region: REGION },
  async (request) => {
    // ── AUTH GUARD — Solo admin de la plataforma Fluix ──
    await verificarPropietarioPlataforma(request);

    const { anio, empresaId, codigoComunidad } = request.data;
    if (!anio || !empresaId) {
      throw new HttpsError("invalid-argument", "Se requiere anio y empresaId");
    }

    const url = `https://date.nager.at/api/v3/PublicHolidays/${anio}/ES`;
    console.log(`📅 Importando festivos de ${url} para empresa ${empresaId}`);

    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new HttpsError("unavailable", `API retornó ${response.status}`);
      }

      const holidays: any[] = await response.json();
      const batch = db.batch();
      let count = 0;

      for (const h of holidays) {
        const isGlobal = h.global === true || !h.counties || h.counties.length === 0;
        const matchesComunidad = codigoComunidad && h.counties && h.counties.includes(codigoComunidad);

        if (isGlobal || matchesComunidad) {
          const date = h.date as string; // "2026-01-01"
          const ref = db
            .collection("empresas")
            .doc(empresaId)
            .collection("festivos")
            .doc(`${anio}`)
            .collection("dias")
            .doc(date);

          batch.set(ref, {
            fecha: admin.firestore.Timestamp.fromDate(new Date(date + "T00:00:00")),
            nombre: h.localName || h.name || "",
            tipo: isGlobal ? "nacional" : "autonomico",
            codigo_comunidad: isGlobal ? null : codigoComunidad,
            es_local: false,
          });
          count++;
        }
      }

      // Metadata
      batch.set(
        db.collection("empresas").doc(empresaId).collection("festivos").doc(`${anio}`),
        {
          anio,
          comunidad_autonoma: codigoComunidad || null,
          total_festivos: count,
          importado_desde: "nager.date",
          fecha_importacion: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await batch.commit();
      console.log(`✅ ${count} festivos importados para ${anio}`);
      return { count, anio };
    } catch (error) {
      console.error("❌ Error importando festivos:", error);
      throw new HttpsError("internal", `Error: ${error}`);
    }
  }
);

/**
 * Trigger: cuando cambia el estado de una solicitud de vacaciones.
 * Envía notificación push al empleado afectado.
 */
export const onVacacionEstadoCambiado = onDocumentUpdated(
  { document: "vacaciones/{empresaId}/solicitudes/{solicitudId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const solicitudId = event.params.solicitudId;
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    // Solo nos interesa cuando cambia el estado
    if (antes.estado === despues.estado) return;
    const nuevoEstado = despues.estado as string;
    if (nuevoEstado !== "aprobado" && nuevoEstado !== "rechazado") return;

    const empleadoId = despues.empleado_id as string;
    if (!empleadoId) return;

    // Formatear fechas
    const fechaInicio = despues.fecha_inicio?.toDate
      ? despues.fecha_inicio.toDate().toLocaleDateString("es-ES")
      : "—";
    const fechaFin = despues.fecha_fin?.toDate
      ? despues.fecha_fin.toDate().toLocaleDateString("es-ES")
      : "—";

    let titulo: string;
    let cuerpo: string;

    if (nuevoEstado === "aprobado") {
      titulo = "✅ Vacaciones aprobadas";
      cuerpo = `Tus vacaciones del ${fechaInicio} al ${fechaFin} han sido aprobadas`;
    } else {
      titulo = "❌ Vacaciones rechazadas";
      cuerpo = `Tu solicitud de vacaciones del ${fechaInicio} al ${fechaFin} ha sido rechazada`;
      const motivo = despues.motivo_rechazo as string | undefined;
      if (motivo) {
        cuerpo += `\nMotivo: ${motivo}`;
      }
    }

    // Obtener token del empleado
    const empleadoDoc = await db.collection("usuarios").doc(empleadoId).get();
    const tokenFCM = empleadoDoc.data()?.token_dispositivo as string | undefined;

    // Guardar en bandeja de notificaciones in-app
    await db
      .collection("notificaciones")
      .doc(empresaId)
      .collection("items")
      .add({
        titulo,
        cuerpo,
        tipo: "vacacion_estado",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "vacaciones",
        entidad_id: solicitudId,
        empleado_id: empleadoId,
      });

    // Enviar push si tiene token
    if (tokenFCM) {
      try {
        await messaging.send({
          token: tokenFCM,
          notification: { title: titulo, body: cuerpo },
          data: {
            tipo: "vacacion_estado",
            empresa_id: empresaId,
            solicitud_id: solicitudId,
            estado: nuevoEstado,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "fluixcrm_canal_principal",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });
        console.log(`✅ Push enviado a empleado ${empleadoId} — ${nuevoEstado}`);
      } catch (pushError: any) {
        console.warn(`⚠️ No se pudo enviar push a ${empleadoId}:`, pushError.message);
        // Si el token es inválido, marcarlo
        if (
          pushError.code === "messaging/registration-token-not-registered" ||
          pushError.code === "messaging/invalid-registration-token"
        ) {
          await db.collection("usuarios").doc(empleadoId).update({
            token_dispositivo: admin.firestore.FieldValue.delete(),
          });
        }
      }
    } else {
      console.log(`ℹ️ Empleado ${empleadoId} sin token FCM, notificación guardada solo in-app`);
    }
  }
);

/**
 * Cierre anual de vacaciones: 31 de diciembre a las 23:59 UTC.
 * Calcula días sobrantes y crea arrastre para el año nuevo.
 */
export const scheduledCierreAnualVacaciones = onSchedule(
  { schedule: "59 23 31 12 *", timeZone: "Europe/Madrid", region: REGION },
  async () => {
    const anio = new Date().getFullYear();
    console.log(`📅 Cierre anual de vacaciones ${anio}`);

    // Obtener todas las empresas
    const empresasSnap = await db.collection("empresas").get();

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;

      // Leer configuración de carryover
      const configDoc = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("vacaciones")
        .get();

      const carryover = configDoc.data()?.carryover || {};
      const diasMaximos = carryover.dias_maximos_traspasar ?? 5;
      const mesExp = carryover.mes_expiracion ?? 3;
      const diaExp = carryover.dia_expiracion ?? 31;

      // Obtener saldos del año actual
      const saldosSnap = await db
        .collection("vacaciones")
        .doc(empresaId)
        .collection("saldos")
        .where("anio", "==", anio)
        .get();

      const batch = db.batch();

      for (const saldoDoc of saldosSnap.docs) {
        const saldo = saldoDoc.data();
        const empleadoId = saldo.empleado_id;
        const pendientes = (saldo.dias_devengados || 0) - (saldo.dias_disfrutados || 0);
        const diasATraspasar = Math.min(Math.max(pendientes, 0), diasMaximos);

        if (diasATraspasar > 0) {
          // Crear/actualizar saldo del año siguiente con arrastre
          const nuevoAnio = anio + 1;
          const docId = `${empleadoId}_${nuevoAnio}`;
          const ref = db
            .collection("vacaciones")
            .doc(empresaId)
            .collection("saldos")
            .doc(docId);

          batch.set(
            ref,
            {
              empleado_id: empleadoId,
              anio: nuevoAnio,
              dias_arrastre: diasATraspasar,
              dias_arrastre_consumidos: 0,
              dias_pendientes_ano_anterior: diasATraspasar,
              fecha_expiracion_arrastre: admin.firestore.Timestamp.fromDate(
                new Date(nuevoAnio, mesExp - 1, diaExp)
              ),
              ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          console.log(`  → ${empleadoId}: ${diasATraspasar} días traspasados a ${nuevoAnio}`);
        }
      }

      await batch.commit();
    }

    console.log(`✅ Cierre anual completado para ${anio}`);
  }
);

/**
 * Expiración de arrastre: por defecto 31 de marzo.
 * Elimina los días traspasados no disfrutados y notifica.
 * Se ejecuta diariamente y comprueba si hoy es la fecha de expiración.
 */
export const scheduledExpiracionCarryover = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Europe/Madrid", region: REGION },
  async () => {
    const hoy = new Date();
    console.log(`📅 Verificando expiración de carryover: ${hoy.toISOString()}`);

    const empresasSnap = await db.collection("empresas").get();

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      const anio = hoy.getFullYear();

      // Leer configuración
      const configDoc = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("vacaciones")
        .get();

      const carryover = configDoc.data()?.carryover || {};
      const mesExp = carryover.mes_expiracion ?? 3;
      const diaExp = carryover.dia_expiracion ?? 31;
      const notificar7dias = carryover.notificar_antes_expirar !== false;

      const fechaExpiracion = new Date(anio, mesExp - 1, diaExp);
      const diasHastaExpiracion = Math.ceil(
        (fechaExpiracion.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24)
      );

      // Obtener saldos con arrastre vigente
      const saldosSnap = await db
        .collection("vacaciones")
        .doc(empresaId)
        .collection("saldos")
        .where("anio", "==", anio)
        .where("dias_arrastre", ">", 0)
        .get();

      for (const saldoDoc of saldosSnap.docs) {
        const saldo = saldoDoc.data();
        const empleadoId = saldo.empleado_id;
        const arrastre = saldo.dias_arrastre || 0;
        const consumidos = saldo.dias_arrastre_consumidos || 0;
        const restantes = arrastre - consumidos;

        if (restantes <= 0) continue;

        // Notificación 7 días antes
        if (notificar7dias && diasHastaExpiracion === 7) {
          const tokenDoc = await db.collection("usuarios").doc(empleadoId).get();
          const token = tokenDoc.data()?.token_dispositivo;

          // In-app notification
          await db.collection("notificaciones").doc(empresaId).collection("items").add({
            titulo: "⏰ Días traspasados por expirar",
            cuerpo: `Tienes ${restantes.toFixed(1)} días de vacaciones traspasados que expiran el ${diaExp}/${mesExp}/${anio}`,
            tipo: "vacacion_carryover_expira",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "vacaciones",
            empleado_id: empleadoId,
          });

          if (token) {
            try {
              await messaging.send({
                token,
                notification: {
                  title: "⏰ Días traspasados por expirar",
                  body: `Tienes ${restantes.toFixed(1)} días de vacaciones que expiran en 7 días`,
                },
                data: {
                  tipo: "vacacion_carryover_expira",
                  empresa_id: empresaId,
                },
              });
            } catch (_) { /* silenciar */ }
          }
        }

        // Expiración el día exacto
        if (diasHastaExpiracion <= 0) {
          await saldoDoc.ref.update({
            dias_arrastre: 0,
            dias_arrastre_consumidos: 0,
            dias_pendientes_ano_anterior: 0,
            ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Notificar al empleado
          await db.collection("notificaciones").doc(empresaId).collection("items").add({
            titulo: "📅 Días traspasados expirados",
            cuerpo: `Se han eliminado ${restantes.toFixed(1)} días de vacaciones traspasados no disfrutados`,
            tipo: "vacacion_carryover_expirado",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "vacaciones",
            empleado_id: empleadoId,
          });

          console.log(`  → ${empleadoId}: ${restantes} días expirados en empresa ${empresaId}`);
        }
      }
    }

    console.log("✅ Verificación de expiración completada");
  }
);

/**
 * Alerta de cobertura: se ejecuta diariamente y revisa los próximos 7 días.
 * Envía push al propietario si hay días con cobertura crítica (<mínimo).
 */
export const scheduledAlertaCobertura = onSchedule(
  { schedule: "0 7 * * *", timeZone: "Europe/Madrid", region: REGION },
  async () => {
    console.log("📅 Verificando cobertura de equipos");

    const empresasSnap = await db.collection("empresas").get();

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;

      // Leer mínimo
      const configDoc = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("vacaciones")
        .get();
      const minimoPorcentaje = configDoc.data()?.minimo_cobertura_porcentaje ?? 50;

      // Total empleados
      const empSnap = await db
        .collection("usuarios")
        .where("empresa_id", "==", empresaId)
        .where("activo", "==", true)
        .get();
      const totalEmpleados = empSnap.docs.length;
      if (totalEmpleados === 0) continue;

      // Solicitudes aprobadas
      const solSnap = await db
        .collection("vacaciones")
        .doc(empresaId)
        .collection("solicitudes")
        .where("estado", "==", "aprobado")
        .get();

      const hoy = new Date();
      const diasCriticos: string[] = [];

      for (let i = 0; i < 7; i++) {
        const dia = new Date(hoy);
        dia.setDate(hoy.getDate() + i);
        if (dia.getDay() === 0 || dia.getDay() === 6) continue; // Skip weekends

        const ausentes = new Set<string>();

        for (const doc of solSnap.docs) {
          const data = doc.data();
          const ini = data.fecha_inicio?.toDate?.() || new Date(0);
          const fin = data.fecha_fin?.toDate?.() || new Date(0);
          if (dia >= ini && dia <= fin) {
            ausentes.add(data.empleado_id);
          }
        }

        const presentes = totalEmpleados - ausentes.size;
        const porcentaje = (presentes / totalEmpleados) * 100;

        if (porcentaje < minimoPorcentaje) {
          diasCriticos.push(`${dia.getDate()}/${dia.getMonth() + 1} (${presentes}/${totalEmpleados})`);
        }
      }

      if (diasCriticos.length > 0) {
        const mensaje = `⚠️ Cobertura crítica en los próximos 7 días:\n${diasCriticos.join(", ")}`;

        // Enviar a todos los dispositivos de la empresa (propietarios)
        await enviarNotificacionEmpresa(
          empresaId,
          "⚠️ Alerta de cobertura",
          mensaje,
          { tipo: "alerta_cobertura" }
        );

        console.log(`⚠️ Empresa ${empresaId}: ${diasCriticos.length} días críticos`);
      }
    }

    console.log("✅ Verificación de cobertura completada");
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO DE FINIQUITOS — Cloud Functions
// ═════════════════════════════════════════════════════════════════════════════

import * as https from "https";
import * as http from "http";

/**
 * Descarga un archivo desde una URL (Firebase Storage URL firmada).
 */
async function descargarArchivo(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https") ? https : http;
    lib.get(url, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    }).on("error", reject);
  });
}

/**
 * Cloud Function: enviar documentación del finiquito al empleado por email.
 * onCall: { finiquitoId, empresaId, emailDestino, documentos: string[] }
 * documentos puede incluir: 'finiquito', 'carta_cese', 'certificado_sepe', 'ultima_nomina'
 */
export const enviarDocumentacionFiniquito = onCall(
  { region: REGION },
  async (request) => {
    const { finiquitoId, empresaId, emailDestino, documentos } = request.data;

    // ── AUTH GUARD ──
    await verificarAuthYEmpresa(request, empresaId);

    if (!finiquitoId || !empresaId || !emailDestino) {
      throw new HttpsError("invalid-argument",
        "Se requiere finiquitoId, empresaId y emailDestino");
    }

    // Validar email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(emailDestino)) {
      throw new HttpsError("invalid-argument", "Email inválido");
    }

    // Obtener finiquito
    const finiqDoc = await db
      .collection("empresas").doc(empresaId)
      .collection("finiquitos").doc(finiquitoId).get();
    if (!finiqDoc.exists) {
      throw new HttpsError("not-found", "Finiquito no encontrado");
    }
    const finiq = finiqDoc.data()!;
    const nombreEmpleado = finiq.empleado_nombre as string ?? "Empleado";

    // Obtener nombre de empresa
    const empDoc = await db.collection("empresas").doc(empresaId).get();
    const nombreEmpresa = empDoc.data()?.nombre as string ?? "La empresa";

    // Construir adjuntos
    const adjuntos: { filename: string; content: Buffer; contentType: string }[] = [];
    const documentosSeleccionados: string[] = Array.isArray(documentos)
      ? documentos
      : ["finiquito", "carta_cese", "certificado_sepe"];

    const urlMap: Record<string, { field: string; nombre: string }> = {
      finiquito: { field: "pdf_firmado_url", nombre: `finiquito_${nombreEmpleado}.pdf` },
      carta_cese: { field: "carta_cese_url", nombre: `carta_cese_${nombreEmpleado}.pdf` },
      certificado_sepe: { field: "certificado_sepe_url", nombre: `certificado_empresa_SEPE_${nombreEmpleado}.pdf` },
    };

    const erroresDescarga: string[] = [];

    for (const doc of documentosSeleccionados) {
      const info = urlMap[doc];
      if (!info) continue;
      const url = finiq[info.field] as string | undefined;
      if (!url) {
        console.warn(`⚠️ ${doc} no disponible`);
        erroresDescarga.push(doc);
        continue;
      }
      try {
        const buffer = await descargarArchivo(url);
        adjuntos.push({
          filename: info.nombre,
          content: buffer,
          contentType: "application/pdf",
        });
      } catch (e) {
        console.error(`❌ Error descargando ${doc}:`, e);
        erroresDescarga.push(doc);
      }
    }

    if (adjuntos.length === 0) {
      throw new HttpsError("internal",
        "No se pudo preparar ningún documento. Genera los PDFs primero.");
    }


    // Template HTML del email
    const htmlEmail = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="font-family: Arial, sans-serif; background:#f5f5f5; margin:0; padding:20px;">
  <div style="max-width:600px; margin:0 auto; background:white; border-radius:12px; overflow:hidden; box-shadow:0 2px 8px rgba(0,0,0,0.1);">
    <div style="background:#1a237e; padding:24px; text-align:center;">
      <h1 style="color:white; margin:0; font-size:20px;">Documentación de su cese</h1>
      <p style="color:#9fa8da; margin:8px 0 0;">${nombreEmpresa}</p>
    </div>
    <div style="padding:32px;">
      <p style="font-size:16px; color:#333;">Estimado/a <strong>${nombreEmpleado}</strong>,</p>
      <p style="color:#555; line-height:1.6;">
        Le remitimos la documentación relacionada con la extinción de su contrato de trabajo.
        Le recomendamos que guarde estos documentos en un lugar seguro, ya que pueden ser
        necesarios para realizar trámites en el SEPE y otros organismos.
      </p>
      <div style="background:#f8f9ff; border-left:4px solid #3949ab; padding:16px; margin:20px 0; border-radius:0 8px 8px 0;">
        <p style="margin:0 0 12px; font-weight:bold; color:#1a237e;">Documentos adjuntos:</p>
        ${adjuntos.map(a => {
          const icon = a.filename.includes("finiquito") ? "📄" :
                       a.filename.includes("carta") ? "📝" : "🏛️";
          const desc = a.filename.includes("finiquito")
            ? "Finiquito y liquidación — detalle de la liquidación económica."
            : a.filename.includes("carta")
            ? "Carta de cese — comunicación formal de extinción del contrato."
            : "Certificado de empresa (SEPE) — necesario para solicitar el paro.";
          return `<p style="margin:4px 0; color:#333;">${icon} <strong>${a.filename}</strong><br><span style="font-size:12px;color:#666;">${desc}</span></p>`;
        }).join('')}
      </div>
      <div style="background:#fff8e1; border:1px solid #ffe082; border-radius:8px; padding:16px; margin:20px 0;">
        <p style="margin:0 0 8px; font-weight:bold; color:#f57f17;">💡 Información importante</p>
        <ul style="margin:0; padding-left:16px; color:#555; font-size:13px; line-height:1.8;">
          <li>Dispone de <strong>20 días hábiles</strong> desde la fecha de cese para impugnar el despido ante el Juzgado de lo Social (si procede).</li>
          <li>Puede solicitar la prestación por desempleo en el <strong>SEPE</strong> en los 15 días siguientes a su cese.</li>
          <li>Para cualquier duda, contacte con nosotros.</li>
        </ul>
      </div>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
      <p style="color:#555; font-size:14px;">
        Si tiene alguna pregunta sobre esta documentación, no dude en ponerse en contacto con nosotros.
      </p>
      <p style="color:#333; font-size:14px;">
        Atentamente,<br>
        <strong>${nombreEmpresa}</strong>
      </p>
    </div>
    <div style="background:#f5f5f5; padding:16px; text-align:center; font-size:11px; color:#999;">
      Este email contiene información confidencial. Si lo ha recibido por error, por favor notifíquelo al remitente.
    </div>
  </div>
</body>
</html>`;

    // Enviar email con Resend
    const { Resend } = await import("resend");
    const resendClient = new Resend(process.env.RESEND_API_KEY);

    try {
      const { error } = await resendClient.emails.send({
        from: `${nombreEmpresa} <noreply@fluixtech.com>`,
        to: emailDestino,
        subject: `Documentación de cese — ${nombreEmpresa}`,
        html: htmlEmail,
        attachments: adjuntos.map((a) => ({
          filename: a.filename,
          content: a.content.toString("base64"),
        })),
      });

      if (error) throw new Error(error.message);

      // Actualizar finiquito con la fecha de envío
      await finiqDoc.ref.update({
        documentacion_enviada_a: emailDestino,
        fecha_envio_documentacion: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Documentación de finiquito enviada a ${emailDestino}`);
      return {
        exito: true,
        mensaje: `Documentación enviada a ${emailDestino}`,
        documentos_enviados: adjuntos.map(a => a.filename),
        documentos_faltantes: erroresDescarga,
      };
    } catch (error) {
      console.error("❌ Error enviando email:", error);
      throw new HttpsError(
        "internal",
        `Error enviando email: ${error instanceof Error ? error.message : "Desconocido"}`
      );
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// CALENDARIO FISCAL — Alertas de vencimientos AEAT
// ═══════════════════════════════════════════════════════════════════════════

export const alertasVencimientosFiscales = onSchedule(
  { schedule: "0 9 * * *", timeZone: "Europe/Madrid", region: REGION },
  async (_event) => {
    console.log("🗓️ Ejecutando alertas de vencimientos fiscales...");

    const hoy = new Date();
    const vencimientosProximos = _calcularVencimientos(hoy);

    if (vencimientosProximos.length === 0) {
      console.log("✅ No hay vencimientos fiscales próximos");
      return;
    }

    // Obtener empresas con Pack Fiscal activo
    const empresasSnap = await db.collection("empresas")
      .where("active_packs", "array-contains", "fiscal_ai")
      .get();

    console.log(`📊 Enviando alertas a ${empresasSnap.size} empresa(s) con Pack Fiscal`);

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      const empresaData = empresaDoc.data();
      const nombreEmpresa = empresaData.nombre || "Tu empresa";

      try {
        // Buscar tokens FCM de usuarios de la empresa
        const tokensQuery = await db
          .collection("empresas").doc(empresaId)
          .collection("usuario_tokens")
          .where("activo", "==", true)
          .get();

        const tokens: string[] = [];
        tokensQuery.forEach(doc => {
          const token = doc.data().fcm_token;
          if (token) tokens.push(token);
        });

        if (tokens.length === 0) {
          console.log(`⚠️ Sin tokens FCM para empresa ${empresaId}`);
          continue;
        }

        // Preparar mensaje de alerta
        const modelo = vencimientosProximos[0]; // El más próximo
        const dias = Math.ceil((modelo.fecha.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24));

        let titulo = "📅 Vencimiento fiscal próximo";
        let mensaje = "";

        if (dias === 0) {
          titulo = "🚨 Vencimiento fiscal HOY";
          mensaje = `Modelo ${modelo.modelo} vence hoy (${_formatearFecha(modelo.fecha)})`;
        } else if (dias === 1) {
          titulo = "⚠️ Vencimiento fiscal MAÑANA";
          mensaje = `Modelo ${modelo.modelo} vence mañana (${_formatearFecha(modelo.fecha)})`;
        } else {
          mensaje = `Modelo ${modelo.modelo} vence en ${dias} días (${_formatearFecha(modelo.fecha)})`;
        }

        // Enviar notificación push
        const response = await messaging.sendMulticast({
          tokens,
          notification: { title: titulo, body: mensaje },
          data: {
            tipo: "vencimiento_fiscal",
            modelo: modelo.modelo,
            fecha: modelo.fecha.toISOString(),
            dias_restantes: dias.toString(),
            empresa_id: empresaId,
          },
          android: {
            notification: {
              channelId: "fluixcrm_canal_principal",
              priority: "high" as const,
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: { title: titulo, body: mensaje },
                badge: 1,
                sound: "default",
              },
            },
          },
        });

        console.log(`✅ Alerta enviada a ${response.successCount}/${tokens.length} dispositivos - ${nombreEmpresa}`);

        // Crear notificación en Firestore para historial
        await db
          .collection("empresas").doc(empresaId)
          .collection("notificaciones")
          .add({
            titulo: titulo,
            mensaje: mensaje,
            tipo: "vencimiento_fiscal",
            modelo: modelo.modelo,
            fecha_vencimiento: admin.firestore.Timestamp.fromDate(modelo.fecha),
            dias_restantes: dias,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
          });

      } catch (error) {
        console.error(`❌ Error enviando alerta fiscal a empresa ${empresaId}:`, error);
      }
    }
  }
);

function _calcularVencimientos(fechaActual: Date): VencimientoFiscal[] {
  const vencimientos: VencimientoFiscal[] = [];
  const anio = fechaActual.getFullYear();

  // Solo alertar si faltan 7 días o menos
  const limiteAlerta = new Date(fechaActual);
  limiteAlerta.setDate(limiteAlerta.getDate() + 7);

  // Vencimientos trimestrales - día 20 del mes siguiente
  for (let trim = 1; trim <= 4; trim++) {
    const mesVencimiento = trim * 3 + 1; // Ene=4, Abr=7, Jul=10, Oct=13
    const fecha = new Date(
      anio + (mesVencimiento > 12 ? 1 : 0),
      mesVencimiento > 12 ? mesVencimiento - 12 : mesVencimiento,
      20
    );

    if (fecha >= fechaActual && fecha <= limiteAlerta) {
      vencimientos.push({
        modelo: "303",
        descripcion: `IVA trimestral ${trim}T/${anio}`,
        fecha: fecha,
      });
    }
  }

  // Vencimientos anuales - enero del año siguiente
  const anioSiguiente = anio + 1;
  const vencimientosAnuales = [
    { modelo: "390", fecha: new Date(anioSiguiente, 0, 30), desc: `Resumen anual IVA ${anio}` },
    { modelo: "190", fecha: new Date(anioSiguiente, 0, 31), desc: `Resumen retenciones IRPF ${anio}` },
    { modelo: "347", fecha: new Date(anioSiguiente, 1, 28), desc: `Operaciones con terceros ${anio}` },
  ];

  for (const v of vencimientosAnuales) {
    if (v.fecha >= fechaActual && v.fecha <= limiteAlerta) {
      vencimientos.push({
        modelo: v.modelo,
        descripcion: v.desc,
        fecha: v.fecha,
      });
    }
  }

  // Ordenar por fecha más próxima primero
  vencimientos.sort((a, b) => a.fecha.getTime() - b.fecha.getTime());

  return vencimientos;
}

function _formatearFecha(fecha: Date): string {
  return fecha.toLocaleDateString("es-ES", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
}

interface VencimientoFiscal {
  modelo: string;
  descripcion: string;
  fecha: Date;
}

// ═════════════════════════════════════════════════════════════════════════════
// BACKUP NOCTURNO AUTOMÁTICO — Datos fiscales a Cloud Storage
// Ejecuta cada noche a las 02:00 hora española
// Exporta: facturas emitidas + recibidas, gastos y libro registro IVA
// Retención: 7 años (Art. 30 Código de Comercio + Art. 70 LIVA)
// ═════════════════════════════════════════════════════════════════════════════

export const backupDatosFiscalesNocturno = onSchedule(
  {
    schedule: "0 2 * * *",
    timeZone: "Europe/Madrid",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async (_event) => {
    const storage  = admin.storage();
    const bucket   = storage.bucket();
    const hoy      = new Date();
    const fechaStr = hoy.toISOString().split("T")[0];
    const anio     = hoy.getFullYear();
    const mes      = String(hoy.getMonth() + 1).padStart(2, "0");

    const empresasSnap = await db.collection("empresas").get();
    let totalFacturas   = 0;
    let totalGastos     = 0;
    let empresasProcesadas = 0;

    for (const empDoc of empresasSnap.docs) {
      const empresaId     = empDoc.id;
      const perfil        = (empDoc.data().perfil as Record<string, unknown>) ?? {};
      const nifEmpresa    = (perfil.nif     as string) ?? empresaId;
      const nombreEmpresa = (perfil.nombre  as string) ?? empresaId;

      try {
        // ── 1. Facturas emitidas ────────────────────────────────────────────
        const facturasSnap = await db
          .collection("empresas").doc(empresaId).collection("facturas")
          .where("fecha", ">=", new Date(anio, 0, 1))
          .get();

        if (!facturasSnap.empty) {
          const csvFacturas = _buildCsvFacturasEmitidas(facturasSnap.docs);
          await bucket.file(`backups/${empresaId}/${anio}/facturas_emitidas_${fechaStr}.csv`)
            .save(csvFacturas, {
              contentType: "text/csv; charset=utf-8",
              metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "facturas_emitidas" },
            });
          totalFacturas += facturasSnap.size;
        }

        // ── 2. Facturas recibidas ───────────────────────────────────────────
        const recibidasSnap = await db
          .collection("empresas").doc(empresaId).collection("facturas_recibidas")
          .where("fecha", ">=", new Date(anio, 0, 1))
          .get();

        if (!recibidasSnap.empty) {
          const csvRecibidas = _buildCsvFacturasRecibidas(recibidasSnap.docs);
          await bucket.file(`backups/${empresaId}/${anio}/facturas_recibidas_${fechaStr}.csv`)
            .save(csvRecibidas, {
              contentType: "text/csv; charset=utf-8",
              metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "facturas_recibidas" },
            });
        }

        // ── 3. Gastos ───────────────────────────────────────────────────────
        const gastosSnap = await db
          .collection("empresas").doc(empresaId).collection("gastos")
          .where("fecha", ">=", new Date(anio, 0, 1))
          .get();

        if (!gastosSnap.empty) {
          const csvGastos = _buildCsvGastos(gastosSnap.docs);
          await bucket.file(`backups/${empresaId}/${anio}/gastos_${fechaStr}.csv`)
            .save(csvGastos, {
              contentType: "text/csv; charset=utf-8",
              metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "gastos" },
            });
          totalGastos += gastosSnap.size;
        }

        // ── 4. Libro registro IVA trimestral (primer día del trimestre) ─────
        const mesesInicioTrimestre = [1, 4, 7, 10];
        const esInicioTrimestre =
          hoy.getDate() === 1 && mesesInicioTrimestre.includes(hoy.getMonth() + 1);

        if (esInicioTrimestre) {
          const mesAnterior   = hoy.getMonth() === 0 ? 12 : hoy.getMonth();
          const anioLibro     = hoy.getMonth() === 0 ? anio - 1 : anio;
          const trimestreNum  = Math.ceil(mesAnterior / 3);
          const libroContent  = await _buildLibroRegistroTrimestral(
            empresaId, nifEmpresa, trimestreNum, anioLibro
          );
          if (libroContent) {
            await bucket
              .file(`backups/${empresaId}/${anioLibro}/libro_IVA_${anioLibro}_T${trimestreNum}.txt`)
              .save(libroContent, {
                contentType: "text/plain; charset=utf-8",
                metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "libro_registro_IVA" },
              });
          }
        }

        // ── 5. Log de ejecución ─────────────────────────────────────────────
        await db.collection("empresas").doc(empresaId)
          .collection("backups_fiscales").doc(fechaStr)
          .set({
            fecha:               admin.firestore.FieldValue.serverTimestamp(),
            facturas_emitidas:   facturasSnap.size,
            facturas_recibidas:  recibidasSnap.size,
            gastos:              gastosSnap.size,
            mes:                 `${anio}-${mes}`,
            estado:              "completado",
          }, { merge: true });

        empresasProcesadas++;

      } catch (err) {
        console.error(`[Backup] Error empresa ${empresaId}:`, err);
        await db.collection("empresas").doc(empresaId)
          .collection("backups_fiscales").doc(fechaStr)
          .set({
            fecha:   admin.firestore.FieldValue.serverTimestamp(),
            estado:  "error",
            error:   String(err),
          }, { merge: true });
      }
    }

    console.log(
      `[Backup Fiscal] ${empresasProcesadas} empresas · ` +
      `${totalFacturas} facturas · ${totalGastos} gastos — ${fechaStr}`
    );
  }
);

// ── Helpers CSV / texto ────────────────────────────────────────────────────────

function _buildCsvFacturasEmitidas(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): string {
  const hdr = [
    "numero_factura","serie","fecha","estado",
    "nif_cliente","nombre_cliente",
    "base_imponible","total_iva","total_recargo_eq",
    "retencion_irpf","total",
    "tipo_factura","metodo_pago",
  ].join(";");

  const rows = docs.map((doc) => {
    const d = doc.data();
    return [
      _bcsv(d.numero_factura),
      _bcsv(d.serie),
      _bcsvFecha(d.fecha),
      _bcsv(d.estado),
      _bcsv(d.datos_fiscales?.nif),
      _bcsv(d.datos_fiscales?.razon_social ?? d.nombre_cliente),
      _bcsvNum(d.base_imponible),
      _bcsvNum(d.total_iva),
      _bcsvNum(d.total_recargo_equivalencia ?? 0),
      _bcsvNum(d.retencion_irpf ?? 0),
      _bcsvNum(d.total),
      _bcsv(d.tipo_factura),
      _bcsv(d.metodo_pago),
    ].join(";");
  });

  return "\uFEFF" + hdr + "\n" + rows.join("\n");
}

function _buildCsvFacturasRecibidas(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): string {
  const hdr = [
    "numero_factura_proveedor","fecha_factura","fecha_contabilizacion",
    "nif_proveedor","nombre_proveedor",
    "base_imponible","cuota_iva","tipo_iva",
    "total","categoria","deducible",
  ].join(";");

  const rows = docs.map((doc) => {
    const d = doc.data();
    return [
      _bcsv(d.numero_factura),
      _bcsvFecha(d.fecha_factura ?? d.fecha),
      _bcsvFecha(d.fecha_contabilizacion ?? d.fecha),
      _bcsv(d.nif_proveedor),
      _bcsv(d.nombre_proveedor),
      _bcsvNum(d.base_imponible),
      _bcsvNum(d.cuota_iva ?? 0),
      _bcsvNum(d.tipo_iva ?? 21),
      _bcsvNum(d.total),
      _bcsv(d.categoria),
      _bcsv(d.deducible !== false ? "Sí" : "No"),
    ].join(";");
  });

  return "\uFEFF" + hdr + "\n" + rows.join("\n");
}

function _buildCsvGastos(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): string {
  const hdr = [
    "id","fecha","concepto","categoria",
    "importe","iva","importe_iva",
    "proveedor","justificante","deducible",
  ].join(";");

  const rows = docs.map((doc) => {
    const d = doc.data();
    return [
      _bcsv(doc.id),
      _bcsvFecha(d.fecha),
      _bcsv(d.concepto),
      _bcsv(d.categoria),
      _bcsvNum(d.importe),
      _bcsvNum(d.iva ?? 0),
      _bcsvNum(d.importe_iva ?? 0),
      _bcsv(d.proveedor ?? d.nombre_proveedor),
      _bcsv(d.url_justificante ? "Sí" : "No"),
      _bcsv(d.deducible !== false ? "Sí" : "No"),
    ].join(";");
  });

  return "\uFEFF" + hdr + "\n" + rows.join("\n");
}

async function _buildLibroRegistroTrimestral(
  empresaId: string,
  nifEmpresa: string,
  trimestre: number,
  anio: number
): Promise<string | null> {
  const mesInicio = (trimestre - 1) * 3 + 1;
  const mesFin    = mesInicio + 2;
  const fechaIni  = new Date(anio, mesInicio - 1, 1);
  const fechaFin  = new Date(anio, mesFin, 0, 23, 59, 59);

  const snap = await db
    .collection("empresas").doc(empresaId).collection("facturas")
    .where("fecha", ">=", fechaIni)
    .where("fecha", "<=", fechaFin)
    .orderBy("fecha")
    .get();

  if (snap.empty) return null;

  const sep   = "─".repeat(88);
  const lines = [
    `LIBRO REGISTRO FACTURAS EMITIDAS`,
    `NIF Titular: ${nifEmpresa}   Ejercicio: ${anio}   Trimestre: T${trimestre}`,
    sep,
    "FACTURA        FECHA       NIF CLIENTE     RAZÓN SOCIAL                 BASE IMP    CUOTA IVA       TOTAL",
    sep,
  ];

  let sumBase = 0, sumCuota = 0, sumTotal = 0;

  for (const doc of snap.docs) {
    const d     = doc.data();
    const base  = (d.base_imponible  as number) ?? 0;
    const cuota = (d.total_iva       as number) ?? 0;
    const total = (d.total           as number) ?? 0;
    sumBase  += base; sumCuota += cuota; sumTotal += total;

    lines.push(
      String(d.numero_factura ?? "").padEnd(15) +
      _bcsvFecha(d.fecha).padEnd(12) +
      String(d.datos_fiscales?.nif ?? "").padEnd(16) +
      String(d.datos_fiscales?.razon_social ?? d.nombre_cliente ?? "").substring(0,28).padEnd(29) +
      base.toFixed(2).padStart(11) +
      cuota.toFixed(2).padStart(11) +
      total.toFixed(2).padStart(12)
    );
  }

  lines.push(sep);
  lines.push(
    "TOTALES".padEnd(15+12+16+29) +
    sumBase.toFixed(2).padStart(11) +
    sumCuota.toFixed(2).padStart(11) +
    sumTotal.toFixed(2).padStart(12)
  );

  return lines.join("\n");
}

function _bcsv(val: unknown): string {
  if (val === null || val === undefined) return "";
  const str = String(val).replace(/"/g, '""');
  return str.includes(";") || str.includes('"') || str.includes("\n") ? `"${str}"` : str;
}

function _bcsvNum(val: unknown): string {
  return Number(val ?? 0).toFixed(2).replace(".", ",");
}

function _bcsvFecha(val: unknown): string {
  if (!val) return "";
  try {
    const d = (val as FirebaseFirestore.Timestamp)?.toDate
      ? (val as FirebaseFirestore.Timestamp).toDate()
      : new Date(val as string);
    return `${String(d.getDate()).padStart(2,"0")}/${String(d.getMonth()+1).padStart(2,"0")}/${d.getFullYear()}`;
  } catch { return String(val); }
}

// ──────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: Enviar emails de contacto de interés (login público)
// ──────────────────────────────────────────────────────────────────────────────

export const enviarEmailsContactoInteres = onCall(
  { region: REGION },
  async (request) => {
    const data = request.data;

    // Importar funciones de Resend
    const {
      enviarConfirmacionContactoInteres,
      enviarNotificacionContactoInteres,
    } = await import("./resend_service");

    try {
      // 1. Email de confirmación al usuario
      const resultadoConfirmacion = await enviarConfirmacionContactoInteres({
        to: data.correo,
        nombre: data.nombre,
        correo: data.correo,
        telefono: data.telefono,
        nombreEmpresa: data.nombreEmpresa,
        actividad: data.actividad,
        numTrabajadores: data.numTrabajadores,
      });

      // 2. Email de notificación al propietario
      const resultadoNotificacion = await enviarNotificacionContactoInteres({
        nombre: data.nombre,
        correo: data.correo,
        telefono: data.telefono,
        nombreEmpresa: data.nombreEmpresa,
        actividad: data.actividad,
        numTrabajadores: data.numTrabajadores,
        leadId: data.leadId,
        fechaSolicitud: data.fechaSolicitud,
      });

      console.log("✅ Emails de contacto enviados:", {
        confirmacion: resultadoConfirmacion.exito,
        notificacion: resultadoNotificacion.exito,
      });

      return {
        exito: true,
        confirmacionEnviada: resultadoConfirmacion.exito,
        notificacionEnviada: resultadoNotificacion.exito,
      };
    } catch (error: any) {
      console.error("❌ Error enviando emails de contacto:", error);
      throw new HttpsError("internal", `Error enviando emails: ${error.message}`);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Zonas de envío internacional — listas de países por zona
// ─────────────────────────────────────────────────────────────────────────────

type AllowedCountry = Stripe.Checkout.SessionCreateParams.ShippingAddressCollection.AllowedCountry;

const _PAISES_EUROPA: AllowedCountry[] = [
  "AT","BE","BG","CY","CZ","DE","DK","EE","FI","FR","GR","HR","HU",
  "IE","IT","LT","LU","LV","MT","NL","PL","PT","RO","SE","SI","SK",
  "GB","CH","NO","IS","AL","BA","ME","MK","RS","UA","MD","LI","MC",
  "AD","SM","VA","XK",
];
const _PAISES_LATAM: AllowedCountry[] = [
  "MX","AR","CL","CO","PE","EC","UY","VE","BO","PY","CR","PA","DO",
  "GT","HN","SV","NI","PR","HT","JM","TT","BB","BS","BZ","GY","SR",
];
const _PAISES_RESTO: AllowedCountry[] = [
  "US","CA","AU","NZ","JP","KR","CN","IN","SG","HK","TW","ZA","AE",
  "SA","IL","TR","MA","TN","EG","NG","BR","JO","KW","QA","BH","OM",
  "PH","TH","ID","MY","VN","PK","BD","LK","MM","KZ","UZ","BY","GE",
  "AM","AZ","KH","NP","RW","TZ","KE","GH","CI","SN","CM","ET",
];

const _SET_EUROPA = new Set<string>(_PAISES_EUROPA);
const _SET_LATAM  = new Set<string>(_PAISES_LATAM);

/** Devuelve la zona a partir del código de país ISO 3166-1 alpha-2. */
function _zonaDesde(pais: string): "es" | "europa" | "latam" | "mundo" {
  if (pais === "ES") return "es";
  if (_SET_EUROPA.has(pais)) return "europa";
  if (_SET_LATAM.has(pais))  return "latam";
  return "mundo";
}

function _opcionesEnvioEuropa(pesoGramos: number): Stripe.Checkout.SessionCreateParams.ShippingOption[] {
  const cents = pesoGramos < 500 ? 1500 : 2000;
  return [{
    shipping_rate_data: {
      type: "fixed_amount",
      fixed_amount: { amount: cents, currency: "eur" },
      display_name: `Envío Europa (7-14 días laborables) — ${(cents/100).toFixed(0)}€`,
      delivery_estimate: {
        minimum: { unit: "business_day", value: 7 },
        maximum: { unit: "business_day", value: 14 },
      },
    },
  }];
}

function _opcionesEnvioLatam(pesoGramos: number): Stripe.Checkout.SessionCreateParams.ShippingOption[] {
  const cents = pesoGramos < 500 ? 2000 : 2500;
  return [{
    shipping_rate_data: {
      type: "fixed_amount",
      fixed_amount: { amount: cents, currency: "eur" },
      display_name: `Envío Latinoamérica (10-21 días laborables) — ${(cents/100).toFixed(0)}€`,
      delivery_estimate: {
        minimum: { unit: "business_day", value: 10 },
        maximum: { unit: "business_day", value: 21 },
      },
    },
  }];
}

function _opcionesEnvioMundo(pesoGramos: number): Stripe.Checkout.SessionCreateParams.ShippingOption[] {
  const cents = pesoGramos < 500 ? 3000 : 3500;
  return [{
    shipping_rate_data: {
      type: "fixed_amount",
      fixed_amount: { amount: cents, currency: "eur" },
      display_name: `Envío internacional (14-30 días laborables) — ${(cents/100).toFixed(0)}€`,
      delivery_estimate: {
        minimum: { unit: "business_day", value: 14 },
        maximum: { unit: "business_day", value: 30 },
      },
    },
  }];
}

// ─────────────────────────────────────────────────────────────────────────────
// crearCheckoutNazari — Crea una sesión de Stripe Checkout para la tienda web
//   de Editorial Nazarí y devuelve la URL de pago.
//
// POST body: { items: [{ catalogo_id, cantidad }], zona?: "ES"|"EU"|"LATAM"|"WORLD" }
// zona por defecto: "ES". El precio y peso se leen SIEMPRE desde Firestore.
// El cliente NO puede influir en el importe a cobrar.
// Respuesta: { url: "https://checkout.stripe.com/..." }
// ─────────────────────────────────────────────────────────────────────────────
const NAZARI_EMPRESA_ID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

// Secret para sincronizarLibroStripeTest — mover a STRIPE_SYNC_SECRET en .env
const STRIPE_SYNC_SECRET = process.env.STRIPE_SYNC_SECRET ?? "fluix-stripe-test-2026";

/** Lee un item de catalogo_web y valida que está disponible para venta. */
async function _resolverItemCatalogoNazari(catalogoId: string): Promise<{
  nombre: string; imagenUrl: string; precioNum: number; precioStr: string;
  pesoGramos: number; preventa: boolean; preventaEnvioLejanoCents: number | null;
}> {
  const col = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("catalogo_web");
  let snap = await col.doc(catalogoId).get();

  // Fallback: buscar por campo 'slug' si el ID de doc no coincide
  if (!snap.exists) {
    const bySlug = await col.where("slug", "==", catalogoId).limit(1).get();
    if (!bySlug.empty) snap = bySlug.docs[0] as any;
  }

  if (!snap.exists) throw new Error(`Producto no encontrado: ${catalogoId}`);
  const d = snap.data()!;
  if (d.activo === false) throw new Error(`Producto no disponible: ${catalogoId}`);

  const precioRaw: string = (d.precio ?? "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
  const precioNum = Math.round(parseFloat(precioRaw || "0") * 100);
  if (isNaN(precioNum) || precioNum <= 0) throw new Error(`Precio inválido en ${catalogoId}: "${d.precio}"`);

  const pesoRaw = d.peso_gramos ?? d.campo_peso ?? d.peso ?? "300";
  const pesoGramos = Math.max(1, parseInt(String(pesoRaw).replace(/[^0-9]/g, ""), 10) || 300);

  // Preventa: precio de envío lejano en céntimos (null si no configurado)
  const preventa: boolean = d.preventa === true || d.es_preventa === true;
  let preventaEnvioLejanoCents: number | null = null;
  if (preventa && d.preventa_envio_lejano != null) {
    const raw = String(d.preventa_envio_lejano).replace(",", ".").replace(/[^0-9.]/g, "");
    const euros = parseFloat(raw);
    if (!isNaN(euros) && euros > 0) preventaEnvioLejanoCents = Math.round(euros * 100);
  }

  return {
    nombre:                    (d.nombre ?? d.titulo ?? "Libro") as string,
    imagenUrl:                 (d.imagen_url ?? "") as string,
    precioNum,
    precioStr:                 d.precio as string,
    pesoGramos,
    preventa,
    preventaEnvioLejanoCents,
  };
}

/**
 * Opciones de envío nacional (España) para Nazarí.
 * Reglas:
 *   - Total ≥ 30 €: Gratuito (ordinario) + Urgente. El peso no aplica.
 *   - Total < 30 €: Ordinario por peso (≤100g→1,50€ | ≤500g→2,50€ | ≤1000g→3,00€) + Urgente.
 *   - Urgente siempre 6 €, independiente del peso y el total.
 */
function _calcularOpcionesEnvioNazariES(
  totalProductosEuros: number,
  pesoGramos: number
): Stripe.Checkout.SessionCreateParams.ShippingOption[] {
  const urgente: Stripe.Checkout.SessionCreateParams.ShippingOption = {
    shipping_rate_data: {
      type: "fixed_amount",
      fixed_amount: { amount: 600, currency: "eur" },
      display_name: "Envío urgente (24-48h) — 6,00€",
      delivery_estimate: {
        minimum: { unit: "business_day", value: 1 },
        maximum: { unit: "business_day", value: 2 },
      },
    },
  };

  if (totalProductosEuros >= 30) {
    return [
      {
        shipping_rate_data: {
          type: "fixed_amount",
          fixed_amount: { amount: 0, currency: "eur" },
          display_name: "Envío gratuito — Ordinario (3-5 días laborables)",
          delivery_estimate: {
            minimum: { unit: "business_day", value: 3 },
            maximum: { unit: "business_day", value: 5 },
          },
        },
      },
      urgente,
    ];
  }

  // <30€: precio ordinario según peso total del pedido
  let ordinarioCents: number;
  if (pesoGramos <= 100)      ordinarioCents = 150;
  else if (pesoGramos <= 500) ordinarioCents = 250;
  else                        ordinarioCents = 300; // hasta 1 kg

  const precioStr = (ordinarioCents / 100).toFixed(2).replace(".", ",");
  return [
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: { amount: ordinarioCents, currency: "eur" },
        display_name: `Envío ordinario (3-5 días laborables) — ${precioStr}€`,
        delivery_estimate: {
          minimum: { unit: "business_day", value: 3 },
          maximum: { unit: "business_day", value: 5 },
        },
      },
    },
    urgente,
  ];
}

// ── Helper: cliente Stripe configurado para Nazarí (TEST o LIVE) ──────────────
// Devuelve el cliente Stripe con la clave correcta para el modo indicado.
// Si existe stripe_account_id en integraciones/stripe (Stripe Connect) lo usa;
// de lo contrario opera directamente sobre la cuenta cuya clave está configurada.
async function getNazariStripeConfig(isTest: boolean) {
  const key  = isTest ? stripeSecretKeyTest.value() : stripeSecretKey.value();
  const mode = isTest ? "TEST" : "LIVE";
  if (!key) throw new Error(`STRIPE_SECRET_KEY${isTest ? "_TEST" : ""} no configurada — añádela a functions/.env`);

  const stripe = new Stripe(key, { apiVersion: "2024-06-20" });

  // Stripe Connect opcional: si existe stripe_account_id lo usamos;
  // si no, operamos directamente (connOpts = undefined, no pasar al SDK).
  let connOpts: Stripe.RequestOptions | undefined;
  let stripeAccountId = "";
  try {
    const integSnap = await db
      .collection("empresas").doc(NAZARI_EMPRESA_ID)
      .collection("integraciones").doc("stripe").get();
    stripeAccountId = integSnap.data()?.stripe_account_id ?? "";
    if (stripeAccountId) connOpts = { stripeAccount: stripeAccountId };
  } catch (_) { /* sin doc de integración — operar directamente */ }

  const acctLabel = stripeAccountId ? ` / Connect: ${stripeAccountId}` : " / cuenta directa";
  console.log(`🔑 [${mode}${acctLabel}] Stripe config lista`);
  return { stripe, connOpts, mode, stripeAccountId };
}

// ── CORS compartido para funciones públicas de Editorial Nazarí ───────────────
const _NAZARI_CORS = [
  "https://www.editorialnazari.com",
  "https://editorialnazari.com",
  "https://seashell-boar-580681.hostingersite.com",
  /^https?:\/\/.*\.hostingersite\.com$/,
  /^http:\/\/localhost(:\d+)?$/,  // localhost con cualquier puerto (Live Server, etc.)
  "null",                          // origen file:// para pruebas locales
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// recomendacionesNazari — Ventas cruzadas por autor
//
// GET/POST ?catalogo_ids=id1,id2   (IDs del carrito actual, separados por coma)
// Devuelve hasta 6 libros activos del mismo autor que NO estén ya en el carrito.
// ─────────────────────────────────────────────────────────────────────────────
export const recomendacionesNazari = onRequest(
  { region: REGION, cors: _NAZARI_CORS as unknown as string[] },
  async (req, res) => {
    const rawParam =
      (req.query.catalogo_ids as string) ??
      (req.query.catalogo_id  as string) ??
      (req.body?.catalogo_ids as string) ??
      (req.body?.catalogo_id  as string) ??
      "";

    const catalogoIds: string[] = rawParam
      .split(",")
      .map((s: string) => s.trim())
      .filter(Boolean)
      .slice(0, 20);

    // Autores enviados directamente desde el carrito (más fiable que el lookup por ID)
    const autoresParam: string[] = (
      Array.isArray(req.query.autor)
        ? (req.query.autor as string[])
        : req.query.autor ? [(req.query.autor as string)] : []
    ).map((s: string) => s.trim()).filter(Boolean);

    if (!catalogoIds.length && !autoresParam.length) {
      res.status(400).json({ error: "Se requiere catalogo_ids o autor" });
      return;
    }

    const col = db
      .collection("empresas").doc(NAZARI_EMPRESA_ID)
      .collection("catalogo_web");

    const autores = new Set<string>();
    const excluidos = new Set<string>(catalogoIds);

    // 1. Usar autores del parámetro si vienen (camino rápido, sin lookup en Firestore)
    autoresParam.forEach(a => autores.add(a));

    // 2. Si no vinieron autores en el parámetro, buscar en Firestore por doc ID o slug
    if (!autores.size && catalogoIds.length) {
      const carritoDocs = await Promise.all(catalogoIds.map(id => col.doc(id).get()));
      const idsNoEncontrados: string[] = [];

      for (let i = 0; i < carritoDocs.length; i++) {
        const snap = carritoDocs[i];
        if (!snap.exists) {
          idsNoEncontrados.push(catalogoIds[i]);
          continue;
        }
        const d = snap.data()!;
        const a = ((d.campo_autor ?? d.autor ?? d.nombre_autor ?? "") as string).trim();
        if (a) autores.add(a);
      }

      // Fallback por campo slug
      if (idsNoEncontrados.length > 0) {
        const slugSnap = await col
          .where("slug", "in", idsNoEncontrados.slice(0, 30))
          .get();
        for (const doc of slugSnap.docs) {
          const d = doc.data();
          const a = ((d.campo_autor ?? d.autor ?? d.nombre_autor ?? "") as string).trim();
          if (a) autores.add(a);
          excluidos.add(doc.id);
        }
      }
    }

    if (!autores.size) {
      res.status(200).json({ libros: [], autores: [] });
      return;
    }

    // Normalizar autor para comparación case-insensitive y sin tildes
    const norm = (s: string) =>
      s.toLowerCase()
        .normalize("NFD")
        .replace(/[̀-ͯ]/g, "")
        .replace(/\s+/g, " ")
        .trim();

    const autoresNorm = new Set([...autores].map(norm));

    // Leer todos los libros y filtrar en memoria
    // (no where("activo","==",true) porque docs sin el campo deben incluirse)
    const todosSnap = await col.get();

    type RecomItem = {
      catalogo_id: string; nombre: string; autor: string;
      precio: string; imagen_url: string; slug: string;
    };
    const recomendaciones: RecomItem[] = [];

    for (const doc of todosSnap.docs) {
      if (recomendaciones.length >= 6) break;
      if (excluidos.has(doc.id)) continue;
      const d = doc.data();
      if (d.activo === false) continue;
      const autorDoc = ((d.campo_autor ?? d.autor ?? d.nombre_autor ?? "") as string).trim();
      if (!autoresNorm.has(norm(autorDoc))) continue;
      recomendaciones.push({
        catalogo_id: doc.id,
        nombre:      (d.nombre ?? d.titulo ?? "Libro") as string,
        autor:       autorDoc,
        precio:      (d.precio ?? "") as string,
        imagen_url:  (d.imagen_url ?? "") as string,
        slug:        (d.slug ?? doc.id) as string,
      });
    }

    res.status(200).json({ libros: recomendaciones, autores: Array.from(autores) });
  }
);

// crearCheckoutNazari — movido a nazariEbooks.ts (re-exportado en línea 111)
// @ts-ignore -- duplicate eliminado; función activa en nazariEbooks.ts
const _crearCheckoutNazari_REMOVED = onRequest(
  { region: REGION, cors: _NAZARI_CORS as unknown as string[] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const isTest = req.body?.test === true || req.query?.test === "true";

    let stripe: Stripe;
    let connOpts: Stripe.RequestOptions | undefined;
    let modeLabel: string;
    try {
      const cfg = await getNazariStripeConfig(isTest);
      stripe    = cfg.stripe;
      connOpts  = cfg.connOpts;
      modeLabel = cfg.mode;
    } catch (e: any) {
      console.error("❌ Error configurando Stripe:", e.message);
      res.status(500).json({ error: e.message });
      return;
    }

    const rawItems: Array<{ catalogo_id?: string; cantidad?: number; titulo?: string }> =
      req.body?.items ?? [];

    if (!rawItems.length) {
      res.status(400).json({ error: "El carrito está vacío" });
      return;
    }

    // Zona de envío: "ES" | "EU" | "LATAM" | "WORLD" (default "ES")
    const zona = ((req.body?.zona as string) ?? "ES").toUpperCase().trim();
    if (!["ES","EU","LATAM","WORLD"].includes(zona)) {
      res.status(400).json({ error: `zona inválida: ${zona}. Valores: ES, EU, LATAM, WORLD` });
      return;
    }

    // Modo pack: aplica descuento leído de Firestore (el cliente no decide el %)
    const packMode: boolean = req.body?.pack_mode === true;

    // Validar que todos los items tienen catalogo_id
    for (const it of rawItems) {
      if (!it.catalogo_id) {
        res.status(400).json({ error: "Cada ítem debe incluir catalogo_id" });
        return;
      }
      const cantidad = it.cantidad ?? 1;
      if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 99) {
        res.status(400).json({ error: `cantidad inválida para ${it.catalogo_id}` });
        return;
      }
    }

    console.log(`🛒 [${modeLabel}] Creando checkout Nazarí — ${rawItems.length} ítem(s) | zona: ${zona}`);

    try {
      // Resolver precio + peso de CADA item desde Firestore (fuente de verdad)
      const resolved = await Promise.all(
        rawItems.map(async (it) => ({
          catalogoId: it.catalogo_id!,
          cantidad:   it.cantidad ?? 1,
          item:       await _resolverItemCatalogoNazari(it.catalogo_id!),
        }))
      );

      // Pack: leer descuento desde Firestore (fuente de verdad, no del cliente)
      let packDescuentoPct = 0;
      if (packMode) {
        const packSnap = await db
          .collection("empresas").doc(NAZARI_EMPRESA_ID)
          .collection("configuracion").doc("pack_seleccion").get();
        const packData = packSnap.data() ?? {};
        if (packData.activo !== true) {
          res.status(400).json({ error: "El pack no está activo" });
          return;
        }
        packDescuentoPct = typeof packData.descuento_porcentaje === "number" ? packData.descuento_porcentaje : 0;
        console.log(`🎁 [${modeLabel}] Pack mode — descuento: ${packDescuentoPct}%`);
      }

      const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = resolved.map(
        ({ catalogoId, cantidad, item }) => {
          const precioFinal = packDescuentoPct > 0
            ? Math.round(item.precioNum * (1 - packDescuentoPct / 100))
            : item.precioNum;
          const pd: Stripe.Checkout.SessionCreateParams.LineItem.PriceData.ProductData = {
            name: item.nombre,
            metadata: { catalogo_id: catalogoId },
          };
          if (item.imagenUrl && /^https:\/\/.+/.test(item.imagenUrl)) pd.images = [item.imagenUrl];
          return {
            price_data: { currency: "eur", product_data: pd, unit_amount: precioFinal },
            quantity: cantidad,
          };
        }
      );

      const totalProductosEuros = resolved.reduce((s, { cantidad, item }) => {
        const pf = packDescuentoPct > 0 ? Math.round(item.precioNum * (1 - packDescuentoPct / 100)) : item.precioNum;
        return s + pf * cantidad;
      }, 0) / 100;
      const pesoTotalGramos     = resolved.reduce((s, { cantidad, item }) => s + item.pesoGramos * cantidad, 0);

      // ── Preventa: todos los libros del carrito deben estar en preventa ────────
      const esPreventa = resolved.length > 0 && resolved.every(({ item }) => item.preventa);

      // Opciones de envío y países permitidos según zona (y si es preventa)
      let shippingOptions: Stripe.Checkout.SessionCreateParams.ShippingOption[];
      let allowedCountries: AllowedCountry[];

      if (esPreventa && (zona === "ES" || zona === "EU")) {
        // Preventa + nacional/Europa → envío siempre gratuito
        shippingOptions = [{
          shipping_rate_data: {
            type: "fixed_amount",
            fixed_amount: { amount: 0, currency: "eur" },
            display_name: "Envío gratuito — Preventa (envío al publicarse)",
            delivery_estimate: {
              minimum: { unit: "business_day", value: 3 },
              maximum: { unit: "business_day", value: 10 },
            },
          },
        }];
        allowedCountries = zona === "EU" ? _PAISES_EUROPA : ["ES"];

      } else if (esPreventa && (zona === "LATAM" || zona === "WORLD")) {
        // Preventa + zona lejana → precio configurado en el libro (o tarifa estándar si no hay)
        const maxCents = resolved.reduce<number | null>((max, { item }) => {
          if (item.preventaEnvioLejanoCents == null) return max;
          return max == null ? item.preventaEnvioLejanoCents : Math.max(max, item.preventaEnvioLejanoCents);
        }, null);

        if (maxCents != null) {
          const precioStr = (maxCents / 100).toFixed(0);
          shippingOptions = [{
            shipping_rate_data: {
              type: "fixed_amount",
              fixed_amount: { amount: maxCents, currency: "eur" },
              display_name: `Envío preventa (envío al publicarse) — ${precioStr}€`,
              delivery_estimate: {
                minimum: { unit: "business_day", value: 14 },
                maximum: { unit: "business_day", value: 30 },
              },
            },
          }];
        } else {
          // Sin precio configurado → usar tarifa estándar de la zona
          shippingOptions = zona === "LATAM"
            ? _opcionesEnvioLatam(pesoTotalGramos)
            : _opcionesEnvioMundo(pesoTotalGramos);
        }
        allowedCountries = zona === "LATAM" ? _PAISES_LATAM : _PAISES_RESTO;

      } else {
        // Flujo normal (no preventa, o carrito mixto)
        switch (zona) {
          case "EU":
            shippingOptions  = _opcionesEnvioEuropa(pesoTotalGramos);
            allowedCountries = _PAISES_EUROPA;
            break;
          case "LATAM":
            shippingOptions  = _opcionesEnvioLatam(pesoTotalGramos);
            allowedCountries = _PAISES_LATAM;
            break;
          case "WORLD":
            shippingOptions  = _opcionesEnvioMundo(pesoTotalGramos);
            allowedCountries = _PAISES_RESTO;
            break;
          default: // "ES"
            shippingOptions  = _calcularOpcionesEnvioNazariES(totalProductosEuros, pesoTotalGramos);
            allowedCountries = ["ES"];
        }
      }

      console.log(`📦 [${modeLabel}] Total: ${totalProductosEuros.toFixed(2)}€ | Peso: ${pesoTotalGramos}g | Zona: ${zona} | Preventa: ${esPreventa} | Opciones: ${shippingOptions.length}`);

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        line_items: lineItems,
        metadata: {
          empresa_id:  NAZARI_EMPRESA_ID,
          tipo:        "pedido_nazari",
          zona_envio:  zona,
          es_preventa: esPreventa ? "true" : "false",
          es_pack:     packMode ? "true" : "false",
        },
        shipping_address_collection: { allowed_countries: allowedCountries },
        shipping_options: shippingOptions,
        success_url: "https://www.editorialnazari.com/gracias.html?session={CHECKOUT_SESSION_ID}",
        cancel_url:  "https://www.editorialnazari.com/catalogo.html",
      }, connOpts);

      console.log(`✅ [${modeLabel}] Checkout creado: ${session.url}`);
      res.status(200).json({ url: session.url, mode: modeLabel });
    } catch (error: any) {
      console.error(`❌ [${modeLabel}] Error creando checkout Nazarí:`, error.message);
      res.status(error.message?.includes("no encontrado") || error.message?.includes("no disponible") ? 404 : 500)
        .json({ error: error.message || "Error creando sesión de pago" });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// crearCheckoutTienda — Versión genérica de crearCheckoutNazari.
//   Crea sesión de Stripe Checkout para CUALQUIER empresa de Fluix.
//
// POST body: {
//   empresa_id:  string,           // ID Firestore de la empresa
//   items:       [{ titulo, precio, cantidad, imagen?, catalogo_id? }],
//   success_url: string,           // URL de éxito (la web de la empresa)
//   cancel_url:  string,           // URL de cancelación
// }
// Respuesta: { url: "https://checkout.stripe.com/..." }
// ─────────────────────────────────────────────────────────────────────────────
export const crearCheckoutTienda = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const empresaId: string  = req.body?.empresa_id  || "";
    const successUrl: string = req.body?.success_url || "";
    const cancelUrl: string  = req.body?.cancel_url  || "";
    const rawItems: Array<{ catalogo_id?: string; cantidad?: number; titulo?: string }> =
      req.body?.items ?? [];

    if (!empresaId) { res.status(400).json({ error: "empresa_id requerido" }); return; }
    if (!rawItems.length) { res.status(400).json({ error: "El carrito está vacío" }); return; }
    if (!successUrl || !cancelUrl) { res.status(400).json({ error: "success_url y cancel_url requeridos" }); return; }

    // Validar que todos los items tienen catalogo_id y cantidad válida
    for (const it of rawItems) {
      if (!it.catalogo_id) { res.status(400).json({ error: "Cada ítem debe incluir catalogo_id" }); return; }
      const cantidad = it.cantidad ?? 1;
      if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 99) {
        res.status(400).json({ error: `cantidad inválida para ${it.catalogo_id}` }); return;
      }
    }

    // Validar que la empresa tiene integración Stripe activa y obtener clave
    let secretKey = stripeSecretKey.value() || "";
    try {
      const integDoc = await db.collection("empresas").doc(empresaId)
        .collection("integraciones").doc("stripe").get();
      if (!integDoc.exists) {
        res.status(403).json({ error: "Empresa no habilitada para pagos" }); return;
      }
      const empresaKey: string = integDoc.data()?.secret_key || "";
      if (empresaKey) secretKey = empresaKey;
    } catch (_) { /* usa la global como fallback */ }

    if (!secretKey) { res.status(500).json({ error: "Pagos no configurados" }); return; }

    const stripe = new Stripe(secretKey, { apiVersion: "2024-06-20" });

    try {
      // Leer precio y datos de cada item desde catalogo_web de esa empresa (fuente de verdad)
      const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = await Promise.all(
        rawItems.map(async (it) => {
          const snap = await db
            .collection("empresas").doc(empresaId)
            .collection("catalogo_web").doc(it.catalogo_id!).get();

          if (!snap.exists) throw new Error(`Producto no encontrado: ${it.catalogo_id} en empresa ${empresaId}`);
          const d = snap.data()!;
          if (d.activo === false) throw new Error(`Producto no disponible: ${it.catalogo_id}`);

          const precioRaw = (d.precio ?? "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
          const precioNum = Math.round(parseFloat(precioRaw || "0") * 100);
          if (isNaN(precioNum) || precioNum <= 0) throw new Error(`Precio inválido: ${it.catalogo_id}`);

          const nombre   = (d.nombre ?? d.titulo ?? "Producto") as string;
          const imagenUrl = (d.imagen_url ?? "") as string;
          const pd: Stripe.Checkout.SessionCreateParams.LineItem.PriceData.ProductData = {
            name: nombre,
            metadata: { catalogo_id: it.catalogo_id! },
          };
          if (imagenUrl && /^https:\/\//.test(imagenUrl)) pd.images = [encodeURI(imagenUrl)];

          return {
            price_data: { currency: "eur", product_data: pd, unit_amount: precioNum },
            quantity: it.cantidad ?? 1,
          };
        })
      );

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        line_items: lineItems,
        metadata: { empresa_id: empresaId, tipo: "pedido_tienda" },
        shipping_address_collection: { allowed_countries: ["ES", "FR", "DE", "PT", "IT", "GB"] },
        success_url: successUrl,
        cancel_url:  cancelUrl,
      });

      res.status(200).json({ url: session.url });
    } catch (error: any) {
      console.error("❌ Error creando checkout tienda:", error.message);
      res.status(error.message?.includes("no encontrado") || error.message?.includes("no disponible") ? 404 : 500)
        .json({ error: error.message || "Error creando sesión de pago" });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// sincronizarLibroStripe — Sincroniza automáticamente libros de Nazarí con
//   Stripe cuando se crean o modifican en catalogo_web (fuente de verdad).
//
// Trigger: escritura en empresas/{empresaId}/catalogo_web/{itemId}
// Solo actúa si empresaId === NAZARI_EMPRESA_ID y STRIPE_SECRET_KEY está configurada.
// ─────────────────────────────────────────────────────────────────────────────

// Campos que escribe esta propia función en catalogo_web.
// Si solo cambian estos, ignoramos para evitar un bucle de triggers.
const _STRIPE_SYNC_FIELDS = new Set([
  "stripe_product_id", "stripe_price_id", "payment_link", "stripe_link",
  "stripe_sync_ts", "stripe_product_id_test", "stripe_price_id_test", "payment_link_test",
]);

export const sincronizarLibroStripe = onDocumentWritten(
  "empresas/{empresaId}/catalogo_web/{itemId}",
  async (event) => {
    if (event.params.empresaId !== NAZARI_EMPRESA_ID) return;
    if (!stripeSecretKey.value()) return;

    const after  = event.data?.after?.data();
    const before = event.data?.before?.data();
    const docRef = event.data?.after?.ref ?? event.data?.before?.ref;
    if (!docRef) return;

    // Guard 1: solo cambiaron campos que nosotros mismos escribimos → bucle, salir
    if (after && before) {
      const changed = Object.keys({ ...after, ...before }).filter(k => {
        const av = after[k]; const bv = before[k];
        // Timestamps del servidor siempre difieren — tratarlos como sin cambio real
        if (av && bv && typeof av === "object" && "_seconds" in av && typeof bv === "object" && "_seconds" in bv) return false;
        return JSON.stringify(av) !== JSON.stringify(bv);
      });
      if (changed.length === 0) {
        console.log(`⏭️ [sincronizarLibroStripe] Solo timestamps cambiaron — skip`);
        return;
      }
      if (changed.length > 0 && changed.every(k => _STRIPE_SYNC_FIELDS.has(k))) {
        console.log(`⏭️ [sincronizarLibroStripe] Solo campos Stripe cambiaron — ignorando para evitar bucle`);
        return;
      }
    }

    // Guard 2: migración masiva — si solo cambiaron campos de migración y el item ya tiene
    // stripe_product_id, no hay nada que hacer en Stripe
    const _MIGRATION_FIELDS = new Set(["nombre","titulo","descripcion","precio","precio_digital",
      "imagen_url","imagen","activo","orden","slug","tag","categoria","genero","campo_autor","autor",
      "campo_isbn","campo_paginas","campo_formato","campo_dimensiones","campo_anio","campo_mes",
      "origen","guardado_en","migrado_en","fecha_actualizacion","fecha_creacion",
      // Campos de envío y preventa — no afectan al producto/precio de Stripe
      "campo_peso","peso","peso_gramos","preventa","es_preventa","preventa_envio_lejano",
      // Campos de sección/web
      "seccion_id","es_libro_del_mes","novedades","en_seleccion"]);
    if (after && before && after.stripe_product_id) {
      const realChanged = Object.keys({ ...after, ...before }).filter(k => {
        const av = after[k]; const bv = before[k];
        if (av && bv && typeof av === "object" && "_seconds" in av && typeof bv === "object" && "_seconds" in bv) return false;
        return JSON.stringify(av) !== JSON.stringify(bv);
      });
      if (realChanged.every(k => _MIGRATION_FIELDS.has(k) || _STRIPE_SYNC_FIELDS.has(k))) {
        // Solo campos de migración cambiaron y ya tiene stripe_product_id → nada que hacer
        // (el nombre/precio se actualizará si realmente cambiaron en la próxima edición real)
        const precioActualStr = (after.precio ?? "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
        const precioAnteriorStr = (before.precio ?? "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
        const nombreCambio = after.nombre !== before.nombre;
        const precioCambio = Math.abs(parseFloat(precioActualStr || "0") - parseFloat(precioAnteriorStr || "0")) > 0.01;
        if (!nombreCambio && !precioCambio && !(after.activo === false && before.activo === true)) {
          console.log(`⏭️ [sincronizarLibroStripe] Migración masiva sin cambios relevantes — skip (${docRef.id})`);
          return;
        }
      }
    }

    let stripe: Stripe;
    let connOpts: Stripe.RequestOptions | undefined;
    try {
      const cfg = await getNazariStripeConfig(false);
      stripe    = cfg.stripe;
      connOpts  = cfg.connOpts;
    } catch (e: any) {
      console.error("❌ [LIVE] Config Stripe:", e.message);
      return;
    }

    // Item desactivado o eliminado → archivar producto en Stripe
    if (!after || after.activo === false) {
      if (before?.stripe_product_id) {
        try {
          await stripe.products.update(before.stripe_product_id, { active: false }, connOpts);
          console.log(`📦 [LIVE] Item ${docRef.id} archivado en Stripe`);
        } catch (e) {
          console.warn("⚠️ [LIVE] No se pudo archivar en Stripe:", e);
        }
      }
      return;
    }

    // Normalizar campos: catalogo_web usa nombre/campo_autor/descripcion/campo_isbn
    const titulo  = (after.nombre ?? after.titulo ?? "Libro") as string;
    const autor   = (after.campo_autor ?? after.autor ?? "") as string;
    const desc    = (after.descripcion ?? after.sinopsis ?? "") as string;
    const isbn    = (after.campo_isbn ?? after.isbn ?? "") as string;
    const imagen  = (after.imagen_url ?? "") as string;

    const parsePrecio = (p: string) =>
      Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
    const precioActual   = parsePrecio(after.precio);
    const precioAnterior = before ? parsePrecio(before.precio) : null;

    // ── Producto ──────────────────────────────────────────────────────────────
    let stripeProductId: string = after.stripe_product_id || "";
    const productBase = {
      name:     titulo,
      metadata: { catalogo_id: docRef.id, empresa_id: NAZARI_EMPRESA_ID, autor, isbn },
      ...(desc   ? { description: desc.slice(0, 500) }               : {}),
      ...(imagen && /^https:\/\//.test(imagen) ? { images: [encodeURI(imagen)] } : {}),
    };
    try {
      if (!stripeProductId) {
        const prod = await stripe.products.create(productBase as Stripe.ProductCreateParams, connOpts);
        stripeProductId = prod.id;
        console.log(`✅ [LIVE] Producto creado: ${stripeProductId} ("${titulo}")`);
      } else {
        await stripe.products.update(stripeProductId, productBase as unknown as Stripe.ProductUpdateParams, connOpts);
        console.log(`🔄 [LIVE] Producto actualizado: ${stripeProductId}`);
      }
    } catch (e) {
      console.error("❌ [LIVE] Error en producto Stripe:", e);
      return;
    }

    // ── Precio ────────────────────────────────────────────────────────────────
    let stripePriceId: string = after.stripe_price_id || "";
    const precioChanged = precioActual > 0 && (precioActual !== precioAnterior || !stripePriceId);
    if (precioChanged) {
      try {
        // Stripe Prices son inmutables en importe → archivar el anterior y crear nuevo
        if (stripePriceId) await stripe.prices.update(stripePriceId, { active: false }, connOpts);
        const price = await stripe.prices.create(
          { product: stripeProductId, unit_amount: precioActual, currency: "eur" },
          connOpts
        );
        stripePriceId = price.id;
        console.log(`💶 [LIVE] Precio: ${stripePriceId} (${precioActual / 100} €)`);
      } catch (e) {
        console.error("❌ [LIVE] Error en precio Stripe:", e);
      }
    }

    // ── Payment Link ──────────────────────────────────────────────────────────
    let paymentLink: string = after.payment_link || "";
    if (stripePriceId && (!paymentLink || precioChanged)) {
      try {
        const pl = await stripe.paymentLinks.create({
          line_items: [{ price: stripePriceId, quantity: 1 }],
          metadata: {
            empresa_id:   NAZARI_EMPRESA_ID,
            tipo:         "pedido_nazari",
            libro_id:     docRef.id,
            libro_titulo: titulo,
            precio_str:   (after.precio as string) || "",
          },
        }, connOpts);
        paymentLink = pl.url;
        console.log(`🔗 [LIVE] Payment Link: ${paymentLink}`);
      } catch (e) {
        console.error("❌ [LIVE] Error en Payment Link:", e);
      }
    }

    // ── Escribir IDs de Stripe de vuelta en catalogo_web ──────────────────────
    // Estos campos están en _STRIPE_SYNC_FIELDS → el guard anti-loop los ignorará
    await docRef.update({
      stripe_product_id: stripeProductId,
      stripe_price_id:   stripePriceId,
      ...(paymentLink ? { payment_link: paymentLink, stripe_link: paymentLink } : {}),
      stripe_sync_ts:    admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`📝 [LIVE] OK → product: ${stripeProductId} | price: ${stripePriceId} | link: ${paymentLink || "n/a"}`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// sincronizarLibroStripeTest — Sincroniza UN libro específico de Nazarí en el
//   entorno TEST de Stripe. Idempotente: omite si ya existe, --force lo rehace.
//   Guarda los IDs TEST en campos _test separados, sin tocar los LIVE.
//
// Uso:
//   curl -X POST \
//     -H "x-sync-secret: fluix-stripe-test-2026" \
//     -H "Content-Type: application/json" \
//     -d '{"libroId":"ID_DEL_LIBRO"}' \
//     https://REGION-planeaapp-4bea4.cloudfunctions.net/sincronizarLibroStripeTest
//
//   Añadir {"force":true} para regenerar aunque ya existan los IDs TEST.
// ─────────────────────────────────────────────────────────────────────────────
export const sincronizarLibroStripeTest = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ error: "POST requerido" }); return; }
    if (!STRIPE_SYNC_SECRET || req.headers["x-sync-secret"] !== STRIPE_SYNC_SECRET) {
      res.status(401).json({ error: "No autorizado" }); return;
    }

    const libroId: string = req.body?.libroId || "";
    const force:   boolean = req.body?.force === true;
    if (!libroId) { res.status(400).json({ error: "Falta libroId" }); return; }

    let stripe: Stripe;
    let connOpts: Stripe.RequestOptions | undefined;
    let mode: string;
    try {
      const cfg = await getNazariStripeConfig(true);
      stripe    = cfg.stripe;
      connOpts  = cfg.connOpts;
      mode      = cfg.mode;
    } catch (e: any) {
      console.error("❌ [TEST] Config Stripe:", e.message);
      res.status(500).json({ error: e.message }); return;
    }

    const libroRef  = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("libros").doc(libroId);
    const libroSnap = await libroRef.get();
    if (!libroSnap.exists) { res.status(404).json({ error: `Libro ${libroId} no encontrado` }); return; }
    const libro = libroSnap.data()!;

    console.log(`🧪 [${mode}] Sincronizando "${libro.titulo}" (${libroId})`);

    const parsePrecio = (p: string) =>
      Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
    const precioNum = parsePrecio(libro.precio);

    // ── Producto ──────────────────────────────────────────────────────────────
    let productId: string = libro.stripe_product_id_test || "";
    if (!productId || force) {
      const pd: Stripe.ProductCreateParams = {
        name: libro.titulo || "Libro",
        metadata: { catalogo_id: libroId, empresa_id: NAZARI_EMPRESA_ID, autor: libro.autor || "", isbn: libro.isbn || "", mode: "test" },
      };
      if (libro.sinopsis)   pd.description = (libro.sinopsis as string).slice(0, 500);
      if (libro.imagen_url && /^https:\/\//.test(libro.imagen_url as string)) pd.images = [encodeURI(libro.imagen_url as string)];

      if (productId && force) {
        await stripe.products.update(productId, pd as unknown as Stripe.ProductUpdateParams, connOpts);
        console.log(`🔄 [${mode}] Producto actualizado: ${productId}`);
      } else {
        const prod = await stripe.products.create(pd, connOpts);
        productId  = prod.id;
        console.log(`✅ [${mode}] Producto creado: ${productId}`);
      }
    } else {
      console.log(`⏭  [${mode}] Producto ya existe: ${productId}`);
    }

    // ── Precio ────────────────────────────────────────────────────────────────
    let priceId: string = libro.stripe_price_id_test || "";
    if ((!priceId || force) && precioNum > 0) {
      if (priceId && force) await stripe.prices.update(priceId, { active: false }, connOpts);
      const price = await stripe.prices.create(
        { product: productId, unit_amount: precioNum, currency: "eur" },
        connOpts
      );
      priceId = price.id;
      console.log(`💶 [${mode}] Precio: ${priceId} (${precioNum / 100} €)`);
    } else {
      console.log(`⏭  [${mode}] Precio ya existe: ${priceId}`);
    }

    // ── Payment Link ──────────────────────────────────────────────────────────
    let paymentLinkUrl: string = libro.payment_link_test || "";
    if ((!paymentLinkUrl || force) && priceId) {
      const pl = await stripe.paymentLinks.create({
        line_items: [{ price: priceId, quantity: 1 }],
        metadata: {
          empresa_id:    NAZARI_EMPRESA_ID,
          tipo:          "pedido_nazari",
          libro_id:      libroId,
          libro_titulo:  (libro.titulo as string) || "Libro",
          precio_str:    (libro.precio as string) || "",
        },
      }, connOpts);
      paymentLinkUrl = pl.url;
      console.log(`🔗 [${mode}] Payment Link: ${paymentLinkUrl}`);
    } else {
      console.log(`⏭  [${mode}] Payment Link ya existe: ${paymentLinkUrl}`);
    }

    // ── Firestore ─────────────────────────────────────────────────────────────
    await libroRef.update({
      stripe_product_id_test: productId,
      stripe_price_id_test:   priceId,
      payment_link_test:      paymentLinkUrl,
      stripe_test_sync_ts:    admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`📝 [${mode}] OK → product: ${productId} | price: ${priceId} | link: ${paymentLinkUrl}`);

    res.status(200).json({
      modo:          mode,
      libro_id:      libroId,
      titulo:        libro.titulo,
      product_id:    productId,
      price_id:      priceId,
      payment_link:  paymentLinkUrl,
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// migrarLibrosStripe — Migración puntual: sube todos los libros existentes de
//   Nazarí a Stripe. Llamar UNA sola vez via GET con el header secreto.
//
// Uso:
//   curl -H "x-migration-secret: fluix-migrate-2026" \
//     https://europe-west1-planeaapp-4bea4.cloudfunctions.net/migrarLibrosStripe
// ─────────────────────────────────────────────────────────────────────────────
// ── Test: crea pedido de prueba para verificar notificaciones ────────────────
export const crearPedidoPruebaTest = onRequest(
  { region: REGION },
  async (req, res) => {
    if (!STRIPE_SYNC_SECRET || req.headers["x-sync-secret"] !== STRIPE_SYNC_SECRET) {
      res.status(401).json({ error: "No autorizado" }); return;
    }
    const libroId = (req.body?.libroId || "33-suenos") as string;
    const libroSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("libros").doc(libroId).get();
    const libro = libroSnap.data() ?? {};
    const totalEuros = parseFloat((libro.precio as string || "10").replace(",", ".").replace(/[^0-9.]/g, ""));
    const contadorRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("contadores").doc("tickets");
    let numTicket = 1;
    const contSnap = await contadorRef.get();
    numTicket = contSnap.exists ? ((contSnap.data()?.ultimo as number) ?? 0) + 1 : 1;
    await contadorRef.set({ ultimo: numTicket }, { merge: true });
    const pedidoRef = await db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("pedidos").add({
      empresa_id: NAZARI_EMPRESA_ID, numero_ticket: numTicket,
      cliente_nombre: "Cliente Prueba TEST", cliente_correo: "test@test.com",
      origen: "web_nazari", estado: "pendiente", estado_pago: "pagado", metodo_pago: "tarjeta",
      lineas: [{ libro_id: libroId, producto_nombre: libro.titulo || libroId, cantidad: 1, precio_unitario: parseFloat((totalEuros/1.04).toFixed(2)), porcentaje_iva: 4 }],
      subtotal: parseFloat((totalEuros/1.04).toFixed(2)), importe_iva: parseFloat((totalEuros - totalEuros/1.04).toFixed(2)), total: totalEuros,
      livemode: false, notas_internas: "PEDIDO DE PRUEBA — borrar después",
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
      fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Notificación directa (onNuevoPedido salta web_nazari para evitar duplicados)
    const cuerpoTest = `Cliente Prueba TEST — €${totalEuros.toFixed(2)} (web Editorial Nazarí · TEST)`;
    try {
      await db.collection("notificaciones").doc(NAZARI_EMPRESA_ID).collection("items").add({
        titulo: "📦 Nuevo Pedido Web (TEST)",
        cuerpo: cuerpoTest,
        tipo: "pedidoNuevo",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "pedidos",
        entidad_id: pedidoRef.id,
        remitente_nombre: "Cliente Prueba TEST",
        remitente_email: "test@test.com",
      });
      await enviarNotificacionEmpresa(NAZARI_EMPRESA_ID, "📦 Nuevo Pedido Web (TEST)", cuerpoTest,
        { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "web_nazari" });
    } catch (_) {}
    console.log(`🧪 Pedido prueba #${numTicket} creado: ${pedidoRef.id}`);
    res.status(200).json({ pedido_id: pedidoRef.id, numero_ticket: numTicket, mensaje: "Pedido + notificación creados directamente" });
  }
);

export const migrarLibrosStripe = onRequest(
  { region: REGION, timeoutSeconds: 540 },
  async (req, res) => {
    if (req.headers["x-migration-secret"] !== "fluix-migrate-2026") {
      res.status(401).json({ error: "No autorizado" });
      return;
    }

    const secretKey: string = stripeSecretKey.value() || "";
    if (!secretKey) {
      res.status(500).json({ error: "STRIPE_SECRET_KEY no configurada" });
      return;
    }

    const stripe = new Stripe(secretKey, { apiVersion: "2024-06-20" });
    const parsePrecio = (p: string) =>
      Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);

    const snap = await db
      .collection("empresas")
      .doc(NAZARI_EMPRESA_ID)
      .collection("libros")
      .get();

    const resultados: Array<{ id: string; titulo: string; estado: string; stripe_product_id?: string }> = [];

    for (const doc of snap.docs) {
      const libro = doc.data();

      if (libro.stripe_product_id) {
        resultados.push({ id: doc.id, titulo: libro.titulo, estado: "ya_sincronizado", stripe_product_id: libro.stripe_product_id });
        continue;
      }

      try {
        const productData: Stripe.ProductCreateParams = {
          name:     libro.titulo || "Libro",
          metadata: {
            catalogo_id: doc.id,
            empresa_id:  NAZARI_EMPRESA_ID,
            autor:        libro.autor  || "",
            isbn:         libro.isbn   || "",
          },
        };
        if (libro.sinopsis)   productData.description = (libro.sinopsis as string).slice(0, 500);
        if (libro.imagen_url) productData.images      = [encodeURI(libro.imagen_url as string)];

        const prod = await stripe.products.create(productData);

        let stripePriceId = "";
        const precioNum = parsePrecio(libro.precio);
        if (precioNum > 0) {
          const price = await stripe.prices.create({
            product:     prod.id,
            unit_amount: precioNum,
            currency:    "eur",
          });
          stripePriceId = price.id;
        }

        await doc.ref.update({
          stripe_product_id: prod.id,
          stripe_price_id:   stripePriceId,
          stripe_sync_ts:    admin.firestore.FieldValue.serverTimestamp(),
        });

        resultados.push({ id: doc.id, titulo: libro.titulo, estado: "creado", stripe_product_id: prod.id });
        // pequeña pausa para respetar rate limits de Stripe
        await new Promise(r => setTimeout(r, 80));
      } catch (e: any) {
        resultados.push({ id: doc.id, titulo: libro.titulo, estado: `error: ${e.message}` });
      }
    }

    const creados = resultados.filter(r => r.estado === "creado").length;
    const yaSync  = resultados.filter(r => r.estado === "ya_sincronizado").length;
    const errores = resultados.filter(r => r.estado.startsWith("error")).length;

    console.log(`✅ Migración completada: ${creados} creados, ${yaSync} ya sincronizados, ${errores} errores`);
    res.status(200).json({ resumen: { creados, ya_sincronizados: yaSync, errores }, detalle: resultados });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// auditarStripeCatalogo — Audita y sincroniza Stripe vs catalogo_web.
//
// Callable desde Fluix (Firebase callable function).
// Requiere que el usuario sea admin de la empresa Nazarí.
//
// Modos (parámetro `modo`):
//   "diagnostico"    → solo lee, no escribe (default)
//   "limpiar"        → archiva en Stripe productos sin catálogo activo
//   "crear_faltantes"→ crea productos Stripe para libros sin stripe_product_id
//   "full"           → limpiar + crear_faltantes
// ─────────────────────────────────────────────────────────────────────────────
export const auditarStripeCatalogo = onCall(
  { region: REGION },
  async (request) => {
    // Solo permite usuarios autenticados de la empresa Nazarí
    if (!request.auth) throw new HttpsError("unauthenticated", "Autenticación requerida");

    const modo: string = (request.data?.modo as string) || "diagnostico";
    const limpiar         = modo === "limpiar"   || modo === "full";
    const crearFaltantes  = modo === "crear_faltantes" || modo === "full";

    const key = stripeSecretKey.value();
    if (!key) throw new HttpsError("failed-precondition", "STRIPE_SECRET_KEY no configurada");

    const stripe = new Stripe(key, { apiVersion: "2024-06-20" });

    // Stripe Connect optional
    let connOpts: Stripe.RequestOptions | undefined;
    try {
      const integSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("integraciones").doc("stripe").get();
      const acct = integSnap.data()?.stripe_account_id ?? "";
      if (acct) connOpts = { stripeAccount: acct };
    } catch (_) {}

    // ── Leer todos los productos de Stripe ──────────────────────────────────
    const stripeProds: Stripe.Product[] = [];
    let startingAfter: string | undefined;
    while (true) {
      const params: Stripe.ProductListParams = { limit: 100 };
      if (startingAfter) params.starting_after = startingAfter;
      const page = await stripe.products.list(params, connOpts);
      stripeProds.push(...page.data);
      if (!page.has_more) break;
      startingAfter = page.data[page.data.length - 1].id;
    }

    // ── Leer catalogo_web ───────────────────────────────────────────────────
    const catSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
      .collection("catalogo_web").get();
    type CatDoc = { id: string; activo?: boolean; stripe_product_id?: string; [k: string]: any };
    const catDocs: CatDoc[] = catSnap.docs.map(d => ({ id: d.id, ...(d.data() as Record<string, any>) }));
    const catIds  = new Set(catDocs.map(d => d.id));

    // ── Análisis ────────────────────────────────────────────────────────────
    const byMeta = new Map<string, Stripe.Product[]>();
    for (const p of stripeProds) {
      const cid = p.metadata?.catalogo_id ?? "";
      if (cid) {
        if (!byMeta.has(cid)) byMeta.set(cid, []);
        byMeta.get(cid)!.push(p);
      }
    }

    const orphans:    string[] = [];
    const duplicates: string[] = [];
    const sinStripe:  string[] = [];

    for (const [cid, prods] of byMeta.entries()) {
      const doc = catDocs.find(d => d.id === cid);
      const enFirestore = catIds.has(cid);
      if (!enFirestore || doc?.activo === false) {
        orphans.push(...prods.filter(p => p.active).map(p => p.id));
      } else {
        const activos = prods.filter(p => p.active);
        if (activos.length > 1) {
          const canonical = doc?.stripe_product_id;
          duplicates.push(...activos.filter(p => p.id !== canonical).map(p => p.id));
        }
      }
    }
    for (const doc of catDocs) {
      if (doc.activo === false) continue;
      if (!doc.stripe_product_id) sinStripe.push(doc.id);
    }

    const sinMeta = stripeProds.filter(p => p.active && !p.metadata?.catalogo_id).length;

    let archivados = 0, creados = 0, errores = 0;

    // ── Archivar orphans + duplicados ───────────────────────────────────────
    if (limpiar) {
      const toArchive = [...new Set([...orphans, ...duplicates])];
      for (const pid of toArchive) {
        try {
          await stripe.products.update(pid, { active: false }, connOpts);
          archivados++;
          await new Promise(r => setTimeout(r, 80));
        } catch (e: any) {
          console.warn(`⚠️ No se pudo archivar ${pid}: ${e.message}`);
          errores++;
        }
      }
    }

    // ── Crear productos faltantes ───────────────────────────────────────────
    if (crearFaltantes) {
      const col = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("catalogo_web");
      for (const itemId of sinStripe) {
        const docSnap = await col.doc(itemId).get();
        if (!docSnap.exists) continue;
        const d = docSnap.data()!;
        const titulo  = (d.nombre ?? d.titulo ?? "Libro") as string;
        const autor   = (d.campo_autor ?? d.autor ?? "") as string;
        const desc    = (d.descripcion ?? "") as string;
        const isbn    = (d.campo_isbn ?? d.isbn ?? "") as string;
        const imagen  = (d.imagen_url ?? "") as string;
        const parsePrecio = (p: string) =>
          Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
        const precio = parsePrecio(d.precio as string);
        try {
          const prod = await stripe.products.create({
            name:        titulo,
            ...(desc  ? { description: desc.slice(0, 500) }                    : {}),
            ...(imagen && /^https:\/\//.test(imagen) ? { images: [encodeURI(imagen)] } : {}),
            metadata:    { catalogo_id: itemId, empresa_id: NAZARI_EMPRESA_ID, autor, isbn },
          }, connOpts);
          let priceId = "";
          if (precio > 0) {
            const price = await stripe.prices.create(
              { product: prod.id, unit_amount: precio, currency: "eur" }, connOpts);
            priceId = price.id;
          }
          await col.doc(itemId).update({
            stripe_product_id: prod.id,
            ...(priceId ? { stripe_price_id: priceId } : {}),
            stripe_sync_ts: admin.firestore.FieldValue.serverTimestamp(),
          });
          creados++;
          await new Promise(r => setTimeout(r, 150));
        } catch (e: any) {
          console.warn(`⚠️ No se pudo crear producto para ${itemId}: ${e.message}`);
          errores++;
        }
      }
    }

    return {
      stripe_total:       stripeProds.length,
      stripe_activos:     stripeProds.filter(p => p.active).length,
      stripe_sin_meta:    sinMeta,
      orphans:            orphans.length,
      duplicados:         duplicates.length,
      catalogo_sin_stripe: sinStripe.length,
      catalogo_total:     catDocs.length,
      // Resultados de operaciones (solo si se ejecutaron)
      ...(limpiar          ? { archivados } : {}),
      ...(crearFaltantes   ? { creados    } : {}),
      ...(limpiar || crearFaltantes ? { errores } : {}),
    };
  }
);

// =============================================================================
// crearLinkPackNazari — HTTP function (autenticada con Firebase ID token)
// Crea un Stripe Payment Link para el pack de La Selección Nazarí y guarda la
// URL en empresas/{EID}/configuracion/pack_seleccion.stripe_link
// POST (sin body necesario) — Authorization: Bearer <firebase-id-token>
// =============================================================================

export const crearLinkPackNazari = onRequest(
  { region: REGION, timeoutSeconds: 120, memory: "256MiB", cors: false, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ error: "Method Not Allowed" }); return; }

    // Verificar Firebase ID token
    const authHeader = req.headers.authorization ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Token requerido" }); return;
    }
    try {
      await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
      res.status(401).json({ error: "Token inválido" }); return;
    }

    try {
      const { stripe, connOpts, mode } = await getNazariStripeConfig(false);

      // 1. Leer configuración del pack
      const packRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("configuracion").doc("pack_seleccion");
      const packSnap = await packRef.get();
      if (!packSnap.exists) { res.status(404).json({ error: "No hay configuración de pack" }); return; }
      const packData = packSnap.data()!;
      const descuentoPct: number = typeof packData.descuento_porcentaje === "number" ? packData.descuento_porcentaje : 0;
      const descripcion: string  = (packData.descripcion as string) || "Pack La Selección Nazarí";

      // 2. Leer libros del pack
      const selSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("seleccion_nazari")
        .where("en_pack", "==", true)
        .where("activo", "==", true)
        .orderBy("orden").limit(8).get();
      if (selSnap.empty) { res.status(400).json({ error: "No hay libros marcados en el pack" }); return; }

      // 3. Resolver precios y pesos
      const libros = await Promise.all(
        selSnap.docs.map(async (d) => {
          const catalogoId = (d.data().catalogo_id as string) || d.id;
          try {
            const item = await _resolverItemCatalogoNazari(catalogoId);
            return { catalogoId, precioNum: item.precioNum, pesoGramos: item.pesoGramos, nombre: item.nombre, imagenUrl: item.imagenUrl };
          } catch {
            const raw = ((d.data().precio as string) ?? "").replace(",", ".").replace(/[^0-9.]/g, "");
            return { catalogoId, precioNum: Math.round(parseFloat(raw || "0") * 100) || 0,
                     pesoGramos: 300, nombre: (d.data().titulo ?? "") as string, imagenUrl: (d.data().imagen ?? "") as string };
          }
        })
      );

      const totalOriginalCents = libros.reduce((s, l) => s + l.precioNum, 0);
      const packPriceCents      = Math.max(100, Math.round(totalOriginalCents * (1 - descuentoPct / 100)));
      const pesoTotal           = libros.reduce((s, l) => s + l.pesoGramos, 0);
      console.log(`🎁 [${mode}] Pack: ${libros.length} libros | original: ${(totalOriginalCents/100).toFixed(2)}€ | pack: ${(packPriceCents/100).toFixed(2)}€ | peso: ${pesoTotal}g`);

      // 4. Crear ShippingRates
      const mesAno = new Date().toLocaleDateString("es-ES", { month: "long", year: "numeric" });
      const tagMeta: Record<string,string> = { tipo: "pack_nazari", mes: mesAno };
      const esGratuito = (packPriceCents / 100) >= 30;
      const esOrdCents = esGratuito ? 0 : (pesoTotal <= 100 ? 150 : pesoTotal <= 500 ? 250 : 300);

      const [rateESOrd, rateESUrg, rateEU, rateIntl] = await Promise.all([
        stripe.shippingRates.create({
          display_name: esGratuito ? "Envío gratuito España (3-5 días laborables)" : `Envío ordinario España — ${(esOrdCents/100).toFixed(2).replace(".",",")}€`,
          type: "fixed_amount", fixed_amount: { amount: esOrdCents, currency: "eur" },
          delivery_estimate: { minimum: { unit: "business_day" as const, value: 3 }, maximum: { unit: "business_day" as const, value: 5 } }, metadata: tagMeta,
        }, connOpts),
        stripe.shippingRates.create({
          display_name: "Envío urgente España (24-48 h) — 6,00€",
          type: "fixed_amount", fixed_amount: { amount: 600, currency: "eur" },
          delivery_estimate: { minimum: { unit: "business_day" as const, value: 1 }, maximum: { unit: "business_day" as const, value: 2 } }, metadata: tagMeta,
        }, connOpts),
        stripe.shippingRates.create({
          display_name: `Envío Europa (7-14 días laborables) — ${pesoTotal < 500 ? "15" : "20"}€`,
          type: "fixed_amount", fixed_amount: { amount: pesoTotal < 500 ? 1500 : 2000, currency: "eur" },
          delivery_estimate: { minimum: { unit: "business_day" as const, value: 7 }, maximum: { unit: "business_day" as const, value: 14 } }, metadata: tagMeta,
        }, connOpts),
        stripe.shippingRates.create({
          display_name: `Envío internacional (14-30 días laborables) — ${pesoTotal < 500 ? "25" : "35"}€`,
          type: "fixed_amount", fixed_amount: { amount: pesoTotal < 500 ? 2500 : 3500, currency: "eur" },
          delivery_estimate: { minimum: { unit: "business_day" as const, value: 14 }, maximum: { unit: "business_day" as const, value: 30 } }, metadata: tagMeta,
        }, connOpts),
      ]);

      // 5. Crear Product + Price
      const imagenPack = (libros[0]?.imagenUrl && /^https:\/\/.+/.test(libros[0].imagenUrl)) ? libros[0].imagenUrl : undefined;
      const product = await stripe.products.create({
        name: `Pack La Seleccion Nazari — ${mesAno}`, description: descripcion,
        ...(imagenPack ? { images: [imagenPack] } : {}),
        metadata: { tipo: "pack_nazari", empresa_id: NAZARI_EMPRESA_ID },
      }, connOpts);
      const price = await stripe.prices.create({ currency: "eur", unit_amount: packPriceCents, product: product.id }, connOpts);

      // 6. Crear Payment Link
      const paymentLink = await stripe.paymentLinks.create({
        line_items: [{ price: price.id, quantity: 1 }],
        shipping_address_collection: {
          allowed_countries: ["ES","PT","FR","DE","IT","BE","NL","AT","PL","SE","DK","NO","FI","IE","GB","CH",
            "MX","AR","CO","PE","CL","UY","VE","EC","BO","PY","CR","GT","PA","US","CA"] as Stripe.PaymentLink.ShippingAddressCollection.AllowedCountry[],
        },
        shipping_options: [{ shipping_rate: rateESOrd.id },{ shipping_rate: rateESUrg.id },{ shipping_rate: rateEU.id },{ shipping_rate: rateIntl.id }],
        after_completion: { type: "redirect", redirect: { url: "https://www.editorialnazari.com/gracias.html" } },
        metadata: { tipo: "pack_nazari", empresa_id: NAZARI_EMPRESA_ID, descuento: String(descuentoPct), mes: mesAno },
      }, connOpts);

      // 7. Guardar en Firestore
      const precioPackStr     = (packPriceCents / 100).toFixed(2).replace(".", ",") + " €";
      const precioOriginalStr = (totalOriginalCents / 100).toFixed(2).replace(".", ",") + " €";
      await packRef.set({
        stripe_link: paymentLink.url, stripe_link_id: paymentLink.id, stripe_price_id: price.id,
        precio_pack: precioPackStr, precio_original: precioOriginalStr, peso_total_gramos: pesoTotal,
        link_generado_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`✅ [${mode}] Pack Payment Link: ${paymentLink.url}`);
      res.status(200).json({ url: paymentLink.url, precio_pack: precioPackStr, precio_original: precioOriginalStr, libros_count: libros.length });
    } catch (e: any) {
      console.error("❌ crearLinkPackNazari:", e.message);
      res.status(500).json({ error: e.message || "Error interno" });
    }
  }
);
