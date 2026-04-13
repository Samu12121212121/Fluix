import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const REGION = "europe-west1";

// ─── Utilidad de notificación ─────────────────────────────────────────────────

async function obtenerTokensEmpresa(empresaId: string): Promise<string[]> {
  const snapshot = await db
    .collection("empresas")
    .doc(empresaId)
    .collection("dispositivos")
    .where("activo", "==", true)
    .get();
  const tokens: string[] = [];
  snapshot.forEach((doc) => {
    const token = doc.data().token as string | undefined;
    if (token) tokens.push(token);
  });
  return tokens;
}

async function enviarNotificacion(
  empresaId: string,
  titulo: string,
  cuerpo: string,
  data: Record<string, string> = {}
): Promise<void> {
  const tokens = await obtenerTokensEmpresa(empresaId);
  if (tokens.length === 0) return;

  const mensaje: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title: titulo, body: cuerpo },
    data: { empresa_id: empresaId, tipo: "certificado_expiracion", ...data },
    android: {
      priority: "high",
      notification: {
        channelId: "fluixcrm_fiscal",
        sound: "default",
        priority: "high",
      },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  };

  try {
    const respuesta = await messaging.sendEachForMulticast(mensaje);
    console.log(
      `[AlertaCert] Empresa ${empresaId}: ${respuesta.successCount}/${tokens.length} notificaciones enviadas`
    );

    // Invalidar tokens muertos
    if (respuesta.failureCount > 0) {
      const tokensAEliminar: string[] = [];
      respuesta.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            tokensAEliminar.push(tokens[idx]);
          }
        }
      });
      if (tokensAEliminar.length > 0) {
        const snp = await db
          .collection("empresas")
          .doc(empresaId)
          .collection("dispositivos")
          .where("token", "in", tokensAEliminar)
          .get();
        const batch = db.batch();
        snp.forEach((d) => batch.update(d.ref, { activo: false }));
        await batch.commit();
      }
    }
  } catch (e) {
    console.error(`[AlertaCert] Error enviando a ${empresaId}:`, e);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION — scheduledAlertaCertificado
//
// Se ejecuta a las 08:00 UTC todos los días.
// Revisa todos los certificados digitales activos y envía alertas push:
//   - 60 días antes: aviso informativo
//   - 30 días antes: advertencia
//   - 7 días antes: urgencia
//   - Mismo día de expiración: crítico
// ═══════════════════════════════════════════════════════════════════════════════

export const scheduledAlertaCertificado = onSchedule(
  {
    schedule: "0 8 * * *", // Cada día a las 08:00 UTC
    timeZone: "Europe/Madrid",
    region: REGION,
  },
  async (_event) => {
    console.log("[AlertaCert] Iniciando revisión diaria de certificados...");

    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    // Obtener todos los certificados digitales activos
    // Buscamos en empresas/{empresaId}/configuracion/certificado_digital
    const empresasSnap = await db.collection("empresas").get();
    console.log(`[AlertaCert] Revisando ${empresasSnap.size} empresas`);

    let alertasEnviadas = 0;
    let errores = 0;

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      try {
        const certDoc = await db
          .collection("empresas")
          .doc(empresaId)
          .collection("configuracion")
          .doc("certificado_digital")
          .get();

        if (!certDoc.exists) continue;

        const certData = certDoc.data();
        if (!certData) continue;

        const validoHasta = certData.valido_hasta;
        if (!validoHasta) continue;

        const fechaExpiracion: Date = validoHasta.toDate();
        fechaExpiracion.setHours(0, 0, 0, 0);

        const diasRestantes = Math.floor(
          (fechaExpiracion.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24)
        );

        const titular = (certData.titular as string) || "certificado digital";
        const nif = (certData.nif as string) || "";

        console.log(
          `[AlertaCert] Empresa ${empresaId}${nif ? " (" + nif + ")" : ""}: ${diasRestantes} días restantes`
        );

        // Determinar si hay que enviar alerta y con qué nivel
        if (diasRestantes < 0) {
          // Expirado — alerta diaria urgente
          await enviarNotificacion(
            empresaId,
            "🔴 Certificado digital EXPIRADO",
            `Tu certificado digital expiró hace ${Math.abs(diasRestantes)} días. ` +
              "Los modelos fiscales no se podrán firmar digitalmente.",
            { dias_restantes: diasRestantes.toString(), tipo_alerta: "expirado" }
          );
          alertasEnviadas++;

          // Registrar en Firestore
          await _registrarAlerta(empresaId, "expirado", diasRestantes);
        } else if (diasRestantes === 0) {
          await enviarNotificacion(
            empresaId,
            "🔴 Tu certificado digital expira HOY",
            "Renueva el certificado digital de inmediato para mantener " +
              "la firma electrónica de los modelos fiscales.",
            { dias_restantes: "0", tipo_alerta: "hoy" }
          );
          alertasEnviadas++;
          await _registrarAlerta(empresaId, "hoy", 0);
        } else if (diasRestantes <= 7) {
          await enviarNotificacion(
            empresaId,
            `🔴 Certificado digital: ${diasRestantes} días`,
            `El certificado ${titular.substring(0, 30)} expira en ${diasRestantes} día(s). ` +
              "Renuévalo urgentemente en Ajustes → Certificado digital.",
            {
              dias_restantes: diasRestantes.toString(),
              tipo_alerta: "urgente",
            }
          );
          alertasEnviadas++;
          await _registrarAlerta(empresaId, "urgente", diasRestantes);
        } else if (diasRestantes === 30) {
          await enviarNotificacion(
            empresaId,
            "⚠️ Certificado digital: 30 días",
            `El certificado digital expira el ${_fmtFecha(fechaExpiracion)}. ` +
              "Planifica su renovación.",
            {
              dias_restantes: "30",
              tipo_alerta: "advertencia",
            }
          );
          alertasEnviadas++;
          await _registrarAlerta(empresaId, "advertencia", 30);
        } else if (diasRestantes === 60) {
          await enviarNotificacion(
            empresaId,
            "⚠️ Certificado digital: 60 días",
            `El certificado digital expira el ${_fmtFecha(fechaExpiracion)}. ` +
              "Recuerda renovarlo antes de que expire.",
            {
              dias_restantes: "60",
              tipo_alerta: "informativo",
            }
          );
          alertasEnviadas++;
          await _registrarAlerta(empresaId, "informativo", 60);
        }
      } catch (e) {
        console.error(`[AlertaCert] Error procesando empresa ${empresaId}:`, e);
        errores++;
      }
    }

    console.log(
      `[AlertaCert] Completado: ${alertasEnviadas} alertas enviadas, ${errores} errores`
    );
  }
);

async function _registrarAlerta(
  empresaId: string,
  tipoAlerta: string,
  diasRestantes: number
): Promise<void> {
  try {
    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("alertas_certificado")
      .add({
        tipo: tipoAlerta,
        dias_restantes: diasRestantes,
        fecha_envio: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (_) {
    // No crítico si falla el log
  }
}

function _fmtFecha(d: Date): string {
  return `${String(d.getDate()).padStart(2, "0")}/${String(
    d.getMonth() + 1
  ).padStart(2, "0")}/${d.getFullYear()}`;
}

