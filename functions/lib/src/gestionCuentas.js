"use strict";
/**
 * gestionCuentas.ts
 * ──────────────────────────────────────────────────────────────
 * Cloud Functions para gestión de suscripciones y cuentas.
 * Permite al propietario de la plataforma (FluxTech) crear y
 * administrar cuentas de clientes SIN pasar por las tiendas de
 * aplicaciones (evita el 30% de Apple y el 15% de Google).
 *
 * Seguridad:
 *   - Todas las callable functions verifican que el llamante
 *     tenga `es_plataforma_admin: true` en /usuarios/{uid}.
 *   - El webhook de pago web valida un token secreto en cabecera.
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
exports.webhookPagoWeb = exports.listarCuentasClientes = exports.actualizarPlanEmpresa = exports.crearCuentaConPlan = exports.PLANES_CONFIG = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
const REGION = "europe-west1";
// ─────────────────────────────────────────────────────────────────────────────
// PLANES DISPONIBLES — fuente canónica de verdad
// ─────────────────────────────────────────────────────────────────────────────
exports.PLANES_CONFIG = {
    basico: {
        id: "basico",
        nombre: "Plan Básico",
        precioAnual: 300,
        duracionDias: 365,
        descripcion: "Reservas, citas, clientes y estadísticas básicas.",
        modulos: [
            "dashboard",
            "reservas",
            "citas",
            "clientes",
            "valoraciones",
            "estadisticas",
        ],
    },
    profesional: {
        id: "profesional",
        nombre: "Plan Profesional",
        precioAnual: 500,
        duracionDias: 365,
        descripcion: "Todo el básico + facturación, pedidos, tareas y servicios.",
        modulos: [
            "dashboard",
            "reservas",
            "citas",
            "clientes",
            "valoraciones",
            "estadisticas",
            "servicios",
            "pedidos",
            "tareas",
            "facturacion",
        ],
    },
    premium: {
        id: "premium",
        nombre: "Plan Premium",
        precioAnual: 800,
        duracionDias: 365,
        descripcion: "Todo incluido: nóminas, empleados, web y fiscal completo.",
        modulos: [
            "dashboard",
            "reservas",
            "citas",
            "clientes",
            "valoraciones",
            "estadisticas",
            "servicios",
            "pedidos",
            "tareas",
            "facturacion",
            "nominas",
            "empleados",
            "web",
        ],
    },
};
// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
/** Genera una contraseña temporal de 12 caracteres seguros */
function generarPasswordTemporal() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$";
    let password = "";
    for (let i = 0; i < 12; i++) {
        password += chars[Math.floor(Math.random() * chars.length)];
    }
    // Asegurar al menos: mayúscula, minúscula, número, símbolo
    return password;
}
/** Verifica que el usuario que llama sea admin de la plataforma */
async function verificarPropietarioPlatforma(uid) {
    var _a;
    const doc = await db.collection("usuarios").doc(uid).get();
    if (!doc.exists || ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.es_plataforma_admin) !== true) {
        throw new https_1.HttpsError("permission-denied", "Solo el propietario de la plataforma puede realizar esta acción.");
    }
}
/** Envía email de bienvenida con credenciales usando la función de email existente */
async function enviarEmailBienvenida(email, nombreEmpresa, tempPassword, planNombre, smtpUser, smtpPass, smtpHost, smtpPort) {
    const nodemailer = await Promise.resolve().then(() => __importStar(require("nodemailer")));
    const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: parseInt(smtpPort),
        secure: parseInt(smtpPort) === 465,
        auth: { user: smtpUser, pass: smtpPass },
    });
    const html = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f7fa;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f7fa;padding:40px 20px;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,.08);">
        <!-- Header -->
        <tr><td style="background:linear-gradient(135deg,#0D47A1,#1976D2);padding:32px 40px;text-align:center;">
          <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700;">🚀 ¡Bienvenido a Fluix CRM!</h1>
          <p style="color:rgba(255,255,255,.85);margin:8px 0 0;font-size:15px;">Tu negocio, bajo control</p>
        </td></tr>
        <!-- Body -->
        <tr><td style="padding:40px;">
          <h2 style="color:#1a1a2e;margin:0 0 8px;font-size:20px;">Hola, ${nombreEmpresa} 👋</h2>
          <p style="color:#555;font-size:15px;line-height:1.6;margin:0 0 24px;">
            Tu cuenta en <strong>Fluix CRM</strong> ha sido activada con el <strong>${planNombre}</strong>.
            Aquí están tus credenciales de acceso:
          </p>

          <!-- Credentials box -->
          <div style="background:#f0f4ff;border:1px solid #c5d3f0;border-radius:12px;padding:24px;margin-bottom:24px;">
            <p style="margin:0 0 12px;"><strong style="color:#0D47A1;">📧 Email:</strong><br>
              <span style="font-size:17px;font-family:monospace;color:#1a1a2e;">${email}</span>
            </p>
            <p style="margin:0;"><strong style="color:#0D47A1;">🔑 Contraseña temporal:</strong><br>
              <span style="font-size:20px;font-family:monospace;font-weight:700;color:#1a1a2e;letter-spacing:2px;">${tempPassword}</span>
            </p>
          </div>

          <div style="background:#fff8e1;border:1px solid #ffe082;border-radius:10px;padding:16px;margin-bottom:24px;">
            <p style="margin:0;color:#f57f17;font-size:14px;">
              ⚠️ <strong>Por seguridad</strong>, te recomendamos cambiar la contraseña en tu primera sesión:
              Perfil → Seguridad → Cambiar contraseña.
            </p>
          </div>

          <p style="color:#555;font-size:14px;margin:0 0 24px;">
            Descarga la app <strong>Fluix CRM</strong> en tu teléfono o accede desde la web,
            inicia sesión con las credenciales de arriba y empieza a gestionar tu negocio.
          </p>

          <div style="text-align:center;margin:32px 0 0;">
            <a href="https://fluixcrm.app" style="background:linear-gradient(135deg,#0D47A1,#1976D2);color:#fff;text-decoration:none;padding:14px 36px;border-radius:10px;font-size:16px;font-weight:700;display:inline-block;">
              Acceder ahora →
            </a>
          </div>
        </td></tr>
        <!-- Footer -->
        <tr><td style="background:#f5f7fa;padding:20px 40px;text-align:center;border-top:1px solid #eee;">
          <p style="margin:0;color:#999;font-size:12px;">Fluix CRM · FluxTech · soporte@fluixcrm.app</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
    await transporter.sendMail({
        from: `"Fluix CRM" <${smtpUser}>`,
        to: email,
        subject: `🚀 Tu cuenta Fluix CRM está lista — ${planNombre}`,
        html,
    });
}
// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 1: crearCuentaConPlan
// ─────────────────────────────────────────────────────────────────────────────
/**
 * Callable. El propietario de la plataforma llama a esta función para
 * crear un nuevo cliente (empresa + usuario propietario).
 *
 * data: {
 *   email: string            — email del propietario del nuevo negocio
 *   planId: string           — "basico" | "profesional" | "premium"
 *   nombreEmpresa: string    — nombre del negocio
 *   tipoNegocio?: string     — "Peluquería", "Restaurante", etc.
 *   nombrePropietario?: string
 * }
 */
