"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculate115 = calculate115;
/**
 * MODELO 115 — Retenciones arrendamientos inmuebles urbanos (trimestral)
 * Retención fija 19% sobre base (art. 101.6 LIRPF)
 */
function calculate115(transactions, period) {
    var _a, _b, _c;
    const arrendadores = {};
    for (const tx of transactions) {
        if (tx.type !== 'invoice_received')
            continue;
        if (!((_a = tx.tax_tags) === null || _a === void 0 ? void 0 : _a.includes('ALQUILER_LOCAL')))
            continue;
        if ((tx.withholding_amount_cents || 0) === 0)
            continue;
        const taxId = (_b = tx.counterparty) === null || _b === void 0 ? void 0 : _b.tax_id;
        if (!taxId)
            continue;
        const base = (tx.base_amount_cents || 0) / 100;
        const withheld = (tx.withholding_amount_cents || 0) / 100;
        if (!arrendadores[taxId]) {
            arrendadores[taxId] = {
                tax_id: taxId,
                nombre: ((_c = tx.counterparty) === null || _c === void 0 ? void 0 : _c.name) || '',
                base: 0,
                retencion: 0,
                num_facturas: 0,
            };
        }
        arrendadores[taxId].base += base;
        arrendadores[taxId].retencion += withheld;
        arrendadores[taxId].num_facturas += 1;
    }
    const baseTotal = Object.values(arrendadores).reduce((s, a) => s + a.base, 0);
    const retencionTotal = Object.values(arrendadores).reduce((s, a) => s + a.retencion, 0);
    return {
        period,
        model_code: '115',
        casillas: {
            '01': Object.keys(arrendadores).length,
            '02': Math.round(baseTotal * 100) / 100,
            '03': Math.round(retencionTotal * 100) / 100,
        },
        arrendadores: Object.values(arrendadores).map((a) => (Object.assign(Object.assign({}, a), { base: Math.round(a.base * 100) / 100, retencion: Math.round(a.retencion * 100) / 100 }))),
        tx_count: transactions.length,
    };
}
//# sourceMappingURL=model115.js.map