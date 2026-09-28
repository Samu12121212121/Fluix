/**
 * escalar_imagenes_blog.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Reemplaza todas las URLs rotas de WordPress en la colección blog por
 * imágenes subidas a Firebase Storage desde las carpetas locales.
 *
 * Estrategia:
 *   1. Para cada post con URL WP rota: extrae el nombre de archivo de la URL
 *   2. Busca ese archivo en las carpetas locales (noticias, entrevistas, media)
 *   3. Busca también las hermanas numeradas (foto-01, foto-02, …)
 *   4. Sube todas a Firebase Storage (salta si ya existe)
 *   5. Actualiza imagen_url + thumbnail_url + galeria en Firestore
 *
 * Uso:
 *   node scripts/escalar_imagenes_blog.js --dry-run    ← solo muestra lo que haría
 *   node scripts/escalar_imagenes_blog.js              ← ejecuta todo
 *   node scripts/escalar_imagenes_blog.js --tipo noticia
 *   node scripts/escalar_imagenes_blog.js --tipo entrevista
 * ─────────────────────────────────────────────────────────────────────────────
 */
'use strict';

const admin  = require('firebase-admin');
const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');

const args   = process.argv.slice(2);
const DRY    = args.includes('--dry-run');
const TIPO   = args.includes('--tipo') ? args[args.indexOf('--tipo')+1] : null;

const EID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET = 'planeaapp-4bea4.firebasestorage.app';

const CARPETAS = [
  path.join('C:','Users','Samu','Downloads','imagenes_noticias'),
  path.join('C:','Users','Samu','Downloads','imagenes_entrevistas'),
  path.join('C:','Users','Samu','Downloads','media_library_export-editorial_nazari-2026_09_23_16_33_23','media_library_export-editorial_nazari-2026_09_23_16_33_23'),
];

const saPath = path.join(__dirname,'..','serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(saPath)),
    storageBucket: BUCKET,
  });
}
const db     = admin.firestore();
const bucket = admin.storage().bucket();

// ── Índice de archivos locales (nombre → ruta absoluta) ───────────────────────
const indiceLocal = {};
for (const carpeta of CARPETAS) {
  if (!fs.existsSync(carpeta)) continue;
  for (const f of fs.readdirSync(carpeta)) {
    if (!indiceLocal[f]) indiceLocal[f] = path.join(carpeta, f);
  }
}
const nombresLocales = Object.keys(indiceLocal);
console.log(`Archivos locales indexados: ${nombresLocales.length}`);

// ── Extrae nombre de archivo de una URL de WP ─────────────────────────────────
function nombreDeUrl(url) {
  if (!url) return null;
  try { return decodeURIComponent(url.split('/').pop().split('?')[0]); } catch { return null; }
}

function esWP(url) {
  return (url||'').includes('editorialnazari.com/wp-content/');
}

function esFS(url) {
  return (url||'').includes('firebasestorage.googleapis.com');
}

// ── Busca un archivo en el índice (exacto o sin -scaledN) ─────────────────────
function encontrarLocal(nombre) {
  if (!nombre) return null;
  if (indiceLocal[nombre]) return nombre;
  // Quitar sufijos WordPress: -1024x768, -scaled, -300x225, etc.
  const sinScaled = nombre.replace(/-\d{2,4}x\d{2,4}(\.\w+)$/, '$1')
                          .replace(/-scaled(\.\w+)$/, '$1');
  if (sinScaled !== nombre && indiceLocal[sinScaled]) return sinScaled;
  return null;
}

// ── Encuentra hermanas numeradas SOLO dentro de la misma décena ──────────────
// Nazarí usa convención de décenas: 01-09 = evento 1, 11-19 = evento 2, etc.
// Para evitar mezclar fotos de distintos eventos del mismo libro.
function encontrarHermanas(nombreBase) {
  const ext  = path.extname(nombreBase);
  const sin  = nombreBase.slice(0, nombreBase.length - ext.length);
  // Extraer prefijo y número final (ej: "images_ERND-" + "21")
  const m = sin.match(/^(.*[-_])(\d{1,3})$/);
  if (!m) return [];
  const prefijo = m[1];
  const num     = parseInt(m[2], 10);
  if (prefijo.length < 4) return [];
  // Límite superior: misma décena (num=21 → máx 29; num=1 → máx 9)
  const decena  = Math.floor(num / 10) * 10;
  const maxNum  = decena + 9;
  const reEscape = prefijo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp('^' + reEscape + '(\\d{1,3})' + ext.replace('.', '\\.') + '$', 'i');
  return nombresLocales.filter(f => {
    if (f === nombreBase) return false;
    const fm = f.match(re);
    if (!fm) return false;
    const fNum = parseInt(fm[1], 10);
    return fNum > num && fNum <= maxNum;
  }).sort();
}

// ── NOTA: sibling detection eliminada — solo se usan los archivos exactos
//    del WP galería original. Las décenas se asignan manualmente post-proceso.

