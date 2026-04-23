/**
 * invitaciones.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Cloud Functions para el sistema de invitación de empleados por email.
 *
 * Trigger:  onDocumentCreated en invitaciones/{token}
 *           → envía el email con el deep link al empleado invitado.
 *
 * Estructura del documento:
 *   token, email, rol, empresa_id, empresa_nombre, creado_por,
 *   expira, usado, fecha_creacion
 *
 * Deep link generado:  fluixcrm://invite?token={token}
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { enviarInvitacion } from "./resend_service";

const REGION = "europe-west1";

// ── CLOUD FUNCTION ───────────────────────────────────────────────────────────

export const onInvitacionCreada = onDocumentCreated(
  { document: "invitaciones/{token}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { token, email, rol, empresa_nombre: empresaNombre } = data as {
      token: string;
      email: string;
      rol: string;
      empresa_nombre: string;
    };

    const rolLabel = rol === "admin" ? "Administrador" : "Empleado";
    const deepLink = `fluixcrm://invite?token=${token}`;

    try {
      const resultado = await enviarInvitacion({
        to: email,
        empresaNombre,
        rolLabel,
        deepLink,
        expiresHours: 72,
      });

      if (!resultado.exito) throw new Error(resultado.error);

      await admin
        .firestore()
        .collection("invitaciones")
        .doc(token)
        .update({ email_enviado: true, email_enviado_at: admin.firestore.FieldValue.serverTimestamp() });

      console.log(`✅ Invitación enviada a ${email} (token: ${token})`);
    } catch (e) {
      console.error(`❌ Error enviando invitación a ${email}:`, e);

      await admin
        .firestore()
        .collection("invitaciones")
        .doc(token)
        .update({ email_error: String(e) });
    }
  }
);

