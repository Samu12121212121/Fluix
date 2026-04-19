"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculate180 = calculate180;
/**
 * MODELO 180 — Resumen anual retenciones arrendamientos (por arrendador)
 * Par anual del modelo 115 trimestral.
 */
function calculate180(transactions, period) {
    var _a, _b, _c, _d;
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
        if (!arrendadores[taxId]) {
            arrendadores[taxId] = {
                tax_id: taxId,
                nombre: ((_c = tx.counterparty) === null || _c === void 0 ? void 0 : _c.name) || '',
                direccion_inmueble: (_d = tx.counterparty) === null || _d === void 0 ? void 0 : _d.address,
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
//# sourceMappingURL=model180.js.map