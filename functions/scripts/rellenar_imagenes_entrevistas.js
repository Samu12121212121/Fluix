/**
 * rellenar_imagenes_entrevistas.js — actualiza imagen_url en Firestore
 * Estrategia (sin peticiones HTTP externas bloqueadas):
 *   1. YouTube en contenido  → thumbnail de YouTube
 *   2. libro_id o autor      → portada del libro en libros/catalogo_web
 *
 * Uso:
 *   node scripts/rellenar_imagenes_entrevistas.js             (real)
 *   node scripts/rellenar_imagenes_entrevistas.js --dry-run   (solo muestra)
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const DRY = process.argv.includes('--dry-run');

function ytIdFromHtml(html) {
  if (!html) return null;
  const m = html.match(/youtu(?:\.be\/|be\.com\/(?:embed\/|watch\?v=|v\/))([A-Za-z0-9_-]{11})/i);
  return m ? m[1] : null;
}

function ytThumb(id) {
  return `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
}

async function main() {
  console.log(`\n${DRY ? '[DRY-RUN] ' : ''}Rellenando imagen_url para entrevistas sin imagen\n`);

  // Cargar libros (portadas) indexados por id y por título normalizado de autor
  const librosSnap = await db.collection('empresas').doc(EID).collection('libros').get();
  const librosPorId    = {};
  const librosPorAutor = {};
  librosSnap.docs.forEach(d => {
    const x = d.data();
    if (x.imagen_url || x.portada_url) {
      librosPorId[d.id] = x.imagen_url || x.portada_url;
      if (x.autores) {
        x.autores.forEach(a => {
          const k = (a.nombre||'').toLowerCase().trim();
          if (k) librosPorAutor[k] = librosPorAutor[k] || (x.imagen_url || x.portada_url);
        });
      }
      if (x.autor) {
        const k = x.autor.toLowerCase().trim();
        librosPorAutor[k] = librosPorAutor[k] || (x.imagen_url || x.portada_url);
      }
    }
  });
  console.log(`Libros cargados: ${librosSnap.size} (con portada: ${Object.keys(librosPorId).length})\n`);

  // Cargar entrevistas sin imagen
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'entrevista').get();
  const sinImg = snap.docs.filter(d => {
    const x = d.data();
    return !x.imagen_url && !x.thumbnail_url;
  });
  console.log(`Entrevistas sin imagen: ${sinImg.length}\n`);

  let porYt = 0, porLibro = 0, sinSolucion = 0;
  const actualizaciones = [];

  for (const doc of sinImg) {
    const data = doc.data();
    const titulo = (data.titulo || doc.id).substring(0, 60);
    let imgUrl = null;
    let fuente = '';

    // ── Estrategia 1: YouTube en contenido ───────────────────────
    const ytId = ytIdFromHtml(data.contenido);
    if (ytId) {
      imgUrl = ytThumb(ytId);
      fuente = `YouTube ${ytId}`;
      porYt++;
    }

    // ── Estrategia 2: portada del libro por libro_id ─────────────
    if (!imgUrl && data.libro_id) {
      imgUrl = librosPorId[data.libro_id];
      if (imgUrl) { fuente = `libro_id=${data.libro_id}`; porLibro++; }
    }

    // ── Estrategia 3: portada por autor ──────────────────────────
    if (!imgUrl && data.autor) {
      const k = data.autor.toLowerCase().trim();
      imgUrl = librosPorAutor[k];
      if (imgUrl) { fuente = `autor="${data.autor}"`; porLibro++; }
    }

    if (imgUrl) {
      console.log(`  ✓ [${fuente}]`);
      console.log(`    ${titulo}`);
      console.log(`    → ${imgUrl.substring(0, 80)}`);
      actualizaciones.push({ id: doc.id, imgUrl });
    } else {
      console.log(`  ✗ sin solución: ${titulo}`);
      sinSolucion++;
    }
  }

  console.log(`\n── Resumen ──────────────────────────────`);
  console.log(`  Por YouTube    : ${porYt}`);
  console.log(`  Por libro/autor: ${porLibro}`);
  console.log(`  Sin solución   : ${sinSolucion}`);
  console.log(`  Total a guardar: ${actualizaciones.length}`);

  if (DRY) {
    console.log(`\n[DRY-RUN] No se ha modificado nada.\n`);
    return;
  }

  // Escribir en Firestore
  console.log(`\nGuardando en Firestore...`);
  let ok = 0, err = 0;
  for (const { id, imgUrl } of actualizaciones) {
    try {
      await db.collection('empresas').doc(EID).collection('blog')
        .doc(id).update({ imagen_url: imgUrl });
      ok++;
    } catch (e) {
      console.error(`  ✗ error ${id}: ${e.message}`);
      err++;
    }
  }

  console.log(`\n══════════════════════════════════════════`);
  console.log(` Guardadas: ${ok}  Errores: ${err}`);
  console.log(`══════════════════════════════════════════\n`);
}

main().catch(e => { console.error(e); process.exit(1); });
