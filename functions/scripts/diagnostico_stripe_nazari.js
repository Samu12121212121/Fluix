/**
 * diagnostico_stripe_nazari.js
 * Muestra el estado Stripe de los libros de Nazarí y la integración Connect.
 *
 * Uso:
 *   cd functions
 *   node scripts/diagnostico_stripe_nazari.js
 */
'use strict';

const admin = require('firebase-admin');
const path  = require('path');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

async function main() {
  // 1. Integración Stripe Connect
  console.log('\n── INTEGRACIÓN STRIPE CONNECT ──────────────────────────');
  const integ = await db.collection('empresas').doc(EID).collection('integraciones').doc('stripe').get();
  if (!integ.exists) {
    console.log('❌  No existe empresas/NAZARI/integraciones/stripe');
  } else {
    const d = integ.data();
    console.log(`  connected        : ${d.connected}`);
    console.log(`  stripe_account_id: ${d.stripe_account_id ?? '(vacío)'}`);
    console.log(`  activo           : ${d.activo}`);
    if (d.scope)       console.log(`  scope            : ${d.scope}`);
    if (d.livemode !== undefined) console.log(`  livemode         : ${d.livemode}`);
  }

  // 2. Libros
  console.log('\n── LIBROS (primeros 10) ─────────────────────────────────');
  const snap = await db.collection('empresas').doc(EID).collection('libros')
    .orderBy('titulo').limit(10).get();

  if (snap.empty) {
    console.log('  (sin libros)');
  } else {
    for (const doc of snap.docs) {
      const b = doc.data();
      const live = b.stripe_product_id  ? '✅' : '❌';
      const test = b.stripe_product_id_test ? '✅' : '❌';
      const link = b.payment_link      ? '🔗' : '  ';
      const linkT = b.payment_link_test ? '🔗' : '  ';
      console.log(`\n  ID      : ${doc.id}`);
      console.log(`  Título  : ${b.titulo ?? '(sin título)'}`);
      console.log(`  Precio  : ${b.precio ?? '—'}  |  Activo: ${b.activo}`);
      console.log(`  LIVE    : ${live} product=${b.stripe_product_id ?? '—'}  price=${b.stripe_price_id ?? '—'}  ${link}link=${b.payment_link ?? '—'}`);
      console.log(`  TEST    : ${test} product=${b.stripe_product_id_test ?? '—'}  price=${b.stripe_price_id_test ?? '—'}  ${linkT}link=${b.payment_link_test ?? '—'}`);
    }
  }

  console.log('\n────────────────────────────────────────────────────────');
  console.log(`Total libros: ${snap.size} (mostrando máx 10)\n`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
