'use strict';

/**
 * sync_autores_firestore.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Lee el JSON generado por scrape_autores_nazari.js,
 * lo compara con la colección `autores` en Firestore (cuenta Nazarí en PlaneaG),
 * reporta TODAS las discrepancias en bio / rol / etiquetas para autores > M
 * y (con --aplicar) aplica las correcciones con backup automático.
 *
 * Uso:
 *   cd functions
 *   node scripts/sync_autores_firestore.js              ← solo diagnóstico
 *   node scripts/sync_autores_firestore.js --aplicar    ← también corrige Firestore
 *   node scripts/sync_autores_firestore.js --todos      ← reporta/aplica a TODOS (no solo > M)
 *
 * Requiere: scripts/autores-web-scraped.json  (generado por scrape_autores_nazari.js)
 *           serviceAccountKey.json o firebase login en functions/
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');
const os    = require('os');

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const APLICAR  = process.argv.includes('--aplicar');
const TODOS    = process.argv.includes('--todos');   // por defecto solo > M
const JSON_IN  = path.join(__dirname, 'autores-web-scraped.json');
const BACKUP_F = path.join(__dirname, `autores-backup-${new Date().toISOString().slice(0, 10)}.json`);

// ── Firebase ───────────────────────────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
    return;
  }
  function getRefreshToken() {
    const candidates = [
      path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    ];
    for (const p of candidates) {
      try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); const rt = d?.tokens?.refresh_token; if (rt) return rt; } catch (_) {}
    }
    return null;
  }
  const rt = getRefreshToken();
  if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token Firebase CLI.'); process.exit(1); }
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

// ── Normalización ──────────────────────────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ── Umbral de diferencia de bio ────────────────────────────────────────────────
// Se considera discrepancia si la bio web es más larga ≥ DIFF_THRESHOLD chars
// O si la bio en Firestore está vacía.
const DIFF_THRESHOLD = 30;

function biosDifieren(bioFS, bioWeb) {
  if (!bioWeb) return false;            // sin bio web no hay nada que comparar
  if (!bioFS || bioFS.length < 20) return true; // Firestore vacía → siempre discrepancia
  return (bioWeb.length - bioFS.length) > DIFF_THRESHOLD; // web tiene bastante más
}

// ── Construir update para Firestore ───────────────────────────────────────────
function buildUpdate(scraped) {
  const upd = {};
  if (scraped.rol)                           upd.rol = scraped.rol;
  if (scraped.bio && scraped.bio.length > 20) {
    upd.bio = scraped.bio;
    upd.descripcion = scraped.bio.substring(0, 1500) + (scraped.bio.length > 1500 ? '…' : '');
  }
  if (scraped.etiquetas && scraped.etiquetas.length > 0) upd.etiquetas = scraped.etiquetas;
  return upd;
}

// ── Formatear línea de diferencia ─────────────────────────────────────────────
function diff(label, valorFS, valorWeb) {
  const vFS  = valorFS  !== undefined && valorFS  !== null ? String(valorFS).substring(0, 60)  : '(vacío)';
  const vWeb = valorWeb !== undefined && valorWeb !== null ? String(valorWeb).substring(0, 60) : '(vacío)';
  return `     ${label.padEnd(14)} FS: ${vFS}\n     ${' '.repeat(14)} WEB: ${vWeb}`;
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '═'.repeat(72));
  console.log(` 🔍  COMPARACIÓN autores web ↔ Firestore Nazarí${APLICAR ? ' [MODO APLICAR]' : ''}`);
  console.log(`     Scope: ${TODOS ? 'TODOS los autores' : 'Solo autores > M (después de la M)'}`);
  console.log('═'.repeat(72) + '\n');

  // ── Cargar JSON de scraping ──────────────────────────────────────────────────
  if (!fs.existsSync(JSON_IN)) {
    console.error(`❌ No encontrado: ${JSON_IN}`);
    console.error('   Ejecuta primero: node scripts/scrape_autores_nazari.js');
    process.exit(1);
  }
  const scraped = JSON.parse(fs.readFileSync(JSON_IN, 'utf8'));
  const webAutores = scraped.autores || [];
  console.log(`📄 JSON de scraping: ${webAutores.length} autores (scraped ${scraped.fecha_scraping})`);

  // Indexar web por nombre normalizado
  const webByNorm = new Map();
  for (const a of webAutores) webByNorm.set(norm(a.nombre), a);

  // ── Leer Firestore ───────────────────────────────────────────────────────────
  initFirebase();
  const db      = admin.firestore();
  const colRef  = db.collection('empresas').doc(EID).collection('autores');
  console.log(`🔥 Leyendo Firestore empresas/${EID}/autores…`);
  const snap = await colRef.get();
  console.log(`   → ${snap.size} documentos en Firestore\n`);

  // Indexar Firestore por nombre normalizado → { docId, data }
  const fsMap = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.nombre) fsMap.set(norm(d.nombre), { docId: doc.id, data: d });
  }

  // ── Filtrar autores a comparar ────────────────────────────────────────────────
  const aComparar = TODOS
    ? webAutores
    : webAutores.filter(a => norm(a.nombre).charAt(0) > 'm');

  console.log(`📋 Autores a comparar: ${aComparar.length}${TODOS ? '' : ' (nombre > M)'}\n`);

  // ── Comparar ─────────────────────────────────────────────────────────────────
  const discrepancias = [];
  const noEnFS  = [];
  const sinBioWeb = [];

  for (const webA of aComparar) {
    const key = norm(webA.nombre);
    const fs_ = fsMap.get(key);

    if (!fs_) {
      noEnFS.push(webA.nombre);
      continue;
    }
    if (!webA.bio) { sinBioWeb.push(webA.nombre); continue; }

    const { data } = fs_;
    const issues   = [];

    // Bio
    if (biosDifieren(data.bio, webA.bio)) {
      issues.push({
        campo: 'bio',
        valorFS:  (data.bio || '').substring(0, 80) + (data.bio && data.bio.length > 80 ? '…' : ''),
        valorWeb: webA.bio.substring(0, 80) + (webA.bio.length > 80 ? '…' : ''),
        detalle:  `FS:${(data.bio || '').length}c → WEB:${webA.bio.length}c (${webA.bio.length - (data.bio || '').length > 0 ? '+' : ''}${webA.bio.length - (data.bio || '').length}c)`,
      });
    }

    // Rol (campo nuevo: si no existe o es diferente)
    if (webA.rol && webA.rol !== data.rol) {
      issues.push({
        campo:    'rol',
        valorFS:  data.rol || '(campo ausente)',
        valorWeb: webA.rol,
        detalle:  !data.rol ? 'Campo nuevo a añadir' : 'Valor diferente',
      });
    }

    // Etiquetas (campo nuevo o incompleto)
    const tagsFS  = Array.isArray(data.etiquetas) ? data.etiquetas : (data.genero ? [data.genero] : []);
    const tagsWeb = webA.etiquetas || [];
    const tagsNew = tagsWeb.filter(t => !tagsFS.map(norm).includes(norm(t)));
    if (tagsWeb.length > 0 && (tagsFS.length === 0 || tagsNew.length > 0)) {
      issues.push({
        campo:    'etiquetas',
        valorFS:  tagsFS.join(', ') || '(campo ausente)',
        valorWeb: tagsWeb.join(', '),
        detalle:  tagsNew.length > 0 ? `Faltan: ${tagsNew.join(', ')}` : 'Campo nuevo',
      });
    }

    if (issues.length > 0) {
      discrepancias.push({ posicion: webA.posicion, nombre: webA.nombre, docId: fs_.docId, issues, webData: webA });
    }
  }

  // ── Reporte ───────────────────────────────────────────────────────────────────
  console.log('─'.repeat(72));
  console.log(`  📊 RESUMEN DE DISCREPANCIAS (autores ${TODOS ? 'totales' : '> M'})\n`);
  console.log(`  Total comparados:          ${aComparar.length}`);
  console.log(`  Con discrepancias:         ${discrepancias.length}`);
  console.log(`  No encontrados en FS:      ${noEnFS.length}`);
  console.log(`  Sin bio en web:            ${sinBioWeb.length}`);
  console.log();

  if (discrepancias.length === 0) {
    console.log('  ✅ Ninguna discrepancia encontrada.\n');
  } else {
    console.log(`  DETALLE (${discrepancias.length} autores con problemas):\n`);
    for (const d of discrepancias) {
      console.log(`  ─── #${String(d.posicion).padStart(3)} ${d.nombre}`);
      for (const issue of d.issues) {
        console.log(`     [${issue.campo.toUpperCase()}] ${issue.detalle}`);
        console.log(`       FS:  ${issue.valorFS.substring(0, 70)}`);
        console.log(`       WEB: ${issue.valorWeb.substring(0, 70)}`);
      }
      console.log();
    }
  }

  if (noEnFS.length > 0) {
    console.log(`  ⚠️  Autores en web no encontrados en Firestore (${noEnFS.length}):`);
    noEnFS.forEach(n => console.log(`       • ${n}`));
    console.log();
  }

  if (!APLICAR) {
    console.log('  ℹ️  Para aplicar las correcciones:\n');
    console.log('     node scripts/sync_autores_firestore.js --aplicar\n');
    console.log('     (También acepta --todos para incluir autores hasta la M)\n');
    process.exit(0);
  }

  // ── Backup ────────────────────────────────────────────────────────────────────
  console.log('─'.repeat(72));
  console.log(`\n  📦 Creando backup en ${BACKUP_F}…`);
  const backupData = {};
  for (const d of discrepancias) {
    backupData[d.docId] = d.webData ? { ...d.webData } : {};
    // También guardar el valor actual de Firestore
    const fsEntry = fsMap.get(norm(d.nombre));
    if (fsEntry) backupData[d.docId]._firestore_actual = { bio: fsEntry.data.bio, rol: fsEntry.data.rol, etiquetas: fsEntry.data.etiquetas, genero: fsEntry.data.genero };
  }
  fs.writeFileSync(BACKUP_F, JSON.stringify(backupData, null, 2), 'utf8');
  console.log(`  ✅ Backup guardado (${Object.keys(backupData).length} documentos)`);

  // ── Aplicar correcciones ──────────────────────────────────────────────────────
  console.log(`\n  🔧 Aplicando ${discrepancias.length} actualizaciones…\n`);

  let batch    = db.batch();
  let batchCnt = 0;
  let aplicados = 0;

  async function flushBatch() {
    if (batchCnt === 0) return;
    await batch.commit();
    batch    = db.batch();
    batchCnt = 0;
  }

  for (const d of discrepancias) {
    const update = buildUpdate(d.webData);
    if (Object.keys(update).length === 0) continue;

    update.fecha_actualizacion = admin.firestore.FieldValue.serverTimestamp();
    batch.update(colRef.doc(d.docId), update);
    batchCnt++;
    aplicados++;

    const campos = Object.keys(update).filter(k => k !== 'fecha_actualizacion').join(', ');
    console.log(`  ✅  #${String(d.posicion).padStart(3)} ${d.nombre.substring(0, 35).padEnd(35)}  [${campos}]`);

    if (batchCnt >= 400) await flushBatch();
  }
  await flushBatch();

  console.log(`\n  ═══════════════════════════════════════════`);
  console.log(`  ✅  Completado: ${aplicados} documentos actualizados en Firestore`);
  console.log(`  📦  Backup en:  ${BACKUP_F}`);
  console.log(`  ═══════════════════════════════════════════\n`);

  process.exit(0);
}

main().catch(e => { console.error('\n❌ Error:', e.message || e); process.exit(1); });
