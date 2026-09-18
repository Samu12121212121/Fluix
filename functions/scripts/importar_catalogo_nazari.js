/**
 * importar_catalogo_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Importa (o actualiza) todos los libros de Editorial Nazarí en la colección
 * `catalogo` de Firestore, para que estén disponibles en Pedidos y TPV.
 *
 * Comportamiento:
 *  - Si existe un producto con el mismo ISBN → actualiza (corrige tildes, añade categoría)
 *  - Si no existe → crea uno nuevo
 *  - IVA libros España: 4 %
 *  - Se usa el genero del JS como `categoria`
 *
 * Uso:
 *   cd functions
 *   node scripts/importar_catalogo_nazari.js
 *
 * Para solo actualizar existentes (no crear nuevos):
 *   node scripts/importar_catalogo_nazari.js --solo-actualizar
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const vm    = require('vm');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE_IMG = 'https://seashell-boar-580681.hostingersite.com';
const BASE_DIR = 'C:\\Users\\Samu\\Downloads\\editorial-nazari-html';
const SOLO_ACTUALIZAR = process.argv.includes('--solo-actualizar');

// ── Cargar el JS con vm (soporta const y let) ─────────────────────────────────
function loadJs(file, varName) {
  let code = fs.readFileSync(`${BASE_DIR}\\${file}`, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx[varName];
}

// ── Parsear precio "14,00 €" → 14.00 ─────────────────────────────────────────
function parsePrecio(str) {
  if (!str) return 0;
  return parseFloat(str.replace(/[€\s]/g, '').replace(',', '.')) || 0;
}

// ── Normalizar texto para comparación (quita tildes y pasa a minúsculas) ─────
function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .trim();
}

// ── Construir el documento de catálogo a partir de un libro del JS ───────────
function libroBuildDoc(libro) {
  const precio = parsePrecio(libro.precio);
  const etiquetas = [];
  if (libro.tag) etiquetas.push(libro.tag);

  return {
    empresa_id:      EID,
    nombre:          libro.titulo  || '',
    descripcion:     libro.sinopsis || '',
    categoria:       libro.genero  || 'Otros',
    precio,
    imagen_url:      libro.imagen ? `${BASE_IMG}/${libro.imagen}` : '',
    thumbnail_url:   libro.imagen ? `${BASE_IMG}/${libro.imagen}` : '',
    stock:           15,
    stock_minimo:    5,
    activo:          true,
    destacado:       false,
    tiene_variantes: false,
    duracion_minutos: null,
    iva_porcentaje:  4,     // libros: IVA reducido 4 %
    sku:             libro.slug   || '',
    codigo_barras:   libro.isbn   || '',
    variantes:       [],
    etiquetas,
    alergenos:       [],
    tipo:            'producto',
    atributos_extra: {
      autor:       libro.autor     || '',
      autor_extra: libro.autorExtra || '',
      coleccion:   libro.coleccion || '',
      paginas:     libro.paginas   || 0,
      formato:     libro.formato   || '',
      dimensiones: libro.dimensiones || '',
      anio:        libro.anio      || 0,
      mes:         libro.mes       || '',
      isbn:        libro.isbn      || '',
      slug:        libro.slug      || '',
    },
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function run() {
  console.log('📚 Cargando libros-data.js...');
  const LIBROS = loadJs('libros-data.js', 'LIBROS');
  console.log(`   → ${LIBROS.length} libros encontrados\n`);

  // Cargar catálogo existente (para detectar duplicados por ISBN o nombre)
  console.log('🔍 Leyendo catálogo actual de Firestore...');
  const snap = await db.collection('empresas').doc(EID).collection('catalogo').get();

  // Índices para búsqueda rápida
  const byIsbn  = new Map(); // isbn  → docId
  const byNorm  = new Map(); // norm(nombre) → docId
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.codigo_barras) byIsbn.set(d.codigo_barras.trim(), doc.id);
    const n = norm(d.nombre);
    if (n) byNorm.set(n, doc.id);
  }
  console.log(`   → ${snap.size} productos en catálogo\n`);

  const col = db.collection('empresas').doc(EID).collection('catalogo');

  let creados   = 0;
  let actualizados = 0;
  let saltados  = 0;

  // Lotes de 250 (límite Firestore: 500, usamos 250 para margen)
  const BATCH_SIZE = 250;
  let   batch      = db.batch();
  let   batchCount = 0;

  async function flush() {
    if (batchCount > 0) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  for (const libro of LIBROS) {
    if (!libro.slug && !libro.titulo) { saltados++; continue; }

    const doc   = libroBuildDoc(libro);
    const isbn  = libro.isbn?.trim();
    const nNorm = norm(libro.titulo);

    // ── Buscar documento existente ──────────────────────────────────────────
    let existingId = null;
    if (isbn && byIsbn.has(isbn))   existingId = byIsbn.get(isbn);
    else if (byNorm.has(nNorm))     existingId = byNorm.get(nNorm);

    if (existingId) {
      // Actualizar existente (corrige encoding + añade categoria, atributos)
      batch.set(col.doc(existingId), {
        ...doc,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      actualizados++;
    } else if (!SOLO_ACTUALIZAR) {
      // Crear nuevo
      const ref = col.doc();
      batch.set(ref, {
        ...doc,
        fecha_creacion:      admin.firestore.FieldValue.serverTimestamp(),
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      });
      // Registrar en índices para libros posteriores del mismo batch
      if (isbn)  byIsbn.set(isbn,  ref.id);
      if (nNorm) byNorm.set(nNorm, ref.id);
      creados++;
    } else {
      saltados++;
    }

    batchCount++;
    if (batchCount >= BATCH_SIZE) {
      await flush();
      console.log(`   ⏳ Lote procesado (${creados + actualizados} hasta ahora)`);
    }
  }

  await flush();

  console.log('\n🎉 Importación completada:');
  console.log(`   ✅ Creados:     ${creados}`);
  console.log(`   🔄 Actualizados: ${actualizados}`);
  console.log(`   ⏭  Saltados:    ${saltados}`);
  process.exit(0);
}

run().catch(e => {
  console.error('❌ Error:', e.message);
  console.error(e.stack);
  process.exit(1);
});
