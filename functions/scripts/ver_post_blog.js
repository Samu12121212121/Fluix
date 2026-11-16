/**
 * ver_post_blog.js  — inspecciona un post concreto
 * Uso: node scripts/ver_post_blog.js <slug>
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

const slug = process.argv[2];
if (!slug) { console.error('Uso: node scripts/ver_post_blog.js <slug>'); process.exit(1); }

(async () => {
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('slug', '==', slug).limit(1).get();
  if (snap.empty) { console.log('Post no encontrado:', slug); process.exit(1); }
  const d = snap.docs[0].data();

  console.log('\n── CAMPOS PRINCIPALES ────────────────────────────────────');
  console.log('titulo:     ', d.titulo);
  console.log('tipo:       ', d.tipo);
  console.log('');
  console.log('resumen (' + (d.resumen||'').length + 'c):');
  console.log(JSON.stringify(d.resumen || ''));
  console.log('');
  console.log('contenido (' + (d.contenido||'').length + 'c) — primeros 300c:');
  console.log(JSON.stringify((d.contenido || '').substring(0, 300)));
  console.log('');
  console.log('contenido_html (' + (d.contenido_html||'').length + 'c) — primeros 400c:');
  console.log(JSON.stringify((d.contenido_html || '').substring(0, 400)));
  console.log('');
  console.log('¿Es Quill Delta?', (d.contenido||'').trimStart().startsWith('[{'));
  console.log('imagen_url: ', d.imagen_url ? d.imagen_url.substring(0,80)+'...' : '(vacío)');
  process.exit(0);
})();
