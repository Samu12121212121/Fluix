/**
 * cambiar_password_empresa.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Busca el propietario de una empresa en Firestore y cambia su contraseña
 * de Firebase Auth directamente, sin necesidad de acceso al email.
 *
 * Uso:
 *   cd functions
 *   node scripts/cambiar_password_empresa.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --password=NuevaClave123
 *   node scripts/cambiar_password_empresa.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --solo-info
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');

const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => { const [k, ...v] = a.slice(2).split('='); return [k, v.join('=') || true]; })
);

const EID       = args['empresa'];
const PASSWORD  = args['password'];
const SOLO_INFO = args['solo-info'] === true || args['solo-info'] === 'true';

if (!EID) {
  console.error('❌  Falta --empresa=<empresaId>');
  process.exit(1);
}
if (!SOLO_INFO && !PASSWORD) {
  console.error('❌  Indica --password=<nueva> o --solo-info para solo ver el usuario');
  process.exit(1);
}
if (PASSWORD && PASSWORD.length < 6) {
  console.error('❌  La contraseña debe tener al menos 6 caracteres');
  process.exit(1);
}

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function main() {
  // 1. Leer el documento de la empresa para obtener el propietario_id
  console.log(`\n🔍 Buscando propietario de empresa ${EID}…`);
  const empSnap = await db.collection('empresas').doc(EID).get();
  if (!empSnap.exists) {
    console.error('❌  Empresa no encontrada en Firestore');
    process.exit(1);
  }
  const emp = empSnap.data();

  // El campo puede llamarse propietario_id, owner_id, uid, userId...
  const uid = emp.propietario_id ?? emp.owner_id ?? emp.uid ?? emp.userId ?? emp.propietarioId;
  const nombreEmpresa = emp.nombre ?? emp.name ?? EID;

  if (!uid) {
    // Si no hay UID en el doc, buscar en la subcolección usuarios o en /usuarios global
    console.log('   UID no encontrado en el documento principal, buscando en /usuarios…');
    const usuariosSnap = await db.collection('usuarios')
        .where('empresa_id', '==', EID)
        .where('rol', 'in', ['propietario', 'admin', 'owner'])
        .limit(1)
        .get();

    if (usuariosSnap.empty) {
      console.error('❌  No se encontró ningún usuario propietario para esta empresa.');
      console.error('   Campos disponibles en el doc empresa:', Object.keys(emp).join(', '));
      process.exit(1);
    }

    const userDoc = usuariosSnap.docs[0];
    const foundUid = userDoc.id;
    await procesarUid(foundUid, nombreEmpresa);
  } else {
    await procesarUid(uid, nombreEmpresa);
  }
}

async function procesarUid(uid, nombreEmpresa) {
  // 2. Obtener el usuario de Firebase Auth
  let userRecord;
  try {
    userRecord = await admin.auth().getUser(uid);
  } catch (e) {
    console.error(`❌  UID "${uid}" no existe en Firebase Auth: ${e.message}`);
    process.exit(1);
  }

  console.log('\n👤 Usuario encontrado:');
  console.log(`   UID      : ${userRecord.uid}`);
  console.log(`   Email    : ${userRecord.email ?? '(sin email)'}`);
  console.log(`   Nombre   : ${userRecord.displayName ?? '(sin nombre)'}`);
  console.log(`   Empresa  : ${nombreEmpresa}`);
  console.log(`   Creado   : ${userRecord.metadata.creationTime}`);
  console.log(`   Último login: ${userRecord.metadata.lastSignInTime ?? 'nunca'}`);

  if (SOLO_INFO) {
    console.log('\nℹ️  Modo --solo-info. No se ha cambiado nada.\n');
    process.exit(0);
  }

  // 3. Cambiar la contraseña
  console.log(`\n🔑 Cambiando contraseña…`);
  await admin.auth().updateUser(uid, { password: PASSWORD });
  console.log(`✅ Contraseña actualizada.`);
  console.log(`\n   Puedes iniciar sesión con:`);
  console.log(`   Email    : ${userRecord.email}`);
  console.log(`   Password : ${PASSWORD}\n`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
