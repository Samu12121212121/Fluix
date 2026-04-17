import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import Stripe from "stripe";
import * as nodemailer from "nodemailer";
import { enviarRecordatoriosCitas } from "./recordatoriosCitas";
import { onTareaAsignada } from "./notificacionesTareas";
import {
  scheduledGenerarTareasRecurrentes,
  scheduledRecordatoriosTareas,
  scheduledTareasVencenHoy,
  onNuevaSugerencia,
} from "./tareasFunciones";
import { scheduledAlertaCertificado } from "./alertaCertificado";
import { verificarAuth, verificarAuthYEmpresa, verificarPropietarioPlataforma } from "./utils/authGuard";
import { verificarLoginIntento } from "./auth/fuerzaBruta";
import fetch from "node-fetch";
export { processInvoice } from "./fiscal/processInvoice";
export { calculateFiscalModel } from "./fiscal/models/calculateModel";

// NOTA: generarThumbnailCatalogo desactivado temporalmente por bug del CLI
// "Can't find the storage bucket region" — se reactiva tras actualizar firebase-tools
// export { generarThumbnailCatalogo } from "./catalogoFunciones";
export { scheduledAlertaPreciosAntiguos } from "./catalogoFunciones";
export { scheduledAlertaCertificado };
export { verificarLoginIntento };


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
const stripeSecretKey   = { value: () => process.env.STRIPE_SECRET_KEY   ?? "" };
const stripeWebhookSecret = { value: () => process.env.STRIPE_WEBHOOK_SECRET ?? "" };
const smtpHost          = { value: () => process.env.SMTP_HOST            ?? "" };
const smtpPort          = { value: () => process.env.SMTP_PORT            ?? "587" };
const smtpUser          = { value: () => process.env.SMTP_USER            ?? "" };
const smtpPass          = { value: () => process.env.SMTP_PASS            ?? "" };

// ── UTILIDADES ────────────────────────────────────────────────────────────────

async function obtenerTokensEmpresa(empresaId: string): Promise<string[]> {
  const col = db.collection("empresas").doc(empresaId).collection("dispositivos");

  // Primero intenta con filtro activo == true
  let snapshot = await col.where("activo", "==", true).get();

  // Si no hay resultados, coge todos (puede que el campo se llame diferente)
  if (snapshot.empty) {
    snapshot = await col.get();
  }

  const tokens: string[] = [];
  snapshot.forEach((doc) => {
    const token = doc.data().token as string | undefined;
    if (token && token.length > 10) tokens.push(token);
  });
  return tokens;
}

async function enviarNotificacionEmpresa(
  empresaId: string,
  titulo: string,
  cuerpo: string,
  data: Record<string, string> = {}
): Promise<void> {
  const tokens = await obtenerTokensEmpresa(empresaId);
  if (tokens.length === 0) {
    console.log(`No hay tokens para empresa ${empresaId}`);
    return;
  }

  const mensaje: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title: titulo, body: cuerpo },
    data: { empresa_id: empresaId, ...data },
    android: {
      priority: "high",
      notification: {
        channelId: "fluixcrm_canal_principal",
        sound: "default",
        priority: "high",
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
  };

  try {
    const respuesta = await messaging.sendEachForMulticast(mensaje);
    console.log(
      `✅ Notificaciones enviadas: ${respuesta.successCount}/${tokens.length}`
    );

    if (respuesta.failureCount > 0) {
      const tokensAEliminar: string[] = [];
      respuesta.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          if (
            error?.code === "messaging/registration-token-not-registered" ||
            error?.code === "messaging/invalid-registration-token"
          ) {
            tokensAEliminar.push(tokens[idx]);
          }
        }
      });

      if (tokensAEliminar.length > 0) {
        const dispositivosRef = db
          .collection("empresas")
          .doc(empresaId)
          .collection("dispositivos");
        const snapshotInvalidos = await dispositivosRef
          .where("token", "in", tokensAEliminar)
          .get();
        const batch = db.batch();
        snapshotInvalidos.forEach((doc) => {
          batch.update(doc.ref, { activo: false });
        });
        await batch.commit();
      }
    }
  } catch (error) {
    console.error("❌ Error enviando notificaciones:", error);
  }
}

// ── CLOUD FUNCTIONS (v2 API) ──────────────────────────────────────────────────

export { onTareaAsignada }; // Export it
export {
  scheduledGenerarTareasRecurrentes,
  scheduledRecordatoriosTareas,
  scheduledTareasVencenHoy,
  onNuevaSugerencia,
};

/**
 * 1. NUEVA RESERVA
 */
