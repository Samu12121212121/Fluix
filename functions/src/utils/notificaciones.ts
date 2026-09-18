/**
 * utils/notificaciones.ts
 * Helper compartido para enviar notificaciones push a todos los dispositivos
 * (propietario + admins) de una empresa.
 * Usado por index.ts, automaciones_clientes.ts y otros módulos.
 */

import * as admin from "firebase-admin";

const db      = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// Recopila todos los tokens FCM activos de una empresa:
//   1. Colección empresas/{id}/dispositivos (fuente principal)
//   2. Fallback: campo token_dispositivo en usuarios con esa empresa_id
// ─────────────────────────────────────────────────────────────────────────────
export async function obtenerTokensEmpresa(empresaId: string): Promise<string[]> {
  const col = db.collection("empresas").doc(empresaId).collection("dispositivos");

  let snapshot = await col.where("activo", "==", true).get();
  if (snapshot.empty) snapshot = await col.get();

  const tokens: string[] = [];
  snapshot.forEach((doc) => {
    const token = doc.data().token as string | undefined;
    if (token && token.length > 10) tokens.push(token);
  });

  // Fallback: buscar en usuarios (propietarios + admins)
  if (tokens.length === 0) {
    console.log(`⚠️ Sin tokens en dispositivos para ${empresaId}, buscando en usuarios...`);
    const usuariosSnap = await db
      .collection("usuarios")
      .where("empresa_id", "==", empresaId)
      .where("activo", "!=", false)
      .get();

    for (const userDoc of usuariosSnap.docs) {
      const tokenUsuario = userDoc.data().token_dispositivo as string | undefined;
      if (tokenUsuario && tokenUsuario.length > 10 && !tokens.includes(tokenUsuario)) {
        tokens.push(tokenUsuario);
        try {
          await col.doc(userDoc.id).set({
            token:                  tokenUsuario,
            uid_usuario:            userDoc.id,
            activo:                 true,
            sincronizado_desde:     "fallback_usuarios",
            ultima_actualizacion:   admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          console.log(`🔄 Token sincronizado de usuarios/${userDoc.id} → dispositivos`);
        } catch (_) { /* no bloquear el envío */ }
      }
    }
  }

  return tokens;
}

// ─────────────────────────────────────────────────────────────────────────────
// Envía push a TODOS los dispositivos activos de la empresa (propietario + admins).
// Limpia automáticamente los tokens inválidos.
// ─────────────────────────────────────────────────────────────────────────────
export async function enviarNotificacionEmpresa(
  empresaId: string,
  titulo: string,
  cuerpo: string,
  data: Record<string, string> = {}
): Promise<void> {
  const tokens = await obtenerTokensEmpresa(empresaId);

  if (tokens.length === 0) {
    console.log(`❌ No hay tokens para empresa ${empresaId} — NO se envía push`);
    return;
  }

  console.log(`📤 Enviando push a ${tokens.length} dispositivo(s) para empresa ${empresaId}: "${titulo}"`);

  const mensaje: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title: titulo, body: cuerpo },
    data:         { empresa_id: empresaId, ...data },
    android: {
      priority: "high",
      notification: {
        channelId: "fluixcrm_canal_principal",
        sound:     "default",
        priority:  "high",
      },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  };

  try {
    const respuesta = await messaging.sendEachForMulticast(mensaje);
    console.log(`✅ Push enviado: ${respuesta.successCount}/${tokens.length}`);

    // Desactivar tokens inválidos
    if (respuesta.failureCount > 0) {
      const tokensAEliminar: string[] = [];
      respuesta.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code ?? "";
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            tokensAEliminar.push(tokens[idx]);
          }
        }
      });

      if (tokensAEliminar.length > 0) {
        const dispositivosRef = db
          .collection("empresas").doc(empresaId).collection("dispositivos");
        const invalidSnap = await dispositivosRef
          .where("token", "in", tokensAEliminar).get();
        const batch = db.batch();
        invalidSnap.forEach((doc) => batch.update(doc.ref, { activo: false }));
        await batch.commit();
      }
    }
  } catch (error) {
    console.error("❌ Error enviando notificaciones:", error);
  }
}
