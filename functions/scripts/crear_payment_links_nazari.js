/**
 * crear_payment_links_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Crea Stripe Payment Links para los libros de Nazarí que tienen stripe_price_id
 * pero no tienen payment_link todavía, y los guarda en Firestore.
 *
 * Uso:
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/crear_payment_links_nazari.js
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/crear_payment_links_nazari.js --apply
 * ─────────────────────────────────────────────────────────────────────────────
 */
'use strict';

const admin  = require('firebase-admin');
const Stripe = require('stripe');
const path   = require('path');

const APPLY     = process.argv.includes('--apply');
const NAZARI_ID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const STRIPE_KEY = process.env.STRIPE_SECRET_KEY || '';

if (!STRIPE_KEY) {
  console.error('❌  Falta STRIPE_SECRET_KEY — ejecútalo así:');
  console.error('   STRIPE_SECRET_KEY=sk_live_xxx node scripts/crear_payment_links_nazari.js --apply');
  process.exit(1);
}

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db     = admin.firestore();
const stripe = new Stripe(STRIPE_KEY, { apiVersion: '2024-06-20' });

async function main() {
  console.log(`\n🔗 Crear Payment Links Nazarí — ${APPLY ? '⚡ MODO REAL' : '👁️  DRY-RUN'}\n`);

  const snap = await db.collection('empresas').doc(NAZARI_ID).collection('catalogo_web').get();
  const sinLink = snap.docs.filter(d => {
    const data = d.data();
    const tieneLink = !!(data.payment_link || data.stripe_link);
    const tienePriceId = !!data.stripe_price_id;
    return !tieneLink && tienePriceId;
  });

  console.log(`Total libros en catálogo: ${snap.docs.length}`);
  console.log(`Sin payment_link pero con stripe_price_id: ${sinLink.length}\n`);

  if (!sinLink.length) {
    console.log('✅ No hay libros pendientes.\n');
    process.exit(0);
  }

  let creados = 0, errores = 0;

  for (const doc of sinLink) {
    const data = doc.data();
    const nombre  = data.nombre || data.titulo || doc.id;
    const priceId = data.stripe_price_id;
    const slug    = data.slug || doc.id;

    console.log(`📖  "${nombre}" (${slug}) → price: ${priceId}`);

    if (!APPLY) continue;

    try {
      const link = await stripe.paymentLinks.create({
        line_items: [{ price: priceId, quantity: 1 }],
        metadata: {
          libro_id:    slug,
          tipo:        'pedido_nazari',
          empresa_id:  NAZARI_ID,
          libro_titulo: nombre,
        },
        after_completion: {
          type: 'redirect',
          redirect: { url: 'https://editorialnazari.com/gracias-por-tu-compra' },
        },
      });

      await doc.ref.update({
        payment_link: link.url,
        stripe_link:  link.url,
        stripe_payment_link_id: link.id,
      });

      console.log(`   ✅  ${link.url}`);
      creados++;
    } catch (e) {
      console.error(`   ❌  Error: ${e.message}`);
      errores++;
    }
  }

  console.log(`\n${'─'.repeat(45)}`);
  if (!APPLY) {
    console.log(`👁️  Dry-run: ${sinLink.length} libros procesarían.`);
    console.log('   Añade --apply para crear los links en Stripe.\n');
  } else {
    console.log(`Creados: ${creados}  |  Errores: ${errores}\n`);
  }

  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
