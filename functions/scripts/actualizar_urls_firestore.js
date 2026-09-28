/**
 * actualizar_urls_firestore.js
 * Después de subir las imágenes a Hostinger, actualiza las URLs en Firestore.
 *
 * Uso:
 *   node scripts/actualizar_urls_firestore.js --base "https://seashell-boar-580681.hostingersite.com/img/noticias/"
 *   node scripts/actualizar_urls_firestore.js --base "..." --dry-run
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

const args    = process.argv;
const BASE    = (args[args.indexOf('--base') + 1] || '').replace(/\/$/, '') + '/';
const DRY     = args.includes('--dry-run');

if (!BASE || BASE === '/') {
  console.error('Uso: node actualizar_urls_firestore.js --base "https://dominio/img/noticias/"');
  process.exit(1);
}

async function main() {
  const mappingPath = path.join(__dirname, '..', 'mapping_imagenes.json');
  if (!fs.existsSync(mappingPath)) {
    console.error('No se encontró mapping_imagenes.json. Ejecuta primero descargar_imagenes_wp.js');
    process.exit(1);
  }
  const mapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));
  console.log(`\n${DRY?'[DRY-RUN] ':''}Actualizando URLs en Firestore`);
  console.log(`Base Hostinger: ${BASE}`);
  console.log(`URLs en mapping: ${Object.keys(mapping).length}\n`);

  const snap = await db.collection('empresas').doc(EID).collection('blog').get();
  const aBatch = [];

  snap.docs.forEach(d => {
    const url = d.data().imagen_url || '';
    if (mapping[url]) {
      const nuevaUrl = BASE + mapping[url];
      aBatch.push({ id: d.id, nuevaUrl });
    }
  });

  console.log(`Documentos a actualizar: ${aBatch.length}`);
  if (DRY) { aBatch.slice(0,5).forEach(x => console.log(`  ${x.id} → ${x.nuevaUrl}`)); console.log('\n[DRY-RUN] No guardado.\n'); return; }

  let ok=0, err=0;
  for (const { id, nuevaUrl } of aBatch) {
    try {
      await db.collection('empresas').doc(EID).collection('blog').doc(id).update({ imagen_url: nuevaUrl });
      ok++;
    } catch(e) { console.error(`  ✗ ${id}: ${e.message}`); err++; }
  }

  console.log(`\n══════════════════════`);
  console.log(` Actualizados: ${ok}  Errores: ${err}`);
  console.log(`══════════════════════\n`);
}

main().catch(e => { console.error(e); process.exit(1); });
