/**
 * nazariResumenEmail.ts
 * Función HTTP one-shot: lee todos los pedidos de Nazarí y envía un resumen
 * a info@editorialnazari.com usando Resend (ya configurado en producción).
 *
 * Uso:
 *   firebase deploy --only functions:enviarResumenNazari
 *   curl -X POST https://europe-west1-planeaapp-4bea4.cloudfunctions.net/enviarResumenNazari
 *
 * Eliminar tras el primer uso.
 */

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { enviarPdfGenerico } from "./resend_service";

const REGION  = "europe-west1";
const EID     = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const NOTIFY  = "info@editorialnazari.com";
const FROM    = "Editorial Nazarí <noreply@fluixtech.com>";

const db = admin.firestore();

// ── helpers ───────────────────────────────────────────────────────────────────

function _fmt(ts: unknown): string {
  if (!ts) return "—";
  if (typeof (ts as any).toDate === "function") {
    return (ts as any).toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  }
  if ((ts as any)._seconds !== undefined) {
    return new Date((ts as any)._seconds * 1000)
      .toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  }
  return String(ts);
}

function _fmtDir(dir: unknown): string {
  if (!dir) return "";
  if (typeof dir === "string") return dir.trim();
  if (typeof dir === "object") {
    const d = dir as Record<string, string>;
    return [d.nombre, d.linea1, d.linea2, `${d.cp || ""} ${d.ciudad || ""}`.trim(), d.pais]
      .filter(Boolean).join(", ");
  }
  return "";
}

function _metodoLabel(m: string): string {
  const map: Record<string, string> = {
    stripe: "Tarjeta (Stripe)", bizum: "Bizum", transferencia: "Transferencia",
  };
  return map[m] || m || "—";
}

function _estadoBadge(estado: string): string {
  const map: Record<string, string> = {
    completado: "#16a34a", entregado: "#16a34a", pagado: "#16a34a",
    pendiente_pago: "#d97706", pendiente: "#d97706",
    cancelado: "#dc2626",
  };
  const color = map[estado] || "#6b7280";
  return `<span style="display:inline-block;padding:2px 8px;border-radius:999px;background:${color};color:#fff;font-size:11px;font-weight:600;">${estado}</span>`;
}

