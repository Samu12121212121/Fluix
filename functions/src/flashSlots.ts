import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

const REGION = "europe-west1";
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: Expirar flash slots cada 5 minutos
// ─────────────────────────────────────────────────────────────────────────────
export const expirarFlashSlots = onSchedule(
  { schedule: "every 5 minutes", region: REGION, timeZone: "Europe/Madrid" },
  async () => {
    const ahora = admin.firestore.Timestamp.now();

    // Buscar todos los slots activos que han expirado
    const snap = await db
      .collectionGroup("flash_slots")
      .where("estado", "==", "activo")
      .where("fecha_hora_expiracion", "<=", ahora)
      .limit(50)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const notifPromises: Promise<any>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      batch.update(doc.ref, { estado: "expirado" });

      // Notificar al negocio
      const empresaId = data.empresa_id as string;
      const negocioNombre = data.negocio_nombre as string;
      const servicioNombre = data.servicio_nombre as string;
      const huecosR = data.huecos_reservados as number ?? 0;
      const huecosT = data.huecos_totales as number ?? 1;

      if (empresaId) {
        notifPromises.push(
          _notificarEmpresaExpiracion(
            empresaId,
            doc.id,
            negocioNombre,
            servicioNombre,
            huecosR,
            huecosT,
          )
        );
      }
    }

    await batch.commit();
    await Promise.allSettled(notifPromises);
    console.log(`✅ Expirados ${snap.size} flash slots`);
  }
);

async function _notificarEmpresaExpiracion(
  empresaId: string,
  slotId: string,
  negocioNombre: string,
  servicioNombre: string,
  huecosReservados: number,
  huecosTotal: number,
) {
  // Obtener FCM tokens de administradores de la empresa
  const empleadosSnap = await db
    .collection("empresas").doc(empresaId)
    .collection("empleados")
    .where("rol", "in", ["admin", "propietario"])
    .where("activo", "==", true)
    .get();

  const tokens: string[] = [];
  for (const emp of empleadosSnap.docs) {
    const t = emp.data().fcm_token;
    if (t) tokens.push(t);
  }

  if (tokens.length === 0) return;

  const ocupacion = huecosTotal > 0
    ? Math.round(huecosReservados / huecosTotal * 100)
    : 0;

  const payload: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title: huecosReservados === 0
        ? `⚡ Flash slot sin reservas - ${negocioNombre}`
        : `⚡ Flash slot expirado - ${negocioNombre}`,
      body: huecosReservados === 0
        ? `Tu slot de "${servicioNombre}" expiró sin reservas. ¿Quieres republicarlo?`
        : `"${servicioNombre}" expiró con ${ocupacion}% de ocupación (${huecosReservados}/${huecosTotal} huecos)`,
    },
    data: {
      tipo: "flash_slot_expirado",
      slot_id: slotId,
      empresa_id: empresaId,
      accion: huecosReservados === 0 ? "republicar" : "ver_historial",
    },
    android: {
      notification: { channelId: "fluixcrm_canal_principal" },
    },
  };

  const result = await admin.messaging().sendEachForMulticast(payload);
  console.log(
    `📩 Notif expiración: ${result.successCount} éxito, ${result.failureCount} fallos`
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER: Enviar notificaciones al crear un nuevo flash_slots_notificaciones
// ─────────────────────────────────────────────────────────────────────────────
export const onNuevoFlashSlot = onDocumentCreated(
  {
    document: "flash_slots_notificaciones/{docId}",
    region: REGION,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (data.procesado === true) return;

    const negocioId     = data.negocio_id as string;
    const negocioNombre = data.negocio_nombre as string;
    const servicioNombre = data.servicio_nombre as string;
    const precioFinal   = data.precio_final as number;
    const huecosTotal   = data.huecos_totales as number;
    const slotId        = data.slot_id as string;

    try {
      const tokens = await _obtenerTokensFavoritos(negocioId);
      if (tokens.length === 0) {
        await snap.ref.update({ procesado: true, tokens_enviados: 0 });
        return;
      }

      // Enviar en lotes de 500 (límite FCM multicast)
      let enviados = 0;
      for (let i = 0; i < tokens.length; i += 500) {
        const lote = tokens.slice(i, i + 500);
        const mensaje: admin.messaging.MulticastMessage = {
          tokens: lote,
          notification: {
            title: `⚡ Oferta flash en ${negocioNombre}`,
            body: `${servicioNombre} por solo €${precioFinal.toFixed(2)} — ${huecosTotal} huecos disponibles`,
          },
          data: {
            tipo: "flash_slot",
            negocio_id: negocioId,
            slot_id: slotId,
          },
          android: {
            notification: { channelId: "fluixcrm_canal_principal" },
            priority: "high",
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { badge: 1, sound: "default" } },
          },
        };
        const result = await admin.messaging().sendEachForMulticast(mensaje);
        enviados += result.successCount;
      }

      await snap.ref.update({
        procesado: true,
        tokens_enviados: enviados,
        procesado_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `⚡ Flash slot ${slotId}: ${enviados} notificaciones enviadas a favoritos`
      );
    } catch (err) {
      console.error("Error enviando notificaciones flash slot:", err);
      await snap.ref.update({ procesado: true, error: String(err) });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Obtener FCM tokens de usuarios que tienen el negocio en favoritos
// ─────────────────────────────────────────────────────────────────────────────
async function _obtenerTokensFavoritos(negocioId: string): Promise<string[]> {
  // Buscar usuarios que tengan este negocio en su subcol favoritos
  const favSnap = await db
    .collectionGroup("favoritos")
    .where("negocio_id", "==", negocioId)
    .limit(500)
    .get();

  const tokens: string[] = [];

  if (favSnap.empty) return tokens;

  // Para cada favorito, obtener el uid del usuario (padre del doc)
  const uids = favSnap.docs.map((d) => {
    // La ruta es usuarios/{uid}/favoritos/{negocioId}
    return d.ref.parent.parent?.id;
  }).filter((uid): uid is string => !!uid);

  // Obtener tokens en paralelo
  const userPromises = uids.map((uid) =>
    db.collection("usuarios").doc(uid).get()
  );
  const userDocs = await Promise.all(userPromises);

  for (const userDoc of userDocs) {
    if (!userDoc.exists) continue;
    const token = userDoc.data()?.fcm_token as string | undefined;
    if (token) tokens.push(token);
  }

  return [...new Set(tokens)]; // deduplica
}

