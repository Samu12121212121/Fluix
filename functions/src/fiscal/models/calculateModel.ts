import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { calculate303 } from './model303';
import { calculate111 } from './model111';
import { calculate115 } from './model115';
import { calculate202 } from './model202';
import { calculate390 } from './model390';
import { calculate190 } from './model190';
import { calculate180 } from './model180';
import { calculate347 } from './model347';

if (!admin.apps.length) admin.initializeApp();

type ModelCode = '303' | '111' | '115' | '202' | '390' | '190' | '180' | '347';

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: calculateFiscalModel
// Calcula un modelo AEAT a partir de las fiscal_transactions y lo guarda en
// empresas/{empresaId}/fiscal_models/{modelCode}_{period}
// ═══════════════════════════════════════════════════════════════════════════════

export const calculateFiscalModel = onCall(
  {
    region: 'europe-west1',
    memory: '512MiB',
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Autenticación requerida');
    }

    const uid = request.auth.uid;
    const { empresaId, modelCode, period } = request.data as {
      empresaId: string;
      modelCode: ModelCode;
      period: string; // "2026-Q1" | "2026" (anuales)
    };

    if (!empresaId || !modelCode || !period) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros: empresaId, modelCode, period');
    }

    // Verificar permisos
    const userDoc = await admin.firestore().doc(`usuarios/${uid}`).get();
    const userData = userDoc.data();
    if (!userData || userData.empresa_id !== empresaId) {
      throw new HttpsError('permission-denied', 'Sin permisos para esta empresa');
    }
    if (userData.rol !== 'admin' && userData.rol !== 'propietario') {
      throw new HttpsError('permission-denied', 'Solo admin o propietario puede calcular modelos');
    }

    // Verificar Pack Fiscal activo
    const empresaDoc = await admin.firestore().doc(`empresas/${empresaId}`).get();
    const empresaData = empresaDoc.data();
    const activePacks: string[] = empresaData?.active_packs || [];
    if (!activePacks.includes('fiscal_ai')) {
      throw new HttpsError('failed-precondition', 'Pack Fiscal IA no activo en esta empresa');
    }

    // Cargar transacciones del período
    const transactions = await loadTransactions(empresaId, period, modelCode);

    // Calcular según modelo
    let result: any;
    switch (modelCode) {
      case '303': result = calculate303(transactions, period); break;
      case '111': result = calculate111(transactions, period); break;
      case '115': result = calculate115(transactions, period); break;
      case '202': result = calculate202(transactions, period, empresaData); break;
      case '390': result = calculate390(transactions, period); break;
      case '190': result = calculate190(transactions, period); break;
      case '180': result = calculate180(transactions, period); break;
      case '347': result = calculate347(transactions, period); break;
      default:
        throw new HttpsError('invalid-argument', `Modelo ${modelCode} no soportado`);
    }

    // Guardar resultado para histórico y UI
    const modelId = `${modelCode}_${period}`;
    await admin.firestore()
      .doc(`empresas/${empresaId}/fiscal_models/${modelId}`)
      .set(
        {
          model_code: modelCode,
          period,
          status: 'draft',
          calculated_data: result,
          source_tx_count: transactions.length,
          source_tx_ids: transactions.map((t: any) => t.id),
          last_calculated_at: admin.firestore.FieldValue.serverTimestamp(),
          last_calculated_by: uid,
        },
        { merge: true },
      );

    return { model_id: modelId, ...result };
  },
);

// ─── Helper: cargar transacciones según período ───────────────────────────────

async function loadTransactions(
  empresaId: string,
  period: string,
  _modelCode: ModelCode,
): Promise<any[]> {
  const isAnnual = !period.includes('-Q');
  const db = admin.firestore();
  let query = db
    .collection(`empresas/${empresaId}/fiscal_transactions`)
    .where('status', '==', 'posted') as FirebaseFirestore.Query;

  if (isAnnual) {
    const year = period; // e.g. "2026"
    query = query
      .where('period', '>=', `${year}-Q1`)
      .where('period', '<=', `${year}-Q4`);
  } else {
    query = query.where('period', '==', period);
  }

  const snap = await query.get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

