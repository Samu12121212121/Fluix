/**
 * configurar_suscripcion_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Establece los módulos exactos que puede ver Editorial Nazarí.
 * Usa modulos_override para forzar la lista sin depender de packs/addons.
 *
 * Módulos del plan base que Nazarí tiene:
 *   dashboard, reservas, clientes, servicios, empleados,
 *   valoraciones, estadisticas, contenido_web (=web)
 *
 * Uso:
 *   cd functions
 *   node scripts/configurar_suscripcion_nazari.js           ← dry-run
 *   node scripts/configurar_suscripcion_nazari.js --aplicar ← escribe
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const APLICAR = process.argv.includes('--aplicar');

// ── Módulos que Nazarí debe ver — ajusta esta lista si contratan más ──────────
const MODULOS_NAZARI = [
  'dashboard',
  'clientes',
  'web',           // contenido web
  'contenido_web', // alias por si el sistema usa este ID
  'reservas',
  'servicios',
  'empleados',
  'valoraciones',
  'estadisticas',
  'tareas',        // ← quitar si no tienen add-on Tareas
];

async function run() {
  console.log('\n🏢 Configurar suscripción — Editorial Nazarí');
  console.log(`   Empresa : ${EID}`);
  console.log(`   Modo    : ${APLICAR ? '✏️  APLICAR (escribe en Firestore)' : '🔍 DRY-RUN'}\n`);

  // Leer suscripción actual
  const ref  = db.collection('empresas').doc(EID).collection('suscripcion').doc('actual');
  const snap = await ref.get();

  if (snap.exists) {
    const d = snap.data();
    console.log('📄 Suscripción actual en Firestore:');
    console.log('   estado          :', d.estado);
    console.log('   plan_base       :', d.plan_base);
    console.log('   packs_activos   :', JSON.stringify(d.packs_activos));
    console.log('   addons_activos  :', JSON.stringify(d.addons_activos));
    console.log('   modulos_override:', JSON.stringify(d.modulos_override));
  } else {
    console.log('⚠️  No existe documento suscripcion/actual — se creará.');
  }

  console.log('\n📋 Módulos que se configurarán:');
  MODULOS_NAZARI.forEach(m => console.log(`   · ${m}`));

  const payload = {
    estado:           'ACTIVA',
    plan_base:        'basico',
    packs_activos:    [],
    addons_activos:   [],
    modulos_override: MODULOS_NAZARI,
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (!APLICAR) {
    console.log('\n💡 Ejecuta con --aplicar para escribir en Firestore.\n');
    return;
  }

  await ref.set(payload, { merge: true });

  // Limpiar también configuracion_modulos para que coincida
  const confRef = db.collection('empresas').doc(EID)
    .collection('configuracion').doc('modulos');
  const confSnap = await confRef.get();
  if (confSnap.exists) {
    const modulos = (confSnap.data()?.modulos || []).map(m => ({
      ...m,
      activo: MODULOS_NAZARI.includes(m.id),
    }));
    await confRef.update({ modulos, ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp() });
    console.log('✅ configuracion/modulos actualizado también.');
  }

  console.log(`\n🎉 Listo. Nazarí ahora solo ve: ${MODULOS_NAZARI.filter(m => m !== 'contenido_web').join(', ')}\n`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
