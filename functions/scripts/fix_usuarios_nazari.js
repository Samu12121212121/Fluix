/**
 * fix_usuarios_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Limpia los usuarios de Editorial Nazarí:
 *   1) Lista todos los usuarios de la empresa para que puedas confirmar
 *   2) Borra el documento con nombre "Alejandro" (duplicado)
 *   3) Actualiza el documento con nombre "Nazarí" / "Editorial Nazarí"
 *      para que pase a llamarse "Alejandro" conservando su email y uid
 *
 * Uso:
 *   node scripts/fix_usuarios_nazari.js --dry-run   ← solo lista, no toca nada
 *   node scripts/fix_usuarios_nazari.js              ← ejecuta los cambios
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const DRY_RUN  = process.argv.includes('--dry-run');

async function main() {
  console.log(`\n── Usuarios de Editorial Nazarí (empresa: ${EID}) ──────────────────`);

  const snap = await db.collection('usuarios')
    .where('empresa_id', '==', EID)
    .get();

  if (snap.empty) {
    console.log('⚠  No se encontraron usuarios para esta empresa.');
    return;
  }

  const usuarios = snap.docs.map(d => ({
    uid:    d.id,
    nombre: d.data().nombre ?? '(sin nombre)',
    email:  d.data().email  ?? '(sin email)',
    rol:    d.data().rol    ?? d.data().puesto ?? '(sin rol)',
    estado: d.data().estado ?? 'activo',
  }));

  console.log('\nUID                              | Nombre                  | Email                          | Rol');
  console.log('─'.repeat(110));
  for (const u of usuarios) {
    console.log(`${u.uid.padEnd(32)} | ${u.nombre.padEnd(23)} | ${u.email.padEnd(30)} | ${u.rol}`);
  }
  console.log('');

  // ── Identificar los documentos a modificar ────────────────────────────────
  const nombreLower = (n) => (n ?? '').toLowerCase().trim();

  const docAlejandro = usuarios.find(u =>
    nombreLower(u.nombre) === 'alejandro' ||
    nombreLower(u.nombre).startsWith('alejandro ')
  );

  const docNazari = usuarios.find(u =>
    nombreLower(u.nombre).includes('nazari') ||
    nombreLower(u.nombre).includes('nazarí') ||
    nombreLower(u.nombre).includes('editorial')
  );

  if (!docAlejandro && !docNazari) {
    console.log('ℹ  No se encontró ningún documento que coincida con los criterios.');
    console.log('   Revisa la tabla de arriba y edita manualmente el script si los nombres son distintos.');
    return;
  }

  console.log('── Acciones a realizar ─────────────────────────────────────────────');
  if (docAlejandro) {
    console.log(`  🗑  BORRAR  → uid=${docAlejandro.uid}  nombre="${docAlejandro.nombre}"  email="${docAlejandro.email}"`);
  } else {
    console.log('  ⏭  No se encontró documento "Alejandro" para borrar.');
  }

  if (docNazari) {
    console.log(`  ✏  RENOMBRAR → uid=${docNazari.uid}  "${docNazari.nombre}" → "Alejandro"  (email conservado: ${docNazari.email})`);
  } else {
    console.log('  ⏭  No se encontró documento "Nazarí/Editorial" para renombrar.');
  }

  if (DRY_RUN) {
    console.log('\n⚠  Modo --dry-run: no se han realizado cambios.\n');
    return;
  }

  // ── Ejecutar ──────────────────────────────────────────────────────────────
  const batch = db.batch();

  if (docAlejandro) {
    batch.delete(db.collection('usuarios').doc(docAlejandro.uid));
  }

  if (docNazari) {
    batch.update(db.collection('usuarios').doc(docNazari.uid), {
      nombre: 'Alejandro',
    });
  }

  await batch.commit();
  console.log('\n✅ Cambios aplicados correctamente.\n');
}

main().catch(e => { console.error('Error:', e); process.exit(1); });
