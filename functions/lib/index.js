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
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPedidoCRM = exports.onReservaCRM = exports.onReservaCreatedCRM = exports.onNuevoClienteCRM = exports.onBienvenidaClienteNuevo = exports.onSelloFidelizacionInApp = exports.procesarSolicitudesValoracion = exports.onReservaCompletadaValoracion = exports.onPromocionClienteNotif = exports.onFlashSlotClienteNotif = exports.recordatorioReservaCliente = exports.onReservaCanceladaCliente = exports.onReservaConfirmadaCliente = exports.verificarCaducidadSellos = exports.marcarQRsExpirados = exports.onCanjeRecompensa = exports.onCheckinFidelizacion = exports.eliminarValoracion = exports.onValoracionBaja = exports.onValoracionWrite = exports.onReservaCompletada = exports.expirarReservasPublicas = exports.gestionarReservaPublica = exports.onReservaPublicaCreada = exports.rechazarReserva = exports.confirmarReserva = exports.onNuevaNotificacionReserva = exports.onNuevaReservaEmail = exports.asignarAdminPlataforma = exports.crearEmpleadoConCredenciales = exports.sendResetPasswordEmail = exports.onInvitacionCreada = exports.fanNumero1Job = exports.evaluarTrofeosFidelidad = exports.onPerfilActualizadoTrofeos = exports.onResenaCreadaTrofeos = exports.onCitaCompletadaTrofeos = exports.verificarLoginIntento = exports.onNuevoFlashSlot = exports.expirarFlashSlots = exports.scheduledAlertaCertificado = exports.scheduledAlertaPreciosAntiguos = exports.generarThumbnailCatalogo = exports.cambiarEstadoChatBot = exports.enviarMensajeAdminWhatsApp = exports.enviarPlantillaWhatsApp = exports.whatsappWebhook = exports.calculateFiscalModel = exports.processInvoice = exports.cerrarCaja = void 0;
exports.onPedidoEstadoCambiado = exports.onNuevoPedido = exports.onNuevaValoracion = exports.reenviarConfirmacionReserva = exports.onReservaCancelada = exports.onReservaConfirmada = exports.enviarCampanaEmail = exports.testEmail = exports.onMensajeContactoRespondido = exports.onNuevoMensajeContacto = exports.onNuevaReserva = exports.publicarBlogsProgramados = exports.generarSitemap = exports.onNuevoContactoSoporte = exports.onNuevaSugerencia = exports.scheduledTareasVencenHoy = exports.scheduledRecordatoriosTareas = exports.scheduledGenerarTareasRecurrentes = exports.onTareaAsignada = exports.resumenSemanalResenas = exports.alertaResenasNegativasAcumuladas = exports.scheduledSincronizarResenas = exports.procesarRespuestasPendientes = exports.publicarRespuestaGoogle = exports.desconectarGoogleBusiness = exports.guardarFichaSeleccionada = exports.obtenerFichasNegocio = exports.storeGmbToken = exports.actualizarModulosSegunPlan = exports.actualizarPlanEmpresaV2 = exports.migracionPlanesV2 = exports.generarFacturasResumenTpv = exports.onJuanitaReservaEstadoCambiado = exports.onPedidoNazariPagado = exports.verificarDescargaEbook = exports.stripeWebhookNazari = exports.crearCheckoutNazari = exports.migrarDatosNazariDesdeWeb = exports.importarContenidoNazari = exports.buscarArchivoNazari = exports.pushNuevoCatalogo = exports.pushNuevoPost = exports.pushNuevoEvento = exports.purgeCatalogoCdn = exports.purgeBlogCdn = exports.purgeEventoCdn = exports.recalcularStatsCliente = exports.onFacturaAnuladaCRM = exports.onFacturaCRM = exports.onPedidoWhatsAppCRM = void 0;
exports.crearLinkPackNazari = exports.auditarStripeCatalogo = exports.migrarLibrosStripe = exports.crearPedidoPruebaTest = exports.sincronizarLibroStripeTest = exports.sincronizarLibroStripe = exports.crearCheckoutTienda = exports.recomendacionesNazari = exports.enviarEmailsContactoInteres = exports.backupDatosFiscalesNocturno = exports.alertasVencimientosFiscales = exports.enviarDocumentacionFiniquito = exports.scheduledAlertaCobertura = exports.scheduledExpiracionCarryover = exports.scheduledCierreAnualVacaciones = exports.onVacacionEstadoCambiado = exports.importarFestivosEspana = exports.stripeWebhookTienda = exports.alertaStockBajo = exports.catalogoPublico = exports.webhookPagoWeb = exports.listarCuentasClientes = exports.actualizarPlanEmpresa = exports.crearCuentaConPlan = exports.getBlogLista = exports.getBlogEntry = exports.publicarPostsProgramados = exports.remitirVerifactu = exports.firmarXMLVerifactu = exports.enviarRecordatoriosCitas = exports.registrarVisita = exports.enviarEmailConPdf = exports.stripeWebhook = exports.crearEmpresaHTTP = exports.inicializarEmpresa = exports.onNuevoPedidoWhatsApp = exports.verificarSuscripciones = exports.onNuevoPedidoGenerarFactura = void 0;
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
Object.defineProperty(exports, "onNuevoContactoSoporte", { enumerable: true, get: function () { return tareasFunciones_1.onNuevoContactoSoporte; } });
const alertaCertificado_1 = require("./alertaCertificado");
Object.defineProperty(exports, "scheduledAlertaCertificado", { enumerable: true, get: function () { return alertaCertificado_1.scheduledAlertaCertificado; } });
const authGuard_1 = require("./utils/authGuard");
const fuerzaBruta_1 = require("./auth/fuerzaBruta");
Object.defineProperty(exports, "verificarLoginIntento", { enumerable: true, get: function () { return fuerzaBruta_1.verificarLoginIntento; } });
const flashSlots_1 = require("./flashSlots");
Object.defineProperty(exports, "expirarFlashSlots", { enumerable: true, get: function () { return flashSlots_1.expirarFlashSlots; } });
Object.defineProperty(exports, "onNuevoFlashSlot", { enumerable: true, get: function () { return flashSlots_1.onNuevoFlashSlot; } });
const node_fetch_1 = __importDefault(require("node-fetch"));
var cerrarCaja_1 = require("./cerrarCaja");
Object.defineProperty(exports, "cerrarCaja", { enumerable: true, get: function () { return cerrarCaja_1.cerrarCaja; } });
var processInvoice_1 = require("./fiscal/processInvoice");
Object.defineProperty(exports, "processInvoice", { enumerable: true, get: function () { return processInvoice_1.processInvoice; } });
var calculateModel_1 = require("./fiscal/models/calculateModel");
Object.defineProperty(exports, "calculateFiscalModel", { enumerable: true, get: function () { return calculateModel_1.calculateFiscalModel; } });
var whatsappBot_1 = require("./whatsappBot");
Object.defineProperty(exports, "whatsappWebhook", { enumerable: true, get: function () { return whatsappBot_1.whatsappWebhook; } });
Object.defineProperty(exports, "enviarPlantillaWhatsApp", { enumerable: true, get: function () { return whatsappBot_1.enviarPlantillaWhatsApp; } });
Object.defineProperty(exports, "enviarMensajeAdminWhatsApp", { enumerable: true, get: function () { return whatsappBot_1.enviarMensajeAdminWhatsApp; } });
Object.defineProperty(exports, "cambiarEstadoChatBot", { enumerable: true, get: function () { return whatsappBot_1.cambiarEstadoChatBot; } });
var catalogoFunciones_1 = require("./catalogoFunciones");
Object.defineProperty(exports, "generarThumbnailCatalogo", { enumerable: true, get: function () { return catalogoFunciones_1.generarThumbnailCatalogo; } });
Object.defineProperty(exports, "scheduledAlertaPreciosAntiguos", { enumerable: true, get: function () { return catalogoFunciones_1.scheduledAlertaPreciosAntiguos; } });
var trofeos_1 = require("./trofeos");
Object.defineProperty(exports, "onCitaCompletadaTrofeos", { enumerable: true, get: function () { return trofeos_1.onCitaCompletadaTrofeos; } });
Object.defineProperty(exports, "onResenaCreadaTrofeos", { enumerable: true, get: function () { return trofeos_1.onResenaCreadaTrofeos; } });
Object.defineProperty(exports, "onPerfilActualizadoTrofeos", { enumerable: true, get: function () { return trofeos_1.onPerfilActualizadoTrofeos; } });
Object.defineProperty(exports, "evaluarTrofeosFidelidad", { enumerable: true, get: function () { return trofeos_1.evaluarTrofeosFidelidad; } });
Object.defineProperty(exports, "fanNumero1Job", { enumerable: true, get: function () { return trofeos_1.fanNumero1Job; } });
var invitaciones_1 = require("./invitaciones");
Object.defineProperty(exports, "onInvitacionCreada", { enumerable: true, get: function () { return invitaciones_1.onInvitacionCreada; } });
var resetPassword_1 = require("./resetPassword");
Object.defineProperty(exports, "sendResetPasswordEmail", { enumerable: true, get: function () { return resetPassword_1.sendResetPasswordEmail; } });
var crearEmpleado_1 = require("./crearEmpleado");
Object.defineProperty(exports, "crearEmpleadoConCredenciales", { enumerable: true, get: function () { return crearEmpleado_1.crearEmpleadoConCredenciales; } });
var adminClaims_1 = require("./adminClaims");
Object.defineProperty(exports, "asignarAdminPlataforma", { enumerable: true, get: function () { return adminClaims_1.asignarAdminPlataforma; } });
var notificacionesReservas_1 = require("./notificacionesReservas");
Object.defineProperty(exports, "onNuevaReservaEmail", { enumerable: true, get: function () { return notificacionesReservas_1.onNuevaReservaEmail; } });
Object.defineProperty(exports, "onNuevaNotificacionReserva", { enumerable: true, get: function () { return notificacionesReservas_1.onNuevaNotificacionReserva; } });
Object.defineProperty(exports, "confirmarReserva", { enumerable: true, get: function () { return notificacionesReservas_1.confirmarReserva; } });
Object.defineProperty(exports, "rechazarReserva", { enumerable: true, get: function () { return notificacionesReservas_1.rechazarReserva; } });
var reservasPublicas_1 = require("./reservasPublicas");
Object.defineProperty(exports, "onReservaPublicaCreada", { enumerable: true, get: function () { return reservasPublicas_1.onReservaPublicaCreada; } });
Object.defineProperty(exports, "gestionarReservaPublica", { enumerable: true, get: function () { return reservasPublicas_1.gestionarReservaPublica; } });
Object.defineProperty(exports, "expirarReservasPublicas", { enumerable: true, get: function () { return reservasPublicas_1.expirarReservasPublicas; } });
var valoraciones_1 = require("./valoraciones");
Object.defineProperty(exports, "onReservaCompletada", { enumerable: true, get: function () { return valoraciones_1.onReservaCompletada; } });
Object.defineProperty(exports, "onValoracionWrite", { enumerable: true, get: function () { return valoraciones_1.onValoracionWrite; } });
Object.defineProperty(exports, "onValoracionBaja", { enumerable: true, get: function () { return valoraciones_1.onValoracionBaja; } });
Object.defineProperty(exports, "eliminarValoracion", { enumerable: true, get: function () { return valoraciones_1.eliminarValoracion; } });
var fidelizacion_1 = require("./fidelizacion");
Object.defineProperty(exports, "onCheckinFidelizacion", { enumerable: true, get: function () { return fidelizacion_1.onCheckinFidelizacion; } });
Object.defineProperty(exports, "onCanjeRecompensa", { enumerable: true, get: function () { return fidelizacion_1.onCanjeRecompensa; } });
Object.defineProperty(exports, "marcarQRsExpirados", { enumerable: true, get: function () { return fidelizacion_1.marcarQRsExpirados; } });
Object.defineProperty(exports, "verificarCaducidadSellos", { enumerable: true, get: function () { return fidelizacion_1.verificarCaducidadSellos; } });
var notificaciones_cliente_1 = require("./notificaciones_cliente");
Object.defineProperty(exports, "onReservaConfirmadaCliente", { enumerable: true, get: function () { return notificaciones_cliente_1.onReservaConfirmadaCliente; } });
Object.defineProperty(exports, "onReservaCanceladaCliente", { enumerable: true, get: function () { return notificaciones_cliente_1.onReservaCanceladaCliente; } });
Object.defineProperty(exports, "recordatorioReservaCliente", { enumerable: true, get: function () { return notificaciones_cliente_1.recordatorioReservaCliente; } });
Object.defineProperty(exports, "onFlashSlotClienteNotif", { enumerable: true, get: function () { return notificaciones_cliente_1.onFlashSlotClienteNotif; } });
Object.defineProperty(exports, "onPromocionClienteNotif", { enumerable: true, get: function () { return notificaciones_cliente_1.onPromocionClienteNotif; } });
Object.defineProperty(exports, "onReservaCompletadaValoracion", { enumerable: true, get: function () { return notificaciones_cliente_1.onReservaCompletadaValoracion; } });
Object.defineProperty(exports, "procesarSolicitudesValoracion", { enumerable: true, get: function () { return notificaciones_cliente_1.procesarSolicitudesValoracion; } });
Object.defineProperty(exports, "onSelloFidelizacionInApp", { enumerable: true, get: function () { return notificaciones_cliente_1.onSelloFidelizacionInApp; } });
Object.defineProperty(exports, "onBienvenidaClienteNuevo", { enumerable: true, get: function () { return notificaciones_cliente_1.onBienvenidaClienteNuevo; } });
var automaciones_clientes_1 = require("./automaciones_clientes");
Object.defineProperty(exports, "onNuevoClienteCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onNuevoClienteCRM; } });
Object.defineProperty(exports, "onReservaCreatedCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onReservaCreatedCRM; } });
Object.defineProperty(exports, "onReservaCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onReservaCRM; } });
Object.defineProperty(exports, "onPedidoCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onPedidoCRM; } });
Object.defineProperty(exports, "onPedidoWhatsAppCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onPedidoWhatsAppCRM; } });
Object.defineProperty(exports, "onFacturaCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onFacturaCRM; } });
Object.defineProperty(exports, "onFacturaAnuladaCRM", { enumerable: true, get: function () { return automaciones_clientes_1.onFacturaAnuladaCRM; } });
Object.defineProperty(exports, "recalcularStatsCliente", { enumerable: true, get: function () { return automaciones_clientes_1.recalcularStatsCliente; } });
var cdnPurge_1 = require("./cdnPurge");
Object.defineProperty(exports, "purgeEventoCdn", { enumerable: true, get: function () { return cdnPurge_1.purgeEventoCdn; } });
Object.defineProperty(exports, "purgeBlogCdn", { enumerable: true, get: function () { return cdnPurge_1.purgeBlogCdn; } });
Object.defineProperty(exports, "purgeCatalogoCdn", { enumerable: true, get: function () { return cdnPurge_1.purgeCatalogoCdn; } });
var webPush_1 = require("./webPush");
Object.defineProperty(exports, "pushNuevoEvento", { enumerable: true, get: function () { return webPush_1.pushNuevoEvento; } });
Object.defineProperty(exports, "pushNuevoPost", { enumerable: true, get: function () { return webPush_1.pushNuevoPost; } });
Object.defineProperty(exports, "pushNuevoCatalogo", { enumerable: true, get: function () { return webPush_1.pushNuevoCatalogo; } });
var nazariMigracion_1 = require("./nazariMigracion");
Object.defineProperty(exports, "buscarArchivoNazari", { enumerable: true, get: function () { return nazariMigracion_1.buscarArchivoNazari; } });
Object.defineProperty(exports, "importarContenidoNazari", { enumerable: true, get: function () { return nazariMigracion_1.importarContenidoNazari; } });
Object.defineProperty(exports, "migrarDatosNazariDesdeWeb", { enumerable: true, get: function () { return nazariMigracion_1.migrarDatosNazariDesdeWeb; } });
var nazariEbooks_1 = require("./nazariEbooks");
Object.defineProperty(exports, "crearCheckoutNazari", { enumerable: true, get: function () { return nazariEbooks_1.crearCheckoutNazari; } });
Object.defineProperty(exports, "stripeWebhookNazari", { enumerable: true, get: function () { return nazariEbooks_1.stripeWebhookNazari; } });
Object.defineProperty(exports, "verificarDescargaEbook", { enumerable: true, get: function () { return nazariEbooks_1.verificarDescargaEbook; } });
Object.defineProperty(exports, "onPedidoNazariPagado", { enumerable: true, get: function () { return nazariEbooks_1.onPedidoNazariPagado; } });
var juanitaReservasEmail_1 = require("./juanitaReservasEmail");
Object.defineProperty(exports, "onJuanitaReservaEstadoCambiado", { enumerable: true, get: function () { return juanitaReservasEmail_1.onJuanitaReservaEstadoCambiado; } });
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
const stripeSecretKeyTest = { value: () => { var _a; return (_a = process.env.STRIPE_SECRET_KEY_TEST) !== null && _a !== void 0 ? _a : ""; } };
const stripeWebhookSecret = { value: () => { var _a; return (_a = process.env.STRIPE_WEBHOOK_SECRET) !== null && _a !== void 0 ? _a : ""; } };
const stripeWebhookSecretTest = { value: () => { var _a; return (_a = process.env.STRIPE_WEBHOOK_SECRET_TEST) !== null && _a !== void 0 ? _a : ""; } };
// Secret para webhooks de tiendas de clientes — puede ser el mismo o uno propio
const stripeTiendaWebhookSecret = { value: () => { var _a, _b; return (_b = (_a = process.env.STRIPE_TIENDA_WEBHOOK_SECRET) !== null && _a !== void 0 ? _a : process.env.STRIPE_WEBHOOK_SECRET) !== null && _b !== void 0 ? _b : ""; } };
// Resend API key — configurado en functions/.env como RESEND_API_KEY
// ── UTILIDADES ────────────────────────────────────────────────────────────────
const notificaciones_1 = require("./utils/notificaciones");
// ── Sitemap.xml dinámico por empresa ─────────────────────────────────────────
// GET /generarSitemap?empresa={empresaId}&base={baseUrl}
// Devuelve un sitemap.xml con blog posts publicados + páginas estáticas.
exports.generarSitemap = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    var _a;
    const empresaId = req.query.empresa;
    const baseUrl = (req.query.base || '').replace(/\/$/, '');
    if (!empresaId) {
        res.status(400).send("Parámetro ?empresa=ID requerido");
        return;
    }
    try {
        // Posts del blog publicados
        const blogSnap = await db
            .collection("empresas").doc(empresaId)
            .collection("blog")
            .where("estado", "==", "publicado")
            .get();
        // Info empresa para schema
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        const dominio = baseUrl || ((_a = empresaDoc.data()) === null || _a === void 0 ? void 0 : _a.dominio_web) || "";
        const ahora = new Date().toISOString().split("T")[0];
        // Páginas estáticas
        const paginas = [
            { loc: `${dominio}/index.html`, priority: "1.0", changefreq: "weekly" },
            { loc: `${dominio}/catalogo.html`, priority: "0.9", changefreq: "weekly" },
            { loc: `${dominio}/blog.html`, priority: "0.9", changefreq: "daily" },
            { loc: `${dominio}/autores.html`, priority: "0.7", changefreq: "monthly" },
            { loc: `${dominio}/eventos.html`, priority: "0.8", changefreq: "weekly" },
            { loc: `${dominio}/conocenos.html`, priority: "0.6", changefreq: "monthly" },
            { loc: `${dominio}/contacto.html`, priority: "0.5", changefreq: "monthly" },
        ];
        // Blog posts
        const blogsUrls = blogSnap.docs.map((d) => {
            const data = d.data();
            const slug = data.slug || d.id;
            const fechaTs = data.fecha_publicacion;
            const fechaStr = (fechaTs === null || fechaTs === void 0 ? void 0 : fechaTs.toDate)
                ? fechaTs.toDate().toISOString().split("T")[0]
                : ahora;
            return {
                loc: `${dominio}/blog-post.html?slug=${encodeURIComponent(slug)}`,
                lastmod: fechaStr,
                priority: "0.8",
                changefreq: "monthly",
            };
        });
        const toUrl = (u) => `  <url>\n    <loc>${u.loc}</loc>\n    <lastmod>${u.lastmod || ahora}</lastmod>\n    <changefreq>${u.changefreq}</changefreq>\n    <priority>${u.priority}</priority>\n  </url>`;
        const xml = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
            ...paginas.map(toUrl),
            ...blogsUrls.map(toUrl),
            '</urlset>',
        ].join("\n");
        res.set("Content-Type", "application/xml; charset=utf-8");
        res.set("Cache-Control", "public, max-age=3600");
        res.status(200).send(xml);
    }
    catch (err) {
        console.error("Error generarSitemap:", err);
        res.status(500).send("Error generando sitemap");
    }
});
// ── Publicación programada de blogs ──────────────────────────────────────────
// Ejecuta cada 10 minutos. Busca blogs con estado='programado' cuya
// fecha_publicacion ya haya llegado y los cambia a 'publicado'.
exports.publicarBlogsProgramados = (0, scheduler_1.onSchedule)({ schedule: "*/10 * * * *", timeZone: "Europe/Madrid", region: REGION }, async (_event) => {
    const ahora = admin.firestore.Timestamp.now();
    const snap = await db
        .collectionGroup("blog")
        .where("estado", "==", "programado")
        .where("fecha_publicacion", "<=", ahora)
        .get();
    if (snap.empty)
        return;
    const batchSize = 500;
    let batch = db.batch();
    let ops = 0;
    let total = 0;
    for (const doc of snap.docs) {
        batch.update(doc.ref, {
            estado: "publicado",
            publicada: true,
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        });
        ops++;
        total++;
        if (ops === batchSize) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
        }
    }
    if (ops > 0)
        await batch.commit();
    console.log(`publicarBlogsProgramados: ${total} blog(s) publicado(s)`);
});
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
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, titulo, cuerpo, { tipo: "nueva_reserva", reserva_id: entidadId, coleccion });
    console.log(`✅ ${label} guardada en bandeja y push enviado — empresa ${empresaId}`);
}
/**
 * 1. NUEVA RESERVA — Unificada (cubre tanto citas TPV como reservas B2C)
 */
