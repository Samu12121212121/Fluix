/**
 * usuarios_registrados_ayer.js
 * Cuenta cuántos usuarios se registraron ayer en la colección 'usuarios'.
 *
 * Uso:
 *   node functions/scripts/usuarios_registrados_ayer.js
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db   = admin.firestore();
const auth = admin.auth();

async function main() {
  const hoy   = new Date();
  const ayer  = new Date(hoy);
  ayer.setDate(hoy.getDate() - 1);

  const inicio = new Date(ayer.getFullYear(), ayer.getMonth(), ayer.getDate(), 0, 0, 0);
  const fin    = new Date(ayer.getFullYear(), ayer.getMonth(), ayer.getDate(), 23, 59, 59);

  console.log(`\n📅 Buscando registros del ${inicio.toLocaleDateString('es-ES')} (${inicio.toISOString()} → ${fin.toISOString()})\n`);

  // ── Consulta por fecha_registro en colección usuarios ──────────────────────
  const snap = await db.collection('usuarios')
    .where('fecha_registro', '>=', admin.firestore.Timestamp.fromDate(inicio))
    .where('fecha_registro', '<=', admin.firestore.Timestamp.fromDate(fin))
    .get();

  if (snap.empty) {
    // Fallback: buscar por campo 'creado_en' o 'created_at'
    const snap2 = await db.collection('usuarios')
      .where('creado_en', '>=', admin.firestore.Timestamp.fromDate(inicio))
      .where('creado_en', '<=', admin.firestore.Timestamp.fromDate(fin))
      .get();

    if (snap2.empty) {
      console.log('⚠️  No se encontraron registros con campo fecha_registro ni creado_en.');
      console.log('   Intentando listar todos los usuarios de Firebase Auth creados ayer...\n');
      await contarDesdeAuth(inicio, fin);
      return;
    }

    mostrarResultados(snap2, 'creado_en');
    return;
  }

  mostrarResultados(snap, 'fecha_registro');
}

function mostrarResultados(snap, campoFecha) {
  console.log(`✅ Total registros ayer (campo ${campoFecha}): ${snap.size}\n`);
  snap.forEach(doc => {
    const d = doc.data();
    const fecha = d[campoFecha]?.toDate?.()?.toLocaleTimeString('es-ES') ?? '?';
    const nombre = d.nombre || d.name || '(sin nombre)';
    const correo = d.correo || d.email || '(sin correo)';
    const empresaId = d.empresa_id || '(sin empresa)';
    console.log(`  · ${fecha} — ${nombre} <${correo}>  empresa: ${empresaId}`);
  });
  console.log('');
}

async function contarDesdeAuth(inicio, fin) {
  // Firebase Auth no soporta filtro por fecha directamente, listamos y filtramos
  let total = 0;
  const encontrados = [];
  let pageToken;

  do {
    const result = await auth.listUsers(1000, pageToken);
    for (const u of result.users) {
      const creado = new Date(u.metadata.creationTime);
      if (creado >= inicio && creado <= fin) {
        total++;
        encontrados.push(u);
      }
    }
    pageToken = result.pageToken;
  } while (pageToken);

  console.log(`✅ Usuarios creados en Firebase Auth ayer: ${total}\n`);
  encontrados.forEach(u => {
    const hora = new Date(u.metadata.creationTime).toLocaleTimeString('es-ES');
    console.log(`  · ${hora} — ${u.displayName || '(sin nombre)'} <${u.email || u.phoneNumber || u.uid}>`);
  });
  console.log('');
}

main().catch(e => { console.error(e); process.exit(1); });
