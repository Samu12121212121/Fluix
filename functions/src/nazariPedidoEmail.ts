/**
 * nazariPedidoEmail.ts
 * Notifica a info@editorialnazari.com cuando un pedido web de Nazarí queda pagado.
 *
 * Trigger: onDocumentUpdated — dispara cuando estado_pago cambia a "pagado".
 * Cubre los tres métodos de pago:
 *   - Stripe: webhook actualiza estado_pago → "pagado" al confirmar el cobro
 *   - Bizum/Transferencia: el admin marca el pago manualmente en Fluix
 *
 * Idempotente: marca emailNotificado:true tras envío exitoso.
 */

import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { enviarPdfGenerico } from "./resend_service";

const REGION     = "europe-west1";
const NAZARI_EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const NOTIFY_TO  = "info@editorialnazari.com";
const FROM       = "Editorial Nazarí <noreply@fluixtech.com>";

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

function _formatDireccion(dir: unknown): string | null {
  if (!dir) return null;
  if (typeof dir === "string") return dir.trim() || null;
  if (typeof dir === "object") {
    const d = dir as Record<string, string>;
    return [
      d.nombre,
      d.linea1,
      d.linea2,
      d.cp && d.ciudad ? `${d.cp} ${d.ciudad}`.trim() : d.ciudad || d.cp,
      d.pais,
    ].filter((p): p is string => Boolean(p && String(p).trim())).join(", ") || null;
  }
  return null;
}

