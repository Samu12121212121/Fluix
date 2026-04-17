"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processInvoice = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const documentai_1 = require("@google-cloud/documentai");
const pdf_parse_1 = __importDefault(require("pdf-parse"));
const sharp_1 = __importDefault(require("sharp"));
if (!admin.apps.length)
    admin.initializeApp();
// ═══════════════════════════════════════════════════════════════
// PROMPT — facturas españolas para pymes
// ═══════════════════════════════════════════════════════════════
const SYSTEM_PROMPT = `Eres un extractor experto de facturas fiscales españolas.
Los usuarios son pymes españolas: hostelería, peluquería, tatuaje,
carnicería, belleza, tiendas. Procesas facturas y tickets de sus proveedores.

REGLAS ABSOLUTAS:
1. Devuelve SOLO JSON válido, sin markdown ni texto adicional.
2. Si un campo no se ve claro en el texto, usa null. NUNCA inventes.
3. Importes como string con 2 decimales: "277.99".
4. Fechas en ISO: YYYY-MM-DD.
5. Países en ISO 3166-1 alfa-2 (ES, NL, DE, FR, PT).
6. Moneda en ISO 4217 (EUR por defecto).

TIPOS DE IVA ESPAÑA:
- 21% (general)
- 10% (reducido): hostelería, alimentación preparada, transporte
- 4% (superreducido): alimentos básicos, libros, medicamentos
- 0% o exento: sanitarios, educativos, financieros, alquiler vivienda

RÉGIMEN DE IVA (vat_scheme):
- "standard": caso general (21%/10%/4%)
- "exempt": exenta (art. 20 LIVA)
- "not_subject": no sujeta (art. 7 LIVA)
- "reverse_charge_domestic": inversión del sujeto pasivo nacional
- "margin_scheme": régimen de margen (bienes usados, REBU)
- "reverse_charge_eu": proveedor UE distinto de ES, sin margen
- "export": proveedor ES, cliente fuera UE
- "import": proveedor fuera UE, cliente ES

TAX_TAGS (añade TODOS los que apliquen):
- MARGIN_SCHEME, SECOND_HAND_GOODS, VAT_NOT_DEDUCTIBLE
- CROSS_BORDER_EU, EXCLUDED_FROM_349
- RECARGO_EQUIVALENCIA (si menciona "recargo de equivalencia" o "RE")
- FIXED_ASSET_CANDIDATE (>300€ y es hardware/equipo duradero)
- HOSTELERIA_INSUMOS, PRODUCTOS_BELLEZA, MATERIAL_TATUAJE,
  SUMINISTROS_CARNICERIA, ALQUILER_LOCAL, SUMINISTROS_BASICOS,
  SERVICIOS_PROFESIONALES, PUBLICIDAD, EQUIPAMIENTO, ALIMENTACION, OTROS, TICKET

VALIDACIÓN MATEMÁTICA INTERNA:
Antes de responder, verifica: base + IVA ≈ total (tolerancia ±0.02€).
Si no cuadra Y vat_scheme no es margin_scheme, añade a extraction_warnings
"math_check_failed: {detalles}".

SI ES UN TICKET: marca en tax_tags: "TICKET".

SI HAY VARIAS LÍNEAS CON TIPOS DE IVA DISTINTOS:
- Desglosa en "lines" con su vat_rate.
- Añade warning "multiple_vat_rates".

NUNCA inventes NIFs, números, fechas o importes.

SCHEMA DE SALIDA:
{
  "invoice_number": string | null,
  "external_reference": string | null,
  "invoice_date": "YYYY-MM-DD",
  "supplier_name": string,
  "supplier_legal_name": string | null,
  "supplier_tax_id": string | null,
  "supplier_country": "XX",
  "supplier_address": string | null,
  "customer_name": string | null,
  "customer_tax_id": string | null,
  "base_amount": "0.00",
  "vat_rate": "0",
  "vat_amount": "0.00",
  "recargo_rate": "0" | null,
  "recargo_amount": "0.00" | null,
  "total_amount": "0.00",
  "currency": "EUR",
  "vat_scheme": "standard" | ...,
  "tax_tags": ["..."],
  "lines": [
    {
      "description": string,
      "sku": string | null,
      "quantity": "1",
      "unit_price": "0.00",
      "line_total": "0.00",
      "vat_rate": "21" | null
    }
  ],
  "extraction_warnings": ["..."]
}`;
// ═══════════════════════════════════════════════════════════════
// CLOUD FUNCTION
// ═══════════════════════════════════════════════════════════════
exports.processInvoice = (0, https_1.onCall)({
    region: "europe-west1",
    memory: "1GiB",
    timeoutSeconds: 180,
    secrets: ["ANTHROPIC_API_KEY", "DOCAI_PROCESSOR_ID"],
    cors: true,
}, async (request) => {
    var _a, _b;
    // 1. AUTH + PERMISOS
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Debe estar autenticado");
    }
    const uid = request.auth.uid;
    const { empresaId, documentId } = request.data;
    if (!empresaId || !documentId) {
        throw new https_1.HttpsError("invalid-argument", "Faltan empresaId o documentId");
    }
    // Verificar pertenencia
    const userDoc = await admin.firestore().doc(`usuarios/${uid}`).get();
    if (!userDoc.exists || ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.empresa_id) !== empresaId) {
        throw new https_1.HttpsError("permission-denied", "No pertenece a esta empresa");
    }
    // Verificar Pack Fiscal activo
    const empresaDoc = await admin
        .firestore()
        .doc(`empresas/${empresaId}`)
        .get();
    const activePacks = ((_b = empresaDoc.data()) === null || _b === void 0 ? void 0 : _b.active_packs) || [];
    if (!activePacks.includes("fiscal_ai")) {
        throw new https_1.HttpsError("failed-precondition", "Pack Fiscal IA no activo en esta empresa");
    }
    // 2. CARGAR ARCHIVO
    const docRef = admin
        .firestore()
        .doc(`empresas/${empresaId}/fiscal_documents/${documentId}`);
    const docSnap = await docRef.get();
    if (!docSnap.exists) {
        throw new https_1.HttpsError("not-found", "Documento no existe");
    }
    const doc = docSnap.data();
    const bucket = admin.storage().bucket();
    const [fileBuffer] = await bucket.file(doc.storage_path).download();
    // 3. EXTRAER TEXTO
    let rawText = "";
    let ocrEngine = "";
    if (doc.mime_type === "application/pdf") {
        try {
            const parsed = await (0, pdf_parse_1.default)(fileBuffer);
            if (parsed.text && parsed.text.trim().length >= 50) {
                rawText = parsed.text;
                ocrEngine = "pdf-parse";
            }
        }
        catch (e) {
            console.warn("pdf-parse falló:", e);
        }
        if (!rawText) {
            rawText = await callDocumentAI(fileBuffer, "application/pdf");
            ocrEngine = "document_ai_pdf";
        }
    }
    else if (doc.mime_type.startsWith("image/")) {
        const optimized = await (0, sharp_1.default)(fileBuffer)
            .rotate()
            .resize({
            width: 2400,
            height: 2400,
            fit: "inside",
            withoutEnlargement: true,
        })
            .jpeg({ quality: 90 })
            .toBuffer();
        rawText = await callDocumentAI(optimized, "image/jpeg");
        ocrEngine = "document_ai_image";
    }
    else {
        throw new https_1.HttpsError("invalid-argument", `Tipo de archivo no soportado: ${doc.mime_type}`);
    }
    if (!rawText || rawText.trim().length < 10) {
        await docRef.update({
            processing_status: "failed",
            processing_error: "No se pudo extraer texto del archivo",
        });
        throw new https_1.HttpsError("internal", "No se pudo extraer texto del documento. Asegúrate de que la factura es legible.");
    }
    // 4. CREAR REGISTRO DE EXTRACCIÓN
    const extractionRef = await admin
        .firestore()
        .collection(`empresas/${empresaId}/fiscal_extractions`)
        .add({
        document_id: documentId,
        ocr_engine: ocrEngine,
        ocr_version: "1.0",
        llm_model: "claude-sonnet-4-5",
        prompt_version: "invoice_es_v1",
        raw_text: rawText,
        status: "processing",
        extracted_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 5. LLAMAR A CLAUDE
    const anthropic = new sdk_1.default({
        apiKey: process.env.ANTHROPIC_API_KEY,
    });
    const today = new Date().toISOString().split("T")[0];
    let invoiceData;
    try {
        const message = await anthropic.messages.create({
            model: "claude-sonnet-4-5",
            max_tokens: 2000,
            temperature: 0,
            system: SYSTEM_PROMPT,
            messages: [
                {
                    role: "user",
                    content: `Extrae los datos de esta factura.\n\nPaís del receptor (el cliente): ES\nFecha actual: ${today}\n\nTexto OCR:\n---\n${rawText}\n---\n\nDevuelve solo el JSON.`,
                },
            ],
        });
        const responseText = message.content[0].text;
        const cleaned = responseText
            .replace(/^```json\s*/i, "")
            .replace(/\s*```$/i, "")
            .trim();
        invoiceData = JSON.parse(cleaned);
    }
    catch (e) {
        await extractionRef.update({
            status: "failed",
            error: e.message || "Error en LLM",
        });
        throw new https_1.HttpsError("internal", "La IA no pudo procesar la factura");
    }
    // 6. VALIDAR
    const validation = validateInvoice(invoiceData);
    // 7. DETECTAR DUPLICADOS
    if (invoiceData.supplier_tax_id && invoiceData.invoice_number) {
        const dupQuery = await admin
            .firestore()
            .collection(`empresas/${empresaId}/fiscal_transactions`)
            .where("counterparty.tax_id", "==", invoiceData.supplier_tax_id)
            .where("invoice_number", "==", invoiceData.invoice_number)
            .where("status", "!=", "voided")
            .limit(1)
            .get();
        if (!dupQuery.empty) {
            validation.warnings.push("Posible duplicado de una factura ya registrada");
        }
    }
    // 8. PERÍODO FISCAL
    const invoiceDate = new Date(invoiceData.invoice_date);
    const year = invoiceDate.getFullYear();
    const quarter = Math.ceil((invoiceDate.getMonth() + 1) / 3);
    const period = `${year}-Q${quarter}`;
    // 9. DECIDIR ESTADO
    const status = decideStatus(invoiceData, validation);
    // 10. GUARDAR EN fiscal_transactions (auditoría/pipeline IA)
    const txRef = await admin
        .firestore()
        .collection(`empresas/${empresaId}/fiscal_transactions`)
        .add({
        type: "invoice_received",
        status,
        document_id: documentId,
        extraction_id: extractionRef.id,
        invoice_number: invoiceData.invoice_number,
        external_reference: invoiceData.external_reference || null,
        invoice_date: admin.firestore.Timestamp.fromDate(invoiceDate),
        period,
        counterparty: {
            name: invoiceData.supplier_name,
            legal_name: invoiceData.supplier_legal_name || null,
            tax_id: invoiceData.supplier_tax_id || null,
            country: invoiceData.supplier_country,
            address: invoiceData.supplier_address || null,
        },
        base_amount_cents: toCents(invoiceData.base_amount),
        vat_amount_cents: toCents(invoiceData.vat_amount),
        total_amount_cents: toCents(invoiceData.total_amount),
        vat_rate: parseFloat(invoiceData.vat_rate || "0"),
        recargo_amount_cents: invoiceData.recargo_amount
            ? toCents(invoiceData.recargo_amount)
            : 0,
        recargo_rate: invoiceData.recargo_rate
            ? parseFloat(invoiceData.recargo_rate)
            : 0,
        currency: invoiceData.currency || "EUR",
        vat_scheme: invoiceData.vat_scheme,
        tax_tags: invoiceData.tax_tags || [],
        lines: invoiceData.lines || [],
        validation_errors: validation.errors,
        validation_warnings: validation.warnings,
        extraction_warnings: invoiceData.extraction_warnings || [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: uid,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 11. GUARDAR EN facturas_recibidas (modelo contable existente)
    const baseAmount = parseFloat(invoiceData.base_amount || "0");
    const vatRate = parseFloat(invoiceData.vat_rate || "0");
    const vatAmount = parseFloat(invoiceData.vat_amount || "0");
    const totalAmount = parseFloat(invoiceData.total_amount || "0");
    const recargoRate = invoiceData.recargo_rate
        ? parseFloat(invoiceData.recargo_rate)
        : 0;
    const esIntracomunitario = invoiceData.vat_scheme === "reverse_charge_eu" ||
        (invoiceData.supplier_country &&
            invoiceData.supplier_country !== "ES" &&
            ["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU",
                "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "SE"]
                .includes(invoiceData.supplier_country));
    const esArrendamiento = (invoiceData.tax_tags || []).includes("ALQUILER_LOCAL");
    const facturaRecibidaRef = admin
        .firestore()
        .collection(`empresas/${empresaId}/facturas_recibidas`)
        .doc();
    const ahora = admin.firestore.Timestamp.now();
    await facturaRecibidaRef.set({
        empresa_id: empresaId,
        numero_factura: invoiceData.invoice_number || `AI-${documentId.substring(0, 8)}`,
        serie: null,
        fecha_emision: admin.firestore.Timestamp.fromDate(invoiceDate),
        fecha_recepcion: ahora,
        nif_proveedor: invoiceData.supplier_tax_id || "",
        nif_iva_comunitario: esIntracomunitario ? invoiceData.supplier_tax_id : null,
        es_intracomunitario: esIntracomunitario,
        nombre_proveedor: invoiceData.supplier_name || "",
        direccion_proveedor: invoiceData.supplier_address || null,
        telefono_proveedor: null,
        base_imponible: baseAmount,
        porcentaje_iva: vatRate,
        importe_iva: vatAmount,
        iva_deducible: !(invoiceData.tax_tags || []).includes("VAT_NOT_DEDUCTIBLE"),
        descuento_global: 0,
        recargo_equivalencia: recargoRate,
        total_con_impuestos: totalAmount,
        porcentaje_retencion: null,
        importe_retencion: null,
        estado: status === "posted" ? "recibida" : "pendiente",
        fecha_pago: null,
        metodo_pago: null,
        referencia_bancaria: null,
        es_arrendamiento: esArrendamiento,
        nif_arrendador: esArrendamiento ? invoiceData.supplier_tax_id : null,
        concepto_arrendamiento: esArrendamiento ? "Alquiler local" : null,
        notas: [
            `Procesada por IA (${ocrEngine})`,
            ...(validation.warnings.length > 0
                ? [`⚠️ ${validation.warnings.join(", ")}`]
                : []),
            ...(invoiceData.vat_scheme !== "standard"
                ? [`Régimen IVA: ${invoiceData.vat_scheme}`]
                : []),
        ].join("\n"),
        fecha_creacion: ahora,
        fecha_actualizacion: ahora,
        // Campos extra IA (no rompen modelo existente)
        _ai_transaction_id: txRef.id,
        _ai_document_id: documentId,
        _ai_confidence: calculateConfidence(invoiceData, validation),
        _ai_tax_tags: invoiceData.tax_tags || [],
        _ai_vat_scheme: invoiceData.vat_scheme,
        _ai_lines: invoiceData.lines || [],
    });
    // 12. COMPLETAR EXTRACCIÓN
    await extractionRef.update({
        raw_json: invoiceData,
        status: "success",
        confidence_score: calculateConfidence(invoiceData, validation),
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
    });
    return {
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
        status,
        warnings: validation.warnings,
        errors: validation.errors,
    };
});
// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
async function callDocumentAI(buffer, mimeType) {
    var _a;
    const client = new documentai_1.DocumentProcessorServiceClient({
        apiEndpoint: "eu-documentai.googleapis.com",
    });
    const projectId = process.env.GCLOUD_PROJECT;
    const processorId = process.env.DOCAI_PROCESSOR_ID;
    const name = `projects/${projectId}/locations/eu/processors/${processorId}`;
    const [result] = await client.processDocument({
        name,
        rawDocument: {
            content: buffer.toString("base64"),
            mimeType,
        },
    });
    return ((_a = result.document) === null || _a === void 0 ? void 0 : _a.text) || "";
}
function toCents(amountStr) {
    if (!amountStr)
        return 0;
    return Math.round(parseFloat(amountStr) * 100);
}
function validateInvoice(data) {
    var _a;
    const errors = [];
    const warnings = [];
    // Matemática
    if (data.vat_scheme !== "margin_scheme" &&
        data.vat_scheme !== "reverse_charge_eu") {
        const base = parseFloat(data.base_amount || "0");
        const vat = parseFloat(data.vat_amount || "0");
        const recargo = parseFloat(data.recargo_amount || "0");
        const total = parseFloat(data.total_amount || "0");
        if (Math.abs(base + vat + recargo - total) > 0.02) {
            errors.push(`Total no cuadra: ${base} + ${vat} + ${recargo} ≠ ${total}`);
        }
    }
    // NIF español
    if (data.supplier_country === "ES" && data.supplier_tax_id) {
        if (!validateSpanishNif(data.supplier_tax_id)) {
            warnings.push(`NIF con formato no estándar: ${data.supplier_tax_id}`);
        }
    }
    // Fecha
    if (data.invoice_date) {
        const invDate = new Date(data.invoice_date);
        const now = new Date();
        if (invDate > now) {
            warnings.push("Fecha de factura en el futuro");
        }
        const fourYearsAgo = new Date();
        fourYearsAgo.setFullYear(now.getFullYear() - 4);
        if (invDate < fourYearsAgo) {
            warnings.push("Fecha muy antigua (>4 años, prescripción fiscal)");
        }
    }
    if ((_a = data.extraction_warnings) === null || _a === void 0 ? void 0 : _a.length) {
        warnings.push(...data.extraction_warnings);
    }
    return { errors, warnings };
}
function validateSpanishNif(nif) {
    const clean = nif.toUpperCase().replace(/[-\s]/g, "");
    const letters = "TRWAGMYFPDXBNJZSQVHLCKE";
    if (/^\d{8}[A-Z]$/.test(clean)) {
        return clean[8] === letters[parseInt(clean.slice(0, 8)) % 23];
    }
    if (/^[XYZ]\d{7}[A-Z]$/.test(clean)) {
        const prefix = { X: "0", Y: "1", Z: "2" };
        return (clean[8] ===
            letters[parseInt(prefix[clean[0]] + clean.slice(1, 8)) % 23]);
    }
    if (/^[ABCDEFGHJNPQRSUVW]\d{7}[0-9A-J]$/.test(clean)) {
        return true;
    }
    return false;
}
function decideStatus(data, validation) {
    if (validation.errors.length > 0)
        return "needs_review";
    if (parseFloat(data.total_amount || "0") > 3000)
        return "needs_review";
    if (!data.supplier_tax_id)
        return "needs_review";
    if (!data.invoice_number)
        return "needs_review";
    if (validation.warnings.some((w) => w.toLowerCase().includes("duplicado")))
        return "needs_review";
    return "posted";
}
function calculateConfidence(data, validation) {
    let score = 1.0;
    score -= validation.errors.length * 0.3;
    score -= validation.warnings.length * 0.05;
    if (!data.supplier_tax_id)
        score -= 0.2;
    if (!data.invoice_number)
        score -= 0.15;
    if (!data.invoice_date)
        score -= 0.2;
    return Math.max(0, Math.min(1, score));
}
//# sourceMappingURL=processInvoice.js.map