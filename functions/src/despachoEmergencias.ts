import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

// ═══════════════════════════════════════════════════════════════════════════════
// DESPACHO DE EMERGENCIAS — Trigger Firestore
//
// Se activa cuando se crea un doc en:
//   empresas/{empresaId}/alertas_despacho/{alertaId}
//
// Envía FCM a todos los usuarios de la empresa con token registrado.
// ═══════════════════════════════════════════════════════════════════════════════

export const onNuevaAlertaDespacho = onDocumentCreated(
  "empresas/{empresaId}/alertas_despacho/{alertaId}",
  async (event) => {
    const snap      = event.data;
    const empresaId = event.params.empresaId;
    const alertaId  = event.params.alertaId;

    if (!snap) return;
    const data = snap.data() as Record<string, any>;

    const tipo      = (data.tipo_codigo  as string) ?? "SVB";
    const prioridad = (data.prioridad    as string) ?? "alta";
    const direccion = (data.direccion    as string) ?? "";
    const localidad = (data.localidad    as string) ?? "";
    const ref       = (data.referencia_mapa as string | null) ?? null;

    const titulos: Record<string, string> = {
      critica: `🚨 DESPACHO CRÍTICO — ${tipo}`,
      alta:    `⚠️ DESPACHO ALTA — ${tipo}`,
      media:   `ℹ️ Despacho Media — ${tipo}`,
      baja:    `✅ Despacho — ${tipo}`,
    };
    const titulo = titulos[prioridad] ?? `🚨 Despacho — ${tipo}`;
    const cuerpo = `${direccion}, ${localidad}${ref ? ` (${ref})` : ""}`;

    // Leer todos los usuarios de la empresa con token FCM
    const usuariosSnap = await admin.firestore()
      .collection("usuarios")
      .where("empresa_id", "==", empresaId)
      .where("activo", "==", true)
      .get();

    const tokens: string[] = [];
    usuariosSnap.forEach((doc) => {
      const token = doc.data().token_dispositivo as string | undefined;
      if (token && token.length > 10) tokens.push(token);
    });

    if (tokens.length === 0) {
      console.log(`⚠️ [despacho] Sin tokens FCM para empresa ${empresaId}`);
      return;
    }

    console.log(`🚨 [despacho] Enviando a ${tokens.length} dispositivos — ${tipo} en ${direccion}`);

    // Enviar en lotes de 500 (límite FCM)
    const batches: string[][] = [];
    for (let i = 0; i < tokens.length; i += 500) {
      batches.push(tokens.slice(i, i + 500));
    }

    for (const batch of batches) {
      const message: admin.messaging.MulticastMessage = {
        tokens: batch,
        notification: { title: titulo, body: cuerpo },
        data: {
          tipo:       "alerta_despacho",
          empresa_id: empresaId,
          alerta_id:  alertaId,
          prioridad,
        },
        android: {
          priority: "high",
          notification: {
            channelId:   "sysday_despacho",
            priority:    "max",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "public",
          },
        },
        apns: {
          headers: { "apns-priority": "10", "apns-push-type": "alert" },
          payload: {
            aps: {
              alert:  { title: titulo, body: cuerpo },
              sound:  "default",
              badge:  1,
              "content-available": 1,
              "interruption-level": prioridad === "critica" ? "critical" : "active",
            },
          },
        },
      };

      const result = await admin.messaging().sendEachForMulticast(message);
      console.log(`✅ [despacho] Enviados: ${result.successCount} / Fallidos: ${result.failureCount}`);

      // Limpiar tokens inválidos
      result.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error?.code === "messaging/registration-token-not-registered") {
          admin.firestore().collection("usuarios")
            .where("token_dispositivo", "==", batch[idx])
            .get()
            .then((snap) => snap.forEach((doc) =>
              doc.ref.update({ token_dispositivo: admin.firestore.FieldValue.delete() })
            ));
        }
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// ALERTA DE PRUEBA — Callable desde la app (solo para admin de la empresa)
//
// Crea un documento de alerta_despacho real que dispara onNuevaAlertaDespacho
// y envía FCM a todos los dispositivos de la empresa.
// Usar desde CAD: botón "Enviar prueba" o desde panel de ajustes.
// ─────────────────────────────────────────────────────────────────────────────

export const enviarAlertaPruebaDespacho = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError("unauthenticated", "Se requiere autenticación");

  const empresaId = request.data.empresa_id as string | undefined;
  if (!empresaId) throw new HttpsError("invalid-argument", "empresa_id es obligatorio");

  // Verificar que el usuario pertenece a la empresa
  const userDoc = await admin.firestore().collection("usuarios").doc(auth.uid).get();
  if (!userDoc.exists || userDoc.data()?.empresa_id !== empresaId) {
    throw new HttpsError("permission-denied", "No tienes acceso a esta empresa");
  }

  // Crear la alerta de prueba — dispara onNuevaAlertaDespacho automáticamente
  const ref = await admin.firestore()
    .collection("empresas").doc(empresaId)
    .collection("alertas_despacho").add({
      tipo_codigo:  "SVB",
      descripcion:  "Alerta de prueba — Sistema de despacho Sysday",
      direccion:    "Av. del Ejército, 15",
      localidad:    "Guadalajara",
      prioridad:    "alta",
      num_pacientes: 1,
      lat:          40.6367,
      lng:          -3.1612,
      ambulancia_asignada: null,
      estado:       "pendiente",
      fecha_hora:   admin.firestore.FieldValue.serverTimestamp(),
      operador_uid: auth.uid,
      es_prueba:    true,
    });

  console.log(`🧪 [despacho-prueba] Alerta creada: ${ref.id} para empresa ${empresaId}`);
  return { alerta_id: ref.id, ok: true };
});
