"use strict";
/**
 * GMB Respuestas — publicación automática de respuestas en Google Business Profile
 * + sincronización periódica de reseñas con alertas por reseñas negativas
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.resumenSemanalResenas = exports.alertaResenasNegativasAcumuladas = exports.scheduledSincronizarResenas = exports.procesarRespuestasPendientes = exports.publicarRespuestaGoogle = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const node_fetch_1 = require("node-fetch");
const gmbTokens_1 = require("./gmbTokens");
const gmbSnapshots_1 = require("./gmbSnapshots");
const REGION = "europe-west1";
// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ── Utilidades de notificación ────────────────────────────────────────────────
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
async function enviarNotificacionPush(empresaId, titulo, cuerpo, data = {}, alta_prioridad = false) {
    const tokens = await obtenerTokensEmpresa(empresaId);
    if (tokens.length === 0)
        return;
    const mensaje = {
        tokens,
        notification: { title: titulo, body: cuerpo },
        data: Object.assign({ empresa_id: empresaId }, data),
        android: {
            priority: "high",
            notification: {
                channelId: alta_prioridad
                    ? "fluixcrm_resenas_negativas"
                    : "fluixcrm_canal_principal",
                sound: alta_prioridad ? "alarma_negativa" : "default",
                priority: alta_prioridad ? "max" : "high",
                visibility: "public",
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: alta_prioridad ? "alarma_negativa.aiff" : "default",
                    badge: 1,
                    "interruption-level": alta_prioridad ? "time-sensitive" : "active",
                },
            },
        },
    };
    try {
        const res = await messaging.sendEachForMulticast(mensaje);
        console.log(`✅ Push enviado: ${res.successCount}/${tokens.length} para ${empresaId}`);
    }
    catch (err) {
        console.error("❌ Error enviando push:", err);
    }
}
// ── Publicar respuesta en Google Business Profile API ────────────────────────
async function llamarApiGmbRespuesta(accessToken, reviewName, comentario) {
    var _a, _b;
    // reviewName tiene formato: "accounts/X/locations/Y/reviews/Z"
    const url = `https://mybusiness.googleapis.com/v4/${reviewName}/reply`;
    const res = await (0, node_fetch_1.default)(url, {
        method: "PUT", // PUT crea o edita la respuesta
        headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ comment: comentario }),
    });
    if (res.ok)
        return { ok: true };
    const errorData = (await res.json());
    const errorMsg = (_b = (_a = errorData.error) === null || _a === void 0 ? void 0 : _a.message) !== null && _b !== void 0 ? _b : `HTTP ${res.status}`;
    // Comprobar si la reseña fue eliminada por Google
    if (res.status === 404) {
        return { ok: false, error: "REVIEW_DELETED" };
    }
    return { ok: false, error: errorMsg };
}
/**
 * publicarRespuestaGoogle
 * Publica la respuesta a una reseña directamente en Google Maps.
 */
