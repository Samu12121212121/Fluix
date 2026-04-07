/**
 * subir_cert_verifactu.js
 *
 * Genera un certificado PKCS#12 de PRUEBA con node-forge
 * y lo sube a Firestore en TWO rutas:
 *
 *   1. config/verifactu_cert          ← fallback global (para cualquier empresa)
 *   2. empresas/{EMPRESA_ID}/configuracion/certificado_verifactu  ← específico
 *
 * USO:
 *   node subir_cert_verifactu.js
 *   node subir_cert_verifactu.js --empresaId=TU_ID_AQUI
 *
 * REQUISITOS: ejecutar desde la raíz del proyecto Flutter
 *   (donde están credentials.json y la carpeta functions/)
 */

const path = require("path");

// Usar node-forge y firebase-admin desde functions/node_modules
const forge = require(path.join(__dirname, "functions", "node_modules", "node-forge"));
const admin = require(path.join(__dirname, "functions", "node_modules", "firebase-admin"));

// ── Leer parámetros ────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const empresaIdArg = args.find((a) => a.startsWith("--empresaId="));
const empresaId = empresaIdArg ? empresaIdArg.split("=")[1] : null;

const CERT_PASSWORD = "fluixtest2026";
const PROJECT_ID   = "planeaapp-4bea4";

// ── Inicializar Firebase Admin ─────────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, "credentials.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});

const db = admin.firestore();

// ══════════════════════════════════════════════════════════════════════════════
// PASO 1 — Generar certificado RSA 2048 autofirmado con node-forge
// ══════════════════════════════════════════════════════════════════════════════
function generarCertificadoPrueba() {
  console.log("\n🔐 Generando par de claves RSA 2048...");

  const keys = forge.pki.rsa.generateKeyPair({ bits: 2048, e: 0x10001 });
  const cert = forge.pki.createCertificate();

  cert.publicKey = keys.publicKey;
  cert.serialNumber = "01";
  cert.validity.notBefore = new Date();
  cert.validity.notAfter  = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 2);

  const attrs = [
    { name: "commonName",         value: "Fluix CRM Pruebas Verifactu" },
    { name: "organizationName",   value: "Fluix"                       },
    { name: "organizationalUnitName", value: "Desarrollo"              },
    { name: "localityName",       value: "Guadalajara"                 },
    { name: "stateOrProvinceName", value: "Guadalajara"                },
    { shortName: "C",             value: "ES"                          },
  ];

  cert.setSubject(attrs);
  cert.setIssuer(attrs);
  cert.setExtensions([
    { name: "basicConstraints", cA: false },
    { name: "keyUsage",  digitalSignature: true, nonRepudiation: true,
      keyEncipherment: true },
  ]);

  cert.sign(keys.privateKey, forge.md.sha256.create());
  console.log("✅ Certificado generado (válido 2 años)");

  // ── Crear PKCS#12 ──────────────────────────────────────────────────────
  const p12Asn1 = forge.pkcs12.toPkcs12Asn1(
    keys.privateKey,
    [cert],
    CERT_PASSWORD,
    { generateLocalKeyId: true, algorithm: "3des" }
  );

  const p12Der  = forge.asn1.toDer(p12Asn1).getBytes();
  const p12B64  = forge.util.encode64(p12Der);

  console.log(`✅ PKCS#12 creado — contraseña: ${CERT_PASSWORD}`);
  console.log(`   Tamaño base64: ${p12B64.length} chars`);

  return p12B64;
}

// ══════════════════════════════════════════════════════════════════════════════
// PASO 2 — Subir a Firestore
// ══════════════════════════════════════════════════════════════════════════════
async function subirAFirestore(p12Base64) {
  const payload = {
    p12Base64,
    password:      CERT_PASSWORD,
    fecha_subida:  admin.firestore.FieldValue.serverTimestamp(),
    nombre:        "cert_pruebas_verifactu_2026.p12",
    tipo:          "autofirmado_pruebas",
    nota:          "SOLO PRUEBAS — Reemplazar con certificado FNMT real para produccion",
  };

  const rutas = [];

  // Ruta 1: global fallback (siempre)
  rutas.push({
    ref:  db.collection("config").doc("verifactu_cert"),
    desc: "config/verifactu_cert (fallback global)",
  });

  // Ruta 2: específico de empresa (si se proporcionó --empresaId)
  if (empresaId) {
    rutas.push({
      ref: db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("certificado_verifactu"),
      desc: `empresas/${empresaId}/configuracion/certificado_verifactu`,
    });
  }

  for (const ruta of rutas) {
    console.log(`\n📤 Subiendo a: ${ruta.desc}`);
    await ruta.ref.set(payload, { merge: true });
    console.log(`   ✅ Guardado correctamente`);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log("════════════════════════════════════════");
  console.log("  Subir Certificado Verifactu a Firestore");
  console.log("  Proyecto: " + PROJECT_ID);
  if (empresaId) console.log("  Empresa:  " + empresaId);
  else           console.log("  Empresa:  (solo fallback global)");
  console.log("════════════════════════════════════════");

  try {
    const p12Base64 = generarCertificadoPrueba();
    await subirAFirestore(p12Base64);

    console.log("\n════════════════════════════════════════");
    console.log("✅ CERTIFICADO SUBIDO CORRECTAMENTE");
    console.log("════════════════════════════════════════");
    console.log("");
    console.log("Contraseña guardada en Firestore: " + CERT_PASSWORD);
    console.log("");
    console.log("Las Cloud Functions ya pueden firmar XMLs Verifactu.");
    console.log("");
    if (!empresaId) {
      console.log("💡 Para subir también al doc de una empresa específica:");
      console.log("   node subir_cert_verifactu.js --empresaId=TU_ID_AQUI");
      console.log("");
      console.log("💡 Para encontrar tu empresaId:");
      console.log("   Firebase Console → Firestore → colección 'empresas'");
    }
    console.log("⚠️  Este es un certificado de PRUEBAS.");
    console.log("   Para producción, sube tu certificado FNMT desde la app:");
    console.log("   Configuración Fiscal → Certificado Verifactu");
  } catch (err) {
    console.error("\n❌ ERROR:", err.message || err);
    process.exit(1);
  }

  process.exit(0);
}

main();

