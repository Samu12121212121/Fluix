/**
 * demo_ambulancias_data.js
 * Inserta datos de prueba realistas para la demo de Sysday Emergencias.
 *
 * Uso:
 *   node functions/scripts/demo_ambulancias_data.js              ← dry run
 *   node functions/scripts/demo_ambulancias_data.js --guardar    ← escribe en Firestore
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db        = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp  = admin.firestore.Timestamp;

const EMPRESA_ID     = 'demo_ambulancias_guadalajara_2026';
const ELENA_UID      = 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2';
const PROPIETARIO_UID = 'Im2f7o104aSdKPwewHtmMjQAv6j2';
const GUARDAR        = process.argv.includes('--guardar');

function ts(daysAgo, hour = 8, min = 0) {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  d.setHours(hour, min, 0, 0);
  return Timestamp.fromDate(d);
}

// ── 1. Empresa: activar fotos en fichaje ──────────────────────────────────────
const empresaUpdate = { fichaje_fotos_entrada: true };

// ── 2. Empleados en la colección de fichajes ──────────────────────────────────
const empleados = [
  { uid: ELENA_UID,  nombre: 'Elena Martín Sanz',   pin: '1234', activo: true, jornadaDiaria: 480, horarioEntrada: '08:00', empresa_id: EMPRESA_ID },
  { uid: 'emp_roberto_lopez', nombre: 'Roberto López Vega', pin: '5678', activo: true, jornadaDiaria: 480, horarioEntrada: '08:00', empresa_id: EMPRESA_ID },
  { uid: 'emp_lucia_rdz',     nombre: 'Lucía Rodríguez',    pin: '9012', activo: true, jornadaDiaria: 480, horarioEntrada: '14:00', empresa_id: EMPRESA_ID },
];

// ── 3. Fichajes de los últimos 7 días ─────────────────────────────────────────
function fichajeDoc(empleadoId, nombre, daysAgo, entradaH, salidaH) {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() - daysAgo);
  const fechaStr = fecha.toISOString().split('T')[0];
  const minutosTrabajados = (salidaH - entradaH) * 60;
  return {
    id: `${empleadoId}_${fechaStr}`,
    data: {
      empleado_id:   empleadoId,
      nombre:        nombre,
      empresa_id:    EMPRESA_ID,
      fecha:         fechaStr,
      entrada:       ts(daysAgo, entradaH, 0),
      salida:        ts(daysAgo, salidaH, 0),
      estado:        'cerrado',
      pausas:        [],
      tiempo_neto:   minutosTrabajados * 60,
      dispositivo_id: 'kiosko_01',
      creado_en:     ts(daysAgo, entradaH, 0),
    }
  };
}

const fichajes = [
  fichajeDoc(ELENA_UID,          'Elena Martín Sanz',   1, 8,  16),
  fichajeDoc(ELENA_UID,          'Elena Martín Sanz',   2, 8,  16),
  fichajeDoc(ELENA_UID,          'Elena Martín Sanz',   3, 8,  16),
  fichajeDoc(ELENA_UID,          'Elena Martín Sanz',   5, 8,  16),
  fichajeDoc(ELENA_UID,          'Elena Martín Sanz',   6, 8,  16),
  fichajeDoc('emp_roberto_lopez','Roberto López Vega',  1, 14, 22),
  fichajeDoc('emp_roberto_lopez','Roberto López Vega',  2, 14, 22),
  fichajeDoc('emp_lucia_rdz',    'Lucía Rodríguez',     1, 22, 6),
  fichajeDoc('emp_lucia_rdz',    'Lucía Rodríguez',     2, 22, 6),
];

// ── 4. Documentos de Elena (contratos) ───────────────────────────────────────
const documentosElena = [
  {
    id: 'contrato_elena_2026',
    data: {
      nombre:         'Contrato de Trabajo Indefinido — Elena Martín Sanz',
      categoria:      'Contrato',
      url:            '',
      bytes:          0,
      es_de_empresa:  true,
      requiere_firma: false,
      estado_firma:   'firmado',
      firmado:        true,
      firma_fecha:    ts(0, 10, 11),
      firma_uid:      ELENA_UID,
      firma_email:    'elena.martin@fluixtest.com',
      hash_documento: 'a3f1c2d4e5b6789012345678901234567890abcdef1234567890abcdef123456',
      audit_firma: {
        uid:              ELENA_UID,
        email:            'elena.martin@fluixtest.com',
        otp_metodo:       'firebase_phone',
        hash_documento:   'a3f1c2d4e5b6789012345678901234567890abcdef1234567890abcdef123456',
        hash_verificado:  true,
        norma_aplicada:   'eIDAS Reglamento (UE) 910/2014 art. 26',
      },
      creado_en:      ts(10, 9, 0),
    }
  },
  {
    id: 'protocolo_ambulancias',
    data: {
      nombre:         'Protocolo de Actuación — Emergencias Sanitarias 2026',
      categoria:      'Certificado',
      url:            '',
      bytes:          0,
      es_de_empresa:  true,
      requiere_firma: true,
      estado_firma:   'pendiente',
      firmado:        false,
      firma_solicitada: ts(1, 9, 0),
      creado_en:      ts(1, 9, 0),
    }
  },
];

// ── 5. Tareas asignadas a Elena ───────────────────────────────────────────────
const tareas = [
  {
    titulo:      'Revisar protocolo COVID-19 actualizado',
    descripcion: 'Leer y confirmar el nuevo protocolo de actuación ante casos COVID-19 en ambulancia.',
    asignado_a:  ELENA_UID,
    asignado_nombre: 'Elena Martín Sanz',
    estado:      'pendiente',
    prioridad:   'alta',
    fecha_limite: ts(-3), // en 3 días
    empresa_id:  EMPRESA_ID,
    creado_por:  PROPIETARIO_UID,
    creado_en:   ts(2),
  },
  {
    titulo:      'Completar formación RCP avanzado',
    descripcion: 'Completar el módulo online de RCP avanzado en la plataforma de formación.',
    asignado_a:  ELENA_UID,
    asignado_nombre: 'Elena Martín Sanz',
    estado:      'en_progreso',
    prioridad:   'media',
    fecha_limite: ts(-7),
    empresa_id:  EMPRESA_ID,
    creado_por:  PROPIETARIO_UID,
    creado_en:   ts(5),
  },
  {
    titulo:      'Revisión equipamiento ambulancia A-07',
    descripcion: 'Comprobar y rellenar el checklist de equipamiento de la ambulancia asignada.',
    asignado_a:  ELENA_UID,
    asignado_nombre: 'Elena Martín Sanz',
    estado:      'completada',
    prioridad:   'alta',
    empresa_id:  EMPRESA_ID,
    creado_por:  PROPIETARIO_UID,
    creado_en:   ts(3),
    completada_en: ts(1),
  },
];

// ── 6. Nóminas de Elena (últimos 2 meses) ────────────────────────────────────
const nominas = [
  {
    empleado_id:   ELENA_UID,
    nombre:        'Elena Martín Sanz',
    mes:           10,
    anio:          2026,
    salario_bruto: 1850.00,
    irpf:          15.5,
    ss_empleado:   6.35,
    salario_neto:  1448.75,
    estado:        'pagada',
    fecha_pago:    ts(5, 10, 0),
    empresa_id:    EMPRESA_ID,
  },
  {
    empleado_id:   ELENA_UID,
    nombre:        'Elena Martín Sanz',
    mes:           9,
    anio:          2026,
    salario_bruto: 1850.00,
    irpf:          15.5,
    ss_empleado:   6.35,
    salario_neto:  1448.75,
    estado:        'pagada',
    fecha_pago:    ts(35, 10, 0),
    empresa_id:    EMPRESA_ID,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// DRY RUN / GUARDAR
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\n🚑 Sysday Emergencias — Demo Data');
  console.log(`   Empresa: ${EMPRESA_ID}`);
  console.log(`   Elena UID: ${ELENA_UID}\n`);

  if (!GUARDAR) {
    console.log('⚠️  DRY RUN — usa --guardar para escribir\n');
    console.log('  Empresa update:', JSON.stringify(empresaUpdate));
    console.log(`  Empleados: ${empleados.length}`);
    console.log(`  Fichajes:  ${fichajes.length}`);
    console.log(`  Docs Elena: ${documentosElena.length}`);
    console.log(`  Tareas:    ${tareas.length}`);
    console.log(`  Nóminas:   ${nominas.length}\n`);
    return;
  }

  const batch = db.batch();

  // Empresa config
  batch.update(db.collection('empresas').doc(EMPRESA_ID), empresaUpdate);

  // Empleados (fichaje)
  for (const e of empleados) {
    batch.set(
      db.collection('empresas').doc(EMPRESA_ID).collection('fichajes_empleados').doc(e.uid),
      e, { merge: true }
    );
  }

  // Fichajes
  for (const f of fichajes) {
    batch.set(
      db.collection('empresas').doc(EMPRESA_ID).collection('fichajes').doc(f.id),
      f.data, { merge: true }
    );
  }

  // Documentos Elena
  for (const d of documentosElena) {
    batch.set(
      db.collection('usuarios').doc(ELENA_UID).collection('documentos').doc(d.id),
      d.data, { merge: true }
    );
  }

  // Tareas
  for (const t of tareas) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('tareas').doc();
    batch.set(ref, t);
  }

  await batch.commit();
  console.log('✅ Empresa, empleados, fichajes, documentos y tareas guardados');

  // Nóminas (batch separado)
  const batch2 = db.batch();
  for (const n of nominas) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('nominas').doc(
      `${n.empleado_id}_${n.anio}_${String(n.mes).padStart(2,'0')}`
    );
    batch2.set(ref, n, { merge: true });
  }
  await batch2.commit();
  console.log('✅ Nóminas guardadas');

  console.log('\n📋 Resumen:');
  console.log(`  · fichaje_fotos_entrada: true (activado en empresa)`);
  console.log(`  · ${empleados.length} empleados registrados en fichaje`);
  console.log(`  · ${fichajes.length} fichajes de los últimos 7 días`);
  console.log(`  · ${documentosElena.length} documentos para Elena (1 firmado, 1 pendiente)`);
  console.log(`  · ${tareas.length} tareas asignadas a Elena`);
  console.log(`  · ${nominas.length} nóminas (sep + oct 2026)\n`);
}

main().catch(e => { console.error(e); process.exit(1); });
