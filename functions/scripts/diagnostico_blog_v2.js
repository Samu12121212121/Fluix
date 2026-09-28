/**
 * diagnostico_blog_v2.js — SOLO LECTURA
 * Compara entrevistas.html (329 originales) vs Firestore (368)
 * para identificar exactamente los 39 extras.
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

/* normalizar título: quitar tildes, puntuación, lowercase */
function norm(s) {
  if (!s) return '';
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function main() {
  // ── 1. Cargar entrevistas del HTML ────────────────────────────
  const htmlPath = 'C:\\Users\\Samu\\Desktop\\imagenes_nazari\\html_nazari\\img\\html_nazari\\entrevistas.html';
  const html = fs.readFileSync(htmlPath, 'utf8');
  const arrMatch = html.match(/var ENTREVISTAS\s*=\s*(\[[\s\S]*?\n\];)/);
  if (!arrMatch) throw new Error('No se encontró ENTREVISTAS en entrevistas.html');

  // Extraer cada entrada {id:N, t:'...', f:'...', l:'...'}
  const entradas = [...arrMatch[1].matchAll(/\{id:(\d+),t:'([^']*)'(?:[^}]*)f:'([^']*)'/g)]
    .map(m => ({ id: m[1], t: m[2], f: m[3] }));
  // También capturar las que tienen comillas dobles en t
  const entradas2 = [...arrMatch[1].matchAll(/\{id:(\d+),t:"([^"]*)"(?:[^}]*)f:'([^']*)'/g)]
    .map(m => ({ id: m[1], t: m[2], f: m[3] }));
  const htmlItems = [...entradas, ...entradas2];
  const htmlTitulos = new Map(htmlItems.map(e => [norm(e.t), e]));
  console.log(`HTML original: ${htmlItems.length} entrevistas\n`);

  // ── 2. Cargar de Firestore ────────────────────────────────────
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'entrevista').get();
  const fbDocs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
  console.log(`Firestore (tipo=entrevista): ${fbDocs.length} docs\n`);

  // ── 3. Identificar duplicados exactos por slug ────────────────
  const porSlug = {};
  fbDocs.forEach(p => {
    const k = p.slug || p.id;
    (porSlug[k] = porSlug[k] || []).push(p);
  });
  const dupsSlug = Object.values(porSlug).filter(a => a.length > 1);

  // ── 4. Identificar duplicados por título normalizado ──────────
  const porTituloNorm = {};
  fbDocs.forEach(p => {
    const k = norm(p.titulo || '');
    if (!k) return;
    (porTituloNorm[k] = porTituloNorm[k] || []).push(p);
  });
  const dupsTitulo = Object.values(porTituloNorm).filter(a => a.length > 1);

  // ── 5. Docs en Firestore que NO están en el HTML ──────────────
  const soloFirestore = fbDocs.filter(p => {
    const k = norm(p.titulo || '');
    return !htmlTitulos.has(k);
  });

  // ── 6. Docs en HTML que NO están en Firestore ─────────────────
  const fbTitulos = new Set(fbDocs.map(p => norm(p.titulo || '')));
  const soloHtml = htmlItems.filter(e => !fbTitulos.has(norm(e.t)));

  // ── Reporte ───────────────────────────────────────────────────
  console.log('════════════════════════════════════════════════');
  console.log(' RESUMEN');
  console.log('════════════════════════════════════════════════');
  console.log(`  HTML original:          ${htmlItems.length}`);
  console.log(`  Firestore (entrevista): ${fbDocs.length}`);
  console.log(`  Diferencia:             +${fbDocs.length - htmlItems.length}`);
  console.log(`  Dups por slug:          ${dupsSlug.length} pares`);
  console.log(`  Dups por título (norm): ${dupsTitulo.length} pares`);
  console.log(`  Solo en Firestore:      ${soloFirestore.length} (no están en el HTML)`);
  console.log(`  Solo en HTML:           ${soloHtml.length} (no están en Firestore)\n`);

  if (dupsTitulo.length) {
    console.log('── Duplicados por título (normalizado) ─────────');
    dupsTitulo.forEach(arr => {
      console.log(`  TÍTULO: "${(arr[0].titulo||'').substring(0,70)}"`);
      arr.forEach(p => console.log(`    · id=${p.id} | estado=${p.estado||'-'} | eliminado=${p.eliminado||false}`));
    });
    console.log('');
  }

  if (soloFirestore.length) {
    console.log(`── En Firestore pero NO en HTML (${soloFirestore.length}) ────────`);
    soloFirestore.forEach(p => {
      console.log(`  · "${(p.titulo||'(sin título)').substring(0,70)}"`);
      console.log(`    id=${p.id} | estado=${p.estado||'-'} | publicada=${p.publicada} | eliminado=${p.eliminado||false}`);
    });
    console.log('');
  }

  if (soloHtml.length) {
    console.log(`── En HTML pero NO en Firestore (${soloHtml.length}) ──────────`);
    soloHtml.forEach(e => console.log(`  · [${e.f}] "${e.t.substring(0,70)}"`));
    console.log('');
  }

  console.log('════════════════════════════════════════════════');
  console.log(' FIN (no se ha modificado nada)');
  console.log('════════════════════════════════════════════════\n');
}

main().catch(e => { console.error(e); process.exit(1); });