function _buildHtml(pedidoId: string, data: Record<string, unknown>): string {
  const ref      = pedidoId.slice(0, 8).toUpperCase();
  const fecha    = _fmt(data.fecha_creacion);
  const nombre   = String(data.nombre      || "—");
  const email    = String(data.email       || "—");
  const metodo   = String(data.metodo_pago || "—");
  const telefono = String((data.direccion_envio as any)?.telefono || "—");
  const subtotal = typeof data.subtotal === "number" ? data.subtotal.toFixed(2) : null;
  const envio    = typeof data.envio    === "number" ? data.envio.toFixed(2)    : null;
  const total    = typeof data.total    === "number" ? data.total.toFixed(2)    : "—";
  const direccion = _formatDireccion(data.direccion_envio);

  const items = Array.isArray(data.items)
    ? (data.items as Array<Record<string, unknown>>)
    : [];

  const lineasHtml = items.map((i) => {
    const titulo   = String(i.titulo   || "—");
    const cantidad = Number(i.cantidad || 1);
    const precio   = typeof i.precio === "number" ? i.precio : 0;
    const tipoTag  = i.es_ebook
      ? ` <em style="color:#6b7280;font-size:11px;">(ebook)</em>`
      : "";
    return `
      <tr>
        <td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;">${titulo}${tipoTag}</td>
        <td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;text-align:center;">${cantidad}</td>
        <td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;text-align:right;">${precio.toFixed(2)} €</td>
        <td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;text-align:right;">${(precio * cantidad).toFixed(2)} €</td>
      </tr>`;
  }).join("");

  const subtotalRow = subtotal
    ? `<tr><td style="padding:4px 0;color:#6b7280;font-size:14px;">Subtotal productos</td><td style="padding:4px 0;text-align:right;font-size:14px;">${subtotal} €</td></tr>`
    : "";
  const envioRow = envio
    ? `<tr><td style="padding:4px 0;color:#6b7280;font-size:14px;">Gastos de envío</td><td style="padding:4px 0;text-align:right;font-size:14px;">${envio} €</td></tr>`
    : "";
  const dirRow = direccion
    ? `<h3 style="margin:0 0 6px;font-size:13px;color:#374151;text-transform:uppercase;letter-spacing:.4px;">Dirección de envío</h3>
       <p style="margin:0 0 20px;color:#374151;font-size:14px;line-height:1.6;">${direccion.replace(/\n/g, "<br>")}</p>`
    : "";

  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Pedido pagado #${ref}</title></head>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;margin:0;padding:32px 16px;">
  <table width="600" cellpadding="0" cellspacing="0"
         style="max-width:600px;margin:0 auto;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.08);">
    <tr>
      <td style="background:#1a1a2e;padding:22px 32px;">
        <span style="color:#fff;font-size:18px;font-weight:bold;">✅ Pedido pagado — Editorial Nazarí</span>
      </td>
    </tr>
    <tr>
      <td style="padding:24px 32px;">
        <p style="margin:0 0 4px;font-size:18px;font-weight:bold;color:#111827;">Pedido #${ref}</p>
        <p style="margin:0 0 22px;font-size:13px;color:#6b7280;">${fecha}</p>

        <h3 style="margin:0 0 8px;font-size:13px;color:#374151;text-transform:uppercase;letter-spacing:.4px;">Cliente</h3>
        <table cellpadding="0" cellspacing="0" style="margin-bottom:22px;width:100%;">
          <tr>
            <td style="padding:3px 0;color:#6b7280;font-size:14px;width:130px;">Nombre</td>
            <td style="padding:3px 0;color:#111827;font-size:14px;font-weight:500;">${nombre}</td>
          </tr>
          <tr>
            <td style="padding:3px 0;color:#6b7280;font-size:14px;">Email</td>
            <td style="padding:3px 0;font-size:14px;"><a href="mailto:${email}" style="color:#4f46e5;">${email}</a></td>
          </tr>
          <tr>
            <td style="padding:3px 0;color:#6b7280;font-size:14px;">Teléfono</td>
            <td style="padding:3px 0;color:#111827;font-size:14px;">${telefono}</td>
          </tr>
          <tr>
            <td style="padding:3px 0;color:#6b7280;font-size:14px;">Método de pago</td>
            <td style="padding:3px 0;color:#111827;font-size:14px;">${metodo}</td>
          </tr>
        </table>

        <h3 style="margin:0 0 8px;font-size:13px;color:#374151;text-transform:uppercase;letter-spacing:.4px;">Productos</h3>
        <table width="100%" cellpadding="0" cellspacing="0"
               style="border-collapse:collapse;margin-bottom:16px;font-size:14px;">
          <thead>
            <tr style="background:#f9fafb;">
              <th style="padding:8px 10px;text-align:left;font-size:12px;color:#6b7280;font-weight:600;">Producto</th>
              <th style="padding:8px 10px;text-align:center;font-size:12px;color:#6b7280;font-weight:600;">Cant.</th>
              <th style="padding:8px 10px;text-align:right;font-size:12px;color:#6b7280;font-weight:600;">Precio</th>
              <th style="padding:8px 10px;text-align:right;font-size:12px;color:#6b7280;font-weight:600;">Importe</th>
            </tr>
          </thead>
          <tbody>${lineasHtml}</tbody>
        </table>

        <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
          ${subtotalRow}
          ${envioRow}
          <tr>
            <td style="padding:10px 0 4px;font-size:16px;font-weight:bold;color:#111827;border-top:2px solid #e5e7eb;">TOTAL</td>
            <td style="padding:10px 0 4px;text-align:right;font-size:16px;font-weight:bold;color:#059669;border-top:2px solid #e5e7eb;">${total} €</td>
          </tr>
        </table>

        ${dirRow}
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

// ── Cloud Function ────────────────────────────────────────────────────────────

export const onNuevoPedidoWebNazariEmail = onDocumentUpdated(
  {
    document: `empresas/${NAZARI_EID}/pedidos_web_nazari/{pedidoId}`,
    region: REGION,
    secrets: ["RESEND_API_KEY"],
  },
  async (event) => {
    const pedidoId = event.params.pedidoId;
    const antes    = event.data?.before.data() as Record<string, unknown> | undefined;
    const despues  = event.data?.after.data()  as Record<string, unknown> | undefined;
    if (!antes || !despues) return;

    // Solo disparar cuando estado_pago cambia de !pagado → pagado
    if (antes.estado_pago === "pagado") return;
    if (despues.estado_pago !== "pagado") return;

    // Excluir simulaciones de prueba
    if (despues.metodo_pago === "simulacion") return;

    // Idempotencia
    if (despues.emailNotificado === true) {
      console.log(`[nazariPedidoEmail] pedido ${pedidoId} ya notificado — omitiendo`);
      return;
    }

    const ref    = pedidoId.slice(0, 8).toUpperCase();
    const nombre = String(despues.nombre || "Cliente");
    const total  = typeof despues.total === "number" ? despues.total.toFixed(2) : "—";
    const html   = _buildHtml(pedidoId, despues);

    try {
      const result = await enviarPdfGenerico({
        from: FROM,
        to: NOTIFY_TO,
        subject: `✅ Pedido pagado #${ref} — ${nombre} (${total} €)`,
        html,
      });

      if (result.exito) {
        console.log(`✅ [nazariPedidoEmail] email enviado para pedido ${pedidoId}`);
        await db
          .collection("empresas").doc(NAZARI_EID)
          .collection("pedidos_web_nazari").doc(pedidoId)
          .update({
            emailNotificado:   true,
            emailNotificadoAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } else {
        console.error(`❌ [nazariPedidoEmail] Resend error para ${pedidoId}:`, result.error);
      }
    } catch (err) {
      console.error(`❌ [nazariPedidoEmail] fallo para pedido ${pedidoId}:`, err);
    }
  }
);
