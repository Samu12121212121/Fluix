/**
 * limpiar_inventario_hardcoded.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Busca y elimina los productos "hardcodeados" del catálogo (colección `catalogo`)
 * de Editorial Nazarí.
 *
 * Un item se considera hardcodeado si cumple TODAS estas condiciones:
 *   1. No tiene ISBN (codigo_barras vacío o ausente)
 *   2. No tiene slug (sku vacío o ausente, o atributos_extra.slug vacío)
 *   3. No tiene descripción real (descripcion vacía o genérica)
 *
 * Uso:
 *   cd functions
 *   node scripts/limpiar_inventario_hardcoded.js           ← solo diagnóstico
 *   node scripts/limpiar_inventario_hardcoded.js --borrar  ← elimina los hardcoded
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BORRAR = process.argv.includes('--borrar');

function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

function esHardcoded(d) {
  const isbn  = (d.codigo_barras || '').trim();
  const sku   = (d.sku || '').trim();
  const slug  = (d.atributos_extra?.slug || '').trim();
  const desc  = (d.descripcion || '').trim();
  const autor = (d.atributos_extra?.autor || '').trim();

  // Tiene ISBN → probablemente legítimo
  if (isbn && isbn.length >= 10) return false;
  // Tiene slug bien formado → legítimo
  if (sku && sku.includes('-')) return false;
  if (slug && slug.includes('-')) return false;
  // Tiene autor → legítimo
  if (autor) return false;
  // Descripción sustanciosa → legítimo
  if (desc && desc.length > 50) return false;

  return true; // sin ISBN, sin slug, sin autor, sin descripción → hardcodeado
}

async function run() {
  console.log('\n📦 Analizando catálogo de Nazarí...');
  const snap = await db.collection('empresas').doc(EID).collection('catalogo').get();
  console.log(`   Total: ${snap.size} productos\n`);

  const hardcoded = [];
  const legitimos = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    if (esHardcoded(d)) {
      hardcoded.push({ id: doc.id, nombre: d.nombre, isbn: d.codigo_barras, sku: d.sku });
    } else {
      legitimos.push(doc.id);
    }
  }

  console.log(`✅ Legítimos (con ISBN/slug/autor):  ${legitimos.length}`);
  console.log(`🚫 Hardcodeados (sin ISBN ni slug):  ${hardcoded.length}\n`);

  if (hardcoded.length) {
    console.log('📋 Lista de hardcodeados:');
    hardcoded.forEach((h, i) => {
      console.log(`  ${String(i + 1).padStart(3)}. [${h.id}] "${h.nombre}" | isbn:${h.isbn||'—'} sku:${h.sku||'—'}`);
    });
  }

  if (!BORRAR) {
    console.log('\n💡 Ejecuta con --borrar para eliminarlos.\n');
    process.exit(0);
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────
  if (hardcoded.length === 0) {
    console.log('\n✅ Nada que eliminar.\n');
    process.exit(0);
  }

  console.log(`\n🗑  Eliminando ${hardcoded.length} productos hardcodeados...`);
  const LOTE = 500;
  for (let i = 0; i < hardcoded.length; i += LOTE) {
    const batch = db.batch();
    hardcoded.slice(i, i + LOTE).forEach(h => {
      batch.delete(db.collection('empresas').doc(EID).collection('catalogo').doc(h.id));
    });
    await batch.commit();
    console.log(`   Lote ${Math.floor(i / LOTE) + 1}: ${Math.min(i + LOTE, hardcoded.length)} eliminados`);
  }

  console.log(`\n🎉 Listo. Catálogo queda con ${legitimos.length} productos reales.\n`);
  process.exit(0);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
