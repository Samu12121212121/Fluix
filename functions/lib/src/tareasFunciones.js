"use strict";
/**
 * CLOUD FUNCTIONS — Tareas Recurrentes, Recordatorios y Sugerencias
 *
 * Exports:
 *   scheduledGenerarTareasRecurrentes  — diario a las 6:00 (Europe/Madrid)
 *   scheduledRecordatoriosTareas       — cada hora (Europe/Madrid)
 *   scheduledTareasVencenHoy           — diario a las 9:00 (Europe/Madrid)
 *   onNuevaSugerencia                  — trigger Firestore al crear sugerencia
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
exports.onNuevaSugerencia = exports.scheduledTareasVencenHoy = exports.scheduledRecordatoriosTareas = exports.scheduledGenerarTareasRecurrentes = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("firebase-functions/v2/firestore");
const REGION = "europe-west1";
const TZ = "Europe/Madrid";
const db = admin.firestore;
// ─────────────────────────────────────────────────────────────────────────────
// UTILIDADES
// ─────────────────────────────────────────────────────────────────────────────
async function obtenerTokensEmpresa(empresaId) {
    const snap = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("dispositivos")
        .where("activo", "==", true)
        .get();
    return snap.docs
        .map((d) => d.data().token)
        .filter((t) => !!t);
}
async function enviarPush(tokens, titulo, cuerpo, data = {}) {
    if (tokens.length === 0)
        return;
    await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: titulo, body: cuerpo },
        data,
        android: { priority: "high", notification: { channelId: "fluixcrm_canal_principal" } },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
}
/** Calcula la próxima fecha de recurrencia según la configuración. */
function calcularProximaFecha(config, desde) {
    var _a, _b, _c;
    const frecuencia = config.frecuencia;
    const pausada = config.pausada;
    const fechaFinTs = config.fecha_fin;
    if (pausada)
        return null;
    if (fechaFinTs && fechaFinTs.toDate() < desde)
        return null;
    const siguiente = new Date(desde);
    switch (frecuencia) {
        case "diaria":
            siguiente.setDate(siguiente.getDate() + 1);
            siguiente.setHours(8, 0, 0, 0);
            break;
        case "semanal": {
            const diasSemana = (_a = config.dias_semana) !== null && _a !== void 0 ? _a : [1];
            siguiente.setDate(siguiente.getDate() + 1);
            for (let i = 0; i < 14; i++) {
                // JS getDay(): 0=Dom, 1=Lun … 6=Sáb → convertir a ISO: Mon=1
                const iso = siguiente.getDay() === 0 ? 7 : siguiente.getDay();
                if (diasSemana.includes(iso)) {
                    siguiente.setHours(8, 0, 0, 0);
                    break;
                }
                siguiente.setDate(siguiente.getDate() + 1);
            }
            break;
        }
        case "quincenal": {
            const diasSemana = (_b = config.dias_semana) !== null && _b !== void 0 ? _b : [1];
            siguiente.setDate(siguiente.getDate() + 8);
            for (let i = 0; i < 14; i++) {
                const iso = siguiente.getDay() === 0 ? 7 : siguiente.getDay();
                if (diasSemana.includes(iso)) {
                    siguiente.setHours(8, 0, 0, 0);
                    break;
                }
                siguiente.setDate(siguiente.getDate() + 1);
            }
            break;
        }
        case "mensual": {
            const diaMes = (_c = config.dia_mes) !== null && _c !== void 0 ? _c : 1;
            siguiente.setMonth(siguiente.getMonth() + 1);
            if (diaMes === 0) {
                // último día del mes
                siguiente.setDate(0);
            }
            else {
                const maxDia = new Date(siguiente.getFullYear(), siguiente.getMonth() + 1, 0).getDate();
                siguiente.setDate(Math.min(diaMes, maxDia));
            }
            siguiente.setHours(8, 0, 0, 0);
            break;
        }
        case "anual":
            siguiente.setFullYear(siguiente.getFullYear() + 1);
            siguiente.setHours(8, 0, 0, 0);
            break;
        default:
            return null;
    }
    if (fechaFinTs && siguiente > fechaFinTs.toDate())
        return null;
    return siguiente;
}
// ─────────────────────────────────────────────────────────────────────────────
// 1. GENERAR TAREAS RECURRENTES — diario a las 6:00
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledGenerarTareasRecurrentes = (0, scheduler_1.onSchedule)({ schedule: "0 6 * * *", timeZone: TZ, region: REGION }, async () => {
    console.log("🔄 [Recurrencia] Iniciando generación de tareas...");
    const ahora = new Date();
    const firestore = admin.firestore();
    const empresasSnap = await firestore.collection("empresas").get();
    let totalGeneradas = 0;
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            // Buscar plantillas recurrentes activas con próxima fecha <= hoy
            const plantillasSnap = await firestore
                .collection("empresas")
                .doc(empresaId)
                .collection("tareas")
                .where("es_plantilla_recurrencia", "==", true)
                .where("estado", "in", ["pendiente", "enProgreso", "completada"])
                .get();
            for (const doc of plantillasSnap.docs) {
                const plantilla = doc.data();
                const config = plantilla.configuracion_recurrencia;
                if (!config || config.pausada)
                    continue;
                const proximaTs = plantilla.proxima_fecha_recurrencia;
                if (!proximaTs)
                    continue;
                const proxima = proximaTs.toDate();
                if (proxima > ahora)
                    continue; // aún no toca
                // Generar nueva instancia
                const nuevaFechaLimite = proxima;
                const nuevaRef = firestore
                    .collection("empresas")
                    .doc(empresaId)
                    .collection("tareas")
                    .doc();
                const instancia = Object.assign(Object.assign({}, plantilla), { id: nuevaRef.id, estado: "pendiente", plantilla_id: doc.id, es_plantilla_recurrencia: false, fecha_creacion: db.FieldValue.serverTimestamp(), fecha_actualizacion: db.FieldValue.serverTimestamp(), fecha_limite: db.Timestamp.fromDate(nuevaFechaLimite), registro_tiempo: [], historial: [
                        {
                            usuario_id: "sistema",
                            accion: "creacion_recurrente",
                            descripcion: "Instancia generada automáticamente por el sistema",
                            fecha: db.FieldValue.serverTimestamp(),
                        },
                    ] });
                await nuevaRef.set(instancia);
                // Actualizar plantilla: ultima_generacion y proxima_fecha_recurrencia
                const siguienteFecha = calcularProximaFecha(config, proxima);
                await doc.ref.update({
                    "configuracion_recurrencia.ultima_generacion": db.FieldValue.serverTimestamp(),
                    proxima_fecha_recurrencia: siguienteFecha
                        ? db.Timestamp.fromDate(siguienteFecha)
                        : null,
                });
                totalGeneradas++;
                console.log(`✅ Instancia generada: ${plantilla.titulo} (empresa: ${empresaId})`);
            }
        }
        catch (error) {
            console.error(`❌ Error empresa ${empresaId}:`, error);
        }
    }
    console.log(`✅ [Recurrencia] Total instancias generadas: ${totalGeneradas}`);
});
// ─────────────────────────────────────────────────────────────────────────────
// 2. RECORDATORIOS DE TAREAS — cada hora
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledRecordatoriosTareas = (0, scheduler_1.onSchedule)({ schedule: "0 * * * *", timeZone: TZ, region: REGION }, async () => {
    console.log("⏰ [Recordatorios] Verificando recordatorios...");
    const ahora = new Date();
    const ventana = new Date(ahora.getTime() + 60 * 60 * 1000); // próxima hora
    const firestore = admin.firestore();
    const empresasSnap = await firestore.collection("empresas").get();
    let totalEnviados = 0;
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            const tareasSnap = await firestore
                .collection("empresas")
                .doc(empresaId)
                .collection("tareas")
                .where("estado", "not-in", ["completada", "cancelada"])
                .get();
            for (const tareaDoc of tareasSnap.docs) {
                const tarea = tareaDoc.data();
                const recordatorio = tarea.recordatorio;
                if (!recordatorio || recordatorio.enviado)
                    continue;
                if (recordatorio.tipo === "ninguno")
                    continue;
                const fechaLimiteTs = tarea.fecha_limite;
                if (!fechaLimiteTs)
                    continue;
                const fechaLimite = fechaLimiteTs.toDate();
                // Calcular fecha efectiva del recordatorio
                let fechaRecordatorio = null;
                if (recordatorio.tipo === "personalizado") {
                    const fpTs = recordatorio.fecha_personalizada;
                    fechaRecordatorio = fpTs ? fpTs.toDate() : null;
                }
                else {
                    const minutosMap = {
                        unaHora: 60, tresHoras: 180, unDia: 1440,
                        dosDias: 2880, unaSemana: 10080,
                    };
                    const minutos = minutosMap[recordatorio.tipo];
                    if (minutos) {
                        fechaRecordatorio = new Date(fechaLimite.getTime() - minutos * 60 * 1000);
                    }
                }
                if (!fechaRecordatorio)
                    continue;
                if (fechaRecordatorio < ahora || fechaRecordatorio > ventana)
                    continue;
                // Enviar notificación al asignado
                const asignadoId = tarea.usuario_asignado_id;
                if (!asignadoId)
                    continue;
                const tokens = await _tokensPorUsuario(empresaId, asignadoId);
                if (tokens.length === 0)
                    continue;
                const diasRestantes = Math.ceil((fechaLimite.getTime() - ahora.getTime()) / (1000 * 60 * 60 * 24));
                const cuandoText = diasRestantes === 0
                    ? "hoy"
                    : diasRestantes === 1
                        ? "mañana"
                        : `el ${fechaLimite.toLocaleDateString("es-ES")}`;
                await enviarPush(tokens, "⏰ Recordatorio de tarea", `${tarea.titulo} vence ${cuandoText}`, { tipo: "recordatorio_tarea", empresa_id: empresaId, tarea_id: tareaDoc.id });
                // Marcar como enviado
                await tareaDoc.ref.update({ "recordatorio.enviado": true });
                totalEnviados++;
            }
        }
        catch (error) {
            console.error(`❌ Error empresa ${empresaId}:`, error);
        }
    }
    console.log(`✅ [Recordatorios] Total enviados: ${totalEnviados}`);
});
// ─────────────────────────────────────────────────────────────────────────────
// 3. TAREAS QUE VENCEN HOY — diario a las 9:00
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledTareasVencenHoy = (0, scheduler_1.onSchedule)({ schedule: "0 9 * * *", timeZone: TZ, region: REGION }, async () => {
    console.log("📅 [VenceHoy] Verificando tareas que vencen hoy...");
    const ahora = new Date();
    const inicioHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 0, 0, 0);
    const finHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 23, 59, 59);
    const firestore = admin.firestore();
    const empresasSnap = await firestore.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            const tareasSnap = await firestore
                .collection("empresas")
                .doc(empresaId)
                .collection("tareas")
                .where("estado", "not-in", ["completada", "cancelada"])
                .where("fecha_limite", ">=", db.Timestamp.fromDate(inicioHoy))
                .where("fecha_limite", "<=", db.Timestamp.fromDate(finHoy))
                .get();
            for (const tareaDoc of tareasSnap.docs) {
                const tarea = tareaDoc.data();
                const asignadoId = tarea.usuario_asignado_id;
                if (!asignadoId)
                    continue;
                const tokens = await _tokensPorUsuario(empresaId, asignadoId);
                if (tokens.length === 0)
                    continue;
                await enviarPush(tokens, "📅 Tarea vence hoy", `"${tarea.titulo}" debe completarse hoy`, { tipo: "tarea_vence_hoy", empresa_id: empresaId, tarea_id: tareaDoc.id });
                console.log(`📨 Recordatorio 'vence hoy' enviado: ${tarea.titulo}`);
            }
        }
        catch (error) {
            console.error(`❌ Error empresa ${empresaId}:`, error);
        }
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// 4. TRIGGER SUGERENCIA CREADA → Notificar propietario
// ─────────────────────────────────────────────────────────────────────────────
exports.onNuevaSugerencia = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/sugerencias/{sugerenciaId}", region: REGION }, async (event) => {
    var _a, _b, _c;
    const empresaId = event.params.empresaId;
    const sugerencia = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!sugerencia)
        return;
    const texto = ((_b = sugerencia.texto) !== null && _b !== void 0 ? _b : "").substring(0, 100);
    // Obtener tokens de la empresa (propietario recibirá la notificación)
    const tokens = await obtenerTokensEmpresa(empresaId);
    if (tokens.length === 0)
        return;
    await enviarPush(tokens, "💡 Nueva sugerencia de mejora", texto.length < ((_c = sugerencia.texto) !== null && _c !== void 0 ? _c : "").length ? `${texto}...` : texto, {
        tipo: "nueva_sugerencia",
        empresa_id: empresaId,
        sugerencia_id: event.params.sugerenciaId,
    });
    console.log(`✅ Notificación sugerencia enviada (empresa: ${empresaId})`);
});
// ─────────────────────────────────────────────────────────────────────────────
// HELPER PRIVADO
// ─────────────────────────────────────────────────────────────────────────────
async function _tokensPorUsuario(empresaId, usuarioId) {
    var _a, _b;
    // Intentar en empresa/dispositivos
    const disposSnap = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("dispositivos")
        .doc(usuarioId)
        .get();
    const token = (_a = disposSnap.data()) === null || _a === void 0 ? void 0 : _a.token;
    if (token)
        return [token];
    // Fallback: colección global usuarios
    const usuSnap = await admin
        .firestore()
        .collection("usuarios")
        .doc(usuarioId)
        .get();
    const t2 = (_b = usuSnap.data()) === null || _b === void 0 ? void 0 : _b.token_dispositivo;
    return t2 ? [t2] : [];
}
//# sourceMappingURL=tareasFunciones.js.map