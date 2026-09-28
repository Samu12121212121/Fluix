/**
 * migrar_portadas_storage.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Sube las portadas de libros desde Hostinger local → Firebase Storage
 * y actualiza imagen_url en cada doc de catalogo_web.
 *
 * Una vez completado con éxito puedes eliminar:
 *   - libros-data.js del sitio Hostinger
 *   - El bloque _imgRelativa en catalogo.html
 *   - El <script src="libros-data.js"> en catalogo.html
 *
 * Uso:
 *   cd functions
 *   node scripts/migrar_portadas_storage.js --dry-run    ← qué haría (no sube)
 *   node scripts/migrar_portadas_storage.js              ← sube todo lo pendiente
 *   node scripts/migrar_portadas_storage.js --forzar     ← re-sube aunque ya tenga imagen_url
 *
 * Requisitos:
 *   - serviceAccountKey.json en functions/
 *   - Las imágenes en ~/Desktop/imagenes_nazari/html_nazari/img/html_nazari/img/
 * ──────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const vm    = require('vm');

const DRY_RUN = process.argv.includes('--dry-run');
const FORZAR  = process.argv.includes('--forzar');
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET  = 'planeaapp-4bea4.firebasestorage.app';
const IMG_DIR = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari', 'img', 'html_nazari', 'img');
const DATA_JS = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari', 'img', 'html_nazari', 'libros-data.js');

// ── Firebase init ─────────────────────────────────────────────────────────────
const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ Se necesita serviceAccountKey.json en functions/');
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

// ── Cargar libros-data.js ─────────────────────────────────────────────────────
function loadLibrosData() {
  if (!fs.existsSync(DATA_JS)) {
    console.error('❌ No se encontró libros-data.js en:', DATA_JS);
    process.exit(1);
  }
  let code = fs.readFileSync(DATA_JS, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx['LIBROS'] || [];
}

// ── URL pública de Firebase Storage ──────────────────────────────────────────
function storageUrl(filePath) {
  const encoded = encodeURIComponent(filePath).replace(/%2F/g, '%2F');
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}?alt=media`;
}

// ── Subir un archivo a Storage ────────────────────────────────────────────────
async function subirArchivo(localPath, storagePath, contentType) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata:    { contentType, cacheControl: 'public, max-age=31536000' },
    public:      true,
  });
  return storageUrl(storagePath);
}

// ── Buscar doc en catalogo_web por slug ───────────────────────────────────────
async function buscarDoc(slug) {
  // 1) Probar doc.id === slug directamente
  const direct = await db.collection('empresas').doc(EID).collection('catalogo_web').doc(slug).get();
  if (direct.exists) return direct;

  // 2) Query por campo slug
  const q = await db.collection('empresas').doc(EID).collection('catalogo_web')
    .where('slug', '==', slug).limit(1).get();
  if (!q.empty) return q.docs[0];

  return null;
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const libros = loadLibrosData();
  console.log(`\n${DRY_RUN ? '[DRY-RUN] ' : ''}Migración portadas → Firebase Storage`);
  console.log(`Libros en libros-data.js: ${libros.length}`);
  console.log(`Carpeta imágenes: ${IMG_DIR}`);
  console.log(`Forzar re-subida: ${FORZAR}\n`);

  if (!fs.existsSync(IMG_DIR)) {
    console.error('❌ No se encontró la carpeta de imágenes:', IMG_DIR);
    process.exit(1);
  }

  let subidos = 0, omitidos = 0, sinArchivo = 0, sinDoc = 0, errores = 0;
  const resultados = [];

  for (const libro of libros) {
    const slug      = libro.slug;
    const imagenRel = libro.imagen; // "img/el-titulo-portada-72ppp.webp"
    if (!slug || !imagenRel) { omitidos++; continue; }

    // Nombre del archivo local: quitamos "img/" del prefijo
    const fileName  = path.basename(imagenRel); // "el-titulo-portada-72ppp.webp"
    const localPath = path.join(IMG_DIR, fileName);

    if (!fs.existsSync(localPath)) {
      console.warn(`  ⚠️  [${slug}] Archivo no encontrado: ${fileName}`);
      sinArchivo++;
      resultados.push({ slug, estado: 'sin_archivo', archivo: fileName });
      continue;
    }

    // Buscar documento en Firestore
    const doc = await buscarDoc(slug);
    if (!doc) {
      console.warn(`  ⚠️  [${slug}] No encontrado en catalogo_web`);
      sinDoc++;
      resultados.push({ slug, estado: 'sin_doc' });
      continue;
    }

    const docData = doc.data();

    // ¿Ya tiene imagen_url de Storage? Saltar si no se fuerza
    if (!FORZAR && docData.imagen_url && docData.imagen_url.includes('firebasestorage.googleapis.com')) {
      console.log(`  ✅ [${slug}] Ya tiene imagen en Storage — omitiendo`);
      omitidos++;
      resultados.push({ slug, estado: 'ya_migrado', url: docData.imagen_url });
      continue;
    }

    const ext         = path.extname(fileName).replace('.', '') || 'webp';
    const contentType = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : 'image/webp';
    const storagePath = `nazari/portadas/${slug}.${ext}`;

    console.log(`  📤 [${slug}] ${fileName} → ${storagePath}`);

    if (DRY_RUN) {
      subidos++;
      resultados.push({ slug, estado: 'pendiente', archivo: fileName, storagePath });
      continue;
    }

    try {
      const url = await subirArchivo(localPath, storagePath, contentType);
      await doc.ref.update({
        imagen_url:             url,
        imagen_url_migrada:     true,
        imagen_storage_path:    storagePath,
        imagen_migrada_ts:      admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`    ✅ Subido y Firestore actualizado`);
      subidos++;
      resultados.push({ slug, estado: 'subido', url, storagePath });
    } catch (e) {
      console.error(`    ❌ Error en [${slug}]:`, e.message);
      errores++;
      resultados.push({ slug, estado: 'error', error: e.message });
    }

    // Pequeña pausa para no saturar Storage
    await new Promise(r => setTimeout(r, 80));
  }

  // ── Resumen ─────────────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════════════════');
  console.log(`${DRY_RUN ? '[DRY-RUN] ' : ''}Resultado migración portadas:`);
  console.log(`  ✅ Subidos/listos:       ${subidos}`);
  console.log(`  ⏭️  Ya migrados (skip):  ${omitidos}`);
  console.log(`  📁 Archivo no existe:   ${sinArchivo}`);
  console.log(`  🔍 Doc no en Firestore: ${sinDoc}`);
  console.log(`  ❌ Errores:             ${errores}`);
  console.log('══════════════════════════════════════════════════════\n');

  if (!DRY_RUN && errores === 0 && sinArchivo === 0 && sinDoc === 0) {
    console.log('🎉 Migración completa. Ahora puedes:');
    console.log('   1. Verificar en Firebase Storage que están las imágenes');
    console.log('   2. Verificar en Firestore que imagen_url está actualizada');
    console.log('   3. Ejecutar: node scripts/migrar_portadas_storage.js --verificar');
    console.log('   4. Eliminar libros-data.js del sitio Hostinger');
    console.log('   5. Eliminar el bloque _imgRelativa de catalogo.html');
  } else if (!DRY_RUN && (sinArchivo > 0 || sinDoc > 0)) {
    console.log('⚠️  Hay entradas sin migrar. Guarda el resultado en un fichero:');
    console.log('   node scripts/migrar_portadas_storage.js 2>&1 | tee resultado_migracion.txt');
  }

  // Guardar log de resultados
  const logPath = path.join(__dirname, 'resultado_migracion_portadas.json');
  fs.writeFileSync(logPath, JSON.stringify(resultados, null, 2));
  console.log(`Log guardado en: ${logPath}`);
}

main().catch(e => { console.error('❌ Error fatal:', e); process.exit(1); });