exports.publicarRespuestaGoogle = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a;
    const { empresaId, valoracionId, texto } = request.data;
    if (!empresaId || !valoracionId || !texto) {
        throw new https_1.HttpsError("invalid-argument", "empresaId, valoracionId y texto son requeridos");
    }
    const valoracionRef = db
        .collection("empresas")
        .doc(empresaId)
        .collection("valoraciones")
        .doc(valoracionId);
    const snap = await valoracionRef.get();
    if (!snap.exists) {
        throw new https_1.HttpsError("not-found", "Valoración no encontrada");
    }
    const data = snap.data();
    const reviewName = data.google_review_name;
    // Guardar siempre en Firestore primero
    await valoracionRef.update({
        respuesta: texto,
        fecha_respuesta: admin.firestore.FieldValue.serverTimestamp(),
        respuesta_estado: "publicando",
        respuesta_intentos: 0,
    });
    if (!reviewName) {
        // No tiene nombre de recurso GMB → solo guardamos en Firestore
        await valoracionRef.update({ respuesta_estado: "sin_gmb" });
        return { success: true, publicado_google: false };
    }
    // Verificar que la empresa tiene GMB configurado
    const configSnap = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("gmb_config")
        .get();
    if (!configSnap.exists || !((_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.conectado)) {
        await valoracionRef.update({ respuesta_estado: "sin_conexion_gmb" });
        return { success: true, publicado_google: false };
    }
    try {
        const accessToken = await (0, gmbTokens_1.getValidGmbAccessToken)(empresaId);
        const resultado = await llamarApiGmbRespuesta(accessToken, reviewName, texto);
        if (resultado.ok) {
            await valoracionRef.update({
                respuesta_estado: "publicada",
                respuesta_subida_google: true,
                respuesta_publicada_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`✅ Respuesta publicada en Google para ${reviewName}`);
            return { success: true, publicado_google: true };
        }
        else {
            if (resultado.error === "REVIEW_DELETED") {
                await valoracionRef.update({
                    respuesta_estado: "resena_eliminada",
                    eliminada_por_google: true,
                });
                return {
                    success: false,
                    publicado_google: false,
                    error: "REVIEW_DELETED",
                };
            }
            // Añadir a cola de pendientes para reintento
            await db
                .collection("empresas")
                .doc(empresaId)
                .collection("respuestas_pendientes")
                .doc(valoracionId)
                .set({
                empresaId,
                valoracionId,
                reviewName,
                texto,
                intentos: 1,
                max_intentos: 3,
                proximo_intento: admin.firestore.Timestamp.fromMillis(Date.now() + 5 * 60 * 1000),
                creado_at: admin.firestore.FieldValue.serverTimestamp(),
                error: resultado.error,
            });
            await valoracionRef.update({
                respuesta_estado: "error_pendiente",
                respuesta_intentos: 1,
                respuesta_ultimo_error: resultado.error,
            });
            return {
                success: false,
                publicado_google: false,
                error: resultado.error,
                en_cola: true,
            };
        }
    }
    catch (err) {
        console.error("❌ Error publicando respuesta:", err);
        // Poner en cola para reintento
        await db
            .collection("empresas")
            .doc(empresaId)
            .collection("respuestas_pendientes")
            .doc(valoracionId)
            .set({
            empresaId,
            valoracionId,
            reviewName,
            texto,
            intentos: 1,
            max_intentos: 3,
            proximo_intento: admin.firestore.Timestamp.fromMillis(Date.now() + 5 * 60 * 1000),
            creado_at: admin.firestore.FieldValue.serverTimestamp(),
            error: String(err),
        });
        await valoracionRef.update({
            respuesta_estado: "error_pendiente",
            respuesta_intentos: 1,
        });
        throw new https_1.HttpsError("internal", "Error publicando en Google");
    }
});
/**
 * procesarRespuestasPendientes
 * Se ejecuta cada 5 minutos para reintentar respuestas fallidas.
 */