exports.onNuevaReserva = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION }, async (event) => {
    var _a;
    const reserva = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!reserva)
        return;
    // Determinar el tipo de notificación según el origen
    const coleccion = reserva.origen === 'tpv_peluqueria' ? 'citas' : 'reservas';
    await procesarNuevaReservaOCita(event.params.empresaId, event.params.reservaId, reserva, coleccion);
});
// ⛔ onNuevaCita ELIMINADA — ahora todo se maneja en reservas/ unificadas
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
// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DE CONTACTO WEB
// ─────────────────────────────────────────────────────────────────────────────
/**
 * NUEVO MENSAJE DE CONTACTO WEB
 * - Envía push notification a todos los dispositivos de la empresa
 * - Envía email al empresario si tiene email_notificaciones configurado
 */
exports.onNuevoMensajeContacto = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/contacto_web/{mensajeId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const msg = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!msg)
        return;
    const empresa = await _getDatosEmpresa(empresaId);
    const nombre = msg.nombre || "Visitante";
    const asunto = msg.asunto || "Sin asunto";
    const cuerpo = `De: ${nombre} — ${asunto}`;
    // ── 1. Push notification ──────────────────────────────────────────────────
    try {
        const tokensDocs = await db
            .collection(`empresas/${empresaId}/dispositivos`)
            .get();
        const tokens = tokensDocs.docs
            .map((d) => d.data().token)
            .filter((t) => !!t);
        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                tokens,
                notification: {
                    title: "💬 Nuevo mensaje de contacto",
                    body: cuerpo,
                },
                data: {
                    tipo: "contacto_web",
                    empresaId,
                    mensajeId: event.params.mensajeId,
                },
                apns: {
                    payload: { aps: { sound: "default", badge: 1 } },
                },
                android: {
                    notification: { sound: "default", channelId: "fluix_general" },
                },
            });
        }
    }
    catch (e) {
        console.error("onNuevoMensajeContacto push error:", e);
    }
    // ── 2. Notificación en colección (para Windows polling) ──────────────────
    try {
        await db.collection(`empresas/${empresaId}/notificaciones`).add({
            titulo: "💬 Nuevo mensaje de contacto",
            cuerpo,
            tipo: "contacto_web",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            datos: { mensajeId: event.params.mensajeId, tipo: "contacto_web", empresaId },
        });
    }
    catch (e) {
        console.error("onNuevoMensajeContacto notificacion error:", e);
    }
    // ── 3. Email al empresario ────────────────────────────────────────────────
    if (empresa.email) {
        try {
            await (0, resend_service_1.enviarNotificacionContactoWeb)({
                emailEmpresario: empresa.email,
                empresaNombre: empresa.nombre,
                nombreRemitente: nombre,
                emailRemitente: msg.email || "",
                telefonoRemitente: msg.telefono || "",
                asunto,
                mensajeTexto: msg.mensaje || "",
            });
        }
        catch (e) {
            console.error("onNuevoMensajeContacto email error:", e);
        }
    }
});
/**
 * MENSAJE RESPONDIDO
 * Cuando el empresario escribe su respuesta en la app, se envía un email
 * automáticamente al visitante usando Resend.
 * Trigger: campos `respondido` (false→true) y `respuesta` (nuevo) en el doc.
 */
exports.onMensajeContactoRespondido = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/contacto_web/{mensajeId}", region: REGION }, async (event) => {
    var _a, _b;
    const empresaId = event.params.empresaId;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    // Solo disparar cuando pasa de no-respondido a respondido y hay respuesta
    if (antes.respondido === true)
        return;
    if (despues.respondido !== true)
        return;
    const respuesta = (despues.respuesta || "").trim();
    if (!respuesta)
        return;
    const emailRemitente = despues.email;
    if (!emailRemitente) {
        console.log("onMensajeContactoRespondido: sin email del remitente, omitiendo");
        return;
    }
    const empresa = await _getDatosEmpresa(empresaId);
    try {
        await (0, resend_service_1.enviarRespuestaContactoWeb)({
            emailRemitente,
            nombreRemitente: despues.nombre || "Visitante",
            empresaNombre: empresa.nombre,
            asunto: despues.asunto || "Tu consulta",
            mensajeOriginal: despues.mensaje || "",
            respuestaTexto: respuesta,
        });
        console.log(`✅ Respuesta enviada a ${emailRemitente}`);
    }
    catch (e) {
        console.error("onMensajeContactoRespondido email error:", e);
    }
});
// ── TEST EMAIL (temporal — quitar tras diagnosticar) ──────────────────────────
exports.testEmail = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    var _a;
    if (req.method !== "POST") {
        res.status(405).send("POST only");
        return;
    }
    const to = ((_a = req.body) === null || _a === void 0 ? void 0 : _a.to) || "sacoor80@gmail.com";
    try {
        const apiKey = process.env.RESEND_API_KEY || "";
        if (!apiKey) {
            res.json({ ok: false, error: "RESEND_API_KEY not set" });
            return;
        }
        const result = await (0, resend_service_1.enviarPdfGenerico)({
            from: "Editorial Nazarí <noreply@fluixtech.com>",
            to,
            subject: "Test email desde Cloud Functions",
            html: `<p>Email de prueba enviado desde la función. API Key presente: ${apiKey.length > 0 ? 'SÍ (' + apiKey.slice(0, 8) + '...)' : 'NO'}</p>`,
        });
        res.json({ ok: result.exito, id: result.id, error: result.error });
    }
    catch (e) {
        res.json({ ok: false, error: e.message });
    }
});
// ── ENVÍO DE CAMPAÑAS DE EMAIL ─────────────────────────────────────────────────
//
// Trigger: campanas_email/{campanaId} pasa a estado 'enviando'
// 1. Recoge la lista de destinatarios según segmento
// 2. Envía con Resend en lotes de 10 (evita rate-limit)
// 3. Actualiza estado → 'enviada' | 'fallida' + total_enviados
exports.enviarCampanaEmail = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/campanas_email/{campanaId}", region: REGION }, async (event) => {
    var _a, _b;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    if (antes.estado === "enviando")
        return;
    if (despues.estado !== "enviando")
        return;
    const empresaId = event.params.empresaId;
    const campanaId = event.params.campanaId;
    const campanaRef = db.collection(`empresas/${empresaId}/campanas_email`).doc(campanaId);
    const asunto = despues.asunto || "(Sin asunto)";
    const contenidoRaw = despues.contenido_html || "";
    const segmento = despues.segmento || "todos";
    const destinatariosManual = despues.destinatarios_manual || [];
    const empresa = await _getDatosEmpresa(empresaId);
    const fromEmail = `${empresa.nombre} <noreply@fluixtech.com>`;
    // Convertir saltos de línea a <br> si el contenido no tiene tags HTML
    const tieneHtml = /<[a-z][\s\S]*>/i.test(contenidoRaw);
    const contenidoProcessed = tieneHtml
        ? contenidoRaw
        : contenidoRaw.replace(/\n/g, "<br>");
    // Envolver en template HTML profesional
    const anio = new Date().getFullYear();
    const contenidoHtml = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${asunto}</title>
