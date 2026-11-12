/**
 * desactivar_2fa_elena.js — Desactiva el 2FA de Elena para pruebas
 * Uso (desde functions/):
 *   node scripts/desactivar_2fa_elena.js
 */
const admin = require('firebase-admin');
const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });

const UID = 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2';

admin.firestore()
  .collection('usuarios').doc(UID)
  .update({ dos_factores_activo: false })
  .then(() => {
    console.log('✅ 2FA desactivado para Elena Martín Sanz');
    console.log('   Ya puedes iniciar sesión con:');
    console.log('   Email:    elena.martin@fluixtest.com');
    console.log('   Password: ElenaTES2026');
    process.exit(0);
  })
  .catch(e => { console.error('❌', e.message); process.exit(1); });
