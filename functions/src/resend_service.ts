/**
 * resend_service.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Servicio centralizado de emails con Resend.
 *
 * CONFIGURACIÓN:
 *   firebase functions:secrets:set RESEND_API_KEY
 *   Dominio verificado en Resend: fluixtech.com
 *   Remitente: noreply@fluixtech.com (o el que configures en Resend)
 *
 * TEMPLATES disponibles:
 *   - factura          → enviarFactura()
 *   - nomina           → enviarNomina()
 *   - bienvenida       → enviarBienvenida()
 *   - cita             → enviarCita()
 *   - invitacion       → enviarInvitacion()
 *   - recordatorio_pago → enviarRecordatorioPago()
 *   - pago_recibido    → enviarPagoRecibido()
 *   - bienvenida_fluix → enviarBienvenidaFluix()   (Fluix → sus clientes)
 *   - suscripcion_renovada → enviarSuscripcionRenovada()
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { Resend } from "resend";
import * as fs from "fs";
import * as path from "path";

// ──────────────────────────────────────────────────────────────────────────────
// TIPOS
// ──────────────────────────────────────────────────────────────────────────────

export interface EmailResult {
  exito: boolean;
  id?: string;
  error?: string;
}

export interface AttachmentResend {
  filename: string;
  content: Buffer;
}

// ──────────────────────────────────────────────────────────────────────────────
// HELPER: TEMPLATE ENGINE (simple {{variable}} replacement)
// ──────────────────────────────────────────────────────────────────────────────

function buildTemplate(templateName: string, vars: Record<string, string>): string {
  const filePath = path.join(__dirname, "templates", `${templateName}.html`);
  if (!fs.existsSync(filePath)) {
    console.warn(`⚠️ Template no encontrado: ${templateName}.html`);
    return fallbackHtml(templateName, vars);
  }
  let html = fs.readFileSync(filePath, "utf-8");
  for (const [key, value] of Object.entries(vars)) {
    html = html.replace(new RegExp(`{{${key}}}`, "g"), value || "");
  }
  // Limpiar variables no usadas
  html = html.replace(/{{[^}]+}}/g, "");
  return html;
}

function fallbackHtml(name: string, vars: Record<string, string>): string {
  return `<html><body style="font-family:sans-serif;padding:20px;">
    <h2>${name}</h2>
    <ul>${Object.entries(vars).map(([k,v]) => `<li><b>${k}:</b> ${v}</li>`).join("")}</ul>
  </body></html>`;
}

// ──────────────────────────────────────────────────────────────────────────────
// CLIENTE RESEND (singleton)
// ──────────────────────────────────────────────────────────────────────────────

function getResend(): Resend {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) throw new Error("RESEND_API_KEY no configurado. Ejecuta: firebase functions:secrets:set RESEND_API_KEY");
  return new Resend(apiKey);
}

const DEFAULT_FROM = "Fluix CRM <noreply@fluixtech.com>";

// ──────────────────────────────────────────────────────────────────────────────
// FUNCIÓN BASE
// ──────────────────────────────────────────────────────────────────────────────

async function enviar(opts: {
  from?: string;
  to: string;
  subject: string;
  html: string;
  attachments?: AttachmentResend[];
}): Promise<EmailResult> {
  try {
    const resend = getResend();
    const payload: any = {
      from: opts.from || DEFAULT_FROM,
      to: opts.to,
      subject: opts.subject,
      html: opts.html,
    };
    if (opts.attachments && opts.attachments.length > 0) {
      payload.attachments = opts.attachments.map((a) => ({
        filename: a.filename,
        content: a.content.toString("base64"),
      }));
    }
    const { data, error } = await resend.emails.send(payload);
    if (error) {
      console.error("❌ Resend error:", error);
      return { exito: false, error: error.message };
    }
    console.log(`✅ Email enviado via Resend: ${data?.id} → ${opts.to}`);
    return { exito: true, id: data?.id };
  } catch (e: any) {
    console.error("❌ Resend excepción:", e.message);
    return { exito: false, error: e.message };
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EMAILS TRANSACCIONALES — EMPRESAS (los clientes de Fluix CRM enviando a sus clientes)
// ──────────────────────────────────────────────────────────────────────────────

/** Envía una factura en PDF adjunto */
export async function enviarFactura(opts: {
  to: string;
  numeroFactura: string;
  fechaFactura: string;
  clienteNombre: string;
  empresaNombre: string;
  empresaDireccion?: string;
  importeTotal: string;
  pdf: Buffer;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("factura", {
    numeroFactura: opts.numeroFactura,
    fecha: opts.fechaFactura,
    clienteNombre: opts.clienteNombre,
    empresaNombre: opts.empresaNombre,
    empresaDireccion: opts.empresaDireccion || "",
    importeTotal: opts.importeTotal,
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `Factura ${opts.numeroFactura} — ${opts.empresaNombre}`,
    html,
    attachments: [{ filename: `Factura_${opts.numeroFactura}.pdf`, content: opts.pdf }],
  });
}

/** Envía una nómina en PDF adjunto */
export async function enviarNomina(opts: {
  to: string;
  empleadoNombre: string;
  periodo: string;
  empresaNombre: string;
  pdf: Buffer;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("nomina", {
    empleadoNombre: opts.empleadoNombre,
    periodo: opts.periodo,
    empresaNombre: opts.empresaNombre,
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `Tu nómina de ${opts.periodo} — ${opts.empresaNombre}`,
    html,
    attachments: [{ filename: `Nomina_${opts.periodo}.pdf`, content: opts.pdf }],
  });
}

/** Recordatorio de pago de factura pendiente */
export async function enviarRecordatorioPago(opts: {
  to: string;
  clienteNombre: string;
  numeroFactura: string;
  importeTotal: string;
  fechaVencimiento: string;
  diasRestantes: number;
  empresaNombre: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("recordatorio_pago", {
    clienteNombre: opts.clienteNombre,
    numeroFactura: opts.numeroFactura,
    importeTotal: opts.importeTotal,
    fechaVencimiento: opts.fechaVencimiento,
    diasRestantes: opts.diasRestantes.toString(),
    empresaNombre: opts.empresaNombre,
    urgencia: opts.diasRestantes <= 2 ? "🚨 URGENTE" : opts.diasRestantes <= 7 ? "⚠️ Próximo" : "ℹ️ Recordatorio",
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `${opts.diasRestantes <= 2 ? "🚨 URGENTE: " : ""}Recordatorio de pago — Factura ${opts.numeroFactura}`,
    html,
  });
}

/** Confirmación de pago recibido */
export async function enviarPagoRecibido(opts: {
  to: string;
  clienteNombre: string;
  numeroFactura: string;
  importeTotal: string;
  fechaPago: string;
  empresaNombre: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("pago_recibido", {
    clienteNombre: opts.clienteNombre,
    numeroFactura: opts.numeroFactura,
    importeTotal: opts.importeTotal,
    fechaPago: opts.fechaPago,
    empresaNombre: opts.empresaNombre,
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `✅ Pago confirmado — Factura ${opts.numeroFactura}`,
    html,
  });
}

/** Confirmación de cita */
export async function enviarCita(opts: {
  to: string;
  clienteNombre: string;
  fecha: string;
  hora: string;
  servicio: string;
  empresaNombre: string;
  empresaDireccion?: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("cita", {
    clienteNombre: opts.clienteNombre,
    fecha: opts.fecha,
    hora: opts.hora,
    servicio: opts.servicio,
    empresaNombre: opts.empresaNombre,
    empresaDireccion: opts.empresaDireccion || "",
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `Confirmación de cita — ${opts.fecha}`,
    html,
  });
}

/** Email de bienvenida nuevo cliente de una empresa */
export async function enviarBienvenida(opts: {
  to: string;
  clienteNombre: string;
  empresaNombre: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("bienvenida", {
    clienteNombre: opts.clienteNombre,
    empresaNombre: opts.empresaNombre,
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `Bienvenido/a a ${opts.empresaNombre}`,
    html,
  });
}

/** Invitación de empleado */
export async function enviarInvitacion(opts: {
  to: string;
  empresaNombre: string;
  rolLabel: string;
  deepLink: string;
  expiresHours: number;
}): Promise<EmailResult> {
  const html = buildTemplate("invitacion", {
    empresaNombre: opts.empresaNombre,
    rolLabel: opts.rolLabel,
    deepLink: opts.deepLink,
    expiresHours: opts.expiresHours.toString(),
  });

  return enviar({
    from: DEFAULT_FROM,
    to: opts.to,
    subject: `Invitación para unirte a ${opts.empresaNombre} en Fluix CRM`,
    html,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// EMAILS DE FLUIX → sus clientes (desde Fluix como empresa)
// ──────────────────────────────────────────────────────────────────────────────

/** Bienvenida cuando una empresa se da de alta en Fluix CRM */
export async function enviarBienvenidaFluix(opts: {
  to: string;
  nombreEmpresa: string;
  nombreContacto: string;
  plan: string;
}): Promise<EmailResult> {
  const html = buildTemplate("bienvenida_fluix", {
    nombreEmpresa: opts.nombreEmpresa,
    nombreContacto: opts.nombreContacto,
    plan: opts.plan,
  });

  return enviar({
    from: "Fluix CRM <hola@fluixtech.com>",
    to: opts.to,
    subject: `🎉 Bienvenido/a a Fluix CRM — ${opts.nombreEmpresa}`,
    html,
  });
}

/** Confirmación de pago / compra de plan en Fluix */
export async function enviarConfirmacionCompraPlan(opts: {
  to: string;
  nombreContacto: string;
  nombreEmpresa: string;
  plan: string;
  importeTotal: string;
  fechaPago: string;
  numeroFactura: string;
  pdf?: Buffer;
}): Promise<EmailResult> {
  const html = buildTemplate("confirmacion_compra_fluix", {
    nombreContacto: opts.nombreContacto,
    nombreEmpresa: opts.nombreEmpresa,
    plan: opts.plan,
    importeTotal: opts.importeTotal,
    fechaPago: opts.fechaPago,
    numeroFactura: opts.numeroFactura,
  });

  const attachments: AttachmentResend[] = [];
  if (opts.pdf) {
    attachments.push({ filename: `Factura_Fluix_${opts.numeroFactura}.pdf`, content: opts.pdf });
  }

  return enviar({
    from: "Fluix CRM <facturas@fluixtech.com>",
    to: opts.to,
    subject: `✅ Pago confirmado — ${opts.plan} · Fluix CRM`,
    html,
    attachments,
  });
}

/** Renovación de suscripción */
export async function enviarSuscripcionRenovada(opts: {
  to: string;
  nombreContacto: string;
  nombreEmpresa: string;
  plan: string;
  proximoVencimiento: string;
  importeTotal: string;
}): Promise<EmailResult> {
  const html = buildTemplate("renovacion_fluix", {
    nombreContacto: opts.nombreContacto,
    nombreEmpresa: opts.nombreEmpresa,
    plan: opts.plan,
    proximoVencimiento: opts.proximoVencimiento,
    importeTotal: opts.importeTotal,
  });

  return enviar({
    from: "Fluix CRM <facturas@fluixtech.com>",
    to: opts.to,
    subject: `🔄 Suscripción renovada — Fluix CRM`,
    html,
  });
}

/** Reset de contraseña con template personalizado */
export async function enviarResetPassword(opts: {
  to: string;
  resetLink: string;
}): Promise<EmailResult> {
  const html = buildTemplate("reset_password", {
    email: opts.to,
    resetLink: opts.resetLink,
  });

  return enviar({
    from: DEFAULT_FROM,
    to: opts.to,
    subject: "🔑 Restablecer tu contraseña — Fluix CRM",
    html,
  });
}

/** Confirmación de reserva al cliente (la empresa aceptó su reserva) */
export async function enviarConfirmacionReserva(opts: {
  to: string;
  clienteNombre: string;
  empresaNombre: string;
  fechaHora: string;
  personas?: string;
  servicio?: string;
  zona?: string;
  notas?: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("confirmacion_reserva", {
    clienteNombre: opts.clienteNombre,
    empresaNombre: opts.empresaNombre,
    fechaHora: opts.fechaHora,
    personas: opts.personas || "",
    servicio: opts.servicio || "",
    zona: opts.zona || "",
    notas: opts.notas || "",
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `✅ Reserva confirmada — ${opts.empresaNombre}`,
    html,
  });
}

/** Cancelación de reserva al cliente (la empresa no puede atenderle) */
export async function enviarCancelacionReserva(opts: {
  to: string;
  clienteNombre: string;
  empresaNombre: string;
  fechaHora: string;
  personas?: string;
  servicio?: string;
  motivoCancelacion?: string;
  fromEmail?: string;
}): Promise<EmailResult> {
  const html = buildTemplate("cancelacion_reserva", {
    clienteNombre: opts.clienteNombre,
    empresaNombre: opts.empresaNombre,
    fechaHora: opts.fechaHora,
    personas: opts.personas || "",
    servicio: opts.servicio || "",
    motivoCancelacion: opts.motivoCancelacion || "",
  });

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `❌ Reserva cancelada — ${opts.empresaNombre}`,
    html,
  });
}

/** PDF genérico con adjunto (para compatibilidad con enviarEmailConPdf) */
export async function enviarPdfGenerico(opts: {
  from: string;
  to: string;
  subject: string;
  html: string;
  pdf: Buffer;
  nombreArchivo: string;
}): Promise<EmailResult> {
  return enviar({
    from: opts.from,
    to: opts.to,
    subject: opts.subject,
    html: opts.html,
    attachments: [{ filename: opts.nombreArchivo, content: opts.pdf }],
  });
}

