/**
 * automaciones_clientes.ts
 *
 * Mantiene sincronizados los stats del CRM de clientes:
 *   total_gastado   ← facturas + pedidos web + pedidos WhatsApp
 *   numero_reservas ← reservas confirmadas
 *   ultima_visita   ← timestamp del último evento
 *
 * Orígenes de clientes capturados:
 *   A) Reserva online/manual  → reservas/{id} onCreate|onUpdate→CONFIRMADA
 *   B) Pedido web / tienda    → pedidos/{id} onCreate
 *   C) Pedido WhatsApp        → pedidos_whatsapp/{id} onCreate
 *   D) Factura manual         → facturas/{id} onCreate
 *   E) Factura anulada        → facturas/{id} onUpdate→anulada (reversal)
 *   F) Cliente manual CRM     → clientes/{id} onCreate → notif a todos los admins
 *
 * Notificaciones → enviarNotificacionEmpresa alcanza TODOS los dispositivos:
 *   propietario + admins (via empresas/{id}/dispositivos con fallback a usuarios)
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { enviarNotificacionEmpresa } from "./utils/notificaciones";
import { enviarBienvenida } from "./resend_service";

const db     = admin.firestore();
const REGION = "europe-west1";

// ─────────────────────────────────────────────────────────────────────────────
// Normaliza strings para comparación: sin tildes, minúsculas, sin espacios extra
// ─────────────────────────────────────────────────────────────────────────────
function norm(s: string): string {
  return s.trim().toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/\s+/g, " ");
}

function normTel(t: string): string {
  return t.replace(/[\s\-().+]/g, "").slice(-9); // últimos 9 dígitos
}

// ─────────────────────────────────────────────────────────────────────────────
// buscarOCrearCliente
//   Prioridad: correo → teléfono (9 dígitos finales) → nombre → auto-crear
//   Devuelve el ID del cliente encontrado o creado, o null si no hay nombre válido.
// ─────────────────────────────────────────────────────────────────────────────
async function buscarOCrearCliente(opts: {
  empresaId: string;
  nombre:    string;
  correo?:   string | null;
  telefono?: string | null;
  origen?:   string;
}): Promise<string | null> {
  const { empresaId, nombre, correo, telefono, origen = "automatico" } = opts;
  const nombreNorm = norm(nombre);

  // Rechazar nombres genéricos
  if (!nombreNorm || ["cliente", "cliente general", "sin nombre", ""].includes(nombreNorm)) {
    return null;
  }

  const col = db.collection("empresas").doc(empresaId).collection("clientes");

  // 1. Por correo
  if (correo && correo.includes("@")) {
    const snap = await col.where("correo", "==", correo.trim().toLowerCase()).limit(1).get();
    if (!snap.empty) return snap.docs[0].id;
  }

  // 2. Por teléfono (últimos 9 dígitos)
  if (telefono) {
    const telNorm = normTel(telefono);
    if (telNorm.length >= 9) {
      const all = await col.get();
      const match = all.docs.find((d) => {
        const t = (d.data().telefono as string | undefined) ?? "";
        return normTel(t) === telNorm;
      });
      if (match) return match.id;
    }
  }

  // 3. Por nombre normalizado (carga colección — solo si <1000 clientes)
  const all = await col.get();
  const byName = all.docs.find((d) => norm((d.data().nombre as string) ?? "") === nombreNorm);
  if (byName) return byName.id;

  // 4. Auto-crear
  const telNorm = telefono ? normTel(telefono) : "";
  const ref = await col.add({
    nombre:          nombre.trim(),
    correo:          correo?.trim().toLowerCase() ?? "",
    telefono:        telefono?.trim() ?? "",
    telefono_norm:   telNorm,
    fecha_registro:  admin.firestore.FieldValue.serverTimestamp(),
    total_gastado:   0.0,
    numero_reservas: 0,
    activo:          true,
    origen,
    etiquetas:       [],
  });

  functions.logger.info(`[CRM] Auto-creado cliente ${ref.id} — "${nombre}" (origen: ${origen}, empresa: ${empresaId})`);
  return ref.id;
}

// ─────────────────────────────────────────────────────────────────────────────
// notifNuevoCliente — notificación in-app para la bandeja + push a todos los admins
// ─────────────────────────────────────────────────────────────────────────────
async function notifNuevoCliente(opts: {
  empresaId: string;
  clienteId: string;
  nombre:    string;
  origen:    string;
}): Promise<void> {
  const { empresaId, clienteId, nombre, origen } = opts;

  const esAutomatico = origen === "automatico";
  const titulo = esAutomatico
    ? "👤 Nuevo cliente registrado"
    : "👤 Nuevo cliente añadido";
  const cuerpo = esAutomatico
    ? `${nombre} ha sido añadido automáticamente desde ${origen}`
    : `${nombre} ha sido registrado en tu base de clientes`;

  await Promise.all([
    // In-app (bandeja)
    db.collection("notificaciones").doc(empresaId).collection("items").add({
      tipo:             "nuevo_cliente",
      titulo,
      cuerpo,
      timestamp:        admin.firestore.FieldValue.serverTimestamp(),
      leida:            false,
      remitente_nombre: nombre,
      cliente_id:       clienteId,
    }),
    // Push FCM → propietario + todos los admins
    enviarNotificacionEmpresa(empresaId, titulo, cuerpo, {
      tipo:       "nuevo_cliente",
      cliente_id: clienteId,
    }),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// A. NUEVO CLIENTE MANUAL EN CRM → notif a todos los admins
//    Evita duplicado con clientes creados automáticamente por las demás funciones.
// ─────────────────────────────────────────────────────────────────────────────
export const onNuevoClienteCRM = functions.firestore.onDocumentCreated(
  { document: "empresas/{empresaId}/clientes/{clienteId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const origen = (data.origen as string | undefined) ?? "manual";

    // Los automáticos ya generan notif desde su propio flujo
    if (origen === "automatico") return;

    await notifNuevoCliente({
      empresaId: event.params.empresaId,
      clienteId: event.params.clienteId,
      nombre:    ((data.nombre as string) ?? "Nuevo cliente").trim(),
      origen:    "manual",
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// B1. RESERVA CREADA directamente como CONFIRMADA (TPV, manual staff)
// ─────────────────────────────────────────────────────────────────────────────
export const onReservaCreatedCRM = functions.firestore.onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.estado !== "CONFIRMADA") return; // las pendientes se procesan en onUpdate

    await _procesarReservaCRM(event.params.empresaId, event.params.reservaId, data, "reserva");
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// B2. RESERVA ONLINE que pasa de PENDIENTE → CONFIRMADA
// ─────────────────────────────────────────────────────────────────────────────
export const onReservaCRM = functions.firestore.onDocumentUpdated(
  { document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION },
  async (event) => {
    const antes   = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "CONFIRMADA" || despues.estado !== "CONFIRMADA") return;
    if (despues.crm_procesada === true) return; // evitar doble proceso

    await _procesarReservaCRM(event.params.empresaId, event.params.reservaId, despues, "reserva");
  }
);

async function _procesarReservaCRM(
  empresaId: string,
  reservaId: string,
  data: FirebaseFirestore.DocumentData,
  origen: string
): Promise<void> {
  const nombre   = ((data.nombre_cliente || data.cliente || data.usuario_nombre || "") as string).trim();
  const correo   = (data.email_cliente   || data.usuario_email   || null) as string | null;
  const telefono = (data.telefono_cliente || null) as string | null;

  if (!nombre) return;

  const esNuevo = !(await _clienteExiste(empresaId, nombre, correo, telefono));

  const clienteId = await buscarOCrearCliente({ empresaId, nombre, correo, telefono, origen });
  if (!clienteId) return;

  await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
    numero_reservas:   admin.firestore.FieldValue.increment(1),
    ultima_visita:     admin.firestore.FieldValue.serverTimestamp(),
    ultima_reserva_id: reservaId,
  });

  // Marcar para evitar reproceso
  await db.collection("empresas").doc(empresaId).collection("reservas").doc(reservaId)
    .update({ crm_procesada: true });

  if (esNuevo) {
    await notifNuevoCliente({ empresaId, clienteId, nombre, origen: "reserva" });
  }

  functions.logger.info(`[CRM] Reserva ${reservaId} → cliente ${clienteId} (+1 reserva)`);
}

// ─────────────────────────────────────────────────────────────────────────────
// C. PEDIDO WEB / APP / TPV (empresas/{id}/pedidos)
// ─────────────────────────────────────────────────────────────────────────────
export const onPedidoCRM = functions.firestore.onDocumentCreated(
  { document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const empresaId = event.params.empresaId;
    const nombre    = ((data.cliente_nombre || data.cliente || data.nombre_cliente || "") as string).trim();
    const correo    = (data.cliente_correo  || data.email   || null) as string | null;
    const telefono  = (data.cliente_telefono || data.telefono || null) as string | null;
    const total     = ((data.precio_total || data.total || 0) as number);
    const origen    = (data.origen as string | undefined) ?? "pedido_web";

    if (!nombre || norm(nombre) === "cliente") return;

    const esNuevo = !(await _clienteExiste(empresaId, nombre, correo, telefono));

    const clienteId = await buscarOCrearCliente({ empresaId, nombre, correo, telefono, origen });
    if (!clienteId) return;

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
      total_gastado:    admin.firestore.FieldValue.increment(total),
      ultima_visita:    admin.firestore.FieldValue.serverTimestamp(),
      ultimo_pedido_id: event.params.pedidoId,
    });

    if (esNuevo) {
      await notifNuevoCliente({ empresaId, clienteId, nombre, origen });
    }

    functions.logger.info(`[CRM] Pedido ${event.params.pedidoId} → cliente ${clienteId} (+${total.toFixed(2)}€)`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// D. PEDIDO WHATSAPP (empresas/{id}/pedidos_whatsapp)
// ─────────────────────────────────────────────────────────────────────────────
export const onPedidoWhatsAppCRM = functions.firestore.onDocumentCreated(
  { document: "empresas/{empresaId}/pedidos_whatsapp/{pedidoId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const empresaId = event.params.empresaId;
    const nombre    = ((data.nombre_cliente || data.cliente || "") as string).trim();
    const telefono  = (data.telefono || null) as string | null;
    const total     = ((data.total || 0) as number);

    if (!nombre && !telefono) return;
    const nombreFinal = nombre || `WhatsApp ${telefono}`;

    const esNuevo = !(await _clienteExiste(empresaId, nombreFinal, null, telefono));

    const clienteId = await buscarOCrearCliente({
      empresaId, nombre: nombreFinal, correo: null, telefono, origen: "whatsapp",
    });
    if (!clienteId) return;

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
      total_gastado:    admin.firestore.FieldValue.increment(total),
      ultima_visita:    admin.firestore.FieldValue.serverTimestamp(),
      ultimo_pedido_id: event.params.pedidoId,
    });

    if (esNuevo) {
      await notifNuevoCliente({ empresaId, clienteId, nombre: nombreFinal, origen: "whatsapp" });
    }

    functions.logger.info(`[CRM] Pedido WhatsApp ${event.params.pedidoId} → cliente ${clienteId}`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// E. FACTURA CREADA → total_gastado + ultima_visita
// ─────────────────────────────────────────────────────────────────────────────
export const onFacturaCRM = functions.firestore.onDocumentCreated(
  { document: "empresas/{empresaId}/facturas/{facturaId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const empresaId = event.params.empresaId;
    const nombre    = ((data.cliente_nombre as string) ?? "").trim();
    const correo    = (data.cliente_correo  as string | null | undefined) ?? null;
    const telefono  = (data.cliente_telefono as string | null | undefined) ?? null;
    const total     = (data.total as number | undefined) ?? 0;
    const estado    = (data.estado as string | undefined) ?? "";
    const tipo      = (data.tipo   as string | undefined) ?? "";

    if (!nombre || norm(nombre) === "cliente general") return;
    if (estado === "anulada" || tipo === "rectificativa") return;

    // Facturas de pedidos ya procesadas por onPedidoCRM — evitar doble suma
    if (data.pedido_id || data.origen_pedido_id) return;

    const clienteId = await buscarOCrearCliente({ empresaId, nombre, correo, telefono, origen: "factura" });
    if (!clienteId) return;

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
      total_gastado:     admin.firestore.FieldValue.increment(total),
      ultima_visita:     admin.firestore.FieldValue.serverTimestamp(),
      ultima_factura_id: event.params.facturaId,
    });

    functions.logger.info(`[CRM] Factura ${event.params.facturaId} → cliente ${clienteId} (+${total.toFixed(2)}€)`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// F. FACTURA ANULADA → reversal de total_gastado
// ─────────────────────────────────────────────────────────────────────────────
export const onFacturaAnuladaCRM = functions.firestore.onDocumentUpdated(
  { document: "empresas/{empresaId}/facturas/{facturaId}", region: REGION },
  async (event) => {
    const antes   = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes || !despues) return;
    if (antes.estado === "anulada" || despues.estado !== "anulada") return;
    if (despues.pedido_id || despues.origen_pedido_id) return; // ya manejado

    const empresaId = event.params.empresaId;
    const nombre    = ((despues.cliente_nombre as string) ?? "").trim();
    const correo    = (despues.cliente_correo  as string | null | undefined) ?? null;
    const telefono  = (despues.cliente_telefono as string | null | undefined) ?? null;
    const total     = (despues.total as number | undefined) ?? 0;

    if (!nombre || norm(nombre) === "cliente general") return;

    const clienteId = await buscarOCrearCliente({ empresaId, nombre, correo, telefono, origen: "automatico" });
    if (!clienteId) return;

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
      total_gastado: admin.firestore.FieldValue.increment(-total),
    });

    functions.logger.info(`[CRM] Factura anulada ${event.params.facturaId} → cliente ${clienteId} (-${total.toFixed(2)}€)`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// G. RECALCULAR STATS — callable para sincronizar histórico completo
// ─────────────────────────────────────────────────────────────────────────────
export const recalcularStatsCliente = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth?.uid) {
      throw new functions.https.HttpsError("unauthenticated", "No autenticado");
    }
    const { empresaId, clienteId } = request.data as { empresaId?: string; clienteId?: string };
    if (!empresaId || !clienteId) {
      throw new functions.https.HttpsError("invalid-argument", "empresaId y clienteId obligatorios");
    }

    const clienteDoc = await db
      .collection("empresas").doc(empresaId)
      .collection("clientes").doc(clienteId).get();
    if (!clienteDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Cliente no encontrado");
    }

    const cData  = clienteDoc.data()!;
    const correo = ((cData.correo as string) ?? "").trim().toLowerCase();

    let totalGastado = 0;
    let numReservas  = 0;
    let ultimaVisita: admin.firestore.Timestamp | null = null;

    // Facturas por nombre
    const fSnap = await db.collection("empresas").doc(empresaId).collection("facturas")
      .where("cliente_nombre", "==", cData.nombre).get();
    const contadas = new Set<string>();
    for (const doc of fSnap.docs) {
      const d = doc.data();
      if (d.estado === "anulada" || d.tipo === "rectificativa") continue;
      totalGastado += (d.total as number | undefined) ?? 0;
      contadas.add(doc.id);
      const ts = d.creado_en as admin.firestore.Timestamp | undefined;
      if (ts && (!ultimaVisita || ts.toMillis() > ultimaVisita.toMillis())) ultimaVisita = ts;
    }

    // Facturas por correo (si hay correo y no estaban ya)
    if (correo) {
      const fCorr = await db.collection("empresas").doc(empresaId).collection("facturas")
        .where("cliente_correo", "==", correo).get();
      for (const doc of fCorr.docs) {
        if (contadas.has(doc.id)) continue;
        const d = doc.data();
        if (d.estado === "anulada" || d.tipo === "rectificativa") continue;
        totalGastado += (d.total as number | undefined) ?? 0;
      }
    }

    // Pedidos
    const pSnap = await db.collection("empresas").doc(empresaId).collection("pedidos")
      .where("cliente_nombre", "==", cData.nombre).get();
    for (const doc of pSnap.docs) {
      const d = doc.data();
      // Evitar doble suma si el pedido ya generó factura
      if (!d.factura_id) totalGastado += (d.precio_total || d.total || 0) as number;
    }

    // Reservas confirmadas (collectionGroup)
    const rSnap = await db.collectionGroup("reservas")
      .where("nombre_cliente", "==", cData.nombre)
      .where("estado", "==", "CONFIRMADA").get();
    numReservas = rSnap.size;

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).update({
      total_gastado:   totalGastado,
      numero_reservas: numReservas,
      ...(ultimaVisita ? { ultima_visita: ultimaVisita } : {}),
    });

    functions.logger.info(`[CRM] Recalculado ${clienteId}: ${totalGastado.toFixed(2)}€, ${numReservas} reservas`);
    return { totalGastado, numReservas };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// H. ENVIAR EMAIL DE BIENVENIDA A NUEVO CLIENTE — callable
// ─────────────────────────────────────────────────────────────────────────────
export const enviarEmailBienvenidaCliente = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth?.uid) {
      throw new functions.https.HttpsError("unauthenticated", "No autenticado");
    }
    const { empresaId, clienteId } = request.data as { empresaId?: string; clienteId?: string };
    if (!empresaId || !clienteId) {
      throw new functions.https.HttpsError("invalid-argument", "empresaId y clienteId son obligatorios");
    }

    const [clienteDoc, empresaDoc] = await Promise.all([
      db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).get(),
      db.collection("empresas").doc(empresaId).get(),
    ]);

    if (!clienteDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Cliente no encontrado");
    }

    const c = clienteDoc.data()!;
    const correo = ((c.correo ?? c.email ?? "") as string).trim().toLowerCase();
    if (!correo || !correo.includes("@")) {
      return { enviado: false, motivo: "sin_email" };
    }

    const e = empresaDoc.data() ?? {};
    const perfil = (e.perfil ?? {}) as Record<string, string>;
    const empresaNombre = (e.nombre_empresa ?? perfil.nombre_empresa ?? e.nombre ?? "Tu empresa") as string;

    await enviarBienvenida({
      to: correo,
      clienteNombre: (c.nombre ?? "Cliente") as string,
      empresaNombre,
    });

    await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId)
      .update({ email_bienvenida_enviado: true, email_bienvenida_enviado_en: admin.firestore.FieldValue.serverTimestamp() });

    return { enviado: true };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// HELPER INTERNO: ¿ya existe este cliente?
// ─────────────────────────────────────────────────────────────────────────────
async function _clienteExiste(
  empresaId: string,
  nombre: string,
  correo: string | null | undefined,
  telefono: string | null | undefined
): Promise<boolean> {
  const col = db.collection("empresas").doc(empresaId).collection("clientes");
  if (correo && correo.includes("@")) {
    const snap = await col.where("correo", "==", correo.trim().toLowerCase()).limit(1).get();
    if (!snap.empty) return true;
  }
  if (telefono) {
    const telNorm = normTel(telefono);
    if (telNorm.length >= 9) {
      const all = await col.get();
      return all.docs.some((d) => normTel((d.data().telefono as string) ?? "") === telNorm);
    }
  }
  const all = await col.get();
  return all.docs.some((d) => norm((d.data().nombre as string) ?? "") === norm(nombre));
}
