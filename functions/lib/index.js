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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.webhookPagoWeb = exports.listarCuentasClientes = exports.actualizarPlanEmpresa = exports.crearCuentaConPlan = exports.remitirVerifactu = exports.firmarXMLVerifactu = exports.enviarRecordatoriosCitas = exports.registrarVisita = exports.enviarEmailConPdf = exports.stripeWebhook = exports.crearEmpresaHTTP = exports.inicializarEmpresa = exports.onNuevoPedidoWhatsApp = exports.verificarSuscripciones = exports.onNuevoPedidoGenerarFactura = exports.onNuevoPedido = exports.onNuevaValoracion = exports.onReservaCancelada = exports.onReservaConfirmada = exports.onNuevaCita = exports.onNuevaReserva = exports.onNuevaSugerencia = exports.scheduledTareasVencenHoy = exports.scheduledRecordatoriosTareas = exports.scheduledGenerarTareasRecurrentes = exports.onTareaAsignada = exports.resumenSemanalResenas = exports.alertaResenasNegativasAcumuladas = exports.scheduledSincronizarResenas = exports.procesarRespuestasPendientes = exports.publicarRespuestaGoogle = exports.desconectarGoogleBusiness = exports.guardarFichaSeleccionada = exports.obtenerFichasNegocio = exports.storeGmbToken = exports.actualizarModulosSegunPlan = exports.actualizarPlanEmpresaV2 = exports.migracionPlanesV2 = exports.generarFacturasResumenTpv = exports.sendResetPasswordEmail = exports.onInvitacionCreada = exports.verificarLoginIntento = exports.scheduledAlertaCertificado = exports.scheduledAlertaPreciosAntiguos = exports.cambiarEstadoChatBot = exports.enviarMensajeAdminWhatsApp = exports.enviarPlantillaWhatsApp = exports.whatsappWebhook = exports.calculateFiscalModel = exports.processInvoice = void 0;
exports.onNuevoMensajeContacto = exports.backupDatosFiscalesNocturno = exports.alertasVencimientosFiscales = exports.enviarDocumentacionFiniquito = exports.scheduledAlertaCobertura = exports.scheduledExpiracionCarryover = exports.scheduledCierreAnualVacaciones = exports.onVacacionEstadoCambiado = exports.importarFestivosEspana = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const stripe_1 = __importDefault(require("stripe"));
const resend_service_1 = require("./resend_service");
const recordatoriosCitas_1 = require("./recordatoriosCitas");
Object.defineProperty(exports, "enviarRecordatoriosCitas", { enumerable: true, get: function () { return recordatoriosCitas_1.enviarRecordatoriosCitas; } });
const notificacionesTareas_1 = require("./notificacionesTareas");
Object.defineProperty(exports, "onTareaAsignada", { enumerable: true, get: function () { return notificacionesTareas_1.onTareaAsignada; } });
const tareasFunciones_1 = require("./tareasFunciones");
Object.defineProperty(exports, "scheduledGenerarTareasRecurrentes", { enumerable: true, get: function () { return tareasFunciones_1.scheduledGenerarTareasRecurrentes; } });
Object.defineProperty(exports, "scheduledRecordatoriosTareas", { enumerable: true, get: function () { return tareasFunciones_1.scheduledRecordatoriosTareas; } });
Object.defineProperty(exports, "scheduledTareasVencenHoy", { enumerable: true, get: function () { return tareasFunciones_1.scheduledTareasVencenHoy; } });
Object.defineProperty(exports, "onNuevaSugerencia", { enumerable: true, get: function () { return tareasFunciones_1.onNuevaSugerencia; } });
const alertaCertificado_1 = require("./alertaCertificado");
Object.defineProperty(exports, "scheduledAlertaCertificado", { enumerable: true, get: function () { return alertaCertificado_1.scheduledAlertaCertificado; } });
const authGuard_1 = require("./utils/authGuard");
const fuerzaBruta_1 = require("./auth/fuerzaBruta");
Object.defineProperty(exports, "verificarLoginIntento", { enumerable: true, get: function () { return fuerzaBruta_1.verificarLoginIntento; } });
const node_fetch_1 = __importDefault(require("node-fetch"));
var processInvoice_1 = require("./fiscal/processInvoice");
Object.defineProperty(exports, "processInvoice", { enumerable: true, get: function () { return processInvoice_1.processInvoice; } });
var calculateModel_1 = require("./fiscal/models/calculateModel");
Object.defineProperty(exports, "calculateFiscalModel", { enumerable: true, get: function () { return calculateModel_1.calculateFiscalModel; } });
var whatsappBot_1 = require("./whatsappBot");
Object.defineProperty(exports, "whatsappWebhook", { enumerable: true, get: function () { return whatsappBot_1.whatsappWebhook; } });
Object.defineProperty(exports, "enviarPlantillaWhatsApp", { enumerable: true, get: function () { return whatsappBot_1.enviarPlantillaWhatsApp; } });
Object.defineProperty(exports, "enviarMensajeAdminWhatsApp", { enumerable: true, get: function () { return whatsappBot_1.enviarMensajeAdminWhatsApp; } });
Object.defineProperty(exports, "cambiarEstadoChatBot", { enumerable: true, get: function () { return whatsappBot_1.cambiarEstadoChatBot; } });
// NOTA: generarThumbnailCatalogo desactivado temporalmente por bug del CLI
// "Can't find the storage bucket region" — se reactiva tras actualizar firebase-tools
// export { generarThumbnailCatalogo } from "./catalogoFunciones";
var catalogoFunciones_1 = require("./catalogoFunciones");
Object.defineProperty(exports, "scheduledAlertaPreciosAntiguos", { enumerable: true, get: function () { return catalogoFunciones_1.scheduledAlertaPreciosAntiguos; } });
var invitaciones_1 = require("./invitaciones");
Object.defineProperty(exports, "onInvitacionCreada", { enumerable: true, get: function () { return invitaciones_1.onInvitacionCreada; } });
var resetPassword_1 = require("./resetPassword");
Object.defineProperty(exports, "sendResetPasswordEmail", { enumerable: true, get: function () { return resetPassword_1.sendResetPasswordEmail; } });
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const REGION = "europe-west1";
// ── Resumen diario TPV automático ─────────────────────────────────────────────
// Ejecuta cada día a las 23:30 hora de Madrid
// Genera facturas resumen para empresas con generarAutomaticamente = true
exports.generarFacturasResumenTpv = (0, scheduler_1.onSchedule)({ schedule: "30 23 * * *", timeZone: "Europe/Madrid", region: REGION }, async (_event) => {
    var _a, _b;
    const hoy = new Date();
    const inicioHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 0, 0, 0);
    const finHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);
    // Buscar empresas con resumen diario automático activado
    const configSnap = await db
        .collectionGroup("configuracion")
        .where("modo", "==", "resumenDiario")
        .where("generar_automaticamente", "==", true)
        .get();
    let procesadas = 0;
    for (const configDoc of configSnap.docs) {
        const empresaId = (_a = configDoc.ref.parent.parent) === null || _a === void 0 ? void 0 : _a.id;
        if (!empresaId)
            continue;
        try {
            // Pedidos TPV del día sin facturar
            const pedidosSnap = await db
                .collection(`empresas/${empresaId}/pedidos`)
                .where("origen", "in", ["presencial", "tpvExterno"])
                .where("estado_pago", "==", "pagado")
                .where("factura_id", "==", null)
                .where("fecha_creacion", ">=", admin.firestore.Timestamp.fromDate(inicioHoy))
                .where("fecha_creacion", "<=", admin.firestore.Timestamp.fromDate(finHoy))
                .get();
            if (pedidosSnap.empty) {
                console.log(`ℹ️ Sin pedidos TPV pendientes para empresa ${empresaId}`);
                continue;
            }
            const totalVentas = pedidosSnap.docs.reduce((sum, doc) => {
                var _a;
                return sum + ((_a = doc.data()["total"]) !== null && _a !== void 0 ? _a : 0);
            }, 0);
            const fechaStr = `${String(hoy.getDate()).padStart(2, "0")}/${String(hoy.getMonth() + 1).padStart(2, "0")}/${hoy.getFullYear()}`;
            // Obtener configuración de facturación (serie, vencimiento, etc.)
            const config = configDoc.data();
            const diasVencimiento = (_b = config["dias_vencimiento"]) !== null && _b !== void 0 ? _b : 0;
            // Crear contador de facturas (serie tpv)
            const contadorRef = db.doc(`empresas/${empresaId}/configuracion/facturacion`);
            const anioActual = hoy.getFullYear();
            let numeroFactura = "";
            await db.runTransaction(async (tx) => {
                var _a, _b, _c;
                const snap = await tx.get(contadorRef);
                const data = snap.exists ? ((_a = snap.data()) !== null && _a !== void 0 ? _a : {}) : {};
                const anioGuardado = (_b = data["anio_ultimo_tpv"]) !== null && _b !== void 0 ? _b : 0;
                let contador = anioGuardado === anioActual
                    ? ((_c = data["ultimo_numero_tpv"]) !== null && _c !== void 0 ? _c : 0) + 1
                    : 1;
                tx.set(contadorRef, {
                    ultimo_numero_tpv: contador,
                    anio_ultimo_tpv: anioActual,
                }, { merge: true });
                numeroFactura = `TPV-${anioActual}-${String(contador).padStart(4, "0")}`;
            });
            // Crear documento de factura
            const facturaRef = db.collection(`empresas/${empresaId}/facturas`).doc();
            const lineas = pedidosSnap.docs.flatMap((pedidoDoc) => {
                var _a;
                const lineasPedido = (_a = pedidoDoc.data()["lineas"]) !== null && _a !== void 0 ? _a : [];
                return lineasPedido.map((l) => {
                    var _a, _b, _c;
                    return ({
                        descripcion: (_a = l.producto_nombre) !== null && _a !== void 0 ? _a : "Venta TPV",
                        precio_unitario: (_b = l.precio_unitario) !== null && _b !== void 0 ? _b : 0,
                        cantidad: (_c = l.cantidad) !== null && _c !== void 0 ? _c : 1,
                        porcentaje_iva: 10,
                        descuento: 0,
                        recargo_equivalencia: 0,
                    });
                });
            });
            const subtotal = lineas.reduce((s, l) => s + l.precio_unitario * l.cantidad, 0);
            const totalIva = lineas.reduce((s, l) => s + (l.precio_unitario * l.cantidad * l.porcentaje_iva / 100), 0);
            await facturaRef.set({
                empresa_id: empresaId,
                numero_factura: numeroFactura,
                serie: "tpv",
                tipo: "venta_directa",
                estado: "pagada",
                cliente_nombre: `Ventas TPV — ${fechaStr}`,
                lineas,
                subtotal,
                total_iva: totalIva,
                total: subtotal + totalIva,
                descuento_global: 0,
                importe_descuento_global: 0,
                porcentaje_irpf: 0,
                retencion_irpf: 0,
                total_recargo_equivalencia: 0,
                dias_vencimiento: diasVencimiento,
                notas_internas: `Resumen diario TPV autom.: ${pedidosSnap.docs.length} ventas · ${totalVentas.toFixed(2)}€`,
                historial: [{
                        usuario_id: "",
                        usuario_nombre: "TPV Auto",
                        accion: "creada",
                        descripcion: "Factura resumen diario TPV generada automáticamente",
                        fecha: admin.firestore.FieldValue.serverTimestamp(),
                    }],
                fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
                fecha_vencimiento: admin.firestore.Timestamp.fromDate(new Date(hoy.getTime() + diasVencimiento * 86400000)),
                pedidos_incluidos: pedidosSnap.docs.map(d => d.id),
            });
            // Marcar pedidos como facturados
            const batch = db.batch();
            pedidosSnap.docs.forEach(doc => {
                batch.update(doc.ref, {
                    factura_id: facturaRef.id,
                    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                });
            });
            await batch.commit();
            procesadas++;
            console.log(`✅ Factura resumen TPV ${numeroFactura} generada para empresa ${empresaId} (${pedidosSnap.docs.length} ventas)`);
        }
        catch (error) {
            console.error(`❌ Error generando factura resumen TPV para empresa ${empresaId}:`, error);
        }
    }
    console.log(`✅ generarFacturasResumenTpv finalizado: ${procesadas} empresas procesadas`);
});
// ── Planes V2: migración, actualización y recálculo de módulos ────────────────
var planesConfigV2_1 = require("./planesConfigV2");
Object.defineProperty(exports, "migracionPlanesV2", { enumerable: true, get: function () { return planesConfigV2_1.migracionPlanesV2; } });
Object.defineProperty(exports, "actualizarPlanEmpresaV2", { enumerable: true, get: function () { return planesConfigV2_1.actualizarPlanEmpresaV2; } });
Object.defineProperty(exports, "actualizarModulosSegunPlan", { enumerable: true, get: function () { return planesConfigV2_1.actualizarModulosSegunPlan; } });
// ── GMB: Google Business Profile ──────────────────────────────────────────────
var gmbTokens_1 = require("./gmbTokens");
Object.defineProperty(exports, "storeGmbToken", { enumerable: true, get: function () { return gmbTokens_1.storeGmbToken; } });
Object.defineProperty(exports, "obtenerFichasNegocio", { enumerable: true, get: function () { return gmbTokens_1.obtenerFichasNegocio; } });
Object.defineProperty(exports, "guardarFichaSeleccionada", { enumerable: true, get: function () { return gmbTokens_1.guardarFichaSeleccionada; } });
Object.defineProperty(exports, "desconectarGoogleBusiness", { enumerable: true, get: function () { return gmbTokens_1.desconectarGoogleBusiness; } });
var gmbRespuestas_1 = require("./gmbRespuestas");
Object.defineProperty(exports, "publicarRespuestaGoogle", { enumerable: true, get: function () { return gmbRespuestas_1.publicarRespuestaGoogle; } });
Object.defineProperty(exports, "procesarRespuestasPendientes", { enumerable: true, get: function () { return gmbRespuestas_1.procesarRespuestasPendientes; } });
Object.defineProperty(exports, "scheduledSincronizarResenas", { enumerable: true, get: function () { return gmbRespuestas_1.scheduledSincronizarResenas; } });
Object.defineProperty(exports, "alertaResenasNegativasAcumuladas", { enumerable: true, get: function () { return gmbRespuestas_1.alertaResenasNegativasAcumuladas; } });
Object.defineProperty(exports, "resumenSemanalResenas", { enumerable: true, get: function () { return gmbRespuestas_1.resumenSemanalResenas; } });
// ── SECRETS via variables de entorno (.env o Firebase env config) ─────────
// Valores reales: edita functions/.env (no subir a git)
const stripeSecretKey = { value: () => { var _a; return (_a = process.env.STRIPE_SECRET_KEY) !== null && _a !== void 0 ? _a : ""; } };
const stripeWebhookSecret = { value: () => { var _a; return (_a = process.env.STRIPE_WEBHOOK_SECRET) !== null && _a !== void 0 ? _a : ""; } };
// Resend API key — configurado en functions/.env como RESEND_API_KEY
// ── UTILIDADES ────────────────────────────────────────────────────────────────
async function obtenerTokensEmpresa(empresaId) {
    const col = db.collection("empresas").doc(empresaId).collection("dispositivos");
    // Primero intenta con filtro activo == true
    let snapshot = await col.where("activo", "==", true).get();
    // Si no hay resultados, coge todos (puede que el campo se llame diferente)
    if (snapshot.empty) {
        snapshot = await col.get();
    }
    const tokens = [];
    snapshot.forEach((doc) => {
        const token = doc.data().token;
        if (token && token.length > 10)
            tokens.push(token);
    });
    // Fallback: si no hay tokens en dispositivos, buscar en colección usuarios
    if (tokens.length === 0) {
        console.log(`⚠️ Sin tokens en dispositivos para ${empresaId}, buscando en usuarios...`);
        const usuariosSnap = await db
            .collection("usuarios")
            .where("empresa_id", "==", empresaId)
            .where("activo", "!=", false)
            .get();
        for (const userDoc of usuariosSnap.docs) {
            const tokenUsuario = userDoc.data().token_dispositivo;
            if (tokenUsuario && tokenUsuario.length > 10 && !tokens.includes(tokenUsuario)) {
                tokens.push(tokenUsuario);
                // Sincronizar: guardar también en dispositivos para la próxima vez
                try {
                    await col.doc(userDoc.id).set({
                        token: tokenUsuario,
                        uid_usuario: userDoc.id,
                        activo: true,
                        sincronizado_desde: "fallback_usuarios",
                        ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                    }, { merge: true });
                    console.log(`🔄 Token sincronizado de usuarios/${userDoc.id} → dispositivos`);
                }
                catch (_) { /* no bloquear el envío */ }
            }
        }
    }
    return tokens;
}
async function enviarNotificacionEmpresa(empresaId, titulo, cuerpo, data = {}) {
    const tokens = await obtenerTokensEmpresa(empresaId);
    if (tokens.length === 0) {
        console.log(`❌ No hay tokens para empresa ${empresaId} — NO se envía push`);
        return;
    }
    console.log(`📤 Enviando push a ${tokens.length} token(s) para empresa ${empresaId}: "${titulo}"`);
    const mensaje = {
        tokens,
        notification: { title: titulo, body: cuerpo },
        data: Object.assign({ empresa_id: empresaId }, data),
        android: {
            priority: "high",
            notification: {
                channelId: "fluixcrm_canal_principal",
                sound: "default",
                priority: "high",
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        },
    };
    try {
        const respuesta = await messaging.sendEachForMulticast(mensaje);
        console.log(`✅ Notificaciones enviadas: ${respuesta.successCount}/${tokens.length}`);
        if (respuesta.failureCount > 0) {
            const tokensAEliminar = [];
            respuesta.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const error = resp.error;
                    if ((error === null || error === void 0 ? void 0 : error.code) === "messaging/registration-token-not-registered" ||
                        (error === null || error === void 0 ? void 0 : error.code) === "messaging/invalid-registration-token") {
                        tokensAEliminar.push(tokens[idx]);
                    }
                }
            });
            if (tokensAEliminar.length > 0) {
                const dispositivosRef = db
                    .collection("empresas")
                    .doc(empresaId)
                    .collection("dispositivos");
                const snapshotInvalidos = await dispositivosRef
                    .where("token", "in", tokensAEliminar)
                    .get();
                const batch = db.batch();
                snapshotInvalidos.forEach((doc) => {
                    batch.update(doc.ref, { activo: false });
                });
                await batch.commit();
            }
        }
    }
    catch (error) {
        console.error("❌ Error enviando notificaciones:", error);
    }
}
/**
 * Helper compartido: procesa reserva/cita nueva → bandeja + push
 */