export const onNuevaReserva = onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const reservaId = event.params.reservaId;
    const reserva = event.data?.data();
    if (!reserva) return;

    const cliente = reserva.nombre_cliente || reserva.cliente || "Cliente";
    const telefonoVal = reserva.telefono_cliente as string | undefined;
    const emailVal    = reserva.email_cliente || reserva.email || (null as string | null);
    const telefono    = telefonoVal ? ` · ${telefonoVal}` : "";
    const personas    = reserva.personas ? ` · ${reserva.personas} pers.` : "";
    const servicio    = reserva.servicio || reserva.notas || "";
    const fechaHora   = reserva.fecha_hora
      ? (reserva.fecha_hora as string).replace("T", " a las ").substring(0, 16)
      : reserva.fecha?.toDate
        ? reserva.fecha.toDate().toLocaleString("es-ES")
        : "Fecha pendiente";

    const titulo = "📅 Nueva Reserva";
    const cuerpo = `${cliente}${telefono}${personas} — ${fechaHora}${servicio ? " · " + servicio : ""}`;

    // 1. Guardar en bandeja in-app con campos de remitente separados
    const bandejaData: Record<string, unknown> = {
      titulo,
      cuerpo,
      tipo: "reservaNueva",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      leida: false,
      modulo_destino: "reservas",
      entidad_id: reservaId,
      remitente_nombre: cliente !== "Cliente" ? cliente : null,
      remitente_telefono: telefonoVal || null,
      remitente_email: emailVal,
    };
    await db.collection("notificaciones").doc(empresaId).collection("items").add(bandejaData);

    // 2. Enviar push FCM
    await enviarNotificacionEmpresa(
      empresaId,
      titulo,
      cuerpo,
      { tipo: "nueva_reserva", reserva_id: reservaId }
    );

    console.log(`✅ Reserva guardada en bandeja y push enviado — empresa ${empresaId}`);
  }
);

/**
 * 2. RESERVA CANCELADA
 */
export const onReservaCancelada = onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;

    if (antes.estado === despues.estado || despues.estado !== "CANCELADA") {
      return;
    }

    const cliente  = despues.nombre_cliente || despues.cliente || "Cliente";
    const servicio = despues.servicio || despues.fecha_hora || "la reserva";
    const cuerpo   = `${cliente} canceló la reserva de ${servicio}`;

    // Guardar en bandeja in-app
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo: "❌ Reserva Cancelada",
      cuerpo,
      tipo: "reservaNueva",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      leida: false,
      modulo_destino: "reservas",
      entidad_id: event.params.reservaId,
      remitente_nombre: cliente !== "Cliente" ? cliente : null,
      remitente_telefono: despues.telefono_cliente || null,
      remitente_email: despues.email_cliente || null,
    });

    await enviarNotificacionEmpresa(
      empresaId,
      "❌ Reserva Cancelada",
      cuerpo,
      { tipo: "reserva_cancelada", reserva_id: event.params.reservaId }
    );
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
    const cuerpo   = `${cliente} — €${(total as number).toFixed(2)} (vía ${origen})`;

    // Guardar en bandeja in-app
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
      titulo:             "🛒 Nuevo Pedido",
      cuerpo,
      tipo:               "reservaNueva", // usamos reservaNueva como tipo genérico hasta añadir tipo pedido
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
      "🛒 Nuevo Pedido",
      cuerpo,
      { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId }
    );
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
        descripcion: l.producto_nombre || l.descripcion || "Producto",
        precio_unitario: (l.precio_unitario as number) || 0,
        cantidad: (l.cantidad as number) || 1,
        porcentaje_iva: 21.0,
        referencia: l.producto_id || null,
      }));

      const subtotal = lineasFactura.reduce(
        (sum, l) => sum + l.precio_unitario * l.cantidad,
        0
      );
      const totalIva = lineasFactura.reduce(
        (sum, l) => sum + l.precio_unitario * l.cantidad * (l.porcentaje_iva / 100),
        0
      );
      const total = subtotal + totalIva;

      const metodoPagoMap: Record<string, string> = {
        tarjeta: "tarjeta",
        paypal: "paypal",
        bizum: "bizum",
        efectivo: "efectivo",
      };
      const metodoPago = metodoPagoMap[pedido.metodo_pago as string] ?? null;

      const facturaData = {
        empresa_id: empresaId,
        numero_factura: numeroFactura,
        tipo: "pedido",
        estado: "pendiente",
        cliente_nombre: pedido.cliente_nombre || "Cliente",
        cliente_telefono: pedido.cliente_telefono || null,
        cliente_correo: pedido.cliente_correo || null,
        datos_fiscales: null,
        lineas: lineasFactura,
        subtotal: subtotal,
        total_iva: totalIva,
        total: total,
        metodo_pago: metodoPago,
        pedido_id: pedidoId,
        notas_internas: null,
        notas_cliente: pedido.notas_cliente || null,
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

/**
 * 6. NUEVA FACTURA PENDIENTE
 */
export const onNuevaFactura = onDocumentCreated(
  { document: "empresas/{empresaId}/facturas/{facturaId}", region: REGION },
  async (event) => {
    const empresaId = event.params.empresaId;
    const factura = event.data?.data();
    if (!factura) return;

    if (factura.estado !== "pendiente") return;

    const numero = factura.numero_factura || event.params.facturaId;
    const total = factura.total || 0;
    const cliente = factura.cliente_nombre || "Cliente";

    await enviarNotificacionEmpresa(
      empresaId,
      "🧾 Nueva Factura Pendiente",
      `${numero} — ${cliente} — €${total.toFixed(2)}`,
      { tipo: "nueva_factura", factura_id: event.params.facturaId }
    );
  }
);

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

/**
 * 9. GENERAR SCRIPT PERSONALIZADO (v2 onRequest)
 */
export const generarScriptEmpresa = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    try {
      const { empresaId, dominio } = req.query;

      if (!empresaId || typeof empresaId !== "string") {
        res.status(400).json({ error: "empresaId es requerido" });
        return;
      }

      const empresaDoc = await db.collection("empresas").doc(empresaId).get();

      if (!empresaDoc.exists) {
        res.status(404).json({ error: "Empresa no encontrada" });
        return;
      }

      const empresa = empresaDoc.data()!;
      const nombreEmpresa = empresa.nombre || "Mi Negocio";
      const dominiWeb = (dominio as string) || empresa.sitio_web || "midominio.com";

      const script = generarScriptHTML(empresaId, nombreEmpresa, dominiWeb);

      res.set("Content-Type", "text/html; charset=utf-8");
      res.set(
        "Content-Disposition",
        `attachment; filename="script-fluixcrm-${empresaId}.html"`
      );
      res.status(200).send(script);
    } catch (error) {
      console.error("❌ Error generando script:", error);
      res.status(500).json({ error: "Error generando script" });
    }
  }
);

