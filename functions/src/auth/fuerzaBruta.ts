/**
 * fuerzaBruta.ts — Protección anti-fuerza-bruta vía Cloud Function
 *
 * Reemplaza la escritura directa a Firestore desde el cliente
 * (que se deniega por las reglas: login_intentos → allow: false).
 *
 * Reglas: max 5 intentos → bloqueo 15 minutos.
 * Limpieza automática de registros > 24 horas.
 */

import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const REGION = "europe-west1";
const MAX_INTENTOS = 5;
const BLOQUEO_MINUTOS = 15;
const LIMPIEZA_HORAS = 24;

const db = admin.firestore();

/**
 * verificarLoginIntento
 *
 * POST body: { email: string, exito?: boolean }
 *
 * Si exito === true → resetea el contador (login correcto).
 * Si exito === false o undefined → incrementa contador.
 *
 * Responde con:
 *   { bloqueado: boolean, segundosRestantes?: number, intentosRestantes?: number }
 */
export const verificarLoginIntento = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const { email, exito } = req.body as {
      email?: string;
      exito?: boolean;
    };

    if (!email || typeof email !== "string") {
      res.status(400).json({ error: "email es requerido" });
      return;
    }

    const emailNorm = email.toLowerCase().trim();
    const ref = db.collection("login_intentos").doc(emailNorm);

    try {
      // ── Login exitoso → resetear ──────────────────────────────────────────
      if (exito === true) {
        await ref.delete();
        res.status(200).json({ bloqueado: false, intentosRestantes: MAX_INTENTOS });
        return;
      }

      // ── Login fallido → verificar y actualizar ────────────────────────────
      const now = Date.now();

      const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data() || {};
        const bloqueadoHasta = data.bloqueado_hasta
          ? (data.bloqueado_hasta as admin.firestore.Timestamp).toMillis()
          : null;

        // Si está bloqueado y el bloqueo no ha expirado
        if (bloqueadoHasta && bloqueadoHasta > now) {
          const segundosRestantes = Math.ceil(
            (bloqueadoHasta - now) / 1000
          );
          return {
            bloqueado: true,
            segundosRestantes,
            intentosRestantes: 0,
          };
        }

        // Si el bloqueo expiró, resetear contador
        let contador = bloqueadoHasta && bloqueadoHasta <= now
          ? 1
          : ((data.contador as number) || 0) + 1;

        const updateData: Record<string, unknown> = {
          email: emailNorm,
          contador,
          ultimo_intento: admin.firestore.FieldValue.serverTimestamp(),
          bloqueado_hasta: null,
        };

        if (contador >= MAX_INTENTOS) {
          updateData.bloqueado_hasta = admin.firestore.Timestamp.fromMillis(
            now + BLOQUEO_MINUTOS * 60 * 1000
          );
        }

        tx.set(ref, updateData, { merge: true });

        if (contador >= MAX_INTENTOS) {
          return {
            bloqueado: true,
            segundosRestantes: BLOQUEO_MINUTOS * 60,
            intentosRestantes: 0,
          };
        }

        return {
          bloqueado: false,
          intentosRestantes: MAX_INTENTOS - contador,
        };
      });

      // ── Limpieza de registros antiguos (async, no bloquea la respuesta) ───
      _limpiarRegistrosAntiguos().catch((err) =>
        console.warn("Error limpieza login_intentos:", err)
      );

      res.status(200).json(result);
    } catch (err) {
      console.error("Error en verificarLoginIntento:", err);
      // En caso de error, NO bloquear al usuario (mejor UX)
      res.status(200).json({ bloqueado: false, intentosRestantes: MAX_INTENTOS });
    }
  }
);

/**
 * Limpia documentos con último intento > 24 horas.
 * Se ejecuta "oportunísticamente" en cada llamada (no crítico).
 */
async function _limpiarRegistrosAntiguos(): Promise<void> {
  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - LIMPIEZA_HORAS * 60 * 60 * 1000
  );

  const snap = await db
    .collection("login_intentos")
    .where("ultimo_intento", "<", cutoff)
    .limit(20)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log(`🧹 Limpiados ${snap.size} registros de login_intentos antiguos`);
}

