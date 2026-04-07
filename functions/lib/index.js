"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.remitirVerifactu = exports.firmarXMLVerifactu = exports.enviarRecordatoriosCitas = exports.enviarEmailConPdf = exports.stripeWebhook = exports.crearEmpresaHTTP = exports.inicializarEmpresa = exports.obtenerScriptJSON = exports.generarScriptEmpresa = exports.onNuevoPedidoWhatsApp = exports.verificarSuscripciones = exports.onNuevaFactura = exports.onNuevoPedidoGenerarFactura = exports.onNuevoPedido = exports.onNuevaValoracion = exports.onReservaCancelada = exports.onNuevaReserva = exports.onTareaAsignada = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const stripe_1 = require("stripe");
const nodemailer = require("nodemailer");
const recordatoriosCitas_1 = require("./recordatoriosCitas");
Object.defineProperty(exports, "enviarRecordatoriosCitas", { enumerable: true, get: function () { return recordatoriosCitas_1.enviarRecordatoriosCitas; } });
const notificacionesTareas_1 = require("./notificacionesTareas");
Object.defineProperty(exports, "onTareaAsignada", { enumerable: true, get: function () { return notificacionesTareas_1.onTareaAsignada; } });
// ── SECRETS via variables de entorno (.env o Firebase env config) ─────────
// Valores reales: edita functions/.env (no subir a git)
const stripeSecretKey = { value: () => { var _a; return (_a = process.env.STRIPE_SECRET_KEY) !== null && _a !== void 0 ? _a : ""; } };
const stripeWebhookSecret = { value: () => { var _a; return (_a = process.env.STRIPE_WEBHOOK_SECRET) !== null && _a !== void 0 ? _a : ""; } };
const smtpHost = { value: () => { var _a; return (_a = process.env.SMTP_HOST) !== null && _a !== void 0 ? _a : ""; } };
const smtpPort = { value: () => { var _a; return (_a = process.env.SMTP_PORT) !== null && _a !== void 0 ? _a : "587"; } };
const smtpUser = { value: () => { var _a; return (_a = process.env.SMTP_USER) !== null && _a !== void 0 ? _a : ""; } };
const smtpPass = { value: () => { var _a; return (_a = process.env.SMTP_PASS) !== null && _a !== void 0 ? _a : ""; } };
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const REGION = "europe-west1";
// ── UTILIDADES ────────────────────────────────────────────────────────────────
async function obtenerTokensEmpresa(empresaId) {
    const snapshot = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("dispositivos")
        .where("activo", "==", true)
        .get();
    const tokens = [];
    snapshot.forEach((doc) => {
        const token = doc.data().token;
        if (token)
            tokens.push(token);
    });
    return tokens;
}
async function enviarNotificacionEmpresa(empresaId, titulo, cuerpo, data = {}) {
    const tokens = await obtenerTokensEmpresa(empresaId);
    if (tokens.length === 0) {
        console.log(`No hay tokens para empresa ${empresaId}`);
        return;
    }
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
 * 1. NUEVA RESERVA
 */
exports.onNuevaReserva = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/reservas/{reservaId}", region: REGION }, async (event) => {
    var _a, _b;
    const empresaId = event.params.empresaId;
    const reserva = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!reserva)
        return;
    const cliente = reserva.cliente || "Cliente";
    const servicio = reserva.servicio || "Servicio";
    const fecha = ((_b = reserva.fecha) === null || _b === void 0 ? void 0 : _b.toDate)
        ? reserva.fecha.toDate().toLocaleDateString("es-ES")
        : "Fecha pendiente";
    await enviarNotificacionEmpresa(empresaId, "📅 Nueva Reserva", `${cliente} — ${servicio} el ${fecha}`, { tipo: "nueva_reserva", reserva_id: event.params.reservaId });
    console.log(`✅ Notificación nueva reserva enviada para empresa ${empresaId}`);
});
/**
 * 2. RESERVA CANCELADA
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
    const cliente = despues.cliente || "Cliente";
    const servicio = despues.servicio || "Servicio";
    await enviarNotificacionEmpresa(empresaId, "❌ Reserva Cancelada", `${cliente} canceló la reserva de ${servicio}`, { tipo: "reserva_cancelada", reserva_id: event.params.reservaId });
});
/**
 * 3. NUEVA VALORACIÓN
 */