async function procesarNuevaReservaOCita(empresaId, entidadId, reserva, coleccion) {
    var _a;
    const cliente = reserva.nombre_cliente || reserva.cliente || "Cliente";
    const telefonoVal = (reserva.telefono_cliente || reserva.telefono);
    const emailVal = reserva.email_cliente || reserva.correo_cliente || reserva.email || null;
    const telefono = telefonoVal ? ` · ${telefonoVal}` : "";
    // Personas / comensales
    const personas = reserva.numero_personas || reserva.comensales || reserva.personas;
    const personasStr = personas ? ` · ${personas} pers.` : "";
    // Ubicación / zona
    const ubicacion = reserva.ubicacion || reserva.zona || "";
    const ubicacionStr = ubicacion
        ? ` · ${ubicacion === "terraza" ? "🌿 Terraza" : ubicacion === "salon" ? "🏠 Salón" : ubicacion}`
        : "";
    // Alérgenos — acepta bool true o string "si"
    const alergenosRaw = reserva.alergenos;
    const tieneAlergenos = alergenosRaw === true || alergenosRaw === "si";
    const alergenosDetalle = (reserva.alergenos_detalle || reserva.detalle_alergenos || "");
    const alergenosStr = tieneAlergenos
        ? ` · ⚠️ Alérgenos${alergenosDetalle ? ": " + alergenosDetalle : ""}`
        : "";
    const servicio = reserva.servicio || "";
    // Campos adicionales genéricos: cualquier campo extra del documento
    const extraCampos = [];
    const camposGenericosCandidatos = ["zona_mesa", "tipo_menu", "ocasion", "habitacion", "preferencias"];
    for (const c of camposGenericosCandidatos) {
        const v = reserva[c];
        if (v && typeof v === "string" && v.trim())
            extraCampos.push(v.trim());
    }
    const extrasStr = extraCampos.length ? ` · ${extraCampos.join(" · ")}` : "";
    const fechaHoraRaw = reserva.fecha_hora;
    let fechaHora = "Fecha pendiente";
    if (fechaHoraRaw) {
        if (typeof fechaHoraRaw === "string") {
            fechaHora = fechaHoraRaw.replace("T", " a las ").substring(0, 19);
        }
        else if (typeof fechaHoraRaw.toDate === "function") {
            fechaHora = fechaHoraRaw.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
        }
        else if (fechaHoraRaw._seconds !== undefined) {
            fechaHora = new Date(fechaHoraRaw._seconds * 1000).toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
        }
    }
    else if ((_a = reserva.fecha) === null || _a === void 0 ? void 0 : _a.toDate) {
        fechaHora = reserva.fecha.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
    }
    const emoji = coleccion === "citas" ? "💈" : "📅";
    const label = coleccion === "citas" ? "Nueva Cita" : "Nueva Reserva";
    const titulo = `${emoji} ${label}`;
    const cuerpo = `${cliente}${telefono}${personasStr}${ubicacionStr} — ${fechaHora}${servicio ? " · " + servicio : ""}${alergenosStr}${extrasStr}`;
    // 1. Guardar en bandeja in-app (con todos los campos extra)
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
        titulo,
        cuerpo,
        tipo: "reservaNueva",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: coleccion,
        entidad_id: entidadId,
        remitente_nombre: cliente !== "Cliente" ? cliente : null,
        remitente_telefono: telefonoVal || null,
        remitente_email: emailVal,
        // Campos extra para la bandeja
        ubicacion: ubicacion || null,
        personas: personas !== undefined && personas !== null ? String(personas) : null,
        alergenos: tieneAlergenos,
        alergenos_detalle: tieneAlergenos && alergenosDetalle ? alergenosDetalle : null,
    });
    // 2. Enviar push FCM
    await enviarNotificacionEmpresa(empresaId, titulo, cuerpo, { tipo: "nueva_reserva", reserva_id: entidadId, coleccion });
    console.log(`✅ ${label} guardada en bandeja y push enviado — empresa ${empresaId}`);
}
/**
 * 1. NUEVA RESERVA
 */
exports.onNuevaReserva = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION }, async (event) => {
    var _a;
    const reserva = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!reserva)
        return;
    await procesarNuevaReservaOCita(event.params.empresaId, event.params.reservaId, reserva, "reservas");
});
/**
 * 1b. NUEVA CITA (mismo flujo, colección distinta)
 */
exports.onNuevaCita = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/citas/{citaId}", region: REGION }, async (event) => {
    var _a;
    const cita = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!cita)
        return;
    await procesarNuevaReservaOCita(event.params.empresaId, event.params.citaId, cita, "citas");
});
// ── HELPER: formatea fecha de reserva para emails ─────────────────────────────
function _formatearFechaReserva(reserva) {
    const raw = reserva.fecha_hora || reserva.fecha;
    if (!raw)
        return "Fecha pendiente";
    if (typeof raw === "string") {
        return raw.replace("T", " a las ").substring(0, 16);
    }
    if (typeof raw.toDate === "function") {
        return raw.toDate().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
    }
    if (raw._seconds !== undefined) {
        return new Date(raw._seconds * 1000).toLocaleString("es-ES", { timeZone: "Europe/Madrid" });
    }
    return "Fecha pendiente";
}
// ── HELPER: obtiene nombre e email de la empresa ───────────────────────────────
async function _getDatosEmpresa(empresaId) {
    try {
        const doc = await db.collection("empresas").doc(empresaId).get();
        const d = doc.data() || {};
        return {
            nombre: d.nombre || "El establecimiento",
            email: (d.email_notificaciones || d.correo || d.email || null),
        };
    }
    catch (_) {
        return { nombre: "El establecimiento", email: null };
    }
}
/**
 * 2a. RESERVA CONFIRMADA — envía push a la empresa + email de confirmación al cliente
 */
exports.onReservaConfirmada = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION }, async (event) => {
    var _a, _b;
    const empresaId = event.params.empresaId;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    // Solo cuando cambia a CONFIRMADA
    if (antes.estado === despues.estado || despues.estado !== "CONFIRMADA")
        return;
    const cliente = despues.nombre_cliente || despues.cliente || "Cliente";
    const fechaHora = _formatearFechaReserva(despues);
    const servicio = despues.servicio || "";
    const emailCliente = despues.email_cliente || despues.correo_cliente || despues.email || null;
    // 1. Push a la empresa (confirmación interna)
    const cuerpo = `${cliente} — ${fechaHora}${servicio ? " · " + servicio : ""}`;
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
        titulo: "✅ Reserva Confirmada",
        cuerpo,
        tipo: "reservaConfirmada",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "reservas",
        entidad_id: event.params.reservaId,
        remitente_nombre: cliente !== "Cliente" ? cliente : null,
        remitente_telefono: despues.telefono_cliente || null,
        remitente_email: emailCliente,
    });
    await enviarNotificacionEmpresa(empresaId, "✅ Reserva Confirmada", cuerpo, { tipo: "reserva_confirmada", reserva_id: event.params.reservaId });
    // 2. Email al cliente si tiene correo
    if (emailCliente) {
        try {
            const empresa = await _getDatosEmpresa(empresaId);
            const personas = despues.numero_personas || despues.personas;
            const zona = despues.zona || "";
            await (0, resend_service_1.enviarConfirmacionReserva)({
                to: emailCliente,
                clienteNombre: cliente,
                empresaNombre: empresa.nombre,
                fechaHora,
                personas: personas ? String(personas) : undefined,
                servicio: servicio || undefined,
                zona: zona || undefined,
                notas: despues.notas || undefined,
                fromEmail: empresa.email || undefined,
            });
            console.log(`✅ Email confirmación reserva enviado a ${emailCliente}`);
        }
        catch (emailErr) {
            console.error("❌ Error enviando email confirmación reserva:", emailErr.message);
        }
    }
    else {
        console.log(`ℹ️ Reserva ${event.params.reservaId} confirmada sin email de cliente`);
    }
});
/**
 * 2b. RESERVA CANCELADA — notifica a la empresa + email de cancelación al cliente
 */
exports.onReservaCancelada = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION }, async (event) => {
    var _a, _b;
    const empresaId = event.params.empresaId;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    if (antes.estado === despues.estado || despues.estado !== "CANCELADA") {
        return;
    }
    const cliente = despues.nombre_cliente || despues.cliente || "Cliente";
    const servicio = despues.servicio || "";
    const fechaHora = _formatearFechaReserva(despues);
    const cuerpo = `${cliente} — ${fechaHora}${servicio ? " · " + servicio : ""}`;
    const emailCliente = despues.email_cliente || despues.correo_cliente || despues.email || null;
    // 1. Bandeja + push a la empresa
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
        titulo: "❌ Reserva Cancelada",
        cuerpo,
        tipo: "reservaCancelada",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "reservas",
        entidad_id: event.params.reservaId,
        remitente_nombre: cliente !== "Cliente" ? cliente : null,
        remitente_telefono: despues.telefono_cliente || null,
        remitente_email: emailCliente,
    });
    await enviarNotificacionEmpresa(empresaId, "❌ Reserva Cancelada", cuerpo, { tipo: "reserva_cancelada", reserva_id: event.params.reservaId });
    // 2. Email al cliente si tiene correo
    if (emailCliente) {
        try {
            const empresa = await _getDatosEmpresa(empresaId);
            const personas = despues.numero_personas || despues.personas;
            await (0, resend_service_1.enviarCancelacionReserva)({
                to: emailCliente,
                clienteNombre: cliente,
                empresaNombre: empresa.nombre,
                fechaHora,
                personas: personas ? String(personas) : undefined,
                servicio: servicio || undefined,
                motivoCancelacion: despues.motivo_cancelacion || undefined,
                fromEmail: empresa.email || undefined,
            });
            console.log(`✅ Email cancelación reserva enviado a ${emailCliente}`);
        }
        catch (emailErr) {
            console.error("❌ Error enviando email cancelación reserva:", emailErr.message);
        }
    }
    else {
        console.log(`ℹ️ Reserva ${event.params.reservaId} cancelada sin email de cliente`);
    }
});
/**
 * 3. NUEVA VALORACIÓN — con alertas diferenciadas por rating
 */
exports.onNuevaValoracion = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/valoraciones/{valoracionId}", region: REGION }, async (event) => {
    var _a, _b, _c;
    const empresaId = event.params.empresaId;
    const valoracion = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!valoracion)
        return;
    const cliente = valoracion.cliente || "Cliente";
    const estrellas = valoracion.calificacion || valoracion.estrellas || 5;
    const comentario = valoracion.comentario || "";
    const origen = valoracion.origen || "app";
    // Leer umbral de alerta configurado por el empresario (defecto: 3)
    let umbralAlerta = 3;
    try {
        const prefSnap = await db
            .collection("empresas").doc(empresaId)
            .collection("configuracion").doc("alertas_resenas")
            .get();
        if (prefSnap.exists) {
            umbralAlerta = (_c = (_b = prefSnap.data()) === null || _b === void 0 ? void 0 : _b.umbral_alerta) !== null && _c !== void 0 ? _c : 3;
        }
    }
    catch (_) { }
    const esNegativa = estrellas <= umbralAlerta;
    const titulo = esNegativa
        ? `⚠️ Nueva reseña de ${estrellas} ${estrellas === 1 ? "estrella" : "estrellas"}`
        : `⭐ Nueva reseña positiva${origen === "google" ? " en Google" : ""}`;
    const cuerpo = `${cliente}: "${comentario.substring(0, 80)}${comentario.length > 80 ? "..." : ""}"`;
    const mensaje = {
        tokens: [],
        notification: { title: titulo, body: cuerpo },
        data: {
            empresa_id: empresaId,
            tipo: esNegativa ? "resena_negativa" : "resena_positiva",
            valoracion_id: event.params.valoracionId,
            calificacion: String(estrellas),
        },
        android: {
            priority: "high",
            notification: {
                channelId: esNegativa
                    ? "fluixcrm_resenas_negativas"
                    : "fluixcrm_canal_principal",
                priority: esNegativa ? "max" : "high",
                sound: "default",
                visibility: "public",
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                    "interruption-level": esNegativa ? "time-sensitive" : "active",
                },
            },
        },
    };
    await enviarNotificacionEmpresa(empresaId, titulo, cuerpo, mensaje.data);
});
/**
 * 4. NUEVO PEDIDO
 */
