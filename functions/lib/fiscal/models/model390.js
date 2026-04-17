"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculate390 = calculate390;
const model303_1 = require("./model303");
/**
 * MODELO 390 — Resumen anual IVA
 * Agrega los 4 trimestres del 303 sobre todas las transacciones del año.
 */
function calculate390(transactions, period) {
    // period = "2026" (año)
    const base303 = (0, model303_1.calculate303)(transactions, period);
    // Desglose por trimestre para auditoría
    const porTrimestre = {};
    for (const q of ['Q1', 'Q2', 'Q3', 'Q4']) {
        const qTxs = transactions.filter((tx) => tx.period === `${period}-${q}`);
        porTrimestre[q] = (0, model303_1.calculate303)(qTxs, `${period}-${q}`);
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
//# sourceMappingURL=model390.js.map