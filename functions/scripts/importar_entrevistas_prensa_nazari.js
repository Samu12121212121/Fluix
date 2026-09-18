/**
 * importar_entrevistas_prensa_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Importa las 329 entrevistas de prensa de entrevistas.html a la colección
 * `blog` de Firestore (empresa 0PoomHYDUJf5w8tDFRLhFi9iURF3).
 *
 * - tipo: 'entrevista'
 * - Usa el slug de la URL como ID del documento (no crea duplicados)
 * - Salta los que ya existen en Firestore
 * - Admite --forzar para sobreescribir los existentes
 *
 * Uso:
 *   cd functions
 *   node scripts/importar_entrevistas_prensa_nazari.js
 *   node scripts/importar_entrevistas_prensa_nazari.js --forzar
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const vm    = require('vm');
const path  = require('path');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const FORZAR = process.argv.includes('--forzar');

// ── Leer entrevistas.html y extraer el array ENTREVISTAS ─────────────────────
function cargarEntrevistasDelHtml() {
  const htmlPath = path.resolve(
    __dirname,
    '../../../../Desktop/imagenes_nazari/html_nazari/entrevistas.html'
  );
  const html = fs.readFileSync(htmlPath, 'utf8');
  const match = html.match(/var ENTREVISTAS\s*=\s*(\[[\s\S]*?\]);/);
  if (!match) throw new Error('No se encontró el array ENTREVISTAS en entrevistas.html');
  const sandbox = {};
  vm.runInNewContext('var ENTREVISTAS = ' + match[1], sandbox);
  return sandbox.ENTREVISTAS;
}

// ── Slug desde URL ────────────────────────────────────────────────────────────
function slugDesdeUrl(url) {
  return url.replace(/\/$/, '').split('/').pop() || '';
}

// ── Importar ──────────────────────────────────────────────────────────────────
async function run() {
  const entrevistas = cargarEntrevistasDelHtml();
  console.log(`📋 ${entrevistas.length} entrevistas cargadas del HTML\n`);

  const col = db.collection('empresas').doc(EID).collection('blog');

  let creadas = 0, saltadas = 0, errores = 0;

  for (const e of entrevistas) {
    const slug = slugDesdeUrl(e.l);
    if (!slug) { errores++; continue; }

    const ref = col.doc(slug);

    if (!FORZAR) {
      const snap = await ref.get();
      if (snap.exists) {
        saltadas++;
        continue;
      }
    }

    const fecha = e.f ? new Date(e.f + 'T12:00:00') : new Date();

    try {
      await ref.set({
        titulo:            e.t,
        slug,
        tipo:              'entrevista',
        publicada:         true,
        url_externa:       e.l,
        fecha_publicacion: admin.firestore.Timestamp.fromDate(fecha),
        wp_id:             e.id || null,
        resumen:           '',
        imagen_url:        '',
        autor:             '',
        guardado_en:       admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: FORZAR });

      creadas++;
      if (creadas % 20 === 0) console.log(`  … ${creadas} importadas`);
    } catch (err) {
      console.error(`  ❌ Error en "${e.t}": ${err.message}`);
      errores++;
    }
  }

  console.log(`\n✅ Importación completada:`);
  console.log(`   Creadas:  ${creadas}`);
  console.log(`   Saltadas: ${saltadas} (ya existían)`);
  console.log(`   Errores:  ${errores}`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
