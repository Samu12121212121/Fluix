'use strict';

/**
 * comparar_catalogo_nazari.js  —  Solo lectura, no modifica nada
 *
 * Compara los títulos de libros_nazari.json (scrapeado) con los documentos
 * de Firestore en empresas/EID/catalogo y muestra qué campos están vacíos
 * en Firestore pero tienen valor en el JSON scrapeado.
 *
 * Uso: node scripts/comparar_catalogo_nazari.js [--json]
 */

const path  = require('path');
const fs    = require('fs');
const admin = require('firebase-admin');

const EID          = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const COLECCION    = 'catalogo_web';   // empresas/{EID}/catalogo_web
const LIBROS_FILE  = path.join(__dirname, 'libros_nazari.json');
const GUARDAR_JSON = process.argv.includes('--json');

// ── Firebase ──────────────────────────────────────────────────────────────────
const SA_PATHS = [
  path.join(__dirname, '..', 'service-account.json'),
  path.join(__dirname, '..', 'serviceAccount.json'),
  path.join(__dirname, '..', 'serviceAccountKey.json'),
];
const saPath = SA_PATHS.find(p => fs.existsSync(p));
if (!saPath) { console.error('No se encontró service-account.json en functions/'); process.exit(1); }

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
}
const db = admin.firestore();

// ── Cargar JSON scrapeado ─────────────────────────────────────────────────────
if (!fs.existsSync(LIBROS_FILE)) {
  console.error('No se encuentra libros_nazari.json — ejecuta primero extraer_campos_nazari.js');
  process.exit(1);
}
const scraped = JSON.parse(fs.readFileSync(LIBROS_FILE, 'utf8')).libros || [];

