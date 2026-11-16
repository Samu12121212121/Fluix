/**
 * LIMPIAR negocios_publicos — conserva solo los autorizados
 *
 * Mantiene: demos internos + los 4 negocios cargados desde webs.
 * Elimina: cualquier otro documento de la colección.
 *
 * Ejecutar: node scripts/limpiar_negocios_publicos.js
 * Requisitos: serviceAccountKey.json en functions/
 * ⚠️  Operación destructiva — revisar CONSERVAR antes de ejecutar.
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// IDs que deben permanecer (demos internos + webs nuevos)
const CONSERVAR = new Set([
  // ── Demos Fluix ────────────────────────────────────────
  'demo_peluqueria_fluix2026',
  'demo_bar_fluix2026',

  // ── Negocios de webs (oct 2026) ────────────────────────
  'laude_servibelleza',
  'cristina_aguilera_aesthetic',
  'clinica_carlos_gomez_guadalajara',
  'medicina_estetica_glow',
]);

async function main() {
  const snap = await db.collection('negocios_publicos').get();
  console.log(`\n📋 Total documentos encontrados: ${snap.docs.length}`);

  const aEliminar = snap.docs.filter(d => !CONSERVAR.has(d.id));
  const aConservar = snap.docs.filter(d => CONSERVAR.has(d.id));

  console.log(`✅ A conservar (${aConservar.length}): ${aConservar.map(d => d.id).join(', ')}`);
  console.log(`🗑️  A eliminar (${aEliminar.length}): ${aEliminar.map(d => `${d.id} (${d.data().nombre})`).join(', ')}`);

  if (aEliminar.length === 0) {
    console.log('\n✨ Nada que eliminar.');
    process.exit(0);
  }

  console.log('\n⏳ Eliminando...');
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let ops = 0;

  for (const doc of aEliminar) {
    batch.delete(doc.ref);
    ops++;
    if (ops >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  console.log(`\n✅ Eliminados ${aEliminar.length} documentos.`);
  console.log(`📌 Colección final: ${CONSERVAR.size} negocios.`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e); process.exit(1); });
