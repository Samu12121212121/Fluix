/**
 * migrar_imagenes.js — Descarga imágenes de WordPress y las sube a Firebase Storage
 *
 * Lee master.json (generado por extractor.js), descarga cada imagen con wp_url
 * que todavía no haya sido migrada, la sube a Firebase Storage y actualiza
 * el master.json con la fluix_url definitiva.
 *
 * Uso:
 *   node scripts/nazari/migrar_imagenes.js
 *   node scripts/nazari/migrar_imagenes.js --master scripts/nazari/master.json
 *   node scripts/nazari/migrar_imagenes.js --concurrency 5
 *   node scripts/nazari/migrar_imagenes.js --dry-run     (sin subir ni guardar)
 *   node scripts/nazari/migrar_imagenes.js --solo-tipo noticias
 *
 * Al terminar escribe el master.json actualizado con todas las fluix_url rellenas
 * y el contenido_html con las URLs sustituidas.
 */

'use strict';

const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');
const admin  = require('../../functions/node_modules/firebase-admin');

// ── CLI args ──────────────────────────────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const get  = (flag) => { const i = args.indexOf(flag); return i !== -1 ? args[i + 1] : null; };
  return {
    masterPath:   get('--master')      ?? path.join(__dirname, 'master.json'),
    concurrency:  parseInt(get('--concurrency') ?? '3', 10),
    delay:        parseInt(get('--delay')       ?? '200', 10),
    dryRun:       args.includes('--dry-run'),
    soloTipo:     get('--solo-tipo'),              // 'noticias' | 'entrevistas' | 'autores' | 'libros'
    checkpointN:  parseInt(get('--checkpoint')   ?? '25', 10),
    bucket:       get('--bucket') ?? 'planeaapp-4bea4.firebasestorage.app',
    storagePath:  get('--storage-path') ?? 'nazari/migracion',
    saPath:       get('--sa') ?? path.join(__dirname, '../../functions/serviceAccountKey.json'),
  };
}

const cfg = parseArgs();

// ── MIME types ────────────────────────────────────────────────────────────────
const MIME_MAP = {
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png',
  gif: 'image/gif',  webp: 'image/webp', svg: 'image/svg+xml',
  avif: 'image/avif',
};

function mimeFromUrl(url) {
  const ext = (url.split('.').pop() ?? '').toLowerCase().split('?')[0];
  return MIME_MAP[ext] ?? 'image/jpeg';
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function log(msg)  { console.log(msg); }
function warn(msg) { console.warn(`  ⚠  ${msg}`); }

function urlHash(url) {
  return crypto.createHash('md5').update(url).digest('hex').slice(0, 8);
}

function storageFilename(wpUrl, tipo, slug) {
  const basename = path.basename(wpUrl.split('?')[0]);
  const hash     = urlHash(wpUrl);
  // nazari/migracion/noticias/mi-slug/a1b2c3d4_imagen.jpg
  const safSlug  = (slug ?? 'sin-slug').slice(0, 60).replace(/[^a-z0-9_-]/gi, '-');
  return `${cfg.storagePath}/${tipo}/${safSlug}/${hash}_${basename}`;
}

// ── Descarga de imagen ────────────────────────────────────────────────────────
async function downloadImage(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Fluix-WP-Migrator/1.0' },
    redirect: 'follow',
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length === 0) throw new Error('Respuesta vacía');
  return buf;
}

// ── Subida a Firebase Storage ─────────────────────────────────────────────────
async function uploadToStorage(buffer, storagePath, contentType) {
  if (cfg.dryRun) {
    return `https://storage.googleapis.com/${cfg.bucket}/${storagePath}`;
  }
  const file = admin.storage().bucket(cfg.bucket).file(storagePath);
  await file.save(buffer, {
    metadata: { contentType, cacheControl: 'public, max-age=31536000' },
  });
  await file.makePublic();
  return file.publicUrl();
}

