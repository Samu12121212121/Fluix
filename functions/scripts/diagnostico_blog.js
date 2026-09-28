/**
 * diagnostico_blog.js  — SOLO LECTURA, no modifica nada
 *
 * Uso:
 *   cd functions
 *   node scripts/diagnostico_blog.js
 *   node scripts/diagnostico_blog.js --tipo entrevista   (solo entrevistas)
 *   node scripts/diagnostico_blog.js --tipo noticia      (solo noticias)
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID  = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const TIPO = process.argv.includes('--tipo')
  ? process.argv[process.argv.indexOf('--tipo') + 1]
  : null;

async function main() {
  console.log('\n═══════════════════════════════════════════════');
  console.log(' DIAGNÓSTICO COLECCIÓN blog (solo lectura)');
  console.log('═══════════════════════════════════════════════\n');

  const snap = await db
    .collection('empresas').doc(EID)
    .collection('blog')
    .get();

  const todos = snap.docs.map(d => ({ id: d.id, ...d.data() }));
  console.log(`Total documentos en blog: ${todos.length}\n`);

  // ── Filtrar por tipo si se pasa --tipo ─────────────────────────
  const docs = TIPO
    ? todos.filter(p =>
        (p.tipo || '').toLowerCase() === TIPO.toLowerCase() ||
        (p.categoria_id || '').toLowerCase() === TIPO.toLowerCase() + 's' ||
        (p.categoria || '').toLowerCase() === TIPO.toLowerCase() + 's'
      )
    : todos;

  if (TIPO) console.log(`Filtrando por tipo="${TIPO}": ${docs.length} docs\n`);

  // ── Estadísticas de campos clave ───────────────────────────────
  const sinPublicada   = docs.filter(p => p.publicada === undefined || p.publicada === null);
  const publicadaTrue  = docs.filter(p => p.publicada === true);
  const publicadaFalse = docs.filter(p => p.publicada === false);
  const borrador       = docs.filter(p => p.estado === 'borrador' || p.estado === 'draft');
  const eliminados     = docs.filter(p => p.eliminado === true);
  const sinEstado      = docs.filter(p => !p.estado && !p.eliminado && p.publicada !== false);

  console.log('── Estado de los campos ─────────────────────────');
  console.log(`  publicada: true       → ${publicadaTrue.length}`);
  console.log(`  publicada: false      → ${publicadaFalse.length}  ← NO deberían verse`);
  console.log(`  publicada: (sin campo)→ ${sinPublicada.length}  ← SÍ se ven (filtro 'todos')`);
  console.log(`  estado: borrador/draft→ ${borrador.length}  ← filtrados en loadPosts()`);
  console.log(`  eliminado: true       → ${eliminados.length}  ← filtrados en loadPosts()`);
  console.log(`  visibles (llegan web) → ${docs.filter(p => p.publicada !== false && p.eliminado !== true && p.estado !== 'borrador' && p.estado !== 'draft').length}`);
  console.log('');

  // ── Duplicados por slug ────────────────────────────────────────
  const porSlug = {};
  docs.forEach(p => {
    const k = p.slug || p.id;
    if (!porSlug[k]) porSlug[k] = [];
    porSlug[k].push(p);
  });
  const duplicadosSlug = Object.entries(porSlug).filter(([, arr]) => arr.length > 1);

  // ── Duplicados por título ──────────────────────────────────────
  const porTitulo = {};
  docs.forEach(p => {
    if (!p.titulo) return;
    const k = p.titulo.trim().toLowerCase();
    if (!porTitulo[k]) porTitulo[k] = [];
    porTitulo[k].push(p);
  });
  const duplicadosTitulo = Object.entries(porTitulo).filter(([, arr]) => arr.length > 1);

  console.log('── Duplicados ───────────────────────────────────');
  console.log(`  Por slug: ${duplicadosSlug.length} grupos con duplicado`);
  console.log(`  Por título: ${duplicadosTitulo.length} grupos con duplicado\n`);

  if (duplicadosSlug.length) {
    console.log('  Duplicados por slug:');
    duplicadosSlug.forEach(([slug, arr]) => {
      console.log(`    slug="${slug}" → ${arr.length} docs:`);
      arr.forEach(p => console.log(`      id=${p.id} | publicada=${p.publicada} | estado=${p.estado} | eliminado=${p.eliminado}`));
    });
    console.log('');
  }

  if (duplicadosTitulo.length) {
    console.log('  Duplicados por título:');
    duplicadosTitulo.slice(0, 20).forEach(([titulo, arr]) => {
      console.log(`    "${titulo.substring(0, 60)}..." → ${arr.length} docs:`);
      arr.forEach(p => console.log(`      id=${p.id} | slug=${p.slug} | publicada=${p.publicada} | estado=${p.estado}`));
    });
    if (duplicadosTitulo.length > 20) console.log(`    ... y ${duplicadosTitulo.length - 20} más`);
    console.log('');
  }

  // ── Entrevistas visibles sin publicada:true ────────────────────
  const visiblesNoExplicitas = docs.filter(p =>
    p.publicada !== true &&
    p.publicada !== false &&
    p.eliminado !== true &&
    p.estado !== 'borrador' &&
    p.estado !== 'draft'
  );
  console.log('── Visibles pero sin publicada:true ─────────────');
  console.log(`  ${visiblesNoExplicitas.length} docs se muestran porque el filtro usa 'todos'`);
  if (visiblesNoExplicitas.length && visiblesNoExplicitas.length <= 50) {
    visiblesNoExplicitas.forEach(p => {
      console.log(`  · ${(p.titulo||'(sin título)').substring(0,60)} | id=${p.id} | tipo=${p.tipo||'-'}`);
    });
  } else if (visiblesNoExplicitas.length > 50) {
    console.log('  (demasiados para listar; usa --tipo entrevista para acotar)');
  }

  console.log('\n═══════════════════════════════════════════════');
  console.log(' FIN (no se ha modificado nada)');
  console.log('═══════════════════════════════════════════════\n');
}

main().catch(e => { console.error(e); process.exit(1); });