exports.onNuevoPedido = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const pedido = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!pedido)
        return;
    // El widget web guarda 'cliente_nombre'; la app guarda 'cliente'
    const cliente = pedido.cliente_nombre || pedido.cliente || pedido.nombre_cliente || "Cliente";
    const telefono = pedido.cliente_telefono || pedido.telefono || null;
    const email = pedido.cliente_correo || pedido.email || null;
    const total = pedido.precio_total || pedido.total || 0;
    const origen = pedido.origen || "app";
    const cuerpo = `${cliente} — €${total.toFixed(2)} (vía ${origen})`;
    // Guardar en bandeja in-app
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
        titulo: "🛒 Nuevo Pedido",
        cuerpo,
        tipo: "reservaNueva", // usamos reservaNueva como tipo genérico hasta añadir tipo pedido
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "pedidos",
        entidad_id: event.params.pedidoId,
        remitente_nombre: cliente !== "Cliente" ? cliente : null,
        remitente_telefono: telefono,
        remitente_email: email,
    });
    await enviarNotificacionEmpresa(empresaId, "🛒 Nuevo Pedido", cuerpo, { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId });
});
/**
 * 5. NUEVO PEDIDO → GENERAR FACTURA AUTOMÁTICAMENTE
 */
exports.onNuevoPedidoGenerarFactura = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const pedidoId = event.params.pedidoId;
    const snap = event.data;
    if (!snap)
        return;
    const pedido = snap.data();
    try {
        const configRef = db
            .collection("empresas")
            .doc(empresaId)
            .collection("configuracion")
            .doc("facturacion");
        let numeroFactura = "";
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const configSnap = await tx.get(configRef);
            let contador = 1;
            if (configSnap.exists) {
                contador = ((_b = (_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.ultimo_numero_factura) !== null && _b !== void 0 ? _b : 0) + 1;
            }
            tx.set(configRef, { ultimo_numero_factura: contador }, { merge: true });
            const anio = new Date().getFullYear();
            numeroFactura = `FAC-${anio}-${String(contador).padStart(4, "0")}`;
        });
        const lineasPedido = pedido.lineas || [];
        const lineasFactura = lineasPedido.map((l) => ({
            descripcion: (l.producto_nombre || l.descripcion || "Producto"),
            precio_unitario: l.precio_unitario || 0,
            cantidad: l.cantidad || 1,
            // Usar el IVA real de la línea del pedido; si no existe, 21% por defecto
            porcentaje_iva: l.porcentaje_iva || l.iva || 21.0,
            descuento: l.descuento || 0,
            recargo_equivalencia: l.recargo_equivalencia || 0,
            referencia: (l.producto_id || l.referencia || null),
        }));
        const subtotal = lineasFactura.reduce((sum, l) => sum + l.precio_unitario * l.cantidad * (1 - l.descuento / 100), 0);
        const totalIva = lineasFactura.reduce((sum, l) => sum + l.precio_unitario * l.cantidad * (1 - l.descuento / 100) * (l.porcentaje_iva / 100), 0);
        const total = subtotal + totalIva;
        const metodoPagoMap = {
            tarjeta: "tarjeta",
            paypal: "paypal",
            bizum: "bizum",
            efectivo: "efectivo",
            transferencia: "transferencia",
            stripe: "tarjeta",
        };
        const metodoPago = (_a = metodoPagoMap[pedido.metodo_pago]) !== null && _a !== void 0 ? _a : null;
        // Si el pedido ya está pagado (origen Stripe, etc.), la factura nace directamente como "pagada"
        const estadoPago = pedido.estado_pago || "";
        const estadoFactura = (estadoPago === "pagado" || estadoPago === "paid") ? "pagada" : "pendiente";
        const facturaData = {
            empresa_id: empresaId,
            numero_factura: numeroFactura,
            serie: "fac",
            tipo: "pedido",
            estado: estadoFactura,
            cliente_nombre: pedido.cliente_nombre || "Cliente",
            cliente_telefono: pedido.cliente_telefono || null,
            cliente_correo: pedido.cliente_correo || null,
            datos_fiscales: pedido.datos_fiscales || null,
            lineas: lineasFactura,
            subtotal: subtotal,
            total_iva: totalIva,
            total: total,
            descuento_global: 0,
            importe_descuento_global: 0,
            porcentaje_irpf: 0,
            retencion_irpf: 0,
            total_recargo_equivalencia: 0,
            dias_vencimiento: 30,
            metodo_pago: metodoPago,
            pedido_id: pedidoId,
            notas_internas: null,
            notas_cliente: pedido.notas_cliente || null,
            // Si ya está pagada, registrar fecha_pago
            fecha_pago: estadoFactura === "pagada"
                ? admin.firestore.FieldValue.serverTimestamp()
                : null,
            historial: [
                {
                    usuario_id: "",
                    usuario_nombre: "Sistema",
                    accion: "creada",
                    descripcion: `Factura generada automáticamente desde pedido ${pedidoId.substring(0, 8).toUpperCase()}`,
                    fecha: admin.firestore.FieldValue.serverTimestamp(),
                },
            ],
            fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
            fecha_vencimiento: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        };
        const facturaRef = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("facturas")
            .add(facturaData);
        await snap.ref.update({ factura_id: facturaRef.id });
        console.log(`✅ Factura ${numeroFactura} generada automáticamente para pedido ${pedidoId} (empresa ${empresaId})`);
    }
    catch (error) {
        console.error(`❌ Error generando factura para pedido ${pedidoId}:`, error);
    }
});
// onNuevaFactura ELIMINADA — todas las facturas se generan automáticamente
// desde pedidos de la web, por lo que la notificación de "nuevo pedido" (onNuevoPedido)
// ya cubre el aviso. Tener una notificación extra por factura era redundante.
/**
 * 7. SUSCRIPCIÓN POR VENCER — Cron diario (v2 scheduler)
 */
exports.verificarSuscripciones = (0, scheduler_1.onSchedule)({
    schedule: "every 24 hours",
    timeZone: "Europe/Madrid",
    region: REGION,
}, async () => {
    var _a;
    console.log("🔍 Verificando suscripciones próximas a vencer...");
    const ahora = new Date();
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        try {
            const suscripcionDoc = await empresaDoc.ref
                .collection("suscripcion")
                .doc("actual")
                .get();
            if (!suscripcionDoc.exists)
                continue;
            const suscripcion = suscripcionDoc.data();
            const fechaFin = ((_a = suscripcion.fecha_fin) === null || _a === void 0 ? void 0 : _a.toDate)
                ? suscripcion.fecha_fin.toDate()
                : null;
            if (!fechaFin || suscripcion.estado === "VENCIDA")
                continue;
            const diasRestantes = Math.ceil((fechaFin.getTime() - ahora.getTime()) / (1000 * 60 * 60 * 24));
            const empresaId = empresaDoc.id;
            // ── AUTO-VENCIMIENTO: marcar como VENCIDA si pasó la fecha ──
            if (diasRestantes < -7 && suscripcion.estado === "ACTIVA") {
                // Pasaron más de 7 días de gracia → bloquear
                await suscripcionDoc.ref.update({
                    estado: "VENCIDA",
                    fecha_vencimiento_real: admin.firestore.FieldValue.serverTimestamp(),
                });
                await enviarNotificacionEmpresa(empresaId, "🔒 Suscripción Vencida", "Tu suscripción ha expirado. Renueva en fluixtech.com para seguir usando la app.", { tipo: "suscripcion_vencida" });
                console.log(`🔒 Suscripción VENCIDA para empresa ${empresaId}`);
                continue;
            }
            if (diasRestantes < 0 && diasRestantes >= -7 && suscripcion.estado === "ACTIVA") {
                // Periodo de gracia (0-7 días tras vencimiento): avisar pero no bloquear
                if (!suscripcion.aviso_gracia_enviado) {
                    await enviarNotificacionEmpresa(empresaId, "⚠️ Suscripción expirada — periodo de gracia", `Tu suscripción venció hace ${Math.abs(diasRestantes)} día(s). Renueva antes de ${7 + diasRestantes} días para no perder acceso.`, { tipo: "suscripcion_gracia", dias_restantes: String(diasRestantes) });
                    await suscripcionDoc.ref.update({
                        aviso_gracia_enviado: true,
                        ultimo_aviso: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    console.log(`⚠️ Periodo de gracia para empresa ${empresaId} (día ${Math.abs(diasRestantes)} de 7)`);
                }
                continue;
            }
            // ── AVISOS PRE-VENCIMIENTO: 7, 3 y 1 día antes ──
            if ([7, 3, 1].includes(diasRestantes)) {
                await enviarNotificacionEmpresa(empresaId, "⚠️ Suscripción por Vencer", `Tu suscripción vence en ${diasRestantes} día${diasRestantes !== 1 ? "s" : ""}. ¡Renueva para continuar!`, {
                    tipo: "suscripcion_por_vencer",
                    dias_restantes: String(diasRestantes),
                });
                await suscripcionDoc.ref.update({
                    aviso_enviado: true,
                    aviso_gracia_enviado: false,
                    ultimo_aviso: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`✅ Aviso suscripción enviado para empresa ${empresaId} (${diasRestantes} días)`);
            }
        }
        catch (error) {
            console.error(`❌ Error procesando empresa ${empresaDoc.id}:`, error);
        }
    }
});
/**
 * 8. PEDIDO WHATSAPP NUEVO
 */
exports.onNuevoPedidoWhatsApp = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/pedidos_whatsapp/{pedidoId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const pedido = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!pedido)
        return;
    const cliente = pedido.nombre_cliente || pedido.telefono || "Cliente WhatsApp";
    const total = pedido.total || 0;
    await enviarNotificacionEmpresa(empresaId, "💬 Pedido por WhatsApp", `${cliente} — €${total.toFixed(2)}`, { tipo: "pedido_whatsapp", pedido_id: event.params.pedidoId });
});
// ── GENERADOR DE SCRIPTS DINÁMICOS ────────────────────────────────────────────
// ⛔ generarScriptEmpresa ELIMINADA — causaba doble push al tener formulario de
//    reservas propio que disparaba onNuevaReserva. Usar script_hostinger_v2.txt
//    (data-fluix-seccion) directamente en la web.
/* generarScriptHTML — ELIMINADO (ver comentario en bloque superior) */
// @ts-ignore — función eliminada, mantenida solo como referencia
function _generarScriptHTML_ELIMINADO(empresaId, nombreEmpresa, dominio) {
    return `<!-- ============================================================
     🔥 FLUIX CRM - SCRIPT COMPLETO: CONTENIDO DINÁMICO + ANALYTICS
     Web: ${dominio}
     Empresa: ${nombreEmpresa}
     Versión: SEGURA (no bloquea la web si Firebase falla)
     ============================================================ -->

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- ② PON ESTOS DIVS DONDE QUIERAS EN TU WEB                      -->
<!-- TIP: añade style="display:none" si quieres ocultar al inicio.  -->
<!--      Se revelarán automáticamente al activarlos en la app.      -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- Ejemplo: <div id="fluixcrm_SECCION_ID"></div>                  -->
<!-- Las secciones que crees en la app se inyectarán aquí.           -->
<!-- También puedes añadir estos divs especiales:                    -->
<!-- <div id="fluixcrm_contacto"></div>   → Formulario de contacto   -->
<!-- <div id="fluixcrm_reservas"></div>   → Formulario de reservas   -->
<!-- <div id="fluixcrm_blog"></div>       → Blog / Noticias          -->

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- ③ PEGA ESTO ANTES DEL </body>                                  -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- Firebase SDK -->
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js"></script>

<script>
(function () {
  'use strict';

  var FIREBASE_CONFIG = {
    apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  var EMPRESA_ID = "${empresaId}";
  var DOMINIO_WEB = "${dominio}";
  var NOMBRE_EMPRESA = "${nombreEmpresa}";

  window.addEventListener('load', function () {
    try {
      inicializar();
    } catch (e) {
      console.warn('Fluix CRM: error al inicializar (la web funciona igualmente)', e);
    }
  });

  function inicializar() {
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }

    var db = firebase.firestore();

    // ── ANALYTICS: registrar visitas y eventos ───────────────────────
    registrarVisita(db).catch(function (e) {
      console.warn('Fluix CRM: error registrando visita', e);
    });
    rastrearEventos(db).catch(function (e) {
      console.warn('Fluix CRM: error rastreando eventos', e);
    });

    // ── CONTENIDO DINÁMICO: secciones editadas desde la app ──────────
    cargarContenidoDinamico(db);

    // ── FORMULARIO DE CONTACTO ───────────────────────────────────────
    cargarFormularioContacto(db);

    // ── FORMULARIO DE RESERVAS ───────────────────────────────────────
    cargarFormularioReservas(db);

    // ── BLOG / NOTICIAS ──────────────────────────────────────────────
    cargarBlog(db);
  }

  // ── HELPER: renderizar div ─────────────────────────────────────────
  function render(id, html, show) {
    var el = document.getElementById("fluixcrm_" + id);
    if (!el) return;
    el.innerHTML = html;
    el.style.display = (show === false) ? "none" : "";
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENIDO DINÁMICO — lee secciones en tiempo real desde Firestore
  // ═══════════════════════════════════════════════════════════════════
  function cargarContenidoDinamico(db) {
    db.collection("empresas").doc(EMPRESA_ID)
      .collection("contenido_web").onSnapshot(function(snap) {

      // Detectar secciones eliminadas → ocultar el div
      snap.docChanges().forEach(function(ch) {
        if (ch.type === "removed") render(ch.doc.id, "", false);
      });

      // Renderizar cada sección activa
      snap.forEach(function(doc) {
        var d = doc.data();
        var tipo = d.tipo || "texto";
        var c = d.contenido || {};

        // Si la sección está desactivada → ocultar
        if (!d.activa) { render(doc.id, "", false); return; }

        var html = "";

        if (tipo === "texto") {
          html = '<h3>' + (c.titulo || '') + '</h3>'
               + '<p>' + (c.texto || '') + '</p>'
               + (c.imagen_url ? '<img src="' + c.imagen_url + '" style="max-width:100%;border-radius:8px">' : '');
        }

        else if (tipo === "carta") {
          var items = (c.items_carta || []).filter(function(p){ return p.disponible !== false; });
          html = items.map(function(p) {
            return '<div style="border-bottom:1px solid #eee;padding:10px 0;display:flex;gap:12px;align-items:start">'
              + (p.imagen_url ? '<img src="' + p.imagen_url + '" style="width:70px;height:70px;object-fit:cover;border-radius:8px">' : '')
              + '<div style="flex:1"><div><strong style="font-size:15px">' + p.nombre + '</strong>'
              + '<span style="float:right;font-weight:bold;color:#e65100">' + p.precio + '€</span></div>'
              + '<p style="margin:4px 0 0;color:#666;font-size:13px;line-height:1.4">' + (p.descripcion || '') + '</p></div></div>';
          }).join("");
        }

        else if (tipo === "galeria") {
          var imgs = c.imagenes_galeria || [];
          html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px">'
            + imgs.map(function(i) {
                return '<img src="' + i.url + '" style="width:100%;border-radius:8px;object-fit:cover;aspect-ratio:1" loading="lazy">';
              }).join("")
            + '</div>';
        }

        else if (tipo === "ofertas") {
          var ofertas = (c.ofertas || []).filter(function(o){ return o.activa; });
          html = ofertas.map(function(o) {
            return '<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:12px">'
              + (o.imagen_url ? '<img src="' + o.imagen_url + '" style="width:100%;border-radius:6px;margin-bottom:8px">' : '')
              + '<h4 style="margin:0 0 6px">' + o.titulo + '</h4>'
              + '<p style="color:#666;font-size:13px">' + (o.descripcion || '') + '</p>'
              + (o.precio_original ? '<s style="color:#999">' + o.precio_original + '€</s> ' : '')
              + (o.precio_oferta ? '<strong style="color:#e53935;font-size:18px">' + o.precio_oferta + '€</strong>' : '')
              + '</div>';
          }).join("");
        }

        else if (tipo === "horarios") {
          var filas = (c.horarios || []).map(function(h) {
            return '<tr style="border-bottom:1px solid #f5f5f5">'
              + '<td style="padding:8px 12px;font-weight:bold">' + h.dia + '</td>'
              + '<td style="padding:8px 12px;color:' + (h.cerrado ? '#e53935' : '#2e7d32') + '">'
              + (h.cerrado ? 'Cerrado' : h.apertura + ' – ' + h.cierre) + '</td></tr>';
          }).join("");
          html = '<table style="width:100%;border-collapse:collapse">' + filas + '</table>';
        }

        render(doc.id, html, true);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // FORMULARIO DE CONTACTO — se inyecta en #fluixcrm_contacto
  // ═══════════════════════════════════════════════════════════════════
  function cargarFormularioContacto(db) {
    var el = document.getElementById("fluixcrm_contacto");
    if (!el) return;
    el.innerHTML = '<div style="max-width:480px">'
      + '<h3>Contáctanos</h3>'
      + '<form id="fluixcrm_form_contacto" style="display:flex;flex-direction:column;gap:12px">'
      + '<input name="nombre" placeholder="Tu nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="email" type="email" placeholder="Tu email" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      + '<textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:10px;border:1px solid #ddd;border-radius:8px;resize:vertical"></textarea>'
      + '<button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button>'
      + '</form></div>';

    document.getElementById("fluixcrm_form_contacto").addEventListener("submit", function(e) {
      e.preventDefault();
      var fd = new FormData(e.target);
      db.collection("empresas").doc(EMPRESA_ID).collection("contacto_web").add({
        nombre: fd.get("nombre"),
        email: fd.get("email"),
        mensaje: fd.get("mensaje"),
        fecha: firebase.firestore.FieldValue.serverTimestamp(),
        leido: false
      }).then(function() {
        e.target.innerHTML = '<p style="color:green;font-weight:bold">✅ Mensaje enviado correctamente.</p>';
      }).catch(function(err) {
        alert("Error: " + err.message);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // FORMULARIO DE RESERVAS — se inyecta en #fluixcrm_reservas
  // ═══════════════════════════════════════════════════════════════════
  function cargarFormularioReservas(db) {
    var el = document.getElementById("fluixcrm_reservas");
    if (!el) return;
    el.innerHTML = '<div style="max-width:480px;border:1px solid #eee;padding:24px;border-radius:12px">'
      + '<h3>📅 Reservar Mesa / Cita</h3>'
      + '<form id="fluixcrm_form_reservas" style="display:flex;flex-direction:column;gap:14px">'
      + '<input name="nombre" placeholder="Tu nombre *" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="telefono" type="tel" placeholder="Tu teléfono *" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="email" type="email" placeholder="Tu email (para confirmación)" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<div style="display:flex;gap:10px">'
      + '<input name="fecha" type="date" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1">'
      + '<input name="hora" type="time" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1">'
      + '</div>'
      + '<input name="personas" type="number" min="1" placeholder="Nº Personas" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<input name="servicio" placeholder="Tipo de servicio / cita (opcional)" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      + '<button type="submit" style="background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:16px">Solicitar Reserva</button>'
      + '</form></div>';

    document.getElementById("fluixcrm_form_reservas").addEventListener("submit", function(e) {
      e.preventDefault();
      var fd = new FormData(e.target);
      var fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";
      var fecha = new Date(fechaStr);
      db.collection("empresas").doc(EMPRESA_ID).collection("reservas").add({
        nombre_cliente:   fd.get("nombre"),
        telefono_cliente: fd.get("telefono"),
        email_cliente:    fd.get("email") || null,
        servicio:         fd.get("servicio") || null,
        personas:         fd.get("personas") ? parseInt(fd.get("personas")) : 1,
        fecha:            firebase.firestore.Timestamp.fromDate(fecha),
        fecha_hora:       fecha.toISOString(),
        estado:           "PENDIENTE",
        origen:           "web",
        fecha_creacion:   firebase.firestore.FieldValue.serverTimestamp()
      }).then(function() {
        e.target.innerHTML = '<div style="text-align:center;padding:20px"><h3 style="color:green">✅ ¡Solicitud enviada!</h3><p>Te confirmaremos pronto.</p></div>';
      }).catch(function(err) {
        alert("Error: " + err.message);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // BLOG / NOTICIAS — se inyecta en #fluixcrm_blog
  // ═══════════════════════════════════════════════════════════════════
  function cargarBlog(db) {
    var el = document.getElementById("fluixcrm_blog");
    if (!el) return;
    db.collection("empresas").doc(EMPRESA_ID)
      .collection("blog")
      .where("publicada", "==", true)
      .orderBy("fecha_publicacion", "desc")
      .limit(6)
      .onSnapshot(function(snap) {
        if (snap.empty) {
          el.innerHTML = "<p>Sin noticias por el momento.</p>";
          return;
        }
        el.innerHTML = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px">'
          + snap.docs.map(function(d) {
              var b = d.data();
              var fechaPub = b.fecha_publicacion && b.fecha_publicacion.toDate
                ? b.fecha_publicacion.toDate().toLocaleDateString("es-ES")
                : "";
              return '<article style="border:1px solid #eee;border-radius:10px;overflow:hidden">'
                + (b.imagen_url ? '<img src="' + b.imagen_url + '" style="width:100%;height:160px;object-fit:cover">' : '<div style="height:6px;background:#1976D2"></div>')
                + '<div style="padding:14px"><h4 style="margin:0 0 8px">' + b.titulo + '</h4>'
                + '<p style="color:#666;font-size:13px;margin:0 0 10px">' + (b.resumen || '') + '</p>'
                + '<small style="color:#999">' + fechaPub + '</small></div></article>';
            }).join("")
          + '</div>';
      });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICS — registrar visitas
  // ═══════════════════════════════════════════════════════════════════
  async function registrarVisita(db) {
    var fechaHoy = new Date().toISOString().substring(0, 10);
    var paginaActual = window.location.pathname || '/';
    var hora = new Date().getHours();
    var referrer = document.referrer || 'Directo';

    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc('web_resumen')
      .set({
        visitas_totales: firebase.firestore.FieldValue.increment(1),
        visitas_mes: firebase.firestore.FieldValue.increment(1),
        ultima_visita: firebase.firestore.FieldValue.serverTimestamp(),
        sitio_web: DOMINIO_WEB,
        nombre_empresa: NOMBRE_EMPRESA,
        pagina_actual: paginaActual,
        referrer_actual: referrer
      }, { merge: true });

    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc(\`visitas_\${fechaHoy}\`)
      .set({
        fecha: fechaHoy,
        sitio: DOMINIO_WEB,
        visitas: firebase.firestore.FieldValue.increment(1),
        paginas_vistas: firebase.firestore.FieldValue.arrayUnion(paginaActual),
        referrers: firebase.firestore.FieldValue.arrayUnion(referrer),
        [\`visitas_hora_\${hora}\`]: firebase.firestore.FieldValue.increment(1),
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    console.log('✅ Visita registrada para ' + NOMBRE_EMPRESA + ' en ' + fechaHoy);
  }

  // ═══════════════════════════════════════════════════════════════════
  // RASTREAR EVENTOS (llamadas, formularios, WhatsApp)
  // ═══════════════════════════════════════════════════════════════════
  async function rastrearEventos(db) {
    var telefonos = document.querySelectorAll('a[href^="tel:"], .telefono, .phone');
    telefonos.forEach(function(tel) {
      tel.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "llamada_telefonica",
            sitio: DOMINIO_WEB,
            numero: tel.textContent || tel.href,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📞 Llamada registrada');
      });
    });

    var formularios = document.querySelectorAll('form[id*="contact"], form[class*="contact"], .contact-form');
    formularios.forEach(function(form) {
      form.addEventListener('submit', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "formulario_contacto",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📧 Formulario registrado');
      });
    });

    var whatsapps = document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"], .whatsapp-btn');
    whatsapps.forEach(function(btn) {
      btn.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "whatsapp_click",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('💬 WhatsApp click registrado');
      });
    });
  }

})();
</script>

<!--
🎯 INSTRUCCIONES DE INSTALACIÓN:

1. 📋 COPIA este código completo
2. 📝 En tu HTML, añade los DIVs donde quieras que aparezca el contenido:
   - <div id="fluixcrm_SECCION_ID"></div>  → para cada sección (el ID lo ves en la app)
   - <div id="fluixcrm_contacto"></div>    → formulario de contacto
   - <div id="fluixcrm_reservas"></div>    → formulario de reservas
   - <div id="fluixcrm_blog"></div>        → blog / noticias
3. 📝 PEGA el bloque <script> antes del </body>
4. ✅ GUARDA los cambios
5. 🔄 Todo se actualiza en TIEMPO REAL desde la app

📊 QUE HARÁ ESTE SCRIPT:
✓ Muestra la carta/menú editada desde la app
✓ Muestra horarios, ofertas, galerías, textos
✓ Muestra el blog/noticias
✓ Formulario de contacto → llega a la app
✓ Formulario de reservas → llega a la app
✓ Registra visitas y estadísticas web
✓ Rastrea llamadas, formularios y WhatsApp clicks
✓ Sincroniza todo en tiempo real con Fluix CRM

🌐 VERÁS LOS DATOS EN:
✅ Dashboard principal
✅ Módulo Contenido Web (secciones)
✅ Módulo Reservas (reservas web)
✅ Módulo Estadísticas (tráfico web)
-->`;
}
// ⛔ obtenerScriptJSON ELIMINADA — mismo motivo que generarScriptEmpresa
/**
 * 10. INICIALIZAR EMPRESA (v2 onCall)
 */