// ── Proceso de una imagen individual ─────────────────────────────────────────
async function procesarImagen(imgEntry, tipo, slug, globalCache, stats) {
  if (imgEntry.descargada) return imgEntry.fluix_url;

  // Usar caché global para no descargar la misma URL dos veces
  if (globalCache.has(imgEntry.wp_url)) {
    const cached = globalCache.get(imgEntry.wp_url);
    imgEntry.fluix_url  = cached;
    imgEntry.descargada = true;
    stats.cacheadas++;
    return cached;
  }

  const storagePath = storageFilename(imgEntry.wp_url, tipo, slug);
  const contentType = mimeFromUrl(imgEntry.wp_url);

  let buffer;
  try {
    buffer = await downloadImage(imgEntry.wp_url);
  } catch (err) {
    warn(`Descarga fallida [${err.message}]: ${imgEntry.wp_url}`);
    stats.errores++;
    return null;
  }

  let fluixUrl;
  try {
    fluixUrl = await uploadToStorage(buffer, storagePath, contentType);
  } catch (err) {
    warn(`Subida fallida [${err.message}]: ${storagePath}`);
    stats.errores++;
    return null;
  }

  imgEntry.fluix_url  = fluixUrl;
  imgEntry.descargada = true;
  globalCache.set(imgEntry.wp_url, fluixUrl);
  stats.descargadas++;
  return fluixUrl;
}

// ── Sustitución de URLs en contenido_html ─────────────────────────────────────
function sustituirUrlsEnHtml(html, sustituciones) {
  if (!html || sustituciones.size === 0) return html;
  let result = html;
  for (const [wpUrl, fluixUrl] of sustituciones) {
    // Escapar caracteres especiales para usar como literal en RegExp
    const escaped = wpUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    result = result.replace(new RegExp(escaped, 'g'), fluixUrl);
  }
  return result;
}

// ── Semáforo para concurrencia limitada ───────────────────────────────────────
function crearSemaforo(max) {
  let activos = 0;
  const cola  = [];
  return async function ejecutar(fn) {
    if (activos >= max) {
      await new Promise(r => cola.push(r));
    }
    activos++;
    try     { return await fn(); }
    finally {
      activos--;
      if (cola.length > 0) cola.shift()();
    }
  };
}