function generarScriptHTML(
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

// ── ENDPOINT ALTERNATIVO: JSON ────────────────────────────────────────────

export const obtenerScriptJSON = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    try {
      const { empresaId } = req.query;

      if (!empresaId || typeof empresaId !== "string") {
        res.status(400).json({ error: "empresaId es requerido" });
        return;
      }

      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      if (!empresaDoc.exists) {
        res.status(404).json({ error: "Empresa no encontrada" });
        return;
      }

      const empresa = empresaDoc.data()!;
      const script = generarScriptHTML(
        empresaId,
        empresa.nombre || "Mi Negocio",
        empresa.sitio_web || "midominio.com"
      );

      res.status(200).json({
        exito: true,
        empresaId,
        nombre: empresa.nombre,
        dominio: empresa.sitio_web,
        script: script,
        instrucciones: "Pega este script en el footer de tu WordPress (antes del </body>)"
      });
    } catch (error) {
      console.error("❌ Error:", error);
      res.status(500).json({ error: "Error generando script" });
    }
  }
);

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

    const secretKey: string = stripeSecretKey.value() || "";
    const webhookSec: string = stripeWebhookSecret.value() || "";

    if (!secretKey) {
      console.error("❌ STRIPE_SECRET_KEY no configurada. Ejecuta: firebase functions:secrets:set STRIPE_SECRET_KEY");
      res.status(500).json({ error: "Stripe no configurado en el servidor" });
      return;
    }

    const stripe = new Stripe(secretKey, { apiVersion: "2024-06-20" });

    let event: Stripe.Event;
    try {
      const sig = req.headers["stripe-signature"] as string;
      const rawBody = (req as unknown as { rawBody: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));

      if (!webhookSec) {
        console.error("❌ STRIPE_WEBHOOK_SECRET no configurada");
        res.status(500).json({ error: "Webhook no configurado" });
        return;
      }
      if (!sig) {
        res.status(400).json({ error: "Firma de Stripe ausente" });
        return;
      }
      try {
        event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
      } catch (err) {
        console.error("❌ Firma Stripe inválida:", err);
        res.status(400).json({ error: "Firma inválida" });
        return;
      }
    } catch (err) {
      console.error("❌ Error verificando firma Stripe:", err);
      res.status(400).json({ error: `Webhook signature verification failed: ${err}` });
      return;
    }

    console.log(`📥 Stripe evento recibido: ${event.type} [${event.id}]`);

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object as Stripe.Checkout.Session;
          await _procesarCheckoutCompletado(session, db);
          break;
        }
        case "payment_intent.succeeded": {
          const pi = event.data.object as Stripe.PaymentIntent;
          if (pi.metadata?.empresa_id) {
            await _procesarPaymentIntentExitoso(pi, db);
          }
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
 *   firebase functions:secrets:set SMTP_HOST     (ej: smtp.gmail.com)
 *   firebase functions:secrets:set SMTP_PORT     (ej: 587)
 *   firebase functions:secrets:set SMTP_USER     (ej: noreply@fluixtech.com)
 *   firebase functions:secrets:set SMTP_PASS     (ej: app-password)
 */
export const enviarEmailConPdf = onCall(
  { region: REGION },
  async (request) => {
    const { destinatario, asunto, cuerpoHtml, pdfBase64, nombreArchivo, empresaId } = request.data;

    // ── AUTH GUARD ──
    if (empresaId) {
      await verificarAuthYEmpresa(request, empresaId);
    } else {
      verificarAuth(request);
    }

    if (!destinatario || !asunto || !pdfBase64) {
      throw new HttpsError("invalid-argument", "destinatario, asunto y pdfBase64 son requeridos");
    }

    const host = smtpHost.value();
    const port = parseInt(smtpPort.value() || "587", 10);
    const user = smtpUser.value();
    const pass = smtpPass.value();

    if (!host || !user || !pass) {
      throw new HttpsError(
        "failed-precondition",
        "SMTP no configurado. Ejecuta: firebase functions:secrets:set SMTP_HOST / SMTP_USER / SMTP_PASS"
      );
    }

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });

    // Obtener datos de la empresa para el remitente
    let nombreEmpresa = "Fluix CRM";
    if (empresaId) {
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      if (empresaDoc.exists) {
        nombreEmpresa = empresaDoc.data()?.nombre || "Fluix CRM";
      }
    }

    try {
      await transporter.sendMail({
        from: `"${nombreEmpresa}" <${user}>`,
        to: destinatario,
        subject: asunto,
        html: cuerpoHtml || `<p>Adjuntamos el documento solicitado.</p><p>— ${nombreEmpresa}</p>`,
        attachments: [
          {
            filename: nombreArchivo || "documento.pdf",
            content: Buffer.from(pdfBase64, "base64"),
            contentType: "application/pdf",
          },
        ],
      });

      console.log(`✅ Email enviado a ${destinatario} — ${asunto}`);
      return { exito: true, mensaje: `Email enviado a ${destinatario}` };
    } catch (error) {
      console.error("❌ Error enviando email:", error);
      throw new HttpsError(
        "internal",
        `Error enviando email: ${error instanceof Error ? error.message : "Desconocido"}`
      );
    }
  }
);

