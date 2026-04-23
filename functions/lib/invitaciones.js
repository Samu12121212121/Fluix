"use strict";
/**
 * invitaciones.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Cloud Functions para el sistema de invitación de empleados por email.
 *
 * Trigger:  onDocumentCreated en invitaciones/{token}
 *           → envía el email con el deep link al empleado invitado.
 *
 * Estructura del documento:
 *   token, email, rol, empresa_id, empresa_nombre, creado_por,
 *   expira, usado, fecha_creacion
 *
 * Deep link generado:  fluixcrm://invite?token={token}
 * ─────────────────────────────────────────────────────────────────────────────
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onInvitacionCreada = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const resend_service_1 = require("./resend_service");
const REGION = "europe-west1";
// ── CLOUD FUNCTION ───────────────────────────────────────────────────────────
exports.onInvitacionCreada = (0, firestore_1.onDocumentCreated)({ document: "invitaciones/{token}", region: REGION }, async (event) => {
    var _a;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const { token, email, rol, empresa_nombre: empresaNombre } = data;
    const rolLabel = rol === "admin" ? "Administrador" : "Empleado";
    const deepLink = `fluixcrm://invite?token=${token}`;
    try {
        const resultado = await (0, resend_service_1.enviarInvitacion)({
            to: email,
            empresaNombre,
            rolLabel,
            deepLink,
            expiresHours: 72,
        });
        if (!resultado.exito)
            throw new Error(resultado.error);
        await admin
            .firestore()
            .collection("invitaciones")
            .doc(token)
            .update({ email_enviado: true, email_enviado_at: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`✅ Invitación enviada a ${email} (token: ${token})`);
    }
    catch (e) {
        console.error(`❌ Error enviando invitación a ${email}:`, e);
        await admin
            .firestore()
            .collection("invitaciones")
            .doc(token)
            .update({ email_error: String(e) });
    }
});
//# sourceMappingURL=invitaciones.js.map