// ── Procesado de una colección completa ──────────────────────────────────────
async function procesarColeccion(items, tipo, globalCache, stats, checkpoint) {
  const sem = crearSemaforo(cfg.concurrency);
  let procesados = 0;

  for (const item of items) {
    if (cfg.soloTipo && tipo !== cfg.soloTipo) continue;

    const sustituciones = new Map();

    // imagen_principal
    if (item.imagen_principal && !item.imagen_principal.descargada) {
      await sem(async () => {
        const fluixUrl = await procesarImagen(item.imagen_principal, tipo, item.slug, globalCache, stats);
        if (fluixUrl) sustituciones.set(item.imagen_principal.wp_url, fluixUrl);
        await sleep(cfg.delay);
      });
    }

    // imagenes_contenido
    for (const imgEntry of (item.imagenes_contenido ?? [])) {
      if (imgEntry.descargada) continue;
      await sem(async () => {
        const fluixUrl = await procesarImagen(imgEntry, tipo, item.slug, globalCache, stats);
        if (fluixUrl) sustituciones.set(imgEntry.wp_url, fluixUrl);
        await sleep(cfg.delay);
      });
    }

    // Sustituir URLs en el HTML del contenido
    if (sustituciones.size > 0 && item.contenido_html) {
      item.contenido_html = sustituirUrlsEnHtml(item.contenido_html, sustituciones);
    }

    procesados++;
    const total = stats.descargadas + stats.cacheadas + stats.errores;
    process.stdout.write(`\r  [${tipo}] ${procesados}/${items.length} items | ${total} imgs`);

    // Checkpoint periódico
    if (procesados % cfg.checkpointN === 0) {
      process.stdout.write(' → guardando checkpoint...\n');
      checkpoint();
    }
  }

  process.stdout.write('\n');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  log('\n═══════════════════════════════════════════════════');
  log('  Fluix — Migrador de imágenes WP → Firebase Storage');
  log(`  master.json : ${cfg.masterPath}`);
  log(`  bucket      : ${cfg.bucket}`);
  log(`  prefijo     : ${cfg.storagePath}`);
  log(`  concurrencia: ${cfg.concurrency}`);
  if (cfg.dryRun) log('  ⚡ DRY RUN — no se subirá nada ni se guardará master.json');
  log('═══════════════════════════════════════════════════\n');

  // ── Leer master.json ────────────────────────────────────────────────────────
  if (!fs.existsSync(cfg.masterPath)) {
    console.error(`❌ No se encontró master.json en ${cfg.masterPath}`);
    console.error('   Ejecuta primero: node scripts/nazari/extractor.js');
    process.exit(1);
  }

  const master = JSON.parse(fs.readFileSync(cfg.masterPath, 'utf8'));

  // ── Inicializar Firebase ────────────────────────────────────────────────────
  if (!cfg.dryRun) {
    if (!fs.existsSync(cfg.saPath)) {
      console.error(`❌ No se encontró el Service Account en ${cfg.saPath}`);
      process.exit(1);
    }
    const sa = JSON.parse(fs.readFileSync(cfg.saPath, 'utf8'));
    admin.initializeApp({
      credential:    admin.credential.cert(sa),
      storageBucket: cfg.bucket,
    });
    log('✅ Firebase Admin inicializado\n');
  }

  // ── Función de checkpoint (guarda el master.json actualizado) ──────────────
  const guardarMaster = () => {
    if (cfg.dryRun) return;
    master._meta.stats.imagenes_migradas =
      Object.values(master).flat().filter(Array.isArray).flat()
        .reduce((acc, item) => {
          if (item?.imagen_principal?.descargada) acc++;
          acc += (item?.imagenes_contenido ?? []).filter(i => i.descargada).length;
          return acc;
        }, 0);
    fs.writeFileSync(cfg.masterPath, JSON.stringify(master, null, 2), 'utf8');
  };

  // ── Caché global para deduplicar imágenes repetidas ───────────────────────
  const globalCache = new Map();

  // Pre-cargar imágenes ya migradas en caché
  for (const tipo of ['noticias', 'entrevistas', 'autores', 'libros']) {
    for (const item of (master[tipo] ?? [])) {
      if (item.imagen_principal?.descargada && item.imagen_principal.fluix_url) {
        globalCache.set(item.imagen_principal.wp_url, item.imagen_principal.fluix_url);
      }
      for (const img of (item.imagenes_contenido ?? [])) {
        if (img.descargada && img.fluix_url) globalCache.set(img.wp_url, img.fluix_url);
      }
    }
  }
  log(`♻️  Imágenes ya migradas en caché: ${globalCache.size}\n`);

  const stats = { descargadas: 0, cacheadas: 0, errores: 0 };

  // ── Procesar cada tipo ─────────────────────────────────────────────────────
  const tipos = [
    { key: 'noticias',    label: 'noticias' },
    { key: 'entrevistas', label: 'entrevistas' },
    { key: 'autores',     label: 'autores' },
    { key: 'libros',      label: 'libros' },
  ];

  for (const { key, label } of tipos) {
    const coleccion = master[key] ?? [];
    if (coleccion.length === 0) continue;
    if (cfg.soloTipo && key !== cfg.soloTipo) {
      log(`⏭  ${label} omitidas (--solo-tipo ${cfg.soloTipo})`);
      continue;
    }

    const pendientes = coleccion.filter(item => {
      const faltaPrincipal = item.imagen_principal && !item.imagen_principal.descargada;
      const faltaContenido = (item.imagenes_contenido ?? []).some(i => !i.descargada);
      return faltaPrincipal || faltaContenido;
    }).length;

    log(`📦 ${label}: ${coleccion.length} items (${pendientes} con imágenes pendientes)`);

    await procesarColeccion(coleccion, key, globalCache, stats, guardarMaster);
    guardarMaster();
    log(`   ✅ ${label} completadas\n`);
  }

  // ── Guardar master.json final ──────────────────────────────────────────────
  guardarMaster();

  const totalImgs = stats.descargadas + stats.cacheadas + stats.errores;

  log('═══════════════════════════════════════════════════');
  log('✅  Migración de imágenes completada');
  log('═══════════════════════════════════════════════════');
  log(`   Descargadas y subidas : ${stats.descargadas}`);
  log(`   Reutilizadas (caché)  : ${stats.cacheadas}`);
  log(`   Errores               : ${stats.errores}`);
  log(`   Total procesadas      : ${totalImgs}`);
  log(`   master.json           : ${cfg.masterPath}`);
  if (stats.errores > 0) {
    log('\n⚠️  Algunos errores se produjeron. Puedes relanzar el script;');
    log('   las imágenes ya migradas se saltarán automáticamente.');
  }
  log('\n👉 Siguiente paso:');
  log('   node scripts/nazari/importar_lote.js --tipo noticias --limite 50');
  log('═══════════════════════════════════════════════════\n');
}

main().catch(err => {
  console.error('\n❌ Error fatal:', err.message ?? String(err));
  process.exit(1);
});
