"use strict";
/**
 * authGuard.ts — Helper de autenticación para Cloud Functions v2
 *
 * Centraliza las verificaciones de auth, empresa y rol para
 * todas las Cloud Functions callable de Fluix CRM.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.verificarAuth = verificarAuth;
exports.verificarAuthYEmpresa = verificarAuthYEmpresa;
exports.verificarPropietarioPlataforma = verificarPropietarioPlataforma;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
/**
 * Verifica que la request tiene un usuario autenticado.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" si no hay auth
 */
function verificarAuth(request) {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Debes iniciar sesión para usar esta función.");
    }
    return request.auth.uid;
}
/**
 * Verifica auth + que el usuario pertenece a la empresa indicada.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" | "permission-denied"
 */
async function verificarAuthYEmpresa(request, empresaId) {
    const uid = verificarAuth(request);
    if (!empresaId) {
        throw new https_1.HttpsError("invalid-argument", "empresaId es requerido");
    }
    const userDoc = await db.collection("usuarios").doc(uid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("permission-denied", "Usuario no registrado en el sistema.");
    }
    const userData = userDoc.data();
    if (userData.empresa_id !== empresaId) {
        throw new https_1.HttpsError("permission-denied", "No tienes acceso a esta empresa.");
    }
    return uid;
}
/**
 * Verifica que el usuario es admin de la plataforma Fluix.
 * @returns uid del usuario
 * @throws HttpsError "unauthenticated" | "permission-denied"
 */
async function verificarPropietarioPlataforma(request) {
    const uid = verificarAuth(request);
    const userDoc = await db.collection("usuarios").doc(uid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("permission-denied", "Usuario no registrado en el sistema.");
    }
    const userData = userDoc.data();
    if (userData.es_plataforma_admin !== true) {
        throw new https_1.HttpsError("permission-denied", "Se requieren permisos de administrador de plataforma.");
    }
    return uid;
}
//# sourceMappingURL=authGuard.js.map