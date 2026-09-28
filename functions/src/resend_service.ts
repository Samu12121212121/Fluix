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

/** Bienvenida a empleado nuevo — incluye credenciales de acceso */
export async function enviarBienvenidaEmpleado(opts: {
  to: string;
  nombre: string;
  empresaNombre: string;
  tempPassword: string;
}): Promise<EmailResult> {
  const html = `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
  <div style="max-width:580px;margin:40px auto;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">
    <div style="background:#1976D2;padding:32px 36px">
      <h1 style="color:#fff;font-size:22px;margin:0;font-weight:700">¡Bienvenido/a a ${opts.empresaNombre}!</h1>
      <p style="color:rgba(255,255,255,.8);margin:8px 0 0;font-size:14px">Tu cuenta en Fluix CRM está lista</p>
    </div>
    <div style="background:#fff;padding:32px 36px">
      <p style="color:#374151;font-size:15px;margin-top:0">Hola <strong>${opts.nombre}</strong>,</p>
      <p style="color:#6b7280;font-size:14px;line-height:1.6">El administrador de <strong>${opts.empresaNombre}</strong> ha creado tu cuenta. Usa estas credenciales para iniciar sesión:</p>
      <div style="background:#f8fafc;border:2px solid #1976D2;border-radius:10px;padding:20px 24px;margin:20px 0">
        <p style="margin:0 0 10px;font-size:13px;color:#6b7280;text-transform:uppercase;letter-spacing:.05em">Email</p>
        <p style="margin:0 0 18px;font-size:16px;color:#111827;font-weight:600">${opts.to}</p>
        <p style="margin:0 0 10px;font-size:13px;color:#6b7280;text-transform:uppercase;letter-spacing:.05em">Contraseña temporal</p>
        <p style="margin:0;font-size:24px;color:#1976D2;font-weight:700;letter-spacing:3px;font-family:monospace">${opts.tempPassword}</p>
      </div>
      <div style="background:#fff7ed;border-left:4px solid #f59e0b;padding:12px 16px;border-radius:0 8px 8px 0;margin-bottom:24px">
        <p style="margin:0;color:#92400e;font-size:13px"><strong>⚠️ Importante:</strong> Esta contraseña es temporal. Cámbiala en cuanto inicies sesión desde Perfil → Cambiar contraseña.</p>
      </div>
      <p style="color:#9ca3af;font-size:12px;margin:0">Si tienes algún problema para acceder, contacta con el administrador de tu empresa.</p>
    </div>
  </div>
</body>
</html>`;

  return enviar({
    from: DEFAULT_FROM,
    to: opts.to,
    subject: `🎉 Tu acceso a ${opts.empresaNombre} — Fluix CRM`,
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

/** PDF genérico con adjunto opcional (para compatibilidad con enviarEmailConPdf) */
export async function enviarPdfGenerico(opts: {
  from: string;
  to: string;
  subject: string;
  html: string;
  pdf?: Buffer;
  nombreArchivo?: string;
}): Promise<EmailResult> {
  return enviar({
    from: opts.from,
    to: opts.to,
    subject: opts.subject,
    html: opts.html,
    ...(opts.pdf && opts.nombreArchivo
      ? { attachments: [{ filename: opts.nombreArchivo, content: opts.pdf }] }
      : {}),
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// CONTACTO DE INTERÉS — Formulario público en login
// ───────────────────────────────────────────────────────────────────���──────────

/** Email de confirmación al usuario que llena el formulario de contacto */
export async function enviarConfirmacionContactoInteres(opts: {
  to: string;
  nombre: string;
  correo: string;
  telefono?: string;
  nombreEmpresa: string;
  actividad: string;
  numTrabajadores?: string;
}): Promise<EmailResult> {
  const year = new Date().getFullYear().toString();
  const html = buildTemplate("contacto_interes_confirmacion", {
    nombre: opts.nombre,
    correo: opts.correo,
    telefono: opts.telefono || "",
    nombreEmpresa: opts.nombreEmpresa,
    actividad: opts.actividad,
    numTrabajadores: opts.numTrabajadores || "",
    year,
  });

  return enviar({
    from: "Fluix CRM <hola@fluixtech.com>",
    to: opts.to,
    subject: "¡Gracias por tu interés en Fluix CRM! 🚀",
    html,
  });
}

/** Email de notificación al propietario con los datos del lead */
export async function enviarNotificacionContactoInteres(opts: {
  nombre: string;
  correo: string;
  telefono?: string;
  nombreEmpresa: string;
  actividad: string;
  numTrabajadores?: string;
  leadId: string;
  fechaSolicitud: string;
}): Promise<EmailResult> {
  const html = buildTemplate("contacto_interes_notificacion", {
    nombre: opts.nombre,
    correo: opts.correo,
    telefono: opts.telefono || "",
    nombreEmpresa: opts.nombreEmpresa,
    actividad: opts.actividad,
    numTrabajadores: opts.numTrabajadores || "",
    leadId: opts.leadId,
    fechaSolicitud: opts.fechaSolicitud,
  });

  return enviar({
    from: "Fluix CRM Leads <leads@fluixtech.com>",
    to: "sacoor80@gmail.com",
    subject: `🎯 Nuevo Lead: ${opts.nombreEmpresa} — ${opts.nombre}`,
    html,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// CONTACTO SOPORTE IN-APP — Formulario de la pantalla Soporte de Fluix
// ──────────────────────────────────────────────────────────────────────────────

/** Email al administrador de Fluix cuando una empresa envía un mensaje de soporte */
export async function enviarContactoSoporte(opts: {
  empresaNombre: string;
  empresaId: string;
  nombreContacto: string;
  emailContacto: string;
  asunto: string;
  mensaje: string;
}): Promise<EmailResult> {
  const html = `
    <div style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
      <div style="background:#6D5EF8;padding:20px 24px;border-radius:10px 10px 0 0">
        <h2 style="color:#fff;margin:0;font-size:18px">📨 Nuevo mensaje de soporte</h2>
        <p style="color:rgba(255,255,255,0.8);margin:4px 0 0;font-size:13px">Formulario in-app — Fluix CRM</p>
      </div>
      <div style="background:#F8FAFC;padding:20px 24px;border:1px solid #E2E8F0;border-top:none">
        <table style="width:100%;border-collapse:collapse;font-size:14px">
          <tr><td style="padding:8px 0;color:#6B7280;width:140px">Empresa</td><td style="padding:8px 0;font-weight:600;color:#0F172A">${opts.empresaNombre}</td></tr>
          <tr><td style="padding:8px 0;color:#6B7280">ID Empresa</td><td style="padding:8px 0;color:#64748B;font-size:12px">${opts.empresaId}</td></tr>
          <tr><td style="padding:8px 0;color:#6B7280">Contacto</td><td style="padding:8px 0;font-weight:600;color:#0F172A">${opts.nombreContacto}</td></tr>
          <tr><td style="padding:8px 0;color:#6B7280">Email</td><td style="padding:8px 0"><a href="mailto:${opts.emailContacto}" style="color:#6D5EF8">${opts.emailContacto}</a></td></tr>
          <tr><td style="padding:8px 0;color:#6B7280">Asunto</td><td style="padding:8px 0;font-weight:700;color:#0F172A">${opts.asunto}</td></tr>
        </table>
        <div style="margin-top:16px;padding:16px;background:#fff;border-radius:8px;border:1px solid #E2E8F0">
          <p style="margin:0;color:#374151;font-size:14px;line-height:1.6">${opts.mensaje.replace(/\n/g, "<br>")}</p>
        </div>
      </div>
      <div style="background:#1E293B;padding:14px 24px;border-radius:0 0 10px 10px">
        <p style="color:#94A3B8;margin:0;font-size:12px">Fluix CRM — Panel de administración · ${new Date().toLocaleDateString("es-ES")}</p>
      </div>
    </div>
  `;
  return enviar({
    from: "Fluix Soporte <noreply@fluixtech.com>",
    to: "sacoor80@gmail.com",
    subject: `📨 Soporte: ${opts.asunto} — ${opts.empresaNombre}`,
    html,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// CONTACTO WEB — Formulario de contacto en sitio web de cliente
// ──────────────────────────────────────────────────────────────────────────────

/** Notificación al empresario de nuevo mensaje de contacto web */
export async function enviarNotificacionContactoWeb(opts: {
  emailEmpresario: string;
  empresaNombre: string;
  nombreRemitente: string;
  emailRemitente: string;
  telefonoRemitente: string;
  asunto: string;
  mensajeTexto: string;
}): Promise<EmailResult> {
  const html = buildTemplate("contacto_notificacion", {
    empresaNombre: opts.empresaNombre,
    nombreRemitente: opts.nombreRemitente,
    emailRemitente: opts.emailRemitente,
    telefonoRemitente: opts.telefonoRemitente,
    asunto: opts.asunto,
    mensajeTexto: opts.mensajeTexto,
  });

  return enviar({
    from: "Fluix CRM <noreply@fluixtech.com>",
    to: opts.emailEmpresario,
    subject: `📬 Nuevo mensaje de contacto: ${opts.nombreRemitente}`,
    html,
  });
}

/** Respuesta del empresario al visitante que envió mensaje de contacto */
export async function enviarRespuestaContactoWeb(opts: {
  emailRemitente: string;
  nombreRemitente: string;
  empresaNombre: string;
  asunto: string;
  mensajeOriginal: string;
  respuestaTexto: string;
}): Promise<EmailResult> {
  const html = buildTemplate("contacto_respuesta", {
    nombreRemitente: opts.nombreRemitente,
    empresaNombre: opts.empresaNombre,
    asunto: opts.asunto,
    mensajeOriginal: opts.mensajeOriginal,
    respuestaTexto: opts.respuestaTexto,
  });

  return enviar({
    from: `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.emailRemitente,
    subject: `Re: ${opts.asunto}`,
    html,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// PEDIDO ENVIADO — notificación de envío al cliente
// ──────────────────────────────────────────────────────────────────────────────

/** Entrega de ebook — enlace de descarga al comprador */
export async function enviarDescargaEbook(opts: {
  to: string;
  clienteNombre: string;
  libroTitulo: string;
  libroAutor: string;
  downloadUrl: string;
  fechaExpiracion: string;
  maxDescargas?: number;
}): Promise<EmailResult> {
  const max = opts.maxDescargas ?? 5;
  const html = `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tu ebook — Editorial Nazarí</title></head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:32px 16px;">
    <tr><td align="center">
      <table width="580" cellpadding="0" cellspacing="0"
             style="background:#fff;border-radius:12px;overflow:hidden;max-width:580px;box-shadow:0 2px 16px rgba(0,0,0,.08);">
        <tr>
          <td style="background:#6b1e2a;padding:28px 40px;text-align:center;">
            <div style="font-size:36px;margin-bottom:8px;">📚</div>
            <h1 style="color:#fff;font-size:20px;margin:0;font-weight:700;">¡Tu ebook está listo!</h1>
            <p style="color:rgba(255,255,255,.8);margin:6px 0 0;font-size:13px;">Editorial Nazarí</p>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 40px 0;">
            <p style="margin:0;font-size:15px;color:#1a1a1a;">Hola <strong>${opts.clienteNombre}</strong>,</p>
            <p style="margin:12px 0 0;font-size:14px;color:#374151;line-height:1.6;">
              Gracias por tu compra. Ya puedes descargar tu ebook:
            </p>
            <div style="margin:20px 0;padding:16px 20px;background:#faf5f0;border:1px solid #e8d8c8;border-radius:8px;">
              <p style="margin:0 0 4px;font-size:16px;font-weight:700;color:#1a1a1a;">${opts.libroTitulo}</p>
              ${opts.libroAutor ? `<p style="margin:0;font-size:13px;color:#6b7280;font-style:italic;">${opts.libroAutor}</p>` : ""}
            </div>
          </td>
        </tr>
        <tr>
          <td style="padding:16px 40px 0;text-align:center;">
            <a href="${opts.downloadUrl}"
               style="display:inline-block;background:#6b1e2a;color:#fff;text-decoration:none;
                      padding:14px 32px;font-size:14px;font-weight:700;letter-spacing:.5px;
                      border-radius:6px;">
              ⬇️ Descargar ebook
            </a>
          </td>
        </tr>
        <tr>
          <td style="padding:20px 40px 0;">
            <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:14px 16px;font-size:12px;color:#6b7280;line-height:1.6;">
              <strong>ℹ️ Información importante:</strong><br>
              • Este enlace expira el <strong>${opts.fechaExpiracion}</strong><br>
              • Puedes descargar hasta <strong>${max} veces</strong><br>
              • Si tienes problemas, escríbenos a <a href="mailto:info@editorialnazari.com" style="color:#6b1e2a;">info@editorialnazari.com</a>
            </div>
          </td>
        </tr>
        <tr>
          <td style="padding:24px 40px;text-align:center;">
            <p style="margin:0;font-size:11px;color:#9ca3af;">
              © ${new Date().getFullYear()} Editorial Nazarí · Granada, España
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  return enviar({
    from: "Editorial Nazarí <noreply@fluixtech.com>",
    to: opts.to,
    subject: `📚 Tu ebook: "${opts.libroTitulo}" — Editorial Nazarí`,
    html,
  });
}

/** Notifica al cliente que su pedido ha sido enviado */
export async function enviarNotificacionPedidoEnviado(opts: {
  to: string;
  clienteNombre: string;
  empresaNombre: string;
  fromEmail?: string;
  numeroTicket: number;
  lineas: Array<{ nombre: string; cantidad: number; precio: number }>;
  total: number;
  direccionEnvio?: string | null;
  notasEnvio?: string;
}): Promise<EmailResult> {
  const anio = new Date().getFullYear().toString();
  const lineasHtml = opts.lineas.map((l) =>
    `<tr>
      <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0;">${l.nombre}</td>
      <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0;text-align:center;">${l.cantidad}</td>
      <td style="padding:8px 12px;border-bottom:1px solid #f0f0f0;text-align:right;font-weight:600;">${(l.precio * l.cantidad).toFixed(2)} €</td>
    </tr>`
  ).join("");

  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Tu pedido está en camino — ${opts.empresaNombre}</title>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:32px 16px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border-radius:12px;overflow:hidden;max-width:600px;box-shadow:0 2px 16px rgba(0,0,0,.08);">

        <!-- CABECERA -->
        <tr>
          <td style="background:#0ea5e9;padding:32px 40px;text-align:center;">
            <div style="font-size:42px;margin-bottom:12px;">📦</div>
            <h1 style="color:#ffffff;font-size:22px;margin:0;font-weight:700;letter-spacing:.3px;">
              ¡Tu pedido está en camino!
            </h1>
            <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">
              Pedido #${String(opts.numeroTicket).padStart(4,"0")} — ${opts.empresaNombre}
            </p>
          </td>
        </tr>

        <!-- SALUDO -->
        <tr>
          <td style="padding:32px 40px 0;">
            <p style="margin:0;font-size:16px;color:#1a1a1a;">
              Hola <strong>${opts.clienteNombre}</strong>,
            </p>
            <p style="margin:12px 0 0;font-size:15px;color:#374151;line-height:1.6;">
              Hemos enviado tu pedido. En breve recibirás tu compra en la dirección indicada.
            </p>
          </td>
        </tr>

        <!-- PRODUCTOS -->
        <tr>
          <td style="padding:24px 40px 0;">
            <h2 style="margin:0 0 12px;font-size:14px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;color:#6b7280;">
              Detalle del pedido
            </h2>
            <table width="100%" cellpadding="0" cellspacing="0"
                   style="border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;">
              <thead>
                <tr style="background:#f9fafb;">
                  <th style="padding:8px 12px;text-align:left;font-size:12px;color:#6b7280;font-weight:600;">Producto</th>
                  <th style="padding:8px 12px;text-align:center;font-size:12px;color:#6b7280;font-weight:600;">Cant.</th>
                  <th style="padding:8px 12px;text-align:right;font-size:12px;color:#6b7280;font-weight:600;">Importe</th>
                </tr>
              </thead>
              <tbody>
                ${lineasHtml}
              </tbody>
              <tfoot>
                <tr style="background:#f9fafb;">
                  <td colspan="2" style="padding:10px 12px;font-weight:700;font-size:14px;">Total</td>
                  <td style="padding:10px 12px;text-align:right;font-weight:700;font-size:16px;color:#0ea5e9;">
                    ${opts.total.toFixed(2)} €
                  </td>
                </tr>
              </tfoot>
            </table>
          </td>
        </tr>

        ${opts.direccionEnvio ? `
        <!-- DIRECCIÓN -->
        <tr>
          <td style="padding:20px 40px 0;">
            <div style="background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:14px 16px;">
              <p style="margin:0;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;color:#0284c7;">
                📍 Dirección de envío
              </p>
              <p style="margin:6px 0 0;font-size:14px;color:#1e3a5f;line-height:1.5;">
                ${opts.direccionEnvio}
              </p>
            </div>
          </td>
        </tr>` : ""}

        ${opts.notasEnvio ? `
        <!-- NOTAS -->
        <tr>
          <td style="padding:16px 40px 0;">
            <p style="margin:0;font-size:13px;color:#6b7280;line-height:1.6;font-style:italic;">
              ${opts.notasEnvio}
            </p>
          </td>
        </tr>` : ""}

        <!-- FOOTER -->
        <tr>
          <td style="padding:32px 40px;border-top:1px solid #f0f0f0;margin-top:24px;text-align:center;">
            <p style="margin:0;font-size:12px;color:#9ca3af;">
              © ${anio} ${opts.empresaNombre}. Todos los derechos reservados.
            </p>
            <p style="margin:6px 0 0;font-size:11px;color:#d1d5db;">
              Si tienes alguna duda, responde a este correo o contacta con nosotros.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;

  return enviar({
    from: opts.fromEmail
      ? `${opts.empresaNombre} <${opts.fromEmail}>`
      : `${opts.empresaNombre} <noreply@fluixtech.com>`,
    to: opts.to,
    subject: `📦 Tu pedido #${String(opts.numeroTicket).padStart(4,"0")} está en camino — ${opts.empresaNombre}`,
    html,
  });
}