exports.inicializarEmpresa = (0, https_1.onCall)({ region: REGION }, async (request) => {
    try {
        // ── AUTH GUARD ──
        (0, authGuard_1.verificarAuth)(request);
        const { empresaId, nombre, dominio, telefono, direccion } = request.data;
        if (!empresaId) {
            throw new https_1.HttpsError("invalid-argument", "empresaId es requerido");
        }
        const empresaRef = db.collection("empresas").doc(empresaId);
        const empresaData = {
            nombre: nombre || "Mi Negocio",
            dominio: dominio || "midominio.com",
            sitio_web: dominio || "midominio.com",
            telefono: telefono || "",
            direccion: direccion || "",
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        };
        await empresaRef.set(empresaData, { merge: true });
        await empresaRef.collection("estadisticas").doc("web_resumen").set({
            visitas_totales: 0,
            visitas_mes: 0,
            ultima_visita: null,
            sitio_web: dominio || "midominio.com",
            nombre_empresa: nombre || "Mi Negocio",
        });
        await empresaRef.collection("configuracion").doc("general").set({
            fecha_instalacion_script: null,
            script_activo: false,
            dominio: dominio || "midominio.com",
        });
        console.log(`✅ Empresa ${empresaId} inicializada correctamente`);
        return {
            exito: true,
            mensaje: `Empresa "${nombre}" creada exitosamente`,
            empresaId,
        };
    }
    catch (error) {
        console.error("❌ Error inicializando empresa:", error);
        throw new https_1.HttpsError("internal", `Error: ${error instanceof Error ? error.message : "Desconocido"}`);
    }
});
/**
 * 11. CREAR EMPRESA HTTP — ⛔ DESHABILITADA POR SEGURIDAD
 * Esta función HTTP no tiene autenticación. Usar inicializarEmpresa (callable) en su lugar.
 */
exports.crearEmpresaHTTP = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    res.status(410).json({
        error: "Esta función ha sido deshabilitada por seguridad. Usa inicializarEmpresa (callable).",
    });
});
// ── STRIPE WEBHOOK (v2 onRequest) ─────────────────────────────────────────────
exports.stripeWebhook = (0, https_1.onRequest)({ region: REGION }, async (req, res) => {
    var _a, _b;
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    const secretKey = stripeSecretKey.value() || "";
    const webhookSec = stripeWebhookSecret.value() || "";
    if (!secretKey) {
        console.error("❌ STRIPE_SECRET_KEY no configurada. Ejecuta: firebase functions:secrets:set STRIPE_SECRET_KEY");
        res.status(500).json({ error: "Stripe no configurado en el servidor" });
        return;
    }
    const stripe = new stripe_1.default(secretKey, { apiVersion: "2024-06-20" });
    let event;
    try {
        const sig = req.headers["stripe-signature"];
        const rawBody = (_a = req.rawBody) !== null && _a !== void 0 ? _a : Buffer.from(JSON.stringify(req.body));
        if (!webhookSec) {
            console.error("❌ STRIPE_WEBHOOK_SECRET no configurada");
            res.status(500).json({ error: "Webhook no configurado" });
            return;
        }
        if (!sig) {
            res.status(400).json({ error: "Firma de Stripe ausente" });
            return;
        }
        try {
            event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
        }
        catch (err) {
            console.error("❌ Firma Stripe inválida:", err);
            res.status(400).json({ error: "Firma inválida" });
            return;
        }
    }
    catch (err) {
        console.error("❌ Error verificando firma Stripe:", err);
        res.status(400).json({ error: `Webhook signature verification failed: ${err}` });
        return;
    }
    console.log(`📥 Stripe evento recibido: ${event.type} [${event.id}]`);
    // ── IDEMPOTENCIA: evitar procesar el mismo evento dos veces ──────────────
    // Stripe puede reenviar eventos ante timeouts o fallos de red.
    const eventDocRef = db.collection("stripe_processed_events").doc(event.id);
    const eventDoc = await eventDocRef.get();
    if (eventDoc.exists) {
        console.log(`⏭️ Evento Stripe ${event.id} ya procesado. Ignorando duplicado.`);
        res.status(200).json({ received: true, skipped: true, reason: "already_processed" });
        return;
    }
    // Marcar como procesado ANTES de ejecutar la lógica (evita race conditions)
    await eventDocRef.set({
        event_id: event.id,
        event_type: event.type,
        processed_at: new Date().toISOString(),
    });
    try {
        switch (event.type) {
            case "checkout.session.completed": {
                const session = event.data.object;
                await _procesarCheckoutCompletado(session, db);
                break;
            }
            case "payment_intent.succeeded": {
                const pi = event.data.object;
                if ((_b = pi.metadata) === null || _b === void 0 ? void 0 : _b.empresa_id) {
                    await _procesarPaymentIntentExitoso(pi, db);
                }
                break;
            }
            case "invoice.paid": {
                // Renovación de suscripción pagada — marcar empresa como activa
                const invoice = event.data.object;
                await _procesarInvoicePagado(invoice, db);
                break;
            }
            case "customer.subscription.deleted": {
                // Suscripción cancelada o impagada — desactivar empresa
                const subscription = event.data.object;
                await _procesarSuscripcionCancelada(subscription, db);
                break;
            }
            case "customer.subscription.updated": {
                // Cambio de plan, renovación, etc.
                const subscription = event.data.object;
                await _procesarSuscripcionActualizada(subscription, db);
                break;
            }
            default:
                console.log(`ℹ️ Evento Stripe ignorado: ${event.type}`);
        }
        res.status(200).json({ received: true, tipo: event.type });
    }
    catch (error) {
        console.error(`❌ Error procesando evento Stripe ${event.type}:`, error);
        res.status(500).json({ error: "Error interno procesando evento" });
    }
});
// ── ENVÍO DE EMAIL CON PDF ADJUNTO (v2 onCall) ───────────────────────────────
/**
 * 12. ENVIAR EMAIL — Envía factura/nómina en PDF por email
 *
 * CONFIGURACIÓN REQUERIDA:
 *   RESEND_API_KEY en functions/.env
 *   Dominio verificado en https://resend.com/domains
 */
