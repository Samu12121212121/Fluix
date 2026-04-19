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
Object.defineProperty(exports, "__esModule", { value: true });
exports.firmarXMLVerifactu = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const forge = __importStar(require("node-forge"));
// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: firmarXMLVerifactu
// Firma XAdES-BES del XML Verifactu usando certificado PKCS#12
// El certificado se almacena en Firestore (config/verifactu_cert)
// ═══════════════════════════════════════════════════════════════════════════════
const REGION = "europe-west1";
exports.firmarXMLVerifactu = (0, https_1.onCall)({ region: REGION, timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Validar autenticación
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "No autenticado");
    }
    const { xmlSinFirmar, empresaId } = request.data;
    if (!xmlSinFirmar || !empresaId) {
        throw new https_1.HttpsError("invalid-argument", "xmlSinFirmar y empresaId son requeridos");
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
        const userEmpresa = (_b = (_a = userRoot.data()) === null || _a === void 0 ? void 0 : _a.empresa_id) !== null && _b !== void 0 ? _b : (_c = userRoot.data()) === null || _c === void 0 ? void 0 : _c.empresaId;
        if (userEmpresa !== empresaId) {
            throw new https_1.HttpsError("permission-denied", "Sin permiso para esta empresa");
        }
    }
    // 3. Leer certificado PKCS12 desde Firestore
    let p12Buffer;
    let p12Password;
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
        p12Buffer = Buffer.from(certData.p12Base64, "base64");
        p12Password = certData.password;
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new https_1.HttpsError("not-found", `Certificado digital no configurado: ${msg}`);
    }
    // 4. Parsear PKCS12 con node-forge
    let privateKey;
    let certificate;
    try {
        const p12Der = forge.util.createBuffer(p12Buffer.toString("binary"));
        const p12Asn1 = forge.asn1.fromDer(p12Der);
        const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);
        const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
        const pkBags = p12.getBags({
            bagType: forge.pki.oids.pkcs8ShroudedKeyBag,
        });
        const certBag = (_d = certBags[forge.pki.oids.certBag]) === null || _d === void 0 ? void 0 : _d[0];
        const pkBag = (_e = pkBags[forge.pki.oids.pkcs8ShroudedKeyBag]) === null || _e === void 0 ? void 0 : _e[0];
        if (!(certBag === null || certBag === void 0 ? void 0 : certBag.cert) || !(pkBag === null || pkBag === void 0 ? void 0 : pkBag.key)) {
            throw new Error("Certificado o clave privada no encontrados en el PKCS#12");
        }
        privateKey = pkBag.key;
        certificate = certBag.cert;
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new https_1.HttpsError("internal", `Error parseando PKCS12: ${msg}`);
    }
    // 5. Generar firma XAdES-BES
    try {
        const xmlFirmado = firmarXAdESBES(xmlSinFirmar, privateKey, certificate);
        return { xmlFirmado };
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new https_1.HttpsError("internal", `Error generando firma XAdES: ${msg}`);
    }
});
// ═══════════════════════════════════════════════════════════════════════════════
// FIRMA XAdES-BES
// ═══════════════════════════════════════════════════════════════════════════════
function firmarXAdESBES(xmlSinFirmar, privateKey, certificate) {
    // Certificado en DER → base64
    const certDer = forge.asn1.toDer(forge.pki.certificateToAsn1(certificate));
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
    const signedProperties = `<xades:SignedProperties Id="${signedPropsId}">` +
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
    const signedInfo = `<ds:SignedInfo>` +
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
    const signatureBlock = `<ds:Signature Id="${signatureId}" ` +
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
//# sourceMappingURL=firmarXMLVerifactu.js.map