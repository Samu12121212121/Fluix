import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Anthropic from "@anthropic-ai/sdk";
import { DocumentProcessorServiceClient } from "@google-cloud/documentai";
import pdfParse from "pdf-parse";
import sharp from "sharp";
import {
  SYSTEM_PROMPT_INVOICE_ES,
  PROMPT_VERSION,
} from "./prompts/invoiceExtractionV1";

if (!admin.apps.length) admin.initializeApp();

const SYSTEM_PROMPT = SYSTEM_PROMPT_INVOICE_ES;

// ═══════════════════════════════════════════════════════════════
// HELPERS: LLAMADA A CLAUDE CON RETRY
// ═══════════════════════════════════════════════════════════════

async function extractWithClaude(
  rawText: string,
  docaiEntities: Record<string, any>,
): Promise<{ data: any; promptVersion: string }> {
  const anthropic = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY!,
  });
  const today = new Date().toISOString().split("T")[0];
  const userPrompt = `Extrae los datos fiscales de la siguiente factura.

País del receptor (cliente): ES
Fecha actual (para detectar fechas futuras): ${today}

═══ TEXTO_OCR ═══
${rawText}

═══ ENTIDADES_DOCAI ═══
${JSON.stringify(docaiEntities, null, 2)}

Devuelve solo el JSON según el schema del bloque 8.`;

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-5",
    max_tokens: 2500,
    temperature: 0,
    system: SYSTEM_PROMPT,
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
  maxRetries = 2,
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
// CLOUD FUNCTION
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
    try {

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
      const userDoc = await admin
        .firestore()
        .collection("usuarios")
        .doc(uid)
        .get();

      console.log(`userDoc exists: ${userDoc.exists}, empresa_id en doc: ${userDoc.data()?.empresa_id}`);

      if (!userDoc.exists || userDoc.data()?.empresa_id !== empresaId) {
        throw new HttpsError("permission-denied", "No pertenece a esta empresa");
      }

      // 3. VERIFICAR PACK FISCAL
      const empresaDoc = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .get();

      const activePacks = empresaDoc.data()?.active_packs || [];
      console.log(`active_packs: ${JSON.stringify(activePacks)}`);

      if (!activePacks.includes("fiscal_ai")) {
        throw new HttpsError(
          "failed-precondition",
          "Pack Fiscal IA no activo en esta empresa"
        );
      }

      // 4. CARGAR METADATA DEL DOCUMENTO
      console.log("Cargando documento de Firestore...");
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

      // 5. DESCARGAR ARCHIVO DE STORAGE
      // BUCKET CORRECTO para proyectos Firebase creados después de 2024
      console.log("Descargando archivo de Storage...");
      const bucket = admin.storage().bucket("planeaapp-4bea4.firebasestorage.app");
      const [fileBuffer] = await bucket.file(doc.storage_path).download();
      console.log(`Archivo descargado: ${fileBuffer.length} bytes`);

      // 6. EXTRAER TEXTO
      let rawText = "";
      let ocrEngine = "";

      if (doc.mime_type === "application/pdf") {
        console.log("Procesando PDF...");
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
          console.log("PDF escaneado, usando Document AI...");
          rawText = await callDocumentAI(fileBuffer, "application/pdf");
          ocrEngine = "document_ai_pdf";
        }
      } else if (doc.mime_type.startsWith("image/")) {
        console.log("Procesando imagen con Document AI...");
        const optimized = await sharp(fileBuffer)
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
      console.log("Creando extracción en Firestore...");
      const extractionRef = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("fiscal_extractions")
        .add({
          document_id: documentId,
          ocr_engine: ocrEngine,
          ocr_version: "1.0",
          llm_model: "claude-sonnet-4-5",
          prompt_version: PROMPT_VERSION,
          raw_text: rawText,
          status: "processing",
          extracted_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      // 8. LLAMAR A CLAUDE CON RETRY
      console.log("Llamando a Claude...");
      let invoiceData: any;

      try {
        const docaiEntities: Record<string, any> =
          (doc.docai_entities as Record<string, any>) || {};
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

      // 10. DETECTAR DUPLICADOS
      if (invoiceData.supplier_tax_id && invoiceData.invoice_number) {
        const dupQuery = await admin
          .firestore()
          .collection("empresas")
          .doc(empresaId)
          .collection("fiscal_transactions")
          .where("counterparty.tax_id", "==", invoiceData.supplier_tax_id)
          .where("invoice_number", "==", invoiceData.invoice_number)
          .where("status", "!=", "voided")
          .limit(1)
          .get();

        if (!dupQuery.empty) {
          validation.warnings.push("Posible duplicado de una factura ya registrada");
        }
      }

      // 11. PERÍODO FISCAL
      const invoiceDate = new Date(invoiceData.invoice_date);
      const year = invoiceDate.getFullYear();
      const quarter = Math.ceil((invoiceDate.getMonth() + 1) / 3);
      const period = `${year}-Q${quarter}`;

      // 12. DECIDIR ESTADO
      const status = decideStatus(invoiceData, validation);
      console.log(`Estado: ${status}`);

      // 13. GUARDAR EN fiscal_transactions
      console.log("Guardando fiscal_transaction...");
      const txRef = await admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("fiscal_transactions")
        .add({
          type: tipoDocumento === "ingreso" ? "invoice_issued" : "invoice_received",
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
          recargo_amount_cents: invoiceData.recargo_amount ? toCents(invoiceData.recargo_amount) : 0,
          recargo_rate: invoiceData.recargo_rate ? parseFloat(invoiceData.recargo_rate) : 0,
          withholding_amount_cents: invoiceData.withholding_amount ? toCents(invoiceData.withholding_amount) : 0,
          withholding_rate: invoiceData.withholding_rate ? parseFloat(invoiceData.withholding_rate) : 0,
          due_date: invoiceData.due_date || null,
          supplier_iban: invoiceData.supplier_iban || null,
          currency: invoiceData.currency || "EUR",
          vat_scheme: invoiceData.vat_scheme,
          tax_tags: invoiceData.tax_tags || [],
          lines: invoiceData.lines || [],
          validation_errors: validation.errors,
          validation_warnings: validation.warnings,
          extraction_warnings: invoiceData.extraction_warnings || [],
          _ai_ocr_engine: ocrEngine,
          _ai_llm_model: "claude-sonnet-4-5",
          _ai_prompt_version: PROMPT_VERSION,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          created_by: uid,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      // 14. GUARDAR EN facturas_recibidas (modelo contable existente)
      console.log("Guardando factura_recibida...");
      const baseAmount = parseFloat(invoiceData.base_amount || "0");
      const vatRate = parseFloat(invoiceData.vat_rate || "0");
      const vatAmount = parseFloat(invoiceData.vat_amount || "0");
      const totalAmount = parseFloat(invoiceData.total_amount || "0");
      const recargoRate = invoiceData.recargo_rate ? parseFloat(invoiceData.recargo_rate) : 0;

      const EU_COUNTRIES = [
        "AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR",
        "HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","SE"
      ];

      const esIntracomunitario =
        invoiceData.vat_scheme === "reverse_charge_eu" ||
        (invoiceData.supplier_country &&
          invoiceData.supplier_country !== "ES" &&
          EU_COUNTRIES.includes(invoiceData.supplier_country));

      const esArrendamiento = (invoiceData.tax_tags || []).includes("ALQUILER_LOCAL");

      const facturaRecibidaRef = admin
        .firestore()
        .collection("empresas")
        .doc(empresaId)
        .collection("facturas_recibidas")
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
          ...(validation.warnings.length > 0 ? [`⚠️ ${validation.warnings.join(", ")}`] : []),
          ...(invoiceData.vat_scheme !== "standard" ? [`Régimen IVA: ${invoiceData.vat_scheme}`] : []),
        ].join("\n"),
        fecha_creacion: ahora,
        fecha_actualizacion: ahora,
        _ai_transaction_id: txRef.id,
        _ai_document_id: documentId,
        _ai_confidence: calculateConfidence(invoiceData, validation),
        _ai_tax_tags: invoiceData.tax_tags || [],
        _ai_vat_scheme: invoiceData.vat_scheme,
        _ai_lines: invoiceData.lines || [],
      });

      // 15. COMPLETAR EXTRACCIÓN
      await extractionRef.update({
        raw_json: invoiceData,
        status: "success",
        confidence_score: calculateConfidence(invoiceData, validation),
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
      });

      console.log("=== processInvoice COMPLETADO OK ===");

      return {
        transaction_id: txRef.id,
        factura_recibida_id: facturaRecibidaRef.id,
        status,
        warnings: validation.warnings,
        errors: validation.errors,
      };

    } catch (error: any) {
      console.error("=== ERROR EN processInvoice ===");
      console.error("Tipo:", error?.constructor?.name);
      console.error("Mensaje:", error?.message);
      console.error("Código:", error?.code);
      console.error("Stack:", error?.stack);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "Error interno desconocido");
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

async function callDocumentAI(buffer: Buffer, mimeType: string): Promise<string> {
  const client = new DocumentProcessorServiceClient({
    apiEndpoint: "eu-documentai.googleapis.com",
  });

  const projectId = process.env.GCLOUD_PROJECT;
  const processorId = process.env.DOCAI_PROCESSOR_ID;
  const name = `projects/${projectId}/locations/eu/processors/${processorId}`;

  console.log(`Document AI llamada: project=${projectId}, processor=${processorId}`);

  const [result] = await client.processDocument({
    name,
    rawDocument: {
      content: buffer.toString("base64"),
      mimeType,
    },
  });

  return result.document?.text || "";
}

function toCents(amountStr: string | null | undefined): number {
  if (!amountStr) return 0;
  return Math.round(parseFloat(amountStr) * 100);
}

function validateInvoice(data: any): { errors: string[]; warnings: string[] } {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (data.vat_scheme !== "margin_scheme" && data.vat_scheme !== "reverse_charge_eu") {
    const base = parseFloat(data.base_amount || "0");
    const vat = parseFloat(data.vat_amount || "0");
    const recargo = parseFloat(data.recargo_amount || "0");
    const total = parseFloat(data.total_amount || "0");
    if (Math.abs(base + vat + recargo - total) > 0.02) {
      errors.push(`Total no cuadra: ${base} + ${vat} + ${recargo} ≠ ${total}`);
    }
  }

  if (data.supplier_country === "ES" && data.supplier_tax_id) {
    if (!validateSpanishNif(data.supplier_tax_id)) {
      warnings.push(`NIF con formato no estándar: ${data.supplier_tax_id}`);
    }
  }

  if (data.invoice_date) {
    const invDate = new Date(data.invoice_date);
    const now = new Date();
    if (invDate > now) warnings.push("Fecha de factura en el futuro");
    const fourYearsAgo = new Date();
    fourYearsAgo.setFullYear(now.getFullYear() - 4);
    if (invDate < fourYearsAgo) warnings.push("Fecha muy antigua (>4 años)");
  }

  if (data.extraction_warnings?.length) {
    warnings.push(...data.extraction_warnings);
  }

  return { errors, warnings };
}

function validateSpanishNif(nif: string): boolean {
  const clean = nif.toUpperCase().replace(/[-\s]/g, "");
  const letters = "TRWAGMYFPDXBNJZSQVHLCKE";
  if (/^\d{8}[A-Z]$/.test(clean)) {
    return clean[8] === letters[parseInt(clean.slice(0, 8)) % 23];
  }
  if (/^[XYZ]\d{7}[A-Z]$/.test(clean)) {
    const prefix: Record<string, string> = { X: "0", Y: "1", Z: "2" };
    return clean[8] === letters[parseInt(prefix[clean[0]] + clean.slice(1, 8)) % 23];
  }
  if (/^[ABCDEFGHJNPQRSUVW]\d{7}[0-9A-J]$/.test(clean)) return true;
  return false;
}

function decideStatus(data: any, validation: any): string {
  if (validation.errors.length > 0) return "needs_review";
  if (parseFloat(data.total_amount || "0") > 3000) return "needs_review";
  if (!data.supplier_tax_id) return "needs_review";
  if (!data.invoice_number) return "needs_review";
  if (validation.warnings.some((w: string) => w.toLowerCase().includes("duplicado"))) return "needs_review";
  return "posted";
}

function calculateConfidence(data: any, validation: any): number {
  let score = 1.0;
  score -= validation.errors.length * 0.3;
  score -= validation.warnings.length * 0.05;
  if (!data.supplier_tax_id) score -= 0.2;
  if (!data.invoice_number) score -= 0.15;
  if (!data.invoice_date) score -= 0.2;
  return Math.max(0, Math.min(1, score));
}