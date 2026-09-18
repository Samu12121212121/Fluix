/**
 * actualizar_email_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Actualiza el email de notificaciones de Editorial Nazarí a
 * info@editorialnazari.com en el documento de la empresa.
 *
 * Uso: node scripts/actualizar_email_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const NAZARI_ID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const NUEVO_EMAIL  = 'info@editorialnazari.com';

async function run() {
  const ref = db.collection('empresas').doc(NAZARI_ID);
  const doc = await ref.get();

  if (!doc.exists) {
    console.error('❌ No se encontró la empresa con ID:', NAZARI_ID);
    process.exit(1);
  }

  const actual = doc.data();
  console.log('Empresa:', actual.nombre || '(sin nombre)');
  console.log('Email anterior: email_notificaciones =', actual.email_notificaciones || '(vacío)',
              '| correo =', actual.correo || '(vacío)',
              '| email =', actual.email || '(vacío)');

  await ref.update({
    email_notificaciones: NUEVO_EMAIL,
    correo:               NUEVO_EMAIL,
    email:                NUEVO_EMAIL,
    fecha_actualizacion:  admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('✅ Email actualizado a:', NUEVO_EMAIL);
}

run().catch(e => { console.error('❌', e); process.exit(1); });
