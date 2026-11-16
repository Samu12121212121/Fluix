#!/usr/bin/env node
/**
 * sembrar_fichajes_hoy_sanir.js
 * ─────────────────────────────────────────────────────────────────
 * Crea los fichajes de HOY para todos los empleados de Sanir
 * Transporte Sanitario CLM (demo_sanir_clm_2026).
 *
 * — Si el empleado ya tiene fichaje hoy, lo omite.
 * — Empleados mañana (ya salieron): entrada + salida.
 * — Empleados tarde/noche aún en jornada: solo entrada (sin salida).
 *
 * USO:
 *   node scripts/sembrar_fichajes_hoy_sanir.js
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');

const SA_PATH = path.join(__dirname, '..', 'credentials.json');
const EID     = 'demo_sanir_clm_2026';

let sa;
try { sa = require(SA_PATH); }
catch (e) { console.error('❌ No se encontró credentials.json en la raíz del proyecto'); process.exit(1); }

try { admin.initializeApp({ credential: admin.credential.cert(sa) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db = admin.firestore();
const TS = admin.firestore.Timestamp;

// ── Helpers ───────────────────────────────────────────────────────────────────

function jitter(seed, min, max) {
  const hash = ((seed * 2654435761) >>> 0) % (max - min + 1);
  return min + hash;
}

// ── Empleados ─────────────────────────────────────────────────────────────────

const EMPLEADOS = [
  // 5 empleados demo con ID propio (turnos 24h o L-V)
  { id: 'amb_emp_001', nombre: 'Elena Martín Sanz',   turno: 'manana', entrada: 7,  salida: 19, jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_002', nombre: 'Roberto López Vega',  turno: 'tarde',  entrada: 19, salida: 7,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_003', nombre: 'Carmen Ruiz Molina',  turno: 'noche',  entrada: 19, salida: 7,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_004', nombre: 'Javier Torres Pérez', turno: 'manana', entrada: 8,  salida: 15, jornada: 420, dias: [1,1,1,1,1,0,0] },
  { id: 'amb_emp_005', nombre: 'Laura González Díaz', turno: 'manana', entrada: 8,  salida: 14, jornada: 360, dias: [1,1,1,1,1,0,0] },
  // 3 empleados con UID real de Firebase
  { id: 'SpnOb0ySgRa7Zqe308u0bZx0YJ63', nombre: 'Coordinador Demo',   turno: 'manana', entrada: 8,  salida: 17, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'U5TgqYNniEXV6sbqPTWSq3oSQYQ2', nombre: 'Roberto López Vega', turno: 'tarde',  entrada: 14, salida: 22, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2', nombre: 'Elena Martín Sanz',  turno: 'manana', entrada: 7,  salida: 15, jornada: 480, dias: [1,1,1,1,1,0,0] },
];

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const hoy   = new Date();
  const year  = hoy.getFullYear();
  const month = hoy.getMonth() + 1;
  const day   = hoy.getDate();
  const HOY_STR = `${year}-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}`;

  // Día de la semana: 0=lun…6=dom (dowIdx compatible con dias[] del script original)
  const dow    = hoy.getDay(); // 0=dom
  const dowIdx = dow === 0 ? 6 : dow - 1;

  console.log(`\n🚑 FICHAJES DE HOY — Sanir Transporte Sanitario CLM`);
  console.log(`   Empresa : ${EID}`);
  console.log(`   Fecha   : ${HOY_STR}`);
  console.log('═'.repeat(55));

  const col = db.collection('empresas').doc(EID).collection('fichajes');

  // Ver qué empleados ya tienen fichaje hoy
  const snap = await col.where('fecha', '==', HOY_STR).get();
  const yaFichados = new Set(snap.docs.map(d => d.data().empleado_id));

  // Hora actual para saber si la jornada ya terminó
  const ahoraMins = hoy.getHours() * 60 + hoy.getMinutes();

  const batch = db.batch();
  let count = 0;

  for (const emp of EMPLEADOS) {
    // ¿Trabaja hoy?
    if (!emp.dias[dowIdx]) {
      console.log(`   ⏭  ${emp.nombre.padEnd(25)} — no trabaja hoy (${['lun','mar','mié','jue','vie','sáb','dom'][dowIdx]})`);
      continue;
    }

    if (yaFichados.has(emp.id)) {
      console.log(`   ✔  ${emp.nombre.padEnd(25)} — ya tiene fichaje hoy`);
      continue;
    }

    // Entrada con pequeño jitter (±5 min)
    const jit       = jitter(emp.id.charCodeAt(0) + day, -3, 7);
    const entradaH  = emp.entrada;
    const entradaM  = Math.max(0, Math.min(59, jit));
    const entradaDate = new Date(year, month - 1, day, entradaH, entradaM, 0);

    // Pausa a mitad de jornada (30 min)
    const pausaInicioDate = new Date(entradaDate.getTime() + (emp.jornada / 2) * 60000);
    const pausaFinDate    = new Date(pausaInicioDate.getTime() + 30 * 60000);

    // Salida = entrada + jornada + pausa
    const salidaMs         = entradaDate.getTime() + (emp.jornada + 30) * 60000;
    const jitSal           = jitter(emp.id.charCodeAt(0) + day * 3, -4, 8);
    const salidaDate       = new Date(salidaMs + jitSal * 60000);
    const salidaMins       = salidaDate.getHours() * 60 + salidaDate.getMinutes();
    const jornadaTerminada = salidaMins < ahoraMins && emp.turno !== 'noche';

    const fichajeId = `fich_${year}${String(month).padStart(2,'0')}${String(day).padStart(2,'0')}_${emp.id}`;

    batch.set(col.doc(fichajeId), {
      id:               fichajeId,
      empresa_id:       EID,
      empleado_id:      emp.id,
      empleado_nombre:  emp.nombre,
      fecha:            HOY_STR,
      fecha_ts:         TS.fromDate(entradaDate),
      entrada:          TS.fromDate(entradaDate),
      salida:           jornadaTerminada ? TS.fromDate(salidaDate) : null,
      pausas: [{
        inicio: TS.fromDate(pausaInicioDate),
        fin:    TS.fromDate(pausaFinDate),
      }],
      tipo_horas:       'ordinarias',
      dispositivo_id:   'demo_tablet',
      creado_at:        TS.fromDate(entradaDate),
      es_correccion:    false,
      correcto:         true,
      minutos_pausa:    30,
      es_demo:          true,
    });

    const estado = jornadaTerminada ? '→ cerrado' : '→ EN JORNADA';
    console.log(`   ✅ ${emp.nombre.padEnd(25)} ${String(entradaH).padStart(2,'0')}:${String(entradaM).padStart(2,'0')} ${estado}`);
    count++;
  }

  if (count > 0) {
    await batch.commit();
    console.log(`\n✅ ${count} fichaje(s) creado(s) para hoy (${HOY_STR})\n`);
  } else {
    console.log('\nℹ️  Todos los empleados ya tenían fichaje de hoy\n');
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    process.exit(1);
  });
