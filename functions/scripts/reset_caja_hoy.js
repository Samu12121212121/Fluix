/**
 * Borra la apertura y el cierre de caja de HOY para la empresa demo.
 * Uso: node functions/scripts/reset_caja_hoy.js
 */
const admin = require('firebase-admin');

const EMPRESA_ID = 'demo_empresa_fluix2026';

admin.initializeApp({ projectId: 'planeaapp-4bea4' });
const db = admin.firestore();

async function main() {
  const hoy = new Date();
  const yyyy = hoy.getFullYear();
  const mm   = String(hoy.getMonth() + 1).padStart(2, '0');
  const dd   = String(hoy.getDate()).padStart(2, '0');
  const fechaStr = `${yyyy}-${mm}-${dd}`;

  const inicio = new Date(yyyy, hoy.getMonth(), hoy.getDate(), 0, 0, 0);
  const fin    = new Date(yyyy, hoy.getMonth(), hoy.getDate() + 1, 0, 0, 0);

  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  // ── Borrar cierre de hoy ────────────────────────────────────────────────────
  const cierreRef = empresaRef.collection('cierres_caja').doc(fechaStr);
  const cierreSnap = await cierreRef.get();
  if (cierreSnap.exists) {
    await cierreRef.delete();
    console.log(`✅ Cierre de caja ${fechaStr} eliminado`);
  } else {
    console.log(`ℹ️  No había cierre para ${fechaStr}`);
  }

  // ── Borrar aperturas de hoy ─────────────────────────────────────────────────
  const aperturasSnap = await empresaRef.collection('aperturas_caja')
    .where('fecha', '>=', admin.firestore.Timestamp.fromDate(inicio))
    .where('fecha', '<',  admin.firestore.Timestamp.fromDate(fin))
    .get();

  if (aperturasSnap.empty) {
    console.log(`ℹ️  No había aperturas para ${fechaStr}`);
  } else {
    for (const doc of aperturasSnap.docs) {
      await doc.ref.delete();
    }
    console.log(`✅ ${aperturasSnap.size} apertura(s) de ${fechaStr} eliminada(s)`);
  }

  console.log('\n🎬 Listo para grabar el vídeo. Apertura y cierre de caja a cero.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
