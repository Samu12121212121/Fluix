/**
 * publicar_blog_nazari.js
 * ──────────────────────────────────────────────────────────────────────────
 * Pone publicada:true en TODAS las entradas de tipo 'noticia' y 'entrevista'
 * que NO estén ya publicadas ni eliminadas.
 *
 * Uso:
 *   cd functions
 *   node publicar_blog_nazari.js              → publica todo
 *   node publicar_blog_nazari.js --dry-run    → solo cuenta, no escribe
 *   node publicar_blog_nazari.js --tipo noticia     → solo noticias
 *   node publicar_blog_nazari.js --tipo entrevista  → solo entrevistas
 */

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');
const os    = require('os');

const DRY_RUN = process.argv.includes('--dry-run');
const TIPO_FILTER = (() => {
  const i = process.argv.indexOf('--tipo');
  return i >= 0 ? process.argv[i + 1] : null;
})();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// ── Init Firebase ────────────────────────────────────────────────────────────
const saPath = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(saPath)) {
  admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
} else {
  // Fallback: usar token de Firebase CLI
  function getRefreshToken() {
    const candidates = [
      path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    ];
    for (const p of candidates) {
      try {
        const d = JSON.parse(fs.readFileSync(p, 'utf8'));
        const rt = d?.tokens?.refresh_token;
        if (rt) return rt;
      } catch (_) {}
    }
    return null;
  }
  const rt = getRefreshToken();
  if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token CLI.'); process.exit(1); }
  admin.initializeApp({
    credential: admin.credential.refreshToken({
      type: 'authorized_user',
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p',
      refresh_token: rt,
    }),
    projectId: 'planeaapp-4bea4',
  });
}

const db  = admin.firestore();
const col = db.collection('empresas').doc(EID).collection('blog');

async function main() {
  const tipos = TIPO_FILTER ? [TIPO_FILTER] : ['noticia', 'entrevista'];
  console.log(`\n🚀 ${DRY_RUN ? '[DRY-RUN] ' : ''}Publicando entradas de blog…`);
  console.log(`   Tipos: ${tipos.join(', ')}`);
  console.log(`   Empresa: ${EID}\n`);

  let totalVistas = 0, totalSinPublicar = 0, totalPublicadas = 0, totalEliminadas = 0;

  for (const tipo of tipos) {
    const snap = await col.where('tipo', '==', tipo).get();
    console.log(`  📂 ${tipo}: ${snap.docs.length} entradas totales`);

    const sinPublicar = snap.docs.filter(d => {
      const data = d.data();
      return !data.eliminado && data.publicada !== true;
    });
    const yaPublicadas = snap.docs.filter(d => d.data().publicada === true && !d.data().eliminado);
    const eliminadas   = snap.docs.filter(d => d.data().eliminado === true);

    console.log(`     ✅ Ya publicadas:   ${yaPublicadas.length}`);
    console.log(`     ⏸  Sin publicar:    ${sinPublicar.length}`);
    console.log(`     🗑  Eliminadas:      ${eliminadas.length}`);

    totalVistas      += snap.docs.length;
    totalSinPublicar += sinPublicar.length;
    totalPublicadas  += yaPublicadas.length;
    totalEliminadas  += eliminadas.length;

    if (sinPublicar.length === 0 || DRY_RUN) continue;

    // Batch update
    let batch = db.batch(), cnt = 0, actualizadas = 0;
    for (const doc of sinPublicar) {
      batch.update(doc.ref, {
        publicada: true,
        estado: 'publicado',
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      });
      cnt++;
      actualizadas++;
      if (cnt >= 490) {
        await batch.commit();
        batch = db.batch();
        cnt   = 0;
        console.log(`     ⏳ Lote enviado (${actualizadas})…`);
      }
    }
    if (cnt > 0) await batch.commit();
    console.log(`     ✅ ${actualizadas} entradas de tipo '${tipo}' publicadas`);
  }

  console.log('\n═══════════════════════════════════════════════');
  console.log(`  TOTALES`);
  console.log(`  Entradas vistas:      ${totalVistas}`);
  console.log(`  Ya publicadas:        ${totalPublicadas}`);
  console.log(`  Sin publicar (fixed): ${DRY_RUN ? totalSinPublicar + ' (dry-run)' : totalSinPublicar}`);
  console.log(`  Eliminadas (skip):    ${totalEliminadas}`);
  console.log('═══════════════════════════════════════════════\n');

  if (DRY_RUN) console.log('[DRY-RUN] No se escribió nada. Quita --dry-run para aplicar.');
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message || e); process.exit(1); });