exports.onNuevaValoracion = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/valoraciones/{valoracionId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const valoracion = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!valoracion)
        return;
    const cliente = valoracion.cliente || "Cliente";
    const estrellas = valoracion.calificacion || valoracion.estrellas || 5;
    const comentario = valoracion.comentario || "";
    const estrellaStr = "⭐".repeat(Math.min(estrellas, 5));
    await enviarNotificacionEmpresa(empresaId, `${estrellaStr} Nueva Valoración`, `${cliente}: "${comentario.substring(0, 60)}${comentario.length > 60 ? "..." : ""}"`, { tipo: "nueva_valoracion", valoracion_id: event.params.valoracionId });
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
    const cliente = pedido.cliente || "Cliente";
    const total = pedido.precio_total || 0;
    const origen = pedido.origen || "app";
    await enviarNotificacionEmpresa(empresaId, "🛒 Nuevo Pedido", `${cliente} — €${total.toFixed(2)} (vía ${origen})`, { tipo: "nuevo_pedido", pedido_id: event.params.pedidoId });
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
            descripcion: l.producto_nombre || l.descripcion || "Producto",
            precio_unitario: l.precio_unitario || 0,
            cantidad: l.cantidad || 1,
            porcentaje_iva: 21.0,
            referencia: l.producto_id || null,
        }));
        const subtotal = lineasFactura.reduce((sum, l) => sum + l.precio_unitario * l.cantidad, 0);
        const totalIva = lineasFactura.reduce((sum, l) => sum + l.precio_unitario * l.cantidad * (l.porcentaje_iva / 100), 0);
        const total = subtotal + totalIva;
        const metodoPagoMap = {
            tarjeta: "tarjeta",
            paypal: "paypal",
            bizum: "bizum",
            efectivo: "efectivo",
        };
        const metodoPago = (_a = metodoPagoMap[pedido.metodo_pago]) !== null && _a !== void 0 ? _a : null;
        const facturaData = {
            empresa_id: empresaId,
            numero_factura: numeroFactura,
            tipo: "pedido",
            estado: "pendiente",
            cliente_nombre: pedido.cliente_nombre || "Cliente",
            cliente_telefono: pedido.cliente_telefono || null,
            cliente_correo: pedido.cliente_correo || null,
            datos_fiscales: null,
            lineas: lineasFactura,
            subtotal: subtotal,
            total_iva: totalIva,
            total: total,
            metodo_pago: metodoPago,
            pedido_id: pedidoId,
            notas_internas: null,
            notas_cliente: pedido.notas_cliente || null,
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
/**
 * 6. NUEVA FACTURA PENDIENTE
 */
exports.onNuevaFactura = (0, firestore_1.onDocumentCreated)({ document: "empresas/{empresaId}/facturas/{facturaId}", region: REGION }, async (event) => {
    var _a;
    const empresaId = event.params.empresaId;
    const factura = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!factura)
        return;
    if (factura.estado !== "pendiente")
        return;
    const numero = factura.numero_factura || event.params.facturaId;
    const total = factura.total || 0;
    const cliente = factura.cliente_nombre || "Cliente";
    await enviarNotificacionEmpresa(empresaId, "🧾 Nueva Factura Pendiente", `${numero} — ${cliente} — €${total.toFixed(2)}`, { tipo: "nueva_factura", factura_id: event.params.facturaId });
});
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
            if ([7, 3, 1].includes(diasRestantes)) {
                const empresaId = empresaDoc.id;
                await enviarNotificacionEmpresa(empresaId, "⚠️ Suscripción por Vencer", `Tu suscripción vence en ${diasRestantes} día${diasRestantes !== 1 ? "s" : ""}. ¡Renueva para continuar!`, {
                    tipo: "suscripcion_por_vencer",
                    dias_restantes: String(diasRestantes),
                });
                await suscripcionDoc.ref.update({
                    aviso_enviado: true,
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
/**
 * 9. GENERAR SCRIPT PERSONALIZADO (v2 onRequest)
 */
exports.generarScriptEmpresa = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    try {
        const { empresaId, dominio } = req.query;
        if (!empresaId || typeof empresaId !== "string") {
            res.status(400).json({ error: "empresaId es requerido" });
            return;
        }
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        if (!empresaDoc.exists) {
            res.status(404).json({ error: "Empresa no encontrada" });
            return;
        }
        const empresa = empresaDoc.data();
        const nombreEmpresa = empresa.nombre || "Mi Negocio";
        const dominiWeb = dominio || empresa.sitio_web || "midominio.com";
        const script = generarScriptHTML(empresaId, nombreEmpresa, dominiWeb);
        res.set("Content-Type", "text/html; charset=utf-8");
        res.set("Content-Disposition", `attachment; filename="script-fluixcrm-${empresaId}.html"`);
        res.status(200).send(script);
    }
    catch (error) {
        console.error("❌ Error generando script:", error);
        res.status(500).json({ error: "Error generando script" });
    }
});
function generarScriptHTML(empresaId, nombreEmpresa, dominio) {
    return `<!-- ============================================================
     🔥 FLUIX CRM - SCRIPT FOOTER DINÁMICO
     Web: ${dominio}
     Empresa: ${nombreEmpresa}
     Versión: SEGURA (no bloquea la web si Firebase falla)
     ============================================================ -->

<!-- Firebase SDK -->
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js"></script>

<script>
(function () {
  'use strict';

  const FIREBASE_CONFIG = {
    apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  const EMPRESA_ID = "${empresaId}";
  const DOMINIO_WEB = "${dominio}";
  const NOMBRE_EMPRESA = "${nombreEmpresa}";

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

    registrarVisita(db).catch(function (e) {
      console.warn('Fluix CRM: error registrando visita', e);
    });

    rastrearEventos(db).catch(function (e) {
      console.warn('Fluix CRM: error rastreando eventos', e);
    });
  }

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
2. 📝 PEGA en el footer de tu WordPress (antes del </body>)
3. ✅ GUARDA los cambios
4. 🔄 Las estadísticas comenzarán a registrarse inmediatamente

📊 QUE HARÁ ESTE SCRIPT:
✓ Registra todas las visitas a ${dominio}
✓ Rastrea llamadas telefónicas
✓ Rastrea envío de formularios de contacto
✓ Rastrea clicks en WhatsApp
✓ Sincroniza datos en tiempo real con tu app Fluix CRM

🌐 VERÁS LOS DATOS EN:
✅ Módulo de Estadísticas (Tráfico Web)
✅ Módulo de Eventos (Acciones de clientes)
✅ Dashboard principal
-->`;
}
// ── ENDPOINT ALTERNATIVO: JSON ────────────────────────────────────────────
exports.obtenerScriptJSON = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    try {
        const { empresaId } = req.query;
        if (!empresaId || typeof empresaId !== "string") {
            res.status(400).json({ error: "empresaId es requerido" });
            return;
        }
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        if (!empresaDoc.exists) {
            res.status(404).json({ error: "Empresa no encontrada" });
            return;
        }
        const empresa = empresaDoc.data();
        const script = generarScriptHTML(empresaId, empresa.nombre || "Mi Negocio", empresa.sitio_web || "midominio.com");
        res.status(200).json({
            exito: true,
            empresaId,
            nombre: empresa.nombre,
            dominio: empresa.sitio_web,
            script: script,
            instrucciones: "Pega este script en el footer de tu WordPress (antes del </body>)"
        });
    }
    catch (error) {
        console.error("❌ Error:", error);
        res.status(500).json({ error: "Error generando script" });
    }
});
/**
 * 10. INICIALIZAR EMPRESA (v2 onCall)
 */
