"use strict";
/**
 * GMB Snapshots — historial de rating mensual y KPIs
 * Cada sync guarda un snapshot del rating calculado sobre las reseñas en Firestore
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
exports.guardarSnapshotMensual = guardarSnapshotMensual;
const admin = __importStar(require("firebase-admin"));
// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
/**
 * guardarSnapshotMensual
 * Calcula el rating medio de las reseñas almacenadas en Firestore
 * y guarda/actualiza el snapshot del mes actual.
 * Se llama desde gmbRespuestas.sincronizarResenasEmpresa después de cada sync.
 */
async function guardarSnapshotMensual(empresaId) {
    try {
        const ahora = new Date();
        const mesKey = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;
        // Calcular rating medio sobre todas las reseñas en Firestore
        const resenasSanp = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("valoraciones")
            .get();
        const totalEnFirestore = resenasSanp.size;
        if (totalEnFirestore === 0)
            return;
        const sumaRatings = resenasSanp.docs.reduce((s, d) => { var _a; return s + ((_a = d.data().calificacion) !== null && _a !== void 0 ? _a : 5); }, 0);
        const ratingMedio = totalEnFirestore > 0 ? sumaRatings / totalEnFirestore : 0;
        // Contar reseñas nuevas este mes
        const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1);
        const nuevasMes = resenasSanp.docs.filter((d) => {
            const fecha = d.data().fecha;
            if (!fecha)
                return false;
            const fechaDate = fecha instanceof admin.firestore.Timestamp
                ? fecha.toDate()
                : new Date(fecha);
            return fechaDate >= inicioMes;
        }).length;
        // Solo un snapshot por mes (sobrescribe el anterior del mismo mes)
        await db
            .collection("empresas")
            .doc(empresaId)
            .collection("rating_historial")
            .doc(mesKey)
            .set({
            mes: mesKey,
            ratingMedio: Math.round(ratingMedio * 100) / 100,
            totalResenasEnFirestore: totalEnFirestore,
            resenasNuevasMes: nuevasMes,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`📸 Snapshot mensual guardado: ${empresaId} — ${mesKey} — rating ${ratingMedio.toFixed(2)}`);
    }
    catch (err) {
        console.error(`❌ Error guardando snapshot mensual para ${empresaId}:`, err);
    }
}
//# sourceMappingURL=gmbSnapshots.js.map