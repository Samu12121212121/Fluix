/**
 * comparar_eventos_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Compara los eventos del sitio estático (eventos-data.js del public_html)
 * con la colección `eventos` de Firestore (Fluix / Editorial Nazarí).
 *
 * Muestra tres grupos:
 *   ✓ En ambos lados (ya importado)
 *   ✗ Solo en local (falta subir a Fluix)
 *   ? Solo en Fluix (importado desde WP web, no está en el JS local)
 *
 * Con --importar: sube a Firestore los eventos que solo están en local.
 * Con --forzar:   sobreescribe aunque ya existan.
 *
 * Uso:
 *   cd functions
 *   node scripts/comparar_eventos_nazari.js
 *   node scripts/comparar_eventos_nazari.js --importar
 *   node scripts/comparar_eventos_nazari.js --importar --forzar
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin  = require('firebase-admin');
const fs     = require('fs');
const vm     = require('vm');
const path   = require('path');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID       = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const IMPORTAR  = process.argv.includes('--importar');
const FORZAR    = process.argv.includes('--forzar');

// Ruta al archivo local — ajusta si es necesario
const LOCAL_PATH = path.join(
  'C:\\Users\\Samu\\Downloads\\public_html (2)',
  'eventos-data.js'
);

// ── Normalizar texto para comparación (sin tildes, minúsculas) ─────────────
function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/['''""‘’“”]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// ── Clave de comparación: título sin adornos + fecha YYYY-MM-DD ────────────
function claveEvento(titulo, fecha) {
  const t = norm(titulo).replace(/^['"]|['"]$/g, '').trim();
  const f = (fecha || '').toString().substring(0, 10);
  return `${t}||${f}`;
}

// ── Cargar eventos locales desde eventos-data.js ───────────────────────────
function cargarLocal() {
  if (!fs.existsSync(LOCAL_PATH)) {
    console.error(`✗ No se encuentra: ${LOCAL_PATH}`);
    process.exit(1);
  }
  let code = fs.readFileSync(LOCAL_PATH, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx.EVENTOS || [];
}

// ── Mapear evento local → documento Firestore ─────────────────────────────
function mapearLocal(ev) {
  const img = ev.imagen_url || (ev.imagen
    ? `https://seashell-boar-580681.hostingersite.com/${ev.imagen}`
    : '');

  let fecha = null;
  if (ev.fecha) {
    try { fecha = admin.firestore.Timestamp.fromDate(new Date(ev.fecha + 'T12:00:00')); }
    catch (_) {}
  }

  const tipoMap = {
    'Presentación': 'presentacion',
    'Presentacion': 'presentacion',
    'Firma':        'firma',
    'Conferencia':  'taller',
    'Premio':       'otro',
    'Taller':       'taller',
    'Feria':        'feria',
    'Lectura':      'lectura',
  };

  return {
    titulo:          ev.titulo     || '',
    subtitulo:       ev.subtitulo  || '',
    descripcion:     ev.descripcionLarga || ev.descripcion || '',
    fecha,
    hora:            ev.hora       || '',
    lugar:           ev.lugar      || '',
    ciudad:          ev.ciudad     || '',
    imagen_url:      img,
    tipo:            tipoMap[ev.tipo] || 'presentacion',
    libro_titulo:    ev.libro_titulo  || '',
    libro_slug:      ev.libro_slug    || '',
    autor_nombre:    ev.autor_nombre  || '',
    activo:          true,
    eliminado:       false,
    origen:          'local_js',
    _local_id:       ev.id,
  };
}

// ── MAIN ──────────────────────────────────────────────────────────────────
(async () => {
  // 1. Cargar eventos locales
  const locales = cargarLocal();
  console.log(`\nEventos en eventos-data.js (local): ${locales.length}`);

  // 2. Cargar todos los eventos de Firestore
  const snap = await db
    .collection('empresas').doc(EID)
    .collection('eventos')
    .get();

  const fluixEventos = [];
  snap.forEach(doc => {
    const d = doc.data();
    fluixEventos.push({ id: doc.id, ...d });
  });
  console.log(`Eventos en Fluix (Firestore):       ${fluixEventos.length}\n`);

  // 3. Construir mapa de claves Fluix
  const fluixClaves = new Map(); // clave → doc.id
  for (const ev of fluixEventos) {
    let fecha = '';
    if (ev.fecha && ev.fecha.toDate) fecha = ev.fecha.toDate().toISOString().substring(0, 10);
    else if (ev.fecha) fecha = String(ev.fecha).substring(0, 10);
    fluixClaves.set(claveEvento(ev.titulo, fecha), ev.id);
  }

  // 4. Construir mapa de claves locales
  const localClaves = new Map(); // clave → ev
  for (const ev of locales) {
    localClaves.set(claveEvento(ev.titulo, ev.fecha), ev);
  }

  // 5. Comparar
  const soloEnLocal    = [];
  const enAmbos        = [];
  const soloEnFluix    = [];

  for (const [clave, ev] of localClaves) {
    if (fluixClaves.has(clave)) {
      enAmbos.push({ local: ev, fluixId: fluixClaves.get(clave) });
    } else {
      soloEnLocal.push(ev);
    }
  }
  for (const [clave, docId] of fluixClaves) {
    if (!localClaves.has(clave)) {
      const ev = fluixEventos.find(e => e.id === docId);
      soloEnFluix.push(ev);
    }
  }

  // 6. Informe
  console.log('═'.repeat(60));
  console.log(`✓ En ambos (ya sincronizados):  ${enAmbos.length}`);
  console.log(`✗ Solo en local (faltan subir): ${soloEnLocal.length}`);
  console.log(`? Solo en Fluix (importados WP): ${soloEnFluix.length}`);
  console.log('═'.repeat(60));

  if (soloEnLocal.length) {
    console.log('\n── FALTAN SUBIR A FLUIX ──────────────────────────────────');
    soloEnLocal.forEach(ev => {
      console.log(`  [${String(ev.id).padStart(3)}] ${ev.fecha}  ${ev.titulo}`);
    });
  }

  if (soloEnFluix.length) {
    console.log('\n── SOLO EN FLUIX (importados de WP, no están en JS local) ─');
    soloEnFluix.slice(0, 20).forEach(ev => {
      let fecha = '';
      if (ev.fecha && ev.fecha.toDate) fecha = ev.fecha.toDate().toISOString().substring(0, 10);
      console.log(`  [${ev.id.substring(0, 30).padEnd(30)}] ${fecha}  ${ev.titulo || ''}`);
    });
    if (soloEnFluix.length > 20) console.log(`  ... y ${soloEnFluix.length - 20} más`);
  }

  if (enAmbos.length) {
    console.log('\n── YA SINCRONIZADOS ──────────────────────────────────────');
    enAmbos.forEach(({ local }) => {
      console.log(`  [${String(local.id).padStart(3)}] ${local.fecha}  ${local.titulo}`);
    });
  }

  // 7. Importar los que faltan si se pidió
  if (IMPORTAR && soloEnLocal.length > 0) {
    console.log(`\n── IMPORTANDO ${soloEnLocal.length} eventos a Firestore... ─────`);
    let ok = 0, err = 0;
    for (const ev of soloEnLocal) {
      const docId = `local_ev_${ev.id}`;
      const ref = db.collection('empresas').doc(EID).collection('eventos').doc(docId);
      try {
        if (!FORZAR) {
          const s = await ref.get();
          if (s.exists) { console.log(`  · local_ev_${ev.id} ya existe`); continue; }
        }
        const { _local_id, ...doc } = mapearLocal(ev);
        await ref.set(doc, { merge: true });
        console.log(`  ✓ local_ev_${ev.id}  ${ev.titulo}`);
        ok++;
      } catch (e) {
        console.error(`  ✗ local_ev_${ev.id}: ${e.message}`);
        err++;
      }
    }
    console.log(`\nImportados: ${ok}  Errores: ${err}`);
  } else if (IMPORTAR && soloEnLocal.length === 0) {
    console.log('\n✓ Todos los eventos locales ya están en Fluix.');
  } else if (soloEnLocal.length > 0) {
    console.log('\nEjecuta con --importar para subir los eventos que faltan.');
  }

  console.log('');
  process.exit(0);
})();
