/**
 * auditar_stripe_catalogo.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Compara todos los productos Stripe con la colección catalogo_web de Firestore.
 * Identifica:
 *   - Orphans en Stripe: productos que ya no existen en catalogo_web
 *   - Sin Stripe: libros de catalogo_web que no tienen stripe_product_id
 *   - Duplicados: varios productos Stripe para el mismo catalogo_id
 *
 * Uso:
 *   cd functions
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/auditar_stripe_catalogo.js
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/auditar_stripe_catalogo.js --limpiar
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/auditar_stripe_catalogo.js --crear-faltantes
 *   STRIPE_SECRET_KEY=sk_live_xxx node scripts/auditar_stripe_catalogo.js --limpiar --crear-faltantes
 * ──────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin  = require('firebase-admin');
const Stripe = require('stripe');
const path   = require('path');

const LIMPIAR         = process.argv.includes('--limpiar');
const CREAR_FALTANTES = process.argv.includes('--crear-faltantes');
const EID             = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const STRIPE_KEY      = process.env.STRIPE_SECRET_KEY || '';

if (!STRIPE_KEY) {
  console.error('❌  Falta STRIPE_SECRET_KEY:');
  console.error('   STRIPE_SECRET_KEY=sk_live_xxx node scripts/auditar_stripe_catalogo.js');
  process.exit(1);
}

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db     = admin.firestore();
const stripe = new Stripe(STRIPE_KEY, { apiVersion: '2024-06-20' });

// ── Leer connOpts (Stripe Connect si hay stripe_account_id) ───────────────────
async function getConnOpts() {
  try {
    const snap = await db.collection('empresas').doc(EID).collection('integraciones').doc('stripe').get();
    const accountId = snap.data()?.stripe_account_id ?? '';
    return accountId ? { stripeAccount: accountId } : undefined;
  } catch (_) { return undefined; }
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const connOpts = await getConnOpts();
  console.log(`\n🔍 Auditando Stripe vs catalogo_web${LIMPIAR ? ' [--limpiar]' : ''}${CREAR_FALTANTES ? ' [--crear-faltantes]' : ''}`);
  if (connOpts) console.log(`   Stripe Connect account: ${connOpts.stripeAccount}`);
  console.log();

  // ── 1. Leer todos los productos de Stripe (auto-paginación) ─────────────
  console.log('📦 Leyendo productos de Stripe…');
  const stripeProds = [];
  let startingAfter;
  while (true) {
    const params = { limit: 100, ...(startingAfter ? { starting_after: startingAfter } : {}) };
    const page = await stripe.products.list(params, connOpts);
    stripeProds.push(...page.data);
    if (!page.has_more) break;
    startingAfter = page.data[page.data.length - 1].id;
  }
  console.log(`   Total productos en Stripe: ${stripeProds.length}\n`);

  // Agrupar por metadata.catalogo_id para detectar duplicados
  const stripeByMeta = new Map(); // catalogoId → [{ id, name, active }]
  const stripeById   = new Map(); // stripeProductId → { catalogoId, name, active }

  for (const p of stripeProds) {
    const cid = p.metadata?.catalogo_id ?? '';
    stripeById.set(p.id, { catalogoId: cid, name: p.name, active: p.active });
    if (cid) {
      if (!stripeByMeta.has(cid)) stripeByMeta.set(cid, []);
      stripeByMeta.get(cid).push({ id: p.id, name: p.name, active: p.active });
    }
  }

  // ── 2. Leer catalogo_web de Firestore ────────────────────────────────────
  console.log('📚 Leyendo catalogo_web de Firestore…');
  const catSnap = await db.collection('empresas').doc(EID).collection('catalogo_web').get();
  const catDocs = catSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  const catIds  = new Set(catDocs.map(d => d.id));
  console.log(`   Total ítems en catalogo_web: ${catDocs.length}\n`);

  // ── 3. Análisis ─────────────────────────────────────────────────────────
  const orphans   = []; // en Stripe pero no en catalogo_web (o inactivo en cat)
  const duplicates = []; // múltiples Stripe products para el mismo catalogo_id
  const sinStripe  = []; // en catalogo_web pero sin stripe_product_id

  // Orphans y duplicados en Stripe
  for (const [cid, prods] of stripeByMeta.entries()) {
    const enFirestore = catIds.has(cid);
    const catDoc = catDocs.find(d => d.id === cid);

    if (!enFirestore || (catDoc && catDoc.activo === false)) {
      for (const p of prods) {
        if (p.active) orphans.push({ ...p, catalogoId: cid, motivo: enFirestore ? 'inactivo en catalogo' : 'no existe en catalogo' });
      }
    } else if (prods.length > 1) {
      const activos = prods.filter(p => p.active);
      if (activos.length > 1) {
        // El que está guardado en Firestore es el canónico
        const canonical = catDoc?.stripe_product_id;
        const extras = activos.filter(p => p.id !== canonical);
        for (const p of extras) {
          duplicates.push({ ...p, catalogoId: cid, canonical });
        }
      }
    }
  }

  // Stripe products activos sin metadata.catalogo_id
  const sinMeta = stripeProds.filter(p => p.active && !p.metadata?.catalogo_id);

  // Sin Stripe en catalogo
  for (const doc of catDocs) {
    if (doc.activo === false) continue;
    if (!doc.stripe_product_id) {
      sinStripe.push({ id: doc.id, nombre: doc.nombre ?? doc.titulo ?? '(sin nombre)' });
    }
  }

  // ── 4. Reporte ───────────────────────────────────────────────────────────
  const divider = '─'.repeat(70);

  console.log(divider);
  console.log(`📊 RESUMEN`);
  console.log(divider);
  console.log(`   Stripe total                   : ${stripeProds.length}`);
  console.log(`   Stripe activos                 : ${stripeProds.filter(p => p.active).length}`);
  console.log(`   Stripe sin metadata.catalogo_id: ${sinMeta.length}`);
  console.log(`   Orphans (Stripe no en catálogo): ${orphans.length}`);
  console.log(`   Duplicados en Stripe           : ${duplicates.length}`);
  console.log(`   catalogo_web sin stripe_product: ${sinStripe.length}`);
  console.log();

  if (orphans.length > 0) {
    console.log(divider);
    console.log(`⚠️  ORPHANS EN STRIPE (no tienen catálogo activo)`);
    console.log(divider);
    for (const p of orphans) {
      console.log(`   ${p.active ? '🔴' : '⚫'} ${p.id.padEnd(20)} "${p.name}" [cat: ${p.catalogoId || 'sin id'}] — ${p.motivo}`);
    }
    console.log();
  }

  if (duplicates.length > 0) {
    console.log(divider);
    console.log(`⚠️  DUPLICADOS EN STRIPE`);
    console.log(divider);
    for (const p of duplicates) {
      console.log(`   🔴 ${p.id.padEnd(20)} "${p.name}" [cat: ${p.catalogoId}] — canónico: ${p.canonical || 'N/A'}`);
    }
    console.log();
  }

  if (sinMeta.length > 0) {
    console.log(divider);
    console.log(`ℹ️  STRIPE SIN METADATA (creados fuera del sistema)`);
    console.log(divider);
    for (const p of sinMeta.slice(0, 20)) {
      console.log(`   🟡 ${p.id.padEnd(20)} "${p.name}"`);
    }
    if (sinMeta.length > 20) console.log(`   … y ${sinMeta.length - 20} más`);
    console.log();
  }

  if (sinStripe.length > 0) {
    console.log(divider);
    console.log(`❌  LIBROS SIN STRIPE PRODUCT`);
    console.log(divider);
    for (const d of sinStripe.slice(0, 30)) {
      console.log(`   📚 ${d.id.padEnd(45)} "${d.nombre}"`);
    }
    if (sinStripe.length > 30) console.log(`   … y ${sinStripe.length - 30} más`);
    console.log();
  }

  // ── 5. Limpiar orphans + duplicados ──────────────────────────────────────
  if (LIMPIAR) {
    const toArchive = [...orphans, ...duplicates];
    console.log(divider);
    console.log(`🗑️  ARCHIVANDO ${toArchive.length} productos huérfanos/duplicados en Stripe…`);
    console.log(divider);
    let archivados = 0, errores = 0;
    for (const p of toArchive) {
      if (!p.active) { console.log(`   ⏭️  ${p.id} ya está inactivo`); continue; }
      try {
        await sleep(100);
        await stripe.products.update(p.id, { active: false }, connOpts);
        console.log(`   ✅ Archivado: ${p.id} "${p.name}"`);
        archivados++;
      } catch (e) {
        console.log(`   ❌ Error: ${p.id}: ${e.message}`);
        errores++;
      }
    }
    console.log(`\n   Archivados: ${archivados}  |  Errores: ${errores}\n`);
  }

  // ── 6. Crear productos faltantes ─────────────────────────────────────────
  if (CREAR_FALTANTES && sinStripe.length > 0) {
    console.log(divider);
    console.log(`✨  CREANDO ${sinStripe.length} productos en Stripe para libros sin stripe_product_id…`);
    console.log(divider);

    const col = db.collection('empresas').doc(EID).collection('catalogo_web');
    let creados = 0, errores = 0;

    for (const item of sinStripe) {
      const docSnap = await col.doc(item.id).get();
      if (!docSnap.exists) continue;
      const d = docSnap.data();

      const titulo = d.nombre ?? d.titulo ?? 'Libro';
      const autor  = d.campo_autor ?? d.autor ?? '';
      const desc   = d.descripcion ?? '';
      const isbn   = d.campo_isbn ?? d.isbn ?? '';
      const imagen = d.imagen_url ?? '';
      const precio = Math.round(parseFloat((d.precio || '0').replace(',', '.').replace(/[^0-9.]/g, '')) * 100);

      try {
        await sleep(200);
        const prod = await stripe.products.create({
          name:        titulo,
          description: desc ? desc.slice(0, 500) : undefined,
          images:      imagen && imagen.startsWith('https://') ? [encodeURI(imagen)] : undefined,
          metadata:    { catalogo_id: item.id, empresa_id: EID, autor, isbn },
        }, connOpts);

        let priceId = '';
        if (precio > 0) {
          const price = await stripe.prices.create(
            { product: prod.id, unit_amount: precio, currency: 'eur' },
            connOpts
          );
          priceId = price.id;
        }

        await col.doc(item.id).update({
          stripe_product_id: prod.id,
          ...(priceId ? { stripe_price_id: priceId } : {}),
          stripe_sync_ts: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`   ✅ "${titulo}" → ${prod.id}${priceId ? ` | ${priceId}` : ''}`);
        creados++;
      } catch (e) {
        console.log(`   ❌ "${titulo}": ${e.message}`);
        errores++;
      }
    }
    console.log(`\n   Creados: ${creados}  |  Errores: ${errores}\n`);
  }

  console.log(divider);
  if (!LIMPIAR && !CREAR_FALTANTES) {
    console.log('ℹ️  Ejecuta con --limpiar para archivar orphans/duplicados en Stripe.');
    console.log('ℹ️  Ejecuta con --crear-faltantes para crear productos para libros sin stripe_product_id.');
    console.log('ℹ️  Puedes combinar: --limpiar --crear-faltantes');
  }
  console.log();
  process.exit(0);
}

main().catch(e => { console.error('\n❌', e.message || e); process.exit(1); });
