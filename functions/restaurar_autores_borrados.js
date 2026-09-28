/**
 * restaurar_autores_borrados.js
 * ──────────────────────────────────────────────────────────────────────────
 * Restaura los docs de autores borrados leyendo Firestore a una hora anterior.
 *
 * Uso:
 *   node restaurar_autores_borrados.js                  (usa 6h atrás por defecto)
 *   node restaurar_autores_borrados.js --horas 3        (3 horas atrás)
 *   node restaurar_autores_borrados.js --horas 12       (12 horas atrás)
 *   node restaurar_autores_borrados.js --dry-run        (solo muestra, no escribe)
 * ──────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');

const DRY_RUN = process.argv.includes('--dry-run');
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// Uso: --hora HH:MM [--dia DD]   (día del mes, por defecto 22)
// Ejemplo ayer a las 23:00:  node restaurar_autores_borrados.js --hora 23:00 --dia 21 --dry-run
const horaIdx    = process.argv.indexOf('--hora');
const diaIdx     = process.argv.indexOf('--dia');
const horaMadrid = horaIdx >= 0 ? process.argv[horaIdx + 1] : '12:50';
const diaMes     = diaIdx  >= 0 ? parseInt(process.argv[diaIdx + 1]) : 22;
const [hh, mm]   = horaMadrid.split(':').map(Number);
// Septiembre en España = UTC+2 (CEST) → restamos 2h para obtener UTC
let utcHH = hh - 2, utcDia = diaMes;
if (utcHH < 0) { utcHH += 24; utcDia -= 1; }
const LEER_DESDE_UTC = new Date(Date.UTC(2026, 8, utcDia, utcHH, mm, 0));

// ── Credenciales ─────────────────────────────────────────────────────────────
const saPath = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(saPath)) {
  admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
} else {
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  let rt = null;
  for (const p of candidates) {
    try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); rt = d?.tokens?.refresh_token; if (rt) break; } catch (_) {}
  }
  if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token de Firebase CLI.'); process.exit(1); }
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

// IDs de los docs borrados (para incluirlos también aunque ya no existan)
const DELETED_IDS = [
  '3',   '6',   '14',  '26',  '27',  '28',  '32',  '37',
  '40',  '52',  '54',  '66',  '69',  '81',  '82',  '98',
  '107', '114', '117', '130', '147', '149', '152', '154',
  'naz-teresa-munoz-valera',
];

async function main() {
  const db     = admin.firestore();
  const colRef = db.collection('empresas').doc(EID).collection('autores');

  const readTime = admin.firestore.Timestamp.fromMillis(LEER_DESDE_UTC.getTime());
  const fechaLectura = new Date(readTime.toMillis()).toLocaleString('es-ES', { timeZone: 'Europe/Madrid' });
  console.log(`\n📅 Leyendo Firestore a las ${horaMadrid} hora Madrid → ${LEER_DESDE_UTC.toISOString()} UTC`);
  console.log(`   (Firestore confirma: ${fechaLectura})\n`);

  // 1. IDs actuales en Firestore
  const currentSnap = await colRef.get();
  const currentIds  = new Set(currentSnap.docs.map(d => d.id));

  // 2. Combinar: actuales + los borrados
  const allIds = [...new Set([...currentIds, ...DELETED_IDS])];
  console.log(`  📋 Docs a leer en histórico: ${allIds.length} (${currentIds.size} actuales + ${DELETED_IDS.filter(id => !currentIds.has(id)).length} borrados)`);

  // 3. Leer en lotes de 300 (límite de getAll)
  const aRestaurar = [];
  for (let i = 0; i < allIds.length; i += 290) {
    const lote    = allIds.slice(i, i + 290);
    const refs    = lote.map(id => colRef.doc(id));
    let   snaps;
    try {
      snaps = await db.getAll(...refs, { readTime });
    } catch (e) {
      console.error(`❌ Error leyendo lote ${i}-${i + lote.length}:`, e.message);
      process.exit(1);
    }
    for (const snap of snaps) {
      if (!snap.exists) {
        console.log(`  ⚠️  No existía a esa hora: ${snap.id}`);
        continue;
      }
      const data = snap.data();
      const bio  = data.bio || data.descripcion || '';
      const gen  = data.genero || '—';
      console.log(`  ✅ ${snap.id.padEnd(45)} "${(data.nombre||'?').padEnd(35)}" bio:${String(bio.length).padStart(4)}c  género:${gen}`);
      aRestaurar.push({ id: snap.id, data });
    }
  }

  console.log(`\n📋 Total a restaurar: ${aRestaurar.length} docs`);

  if (DRY_RUN) {
    console.log('\n[DRY-RUN] No se escribió nada. Ejecuta sin --dry-run para restaurar.');
    return;
  }

  if (!aRestaurar.length) {
    console.log('⚠️  Ningún doc encontrado en ese momento. Prueba con más horas (--horas 12).');
    process.exit(0);
  }

  // Confirmar antes de escribir
  console.log('\n⚠️  Se van a restaurar los datos tal como estaban. Los cambios actuales en esos docs se sobreescribirán.');

  let batch = db.batch();
  let cnt   = 0;
  let ok    = 0;

  for (const { id, data } of aRestaurar) {
    batch.set(colRef.doc(id), {
      ...data,
      fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    ok++;
    cnt++;
    if (cnt === 400) {
      await batch.commit();
      batch = db.batch();
      cnt   = 0;
    }
  }
  if (cnt > 0) await batch.commit();

  console.log(`\n✅ Restaurados ${ok} docs con sus datos históricos.`);
  console.log(`\nSiguiente paso: ejecuta asignar_prioridades_nazari.js para que tengan el orden correcto.`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
