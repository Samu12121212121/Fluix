#!/usr/bin/env node
/**
 * Busca empresas de ambulancias en Firestore y muestra sus empleados/nóminas.
 * Uso: node scripts/buscar_empresa_ambulancias.js [--generar]
 * En el IDE: ! node scripts/buscar_empresa_ambulancias.js
 */

const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const FUNCTIONS_MODULES = path.join(ROOT, 'functions', 'node_modules');

let admin;
try {
  admin = require(path.join(FUNCTIONS_MODULES, 'firebase-admin'));
} catch (e) {
  console.error('❌ firebase-admin no encontrado. Ejecuta: cd functions && npm install');
  process.exit(1);
}

const PROJECT_ID = 'planeaapp-4bea4';

try {
  admin.initializeApp({ projectId: PROJECT_ID });
} catch (e) {
  if (!e.message.includes('already exists')) {
    console.error('❌ Sin credenciales. Ejecuta: gcloud auth application-default login');
    process.exit(1);
  }
}

const db = admin.firestore();
const GENERAR = process.argv.includes('--generar');
const now = new Date();
const MES = now.getMonth() + 1;
const ANIO = now.getFullYear();

const SECTORES = ['ambulancia', 'ambulancias', 'transporte_sanitario', 'emergencias_sanitarias', 'tes', 'transporte sanitario'];

async function main() {
  console.log('\n🔍 Consultando todas las empresas...\n');

  const snap = await db.collection('empresas').get();
  console.log(`Total empresas en Firestore: ${snap.docs.length}\n`);

  const ambulancias = snap.docs.filter(doc => {
    const sector = (doc.data().sector || '').toLowerCase().trim();
    return SECTORES.some(s => sector.includes(s.replace('_', ' ')) || sector.includes(s));
  });

  if (ambulancias.length === 0) {
    console.log('⚠️  Ninguna empresa con sector ambulancias encontrada.');
    console.log('\nTodas las empresas y sus sectores:');
    snap.docs.forEach(d => {
      const data = d.data();
      console.log(`  • ${(data.nombre || '(sin nombre)').substring(0,30).padEnd(32)} | sector: ${data.sector || '—'} | id: ${d.id}`);
    });
    return;
  }

  for (const empDoc of ambulancias) {
    const data = empDoc.data();
    console.log('════════════════════════════════════════════════════════════');
    console.log(`🏥 ${data.nombre || '(sin nombre)'}`);
    console.log(`   ID:     ${empDoc.id}`);
    console.log(`   Sector: ${data.sector}`);
    console.log(`   CIF:    ${data.cif || '—'}`);

    const empSnap = await db.collection('usuarios')
      .where('empresa_id', '==', empDoc.id)
      .where('activo', '==', true)
      .get();

    const conDatos = empSnap.docs.filter(d => d.data().datos_nomina);

    console.log(`\n   👥 Empleados activos (en usuarios/): ${empSnap.docs.length}`);
    console.log(`   📋 Con datos_nomina:                 ${conDatos.length}`);

    if (conDatos.length > 0 && empSnap.docs.length > 0) {
      console.log('\n   Lista de empleados con datos_nomina:');
      conDatos.forEach(d => {
        const emp = d.data();
        const dn = emp.datos_nomina || {};
        console.log(`     • ${(emp.nombre || d.id).padEnd(28)} | ${dn.salario_bruto_anual || '—'}€/año | ${emp.puesto || '—'}`);
      });
    }

    const nominasSnap = await db.collection('empresas').doc(empDoc.id)
      .collection('nominas')
      .where('mes', '==', MES)
      .where('anio', '==', ANIO)
      .get();

    console.log(`\n   📄 Nóminas ${MES}/${ANIO} ya en Firestore: ${nominasSnap.docs.length}`);

    if (GENERAR && nominasSnap.docs.length === 0 && conDatos.length > 0) {
      console.log('\n   ⚠️  La generación requiere el motor Dart (IRPF, SS, convenios).');
      console.log('   ➡️  Pasos para generar desde la app:');
      console.log(`        1. Abre Fluix como propietario de plataforma`);
      console.log(`        2. En el panel → "Ver como empresa" → selecciona "${data.nombre}"`);
      console.log(`        3. Módulo Nóminas → botón "Generar nóminas"`);
      console.log(`\n   📌 ID de empresa: ${empDoc.id}`);
    }
  }

  console.log('\n════════════════════════════════════════════════════════════\n');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    if (e.code === 7 || e.message?.includes('credentials') || e.message?.includes('UNAUTHENTICATED')) {
      console.error('\n❌ Sin credenciales de Google Cloud.');
      console.error('   Ejecuta: ! gcloud auth application-default login');
    } else {
      console.error('\n❌ Error:', e.message);
    }
    process.exit(1);
  });
