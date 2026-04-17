/**
 * MODELO 190 — Resumen anual retenciones IRPF (por perceptor)
 * Claves: A = rendimientos del trabajo, G = actividades económicas
 */
export function calculate190(transactions: any[], period: string): any {
  const perceptores: Record<string, {
    tax_id: string;
    nombre: string;
    clave: 'A' | 'G';
    base_anual: number;
    retenciones_anual: number;
    num_registros: number;
  }> = {};

  for (const tx of transactions) {
    if ((tx.withholding_amount_cents || 0) === 0) continue;
    if (tx.type !== 'invoice_received' && tx.type !== 'payroll') continue;

    const taxId = tx.counterparty?.tax_id;
    if (!taxId) continue;

    const clave: 'A' | 'G' = tx.type === 'payroll' ? 'A' : 'G';
    const key = `${taxId}_${clave}`;

    if (!perceptores[key]) {
      perceptores[key] = {
        tax_id: taxId,
        nombre: tx.counterparty?.name || '',
        clave,
        base_anual: 0,
        retenciones_anual: 0,
        num_registros: 0,
      };
    }

    perceptores[key].base_anual += (tx.base_amount_cents || 0) / 100;
    perceptores[key].retenciones_anual += (tx.withholding_amount_cents || 0) / 100;
    perceptores[key].num_registros += 1;
  }

  const totales = { num_perceptores: 0, base_total: 0, retenciones_total: 0 };
  for (const p of Object.values(perceptores)) {
    p.base_anual = Math.round(p.base_anual * 100) / 100;
    p.retenciones_anual = Math.round(p.retenciones_anual * 100) / 100;
    totales.base_total += p.base_anual;
    totales.retenciones_total += p.retenciones_anual;
  }
  totales.num_perceptores = Object.keys(perceptores).length;
  totales.base_total = Math.round(totales.base_total * 100) / 100;
  totales.retenciones_total = Math.round(totales.retenciones_total * 100) / 100;

  return {
    period,
    model_code: '190',
    totales,
    perceptores: Object.values(perceptores),
    tx_count: transactions.length,
  };
}

