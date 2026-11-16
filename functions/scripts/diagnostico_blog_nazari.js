/**
 * diagnostico_blog_nazari.js
 * Lee los posts de blog de Firestore y detecta:
 *  1. Posts donde resumen aparece duplicado al inicio del contenido
 *  2. Cómo están almacenados los saltos de línea en contenido
 *
 * Uso: node scripts/diagnostico_blog_nazari.js
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

function norm(s = '') {
  return s.toLowerCase().replace(/\s+/g, ' ').trim().substring(0, 80);
}

(async () => {
  // Cargar todas las colecciones relevantes
  const [snapBlog, snapNoticias, snapEntrevistas] = await Promise.all([
    db.collection('empresas').doc(EID).collection('blog').get(),
    db.collection('empresas').doc(EID).collection('noticias').get().catch(() => ({ size: 0, forEach: () => {} })),
    db.collection('empresas').doc(EID).collection('entrevistas').get().catch(() => ({ size: 0, forEach: () => {} })),
  ]);

  // Combinar todos los docs, anotando de qué colección vienen
  const todosDocs = [];
  snapBlog.forEach(doc       => todosDocs.push({ doc, col: 'blog' }));
  snapNoticias.forEach(doc   => todosDocs.push({ doc, col: 'noticias' }));
  snapEntrevistas.forEach(doc => todosDocs.push({ doc, col: 'entrevistas' }));

  // También separar por tipo dentro de blog
  const porTipo = {};
  let eliminados = 0, sinEliminadoField = 0;
  snapBlog.forEach(doc => {
    const d = doc.data();
    const tipo = d.tipo || 'sin_tipo';
    if (!porTipo[tipo]) porTipo[tipo] = 0;
    porTipo[tipo]++;
    if (d.eliminado === true) eliminados++;
    if (d.eliminado === undefined || d.eliminado === null) sinEliminadoField++;
  });

  console.log(`\nColecciones encontradas:`);
  console.log(`  blog:        ${snapBlog.size} docs`);
  console.log(`    tipos: ${JSON.stringify(porTipo)}`);
  console.log(`    eliminados=true:          ${eliminados}`);
  console.log(`    sin campo eliminado:       ${sinEliminadoField}`);
  console.log(`  noticias:    ${snapNoticias.size} docs`);
  console.log(`  entrevistas: ${snapEntrevistas.size} docs`);
  console.log(`  TOTAL:       ${todosDocs.length} docs\n`);

  const snap = { size: todosDocs.length, forEach: (fn) => todosDocs.forEach(({ doc }) => fn(doc)) };

  console.log(`\nTotal posts en blog: ${snap.size}\n`);

  let conDuplicacion = 0;
  let conSaltosN     = 0;  // contenido tiene \n reales
  let conSaltosLit   = 0;  // contenido tiene \\n literales (mal escapado)
  let sinContenido   = 0;
  let conContenido   = 0;

  const duplicados   = [];
  const sinSaltos    = [];  // tienen contenido pero sin ningún salto

  snap.forEach(doc => {
    const d       = doc.data();
    const resumen = (d.resumen || '').trim();
    const cont    = d.contenido || '';
    const contH   = d.contenido_html || '';

    if (!cont && !contH) { sinContenido++; return; }
    conContenido++;

    // ── 1. Duplicación: ¿empieza el contenido con el resumen? ─────────────
    if (resumen && cont) {
      const inicioContenido = norm(cont.replace(/<[^>]+>/g, ''));
      const normResumen     = norm(resumen);
      if (normResumen.length > 20 && inicioContenido.startsWith(normResumen.substring(0, 60))) {
        conDuplicacion++;
        duplicados.push({ id: doc.id, titulo: d.titulo });
      }
    }

    // ── 2. Saltos de línea en contenido ───────────────────────────────────
    if (cont) {
      const tieneN    = cont.includes('\n');
      const tieneLit  = cont.includes('\\n');
      if (tieneN)   conSaltosN++;
      if (tieneLit) conSaltosLit++;
      if (!tieneN && !tieneLit && cont.length > 100) {
        sinSaltos.push({ id: doc.id, titulo: d.titulo, len: cont.length,
          muestra: cont.substring(0, 120).replace(/\n/g,'↵').replace(/\\n/g,'[\\n]') });
      }
    }
  });

  // ── Informe ───────────────────────────────────────────────────────────────
  console.log('═'.repeat(55));
  console.log('CONTENIDO');
  console.log('  Con contenido (contenido o contenido_html): ', conContenido);
  console.log('  Sin contenido (solo resumen/imagen):        ', sinContenido);

  console.log('\nSALTOS DE LÍNEA en campo "contenido"');
  console.log('  Con \\n reales (correcto):                  ', conSaltosN);
  console.log('  Con \\\\n literales (bug escapado):           ', conSaltosLit);
  console.log('  Con contenido largo pero SIN saltos:       ', sinSaltos.length);

  console.log('\nDUPLICACIÓN (resumen al inicio del contenido)');
  console.log('  Posts con texto duplicado:                 ', conDuplicacion);

  if (sinSaltos.length) {
    console.log('\n── Posts con contenido largo sin saltos de línea ──');
    sinSaltos.slice(0, 10).forEach(p =>
      console.log(`  [${p.id.substring(0,25).padEnd(26)}] ${p.len}c  "${p.muestra}"`)
    );
    if (sinSaltos.length > 10) console.log(`  ... y ${sinSaltos.length - 10} más`);
  }

  if (duplicados.length) {
    console.log('\n── Posts con texto duplicado ──');
    duplicados.slice(0, 10).forEach(p =>
      console.log(`  [${p.id.substring(0,25).padEnd(26)}] ${p.titulo}`)
    );
    if (duplicados.length > 10) console.log(`  ... y ${duplicados.length - 10} más`);
  }

  // Muestra un ejemplo concreto para depurar saltos
  console.log('\n── Ejemplo detallado (primer post con contenido) ──');
  let ejemplo = null;
  snap.forEach(doc => {
    if (!ejemplo && doc.data().contenido && doc.data().contenido.length > 50) ejemplo = doc;
  });
  if (ejemplo) {
    const d = ejemplo.data();
    const cont = d.contenido;
    console.log(`  ID: ${ejemplo.id}`);
    console.log(`  Título: ${d.titulo}`);
    console.log(`  Resumen (${(d.resumen||'').length}c): "${(d.resumen||'').substring(0,80)}"`);
    console.log(`  Contenido (${cont.length}c):`);
    console.log(`    Tiene \\n: ${cont.includes('\n')}`);
    console.log(`    Tiene \\\\n: ${cont.includes('\\n')}`);
    console.log(`    Primeros 200 chars RAW: ${JSON.stringify(cont.substring(0, 200))}`);
  }

  console.log('');
  process.exit(0);
})();
