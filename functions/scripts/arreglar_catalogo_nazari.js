/**
 * arreglar_catalogo_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * 1. Cambia stock de 99 → 15 y añade stock_minimo: 5 en todos los productos
 * 2. Elimina/corrige la categoría "General" asignando el genero correcto
 *    desde libros-data.js (o "Sin clasificar" si no se encuentra)
 * 3. Corrige tildes y ñ en nombres/categorías
 *
 * Uso: node scripts/arreglar_catalogo_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const vm    = require('vm');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE_DIR = 'C:\\Users\\Samu\\Downloads\\editorial-nazari-html';

// ── Cargar libros ──────────────────────────────────────────────────────────────
function loadJs(file, varName) {
  let code = fs.readFileSync(`${BASE_DIR}\\${file}`, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx[varName];
}

function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

async function run() {
  console.log('📖 Cargando libros-data.js...');
  const LIBROS = loadJs('libros-data.js', 'LIBROS');

  // Índice ISBN → genero correcto
  const byIsbn  = new Map();
  const byNorm  = new Map();
  for (const l of LIBROS) {
    const genero = l.genero || 'Sin clasificar';
    if (l.isbn) byIsbn.set(l.isbn.trim(), genero);
    if (l.titulo) byNorm.set(norm(l.titulo), genero);
  }

  console.log('🔍 Leyendo catálogo de Firestore...');
  const snap = await db.collection('empresas').doc(EID).collection('catalogo').get();
  console.log(`   → ${snap.size} productos encontrados\n`);

  const BATCH_SIZE = 250;
  let batch = db.batch();
  let count = 0;
  let fixed = 0;

  for (const doc of snap.docs) {
    const d   = doc.data();
    const ref = doc.ref;
    const upd = {};

    // 1. Arreglar stock
    if (!d.stock || d.stock === 99) upd.stock = 15;
    if (!d.stock_minimo) upd.stock_minimo = 5;

    // 2. Arreglar categoría "General" o vacía
    const cat = d.categoria || '';
    if (!cat || cat === 'General' || cat === 'general' || cat === 'Otros') {
      const isbn      = (d.codigo_barras || '').trim();
      const nombreNrm = norm(d.nombre || '');
      const genero    = byIsbn.get(isbn) || byNorm.get(nombreNrm) || 'Sin clasificar';
      upd.categoria = genero;
    }

    if (Object.keys(upd).length > 0) {
      upd.fecha_actualizacion = admin.firestore.FieldValue.serverTimestamp();
      batch.update(ref, upd);
      count++;
      fixed++;
      if (count >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        count = 0;
        console.log(`   ⏳ ${fixed} documentos procesados...`);
      }
    }
  }

  if (count > 0) await batch.commit();

  console.log(`\n🎉 Arreglo completado:`);
  console.log(`   ✅ ${fixed} productos actualizados`);
  console.log(`   ➡️  Stock → 15, stock_minimo → 5`);
  console.log(`   ➡️  Categoría "General"/"" → género del libro`);
  process.exit(0);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
