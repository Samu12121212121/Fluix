import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Anthropic from "@anthropic-ai/sdk";
import { DocumentProcessorServiceClient } from "@google-cloud/documentai";
import pdfParse from "pdf-parse";
import sharp from "sharp";
import * as crypto from "crypto";
import fetch from "node-fetch";
import {
  SYSTEM_PROMPT_INVOICE_ES,
  PROMPT_VERSION,
} from "./prompts/invoiceExtractionV4";
import { preprocesarTextoOCR } from "./ocrPreprocessor";

if (!admin.apps.length) admin.initializeApp();

const EU_COUNTRIES = [
  "AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR",
  "HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","SE"
];

// ═══════════════════════════════════════════════════════════════
// HELPER: HASH SHA-256 del archivo (detección de duplicados)
// ═══════════════════════════════════════════════════════════════

function computeFileHash(buffer: Buffer): string {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

// ═══════════════════════════════════════════════════════════════
// HELPER: TIPO DE CAMBIO BCE (Banco Central Europeo)
// Llama a la API SDMX pública del BCE para obtener el tipo de
// cambio oficial de cierre del día anterior.
// ═══════════════════════════════════════════════════════════════

async function fetchExchangeRateBCE(currency: string): Promise<{
  rate: number;
  date: string;
} | null> {
  if (currency === "EUR") return null;
  try {
    const url =
      `https://data-api.ecb.europa.eu/service/data/EXR/D.${currency}.EUR.SP00.A` +
      `?lastNObservations=1&format=jsondata`;

    const resp = await fetch(url, {
      headers: { "Accept": "application/json" },
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      signal: (AbortSignal as any).timeout(8000),
    });

    if (!resp.ok) {
      console.warn(`BCE API HTTP ${resp.status} para ${currency}`);
      return null;
    }

    const json = await resp.json() as any;
    const observations =
      json?.dataSets?.[0]?.series?.["0:0:0:0:0"]?.observations;

    if (!observations) {
      console.warn(`BCE: sin observaciones para ${currency}`);
      return null;
    }

    const keys = Object.keys(observations).sort((a, b) => Number(b) - Number(a));
    const latestKey = keys[0];
    const rateRaw = observations[latestKey]?.[0];

    if (!rateRaw) return null;

    // El BCE da EUR por 1 unidad de divisa. Invertimos para obtener divisa/EUR.
    const rateEurPerForeign = parseFloat(rateRaw);

    // Obtener la fecha de la observación más reciente
    const timeDimension = json?.structure?.dimensions?.observation?.find(
      (d: any) => d.id === "TIME_PERIOD"
    );
    const dateStr =
      timeDimension?.values?.[parseInt(latestKey)]?.id || new Date().toISOString().substring(0, 10);

    return { rate: rateEurPerForeign, date: dateStr };
  } catch (e) {
    console.warn(`BCE API error para ${currency}:`, e);
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER: DOCUMENT AI
// ═══════════════════════════════════════════════════════════════

async function callDocumentAI(
  fileBuffer: Buffer,
  mimeType: string
): Promise<string> {
  const client = new DocumentProcessorServiceClient();
  const processorId = process.env.DOCAI_PROCESSOR_ID!;
  const encodedFile = fileBuffer.toString("base64");

  const [result] = await client.processDocument({
    name: processorId,
    rawDocument: { content: encodedFile, mimeType },
  });

  return result.document?.text || "";
}

// ═══════════════════════════════════════════════════════════════
// HELPER: CLAUDE CON RETRY
// ═══════════════════════════════════════════════════════════════

async function extractWithClaude(
  rawText: string,
  docaiEntities: Record<string, any>
): Promise<{ data: any; promptVersion: string }> {
  const anthropic = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY!,
  });

  const today = new Date().toISOString().split("T")[0];

  // ── NUEVO v4: preprocesar el texto OCR ──────────────────────
  const { textoEnriquecido, avisos } = preprocesarTextoOCR(rawText);
  if (avisos.length > 0) {
    console.log(`[preprocesador] avisos: ${avisos.join(', ')}`);
  }
  // ────────────────────────────────────────────────────────────

  const userPrompt = `Extrae los datos fiscales de la siguiente factura.

País del receptor (cliente): ES
Fecha actual (para detectar fechas futuras): ${today}

═══ TEXTO_OCR ═══
${textoEnriquecido}

═══ ENTIDADES_DOCAI ═══
${JSON.stringify(docaiEntities, null, 2)}

Devuelve solo el JSON según el schema del bloque 8.`;

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 2500,
    temperature: 0,
    system: SYSTEM_PROMPT_INVOICE_ES,
    messages: [{ role: "user", content: userPrompt }],
  });

  const responseText = (message.content[0] as any).text;
  const cleaned = responseText
    .replace(/^```json\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  const data = JSON.parse(cleaned);
  return { data, promptVersion: PROMPT_VERSION };
}

async function extractWithRetry(
  rawText: string,
  docaiEntities: Record<string, any>,
  maxRetries = 2
): Promise<any> {
  let lastError: Error | null = null;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await extractWithClaude(rawText, docaiEntities);
    } catch (e: any) {
      lastError = e;
      if (e.message?.includes("JSON") || e instanceof SyntaxError) {
        console.warn(`Intento ${attempt + 1} falló por JSON inválido`);
        await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
        continue;
      }
      if (e.status === 429 || e.status === 503) {
        console.warn(`Intento ${attempt + 1} falló por API: ${e.status}`);
        await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
        continue;
      }
      throw e;
    }
  }
  throw lastError || new Error("Max retries exceeded");
}

// ═══════════════════════════════════════════════════════════════
// HELPER: VALIDACIÓN
// ═══════════════════════════════════════════════════════════════

function validateInvoice(data: any): { errors: string[]; warnings: string[] } {
  const errors: string[] = [];
  const warnings: string[] = [...(data.extraction_warnings || [])];

  if (!data.invoice_date) errors.push("Fecha de factura ausente");
  if (!data.supplier_name) errors.push("Proveedor ausente");
  if (!data.total_amount || data.total_amount === "0.00") errors.push("Importe total ausente o cero");
  if (!data.base_amount || data.base_amount === "0.00") errors.push("Base imponible ausente o cero");

  // Validación matemática con fórmula v3 (incluye non_subject_amount)
  const base = parseFloat(data.base_amount || "0");
  const vat = parseFloat(data.vat_amount || "0");
  const recargo = parseFloat(data.recargo_amount || "0");
  const retencion = parseFloat(data.withholding_amount || "0");
  const noSujeto = parseFloat(data.non_subject_amount || "0");
  const total = parseFloat(data.total_amount || "0");

  if (
    data.vat_scheme !== "margin_scheme" &&
    data.vat_scheme !== "reverse_charge_eu" &&
    data.vat_scheme !== "reverse_charge_domestic"
  ) {
    const calculado = base + vat + recargo - retencion + noSujeto;
    const diferencia = Math.abs(calculado - total);

    if (diferencia > 20) {
      warnings.push(`math_mismatch: calculado=${calculado.toFixed(2)}, declarado=${total.toFixed(2)}, diff=${diferencia.toFixed(2)}`);
    } else if (diferencia > 0.10) {
      warnings.push(`math_small_discrepancy: diff=${diferencia.toFixed(2)}`);
    }
  }

  // Detección automática: proveedor fuera de UE → art. 21 exención IVA importación
  const supplierCountry = (data.supplier_country || "").toUpperCase();
  if (
    supplierCountry &&
    supplierCountry !== "ES" &&
    !EU_COUNTRIES.includes(supplierCountry) &&
    data.vat_scheme !== "margin_scheme"
  ) {
    if (!(data.tax_tags || []).includes("IMPORTACION_TERCEROS_PAISES")) {
      (data.tax_tags = data.tax_tags || []).push("IMPORTACION_TERCEROS_PAISES");
    }
    if (!data.vat_scheme || data.vat_scheme === "standard") {
      data.vat_scheme = "import_vat";
      warnings.push("Posible importación de terceros países (art.21 LIVA) — verifica la exención de IVA");
    }
  }

  // Régimen de margen (REBU / art. 135 LIVA)
  if (data.vat_scheme === "margin_scheme") {
    if (!(data.tax_tags || []).includes("REBU")) {
      (data.tax_tags = data.tax_tags || []).push("REBU");
    }
    warnings.push("Régimen especial del margen de beneficios (REBU) — IVA calculado sobre el margen, no sobre el total");
  }

  return { errors, warnings };
}

// ═══════════════════════════════════════════════════════════════
// HELPER: CONFIANZA (auto-publicación ≥ 92%)
// ═══════════════════════════════════════════════════════════════

function calculateConfidence(
  data: any,
  validation: { errors: string[]; warnings: string[] },
  docaiEntities: Record<string, any>
): number {
  const criticalFields = [
    "invoice_number",
    "invoice_date",
    "supplier_name",
    "supplier_tax_id",
    "base_amount",
    "total_amount",
    "vat_amount",
  ];

  let totalScore = 0;
  let fieldCount = 0;

  for (const field of criticalFields) {
    if (data[field] !== null && data[field] !== undefined) {
      const docaiScore = docaiEntities[field]?.confidence ?? 0.75;
      totalScore += docaiScore;
    }
    fieldCount++;
  }

  let score = totalScore / fieldCount;

  // Penalizaciones
  const hasMathMismatch = validation.warnings.some((w) =>
    w.startsWith("math_mismatch")
  );
  const hasMultipleVAT = validation.warnings.some((w) =>
    w.includes("multiple_vat_rates")
  );
  const hasErrors = validation.errors.length > 0;

  if (hasMathMismatch) score -= 0.15;
  if (hasMultipleVAT) score -= 0.05;
  if (hasErrors) score -= 0.20;

  return Math.max(0, Math.min(1, score));
}

function decideStatus(
  data: any,
  validation: { errors: string[]; warnings: string[] },
  docaiEntities: Record<string, any>
): string {
  if (validation.errors.length > 0) return "needs_review";
  if (!data.supplier_tax_id) return "needs_review";
  if (!data.invoice_number) return "needs_review";
  if (parseFloat(data.total_amount || "0") > 3000) return "needs_review";

  const confidence = calculateConfidence(data, validation, docaiEntities);

  // Auto-publicación si confianza ≥ 92%
  if (confidence >= 0.92) return "posted";
  return "needs_review";
}


function toCents(value: string | number): number {
  return Math.round(parseFloat(String(value)) * 100);
}

// ═══════════════════════════════════════════════════════════════
// CLOUD FUNCTION PRINCIPAL
// ═══════════════════════════════════════════════════════════════

export const processInvoice = onCall(
  {
    region: "europe-west1",
    memory: "1GiB",
    timeoutSeconds: 180,
    secrets: ["ANTHROPIC_API_KEY", "DOCAI_PROCESSOR_ID"],
    cors: true,
  },
  async (request) => {
    console.log("=== processInvoice INICIADO ===");

    // 1. AUTH
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debe estar autenticado");
    }

    const uid = request.auth.uid;
    const { empresaId, documentId, tipoDocumento = "gasto" } = request.data;

    console.log(`uid: ${uid}, empresaId: ${empresaId}, documentId: ${documentId}`);

    if (!empresaId || !documentId) {
      throw new HttpsError("invalid-argument", "Faltan empresaId o documentId");
    }

    // 2. VERIFICAR PERTENENCIA
    const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();

    if (!userDoc.exists || userDoc.data()?.empresa_id !== empresaId) {
      throw new HttpsError("permission-denied", "No pertenece a esta empresa");
    }

    // 3. VERIFICAR PACK FISCAL
    const empresaDoc = await admin.firestore().collection("empresas").doc(empresaId).get();
    const activePacks = empresaDoc.data()?.active_packs || [];

    if (!activePacks.includes("fiscal_ai")) {
      throw new HttpsError(
        "failed-precondition",
        "Pack Fiscal IA no activo en esta empresa"
      );
    }

    // 4. CARGAR METADATA DEL DOCUMENTO
    const docRef = admin
      .firestore()
      .collection("empresas")
      .doc(empresaId)
      .collection("fiscal_documents")
      .doc(documentId);

    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw new HttpsError("not-found", "Documento no existe en Firestore");
    }

    const doc = docSnap.data()!;
    console.log(`storage_path: ${doc.storage_path}, mime_type: ${doc.mime_type}`);

    // 5. DESCARGAR ARCHIVO DE STORAGE + calcular hash SHA-256
    const bucket = admin.storage().bucket("planeaapp-4bea4.firebasestorage.app");
    const [fileBuffer] = await bucket.file(doc.storage_path).download();
    const fileHash = computeFileHash(fileBuffer);
    console.log(`Archivo descargado: ${fileBuffer.length} bytes, hash: ${fileHash.substring(0, 12)}…`);

    // 6. EXTRAER TEXTO
    let rawText = "";
    let ocrEngine = "";

    if (doc.mime_type === "application/pdf") {
      try {
        const parsed = await pdfParse(fileBuffer);
        if (parsed.text && parsed.text.trim().length >= 50) {
          rawText = parsed.text;
          ocrEngine = "pdf-parse";
          console.log(`PDF con texto nativo: ${rawText.length} chars`);
        }
      } catch (e) {
        console.warn("pdf-parse falló:", e);
      }

      if (!rawText) {
        rawText = await callDocumentAI(fileBuffer, "application/pdf");
        ocrEngine = "document_ai_pdf";
      }
    } else if (doc.mime_type.startsWith("image/")) {
      const optimized = await sharp(fileBuffer)
        .rotate()
        .resize({ width: 2400, height: 2400, fit: "inside", withoutEnlargement: true })
        .jpeg({ quality: 90 })
        .toBuffer();

      rawText = await callDocumentAI(optimized, "image/jpeg");
      ocrEngine = "document_ai_image";
    } else {
      throw new HttpsError(
        "invalid-argument",
        `Tipo de archivo no soportado: ${doc.mime_type}`
      );
    }

    console.log(`OCR completado. Motor: ${ocrEngine}, Chars: ${rawText.length}`);

    if (!rawText || rawText.trim().length < 10) {
      await docRef.update({
        processing_status: "failed",
        processing_error: "No se pudo extraer texto del archivo",
      });
      throw new HttpsError(
        "internal",
        "No se pudo extraer texto. Asegúrate de que la factura es legible."
      );
    }

    // 7. CREAR REGISTRO DE EXTRACCIÓN
    const extractionRef = await admin
      .firestore()
      .collection("empresas")
      .doc(empresaId)
      .collection("fiscal_extractions")
      .add({
        document_id: documentId,
        ocr_engine: ocrEngine,
        ocr_version: "1.0",
        llm_model: "claude-sonnet-4-20250514",
        prompt_version: PROMPT_VERSION,
        raw_text: rawText,
        status: "processing",
        extracted_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    // 8. LLAMAR A CLAUDE CON RETRY
    let invoiceData: any;
    const docaiEntities: Record<string, any> =
      (doc.docai_entities as Record<string, any>) || {};

    try {
      const result = await extractWithRetry(rawText, docaiEntities);
      invoiceData = result.data;
      console.log("Claude respondió OK");
    } catch (e: any) {
      console.error("Error en Claude:", e.message);
      await extractionRef.update({
        status: "failed",
        error: e.message || "Error en LLM",
      });
      throw new HttpsError("internal", "La IA no pudo procesar la factura");
    }

    // 9. VALIDAR
    const validation = validateInvoice(invoiceData);
    console.log(`Validación: ${validation.errors.length} errores, ${validation.warnings.length} warnings`);

    // 10. DETECTAR DUPLICADOS — por hash SHA-256 del archivo (exacto) y por NIF+número (lógico)
    // 10a. Duplicado exacto por hash
    const hashQuery = await admin
      .firestore()
      .collection("empresas")
      .doc(empresaId)
      .collection("fiscal_documents")
      .where("file_hash", "==", fileHash)
      .where("status", "!=", "processing")
      .limit(1)
      .get();

    if (!hashQuery.empty && hashQuery.docs[0].id !== documentId) {
      validation.errors.push(
        `Archivo duplicado — este fichero ya fue subido (doc: ${hashQuery.docs[0].id})`
      );
    } else {
      // Guardar hash en el documento para futuras comparaciones
      await docRef.update({ file_hash: fileHash });
    }

    // 10b. Duplicado lógico por NIF proveedor + número de factura
    if (invoiceData.supplier_tax_id && invoiceData.invoice_number) {
      const dupQuery = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("fiscal_transactions")
        .where("supplier_tax_id", "==", invoiceData.supplier_tax_id)
        .where("invoice_number", "==", invoiceData.invoice_number)
        .where("status", "!=", "voided")
        .limit(1)
        .get();

      if (!dupQuery.empty) {
        validation.warnings.push(
          `Posible duplicado — ya existe una factura de ${invoiceData.supplier_tax_id} con nº ${invoiceData.invoice_number}`
        );
      }
    }

    // 11. DECIDIR ESTADO (auto-publicación ≥ 92% confianza)
    const confidence = calculateConfidence(invoiceData, validation, docaiEntities);
    const status = decideStatus(invoiceData, validation, docaiEntities);
    const autoPublished = status === "posted";

    console.log(`Confianza: ${(confidence * 100).toFixed(1)}%, estado: ${status}, auto_published: ${autoPublished}`);

    // 12. CONVERSIÓN DE MONEDA BCE (llamada real a la API del BCE)
    let bceRate: { rate: number; date: string } | null = null;
    const currency = invoiceData.currency || "EUR";
    const needsCurrencyConversion = currency !== "EUR";

    if (needsCurrencyConversion) {
      bceRate = await fetchExchangeRateBCE(currency);
      if (bceRate) {
        console.log(`BCE: 1 ${currency} = ${bceRate.rate} EUR (${bceRate.date})`);
      } else {
        validation.warnings.push(
          `No se pudo obtener tipo de cambio BCE para ${currency} — conversión pendiente manual`
        );
      }
    }

    // 13. PARSEAR FECHA
    let invoiceDate: Date;
    try {
      invoiceDate = new Date(invoiceData.invoice_date);
      if (isNaN(invoiceDate.getTime())) throw new Error("Fecha inválida");
    } catch {
      invoiceDate = new Date();
    }

    const ahora = admin.firestore.Timestamp.now();

    // 14A. CREAR FISCAL TRANSACTION
    const baseAmount = parseFloat(invoiceData.base_amount || "0");
    const vatAmount = parseFloat(invoiceData.vat_amount || "0");
    const vatRate = parseFloat(invoiceData.vat_rate || "0");
    const totalAmount = parseFloat(invoiceData.total_amount || "0");
    const recargoRate = parseFloat(invoiceData.recargo_rate || "0");
    const withholdingAmount = parseFloat(invoiceData.withholding_amount || "0");
    const nonSubjectAmount = parseFloat(invoiceData.non_subject_amount || "0");

    const esIntracomunitario =
      invoiceData.vat_scheme === "reverse_charge_eu" ||
      (invoiceData.supplier_country &&
        invoiceData.supplier_country !== "ES" &&
        EU_COUNTRIES.includes(invoiceData.supplier_country));

    const esArrendamiento = (invoiceData.tax_tags || []).includes("ALQUILER_LOCAL");

    const txRef = admin
      .firestore()
      .collection("empresas")
      .doc(empresaId)
      .collection("fiscal_transactions")
      .doc();

    await txRef.set({
      // Identificación
      type: tipoDocumento === "ingreso" ? "income" : "expense",
      status,
      auto_published: autoPublished,
      confidence_score: confidence,

      // Documento origen
      document_id: documentId,
      extraction_id: extractionRef.id,
      prompt_version: PROMPT_VERSION,

      // Proveedor/Cliente
      supplier_name: invoiceData.supplier_name || "",
      supplier_legal_name: invoiceData.supplier_legal_name || null,
      supplier_tax_id: invoiceData.supplier_tax_id || null,
      supplier_country: invoiceData.supplier_country || "ES",
      supplier_address: invoiceData.supplier_address || null,
      supplier_iban: invoiceData.supplier_iban || null,
      customer_name: invoiceData.customer_name || null,
      customer_tax_id: invoiceData.customer_tax_id || null,

      // Datos fiscales
      invoice_number: invoiceData.invoice_number || null,
      invoice_date: admin.firestore.Timestamp.fromDate(invoiceDate),
      due_date: invoiceData.due_date
        ? admin.firestore.Timestamp.fromDate(new Date(invoiceData.due_date))
        : null,

      // Importes (v3: incluye non_subject_amount)
      base_amount_cents: toCents(baseAmount),
      vat_rate: vatRate,
      vat_amount_cents: toCents(vatAmount),
      recargo_rate: recargoRate,
      recargo_amount_cents: toCents(invoiceData.recargo_amount || "0"),
      withholding_rate: parseFloat(invoiceData.withholding_rate || "0"),
      withholding_amount_cents: toCents(withholdingAmount),
      non_subject_amount_cents: toCents(nonSubjectAmount),
      total_amount_cents: toCents(totalAmount),

      // Moneda
      currency: currency,
      needs_currency_conversion: needsCurrencyConversion,
      conversion_status: !needsCurrencyConversion
        ? "not_needed"
        : bceRate
          ? "converted"
          : "pending",
      eur_amount: bceRate ? Math.round(totalAmount * bceRate.rate * 100) / 100 : null,
      exchange_rate: bceRate?.rate ?? null,
      exchange_rate_date: bceRate?.date ?? null,
      exchange_rate_source: bceRate ? "ECB" : null,
      original_currency_data: bceRate
        ? {
            original_currency: currency,
            original_total: totalAmount,
            exchange_rate: bceRate.rate,
            rate_date: bceRate.date,
            total_eur: Math.round(totalAmount * bceRate.rate * 100) / 100,
          }
        : null,

      // Régimen y clasificación
      vat_scheme: invoiceData.vat_scheme || "standard",
      tax_tags: invoiceData.tax_tags || [],
      lines: invoiceData.lines || [],
      es_intracomunitario: esIntracomunitario,
      es_arrendamiento: esArrendamiento,

      // Validación
      validation_errors: validation.errors,
      validation_warnings: validation.warnings,

      // Metadatos IA
      _ai_llm_model: "claude-sonnet-4-20250514",
      _ai_prompt_version: PROMPT_VERSION,
      _ai_ocr_engine: ocrEngine,

      // Timestamps
      created_at: ahora,
      updated_at: ahora,
    });

    // 14B. CREAR REGISTRO EN COLECCIÓN LEGACY
    if (tipoDocumento === "ingreso") {
      // Facturas emitidas
      const facturaEmitidaRef = admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("facturas")
        .doc();

      await facturaEmitidaRef.set({
        empresa_id: empresaId,
        numero_factura: invoiceData.invoice_number || `AI-${documentId.substring(0, 8)}`,
        fecha_emision: admin.firestore.Timestamp.fromDate(invoiceDate),
        cliente_nombre: invoiceData.customer_name || invoiceData.supplier_name || "",
        datos_fiscales: {
          nif: invoiceData.customer_tax_id || null,
          razon_social: invoiceData.customer_name || null,
          direccion: null,
          pais: invoiceData.customer_country || "ES",
        },
        subtotal: baseAmount,
        total_iva: vatAmount,
        total: totalAmount,
        lineas: (invoiceData.lines || []).map((l: any) => ({
          descripcion: l.description || "",
          precio_unitario: parseFloat(l.unit_price || "0"),
          cantidad: parseInt(l.quantity || "1"),
          porcentaje_iva: parseFloat(l.vat_rate || invoiceData.vat_rate || "21"),
          descuento: 0,
          recargo_equivalencia: 0,
        })),
        estado: status === "posted" ? "emitida" : "pendiente",
        fecha_creacion: ahora,
        fecha_actualizacion: ahora,
        _ai_transaction_id: txRef.id,
        _ai_document_id: documentId,
        _ai_confidence: confidence,
      });

      await extractionRef.update({
        raw_json: invoiceData,
        status: "success",
        confidence_score: confidence,
        transaction_id: txRef.id,
        factura_id: facturaEmitidaRef.id,
      });

      console.log("=== processInvoice COMPLETADO OK (ingreso) ===");

      return {
        transaction_id: txRef.id,
        factura_id: facturaEmitidaRef.id,
        status,
        auto_published: autoPublished,
        confidence_score: Math.round(confidence * 100),
        needs_currency_conversion: needsCurrencyConversion,
        warnings: validation.warnings,
        errors: validation.errors,
      };

    } else {
      // Facturas recibidas (gastos)
      const facturaRecibidaRef = admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("facturas_recibidas")
        .doc();

      await facturaRecibidaRef.set({
        empresa_id: empresaId,
        numero_factura: invoiceData.invoice_number || `AI-${documentId.substring(0, 8)}`,
        fecha_emision: admin.firestore.Timestamp.fromDate(invoiceDate),
        fecha_recepcion: ahora,

        // Proveedor
        nif_proveedor: invoiceData.supplier_tax_id || "",
        nif_iva_comunitario: esIntracomunitario ? invoiceData.supplier_tax_id : null,
        es_intracomunitario: esIntracomunitario,
        nombre_proveedor: invoiceData.supplier_name || "",
        direccion_proveedor: invoiceData.supplier_address || null,
        telefono_proveedor: null,

        // Importes (v3: campo non_subject_amount separado)
        base_imponible: baseAmount,
        porcentaje_iva: vatRate,
        importe_iva: vatAmount,
        importe_no_sujeto: nonSubjectAmount,   // ← NUEVO v3
        iva_deducible: !(invoiceData.tax_tags || []).includes("VAT_NOT_DEDUCTIBLE"),
        descuento_global: 0,
        recargo_equivalencia: recargoRate,
        porcentaje_retencion: parseFloat(invoiceData.withholding_rate || "0") || null,
        importe_retencion: withholdingAmount || null,
        total_con_impuestos: totalAmount,

        // Moneda
        moneda: invoiceData.currency || "EUR",
        importe_eur: invoiceData.currency === "EUR" ? totalAmount : null,
        tipo_cambio: null,
        conversion_status: invoiceData.currency === "EUR" ? "not_needed" : "pending",

        // Estado y pago
        estado: status === "posted" ? "recibida" : "pendiente",
        auto_published: autoPublished,
        fecha_pago: null,
        metodo_pago: null,
        referencia_bancaria: null,

        // Arrendamiento
        es_arrendamiento: esArrendamiento,
        nif_arrendador: esArrendamiento ? invoiceData.supplier_tax_id : null,
        concepto_arrendamiento: esArrendamiento ? "Alquiler local" : null,

        // Notas
        notas: [
          `Procesada por IA (${ocrEngine})`,
          ...(validation.warnings.length > 0
            ? [`⚠️ ${validation.warnings.join(", ")}`]
            : []),
          ...(invoiceData.vat_scheme !== "standard"
            ? [`Régimen IVA: ${invoiceData.vat_scheme}`]
            : []),
          ...(nonSubjectAmount > 0
            ? [`Importe no sujeto a IVA: ${nonSubjectAmount.toFixed(2)}€`]
            : []),
        ]
          .filter(Boolean)
          .join("\n"),

        // Metadatos
        fecha_creacion: ahora,
        fecha_actualizacion: ahora,
        _ai_transaction_id: txRef.id,
        _ai_document_id: documentId,
        _ai_confidence: confidence,
        _ai_tax_tags: invoiceData.tax_tags || [],
        _ai_vat_scheme: invoiceData.vat_scheme,
        _ai_lines: invoiceData.lines || [],
      });

      await extractionRef.update({
        raw_json: invoiceData,
        status: "success",
        confidence_score: confidence,
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
      });

      console.log("=== processInvoice COMPLETADO OK (gasto) ===");

      return {
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
        status,
        auto_published: autoPublished,
        confidence_score: Math.round(confidence * 100),
        needs_currency_conversion: needsCurrencyConversion,
        warnings: validation.warnings,
        errors: validation.errors,
      };
    }
  }
);