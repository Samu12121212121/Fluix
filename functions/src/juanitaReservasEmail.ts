/**
 * juanitaReservasEmail.ts
 * ──────────────────────────────────────────────────────────────────────────────
 * Escucha cambios de estado en reservas del negocio de juanitataberna@gmail.com
 * y manda correo de confirmación o cancelación al cliente.
 *
 * Funciona de forma completamente independiente al resto del sistema.
 * ──────────────────────────────────────────────────────────────────────────────
 */

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { enviarConfirmacionReserva, enviarCancelacionReserva } from "./resend_service";

const REGION = "europe-west1";
const JUANITA_EMAIL = "juanitataberna@gmail.com";

// Cache en memoria para evitar re-consultar Firestore en cada invocación
let juanitaEmpresaId: string | null = null;
let juanitaNegocioNombre: string | null = null;

// empresaId conocido de los logs — se usa si el lookup por email falla
const JUANITA_EMPRESA_ID_FALLBACK = "AP6JV9bxONgibrjaKzvrrk4xvWM2";

async function getJuanitaInfo(db: admin.firestore.Firestore): Promise<{ empresaId: string; nombre: string } | null> {
  if (juanitaEmpresaId && juanitaNegocioNombre) {
    return { empresaId: juanitaEmpresaId, nombre: juanitaNegocioNombre };
  }
  // Intentar por email primero
  const snap = await db
    .collection("negocios_publicos")
    .where("emailNotificaciones", "==", JUANITA_EMAIL)
    .limit(1)
    .get();
  if (!snap.empty) {
    const d = snap.docs[0].data();
    juanitaEmpresaId = d.empresaIdVinculada as string;
    juanitaNegocioNombre = (d.nombre as string) || "La Taberna";
    return { empresaId: juanitaEmpresaId!, nombre: juanitaNegocioNombre! };
  }
  // Fallback: buscar el negocio directamente por el empresaId conocido
  const negSnap = await db
    .collection("negocios_publicos")
    .where("empresaIdVinculada", "==", JUANITA_EMPRESA_ID_FALLBACK)
    .limit(1)
    .get();
  if (!negSnap.empty) {
    const d = negSnap.docs[0].data();
    juanitaEmpresaId = JUANITA_EMPRESA_ID_FALLBACK;
    juanitaNegocioNombre = (d.nombre as string) || "La Taberna";
    return { empresaId: juanitaEmpresaId, nombre: juanitaNegocioNombre };
  }
  // Último recurso: usar el empresaId hardcodeado con nombre genérico
  console.log("[juanita] negocio no encontrado en negocios_publicos, usando fallback");
  return { empresaId: JUANITA_EMPRESA_ID_FALLBACK, nombre: "La Taberna" };
}

export const onJuanitaReservaEstadoCambiado = onDocumentUpdated(
  {
    document: "empresas/{empresaId}/reservas/{reservaId}",
    region: REGION,
  },
  async (event) => {
    const antes = event.data?.before?.data();
    const despues = event.data?.after?.data();
    if (!antes || !despues) { console.log("[juanita] sin datos, saliendo"); return; }

    const estadoAntes: string = (antes.estado || "").toLowerCase();
    const estadoDespues: string = (despues.estado || "").toLowerCase();
    console.log(`[juanita] estado: ${estadoAntes} → ${estadoDespues} | empresa: ${event.params.empresaId}`);

    if (estadoAntes === estadoDespues) { console.log("[juanita] estado no cambió, saliendo"); return; }

    const esConfirmada = estadoDespues === "confirmada";
    const esCancelada = estadoDespues === "cancelada" || estadoDespues === "rechazada";
    if (!esConfirmada && !esCancelada) { console.log(`[juanita] estado '${estadoDespues}' no relevante, saliendo`); return; }

    if (despues.email_cliente_notificado === true) { console.log("[juanita] ya notificado, saliendo"); return; }

    const db = admin.firestore();
    const empresaId = event.params.empresaId;

    const juanita = await getJuanitaInfo(db);
    console.log(`[juanita] lookup resultado: ${JSON.stringify(juanita)}`);
    if (!juanita) { console.log("[juanita] no se encontró negocio con ese email"); return; }
    if (juanita.empresaId !== empresaId) { console.log(`[juanita] empresa no coincide: ${juanita.empresaId} vs ${empresaId}`); return; }

    const emailCliente: string =
      despues.email_cliente || despues.usuario_email || despues.cliente_email || "";
    if (!emailCliente) {
      console.log(`[juanita] Reserva ${event.params.reservaId} sin email de cliente, omitiendo.`);
      return;
    }

    const nombreCliente: string =
      despues.nombre_cliente || despues.usuario_nombre || despues.cliente_nombre || "Cliente";

    let fechaHora = "";
    try {
      const fh = despues.fecha_hora?.toDate ? despues.fecha_hora.toDate() : new Date(despues.fecha_hora);
      fechaHora = fh.toLocaleString("es-ES", {
        weekday: "long", day: "numeric", month: "long",
        hour: "2-digit", minute: "2-digit",
      });
    } catch (_) {}

    const servicio: string = despues.servicio_nombre || despues.servicio || "";
    const personas: string =
      despues.numero_personas ? `${despues.numero_personas} personas`
      : despues.personas ? `${despues.personas} personas`
      : despues.comensales ? `${despues.comensales} comensales`
      : "";
    const zona: string = despues.zona || despues.sala || despues.ubicacion || "";
    const notas: string = despues.notas || despues.nota || despues.nota_interna || despues.mensaje || "";

    try {
      if (esConfirmada) {
        await enviarConfirmacionReserva({
          to: emailCliente,
          clienteNombre: nombreCliente,
          empresaNombre: juanita.nombre,
          fechaHora: fechaHora || "Próximamente",
          servicio,
          personas,
          zona,
          notas,
        });
        console.log(`[juanita] Confirmación enviada a ${emailCliente}`);
      } else {
        const motivo: string = despues.motivo_cancelacion || "";
        await enviarCancelacionReserva({
          to: emailCliente,
          clienteNombre: nombreCliente,
          empresaNombre: juanita.nombre,
          fechaHora: fechaHora || "Próximamente",
          servicio,
          personas,
          motivoCancelacion: motivo || "Sin motivo especificado",
        });
        console.log(`[juanita] Cancelación enviada a ${emailCliente}`);
      }

      // Marcar como notificado para que otros triggers no lo reenvíen
      await event.data!.after.ref.update({ email_cliente_notificado: true });
    } catch (err) {
      console.error("[juanita] Error enviando email:", err);
    }
  }
);
