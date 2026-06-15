/**
 * adminClaims.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Gestión del custom claim `plataforma_admin` en Firebase Auth.
 *
 * Bootstrap: el PRIMER admin debe asignarse manualmente desde Firebase Console
 * (ver instrucciones al final del proyecto).
 *
 * A partir del primer admin, este puede dar o revocar el claim a otros UIDs
 * llamando a la función callable `asignarAdminPlataforma`.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (!admin.apps.length) admin.initializeApp();

const db    = admin.firestore();
const auth  = admin.auth();
const REGION = "europe-west1";

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: asignarAdminPlataforma
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Asigna o revoca el custom claim `plataforma_admin` a un usuario.
 *
 * Requisito: el llamante debe tener `plataforma_admin: true` en su token JWT.
 *
 * data: { uid: string, activo: boolean }
 */
export const asignarAdminPlataforma = onCall(
  { region: REGION },
  async (request) => {
    // 1. Verificar que el llamante está autenticado
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    // 2. Verificar que tiene el custom claim plataforma_admin en su token
    const callerClaims = request.auth.token;
    if (callerClaims.plataforma_admin !== true) {
      throw new HttpsError(
        "permission-denied",
        "Solo un admin de plataforma puede asignar este permiso."
      );
    }

    // 3. Validar parámetros
    const { uid, activo } = request.data as { uid: string; activo: boolean };

    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "uid es obligatorio.");
    }
    if (typeof activo !== "boolean") {
      throw new HttpsError("invalid-argument", "activo debe ser boolean.");
    }

    // 4. Verificar que el UID destino existe en Firebase Auth
    let targetUser: admin.auth.UserRecord;
    try {
      targetUser = await auth.getUser(uid);
    } catch {
      throw new HttpsError("not-found", `Usuario ${uid} no encontrado en Firebase Auth.`);
    }

    // 5. Asignar o revocar el custom claim
    const claimsActuales = targetUser.customClaims ?? {};
    const claimNuevo = { ...claimsActuales, plataforma_admin: activo };
    await auth.setCustomUserClaims(uid, claimNuevo);

    // 6. Registrar el cambio en Firestore
    await db.collection("logs").doc("admin_claims").collection(uid).add({
      uid_destino:   uid,
      uid_caller:    request.auth.uid,
      activo,
      timestamp:     admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7. (Opcional) Actualizar el campo legacy en Firestore para trazabilidad
    try {
      await db.collection("usuarios").doc(uid).update({
        es_plataforma_admin: activo,
        admin_claim_actualizado: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch {
      // Si el documento no existe, no es un error crítico
    }

    console.log(
      `[adminClaims] plataforma_admin=${activo} asignado a uid=${uid} por uid=${request.auth.uid}`
    );

    return {
      ok: true,
      uid,
      activo,
      email: targetUser.email ?? null,
    };
  }
);
