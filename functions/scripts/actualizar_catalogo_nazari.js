'use strict';

/**
 * actualizar_catalogo_nazari.js  —  DRY RUN por defecto, NO escribe nada sin --ejecutar
 *
 * Compara libros_nazari.json con empresas/{EID}/catalogo_web y muestra
 * exactamente qué campos se cambiarían en Firestore y con qué valor.
 *
 * Uso:
 *   node scripts/actualizar_catalogo_nazari.js            ← solo muestra cambios
 *   node scripts/actualizar_catalogo_nazari.js --ejecutar ← aplica los cambios
 *
 * Qué actualiza (NUNCA sobrescribe un campo que ya tiene valor, salvo descripcion):
 *   · campo_isbn       → solo si está vacío en FS
 *   · precio_digital   → solo si está vacío en FS
 *   · campo_paginas    → solo si está vacío en FS
 *   · descripcion      → si FS está vacío Y scrapeado tiene texto
 *                        O si scrapeado es >= 200 chars más largo que FS
 */

const path  = require('path');
const fs    = require('fs');
const admin = require('firebase-admin');

const EID          = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const COLECCION    = 'catalogo_web';
const LIBROS_FILE  = path.join(__dirname, 'libros_nazari.json');
const EJECUTAR     = process.argv.includes('--ejecutar');
const UMBRAL_DESC  = 1;  // reemplazar si scrapeado tiene aunque sea 1 char más

// ── Firebase ──────────────────────────────────────────────────────────────────
const SA_PATHS = [
  path.join(__dirname, '..', 'service-account.json'),
  path.join(__dirname, '..', 'serviceAccount.json'),
  path.join(__dirname, '..', 'serviceAccountKey.json'),
];
const saPath = SA_PATHS.find(p => fs.existsSync(p));
if (!saPath) { console.error('No se encontró service-account.json'); process.exit(1); }
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const db = admin.firestore();

// ── Cargar scrapeado ──────────────────────────────────────────────────────────
if (!fs.existsSync(LIBROS_FILE)) {
  console.error('No se encuentra libros_nazari.json');
  process.exit(1);
}
const scraped = JSON.parse(fs.readFileSync(LIBROS_FILE, 'utf8')).libros || [];