exports.enviarEmailConPdf = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a;
    const { destinatario, asunto, cuerpoHtml, pdfBase64, nombreArchivo, empresaId } = request.data;
    if (empresaId) {
        await (0, authGuard_1.verificarAuthYEmpresa)(request, empresaId);
    }
    else {
        (0, authGuard_1.verificarAuth)(request);
    }
    if (!destinatario || !asunto || !pdfBase64) {
        throw new https_1.HttpsError("invalid-argument", "destinatario, asunto y pdfBase64 son requeridos");
    }
    // Obtener nombre de empresa para el remitente
    let nombreEmpresa = "Fluix CRM";
    if (empresaId) {
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        if (empresaDoc.exists) {
            nombreEmpresa = ((_a = empresaDoc.data()) === null || _a === void 0 ? void 0 : _a.nombre) || "Fluix CRM";
        }
    }
    const resultado = await (0, resend_service_1.enviarPdfGenerico)({
        from: `${nombreEmpresa} <noreply@fluixtech.com>`,
        to: destinatario,
        subject: asunto,
        html: cuerpoHtml || `<p style="font-family:Arial,sans-serif;">Adjuntamos el documento solicitado.</p><p>— ${nombreEmpresa}</p>`,
        pdf: Buffer.from(pdfBase64, "base64"),
        nombreArchivo: nombreArchivo || "documento.pdf",
    });
    if (!resultado.exito) {
        throw new https_1.HttpsError("internal", `Error enviando email: ${resultado.error}`);
    }
    console.log(`✅ Email enviado a ${destinatario} — ${asunto}`);
    return { exito: true, mensaje: `Email enviado a ${destinatario}` };
});
// ── FUNCIONES HELPER STRIPE ───────────────────────────────────────────────────
async function _procesarCheckoutCompletado(session, db) {
    var _a, _b, _c, _d, _e, _f;
    const empresaClienteId = ((_a = session.metadata) === null || _a === void 0 ? void 0 : _a.empresa_id) || "";
    const paquete = ((_b = session.metadata) === null || _b === void 0 ? void 0 : _b.paquete) || "Paquete Fluix";
    const FLUIXTECH_ID = "fluixtech";
    const clienteNombre = ((_c = session.customer_details) === null || _c === void 0 ? void 0 : _c.name) || "Cliente Web";
    const clienteEmail = ((_d = session.customer_details) === null || _d === void 0 ? void 0 : _d.email) || null;
    const clienteTelefono = ((_e = session.customer_details) === null || _e === void 0 ? void 0 : _e.phone) || null;
    const totalEuros = ((_f = session.amount_total) !== null && _f !== void 0 ? _f : 0) / 100;
    const baseImponible = parseFloat((totalEuros / 1.21).toFixed(2));
    const importeIva = parseFloat((totalEuros - baseImponible).toFixed(2));
    const lineasIngreso = [
        {
            producto_nombre: paquete,
            descripcion: `${paquete} — Pago online vía Stripe`,
            cantidad: 1,
            precio_unitario: baseImponible,
            porcentaje_iva: 21,
            referencia: session.id,
        },
    ];
    const pedidoFluixtech = {
        empresa_id: FLUIXTECH_ID,
        cliente_nombre: clienteNombre,
        cliente_correo: clienteEmail,
        cliente_telefono: clienteTelefono,
        empresa_cliente_id: empresaClienteId || null,
        origen: "web",
        estado: "confirmado",
        estado_pago: "pagado",
        metodo_pago: "tarjeta",
        lineas: lineasIngreso,
        subtotal: baseImponible,
        total: totalEuros,
        notas_cliente: `Venta de "${paquete}" a ${clienteNombre}. Stripe Session: ${session.id}`,
        stripe_session_id: session.id,
        stripe_payment_intent: session.payment_intent,
        fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    const pedidoRef = await db
        .collection("empresas")
        .doc(FLUIXTECH_ID)
        .collection("pedidos")
        .add(pedidoFluixtech);
    console.log(`✅ [INGRESO] Pedido ${pedidoRef.id} creado en fluixtech — ${clienteNombre} — €${totalEuros}`);
    console.log(`   ➡️  Factura de ingreso se generará automáticamente via onNuevoPedidoGenerarFactura`);
    if (empresaClienteId && empresaClienteId !== FLUIXTECH_ID) {
        const configRef = db
            .collection("empresas")
            .doc(FLUIXTECH_ID)
            .collection("configuracion")
            .doc("facturacion");
        let numeroFactura = "";
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const snap = await tx.get(configRef);
            // NOTA: onNuevoPedidoGenerarFactura incrementará este contador más tarde.
            // Aquí solo leemos el valor ACTUAL + 1 para que el numero_factura_proveedor
            // coincida con la factura que se generará automáticamente.
            const contador = ((_b = (_a = snap.data()) === null || _a === void 0 ? void 0 : _a.ultimo_numero_factura) !== null && _b !== void 0 ? _b : 0) + 1;
            const anio = new Date().getFullYear();
            numeroFactura = `FAC-${anio}-${String(contador).padStart(4, "0")}`;
        });
        const gastoData = {
            empresa_id: empresaClienteId,
            concepto: `Suscripción Fluix CRM — ${paquete}`,
            categoria: "software",
            proveedor_nombre: "FluxTech",
            proveedor_id: null,
            numero_factura_proveedor: numeroFactura || `STRIPE-${session.id.substring(3, 11).toUpperCase()}`,
            stripe_session_id: session.id,
            base_imponible: baseImponible,
            porcentaje_iva: 21,
            importe_iva: importeIva,
            total: totalEuros,
            iva_deducible: true,
            estado: "pagado",
            fecha_gasto: admin.firestore.FieldValue.serverTimestamp(),
            fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
            metodo_pago: "tarjeta",
            notas: `Pago automático vía Stripe. Paquete: "${paquete}". Proveedor: FluxTech (fluixtech.com)`,
            creado_por: "sistema_stripe",
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        };
        const gastoRef = await db
            .collection("empresas")
            .doc(empresaClienteId)
            .collection("gastos")
            .add(gastoData);
        const ahora = new Date();
        const cacheId = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;
        await db
            .collection("empresas")
            .doc(empresaClienteId)
            .collection("cache_contable")
            .doc(cacheId)
            .set({
            gastos_base: admin.firestore.FieldValue.increment(baseImponible),
            gastos_iva_soportado: admin.firestore.FieldValue.increment(importeIva),
            gastos_total: admin.firestore.FieldValue.increment(totalEuros),
            num_gastos: admin.firestore.FieldValue.increment(1),
            ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`✅ [GASTO] Gasto ${gastoRef.id} creado en empresa "${empresaClienteId}" — €${totalEuros} — "${paquete}"`);
    }
    else if (!empresaClienteId) {
        console.log(`ℹ️  Sin empresa_id en metadata de Stripe → no se crea gasto en empresa cliente`);
    }
}
async function _procesarPaymentIntentExitoso(pi, db) {
    var _a, _b, _c;
    const empresaClienteId = ((_a = pi.metadata) === null || _a === void 0 ? void 0 : _a.empresa_id) || "";
    const paquete = ((_b = pi.metadata) === null || _b === void 0 ? void 0 : _b.paquete) || "Pago directo Stripe";
    const FLUIXTECH_ID = "fluixtech";
    const totalEuros = pi.amount / 100;
    const baseImponible = parseFloat((totalEuros / 1.21).toFixed(2));
    const importeIva = parseFloat((totalEuros - baseImponible).toFixed(2));
    const pedidoData = {
        empresa_id: FLUIXTECH_ID,
        cliente_nombre: ((_c = pi.metadata) === null || _c === void 0 ? void 0 : _c.cliente_nombre) || "Cliente",
        cliente_correo: pi.receipt_email || null,
        empresa_cliente_id: empresaClienteId || null,
        origen: "web",
        estado: "confirmado",
        estado_pago: "pagado",
        metodo_pago: "tarjeta",
        lineas: [
            {
                producto_nombre: paquete,
                cantidad: 1,
                precio_unitario: baseImponible,
                porcentaje_iva: 21,
                referencia: pi.id,
            },
        ],
        subtotal: baseImponible,
        total: totalEuros,
        notas_cliente: `Pago directo Stripe. PaymentIntent: ${pi.id}`,
        stripe_payment_intent: pi.id,
        fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    const pedidoRef = await db
        .collection("empresas")
        .doc(FLUIXTECH_ID)
        .collection("pedidos")
        .add(pedidoData);
    console.log(`✅ [INGRESO] Pedido ${pedidoRef.id} creado en fluixtech via PaymentIntent — €${totalEuros}`);
    if (empresaClienteId && empresaClienteId !== FLUIXTECH_ID) {
        const gastoData = {
            empresa_id: empresaClienteId,
            concepto: `Suscripción Fluix CRM — ${paquete}`,
            categoria: "software",
            proveedor_nombre: "FluxTech",
            proveedor_id: null,
            numero_factura_proveedor: `STRIPE-${pi.id.substring(3, 11).toUpperCase()}`,
            stripe_payment_intent: pi.id,
            base_imponible: baseImponible,
            porcentaje_iva: 21,
            importe_iva: importeIva,
            total: totalEuros,
            iva_deducible: true,
            estado: "pagado",
            fecha_gasto: admin.firestore.FieldValue.serverTimestamp(),
            fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
            metodo_pago: "tarjeta",
            notas: `Pago automático vía Stripe. Paquete: "${paquete}". PaymentIntent: ${pi.id}`,
            creado_por: "sistema_stripe",
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        };
        const gastoRef = await db
            .collection("empresas")
            .doc(empresaClienteId)
            .collection("gastos")
            .add(gastoData);
        const ahora = new Date();
        const cacheId = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;
        await db
            .collection("empresas")
            .doc(empresaClienteId)
            .collection("cache_contable")
            .doc(cacheId)
            .set({
            gastos_base: admin.firestore.FieldValue.increment(baseImponible),
            gastos_iva_soportado: admin.firestore.FieldValue.increment(importeIva),
            gastos_total: admin.firestore.FieldValue.increment(totalEuros),
            num_gastos: admin.firestore.FieldValue.increment(1),
            ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`✅ [GASTO] Gasto ${gastoRef.id} creado en empresa "${empresaClienteId}" — €${totalEuros}`);
    }
}
// ── HELPERS STRIPE: SUSCRIPCIONES ────────────────────────────────────────────
/**
 * invoice.paid — Se dispara en cada renovación de suscripción pagada con éxito.
 * Actualiza la empresa en Firestore como activa y registra la fecha de próximo vencimiento.
 */
async function _procesarInvoicePagado(invoice, db) {
    var _a, _b, _c, _d, _e, _f;
    const customerId = invoice.customer;
    if (!customerId)
        return;
    // Buscar empresa por stripe_customer_id
    const snap = await db
        .collectionGroup("empresas")
        .where("stripe_customer_id", "==", customerId)
        .limit(1)
        .get();
    // Si no está en collectionGroup, buscar en raíz
    const rootSnap = snap.empty
        ? await db.collection("empresas").where("stripe_customer_id", "==", customerId).limit(1).get()
        : snap;
    if (rootSnap.empty) {
        console.warn(`⚠️ invoice.paid: No se encontró empresa con stripe_customer_id=${customerId}`);
        return;
    }
    const empresaRef = rootSnap.docs[0].ref;
    const empresaId = rootSnap.docs[0].id;
    const periodEnd = (_d = (_c = (_b = (_a = invoice.lines) === null || _a === void 0 ? void 0 : _a.data) === null || _b === void 0 ? void 0 : _b[0]) === null || _c === void 0 ? void 0 : _c.period) === null || _d === void 0 ? void 0 : _d.end;
    const proximoVencimiento = periodEnd
        ? admin.firestore.Timestamp.fromDate(new Date(periodEnd * 1000))
        : null;
    await empresaRef.update({
        suscripcion_activa: true,
        suscripcion_estado: "active",
        suscripcion_proximo_pago: proximoVencimiento,
        suscripcion_ultima_factura_stripe: invoice.id,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ [SUSCRIPCIÓN] invoice.paid — empresa ${empresaId} renovada hasta ${(_f = (_e = proximoVencimiento === null || proximoVencimiento === void 0 ? void 0 : proximoVencimiento.toDate()) === null || _e === void 0 ? void 0 : _e.toISOString()) !== null && _f !== void 0 ? _f : "—"}`);
}
/**
 * customer.subscription.deleted — Suscripción cancelada por impago o por el usuario.
 * Marca la empresa como inactiva en Firestore.
 */
async function _procesarSuscripcionCancelada(subscription, db) {
    const customerId = subscription.customer;
    if (!customerId)
        return;
    const snap = await db
        .collection("empresas")
        .where("stripe_customer_id", "==", customerId)
        .limit(1)
        .get();
    if (snap.empty) {
        console.warn(`⚠️ subscription.deleted: No se encontró empresa con stripe_customer_id=${customerId}`);
        return;
    }
    const empresaRef = snap.docs[0].ref;
    const empresaId = snap.docs[0].id;
    await empresaRef.update({
        suscripcion_activa: false,
        suscripcion_estado: "canceled",
        suscripcion_cancelada_en: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`🔴 [SUSCRIPCIÓN] subscription.deleted — empresa ${empresaId} DESACTIVADA`);
}
/**
 * customer.subscription.updated — Cambio de plan, pausa, renovación automática.
 * Sincroniza el estado de la suscripción con Firestore.
 */
async function _procesarSuscripcionActualizada(subscription, db) {
    const customerId = subscription.customer;
    if (!customerId)
        return;
    const snap = await db
        .collection("empresas")
        .where("stripe_customer_id", "==", customerId)
        .limit(1)
        .get();
    if (snap.empty)
        return;
    const empresaRef = snap.docs[0].ref;
    const empresaId = snap.docs[0].id;
    const estado = subscription.status; // "active" | "past_due" | "canceled" | "trialing" | etc.
    await empresaRef.update({
        suscripcion_activa: estado === "active" || estado === "trialing",
        suscripcion_estado: estado,
        suscripcion_proximo_pago: subscription.current_period_end
            ? admin.firestore.Timestamp.fromDate(new Date(subscription.current_period_end * 1000))
            : null,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`🔄 [SUSCRIPCIÓN] subscription.updated — empresa ${empresaId} estado=${estado}`);
}
// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRAR VISITA WEB — endpoint HTTP llamado desde el script embebido
// ═══════════════════════════════════════════════════════════════════════════════
exports.registrarVisita = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).json({ error: "Método no permitido" });
            return;
        }
        const { empresaId, dominio, pagina, referrer } = req.body;
        if (!empresaId || typeof empresaId !== "string") {
            res.status(400).json({ error: "empresaId es requerido" });
            return;
        }
        const ahora = new Date();
        const fechaHoy = ahora.toISOString().substring(0, 10);
        const hora = ahora.getHours();
        const paginaActual = pagina || "/";
        const referrerActual = referrer || "directo";
        const dominioActual = dominio || "desconocido";
        // 1. Actualizar resumen general
        await db
            .collection('empresas').doc(empresaId)
            .collection('estadisticas').doc('web_resumen')
            .set({
            visitas_totales: admin.firestore.FieldValue.increment(1),
            visitas_mes: admin.firestore.FieldValue.increment(1),
            ultima_visita: admin.firestore.FieldValue.serverTimestamp(),
            sitio_web: dominioActual,
            pagina_actual: paginaActual,
            referrer_actual: referrerActual,
        }, { merge: true });
        // 2. Actualizar estadísticas del día
        await db
            .collection('empresas').doc(empresaId)
            .collection('estadisticas').doc(`visitas_${fechaHoy}`)
            .set({
            fecha: fechaHoy,
            sitio: dominioActual,
            visitas: admin.firestore.FieldValue.increment(1),
            paginas_vistas: admin.firestore.FieldValue.arrayUnion(paginaActual),
            referrers: admin.firestore.FieldValue.arrayUnion(referrerActual),
            [`visitas_hora_${hora}`]: admin.firestore.FieldValue.increment(1),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`✅ Visita registrada: ${empresaId} — ${dominioActual} — ${fechaHoy}`);
        res.status(200).json({ ok: true });
    }
    catch (error) {
        console.error("❌ Error registrando visita:", error);
        res.status(500).json({ error: "Error registrando visita" });
    }
});
// ── VERIFACTU: Firma XAdES + Remisión AEAT ──────────────────────────────────
var firmarXMLVerifactu_1 = require("./firmarXMLVerifactu");
Object.defineProperty(exports, "firmarXMLVerifactu", { enumerable: true, get: function () { return firmarXMLVerifactu_1.firmarXMLVerifactu; } });
var remitirVerifactu_1 = require("./remitirVerifactu");
Object.defineProperty(exports, "remitirVerifactu", { enumerable: true, get: function () { return remitirVerifactu_1.remitirVerifactu; } });
// ── GESTIÓN DE CUENTAS Y SUSCRIPCIONES (sin pasar por Apple/Google) ──────────
var gestionCuentas_1 = require("./gestionCuentas");
Object.defineProperty(exports, "crearCuentaConPlan", { enumerable: true, get: function () { return gestionCuentas_1.crearCuentaConPlan; } });
Object.defineProperty(exports, "actualizarPlanEmpresa", { enumerable: true, get: function () { return gestionCuentas_1.actualizarPlanEmpresa; } });
Object.defineProperty(exports, "listarCuentasClientes", { enumerable: true, get: function () { return gestionCuentas_1.listarCuentasClientes; } });
Object.defineProperty(exports, "webhookPagoWeb", { enumerable: true, get: function () { return gestionCuentas_1.webhookPagoWeb; } });
// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO DE VACACIONES — Cloud Functions
// ═══════════════════════════════════════════════════════════════════════════════
/**
 * Importar festivos de España desde la API Nager.Date.
 * onCall: { anio: number, empresaId: string, codigoComunidad?: string }
 */
exports.importarFestivosEspana = (0, https_1.onCall)({ region: REGION }, async (request) => {
    // ── AUTH GUARD — Solo admin de la plataforma Fluix ──
    await (0, authGuard_1.verificarPropietarioPlataforma)(request);
    const { anio, empresaId, codigoComunidad } = request.data;
    if (!anio || !empresaId) {
        throw new https_1.HttpsError("invalid-argument", "Se requiere anio y empresaId");
    }
    const url = `https://date.nager.at/api/v3/PublicHolidays/${anio}/ES`;
    console.log(`📅 Importando festivos de ${url} para empresa ${empresaId}`);
    try {
        const response = await (0, node_fetch_1.default)(url);
        if (!response.ok) {
            throw new https_1.HttpsError("unavailable", `API retornó ${response.status}`);
        }
        const holidays = await response.json();
        const batch = db.batch();
        let count = 0;
        for (const h of holidays) {
            const isGlobal = h.global === true || !h.counties || h.counties.length === 0;
            const matchesComunidad = codigoComunidad && h.counties && h.counties.includes(codigoComunidad);
            if (isGlobal || matchesComunidad) {
                const date = h.date; // "2026-01-01"
                const ref = db
                    .collection("empresas")
                    .doc(empresaId)
                    .collection("festivos")
                    .doc(`${anio}`)
                    .collection("dias")
                    .doc(date);
                batch.set(ref, {
                    fecha: admin.firestore.Timestamp.fromDate(new Date(date + "T00:00:00")),
                    nombre: h.localName || h.name || "",
                    tipo: isGlobal ? "nacional" : "autonomico",
                    codigo_comunidad: isGlobal ? null : codigoComunidad,
                    es_local: false,
                });
                count++;
            }
        }
        // Metadata
        batch.set(db.collection("empresas").doc(empresaId).collection("festivos").doc(`${anio}`), {
            anio,
            comunidad_autonoma: codigoComunidad || null,
            total_festivos: count,
            importado_desde: "nager.date",
            fecha_importacion: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await batch.commit();
        console.log(`✅ ${count} festivos importados para ${anio}`);
        return { count, anio };
    }
    catch (error) {
        console.error("❌ Error importando festivos:", error);
        throw new https_1.HttpsError("internal", `Error: ${error}`);
    }
});
/**
 * Trigger: cuando cambia el estado de una solicitud de vacaciones.
 * Envía notificación push al empleado afectado.
 */
exports.onVacacionEstadoCambiado = (0, firestore_1.onDocumentUpdated)({ document: "vacaciones/{empresaId}/solicitudes/{solicitudId}", region: REGION }, async (event) => {
    var _a, _b, _c, _d, _e;
    const empresaId = event.params.empresaId;
    const solicitudId = event.params.solicitudId;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    // Solo nos interesa cuando cambia el estado
    if (antes.estado === despues.estado)
        return;
    const nuevoEstado = despues.estado;
    if (nuevoEstado !== "aprobado" && nuevoEstado !== "rechazado")
        return;
    const empleadoId = despues.empleado_id;
    if (!empleadoId)
        return;
    // Formatear fechas
    const fechaInicio = ((_c = despues.fecha_inicio) === null || _c === void 0 ? void 0 : _c.toDate)
        ? despues.fecha_inicio.toDate().toLocaleDateString("es-ES")
        : "—";
    const fechaFin = ((_d = despues.fecha_fin) === null || _d === void 0 ? void 0 : _d.toDate)
        ? despues.fecha_fin.toDate().toLocaleDateString("es-ES")
        : "—";
    let titulo;
    let cuerpo;
    if (nuevoEstado === "aprobado") {
        titulo = "✅ Vacaciones aprobadas";
        cuerpo = `Tus vacaciones del ${fechaInicio} al ${fechaFin} han sido aprobadas`;
    }
    else {
        titulo = "❌ Vacaciones rechazadas";
        cuerpo = `Tu solicitud de vacaciones del ${fechaInicio} al ${fechaFin} ha sido rechazada`;
        const motivo = despues.motivo_rechazo;
        if (motivo) {
            cuerpo += `\nMotivo: ${motivo}`;
        }
    }
    // Obtener token del empleado
    const empleadoDoc = await db.collection("usuarios").doc(empleadoId).get();
    const tokenFCM = (_e = empleadoDoc.data()) === null || _e === void 0 ? void 0 : _e.token_dispositivo;
    // Guardar en bandeja de notificaciones in-app
    await db
        .collection("notificaciones")
        .doc(empresaId)
        .collection("items")
        .add({
        titulo,
        cuerpo,
        tipo: "vacacion_estado",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "vacaciones",
        entidad_id: solicitudId,
        empleado_id: empleadoId,
    });
    // Enviar push si tiene token
    if (tokenFCM) {
        try {
            await messaging.send({
                token: tokenFCM,
                notification: { title: titulo, body: cuerpo },
                data: {
                    tipo: "vacacion_estado",
                    empresa_id: empresaId,
                    solicitud_id: solicitudId,
                    estado: nuevoEstado,
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "fluixcrm_canal_principal",
                        sound: "default",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            });
            console.log(`✅ Push enviado a empleado ${empleadoId} — ${nuevoEstado}`);
        }
        catch (pushError) {
            console.warn(`⚠️ No se pudo enviar push a ${empleadoId}:`, pushError.message);
            // Si el token es inválido, marcarlo
            if (pushError.code === "messaging/registration-token-not-registered" ||
                pushError.code === "messaging/invalid-registration-token") {
                await db.collection("usuarios").doc(empleadoId).update({
                    token_dispositivo: admin.firestore.FieldValue.delete(),
                });
            }
        }
    }
    else {
        console.log(`ℹ️ Empleado ${empleadoId} sin token FCM, notificación guardada solo in-app`);
    }
});
/**
 * Cierre anual de vacaciones: 31 de diciembre a las 23:59 UTC.
 * Calcula días sobrantes y crea arrastre para el año nuevo.
 */
exports.scheduledCierreAnualVacaciones = (0, scheduler_1.onSchedule)({ schedule: "59 23 31 12 *", timeZone: "Europe/Madrid", region: REGION }, async () => {
    var _a, _b, _c, _d;
    const anio = new Date().getFullYear();
    console.log(`📅 Cierre anual de vacaciones ${anio}`);
    // Obtener todas las empresas
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        // Leer configuración de carryover
        const configDoc = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("configuracion")
            .doc("vacaciones")
            .get();
        const carryover = ((_a = configDoc.data()) === null || _a === void 0 ? void 0 : _a.carryover) || {};
        const diasMaximos = (_b = carryover.dias_maximos_traspasar) !== null && _b !== void 0 ? _b : 5;
        const mesExp = (_c = carryover.mes_expiracion) !== null && _c !== void 0 ? _c : 3;
        const diaExp = (_d = carryover.dia_expiracion) !== null && _d !== void 0 ? _d : 31;
        // Obtener saldos del año actual
        const saldosSnap = await db
            .collection("vacaciones")
            .doc(empresaId)
            .collection("saldos")
            .where("anio", "==", anio)
            .get();
        const batch = db.batch();
        for (const saldoDoc of saldosSnap.docs) {
            const saldo = saldoDoc.data();
            const empleadoId = saldo.empleado_id;
            const pendientes = (saldo.dias_devengados || 0) - (saldo.dias_disfrutados || 0);
            const diasATraspasar = Math.min(Math.max(pendientes, 0), diasMaximos);
            if (diasATraspasar > 0) {
                // Crear/actualizar saldo del año siguiente con arrastre
                const nuevoAnio = anio + 1;
                const docId = `${empleadoId}_${nuevoAnio}`;
                const ref = db
                    .collection("vacaciones")
                    .doc(empresaId)
                    .collection("saldos")
                    .doc(docId);
                batch.set(ref, {
                    empleado_id: empleadoId,
                    anio: nuevoAnio,
                    dias_arrastre: diasATraspasar,
                    dias_arrastre_consumidos: 0,
                    dias_pendientes_ano_anterior: diasATraspasar,
                    fecha_expiracion_arrastre: admin.firestore.Timestamp.fromDate(new Date(nuevoAnio, mesExp - 1, diaExp)),
                    ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                console.log(`  → ${empleadoId}: ${diasATraspasar} días traspasados a ${nuevoAnio}`);
            }
        }
        await batch.commit();
    }
    console.log(`✅ Cierre anual completado para ${anio}`);
});
/**
 * Expiración de arrastre: por defecto 31 de marzo.
 * Elimina los días traspasados no disfrutados y notifica.
 * Se ejecuta diariamente y comprueba si hoy es la fecha de expiración.
 */
exports.scheduledExpiracionCarryover = (0, scheduler_1.onSchedule)({ schedule: "0 8 * * *", timeZone: "Europe/Madrid", region: REGION }, async () => {
    var _a, _b, _c, _d;
    const hoy = new Date();
    console.log(`📅 Verificando expiración de carryover: ${hoy.toISOString()}`);
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        const anio = hoy.getFullYear();
        // Leer configuración
        const configDoc = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("configuracion")
            .doc("vacaciones")
            .get();
        const carryover = ((_a = configDoc.data()) === null || _a === void 0 ? void 0 : _a.carryover) || {};
        const mesExp = (_b = carryover.mes_expiracion) !== null && _b !== void 0 ? _b : 3;
        const diaExp = (_c = carryover.dia_expiracion) !== null && _c !== void 0 ? _c : 31;
        const notificar7dias = carryover.notificar_antes_expirar !== false;
        const fechaExpiracion = new Date(anio, mesExp - 1, diaExp);
        const diasHastaExpiracion = Math.ceil((fechaExpiracion.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24));
        // Obtener saldos con arrastre vigente
        const saldosSnap = await db
            .collection("vacaciones")
            .doc(empresaId)
            .collection("saldos")
            .where("anio", "==", anio)
            .where("dias_arrastre", ">", 0)
            .get();
        for (const saldoDoc of saldosSnap.docs) {
            const saldo = saldoDoc.data();
            const empleadoId = saldo.empleado_id;
            const arrastre = saldo.dias_arrastre || 0;
            const consumidos = saldo.dias_arrastre_consumidos || 0;
            const restantes = arrastre - consumidos;
            if (restantes <= 0)
                continue;
            // Notificación 7 días antes
            if (notificar7dias && diasHastaExpiracion === 7) {
                const tokenDoc = await db.collection("usuarios").doc(empleadoId).get();
                const token = (_d = tokenDoc.data()) === null || _d === void 0 ? void 0 : _d.token_dispositivo;
                // In-app notification
                await db.collection("notificaciones").doc(empresaId).collection("items").add({
                    titulo: "⏰ Días traspasados por expirar",
                    cuerpo: `Tienes ${restantes.toFixed(1)} días de vacaciones traspasados que expiran el ${diaExp}/${mesExp}/${anio}`,
                    tipo: "vacacion_carryover_expira",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    leida: false,
                    modulo_destino: "vacaciones",
                    empleado_id: empleadoId,
                });
                if (token) {
                    try {
                        await messaging.send({
                            token,
                            notification: {
                                title: "⏰ Días traspasados por expirar",
                                body: `Tienes ${restantes.toFixed(1)} días de vacaciones que expiran en 7 días`,
                            },
                            data: {
                                tipo: "vacacion_carryover_expira",
                                empresa_id: empresaId,
                            },
                        });
                    }
                    catch (_) { /* silenciar */ }
                }
            }
            // Expiración el día exacto
            if (diasHastaExpiracion <= 0) {
                await saldoDoc.ref.update({
                    dias_arrastre: 0,
                    dias_arrastre_consumidos: 0,
                    dias_pendientes_ano_anterior: 0,
                    ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
                });
                // Notificar al empleado
                await db.collection("notificaciones").doc(empresaId).collection("items").add({
                    titulo: "📅 Días traspasados expirados",
                    cuerpo: `Se han eliminado ${restantes.toFixed(1)} días de vacaciones traspasados no disfrutados`,
                    tipo: "vacacion_carryover_expirado",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    leida: false,
                    modulo_destino: "vacaciones",
                    empleado_id: empleadoId,
                });
                console.log(`  → ${empleadoId}: ${restantes} días expirados en empresa ${empresaId}`);
            }
        }
    }
    console.log("✅ Verificación de expiración completada");
});
/**
 * Alerta de cobertura: se ejecuta diariamente y revisa los próximos 7 días.
 * Envía push al propietario si hay días con cobertura crítica (<mínimo).
 */
exports.scheduledAlertaCobertura = (0, scheduler_1.onSchedule)({ schedule: "0 7 * * *", timeZone: "Europe/Madrid", region: REGION }, async () => {
    var _a, _b, _c, _d, _e, _f;
    console.log("📅 Verificando cobertura de equipos");
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        // Leer mínimo
        const configDoc = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("configuracion")
            .doc("vacaciones")
            .get();
        const minimoPorcentaje = (_b = (_a = configDoc.data()) === null || _a === void 0 ? void 0 : _a.minimo_cobertura_porcentaje) !== null && _b !== void 0 ? _b : 50;
        // Total empleados
        const empSnap = await db
            .collection("usuarios")
            .where("empresa_id", "==", empresaId)
            .where("activo", "==", true)
            .get();
        const totalEmpleados = empSnap.docs.length;
        if (totalEmpleados === 0)
            continue;
        // Solicitudes aprobadas
        const solSnap = await db
            .collection("vacaciones")
            .doc(empresaId)
            .collection("solicitudes")
            .where("estado", "==", "aprobado")
            .get();
        const hoy = new Date();
        const diasCriticos = [];
        for (let i = 0; i < 7; i++) {
            const dia = new Date(hoy);
            dia.setDate(hoy.getDate() + i);
            if (dia.getDay() === 0 || dia.getDay() === 6)
                continue; // Skip weekends
            const ausentes = new Set();
            for (const doc of solSnap.docs) {
                const data = doc.data();
                const ini = ((_d = (_c = data.fecha_inicio) === null || _c === void 0 ? void 0 : _c.toDate) === null || _d === void 0 ? void 0 : _d.call(_c)) || new Date(0);
                const fin = ((_f = (_e = data.fecha_fin) === null || _e === void 0 ? void 0 : _e.toDate) === null || _f === void 0 ? void 0 : _f.call(_e)) || new Date(0);
                if (dia >= ini && dia <= fin) {
                    ausentes.add(data.empleado_id);
                }
            }
            const presentes = totalEmpleados - ausentes.size;
            const porcentaje = (presentes / totalEmpleados) * 100;
            if (porcentaje < minimoPorcentaje) {
                diasCriticos.push(`${dia.getDate()}/${dia.getMonth() + 1} (${presentes}/${totalEmpleados})`);
            }
        }
        if (diasCriticos.length > 0) {
            const mensaje = `⚠️ Cobertura crítica en los próximos 7 días:\n${diasCriticos.join(", ")}`;
            // Enviar a todos los dispositivos de la empresa (propietarios)
            await enviarNotificacionEmpresa(empresaId, "⚠️ Alerta de cobertura", mensaje, { tipo: "alerta_cobertura" });
            console.log(`⚠️ Empresa ${empresaId}: ${diasCriticos.length} días críticos`);
        }
    }
    console.log("✅ Verificación de cobertura completada");
});
// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO DE FINIQUITOS — Cloud Functions
// ═════════════════════════════════════════════════════════════════════════════
const https = __importStar(require("https"));
const http = __importStar(require("http"));
/**
 * Descarga un archivo desde una URL (Firebase Storage URL firmada).
 */
async function descargarArchivo(url) {
    return new Promise((resolve, reject) => {
        const lib = url.startsWith("https") ? https : http;
        lib.get(url, (res) => {
            const chunks = [];
            res.on("data", (chunk) => chunks.push(chunk));
            res.on("end", () => resolve(Buffer.concat(chunks)));
            res.on("error", reject);
        }).on("error", reject);
    });
}
/**
 * Cloud Function: enviar documentación del finiquito al empleado por email.
 * onCall: { finiquitoId, empresaId, emailDestino, documentos: string[] }
 * documentos puede incluir: 'finiquito', 'carta_cese', 'certificado_sepe', 'ultima_nomina'
 */
exports.enviarDocumentacionFiniquito = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c;
    const { finiquitoId, empresaId, emailDestino, documentos } = request.data;
    // ── AUTH GUARD ──
    await (0, authGuard_1.verificarAuthYEmpresa)(request, empresaId);
    if (!finiquitoId || !empresaId || !emailDestino) {
        throw new https_1.HttpsError("invalid-argument", "Se requiere finiquitoId, empresaId y emailDestino");
    }
    // Validar email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(emailDestino)) {
        throw new https_1.HttpsError("invalid-argument", "Email inválido");
    }
    // Obtener finiquito
    const finiqDoc = await db
        .collection("empresas").doc(empresaId)
        .collection("finiquitos").doc(finiquitoId).get();
    if (!finiqDoc.exists) {
        throw new https_1.HttpsError("not-found", "Finiquito no encontrado");
    }
    const finiq = finiqDoc.data();
    const nombreEmpleado = (_a = finiq.empleado_nombre) !== null && _a !== void 0 ? _a : "Empleado";
    // Obtener nombre de empresa
    const empDoc = await db.collection("empresas").doc(empresaId).get();
    const nombreEmpresa = (_c = (_b = empDoc.data()) === null || _b === void 0 ? void 0 : _b.nombre) !== null && _c !== void 0 ? _c : "La empresa";
    // Construir adjuntos
    const adjuntos = [];
    const documentosSeleccionados = Array.isArray(documentos)
        ? documentos
        : ["finiquito", "carta_cese", "certificado_sepe"];
    const urlMap = {
        finiquito: { field: "pdf_firmado_url", nombre: `finiquito_${nombreEmpleado}.pdf` },
        carta_cese: { field: "carta_cese_url", nombre: `carta_cese_${nombreEmpleado}.pdf` },
        certificado_sepe: { field: "certificado_sepe_url", nombre: `certificado_empresa_SEPE_${nombreEmpleado}.pdf` },
    };
    const erroresDescarga = [];
    for (const doc of documentosSeleccionados) {
        const info = urlMap[doc];
        if (!info)
            continue;
        const url = finiq[info.field];
        if (!url) {
            console.warn(`⚠️ ${doc} no disponible`);
            erroresDescarga.push(doc);
            continue;
        }
        try {
            const buffer = await descargarArchivo(url);
            adjuntos.push({
                filename: info.nombre,
                content: buffer,
                contentType: "application/pdf",
            });
        }
        catch (e) {
            console.error(`❌ Error descargando ${doc}:`, e);
            erroresDescarga.push(doc);
        }
    }
    if (adjuntos.length === 0) {
        throw new https_1.HttpsError("internal", "No se pudo preparar ningún documento. Genera los PDFs primero.");
    }
    // Template HTML del email
    const htmlEmail = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="font-family: Arial, sans-serif; background:#f5f5f5; margin:0; padding:20px;">
  <div style="max-width:600px; margin:0 auto; background:white; border-radius:12px; overflow:hidden; box-shadow:0 2px 8px rgba(0,0,0,0.1);">
    <div style="background:#1a237e; padding:24px; text-align:center;">
      <h1 style="color:white; margin:0; font-size:20px;">Documentación de su cese</h1>
      <p style="color:#9fa8da; margin:8px 0 0;">${nombreEmpresa}</p>
    </div>
    <div style="padding:32px;">
      <p style="font-size:16px; color:#333;">Estimado/a <strong>${nombreEmpleado}</strong>,</p>
      <p style="color:#555; line-height:1.6;">
        Le remitimos la documentación relacionada con la extinción de su contrato de trabajo.
        Le recomendamos que guarde estos documentos en un lugar seguro, ya que pueden ser
        necesarios para realizar trámites en el SEPE y otros organismos.
      </p>
      <div style="background:#f8f9ff; border-left:4px solid #3949ab; padding:16px; margin:20px 0; border-radius:0 8px 8px 0;">
        <p style="margin:0 0 12px; font-weight:bold; color:#1a237e;">Documentos adjuntos:</p>
        ${adjuntos.map(a => {
        const icon = a.filename.includes("finiquito") ? "📄" :
            a.filename.includes("carta") ? "📝" : "🏛️";
        const desc = a.filename.includes("finiquito")
            ? "Finiquito y liquidación — detalle de la liquidación económica."
            : a.filename.includes("carta")
                ? "Carta de cese — comunicación formal de extinción del contrato."
                : "Certificado de empresa (SEPE) — necesario para solicitar el paro.";
        return `<p style="margin:4px 0; color:#333;">${icon} <strong>${a.filename}</strong><br><span style="font-size:12px;color:#666;">${desc}</span></p>`;
    }).join('')}
      </div>
      <div style="background:#fff8e1; border:1px solid #ffe082; border-radius:8px; padding:16px; margin:20px 0;">
        <p style="margin:0 0 8px; font-weight:bold; color:#f57f17;">💡 Información importante</p>
        <ul style="margin:0; padding-left:16px; color:#555; font-size:13px; line-height:1.8;">
          <li>Dispone de <strong>20 días hábiles</strong> desde la fecha de cese para impugnar el despido ante el Juzgado de lo Social (si procede).</li>
          <li>Puede solicitar la prestación por desempleo en el <strong>SEPE</strong> en los 15 días siguientes a su cese.</li>
          <li>Para cualquier duda, contacte con nosotros.</li>
        </ul>
      </div>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
      <p style="color:#555; font-size:14px;">
        Si tiene alguna pregunta sobre esta documentación, no dude en ponerse en contacto con nosotros.
      </p>
      <p style="color:#333; font-size:14px;">
        Atentamente,<br>
        <strong>${nombreEmpresa}</strong>
      </p>
    </div>
    <div style="background:#f5f5f5; padding:16px; text-align:center; font-size:11px; color:#999;">
      Este email contiene información confidencial. Si lo ha recibido por error, por favor notifíquelo al remitente.
    </div>
  </div>
</body>
</html>`;
    // Enviar email con Resend
    const { Resend } = await Promise.resolve().then(() => __importStar(require("resend")));
    const resendClient = new Resend(process.env.RESEND_API_KEY);
    try {
        const { error } = await resendClient.emails.send({
            from: `${nombreEmpresa} <noreply@fluixtech.com>`,
            to: emailDestino,
            subject: `Documentación de cese — ${nombreEmpresa}`,
            html: htmlEmail,
            attachments: adjuntos.map((a) => ({
                filename: a.filename,
                content: a.content.toString("base64"),
            })),
        });
        if (error)
            throw new Error(error.message);
        // Actualizar finiquito con la fecha de envío
        await finiqDoc.ref.update({
            documentacion_enviada_a: emailDestino,
            fecha_envio_documentacion: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Documentación de finiquito enviada a ${emailDestino}`);
        return {
            exito: true,
            mensaje: `Documentación enviada a ${emailDestino}`,
            documentos_enviados: adjuntos.map(a => a.filename),
            documentos_faltantes: erroresDescarga,
        };
    }
    catch (error) {
        console.error("❌ Error enviando email:", error);
        throw new https_1.HttpsError("internal", `Error enviando email: ${error instanceof Error ? error.message : "Desconocido"}`);
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// CALENDARIO FISCAL — Alertas de vencimientos AEAT
// ═══════════════════════════════════════════════════════════════════════════
exports.alertasVencimientosFiscales = (0, scheduler_1.onSchedule)({ schedule: "0 9 * * *", timeZone: "Europe/Madrid", region: REGION }, async (_event) => {
    console.log("🗓️ Ejecutando alertas de vencimientos fiscales...");
    const hoy = new Date();
    const vencimientosProximos = _calcularVencimientos(hoy);
    if (vencimientosProximos.length === 0) {
        console.log("✅ No hay vencimientos fiscales próximos");
        return;
    }
    // Obtener empresas con Pack Fiscal activo
    const empresasSnap = await db.collection("empresas")
        .where("active_packs", "array-contains", "fiscal_ai")
        .get();
    console.log(`📊 Enviando alertas a ${empresasSnap.size} empresa(s) con Pack Fiscal`);
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        const empresaData = empresaDoc.data();
        const nombreEmpresa = empresaData.nombre || "Tu empresa";
        try {
            // Buscar tokens FCM de usuarios de la empresa
            const tokensQuery = await db
                .collection("empresas").doc(empresaId)
                .collection("usuario_tokens")
                .where("activo", "==", true)
                .get();
            const tokens = [];
            tokensQuery.forEach(doc => {
                const token = doc.data().fcm_token;
                if (token)
                    tokens.push(token);
            });
            if (tokens.length === 0) {
                console.log(`⚠️ Sin tokens FCM para empresa ${empresaId}`);
                continue;
            }
            // Preparar mensaje de alerta
            const modelo = vencimientosProximos[0]; // El más próximo
            const dias = Math.ceil((modelo.fecha.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24));
            let titulo = "📅 Vencimiento fiscal próximo";
            let mensaje = "";
            if (dias === 0) {
                titulo = "🚨 Vencimiento fiscal HOY";
                mensaje = `Modelo ${modelo.modelo} vence hoy (${_formatearFecha(modelo.fecha)})`;
            }
            else if (dias === 1) {
                titulo = "⚠️ Vencimiento fiscal MAÑANA";
                mensaje = `Modelo ${modelo.modelo} vence mañana (${_formatearFecha(modelo.fecha)})`;
            }
            else {
                mensaje = `Modelo ${modelo.modelo} vence en ${dias} días (${_formatearFecha(modelo.fecha)})`;
            }
            // Enviar notificación push
            const response = await messaging.sendMulticast({
                tokens,
                notification: { title: titulo, body: mensaje },
                data: {
                    tipo: "vencimiento_fiscal",
                    modelo: modelo.modelo,
                    fecha: modelo.fecha.toISOString(),
                    dias_restantes: dias.toString(),
                    empresa_id: empresaId,
                },
                android: {
                    notification: {
                        channelId: "fluixcrm_canal_principal",
                        priority: "high",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            alert: { title: titulo, body: mensaje },
                            badge: 1,
                            sound: "default",
                        },
                    },
                },
            });
            console.log(`✅ Alerta enviada a ${response.successCount}/${tokens.length} dispositivos - ${nombreEmpresa}`);
            // Crear notificación en Firestore para historial
            await db
                .collection("empresas").doc(empresaId)
                .collection("notificaciones")
                .add({
                titulo: titulo,
                mensaje: mensaje,
                tipo: "vencimiento_fiscal",
                modelo: modelo.modelo,
                fecha_vencimiento: admin.firestore.Timestamp.fromDate(modelo.fecha),
                dias_restantes: dias,
                created_at: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error(`❌ Error enviando alerta fiscal a empresa ${empresaId}:`, error);
        }
    }
});
function _calcularVencimientos(fechaActual) {
    const vencimientos = [];
    const anio = fechaActual.getFullYear();
    // Solo alertar si faltan 7 días o menos
    const limiteAlerta = new Date(fechaActual);
    limiteAlerta.setDate(limiteAlerta.getDate() + 7);
    // Vencimientos trimestrales - día 20 del mes siguiente
    for (let trim = 1; trim <= 4; trim++) {
        const mesVencimiento = trim * 3 + 1; // Ene=4, Abr=7, Jul=10, Oct=13
        const fecha = new Date(anio + (mesVencimiento > 12 ? 1 : 0), mesVencimiento > 12 ? mesVencimiento - 12 : mesVencimiento, 20);
        if (fecha >= fechaActual && fecha <= limiteAlerta) {
            vencimientos.push({
                modelo: "303",
                descripcion: `IVA trimestral ${trim}T/${anio}`,
                fecha: fecha,
            });
        }
    }
    // Vencimientos anuales - enero del año siguiente
    const anioSiguiente = anio + 1;
    const vencimientosAnuales = [
        { modelo: "390", fecha: new Date(anioSiguiente, 0, 30), desc: `Resumen anual IVA ${anio}` },
        { modelo: "190", fecha: new Date(anioSiguiente, 0, 31), desc: `Resumen retenciones IRPF ${anio}` },
        { modelo: "347", fecha: new Date(anioSiguiente, 1, 28), desc: `Operaciones con terceros ${anio}` },
    ];
    for (const v of vencimientosAnuales) {
        if (v.fecha >= fechaActual && v.fecha <= limiteAlerta) {
            vencimientos.push({
                modelo: v.modelo,
                descripcion: v.desc,
                fecha: v.fecha,
            });
        }
    }
    // Ordenar por fecha más próxima primero
    vencimientos.sort((a, b) => a.fecha.getTime() - b.fecha.getTime());
    return vencimientos;
}
function _formatearFecha(fecha) {
    return fecha.toLocaleDateString("es-ES", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
    });
}
// ═════════════════════════════════════════════════════════════════════════════
// BACKUP NOCTURNO AUTOMÁTICO — Datos fiscales a Cloud Storage
// Ejecuta cada noche a las 02:00 hora española
// Exporta: facturas emitidas + recibidas, gastos y libro registro IVA
// Retención: 7 años (Art. 30 Código de Comercio + Art. 70 LIVA)
// ═════════════════════════════════════════════════════════════════════════════
exports.backupDatosFiscalesNocturno = (0, scheduler_1.onSchedule)({
    schedule: "0 2 * * *",
    timeZone: "Europe/Madrid",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 540,
}, async (_event) => {
    var _a, _b, _c;
    const storage = admin.storage();
    const bucket = storage.bucket();
    const hoy = new Date();
    const fechaStr = hoy.toISOString().split("T")[0];
    const anio = hoy.getFullYear();
    const mes = String(hoy.getMonth() + 1).padStart(2, "0");
    const empresasSnap = await db.collection("empresas").get();
    let totalFacturas = 0;
    let totalGastos = 0;
    let empresasProcesadas = 0;
    for (const empDoc of empresasSnap.docs) {
        const empresaId = empDoc.id;
        const perfil = (_a = empDoc.data().perfil) !== null && _a !== void 0 ? _a : {};
        const nifEmpresa = (_b = perfil.nif) !== null && _b !== void 0 ? _b : empresaId;
        const nombreEmpresa = (_c = perfil.nombre) !== null && _c !== void 0 ? _c : empresaId;
        try {
            // ── 1. Facturas emitidas ────────────────────────────────────────────
            const facturasSnap = await db
                .collection("empresas").doc(empresaId).collection("facturas")
                .where("fecha", ">=", new Date(anio, 0, 1))
                .get();
            if (!facturasSnap.empty) {
                const csvFacturas = _buildCsvFacturasEmitidas(facturasSnap.docs);
                await bucket.file(`backups/${empresaId}/${anio}/facturas_emitidas_${fechaStr}.csv`)
                    .save(csvFacturas, {
                    contentType: "text/csv; charset=utf-8",
                    metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "facturas_emitidas" },
                });
                totalFacturas += facturasSnap.size;
            }
            // ── 2. Facturas recibidas ───────────────────────────────────────────
            const recibidasSnap = await db
                .collection("empresas").doc(empresaId).collection("facturas_recibidas")
                .where("fecha", ">=", new Date(anio, 0, 1))
                .get();
            if (!recibidasSnap.empty) {
                const csvRecibidas = _buildCsvFacturasRecibidas(recibidasSnap.docs);
                await bucket.file(`backups/${empresaId}/${anio}/facturas_recibidas_${fechaStr}.csv`)
                    .save(csvRecibidas, {
                    contentType: "text/csv; charset=utf-8",
                    metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "facturas_recibidas" },
                });
            }
            // ── 3. Gastos ───────────────────────────────────────────────────────
            const gastosSnap = await db
                .collection("empresas").doc(empresaId).collection("gastos")
                .where("fecha", ">=", new Date(anio, 0, 1))
                .get();
            if (!gastosSnap.empty) {
                const csvGastos = _buildCsvGastos(gastosSnap.docs);
                await bucket.file(`backups/${empresaId}/${anio}/gastos_${fechaStr}.csv`)
                    .save(csvGastos, {
                    contentType: "text/csv; charset=utf-8",
                    metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "gastos" },
                });
                totalGastos += gastosSnap.size;
            }
            // ── 4. Libro registro IVA trimestral (primer día del trimestre) ─────
            const mesesInicioTrimestre = [1, 4, 7, 10];
            const esInicioTrimestre = hoy.getDate() === 1 && mesesInicioTrimestre.includes(hoy.getMonth() + 1);
            if (esInicioTrimestre) {
                const mesAnterior = hoy.getMonth() === 0 ? 12 : hoy.getMonth();
                const anioLibro = hoy.getMonth() === 0 ? anio - 1 : anio;
                const trimestreNum = Math.ceil(mesAnterior / 3);
                const libroContent = await _buildLibroRegistroTrimestral(empresaId, nifEmpresa, trimestreNum, anioLibro);
                if (libroContent) {
                    await bucket
                        .file(`backups/${empresaId}/${anioLibro}/libro_IVA_${anioLibro}_T${trimestreNum}.txt`)
                        .save(libroContent, {
                        contentType: "text/plain; charset=utf-8",
                        metadata: { empresa: nombreEmpresa, nif: nifEmpresa, tipo: "libro_registro_IVA" },
                    });
                }
            }
            // ── 5. Log de ejecución ─────────────────────────────────────────────
            await db.collection("empresas").doc(empresaId)
                .collection("backups_fiscales").doc(fechaStr)
                .set({
                fecha: admin.firestore.FieldValue.serverTimestamp(),
                facturas_emitidas: facturasSnap.size,
                facturas_recibidas: recibidasSnap.size,
                gastos: gastosSnap.size,
                mes: `${anio}-${mes}`,
                estado: "completado",
            }, { merge: true });
            empresasProcesadas++;
        }
        catch (err) {
            console.error(`[Backup] Error empresa ${empresaId}:`, err);
            await db.collection("empresas").doc(empresaId)
                .collection("backups_fiscales").doc(fechaStr)
                .set({
                fecha: admin.firestore.FieldValue.serverTimestamp(),
                estado: "error",
                error: String(err),
            }, { merge: true });
        }
    }
    console.log(`[Backup Fiscal] ${empresasProcesadas} empresas · ` +
        `${totalFacturas} facturas · ${totalGastos} gastos — ${fechaStr}`);
});
// ── Helpers CSV / texto ────────────────────────────────────────────────────────
function _buildCsvFacturasEmitidas(docs) {
    const hdr = [
        "numero_factura", "serie", "fecha", "estado",
        "nif_cliente", "nombre_cliente",
        "base_imponible", "total_iva", "total_recargo_eq",
        "retencion_irpf", "total",
        "tipo_factura", "metodo_pago",
    ].join(";");
    const rows = docs.map((doc) => {
        var _a, _b, _c, _d, _e;
        const d = doc.data();
        return [
            _bcsv(d.numero_factura),
            _bcsv(d.serie),
            _bcsvFecha(d.fecha),
            _bcsv(d.estado),
            _bcsv((_a = d.datos_fiscales) === null || _a === void 0 ? void 0 : _a.nif),
            _bcsv((_c = (_b = d.datos_fiscales) === null || _b === void 0 ? void 0 : _b.razon_social) !== null && _c !== void 0 ? _c : d.nombre_cliente),
            _bcsvNum(d.base_imponible),
            _bcsvNum(d.total_iva),
            _bcsvNum((_d = d.total_recargo_equivalencia) !== null && _d !== void 0 ? _d : 0),
            _bcsvNum((_e = d.retencion_irpf) !== null && _e !== void 0 ? _e : 0),
            _bcsvNum(d.total),
            _bcsv(d.tipo_factura),
            _bcsv(d.metodo_pago),
        ].join(";");
    });
    return "\uFEFF" + hdr + "\n" + rows.join("\n");
}
function _buildCsvFacturasRecibidas(docs) {
    const hdr = [
        "numero_factura_proveedor", "fecha_factura", "fecha_contabilizacion",
        "nif_proveedor", "nombre_proveedor",
        "base_imponible", "cuota_iva", "tipo_iva",
        "total", "categoria", "deducible",
    ].join(";");
    const rows = docs.map((doc) => {
        var _a, _b, _c, _d;
        const d = doc.data();
        return [
            _bcsv(d.numero_factura),
            _bcsvFecha((_a = d.fecha_factura) !== null && _a !== void 0 ? _a : d.fecha),
            _bcsvFecha((_b = d.fecha_contabilizacion) !== null && _b !== void 0 ? _b : d.fecha),
            _bcsv(d.nif_proveedor),
            _bcsv(d.nombre_proveedor),
            _bcsvNum(d.base_imponible),
            _bcsvNum((_c = d.cuota_iva) !== null && _c !== void 0 ? _c : 0),
            _bcsvNum((_d = d.tipo_iva) !== null && _d !== void 0 ? _d : 21),
            _bcsvNum(d.total),
            _bcsv(d.categoria),
            _bcsv(d.deducible !== false ? "Sí" : "No"),
        ].join(";");
    });
    return "\uFEFF" + hdr + "\n" + rows.join("\n");
}
function _buildCsvGastos(docs) {
    const hdr = [
        "id", "fecha", "concepto", "categoria",
        "importe", "iva", "importe_iva",
        "proveedor", "justificante", "deducible",
    ].join(";");
    const rows = docs.map((doc) => {
        var _a, _b, _c;
        const d = doc.data();
        return [
            _bcsv(doc.id),
            _bcsvFecha(d.fecha),
            _bcsv(d.concepto),
            _bcsv(d.categoria),
            _bcsvNum(d.importe),
            _bcsvNum((_a = d.iva) !== null && _a !== void 0 ? _a : 0),
            _bcsvNum((_b = d.importe_iva) !== null && _b !== void 0 ? _b : 0),
            _bcsv((_c = d.proveedor) !== null && _c !== void 0 ? _c : d.nombre_proveedor),
            _bcsv(d.url_justificante ? "Sí" : "No"),
            _bcsv(d.deducible !== false ? "Sí" : "No"),
        ].join(";");
    });
    return "\uFEFF" + hdr + "\n" + rows.join("\n");
}
async function _buildLibroRegistroTrimestral(empresaId, nifEmpresa, trimestre, anio) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const mesInicio = (trimestre - 1) * 3 + 1;
    const mesFin = mesInicio + 2;
    const fechaIni = new Date(anio, mesInicio - 1, 1);
    const fechaFin = new Date(anio, mesFin, 0, 23, 59, 59);
    const snap = await db
        .collection("empresas").doc(empresaId).collection("facturas")
        .where("fecha", ">=", fechaIni)
        .where("fecha", "<=", fechaFin)
        .orderBy("fecha")
        .get();
    if (snap.empty)
        return null;
    const sep = "─".repeat(88);
    const lines = [
        `LIBRO REGISTRO FACTURAS EMITIDAS`,
        `NIF Titular: ${nifEmpresa}   Ejercicio: ${anio}   Trimestre: T${trimestre}`,
        sep,
        "FACTURA        FECHA       NIF CLIENTE     RAZÓN SOCIAL                 BASE IMP    CUOTA IVA       TOTAL",
        sep,
    ];
    let sumBase = 0, sumCuota = 0, sumTotal = 0;
    for (const doc of snap.docs) {
        const d = doc.data();
        const base = (_a = d.base_imponible) !== null && _a !== void 0 ? _a : 0;
        const cuota = (_b = d.total_iva) !== null && _b !== void 0 ? _b : 0;
        const total = (_c = d.total) !== null && _c !== void 0 ? _c : 0;
        sumBase += base;
        sumCuota += cuota;
        sumTotal += total;
        lines.push(String((_d = d.numero_factura) !== null && _d !== void 0 ? _d : "").padEnd(15) +
            _bcsvFecha(d.fecha).padEnd(12) +
            String((_f = (_e = d.datos_fiscales) === null || _e === void 0 ? void 0 : _e.nif) !== null && _f !== void 0 ? _f : "").padEnd(16) +
            String((_j = (_h = (_g = d.datos_fiscales) === null || _g === void 0 ? void 0 : _g.razon_social) !== null && _h !== void 0 ? _h : d.nombre_cliente) !== null && _j !== void 0 ? _j : "").substring(0, 28).padEnd(29) +
            base.toFixed(2).padStart(11) +
            cuota.toFixed(2).padStart(11) +
            total.toFixed(2).padStart(12));
    }
    lines.push(sep);
    lines.push("TOTALES".padEnd(15 + 12 + 16 + 29) +
        sumBase.toFixed(2).padStart(11) +
        sumCuota.toFixed(2).padStart(11) +
        sumTotal.toFixed(2).padStart(12));
    return lines.join("\n");
}
function _bcsv(val) {
    if (val === null || val === undefined)
        return "";
    const str = String(val).replace(/"/g, '""');
    return str.includes(";") || str.includes('"') || str.includes("\n") ? `"${str}"` : str;
}
function _bcsvNum(val) {
    return Number(val !== null && val !== void 0 ? val : 0).toFixed(2).replace(".", ",");
}
function _bcsvFecha(val) {
    if (!val)
        return "";
    try {
        const d = (val === null || val === void 0 ? void 0 : val.toDate)
            ? val.toDate()
            : new Date(val);
        return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()}`;
    }
    catch (_a) {
        return String(val);
    }
}
// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO DE CONTACTO WEB — notificación push + email al admin al recibir msg
// Trigger: empresas/{empresaId}/contacto_web/{mensajeId}  (onDocumentCreated)
// ═══════════════════════════════════════════════════════════════════════════════
exports.onNuevoMensajeContacto = (0, firestore_1.onDocumentCreated)({
    document: "empresas/{empresaId}/contacto_web/{mensajeId}",
    region: REGION,
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const empresaId = event.params.empresaId;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const nombre = (_b = data.nombre) !== null && _b !== void 0 ? _b : "Desconocido";
    const email = (_c = data.email) !== null && _c !== void 0 ? _c : "";
    const mensaje = (_d = data.mensaje) !== null && _d !== void 0 ? _d : "";
    const telefono = (_e = data.telefono) !== null && _e !== void 0 ? _e : "";
    const fecha = new Date().toLocaleDateString("es-ES", {
        day: "2-digit", month: "long", year: "numeric",
        hour: "2-digit", minute: "2-digit",
    });
    // ── 1. Datos de la empresa ────────────────────────────────────────────
    let empresaNombre = "Tu empresa";
    let correoAdmin = null;
    try {
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        const perfil = (_g = (_f = empresaDoc.data()) === null || _f === void 0 ? void 0 : _f.perfil) !== null && _g !== void 0 ? _g : {};
        empresaNombre = (_h = perfil.nombre) !== null && _h !== void 0 ? _h : empresaNombre;
        correoAdmin = (_j = perfil.correo) !== null && _j !== void 0 ? _j : null;
    }
    catch (e) {
        console.warn("⚠️ No se pudo leer empresa:", e);
    }
    // ── 2. Push notifications a todos los dispositivos activos ────────────
    try {
        const devSnap = await db
            .collection("empresas").doc(empresaId)
            .collection("dispositivos")
            .where("activo", "==", true)
            .get();
        const tokens = devSnap.docs
            .map((d) => d.data().token)
            .filter((t) => !!t);
        if (tokens.length > 0) {
            await admin.messaging().sendEachForMulticast({
                tokens,
                notification: {
                    title: "✉️ Nuevo mensaje de contacto",
                    body: `${nombre}: "${mensaje.substring(0, 80)}${mensaje.length > 80 ? "…" : ""}"`,
                },
                data: {
                    tipo: "mensaje_contacto",
                    empresa_id: empresaId,
                },
                android: {
                    priority: "high",
                    notification: { channelId: "fluixcrm_canal_principal" },
                },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            console.log(`✅ Push enviado a ${tokens.length} dispositivos (empresa: ${empresaId})`);
        }
    }
    catch (e) {
        console.error("❌ Error enviando push contacto:", e);
    }
    // ── 3. Email al admin/propietario via Resend ──────────────────────────
    if (correoAdmin) {
        try {
            const apiKey = process.env.RESEND_API_KEY;
            if (apiKey) {
                const { Resend } = await Promise.resolve().then(() => __importStar(require("resend")));
                const resend = new Resend(apiKey);
                const fs = await Promise.resolve().then(() => __importStar(require("fs")));
                const path = await Promise.resolve().then(() => __importStar(require("path")));
                const tplPath = path.join(__dirname, "templates", "contacto_notificacion.html");
                let html = fs.existsSync(tplPath) ? fs.readFileSync(tplPath, "utf-8") : "";
                const vars = {
                    nombre, email, mensaje, telefono, fecha, empresa_nombre: empresaNombre,
                };
                for (const [k, v] of Object.entries(vars)) {
                    html = html.replace(new RegExp(`{{${k}}}`, "g"), v);
                }
                // Limpiar helpers condicionales y variables sobrantes
                if (!telefono) {
                    html = html.replace(/{{#telefono}}[\s\S]*?{{\/telefono}}/g, "");
                }
                else {
                    html = html.replace(/{{#telefono}}|{{\/telefono}}/g, "");
                }
                html = html.replace(/{{[^}]+}}/g, "");
                await resend.emails.send({
                    from: "Fluix CRM <noreply@fluixtech.com>",
                    to: correoAdmin,
                    subject: `✉️ Nuevo mensaje de ${nombre} — ${empresaNombre}`,
                    html: html || `<p>Nuevo mensaje de <b>${nombre}</b> (${email}):<br><br>${mensaje}</p>`,
                });
                console.log(`✅ Email de contacto enviado a ${correoAdmin}`);
            }
        }
        catch (e) {
            console.error("❌ Error enviando email contacto:", e);
        }
    }
});
//# sourceMappingURL=index.js.map