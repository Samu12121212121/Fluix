import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as crypto from "crypto";
import fetch from "node-fetch";

// ═══════════════════════════════════════════════════════════════════════════════
// SELLO DE TIEMPO (TSA) — RFC 3161
//
// Se activa cuando un documento pasa a estado_firma = 'firmado'.
// Envía el hash SHA-256 del PDF firmado a FreeTSA.org (TSA pública gratuita)
// y guarda el token de respuesta en Storage + URL en Firestore.
//
// El token TSA es prueba criptográfica de que el documento existía en ese
// instante — refuerza la validez legal bajo eIDAS art. 26 y Ley 6/2020.
// ═══════════════════════════════════════════════════════════════════════════════

const TSA_URL = "https://freetsa.org/tsr";
const BUCKET  = "planeaapp-4bea4.firebasestorage.app";

// ── Construir TimeStampReq RFC 3161 (DER) con SHA-256 ──────────────────────
// Estructura ASN.1 mínima válida para cualquier TSA compatible con RFC 3161
function buildTsq(hash: Buffer): Buffer {
  const SHA256_OID = Buffer.from("3031300d060960864801650304020105000420", "hex");
  // TimeStampReq ::= SEQUENCE { version INTEGER, messageImprint MessageImprint, certReq BOOLEAN }
  const msgImprint = Buffer.concat([SHA256_OID, hash]);         // AlgorithmId + hash
  const certReq    = Buffer.from("0101ff", "hex");              // certReq = TRUE

  // Envolver en SEQUENCE con longitud
  function wrap(tag: number, content: Buffer): Buffer {
    const lenBuf = content.length < 128
      ? Buffer.from([content.length])
      : Buffer.from([0x82, (content.length >> 8) & 0xff, content.length & 0xff]);
    return Buffer.concat([Buffer.from([tag]), lenBuf, content]);
  }

  const version    = Buffer.from("020101", "hex");              // INTEGER 1
  const imprint    = wrap(0x30, msgImprint);                    // SEQUENCE
  const inner      = Buffer.concat([version, imprint, certReq]);
  return wrap(0x30, inner);
}

// ── Cloud Function trigger ────────────────────────────────────────────────────
export const onDocumentoFirmado = onDocumentUpdated(
  "usuarios/{uid}/documentos/{docId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();

    // Solo actuar cuando pasa de no-firmado a firmado
    if (!after || after.estado_firma !== "firmado" || before?.estado_firma === "firmado") return;
    if (after.tsa_token_url) return; // ya tiene sello

    const uid   = event.params.uid;
    const docId = event.params.docId;
    const storagePath = after.storage_path as string | undefined;
    if (!storagePath) return;

    try {
      // 1. Descargar PDF firmado
      const bucket   = admin.storage().bucket(BUCKET);
      const [pdfBuf] = await bucket.file(storagePath).download();

      // 2. Hash SHA-256 del PDF firmado
      const hash = crypto.createHash("sha256").update(pdfBuf).digest();

      // 3. Construir TSQ y enviar a FreeTSA.org
      const tsq = buildTsq(hash);
      const res = await fetch(TSA_URL, {
        method: "POST",
        headers: { "Content-Type": "application/timestamp-query" },
        body: tsq,
        signal: AbortSignal.timeout(10000),
      });

      if (!res.ok) throw new Error(`TSA HTTP ${res.status}`);
      const tsrBuf = Buffer.from(await res.arrayBuffer());

      // 4. Guardar token en Storage
      const tsaPath = storagePath.replace(/\.pdf$/, "_tsa.tsr");
      await bucket.file(tsaPath).save(tsrBuf, {
        metadata: { contentType: "application/timestamp-reply" },
      });
      const [tsaUrl] = await bucket.file(tsaPath).getSignedUrl({
        action: "read",
        expires: "01-01-2099",
      });

      // 5. Actualizar Firestore con URL del token y hash del PDF firmado
      await admin.firestore()
        .collection("usuarios").doc(uid)
        .collection("documentos").doc(docId)
        .update({
          tsa_token_url:    tsaUrl,
          tsa_hash_sha256:  hash.toString("hex"),
          tsa_timestamp:    admin.firestore.FieldValue.serverTimestamp(),
          tsa_issuer:       "FreeTSA.org — RFC 3161",
        });

      console.log(`✅ TSA aplicado a doc ${docId} (uid ${uid})`);
    } catch (e) {
      console.error(`⚠️ TSA error para ${docId}:`, e);
      // No propagamos el error — la firma es válida aunque el sello falle
    }
  }
);
