import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as forge from "node-forge";

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: firmarXMLVerifactu
// Firma XAdES-BES del XML Verifactu usando certificado PKCS#12
// El certificado se almacena en Firestore (config/verifactu_cert)
// ═══════════════════════════════════════════════════════════════════════════════

const REGION = "europe-west1";

export const firmarXMLVerifactu = onCall(
  { region: REGION, timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    // 1. Validar autenticación
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "No autenticado");
    }

    const { xmlSinFirmar, empresaId } = request.data as {
      xmlSinFirmar: string;
      empresaId: string;
    };

    if (!xmlSinFirmar || !empresaId) {
      throw new HttpsError(
        "invalid-argument",
        "xmlSinFirmar y empresaId son requeridos"
      );
    }

    // 2. Verificar que el usuario pertenece a la empresa
    const db = admin.firestore();
    const userDoc = await db
      .collection("empresas")
      .doc(empresaId)
      .collection("usuarios")
      .doc(request.auth.uid)
      .get();

    if (!userDoc.exists) {
      // Fallback: verificar en colección raíz de usuarios
      const userRoot = await db.collection("usuarios").doc(request.auth.uid).get();
      const userEmpresa = userRoot.data()?.empresa_id ?? userRoot.data()?.empresaId;
      if (userEmpresa !== empresaId) {
        throw new HttpsError("permission-denied", "Sin permiso para esta empresa");
      }
    }

    // 3. Leer certificado PKCS12 desde Firestore
    let p12Buffer: Buffer;
    let p12Password: string;

    try {
      // Intentar certificado específico de empresa
      let certDoc = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("certificado_verifactu")
        .get();

      if (!certDoc.exists) {
        // Fallback a certificado global
        certDoc = await db.collection("config").doc("verifactu_cert").get();
      }

      if (!certDoc.exists) {
        throw new Error("No se encontró certificado");
      }

      const certData = certDoc.data();
      p12Buffer = Buffer.from(certData!.p12Base64, "base64");
      p12Password = certData!.password;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError(
        "not-found",
        `Certificado digital no configurado: ${msg}`
      );
    }

    // 4. Parsear PKCS12 con node-forge
    let privateKey: forge.pki.rsa.PrivateKey;
    let certificate: forge.pki.Certificate;

    try {
      const p12Der = forge.util.createBuffer(p12Buffer.toString("binary"));
      const p12Asn1 = forge.asn1.fromDer(p12Der);
      const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);

      const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
      const pkBags = p12.getBags({
        bagType: forge.pki.oids.pkcs8ShroudedKeyBag,
      });

      const certBag = certBags[forge.pki.oids.certBag]?.[0];
      const pkBag = pkBags[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0];

      if (!certBag?.cert || !pkBag?.key) {
        throw new Error("Certificado o clave privada no encontrados en el PKCS#12");
      }

      privateKey = pkBag.key as forge.pki.rsa.PrivateKey;
      certificate = certBag.cert;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Error parseando PKCS12: ${msg}`);
    }

    // 5. Generar firma XAdES-BES
    try {
      const xmlFirmado = firmarXAdESBES(xmlSinFirmar, privateKey, certificate);
      return { xmlFirmado };
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Error generando firma XAdES: ${msg}`);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FIRMA XAdES-BES
// ═══════════════════════════════════════════════════════════════════════════════

function firmarXAdESBES(
  xmlSinFirmar: string,
  privateKey: forge.pki.rsa.PrivateKey,
  certificate: forge.pki.Certificate
): string {
  // Certificado en DER → base64
  const certDer = forge.asn1.toDer(
    forge.pki.certificateToAsn1(certificate)
  );
  const certBase64 = forge.util.encode64(certDer.data);

  // Hash SHA-256 del certificado (para XAdES CertDigest)
  const certMd = forge.md.sha256.create();
  certMd.update(certDer.data);
  const certHash = forge.util.encode64(certMd.digest().data);

  // IDs únicos
  const signatureId = `Signature-${Date.now()}`;
  const signedPropsId = `SignedProperties-${signatureId}`;
  const signingTime = new Date().toISOString();

  // SignedProperties (XAdES)
  const signedProperties =
    `<xades:SignedProperties Id="${signedPropsId}">` +
    `<xades:SignedSignatureProperties>` +
    `<xades:SigningTime>${signingTime}</xades:SigningTime>` +
    `<xades:SigningCertificateV2>` +
    `<xades:Cert>` +
    `<xades:CertDigest>` +
    `<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>` +
    `<ds:DigestValue>${certHash}</ds:DigestValue>` +
    `</xades:CertDigest>` +
    `</xades:Cert>` +
    `</xades:SigningCertificateV2>` +
    `</xades:SignedSignatureProperties>` +
    `</xades:SignedProperties>`;

  // Digest del documento XML
  const docMd = forge.md.sha256.create();
  docMd.update(Buffer.from(xmlSinFirmar, "utf8").toString("binary"));
  const docDigest = forge.util.encode64(docMd.digest().data);

  // Digest de SignedProperties
  const spMd = forge.md.sha256.create();
  spMd.update(Buffer.from(signedProperties, "utf8").toString("binary"));
  const spDigest = forge.util.encode64(spMd.digest().data);

  // SignedInfo
  const signedInfo =
    `<ds:SignedInfo>` +
    `<ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>` +
    `<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>` +
    `<ds:Reference URI="">` +
    `<ds:Transforms>` +
    `<ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>` +
    `<ds:Transform Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>` +
    `</ds:Transforms>` +
    `<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>` +
    `<ds:DigestValue>${docDigest}</ds:DigestValue>` +
    `</ds:Reference>` +
    `<ds:Reference Type="http://uri.etsi.org/01903#SignedProperties" URI="#${signedPropsId}">` +
    `<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>` +
    `<ds:DigestValue>${spDigest}</ds:DigestValue>` +
    `</ds:Reference>` +
    `</ds:SignedInfo>`;

  // Firmar SignedInfo con RSA-SHA256
  const md = forge.md.sha256.create();
  md.update(Buffer.from(signedInfo, "utf8").toString("binary"));
  const signature = privateKey.sign(md);
  const signatureB64 = forge.util.encode64(signature);

  // Bloque Signature completo
  const signatureBlock =
    `<ds:Signature Id="${signatureId}" ` +
    `xmlns:ds="http://www.w3.org/2000/09/xmldsig#" ` +
    `xmlns:xades="http://uri.etsi.org/01903/v1.3.2#">` +
    signedInfo +
    `<ds:SignatureValue>${signatureB64}</ds:SignatureValue>` +
    `<ds:KeyInfo>` +
    `<ds:X509Data>` +
    `<ds:X509Certificate>${certBase64}</ds:X509Certificate>` +
    `</ds:X509Data>` +
    `</ds:KeyInfo>` +
    `<ds:Object>` +
    `<xades:QualifyingProperties Target="#${signatureId}">` +
    signedProperties +
    `</xades:QualifyingProperties>` +
    `</ds:Object>` +
    `</ds:Signature>`;

  // Insertar firma antes del cierre del elemento raíz
  return xmlSinFirmar.replace(/<\/([^>]+)>\s*$/, signatureBlock + "</$1>");
}

