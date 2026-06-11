/**
 * cerrarCaja.ts — Cloud Function callable (v2)
 *
 * Cierre de caja atómico con:
 *   - Número Z correlativo sin huecos (contador en /configuracion/caja)
 *   - serverTimestamp del servidor (no del cliente)
 *   - Desglose IVA calculado desde líneas de pedido (4 / 10 / 21 %)
 *   - Nombre real del empleado (no solo UID)
 *   - Transacción Firestore para evitar doble cierre simultáneo
 *
 * Normativa: Z-Report fiscal España (regla de cierre diario).
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { verificarAuthYEmpresa } from "./utils/authGuard";

const db = admin.firestore();
const REGION = "europe-west1";

interface DesgloseIvaEntry {
  base: number;
  cuota: number;
}

export const cerrarCaja = onCall(
  { region: REGION },
  async (request) => {
    const {
      empresaId,
      efectivoReal,
      observaciones,
      dispositivoId,
    } = request.data as {
      empresaId: string;
      efectivoReal?: number;
      observaciones?: string;
      dispositivoId?: string;
    };

    if (!empresaId) throw new HttpsError("invalid-argument", "empresaId requerido");

    // ── Auth: el usuario debe pertenecer a la empresa ─────────────────────────
    const uid = await verificarAuthYEmpresa(request, empresaId);

    // ── Calcular rango del día (Madrid / hora servidor) ───────────────────────
    const ahora = new Date();
    const inicio = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 0, 0, 0);
    const finDelDia = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + 1, 0, 0, 0);
    const docId = [
      ahora.getFullYear(),
      String(ahora.getMonth() + 1).padStart(2, "0"),
      String(ahora.getDate()).padStart(2, "0"),
    ].join("-");

    return await db.runTransaction(async (tx) => {
      // ── 1. Verificar que no existe cierre hoy ───────────────────────────────
      const cierreRef = db.doc(`empresas/${empresaId}/cierres_caja/${docId}`);
      const cierreSnap = await tx.get(cierreRef);
      if (cierreSnap.exists) {
        throw new HttpsError("already-exists", `Ya existe cierre de caja para ${docId}`);
      }

      // ── 2. Número Z correlativo ─────────────────────────────────────────────
      const contadorRef = db.doc(`empresas/${empresaId}/configuracion/caja`);
      const contadorSnap = await tx.get(contadorRef);
      const ultimoZ = (contadorSnap.data()?.["ultimo_numero_z"] as number) ?? 0;
      const numeroZ = ultimoZ + 1;

      // ── 3. Fondo inicial de la apertura del día ─────────────────────────────
      const aperturasSnap = await db
        .collection(`empresas/${empresaId}/aperturas_caja`)
        .where("fecha", ">=", admin.firestore.Timestamp.fromDate(inicio))
        .where("fecha", "<", admin.firestore.Timestamp.fromDate(finDelDia))
        .orderBy("fecha", "desc")
        .limit(1)
        .get();
      const fondoInicial =
        (aperturasSnap.docs[0]?.data()?.["fondo_inicial"] as number) ?? 0;

      // ── 4. Pedidos pagados del día ──────────────────────────────────────────
      const pedidosSnap = await db
        .collection(`empresas/${empresaId}/pedidos`)
        .where("fecha_creacion", ">=", admin.firestore.Timestamp.fromDate(inicio))
        .where("fecha_creacion", "<", admin.firestore.Timestamp.fromDate(finDelDia))
        .where("estado_pago", "==", "pagado")
        .get();

      // ── 5. Totales y desglose IVA ───────────────────────────────────────────
      let totalEfectivo = 0;
      let totalTarjeta = 0;
      let totalTransferencia = 0;
      let totalVentas = 0;
      let numDescuentos = 0;
      const desgloseIva: Record<string, DesgloseIvaEntry> = {};

      const IVA_VALIDOS = new Set([0, 4, 10, 21]);

      for (const pedidoDoc of pedidosSnap.docs) {
        const p = pedidoDoc.data();
        const total = (p["total"] as number) ?? 0;
        const metodo = (p["metodo_pago"] as string) ?? "efectivo";

        totalVentas += total;

        if (metodo === "efectivo") {
          totalEfectivo += (p["importe_efectivo"] as number) ?? total;
        } else if (["tarjeta", "bizum", "paypal"].includes(metodo)) {
          totalTarjeta += (p["importe_tarjeta"] as number) ?? total;
        } else if (metodo === "mixto") {
          totalEfectivo += (p["importe_efectivo"] as number) ?? 0;
          totalTarjeta += (p["importe_tarjeta"] as number) ?? 0;
        } else {
          totalTransferencia += total;
        }

        // Desglose IVA desde líneas del pedido
        for (const linea of (p["lineas"] as any[]) ?? []) {
          const ivaPct: number = linea["porcentaje_iva"] ?? linea["iva_porcentaje"] ?? 21;
          // Validar IVA contra tipos legales España
          const ivaSanitizado = IVA_VALIDOS.has(ivaPct) ? ivaPct : 21;
          const key = String(ivaSanitizado);
          const cantidad: number = linea["cantidad"] ?? 1;
          const precioUnit: number =
            linea["precio_unitario"] ?? linea["precio"] ?? 0;
          const descuento: number = linea["descuento"] ?? 0;
          const base = precioUnit * cantidad * (1 - descuento / 100);
          const cuota = base * ivaSanitizado / 100;

          if (!desgloseIva[key]) desgloseIva[key] = { base: 0, cuota: 0 };
          desgloseIva[key].base += base;
          desgloseIva[key].cuota += cuota;
          if (descuento > 0) numDescuentos++;
        }
      }

      // ── 6. Nombre real del empleado ─────────────────────────────────────────
      const userSnap = await db.collection("usuarios").doc(uid).get();
      const ud = userSnap.data() ?? {};
      const nombreEmpleado =
        (ud["nombre"] as string) ||
        (ud["nombre_completo"] as string) ||
        (ud["email"] as string) ||
        uid;

      // ── 7. Control de efectivo ──────────────────────────────────────────────
      const efectivoTeorico = fondoInicial + totalEfectivo;
      const efectivoRealFinal =
        typeof efectivoReal === "number" ? efectivoReal : efectivoTeorico;
      const diferencia = efectivoRealFinal - efectivoTeorico;

      // ── 8. Documento de cierre ──────────────────────────────────────────────
      const cierreData = {
        numero_z: numeroZ,
        fecha: admin.firestore.Timestamp.fromDate(inicio),
        timestamp_cierre: admin.firestore.FieldValue.serverTimestamp(),
        cerrado_por_uid: uid,
        cerrado_por_nombre: nombreEmpleado,
        dispositivo_id: (dispositivoId as string) ?? "desconocido",
        fondo_inicial: fondoInicial,
        total_efectivo: totalEfectivo,
        total_tarjeta: totalTarjeta,
        total_transferencia: totalTransferencia,
        total_ventas: totalVentas,
        num_tickets: pedidosSnap.docs.length,
        num_descuentos: numDescuentos,
        ticket_medio:
          pedidosSnap.docs.length > 0
            ? totalVentas / pedidosSnap.docs.length
            : 0,
        efectivo_teorico: efectivoTeorico,
        efectivo_real: efectivoRealFinal,
        diferencia: diferencia,
        desglose_iva: desgloseIva,
        observaciones: (observaciones as string) ?? null,
        generado_por: "cloud_function_v1",
      };

      // ── 9. Escritura atómica ────────────────────────────────────────────────
      tx.set(cierreRef, cierreData);
      tx.set(contadorRef, { ultimo_numero_z: numeroZ }, { merge: true });

      console.log(
        `✅ Cierre Z-${numeroZ} (${docId}) generado para empresa ${empresaId} — ${pedidosSnap.docs.length} tickets · ${totalVentas.toFixed(2)}€`
      );

      return {
        exito: true,
        docId,
        numeroZ,
        totalVentas,
        numTickets: pedidosSnap.docs.length,
        diferencia,
      };
    });
  }
);
