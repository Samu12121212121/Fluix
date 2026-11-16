/**
 * comparar_web_vs_fluix.js
 * Compara los eventos de eventos-data.js (web estática local)
 * con los eventos de Firestore (Fluix).
 *
 * Muestra:
 *   ✓ En Fluix Y en la web estática
 *   ✗ En la web estática pero NO en Fluix → hay que quitarlos de la web
 *   ? Solo en Fluix (importados de WP, no están en el JS local)
 *
 * Uso: node scripts/comparar_web_vs_fluix.js
 */
const admin = require('firebase-admin');
const fs    = require('fs');
const vm    = require('vm');
const path  = require('path');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

const LOCAL_PATH = path.join('C:\\Users\\Samu\\Downloads\\public_html (2)', 'eventos-data.js');

function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/['''"""«»]/g, '').replace(/\s+/g, ' ').trim();
}

function clave(titulo, fecha) {
  return norm(titulo).replace(/^['"]|['"]$/g, '').trim() + '||' + String(fecha).substring(0, 10);
}

(async () => {
  // ── 1. Cargar eventos locales ──────────────────────────────────────────────
  let code = fs.readFileSync(LOCAL_PATH, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {}; vm.runInNewContext(code, ctx);
  const locales = ctx.EVENTOS || [];
  console.log(`\nEventos en eventos-data.js (web local): ${locales.length}`);

  // ── 2. Cargar eventos de Fluix (Firestore) ─────────────────────────────────
  const snap = await db.collection('empresas').doc(EID).collection('eventos').get();
  console.log(`Eventos en Fluix (Firestore):           ${snap.size}`);

  // Índice Fluix por clave título+fecha
  const fluixMap = new Map();
  snap.forEach(doc => {
    const d = doc.data();
    let fecha = '';
    if (d.fecha && d.fecha.toDate) fecha = d.fecha.toDate().toISOString().substring(0, 10);
    else if (d.fecha) fecha = String(d.fecha).substring(0, 10);
    fluixMap.set(clave(d.titulo || '', fecha), { id: doc.id, titulo: d.titulo, fecha });
  });

  // ── 3. Comparar ────────────────────────────────────────────────────────────
  const enAmbos  = [];
  const soloWeb  = [];  // en web local pero NO en Fluix → hay que quitar de la web

  for (const ev of locales) {
    const k = clave(ev.titulo, ev.fecha);
    if (fluixMap.has(k)) {
      enAmbos.push(ev);
      fluixMap.delete(k); // marcar como visto
    } else {
      soloWeb.push(ev);
    }
  }

  // Lo que queda en fluixMap = solo en Fluix, no en el JS local
  const soloFluix = [...fluixMap.values()];

  // ── 4. Informe ─────────────────────────────────────────────────────────────
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`✓ En Fluix y en la web estática:       ${enAmbos.length}`);
  console.log(`✗ Solo en web estática (NO en Fluix):  ${soloWeb.length}  ← HAY QUE QUITAR DE LA WEB`);
  console.log(`? Solo en Fluix (importados WP):       ${soloFluix.length}`);
  console.log('═'.repeat(60));

  if (soloWeb.length) {
    console.log('\n── EVENTOS EN LA WEB LOCAL QUE NO ESTÁN EN FLUIX ─────────');
    console.log('   (IDs a eliminar de eventos-data.js)');
    soloWeb.forEach(ev =>
      console.log(`  id:${String(ev.id).padEnd(3)}  ${ev.fecha}  ${ev.titulo}`)
    );
  }

  if (soloFluix.length) {
    console.log(`\n── SOLO EN FLUIX (primeros 20) ────────────────────────────`);
    soloFluix.slice(0, 20).forEach(ev =>
      console.log(`  [${ev.id.substring(0,30).padEnd(31)}] ${ev.fecha}  ${(ev.titulo||'').substring(0,50)}`)
    );
    if (soloFluix.length > 20) console.log(`  ... y ${soloFluix.length - 20} más`);
  }

  console.log('');
  process.exit(0);
})();
