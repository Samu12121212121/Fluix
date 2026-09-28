/**
 * rellenar_imagenes_noticias.js
 * Rellena video_url (YouTube) e imagen_url (portada libro) para noticias sin imagen.
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const DRY = process.argv.includes('--dry-run');

function ytId(html) {
  const m = (html||'').match(/youtu(?:\.be\/|be\.com\/(?:embed\/|watch\?v=|v\/))([A-Za-z0-9_-]{11})/i);
  return m ? m[1] : null;
}

async function main() {
  console.log(`\n${DRY?'[DRY-RUN] ':''}Rellenando imágenes/videos para noticias\n`);

  const librosSnap = await db.collection('empresas').doc(EID).collection('libros').get();
  const librosPorId = {}, librosPorAutor = {};
  librosSnap.docs.forEach(d => {
    const x = d.data();
    const img = x.imagen_url || x.portada_url;
    if (!img) return;
    librosPorId[d.id] = img;
    if (x.autor) librosPorAutor[x.autor.toLowerCase().trim()] = librosPorAutor[x.autor.toLowerCase().trim()] || img;
    (x.autores||[]).forEach(a => {
      const k = (a.nombre||'').toLowerCase().trim();
      if (k) librosPorAutor[k] = librosPorAutor[k] || img;
    });
  });

  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo','==','noticia').get();
  const sinImg = snap.docs.filter(d => {
    const x = d.data();
    return !x.imagen_url && !x.thumbnail_url && !x.video_url;
  });
  console.log(`Noticias sin imagen/video: ${sinImg.length}\n`);

  let porYt=0, porLibro=0, sinSol=0;
  const updates = [];

  for (const doc of sinImg) {
    const x = doc.data();
    const titulo = (x.titulo||doc.id).substring(0,60);
    let update = null;

    // 1. YouTube en contenido → guardar como video_url
    const yt = ytId(x.contenido);
    if (yt) {
      update = { video_url: `https://www.youtube.com/watch?v=${yt}` };
      console.log(`  ✓ [YouTube ${yt}] ${titulo}`);
      porYt++;
    }
    // 2. Portada por libro_id
    else if (x.libro_id && librosPorId[x.libro_id]) {
      update = { imagen_url: librosPorId[x.libro_id] };
      console.log(`  ✓ [libro] ${titulo}`);
      porLibro++;
    }
    // 3. Portada por autor
    else if (x.autor && librosPorAutor[x.autor.toLowerCase().trim()]) {
      update = { imagen_url: librosPorAutor[x.autor.toLowerCase().trim()] };
      console.log(`  ✓ [autor] ${titulo}`);
      porLibro++;
    } else {
      console.log(`  ✗ sin solución: ${titulo}`);
      sinSol++;
    }

    if (update) updates.push({ id: doc.id, update });
  }

  console.log(`\n── Resumen ───────────────────────────`);
  console.log(`  YouTube (video_url): ${porYt}`);
  console.log(`  Portada libro:       ${porLibro}`);
  console.log(`  Sin solución:        ${sinSol}`);
  console.log(`  Total a guardar:     ${updates.length}`);

  if (DRY) { console.log('\n[DRY-RUN] No guardado.\n'); return; }

  console.log('\nGuardando...');
  let ok=0, err=0;
  for (const { id, update } of updates) {
    try {
      await db.collection('empresas').doc(EID).collection('blog').doc(id).update(update);
      ok++;
    } catch(e) { console.error(`  ✗ ${id}: ${e.message}`); err++; }
  }
  console.log(`\n═══════════════════════════════════`);
  console.log(` Guardadas: ${ok}  Errores: ${err}`);
  console.log(`═══════════════════════════════════\n`);
}
main().catch(e => { console.error(e); process.exit(1); });