exports.procesarRespuestasPendientes = (0, scheduler_1.onSchedule)({ schedule: "every 5 minutes", region: REGION }, async () => {
    const ahora = admin.firestore.Timestamp.now();
    // Buscar empresas con respuestas pendientes
    // (búsqueda cross-collection group)
    const pendientesSnap = await db
        .collectionGroup("respuestas_pendientes")
        .where("proximo_intento", "<=", ahora)
        .where("intentos", "<", 3)
        .limit(50)
        .get();
    console.log(`🔄 Procesando ${pendientesSnap.size} respuestas pendientes...`);
    for (const doc of pendientesSnap.docs) {
        const item = doc.data();
        try {
            const accessToken = await (0, gmbTokens_1.getValidGmbAccessToken)(item.empresaId);
            const resultado = await llamarApiGmbRespuesta(accessToken, item.reviewName, item.texto);
            const valoracionRef = db
                .collection("empresas")
                .doc(item.empresaId)
                .collection("valoraciones")
                .doc(item.valoracionId);
            if (resultado.ok) {
                // Publicado con éxito → eliminar de la cola
                await doc.ref.delete();
                await valoracionRef.update({
                    respuesta_estado: "publicada",
                    respuesta_subida_google: true,
                    respuesta_publicada_at: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`✅ Reintento exitoso para ${item.reviewName}`);
            }
            else {
                const nuevosIntentos = item.intentos + 1;
                if (nuevosIntentos >= item.max_intentos) {
                    // Máximo de reintentos alcanzado → notificar al propietario
                    await doc.ref.update({
                        intentos: nuevosIntentos,
                        error_final: resultado.error,
                    });
                    await valoracionRef.update({
                        respuesta_estado: "error_definitivo",
                        respuesta_intentos: nuevosIntentos,
                    });
                    await enviarNotificacionPush(item.empresaId, "⚠️ Error publicando respuesta", "No pudimos publicar tu respuesta en Google. Inténtalo manualmente.", {
                        tipo: "error_respuesta_google",
                        valoracion_id: item.valoracionId,
                    });
                }
                else {
                    // Programar siguiente reintento
                    await doc.ref.update({
                        intentos: nuevosIntentos,
                        proximo_intento: admin.firestore.Timestamp.fromMillis(Date.now() + 5 * 60 * 1000 * nuevosIntentos),
                        error: resultado.error,
                    });
                }
            }
        }
        catch (err) {
            console.error(`❌ Error reintentando respuesta ${doc.id}:`, err);
        }
    }
});
// ── Sincronización periódica de reseñas con alertas ──────────────────────────
/**
 * scheduledSincronizarResenas
 * Se ejecuta cada 30 minutos para sincronizar reseñas desde GMB API.
 * Detecta reseñas nuevas y envía alertas según el rating.
 */
exports.scheduledSincronizarResenas = (0, scheduler_1.onSchedule)({
    schedule: "every 30 minutes",
    region: REGION,
    timeoutSeconds: 300,
}, async () => {
    var _a;
    console.log("🔄 Iniciando sincronización periódica de reseñas GMB...");
    // Obtener todas las empresas con GMB conectado
    const empresasSnap = await db.collection("empresas").get();
    let sincronizadas = 0;
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            const configSnap = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("configuracion")
                .doc("gmb_config")
                .get();
            if (!configSnap.exists || !((_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.conectado))
                continue;
            const config = configSnap.data();
            const locationId = config.location_id;
            if (!locationId)
                continue;
            await sincronizarResenasEmpresa(empresaId, locationId);
            sincronizadas++;
        }
        catch (err) {
            console.error(`❌ Error sincronizando empresa ${empresaId}:`, err);
        }
    }
    console.log(`✅ Sincronización completada: ${sincronizadas} empresas`);
});
async function sincronizarResenasEmpresa(empresaId, locationId) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q;
    const accessToken = await (0, gmbTokens_1.getValidGmbAccessToken)(empresaId);
    // Obtener configuración de umbral de alertas
    const prefSnap = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("alertas_resenas")
        .get();
    const umbralAlerta = (_b = (_a = prefSnap.data()) === null || _a === void 0 ? void 0 : _a.umbral_alerta) !== null && _b !== void 0 ? _b : 3;
    // Llamar a Business Profile API para obtener reseñas
    const url = `https://mybusiness.googleapis.com/v4/${locationId}/reviews?pageSize=10`;
    const res = await (0, node_fetch_1.default)(url, {
        headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
        const errData = (await res.json());
        throw new Error(`GMB API error: ${(_d = (_c = errData.error) === null || _c === void 0 ? void 0 : _c.message) !== null && _d !== void 0 ? _d : res.status}`);
    }
    const data = (await res.json());
    const reviews = (_e = data.reviews) !== null && _e !== void 0 ? _e : [];
    const ratingGlobal = (_f = data.averageRating) !== null && _f !== void 0 ? _f : 0;
    const totalGlobal = (_g = data.totalReviewCount) !== null && _g !== void 0 ? _g : 0;
    // Mapa de estrellas texto → número
    const starMap = {
        ONE: 1, TWO: 2, THREE: 3, FOUR: 4, FIVE: 5,
    };
    const valoracionesRef = db
        .collection("empresas")
        .doc(empresaId)
        .collection("valoraciones");
    let nuevasNegativas = 0;
    let nuevasPositivas = 0;
    const resenasProcesadas = [];
    for (const review of reviews) {
        const reviewId = (_h = review.name.split("/").pop()) !== null && _h !== void 0 ? _h : review.name;
        const docId = `gmb_${reviewId}`;
        const calificacion = (_j = starMap[review.starRating]) !== null && _j !== void 0 ? _j : 5;
        const nombre = (_k = review.reviewer.displayName) !== null && _k !== void 0 ? _k : "Cliente de Google";
        const comentario = (_l = review.comment) !== null && _l !== void 0 ? _l : "";
        const fecha = new Date(review.createTime);
        // Comprobar si ya existe en Firestore
        const existeSnap = await valoracionesRef.doc(docId).get();
        const yaExistia = existeSnap.exists;
        // Si tiene respuesta de Google, sincronizar también
        const respuestaGoogle = (_m = review.reviewReply) === null || _m === void 0 ? void 0 : _m.comment;
        await valoracionesRef.doc(docId).set(Object.assign({ id: docId, cliente: nombre, calificacion,
            comentario, fecha: admin.firestore.Timestamp.fromDate(fecha), origen: "google", avatar_url: (_o = review.reviewer.profilePhotoUrl) !== null && _o !== void 0 ? _o : null, google_review_name: review.name, google_review_id: reviewId, google_time: fecha.getTime() / 1000 }, (respuestaGoogle && !((_p = existeSnap.data()) === null || _p === void 0 ? void 0 : _p.respuesta)
            ? {
                respuesta: respuestaGoogle,
                respuesta_estado: "publicada",
                respuesta_subida_google: true,
            }
            : {})), { merge: true });
        resenasProcesadas.push(docId);
        // Solo alertar por reseñas nuevas que aún no generaron notificación
        if (!yaExistia || !((_q = existeSnap.data()) === null || _q === void 0 ? void 0 : _q.notificacion_enviada)) {
            if (calificacion <= umbralAlerta) {
                nuevasNegativas++;
                await enviarNotificacionPush(empresaId, `⚠️ Nueva reseña de ${calificacion} ${calificacion === 1 ? "estrella" : "estrellas"}`, `${nombre}: "${comentario.substring(0, 80)}${comentario.length > 80 ? "..." : ""}"`, {
                    tipo: "resena_negativa",
                    valoracion_id: docId,
                    calificacion: String(calificacion),
                }, true // alta prioridad
                );
            }
            else {
                nuevasPositivas++;
                await enviarNotificacionPush(empresaId, `⭐ Nueva reseña positiva de ${nombre}`, `${calificacion} estrellas: "${comentario.substring(0, 60)}${comentario.length > 60 ? "..." : ""}"`, {
                    tipo: "resena_positiva",
                    valoracion_id: docId,
                    calificacion: String(calificacion),
                });
            }
            // Marcar que ya se envió notificación para esta reseña
            await valoracionesRef.doc(docId).update({
                notificacion_enviada: true,
                notificacion_enviada_at: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
    // Actualizar estadísticas en Firestore
    await db
        .collection("empresas")
        .doc(empresaId)
        .collection("estadisticas")
        .doc("resumen")
        .set({
        rating_google: ratingGlobal,
        total_resenas_google: totalGlobal,
        ultima_sync_google: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // Actualizar timestamp de última sync en gmb_config
    await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("gmb_config")
        .update({
        ultima_sync: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Limpiar sobrantes (máx 50 reseñas)
    await limpiarResenasSobrantes(empresaId);
    // Guardar snapshot mensual de rating
    await (0, gmbSnapshots_1.guardarSnapshotMensual)(empresaId);
    if (nuevasNegativas > 0 || nuevasPositivas > 0) {
        console.log(`📊 ${empresaId}: ${nuevasNegativas} negativas, ${nuevasPositivas} positivas`);
    }
}
async function limpiarResenasSobrantes(empresaId) {
    const MAX_RESENAS = 50;
    const todas = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("valoraciones")
        .orderBy("fecha", "asc")
        .get();
    if (todas.size <= MAX_RESENAS)
        return;
    const aBorrar = todas.size - MAX_RESENAS;
    const batch = db.batch();
    for (const doc of todas.docs.slice(0, aBorrar)) {
        batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`🗑️ Eliminadas ${aBorrar} reseñas antiguas de ${empresaId}`);
}
/**
 * alertaResenasNegativasAcumuladas
 * Ejecuta diariamente: si hay 3+ reseñas negativas en el día, envía alerta especial.
 */
exports.alertaResenasNegativasAcumuladas = (0, scheduler_1.onSchedule)({ schedule: "every 24 hours", region: REGION }, async () => {
    var _a, _b, _c;
    console.log("🔍 Comprobando reseñas negativas acumuladas hoy...");
    const inicioDelDia = new Date();
    inicioDelDia.setHours(0, 0, 0, 0);
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            const configSnap = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("configuracion")
                .doc("gmb_config")
                .get();
            if (!configSnap.exists || !((_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.conectado))
                continue;
            const prefSnap = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("configuracion")
                .doc("alertas_resenas")
                .get();
            const umbralAlerta = (_c = (_b = prefSnap.data()) === null || _b === void 0 ? void 0 : _b.umbral_alerta) !== null && _c !== void 0 ? _c : 3;
            const negativasHoy = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("valoraciones")
                .where("origen", "==", "google")
                .where("fecha", ">=", admin.firestore.Timestamp.fromDate(inicioDelDia))
                .where("calificacion", "<=", umbralAlerta)
                .get();
            if (negativasHoy.size >= 3) {
                await enviarNotificacionPush(empresaId, "⚠️ Atención: Varias reseñas negativas hoy", `Has recibido ${negativasHoy.size} reseñas negativas hoy. Responde para mostrar tu profesionalidad.`, {
                    tipo: "alerta_acumulada",
                    cantidad: String(negativasHoy.size),
                }, true);
                console.log(`🚨 Alerta acumulada enviada a ${empresaId}: ${negativasHoy.size} negativas`);
            }
        }
        catch (err) {
            console.error(`❌ Error comprobando negativas para ${empresaId}:`, err);
        }
    }
});
/**
 * resumenSemanalResenas
 * Se ejecuta los lunes a las 9:00 con el resumen de la semana.
 */
exports.resumenSemanalResenas = (0, scheduler_1.onSchedule)({
    schedule: "every monday 09:00",
    timeZone: "Europe/Madrid",
    region: REGION,
}, async () => {
    var _a;
    console.log("📊 Generando resumen semanal de reseñas...");
    const hacerUnaSemana = new Date();
    hacerUnaSemana.setDate(hacerUnaSemana.getDate() - 7);
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        try {
            const configSnap = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("configuracion")
                .doc("gmb_config")
                .get();
            if (!configSnap.exists || !((_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.conectado))
                continue;
            // Reseñas de la última semana
            const resenasSemana = await db
                .collection("empresas")
                .doc(empresaId)
                .collection("valoraciones")
                .where("fecha", ">=", admin.firestore.Timestamp.fromDate(hacerUnaSemana))
                .get();
            const total = resenasSemana.size;
            if (total === 0)
                continue;
            const sumaRating = resenasSemana.docs.reduce((s, d) => { var _a; return s + ((_a = d.data().calificacion) !== null && _a !== void 0 ? _a : 5); }, 0);
            const ratingMedio = total > 0 ? sumaRating / total : 0;
            const sinResponder = resenasSemana.docs.filter((d) => !d.data().respuesta || d.data().respuesta === "").length;
            await enviarNotificacionPush(empresaId, "📊 Resumen semanal de reseñas", `Esta semana: ${total} reseñas, rating medio ${ratingMedio.toFixed(1)}⭐, ${sinResponder} sin responder.`, { tipo: "resumen_semanal", total: String(total) });
            console.log(`✅ Resumen semanal enviado a ${empresaId}: ${total} reseñas`);
        }
        catch (err) {
            console.error(`❌ Error generando resumen para ${empresaId}:`, err);
        }
    }
});
//# sourceMappingURL=gmbRespuestas.js.map