exports.crearCuentaConPlan = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Autenticación
    const callerUid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!callerUid)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado.");
    // 2. Verificar que es el propietario de la plataforma
    await verificarPropietarioPlatforma(callerUid);
    // 3. Validar datos de entrada
    const { email, planId, nombreEmpresa, tipoNegocio = "Otro", nombrePropietario = "", } = request.data;
    if (!email || !planId || !nombreEmpresa) {
        throw new https_1.HttpsError("invalid-argument", "email, planId y nombreEmpresa son obligatorios.");
    }
    const plan = exports.PLANES_CONFIG[planId];
    if (!plan) {
        throw new https_1.HttpsError("invalid-argument", `Plan desconocido: ${planId}. Usa: ${Object.keys(exports.PLANES_CONFIG).join(", ")}`);
    }
    // 4. Generar contraseña temporal
    const tempPassword = generarPasswordTemporal();
    // 5. Crear usuario en Firebase Auth
    let newUser;
    try {
        newUser = await admin.auth().createUser({
            email: email.toLowerCase().trim(),
            password: tempPassword,
            displayName: nombreEmpresa,
            emailVerified: false,
        });
    }
    catch (err) {
        const authErr = err;
        if (authErr.code === "auth/email-already-exists") {
            throw new https_1.HttpsError("already-exists", `Ya existe una cuenta con el email ${email}.`);
        }
        throw new https_1.HttpsError("internal", `Error creando usuario: ${authErr.message}`);
    }
    const uid = newUser.uid;
    const empresaId = uid; // El ID de empresa es el mismo que el UID del propietario
    // 6. Calcular fechas de suscripción
    const ahora = new Date();
    const fechaFin = new Date(ahora);
    fechaFin.setDate(fechaFin.getDate() + plan.duracionDias);
    try {
        const batch = db.batch();
        // 6a. Crear documento de empresa
        const empresaRef = db.collection("empresas").doc(empresaId);
        batch.set(empresaRef, {
            nombre: nombreEmpresa,
            tipo_negocio: tipoNegocio,
            telefono: "",
            direccion: "",
            descripcion: "",
            email_contacto: email,
            sector: "otros",
            horarios: {
                apertura: "09:00",
                cierre: "20:00",
                lunes: true,
                martes: true,
                miercoles: true,
                jueves: true,
                viernes: true,
                sabado: false,
                domingo: false,
            },
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
            activa: true,
            plan_id: planId,
        });
        // 6b. Suscripción
        const suscripcionRef = empresaRef.collection("suscripcion").doc("actual");
        batch.set(suscripcionRef, {
            plan: planId,
            plan_nombre: plan.nombre,
            precio_anual: plan.precioAnual,
            modulos_activos: plan.modulos,
            estado: "ACTIVA",
            fecha_inicio: admin.firestore.Timestamp.fromDate(ahora),
            fecha_fin: admin.firestore.Timestamp.fromDate(fechaFin),
            creada_por: callerUid,
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
            metodo_pago: "externo_web",
        });
        // 6c. Configuración de módulos (todos OFF por defecto, el usuario los activa)
        const configuracionRef = empresaRef
            .collection("configuracion")
            .doc("modulos");
        const modulosConfig = {};
        plan.modulos.forEach((m) => {
            modulosConfig[m] = false; // OFF por defecto
        });
        batch.set(configuracionRef, Object.assign(Object.assign({}, modulosConfig), { fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp() }));
        // 6d. Documento de usuario (admin del negocio — no es propietario de la plataforma)
        const usuarioRef = db.collection("usuarios").doc(uid);
        batch.set(usuarioRef, {
            uid,
            nombre: nombrePropietario || nombreEmpresa,
            correo: email,
            empresa_id: empresaId,
            rol: "propietario",
            es_plataforma_admin: false,
            fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
            modulos_personalizados: null,
        });
        await batch.commit();
        console.log(`✅ Cuenta creada: uid=${uid}, empresa=${empresaId}, plan=${planId}`);
    }
    catch (err) {
        // Si falló Firestore, borrar el usuario de Auth para no dejar huérfanos
        await admin.auth().deleteUser(uid).catch(() => { });
        throw new https_1.HttpsError("internal", `Error creando datos en Firestore: ${err.message}`);
    }
    // 7. Enviar email de bienvenida (no bloquea si falla)
    try {
        const smtpHost = (_b = process.env.SMTP_HOST) !== null && _b !== void 0 ? _b : "";
        const smtpPort = (_c = process.env.SMTP_PORT) !== null && _c !== void 0 ? _c : "587";
        const smtpUser = (_d = process.env.SMTP_USER) !== null && _d !== void 0 ? _d : "";
        const smtpPass = (_e = process.env.SMTP_PASS) !== null && _e !== void 0 ? _e : "";
        if (smtpUser && smtpPass) {
            await enviarEmailBienvenida(email, nombreEmpresa, tempPassword, plan.nombre, smtpUser, smtpPass, smtpHost, smtpPort);
            console.log(`📧 Email de bienvenida enviado a ${email}`);
        }
    }
    catch (emailErr) {
        console.warn("⚠️ Email de bienvenida no enviado:", emailErr);
    }
    return {
        ok: true,
        empresaId,
        uid,
        email,
        planId,
        planNombre: plan.nombre,
        tempPassword, // Lo recibe el propietario de la plataforma para anotarlo
        fechaFin: fechaFin.toISOString(),
    };
});
// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 2: actualizarPlanEmpresa
// ─────────────────────────────────────────────────────────────────────────────
/**
 * Callable. Actualiza el plan de una empresa existente.
 *
 * data: {
 *   empresaId: string
 *   nuevoPlanId: string
 *   extenderDias?: number  — si 0 mantiene la fecha_fin actual, si >0 extiende
 * }
 */
