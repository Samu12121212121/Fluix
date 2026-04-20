"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTareaAsignada = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const REGION = "europe-west1";
exports.onTareaAsignada = (0, firestore_1.onDocumentWritten)({ document: "empresas/{empresaId}/tareas/{tareaId}", region: REGION }, async (event) => {
    var _a, _b;
    const change = event.data;
    if (!change)
        return; // Deleted or invalid
    const db = admin.firestore(); // moved here
    const before = change.before.data();
    const after = change.after.data();
    const empresaId = event.params.empresaId;
    const tareaId = event.params.tareaId;
    // Check if task exists (not deleted)
    if (!after)
        return;
    const asignadoAntes = before ? before.usuario_asignado_id : null;
    const asignadoDespues = after.usuario_asignado_id;
    // Si no hay asignado ahora, o es el mismo que antes, no hacer nada
    if (!asignadoDespues || asignadoAntes === asignadoDespues) {
        return;
    }
    console.log(`📝 Tarea ${tareaId} asignada a ${asignadoDespues} en empresa ${empresaId}`);
    try {
        // 1. Obtener token del usuario asignado
        // Buscamos en 'empresas/{empresaId}/dispositivos/{usuarioId}' (según NotificacionesService)
        // O en 'usuarios/{usuarioId}'
        // Intentar primero en empresa/dispositivos para asegurar que está activo en esa empresa
        const dispositivoRef = db
            .collection("empresas")
            .doc(empresaId)
            .collection("dispositivos")
            .doc(asignadoDespues);
        const dispositivoSnap = await dispositivoRef.get();
        let token = (_a = dispositivoSnap.data()) === null || _a === void 0 ? void 0 : _a.token;
        // Si no, intentar en colección global usuarios (fallback)
        if (!token) {
            const usuarioRef = db.collection("usuarios").doc(asignadoDespues);
            const usuarioSnap = await usuarioRef.get();
            token = (_b = usuarioSnap.data()) === null || _b === void 0 ? void 0 : _b.token_dispositivo;
        }
        if (!token) {
            console.log(`⚠️ Usuario ${asignadoDespues} no tiene token FCM registrado.`);
            return;
        }
        // 2. Enviar notificación
        const titulo = "Nueva tarea asignada";
        const cuerpo = `Se te ha asignado: ${after.titulo || "Sin título"}`;
        const mensaje = {
            token: token,
            notification: {
                title: titulo,
                body: cuerpo,
            },
            data: {
                tipo: "tarea_asignada",
                empresa_id: empresaId,
                tarea_id: tareaId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "fluixcrm_canal_principal",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                },
            },
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: titulo,
                            body: cuerpo,
                        },
                        sound: "default",
                        badge: 1,
                        'mutable-content': 1,
                    },
                },
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                },
            },
        };
        await admin.messaging().send(mensaje);
        console.log(`✅ Notificación enviada a ${asignadoDespues}`);
    }
    catch (error) {
        console.error("❌ Error enviando notificación de tarea:", error);
    }
});
//# sourceMappingURL=notificacionesTareas.js.map