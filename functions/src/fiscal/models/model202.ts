/**
 * MODELO 202 — Pagos fraccionados Impuesto de Sociedades
 *
 * ⚠ Modelo simplificado: para cálculo exacto hay que integrar resultado contable
 * real del ejercicio anterior. Este cálculo usa las transacciones fiscales como proxy.
 *
 * Aplica cuando la empresa tiene cifra de negocios > 6M€ O elige sistema de pagos
 * fraccionados. Para pymes pequeñas es opcional/raro.
 */
export function calculate202(
  transactions: any[],
  period: string,
  empresaData: any,
): any {
  const ingresos = transactions
    .filter((tx) => (tx.type === 'invoice_sent' || tx.type === 'invoice_issued') && tx.status === 'posted')
    .reduce((sum, tx) => sum + (tx.base_amount_cents || 0) / 100, 0);

  const gastos = transactions
    .filter(
      (tx) =>
        tx.type === 'invoice_received' &&
        tx.status === 'posted' &&
        !tx.tax_tags?.includes('VAT_NOT_DEDUCTIBLE'),
    )
    .reduce((sum, tx) => sum + (tx.base_amount_cents || 0) / 100, 0);

  const resultadoContable = ingresos - gastos;
  const baseImponible = Math.max(resultadoContable, 0);

  // Tipo IS: 15% empresa nueva (primeros 2 años con beneficio), 25% general
  const isNewCompany: boolean = empresaData?.is_new_company === true;
  const tipoImpositivo = isNewCompany ? 0.15 : 0.25;
  const cuotaTotal = baseImponible * tipoImpositivo;

  // El pago fraccionado del 202 es el 18% de la cuota anual estimada
  const pagoFraccionado = cuotaTotal * 0.18;

  const retencionesSoportadas = transactions
    .filter((tx) => tx.type === 'invoice_received' && (tx.withholding_amount_cents || 0) > 0)
    .reduce((sum, tx) => sum + (tx.withholding_amount_cents || 0) / 100, 0);

  const aIngresar = Math.max(pagoFraccionado - retencionesSoportadas, 0);

  return {
    period,
    model_code: '202',
    casillas: {
      ingresos_periodo: Math.round(ingresos * 100) / 100,
      gastos_periodo: Math.round(gastos * 100) / 100,
      resultado_contable: Math.round(resultadoContable * 100) / 100,
      base_imponible: Math.round(baseImponible * 100) / 100,
      tipo_impositivo_pct: tipoImpositivo * 100,
      cuota_anual_estimada: Math.round(cuotaTotal * 100) / 100,
      pago_fraccionado_18pct: Math.round(pagoFraccionado * 100) / 100,
      retenciones_soportadas: Math.round(retencionesSoportadas * 100) / 100,
      a_ingresar: Math.round(aIngresar * 100) / 100,
    },
    tx_count: transactions.length,
    warnings: [
      '⚠ Modelo 202 simplificado. Para cálculo exacto, consulta asesor fiscal con el resultado contable real.',
      isNewCompany ? 'Tipo reducido 15% (empresa nueva / 1er año con beneficio)' : 'Tipo general 25%',
    ],
  };
}

