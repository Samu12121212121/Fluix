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
import * as nodemailer from "nodemailer";

const REGION = "europe-west1";

// ── CREAR TRANSPORTER ───────────────────────────────────────────────────────

function crearTransporter() {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST ?? "",
    port: parseInt(process.env.SMTP_PORT ?? "587"),
    secure: false,
    auth: {
      user: process.env.SMTP_USER ?? "",
      pass: process.env.SMTP_PASS ?? "",
    },
  });
}

// ── TEMPLATE HTML DEL EMAIL ──────────────────────────────────────────────────

function buildInvitationEmail(
  empresaNombre: string,
  rolLabel: string,
  deepLink: string,
  expiresHours: number
): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitación a ${empresaNombre}</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fa;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td style="padding:40px 20px;">
      <table width="600" align="center" cellpadding="0" cellspacing="0"
             style="background:#fff;border-radius:16px;overflow:hidden;
                    box-shadow:0 4px 20px rgba(0,0,0,0.08);">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#0D47A1,#1976D2);
                     padding:32px 40px;text-align:center;">
            <div style="font-size:28px;font-weight:bold;color:#fff;
                        letter-spacing:-0.5px;">Fluix CRM</div>
            <div style="font-size:14px;color:rgba(255,255,255,0.75);
                        margin-top:4px;">Gestión empresarial simplificada</div>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:40px;">
            <h2 style="margin:0 0 12px;font-size:22px;color:#0D47A1;">
              Has sido invitado a ${empresaNombre} 🎉
            </h2>
            <p style="color:#555;font-size:15px;line-height:1.6;margin:0 0 20px;">
              Un administrador de <strong>${empresaNombre}</strong> te ha invitado
              a unirte como <strong>${rolLabel}</strong> en la plataforma Fluix CRM.
            </p>

            <!-- Role badge -->
            <div style="display:inline-block;background:#E3F2FD;color:#0D47A1;
                        padding:6px 14px;border-radius:20px;font-size:13px;
                        font-weight:600;margin-bottom:28px;">
              Rol: ${rolLabel}
            </div>

            <!-- CTA Button -->
            <div style="text-align:center;margin:28px 0;">
              <a href="${deepLink}"
                 style="display:inline-block;background:#0D47A1;color:#fff;
                        padding:16px 36px;border-radius:12px;font-size:16px;
                        font-weight:bold;text-decoration:none;
                        letter-spacing:0.2px;">
                Aceptar invitación →
              </a>
            </div>

            <!-- Expiry notice -->
            <div style="background:#FFF8E1;border:1px solid #FFE082;
                        border-radius:10px;padding:14px 18px;margin-bottom:20px;">
              <p style="margin:0;font-size:13px;color:#F57C00;">
                ⏱ Este enlace caduca en <strong>${expiresHours} horas</strong>.
                Si no puedes abrirlo ahora, pide al administrador que te envíe
                uno nuevo.
              </p>
            </div>

            <!-- Manual link -->
            <p style="font-size:12px;color:#999;word-break:break-all;margin:0;">
              Si el botón no funciona, copia este enlace en tu navegador:<br>
              <span style="color:#0D47A1;">${deepLink}</span>
            </p>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#f5f7fa;padding:20px 40px;text-align:center;">
            <p style="margin:0;font-size:12px;color:#aaa;">
              Si no esperabas esta invitación, puedes ignorar este mensaje.<br>
              © 2026 Fluix CRM · <a href="https://fluixtech.com"
                                    style="color:#0D47A1;">fluixtech.com</a>
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ── CLOUD FUNCTION ───────────────────────────────────────────────────────────

export const onInvitacionCreada = onDocumentCreated(
  {
    document: "invitaciones/{token}",
    region: REGION,
  },
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
    const expiresHours = 72;

    try {
      const transporter = crearTransporter();
      await transporter.sendMail({
        from: `"Fluix CRM" <${process.env.SMTP_USER}>`,
        to: email,
        subject: `Invitación para unirte a ${empresaNombre} en Fluix CRM`,
        html: buildInvitationEmail(
          empresaNombre,
          rolLabel,
          deepLink,
          expiresHours
        ),
      });

      // Marcar como email enviado
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

