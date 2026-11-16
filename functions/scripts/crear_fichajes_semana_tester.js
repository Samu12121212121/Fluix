'use strict';

/**
 * crear_fichajes_semana_tester.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Inserta fichajes de ejemplo para la cuenta Tester Staff durante la semana
 * actual (lunes → hoy). Los datos simulan una jornada laboral normal con
 * pausa para comer.
 *
 * Uso:
 *   cd functions
 *   node scripts/crear_fichajes_semana_tester.js
 *   node scripts/crear_fichajes_semana_tester.js --dry-run
 * ──────────────────────────────────────────────────────────────────────────────
 */

const admin  = require('firebase-admin');
const crypto = require('crypto');

const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => { const [k, ...v] = a.slice(2).split('='); return [k, v.join('=') || true]; })
);
const DRY_RUN = args['dry-run'] === true || args['dry-run'] === 'true';

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// ── Configuración ─────────────────────────────────────────────────────────────
const EMPLEADO_ID     = 'n3LqOP10szdZKFOjAuW6GDKfxuM2';
const EMPLEADO_NOMBRE = 'Tester Staff';

// ── Helpers ───────────────────────────────────────────────────────────────────
function firmaIntegridad(empleadoId, fecha, entradaMs, dispositivoId) {
  const str = `${empleadoId}|${fecha}|${entradaMs ?? 0}|${dispositivoId}`;
  return crypto.createHash('sha256').update(str).digest('hex');
}

function formatDate(d) {
  const y   = d.getFullYear();
  const m   = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function hhmm(d) {
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

/** Lunes de la semana actual a medianoche local */
function getLunes() {
  const hoy = new Date();
  const dow = hoy.getDay();                          // 0=Dom, 1=Lun, …
  const diff = dow === 0 ? -6 : 1 - dow;
  const lunes = new Date(hoy);
  lunes.setDate(hoy.getDate() + diff);
  lunes.setHours(0, 0, 0, 0);
  return lunes;
}

/**
 * Devuelve datos de jornada con pequeñas variaciones aleatorias.
 * i=0 → lunes   i=4 → viernes
 */
function generarJornada(diaBase, esHoy) {
  // Entrada: 8:45 – 9:10 (variación de 25 min)
  const minEntrada = 45 + Math.floor(Math.random() * 26);
  const entrada = new Date(diaBase);
  entrada.setHours(8, minEntrada, 0, 0);

  // Inicio pausa comida: 13:30 – 14:00
  const minInicioPausa = 30 + Math.floor(Math.random() * 31);
  const inicioPausa = new Date(diaBase);
  inicioPausa.setHours(13, minInicioPausa, 0, 0);

  // Fin pausa: 30 – 45 min después
  const durPausa = 30 + Math.floor(Math.random() * 16);
  const finPausa = new Date(inicioPausa.getTime() + durPausa * 60_000);

  // Salida: 17:20 – 17:50
  const minSalida = 20 + Math.floor(Math.random() * 31);
  const salida = new Date(diaBase);
  salida.setHours(17, minSalida, 0, 0);

  return {
    entrada,
    salida: esHoy ? null : salida,      // hoy: jornada abierta (sin salida)
    pausas: esHoy
      ? []                               // hoy: sin pausa todavía
      : [{ inicio: inicioPausa, fin: finPausa }],
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  // 1. Leer empresa_id real del empleado desde Firestore
  console.log(`\n🔍 Leyendo datos de ${EMPLEADO_ID}…`);
  const userDoc = await db.collection('usuarios').doc(EMPLEADO_ID).get();
  if (!userDoc.exists) {
    console.error('❌ Usuario no encontrado en /usuarios');
    process.exit(1);
  }
  const EMPRESA_ID = userDoc.data().empresa_id;
  console.log(`   empresa_id: ${EMPRESA_ID}`);
  console.log(`   nombre:     ${userDoc.data().nombre}`);

  const colRef = db.collection('empresas').doc(EMPRESA_ID).collection('fichajes');

  // 2. Calcular días de la semana (lunes → hoy, solo laborables)
  const lunesActual   = getLunes();
  const lunesPasado   = new Date(lunesActual);
  lunesPasado.setDate(lunesActual.getDate() - 7);

  const hoy = new Date();
  hoy.setHours(23, 59, 59, 0);

  const DIAS_SEMANA = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  console.log(`\n📅 Insertando semana pasada + semana actual\n`);

  if (DRY_RUN) {
    console.log('ℹ️  Modo --dry-run. Fichajes que se crearían:\n');
  }

  let creados = 0;
  let saltados = 0;

  // 14 días: semana pasada + semana actual
  for (let i = 0; i < 14; i++) {
    const dia = new Date(lunesPasado);
    dia.setDate(lunesPasado.getDate() + i);
    dia.setHours(0, 0, 0, 0);

    const fecha = formatDate(dia);
    const dow   = dia.getDay();

    // Saltar fines de semana y días futuros
    if (dow === 0 || dow === 6) continue;
    if (dia > hoy) { console.log(`  ⏭️  ${DIAS_SEMANA[dow]} ${fecha} — futuro, se omite`); continue; }

    const esHoy = formatDate(dia) === formatDate(new Date());

    // Verificar si ya existe fichaje para este día
    const existing = await colRef
      .where('empleado_id', '==', EMPLEADO_ID)
      .where('fecha',       '==', fecha)
      .where('es_correccion', '==', false)
      .limit(1)
      .get();

    if (!existing.empty) {
      console.log(`  ⚠️  ${DIAS_SEMANA[dow]} ${fecha} — ya existe, se omite`);
      saltados++;
      continue;
    }

    const { entrada, salida, pausas } = generarJornada(dia, esHoy);
    const entradaMs = entrada.getTime();
    const firma = firmaIntegridad(EMPLEADO_ID, fecha, entradaMs, 'script_semana');

    const docData = {
      empleado_id:       EMPLEADO_ID,
      empleado_nombre:   EMPLEADO_NOMBRE,
      fecha,
      entrada:           admin.firestore.Timestamp.fromDate(entrada),
      salida:            salida ? admin.firestore.Timestamp.fromDate(salida) : null,
      pausas:            pausas.map(p => ({
        inicio: admin.firestore.Timestamp.fromDate(p.inicio),
        fin:    admin.firestore.Timestamp.fromDate(p.fin),
      })),
      tipo_horas:        'ordinarias',
      dispositivo_id:    'script_semana',
      creado_at:         admin.firestore.Timestamp.fromDate(entrada),
      firma_integridad:  firma,
      es_correccion:     false,
      correccion_de:     null,
      motivo_correccion: null,
      corregido_por_uid: null,
      corregido_at:      null,
    };

    const resumen = salida
      ? `${hhmm(entrada)} → ${hhmm(salida)}${pausas.length ? `  (pausa ${hhmm(pausas[0].inicio)}-${hhmm(pausas[0].fin)})` : ''}`
      : `${hhmm(entrada)} → (abierta)`;

    if (DRY_RUN) {
      console.log(`  📋 ${DIAS_SEMANA[dow]} ${fecha}: ${resumen}`);
    } else {
      await colRef.add(docData);
      console.log(`  ✅ ${DIAS_SEMANA[dow]} ${fecha}: ${resumen}`);
      creados++;
    }
  }

  if (DRY_RUN) {
    console.log('\nEjecuta sin --dry-run para insertar los datos.\n');
  } else {
    console.log(`\n✅ Completado: ${creados} fichajes creados, ${saltados} omitidos.\n`);
  }

  process.exit(0);
}

main().catch(e => {
  console.error('❌ Error inesperado:', e.message);
  process.exit(1);
});
