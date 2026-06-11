/**
 * reservasPublicas.ts
 * Sistema de reservas MVP para negocios públicos.
 *
 * Path Firestore : negocios_publicos/{negocioId}/reservas/{reservationId}
 * Email destino  : negocios_publicos/{negocioId}.emailNotificaciones
 * Secreto JWT    : firebase functions:secrets:set JWT_SECRET
 *
 * Funciones exportadas:
 *   onReservaPublicaCreada  — onCreate trigger → email al negocio con botones JWT
 *   gestionarReservaPublica — HTTP GET/POST   → página intermedia + actualiza Firestore
 *   expirarReservasPublicas — Scheduled 5 min → marca expired + notifica cliente
 *
 * Índice Firestore requerido (collection group):
 *   Colección: reservas  |  status ASC  |  createdAt ASC
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as jwt from "jsonwebtoken";
import {
  enviarConfirmacionReserva,
  enviarCancelacionReserva,
} from "./resend_service";

const REGION = "europe-west1";
const ACTION_URL =
  "https://europe-west1-planeaapp-4bea4.cloudfunctions.net/gestionarReservaPublica";

// ── TIPOS ─────────────────────────────────────────────────────────────────────

export type ReservaStatus =
  | "pending"
  | "accepted"
  | "rejected"
  | "cancelled"
  | "expired";

export interface Reserva {
  customerName: string;
  customerEmail: string;
  phone?: string;
  date: string;       // "YYYY-MM-DD"
  time: string;       // "HH:MM"
  guests?: number;
  notes?: string;
  servicio?: string;
  status: ReservaStatus;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  usuarioUid?: string;
  mensajeNegocio?: string;
  aceptadoEn?: admin.firestore.Timestamp;
  rechazadoEn?: admin.firestore.Timestamp;
}

interface ReservaJwtPayload extends jwt.JwtPayload {
  reservationId: string;
  negocioId: string;
  action: "accept" | "reject";
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

const _secret = (): string =>
  process.env.JWT_SECRET || "fluixcrm-jwt-reservas-2026";

const _sign = (
  reservationId: string,
  negocioId: string,
  action: "accept" | "reject"
): string =>
  jwt.sign({ reservationId, negocioId, action }, _secret(), {
    expiresIn: "60m",
  });

const _verify = (token: string): ReservaJwtPayload =>
  jwt.verify(token, _secret()) as ReservaJwtPayload;

function fmtDateTime(date: string, time: string): string {
  try {
    return new Date(`${date}T${time}`).toLocaleString("es-ES", {
      weekday: "long",
      day: "numeric",
      month: "long",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return `${date} ${time}`;
  }
}

// ── EMAIL AL NEGOCIO ──────────────────────────────────────────────────────────

function buildEmailNegocio(opts: {
  negocioNombre: string;
  customerName: string;
  fechaHora: string;
  servicio: string;
  guests: string;
  notes: string;
  urlAccept: string;
  urlReject: string;
}): string {
  return `<!DOCTYPE html><html><head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f4f6fb;font-family:Arial,sans-serif;">
<table width="100%"><tr><td align="center" style="padding:32px 16px;">
<table width="600" style="background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
<tr><td style="background:linear-gradient(135deg,#0D47A1,#1976D2);padding:32px;text-align:center;">
  <h1 style="margin:0;color:white;font-size:26px;">🎉 Nueva Solicitud de Reserva</h1>
  <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;">Para <strong>${opts.negocioNombre}</strong></p>
</td></tr>
<tr><td style="padding:32px;">
  <table width="100%"><tr><td style="background:#f8f9fa;border-left:4px solid #0D47A1;padding:16px;border-radius:6px;">
    <table width="100%">
      <tr><td style="color:#666;width:140px;">👤 Cliente:</td><td><strong>${opts.customerName}</strong></td></tr>
      <tr><td style="color:#666;">📅 Fecha:</td><td><strong>${opts.fechaHora}</strong></td></tr>
      ${opts.servicio ? `<tr><td style="color:#666;">✂️ Servicio:</td><td>${opts.servicio}</td></tr>` : ""}
      ${opts.guests ? `<tr><td style="color:#666;">👥 Personas:</td><td>${opts.guests}</td></tr>` : ""}
      ${opts.notes ? `<tr><td style="color:#666;">💬 Notas:</td><td>${opts.notes}</td></tr>` : ""}
    </table>
  </td></tr></table>
  <p style="text-align:center;color:#E65100;font-size:13px;font-weight:bold;margin:24px 0 8px;">⚠️ Los botones expiran en 60 minutos</p>
  <h3 style="text-align:center;color:#0D47A1;margin:8px 0 16px;">¿Qué deseas hacer?</h3>
  <table width="100%"><tr>
    <td align="center" width="50%" style="padding:0 8px;">
      <a href="${opts.urlAccept}" style="display:block;background:#2E7D32;color:white;text-decoration:none;padding:16px;border-radius:10px;font-size:16px;font-weight:bold;text-align:center;">✅ ACEPTAR RESERVA</a>
    </td>
    <td align="center" width="50%" style="padding:0 8px;">
      <a href="${opts.urlReject}" style="display:block;background:#C62828;color:white;text-decoration:none;padding:16px;border-radius:10px;font-size:16px;font-weight:bold;text-align:center;">❌ RECHAZAR RESERVA</a>
    </td>
  </tr></table>
  <p style="text-align:center;color:#999;font-size:12px;margin-top:20px;">Gestiona también desde <a href="https://fluixtech.com" style="color:#0D47A1;">fluixtech.com</a></p>
</td></tr>
<tr><td style="background:#263238;padding:16px;text-align:center;">
  <p style="margin:0;color:#B0BEC5;font-size:12px;">Fluix CRM · Sistema de Reservas</p>
</td></tr>
</table></td></tr></table></body></html>`;
}

// ── HTML PÁGINAS INTERMEDIAS ──────────────────────────────────────────────────

const _CSS = `<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',Arial,sans-serif;background:linear-gradient(135deg,#0D47A1,#1976D2,#0097A7);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.card{background:white;padding:40px;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,.25);max-width:520px;width:100%}
h1{font-size:24px;margin-bottom:10px}
.info{background:#f8f9fa;padding:16px;border-radius:10px;margin:20px 0;font-size:14px;line-height:1.8}
textarea{width:100%;padding:12px;border:2px solid #ddd;border-radius:10px;font-size:14px;font-family:inherit;min-height:100px;resize:vertical;margin:10px 0}
textarea:focus{outline:none;border-color:#1976D2}
label{font-weight:600;color:#333;font-size:14px}
button{width:100%;padding:16px;font-size:16px;font-weight:700;border:none;border-radius:10px;cursor:pointer;margin-top:8px;transition:opacity .2s}
button:hover{opacity:.9}
.btn-g{background:#2E7D32;color:white}
.btn-r{background:#C62828;color:white}
.badge{display:inline-block;padding:8px 16px;border-radius:20px;font-size:13px;font-weight:600;margin-bottom:16px}
.g{background:#C8E6C9;color:#1B5E20}
.o{background:#FFE0B2;color:#BF360C}
.r{background:#FFCDD2;color:#B71C1C}
</style>`;

function paginaEstado(
  tipo: string,
  titulo: string,
  msg: string,
  color: "green" | "orange" | ""
): string {
  const cls = color === "green" ? "g" : color === "orange" ? "o" : "r";
  const em = color === "green" ? "✅" : color === "orange" ? "⚠️" : "❌";
  return `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${titulo}</title>${_CSS}</head>
<body><div class="card">
  <span class="badge ${cls}">${em} ${tipo.toUpperCase()}</span>
  <h1>${titulo}</h1>
  <p style="color:#666;margin-top:8px;">${msg}</p>
  <p style="margin-top:24px;color:#999;font-size:12px;text-align:center;">Puedes cerrar esta ventana.</p>
</div></body></html>`;
}

function _infoBox(r: Record<string, any>, ft: string): string {
  return `<div class="info">
    <strong>👤</strong> ${r.customerName || "Cliente"}<br>
    <strong>📅</strong> ${ft}
    ${r.servicio ? `<br><strong>✂️</strong> ${r.servicio}` : ""}
    ${r.guests ? `<br><strong>👥</strong> ${r.guests} personas` : ""}
    ${r.notes ? `<br><strong>💬</strong> ${r.notes}` : ""}
  </div>`;
}

function formAceptar(
  token: string,
  r: Record<string, any>,
  ft: string
): string {
  return `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Confirmar reserva</title>${_CSS}</head>
<body><div class="card">
  <span class="badge g">✅ CONFIRMAR</span>
  <h1>Confirmar Reserva</h1>
  ${_infoBox(r, ft)}
  <form method="POST">
    <input type="hidden" name="token" value="${token}">
    <label>Mensaje al cliente (opcional):</label>
    <textarea name="mensaje" placeholder="Ej: ¡Te esperamos! Recuerda traer confirmación."></textarea>
    <button type="submit" class="btn-g">✅ Confirmar y Notificar al Cliente</button>
  </form>
</div></body></html>`;
}

function formRechazar(
  token: string,
  r: Record<string, any>,
  ft: string
): string {
  return `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rechazar reserva</title>${_CSS}</head>
<body><div class="card">
  <span class="badge r">❌ RECHAZAR</span>
  <h1>Rechazar Reserva</h1>
  ${_infoBox(r, ft)}
  <form method="POST">
    <input type="hidden" name="token" value="${token}">
    <label>Motivo del rechazo:</label>
    <textarea name="motivo" placeholder="Ej: No hay disponibilidad para esa fecha." required></textarea>
    <button type="submit" class="btn-r">❌ Rechazar y Notificar al Cliente</button>
  </form>
</div></body></html>`;
}

// ── onReservaPublicaCreada ─────────────────────────────────────────────────────

export const onReservaPublicaCreada = onDocumentCreated(
  {
    document: "negocios_publicos/{negocioId}/reservas/{reservationId}",
    region: REGION,
    secrets: ["RESEND_API_KEY"],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const r = snap.data() as Partial<Reserva>;
    const { negocioId, reservationId } = event.params;

    const db = admin.firestore();
    const negocioSnap = await db
      .collection("negocios_publicos")
      .doc(negocioId)
      .get();
    if (!negocioSnap.exists) return;

    const nd = negocioSnap.data()!;
    const email: string = nd.emailNotificaciones || "";
    if (!email) {
      console.warn(
        `[reservas_pub] negocio ${negocioId} sin emailNotificaciones`
      );
      return;
    }
    const negocioNombre: string = nd.nombre || "Tu Negocio";

    const acceptToken = _sign(reservationId, negocioId, "accept");
    const rejectToken = _sign(reservationId, negocioId, "reject");
    const ft = fmtDateTime(r.date || "", r.time || "");

    const html = buildEmailNegocio({
      negocioNombre,
      customerName: r.customerName || "Un cliente",
      fechaHora: ft,
      servicio: r.servicio || "",
      guests: r.guests ? `${r.guests} persona${r.guests !== 1 ? "s" : ""}` : "",
      notes: r.notes || "",
      urlAccept: `${ACTION_URL}?token=${encodeURIComponent(acceptToken)}`,
      urlReject: `${ACTION_URL}?token=${encodeURIComponent(rejectToken)}`,
    });

    const { Resend } = await import("resend");
    const resend = new Resend(process.env.RESEND_API_KEY);
    await resend.emails.send({
      from: `${negocioNombre} vía Fluix <noreply@fluixtech.com>`,
      to: email,
      subject: `🎉 Nueva solicitud de ${r.customerName || "un cliente"} — ${ft}`,
      html,
    });
    console.log(
      `[reservas_pub] Email → ${email} | negocio=${negocioId} | reserva=${reservationId}`
    );
  }
);

// ── gestionarReservaPublica ───────────────────────────────────────────────────

export const gestionarReservaPublica = onRequest(
  { region: REGION, secrets: ["RESEND_API_KEY"] },
  async (req, res) => {
    // Token puede venir en query string (GET) o body hidden field (POST)
    const rawToken = (
      req.query.token ||
      req.body?.token ||
      ""
    ) as string;

    if (!rawToken) {
      res
        .status(400)
        .send(paginaEstado("error", "Enlace inválido", "Falta el parámetro token.", ""));
      return;
    }

    let payload: ReservaJwtPayload;
    try {
      payload = _verify(rawToken);
    } catch (e: any) {
      const expired = e?.name === "TokenExpiredError";
      res.status(403).send(
        paginaEstado(
          "error",
          expired ? "Enlace expirado" : "Enlace inválido",
          expired
            ? "Este enlace ha expirado. Los enlaces son válidos 60 minutos desde que se envió el email."
            : "El token no es válido o ha sido manipulado.",
          ""
        )
      );
      return;
    }

    const { reservationId, negocioId, action } = payload;
    const db = admin.firestore();
    const ref = db
      .collection("negocios_publicos")
      .doc(negocioId)
      .collection("reservas")
      .doc(reservationId);

    try {
      const snap = await ref.get();
      if (!snap.exists) {
        res
          .status(404)
          .send(paginaEstado("error", "No encontrada", "Esta reserva no existe.", ""));
        return;
      }
      const r = snap.data()!;

      if (r.status !== "pending") {
        const labels: Record<string, string> = {
          accepted: "Reserva ya confirmada",
          rejected: "Reserva ya rechazada",
          expired: "Reserva expirada",
          cancelled: "Reserva cancelada",
        };
        res.send(
          paginaEstado(
            r.status,
            labels[r.status] || "Reserva ya gestionada",
            "Esta reserva ya fue procesada anteriormente.",
            r.status === "accepted" ? "green" : "orange"
          )
        );
        return;
      }

      const ft = fmtDateTime(r.date || "", r.time || "");

      if (req.method === "GET") {
        res.send(
          action === "accept"
            ? formAceptar(rawToken, r, ft)
            : formRechazar(rawToken, r, ft)
        );
        return;
      }

      // POST: procesar confirmación o rechazo
      const mensaje = (
        (req.body?.mensaje || req.body?.motivo || "") as string
      ).trim();
      const newStatus: ReservaStatus =
        action === "accept" ? "accepted" : "rejected";

      await ref.update({
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(mensaje ? { mensajeNegocio: mensaje } : {}),
        ...(action === "accept"
          ? { aceptadoEn: admin.firestore.FieldValue.serverTimestamp() }
          : { rechazadoEn: admin.firestore.FieldValue.serverTimestamp() }),
      });

      const customerEmail = r.customerEmail as string | undefined;
      if (customerEmail) {
        const negocioSnap = await db
          .collection("negocios_publicos")
          .doc(negocioId)
          .get();
        const negocioNombre: string =
          (negocioSnap.data()?.nombre as string) || "El negocio";
        const base = {
          to: customerEmail,
          clienteNombre: (r.customerName as string) || "Cliente",
          empresaNombre: negocioNombre,
          fechaHora: ft,
          servicio: (r.servicio as string) || "",
          personas: r.guests ? `${r.guests} personas` : undefined,
        };
        if (action === "accept") {
          await enviarConfirmacionReserva({
            ...base,
            notas: mensaje || undefined,
          });
        } else {
          await enviarCancelacionReserva({
            ...base,
            motivoCancelacion: mensaje || "Sin motivo especificado",
          });
        }
      }

      res.send(
        action === "accept"
          ? paginaEstado(
              "confirmada",
              "¡Reserva Confirmada!",
              "El cliente recibirá un email de confirmación.",
              "green"
            )
          : paginaEstado(
              "rechazada",
              "Reserva No Aceptada",
              "El cliente recibirá un email de cancelación.",
              "orange"
            )
      );
    } catch (err) {
      console.error("[gestionar_reserva_pub]", err);
      res
        .status(500)
        .send(paginaEstado("error", "Error interno", String(err), ""));
    }
  }
);

// ── expirarReservasPublicas ───────────────────────────────────────────────────
// Requiere índice de collection group en Firestore:
//   Colección: reservas | Campos: status (Asc), createdAt (Asc)

export const expirarReservasPublicas = onSchedule(
  {
    schedule: "*/5 * * * *",
    region: REGION,
    secrets: ["RESEND_API_KEY"],
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000)
    );

    const snap = await db
      .collectionGroup("reservas")
      .where("status", "==", "pending")
      .where("createdAt", "<", cutoff)
      .get();

    if (snap.empty) return;

    const negocioCache = new Map<string, string>();
    const batch = db.batch();
    const emailTasks: Promise<void>[] = [];

    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        status: "expired" as ReservaStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const r = doc.data();
      const customerEmail = r.customerEmail as string | undefined;
      if (!customerEmail) continue;

      const negocioRef = doc.ref.parent.parent;
      if (!negocioRef) continue;
      const negocioId = negocioRef.id;

      emailTasks.push(
        (async () => {
          if (!negocioCache.has(negocioId)) {
            const nd = await negocioRef.get();
            negocioCache.set(
              negocioId,
              (nd.data()?.nombre as string) || "El negocio"
            );
          }
          const negocioNombre = negocioCache.get(negocioId)!;
          const ft = fmtDateTime(
            (r.date as string) || "",
            (r.time as string) || ""
          );
          await enviarCancelacionReserva({
            to: customerEmail,
            clienteNombre: (r.customerName as string) || "Cliente",
            empresaNombre: negocioNombre,
            fechaHora: ft,
            motivoCancelacion:
              "El negocio no respondió en el tiempo establecido (60 minutos). Puedes volver a solicitarlo.",
          }).catch((e) => console.error("[expire_email]", e));
        })()
      );
    }

    await batch.commit();
    await Promise.allSettled(emailTasks);
    console.log(`[expire_reservas_pub] ${snap.size} reservas expiradas`);
  }
);
