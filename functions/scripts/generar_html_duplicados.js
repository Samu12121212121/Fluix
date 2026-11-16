/**
 * Genera revision_duplicados_blog.html cruzando:
 *  - Firestore (contenido real de cada noticia)
 *  - wp_excerpts.json (resumen COMPLETO sin truncar del backup de WordPress)
 *
 * Uso: cd functions && node scripts/generar_html_duplicados.js
 */
const admin = require('firebase-admin');
const fs    = require('fs');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

const WP_POSTS = JSON.parse(
  fs.readFileSync('C:/Users/Samu/Downloads/wp_posts_completo.json', 'utf8')
);
const OUT = 'C:/Users/Samu/Desktop/revision_duplicados_blog.html';

function quillToText(c) {
  try { return JSON.parse(c).map(op => typeof op.insert === 'string' ? op.insert : '').join('').replace(/\n/g, ' ').trim(); }
  catch { return ''; }
}
function htmlToText(c) {
  return (c || '')
    .replace(/<\/p>/gi, '\n').replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/div>/gi, '\n').replace(/<\/li>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n[ \t]+/g, '\n').replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}
function getTexto(c) {
  if (!c) return '';
  const t = c.trim();
  if (t.startsWith('[{')) return quillToText(t);
  return htmlToText(t);
}
function limpiarResumen(r) {
  return r.replace(/\s*\[(&hellip;|…|\.\.\.|…)\]\s*$/, '')
          .replace(/\s*\[…\]\s*$/, '').replace(/\s*…\s*$/, '')
          .replace(/\s*\.\.\.\s*$/, '').trim();
}
function esc(s) { return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

(async () => {
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'noticia').get();

  const casos = [];

  snap.forEach(doc => {
    const d = doc.data();
    if (d.eliminado === true) return;

    const slug   = doc.id;
    const wpPost = WP_POSTS[slug];

    // Contenido con saltos de línea (para mostrar)
    const wpContent   = wpPost ? htmlToText(wpPost.content) : '';
    const contenido   = (wpContent.length > 50 ? wpContent : null) || getTexto(d.contenido);
    if (!contenido || contenido.length < 30) return;
    // Versión normalizada (para buscar): sin newlines ni espacios dobles
    const contenidoNorm = contenido.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

    // Resumen: preferir excerpt WP, si no el de Firestore
    const resumenWP       = wpPost && wpPost.excerpt ? limpiarResumen(wpPost.excerpt.replace(/\s+/g, ' ')) : '';
    const resumenFirebase = limpiarResumen((d.resumen || '').replace(/\s+/g, ' ').trim());
    const resumenBuscar   = resumenWP || resumenFirebase;

    if (!resumenBuscar || resumenBuscar.length < 30) return;

    const frag = resumenBuscar.substring(0, Math.min(resumenBuscar.length, 60));
    // Buscar en la versión normalizada
    const idx  = contenidoNorm.indexOf(frag);
    if (idx === -1 || idx > 200) return;

    // Calcular finResumen en contenidoNorm, luego aplicar a contenido (mismos índices, 1:1)
    let finResumen = idx + resumenBuscar.length;

    if (wpPost && wpPost.content) {
      // Primer párrafo del HTML de WP → convertir a texto normalizado y medir su longitud
      const parrafoEnd = wpPost.content.indexOf('</p>');
      if (parrafoEnd !== -1) {
        const parrafoNorm = wpPost.content.substring(0, parrafoEnd + 4)
          .replace(/\n/g, ' ').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
        if (parrafoNorm.length > resumenBuscar.length) {
          finResumen = idx + parrafoNorm.length;
        }
      }
    }
    // Extender en contenidoNorm hasta el primer punto seguido después de finResumen
    const puntoIdx = contenidoNorm.indexOf('. ', finResumen);
    if (puntoIdx !== -1 && puntoIdx - finResumen < 200) finResumen = puntoIdx + 1;

    // Asegurarse de no sobrepasar la longitud del contenido
    finResumen = Math.min(finResumen, contenido.length);

    casos.push({
      id:            slug,
      titulo:        d.titulo,
      parteAntes:    contenido.substring(0, idx),
      parteEliminar: contenido.substring(idx, finResumen),
      parteDespues:  contenido.substring(finResumen),
    });
  });

  const muestra = casos; // todos los casos
  console.log('Total casos: ' + casos.length + ' | Mostrando: ' + muestra.length);

  let html = `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8">
<title>Revisión duplicados blog — ${muestra.length} de ${casos.length}</title>
<style>
  body  { font-family: Arial, sans-serif; font-size: 13px; margin: 30px; color: #222; }
  h1    { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; }
  .post { border: 1px solid #ccc; border-radius: 6px; margin-bottom: 28px; padding: 14px 18px; page-break-inside: avoid; }
  .post-title { font-size: 14px; font-weight: bold; color: #1a1a8c; margin-bottom: 4px; }
  .slug  { font-size: 10px; color: #999; margin-bottom: 8px; }
  .label { font-size: 11px; font-weight: bold; text-transform: uppercase; color: #666; margin: 10px 0 4px; }
  .resumen-box   { background: #fff8dc; border-left: 4px solid #f5c518; padding: 8px 12px; border-radius: 3px; white-space: pre-wrap; word-break: break-word; }
  .resumen-box.wp { border-color: #e6a800; }
  .contenido-box { background: #f9f9f9; border-left: 4px solid #aaa; padding: 8px 12px; border-radius: 3px; white-space: pre-wrap; word-break: break-word; }
  mark  { background: #ffe066; padding: 1px 2px; border-radius: 2px; }
  .n    { color: #888; font-size: 11px; float: right; }
  .intro { background: #eef; padding: 12px 16px; border-radius: 6px; margin-bottom: 24px; }
  .badge-wp { background: #e6a800; color: #fff; font-size: 10px; padding: 1px 5px; border-radius: 3px; margin-left: 6px; }
</style></head><body>
<h1>Noticias con resumen duplicado al inicio del contenido — ${muestra.length} de ${casos.length}</h1>
<div class="intro">
  🟡 <b>Resumen</b>: texto completo de WordPress <span class="badge-wp">WP</span> (el que aparece encima de la foto, no se modifica).<br>
  <mark>Amarillo en Contenido</mark>: parte que se eliminará del campo contenido. Lo que sigue es lo que queda.
</div>`;

  muestra.forEach((c, i) => {
    // El recuadro del resumen siempre muestra parteEliminar: es exactamente lo que está
    // en el contenido y que se va a borrar — el texto completo, sin truncar
    html += `
<div class="post">
  <div class="post-title"><span class="n">#${i + 1}/${muestra.length}</span>${esc(c.titulo)}</div>
  <div class="slug">ID: ${esc(c.id)}</div>
  <div class="label">🟡 Texto duplicado que aparece encima de la foto y también en el contenido</div>
  <div class="resumen-box wp">${esc(c.parteEliminar)}</div>
  <div class="label">Contenido completo — <mark>amarillo = se elimina</mark></div>
  <div class="contenido-box">${c.parteAntes ? '<mark>' + esc(c.parteAntes) + '</mark>' : ''}<mark>${esc(c.parteEliminar)}</mark>${esc(c.parteDespues)}</div>
</div>`;
  });

  html += '</body></html>';
  fs.writeFileSync(OUT, html, 'utf8');
  console.log('Guardado: ' + OUT);
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
