/**
 * MODELO 111 — Retenciones IRPF trimestrales
 * Grupos: Trabajo (empleados) clave A, Actividades económicas clave G
 */
export function calculate111(transactions: any[], period: string): any {
  const r: any = {
    period,
    model_code: '111',
    casillas: {
      '01': 0,  // num perceptores trabajo
      '02': 0,  // base trabajo
      '03': 0,  // retenciones trabajo
      '04': 0,  // num perceptores actividades
      '05': 0,  // base actividades
      '06': 0,  // retenciones actividades
      '28': 0,  // TOTAL BASE
      '29': 0,  // TOTAL RETENCIONES
    },
    perceptores_trabajo: new Set<string>(),
    perceptores_actividades: new Set<string>(),
    tx_count: transactions.length,
  };

  for (const tx of transactions) {
    if ((tx.withholding_amount_cents || 0) === 0) continue;

    const base = (tx.base_amount_cents || 0) / 100;
    const withheld = (tx.withholding_amount_cents || 0) / 100;
    const taxId = tx.counterparty?.tax_id;
    if (!taxId) continue;

    if (tx.type === 'payroll') {
      r.casillas['02'] += base;
      r.casillas['03'] += withheld;
      r.perceptores_trabajo.add(taxId);
    } else if (
      tx.type === 'invoice_received' &&
      tx.tax_tags?.includes('SERVICIOS_PROFESIONALES')
    ) {
      r.casillas['05'] += base;
      r.casillas['06'] += withheld;
      r.perceptores_actividades.add(taxId);
    }
  }

  r.casillas['01'] = r.perceptores_trabajo.size;
  r.casillas['04'] = r.perceptores_actividades.size;
  r.casillas['28'] = r.casillas['02'] + r.casillas['05'];
  r.casillas['29'] = r.casillas['03'] + r.casillas['06'];

  for (const k of Object.keys(r.casillas)) {
    if (typeof r.casillas[k] === 'number') {
      r.casillas[k] = Math.round(r.casillas[k] * 100) / 100;
    }
  }

  return {
    ...r,
    perceptores_trabajo: Array.from(r.perceptores_trabajo),
    perceptores_actividades: Array.from(r.perceptores_actividades),
  };
}