</head>
<body style="margin:0;padding:0;background:#f0f0f0;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f0f0;padding:32px 16px;">
    <tr><td align="center">
      <table width="620" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border-radius:10px;overflow:hidden;max-width:620px;box-shadow:0 2px 12px rgba(0,0,0,.08);">
        <!-- HEADER -->
        <tr>
          <td style="background:#1a1a2e;padding:28px 40px;text-align:center;">
            <span style="color:#ffffff;font-size:24px;font-weight:bold;letter-spacing:.5px;">${empresa.nombre}</span>
          </td>
        </tr>
        <!-- ASUNTO -->
        <tr>
          <td style="padding:28px 40px 0;border-bottom:1px solid #e8eaed;">
            <h2 style="margin:0 0 16px;font-size:20px;color:#1a1a2e;font-weight:700;line-height:1.3;">${asunto}</h2>
          </td>
        </tr>
        <!-- CONTENIDO -->
        <tr>
          <td style="padding:28px 40px;font-size:15px;color:#374151;line-height:1.7;">
            ${contenidoProcessed}
          </td>
        </tr>
        <!-- FOOTER -->
        <tr>
          <td style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #e8eaed;">
            <p style="margin:0;font-size:12px;color:#9ca3af;">
              © ${anio} ${empresa.nombre}. Todos los derechos reservados.<br>
              Para dejar de recibir este tipo de comunicaciones responde con "BAJA".
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
    // Construir lista de destinatarios
    let emails = [];
    try {
        if (segmento === "manual") {
            emails = destinatariosManual.filter(e => e.includes("@"));
        }
        else {
            // Segmento 'todos' o 'clientes_activos': leer de colección clientes
            const corte = segmento === "clientes_activos"
                ? new Date(Date.now() - 90 * 24 * 3600 * 1000)
                : null;
            let q = db.collection(`empresas/${empresaId}/clientes`)
                .where("activo", "!=", false);
            if (corte) {
                q = db.collection(`empresas/${empresaId}/clientes`)
                    .where("fecha_creacion", ">=", admin.firestore.Timestamp.fromDate(corte));
            }
            const snap = await q.get();
            snap.docs.forEach(d => {
                const email = d.data().email || d.data().correo || "";
                if (email.includes("@"))
                    emails.push(email);
            });
            // También leer de colección 'clientes_web' si existe
            try {
                const snapWeb = await db.collection(`empresas/${empresaId}/contacto_web`)
                    .where("origen", "!=", "manuscrito").get();
                snapWeb.docs.forEach(d => {
                    const email = d.data().email || "";
                    if (email.includes("@") && !emails.includes(email))
                        emails.push(email);
                });
            }
            catch (_) { }
        }
    }
    catch (e) {
        console.error("❌ [Campaña] Error obteniendo destinatarios:", e);
        await campanaRef.update({ estado: "fallida", error_mensaje: "Error obteniendo destinatarios" });
        return;
    }
    if (emails.length === 0) {
        console.warn(`⚠️ [Campaña] ${campanaId} — sin destinatarios`);
        await campanaRef.update({ estado: "enviada", total_enviados: 0, fecha_envio: admin.firestore.FieldValue.serverTimestamp() });
        return;
    }
    // Envío en lotes de 10
    let enviados = 0;
    const LOTE = 10;
    for (let i = 0; i < emails.length; i += LOTE) {
        const lote = emails.slice(i, i + LOTE);
        await Promise.allSettled(lote.map(to => (0, resend_service_1.enviarPdfGenerico)({ from: fromEmail, to, subject: asunto, html: contenidoHtml })
            .then(r => { if (r.exito)
            enviados++; })
            .catch(() => { })));
        // Pausa breve entre lotes para no saturar Resend
        if (i + LOTE < emails.length)
            await new Promise(r => setTimeout(r, 500));
    }
    await campanaRef.update({
        estado: "enviada",
        total_enviados: enviados,
        fecha_envio: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ [Campaña] ${campanaId} enviada — ${enviados}/${emails.length} emails`);
});
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
exports.onReservaConfirmada = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION, secrets: ["RESEND_API_KEY"] }, async (event) => {
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
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "✅ Reserva Confirmada", cuerpo, { tipo: "reserva_confirmada", reserva_id: event.params.reservaId });
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
exports.onReservaCancelada = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION, secrets: ["RESEND_API_KEY"] }, async (event) => {
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
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "❌ Reserva Cancelada", cuerpo, { tipo: "reserva_cancelada", reserva_id: event.params.reservaId });
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
 * 2c. REENVÍO MANUAL de confirmación de reserva (callable desde la app)
 */
exports.reenviarConfirmacionReserva = (0, https_1.onCall)({ region: REGION, secrets: ["RESEND_API_KEY"] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado");
    }
    const { empresaId, reservaId } = request.data;
    if (!empresaId || !reservaId) {
        throw new https_1.HttpsError("invalid-argument", "Faltan empresaId o reservaId");
    }
    const snap = await db
        .collection("empresas").doc(empresaId)
        .collection("reservas").doc(reservaId).get();
    if (!snap.exists) {
        throw new https_1.HttpsError("not-found", "Reserva no encontrada");
    }
    const d = snap.data();
    const emailCliente = d.email_cliente || d.correo_cliente || d.email || null;
    if (!emailCliente) {
        throw new https_1.HttpsError("failed-precondition", "La reserva no tiene email de cliente");
    }
    const cliente = d.nombre_cliente || d.cliente || "Cliente";
    const empresa = await _getDatosEmpresa(empresaId);
    await (0, resend_service_1.enviarConfirmacionReserva)({
        to: emailCliente,
        clienteNombre: cliente,
        empresaNombre: empresa.nombre,
        fechaHora: _formatearFechaReserva(d),
        personas: (d.numero_personas || d.personas) ? String(d.numero_personas || d.personas) : undefined,
        servicio: d.servicio || undefined,
        zona: d.zona || undefined,
        notas: d.notas || undefined,
        fromEmail: empresa.email || undefined,
    });
    return { exito: true };
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
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, titulo, cuerpo, mensaje.data);
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
    // Las funciones Stripe crean la notificación directamente para garantizar entrega.
    // Evitar duplicados saltando sus orígenes aquí.
    if (origen === "web_nazari" || origen === "tienda_online")
        return;
    const cuerpo = `${cliente} — €${total.toFixed(2)} (vía ${origen})`;
    // Guardar en bandeja in-app
    await db.collection("notificaciones").doc(empresaId).collection("items").add({
        titulo: "📦 Nuevo Pedido",
        cuerpo,
        tipo: "pedidoNuevo",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leida: false,
        modulo_destino: "pedidos",
        entidad_id: event.params.pedidoId,
        remitente_nombre: cliente !== "Cliente" ? cliente : null,
        remitente_telefono: telefono,
        remitente_email: email,
    });
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "📦 Nuevo Pedido", cuerpo, { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId });
});
/**
 * 4b. PEDIDO ENVIADO → email al cliente con resumen de envío
 */
exports.onPedidoEstadoCambiado = (0, firestore_1.onDocumentUpdated)({ document: "empresas/{empresaId}/pedidos/{pedidoId}", region: REGION }, async (event) => {
    var _a, _b;
    const antes = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const despues = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!antes || !despues)
        return;
    // Solo cuando cambia de otro estado a 'enviado'
    if (antes.estado === despues.estado)
        return;
    if (despues.estado !== "enviado")
        return;
    const correo = despues.cliente_correo || despues.cliente_email || null;
    if (!correo) {
        console.log(`ℹ️ Pedido ${event.params.pedidoId} enviado, sin correo del cliente`);
        return;
    }
    const empresaId = event.params.empresaId;
    const empresa = await _getDatosEmpresa(empresaId);
    const lineas = (despues.lineas || []).map((l) => ({
        nombre: String(l.producto_nombre || l.nombre || "Producto"),
        cantidad: Number(l.cantidad || 1),
        precio: Number(l.precio_unitario || l.precio || 0),
    }));
    try {
        await (0, resend_service_1.enviarNotificacionPedidoEnviado)({
            to: correo,
            clienteNombre: String(despues.cliente_nombre || "Cliente"),
            empresaNombre: empresa.nombre,
            fromEmail: empresa.email || undefined,
            numeroTicket: Number(despues.numero_ticket || 0),
            lineas,
            total: Number(despues.total || 0),
            direccionEnvio: despues.direccion_envio || null,
            notasEnvio: String(despues.notas_envio || ""),
        });
        console.log(`📧 Email de envío enviado a ${correo} (pedido ${event.params.pedidoId})`);
    }
    catch (e) {
        console.warn("⚠️ Error enviando email de envío:", e);
    }
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
                await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "🔒 Suscripción Vencida", "Tu suscripción ha expirado. Renueva en fluixtech.com para seguir usando la app.", { tipo: "suscripcion_vencida" });
                console.log(`🔒 Suscripción VENCIDA para empresa ${empresaId}`);
                continue;
            }
            if (diasRestantes < 0 && diasRestantes >= -7 && suscripcion.estado === "ACTIVA") {
                // Periodo de gracia (0-7 días tras vencimiento): avisar pero no bloquear
                if (!suscripcion.aviso_gracia_enviado) {
                    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "⚠️ Suscripción expirada — periodo de gracia", `Tu suscripción venció hace ${Math.abs(diasRestantes)} día(s). Renueva antes de ${7 + diasRestantes} días para no perder acceso.`, { tipo: "suscripcion_gracia", dias_restantes: String(diasRestantes) });
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
                await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "⚠️ Suscripción por Vencer", `Tu suscripción vence en ${diasRestantes} día${diasRestantes !== 1 ? "s" : ""}. ¡Renueva para continuar!`, {
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
    await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "💬 Pedido por WhatsApp", `${cliente} — €${total.toFixed(2)}`, { tipo: "pedido_whatsapp", pedido_id: event.params.pedidoId });
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
    var _a, _b, _c;
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    const liveKey = stripeSecretKey.value() || "";
    const testKey = stripeSecretKeyTest.value() || "";
    const liveSec = stripeWebhookSecret.value() || "";
    const testSec = stripeWebhookSecretTest.value() || "";
    if (!liveKey && !testKey) {
        console.error("❌ STRIPE_SECRET_KEY no configurada");
        res.status(500).json({ error: "Stripe no configurado en el servidor" });
        return;
    }
    const sig = req.headers["stripe-signature"];
    const rawBody = (_a = req.rawBody) !== null && _a !== void 0 ? _a : Buffer.from(JSON.stringify(req.body));
    if (!sig) {
        res.status(400).json({ error: "Firma de Stripe ausente" });
        return;
    }
    // Intentar verificar con LIVE secret primero, luego con TEST secret
    let event;
    let isTestEvent = false;
    const stripeVerifier = new stripe_1.default(liveKey || testKey, { apiVersion: "2024-06-20" });
    let verified = false;
    if (liveSec) {
        try {
            event = stripeVerifier.webhooks.constructEvent(rawBody, sig, liveSec);
            verified = true;
        }
        catch (_) { /* probar con TEST */ }
    }
    if (!verified && testSec) {
        try {
            event = stripeVerifier.webhooks.constructEvent(rawBody, sig, testSec);
            verified = true;
            isTestEvent = true;
        }
        catch (_) { /* ninguno funcionó */ }
    }
    if (!verified) {
        console.error("❌ Firma Stripe inválida — comprueba STRIPE_WEBHOOK_SECRET y STRIPE_WEBHOOK_SECRET_TEST");
        res.status(400).json({ error: "Firma inválida" });
        return;
    }
    console.log(`📥 Stripe evento: ${event.type} [${event.id}] modo=${isTestEvent ? "TEST" : "LIVE"}`);
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
                if (((_b = session.metadata) === null || _b === void 0 ? void 0 : _b.tipo) === "pedido_nazari") {
                    await _procesarPedidoNazari(session, db);
                }
                else {
                    await _procesarCheckoutCompletado(session, db);
                }
                break;
            }
            case "payment_intent.succeeded": {
                const pi = event.data.object;
                if ((_c = pi.metadata) === null || _c === void 0 ? void 0 : _c.empresa_id) {
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
// ── Pedido de libro Editorial Nazarí (via Payment Link o Checkout) ────────────
async function _procesarPedidoNazari(session, db) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
    const modoLabel = session.livemode ? "LIVE" : "TEST";
    const libroId = ((_a = session.metadata) === null || _a === void 0 ? void 0 : _a.libro_id) || "";
    const totalEuros = ((_b = session.amount_total) !== null && _b !== void 0 ? _b : 0) / 100;
    // Envío: shipping_cost viene incluido en amount_total
    const gastosEnvioEuros = ((_d = (_c = session.shipping_cost) === null || _c === void 0 ? void 0 : _c.amount_total) !== null && _d !== void 0 ? _d : 0) / 100;
    const totalProductosEuros = parseFloat((totalEuros - gastosEnvioEuros).toFixed(2));
    // Zona y opción de envío derivadas del país del destinatario y el importe
    const paisDestinatario = (_g = (_f = (_e = session.shipping_details) === null || _e === void 0 ? void 0 : _e.address) === null || _f === void 0 ? void 0 : _f.country) !== null && _g !== void 0 ? _g : "ES";
    const zonaEnvio = _zonaDesde(paisDestinatario);
    let opcionEnvio;
    if (zonaEnvio !== "es") {
        opcionEnvio = zonaEnvio; // "europa" | "latam" | "mundo"
    }
    else if (gastosEnvioEuros === 0) {
        opcionEnvio = "gratuito";
    }
    else if (gastosEnvioEuros >= 6) {
        opcionEnvio = "urgente";
    }
    else {
        opcionEnvio = "ordinario";
    }
    const clienteNombre = ((_h = session.customer_details) === null || _h === void 0 ? void 0 : _h.name) || "Cliente web";
    const clienteEmail = ((_j = session.customer_details) === null || _j === void 0 ? void 0 : _j.email) || null;
    const clienteTelefono = ((_k = session.customer_details) === null || _k === void 0 ? void 0 : _k.phone) || null;
    const direccionEnvio = _formatearDireccion(session.shipping_details);
    // ── Line items desde Stripe (expande nombre real, cantidad, precio) ──────────
    const stripeKey = session.livemode ? stripeSecretKey.value() : stripeSecretKeyTest.value();
    const stripeInst = new stripe_1.default(stripeKey, { apiVersion: "2024-06-20" });
    let lineas = [];
    try {
        const items = await stripeInst.checkout.sessions.listLineItems(session.id, { limit: 100, expand: ["data.price.product"] });
        lineas = items.data.map(item => {
            var _a, _b, _c, _d, _e, _f;
            const prod = (_a = item.price) === null || _a === void 0 ? void 0 : _a.product;
            const catId = ((_b = prod === null || prod === void 0 ? void 0 : prod.metadata) === null || _b === void 0 ? void 0 : _b.catalogo_id) || libroId;
            const titulo = (prod === null || prod === void 0 ? void 0 : prod.name) || item.description || ((_c = session.metadata) === null || _c === void 0 ? void 0 : _c.libro_titulo) || "Libro";
            const precioUnitario = (((_e = (_d = item.price) === null || _d === void 0 ? void 0 : _d.unit_amount) !== null && _e !== void 0 ? _e : 0) / 100) / 1.04;
            return {
                libro_id: catId,
                producto_nombre: titulo,
                descripcion: `${titulo} — venta online Editorial Nazarí`,
                cantidad: (_f = item.quantity) !== null && _f !== void 0 ? _f : 1,
                precio_unitario: parseFloat(precioUnitario.toFixed(2)),
                porcentaje_iva: 4, // IVA superreducido libros España
            };
        });
    }
    catch (_) {
        // Fallback: usar metadata del payment link
        const titulo = ((_l = session.metadata) === null || _l === void 0 ? void 0 : _l.libro_titulo) || "Libro";
        lineas = [{
                libro_id: libroId,
                producto_nombre: titulo,
                descripcion: `${titulo} — venta online Editorial Nazarí`,
                cantidad: 1,
                precio_unitario: parseFloat((totalEuros / 1.04).toFixed(2)),
                porcentaje_iva: 4,
            }];
    }
    const baseImponible = parseFloat(lineas.reduce((s, l) => s + l.precio_unitario * l.cantidad, 0).toFixed(2));
    // importeIva solo sobre los libros (IVA 4% superreducido); no incluye el envío
    const importeIva = parseFloat((totalProductosEuros - baseImponible).toFixed(2));
    // ── Número de ticket correlativo ──────────────────────────────────────────
    const contadorRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("contadores").doc("tickets");
    let numTicket = 1;
    const contSnap = await contadorRef.get();
    numTicket = contSnap.exists ? ((_o = (_m = contSnap.data()) === null || _m === void 0 ? void 0 : _m.ultimo) !== null && _o !== void 0 ? _o : 0) + 1 : 1;
    await contadorRef.set({ ultimo: numTicket }, { merge: true });
    // ── Crear pedido ──────────────────────────────────────────────────────────
    const pedidoData = {
        empresa_id: NAZARI_EMPRESA_ID,
        numero_ticket: numTicket,
        cliente_nombre: clienteNombre,
        cliente_correo: clienteEmail,
        cliente_telefono: clienteTelefono,
        direccion_envio: direccionEnvio,
        origen: "web_nazari",
        estado: "pendiente",
        estado_pago: "pagado",
        metodo_pago: "tarjeta",
        lineas,
        subtotal: baseImponible,
        importe_iva: importeIva,
        total_productos: totalProductosEuros,
        gastos_envio: gastosEnvioEuros,
        opcion_envio: opcionEnvio,
        zona_envio: zonaEnvio,
        pais_destino: paisDestinatario,
        es_preventa: ((_p = session.metadata) === null || _p === void 0 ? void 0 : _p.es_preventa) === "true",
        total: totalEuros,
        stripe_session_id: session.id,
        stripe_payment_intent: typeof session.payment_intent === "string" ? session.payment_intent : null,
        livemode: session.livemode,
        notas_internas: `Compra online via Stripe ${modoLabel}. Session: ${session.id}`,
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    const pedidoRef = await db
        .collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("pedidos").add(pedidoData);
    console.log(`✅ [NAZARI-${modoLabel}] Pedido #${numTicket} (${pedidoRef.id}) — ${clienteNombre} — €${totalEuros}`);
    // ── Notificación en bandeja + push FCM ────────────────────────────────────
    const cuerpoNotif = `${clienteNombre} — €${totalEuros.toFixed(2)} (web Editorial Nazarí)`;
    try {
        await db.collection("notificaciones").doc(NAZARI_EMPRESA_ID).collection("items").add({
            titulo: "📦 Nuevo Pedido Web",
            cuerpo: cuerpoNotif,
            tipo: "pedidoNuevo",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "pedidos",
            entidad_id: pedidoRef.id,
            remitente_nombre: clienteNombre !== "Cliente online" ? clienteNombre : null,
            remitente_email: clienteEmail,
        });
        await (0, notificaciones_1.enviarNotificacionEmpresa)(NAZARI_EMPRESA_ID, "📦 Nuevo Pedido Web", cuerpoNotif, { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "web_nazari" });
    }
    catch (e) {
        console.warn(`⚠️ [NAZARI-${modoLabel}] Error enviando notificación:`, e);
    }
    // ── Descontar stock en colección libros ───────────────────────────────────
    for (const linea of lineas) {
        if (!linea.libro_id)
            continue;
        try {
            await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
                .collection("libros").doc(linea.libro_id)
                .update({ stock: admin.firestore.FieldValue.increment(-linea.cantidad) });
            console.log(`📦 [NAZARI-${modoLabel}] Stock decrementado: ${linea.producto_nombre} -${linea.cantidad}`);
        }
        catch (_) { /* libro sin campo stock — ignorar */ }
    }
    // ── Email de confirmación al cliente ──────────────────────────────────────
    if (clienteEmail) {
        try {
            const lineasHtml = lineas.map(l => `<tr><td style="padding:6px 0;">${l.producto_nombre}</td><td style="text-align:right;padding:6px 0;">${l.cantidad}x ${l.precio_unitario.toFixed(2)} €</td></tr>`).join("");
            await (0, resend_service_1.enviarPdfGenerico)({
                from: "Editorial Nazarí <noreply@fluixtech.com>",
                to: clienteEmail,
                subject: `✅ Pedido #${numTicket} confirmado — Editorial Nazarí`,
                html: `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
            <h2 style="color:#1B5E20;">¡Pedido recibido!</h2>
            <p>Hola ${clienteNombre}, hemos recibido tu pedido correctamente.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0;">${lineasHtml}</table>
            <p style="font-size:18px;font-weight:bold;text-align:right;">Total: ${totalEuros.toFixed(2)} €</p>
            <p style="color:#555;">IVA incluido (4% libros). Te enviaremos el libro a la dirección indicada.</p>
            <p style="color:#999;font-size:11px;">— Editorial Nazarí · noreply@fluixtech.com</p>
          </div>`,
            });
            console.log(`📧 [NAZARI-${modoLabel}] Email enviado a ${clienteEmail}`);
        }
        catch (e) {
            console.warn(`⚠️ [NAZARI-${modoLabel}] No se pudo enviar email:`, e);
        }
    }
}
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
// ── BLOG: Publicar posts programados (cada 15 min) ────────────────────────────
var schedulerBlog_1 = require("./schedulerBlog");
Object.defineProperty(exports, "publicarPostsProgramados", { enumerable: true, get: function () { return schedulerBlog_1.publicarPostsProgramados; } });
var blogApi_1 = require("./blogApi");
Object.defineProperty(exports, "getBlogEntry", { enumerable: true, get: function () { return blogApi_1.getBlogEntry; } });
Object.defineProperty(exports, "getBlogLista", { enumerable: true, get: function () { return blogApi_1.getBlogLista; } });
// ── GESTIÓN DE CUENTAS Y SUSCRIPCIONES (sin pasar por Apple/Google) ──────────
var gestionCuentas_1 = require("./gestionCuentas");
Object.defineProperty(exports, "crearCuentaConPlan", { enumerable: true, get: function () { return gestionCuentas_1.crearCuentaConPlan; } });
Object.defineProperty(exports, "actualizarPlanEmpresa", { enumerable: true, get: function () { return gestionCuentas_1.actualizarPlanEmpresa; } });
Object.defineProperty(exports, "listarCuentasClientes", { enumerable: true, get: function () { return gestionCuentas_1.listarCuentasClientes; } });
Object.defineProperty(exports, "webhookPagoWeb", { enumerable: true, get: function () { return gestionCuentas_1.webhookPagoWeb; } });
// ── CATÁLOGO PÚBLICO — endpoint para webs de clientes ────────────────────────
//
// La web del cliente (ej: Nazari) puede llamar a:
//   GET https://europe-west1-planeaapp-4bea4.cloudfunctions.net/catalogoPublico?empresa_id=XXX
// para obtener el catálogo en JSON, respetando precio_web si existe.
// Respeta CORS para dominios configurados en Firestore (empresa.sitio_web).
//
exports.catalogoPublico = (0, https_1.onRequest)({ region: REGION }, async (req, res) => {
    var _a;
    const empresaId = req.query.empresa_id;
    if (!empresaId) {
        res.status(400).json({ error: "empresa_id requerido" });
        return;
    }
    // Verificar empresa y dominios permitidos
    try {
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        if (!empresaDoc.exists) {
            res.status(404).json({ error: "Empresa no encontrada" });
            return;
        }
        const sitioWeb = (_a = empresaDoc.data()) === null || _a === void 0 ? void 0 : _a.sitio_web;
        const origen = req.headers.origin;
        if (sitioWeb && origen) {
            // Permitir solo el dominio configurado + localhost para desarrollo
            const dominioPermitido = sitioWeb.replace(/^https?:\/\//, '').split('/')[0];
            if (!origen.includes(dominioPermitido) && !origen.includes('localhost')) {
                res.setHeader("Access-Control-Allow-Origin", sitioWeb);
            }
            else {
                res.setHeader("Access-Control-Allow-Origin", origen);
            }
        }
        else {
            res.setHeader("Access-Control-Allow-Origin", "*");
        }
    }
    catch (_) {
        res.setHeader("Access-Control-Allow-Origin", "*");
    }
    if (req.method === "OPTIONS") {
        res.setHeader("Access-Control-Allow-Methods", "GET");
        res.setHeader("Access-Control-Allow-Headers", "Content-Type");
        res.status(204).send("");
        return;
    }
    try {
        const snap = await db
            .collection("empresas").doc(empresaId)
            .collection("catalogo")
            .where("activo", "==", true)
            .get();
        const productos = snap.docs.map(d => {
            var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
            const data = d.data();
            const precioTienda = (_a = data.precio) !== null && _a !== void 0 ? _a : 0;
            const precioWeb = data.precio_web;
            return {
                id: d.id,
                nombre: (_b = data.nombre) !== null && _b !== void 0 ? _b : "",
                descripcion: (_c = data.descripcion) !== null && _c !== void 0 ? _c : "",
                categoria: (_d = data.categoria) !== null && _d !== void 0 ? _d : "",
                precio: precioWeb !== null && precioWeb !== void 0 ? precioWeb : precioTienda, // precio_web tiene prioridad
                precio_tienda: precioTienda,
                tiene_precio_web: !!precioWeb,
                imagen_url: (_f = (_e = data.imagen_url) !== null && _e !== void 0 ? _e : data.thumbnail_url) !== null && _f !== void 0 ? _f : null,
                iva_porcentaje: (_g = data.iva_porcentaje) !== null && _g !== void 0 ? _g : 21,
                stock: (_h = data.stock) !== null && _h !== void 0 ? _h : null,
                codigo_barras: (_j = data.codigo_barras) !== null && _j !== void 0 ? _j : null,
                destacado: (_k = data.destacado) !== null && _k !== void 0 ? _k : false,
                // catalogo_id incluido para que el checkout de Stripe pueda descuentar stock
                catalogo_id: d.id,
            };
        });
        res.setHeader("Cache-Control", "public, max-age=60"); // cache 1 min
        res.status(200).json({ productos, total: productos.length });
    }
    catch (e) {
        console.error("Error obteniendo catálogo público:", e);
        res.status(500).json({ error: "Error interno" });
    }
});
// ── ALERTA DE STOCK BAJO ──────────────────────────────────────────────────────
//
// Se dispara cuando se actualiza el campo `stock` de un producto del catálogo.
// Si el stock nuevo <= stock_minimo, envía email al propietario de la empresa.
// Se ignora si stock_minimo es 0 (sin control de stock configurado).
//
exports.alertaStockBajo = (0, firestore_1.onDocumentUpdated)("empresas/{empresaId}/catalogo/{productoId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const stockAntes = (_c = before === null || before === void 0 ? void 0 : before.stock) !== null && _c !== void 0 ? _c : -1;
    const stockAhora = (_d = after === null || after === void 0 ? void 0 : after.stock) !== null && _d !== void 0 ? _d : -1;
    const stockMinimo = (_e = after === null || after === void 0 ? void 0 : after.stock_minimo) !== null && _e !== void 0 ? _e : 0;
    // Solo actuar si el stock bajó y hay stock_minimo configurado
    if (stockAhora < 0 || stockMinimo <= 0)
        return;
    if (stockAhora >= stockMinimo || stockAhora >= stockAntes)
        return;
    // Solo enviar la primera vez que cruce el umbral (no en cada venta)
    if (stockAntes <= stockMinimo)
        return;
    const empresaId = event.params.empresaId;
    const nombreProd = (_f = after === null || after === void 0 ? void 0 : after.nombre) !== null && _f !== void 0 ? _f : "Producto";
    const categoria = (_g = after === null || after === void 0 ? void 0 : after.categoria) !== null && _g !== void 0 ? _g : "";
    // Obtener email del propietario
    let emailPropietario = null;
    let nombreEmpresa = "Tu tienda";
    try {
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        const eData = (_h = empresaDoc.data()) !== null && _h !== void 0 ? _h : {};
        nombreEmpresa = (_j = eData.nombre) !== null && _j !== void 0 ? _j : nombreEmpresa;
        // Buscar el propietario en la empresa
        const usuariosSnap = await db.collection("usuarios")
            .where("empresa_id", "==", empresaId)
            .where("rol", "in", ["propietario", "admin"])
            .limit(1).get();
        if (!usuariosSnap.empty) {
            emailPropietario = (_k = usuariosSnap.docs[0].data().email) !== null && _k !== void 0 ? _k : null;
        }
    }
    catch (_) { }
    if (!emailPropietario) {
        console.warn(`⚠️ alertaStockBajo: no se encontró email para empresa ${empresaId}`);
        return;
    }
    const alertaHtml = `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;">
        <div style="background:#FFF3E0;border-left:4px solid #FF9800;padding:16px;border-radius:8px;">
          <h2 style="color:#E65100;margin:0 0 8px;">⚠️ Stock bajo: ${nombreProd}</h2>
          <p style="margin:4px 0;color:#333;">
            <strong>Stock actual:</strong> ${stockAhora} unidades (mínimo: ${stockMinimo})
          </p>
          ${categoria ? `<p style="margin:4px 0;color:#666;font-size:13px;">Categoría: ${categoria}</p>` : ""}
        </div>
        <p style="margin:16px 0;color:#555;">
          Es posible que necesites reponer existencias pronto.
          Puedes actualizar el stock desde el TPV de ${nombreEmpresa}.
        </p>
        <p style="color:#999;font-size:11px;">— ${nombreEmpresa} · Alertas automáticas PlaneaG</p>
      </div>
    `;
    try {
        await (0, resend_service_1.enviarPdfGenerico)({
            from: `${nombreEmpresa} <noreply@fluixtech.com>`,
            to: emailPropietario,
            subject: `⚠️ Stock bajo: ${nombreProd} (${stockAhora} uds.) — ${nombreEmpresa}`,
            html: alertaHtml,
        });
        console.log(`📉 Alerta stock bajo enviada: ${nombreProd} (${stockAhora}) → ${emailPropietario}`);
    }
    catch (e) {
        console.error("Error enviando alerta de stock:", e);
    }
});
// ── STRIPE WEBHOOK — PEDIDOS DE TIENDA DE CLIENTES ────────────────────────────
//
// Cómo funciona:
//  1. La web del cliente (ej: Editorial Nazari) crea un Stripe Checkout Session
//     incluyendo en metadata: { empresa_id: "ID_EN_PLANEAG", tipo: "pedido_tienda" }
//  2. Stripe llama a este endpoint al completarse el pago
//  3. La función crea el pedido en Firestore y descuenta el stock del catálogo
//
// Configuración (una sola vez por cliente):
//  a) En el dashboard de Stripe del cliente: Developers → Webhooks → Add endpoint
//     URL: https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhookTienda
//     Events: checkout.session.completed
//  b) Copiar el "Signing secret" del webhook y guardarlo en functions/.env como
//     STRIPE_TIENDA_WEBHOOK_SECRET (o reutilizar STRIPE_WEBHOOK_SECRET)
//  c) En la web del cliente añadir empresa_id y tipo a los metadatos del session:
//     metadata: { empresa_id: "XXXXX", tipo: "pedido_tienda" }
//
exports.stripeWebhookTienda = (0, https_1.onRequest)({ region: REGION }, async (req, res) => {
    var _a, _b, _c;
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    const liveKey = stripeSecretKey.value() || "";
    const testKey = stripeSecretKeyTest.value() || "";
    const liveSec = stripeTiendaWebhookSecret.value() || "";
    const testSec = stripeWebhookSecretTest.value() || "";
    const sig = req.headers["stripe-signature"];
    const rawBody = (_a = req.rawBody) !== null && _a !== void 0 ? _a : Buffer.from(JSON.stringify(req.body));
    if (!sig) {
        res.status(400).json({ error: "Firma ausente" });
        return;
    }
    let event;
    let isTestEvent = false;
    const verifier = new stripe_1.default(liveKey || testKey, { apiVersion: "2024-06-20" });
    let verified = false;
    if (liveSec) {
        try {
            event = verifier.webhooks.constructEvent(rawBody, sig, liveSec);
            verified = true;
        }
        catch (_) { }
    }
    if (!verified && testSec) {
        try {
            event = verifier.webhooks.constructEvent(rawBody, sig, testSec);
            verified = true;
            isTestEvent = true;
        }
        catch (_) { }
    }
    if (!verified) {
        console.error("❌ Firma inválida en stripeWebhookTienda");
        res.status(400).json({ error: "Firma inválida" });
        return;
    }
    const stripe = new stripe_1.default(isTestEvent ? (testKey || liveKey) : liveKey, { apiVersion: "2024-06-20" });
    console.log(`📥 [stripeWebhookTienda] ${event.type} modo=${isTestEvent ? "TEST" : "LIVE"}`);
    // ── IDEMPOTENCIA ATÓMICA ───────────────────────────────────────────────────
    // Usamos create() (no set/get) para "reclamar" el evento. Firestore garantiza
    // que solo UNA petición concurrente puede crear el documento; las demás reciben
    // ALREADY_EXISTS (código gRPC 6) y terminan sin crear pedido duplicado.
    const eventDocRef = db.collection("stripe_processed_events").doc(`tienda_${event.id}`);
    try {
        await eventDocRef.create({
            event_id: event.id,
            event_type: event.type,
            claimed_at: new Date().toISOString(),
        });
    }
    catch (claimErr) {
        if ((claimErr === null || claimErr === void 0 ? void 0 : claimErr.code) === 6) {
            // ALREADY_EXISTS — otro proceso ya reclamó este evento
            console.log(`⏭️ Evento tienda ${event.id} ya reclamado/procesado`);
            res.status(200).json({ received: true, duplicado: true });
            return;
        }
        // Error inesperado al reclamar — dejar que Stripe reintente
        console.error("❌ Error reclamando evento tienda:", claimErr);
        res.status(500).json({ error: "Error interno" });
        return;
    }
    try {
        if (event.type === "checkout.session.completed") {
            const session = event.data.object;
            const empresaId = ((_b = session.metadata) === null || _b === void 0 ? void 0 : _b.empresa_id) || "";
            const tipo = ((_c = session.metadata) === null || _c === void 0 ? void 0 : _c.tipo) || "";
            if (tipo === "pedido_nazari" || empresaId === NAZARI_EMPRESA_ID) {
                await _procesarPedidoNazari(session, db);
            }
            else if (empresaId && tipo === "pedido_tienda") {
                await _procesarPedidoTienda(session, stripe, empresaId, db);
            }
            else {
                // Sin metadata → Payment Link de Nazarí sin tipo configurado.
                // Este webhook es exclusivo de Nazarí, por lo que tratamos la sesión como suya.
                console.log(`ℹ️ [stripeWebhookTienda] Sin metadata tipo/empresa — procesando como pedido Nazarí. Session: ${session.id}`);
                await _procesarPedidoNazari(session, db);
            }
        }
        // Marcar como completado (el claim ya existe; update para añadir ts de fin)
        await eventDocRef.update({ procesado: true, ts: admin.firestore.FieldValue.serverTimestamp() });
        res.status(200).json({ received: true, tipo: event.type });
    }
    catch (error) {
        console.error("❌ Error en stripeWebhookTienda:", error);
        res.status(500).json({ error: "Error interno procesando pedido de tienda" });
    }
});
async function _procesarPedidoTienda(session, stripe, empresaId, db) {
    var _a, _b, _c, _d, _e, _f, _g;
    // ── Datos del cliente ──────────────────────────────────────────────────────
    const clienteNombre = ((_a = session.customer_details) === null || _a === void 0 ? void 0 : _a.name) || "Cliente online";
    const clienteEmail = ((_b = session.customer_details) === null || _b === void 0 ? void 0 : _b.email) || null;
    const clienteTelefono = ((_c = session.customer_details) === null || _c === void 0 ? void 0 : _c.phone) || null;
    const direccionEnvio = _formatearDireccion(session.shipping_details);
    // ── Importe total ──────────────────────────────────────────────────────────
    const totalEuros = ((_d = session.amount_total) !== null && _d !== void 0 ? _d : 0) / 100;
    // ── Line items de Stripe ──────────────────────────────────────────────────
    // Expandimos para obtener la info completa de cada ítem
    let lineas = [];
    try {
        const lineItems = await stripe.checkout.sessions.listLineItems(session.id, { limit: 100, expand: ["data.price.product"] });
        lineas = lineItems.data.map((item) => {
            var _a, _b, _c, _d, _e, _f, _g;
            const prod = (_a = item.price) === null || _a === void 0 ? void 0 : _a.product;
            const stripeProductId = (_b = prod === null || prod === void 0 ? void 0 : prod.id) !== null && _b !== void 0 ? _b : "";
            // El metadata del producto puede incluir el catalogo_id de PlaneaG
            const catalogoId = (_d = (_c = prod === null || prod === void 0 ? void 0 : prod.metadata) === null || _c === void 0 ? void 0 : _c.catalogo_id) !== null && _d !== void 0 ? _d : "";
            return {
                productoId: catalogoId || `stripe_${stripeProductId}`,
                nombre: (prod === null || prod === void 0 ? void 0 : prod.name) || item.description || "Producto",
                cantidad: (_e = item.quantity) !== null && _e !== void 0 ? _e : 1,
                precioUnitario: (((_g = (_f = item.price) === null || _f === void 0 ? void 0 : _f.unit_amount) !== null && _g !== void 0 ? _g : 0) / 100),
                stripeProductId,
            };
        });
    }
    catch (e) {
        console.warn("⚠️ No se pudieron obtener line items de Stripe:", e);
        // Fallback: creamos una línea resumen con el total
        lineas = [{
                productoId: `stripe_${session.id}`,
                nombre: "Pedido online",
                cantidad: 1,
                precioUnitario: totalEuros,
            }];
    }
    // ── Calcular número de ticket correlativo ─────────────────────────────────
    const contadorRef = db.collection("empresas").doc(empresaId).collection("contadores").doc("tickets");
    let numTicket = 1;
    const contSnap = await contadorRef.get();
    numTicket = contSnap.exists ? ((_f = (_e = contSnap.data()) === null || _e === void 0 ? void 0 : _e.ultimo) !== null && _f !== void 0 ? _f : 0) + 1 : 1;
    await contadorRef.set({ ultimo: numTicket }, { merge: true });
    // ── Crear pedido en Firestore ─────────────────────────────────────────────
    const pedidoData = {
        empresa_id: empresaId,
        numero_ticket: numTicket,
        cliente_nombre: clienteNombre,
        cliente_email: clienteEmail,
        cliente_telefono: clienteTelefono,
        direccion_envio: direccionEnvio,
        origen: "tienda_online",
        estado: "pendiente",
        estado_pago: "pagado",
        metodo_pago: "tarjeta",
        lineas: lineas.map((l) => ({
            producto_id: l.productoId,
            producto_nombre: l.nombre,
            cantidad: l.cantidad,
            precio_unitario: l.precioUnitario,
            iva_porcentaje: 21,
        })),
        subtotal: parseFloat((totalEuros / 1.21).toFixed(2)),
        importe_iva: parseFloat((totalEuros - totalEuros / 1.21).toFixed(2)),
        total: totalEuros,
        stripe_session_id: session.id,
        stripe_payment_intent: session.payment_intent,
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    };
    const pedidoRef = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("pedidos")
        .add(pedidoData);
    console.log(`✅ [TIENDA] Pedido #${numTicket} creado para empresa ${empresaId} — ${clienteNombre} — €${totalEuros} — id: ${pedidoRef.id}`);
    // ── Notificación en bandeja + push FCM ────────────────────────────────────
    const cuerpoNotifTienda = `${clienteNombre} — €${totalEuros.toFixed(2)} (tienda online)`;
    try {
        await db.collection("notificaciones").doc(empresaId).collection("items").add({
            titulo: "📦 Nuevo Pedido Web",
            cuerpo: cuerpoNotifTienda,
            tipo: "pedidoNuevo",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "pedidos",
            entidad_id: pedidoRef.id,
            remitente_nombre: clienteNombre !== "Cliente online" ? clienteNombre : null,
            remitente_email: clienteEmail,
        });
        await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "📦 Nuevo Pedido Web", cuerpoNotifTienda, { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "tienda_online" });
    }
    catch (e) {
        console.warn("⚠️ [TIENDA] Error enviando notificación:", e);
    }
    // ── Descontar stock (catalogo, catalogo_web y libros) ────────────────────
    for (const linea of lineas) {
        if (!linea.productoId || linea.productoId.startsWith("stripe_"))
            continue;
        const decremento = admin.firestore.FieldValue.increment(-linea.cantidad);
        const base = db.collection("empresas").doc(empresaId);
        // Intentar en las tres colecciones posibles; cada una puede o no existir
        for (const col of ["catalogo", "catalogo_web", "libros"]) {
            try {
                await base.collection(col).doc(linea.productoId).update({ stock: decremento });
                console.log(`📦 Stock ${col} decrementado: ${linea.nombre} -${linea.cantidad}`);
            }
            catch (_) { /* no existe en esta colección — silencioso */ }
        }
    }
    // ── Email de confirmación al cliente ─────────────────────────────────────
    if (clienteEmail) {
        try {
            const empresaDoc = await db.collection("empresas").doc(empresaId).get();
            const nombreEmpresa = ((_g = empresaDoc.data()) === null || _g === void 0 ? void 0 : _g.nombre) || "La tienda";
            const lineasHtml = lineas.map((l) => `<tr><td style="padding:6px 0;">${l.nombre}</td><td style="text-align:right;padding:6px 0;">${l.cantidad}x ${l.precioUnitario.toFixed(2)} €</td></tr>`).join("");
            await (0, resend_service_1.enviarPdfGenerico)({
                from: `${nombreEmpresa} <noreply@fluixtech.com>`,
                to: clienteEmail,
                subject: `✅ Pedido #${numTicket} confirmado — ${nombreEmpresa}`,
                html: `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
            <h2 style="color:#1B5E20;">¡Pedido recibido!</h2>
            <p>Hola ${clienteNombre}, hemos recibido tu pedido correctamente.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0;">${lineasHtml}</table>
            <p style="font-size:18px;font-weight:bold;">Total: ${totalEuros.toFixed(2)} €</p>
            ${direccionEnvio ? `<p>📦 Envío a: ${direccionEnvio}</p>` : ""}
            <p>Te avisaremos cuando tu pedido esté preparado.</p>
            <p style="color:#999;font-size:12px;">Pedido #${numTicket} · ${nombreEmpresa}</p>
          </div>
        `,
            });
        }
        catch (e) {
            console.warn("⚠️ Error enviando email de confirmación:", e);
        }
    }
}
function _formatearDireccion(shipping) {
    if (!(shipping === null || shipping === void 0 ? void 0 : shipping.address))
        return null;
    const a = shipping.address;
    return [shipping.name, a.line1, a.line2, a.postal_code, a.city, a.country]
        .filter(Boolean)
        .join(", ");
}
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
            await (0, notificaciones_1.enviarNotificacionEmpresa)(empresaId, "⚠️ Alerta de cobertura", mensaje, { tipo: "alerta_cobertura" });
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
// ──────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: Enviar emails de contacto de interés (login público)
// ──────────────────────────────────────────────────────────────────────────────
exports.enviarEmailsContactoInteres = (0, https_1.onCall)({ region: REGION }, async (request) => {
    const data = request.data;
    // Importar funciones de Resend
    const { enviarConfirmacionContactoInteres, enviarNotificacionContactoInteres, } = await Promise.resolve().then(() => __importStar(require("./resend_service")));
    try {
        // 1. Email de confirmación al usuario
        const resultadoConfirmacion = await enviarConfirmacionContactoInteres({
            to: data.correo,
            nombre: data.nombre,
            correo: data.correo,
            telefono: data.telefono,
            nombreEmpresa: data.nombreEmpresa,
            actividad: data.actividad,
            numTrabajadores: data.numTrabajadores,
        });
        // 2. Email de notificación al propietario
        const resultadoNotificacion = await enviarNotificacionContactoInteres({
            nombre: data.nombre,
            correo: data.correo,
            telefono: data.telefono,
            nombreEmpresa: data.nombreEmpresa,
            actividad: data.actividad,
            numTrabajadores: data.numTrabajadores,
            leadId: data.leadId,
            fechaSolicitud: data.fechaSolicitud,
        });
        console.log("✅ Emails de contacto enviados:", {
            confirmacion: resultadoConfirmacion.exito,
            notificacion: resultadoNotificacion.exito,
        });
        return {
            exito: true,
            confirmacionEnviada: resultadoConfirmacion.exito,
            notificacionEnviada: resultadoNotificacion.exito,
        };
    }
    catch (error) {
        console.error("❌ Error enviando emails de contacto:", error);
        throw new https_1.HttpsError("internal", `Error enviando emails: ${error.message}`);
    }
});
const _PAISES_EUROPA = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "FI", "FR", "GR", "HR", "HU",
    "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO", "SE", "SI", "SK",
    "GB", "CH", "NO", "IS", "AL", "BA", "ME", "MK", "RS", "UA", "MD", "LI", "MC",
    "AD", "SM", "VA", "XK",
];
const _PAISES_LATAM = [
    "MX", "AR", "CL", "CO", "PE", "EC", "UY", "VE", "BO", "PY", "CR", "PA", "DO",
    "GT", "HN", "SV", "NI", "PR", "HT", "JM", "TT", "BB", "BS", "BZ", "GY", "SR",
];
const _PAISES_RESTO = [
    "US", "CA", "AU", "NZ", "JP", "KR", "CN", "IN", "SG", "HK", "TW", "ZA", "AE",
    "SA", "IL", "TR", "MA", "TN", "EG", "NG", "BR", "JO", "KW", "QA", "BH", "OM",
    "PH", "TH", "ID", "MY", "VN", "PK", "BD", "LK", "MM", "KZ", "UZ", "BY", "GE",
    "AM", "AZ", "KH", "NP", "RW", "TZ", "KE", "GH", "CI", "SN", "CM", "ET",
];
const _SET_EUROPA = new Set(_PAISES_EUROPA);
const _SET_LATAM = new Set(_PAISES_LATAM);
/** Devuelve la zona a partir del código de país ISO 3166-1 alpha-2. */
function _zonaDesde(pais) {
    if (pais === "ES")
        return "es";
    if (_SET_EUROPA.has(pais))
        return "europa";
    if (_SET_LATAM.has(pais))
        return "latam";
    return "mundo";
}
function _opcionesEnvioEuropa(pesoGramos) {
    const cents = pesoGramos < 500 ? 1500 : 2000;
    return [{
            shipping_rate_data: {
                type: "fixed_amount",
                fixed_amount: { amount: cents, currency: "eur" },
                display_name: `Envío Europa (7-14 días laborables) — ${(cents / 100).toFixed(0)}€`,
                delivery_estimate: {
                    minimum: { unit: "business_day", value: 7 },
                    maximum: { unit: "business_day", value: 14 },
                },
            },
        }];
}
function _opcionesEnvioLatam(pesoGramos) {
    const cents = pesoGramos < 500 ? 2000 : 2500;
    return [{
            shipping_rate_data: {
                type: "fixed_amount",
                fixed_amount: { amount: cents, currency: "eur" },
                display_name: `Envío Latinoamérica (10-21 días laborables) — ${(cents / 100).toFixed(0)}€`,
                delivery_estimate: {
                    minimum: { unit: "business_day", value: 10 },
                    maximum: { unit: "business_day", value: 21 },
                },
            },
        }];
}
function _opcionesEnvioMundo(pesoGramos) {
    const cents = pesoGramos < 500 ? 3000 : 3500;
    return [{
            shipping_rate_data: {
                type: "fixed_amount",
                fixed_amount: { amount: cents, currency: "eur" },
                display_name: `Envío internacional (14-30 días laborables) — ${(cents / 100).toFixed(0)}€`,
                delivery_estimate: {
                    minimum: { unit: "business_day", value: 14 },
                    maximum: { unit: "business_day", value: 30 },
                },
            },
        }];
}
// ─────────────────────────────────────────────────────────────────────────────
// crearCheckoutNazari — Crea una sesión de Stripe Checkout para la tienda web
//   de Editorial Nazarí y devuelve la URL de pago.
//
// POST body: { items: [{ catalogo_id, cantidad }], zona?: "ES"|"EU"|"LATAM"|"WORLD" }
// zona por defecto: "ES". El precio y peso se leen SIEMPRE desde Firestore.
// El cliente NO puede influir en el importe a cobrar.
// Respuesta: { url: "https://checkout.stripe.com/..." }
// ─────────────────────────────────────────────────────────────────────────────
const NAZARI_EMPRESA_ID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
// Secret para sincronizarLibroStripeTest — mover a STRIPE_SYNC_SECRET en .env
const STRIPE_SYNC_SECRET = (_a = process.env.STRIPE_SYNC_SECRET) !== null && _a !== void 0 ? _a : "fluix-stripe-test-2026";
/** Lee un item de catalogo_web y valida que está disponible para venta. */
async function _resolverItemCatalogoNazari(catalogoId) {
    var _a, _b, _c, _d, _e, _f, _g;
    const col = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("catalogo_web");
    let snap = await col.doc(catalogoId).get();
    // Fallback: buscar por campo 'slug' si el ID de doc no coincide
    if (!snap.exists) {
        const bySlug = await col.where("slug", "==", catalogoId).limit(1).get();
        if (!bySlug.empty)
            snap = bySlug.docs[0];
    }
    if (!snap.exists)
        throw new Error(`Producto no encontrado: ${catalogoId}`);
    const d = snap.data();
    if (d.activo === false)
        throw new Error(`Producto no disponible: ${catalogoId}`);
    const precioRaw = ((_a = d.precio) !== null && _a !== void 0 ? _a : "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
    const precioNum = Math.round(parseFloat(precioRaw || "0") * 100);
    if (isNaN(precioNum) || precioNum <= 0)
        throw new Error(`Precio inválido en ${catalogoId}: "${d.precio}"`);
    const pesoRaw = (_d = (_c = (_b = d.peso_gramos) !== null && _b !== void 0 ? _b : d.campo_peso) !== null && _c !== void 0 ? _c : d.peso) !== null && _d !== void 0 ? _d : "300";
    const pesoGramos = Math.max(1, parseInt(String(pesoRaw).replace(/[^0-9]/g, ""), 10) || 300);
    // Preventa: precio de envío lejano en céntimos (null si no configurado)
    const preventa = d.preventa === true || d.es_preventa === true;
    let preventaEnvioLejanoCents = null;
    if (preventa && d.preventa_envio_lejano != null) {
        const raw = String(d.preventa_envio_lejano).replace(",", ".").replace(/[^0-9.]/g, "");
        const euros = parseFloat(raw);
        if (!isNaN(euros) && euros > 0)
            preventaEnvioLejanoCents = Math.round(euros * 100);
    }
    return {
        nombre: ((_f = (_e = d.nombre) !== null && _e !== void 0 ? _e : d.titulo) !== null && _f !== void 0 ? _f : "Libro"),
        imagenUrl: ((_g = d.imagen_url) !== null && _g !== void 0 ? _g : ""),
        precioNum,
        precioStr: d.precio,
        pesoGramos,
        preventa,
        preventaEnvioLejanoCents,
    };
}
/**
 * Opciones de envío nacional (España) para Nazarí.
 * Reglas:
 *   - Total ≥ 30 €: Gratuito (ordinario) + Urgente. El peso no aplica.
 *   - Total < 30 €: Ordinario por peso (≤100g→1,50€ | ≤500g→2,50€ | ≤1000g→3,00€) + Urgente.
 *   - Urgente siempre 6 €, independiente del peso y el total.
 */
function _calcularOpcionesEnvioNazariES(totalProductosEuros, pesoGramos) {
    const urgente = {
        shipping_rate_data: {
            type: "fixed_amount",
            fixed_amount: { amount: 600, currency: "eur" },
            display_name: "Envío urgente (24-48h) — 6,00€",
            delivery_estimate: {
                minimum: { unit: "business_day", value: 1 },
                maximum: { unit: "business_day", value: 2 },
            },
        },
    };
    if (totalProductosEuros >= 30) {
        return [
            {
                shipping_rate_data: {
                    type: "fixed_amount",
                    fixed_amount: { amount: 0, currency: "eur" },
                    display_name: "Envío gratuito — Ordinario (3-5 días laborables)",
                    delivery_estimate: {
                        minimum: { unit: "business_day", value: 3 },
                        maximum: { unit: "business_day", value: 5 },
                    },
                },
            },
            urgente,
        ];
    }
    // <30€: precio ordinario según peso total del pedido
    let ordinarioCents;
    if (pesoGramos <= 100)
        ordinarioCents = 150;
    else if (pesoGramos <= 500)
        ordinarioCents = 250;
    else
        ordinarioCents = 300; // hasta 1 kg
    const precioStr = (ordinarioCents / 100).toFixed(2).replace(".", ",");
    return [
        {
            shipping_rate_data: {
                type: "fixed_amount",
                fixed_amount: { amount: ordinarioCents, currency: "eur" },
                display_name: `Envío ordinario (3-5 días laborables) — ${precioStr}€`,
                delivery_estimate: {
                    minimum: { unit: "business_day", value: 3 },
                    maximum: { unit: "business_day", value: 5 },
                },
            },
        },
        urgente,
    ];
}
// ── Helper: cliente Stripe configurado para Nazarí (TEST o LIVE) ──────────────
// Devuelve el cliente Stripe con la clave correcta para el modo indicado.
// Si existe stripe_account_id en integraciones/stripe (Stripe Connect) lo usa;
// de lo contrario opera directamente sobre la cuenta cuya clave está configurada.
async function getNazariStripeConfig(isTest) {
    var _a, _b;
    const key = isTest ? stripeSecretKeyTest.value() : stripeSecretKey.value();
    const mode = isTest ? "TEST" : "LIVE";
    if (!key)
        throw new Error(`STRIPE_SECRET_KEY${isTest ? "_TEST" : ""} no configurada — añádela a functions/.env`);
    const stripe = new stripe_1.default(key, { apiVersion: "2024-06-20" });
    // Stripe Connect opcional: si existe stripe_account_id lo usamos;
    // si no, operamos directamente (connOpts = undefined, no pasar al SDK).
    let connOpts;
    let stripeAccountId = "";
    try {
        const integSnap = await db
            .collection("empresas").doc(NAZARI_EMPRESA_ID)
            .collection("integraciones").doc("stripe").get();
        stripeAccountId = (_b = (_a = integSnap.data()) === null || _a === void 0 ? void 0 : _a.stripe_account_id) !== null && _b !== void 0 ? _b : "";
        if (stripeAccountId)
            connOpts = { stripeAccount: stripeAccountId };
    }
    catch (_) { /* sin doc de integración — operar directamente */ }
    const acctLabel = stripeAccountId ? ` / Connect: ${stripeAccountId}` : " / cuenta directa";
    console.log(`🔑 [${mode}${acctLabel}] Stripe config lista`);
    return { stripe, connOpts, mode, stripeAccountId };
}
// ── CORS compartido para funciones públicas de Editorial Nazarí ───────────────
const _NAZARI_CORS = [
    "https://www.editorialnazari.com",
    "https://editorialnazari.com",
    "https://seashell-boar-580681.hostingersite.com",
    /^https?:\/\/.*\.hostingersite\.com$/,
    /^http:\/\/localhost(:\d+)?$/, // localhost con cualquier puerto (Live Server, etc.)
    "null", // origen file:// para pruebas locales
];
// ─────────────────────────────────────────────────────────────────────────────
// recomendacionesNazari — Ventas cruzadas por autor
//
// GET/POST ?catalogo_ids=id1,id2   (IDs del carrito actual, separados por coma)
// Devuelve hasta 6 libros activos del mismo autor que NO estén ya en el carrito.
// ─────────────────────────────────────────────────────────────────────────────
exports.recomendacionesNazari = (0, https_1.onRequest)({ region: REGION, cors: _NAZARI_CORS }, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v;
    const rawParam = (_f = (_d = (_b = (_a = req.query.catalogo_ids) !== null && _a !== void 0 ? _a : req.query.catalogo_id) !== null && _b !== void 0 ? _b : (_c = req.body) === null || _c === void 0 ? void 0 : _c.catalogo_ids) !== null && _d !== void 0 ? _d : (_e = req.body) === null || _e === void 0 ? void 0 : _e.catalogo_id) !== null && _f !== void 0 ? _f : "";
    const catalogoIds = rawParam
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
        .slice(0, 20);
    // Autores enviados directamente desde el carrito (más fiable que el lookup por ID)
    const autoresParam = (Array.isArray(req.query.autor)
        ? req.query.autor
        : req.query.autor ? [req.query.autor] : []).map((s) => s.trim()).filter(Boolean);
    if (!catalogoIds.length && !autoresParam.length) {
        res.status(400).json({ error: "Se requiere catalogo_ids o autor" });
        return;
    }
    const col = db
        .collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("catalogo_web");
    const autores = new Set();
    const excluidos = new Set(catalogoIds);
    // 1. Usar autores del parámetro si vienen (camino rápido, sin lookup en Firestore)
    autoresParam.forEach(a => autores.add(a));
    // 2. Si no vinieron autores en el parámetro, buscar en Firestore por doc ID o slug
    if (!autores.size && catalogoIds.length) {
        const carritoDocs = await Promise.all(catalogoIds.map(id => col.doc(id).get()));
        const idsNoEncontrados = [];
        for (let i = 0; i < carritoDocs.length; i++) {
            const snap = carritoDocs[i];
            if (!snap.exists) {
                idsNoEncontrados.push(catalogoIds[i]);
                continue;
            }
            const d = snap.data();
            const a = ((_j = (_h = (_g = d.campo_autor) !== null && _g !== void 0 ? _g : d.autor) !== null && _h !== void 0 ? _h : d.nombre_autor) !== null && _j !== void 0 ? _j : "").trim();
            if (a)
                autores.add(a);
        }
        // Fallback por campo slug
        if (idsNoEncontrados.length > 0) {
            const slugSnap = await col
                .where("slug", "in", idsNoEncontrados.slice(0, 30))
                .get();
            for (const doc of slugSnap.docs) {
                const d = doc.data();
                const a = ((_m = (_l = (_k = d.campo_autor) !== null && _k !== void 0 ? _k : d.autor) !== null && _l !== void 0 ? _l : d.nombre_autor) !== null && _m !== void 0 ? _m : "").trim();
                if (a)
                    autores.add(a);
                excluidos.add(doc.id);
            }
        }
    }
    if (!autores.size) {
        res.status(200).json({ libros: [], autores: [] });
        return;
    }
    // Normalizar autor para comparación case-insensitive y sin tildes
    const norm = (s) => s.toLowerCase()
        .normalize("NFD")
        .replace(/[̀-ͯ]/g, "")
        .replace(/\s+/g, " ")
        .trim();
    const autoresNorm = new Set([...autores].map(norm));
    // Leer todos los libros y filtrar en memoria
    // (no where("activo","==",true) porque docs sin el campo deben incluirse)
    const todosSnap = await col.get();
    const recomendaciones = [];
    for (const doc of todosSnap.docs) {
        if (recomendaciones.length >= 6)
            break;
        if (excluidos.has(doc.id))
            continue;
        const d = doc.data();
        if (d.activo === false)
            continue;
        const autorDoc = ((_q = (_p = (_o = d.campo_autor) !== null && _o !== void 0 ? _o : d.autor) !== null && _p !== void 0 ? _p : d.nombre_autor) !== null && _q !== void 0 ? _q : "").trim();
        if (!autoresNorm.has(norm(autorDoc)))
            continue;
        recomendaciones.push({
            catalogo_id: doc.id,
            nombre: ((_s = (_r = d.nombre) !== null && _r !== void 0 ? _r : d.titulo) !== null && _s !== void 0 ? _s : "Libro"),
            autor: autorDoc,
            precio: ((_t = d.precio) !== null && _t !== void 0 ? _t : ""),
            imagen_url: ((_u = d.imagen_url) !== null && _u !== void 0 ? _u : ""),
            slug: ((_v = d.slug) !== null && _v !== void 0 ? _v : doc.id),
        });
    }
    res.status(200).json({ libros: recomendaciones, autores: Array.from(autores) });
});
// crearCheckoutNazari — movido a nazariEbooks.ts (re-exportado en línea 111)
// @ts-ignore -- duplicate eliminado; función activa en nazariEbooks.ts
const _crearCheckoutNazari_REMOVED = (0, https_1.onRequest)({ region: REGION, cors: _NAZARI_CORS }, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l;
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method Not Allowed" });
        return;
    }
    const isTest = ((_a = req.body) === null || _a === void 0 ? void 0 : _a.test) === true || ((_b = req.query) === null || _b === void 0 ? void 0 : _b.test) === "true";
    let stripe;
    let connOpts;
    let modeLabel;
    try {
        const cfg = await getNazariStripeConfig(isTest);
        stripe = cfg.stripe;
        connOpts = cfg.connOpts;
        modeLabel = cfg.mode;
    }
    catch (e) {
        console.error("❌ Error configurando Stripe:", e.message);
        res.status(500).json({ error: e.message });
        return;
    }
    const rawItems = (_d = (_c = req.body) === null || _c === void 0 ? void 0 : _c.items) !== null && _d !== void 0 ? _d : [];
    if (!rawItems.length) {
        res.status(400).json({ error: "El carrito está vacío" });
        return;
    }
    // Zona de envío: "ES" | "EU" | "LATAM" | "WORLD" (default "ES")
    const zona = ((_f = (_e = req.body) === null || _e === void 0 ? void 0 : _e.zona) !== null && _f !== void 0 ? _f : "ES").toUpperCase().trim();
    if (!["ES", "EU", "LATAM", "WORLD"].includes(zona)) {
        res.status(400).json({ error: `zona inválida: ${zona}. Valores: ES, EU, LATAM, WORLD` });
        return;
    }
    // Modo pack: aplica descuento leído de Firestore (el cliente no decide el %)
    const packMode = ((_g = req.body) === null || _g === void 0 ? void 0 : _g.pack_mode) === true;
    // Validar que todos los items tienen catalogo_id
    for (const it of rawItems) {
        if (!it.catalogo_id) {
            res.status(400).json({ error: "Cada ítem debe incluir catalogo_id" });
            return;
        }
        const cantidad = (_h = it.cantidad) !== null && _h !== void 0 ? _h : 1;
        if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 99) {
            res.status(400).json({ error: `cantidad inválida para ${it.catalogo_id}` });
            return;
        }
    }
    console.log(`🛒 [${modeLabel}] Creando checkout Nazarí — ${rawItems.length} ítem(s) | zona: ${zona}`);
    try {
        // Resolver precio + peso de CADA item desde Firestore (fuente de verdad)
        const resolved = await Promise.all(rawItems.map(async (it) => {
            var _a;
            return ({
                catalogoId: it.catalogo_id,
                cantidad: (_a = it.cantidad) !== null && _a !== void 0 ? _a : 1,
                item: await _resolverItemCatalogoNazari(it.catalogo_id),
            });
        }));
        // Pack: leer descuento desde Firestore (fuente de verdad, no del cliente)
        let packDescuentoPct = 0;
        if (packMode) {
            const packSnap = await db
                .collection("empresas").doc(NAZARI_EMPRESA_ID)
                .collection("configuracion").doc("pack_seleccion").get();
            const packData = (_j = packSnap.data()) !== null && _j !== void 0 ? _j : {};
            if (packData.activo !== true) {
                res.status(400).json({ error: "El pack no está activo" });
                return;
            }
            packDescuentoPct = typeof packData.descuento_porcentaje === "number" ? packData.descuento_porcentaje : 0;
            console.log(`🎁 [${modeLabel}] Pack mode — descuento: ${packDescuentoPct}%`);
        }
        const lineItems = resolved.map(({ catalogoId, cantidad, item }) => {
            const precioFinal = packDescuentoPct > 0
                ? Math.round(item.precioNum * (1 - packDescuentoPct / 100))
                : item.precioNum;
            const pd = {
                name: item.nombre,
                metadata: { catalogo_id: catalogoId },
            };
            if (item.imagenUrl && /^https:\/\/.+/.test(item.imagenUrl))
                pd.images = [item.imagenUrl];
            return {
                price_data: { currency: "eur", product_data: pd, unit_amount: precioFinal },
                quantity: cantidad,
            };
        });
        const totalProductosEuros = resolved.reduce((s, { cantidad, item }) => {
            const pf = packDescuentoPct > 0 ? Math.round(item.precioNum * (1 - packDescuentoPct / 100)) : item.precioNum;
            return s + pf * cantidad;
        }, 0) / 100;
        const pesoTotalGramos = resolved.reduce((s, { cantidad, item }) => s + item.pesoGramos * cantidad, 0);
        // ── Preventa: todos los libros del carrito deben estar en preventa ────────
        const esPreventa = resolved.length > 0 && resolved.every(({ item }) => item.preventa);
        // Opciones de envío y países permitidos según zona (y si es preventa)
        let shippingOptions;
        let allowedCountries;
        if (esPreventa && (zona === "ES" || zona === "EU")) {
            // Preventa + nacional/Europa → envío siempre gratuito
            shippingOptions = [{
                    shipping_rate_data: {
                        type: "fixed_amount",
                        fixed_amount: { amount: 0, currency: "eur" },
                        display_name: "Envío gratuito — Preventa (envío al publicarse)",
                        delivery_estimate: {
                            minimum: { unit: "business_day", value: 3 },
                            maximum: { unit: "business_day", value: 10 },
                        },
                    },
                }];
            allowedCountries = zona === "EU" ? _PAISES_EUROPA : ["ES"];
        }
        else if (esPreventa && (zona === "LATAM" || zona === "WORLD")) {
            // Preventa + zona lejana → precio configurado en el libro (o tarifa estándar si no hay)
            const maxCents = resolved.reduce((max, { item }) => {
                if (item.preventaEnvioLejanoCents == null)
                    return max;
                return max == null ? item.preventaEnvioLejanoCents : Math.max(max, item.preventaEnvioLejanoCents);
            }, null);
            if (maxCents != null) {
                const precioStr = (maxCents / 100).toFixed(0);
                shippingOptions = [{
                        shipping_rate_data: {
                            type: "fixed_amount",
                            fixed_amount: { amount: maxCents, currency: "eur" },
                            display_name: `Envío preventa (envío al publicarse) — ${precioStr}€`,
                            delivery_estimate: {
                                minimum: { unit: "business_day", value: 14 },
                                maximum: { unit: "business_day", value: 30 },
                            },
                        },
                    }];
            }
            else {
                // Sin precio configurado → usar tarifa estándar de la zona
                shippingOptions = zona === "LATAM"
                    ? _opcionesEnvioLatam(pesoTotalGramos)
                    : _opcionesEnvioMundo(pesoTotalGramos);
            }
            allowedCountries = zona === "LATAM" ? _PAISES_LATAM : _PAISES_RESTO;
        }
        else {
            // Flujo normal (no preventa, o carrito mixto)
            switch (zona) {
                case "EU":
                    shippingOptions = _opcionesEnvioEuropa(pesoTotalGramos);
                    allowedCountries = _PAISES_EUROPA;
                    break;
                case "LATAM":
                    shippingOptions = _opcionesEnvioLatam(pesoTotalGramos);
                    allowedCountries = _PAISES_LATAM;
                    break;
                case "WORLD":
                    shippingOptions = _opcionesEnvioMundo(pesoTotalGramos);
                    allowedCountries = _PAISES_RESTO;
                    break;
                default: // "ES"
                    shippingOptions = _calcularOpcionesEnvioNazariES(totalProductosEuros, pesoTotalGramos);
                    allowedCountries = ["ES"];
            }
        }
        console.log(`📦 [${modeLabel}] Total: ${totalProductosEuros.toFixed(2)}€ | Peso: ${pesoTotalGramos}g | Zona: ${zona} | Preventa: ${esPreventa} | Opciones: ${shippingOptions.length}`);
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ["card"],
            mode: "payment",
            line_items: lineItems,
            metadata: {
                empresa_id: NAZARI_EMPRESA_ID,
                tipo: "pedido_nazari",
                zona_envio: zona,
                es_preventa: esPreventa ? "true" : "false",
                es_pack: packMode ? "true" : "false",
            },
            shipping_address_collection: { allowed_countries: allowedCountries },
            shipping_options: shippingOptions,
            success_url: "https://www.editorialnazari.com/gracias.html?session={CHECKOUT_SESSION_ID}",
            cancel_url: "https://www.editorialnazari.com/catalogo.html",
        }, connOpts);
        console.log(`✅ [${modeLabel}] Checkout creado: ${session.url}`);
        res.status(200).json({ url: session.url, mode: modeLabel });
    }
    catch (error) {
        console.error(`❌ [${modeLabel}] Error creando checkout Nazarí:`, error.message);
        res.status(((_k = error.message) === null || _k === void 0 ? void 0 : _k.includes("no encontrado")) || ((_l = error.message) === null || _l === void 0 ? void 0 : _l.includes("no disponible")) ? 404 : 500)
            .json({ error: error.message || "Error creando sesión de pago" });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// crearCheckoutTienda — Versión genérica de crearCheckoutNazari.
//   Crea sesión de Stripe Checkout para CUALQUIER empresa de Fluix.
//
// POST body: {
//   empresa_id:  string,           // ID Firestore de la empresa
//   items:       [{ titulo, precio, cantidad, imagen?, catalogo_id? }],
//   success_url: string,           // URL de éxito (la web de la empresa)
//   cancel_url:  string,           // URL de cancelación
// }
// Respuesta: { url: "https://checkout.stripe.com/..." }
// ─────────────────────────────────────────────────────────────────────────────
exports.crearCheckoutTienda = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method Not Allowed" });
        return;
    }
    const empresaId = ((_a = req.body) === null || _a === void 0 ? void 0 : _a.empresa_id) || "";
    const successUrl = ((_b = req.body) === null || _b === void 0 ? void 0 : _b.success_url) || "";
    const cancelUrl = ((_c = req.body) === null || _c === void 0 ? void 0 : _c.cancel_url) || "";
    const rawItems = (_e = (_d = req.body) === null || _d === void 0 ? void 0 : _d.items) !== null && _e !== void 0 ? _e : [];
    if (!empresaId) {
        res.status(400).json({ error: "empresa_id requerido" });
        return;
    }
    if (!rawItems.length) {
        res.status(400).json({ error: "El carrito está vacío" });
        return;
    }
    if (!successUrl || !cancelUrl) {
        res.status(400).json({ error: "success_url y cancel_url requeridos" });
        return;
    }
    // Validar que todos los items tienen catalogo_id y cantidad válida
    for (const it of rawItems) {
        if (!it.catalogo_id) {
            res.status(400).json({ error: "Cada ítem debe incluir catalogo_id" });
            return;
        }
        const cantidad = (_f = it.cantidad) !== null && _f !== void 0 ? _f : 1;
        if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 99) {
            res.status(400).json({ error: `cantidad inválida para ${it.catalogo_id}` });
            return;
        }
    }
    // Validar que la empresa tiene integración Stripe activa y obtener clave
    let secretKey = stripeSecretKey.value() || "";
    try {
        const integDoc = await db.collection("empresas").doc(empresaId)
            .collection("integraciones").doc("stripe").get();
        if (!integDoc.exists) {
            res.status(403).json({ error: "Empresa no habilitada para pagos" });
            return;
        }
        const empresaKey = ((_g = integDoc.data()) === null || _g === void 0 ? void 0 : _g.secret_key) || "";
        if (empresaKey)
            secretKey = empresaKey;
    }
    catch (_) { /* usa la global como fallback */ }
    if (!secretKey) {
        res.status(500).json({ error: "Pagos no configurados" });
        return;
    }
    const stripe = new stripe_1.default(secretKey, { apiVersion: "2024-06-20" });
    try {
        // Leer precio y datos de cada item desde catalogo_web de esa empresa (fuente de verdad)
        const lineItems = await Promise.all(rawItems.map(async (it) => {
            var _a, _b, _c, _d, _e;
            const snap = await db
                .collection("empresas").doc(empresaId)
                .collection("catalogo_web").doc(it.catalogo_id).get();
            if (!snap.exists)
                throw new Error(`Producto no encontrado: ${it.catalogo_id} en empresa ${empresaId}`);
            const d = snap.data();
            if (d.activo === false)
                throw new Error(`Producto no disponible: ${it.catalogo_id}`);
            const precioRaw = ((_a = d.precio) !== null && _a !== void 0 ? _a : "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
            const precioNum = Math.round(parseFloat(precioRaw || "0") * 100);
            if (isNaN(precioNum) || precioNum <= 0)
                throw new Error(`Precio inválido: ${it.catalogo_id}`);
            const nombre = ((_c = (_b = d.nombre) !== null && _b !== void 0 ? _b : d.titulo) !== null && _c !== void 0 ? _c : "Producto");
            const imagenUrl = ((_d = d.imagen_url) !== null && _d !== void 0 ? _d : "");
            const pd = {
                name: nombre,
                metadata: { catalogo_id: it.catalogo_id },
            };
            if (imagenUrl && /^https:\/\//.test(imagenUrl))
                pd.images = [encodeURI(imagenUrl)];
            return {
                price_data: { currency: "eur", product_data: pd, unit_amount: precioNum },
                quantity: (_e = it.cantidad) !== null && _e !== void 0 ? _e : 1,
            };
        }));
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ["card"],
            mode: "payment",
            line_items: lineItems,
            metadata: { empresa_id: empresaId, tipo: "pedido_tienda" },
            shipping_address_collection: { allowed_countries: ["ES", "FR", "DE", "PT", "IT", "GB"] },
            success_url: successUrl,
            cancel_url: cancelUrl,
        });
        res.status(200).json({ url: session.url });
    }
    catch (error) {
        console.error("❌ Error creando checkout tienda:", error.message);
        res.status(((_h = error.message) === null || _h === void 0 ? void 0 : _h.includes("no encontrado")) || ((_j = error.message) === null || _j === void 0 ? void 0 : _j.includes("no disponible")) ? 404 : 500)
            .json({ error: error.message || "Error creando sesión de pago" });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// sincronizarLibroStripe — Sincroniza automáticamente libros de Nazarí con
//   Stripe cuando se crean o modifican en catalogo_web (fuente de verdad).
//
// Trigger: escritura en empresas/{empresaId}/catalogo_web/{itemId}
// Solo actúa si empresaId === NAZARI_EMPRESA_ID y STRIPE_SECRET_KEY está configurada.
// ─────────────────────────────────────────────────────────────────────────────
// Campos que escribe esta propia función en catalogo_web.
// Si solo cambian estos, ignoramos para evitar un bucle de triggers.
const _STRIPE_SYNC_FIELDS = new Set([
    "stripe_product_id", "stripe_price_id", "payment_link", "stripe_link",
    "stripe_sync_ts", "stripe_product_id_test", "stripe_price_id_test", "payment_link_test",
]);
exports.sincronizarLibroStripe = (0, firestore_1.onDocumentWritten)("empresas/{empresaId}/catalogo_web/{itemId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v;
    if (event.params.empresaId !== NAZARI_EMPRESA_ID)
        return;
    if (!stripeSecretKey.value())
        return;
    const after = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after) === null || _b === void 0 ? void 0 : _b.data();
    const before = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.before) === null || _d === void 0 ? void 0 : _d.data();
    const docRef = (_g = (_f = (_e = event.data) === null || _e === void 0 ? void 0 : _e.after) === null || _f === void 0 ? void 0 : _f.ref) !== null && _g !== void 0 ? _g : (_j = (_h = event.data) === null || _h === void 0 ? void 0 : _h.before) === null || _j === void 0 ? void 0 : _j.ref;
    if (!docRef)
        return;
    // Guard 1: solo cambiaron campos que nosotros mismos escribimos → bucle, salir
    if (after && before) {
        const changed = Object.keys(Object.assign(Object.assign({}, after), before)).filter(k => {
            const av = after[k];
            const bv = before[k];
            // Timestamps del servidor siempre difieren — tratarlos como sin cambio real
            if (av && bv && typeof av === "object" && "_seconds" in av && typeof bv === "object" && "_seconds" in bv)
                return false;
            return JSON.stringify(av) !== JSON.stringify(bv);
        });
        if (changed.length === 0) {
            console.log(`⏭️ [sincronizarLibroStripe] Solo timestamps cambiaron — skip`);
            return;
        }
        if (changed.length > 0 && changed.every(k => _STRIPE_SYNC_FIELDS.has(k))) {
            console.log(`⏭️ [sincronizarLibroStripe] Solo campos Stripe cambiaron — ignorando para evitar bucle`);
            return;
        }
    }
    // Guard 2: migración masiva — si solo cambiaron campos de migración y el item ya tiene
    // stripe_product_id, no hay nada que hacer en Stripe
    const _MIGRATION_FIELDS = new Set(["nombre", "titulo", "descripcion", "precio", "precio_digital",
        "imagen_url", "imagen", "activo", "orden", "slug", "tag", "categoria", "genero", "campo_autor", "autor",
        "campo_isbn", "campo_paginas", "campo_formato", "campo_dimensiones", "campo_anio", "campo_mes",
        "origen", "guardado_en", "migrado_en", "fecha_actualizacion", "fecha_creacion",
        // Campos de envío y preventa — no afectan al producto/precio de Stripe
        "campo_peso", "peso", "peso_gramos", "preventa", "es_preventa", "preventa_envio_lejano",
        // Campos de sección/web
        "seccion_id", "es_libro_del_mes", "novedades", "en_seleccion"]);
    if (after && before && after.stripe_product_id) {
        const realChanged = Object.keys(Object.assign(Object.assign({}, after), before)).filter(k => {
            const av = after[k];
            const bv = before[k];
            if (av && bv && typeof av === "object" && "_seconds" in av && typeof bv === "object" && "_seconds" in bv)
                return false;
            return JSON.stringify(av) !== JSON.stringify(bv);
        });
        if (realChanged.every(k => _MIGRATION_FIELDS.has(k) || _STRIPE_SYNC_FIELDS.has(k))) {
            // Solo campos de migración cambiaron y ya tiene stripe_product_id → nada que hacer
            // (el nombre/precio se actualizará si realmente cambiaron en la próxima edición real)
            const precioActualStr = ((_k = after.precio) !== null && _k !== void 0 ? _k : "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
            const precioAnteriorStr = ((_l = before.precio) !== null && _l !== void 0 ? _l : "").toString().replace(",", ".").replace(/[^0-9.]/g, "");
            const nombreCambio = after.nombre !== before.nombre;
            const precioCambio = Math.abs(parseFloat(precioActualStr || "0") - parseFloat(precioAnteriorStr || "0")) > 0.01;
            if (!nombreCambio && !precioCambio && !(after.activo === false && before.activo === true)) {
                console.log(`⏭️ [sincronizarLibroStripe] Migración masiva sin cambios relevantes — skip (${docRef.id})`);
                return;
            }
        }
    }
    let stripe;
    let connOpts;
    try {
        const cfg = await getNazariStripeConfig(false);
        stripe = cfg.stripe;
        connOpts = cfg.connOpts;
    }
    catch (e) {
        console.error("❌ [LIVE] Config Stripe:", e.message);
        return;
    }
    // Item desactivado o eliminado → archivar producto en Stripe
    if (!after || after.activo === false) {
        if (before === null || before === void 0 ? void 0 : before.stripe_product_id) {
            try {
                await stripe.products.update(before.stripe_product_id, { active: false }, connOpts);
                console.log(`📦 [LIVE] Item ${docRef.id} archivado en Stripe`);
            }
            catch (e) {
                console.warn("⚠️ [LIVE] No se pudo archivar en Stripe:", e);
            }
        }
        return;
    }
    // Normalizar campos: catalogo_web usa nombre/campo_autor/descripcion/campo_isbn
    const titulo = ((_o = (_m = after.nombre) !== null && _m !== void 0 ? _m : after.titulo) !== null && _o !== void 0 ? _o : "Libro");
    const autor = ((_q = (_p = after.campo_autor) !== null && _p !== void 0 ? _p : after.autor) !== null && _q !== void 0 ? _q : "");
    const desc = ((_s = (_r = after.descripcion) !== null && _r !== void 0 ? _r : after.sinopsis) !== null && _s !== void 0 ? _s : "");
    const isbn = ((_u = (_t = after.campo_isbn) !== null && _t !== void 0 ? _t : after.isbn) !== null && _u !== void 0 ? _u : "");
    const imagen = ((_v = after.imagen_url) !== null && _v !== void 0 ? _v : "");
    const parsePrecio = (p) => Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
    const precioActual = parsePrecio(after.precio);
    const precioAnterior = before ? parsePrecio(before.precio) : null;
    // ── Producto ──────────────────────────────────────────────────────────────
    let stripeProductId = after.stripe_product_id || "";
    const productBase = Object.assign(Object.assign({ name: titulo, metadata: { catalogo_id: docRef.id, empresa_id: NAZARI_EMPRESA_ID, autor, isbn } }, (desc ? { description: desc.slice(0, 500) } : {})), (imagen && /^https:\/\//.test(imagen) ? { images: [encodeURI(imagen)] } : {}));
    try {
        if (!stripeProductId) {
            const prod = await stripe.products.create(productBase, connOpts);
            stripeProductId = prod.id;
            console.log(`✅ [LIVE] Producto creado: ${stripeProductId} ("${titulo}")`);
        }
        else {
            await stripe.products.update(stripeProductId, productBase, connOpts);
            console.log(`🔄 [LIVE] Producto actualizado: ${stripeProductId}`);
        }
    }
    catch (e) {
        console.error("❌ [LIVE] Error en producto Stripe:", e);
        return;
    }
    // ── Precio ────────────────────────────────────────────────────────────────
    let stripePriceId = after.stripe_price_id || "";
    const precioChanged = precioActual > 0 && (precioActual !== precioAnterior || !stripePriceId);
    if (precioChanged) {
        try {
            // Stripe Prices son inmutables en importe → archivar el anterior y crear nuevo
            if (stripePriceId)
                await stripe.prices.update(stripePriceId, { active: false }, connOpts);
            const price = await stripe.prices.create({ product: stripeProductId, unit_amount: precioActual, currency: "eur" }, connOpts);
            stripePriceId = price.id;
            console.log(`💶 [LIVE] Precio: ${stripePriceId} (${precioActual / 100} €)`);
        }
        catch (e) {
            console.error("❌ [LIVE] Error en precio Stripe:", e);
        }
    }
    // ── Payment Link ──────────────────────────────────────────────────────────
    let paymentLink = after.payment_link || "";
    if (stripePriceId && (!paymentLink || precioChanged)) {
        try {
            const pl = await stripe.paymentLinks.create({
                line_items: [{ price: stripePriceId, quantity: 1 }],
                metadata: {
                    empresa_id: NAZARI_EMPRESA_ID,
                    tipo: "pedido_nazari",
                    libro_id: docRef.id,
                    libro_titulo: titulo,
                    precio_str: after.precio || "",
                },
            }, connOpts);
            paymentLink = pl.url;
            console.log(`🔗 [LIVE] Payment Link: ${paymentLink}`);
        }
        catch (e) {
            console.error("❌ [LIVE] Error en Payment Link:", e);
        }
    }
    // ── Escribir IDs de Stripe de vuelta en catalogo_web ──────────────────────
    // Estos campos están en _STRIPE_SYNC_FIELDS → el guard anti-loop los ignorará
    await docRef.update(Object.assign(Object.assign({ stripe_product_id: stripeProductId, stripe_price_id: stripePriceId }, (paymentLink ? { payment_link: paymentLink, stripe_link: paymentLink } : {})), { stripe_sync_ts: admin.firestore.FieldValue.serverTimestamp() }));
    console.log(`📝 [LIVE] OK → product: ${stripeProductId} | price: ${stripePriceId} | link: ${paymentLink || "n/a"}`);
});
// ─────────────────────────────────────────────────────────────────────────────
// sincronizarLibroStripeTest — Sincroniza UN libro específico de Nazarí en el
//   entorno TEST de Stripe. Idempotente: omite si ya existe, --force lo rehace.
//   Guarda los IDs TEST en campos _test separados, sin tocar los LIVE.
//
// Uso:
//   curl -X POST \
//     -H "x-sync-secret: fluix-stripe-test-2026" \
//     -H "Content-Type: application/json" \
//     -d '{"libroId":"ID_DEL_LIBRO"}' \
//     https://REGION-planeaapp-4bea4.cloudfunctions.net/sincronizarLibroStripeTest
//
//   Añadir {"force":true} para regenerar aunque ya existan los IDs TEST.
// ─────────────────────────────────────────────────────────────────────────────
exports.sincronizarLibroStripeTest = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    var _a, _b;
    if (req.method !== "POST") {
        res.status(405).json({ error: "POST requerido" });
        return;
    }
    if (!STRIPE_SYNC_SECRET || req.headers["x-sync-secret"] !== STRIPE_SYNC_SECRET) {
        res.status(401).json({ error: "No autorizado" });
        return;
    }
    const libroId = ((_a = req.body) === null || _a === void 0 ? void 0 : _a.libroId) || "";
    const force = ((_b = req.body) === null || _b === void 0 ? void 0 : _b.force) === true;
    if (!libroId) {
        res.status(400).json({ error: "Falta libroId" });
        return;
    }
    let stripe;
    let connOpts;
    let mode;
    try {
        const cfg = await getNazariStripeConfig(true);
        stripe = cfg.stripe;
        connOpts = cfg.connOpts;
        mode = cfg.mode;
    }
    catch (e) {
        console.error("❌ [TEST] Config Stripe:", e.message);
        res.status(500).json({ error: e.message });
        return;
    }
    const libroRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("libros").doc(libroId);
    const libroSnap = await libroRef.get();
    if (!libroSnap.exists) {
        res.status(404).json({ error: `Libro ${libroId} no encontrado` });
        return;
    }
    const libro = libroSnap.data();
    console.log(`🧪 [${mode}] Sincronizando "${libro.titulo}" (${libroId})`);
    const parsePrecio = (p) => Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
    const precioNum = parsePrecio(libro.precio);
    // ── Producto ──────────────────────────────────────────────────────────────
    let productId = libro.stripe_product_id_test || "";
    if (!productId || force) {
        const pd = {
            name: libro.titulo || "Libro",
            metadata: { catalogo_id: libroId, empresa_id: NAZARI_EMPRESA_ID, autor: libro.autor || "", isbn: libro.isbn || "", mode: "test" },
        };
        if (libro.sinopsis)
            pd.description = libro.sinopsis.slice(0, 500);
        if (libro.imagen_url && /^https:\/\//.test(libro.imagen_url))
            pd.images = [encodeURI(libro.imagen_url)];
        if (productId && force) {
            await stripe.products.update(productId, pd, connOpts);
            console.log(`🔄 [${mode}] Producto actualizado: ${productId}`);
        }
        else {
            const prod = await stripe.products.create(pd, connOpts);
            productId = prod.id;
            console.log(`✅ [${mode}] Producto creado: ${productId}`);
        }
    }
    else {
        console.log(`⏭  [${mode}] Producto ya existe: ${productId}`);
    }
    // ── Precio ────────────────────────────────────────────────────────────────
    let priceId = libro.stripe_price_id_test || "";
    if ((!priceId || force) && precioNum > 0) {
        if (priceId && force)
            await stripe.prices.update(priceId, { active: false }, connOpts);
        const price = await stripe.prices.create({ product: productId, unit_amount: precioNum, currency: "eur" }, connOpts);
        priceId = price.id;
        console.log(`💶 [${mode}] Precio: ${priceId} (${precioNum / 100} €)`);
    }
    else {
        console.log(`⏭  [${mode}] Precio ya existe: ${priceId}`);
    }
    // ── Payment Link ──────────────────────────────────────────────────────────
    let paymentLinkUrl = libro.payment_link_test || "";
    if ((!paymentLinkUrl || force) && priceId) {
        const pl = await stripe.paymentLinks.create({
            line_items: [{ price: priceId, quantity: 1 }],
            metadata: {
                empresa_id: NAZARI_EMPRESA_ID,
                tipo: "pedido_nazari",
                libro_id: libroId,
                libro_titulo: libro.titulo || "Libro",
                precio_str: libro.precio || "",
            },
        }, connOpts);
        paymentLinkUrl = pl.url;
        console.log(`🔗 [${mode}] Payment Link: ${paymentLinkUrl}`);
    }
    else {
        console.log(`⏭  [${mode}] Payment Link ya existe: ${paymentLinkUrl}`);
    }
    // ── Firestore ─────────────────────────────────────────────────────────────
    await libroRef.update({
        stripe_product_id_test: productId,
        stripe_price_id_test: priceId,
        payment_link_test: paymentLinkUrl,
        stripe_test_sync_ts: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`📝 [${mode}] OK → product: ${productId} | price: ${priceId} | link: ${paymentLinkUrl}`);
    res.status(200).json({
        modo: mode,
        libro_id: libroId,
        titulo: libro.titulo,
        product_id: productId,
        price_id: priceId,
        payment_link: paymentLinkUrl,
    });
});
// ─────────────────────────────────────────────────────────────────────────────
// migrarLibrosStripe — Migración puntual: sube todos los libros existentes de
//   Nazarí a Stripe. Llamar UNA sola vez via GET con el header secreto.
//
// Uso:
//   curl -H "x-migration-secret: fluix-migrate-2026" \
//     https://europe-west1-planeaapp-4bea4.cloudfunctions.net/migrarLibrosStripe
// ─────────────────────────────────────────────────────────────────────────────
// ── Test: crea pedido de prueba para verificar notificaciones ────────────────
exports.crearPedidoPruebaTest = (0, https_1.onRequest)({ region: REGION }, async (req, res) => {
    var _a, _b, _c, _d;
    if (!STRIPE_SYNC_SECRET || req.headers["x-sync-secret"] !== STRIPE_SYNC_SECRET) {
        res.status(401).json({ error: "No autorizado" });
        return;
    }
    const libroId = (((_a = req.body) === null || _a === void 0 ? void 0 : _a.libroId) || "33-suenos");
    const libroSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("libros").doc(libroId).get();
    const libro = (_b = libroSnap.data()) !== null && _b !== void 0 ? _b : {};
    const totalEuros = parseFloat((libro.precio || "10").replace(",", ".").replace(/[^0-9.]/g, ""));
    const contadorRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("contadores").doc("tickets");
    let numTicket = 1;
    const contSnap = await contadorRef.get();
    numTicket = contSnap.exists ? ((_d = (_c = contSnap.data()) === null || _c === void 0 ? void 0 : _c.ultimo) !== null && _d !== void 0 ? _d : 0) + 1 : 1;
    await contadorRef.set({ ultimo: numTicket }, { merge: true });
    const pedidoRef = await db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("pedidos").add({
        empresa_id: NAZARI_EMPRESA_ID, numero_ticket: numTicket,
        cliente_nombre: "Cliente Prueba TEST", cliente_correo: "test@test.com",
        origen: "web_nazari", estado: "pendiente", estado_pago: "pagado", metodo_pago: "tarjeta",
        lineas: [{ libro_id: libroId, producto_nombre: libro.titulo || libroId, cantidad: 1, precio_unitario: parseFloat((totalEuros / 1.04).toFixed(2)), porcentaje_iva: 4 }],
        subtotal: parseFloat((totalEuros / 1.04).toFixed(2)), importe_iva: parseFloat((totalEuros - totalEuros / 1.04).toFixed(2)), total: totalEuros,
        livemode: false, notas_internas: "PEDIDO DE PRUEBA — borrar después",
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
        fecha_pedido: admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Notificación directa (onNuevoPedido salta web_nazari para evitar duplicados)
    const cuerpoTest = `Cliente Prueba TEST — €${totalEuros.toFixed(2)} (web Editorial Nazarí · TEST)`;
    try {
        await db.collection("notificaciones").doc(NAZARI_EMPRESA_ID).collection("items").add({
            titulo: "📦 Nuevo Pedido Web (TEST)",
            cuerpo: cuerpoTest,
            tipo: "pedidoNuevo",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "pedidos",
            entidad_id: pedidoRef.id,
            remitente_nombre: "Cliente Prueba TEST",
            remitente_email: "test@test.com",
        });
        await (0, notificaciones_1.enviarNotificacionEmpresa)(NAZARI_EMPRESA_ID, "📦 Nuevo Pedido Web (TEST)", cuerpoTest, { tipo: "nuevo_pedido", pedido_id: pedidoRef.id, origen: "web_nazari" });
    }
    catch (_) { }
    console.log(`🧪 Pedido prueba #${numTicket} creado: ${pedidoRef.id}`);
    res.status(200).json({ pedido_id: pedidoRef.id, numero_ticket: numTicket, mensaje: "Pedido + notificación creados directamente" });
});
exports.migrarLibrosStripe = (0, https_1.onRequest)({ region: REGION, timeoutSeconds: 540 }, async (req, res) => {
    if (req.headers["x-migration-secret"] !== "fluix-migrate-2026") {
        res.status(401).json({ error: "No autorizado" });
        return;
    }
    const secretKey = stripeSecretKey.value() || "";
    if (!secretKey) {
        res.status(500).json({ error: "STRIPE_SECRET_KEY no configurada" });
        return;
    }
    const stripe = new stripe_1.default(secretKey, { apiVersion: "2024-06-20" });
    const parsePrecio = (p) => Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
    const snap = await db
        .collection("empresas")
        .doc(NAZARI_EMPRESA_ID)
        .collection("libros")
        .get();
    const resultados = [];
    for (const doc of snap.docs) {
        const libro = doc.data();
        if (libro.stripe_product_id) {
            resultados.push({ id: doc.id, titulo: libro.titulo, estado: "ya_sincronizado", stripe_product_id: libro.stripe_product_id });
            continue;
        }
        try {
            const productData = {
                name: libro.titulo || "Libro",
                metadata: {
                    catalogo_id: doc.id,
                    empresa_id: NAZARI_EMPRESA_ID,
                    autor: libro.autor || "",
                    isbn: libro.isbn || "",
                },
            };
            if (libro.sinopsis)
                productData.description = libro.sinopsis.slice(0, 500);
            if (libro.imagen_url)
                productData.images = [encodeURI(libro.imagen_url)];
            const prod = await stripe.products.create(productData);
            let stripePriceId = "";
            const precioNum = parsePrecio(libro.precio);
            if (precioNum > 0) {
                const price = await stripe.prices.create({
                    product: prod.id,
                    unit_amount: precioNum,
                    currency: "eur",
                });
                stripePriceId = price.id;
            }
            await doc.ref.update({
                stripe_product_id: prod.id,
                stripe_price_id: stripePriceId,
                stripe_sync_ts: admin.firestore.FieldValue.serverTimestamp(),
            });
            resultados.push({ id: doc.id, titulo: libro.titulo, estado: "creado", stripe_product_id: prod.id });
            // pequeña pausa para respetar rate limits de Stripe
            await new Promise(r => setTimeout(r, 80));
        }
        catch (e) {
            resultados.push({ id: doc.id, titulo: libro.titulo, estado: `error: ${e.message}` });
        }
    }
    const creados = resultados.filter(r => r.estado === "creado").length;
    const yaSync = resultados.filter(r => r.estado === "ya_sincronizado").length;
    const errores = resultados.filter(r => r.estado.startsWith("error")).length;
    console.log(`✅ Migración completada: ${creados} creados, ${yaSync} ya sincronizados, ${errores} errores`);
    res.status(200).json({ resumen: { creados, ya_sincronizados: yaSync, errores }, detalle: resultados });
});
// ─────────────────────────────────────────────────────────────────────────────
// auditarStripeCatalogo — Audita y sincroniza Stripe vs catalogo_web.
//
// Callable desde Fluix (Firebase callable function).
// Requiere que el usuario sea admin de la empresa Nazarí.
//
// Modos (parámetro `modo`):
//   "diagnostico"    → solo lee, no escribe (default)
//   "limpiar"        → archiva en Stripe productos sin catálogo activo
//   "crear_faltantes"→ crea productos Stripe para libros sin stripe_product_id
//   "full"           → limpiar + crear_faltantes
// ─────────────────────────────────────────────────────────────────────────────
exports.auditarStripeCatalogo = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o;
    // Solo permite usuarios autenticados de la empresa Nazarí
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida");
    const modo = ((_a = request.data) === null || _a === void 0 ? void 0 : _a.modo) || "diagnostico";
    const limpiar = modo === "limpiar" || modo === "full";
    const crearFaltantes = modo === "crear_faltantes" || modo === "full";
    const key = stripeSecretKey.value();
    if (!key)
        throw new https_1.HttpsError("failed-precondition", "STRIPE_SECRET_KEY no configurada");
    const stripe = new stripe_1.default(key, { apiVersion: "2024-06-20" });
    // Stripe Connect optional
    let connOpts;
    try {
        const integSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
            .collection("integraciones").doc("stripe").get();
        const acct = (_c = (_b = integSnap.data()) === null || _b === void 0 ? void 0 : _b.stripe_account_id) !== null && _c !== void 0 ? _c : "";
        if (acct)
            connOpts = { stripeAccount: acct };
    }
    catch (_) { }
    // ── Leer todos los productos de Stripe ──────────────────────────────────
    const stripeProds = [];
    let startingAfter;
    while (true) {
        const params = { limit: 100 };
        if (startingAfter)
            params.starting_after = startingAfter;
        const page = await stripe.products.list(params, connOpts);
        stripeProds.push(...page.data);
        if (!page.has_more)
            break;
        startingAfter = page.data[page.data.length - 1].id;
    }
    // ── Leer catalogo_web ───────────────────────────────────────────────────
    const catSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
        .collection("catalogo_web").get();
    const catDocs = catSnap.docs.map(d => (Object.assign({ id: d.id }, d.data())));
    const catIds = new Set(catDocs.map(d => d.id));
    // ── Análisis ────────────────────────────────────────────────────────────
    const byMeta = new Map();
    for (const p of stripeProds) {
        const cid = (_e = (_d = p.metadata) === null || _d === void 0 ? void 0 : _d.catalogo_id) !== null && _e !== void 0 ? _e : "";
        if (cid) {
            if (!byMeta.has(cid))
                byMeta.set(cid, []);
            byMeta.get(cid).push(p);
        }
    }
    const orphans = [];
    const duplicates = [];
    const sinStripe = [];
    for (const [cid, prods] of byMeta.entries()) {
        const doc = catDocs.find(d => d.id === cid);
        const enFirestore = catIds.has(cid);
        if (!enFirestore || (doc === null || doc === void 0 ? void 0 : doc.activo) === false) {
            orphans.push(...prods.filter(p => p.active).map(p => p.id));
        }
        else {
            const activos = prods.filter(p => p.active);
            if (activos.length > 1) {
                const canonical = doc === null || doc === void 0 ? void 0 : doc.stripe_product_id;
                duplicates.push(...activos.filter(p => p.id !== canonical).map(p => p.id));
            }
        }
    }
    for (const doc of catDocs) {
        if (doc.activo === false)
            continue;
        if (!doc.stripe_product_id)
            sinStripe.push(doc.id);
    }
    const sinMeta = stripeProds.filter(p => { var _a; return p.active && !((_a = p.metadata) === null || _a === void 0 ? void 0 : _a.catalogo_id); }).length;
    let archivados = 0, creados = 0, errores = 0;
    // ── Archivar orphans + duplicados ───────────────────────────────────────
    if (limpiar) {
        const toArchive = [...new Set([...orphans, ...duplicates])];
        for (const pid of toArchive) {
            try {
                await stripe.products.update(pid, { active: false }, connOpts);
                archivados++;
                await new Promise(r => setTimeout(r, 80));
            }
            catch (e) {
                console.warn(`⚠️ No se pudo archivar ${pid}: ${e.message}`);
                errores++;
            }
        }
    }
    // ── Crear productos faltantes ───────────────────────────────────────────
    if (crearFaltantes) {
        const col = db.collection("empresas").doc(NAZARI_EMPRESA_ID).collection("catalogo_web");
        for (const itemId of sinStripe) {
            const docSnap = await col.doc(itemId).get();
            if (!docSnap.exists)
                continue;
            const d = docSnap.data();
            const titulo = ((_g = (_f = d.nombre) !== null && _f !== void 0 ? _f : d.titulo) !== null && _g !== void 0 ? _g : "Libro");
            const autor = ((_j = (_h = d.campo_autor) !== null && _h !== void 0 ? _h : d.autor) !== null && _j !== void 0 ? _j : "");
            const desc = ((_k = d.descripcion) !== null && _k !== void 0 ? _k : "");
            const isbn = ((_m = (_l = d.campo_isbn) !== null && _l !== void 0 ? _l : d.isbn) !== null && _m !== void 0 ? _m : "");
            const imagen = ((_o = d.imagen_url) !== null && _o !== void 0 ? _o : "");
            const parsePrecio = (p) => Math.round(parseFloat((p || "0").replace(",", ".").replace(/[^0-9.]/g, "")) * 100);
            const precio = parsePrecio(d.precio);
            try {
                const prod = await stripe.products.create(Object.assign(Object.assign(Object.assign({ name: titulo }, (desc ? { description: desc.slice(0, 500) } : {})), (imagen && /^https:\/\//.test(imagen) ? { images: [encodeURI(imagen)] } : {})), { metadata: { catalogo_id: itemId, empresa_id: NAZARI_EMPRESA_ID, autor, isbn } }), connOpts);
                let priceId = "";
                if (precio > 0) {
                    const price = await stripe.prices.create({ product: prod.id, unit_amount: precio, currency: "eur" }, connOpts);
                    priceId = price.id;
                }
                await col.doc(itemId).update(Object.assign(Object.assign({ stripe_product_id: prod.id }, (priceId ? { stripe_price_id: priceId } : {})), { stripe_sync_ts: admin.firestore.FieldValue.serverTimestamp() }));
                creados++;
                await new Promise(r => setTimeout(r, 150));
            }
            catch (e) {
                console.warn(`⚠️ No se pudo crear producto para ${itemId}: ${e.message}`);
                errores++;
            }
        }
    }
    return Object.assign(Object.assign(Object.assign({ stripe_total: stripeProds.length, stripe_activos: stripeProds.filter(p => p.active).length, stripe_sin_meta: sinMeta, orphans: orphans.length, duplicados: duplicates.length, catalogo_sin_stripe: sinStripe.length, catalogo_total: catDocs.length }, (limpiar ? { archivados } : {})), (crearFaltantes ? { creados } : {})), (limpiar || crearFaltantes ? { errores } : {}));
});
// =============================================================================
// crearLinkPackNazari — HTTP function (autenticada con Firebase ID token)
// Crea un Stripe Payment Link para el pack de La Selección Nazarí y guarda la
// URL en empresas/{EID}/configuracion/pack_seleccion.stripe_link
// POST (sin body necesario) — Authorization: Bearer <firebase-id-token>
// =============================================================================
exports.crearLinkPackNazari = (0, https_1.onRequest)({ region: REGION, timeoutSeconds: 120, memory: "256MiB", cors: false, invoker: "public" }, async (req, res) => {
    var _a, _b;
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method Not Allowed" });
        return;
    }
    // Verificar Firebase ID token
    const authHeader = (_a = req.headers.authorization) !== null && _a !== void 0 ? _a : "";
    if (!authHeader.startsWith("Bearer ")) {
        res.status(401).json({ error: "Token requerido" });
        return;
    }
    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    }
    catch (_c) {
        res.status(401).json({ error: "Token inválido" });
        return;
    }
    try {
        const { stripe, connOpts, mode } = await getNazariStripeConfig(false);
        // 1. Leer configuración del pack
        const packRef = db.collection("empresas").doc(NAZARI_EMPRESA_ID)
            .collection("configuracion").doc("pack_seleccion");
        const packSnap = await packRef.get();
        if (!packSnap.exists) {
            res.status(404).json({ error: "No hay configuración de pack" });
            return;
        }
        const packData = packSnap.data();
        const descuentoPct = typeof packData.descuento_porcentaje === "number" ? packData.descuento_porcentaje : 0;
        const descripcion = packData.descripcion || "Pack La Selección Nazarí";
        // 2. Leer libros del pack
        const selSnap = await db.collection("empresas").doc(NAZARI_EMPRESA_ID)
            .collection("seleccion_nazari")
            .where("en_pack", "==", true)
            .where("activo", "==", true)
            .orderBy("orden").limit(8).get();
        if (selSnap.empty) {
            res.status(400).json({ error: "No hay libros marcados en el pack" });
            return;
        }
        // 3. Resolver precios y pesos
        const libros = await Promise.all(selSnap.docs.map(async (d) => {
            var _a, _b, _c;
            const catalogoId = d.data().catalogo_id || d.id;
            try {
                const item = await _resolverItemCatalogoNazari(catalogoId);
                return { catalogoId, precioNum: item.precioNum, pesoGramos: item.pesoGramos, nombre: item.nombre, imagenUrl: item.imagenUrl };
            }
            catch (_d) {
                const raw = ((_a = d.data().precio) !== null && _a !== void 0 ? _a : "").replace(",", ".").replace(/[^0-9.]/g, "");
                return { catalogoId, precioNum: Math.round(parseFloat(raw || "0") * 100) || 0,
                    pesoGramos: 300, nombre: ((_b = d.data().titulo) !== null && _b !== void 0 ? _b : ""), imagenUrl: ((_c = d.data().imagen) !== null && _c !== void 0 ? _c : "") };
            }
        }));
        const totalOriginalCents = libros.reduce((s, l) => s + l.precioNum, 0);
        const packPriceCents = Math.max(100, Math.round(totalOriginalCents * (1 - descuentoPct / 100)));
        const pesoTotal = libros.reduce((s, l) => s + l.pesoGramos, 0);
        console.log(`🎁 [${mode}] Pack: ${libros.length} libros | original: ${(totalOriginalCents / 100).toFixed(2)}€ | pack: ${(packPriceCents / 100).toFixed(2)}€ | peso: ${pesoTotal}g`);
        // 4. Crear ShippingRates
        const mesAno = new Date().toLocaleDateString("es-ES", { month: "long", year: "numeric" });
        const tagMeta = { tipo: "pack_nazari", mes: mesAno };
        const esGratuito = (packPriceCents / 100) >= 30;
        const esOrdCents = esGratuito ? 0 : (pesoTotal <= 100 ? 150 : pesoTotal <= 500 ? 250 : 300);
        const [rateESOrd, rateESUrg, rateEU, rateIntl] = await Promise.all([
            stripe.shippingRates.create({
                display_name: esGratuito ? "Envío gratuito España (3-5 días laborables)" : `Envío ordinario España — ${(esOrdCents / 100).toFixed(2).replace(".", ",")}€`,
                type: "fixed_amount", fixed_amount: { amount: esOrdCents, currency: "eur" },
                delivery_estimate: { minimum: { unit: "business_day", value: 3 }, maximum: { unit: "business_day", value: 5 } }, metadata: tagMeta,
            }, connOpts),
            stripe.shippingRates.create({
                display_name: "Envío urgente España (24-48 h) — 6,00€",
                type: "fixed_amount", fixed_amount: { amount: 600, currency: "eur" },
                delivery_estimate: { minimum: { unit: "business_day", value: 1 }, maximum: { unit: "business_day", value: 2 } }, metadata: tagMeta,
            }, connOpts),
            stripe.shippingRates.create({
                display_name: `Envío Europa (7-14 días laborables) — ${pesoTotal < 500 ? "15" : "20"}€`,
                type: "fixed_amount", fixed_amount: { amount: pesoTotal < 500 ? 1500 : 2000, currency: "eur" },
                delivery_estimate: { minimum: { unit: "business_day", value: 7 }, maximum: { unit: "business_day", value: 14 } }, metadata: tagMeta,
            }, connOpts),
            stripe.shippingRates.create({
                display_name: `Envío internacional (14-30 días laborables) — ${pesoTotal < 500 ? "25" : "35"}€`,
                type: "fixed_amount", fixed_amount: { amount: pesoTotal < 500 ? 2500 : 3500, currency: "eur" },
                delivery_estimate: { minimum: { unit: "business_day", value: 14 }, maximum: { unit: "business_day", value: 30 } }, metadata: tagMeta,
            }, connOpts),
        ]);
        // 5. Crear Product + Price
        const imagenPack = (((_b = libros[0]) === null || _b === void 0 ? void 0 : _b.imagenUrl) && /^https:\/\/.+/.test(libros[0].imagenUrl)) ? libros[0].imagenUrl : undefined;
        const product = await stripe.products.create(Object.assign(Object.assign({ name: `Pack La Seleccion Nazari — ${mesAno}`, description: descripcion }, (imagenPack ? { images: [imagenPack] } : {})), { metadata: { tipo: "pack_nazari", empresa_id: NAZARI_EMPRESA_ID } }), connOpts);
        const price = await stripe.prices.create({ currency: "eur", unit_amount: packPriceCents, product: product.id }, connOpts);
        // 6. Crear Payment Link
        const paymentLink = await stripe.paymentLinks.create({
            line_items: [{ price: price.id, quantity: 1 }],
            shipping_address_collection: {
                allowed_countries: ["ES", "PT", "FR", "DE", "IT", "BE", "NL", "AT", "PL", "SE", "DK", "NO", "FI", "IE", "GB", "CH",
                    "MX", "AR", "CO", "PE", "CL", "UY", "VE", "EC", "BO", "PY", "CR", "GT", "PA", "US", "CA"],
            },
            shipping_options: [{ shipping_rate: rateESOrd.id }, { shipping_rate: rateESUrg.id }, { shipping_rate: rateEU.id }, { shipping_rate: rateIntl.id }],
            after_completion: { type: "redirect", redirect: { url: "https://www.editorialnazari.com/gracias.html" } },
            metadata: { tipo: "pack_nazari", empresa_id: NAZARI_EMPRESA_ID, descuento: String(descuentoPct), mes: mesAno },
        }, connOpts);
        // 7. Guardar en Firestore
        const precioPackStr = (packPriceCents / 100).toFixed(2).replace(".", ",") + " €";
        const precioOriginalStr = (totalOriginalCents / 100).toFixed(2).replace(".", ",") + " €";
        await packRef.set({
            stripe_link: paymentLink.url, stripe_link_id: paymentLink.id, stripe_price_id: price.id,
            precio_pack: precioPackStr, precio_original: precioOriginalStr, peso_total_gramos: pesoTotal,
            link_generado_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`✅ [${mode}] Pack Payment Link: ${paymentLink.url}`);
        res.status(200).json({ url: paymentLink.url, precio_pack: precioPackStr, precio_original: precioOriginalStr, libros_count: libros.length });
    }
    catch (e) {
        console.error("❌ crearLinkPackNazari:", e.message);
        res.status(500).json({ error: e.message || "Error interno" });
    }
});
//# sourceMappingURL=index.js.map