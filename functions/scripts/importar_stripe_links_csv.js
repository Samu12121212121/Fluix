/**
 * importar_stripe_links_csv.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Importa Stripe Payment Links desde un CSV a la colección catalogo_web.
 *
 * Formato del CSV (sin cabecera, o con cabecera slug,stripe_link):
 *   el-mundial-que-espana-no-gano,https://buy.stripe.com/xxxxx
 *   espejos,https://buy.stripe.com/yyyyy
 *
 * Si no tienes los slugs, usa --por-titulo: columnas titulo,stripe_link
 * y el script busca por coincidencia de título.
 *
 * Uso:
 *   node scripts/importar_stripe_links_csv.js --archivo=stripe_links.csv
 *   node scripts/importar_stripe_links_csv.js --archivo=stripe_links.csv --por-titulo
 *   node scripts/importar_stripe_links_csv.js --archivo=stripe_links.csv --confirmar
 *   node scripts/importar_stripe_links_csv.js --generar-plantilla   ← genera el CSV vacío
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => { const [k,...v] = a.slice(2).split('='); return [k, v.length ? v.join('=') : true]; })
);

const EID            = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const CONFIRMAR      = args['confirmar'] === true;
const POR_TITULO     = args['por-titulo'] === true;
const ARCHIVO        = args['archivo'] || 'stripe_links.csv';
const GEN_PLANTILLA  = args['generar-plantilla'] === true;

// ── Normalizar texto ─────────────────────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/\s+/g,' ').trim();
}

// ── Parsear CSV simple (sep: coma o punto y coma) ────────────────────────────
function parseCsv(text) {
  const lineas = text.split(/\r?\n/).filter(l => l.trim());
  const rows = [];
  for (const linea of lineas) {
    // Ignorar cabecera si empieza por slug/titulo/nombre
    if (/^(slug|titulo|nombre|title)/i.test(linea.trim())) continue;
    const sep = linea.includes(';') ? ';' : ',';
    // Dividir en 2 partes: columna1, resto (URL puede tener comas)
    const idx = linea.indexOf(sep);
    if (idx < 0) continue;
    const col1 = linea.slice(0, idx).trim().replace(/^["']|["']$/g, '');
    const col2 = linea.slice(idx + 1).trim().replace(/^["']|["']$/g, '');
    if (col1 && col2) rows.push([col1, col2]);
  }
  return rows;
}

async function generarPlantilla() {
  const sa = require('../serviceAccountKey.json');
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  console.log('📋 Generando plantilla CSV con todos los libros del catálogo…');
  const snap = await db.collection('empresas').doc(EID).collection('catalogo_web').get();
  const lines = ['slug,titulo,stripe_link'];
  snap.docs
    .map(d => ({ id: d.id, ...d.data() }))
    .filter(l => !l.eliminado)
    .sort((a,b) => (a.nombre || a.titulo || '').localeCompare(b.nombre || b.titulo || '', 'es'))
    .forEach(l => {
      const slug  = l.slug || l.id || '';
      const tit   = (l.nombre || l.titulo || '').replace(/,/g,' ');
      const link  = l.stripe_link || '';
      lines.push(`${slug},"${tit}",${link}`);
    });

  const outFile = path.resolve(process.cwd(), 'stripe_links_plantilla.csv');
  fs.writeFileSync(outFile, lines.join('\n'), 'utf8');
  console.log(`✅ Plantilla generada: ${outFile}`);
  console.log(`   ${snap.docs.length} libros — rellena la columna stripe_link y ejecuta:`);
  console.log(`   node scripts/importar_stripe_links_csv.js --archivo=stripe_links_plantilla.csv --confirmar`);
  process.exit(0);
}

async function run() {
  if (GEN_PLANTILLA) { await generarPlantilla(); return; }

  const sa = require('../serviceAccountKey.json');
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const csvPath = path.resolve(process.cwd(), ARCHIVO);
  if (!fs.existsSync(csvPath)) {
    console.error(`❌ Archivo no encontrado: ${csvPath}`);
    console.error('   Genera una plantilla con: node scripts/importar_stripe_links_csv.js --generar-plantilla');
    process.exit(1);
  }

  const texto = fs.readFileSync(csvPath, 'utf8');
  const filas = parseCsv(texto);
  console.log(`\n📄 ${filas.length} filas en el CSV`);
  console.log(`   Modo: ${POR_TITULO ? 'buscar por título' : 'buscar por slug'}`);
  console.log(`   ${CONFIRMAR ? '✏️  CONFIRMAR — escribe en Firestore' : '🔍 DRY-RUN — solo muestra el plan'}\n`);

  // Cargar catálogo
  const snap = await db.collection('empresas').doc(EID).collection('catalogo_web').get();
  const libros = snap.docs.map(d => ({ _docId: d.id, ...d.data() })).filter(l => !l.eliminado);

  // Índice por slug y por título normalizado
  const porSlug   = {};
  const porTitulo = {};
  for (const l of libros) {
    const slug = l.slug || l._docId || '';
    if (slug) porSlug[slug] = l;
    const tit = norm(l.nombre || l.titulo || l.nombre || '');
    if (tit) {
      if (!porTitulo[tit]) porTitulo[tit] = [];
      porTitulo[tit].push(l);
    }
  }

  const vinculaciones = [];
  const noEncontrados = [];
  const sinLink       = [];

  for (const [col1, col2] of filas) {
    const link = col2.trim();
    if (!link || !link.startsWith('http')) { sinLink.push(col1); continue; }

    let libro = null;
    if (POR_TITULO) {
      const candidatos = porTitulo[norm(col1)] || [];
      if (candidatos.length === 1) libro = candidatos[0];
      else if (candidatos.length > 1) {
        console.warn(`  ⚠️  Varios libros con título "${col1}" — usa slug`);
        noEncontrados.push(col1);
        continue;
      }
    } else {
      libro = porSlug[col1] || null;
    }

    if (!libro) {
      noEncontrados.push(col1);
    } else {
      vinculaciones.push({ docId: libro._docId, titulo: libro.nombre || libro.titulo || col1, link });
    }
  }

  console.log(`✅ Vinculaciones encontradas : ${vinculaciones.length}`);
  console.log(`❌ No encontrados            : ${noEncontrados.length}`);
  console.log(`⏭  Sin link en CSV           : ${sinLink.length}\n`);

  if (vinculaciones.length) {
    console.log('── VINCULACIONES ────────────────────────────────────────────');
    for (const v of vinculaciones) {
      console.log(`  [${v.docId}] "${v.titulo.substring(0,50)}" → ${v.link}`);
    }
    console.log('');
  }
  if (noEncontrados.length) {
    console.log('── NO ENCONTRADOS (revisa el slug/título) ───────────────────');
    noEncontrados.forEach(x => console.log('  · ' + x));
    console.log('');
  }

  if (!CONFIRMAR) {
    console.log('💡 Añade --confirmar para escribir en Firestore.\n');
    return;
  }

  if (!vinculaciones.length) {
    console.log('ℹ️  Sin vinculaciones que aplicar.\n');
    return;
  }

  const col = db.collection('empresas').doc(EID).collection('catalogo_web');
  for (let i = 0; i < vinculaciones.length; i += 400) {
    const chunk = vinculaciones.slice(i, i + 400);
    const batch = db.batch();
    for (const v of chunk) {
      batch.update(col.doc(v.docId), {
        stripe_link:          v.link,
        fecha_actualizacion:  admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    console.log(`  … ${Math.min(i + 400, vinculaciones.length)} / ${vinculaciones.length} escritas`);
  }

  console.log(`\n🎉 Listo. ${vinculaciones.length} libros vinculados a Stripe.\n`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
