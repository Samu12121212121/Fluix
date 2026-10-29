import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as forge from "node-forge";
import * as https from "https";

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION: remitirVerifactu
// Envía XML firmado a la AEAT vía SOAP con mTLS
// ═══════════════════════════════════════════════════════════════════════════════

const REGION = "europe-west1";

const ENDPOINTS = {
  pruebas:
    "https://prewww2.aeat.es/wlpl/TIKE-CONT/ws/SuministroInformacion",
  produccion:
    "https://www2.aeat.es/wlpl/TIKE-CONT/ws/SuministroInformacion",
};

export const remitirVerifactu = onCall(
  { region: REGION, timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "No autenticado");
    }

    const { xmlFirmado, empresaId, facturaId } = request.data as {
      xmlFirmado: string;
      empresaId: string;
      facturaId: string;
    };

    if (!xmlFirmado || !empresaId || !facturaId) {
      throw new HttpsError(
        "invalid-argument",
        "Parámetros requeridos: xmlFirmado, empresaId, facturaId"
      );
    }

    const db = admin.firestore();

    // 1. Leer entorno (pruebas/produccion)
    const configDoc = await db.collection("config").doc("verifactu").get();
    const entorno = (configDoc.data()?.entorno ?? "pruebas") as keyof typeof ENDPOINTS;
    const endpoint = ENDPOINTS[entorno] ?? ENDPOINTS.pruebas;

    // 2. Cargar certificado PKCS12
    let p12Buffer: Buffer;
    let p12Password: string;

    try {
      let certDoc = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("certificado_verifactu")
        .get();

      if (!certDoc.exists) {
        throw new Error(
          "Esta empresa no tiene certificado digital configurado para Verifactu. " +
          "Ve a Configuración → Verifactu → Certificado para subir tu archivo .p12."
        );
      }

      const certData = certDoc.data()!;
      p12Buffer = Buffer.from(certData.p12Base64, "base64");
      p12Password = certData.password;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      await guardarEstadoFirestore(db, facturaId, empresaId, "error", null, msg);
      throw new HttpsError("not-found", `Certificado: ${msg}`);
    }

    // 3. Extraer clave y cert del PKCS12 para mTLS
    let certPem: string;
    let keyPem: string;

    try {
      const p12Der = forge.util.createBuffer(p12Buffer.toString("binary"));
      const p12Asn1 = forge.asn1.fromDer(p12Der);
      const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);

      const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
      const pkBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag });
      const cert = certBags[forge.pki.oids.certBag]?.[0]?.cert!;
      const key = pkBags[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0]?.key!;

      certPem = forge.pki.certificateToPem(cert);
      keyPem = forge.pki.privateKeyToPem(key as forge.pki.rsa.PrivateKey);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      await guardarEstadoFirestore(db, facturaId, empresaId, "error", null, msg);
      throw new HttpsError("internal", `Error parseando PKCS12: ${msg}`);
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
    let respuestaAEAT: string;
    try {
      respuestaAEAT = await enviarSOAP(endpoint, soapBody, certPem, keyPem);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      await guardarEstadoFirestore(db, facturaId, empresaId, "error", null, msg);
      throw new HttpsError("unavailable", `Error conectando con AEAT: ${msg}`);
    }

    // 6. Parsear respuesta AEAT
    const estadoAEAT = parsearRespuestaAEAT(respuestaAEAT);

    // 7. Guardar estado en Firestore
    await guardarEstadoFirestore(
      db,
      facturaId,
      empresaId,
      estadoAEAT.estado,
      estadoAEAT.csv,
      estadoAEAT.descripcionError
    );

    return {
      estado: estadoAEAT.estado,
      csv: estadoAEAT.csv,
      descripcionError: estadoAEAT.descripcionError,
    };
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCIÓN REUTILIZABLE — usada también por procesarColaVerifactu
// ═══════════════════════════════════════════════════════════════════════════════

/** Envía un XML firmado a AEAT para una empresa/factura concretas y persiste el resultado. */
export async function enviarSOAPInterno(
  empresaId: string,
  facturaId: string,
  xmlFirmado: string
): Promise<{ estado: string; csv: string | null; descripcionError: string | null }> {
  const db = admin.firestore();
  const configDoc = await db.collection("config").doc("verifactu").get();
  const entorno = (configDoc.data()?.entorno ?? "pruebas") as keyof typeof ENDPOINTS;
  const endpoint = ENDPOINTS[entorno] ?? ENDPOINTS.pruebas;

  let certDoc = await db
    .collection("empresas").doc(empresaId)
    .collection("configuracion").doc("certificado_verifactu")
    .get();
  if (!certDoc.exists) throw new Error(
    "Esta empresa no tiene certificado digital configurado. Ve a Configuración → Verifactu → Certificado."
  );

  const certData = certDoc.data()!;
  const p12Buffer = Buffer.from(certData.p12Base64, "base64");
  const p12Der = forge.util.createBuffer(p12Buffer.toString("binary"));
  const p12 = forge.pkcs12.pkcs12FromAsn1(forge.asn1.fromDer(p12Der), certData.password);
  const cert = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag]?.[0]?.cert!;
  const key = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0]?.key!;
  const certPem = forge.pki.certificateToPem(cert);
  const keyPem = forge.pki.privateKeyToPem(key as forge.pki.rsa.PrivateKey);

  const soapBody = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sum="https://www2.aeat.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.wsdl">
  <soapenv:Header/><soapenv:Body><sum:SuministroLRFacturasEmitidas>${xmlFirmado}</sum:SuministroLRFacturasEmitidas></soapenv:Body>
</soapenv:Envelope>`;

  const respuestaXML = await enviarSOAP(endpoint, soapBody, certPem, keyPem);
  const resultado = parsearRespuestaAEAT(respuestaXML);
  await guardarEstadoFirestore(db, facturaId, empresaId, resultado.estado, resultado.csv, resultado.descripcionError);
  return resultado;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

function enviarSOAP(
  endpoint: string,
  body: string,
  certPem: string,
  keyPem: string
): Promise<string> {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint);

    const options: https.RequestOptions = {
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
      res.on("data", (chunk: Buffer) => (data += chunk.toString()));
      res.on("end", () => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
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

function parsearRespuestaAEAT(xml: string): {
  estado: string;
  csv: string | null;
  descripcionError: string | null;
} {
  const estadoMatch = xml.match(/<EstadoEnvio[^>]*>([^<]+)<\/EstadoEnvio>/);
  const csvMatch = xml.match(/<CSV[^>]*>([^<]+)<\/CSV>/);
  const errorMatch = xml.match(
    /<DescripcionErrorRegistro[^>]*>([^<]+)<\/DescripcionErrorRegistro>/
  );

  const estadoAEAT = estadoMatch?.[1]?.trim();
  // "Correcto" = AEAT aceptó, "AceptadoConErrores" = parcial, resto = rechazado
  const estado = estadoAEAT === "Correcto"
    ? "enviada"
    : estadoAEAT === "AceptadoConErrores"
    ? "aceptada"
    : "rechazada";

  return {
    estado,
    csv: csvMatch?.[1]?.trim() ?? null,
    descripcionError: errorMatch?.[1]?.trim() ?? null,
  };
}

async function guardarEstadoFirestore(
  db: admin.firestore.Firestore,
  facturaId: string,
  empresaId: string,
  estado: string,
  csv: string | null,
  error: string | null
): Promise<void> {
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
        "verifactu.fechaUltimoEnvio":
          admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch {
    // No bloquear si falla la escritura de estado
    console.error(
      `No se pudo actualizar estado verifactu para factura ${facturaId}`
    );
  }
}

