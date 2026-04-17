"use strict";
/**
 * CLOUD FUNCTIONS — Catálogo
 *
 * generarThumbnailCatalogo  — Storage trigger al subir imagen.jpg
 * scheduledAlertaPreciosAntiguos — Scheduler anual en enero
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
exports.scheduledAlertaPreciosAntiguos = exports.generarThumbnailCatalogo = void 0;
const admin = __importStar(require("firebase-admin"));
const storage_1 = require("firebase-functions/v2/storage");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const REGION = "europe-west1";
// ─────────────────────────────────────────────────────────────────────────────
// generarThumbnailCatalogo
// Trigger: cuando se sube empresas/{empresaId}/catalogo/{productoId}/imagen.jpg
// Genera thumb_imagen.jpg 400×400 y actualiza thumbnail_url en Firestore
// ─────────────────────────────────────────────────────────────────────────────
exports.generarThumbnailCatalogo = (0, storage_1.onObjectFinalized)({ region: REGION, memory: "512MiB" }, async (event) => {
    const filePath = event.data.name;
    if (!filePath)
        return;
    // Solo procesar imagen.jpg en catalogo (no procesar el propio thumbnail)
    const match = filePath.match(/^empresas\/([^/]+)\/catalogo\/([^/]+)\/imagen\.jpg$/);
    if (!match)
        return;
    const empresaId = match[1];
    const productoId = match[2];
    const thumbPath = `empresas/${empresaId}/catalogo/${productoId}/thumb_imagen.jpg`;
    const bucket = admin.storage().bucket(event.data.bucket);
    try {
        // Cargar sharp dinámicamente (no disponible en cold start siempre)
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const sharp = require("sharp");
        // Descargar imagen original
        const [imageBuffer] = await bucket.file(filePath).download();
        // Generar thumbnail 400×400 con recorte centrado (cover)
        const thumbBuffer = await sharp(imageBuffer)
            .resize(400, 400, {
            fit: "cover",
            position: "center",
        })
            .jpeg({ quality: 80 })
            .toBuffer();
        // Subir thumbnail
        const thumbFile = bucket.file(thumbPath);
        await thumbFile.save(thumbBuffer, {
            metadata: {
                contentType: "image/jpeg",
                metadata: {
                    empresaId,
                    productoId,
                    generadoEn: new Date().toISOString(),
                },
            },
        });
        // Obtener URL pública del thumbnail
        await thumbFile.makePublic();
        const thumbUrl = `https://storage.googleapis.com/${event.data.bucket}/${thumbPath}`;
        // Actualizar Firestore con thumbnail_url
        await admin
            .firestore()
            .collection("empresas")
            .doc(empresaId)
            .collection("catalogo")
            .doc(productoId)
            .update({
            thumbnail_url: thumbUrl,
        });
        console.log(`✅ Thumbnail generado para ${productoId} en empresa ${empresaId}`);
    }
    catch (err) {
        console.error(`❌ Error generando thumbnail: ${err}`);
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// scheduledAlertaPreciosAntiguos
// Corre el 15 de enero a las 9:00 (hora Madrid)
// Detecta productos con precio sin actualizar > 12 meses y notifica
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledAlertaPreciosAntiguos = (0, scheduler_1.onSchedule)({
    schedule: "0 9 15 1 *", // 15 enero 09:00
    timeZone: "Europe/Madrid",
    region: REGION,
}, async () => {
    var _a;
    const db = admin.firestore();
    const messaging = admin.messaging();
    const haceUnAnio = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 365 * 24 * 60 * 60 * 1000));
    const empresasSnap = await db.collection("empresas").get();
    for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;
        // Buscar productos activos con precio no actualizado en > 12 meses
        const productosSnap = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("catalogo")
            .where("activo", "==", true)
            .get();
        const productosAntiguos = [];
        for (const doc of productosSnap.docs) {
            const d = doc.data();
            const fechaUltimoCambio = (_a = d.fecha_ultimo_cambio_precio) !== null && _a !== void 0 ? _a : d.fecha_creacion;
            if (!fechaUltimoCambio)
                continue;
            const ts = fechaUltimoCambio;
            if (ts.toMillis() < haceUnAnio.toMillis()) {
                productosAntiguos.push(d.nombre);
            }
        }
        if (productosAntiguos.length === 0)
            continue;
        // Obtener tokens de dispositivos de la empresa
        const dispositivosSnap = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("dispositivos")
            .where("activo", "==", true)
            .get();
        const tokens = [];
        dispositivosSnap.forEach((d) => {
            const token = d.data().token;
            if (token)
                tokens.push(token);
        });
        if (tokens.length === 0)
            continue;
        const n = productosAntiguos.length;
        const titulo = "⚠️ Precios sin revisar";
        const cuerpo = n === 1
            ? `"${productosAntiguos[0]}" lleva más de un año sin actualizar el precio`
            : `${n} productos llevan más de un año sin actualizar el precio. ¿Los revisas?`;
        // Enviar notificación push
        try {
            await messaging.sendEachForMulticast({
                tokens,
                notification: { title: titulo, body: cuerpo },
                data: {
                    tipo: "alerta_precios_antiguos",
                    cantidad: n.toString(),
                    empresaId,
                },
                android: { priority: "normal" },
                apns: {
                    payload: {
                        aps: { badge: 1, sound: "default" },
                    },
                },
            });
            // Guardar alerta en Firestore para mostrarla en la app
            await db
                .collection("empresas")
                .doc(empresaId)
                .collection("alertas")
                .add({
                tipo: "precios_antiguos",
                titulo,
                cuerpo,
                productosAfectados: productosAntiguos.slice(0, 20), // max 20
                totalAfectados: n,
                leida: false,
                fecha: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`✅ Alerta enviada a empresa ${empresaId}: ${n} productos sin actualizar`);
        }
        catch (err) {
            console.error(`❌ Error enviando alerta a ${empresaId}: ${err}`);
        }
    }
});
//# sourceMappingURL=catalogoFunciones.js.map