// ── Cache de subidas para no subir el mismo archivo dos veces ─────────────────
const cacheUrls = {};

async function subirArchivo(nombreLocal) {
  if (cacheUrls[nombreLocal]) return cacheUrls[nombreLocal];

  const rutaLocal   = indiceLocal[nombreLocal];
  const storagePath = `empresas/${EID}/noticias/${nombreLocal}`;
  const file        = bucket.file(storagePath);

  // Si ya existe en Storage, leer su token
  try {
    const [exists] = await file.exists();
    if (exists) {
      const [meta] = await file.getMetadata();
      const token  = meta.metadata?.firebaseStorageDownloadTokens;
      if (token) {
        const enc = encodeURIComponent(storagePath).replace(/%2F/g,'%2F');
        const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${enc}?alt=media&token=${token}`;
        cacheUrls[nombreLocal] = url;
        return url;
      }
    }
  } catch (_) {}

  const token = crypto.randomUUID();
  const ext   = path.extname(nombreLocal).toLowerCase();
  const mime  = ext==='.png'?'image/png':ext==='.gif'?'image/gif':'image/jpeg';
  await file.save(fs.readFileSync(rutaLocal), {
    metadata: { contentType: mime, metadata: { firebaseStorageDownloadTokens: token } },
  });
  const enc = encodeURIComponent(storagePath).replace(/%2F/g,'%2F');
  const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${enc}?alt=media&token=${token}`;
  cacheUrls[nombreLocal] = url;
  return url;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${DRY?'[DRY-RUN] ':''}Escalando imágenes del blog${TIPO?' (tipo: '+TIPO+')':''}\n`);

  let query = db.collection('empresas').doc(EID).collection('blog');
  if (TIPO) query = query.where('tipo','==',TIPO);
  const snap = await query.get();

  const posts = snap.docs.map(d => ({ id: d.id, ref: d.ref, ...d.data() }));
  console.log(`Posts cargados: ${posts.length}`);

  let procesados=0, subidos=0, sinSolucion=0, yaOk=0, errores=0;

  for (const post of posts) {
    const mainUrl = post.thumbnail_url || post.imagen_url || '';
    const galeriaActual = post.galeria || [];

    // Skip si ya está en Firebase Storage y galeria limpia
    const todoFS = esFS(mainUrl) && galeriaActual.every(u => esFS(u) || !u);
    if (todoFS) { yaOk++; continue; }

    // Extraer nombres de archivo de las URLs WP
    const wpNombre    = encontrarLocal(nombreDeUrl(mainUrl));
    const wpGalNombres = galeriaActual
      .filter(u => esWP(u))
      .map(u => encontrarLocal(nombreDeUrl(u)))
      .filter(Boolean);

    // Si no encontramos el archivo principal, saltar
    if (!wpNombre && !esFS(mainUrl)) {
      sinSolucion++;
      continue;
    }

    // Reunir archivos: principal + galeria WP exacta (SIN hermanas automáticas)
    const archivosSet = new Set();
    if (wpNombre) archivosSet.add(wpNombre);
    wpGalNombres.forEach(n => archivosSet.add(n));
    // Conservar URLs de FS que ya estaban en galeria
    const fsExistentes = galeriaActual.filter(u => esFS(u));

    const archivos = [...archivosSet].sort();

    if (DRY) {
      if (archivos.length > 0) {
        console.log(`\n  📌 ${post.id.slice(0,55)} (${post.tipo||'?'})`);
        archivos.forEach(a => console.log(`     + ${a}`));
        procesados++;
      }
      continue;
    }

    // Subir todos los archivos
    try {
      const nuevasUrls = [];
      for (const archivo of archivos) {
        const url = await subirArchivo(archivo);
        nuevasUrls.push(url);
        subidos++;
      }

      // Construir galeria: nuevas + FS existentes (dedup)
      const galeriaFinal = [...new Set([...nuevasUrls, ...fsExistentes])];
      const mainFinal    = galeriaFinal[0] || (esFS(mainUrl) ? mainUrl : '');

      if (mainFinal) {
        await post.ref.update({
          imagen_url:    mainFinal,
          thumbnail_url: mainFinal,
          galeria:       galeriaFinal,
        });
        procesados++;
      }

      if (procesados % 50 === 0) {
        console.log(`  … ${procesados} posts procesados, ${subidos} archivos subidos`);
      }
    } catch (e) {
      console.error(`  ❌ ${post.id}: ${e.message}`);
      errores++;
    }
  }

  console.log(`\n${'═'.repeat(60)}`);
  console.log(` Posts procesados:    ${procesados}`);
  console.log(` Archivos subidos:    ${subidos}`);
  console.log(` Ya en Firebase:      ${yaOk}`);
  console.log(` Sin archivo local:   ${sinSolucion}`);
  console.log(` Errores:             ${errores}`);
  console.log(`${'═'.repeat(60)}\n`);
}

main().catch(e => { console.error('❌ Fatal:', e.message); process.exit(1); });
