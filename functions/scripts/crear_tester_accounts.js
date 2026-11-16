/**
 * crear_tester_accounts.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Crea dos cuentas de prueba (admin + staff) dentro de la empresa asociada
 * al propietario sacoor80@gmail.com.
 *
 * Uso:
 *   cd functions
 *   node scripts/crear_tester_accounts.js
 *   node scripts/crear_tester_accounts.js --dry-run   (solo muestra, no crea)
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');

const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => { const [k, ...v] = a.slice(2).split('='); return [k, v.join('=') || true]; })
);
const DRY_RUN = args['dry-run'] === true || args['dry-run'] === 'true';

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const auth = admin.auth();

// ── Configuración ──────────────────────────────────────────────────────────
const PROPIETARIO_EMAIL = 'sacoor80@gmail.com';
const PASSWORD          = 'R4?¿payaso';

const CUENTAS = [
  { emailLocal: 'Tester_Fluix_Admin@fluixtest.com', rol: 'admin',  nombre: 'Tester Admin'  },
  { emailLocal: 'Tester_Fluix_Staff@fluixtest.com', rol: 'staff',  nombre: 'Tester Staff'  },
];

async function main() {
  // 1. Encontrar el UID del propietario
  console.log(`\n🔍 Buscando usuario propietario: ${PROPIETARIO_EMAIL}`);
  let propietario;
  try {
    propietario = await auth.getUserByEmail(PROPIETARIO_EMAIL);
  } catch (e) {
    console.error(`❌  No se encontró ${PROPIETARIO_EMAIL} en Firebase Auth: ${e.message}`);
    process.exit(1);
  }
  console.log(`   UID propietario: ${propietario.uid}`);

  // 2. Obtener empresa_id del propietario en Firestore
  const userDoc = await db.collection('usuarios').doc(propietario.uid).get();
  if (!userDoc.exists) {
    console.error('❌  Documento de usuario no encontrado en /usuarios');
    process.exit(1);
  }
  const empresaId = userDoc.data().empresa_id;
  if (!empresaId) {
    console.error('❌  El usuario no tiene empresa_id en su documento');
    process.exit(1);
  }
  console.log(`   empresa_id: ${empresaId}`);

  // 3. Verificar que la empresa existe
  const empDoc = await db.collection('empresas').doc(empresaId).get();
  const empNombre = empDoc.exists
    ? (empDoc.data()?.perfil?.nombre ?? empDoc.data()?.nombre ?? empresaId)
    : empresaId;
  console.log(`   Empresa: ${empNombre}\n`);

  if (DRY_RUN) {
    console.log('ℹ️  Modo --dry-run. Las cuentas que se crearían son:\n');
    for (const c of CUENTAS) {
      console.log(`  📧 ${c.emailLocal}  |  rol: ${c.rol}  |  empresa: ${empresaId}`);
    }
    console.log('\nEjecuta sin --dry-run para crearlas.\n');
    process.exit(0);
  }

  // 4. Crear cada cuenta
  for (const cuenta of CUENTAS) {
    console.log(`\n👤 Creando cuenta ${cuenta.emailLocal} (${cuenta.rol})…`);

    // 4a. Crear en Firebase Auth (o actualizar si ya existe)
    let uid;
    try {
      const existing = await auth.getUserByEmail(cuenta.emailLocal);
      // Ya existe — actualizar contraseña
      await auth.updateUser(existing.uid, { password: PASSWORD, displayName: cuenta.nombre });
      uid = existing.uid;
      console.log(`   ⚠️  Ya existía en Auth → contraseña actualizada. UID: ${uid}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        const newUser = await auth.createUser({
          email:       cuenta.emailLocal,
          password:    PASSWORD,
          displayName: cuenta.nombre,
        });
        uid = newUser.uid;
        console.log(`   ✅ Creado en Auth. UID: ${uid}`);
      } else {
        throw e;
      }
    }

    // 4b. Crear/actualizar documento en /usuarios
    await db.collection('usuarios').doc(uid).set({
      uid,
      nombre:     cuenta.nombre,
      correo:     cuenta.emailLocal,
      empresa_id: empresaId,
      rol:        cuenta.rol,
      activo:     true,
      creado_en:  admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`   ✅ Documento /usuarios/${uid} guardado`);
  }

  console.log('\n✅ Cuentas creadas correctamente.');
  console.log('─────────────────────────────────────────────────');
  for (const c of CUENTAS) {
    console.log(`  Email    : ${c.emailLocal}`);
    console.log(`  Password : ${PASSWORD}`);
    console.log(`  Rol      : ${c.rol}`);
    console.log('');
  }
  process.exit(0);
}

main().catch(e => {
  console.error('❌ Error inesperado:', e.message);
  process.exit(1);
});
