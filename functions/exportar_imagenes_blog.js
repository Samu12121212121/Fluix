/**
 * exportar_imagenes_blog.js
 * Consulta Firestore y exporta las imagen_url de todas las entradas
 * de tipo 'entrevista' y 'noticia' para la empresa de Nazarí.
 *
 * Uso:
 *   node exportar_imagenes_blog.js
 *   node exportar_imagenes_blog.js --out C:\ruta\salida.json
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');

const EID  = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const OUT  = process.argv.find(a => a.startsWith('--out='))?.split('=')[1]
           || path.join(os.homedir(), 'Downloads', 'blog_imagenes_export.json');

// ── Credenciales ──────────────────────────────────────────────────────────────
function initFirebase() {
  const saPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    const sa = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(sa) });
    return;
  }
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  for (const p of candidates) {
    try {
      const d = JSON.parse(fs.readFileSync(p, 'utf8'));
      const rt = d?.tokens?.refresh_token;
      if (rt) {
        admin.initializeApp({
          credential: admin.credential.refreshToken({
            type: 'authorized_user',
            client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
            client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p',
            refresh_token: rt,
          }),
          projectId: 'planeaapp-4bea4',
        });
        return;
      }
    } catch (_) {}
  }
  console.error('❌ No se encontró serviceAccountKey.json ni token de Firebase CLI.');
  process.exit(1);
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  initFirebase();
  const db = admin.firestore();
  const col = db.collection('empresas').doc(EID).collection('blog');

  console.log('🔍 Consultando Firestore (colección blog)…');
  const snap = await col.get();
  console.log(`   Total documentos: ${snap.size}`);

  const noticias    = [];
  const entrevistas = [];
  const otros       = [];

  snap.forEach(doc => {
    const d = doc.data();
    const tipo = (d.tipo || d.categoria_id || '').toLowerCase();
    const fechaRaw = d.fecha_publicacion || d.fecha || '';
    const fecha = (fechaRaw && typeof fechaRaw.toDate === 'function')
      ? fechaRaw.toDate().toISOString().substring(0, 10)
      : String(fechaRaw).substring(0, 10);
    const entry = {
      id:          doc.id,
      slug:        d.slug || '',
      titulo:      d.titulo || d.title || '',
      fecha,
      imagen_url:  d.imagen_url || d.thumbnail_url || '',
      imagenes:    Array.isArray(d.imagenes) ? d.imagenes : [],
      tipo,
    };

    if (tipo === 'noticia' || tipo === 'noticias') {
      noticias.push(entry);
    } else if (tipo === 'entrevista' || tipo === 'entrevistas') {
      entrevistas.push(entry);
    } else {
      otros.push(entry);
    }
  });

  // Ordenar por fecha desc
  const byFecha = (a, b) => (b.fecha || '').localeCompare(a.fecha || '');
  noticias.sort(byFecha);
  entrevistas.sort(byFecha);

  // Estadísticas
  const entConImg = entrevistas.filter(e => e.imagen_url).length;
  const notConImg = noticias.filter(n => n.imagen_url || n.imagenes.length > 0).length;

  console.log(`\n📰 NOTICIAS:    ${noticias.length} total, ${notConImg} con imagen`);
  console.log(`🎤 ENTREVISTAS: ${entrevistas.length} total, ${entConImg} con imagen`);
  console.log(`📦 Otros tipos: ${otros.length}`);

  // Mostrar entrevistas con imagen
  console.log('\n=== ENTREVISTAS CON imagen_url ===');
  entrevistas.filter(e => e.imagen_url).forEach((e, i) => {
    const fname = e.imagen_url.split('/').pop().split('?')[0];
    console.log(`  [${i+1}] ${e.fecha} | ${e.titulo.substring(0,50)}`);
    console.log(`        ${fname}`);
  });

  // Mostrar noticias con imagen
  console.log('\n=== NOTICIAS CON imagen_url ===');
  noticias.filter(n => n.imagen_url || n.imagenes.length > 0).forEach((n, i) => {
    const fname = n.imagen_url ? n.imagen_url.split('/').pop().split('?')[0] : '';
    const extra = n.imagenes.length > 0 ? ` + ${n.imagenes.length} en galería` : '';
    console.log(`  [${i+1}] ${n.fecha} | ${n.titulo.substring(0,50)}`);
    if (fname) console.log(`        portada: ${fname}${extra}`);
    if (n.imagenes.length > 0) {
      n.imagenes.forEach(u => console.log(`        galería: ${u.split('/').pop().split('?')[0]}`));
    }
  });

  // Guardar JSON completo
  const output = { noticias, entrevistas, otros, generado: new Date().toISOString() };
  fs.writeFileSync(OUT, JSON.stringify(output, null, 2), 'utf8');
  console.log(`\n✅ Exportado a: ${OUT}`);
}

main().catch(e => { console.error(e); process.exit(1); });
