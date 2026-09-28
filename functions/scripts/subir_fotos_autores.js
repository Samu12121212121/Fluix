/**
 * subir_fotos_autores.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Lee las 169 fotos de autores desde la carpeta local img/ del proyecto HTML,
 * las sube a Firebase Storage y actualiza foto_url en Firestore.
 *
 * EJECUTAR ANTES DE BORRAR EL SITIO WEB O EL WORDPRESS.
 *
 * Uso:
 *   cd functions
 *   node scripts/subir_fotos_autores.js --dry-run         ← qué haría (no sube)
 *   node scripts/subir_fotos_autores.js                   ← sube fotos pendientes
 *   node scripts/subir_fotos_autores.js --forzar          ← re-sube aunque ya tenga foto_url
 *
 * Requiere:
 *   - serviceAccountKey.json en functions/
 *   - La carpeta html_nazari en ~/Desktop/imagenes_nazari/html_nazari
 *
 * Resultado en Firestore:
 *   foto_url: "https://firebasestorage.googleapis.com/v0/b/.../autores/foto_naz-...webp?..."
 * ──────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin  = require('firebase-admin');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');
const vm     = require('vm');
const crypto = require('crypto');
const https  = require('https');
const { execSync } = require('child_process');

const DRY_RUN = process.argv.includes('--dry-run');
const FORZAR  = process.argv.includes('--forzar');
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET  = 'planeaapp-4bea4.firebasestorage.app';
const HTML_DIR = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');

// ── Firebase init ─────────────────────────────────────────────────────────────
const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ Se necesita serviceAccountKey.json para acceder a Firebase Storage.');
  console.error('   Descárgalo desde Firebase Console → Configuración del proyecto → Cuentas de servicio.');
  process.exit(1);
}
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(saPath)),
    storageBucket: BUCKET,
  });
}
const db     = admin.firestore();
const bucket = admin.storage().bucket();

// ── Slug para docId ───────────────────────────────────────────────────────────
function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ── Cargar autores-data.js (lo recupera de git si fue borrado) ────────────────
function loadAutoresData() {
  const filePath = path.join(HTML_DIR, 'autores-data.js');
  let code;

  if (fs.existsSync(filePath)) {
    code = fs.readFileSync(filePath, 'utf8');
  } else {
    console.log('  ℹ️  autores-data.js borrado del directorio, recuperando desde git...');
    try {
      code = execSync('git show HEAD:autores-data.js', { cwd: HTML_DIR }).toString();
      console.log('  ✅ Recuperado correctamente desde git\n');
    } catch (e) {
      console.error('❌ No se pudo recuperar autores-data.js desde git:', e.message);
      process.exit(1);
    }
  }

  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx['AUTORES'] || [];
}

// ── Descarga una imagen desde una URL y devuelve el Buffer ───────────────────
function descargarImagen(url) {
  return new Promise((resolve, reject) => {
    const get = (u, redireccionesRestantes = 5) => {
      https.get(u, { headers: { 'User-Agent': 'NazariBackup/1.0' } }, res => {
        if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
          if (redireccionesRestantes <= 0) return reject(new Error('Demasiadas redirecciones'));
          return get(res.headers.location, redireccionesRestantes - 1);
        }
        if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
        const chunks = [];
        res.on('data', c => chunks.push(c));
        res.on('end', () => resolve(Buffer.concat(chunks)));
      }).on('error', reject);
    };
    get(url);
  });
}

// ── Sube datos (Buffer o ruta local) a Storage y devuelve URL con token ───────
async function subirArchivo(datos, storagePath, ext) {
  const token   = crypto.randomUUID();
  const file    = bucket.file(storagePath);
  const buffer  = Buffer.isBuffer(datos) ? datos : fs.readFileSync(datos);
  const mime    = (ext || storagePath).endsWith('.webp') ? 'image/webp'
                : (ext || storagePath).endsWith('.png')  ? 'image/png'
                : 'image/jpeg';

  await file.save(buffer, {
    metadata: {
      contentType: mime,
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });

  const encodedPath = encodeURIComponent(storagePath).replace(/%2F/g, '%2F');
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodedPath}?alt=media&token=${token}`;
}

// ── Pausa ──────────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n📸 ${DRY_RUN ? '[DRY-RUN] ' : ''}Subiendo fotos de autores a Firebase Storage...\n`);

  // 1. Cargar mapeo foto → autor desde autores-data.js
  const autoresData = loadAutoresData();
  console.log(`   autores-data.js cargado: ${autoresData.length} autores\n`);

  // 2. Leer estado actual de Firestore
  const col  = db.collection('empresas').doc(EID).collection('autores');
  const snap = await col.get();
  const fsMap = new Map(); // docId → data
  for (const doc of snap.docs) fsMap.set(doc.id, doc.data());
  console.log(`   Autores en Firestore: ${fsMap.size}\n`);

  let subidas = 0, saltadas = 0, errores = 0, noEncontradas = 0;
  const batch    = [];
  const COL_REF  = col;

  for (const autor of autoresData) {
    const fotoLocal = autor.foto || autor.foto_url || '';
    if (!fotoLocal || !fotoLocal.startsWith('img/')) continue;

    const localPath   = path.join(HTML_DIR, fotoLocal);
    const nombre      = autor.nombre || '';
    const docId       = `naz-${toSlug(nombre)}`;
    const fsData      = fsMap.get(docId);

    // Saltar si ya tiene foto_url real (https://) y no estamos forzando
    if (!FORZAR && fsData && fsData.foto_url && fsData.foto_url.startsWith('https://')) {
      saltadas++;
      continue;
    }

    const ext         = path.extname(fotoLocal) || '.webp';
    const storagePath = `empresas/${EID}/autores/${docId}${ext}`;

    // ── Obtener datos de imagen: primero local, si no existe descarga de WP ──
    let datosImagen  = null;
    let origenLabel  = '';

    if (fs.existsSync(localPath)) {
      datosImagen = localPath; // ruta; subirArchivo la leerá
      origenLabel = `local (${Math.round(fs.statSync(localPath).size / 1024)} KB)`;
    } else {
      // Intentar descargar desde WordPress usando la foto_url actual de Firestore
      const wpUrl = fsData && (fsData.foto_url || fsData.foto || '');
      if (wpUrl && wpUrl.startsWith('https://www.editorialnazari.com/wp-content/uploads/')) {
        if (DRY_RUN) {
          console.log(`  📥 ${nombre} → descargaría de WP: ${wpUrl}`);
          subidas++;
          continue;
        }
        try {
          datosImagen = await descargarImagen(wpUrl);
          origenLabel = `WP (${Math.round(datosImagen.length / 1024)} KB)`;
        } catch (e) {
          console.log(`  ❌ ${nombre}: archivo local no existe y descarga WP falló: ${e.message}`);
          errores++;
          continue;
        }
      } else {
        console.log(`  ⚠️  ${nombre}: ni archivo local ni URL de WP disponibles`);
        noEncontradas++;
        continue;
      }
    }

    if (DRY_RUN) {
      console.log(`  📋 ${nombre} → ${origenLabel} → gs://${BUCKET}/${storagePath}`);
      subidas++;
      continue;
    }

    try {
      await sleep(200);
      const url = await subirArchivo(datosImagen, storagePath, ext);
      await COL_REF.doc(docId).set({ foto_url: url, foto: url }, { merge: true });
      console.log(`  ✅ ${nombre} [${origenLabel}]`);
      subidas++;
    } catch (e) {
      console.log(`  ❌ ${nombre}: ${e.message}`);
      errores++;
    }
  }

  console.log(`\n══════════════════════════════════════════`);
  console.log(`  Subidas:          ${subidas}`);
  console.log(`  Ya tenían foto:   ${saltadas}`);
  console.log(`  Archivo no existe: ${noEncontradas}`);
  console.log(`  Errores:          ${errores}`);
  if (!DRY_RUN && subidas > 0) {
    console.log(`\n✅ Fotos en Firebase Storage: gs://${BUCKET}/empresas/${EID}/autores/`);
    console.log(`   Los foto_url en Firestore apuntan ahora a Storage (permanentes).`);
  }
  process.exit(0);
}

main().catch(e => { console.error('\n❌', e.message || e); process.exit(1); });
