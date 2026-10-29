/**
 * borrar_facturas_prueba.js
 * ─────────────────────────────────────────────────────────────────
 * Borra TODAS las facturas, presupuestos y albaranes de una cuenta.
 * (todos están en empresas/{empresaId}/facturas con distinto tipo)
 *
 * USO:
 *   node scripts/borrar_facturas_prueba.js EMAIL@gmail.com
 *
 * Ejemplo:
 *   node scripts/borrar_facturas_prueba.js sacoor80@gmail.com
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "..", "credentials.json");

let serviceAccount;
try {
  serviceAccount = require(SERVICE_ACCOUNT_PATH);
} catch {
  console.error("❌ No se encontró credentials.json en la raíz del proyecto.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db   = admin.firestore();

async function borrarColeccion(colRef) {
  const BATCH_SIZE = 400;
  let borrados = 0;

  while (true) {
    const snap = await colRef.limit(BATCH_SIZE).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    borrados += snap.size;
    process.stdout.write(`\r   Borrados: ${borrados}...`);
  }

  return borrados;
}

async function main() {
  const email = process.argv[2];

  if (!email) {
    console.error("❌ Debes pasar el email como argumento.");
    console.error("   Ejemplo: node scripts/borrar_facturas_prueba.js sacoor80@gmail.com");
    process.exit(1);
  }

  console.log(`\n🔍 Buscando usuario: ${email}...`);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch {
    console.error(`❌ No se encontró ningún usuario con email "${email}" en Firebase Auth.`);
    process.exit(1);
  }

  const uid = userRecord.uid;
  console.log(`✅ Usuario encontrado: uid=${uid}`);

  // Obtener empresaId desde el doc de usuario (puede diferir del uid)
  const usuarioSnap = await db.collection("usuarios").doc(uid).get();
  let empresaId = uid; // fallback

  if (usuarioSnap.exists) {
    const data = usuarioSnap.data();
    empresaId = data.empresa_id || data.empresaId || uid;
    console.log(`   empresa_id en doc usuario: ${empresaId}`);
  } else {
    console.log(`   ⚠️  No hay doc /usuarios/${uid}, usando uid como empresaId`);
  }

  const empresaRef = db.collection("empresas").doc(empresaId);
  const empresaSnap = await empresaRef.get();

  if (!empresaSnap.exists) {
    console.error(`❌ No existe el documento /empresas/${empresaId} en Firestore.`);
    console.error(`   UID Auth: ${uid}`);
    console.error(`   empresaId probado: ${empresaId}`);
    process.exit(1);
  }

  console.log(`✅ Empresa encontrada: ${empresaSnap.data().nombre || uid}\n`);

  // Colección única que contiene facturas + presupuestos (tipo=proforma) + albaranes (tipo=albaran)
  const facturasRef = empresaRef.collection("facturas");

  // Contar primero para informar
  const countSnap = await facturasRef.count().get();
  const total = countSnap.data().count;

  if (total === 0) {
    console.log("ℹ️  No hay facturas/presupuestos/albaranes que borrar.");
    process.exit(0);
  }

  console.log(`📋 Documentos a borrar en /empresas/${uid}/facturas: ${total}`);
  console.log("⏳ Borrando...");

  const borrados = await borrarColeccion(facturasRef);

  console.log(`\n\n═══════════════════════════════════════════════════════`);
  console.log(`✅  ¡LISTO! Datos de prueba eliminados.`);
  console.log(`═══════════════════════════════════════════════════════`);
  console.log(`   Email   : ${email}`);
  console.log(`   UID     : ${uid}`);
  console.log(`   Borrados: ${borrados} documentos (facturas + presupuestos + albaranes)`);
  console.log(`═══════════════════════════════════════════════════════\n`);

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Error inesperado:", err.message);
  process.exit(1);
});
