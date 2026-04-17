/**
 * MODELO 180 — Resumen anual retenciones arrendamientos (por arrendador)
 * Par anual del modelo 115 trimestral.
 */
export function calculate180(transactions: any[], period: string): any {
  const arrendadores: Record<string, {
    tax_id: string;
    nombre: string;
    direccion_inmueble?: string;
    base_anual: number;
    retenciones_anual: number;
    num_registros: number;
  }> = {};

  for (const tx of transactions) {
    if (tx.type !== 'invoice_received') continue;
    if (!tx.tax_tags?.includes('ALQUILER_LOCAL')) continue;
    if ((tx.withholding_amount_cents || 0) === 0) continue;

    const taxId = tx.counterparty?.tax_id;
    if (!taxId) continue;

    if (!arrendadores[taxId]) {
      arrendadores[taxId] = {
        tax_id: taxId,
        nombre: tx.counterparty?.name || '',
        direccion_inmueble: tx.counterparty?.address,
        base_anual: 0,
        retenciones_anual: 0,
        num_registros: 0,
      };
    }

    arrendadores[taxId].base_anual += (tx.base_amount_cents || 0) / 100;
    arrendadores[taxId].retenciones_anual += (tx.withholding_amount_cents || 0) / 100;
    arrendadores[taxId].num_registros += 1;
  }

  let baseTotal = 0;
  let retencionTotal = 0;
  for (const a of Object.values(arrendadores)) {
    a.base_anual = Math.round(a.base_anual * 100) / 100;
    a.retenciones_anual = Math.round(a.retenciones_anual * 100) / 100;
    baseTotal += a.base_anual;
    retencionTotal += a.retenciones_anual;
  }

  return {
    period,
    model_code: '180',
    casillas: {
      '01': Object.keys(arrendadores).length,
      '02': Math.round(baseTotal * 100) / 100,
      '03': Math.round(retencionTotal * 100) / 100,
    },
    arrendadores: Object.values(arrendadores),
    tx_count: transactions.length,
  };
}

