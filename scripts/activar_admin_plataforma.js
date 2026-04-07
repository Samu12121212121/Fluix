/**
 * activar_admin_plataforma.js
 * ─────────────────────────────────────────────────────────────────
 * Script de un solo uso para activar el flag es_plataforma_admin=true
 * en la cuenta del propietario de la plataforma FluxTech.
 *
 * USO:
 *   node scripts/activar_admin_plataforma.js TU_EMAIL@gmail.com
 *
 * Ejemplo:
 *   node scripts/activar_admin_plataforma.js samu@fluixcrm.app
 *
 * Requisitos:
 *   - Tener el archivo credentials.json (Service Account de Firebase)
 *     en la raíz del proyecto (ya existe en tu proyecto).
 *   - Node.js instalado.
 *   - firebase-admin: npm install firebase-admin (o usa el de functions/)
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

// ── Configuración ────────────────────────────────────────────────
// Ruta al Service Account JSON (el credentials.json de tu proyecto)
const SERVICE_ACCOUNT_PATH = path.join(__dirname, "..", "credentials.json");

// ── Inicializar Firebase Admin ────────────────────────────────────
let serviceAccount;
try {
  serviceAccount = require(SERVICE_ACCOUNT_PATH);
} catch {
  console.error("❌ No se encontró credentials.json en la raíz del proyecto.");
  console.error("   Descárgalo de: Firebase Console → Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db   = admin.firestore();

// ── Main ──────────────────────────────────────────────────────────
async function main() {
  const email = process.argv[2];

  if (!email) {
    console.error("❌ Debes pasar tu email como argumento.");
    console.error("   Ejemplo: node scripts/activar_admin_plataforma.js tucorreo@gmail.com");
    process.exit(1);
  }

  console.log(`🔍 Buscando usuario con email: ${email}...`);

  // 1. Buscar el UID por email en Firebase Auth
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch {
    console.error(`❌ No se encontró ningún usuario con email "${email}" en Firebase Auth.`);
    console.error("   Asegúrate de haber iniciado sesión en la app al menos una vez.");
    process.exit(1);
  }

  const uid = userRecord.uid;
  console.log(`✅ Usuario encontrado: uid=${uid}`);

  // 2. Actualizar el doc en Firestore
  const usuarioRef = db.collection("usuarios").doc(uid);
  const snap = await usuarioRef.get();

  if (!snap.exists) {
    console.error(`❌ No existe el documento /usuarios/${uid} en Firestore.`);
    console.error("   Inicia sesión en la app para que se cree el documento de usuario.");
    process.exit(1);
  }

  await usuarioRef.update({
    es_plataforma_admin: true,
    rol: "propietario",            // asegurarse de que también es propietario
  });

  console.log("");
  console.log("═══════════════════════════════════════════════════════");
  console.log("✅  ¡LISTO! Administrador de plataforma activado.");
  console.log("═══════════════════════════════════════════════════════");
  console.log(`   Email  : ${email}`);
  console.log(`   UID    : ${uid}`);
  console.log(`   Flag   : es_plataforma_admin = true`);
  console.log("");
  console.log("👉  Cierra sesión en la app y vuelve a iniciarla.");
  console.log("    Verás un nuevo tab 'Cuentas' en Perfil.");
  console.log("═══════════════════════════════════════════════════════");

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Error inesperado:", err.message);
  process.exit(1);
});


