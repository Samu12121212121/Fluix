import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { enviarConfirmacionReserva, enviarCancelacionReserva } from "./resend_service";

const REGION = "europe-west1";
const BASE_URL = "https://fluixtech.com/reservas";

function generarToken(reservaId: string, empresaId: string, accion: string): string {
  const secreto = process.env.RESERVAS_TOKEN_SECRET || "fluixcrm-reservas-2026";
  return crypto.createHmac("sha256", secreto).update(`${reservaId}:${empresaId}:${accion}`).digest("hex").substring(0, 32);
}

function buildEmailEmpresa(opts: {
  negocioNombre: string; clienteNombre: string; fechaHora: string;
  servicio: string; personas: string; notas: string;
  camposExtra: Record<string, any>; urlAceptar: string; urlRechazar: string;
}): string {
  const extras = Object.entries(opts.camposExtra).map(([k, v]) =>
    `<tr><td style="color:#666;padding:4px 0;width:140px;">${k}:</td><td>${v}</td></tr>`).join("");
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
      <tr><td style="color:#666;width:140px;">👤 Cliente:</td><td><strong>${opts.clienteNombre}</strong></td></tr>
      <tr><td style="color:#666;">📅 Fecha:</td><td><strong>${opts.fechaHora}</strong></td></tr>
      ${opts.servicio ? `<tr><td style="color:#666;">✂️ Servicio:</td><td>${opts.servicio}</td></tr>` : ""}
      ${opts.personas ? `<tr><td style="color:#666;">👥 Personas:</td><td>${opts.personas}</td></tr>` : ""}
      ${opts.notas ? `<tr><td style="color:#666;">💬 Notas:</td><td>${opts.notas}</td></tr>` : ""}
      ${extras}
    </table>
  </td></tr></table>
  <h3 style="text-align:center;color:#0D47A1;margin:28px 0 16px;">¿Qué deseas hacer?</h3>
  <table width="100%"><tr>
    <td align="center" width="50%" style="padding:0 8px;">
      <a href="${opts.urlAceptar}" style="display:block;background:#2E7D32;color:white;text-decoration:none;padding:16px;border-radius:10px;font-size:16px;font-weight:bold;text-align:center;">✅ ACEPTAR RESERVA</a>
    </td>
    <td align="center" width="50%" style="padding:0 8px;">
      <a href="${opts.urlRechazar}" style="display:block;background:#C62828;color:white;text-decoration:none;padding:16px;border-radius:10px;font-size:16px;font-weight:bold;text-align:center;">❌ RECHAZAR RESERVA</a>
    </td>
  </tr></table>
  <p style="text-align:center;color:#999;font-size:12px;margin-top:20px;">Gestiona también desde <a href="https://fluixtech.com" style="color:#0D47A1;">fluixtech.com</a></p>
</td></tr>
<tr><td style="background:#263238;padding:16px;text-align:center;"><p style="margin:0;color:#B0BEC5;font-size:12px;">Fluix CRM · Sistema de Reservas</p></td></tr>
</table></td></tr></table></body></html>`;
}

// ── EMAIL al crear reserva de app_cliente (push/in-app está en index.ts) ─────
export const onNuevaReservaEmail = onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION, secrets: ["RESEND_API_KEY", "RESERVAS_TOKEN_SECRET"] },
  async (event) => {
    const snap = event.data; if (!snap) return;
    const r = snap.data(); const empresaId = event.params.empresaId; const reservaId = event.params.reservaId;
    const origen: string = r.origen || "";
    if (origen !== "app_cliente" && origen !== "web_publica") return;
    const db = admin.firestore();
    let ft = "";
    try { const d = r.fecha_hora?.toDate ? r.fecha_hora.toDate() : new Date(r.fecha_hora); ft = d.toLocaleString("es-ES", { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }); } catch (_) {}
    const cn = r.nombre_cliente || r.cliente_nombre || r.usuario_nombre || "Un cliente";
    try {
      const ns = await db.collection("negocios_publicos").where("empresaIdVinculada", "==", empresaId).limit(1).get();
      if (ns.empty) return;
      const nd = ns.docs[0].data(); const email: string = nd.emailNotificaciones || ""; if (!email) return;
      const nn: string = nd.nombre || "Tu Negocio";
      const ta = generarToken(reservaId, empresaId, "aceptar"); const tr = generarToken(reservaId, empresaId, "rechazar");
      const html = buildEmailEmpresa({ negocioNombre: nn, clienteNombre: cn, fechaHora: ft || "No especificada", servicio: r.servicio_nombre || r.servicio || "", personas: r.numero_personas ? `${r.numero_personas} personas` : "", notas: r.notas || "", camposExtra: r.campos_extra || {}, urlAceptar: `${BASE_URL}/confirmar?id=${reservaId}&empresa=${empresaId}&token=${ta}`, urlRechazar: `${BASE_URL}/rechazar?id=${reservaId}&empresa=${empresaId}&token=${tr}` });
      const { Resend } = await import("resend"); const c = new Resend(process.env.RESEND_API_KEY);
      await c.emails.send({ from: `${nn} vía Fluix <noreply@fluixtech.com>`, to: email, subject: `🎉 Nueva reserva de ${cn} — ${ft}`, html });
      await db.collection("reservas_tokens").doc(reservaId).set({ token_aceptar: ta, token_rechazar: tr, empresa_id: empresaId, reserva_id: reservaId, expira_en: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 86400000)), creado_en: admin.firestore.FieldValue.serverTimestamp() });
      console.log(`[email] Enviado a ${email}`);
    } catch (err) { console.error("[email]", err); }
  }
);

// ── TRIGGER colección notificaciones_reservas (desde Flutter) ────────────────
export const onNuevaNotificacionReserva = onDocumentCreated(
  { document: "notificaciones_reservas/{docId}", region: REGION, secrets: ["RESEND_API_KEY", "RESERVAS_TOKEN_SECRET"] },
  async (event) => {
    const snap = event.data; if (!snap) return;
    const data = snap.data(); if (data.procesado) return;
    await snap.ref.update({ procesado: true });
    const db = admin.firestore();
    const reservaId: string = data.reserva_id; const empresaId: string = data.empresa_id;
    const email: string = data.email_notificaciones || ""; if (!email) return;
    const nn: string = data.negocio_nombre || "Tu Negocio"; const dr: Record<string, any> = data.datos_reserva || {};
    let ft = "";
    try { const fh = dr.fecha_hora?.toDate ? dr.fecha_hora.toDate() : new Date(dr.fecha_hora); ft = fh.toLocaleString("es-ES", { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }); } catch (_) {}
    const cn = dr.usuario_nombre || dr.nombre_cliente || "Cliente";
    const ta = generarToken(reservaId, empresaId, "aceptar"); const tr = generarToken(reservaId, empresaId, "rechazar");
    const html = buildEmailEmpresa({ negocioNombre: nn, clienteNombre: cn, fechaHora: ft || "No especificada", servicio: dr.servicio_nombre || "", personas: dr.numero_personas ? `${dr.numero_personas} personas` : "", notas: dr.notas || "", camposExtra: dr.campos_extra || {}, urlAceptar: `${BASE_URL}/confirmar?id=${reservaId}&empresa=${empresaId}&token=${ta}`, urlRechazar: `${BASE_URL}/rechazar?id=${reservaId}&empresa=${empresaId}&token=${tr}` });
    try {
      const { Resend } = await import("resend"); const c = new Resend(process.env.RESEND_API_KEY);
      await c.emails.send({ from: `${nn} vía Fluix <noreply@fluixtech.com>`, to: email, subject: `🎉 Nueva reserva de ${cn} — ${ft}`, html });
      await db.collection("reservas_tokens").doc(reservaId).set({ token_aceptar: ta, token_rechazar: tr, empresa_id: empresaId, reserva_id: reservaId, expira_en: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 86400000)), creado_en: admin.firestore.FieldValue.serverTimestamp() });
    } catch (err) { console.error("[notif_reserva]", err); }
  }
);

// ── HTTP: Confirmar reserva ───────────────────────────────────────────────────
export const confirmarReserva = onRequest(
  { region: REGION, secrets: ["RESEND_API_KEY", "RESERVAS_TOKEN_SECRET"] },
  async (req, res) => {
    const { id: rid, empresa: eid, token, mensaje = "" } = req.query as Record<string, string>;
    if (!rid || !eid || !token) { res.status(400).send(_land("error", "Enlace inválido", "Faltan parámetros.", "")); return; }
    if (token !== generarToken(rid, eid, "aceptar")) { res.status(403).send(_land("error", "Token inválido", "Enlace no válido.", "")); return; }
    const db = admin.firestore();
    try {
      const ref = db.collection("empresas").doc(eid).collection("reservas").doc(rid);
      const s = await ref.get(); if (!s.exists) { res.status(404).send(_land("error", "No encontrada", "Esta reserva no existe.", "")); return; }
      const rd = s.data()!;
      if (rd.estado === "confirmada") { res.send(_land("ya_confirmada", "Ya confirmada", "Ya fue confirmada anteriormente.", "green")); return; }
      let ft = ""; try { const fh = rd.fecha_hora?.toDate ? rd.fecha_hora.toDate() : new Date(rd.fecha_hora); ft = fh.toLocaleString("es-ES", { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }); } catch (_) {}
      if (req.method === "GET") { res.send(_formConfirmar(rid, eid, token, rd, ft)); return; }
      await ref.update({ estado: "confirmada", confirmado_en: admin.firestore.FieldValue.serverTimestamp() });
      const ec: string = rd.email_cliente || rd.usuario_email || "";
      if (ec) {
        const ns = await db.collection("negocios_publicos").where("empresaIdVinculada", "==", eid).limit(1).get();
        const nn = ns.empty ? "El negocio" : ns.docs[0].data().nombre;
        await enviarConfirmacionReserva({ to: ec, clienteNombre: rd.nombre_cliente || rd.usuario_nombre || "Cliente", empresaNombre: nn, fechaHora: ft, servicio: rd.servicio_nombre || "", notas: mensaje || undefined });
      }
      res.send(_land("confirmada", "¡Reserva Confirmada!", "El cliente recibirá un email.", "green"));
    } catch (err) { console.error("[confirmar]", err); res.status(500).send(_land("error", "Error", String(err), "")); }
  }
);

// ── HTTP: Rechazar reserva ────────────────────────────────────────────────────
export const rechazarReserva = onRequest(
  { region: REGION, secrets: ["RESEND_API_KEY", "RESERVAS_TOKEN_SECRET"] },
  async (req, res) => {
    const { id: rid, empresa: eid, token, motivo = "" } = req.query as Record<string, string>;
    if (!rid || !eid || !token) { res.status(400).send(_land("error", "Enlace inválido", "Faltan parámetros.", "")); return; }
    if (token !== generarToken(rid, eid, "rechazar")) { res.status(403).send(_land("error", "Token inválido", "Enlace no válido.", "")); return; }
    const db = admin.firestore();
    try {
      const ref = db.collection("empresas").doc(eid).collection("reservas").doc(rid);
      const s = await ref.get(); if (!s.exists) { res.status(404).send(_land("error", "No encontrada", "Esta reserva no existe.", "")); return; }
      const rd = s.data()!;
      if (rd.estado === "cancelada" || rd.estado === "rechazada") { res.send(_land("ya_gestionada", "Ya gestionada", "Ya fue rechazada.", "orange")); return; }
      let ft = ""; try { const fh = rd.fecha_hora?.toDate ? rd.fecha_hora.toDate() : new Date(rd.fecha_hora); ft = fh.toLocaleString("es-ES", { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }); } catch (_) {}
      if (req.method === "GET") { res.send(_formRechazar(rid, eid, token, rd, ft)); return; }
      await ref.update({ estado: "cancelada", motivo_cancelacion: motivo, rechazado_en: admin.firestore.FieldValue.serverTimestamp() });
      const ec: string = rd.email_cliente || rd.usuario_email || "";
      if (ec) {
        const ns = await db.collection("negocios_publicos").where("empresaIdVinculada", "==", eid).limit(1).get();
        const nn = ns.empty ? "El negocio" : ns.docs[0].data().nombre;
        await enviarCancelacionReserva({ to: ec, clienteNombre: rd.nombre_cliente || rd.usuario_nombre || "Cliente", empresaNombre: nn, fechaHora: ft, motivoCancelacion: motivo || "Sin motivo especificado" });
      }
      res.send(_land("rechazada", "Reserva No Aceptada", "Se ha notificado al cliente.", "orange"));
    } catch (err) { console.error("[rechazar]", err); res.status(500).send(_land("error", "Error", String(err), "")); }
  }
);

// ── Landing pages ─────────────────────────────────────────────────────────────
const _CSS = `<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:'Segoe UI',Arial,sans-serif;background:linear-gradient(135deg,#0D47A1,#1976D2,#0097A7);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.card{background:white;padding:40px;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,.25);max-width:520px;width:100%}h1{font-size:26px;margin-bottom:10px}.info{background:#f8f9fa;padding:16px;border-radius:10px;margin:20px 0;font-size:14px;line-height:1.7}textarea{width:100%;padding:12px;border:2px solid #ddd;border-radius:10px;font-size:14px;font-family:inherit;min-height:100px;resize:vertical;margin:10px 0}label{font-weight:600;color:#333;font-size:14px}button{width:100%;padding:16px;font-size:16px;font-weight:700;border:none;border-radius:10px;cursor:pointer;margin-top:8px}.btn-g{background:#2E7D32;color:white}.btn-r{background:#C62828;color:white}.badge{display:inline-block;padding:8px 16px;border-radius:20px;font-size:13px;font-weight:600;margin-bottom:16px}.g{background:#C8E6C9;color:#1B5E20}.o{background:#FFE0B2;color:#BF360C}.r{background:#FFCDD2;color:#B71C1C}</style>`;

function _land(tipo: string, titulo: string, msg: string, color: string): string {
  const cls = color === "green" ? "g" : color === "orange" ? "o" : "r";
  const em = color === "green" ? "✅" : color === "orange" ? "⚠️" : "❌";
  return `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">${_CSS}</head><body><div class="card"><span class="badge ${cls}">${em} ${tipo.replace(/_/g," ").toUpperCase()}</span><h1>${titulo}</h1><p style="color:#666;margin-top:8px;">${msg}</p><p style="margin-top:24px;color:#999;font-size:12px;text-align:center;">Puedes cerrar esta ventana.</p></div></body></html>`;
}

function _infoBox(d: Record<string, any>, ft: string): string {
  return `<div class="info"><strong>👤</strong> ${d.nombre_cliente || d.usuario_nombre || "Cliente"}<br><strong>📅</strong> ${ft}${d.servicio_nombre ? `<br><strong>✂️</strong> ${d.servicio_nombre}` : ""}${d.numero_personas ? `<br><strong>👥</strong> ${d.numero_personas} personas` : ""}${d.notas ? `<br><strong>💬</strong> ${d.notas}` : ""}</div>`;
}

function _formConfirmar(id: string, emp: string, tok: string, d: Record<string, any>, ft: string): string {
  return `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">${_CSS}</head><body><div class="card"><span class="badge g">✅ CONFIRMAR</span><h1>Confirmar Reserva</h1>${_infoBox(d, ft)}<form method="POST" action="/confirmarReserva?id=${id}&empresa=${emp}&token=${tok}"><label>Mensaje al cliente (opcional):</label><textarea name="mensaje" placeholder="Ej: ¡Te esperamos!"></textarea><button type="submit" class="btn-g">✅ Confirmar y Notificar</button></form></div></body></html>`;
}

function _formRechazar(id: string, emp: string, tok: string, d: Record<string, any>, ft: string): string {
  return `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">${_CSS}</head><body><div class="card"><span class="badge r">❌ RECHAZAR</span><h1>Rechazar Reserva</h1>${_infoBox(d, ft)}<form method="POST" action="/rechazarReserva?id=${id}&empresa=${emp}&token=${tok}"><label>Motivo del rechazo:</label><textarea name="motivo" placeholder="Ej: No hay disponibilidad." required></textarea><button type="submit" class="btn-r">❌ Rechazar y Notificar</button></form></div></body></html>`;
}
