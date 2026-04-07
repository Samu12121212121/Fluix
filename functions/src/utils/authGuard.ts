/**
 * authGuard.ts — Helper de autenticación para Cloud Functions v2
 *
 * Centraliza las verificaciones de auth, empresa y rol para
 * todas las Cloud Functions callable de Fluix CRM.
 */

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

/**
 * Verifica que la request tiene un usuario autenticado.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" si no hay auth
 */
export function verificarAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para usar esta función."
    );
  }
  return request.auth.uid;
}

/**
 * Verifica auth + que el usuario pertenece a la empresa indicada.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" | "permission-denied"
 */
export async function verificarAuthYEmpresa(
  request: CallableRequest,
  empresaId: string
): Promise<string> {
  const uid = verificarAuth(request);

  if (!empresaId) {
    throw new HttpsError("invalid-argument", "empresaId es requerido");
  }

  const userDoc = await db.collection("usuarios").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Usuario no registrado en el sistema."
    );
  }

  const userData = userDoc.data()!;
  if (userData.empresa_id !== empresaId) {
    throw new HttpsError(
      "permission-denied",
      "No tienes acceso a esta empresa."
    );
  }

  return uid;
}

/**
 * Verifica que el usuario es admin de la plataforma Fluix.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" | "permission-denied"
 */
export async function verificarPropietarioPlataforma(
  request: CallableRequest
): Promise<string> {
  const uid = verificarAuth(request);

  const userDoc = await db.collection("usuarios").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Usuario no registrado en el sistema."
    );
  }

  const userData = userDoc.data()!;
  if (userData.es_plataforma_admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Se requieren permisos de administrador de plataforma."
    );
  }

  return uid;
}

