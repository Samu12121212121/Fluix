const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
const fs    = require('fs');
const vm    = require('vm');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE_IMG = 'https://seashell-boar-580681.hostingersite.com';
const BASE_DIR = 'C:\\Users\\Samu\\Downloads\\editorial-nazari-html';

function loadJs(file, varName) {
  // const/let no se asignan al contexto de vm → reemplazar por var o usar eval
  let code = fs.readFileSync(`${BASE_DIR}\\${file}`, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx[varName];
}

const LIBROS  = loadJs('libros-data.js',  'LIBROS');
const AUTORES = loadJs('autores-data.js', 'AUTORES');

async function migrar() {
  console.log(`📚 Migrando ${LIBROS.length} libros...`);
  for (const libro of LIBROS) {
    const slug = libro.slug;
    if (!slug) { console.warn('⚠ Sin slug:', libro.titulo); continue; }
    await db.collection('empresas').doc(EID).collection('libros').doc(slug).set({
      slug, titulo: libro.titulo||'', autor: libro.autor||'',
      autor_extra: libro.autorExtra||null, genero: libro.genero||'',
      precio: libro.precio||'', coleccion: libro.coleccion||'',
      paginas: libro.paginas||0, anio: libro.anio||0, mes: libro.mes||'',
      isbn: libro.isbn||'', formato: libro.formato||'', dimensiones: libro.dimensiones||'',
      imagen: libro.imagen||'',
      imagen_url: libro.imagen ? `${BASE_IMG}/${libro.imagen}` : '',
      sinopsis: libro.sinopsis||'', bio_autor: libro.bio||'',
      tag: libro.tag||null, activo: true, eliminado: false,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('  ✅', libro.titulo);
  }

  console.log(`\n👤 Migrando ${AUTORES.length} autores...`);
  for (const autor of AUTORES) {
    const docId = String(autor.id);
    await db.collection('empresas').doc(EID).collection('autores').doc(docId).set({
      nombre: autor.nombre||'', genero: autor.genero||'', lugar: autor.lugar||'',
      descripcion: autor.descripcion||'', bio: autor.bio||'',
      foto: autor.foto||'',
      foto_url: autor.foto ? `${BASE_IMG}/${autor.foto}` : '',
      activo: true, eliminado: false,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('  ✅', autor.nombre);
  }

  console.log('\n🎉 Migración completada.');
  process.exit(0);
}

migrar().catch(e => { console.error('❌', e.message); process.exit(1); });
