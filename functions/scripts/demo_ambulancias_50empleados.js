/**
 * demo_ambulancias_50empleados.js
 * Inserta 50 empleados con fichajes (10 días) y solicitudes de vacaciones.
 * Uso: node functions/scripts/demo_ambulancias_50empleados.js --guardar
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db        = admin.firestore();
const Timestamp  = admin.firestore.Timestamp;
const GUARDAR   = process.argv.includes('--guardar');
const EID       = 'demo_ambulancias_guadalajara_2026';

// ── Datos ficticios ───────────────────────────────────────────────────────────
const NOMBRES = ['Carlos','María','Pedro','Ana','Luis','Laura','Miguel','Carmen','Antonio','Elena',
  'Francisco','Isabel','Javier','Rosa','Manuel','Lucía','David','Teresa','José','Marta',
  'Alejandro','Pilar','Daniel','Beatriz','Pablo','Cristina','Sergio','Nuria','Raúl','Patricia',
  'Alberto','Sandra','Rubén','Alicia','Álvaro','Silvia','Iván','Mónica','Roberto','Verónica',
  'Andrés','Natalia','Hugo','Rebeca','Adrián','Lorena','Marcos','Irene','Diego','Rocío'];

const APELLIDOS1 = ['García','López','Martínez','Sánchez','Pérez','Gómez','Fernández','Rodríguez',
  'González','Hernández','Jiménez','Díaz','Moreno','Álvarez','Romero','Torres','Navarro','Domínguez',
  'Ramos','Gil','Serrano','Molina','Blanco','Morales','Suárez','Ortega','Castro','Ruiz','Vega','Núñez'];

const APELLIDOS2 = ['de la Cruz','del Valle','de Haro','Ortiz','Muñoz','Alonso','Gutiérrez',
  'Cano','Lara','Reyes','Medina','Herrero','León','Prieto','Fuentes','Cabrera','Flores','Pardo',
  'Nieto','Calvo','Bravo','Miranda','Iglesias','Rubio','Crespo','Vargas','Santos','Gallego'];

const PUESTOS = [
  ...Array(20).fill('Técnico en Emergencias Sanitarias'),
  ...Array(14).fill('Conductor Ambulancia'),
  ...Array(8).fill('Enfermero/a de Emergencias'),
  ...Array(4).fill('Médico de Urgencias'),
  ...Array(2).fill('Jefe de Guardia'),
  ...Array(1).fill('Coordinador de Emergencias'),
  'Administrativo/a Sanitario',
];

const TURNOS = [
  { nombre: 'mañana',    entrada: '08:00', hIni: 8,  hFin: 16 },
  { nombre: 'mañana',    entrada: '08:00', hIni: 8,  hFin: 16 },
  { nombre: 'mañana',    entrada: '08:00', hIni: 8,  hFin: 16 },
  { nombre: 'tarde',     entrada: '14:00', hIni: 14, hFin: 22 },
  { nombre: 'tarde',     entrada: '14:00', hIni: 14, hFin: 22 },
  { nombre: 'tarde',     entrada: '14:00', hIni: 14, hFin: 22 },
  { nombre: 'noche',     entrada: '22:00', hIni: 22, hFin: 6  },
  { nombre: 'noche',     entrada: '22:00', hIni: 22, hFin: 6  },
  { nombre: 'rotativo',  entrada: '08:00', hIni: 8,  hFin: 16 },
  { nombre: 'rotativo',  entrada: '08:00', hIni: 8,  hFin: 16 },
];

function pick(arr, seed) { return arr[seed % arr.length]; }
function ts(daysAgo, h, m=0) {
  const d = new Date(); d.setDate(d.getDate() - daysAgo); d.setHours(h, m, 0, 0);
  return Timestamp.fromDate(d);
}
function dateStr(daysAgo) {
  const d = new Date(); d.setDate(d.getDate() - daysAgo);
  return d.toISOString().split('T')[0];
}
function isWeekend(daysAgo) {
  const d = new Date(); d.setDate(d.getDate() - daysAgo);
  return d.getDay() === 0 || d.getDay() === 6;
}

// ── Generar 50 empleados ──────────────────────────────────────────────────────
const empleados = NOMBRES.map((nombre, i) => {
  const ap1   = pick(APELLIDOS1, i * 7 + 3);
  const ap2   = pick(APELLIDOS2, i * 11 + 5);
  const turno = TURNOS[i % TURNOS.length];
  const puesto= PUESTOS[i] || 'Técnico en Emergencias Sanitarias';
  const uid   = `emp_ambu_${String(i+1).padStart(3,'0')}`;
  const email = `${nombre.toLowerCase().replace(/[áéíóú]/g, c => ({á:'a',é:'e',í:'i',ó:'o',ú:'u'}[c]||c))}.${ap1.toLowerCase().split(' ')[0].replace(/[áéíóú]/g, c => ({á:'a',é:'e',í:'i',ó:'o',ú:'u'}[c]||c))}@sysday.es`;
  const pin   = String(1000 + i * 17 % 9000).padStart(4,'0');
  const salario = puesto.includes('Médico') ? 3200 : puesto.includes('Jefe') ? 2400 : puesto.includes('Coordinador') ? 2600 : puesto.includes('Enfermero') ? 2100 : puesto.includes('Administrativo') ? 1600 : 1850;

  return { uid, nombre: `${nombre} ${ap1} ${ap2}`, email, pin, turno, puesto, salario,
    nombreCompleto: `${nombre} ${ap1} ${ap2}` };
});

// ── Generar fichajes (10 días laborables por empleado) ────────────────────────
function generarFichajes(emp) {
  const result = [];
  let dias = 0, daysAgo = 0;
  while (dias < 10 && daysAgo < 20) {
    daysAgo++;
    if (isWeekend(daysAgo)) continue;
    // 5% de ausencias
    if ((emp.uid.charCodeAt(8) + daysAgo) % 20 === 0) continue;
    const t = emp.turno;
    const hIni = t.hIni, hFin = t.hFin;
    // Ligera variación ±10min
    const varMin = ((emp.uid.charCodeAt(9) + daysAgo) % 11) - 5;
    const minNeto = hFin > hIni ? (hFin - hIni) * 60 : (24 - hIni + hFin) * 60;
    result.push({
      id: `${emp.uid}_${dateStr(daysAgo)}`,
      empleado_id:    emp.uid,
      nombre:         emp.nombre,
      empresa_id:     EID,
      fecha:          dateStr(daysAgo),
      entrada:        ts(daysAgo, hIni, Math.max(0, varMin)),
      salida:         ts(daysAgo, hFin, 0),
      estado:         'cerrado',
      pausas:         [],
      tiempo_neto:    minNeto * 60,
      dispositivo_id: `kiosko_0${1 + (parseInt(emp.uid.slice(-3)) % 3)}`,
      creado_en:      ts(daysAgo, hIni, 0),
    });
    dias++;
  }
  return result;
}

// ── Vacaciones (15 empleados) ─────────────────────────────────────────────────
function generarVacaciones(emp, idx) {
  const estados = ['aprobada','aprobada','aprobada','solicitado','solicitado'];
  const estado  = estados[idx % estados.length];
  // Distintos periodos para no solapar todos
  const offset  = idx * 3;
  const inicio  = new Date(); inicio.setDate(inicio.getDate() + 10 + offset);
  const fin     = new Date(inicio); fin.setDate(fin.getDate() + 6);
  return {
    empleado_id:      emp.uid,
    empresa_id:       EID,
    tipo:             'vacaciones',
    fecha_inicio:     Timestamp.fromDate(inicio),
    fecha_fin:        Timestamp.fromDate(fin),
    dias_naturales:   7,
    dias_laborables:  5,
    estado,
    descuento_salario: 0,
    fecha_creacion:   Timestamp.fromDate(new Date()),
    empleado_nombre:  emp.nombre,
  };
}

// ── Saldo vacaciones ──────────────────────────────────────────────────────────
function saldoVacaciones(emp) {
  return {
    empleado_id: emp.uid,
    empresa_id:  EID,
    anio:        2026,
    dias_totales: 23,
    dias_disfrutados: Math.floor(Math.random() * 15),
    dias_pendientes_aprobacion: 0,
    fecha_actualizacion: Timestamp.fromDate(new Date()),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  const allFichajes = empleados.flatMap(generarFichajes);
  const vacaciones  = empleados.slice(0, 15).map((e, i) => generarVacaciones(e, i));

  console.log('\n🚑 Sysday Emergencias — 50 empleados');
  console.log(`  Empleados:  ${empleados.length}`);
  console.log(`  Fichajes:   ${allFichajes.length}`);
  console.log(`  Vacaciones: ${vacaciones.length} (15 empleados)`);
  console.log(`  Turnos:     mañana ${empleados.filter(e=>e.turno.nombre==='mañana').length} | tarde ${empleados.filter(e=>e.turno.nombre==='tarde').length} | noche ${empleados.filter(e=>e.turno.nombre==='noche').length} | rotativo ${empleados.filter(e=>e.turno.nombre==='rotativo').length}\n`);

  if (!GUARDAR) { console.log('⚠️  DRY RUN — usa --guardar\n'); return; }

  // ── Batch 1: empleados + fichajes_empleados ──────────────────────────────
  let b = db.batch();
  for (const e of empleados) {
    b.set(db.collection('empresas').doc(EID).collection('empleados').doc(e.uid), {
      uid: e.uid, nombre: e.nombre, email: e.email,
      puesto: e.puesto, departamento: 'Operaciones', empresa_id: EID, activo: true,
      fecha_alta: Timestamp.fromDate(new Date(2024, 0, 15)),
      datos_nomina: {
        salario_bruto_anual: e.salario * 12,
        num_pagas: 12, pagas_prorrateadas: true,
        tipo_contrato: 'indefinido', horas_semanales: 40,
        estado_civil: 'soltero', num_hijos: 0,
        comunidad_autonoma: 'castillaLaMancha',
        base_acumulada_ytd: e.salario * 10,
        irpf_acumulado_ytd: e.salario * 10 * 0.145,
        mes_ultima_actualizacion: 10, anio_ultima_actualizacion: 2026,
      },
    }, { merge: true });
    b.set(db.collection('empresas').doc(EID).collection('empleados_fichaje').doc(e.uid), {
      uid: e.uid, nombre: e.nombre, pin: e.pin, activo: true,
      jornadaDiaria: 480, horarioEntrada: e.turno.entrada, empresa_id: EID,
      turno: e.turno.nombre,
    }, { merge: true });
  }
  await b.commit();
  console.log('✅ Batch 1/4: empleados + fichajes_empleados');

  // ── Batch 2: fichajes (primeros 450) ─────────────────────────────────────
  b = db.batch();
  for (const f of allFichajes.slice(0, 450)) {
    const { id, ...data } = f;
    b.set(db.collection('empresas').doc(EID).collection('fichajes').doc(id), data, { merge: true });
  }
  await b.commit();
  console.log('✅ Batch 2/4: fichajes 1-450');

  // ── Batch 3: fichajes (resto) ─────────────────────────────────────────────
  if (allFichajes.length > 450) {
    b = db.batch();
    for (const f of allFichajes.slice(450)) {
      const { id, ...data } = f;
      b.set(db.collection('empresas').doc(EID).collection('fichajes').doc(id), data, { merge: true });
    }
    await b.commit();
    console.log('✅ Batch 3/4: fichajes restantes');
  }

  // ── Batch 4: vacaciones + saldos ──────────────────────────────────────────
  b = db.batch();
  for (const v of vacaciones) {
    b.set(db.collection('vacaciones').doc(EID).collection('solicitudes').doc(), v);
  }
  for (const e of empleados) {
    b.set(db.collection('vacaciones').doc(EID).collection('saldos').doc(e.uid),
      saldoVacaciones(e), { merge: true });
  }
  await b.commit();
  console.log('✅ Batch 4/4: vacaciones + saldos\n');

  // Resumen de turnos
  const mt = empleados.filter(e=>e.turno.nombre==='mañana').length;
  const tt = empleados.filter(e=>e.turno.nombre==='tarde').length;
  const nt = empleados.filter(e=>e.turno.nombre==='noche').length;
  const rt = empleados.filter(e=>e.turno.nombre==='rotativo').length;
  console.log('📋 Resumen:');
  console.log(`  · 50 empleados (pins del 1000 al 9999 únicos)`);
  console.log(`  · Turnos: mañana ${mt} | tarde ${tt} | noche ${nt} | rotativo ${rt}`);
  console.log(`  · ${allFichajes.length} fichajes de los últimos 10 días laborables`);
  console.log(`  · 15 solicitudes vacaciones (10 aprobadas, 5 pendientes)`);
  console.log(`  · 50 saldos de vacaciones (23 días/año)`);
  console.log('\n  Primeros 5 PINs:');
  empleados.slice(0,5).forEach(e => console.log(`    ${e.pin} → ${e.nombre} (${e.turno.nombre})`));
  console.log('  ...\n');
}

main().catch(e => { console.error(e); process.exit(1); });
