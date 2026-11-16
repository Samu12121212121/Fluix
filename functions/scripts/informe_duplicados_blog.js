/**
 * informe_duplicados_blog.js
 * Genera un informe de las noticias 126-225 mostrando:
 *  - Lo que aparece ANTES de la foto (resumen del hero)
 *  - Lo que aparece DESPUÉS de la foto (inicio del contenido)
 *  - Si hay duplicación
 *
 * Uso: node scripts/informe_duplicados_blog.js
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

function norm(s = '') {
  return s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[«»'"''""]/g, '')
    .replace(/\s+/g, ' ').trim();
}
function primeros(s, n) {
  return (s || '').replace(/<[^>]+>/g, '').replace(/\s+/g,' ').trim().substring(0, n);
}

(async () => {
  // Cargar todas las noticias ordenadas por fecha desc
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'noticia')
    .orderBy('fecha_publicacion', 'desc')
    .get();

  const todas = [];
  snap.forEach(doc => todas.push({ id: doc.id, ...doc.data() }));

  console.log(`Total noticias: ${todas.length}\n`);

  const desde = 125; // índice 0-based → noticia 126
  const hasta = 225; // noticia 225
  const lote  = todas.slice(desde, hasta);

  console.log(`Mostrando noticias ${desde + 1} a ${Math.min(hasta, todas.length)} de ${todas.length}\n`);
  console.log('═'.repeat(80));

  let nDuplicados = 0;

  lote.forEach((post, i) => {
    const num     = desde + i + 1;
    const resumen = (post.resumen || '').trim();
    const rawHtml = post.contenido_html || '';
    const cont    = post.contenido    || '';

    // Lo que sale después de la foto
    const esQuill  = cont.trimStart().startsWith('[{');
    const esHtml   = !esQuill && /<(h[1-6]|p|div|ul|ol)[^>]*>/i.test(cont);
    const fuente   = rawHtml || (esHtml ? cont : '');
    const bodyText = primeros(fuente || cont, 200);

    // Detección de duplicación — busca si el body CONTIENE el resumen o el título
    const normRes   = norm(resumen).substring(0, 120);
    const normBody  = norm(fuente || cont); // body completo normalizado
    const normTit   = norm(post.titulo || '').substring(0, 80);
    const repiteRes = normRes.length > 30 && normBody.includes(normRes.substring(0, 80));
    const repiteTit = normTit.length > 20 && normBody.includes(normTit.substring(0, 40));
    const duplicado = repiteRes || repiteTit;

    if (duplicado) nDuplicados++;

    // Buscar repetición en TODO el body (no solo inicio/final)
    const normBodyFull = norm(fuente || cont);  // body completo normalizado
    const repiteResAll = normRes.length > 30 && normBodyFull.includes(normRes.substring(0, 80));
    const repiteTitAll = normTit.length > 20 && normBodyFull.includes(normTit.substring(0, 40));
    const anyDuplicado = repiteResAll || repiteTitAll;
    if (anyDuplicado) nDuplicados++;

    const marca = anyDuplicado ? '⚠️ DUPLICADO' : '✓';

    console.log(`\n[${num}] ${marca}  ${post.titulo || '(sin título)'}`);
    console.log(`  slug: ${post.id}`);
    console.log(`  ANTES foto (resumen):     "${resumen.substring(0, 100)}${resumen.length > 100 ? '…' : ''}"`);
    console.log(`  DESPUÉS foto (inicio):    "${bodyText.substring(0, 100)}${bodyText.length > 100 ? '…' : ''}"`);
    if (anyDuplicado) {
      if (repiteTitAll) console.log(`  → título repetido en el body`);
      if (repiteResAll) console.log(`  → resumen repetido en el body`);
    }
  });

  console.log(`\n${'═'.repeat(80)}`);
  console.log(`Total con duplicación: ${nDuplicados} de ${lote.length}`);
  console.log('');
  process.exit(0);
})();
