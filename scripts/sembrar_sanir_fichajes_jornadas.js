#!/usr/bin/env node
/**
 * sembrar_sanir_fichajes_jornadas.js
 * ─────────────────────────────────────────────────────────────────
 * Para Sanir Transporte Sanitario CLM (demo_sanir_clm_2026):
 *
 *  1. Completa empleados_fichaje (jornada/horario) para los 3 usuarios
 *     UID-reales que aún no tienen registro.
 *  2. Crea el fichaje de HOY (2026-11-07) para los empleados sin él.
 *  3. Genera fichajes para el resto del año (8 nov → 31 dic 2026)
 *     respetando los turnos de cada empleado.
 *
 * USO:
 *   node scripts/sembrar_sanir_fichajes_jornadas.js
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');

const SA_PATH = path.join(__dirname, '..', 'credentials.json');
const EID     = 'demo_sanir_clm_2026';

let sa;
try { sa = require(SA_PATH); }
catch (e) { console.error('❌ No se encontró credentials.json'); process.exit(1); }

try { admin.initializeApp({ credential: admin.credential.cert(sa) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db = admin.firestore();
const TS = admin.firestore.Timestamp;

// ── Helpers ───────────────────────────────────────────────────────────────────

function dateStr(year, month, day) {
  return `${year}-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}`;
}

function tsAt(year, month, day, hour, min = 0) {
  return TS.fromDate(new Date(year, month - 1, day, hour, min, 0));
}

// Variación aleatoria determinista basada en hash simple (reproducible)
function jitter(seed, min, max) {
  const hash = ((seed * 2654435761) >>> 0) % (max - min);
  return min + hash;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

// Genera todos los días entre dos fechas (inclusive)
function diasEnRango(desde, hasta) {
  const dias = [];
  const cur = new Date(desde);
  cur.setHours(0, 0, 0, 0);
  hasta.setHours(0, 0, 0, 0);
  while (cur <= hasta) {
    dias.push(new Date(cur));
    cur.setDate(cur.getDate() + 1);
  }
  return dias;
}

// ── Definición de empleados ───────────────────────────────────────────────────

// Los 5 empleados demo con IDs propios
const EMPLEADOS_AMB = [
  { id: 'amb_emp_001', nombre: 'Elena Martín Sanz',   turno: 'manana',  entrada: 7,  salida: 19, jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_002', nombre: 'Roberto López Vega',  turno: 'tarde',   entrada: 19, salida: 7,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_003', nombre: 'Carmen Ruiz Molina',  turno: 'noche',   entrada: 19, salida: 7,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_004', nombre: 'Javier Torres Pérez', turno: 'manana',  entrada: 8,  salida: 15, jornada: 420, dias: [1,1,1,1,1,0,0] },
  { id: 'amb_emp_005', nombre: 'Laura González Díaz', turno: 'manana',  entrada: 8,  salida: 14, jornada: 360, dias: [1,1,1,1,1,0,0] },
];

// Los 3 empleados con UID real de Firebase que aún no tienen empleados_fichaje
const EMPLEADOS_UID = [
  { id: 'SpnOb0ySgRa7Zqe308u0bZx0YJ63', nombre: 'Coordinador Demo', turno: 'manana',  entrada: 8, salida: 17, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'U5TgqYNniEXV6sbqPTWSq3oSQYQ2', nombre: 'Roberto López Vega', turno: 'tarde', entrada: 14, salida: 22, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2', nombre: 'Elena Martín Sanz', turno: 'manana', entrada: 7, salida: 15, jornada: 480, dias: [1,1,1,1,1,0,0] },
];

const TODOS_EMPLEADOS = [...EMPLEADOS_AMB, ...EMPLEADOS_UID];

// ══════════════════════════════════════════════════════════════════════════════
// 1. COMPLETAR empleados_fichaje para los 3 UID-reales
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarJornadas() {
  console.log('\n📋 1. Completando empleados_fichaje (jornadas)...');
  const col = db.collection('empresas').doc(EID).collection('empleados_fichaje');

  const batch = db.batch();
  for (const emp of EMPLEADOS_UID) {
    const ref = col.doc(emp.id);
    batch.set(ref, {
      uid: emp.id,
      empleado_id: emp.id,
      nombre: emp.nombre,
      empresa_id: EID,
      activo: true,
      jornada_diaria: emp.jornada,
      horario_entrada: `${String(emp.entrada).padStart(2,'0')}:00`,
      horario_salida: `${String(emp.salida).padStart(2,'0')}:00`,
      dias_laborables: emp.dias.map(v => v === 1),
      pin: `${1000 + EMPLEADOS_UID.indexOf(emp)}`,
      actualizado_at: TS.fromDate(new Date()),
      es_demo: true,
    }, { merge: true });
  }
  await batch.commit();
  console.log(`   ✅ ${EMPLEADOS_UID.length} jornadas de empleados UID configuradas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. FICHAJE DE HOY (2026-11-07) para los 3 UID-reales
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFichajeHoy() {
  console.log('\n⏱️  2. Fichajes de HOY (2026-11-07) para empleados UID...');
  const col = db.collection('empresas').doc(EID).collection('fichajes');
  const HOY_STR = '2026-11-07';

  // Verificar cuáles ya tienen fichaje hoy
  const snap = await col.where('fecha', '==', HOY_STR).get();
  const yaFichados = new Set(snap.docs.map(d => d.data().empleado_id));

  const batch = db.batch();
  let count = 0;

  for (const emp of TODOS_EMPLEADOS) {
    if (yaFichados.has(emp.id)) continue; // ya tiene fichaje hoy

    const fichajeId = `fich_hoy_${emp.id}`;
    const ref = col.doc(fichajeId);

    // Entrada: hora habitual ± 2-5 min de jitter
    const jit = jitter(emp.id.charCodeAt(0) + 7, 0, 7);
    const entradaH = emp.entrada;
    const entradaM = jit;
    const entradaDate = new Date(2026, 10, 7, entradaH, entradaM, 0);

    // Pausa a mitad de jornada (30 min)
    const mitadMins = emp.jornada / 2;
    const pausaInicioDate = new Date(entradaDate.getTime() + mitadMins * 60000);
    const pausaFinDate    = new Date(pausaInicioDate.getTime() + 30 * 60000);

    // Para turno noche de salida > entrada, la salida es el día siguiente
    // Para empleados sin salida todavía (turno tarde/noche que sigue activo)
    // Los de jornada mañana ya han salido; los de tarde/noche siguen activos
    const ahoraMs  = new Date('2026-11-07T16:30:00').getTime(); // simular ~16:30
    const salidaMs = entradaDate.getTime() + emp.jornada * 60000 + 30 * 60000; // +30 de pausa
    const salidaYaOcurrio = salidaMs < ahoraMs;

    const fichaje = {
      id: fichajeId,
      empresa_id: EID,
      empleado_id: emp.id,
      empleado_nombre: emp.nombre,
      fecha: HOY_STR,
      fecha_ts: TS.fromDate(entradaDate),
      entrada: TS.fromDate(entradaDate),
      salida: salidaYaOcurrio ? TS.fromDate(new Date(salidaMs)) : null,
      pausas: [
        {
          inicio: TS.fromDate(pausaInicioDate),
          fin: TS.fromDate(pausaFinDate),
        }
      ],
      tipo_horas: 'ordinarias',
      dispositivo_id: 'demo_tablet',
      creado_at: TS.fromDate(entradaDate),
      es_correccion: false,
      correcto: true,
      minutos_pausa: 30,
      es_demo: true,
    };

    batch.set(ref, fichaje);
    count++;
    console.log(`   ✅ ${emp.nombre} — entrada ${String(entradaH).padStart(2,'0')}:${String(entradaM).padStart(2,'0')} ${salidaYaOcurrio ? '→ cerrado' : '→ EN JORNADA'}`);
  }

  if (count > 0) await batch.commit();
  else console.log('   ℹ️  Todos los empleados ya tenían fichaje de hoy');
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. FICHAJES RESTO DEL AÑO (8 nov → 31 dic 2026)
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFichajesRestoAno() {
  console.log('\n📆 3. Fichajes resto del año (8 nov – 31 dic 2026)...');
  const col = db.collection('empresas').doc(EID).collection('fichajes');

  const desde = new Date(2026, 10, 8);  // 8 nov
  const hasta  = new Date(2026, 11, 31); // 31 dic
  const dias   = diasEnRango(desde, hasta);

  // Verificar qué fechas+empleados ya existen para no duplicar
  const existSnap = await col
    .where('fecha', '>=', '2026-11-08')
    .where('fecha', '<=', '2026-12-31')
    .get();
  const existentes = new Set(existSnap.docs.map(d => `${d.data().fecha}_${d.data().empleado_id}`));

  let totalGenerados = 0;
  let lote  = db.batch();
  let enLote = 0;

  for (const dia of dias) {
    const year  = dia.getFullYear();
    const month = dia.getMonth() + 1; // 1-based
    const day   = dia.getDate();
    const dow   = dia.getDay(); // 0=dom, 1=lun...6=sab
    const dowIdx = dow === 0 ? 6 : dow - 1; // 0=lun…6=dom
    const diaStr = dateStr(year, month, day);

    for (const emp of TODOS_EMPLEADOS) {
      // Verificar si trabaja este día según sus dias_laborables
      const trabajaEsteDia = emp.dias[dowIdx] === 1;
      if (!trabajaEsteDia) continue;

      const clave = `${diaStr}_${emp.id}`;
      if (existentes.has(clave)) continue;

      // Variación de entrada ±5 min
      const jit = jitter(emp.id.charCodeAt(0) + day + month, -4, 8);
      const entradaH  = emp.entrada;
      const entradaM  = Math.max(0, Math.min(59, jit));

      let entradaDate;
      if (emp.turno === 'noche' && emp.entrada >= 19) {
        // Turno noche: entra a las 19h del día actual
        entradaDate = new Date(year, month - 1, day, 19, entradaM, 0);
      } else {
        entradaDate = new Date(year, month - 1, day, entradaH, entradaM, 0);
      }

      // Salida: jornada + pausa 30 min
      const salidaMs  = entradaDate.getTime() + (emp.jornada + 30) * 60000;
      // Jitter salida
      const jitSal    = jitter(emp.id.charCodeAt(0) + day * 7, -5, 10);
      const salidaDate = new Date(salidaMs + jitSal * 60000);

      // Pausa: a mitad de jornada
      const pausaInicioDate = new Date(entradaDate.getTime() + (emp.jornada / 2) * 60000);
      const pausaFinDate    = new Date(pausaInicioDate.getTime() + 30 * 60000);

      const fichajeId = `fich_${year}${String(month).padStart(2,'0')}${String(day).padStart(2,'0')}_${emp.id}`;
      const ref = col.doc(fichajeId);

      lote.set(ref, {
        id: fichajeId,
        empresa_id: EID,
        empleado_id: emp.id,
        empleado_nombre: emp.nombre,
        fecha: diaStr,
        fecha_ts: TS.fromDate(entradaDate),
        entrada: TS.fromDate(entradaDate),
        salida: TS.fromDate(salidaDate),
        pausas: [{
          inicio: TS.fromDate(pausaInicioDate),
          fin: TS.fromDate(pausaFinDate),
        }],
        tipo_horas: 'ordinarias',
        dispositivo_id: 'demo_tablet',
        creado_at: TS.fromDate(entradaDate),
        es_correccion: false,
        correcto: true,
        minutos_pausa: 30,
        es_demo: true,
      });

      enLote++;
      totalGenerados++;

      if (enLote >= 400) {
        await lote.commit();
        lote  = db.batch();
        enLote = 0;
        process.stdout.write('.');
      }
    }
  }

  if (enLote > 0) await lote.commit();
  console.log(`\n   ✅ ${totalGenerados} fichajes generados (nov–dic 2026)`);
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

async function main() {
  console.log('\n🚑 FICHAJES Y JORNADAS — Sanir Transporte Sanitario CLM');
  console.log(`   empresaId: ${EID}`);
  console.log('═'.repeat(60));

  await sembrarJornadas();
  await sembrarFichajeHoy();
  await sembrarFichajesRestoAno();

  console.log('\n' + '═'.repeat(60));
  console.log('✅ Jornadas y fichajes completados');
  console.log('\n   empleados_fichaje: 8 empleados (5 existentes + 3 nuevos)');
  console.log('   Fichajes hoy: todos los empleados activos fichados');
  console.log('   Fichajes nov-dic 2026: generados para todos los turnos\n');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    process.exit(1);
  });
