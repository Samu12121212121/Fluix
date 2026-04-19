"use strict";
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
exports.enviarRecordatoriosCitas = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
// ⚠️ NO inicializar admin.firestore() a nivel de módulo.
//    Debe estar dentro del handler para que initializeApp() ya haya corrido.
exports.enviarRecordatoriosCitas = (0, scheduler_1.onSchedule)("every 1 hours", async (event) => {
    const db = admin.firestore(); // ← aquí, dentro del handler
    const now = new Date();
    // Rango de búsqueda: citas entre 23h y 25h desde ahora
    const start = new Date(now.getTime() + 23 * 60 * 60 * 1000);
    const end = new Date(now.getTime() + 25 * 60 * 60 * 1000);
    console.log(`Buscando citas para recordar entre ${start.toISOString()} y ${end.toISOString()}`);
    const snapshot = await db.collectionGroup("citas")
        .where("fecha_hora", ">=", start.toISOString())
        .where("fecha_hora", "<=", end.toISOString())
        .get();
    if (snapshot.empty) {
        console.log("No hay citas próximas para recordar.");
        return;
    }
    const promises = [];
    snapshot.docs.forEach(doc => {
        const cita = doc.data();
        if (cita.recordatorioEnviado === true)
            return;
        const empresaRef = doc.ref.parent.parent;
        if (!empresaRef)
            return;
        const empresaId = empresaRef.id;
        const p = (async () => {
            try {
                const nombreCliente = cita.nombre_cliente || cita.cliente || "Cliente";
                const horaStr = new Date(cita.fecha_hora).toLocaleTimeString("es-ES", {
                    hour: "2-digit", minute: "2-digit"
                });
                // CORRECCIÓN: notificar al EQUIPO del negocio (no al cliente externo,
                // ya que los clientes no tienen la app instalada ni tokens FCM)
                const dispositivosSnap = await db
                    .collection("empresas").doc(empresaId)
                    .collection("dispositivos")
                    .where("activo", "==", true)
                    .get();
                const tokens = [];
                dispositivosSnap.forEach(d => {
                    const token = d.data().token;
                    if (token)
                        tokens.push(token);
                });
                if (tokens.length > 0) {
                    const mensaje = {
                        tokens,
                        notification: {
                            title: "📅 Cita mañana",
                            body: `${nombreCliente} tiene cita mañana a las ${horaStr}`,
                        },
                        data: {
                            tipo: "recordatorio_cita",
                            empresa_id: empresaId,
                            cita_id: doc.id,
                        },
                        android: {
                            priority: "high",
                            notification: { channelId: "fluixcrm_canal_principal" },
                        },
                        apns: { payload: { aps: { sound: "default", badge: 1 } } },
                    };
                    await admin.messaging().sendEachForMulticast(mensaje);
                    console.log(`📨 Recordatorio enviado al equipo de empresa ${empresaId} para cita de ${nombreCliente}`);
                }
                // Guardar en bandeja in-app de la empresa
                await db.collection("notificaciones").doc(empresaId).collection("items").add({
                    titulo: "📅 Cita mañana",
                    cuerpo: `${nombreCliente} tiene cita mañana a las ${horaStr}`,
                    tipo: "reservaNueva",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    leida: false,
                    modulo_destino: "reservas",
                    entidad_id: doc.id,
                    remitente_nombre: nombreCliente,
                    remitente_telefono: cita.telefono_cliente || null,
                    remitente_email: cita.email_cliente || null,
                });
                // Marcar como enviada
                await doc.ref.update({
                    recordatorioEnviado: true,
                    fechaRecordatorio: admin.firestore.FieldValue.serverTimestamp()
                });
            }
            catch (error) {
                console.error(`Error procesando recordatorio para cita ${doc.id}:`, error);
            }
        })();
        promises.push(p);
    });
    await Promise.all(promises);
});
//# sourceMappingURL=recordatoriosCitas.js.map