exports.actualizarPlanEmpresa = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e;
    const callerUid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!callerUid)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado.");
    await verificarPropietarioPlatforma(callerUid);
    const { empresaId, nuevoPlanId, extenderDias = 365, } = request.data;
    if (!empresaId || !nuevoPlanId) {
        throw new https_1.HttpsError("invalid-argument", "empresaId y nuevoPlanId son obligatorios.");
    }
    const nuevoPlan = exports.PLANES_CONFIG[nuevoPlanId];
    if (!nuevoPlan) {
        throw new https_1.HttpsError("invalid-argument", `Plan desconocido: ${nuevoPlanId}`);
    }
    // Leer suscripción actual
    const suscripcionRef = db
        .collection("empresas")
        .doc(empresaId)
        .collection("suscripcion")
        .doc("actual");
    const suscripcionSnap = await suscripcionRef.get();
    let fechaFin;
    if (suscripcionSnap.exists && extenderDias === 0) {
        // Mantener fecha_fin existente
        fechaFin =
            (_d = (_c = (_b = suscripcionSnap.data()) === null || _b === void 0 ? void 0 : _b.fecha_fin) === null || _c === void 0 ? void 0 : _c.toDate()) !== null && _d !== void 0 ? _d : new Date();
    }
    else {
        // Extender desde ahora
        fechaFin = new Date();
        fechaFin.setDate(fechaFin.getDate() + (extenderDias || 365));
    }
    const batch = db.batch();
    // Actualizar suscripción
    batch.set(suscripcionRef, {
        plan: nuevoPlanId,
        plan_nombre: nuevoPlan.nombre,
        precio_anual: nuevoPlan.precioAnual,
        modulos_activos: nuevoPlan.modulos,
        estado: "ACTIVA",
        fecha_fin: admin.firestore.Timestamp.fromDate(fechaFin),
        actualizado_por: callerUid,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Actualizar empresa
    batch.update(db.collection("empresas").doc(empresaId), {
        plan_id: nuevoPlanId,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Actualizar módulos en configuración (añadir nuevos módulos como OFF)
    const configRef = db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("modulos");
    const configSnap = await configRef.get();
    const configActual = (_e = configSnap.data()) !== null && _e !== void 0 ? _e : {};
    const modulosNuevos = {};
    nuevoPlan.modulos.forEach((m) => {
        // No sobreescribir los que ya estaban activos
        if (!(m in configActual)) {
            modulosNuevos[m] = false;
        }
    });
    if (Object.keys(modulosNuevos).length > 0) {
        batch.set(configRef, modulosNuevos, { merge: true });
    }
    await batch.commit();
    console.log(`✅ Plan actualizado: empresa=${empresaId}, nuevo plan=${nuevoPlanId}`);
    return {
        ok: true,
        empresaId,
        nuevoPlanId,
        planNombre: nuevoPlan.nombre,
        fechaFin: fechaFin.toISOString(),
    };
});
// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 3: listarCuentasClientes
// ─────────────────────────────────────────────────────────────────────────────
/**
 * Callable. Devuelve la lista de todas las empresas registradas con su
 * estado de suscripción. Solo accesible por el admin de la plataforma.
 */
exports.listarCuentasClientes = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v;
    const callerUid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!callerUid)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado.");
    await verificarPropietarioPlatforma(callerUid);
    const empresasSnap = await db
        .collection("empresas")
        .orderBy("fecha_creacion", "desc")
        .limit(200)
        .get();
    const result = [];
    for (const doc of empresasSnap.docs) {
        const empresa = doc.data();
        const suscripcionSnap = await doc.ref
            .collection("suscripcion")
            .doc("actual")
            .get();
        const suscripcion = suscripcionSnap.data();
        result.push({
            empresaId: doc.id,
            nombre: (_b = empresa.nombre) !== null && _b !== void 0 ? _b : "—",
            email: (_c = empresa.email_contacto) !== null && _c !== void 0 ? _c : "",
            tipoNegocio: (_d = empresa.tipo_negocio) !== null && _d !== void 0 ? _d : "",
            planId: (_e = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.plan) !== null && _e !== void 0 ? _e : "sin_plan",
            planNombre: (_f = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.plan_nombre) !== null && _f !== void 0 ? _f : "Sin plan",
            estado: (_g = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.estado) !== null && _g !== void 0 ? _g : "DESCONOCIDO",
            fechaFin: (_l = (_k = (_j = (_h = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.fecha_fin) === null || _h === void 0 ? void 0 : _h.toDate) === null || _j === void 0 ? void 0 : _j.call(_h)) === null || _k === void 0 ? void 0 : _k.toISOString()) !== null && _l !== void 0 ? _l : null,
            activa: (_m = empresa.activa) !== null && _m !== void 0 ? _m : false,
            fechaCreacion: (_r = (_q = (_p = (_o = empresa.fecha_creacion) === null || _o === void 0 ? void 0 : _o.toDate) === null || _p === void 0 ? void 0 : _p.call(_o)) === null || _q === void 0 ? void 0 : _q.toISOString()) !== null && _r !== void 0 ? _r : null,
            // Campos V2
            packsActivos: (_s = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.packs_activos) !== null && _s !== void 0 ? _s : [],
            addonsActivos: (_t = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.addons_activos) !== null && _t !== void 0 ? _t : [],
            empleadosNomina: (_u = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.empleados_nomina) !== null && _u !== void 0 ? _u : 0,
            precioTotal: (_v = suscripcion === null || suscripcion === void 0 ? void 0 : suscripcion.precio_total) !== null && _v !== void 0 ? _v : 0,
        });
    }
    return { ok: true, cuentas: result };
});
// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 4: webhookPagoWeb
// ─────────────────────────────────────────────────────────────────────────────
/**
 * HTTP endpoint. Tu web llama a este endpoint cuando alguien completa un pago.
 * Notifica al propietario de la plataforma y opcionalmente activa/crea la cuenta.
 *
 * Headers requeridos:
 *   X-Fluix-Secret: <token secreto definido en FLUIX_WEBHOOK_SECRET env var>
 *
 * Body JSON:
 * {
 *   email: string,
 *   planId: string,
 *   nombreEmpresa: string,
 *   tipoNegocio?: string,
 *   importe: number,          — en euros
 *   referenciaPago: string,   — ID de la transacción en tu web
 *   crearCuentaAuto?: boolean — si true, crea la cuenta automáticamente
 * }
 */
