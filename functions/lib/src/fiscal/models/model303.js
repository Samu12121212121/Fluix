"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculate303 = calculate303;
/**
 * MODELO 303 — IVA trimestral
 *
 * Casillas principales:
 *   IVA DEVENGADO (ventas):
 *     01-02: Base y cuota al 4%
 *     04-05: Base y cuota al 10%
 *     07-08: Base y cuota al 21%
 *     10-11: Adquisiciones intracomunitarias
 *     12-13: ISP nacional
 *
 *   IVA DEDUCIBLE (compras):
 *     28-29: IVA soportado interior bienes corrientes
 *     30-31: IVA soportado interior bienes inversión
 *     32-33: IVA soportado importaciones
 *     34-35: IVA intracomunitarias deducible
 *
 *   RESULTADO:
 *     27 = total IVA devengado
 *     45 = total IVA deducible
 *     46 = resultado (27 - 45)
 */
function calculate303(transactions, period) {
    const r = {
        period,
        model_code: '303',
        casillas: {
            '01': 0, '02': 0,
            '04': 0, '05': 0,
            '07': 0, '08': 0,
            '10': 0, '11': 0,
            '12': 0, '13': 0,
            '27': 0,
            '28': 0, '29': 0,
            '30': 0, '31': 0,
            '32': 0, '33': 0,
            '34': 0, '35': 0,
            '45': 0,
            '46': 0,
        },
        tx_count: transactions.length,
        tx_processed: [],
        tx_skipped: [],
        warnings: [],
    };
    for (const tx of transactions) {
        try {
            processTx303(tx, r);
            r.tx_processed.push(tx.id);
        }
        catch (e) {
            r.tx_skipped.push({ id: tx.id, reason: e.message });
        }
    }
    const c = r.casillas;
    c['27'] = c['02'] + c['05'] + c['08'] + c['11'] + c['13'];
    c['45'] = c['29'] + c['31'] + c['33'] + c['35'];
    c['46'] = c['27'] - c['45'];
    for (const key of Object.keys(c)) {
        c[key] = Math.round(c[key] * 100) / 100;
    }
    return r;
}
function processTx303(tx, r) {
    const base = (tx.base_amount_cents || 0) / 100;
    const vat = (tx.vat_amount_cents || 0) / 100;
    const rate = tx.vat_rate || 0;
    const scheme = tx.vat_scheme;
    const tags = tx.tax_tags || [];
    if (scheme === 'margin_scheme')
        throw new Error('Régimen margen: excluido de 303');
    if (tags.includes('VAT_NOT_DEDUCTIBLE') && tx.type === 'invoice_received') {
        throw new Error('IVA no deducible');
    }
    if (tx.type === 'invoice_sent' || tx.type === 'invoice_issued') {
        if (scheme === 'standard') {
            if (rate === 4) {
                r.casillas['01'] += base;
                r.casillas['02'] += vat;
            }
            else if (rate === 10) {
                r.casillas['04'] += base;
                r.casillas['05'] += vat;
            }
            else if (rate === 21) {
                r.casillas['07'] += base;
                r.casillas['08'] += vat;
            }
        }
    }
    if (tx.type === 'invoice_received') {
        if (scheme === 'standard') {
            const isFixedAsset = tags.includes('FIXED_ASSET_CANDIDATE');
            if (isFixedAsset) {
                r.casillas['30'] += base;
                r.casillas['31'] += vat;
            }
            else {
                r.casillas['28'] += base;
                r.casillas['29'] += vat;
            }
        }
        else if (scheme === 'reverse_charge_eu') {
            const calcVat = base * 0.21;
            r.casillas['10'] += base;
            r.casillas['11'] += calcVat;
            r.casillas['34'] += base;
            r.casillas['35'] += calcVat;
        }
        else if (scheme === 'reverse_charge_domestic') {
            const calcVat = base * (rate / 100 || 0.21);
            r.casillas['12'] += base;
            r.casillas['13'] += calcVat;
            r.casillas['28'] += base;
            r.casillas['29'] += calcVat;
        }
        else if (scheme === 'import') {
            r.casillas['32'] += base;
            r.casillas['33'] += vat;
        }
    }
}
//# sourceMappingURL=model303.js.map