// ── Normalización de título para comparar ─────────────────────────────────────
const normTitulo = s => (s || '')
  .toLowerCase()
  .normalize('NFD').replace(/[̀-ͯ]/g, '')   // quitar tildes
  .replace(/^libro\s+/i, '')                 // quitar prefijo "Libro " de Firestore
  .replace(/\s*editorial\s+nazar[ií]\s*[-|]?\s*$/i, '')  // quitar sufijo editorial
  .replace(/[¿¡!?"'«».,;:()\-]/g, ' ')      // puntuación → espacio
  .replace(/\s+/g, ' ')
  .trim();

// ── Campos a comparar ─────────────────────────────────────────────────────────
// Cada entrada: campo en el doc de Firestore → función que extrae el valor del scrapeado
// Si el campo de Firestore está vacío Y el scrapeado tiene valor → discrepancia
const CAMPOS = [
  { fs: 'descripcion',     label: 'Sinopsis/descripción',  sc: l => l.sinopsis },
  { fs: 'campo_autor',     label: 'Autor',                  sc: l => l.autor },
  { fs: 'campo_isbn',      label: 'ISBN',                   sc: l => l.isbn || l.isbn13 },
  { fs: 'precio',          label: 'Precio impreso',         sc: l => l.precio_impreso || l.precio_unico },
  { fs: 'precio_digital',  label: 'Precio ebook',           sc: l => l.precio_ebook },
  { fs: 'campo_paginas',   label: 'Páginas',                sc: l => l.paginas ? String(l.paginas) : '' },
  { fs: 'campo_dimensiones',label: 'Tamaño/dimensiones',   sc: l => l.tamano },
  { fs: 'campo_formato',   label: 'Encuadernación',         sc: l => l.encuadernacion },
  { fs: 'campo_mes',       label: 'Mes impresión',          sc: l => {
    if (!l.fecha_impresion) return '';
    const m = l.fecha_impresion.match(/^([A-Za-záéíóúñÁÉÍÓÚÑ]+)/);
    return m ? m[1] : '';
  }},
  { fs: 'campo_anio',      label: 'Año impresión',          sc: l => {
    if (!l.fecha_impresion) return '';
    const m = l.fecha_impresion.match(/(\d{4})/);
    return m ? m[1] : '';
  }},
  { fs: 'imagen_url',      label: 'Imagen portada',         sc: l => l.portada },
  { fs: 'categoria',       label: 'Categoría/colección',    sc: l => l.coleccion || l.categorias },
];

function estaVacio(val) {
  if (val === null || val === undefined) return true;
  if (typeof val === 'string' && val.trim() === '') return true;
  if (typeof val === 'number' && val === 0) return true;
  return false;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\nLeyendo ' + COLECCION + ' de Firestore...');
  const snap = await db.collection('empresas').doc(EID).collection(COLECCION).get();
  const firestoreDocs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
  console.log(' Documentos en Firestore: ' + firestoreDocs.length);
  console.log(' Libros scrapeados:       ' + scraped.length);

  // Índice Firestore por título normalizado
  const fsIndex = {};
  firestoreDocs.forEach(doc => {
    const k = normTitulo(doc.nombre || '');
    if (k) fsIndex[k] = doc;
  });

  // Índice scrapeado por título normalizado
  const scIndex = {};
  scraped.forEach(l => {
    const k = normTitulo(l.titulo || '');
    if (k) scIndex[k] = l;
  });

  // ── Comparar coincidencias ────────────────────────────────────────────────
  const coincidencias   = [];
  const soloEnScrapeado = [];
  const soloEnFirestore = [];

  for (const [k, sc] of Object.entries(scIndex)) {
    if (fsIndex[k]) {
      coincidencias.push({ scrapeado: sc, firestore: fsIndex[k] });
    } else {
      soloEnScrapeado.push(sc);
    }
  }
  for (const [k, fs] of Object.entries(fsIndex)) {
    if (!scIndex[k]) soloEnFirestore.push(fs);
  }

  // ── Campos vacíos ─────────────────────────────────────────────────────────
  const discrepancias = [];
  for (const { scrapeado, firestore } of coincidencias) {
    const camposVaciosEnFs = [];
    for (const def of CAMPOS) {
      const valFs = firestore[def.fs];
      const valSc = def.sc(scrapeado);
      if (estaVacio(valFs) && !estaVacio(valSc)) {
        camposVaciosEnFs.push({ campo: def.fs, label: def.label, valor_disponible: String(valSc).substring(0, 150) });
      }
    }
    if (camposVaciosEnFs.length > 0) {
      discrepancias.push({ titulo: scrapeado.titulo, id_fs: firestore.id, campos_vacios: camposVaciosEnFs });
    }
  }

  // ── Comparación de descripciones ─────────────────────────────────────────
  const diffDesc = [];
  for (const { scrapeado, firestore } of coincidencias) {
    const descFs  = (firestore.descripcion || '').trim();
    const descSc  = (scrapeado.sinopsis    || '').trim();
    if (!descFs && !descSc) continue;
    const masLargaEs = descFs.length >= descSc.length ? 'firestore' : 'scrapeado';
    const diff = Math.abs(descFs.length - descSc.length);
    if (diff > 20) {  // solo registrar si hay diferencia real
      diffDesc.push({
        titulo:       scrapeado.titulo,
        id_fs:        firestore.id,
        fs_chars:     descFs.length,
        sc_chars:     descSc.length,
        mas_larga_en: masLargaEs,
        diff_chars:   diff,
        fs_preview:   descFs.substring(0, 120),
        sc_preview:   descSc.substring(0, 120),
      });
    }
  }
  diffDesc.sort((a, b) => b.diff_chars - a.diff_chars);

  // ── Comparación de páginas ────────────────────────────────────────────────
  const diffPaginas = [];
  for (const { scrapeado, firestore } of coincidencias) {
    const pFs = parseInt(firestore.campo_paginas || '0', 10) || 0;
    const pSc = parseInt(scrapeado.paginas       || '0', 10) || 0;
    if (!pFs && !pSc) continue;
    if (pFs !== pSc) {
      diffPaginas.push({ titulo: scrapeado.titulo, id_fs: firestore.id,
        firestore: pFs || '(vacío)', scrapeado: pSc || '(vacío)' });
    }
  }

  // ── Comparación de precios ────────────────────────────────────────────────
  const limpiar = s => (s || '').replace(/\s*€\s*/g, '').replace(/\s+/g, ' ').trim();

  const diffPrecios = [];
  for (const { scrapeado, firestore } of coincidencias) {
    const fsImpreso  = limpiar(firestore.precio         || '');
    const fsEbook    = limpiar(firestore.precio_digital  || '');
    const scImpreso  = limpiar(scrapeado.precio_impreso || scrapeado.precio_unico || '');
    const scEbook    = limpiar(scrapeado.precio_ebook    || '');

    // Solo incluir si hay al menos un valor en algún lado
    if (!fsImpreso && !fsEbook && !scImpreso && !scEbook) continue;

    const impresoDifiere = fsImpreso !== scImpreso;
    const ebookDifiere   = fsEbook   !== scEbook;

    if (impresoDifiere || ebookDifiere) {
      diffPrecios.push({
        titulo:      scrapeado.titulo,
        id_fs:       firestore.id,
        // Impreso
        fs_impreso:  fsImpreso  || '(vacío)',
        sc_impreso:  scImpreso  || '(vacío)',
        impreso_ok:  !impresoDifiere,
        // Ebook
        fs_ebook:    fsEbook    || '(vacío)',
        sc_ebook:    scEbook    || '(vacío)',
        ebook_ok:    !ebookDifiere,
      });
    }
  }

  // ── Mostrar resultados ────────────────────────────────────────────────────
  const sep = '─'.repeat(72);
  console.log('\n' + '═'.repeat(72));
  console.log(' RESUMEN');
  console.log('═'.repeat(72));
  console.log(' Coincidencias (mismo título en ambos):   ' + coincidencias.length);
  console.log(' Solo en scrapeado (faltan en Firestore):  ' + soloEnScrapeado.length);
  console.log(' Solo en Firestore (no scrapeados):        ' + soloEnFirestore.length);
  console.log(' Con campo vacío en Firestore:             ' + discrepancias.length);
  console.log(' Precios con discrepancia:                 ' + diffPrecios.length +
    '  (' + diffPrecios.filter(d => !d.impreso_ok).length + ' impreso, ' +
             diffPrecios.filter(d => !d.ebook_ok).length + ' ebook)');
  console.log(' Descripciones con diferencia:             ' + diffDesc.length +
    '  (' + diffDesc.filter(d => d.mas_larga_en === 'scrapeado').length + ' más largas en scrapeado, ' +
             diffDesc.filter(d => d.mas_larga_en === 'firestore').length + ' más largas en Firestore)');
  console.log(' Páginas distintas:                        ' + diffPaginas.length);

  // Precios con discrepancia — tabla completa
  if (diffPrecios.length > 0) {
    console.log('\n' + sep);
    console.log(' PRECIOS — COMPARATIVA COMPLETA (' + diffPrecios.length + ' libros con diferencia)');
    console.log(sep);
    console.log('  ' + 'Título'.padEnd(40) + 'Fluix impreso'.padEnd(14) + 'Web impreso'.padEnd(14) + 'Fluix ebook'.padEnd(14) + 'Web ebook');
    console.log('  ' + '─'.repeat(90));
    diffPrecios.forEach(d => {
      const ok  = s => s;
      const chk = (fs, sc, igual) => igual ? '✓ ' + fs : '✗ FS:' + fs + ' SC:' + sc;
      const titulo = d.titulo.substring(0, 38).padEnd(40);
      const imp = d.impreso_ok
        ? ('✓ ' + d.fs_impreso).padEnd(28)
        : ('✗ FS:' + d.fs_impreso + '  SC:' + d.sc_impreso).padEnd(28);
      const ebo = d.ebook_ok
        ? ('✓ ' + d.fs_ebook).padEnd(28)
        : ('✗ FS:' + d.fs_ebook + '  SC:' + d.sc_ebook);
      console.log('  ' + titulo + imp + ebo);
    });
  }

  // Campos vacíos
  if (discrepancias.length > 0) {
    console.log('\n' + sep);
    console.log(' CAMPOS VACÍOS EN FIRESTORE (tienen valor en scrapeado)');
    console.log(sep);
    discrepancias.forEach((d, i) => {
      console.log('\n' + String(i + 1).padStart(3) + '. ' + d.titulo + '  [' + d.id_fs + ']');
      d.campos_vacios.forEach(c => {
        console.log('     ✗ ' + c.label.padEnd(25) + '(' + c.campo + ')  →  "' + c.valor_disponible + '"');
      });
    });
  }

  // Descripciones — 5 ejemplos de scrapeado más largo y 5 de Firestore más largo
  console.log('\n' + sep);
  console.log(' DESCRIPCIONES — 5 libros donde el SCRAPEADO tiene más texto');
  console.log(sep);
  diffDesc.filter(d => d.mas_larga_en === 'scrapeado').slice(0, 5).forEach((d, i) => {
    console.log('\n' + String(i + 1) + '. ' + d.titulo);
    console.log('   Firestore  (' + d.fs_chars + ' chars): "' + d.fs_preview + (d.fs_chars > 120 ? '...' : '') + '"');
    console.log('   Scrapeado  (' + d.sc_chars + ' chars): "' + d.sc_preview + (d.sc_chars > 120 ? '...' : '') + '"');
  });

  console.log('\n' + sep);
  console.log(' DESCRIPCIONES — 5 libros donde FIRESTORE tiene más texto');
  console.log(sep);
  diffDesc.filter(d => d.mas_larga_en === 'firestore').slice(0, 5).forEach((d, i) => {
    console.log('\n' + String(i + 1) + '. ' + d.titulo);
    console.log('   Firestore  (' + d.fs_chars + ' chars): "' + d.fs_preview + (d.fs_chars > 120 ? '...' : '') + '"');
    console.log('   Scrapeado  (' + d.sc_chars + ' chars): "' + d.sc_preview + (d.sc_chars > 120 ? '...' : '') + '"');
  });

  // Páginas — 5 donde Firestore difiere del scrapeado
  console.log('\n' + sep);
  console.log(' PÁGINAS DISTINTAS — 5 ejemplos');
  console.log(sep);
  diffPaginas.slice(0, 5).forEach((d, i) => {
    console.log(String(i + 1) + '. ' + d.titulo);
    console.log('   Firestore: ' + d.firestore + '  |  Scrapeado: ' + d.scrapeado);
  });

  // Solo en scrapeado
  if (soloEnScrapeado.length > 0) {
    console.log('\n' + sep);
    console.log(' LIBROS SCRAPEADOS QUE NO ESTÁN EN FIRESTORE (' + soloEnScrapeado.length + ')');
    console.log(sep);
    soloEnScrapeado.filter(l => l.isbn).slice(0, 30).forEach((l, i) => {
      console.log('  ' + String(i + 1).padStart(3) + '. ' + l.titulo + '  [' + l.isbn + ']');
    });
    const sinIsbn = soloEnScrapeado.filter(l => !l.isbn);
    if (sinIsbn.length) console.log('  + ' + sinIsbn.length + ' sin ISBN (probablemente basura del scraper)');
  }

  if (GUARDAR_JSON) {
    const out = {
      fecha: new Date().toISOString(),
      resumen: {
        coincidencias:            coincidencias.length,
        solo_en_scrapeado:        soloEnScrapeado.length,
        solo_en_firestore:        soloEnFirestore.length,
        con_campos_vacios:        discrepancias.length,
        descripciones_diferentes: diffDesc.length,
        desc_mas_larga_scrapeado: diffDesc.filter(d => d.mas_larga_en === 'scrapeado').length,
        desc_mas_larga_firestore: diffDesc.filter(d => d.mas_larga_en === 'firestore').length,
        paginas_diferentes:       diffPaginas.length,
        precios_diferentes:       diffPrecios.length,
        precios_impreso_diff:     diffPrecios.filter(d => !d.impreso_ok).length,
        precios_ebook_diff:       diffPrecios.filter(d => !d.ebook_ok).length,
      },
      campos_vacios_en_firestore: discrepancias,
      precios_diferentes:         diffPrecios,
      descripciones_diferentes:   diffDesc,
      paginas_diferentes:         diffPaginas,
      solo_en_scrapeado:    soloEnScrapeado.filter(l => l.isbn).map(l => ({ titulo: l.titulo, isbn: l.isbn, autor: l.autor })),
      solo_en_firestore:    soloEnFirestore.map(d => ({ titulo: d.nombre, id: d.id })),
    };
    const outFile = path.join(__dirname, 'discrepancias_catalogo_nazari.json');
    fs.writeFileSync(outFile, JSON.stringify(out, null, 2), 'utf8');
    console.log('\nGuardado: ' + outFile);
  }

  await admin.app().delete();
}

main().catch(e => { console.error('Error:', e.message || e); process.exit(1); });
