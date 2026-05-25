/**
 * notificaciones_cliente.ts
 * Sistema B2C de notificaciones para clientes finales (app Explorar / Fluix)
 * 8 tipos: reserva_confirmada, reserva_cancelada, recordatorio, flash_slot,
 *          promocion, solicitud_valoracion, sello_fidelizacion, bienvenida
 */

import * as functions from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();
const REGION = "europe-west1";
/** Campo donde el cliente guarda su token FCM (según NotificacionesService.dart) */
const TOKEN_FIELD = "token_dispositivo";

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CENTRAL: envía push FCM + crea notif in-app
// ─────────────────────────────────────────────────────────────────────────────

async function enviarNotifCliente(opts: {
  uid: string;
  titulo: string;
  cuerpo: string;
  tipo: string;
  extra?: Record<string, string>;
}): Promise<void> {
  const { uid, titulo, cuerpo, tipo, extra = {} } = opts;

  const userSnap = await db.collection("usuarios").doc(uid).get();
  if (!userSnap.exists) return;

  // ── Guardar notificación in-app ──────────────────────────────────────────
  await db
    .collection("usuarios")
    .doc(uid)
    .collection("notificaciones")
    .add({
      titulo,
      cuerpo,
      tipo,
      creado_en: admin.firestore.FieldValue.serverTimestamp(),
      leida: false,
      ...extra,
    });

  // ── Enviar push FCM ──────────────────────────────────────────────────────
  const token = userSnap.data()?.[TOKEN_FIELD] as string | undefined;
  if (!token) return;

  try {
    await admin.messaging().send({
      token,
      notification: { title: titulo, body: cuerpo },
      data: { tipo, ...extra },
      android: {
        priority: "high",
        notification: { channelId: "fluixcrm_canal_principal", sound: "default" },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err: any) {
    if (err?.errorInfo?.code === "messaging/registration-token-not-registered") {
      // Token inválido → limpiar para evitar reenvíos fallidos
      await db
        .collection("usuarios")
        .doc(uid)
        .update({ [TOKEN_FIELD]: admin.firestore.FieldValue.delete() });
      functions.logger.warn(`[NotifCliente] token inválido eliminado para uid=${uid}`);
    } else {
      functions.logger.error("[NotifCliente] error FCM:", err);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. RESERVA CONFIRMADA → cliente
// ─────────────────────────────────────────────────────────────────────────────

export const onReservaConfirmadaCliente = functions.firestore.onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "CONFIRMADA" || despues.estado !== "CONFIRMADA") return;

    const uid = (despues.cliente_uid ?? despues.usuario_uid) as string | undefined;
    if (!uid) return;

    const negocio = _nombreNegocio(despues);
    const fecha = _formatFecha(despues.fecha_hora);
    const hora = _formatHora(despues.fecha_hora);

    await enviarNotifCliente({
      uid,
      titulo: "✅ Reserva confirmada",
      cuerpo: `Tu reserva en ${negocio} está confirmada — ${fecha} a las ${hora}`,
      tipo: "reserva_confirmada",
      extra: {
        reserva_id: event.params.reservaId,
        empresa_id: event.params.empresaId,
      },
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. RESERVA CANCELADA → cliente
// ─────────────────────────────────────────────────────────────────────────────

export const onReservaCanceladaCliente = functions.firestore.onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "CANCELADA" || despues.estado !== "CANCELADA") return;

    const uid = (despues.cliente_uid ?? despues.usuario_uid) as string | undefined;
    if (!uid) return;

    const negocio = _nombreNegocio(despues);
    const motivo = despues.motivo_cancelacion as string | undefined;
    const cuerpo = motivo
      ? `Tu reserva en ${negocio} ha sido cancelada. Motivo: ${motivo}`
      : `Tu reserva en ${negocio} ha sido cancelada`;

    await enviarNotifCliente({
      uid,
      titulo: "❌ Reserva cancelada",
      cuerpo,
      tipo: "reserva_cancelada",
      extra: {
        reserva_id: event.params.reservaId,
        empresa_id: event.params.empresaId,
      },
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. RECORDATORIO DE RESERVA — cron cada hora
//    Busca reservas CONFIRMADAS en ventana 23h–25h y envía si no se ha enviado
// ─────────────────────────────────────────────────────────────────────────────

export const recordatorioReservaCliente = onSchedule(
  { schedule: "every 60 minutes", region: REGION, timeZone: "Europe/Madrid" },
  async () => {
    const ahora = Date.now();
    const en23h = new Date(ahora + 23 * 3600_000);
    const en25h = new Date(ahora + 25 * 3600_000);

    const snap = await db
      .collectionGroup("reservas")
      .where("estado", "==", "CONFIRMADA")
      .where("fecha_hora", ">=", admin.firestore.Timestamp.fromDate(en23h))
      .where("fecha_hora", "<=", admin.firestore.Timestamp.fromDate(en25h))
      .where("recordatorio_cliente_enviado", "!=", true)
      .limit(100)
      .get();

    if (snap.empty) return;

    const tareas: Promise<any>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = (data.cliente_uid ?? data.usuario_uid) as string | undefined;
      if (!uid) continue;

      const negocio = _nombreNegocio(data);
      const hora = _formatHora(data.fecha_hora);

      tareas.push(
        enviarNotifCliente({
          uid,
          titulo: "🔔 Recordatorio de cita",
          cuerpo: `Recuerda: mañana tienes cita en ${negocio} a las ${hora}`,
          tipo: "reserva_pendiente",
          extra: { reserva_id: doc.id },
        }).then(() => doc.ref.update({ recordatorio_cliente_enviado: true }))
      );
    }

    await Promise.allSettled(tareas);
    functions.logger.info(`[Recordatorio] procesados ${snap.size} registros`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. FLASH SLOT DISPONIBLE → favoritos del negocio
//    Trigger: negocios_publicos/{id}/flash_slots/{id} — onCreate con estado "activo"
// ─────────────────────────────────────────────────────────────────────────────

export const onFlashSlotClienteNotif = functions.firestore.onDocumentCreated(
  {
    document: "negocios_publicos/{negocioId}/flash_slots/{slotId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data || data.estado !== "activo") return;

    const negocioId = event.params.negocioId;
    const slotId = event.params.slotId;

    // Solo slots de hoy o mañana
    const fechaTs = data.fecha_hora as admin.firestore.Timestamp | undefined;
    if (!fechaTs) return;
    const diffHoras = (fechaTs.toMillis() - Date.now()) / 3_600_000;
    if (diffHoras < 0 || diffHoras > 48) return;

    const negocioDoc = await db.collection("negocios_publicos").doc(negocioId).get();
    const negocioNombre = negocioDoc.data()?.nombre ?? "Negocio";
    const hora = _formatHora(data.fecha_hora);
    const descuento = data.descuento_porcentaje as number | undefined;
    const sufijo = descuento ? ` — ${descuento}% dto.` : "";
    const cuerpo = `${negocioNombre} tiene una plaza libre hoy a las ${hora}${sufijo}`;

    // Obtener usuarios con ese negocio en favoritos
    const favSnap = await db
      .collectionGroup("favoritos")
      .where("negocio_id", "==", negocioId)
      .limit(500)
      .get();

    if (favSnap.empty) return;

    const uids = [
      ...new Set(
        favSnap.docs
          .map((d) => d.ref.parent.parent?.id)
          .filter((u): u is string => !!u)
      ),
    ];

    const tareas = uids.map((uid) =>
      enviarNotifCliente({
        uid,
        titulo: `⚡ Plaza libre en ${negocioNombre}`,
        cuerpo,
        tipo: "promo",
        extra: { negocio_id: negocioId, slot_id: slotId },
      })
    );

    await Promise.allSettled(tareas);
    functions.logger.info(
      `[FlashSlot] ${slotId}: enviado a ${uids.length} favoritos`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 5. PROMOCIÓN / OFERTA → clientes del negocio
//    Trigger: empresas/{id}/promociones/{id} — onCreate con activo: true
//    Límite: máx 1 promo/negocio/semana por cliente
// ─────────────────────────────────────────────────────────────────────────────

export const onPromocionClienteNotif = functions.firestore.onDocumentCreated(
  {
    document: "empresas/{empresaId}/promociones/{promoId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data || !data.activo) return;

    const empresaId = event.params.empresaId;
    const tituloProm = (data.titulo ?? data.nombre ?? "Nueva oferta") as string;
    const negocioNombre = (data.negocio_nombre ?? data.nombre_negocio ?? "") as string;

    // Buscar clientes de la empresa que tengan uid
    const clientesSnap = await db
      .collection("empresas")
      .doc(empresaId)
      .collection("clientes")
      .where("uid", "!=", null)
      .limit(300)
      .get();

    if (clientesSnap.empty) return;

    const uids = [
      ...new Set(
        clientesSnap.docs
          .map((d) => d.data().uid as string | undefined)
          .filter((u): u is string => !!u)
      ),
    ];

    const ahora = admin.firestore.Timestamp.now();
    const hace7dias = new Date(ahora.toMillis() - 7 * 24 * 3600_000);

    const tareas = uids.map(async (uid) => {
      // Verificar límite semanal por negocio
      const prefsRef = db
        .collection("usuarios")
        .doc(uid)
        .collection("prefs")
        .doc(empresaId);
      const prefsSnap = await prefsRef.get();
      if (prefsSnap.exists) {
        const ultima = prefsSnap.data()?.ultima_promo_enviada as
          | admin.firestore.Timestamp
          | undefined;
        if (ultima && ultima.toDate() > hace7dias) return; // throttle
      }

      const display = negocioNombre ? `${negocioNombre}: ${tituloProm}` : tituloProm;

      await enviarNotifCliente({
        uid,
        titulo: `🎁 ${negocioNombre || "Oferta especial"}`,
        cuerpo: display,
        tipo: "promo",
        extra: { empresa_id: empresaId, promo_id: event.params.promoId },
      });

      // Actualizar timestamp de última promo
      await prefsRef.set({ ultima_promo_enviada: ahora }, { merge: true });
    });

    await Promise.allSettled(tareas);
    functions.logger.info(
      `[Promo] ${event.params.promoId}: enviada a ${uids.length} clientes`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 6A. SOLICITUD DE VALORACIÓN — marcar reserva completada
//     Trigger: reserva cambia a estado "completada"
// ─────────────────────────────────────────────────────────────────────────────

export const onReservaCompletadaValoracion = functions.firestore.onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "completada" || despues.estado !== "completada") return;
    if (despues.solicitud_valoracion_enviada === true) return;

    // Marcar para procesamiento con delay por el cron
    await event.data!.after.ref.update({
      solicitud_valoracion_pendiente: true,
      fecha_completada: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 6B. CRON — procesar solicitudes de valoración con delay de 2 horas
// ─────────────────────────────────────────────────────────────────────────────

export const procesarSolicitudesValoracion = onSchedule(
  { schedule: "every 30 minutes", region: REGION, timeZone: "Europe/Madrid" },
  async () => {
    const hace2h = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 2 * 3600_000)
    );

    const snap = await db
      .collectionGroup("reservas")
      .where("solicitud_valoracion_pendiente", "==", true)
      .where("fecha_completada", "<=", hace2h)
      .limit(50)
      .get();

    if (snap.empty) return;

    const tareas: Promise<any>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = (data.cliente_uid ?? data.usuario_uid) as string | undefined;

      const marcarEnviada = doc.ref.update({
        solicitud_valoracion_pendiente: false,
        solicitud_valoracion_enviada: true,
      });

      if (!uid) {
        tareas.push(marcarEnviada);
        continue;
      }

      // Verificar si ya valoró esta reserva
      const yaValoro = await db
        .collectionGroup("valoraciones")
        .where("reserva_id", "==", doc.id)
        .where("cliente_uid", "==", uid)
        .limit(1)
        .get();

      if (!yaValoro.empty) {
        tareas.push(marcarEnviada);
        continue;
      }

      const negocio = _nombreNegocio(data);

      tareas.push(
        enviarNotifCliente({
          uid,
          titulo: "⭐ ¿Cómo fue tu visita?",
          cuerpo: `¿Cómo fue tu visita a ${negocio}? Cuéntanos en 30 segundos`,
          tipo: "info",
          extra: { reserva_id: doc.id, accion: "valorar" },
        }).then(() => marcarEnviada)
      );
    }

    await Promise.allSettled(tareas);
    functions.logger.info(
      `[Valoracion] procesadas ${snap.size} solicitudes pendientes`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 7. SELLO DE FIDELIZACIÓN — notif in-app complementaria
//    (El push FCM ya lo envía fidelizacion.ts con el mismo trigger)
// ─────────────────────────────────────────────────────────────────────────────

export const onSelloFidelizacionInApp = functions.firestore.onDocumentCreated(
  {
    document: "negocios_publicos/{negocioId}/checkins/{checkinId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const clienteId = data.cliente_id as string | undefined;
    if (!clienteId) return;

    const negocioId = event.params.negocioId;
    const negocioDoc = await db.collection("negocios_publicos").doc(negocioId).get();
    const negocioNombre = negocioDoc.data()?.nombre ?? "Negocio";

    const sellosActuales = (data.sellos_acumulados as number | undefined) ?? 1;
    const totalNecesarios = (data.total_necesarios as number | undefined) ?? 10;
    const recompensaDesbloqueada = data.recompensa_desbloqueada === true;

    const titulo = recompensaDesbloqueada
      ? `🎉 ¡Bono completado en ${negocioNombre}!`
      : `☕ ¡Nuevo sello en ${negocioNombre}!`;
    const cuerpo = recompensaDesbloqueada
      ? `¡Bono completado en ${negocioNombre}! Ya puedes canjear tu recompensa`
      : `¡Nuevo sello en ${negocioNombre}! Llevas ${sellosActuales} de ${totalNecesarios}`;

    // Solo in-app — evitar doble push con fidelizacion.ts
    await db
      .collection("usuarios")
      .doc(clienteId)
      .collection("notificaciones")
      .add({
        titulo,
        cuerpo,
        tipo: "promo",
        creado_en: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        negocio_id: negocioId,
      });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 8. BIENVENIDA CLIENTE NUEVO
//    Trigger: usuarios/{uid} — onCreate, solo si origen == "app_explorar"
// ─────────────────────────────────────────────────────────────────────────────

export const onBienvenidaClienteNuevo = functions.firestore.onDocumentCreated(
  { document: "usuarios/{uid}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.origen !== "app_explorar") return;

    const uid = event.params.uid;

    await enviarNotifCliente({
      uid,
      titulo: "👋 Bienvenido a Fluix",
      cuerpo: "Descubre negocios cerca de ti y reserva en segundos.",
      tipo: "info",
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS privados
// ─────────────────────────────────────────────────────────────────────────────

function _nombreNegocio(data: FirebaseFirestore.DocumentData): string {
  return (
    (data.negocio_nombre as string | undefined) ??
    (data.empresa_nombre as string | undefined) ??
    "tu negocio"
  );
}

function _formatFecha(ts: unknown): string {
  if (!ts) return "";
  const date =
    ts instanceof admin.firestore.Timestamp
      ? ts.toDate()
      : new Date(ts as any);
  return date.toLocaleDateString("es-ES", { day: "2-digit", month: "long" });
}

function _formatHora(ts: unknown): string {
  if (!ts) return "";
  const date =
    ts instanceof admin.firestore.Timestamp
      ? ts.toDate()
      : new Date(ts as any);
  return date.toLocaleTimeString("es-ES", {
    hour: "2-digit",
    minute: "2-digit",
  });
}

