/**
 * piloto_imagenes_noticias.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Piloto: 1 imagen por año (2022-2026) para noticias.
 * Maneja dos casos:
 *   A) Post con URL rota del WP original → reemplazar por Firebase Storage
 *   B) Post sin imagen → añadir desde local
 *
 * Uso:
 *   node scripts/piloto_imagenes_noticias.js --dry-run    ← solo muestra el mapeo
 *   node scripts/piloto_imagenes_noticias.js              ← sube y actualiza Firestore
 * ─────────────────────────────────────────────────────────────────────────────
 */
'use strict';

const admin  = require('firebase-admin');
const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');

const DRY    = process.argv.includes('--dry-run');
const EID    = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET = 'planeaapp-4bea4.firebasestorage.app';
const CARPETA = 'C:\\Users\\Samu\\Downloads\\imagenes_noticias';

const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(saPath)),
    storageBucket: BUCKET,
  });
}
const db     = admin.firestore();
const bucket = admin.storage().bucket();

function esUrlRotaWP(url) {
  return (url || '').includes('editorialnazari.com/wp-content/uploads/');
}

async function subirArchivo(rutaLocal, storagePath) {
  const token  = crypto.randomUUID();
  const file   = bucket.file(storagePath);
  const buffer = fs.readFileSync(rutaLocal);
  const ext    = path.extname(rutaLocal).toLowerCase();
  const mime   = ext === '.png' ? 'image/png' : ext === '.gif' ? 'image/gif' : 'image/jpeg';
  await file.save(buffer, {
    metadata: { contentType: mime, metadata: { firebaseStorageDownloadTokens: token } },
  });
  const encoded = encodeURIComponent(storagePath).replace(/%2F/g, '%2F');
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}?alt=media&token=${token}`;
}

// ── 5 candidatos verificados: 1 por año 2022-2026 ────────────────────────────
const PILOTO = [
  {
    anio: 2022,
    postId: 'asi-fue-la-presentacion-de-otras-hogueras-y-me-voy-de-aqui-en-barcelona',
    archivo: 'Me-voy-de-aqui-Barcelona-07-04-2022-01-scaled.jpg',
    titulo: "Presentación 'Otras hogueras' y 'Me voy de aquí' en Barcelona",
  },
  {
    anio: 2023,
    postId: 'asi-fue-el-norte-en-la-casa-del-poeta-ramon-lopez-velarde',
    archivo: '2023-09-14-El-norte.jpg',
    titulo: "'El norte' en la Casa del Poeta",
  },
  {
    anio: 2024,
    postId: 'asi-fue-la-presentacion-de-por-la-vida-rapida-en-la-feria-del-libro-de-avila',
    archivo: '2024-04-12-Por-la-vida-rapida-1.jpg',
    titulo: "'Por la vida rápida' en la Feria del Libro de Ávila",
  },
  {
    anio: 2025,
    postId: 'noticia-13',
    archivo: '2025-11-03-maneras-de-estar-tumbada-1.jpg',
    titulo: "Presentación «Maneras de estar tumbada» en Murcia",
  },
  {
    anio: 2026,
    postId: 'noticia-27',
    archivo: '2026-02-03-lagrimaciendo-sobre-el-vacio.jpg',
    titulo: "«Lagrimaciendo sobre el vacío» en Íllora",
  },
];

async function main() {
  console.log(`\n${DRY ? '[DRY-RUN] ' : ''}Piloto imágenes noticias — 1 por año (2022-2026)\n`);
  console.log('─'.repeat(65));

  const resultados = [];

  for (const item of PILOTO) {
    const rutaLocal = path.join(CARPETA, item.archivo);

    // Verificar archivo local
    if (!fs.existsSync(rutaLocal)) {
      console.log(`  ⚠️  ${item.anio}: archivo NO encontrado → ${item.archivo}`);
      continue;
    }

    // Verificar post en Firestore
    const docRef = db.collection('empresas').doc(EID).collection('blog').doc(item.postId);
    const snap   = await docRef.get();
    if (!snap.exists) {
      console.log(`  ❌ ${item.anio}: post NO existe en Firestore → ${item.postId}`);
      continue;
    }

    const data    = snap.data();
    const imgActual = data.imagen_url || '';
    const rota    = esUrlRotaWP(imgActual);
    const sinImg  = !imgActual;
    const caso    = sinImg ? 'B) Sin imagen' : rota ? 'A) URL rota WP' : '✓ Ya tiene imagen válida';

    console.log(`\n  📅 ${item.anio} — ${caso}`);
    console.log(`     Post:    ${item.titulo}`);
    console.log(`     ID:      ${item.postId}`);
    if (imgActual) console.log(`     URL actual: ${imgActual.slice(0, 70)}…`);
    console.log(`     Nueva imagen: ${item.archivo}`);
    console.log(`     Archivo local: ✅ existe (${(fs.statSync(rutaLocal).size / 1024).toFixed(0)} KB)`);

    if (!sinImg && !rota) {
      console.log(`     → Tiene imagen válida, no se actualizará.`);
      continue;
    }

    resultados.push({ item, docRef, caso });
  }

  console.log('\n' + '─'.repeat(65));
  console.log(`\nResumen: ${resultados.length} de ${PILOTO.length} para actualizar`);
  resultados.forEach(r => console.log(`  ${r.item.anio}: ${r.caso} → ${r.item.archivo}`));

  if (DRY) {
    console.log('\n[DRY-RUN] No se ha subido ni modificado nada.');
    console.log('  Para ejecutar: node scripts/piloto_imagenes_noticias.js\n');
    return;
  }

  console.log('\nSubiendo a Firebase Storage y actualizando Firestore…\n');
  let ok = 0, err = 0;

  for (const { item, docRef } of resultados) {
    const rutaLocal   = path.join(CARPETA, item.archivo);
    const storagePath = `empresas/${EID}/noticias/${item.archivo}`;
    try {
      process.stdout.write(`  ⬆️  ${item.anio}: subiendo ${item.archivo}… `);
      const url = await subirArchivo(rutaLocal, storagePath);
      await docRef.update({ imagen_url: url });
      console.log('✅');
      console.log(`      → ${url.slice(0, 80)}…`);
      ok++;
    } catch (e) {
      console.log('❌');
      console.error(`      Error: ${e.message}`);
      err++;
    }
  }

  console.log(`\n${'═'.repeat(65)}`);
  console.log(` Subidas: ${ok}   Errores: ${err}`);
  console.log(`${'═'.repeat(65)}\n`);
  if (ok > 0) console.log('Comprueba los posts en la web para confirmar que se ven las imágenes.\n');
}

main().catch(e => { console.error('❌ Fatal:', e.message); process.exit(1); });
