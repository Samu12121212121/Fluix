/**
 * 7_generar_data_js.js
 * Genera public_html_acentuarte/data.js con snapshot estático de Firestore.
 * Igual que Nazarí usa libros-data.js / autores-data.js para evitar consultas
 * en cada visita — la web carga los datos sin coste de Firestore.
 *
 * Uso:
 *   cd functions
 *   node scripts/7_generar_data_js.js
 *
 * Regenerar antes de cada deploy. En producción el archivo se sube junto
 * con el resto del HTML a Hostinger.
 */
'use strict';
const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID_AC  = 'pU4wGaElcyoDR5dA0YNO';
const OUT_DIR = 'C:\\Users\\Samu\\Downloads\\public_html_acentuarte';

function ts2str(val) {
  if (!val) return null;
  if (val && typeof val.toDate === 'function') return val.toDate().toISOString();
  return val;
}

async function cargar(col) {
  const snap = await db.collection('empresas').doc(EID_AC).collection(col).get();
  const docs = [];
  snap.forEach(d => {
    const data = d.data();
    if (data.eliminado) return;
    // Normalize timestamps to strings
    Object.keys(data).forEach(k => {
      if (data[k] && typeof data[k].toDate === 'function') data[k] = ts2str(data[k]);
    });
    docs.push({ id: d.id, ...data });
  });
  return docs;
}

async function run() {
  console.log('Cargando datos de Firebase…');

  const [libros, autores, blog] = await Promise.all([
    cargar('catalogo_web'),
    cargar('autores'),
    cargar('blog'),
  ]);
  console.log(`  libros: ${libros.length} | autores: ${autores.length} | blog: ${blog.length}`);

  // ── Transformar a formato que usa app.js ────────────────────────────────────
  const books = libros
    .filter(l => l.activo !== false)
    .sort((a, b) => (a.titulo || '').localeCompare(b.titulo || '', 'es'))
    .map(l => ({
      id:             l.slug || l.id,
      name:           l.titulo || l.nombre || '',
      author:         l.autor  || l.campo_autor || '',
      image:          l.imagen || l.imagen_url  || '',
      desc:           l.sinopsis || l.descripcion || '',
      isbn:           l.isbn || l.isbn13 || '',
      precio:         l.precio || '',
      genero:         l.genero || l.categoria || '',
      coleccion:      l.coleccion || l.campo_coleccion || '',
      encuadernacion: l.encuadernacion || '',
      formato:        l.formato || '',
      url:            l.url || '',
      slug:           l.slug || l.id,
    }));

  const authorsArr = autores
    .filter(a => a.activo !== false)
    .sort((a, b) => (a.nombre || '').localeCompare(b.nombre || '', 'es'))
    .map(a => {
      const pubs = books
        .map((b, i) => ({ b, i }))
        .filter(x => x.b.author === (a.nombre || ''))
        .map(x => ({ name: x.b.name, image: x.b.image, bookIndex: x.i }));
      return {
        id:           a.slug || a.id,
        name:         a.nombre || '',
        image:        a.foto_url || a.imagen || '',
        bio:          a.bio || a.descripcion || '',
        publications: pubs,
        interviews:   a.entrevistas || [],
        role:         a.rol || '',
      };
    });

  const noticias = blog
    .filter(e => !e.eliminado && (e.tipo === 'noticia' || e.tipo === 'noticias'))
    .sort((a, b) => (b.fecha_publicacion || '').localeCompare(a.fecha_publicacion || ''))
    .map(e => ({
      id:      e.slug || e.id,
      titulo:  e.titulo || '',
      imagen:  e.imagen_url || e.imagen || '',
      resumen: e.resumen || e.descripcion || '',
      fecha:   e.fecha_publicacion || null,
      autor:   e.autor || '',
      slug:    e.slug || e.id,
    }));

  const entrevistas = blog
    .filter(e => !e.eliminado && (e.tipo === 'entrevista' || e.tipo === 'entrevistas'))
    .sort((a, b) => (b.fecha_publicacion || '').localeCompare(a.fecha_publicacion || ''))
    .map(e => ({
      id:      e.slug || e.id,
      titulo:  e.titulo || '',
      imagen:  e.imagen_url || e.imagen || '',
      resumen: e.resumen || e.descripcion || '',
      fecha:   e.fecha_publicacion || null,
      autor:   e.autor || '',
      slug:    e.slug || e.id,
    }));

  const payload = { books, authors: authorsArr, noticias, entrevistas };
  const js = `window.__DATA__ = ${JSON.stringify(payload)};\n`;

  const outPath = path.join(OUT_DIR, 'data.js');
  fs.writeFileSync(outPath, js, 'utf8');
  const kb = Math.round(fs.statSync(outPath).size / 1024);
  console.log(`✅ data.js generado: ${outPath} (${kb} KB)`);
  console.log(`   books: ${books.length} | authors: ${authorsArr.length} | noticias: ${noticias.length} | entrevistas: ${entrevistas.length}`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
