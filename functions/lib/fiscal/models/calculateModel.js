"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateFiscalModel = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const model303_1 = require("./model303");
const model111_1 = require("./model111");
const model115_1 = require("./model115");
const model202_1 = require("./model202");
const model390_1 = require("./model390");
const model190_1 = require("./model190");
const model180_1 = require("./model180");
const model347_1 = require("./model347");
if (!admin.apps.length)
    admin.initializeApp();
// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: calculateFiscalModel
// Calcula un modelo AEAT a partir de las fiscal_transactions y lo guarda en
// empresas/{empresaId}/fiscal_models/{modelCode}_{period}
// ═══════════════════════════════════════════════════════════════════════════════
exports.calculateFiscalModel = (0, https_1.onCall)({
    region: 'europe-west1',
    memory: '512MiB',
    timeoutSeconds: 120,
}, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Autenticación requerida');
    }
    const uid = request.auth.uid;
    const { empresaId, modelCode, period } = request.data;
    if (!empresaId || !modelCode || !period) {
        throw new https_1.HttpsError('invalid-argument', 'Faltan parámetros: empresaId, modelCode, period');
    }
    // Verificar permisos
    const userDoc = await admin.firestore().doc(`usuarios/${uid}`).get();
    const userData = userDoc.data();
    if (!userData || userData.empresa_id !== empresaId) {
        throw new https_1.HttpsError('permission-denied', 'Sin permisos para esta empresa');
    }
    if (userData.rol !== 'admin' && userData.rol !== 'propietario') {
        throw new https_1.HttpsError('permission-denied', 'Solo admin o propietario puede calcular modelos');
    }
    // Verificar Pack Fiscal activo
    const empresaDoc = await admin.firestore().doc(`empresas/${empresaId}`).get();
    const empresaData = empresaDoc.data();
    const activePacks = (empresaData === null || empresaData === void 0 ? void 0 : empresaData.active_packs) || [];
    if (!activePacks.includes('fiscal_ai')) {
        throw new https_1.HttpsError('failed-precondition', 'Pack Fiscal IA no activo en esta empresa');
    }
    // Cargar transacciones del período
    const transactions = await loadTransactions(empresaId, period, modelCode);
    // Calcular según modelo
    let result;
    switch (modelCode) {
        case '303':
            result = (0, model303_1.calculate303)(transactions, period);
            break;
        case '111':
            result = (0, model111_1.calculate111)(transactions, period);
            break;
        case '115':
            result = (0, model115_1.calculate115)(transactions, period);
            break;
        case '202':
            result = (0, model202_1.calculate202)(transactions, period, empresaData);
            break;
        case '390':
            result = (0, model390_1.calculate390)(transactions, period);
            break;
        case '190':
            result = (0, model190_1.calculate190)(transactions, period);
            break;
        case '180':
            result = (0, model180_1.calculate180)(transactions, period);
            break;
        case '347':
            result = (0, model347_1.calculate347)(transactions, period);
            break;
        default:
            throw new https_1.HttpsError('invalid-argument', `Modelo ${modelCode} no soportado`);
    }
    // Guardar resultado para histórico y UI
    const modelId = `${modelCode}_${period}`;
    await admin.firestore()
        .doc(`empresas/${empresaId}/fiscal_models/${modelId}`)
        .set({
        model_code: modelCode,
        period,
        status: 'draft',
        calculated_data: result,
        source_tx_count: transactions.length,
        source_tx_ids: transactions.map((t) => t.id),
        last_calculated_at: admin.firestore.FieldValue.serverTimestamp(),
        last_calculated_by: uid,
    }, { merge: true });
    return Object.assign({ model_id: modelId }, result);
});
// ─── Helper: cargar transacciones según período ───────────────────────────────
async function loadTransactions(empresaId, period, _modelCode) {
    const isAnnual = !period.includes('-Q');
    const db = admin.firestore();
    let query = db
        .collection(`empresas/${empresaId}/fiscal_transactions`)
        .where('status', '==', 'posted');
    if (isAnnual) {
        const year = period; // e.g. "2026"
        query = query
            .where('period', '>=', `${year}-Q1`)
            .where('period', '<=', `${year}-Q4`);
    }
    else {
        query = query.where('period', '==', period);
    }
    const snap = await query.get();
    return snap.docs.map((d) => (Object.assign({ id: d.id }, d.data())));
}
//# sourceMappingURL=calculateModel.js.map