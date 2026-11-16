/**
 * check_elena_2fa.js — Comprueba y actualiza el teléfono 2FA de un usuario.
 * Uso:
 *   node functions/scripts/check_elena_2fa.js              ← ver datos
 *   node functions/scripts/check_elena_2fa.js --actualizar ← cambia el teléfono a +34684287980
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db   = admin.firestore();
const auth = admin.auth();

const EMAIL_ELENA = 'elena.martin@fluixtest.com';
const NUEVO_TEL   = '+34684287980';
const ACTUALIZAR  = process.argv.includes('--actualizar');

async function main() {
  // Buscar usuario por email en Firebase Auth
  const userRecord = await auth.getUserByEmail(EMAIL_ELENA);
  console.log(`\n👤 ${EMAIL_ELENA}`);
  console.log(`   UID: ${userRecord.uid}`);
  console.log(`   Creado: ${userRecord.metadata.creationTime}`);
  console.log(`   Teléfono Auth: ${userRecord.phoneNumber || '(ninguno)'}`);

  // Leer documento Firestore
  const doc = await db.collection('usuarios').doc(userRecord.uid).get();
  const data = doc.data() || {};
  console.log(`\n📄 Firestore usuarios/${userRecord.uid}`);
  console.log(`   dos_factores_activo:   ${data.dos_factores_activo ?? '(no definido)'}`);
  console.log(`   dos_factores_telefono: ${data.dos_factores_telefono || '(vacío)'}`);
  console.log(`   empresa_id:            ${data.empresa_id || '(sin empresa)'}`);
  console.log(`   nombre:                ${data.nombre || '(sin nombre)'}`);

  if (ACTUALIZAR) {
    await db.collection('usuarios').doc(userRecord.uid).update({
      dos_factores_activo: true,
      dos_factores_telefono: NUEVO_TEL,
    });
    console.log(`\n✅ Actualizado → dos_factores_telefono: ${NUEVO_TEL}\n`);
  } else {
    console.log(`\n💡 Para cambiar el teléfono 2FA a ${NUEVO_TEL}:`);
    console.log(`   node functions/scripts/check_elena_2fa.js --actualizar\n`);
  }
}

main().catch(e => { console.error(e); process.exit(1); });
