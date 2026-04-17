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
exports.remitirVerifactu = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const forge = __importStar(require("node-forge"));
const https = __importStar(require("https"));
// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: remitirVerifactu
// Envía XML firmado a la AEAT vía SOAP con mTLS
// ═══════════════════════════════════════════════════════════════════════════════
const REGION = "europe-west1";
const ENDPOINTS = {
    pruebas: "https://prewww2.aeat.es/wlpl/TIKE-CONT/ws/SuministroInformacion",
    produccion: "https://www2.aeat.es/wlpl/TIKE-CONT/ws/SuministroInformacion",
};
exports.remitirVerifactu = (0, https_1.onCall)({ region: REGION, timeoutSeconds: 120, memory: "512MiB" }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "No autenticado");
    }
    const { xmlFirmado, empresaId, facturaId } = request.data;
    if (!xmlFirmado || !empresaId || !facturaId) {
        throw new https_1.HttpsError("invalid-argument", "Parámetros requeridos: xmlFirmado, empresaId, facturaId");
    }
    const db = admin.firestore();
    // 1. Leer entorno (pruebas/produccion)
    const configDoc = await db.collection("config").doc("verifactu").get();
    const entorno = ((_b = (_a = configDoc.data()) === null || _a === void 0 ? void 0 : _a.entorno) !== null && _b !== void 0 ? _b : "pruebas");
    const endpoint = (_c = ENDPOINTS[entorno]) !== null && _c !== void 0 ? _c : ENDPOINTS.pruebas;
    // 2. Cargar certificado PKCS12
    let p12Buffer;
    let p12Password;
    try {
        let certDoc = await db
            .collection("empresas")
            .doc(empresaId)
            .collection("configuracion")
            .doc("certificado_verifactu")
            .get();
        if (!certDoc.exists) {
            certDoc = await db.collection("config").doc("verifactu_cert").get();
        }
        if (!certDoc.exists) {
            throw new Error("Certificado no configurado");
        }
        const certData = certDoc.data();
        p12Buffer = Buffer.from(certData.p12Base64, "base64");
        p12Password = certData.password;
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        await guardarEstadoFirestore(db, facturaId, empresaId, "error_cert", null, msg);
        throw new https_1.HttpsError("not-found", `Certificado: ${msg}`);
    }
    // 3. Extraer clave y cert del PKCS12 para mTLS
    let certPem;
    let keyPem;
    try {
        const p12Der = forge.util.createBuffer(p12Buffer.toString("binary"));
        const p12Asn1 = forge.asn1.fromDer(p12Der);
        const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);
        const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
        const pkBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag });
        const cert = (_e = (_d = certBags[forge.pki.oids.certBag]) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.cert;
        const key = (_g = (_f = pkBags[forge.pki.oids.pkcs8ShroudedKeyBag]) === null || _f === void 0 ? void 0 : _f[0]) === null || _g === void 0 ? void 0 : _g.key;
        certPem = forge.pki.certificateToPem(cert);
        keyPem = forge.pki.privateKeyToPem(key);
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        await guardarEstadoFirestore(db, facturaId, empresaId, "error_cert", null, msg);
        throw new https_1.HttpsError("internal", `Error parseando PKCS12: ${msg}`);
    }
    // 4. Construir SOAP envelope
    const soapBody = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope
  xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:sum="https://www2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.wsdl">
  <soapenv:Header/>
  <soapenv:Body>
    <sum:SuministroLRFacturasEmitidas>
      ${xmlFirmado}
    </sum:SuministroLRFacturasEmitidas>
  </soapenv:Body>
</soapenv:Envelope>`;
    // 5. Enviar petición SOAP con mTLS
    let respuestaAEAT;
    try {
        respuestaAEAT = await enviarSOAP(endpoint, soapBody, certPem, keyPem);
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        await guardarEstadoFirestore(db, facturaId, empresaId, "error_red", null, msg);
        throw new https_1.HttpsError("unavailable", `Error conectando con AEAT: ${msg}`);
    }
    // 6. Parsear respuesta AEAT
    const estadoAEAT = parsearRespuestaAEAT(respuestaAEAT);
    // 7. Guardar estado en Firestore
    await guardarEstadoFirestore(db, facturaId, empresaId, estadoAEAT.estado, estadoAEAT.csv, estadoAEAT.descripcionError);
    return {
        estado: estadoAEAT.estado,
        csv: estadoAEAT.csv,
        descripcionError: estadoAEAT.descripcionError,
    };
});
// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
function enviarSOAP(endpoint, body, certPem, keyPem) {
    return new Promise((resolve, reject) => {
        const url = new URL(endpoint);
        const options = {
            hostname: url.hostname,
            port: 443,
            path: url.pathname,
            method: "POST",
            cert: certPem,
            key: keyPem,
            rejectUnauthorized: true,
            headers: {
                "Content-Type": "text/xml;charset=utf-8",
                "SOAPAction": "SuministroLRFacturasEmitidas",
                "Content-Length": Buffer.byteLength(body, "utf8").toString(),
            },
            timeout: 90000,
        };
        const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk.toString()));
            res.on("end", () => {
                if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(data);
                }
                else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data.substring(0, 500)}`));
                }
            });
        });
        req.on("error", reject);
        req.on("timeout", () => {
            req.destroy();
            reject(new Error("Timeout conectando con AEAT (90s)"));
        });
        req.write(body);
        req.end();
    });
}
function parsearRespuestaAEAT(xml) {
    var _a, _b, _c, _d, _e;
    const estadoMatch = xml.match(/<EstadoEnvio[^>]*>([^<]+)<\/EstadoEnvio>/);
    const csvMatch = xml.match(/<CSV[^>]*>([^<]+)<\/CSV>/);
    const errorMatch = xml.match(/<DescripcionErrorRegistro[^>]*>([^<]+)<\/DescripcionErrorRegistro>/);
    const estado = ((_a = estadoMatch === null || estadoMatch === void 0 ? void 0 : estadoMatch[1]) === null || _a === void 0 ? void 0 : _a.trim()) === "Correcto" ? "enviado" : "rechazado";
    return {
        estado,
        csv: (_c = (_b = csvMatch === null || csvMatch === void 0 ? void 0 : csvMatch[1]) === null || _b === void 0 ? void 0 : _b.trim()) !== null && _c !== void 0 ? _c : null,
        descripcionError: (_e = (_d = errorMatch === null || errorMatch === void 0 ? void 0 : errorMatch[1]) === null || _d === void 0 ? void 0 : _d.trim()) !== null && _e !== void 0 ? _e : null,
    };
}
async function guardarEstadoFirestore(db, facturaId, empresaId, estado, csv, error) {
    try {
        await db
            .collection("empresas")
            .doc(empresaId)
            .collection("facturas")
            .doc(facturaId)
            .update({
            "verifactu.estado": estado,
            "verifactu.csv": csv,
            "verifactu.ultimoError": error,
            "verifactu.fechaUltimoEnvio": admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (_a) {
        // No bloquear si falla la escritura de estado
        console.error(`No se pudo actualizar estado verifactu para factura ${facturaId}`);
    }
}
//# sourceMappingURL=remitirVerifactu.js.map