/**
 * arreglar_links_video_blog.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Para cada entrada del blog de Nazarí que tenga video_url definido,
 * busca en contenido_html frases como "podéis ver el vídeo aquí" (y variantes)
 * y las convierte en <a href="video_url">...</a>.
 *
 * Uso: node scripts/arreglar_links_video_blog.js
 * Para ver qué cambiaría sin modificar nada: node scripts/arreglar_links_video_blog.js --dry-run
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const DRY_RUN = process.argv.includes('--dry-run');

// Frases a enlazar (orden: más específicas primero)
const PATRONES = [
  'podéis ver el vídeo aquí',
  'podeis ver el video aqui',
  'podéis ver el video aquí',
  'podeis ver el vídeo aquí',
  'ver el vídeo aquí',
  'ver el video aquí',
  'ver el video aqui',
  '(ver vídeo)',
  '(ver video)',
  'ver el vídeo',
  'ver el video',
];

function autoLinkVideo(html, videoUrl) {
  let result = html;
  for (const patron of PATRONES) {
    const re = new RegExp(patron.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
    result = result.replace(re, (matched, offset) => {
      // No doble-enlazar si ya está dentro de <a
      const before = result.substring(0, offset);
      const lastOpen  = before.lastIndexOf('<a ');
      const lastClose = before.lastIndexOf('</a>');
      if (lastOpen > lastClose) return matched;
      return `<a href="${videoUrl}" target="_blank" rel="noopener">${matched}</a>`;
    });
  }
  return result;
}

async function main() {
  console.log(`\n${'='.repeat(60)}`);
  console.log(DRY_RUN ? '  DRY RUN — sin modificaciones' : '  MODO REAL — se escribirá en Firestore');
  console.log('='.repeat(60));

  const snap = await db
    .collection('empresas').doc(EID)
    .collection('blog')
    .where('eliminado', '==', false)
    .get();

  console.log(`\nTotal entradas: ${snap.size}`);

  let conVideo   = 0;
  let modificados = 0;
  let sinCambios = 0;
  const batch = { ops: [], commit: async () => {} };

  const writes = [];

  for (const doc of snap.docs) {
    const d   = doc.data();
    let videoUrl = d.video_url || null;

    const html = d.contenido_html || d.contenido || '';

    // Si no tiene video_url guardado, intentar extraerlo del HTML
    if (!videoUrl && html) {
      const ytMatch = html.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
      if (ytMatch) videoUrl = `https://www.youtube.com/watch?v=${ytMatch[1]}`;
      if (!videoUrl) {
        const vimeoMatch = html.match(/vimeo\.com\/(\d+)/);
        if (vimeoMatch) videoUrl = `https://vimeo.com/${vimeoMatch[1]}`;
      }
    }

    if (!videoUrl) continue;
    conVideo++;

    if (!html) continue;

    const htmlNuevo = autoLinkVideo(html, videoUrl);
    if (htmlNuevo === html) {
      sinCambios++;
      continue;
    }

    modificados++;
    console.log(`\n✏️  ${doc.id.substring(0, 8)}… "${(d.titulo || '').substring(0, 50)}"`);
    console.log(`   video_url: ${videoUrl.substring(0, 60)}`);

    if (!DRY_RUN) {
      const updateData = { contenido_html: htmlNuevo };
      // Si video_url no estaba guardado, añadirlo también
      if (!d.video_url && videoUrl) updateData.video_url = videoUrl;
      // Si no hay imagen pero hay YT, guardar thumbnail
      if (!d.imagen_url && !d.imagen && videoUrl && videoUrl.includes('youtube')) {
        const m = videoUrl.match(/watch\?v=([a-zA-Z0-9_-]{11})/);
        if (m) updateData.imagen_url = `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg`;
      }
      writes.push(doc.ref.update(updateData));
    }
  }

  if (!DRY_RUN && writes.length > 0) {
    // Ejecutar en lotes de 20 para no saturar
    for (let i = 0; i < writes.length; i += 20) {
      await Promise.all(writes.slice(i, i + 20));
      console.log(`  Lote ${Math.floor(i/20) + 1}/${Math.ceil(writes.length/20)} guardado`);
    }
  }

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`Entradas con video_url: ${conVideo}`);
  console.log(`Modificadas:            ${modificados}`);
  console.log(`Sin cambios (ya ok):    ${sinCambios}`);
  if (DRY_RUN) {
    console.log('\n⚠️  DRY RUN: ejecuta sin --dry-run para aplicar los cambios');
  } else {
    console.log('\n✅ Listo');
  }
}

main().catch(e => { console.error(e); process.exit(1); });