function _buildResumenHtml(
  pedidos: Array<{ id: string; data: Record<string, unknown> }>
): string {
  const ahora = new Date().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
  const totalFacturado = pedidos.reduce((s, p) => s + (Number(p.data.total) || 0), 0);

  const filas = pedidos.map(({ id, data }) => {
    const ref     = id.slice(0, 8).toUpperCase();
    const fecha   = _fmt(data.fecha_creacion);
    const nombre  = String(data.nombre || "—");
    const email   = String(data.email  || "—");
    const telefono = String((data.direccion_envio as any)?.telefono || "—");
    const metodo  = _metodoLabel(String(data.metodo_pago || ""));
    const estado  = _estadoBadge(String(data.estado || "—"));
    const total   = typeof data.total === "number" ? `${data.total.toFixed(2)} €` : "—";
    const items   = Array.isArray(data.items) ? data.items as Array<Record<string, unknown>> : [];
    const dir     = _fmtDir(data.direccion_envio);

    const productosHtml = items.map((i) =>
      `<div style="font-size:12px;color:#374151;padding:1px 0;">
        · ${i.titulo || "—"} × ${i.cantidad || 1}
        ${i.es_ebook ? `<em style="color:#9ca3af;">(ebook)</em>` : ""}
        — ${typeof i.precio === "number" ? i.precio.toFixed(2) : "—"} €/u.
      </div>`
    ).join("");

    return `<tr style="vertical-align:top;">
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;font-size:13px;font-weight:600;color:#111827;white-space:nowrap;">#${ref}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;font-size:12px;color:#6b7280;white-space:nowrap;">${fecha}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;">
        <div style="font-size:13px;font-weight:500;color:#111827;">${nombre}</div>
        <div style="font-size:12px;color:#4f46e5;"><a href="mailto:${email}" style="color:#4f46e5;">${email}</a></div>
        <div style="font-size:12px;color:#6b7280;">${telefono !== "—" ? `📞 ${telefono}` : ""}</div>
        ${dir ? `<div style="font-size:11px;color:#9ca3af;margin-top:2px;">${dir}</div>` : ""}
      </td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;">${productosHtml}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;font-size:12px;color:#374151;">${metodo}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;">${estado}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e5e7eb;font-size:13px;font-weight:bold;color:#111827;text-align:right;white-space:nowrap;">${total}</td>
    </tr>`;
  }).join("");

  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Resumen de pedidos — Editorial Nazarí</title></head>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;margin:0;padding:24px 16px;">
  <table width="900" cellpadding="0" cellspacing="0"
         style="max-width:900px;margin:0 auto;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.08);">
    <tr>
      <td style="background:#1a1a2e;padding:22px 32px;">
        <span style="color:#fff;font-size:20px;font-weight:bold;">📋 Resumen de pedidos web — Editorial Nazarí</span>
      </td>
    </tr>
    <tr>
      <td style="padding:16px 32px;background:#f9fafb;border-bottom:1px solid #e5e7eb;">
        <span style="font-size:13px;color:#6b7280;">Generado el ${ahora}</span>
        &nbsp;·&nbsp;
        <span style="font-size:13px;font-weight:600;color:#111827;">${pedidos.length} pedidos</span>
        &nbsp;·&nbsp;
        <span style="font-size:13px;font-weight:600;color:#059669;">Total: ${totalFacturado.toFixed(2)} €</span>
      </td>
    </tr>
    <tr>
      <td style="padding:20px 24px;overflow-x:auto;">
        <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;font-size:13px;">
          <thead>
            <tr style="background:#f3f4f6;">
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">REF</th>
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">FECHA</th>
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">CLIENTE</th>
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">PRODUCTOS</th>
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">PAGO</th>
              <th style="padding:8px;text-align:left;font-size:11px;color:#6b7280;font-weight:600;">ESTADO</th>
              <th style="padding:8px;text-align:right;font-size:11px;color:#6b7280;font-weight:600;">TOTAL</th>
            </tr>
          </thead>
          <tbody>${filas}</tbody>
          <tfoot>
            <tr>
              <td colspan="6" style="padding:12px 8px;font-size:14px;font-weight:bold;color:#111827;border-top:2px solid #111827;">TOTAL FACTURADO</td>
              <td style="padding:12px 8px;text-align:right;font-size:14px;font-weight:bold;color:#059669;border-top:2px solid #111827;">${totalFacturado.toFixed(2)} €</td>
            </tr>
          </tfoot>
        </table>
      </td>
    </tr>
    <tr>
      <td style="background:#f9fafb;padding:14px 32px;text-align:center;border-top:1px solid #e5e7eb;">
        <p style="margin:0;font-size:11px;color:#9ca3af;">Notificación automática · Editorial Nazarí · Fluix CRM</p>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ── Cloud Function HTTP (one-shot) ────────────────────────────────────────────

export const enviarResumenNazari = onRequest(
  { region: REGION, cors: false, secrets: ["RESEND_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("POST only");
      return;
    }

    // Permite sobrescribir el destinatario desde el body: { "to": "otro@email.com" }
    const destinatario: string = (req.body?.to as string) || NOTIFY;

    console.log(`[enviarResumenNazari] Enviando a: ${destinatario}`);

    let pedidos: Array<{ id: string; data: Record<string, unknown> }> = [];
    try {
      // Incluye: pagados + transferencias/bizum pendientes (pedidos reales)
      // Excluye: carritos Stripe abandonados, simulaciones, cancelados
      const snap = await db
        .collection("empresas").doc(EID)
        .collection("pedidos_web_nazari")
        .get();

      pedidos = snap.docs
        .map((d) => ({ id: d.id, data: d.data() as Record<string, unknown> }))
        .filter((p) => {
          const metodo     = String(p.data.metodo_pago || "");
          const estadoPago = String(p.data.estado_pago || "");
          const estado     = String(p.data.estado      || "");
          if (metodo === "simulacion")    return false;  // tests
          if (estado === "cancelado")     return false;  // cancelados
          // Stripe: solo si ya está pagado (excluye sesiones abandonadas)
          if (metodo === "stripe" && estadoPago !== "pagado") return false;
          return true;
        })
        .sort((a, b) => {
          const ta = (a.data.fecha_creacion as any)?._seconds ?? 0;
          const tb = (b.data.fecha_creacion as any)?._seconds ?? 0;
          return tb - ta;
        });
      console.log(`[enviarResumenNazari] ${pedidos.length} pedidos encontrados`);
    } catch (err) {
      console.error("[enviarResumenNazari] Error leyendo Firestore:", err);
      res.status(500).json({ error: "Error leyendo pedidos" });
      return;
    }

    if (pedidos.length === 0) {
      res.status(200).json({ ok: true, message: "Sin pedidos — no se envió email" });
      return;
    }

    const html = _buildResumenHtml(pedidos);

    try {
      const result = await enviarPdfGenerico({
        from: FROM,
        to: destinatario,
        subject: `📋 Resumen de pedidos web — ${pedidos.length} pedidos (Editorial Nazarí)`,
        html,
      });

      if (result.exito) {
        console.log(`✅ [enviarResumenNazari] Email enviado a ${destinatario}. ${pedidos.length} pedidos.`);
        res.status(200).json({ ok: true, to: destinatario, pedidos: pedidos.length, resend_id: result.id });
      } else {
        console.error("[enviarResumenNazari] Resend error:", result.error);
        res.status(500).json({ ok: false, error: result.error });
      }
    } catch (err) {
      console.error("[enviarResumenNazari] Error enviando email:", err);
      res.status(500).json({ ok: false, error: String(err) });
    }
  }
);