// ── FUNCIONES HELPER STRIPE ───────────────────────────────────────────────────

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
      const contador = (snap.data()?.ultimo_numero_factura as number) ?? 0;
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
        .collection("empresas").doc(empresaId)
        .collection("estadisticas").doc("web_resumen")
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
        .collection("empresas").doc(empresaId)
        .collection("estadisticas").doc(`visitas_${fechaHoy}`)
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

// ── GESTIÓN DE CUENTAS Y SUSCRIPCIONES (sin pasar por Apple/Google) ──────────
export {
  crearCuentaConPlan,
  actualizarPlanEmpresa,
  listarCuentasClientes,
  webhookPagoWeb,
} from "./gestionCuentas";

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
            payload: { aps: { sound: "default", badge: 1 } },
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

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO DE FINIQUITOS — Cloud Functions
// ═══════════════════════════════════════════════════════════════════════════════

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

    // Enviar email
    const transporter = nodemailer.createTransport({
      host: smtpHost.value(),
      port: parseInt(smtpPort.value()),
      secure: smtpPort.value() === "465",
      auth: { user: smtpUser.value(), pass: smtpPass.value() },
    });

    try {
      await transporter.sendMail({
        from: `"${nombreEmpresa}" <${smtpUser.value()}>`,
        to: emailDestino,
        subject: `Documentación de tu cese en ${nombreEmpresa}`,
        html: htmlEmail,
        attachments: adjuntos.map((a) => ({
          filename: a.filename,
          content: a.content,
          contentType: a.contentType,
        })),
      });
    } catch (e: any) {
      console.error("❌ Error enviando email:", e.message);
      throw new HttpsError("internal",
        `Error enviando email: ${e.message}. Verifica la configuración SMTP.`);
    }

    // Registrar en Firestore
    await db.collection("empresas").doc(empresaId)
      .collection("finiquitos").doc(finiquitoId).update({
        email_enviado: emailDestino,
        fecha_envio_email: admin.firestore.FieldValue.serverTimestamp(),
        documentos_enviados: documentosSeleccionados.filter(d => !erroresDescarga.includes(d)),
      });

    console.log(`✅ Documentación enviada a ${emailDestino} (${adjuntos.length} archivos)`);

    return {
      ok: true,
      archivosEnviados: adjuntos.length,
      errores: erroresDescarga,
    };
  }
);