exports.webhookPagoWeb = (0, https_1.onRequest)({ region: REGION, cors: false }, async (req, res) => {
    var _a, _b, _c, _d, _e, _f;
    // Solo POST
    if (req.method !== "POST") {
        res.status(405).json({ error: "Método no permitido" });
        return;
    }
    // Validar token secreto
    const secretEnv = (_a = process.env.FLUIX_WEBHOOK_SECRET) !== null && _a !== void 0 ? _a : "";
    const secretHeader = req.headers["x-fluix-secret"];
    if (!secretEnv || secretHeader !== secretEnv) {
        console.warn("🔒 Webhook rechazado: token inválido");
        res.status(401).json({ error: "No autorizado" });
        return;
    }
    try {
        const { email, planId, nombreEmpresa, tipoNegocio = "Otro", importe, referenciaPago, crearCuentaAuto = false, } = req.body;
        if (!email || !planId || !importe || !referenciaPago) {
            res.status(400).json({ error: "Faltan campos: email, planId, importe, referenciaPago" });
            return;
        }
        const plan = exports.PLANES_CONFIG[planId];
        const planNombre = (_b = plan === null || plan === void 0 ? void 0 : plan.nombre) !== null && _b !== void 0 ? _b : planId;
        // 1. Registrar el pago en la colección de pagos de plataforma
        await db.collection("plataforma_pagos").add({
            email,
            planId,
            planNombre,
            nombreEmpresa: nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : "—",
            tipoNegocio,
            importe,
            referenciaPago,
            crearCuentaAuto,
            estado: "recibido",
            fecha: admin.firestore.FieldValue.serverTimestamp(),
        });
        // 2. Notificar al propietario de la plataforma (buscar sus dispositivos)
        const adminsSnap = await db
            .collection("usuarios")
            .where("es_plataforma_admin", "==", true)
            .get();
        for (const adminDoc of adminsSnap.docs) {
            const adminData = adminDoc.data();
            const adminEmpresaId = adminData.empresa_id;
            if (!adminEmpresaId)
                continue;
            // Obtener tokens de FCM del admin
            const dispositivosSnap = await db
                .collection("empresas")
                .doc(adminEmpresaId)
                .collection("dispositivos")
                .where("activo", "==", true)
                .get();
            const tokens = [];
            dispositivosSnap.forEach((d) => {
                const token = d.data().token;
                if (token)
                    tokens.push(token);
            });
            if (tokens.length > 0) {
                await admin.messaging().sendEachForMulticast({
                    tokens,
                    notification: {
                        title: "💰 Nuevo pago recibido en la web",
                        body: `${nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : email} — ${planNombre} — €${importe}`,
                    },
                    data: {
                        tipo: "pago_web",
                        email,
                        plan_id: planId,
                        importe: String(importe),
                        referencia: referenciaPago,
                    },
                });
            }
        }
        // 3. Si crearCuentaAuto, intentar crear la cuenta automáticamente
        let cuentaCreada = false;
        let tempPassword = null;
        if (crearCuentaAuto && plan) {
            try {
                tempPassword = generarPasswordTemporal();
                const newUser = await admin.auth().createUser({
                    email: email.toLowerCase().trim(),
                    password: tempPassword,
                    displayName: nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : email,
                });
                const uid = newUser.uid;
                const empresaId = uid;
                const ahora = new Date();
                const fechaFin = new Date(ahora);
                fechaFin.setDate(fechaFin.getDate() + plan.duracionDias);
                const batch = db.batch();
                batch.set(db.collection("empresas").doc(empresaId), {
                    nombre: nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : email,
                    tipo_negocio: tipoNegocio,
                    email_contacto: email,
                    activa: true,
                    plan_id: planId,
                    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
                });
                batch.set(db
                    .collection("empresas")
                    .doc(empresaId)
                    .collection("suscripcion")
                    .doc("actual"), {
                    plan: planId,
                    plan_nombre: plan.nombre,
                    precio_anual: plan.precioAnual,
                    modulos_activos: plan.modulos,
                    estado: "ACTIVA",
                    fecha_inicio: admin.firestore.Timestamp.fromDate(ahora),
                    fecha_fin: admin.firestore.Timestamp.fromDate(fechaFin),
                    referencia_pago: referenciaPago,
                    metodo_pago: "web",
                    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
                });
                const modulosConfig = {};
                plan.modulos.forEach((m) => { modulosConfig[m] = false; });
                batch.set(db.collection("empresas").doc(empresaId).collection("configuracion").doc("modulos"), Object.assign({}, modulosConfig));
                batch.set(db.collection("usuarios").doc(uid), {
                    uid,
                    nombre: nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : email,
                    correo: email,
                    empresa_id: empresaId,
                    rol: "admin",
                    activo: true,
                    es_plataforma_admin: false,
                    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
                });
                await batch.commit();
                // Actualizar registro de pago
                await db
                    .collection("plataforma_pagos")
                    .where("referenciaPago", "==", referenciaPago)
                    .limit(1)
                    .get()
                    .then((snap) => {
                    if (!snap.empty) {
                        snap.docs[0].ref.update({
                            estado: "cuenta_creada",
                            empresa_id: empresaId,
                        });
                    }
                });
                cuentaCreada = true;
                // Enviar email de bienvenida
                const smtpUser = (_c = process.env.SMTP_USER) !== null && _c !== void 0 ? _c : "";
                const smtpPass = (_d = process.env.SMTP_PASS) !== null && _d !== void 0 ? _d : "";
                if (smtpUser && smtpPass) {
                    await enviarEmailBienvenida(email, nombreEmpresa !== null && nombreEmpresa !== void 0 ? nombreEmpresa : email, tempPassword, plan.nombre, smtpUser, smtpPass, (_e = process.env.SMTP_HOST) !== null && _e !== void 0 ? _e : "", (_f = process.env.SMTP_PORT) !== null && _f !== void 0 ? _f : "587");
                }
                console.log(`✅ [webhookPago] Cuenta creada automáticamente: ${empresaId}`);
            }
            catch (autoErr) {
                console.error("⚠️ [webhookPago] Error creando cuenta automática:", autoErr);
            }
        }
        res.status(200).json({
            ok: true,
            message: "Pago registrado.",
            cuentaCreada,
            tempPassword: cuentaCreada ? tempPassword : undefined,
        });
    }
    catch (err) {
        console.error("❌ [webhookPagoWeb] Error:", err);
        res.status(500).json({ error: "Error interno del servidor" });
    }
});
//# sourceMappingURL=gestionCuentas.js.map