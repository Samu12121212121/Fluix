/**
 * resetPassword.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Cloud Function (onCall) para envío de email de reset de contraseña
 * con template HTML propio (Resend) en lugar del genérico de Firebase.
 *
 * Llamada desde Flutter:
 *   final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
 *     .httpsCallable('sendResetPasswordEmail');
 *   await fn.call({'email': 'usuario@example.com'});
 *
 * Variables de entorno requeridas:
 *   RESEND_API_KEY  (ya configurado para el resto de emails)
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { enviarResetPassword } from "./resend_service";

const REGION = "europe-west1";

export const sendResetPasswordEmail = onCall(
  { region: REGION },
  async (request) => {
    const { email } = request.data as { email?: string };

    // ── Validación básica ──────────────────────────────────────────────────
    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Email inválido o no proporcionado.");
    }

    const emailNormalizado = email.trim().toLowerCase();

    // ── Verificar que el usuario existe en Firebase Auth ──────────────────
    // (Si no existe, no revelamos info por seguridad — devolvemos éxito igualmente)
    try {
      await admin.auth().getUserByEmail(emailNormalizado);
    } catch (e: any) {
      if (e.code === "auth/user-not-found") {
        // Respuesta genérica para no revelar si el email está registrado
        console.log(`ℹ️  Reset solicitado para email no registrado: ${emailNormalizado} — ignorado silenciosamente`);
        return { exito: true, mensaje: "Si el email está registrado, recibirás un enlace en breve." };
      }
      throw new HttpsError("internal", "Error verificando usuario.");
    }

    // ── Generar link de reset con Firebase Admin SDK ───────────────────────
    let resetLink: string;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(emailNormalizado, {
        url: "https://fluixtech.com/login", // Redirección tras resetear
        handleCodeInApp: false,
      });
    } catch (e: any) {
      console.error("❌ Error generando password reset link:", e);
      throw new HttpsError("internal", "No se pudo generar el enlace de restablecimiento.");
    }

    // ── Enviar email con template personalizado via Resend ─────────────────
    const resultado = await enviarResetPassword({
      to: emailNormalizado,
      resetLink,
    });

    if (!resultado.exito) {
      console.error(`❌ Error enviando reset email a ${emailNormalizado}:`, resultado.error);
      throw new HttpsError("internal", `Error enviando el email: ${resultado.error}`);
    }

    console.log(`✅ Reset password email enviado a ${emailNormalizado} (id: ${resultado.id})`);
    return { exito: true, mensaje: "Email de restablecimiento enviado correctamente." };
  }
);

