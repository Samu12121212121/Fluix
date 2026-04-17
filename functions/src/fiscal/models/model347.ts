/**
 * MODELO 347 — Operaciones con terceros > 3.005,06 €/año
 *
 * Obligación: declarar clientes/proveedores con los que la suma anual
 * (total facturas, con IVA) supere 3.005,06 €.
 *
 * EXCLUSIONES:
 *   - Operaciones intracomunitarias (van a 349)
 *   - Alquileres con retención (van a 180)
 *   - Nóminas
 *   - Operaciones marcadas EXCLUDED_FROM_347
 */
const UMBRAL_347 = 3005.06;

export function calculate347(transactions: any[], period: string): any {
  const operadores: Record<string, {
    tax_id: string;
    nombre: string;
    tipo: 'cliente' | 'proveedor';
    total_anual: number;
    num_facturas: number;
    trimestres: { Q1: number; Q2: number; Q3: number; Q4: number };
  }> = {};

  for (const tx of transactions) {
    if (tx.tax_tags?.includes('EXCLUDED_FROM_347')) continue;
    if (tx.tax_tags?.includes('CROSS_BORDER_EU')) continue;
    if (tx.tax_tags?.includes('ALQUILER_LOCAL') && (tx.withholding_amount_cents || 0) > 0) continue;
    if (tx.type === 'payroll') continue;

    const taxId = tx.counterparty?.tax_id;
    if (!taxId) continue;

    const total = (tx.total_amount_cents || 0) / 100;
    const tipo: 'cliente' | 'proveedor' =
      tx.type === 'invoice_sent' || tx.type === 'invoice_issued' ? 'cliente' : 'proveedor';
    const q = (tx.period?.split('-')[1] || '') as 'Q1' | 'Q2' | 'Q3' | 'Q4';

    const key = `${taxId}_${tipo}`;
    if (!operadores[key]) {
      operadores[key] = {
        tax_id: taxId,
        nombre: tx.counterparty?.name || '',
        tipo,
        total_anual: 0,
        num_facturas: 0,
        trimestres: { Q1: 0, Q2: 0, Q3: 0, Q4: 0 },
      };
    }

    operadores[key].total_anual += total;
    operadores[key].num_facturas += 1;
    if (q && operadores[key].trimestres[q] !== undefined) {
      operadores[key].trimestres[q] += total;
    }
  }

  const declarables = Object.values(operadores)
    .filter((o) => o.total_anual >= UMBRAL_347)
    .map((o) => ({
      ...o,
      total_anual: Math.round(o.total_anual * 100) / 100,
      trimestres: {
        Q1: Math.round(o.trimestres.Q1 * 100) / 100,
        Q2: Math.round(o.trimestres.Q2 * 100) / 100,
        Q3: Math.round(o.trimestres.Q3 * 100) / 100,
        Q4: Math.round(o.trimestres.Q4 * 100) / 100,
      },
    }));

  return {
    period,
    model_code: '347',
    umbral: UMBRAL_347,
    num_operadores_declarables: declarables.length,
    total_declarado: Math.round(
      declarables.reduce((s, o) => s + o.total_anual, 0) * 100
    ) / 100,
    operadores: declarables,
    operadores_bajo_umbral: Object.keys(operadores).length - declarables.length,
    tx_count: transactions.length,
  };
}

