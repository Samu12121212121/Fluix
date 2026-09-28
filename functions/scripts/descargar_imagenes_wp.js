/**
 * descargar_imagenes_wp.js
 * Descarga todas las imágenes de editorialnazari.com que están en Firestore
 * usando credenciales de WordPress (Application Password).
 *
 * Uso:
 *   node scripts/descargar_imagenes_wp.js --user "admin@email.com" --pass "xxxx xxxx xxxx xxxx"
 *   node scripts/descargar_imagenes_wp.js --user "..." --pass "..." --dry-run
 *
 * Resultado:
 *   - Imágenes guardadas en ./imagenes_descargadas/
 *   - mapping.json con { url_vieja: nombre_archivo }
 */

const admin  = require('firebase-admin');
const fetch  = require('node-fetch');
const fs     = require('fs');
const path   = require('path');
const sa     = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

const args  = process.argv;
const USER  = args[args.indexOf('--user') + 1];
const PASS  = args[args.indexOf('--pass') + 1];
const DRY   = args.includes('--dry-run');
const DEST  = path.join(__dirname, '..', 'imagenes_descargadas');
const PAUSA = 300; // ms entre peticiones

if (!USER || !PASS) {
  console.error('Uso: node descargar_imagenes_wp.js --user "usuario" --pass "contraseña"');
  process.exit(1);
}

const AUTH = 'Basic ' + Buffer.from(USER + ':' + PASS.replace(/\s/g, '')).toString('base64');
const sleep = ms => new Promise(r => setTimeout(r, ms));

function nombreArchivo(url) {
  // Preserva año/mes para evitar colisiones: 2024-10-imagen.jpg
  const m = url.match(/uploads\/(\d{4})\/(\d{2})\/([^?#]+)$/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  return url.split('/').pop().split('?')[0];
}

async function descargar(url, destFile) {
  const res = await fetch(url, {
    headers: {
      'Authorization': AUTH,
      'User-Agent': 'Mozilla/5.0 (compatible; NazariMigrator/1.0)',
    },
    timeout: 15000,
  });
  if (!res.ok) return `HTTP ${res.status}`;
  const ct = res.headers.get('content-type') || '';
  if (!ct.startsWith('image/')) return `no es imagen (${ct})`;
  const buf = await res.buffer();
  fs.writeFileSync(destFile, buf);
  return null; // sin error
}

async function main() {
  console.log(`\n${DRY ? '[DRY-RUN] ' : ''}Descargando imágenes de editorialnazari.com\n`);

  if (!DRY && !fs.existsSync(DEST)) fs.mkdirSync(DEST, { recursive: true });

  // Recoger todas las URLs únicas de editorialnazari.com en la colección blog
  const snap = await db.collection('empresas').doc(EID).collection('blog').get();
  const urlMap = {}; // url → [docId, ...]
  snap.docs.forEach(d => {
    const url = d.data().imagen_url || '';
    if (url.includes('editorialnazari.com')) {
      (urlMap[url] = urlMap[url] || []).push(d.id);
    }
  });

  const urls = Object.keys(urlMap);
  console.log(`URLs únicas a descargar: ${urls.length}\n`);

  const mapping = {}; // url_vieja → nombre_archivo_nuevo
  let ok = 0, errores = [];

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    const nombre = nombreArchivo(url);
    const destFile = path.join(DEST, nombre);

    process.stdout.write(`[${String(i+1).padStart(4,'0')}/${urls.length}] ${nombre.substring(0,60)}`);

    if (DRY) {
      process.stdout.write(` → (dry-run)\n`);
      mapping[url] = nombre;
      ok++;
      continue;
    }

    // No re-descargar si ya existe
    if (fs.existsSync(destFile)) {
      process.stdout.write(` → ya existe\n`);
      mapping[url] = nombre;
      ok++;
      continue;
    }

    const err = await descargar(url, destFile);
    if (err) {
      process.stdout.write(` ✗ ${err}\n`);
      errores.push({ url, err });
    } else {
      process.stdout.write(` ✓\n`);
      mapping[url] = nombre;
      ok++;
    }

    await sleep(PAUSA);
  }

  // Guardar mapping
  const mappingPath = path.join(__dirname, '..', 'mapping_imagenes.json');
  fs.writeFileSync(mappingPath, JSON.stringify(mapping, null, 2));

  console.log(`\n══════════════════════════════════════════`);
  console.log(` Descargadas : ${ok}`);
  console.log(` Errores     : ${errores.length}`);
  if (errores.length) {
    console.log(` Errores detalle:`);
    errores.slice(0, 10).forEach(e => console.log(`   ${e.url.split('/').pop()} → ${e.err}`));
    if (errores.length > 10) console.log(`   ... y ${errores.length - 10} más`);
  }
  console.log(`\n mapping_imagenes.json guardado`);
  console.log(` Imágenes en: ${DEST}`);
  console.log(`\n SIGUIENTE PASO:`);
  console.log(` 1. Sube la carpeta imagenes_descargadas/ a Hostinger en /img/noticias/`);
  console.log(` 2. Confirma que se ven bien`);
  console.log(` 3. Ejecuta: node scripts/actualizar_urls_firestore.js --base "https://TU-DOMINIO/img/noticias/"`);
  console.log(`══════════════════════════════════════════\n`);
}

main().catch(e => { console.error(e); process.exit(1); });