exports.inicializarEmpresa = (0, https_1.onCall)({ region: REGION }, async (request) => {
    try {
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
 * 11. CREAR EMPRESA HTTP (v2 onRequest)
 */
exports.crearEmpresaHTTP = (0, https_1.onRequest)({ region: REGION, cors: true }, async (req, res) => {
    try {
        const { empresaId, nombre, dominio, telefono, direccion } = req.body;
        if (!empresaId) {
            res.status(400).json({ error: "empresaId es requerido" });
            return;
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
        res.status(200).json({
            exito: true,
            mensaje: `Empresa "${nombre}" creada exitosamente`,
            empresaId,
        });
    }
    catch (error) {
        console.error("❌ Error:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "Error desconocido",
        });
    }
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
        if (webhookSec && sig) {
            event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
        }
        else {
            console.warn("⚠️ Stripe webhook sin verificación de firma (modo dev)");
            event = req.body;
        }
    }
    catch (err) {
        console.error("❌ Error verificando firma Stripe:", err);
        res.status(400).json({ error: `Webhook signature verification failed: ${err}` });
        return;
    }
    console.log(`📥 Stripe evento recibido: ${event.type} [${event.id}]`);
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
 *   firebase functions:secrets:set SMTP_HOST     (ej: smtp.gmail.com)
 *   firebase functions:secrets:set SMTP_PORT     (ej: 587)
 *   firebase functions:secrets:set SMTP_USER     (ej: noreply@fluixtech.com)
 *   firebase functions:secrets:set SMTP_PASS     (ej: app-password)
 */
exports.enviarEmailConPdf = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a;
    const { destinatario, asunto, cuerpoHtml, pdfBase64, nombreArchivo, empresaId } = request.data;
    if (!destinatario || !asunto || !pdfBase64) {
        throw new https_1.HttpsError("invalid-argument", "destinatario, asunto y pdfBase64 son requeridos");
    }
    const host = smtpHost.value();
    const port = parseInt(smtpPort.value() || "587", 10);
    const user = smtpUser.value();
    const pass = smtpPass.value();
    if (!host || !user || !pass) {
        throw new https_1.HttpsError("failed-precondition", "SMTP no configurado. Ejecuta: firebase functions:secrets:set SMTP_HOST / SMTP_USER / SMTP_PASS");
    }
    const transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
    });
    // Obtener datos de la empresa para el remitente
    let nombreEmpresa = "Fluix CRM";
    if (empresaId) {
        const empresaDoc = await db.collection("empresas").doc(empresaId).get();
        if (empresaDoc.exists) {
            nombreEmpresa = ((_a = empresaDoc.data()) === null || _a === void 0 ? void 0 : _a.nombre) || "Fluix CRM";
        }
    }
    try {
        await transporter.sendMail({
            from: `"${nombreEmpresa}" <${user}>`,
            to: destinatario,
            subject: asunto,
            html: cuerpoHtml || `<p>Adjuntamos el documento solicitado.</p><p>— ${nombreEmpresa}</p>`,
            attachments: [
                {
                    filename: nombreArchivo || "documento.pdf",
                    content: Buffer.from(pdfBase64, "base64"),
                    contentType: "application/pdf",
                },
            ],
        });
        console.log(`✅ Email enviado a ${destinatario} — ${asunto}`);
        return { exito: true, mensaje: `Email enviado a ${destinatario}` };
    }
    catch (error) {
        console.error("❌ Error enviando email:", error);
        throw new https_1.HttpsError("internal", `Error enviando email: ${error instanceof Error ? error.message : "Desconocido"}`);
    }
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
            const contador = (_b = (_a = snap.data()) === null || _a === void 0 ? void 0 : _a.ultimo_numero_factura) !== null && _b !== void 0 ? _b : 0;
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
// ── VERIFACTU: Firma XAdES + Remisión AEAT ──────────────────────────────────
var firmarXMLVerifactu_1 = require("./firmarXMLVerifactu");
Object.defineProperty(exports, "firmarXMLVerifactu", { enumerable: true, get: function () { return firmarXMLVerifactu_1.firmarXMLVerifactu; } });
var remitirVerifactu_1 = require("./remitirVerifactu");
Object.defineProperty(exports, "remitirVerifactu", { enumerable: true, get: function () { return remitirVerifactu_1.remitirVerifactu; } });
//# sourceMappingURL=index.js.map