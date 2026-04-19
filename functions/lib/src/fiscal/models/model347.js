"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculate347 = calculate347;
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
function calculate347(transactions, period) {
    var _a, _b, _c, _d, _e, _f;
    const operadores = {};
    for (const tx of transactions) {
        if ((_a = tx.tax_tags) === null || _a === void 0 ? void 0 : _a.includes('EXCLUDED_FROM_347'))
            continue;
        if ((_b = tx.tax_tags) === null || _b === void 0 ? void 0 : _b.includes('CROSS_BORDER_EU'))
            continue;
        if (((_c = tx.tax_tags) === null || _c === void 0 ? void 0 : _c.includes('ALQUILER_LOCAL')) && (tx.withholding_amount_cents || 0) > 0)
            continue;
        if (tx.type === 'payroll')
            continue;
        const taxId = (_d = tx.counterparty) === null || _d === void 0 ? void 0 : _d.tax_id;
        if (!taxId)
            continue;
        const total = (tx.total_amount_cents || 0) / 100;
        const tipo = tx.type === 'invoice_sent' || tx.type === 'invoice_issued' ? 'cliente' : 'proveedor';
        const q = (((_e = tx.period) === null || _e === void 0 ? void 0 : _e.split('-')[1]) || '');
        const key = `${taxId}_${tipo}`;
        if (!operadores[key]) {
            operadores[key] = {
                tax_id: taxId,
                nombre: ((_f = tx.counterparty) === null || _f === void 0 ? void 0 : _f.name) || '',
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
        .map((o) => (Object.assign(Object.assign({}, o), { total_anual: Math.round(o.total_anual * 100) / 100, trimestres: {
            Q1: Math.round(o.trimestres.Q1 * 100) / 100,
            Q2: Math.round(o.trimestres.Q2 * 100) / 100,
            Q3: Math.round(o.trimestres.Q3 * 100) / 100,
            Q4: Math.round(o.trimestres.Q4 * 100) / 100,
        } })));
    return {
        period,
        model_code: '347',
        umbral: UMBRAL_347,
        num_operadores_declarables: declarables.length,
        total_declarado: Math.round(declarables.reduce((s, o) => s + o.total_anual, 0) * 100) / 100,
        operadores: declarables,
        operadores_bajo_umbral: Object.keys(operadores).length - declarables.length,
        tx_count: transactions.length,
    };
}
//# sourceMappingURL=model347.js.map