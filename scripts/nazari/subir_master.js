/**
 * subir_master.js — Sube master.json local a Firebase Storage
 *
 * Uso:
 *   node scripts/nazari/subir_master.js
 *   node scripts/nazari/subir_master.js --master scripts/nazari/master.json
 *   node scripts/nazari/subir_master.js --bucket planeaapp-4bea4.appspot.com
 */
'use strict';

const fs    = require('fs');
const path  = require('path');
const admin = require('../../functions/node_modules/firebase-admin');

const args      = process.argv.slice(2);
const getArg    = (flag) => { const i = args.indexOf(flag); return i !== -1 ? args[i + 1] : null; };
const masterPath = getArg('--master') ?? path.join(__dirname, 'master.json');
const bucket     = getArg('--bucket') ?? 'planeaapp-4bea4.firebasestorage.app';
const destPath   = 'nazari/migracion/master.json';
const saPath     = getArg('--sa') ?? path.join(__dirname, '../../functions/serviceAccountKey.json');

async function main() {
  console.log('\n═══════════════════════════════════════════════════');
  console.log('  Fluix — Subir master.json a Firebase Storage');
  console.log(`  Local   : ${masterPath}`);
  console.log(`  Destino : gs://${bucket}/${destPath}`);
  console.log('═══════════════════════════════════════════════════\n');

  if (!fs.existsSync(masterPath)) {
    console.error(`❌ No se encontró: ${masterPath}`);
    console.error('   Ejecuta primero: node scripts/nazari/extractor.js https://editorialnazari.com');
    process.exit(1);
  }

  if (!admin.apps.length) {
    if (fs.existsSync(saPath)) {
      const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
      admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: bucket });
    } else {
      admin.initializeApp({ storageBucket: bucket });
    }
  }

  const file    = admin.storage().bucket(bucket).file(destPath);
  const content = fs.readFileSync(masterPath);
  const sizeKB  = Math.round(content.length / 1024);

  console.log(`📤 Subiendo ${sizeKB} KB...`);
  await file.save(content, {
    metadata: { contentType: 'application/json' },
    resumable: false,
  });

  // Hacer público para que las Cloud Functions puedan leerlo sin auth adicional
  // (las Functions ya tienen acceso con service account — esto es opcional)
  // await file.makePublic();

  const [meta] = await file.getMetadata();
  console.log(`\n✅ Subido correctamente`);
  console.log(`   Tamaño  : ${sizeKB} KB`);
  console.log(`   Ruta    : gs://${bucket}/${destPath}`);
  console.log(`   Updated : ${meta.updated}`);
  console.log('\n👉 Ahora abre la app → Archivo Histórico → busca cualquier término\n');
}

main().catch(err => {
  console.error('\n❌ Error:', err.message ?? String(err));
  process.exit(1);
});
