import { calculate303 } from './model303';

/**
 * MODELO 390 — Resumen anual IVA
 * Agrega los 4 trimestres del 303 sobre todas las transacciones del año.
 */
export function calculate390(transactions: any[], period: string): any {
  // period = "2026" (año)
  const base303 = calculate303(transactions, period);

  // Desglose por trimestre para auditoría
  const porTrimestre: Record<string, any> = {};
  for (const q of ['Q1', 'Q2', 'Q3', 'Q4']) {
    const qTxs = transactions.filter((tx) => tx.period === `${period}-${q}`);
    porTrimestre[q] = calculate303(qTxs, `${period}-${q}`);
  }

  return {
    period,
    model_code: '390',
    casillas: base303.casillas,
    desglose_trimestral: {
      Q1: porTrimestre['Q1'].casillas,
      Q2: porTrimestre['Q2'].casillas,
      Q3: porTrimestre['Q3'].casillas,
      Q4: porTrimestre['Q4'].casillas,
    },
    tx_count: transactions.length,
    tx_skipped: base303.tx_skipped,
    warnings: base303.warnings,
  };
}