// ── Notificación push cuando llega una reserva nueva desde la web ─────────────
// Trigger: onCreate en empresas/{empresaId}/reservas/{reservaId}
// Solo notifica cuando origen == 'web' (no spamea al admin con sus propias reservas manuales)
export const onReservaNueva = onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const empresaId = event.params.empresaId;
    const reservaId = event.params.reservaId;

    // Solo notificar reservas que vienen de la web
    const origen = data.origen ?? data.creado_por ?? '';
    if (origen !== 'web' && origen !== 'web_widget') {
      console.log(`ℹ️ Reserva ${reservaId} con origen '${origen}' — sin notificación`);
      return;
    }

    // Obtener tokens FCM de admins y propietarios de la empresa
    // Los usuarios están en la colección raíz con campo empresa_id
    const usuariosSnap = await db
      .collection('usuarios')
      .where('empresa_id', '==', empresaId)
      .where('rol', 'in', ['propietario', 'admin'])
      .where('activo', '==', true)
      .get();

    if (usuariosSnap.empty) {
      console.log(`⚠️ No hay admins/propietarios para empresa ${empresaId}`);
      return;
    }

    // Recoger todos los tokens válidos (token_dispositivo en el doc usuario)
    const tokens: string[] = [];
    for (const userDoc of usuariosSnap.docs) {
      const uData = userDoc.data();
      // Intentar primero en empresas/{id}/dispositivos (como hace notificacionesTareas)
      try {
        const dispositivoSnap = await db
          .collection('empresas').doc(empresaId)
          .collection('dispositivos').doc(userDoc.id)
          .get();
        const tokenDispositivo = dispositivoSnap.data()?.token;
        if (tokenDispositivo) { tokens.push(tokenDispositivo); continue; }
      } catch (_) { /* fallback */ }
      // Fallback: token_dispositivo en el doc usuario
      const tokenUsuario = uData.token_dispositivo as string | undefined;
      if (tokenUsuario) tokens.push(tokenUsuario);
    }

    if (tokens.length === 0) {
      console.log(`⚠️ Ningún admin de empresa ${empresaId} tiene token FCM registrado`);
      return;
    }

    // Construir el texto de la notificación
    const nombre = (data.nombre_cliente || data.nombre_cliente_web || 'Cliente desconocido') as string;
    const servicio = (data.servicio || data.servicio_nombre || '') as string;
    const fechaHoraRaw = data.fecha_hora as string | undefined;
    let fechaFormateada = 'Fecha pendiente';
    if (fechaHoraRaw) {
      try {
        fechaFormateada = new Date(fechaHoraRaw).toLocaleString('es-ES', {
          timeZone: 'Europe/Madrid',
          weekday: 'short',
          day: '2-digit',
          month: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
        });
      } catch (_) { fechaFormateada = fechaHoraRaw; }
    }

    const bodyParts = [nombre];
    if (servicio) bodyParts.push(servicio);
    bodyParts.push(fechaFormateada);

    const mensaje: admin.messaging.MulticastMessage = {
      notification: {
        title: '📅 Nueva reserva desde la web',
        body: bodyParts.join(' · '),
      },
      data: {
        tipo: 'reserva_nueva',
        empresa_id: empresaId,
        reserva_id: reservaId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'fluixcrm_canal_principal',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      tokens,
    };

    try {
      const result = await messaging.sendEachForMulticast(mensaje);
      console.log(`✅ Notificación reserva web enviada: ${result.successCount}/${tokens.length} tokens OK (empresa ${empresaId})`);
      if (result.failureCount > 0) {
        result.responses.forEach((r, i) => {
          if (!r.success) console.warn(`  ⚠️ Token[${i}] falló: ${r.error?.message}`);
        });
      }
    } catch (e: any) {
      console.error(`❌ Error enviando notificación reserva web:`, e.message);
    }
  }
);

