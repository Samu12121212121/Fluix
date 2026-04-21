"use strict";
/**
 * Generador de PDF oficial relleno con pdf-lib
 *
 * REQUISITO: tener el PDF oficial de la AEAT almacenado en Firebase Storage
 * en la ruta: templates/fiscal/modelo{code}_{year}.pdf
 *
 * Los PDFs oficiales son formularios editables publicados por la AEAT.
 * Se descargan de: https://sede.agenciatributaria.gob.es/Sede/modelos-formularios
 *
 * ⚠ Los nombres de campo del formulario se obtienen con pdf-lib o Adobe Acrobat
 * inspeccionando el PDF. Cada modelo tiene sus propios nombres de campo.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.generarModeloPdf = generarModeloPdf;
const pdf_lib_1 = require("pdf-lib");
const admin = __importStar(require("firebase-admin"));
/**
 * Genera el PDF relleno del modelo AEAT indicado.
 * @param modelCode  - '303', '111', etc.
 * @param modelData  - resultado del calculate{Model}()
 * @param empresa    - datos fiscales empresa
 * @param year       - año fiscal (para cargar el template correcto)
 * @returns Buffer con el PDF relleno
 */
async function generarModeloPdf(modelCode, modelData, empresa, year = new Date().getFullYear()) {
    var _a, _b;
    // 1. Cargar template PDF desde Storage
    const bucket = admin.storage().bucket();
    const templatePath = `templates/fiscal/modelo${modelCode}_${year}.pdf`;
    let pdfBytes;
    try {
        const [file] = await bucket.file(templatePath).download();
        pdfBytes = file;
    }
    catch (_c) {
        throw new Error(`Template PDF no encontrado en Storage: ${templatePath}. ` +
            `Sube el PDF oficial de la AEAT para el año ${year}.`);
    }
    // 2. Cargar y rellenar
    const pdfDoc = await pdf_lib_1.PDFDocument.load(pdfBytes);
    const form = pdfDoc.getForm();
    // 3. Rellenar campos comunes
    safeSetField(form, 'NIF', empresa.tax_id.replace(/[-\s]/g, ''));
    safeSetField(form, 'Apellidos_Nombre', empresa.legal_name.toUpperCase());
    safeSetField(form, 'Ejercicio', ((_a = modelData.period) === null || _a === void 0 ? void 0 : _a.split('-')[0]) || String(year));
    // Período (si es trimestral)
    if ((_b = modelData.period) === null || _b === void 0 ? void 0 : _b.includes('-Q')) {
        const q = modelData.period.split('-Q')[1];
        safeSetField(form, 'Periodo', `${q}T`);
    }
    // 4. Rellenar casillas del modelo
    const casillas = modelData.casillas || {};
    for (const [num, valor] of Object.entries(casillas)) {
        // Intentar varios formatos de nombre de campo
        const intentos = [
            `Casilla_${num}`,
            `C${num}`,
            `casilla${num}`,
            num,
        ];
        let rellenado = false;
        for (const nombre of intentos) {
            if (safeSetField(form, nombre, formatoImporteEs(valor))) {
                rellenado = true;
                break;
            }
        }
        if (!rellenado) {
            console.warn(`Campo para casilla ${num} no encontrado en el PDF`);
        }
    }
    // 5. Aplanar (no editable) y retornar
    form.flatten();
    return pdfDoc.save();
}
// ─── Helpers ─────────────────────────────────────────────────────────────────
function safeSetField(form, fieldName, value) {
    try {
        form.getTextField(fieldName).setText(value);
        return true;
    }
    catch (_a) {
        return false;
    }
}
function formatoImporteEs(valor) {
    // Formato español: 1.234,56
    return valor.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}
//# sourceMappingURL=generateModelPdf.js.map