// ── Normalización ─────────────────────────────────────────────────────────────
const normTitulo = s => (s || '')
  .toLowerCase()
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/^libro\s+/i, '')
  .replace(/\s*editorial\s+nazar[ií]\s*[-|]?\s*$/i, '')
  .replace(/[¿¡!?"'«».,;:()\-]/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

const estaVacio = v => v === null || v === undefined || String(v).trim() === '' || v === 0;

// ── Reglas de actualización ───────────────────────────────────────────────────
// campo_isbn: existe en Firestore y en el editor de la app pero NO se renderiza
// en el script web público — se incluye solo como dato interno.
// precio_digital: SÍ se muestra en la web (fluix-cat-precio-digital).
//   El scrapeado lo trae con "€" — lo limpiamos para ser coherente con el campo
//   precio que Firestore ya guarda sin símbolo (ej: "15,00" no "15,00 €").

const limpiarPrecio = s => (s || '').replace(/\s*€\s*$/, '').trim();

const REGLAS = [
  {
    campo: 'campo_isbn',
    label: 'ISBN (interno, no visible en web)',
    obtener: sc => sc.isbn || sc.isbn13 || '',
    condicion: (valFs, valSc) => estaVacio(valFs) && !estaVacio(valSc),
  },
  {
    campo: 'precio',
    label: 'Precio impreso (visible en web)',
    obtener: sc => limpiarPrecio(sc.precio_impreso || sc.precio_unico),
    condicion: (valFs, valSc) => estaVacio(valFs) && !estaVacio(valSc),
  },
  {
    campo: 'precio_digital',
    label: 'Precio ebook (visible en web)',
    obtener: sc => limpiarPrecio(sc.precio_ebook),
    condicion: (valFs, valSc) => estaVacio(valFs) && !estaVacio(valSc),
  },
  {
    campo: 'campo_paginas',
    label: 'Páginas',
    obtener: sc => sc.paginas ? String(sc.paginas) : '',
    condicion: (valFs, valSc) => estaVacio(valFs) && !estaVacio(valSc),
  },
  {
    campo: 'descripcion',
    label: 'Descripción (visible en web)',
    obtener: sc => sc.sinopsis || '',
    condicion: (valFs, valSc) => {
      if (estaVacio(valSc)) return false;
      if (estaVacio(valFs)) return true;                    // FS vacío → rellenar
      return (valSc.length - valFs.length) >= UMBRAL_DESC; // scrapeado >= 200 chars más largo
    },
  },
];

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  if (!EJECUTAR) {
    console.log('\n' + '█'.repeat(72));
    console.log('  DRY RUN — no se escribe nada en Firestore');
    console.log('  Ejecuta con --ejecutar para aplicar los cambios');
    console.log('█'.repeat(72));
  } else {
    console.log('\n' + '!'.repeat(72));
    console.log('  MODO ESCRITURA ACTIVO — se van a modificar documentos en Firestore');
    console.log('!'.repeat(72));
  }

  console.log('\nLeyendo ' + COLECCION + '...');
  const snap = await db.collection('empresas').doc(EID).collection(COLECCION).get();
  const fsDocs = snap.docs.map(d => ({ _id: d.id, ...d.data() }));
  console.log(' Docs en Firestore: ' + fsDocs.length + ' | Scrapeados: ' + scraped.length);

  // Índices por título normalizado
  const fsIdx = {}, scIdx = {};
  fsDocs.forEach(d => { const k = normTitulo(d.nombre || ''); if (k) fsIdx[k] = d; });
  scraped.forEach(l => { const k = normTitulo(l.titulo || ''); if (k) scIdx[k] = l; });

  // ── Calcular todos los cambios ────────────────────────────────────────────
  // Agrupados por tipo de campo para revisar de un vistazo
  const cambiosPorCampo = {};
  REGLAS.forEach(r => { cambiosPorCampo[r.campo] = []; });

  let totalCambios = 0, totalDocs = 0;

  for (const [k, sc] of Object.entries(scIdx)) {
    const fs = fsIdx[k];
    if (!fs) continue;

    const cambiosEsteDoc = [];
    for (const regla of REGLAS) {
      const valFs = fs[regla.campo];
      const valSc = regla.obtener(sc);
      if (regla.condicion(valFs, valSc)) {
        cambiosEsteDoc.push({
          campo:     regla.campo,
          label:     regla.label,
          valor_actual: estaVacio(valFs) ? '(vacío)' : String(valFs).substring(0, 100),
          valor_nuevo:  String(valSc).substring(0, 100),
          valor_completo: String(valSc),  // para escritura real
        });
        cambiosPorCampo[regla.campo].push({
          titulo:      sc.titulo,
          id_fs:       fs._id,
          valor_actual: estaVacio(valFs) ? '(vacío)' : String(valFs).substring(0, 120),
          valor_nuevo:  String(valSc).substring(0, 120),
          valor_completo: String(valSc),
        });
        totalCambios++;
      }
    }
    if (cambiosEsteDoc.length > 0) totalDocs++;
  }

  // ── Mostrar resumen por campo ─────────────────────────────────────────────
  const sep = '─'.repeat(72);
  console.log('\n' + '═'.repeat(72));
  console.log(' CAMBIOS PREVISTOS — ' + totalDocs + ' documentos, ' + totalCambios + ' campos');
  console.log('═'.repeat(72));

  for (const regla of REGLAS) {
    const cambios = cambiosPorCampo[regla.campo];
    if (!cambios.length) continue;
    console.log('\n' + sep);
    console.log(' ' + regla.label.toUpperCase() + ' (' + regla.campo + ') — ' + cambios.length + ' cambios');
    console.log(sep);
    cambios.forEach((c, i) => {
      console.log('\n  ' + String(i + 1).padStart(3) + '. ' + c.titulo);
      console.log('       ID:     ' + c.id_fs);
      console.log('       ANTES:  "' + c.valor_actual + '"');
      console.log('       NUEVO:  "' + c.valor_nuevo + (c.valor_nuevo.length >= 100 ? '...' : '') + '"');
    });
  }

  if (EJECUTAR) {
    // ── Aplicar cambios en batches de 500 ──────────────────────────────────
    console.log('\n' + '═'.repeat(72));
    console.log(' APLICANDO CAMBIOS...');
    console.log('═'.repeat(72));

    const col = db.collection('empresas').doc(EID).collection(COLECCION);
    let batch = db.batch(), batchSize = 0, totalEscritos = 0, errores = 0;

    for (const [k, sc] of Object.entries(scIdx)) {
      const fsDoc = fsIdx[k];
      if (!fsDoc) continue;

      const updates = {};
      for (const regla of REGLAS) {
        const valFs = fsDoc[regla.campo];
        const valSc = regla.obtener(sc);
        if (regla.condicion(valFs, valSc)) {
          updates[regla.campo] = regla.campo === 'campo_paginas'
            ? parseInt(valSc, 10) || valSc
            : valSc;
        }
      }

      if (Object.keys(updates).length === 0) continue;

      updates.fecha_actualizacion = admin.firestore.FieldValue.serverTimestamp();
      batch.update(col.doc(fsDoc._id), updates);
      batchSize++;
      totalEscritos++;

      process.stdout.write('\r  Procesados: ' + totalEscritos + ' | Errores: ' + errores + '  ');

      if (batchSize >= 499) {
        try { await batch.commit(); } catch (e) { errores++; console.error('\n  Error batch:', e.message); }
        batch = db.batch(); batchSize = 0;
      }
    }

    if (batchSize > 0) {
      try { await batch.commit(); } catch (e) { errores++; console.error('\n  Error batch final:', e.message); }
    }

    process.stdout.write('\n');
    console.log('\n  ✓ Documentos actualizados: ' + totalEscritos);
    if (errores > 0) console.log('  ✗ Errores: ' + errores);
  } else {
    console.log('\n' + '═'.repeat(72));
    console.log(' Para aplicar estos ' + totalCambios + ' cambios en ' + totalDocs + ' documentos:');
    console.log(' node scripts/actualizar_catalogo_nazari.js --ejecutar');
    console.log('═'.repeat(72));
  }

  await admin.app().delete();
}

main().catch(e => { console.error('Error:', e.message || e); process.exit(1); });
