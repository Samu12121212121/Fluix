/**
 * init_config_reservas_juanita.js
 * Inicializa la configuración de reservas de Juanita Taberna en Firestore
 * para que la web pueda leerla en tiempo real desde fluix-reservas-core.js
 *
 * Uso:
 *   node functions/scripts/init_config_reservas_juanita.js            ← dry run
 *   node functions/scripts/init_config_reservas_juanita.js --guardar  ← escribe de verdad
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EMPRESA_ID = 'AP6JV9bxONgibrjaKzvrrk4xvWM2'; // juanitataberna@gmail.com
const GUARDAR    = process.argv.includes('--guardar');

// ── Horario de reservas ────────────────────────────────────────────────────────
// Mar-Sáb: mediodía 13:00-15:30 y noche 20:00-22:30
// Lunes: mediodía 13:00-15:30 (solo almuerzo)
// Domingo: mediodía 13:00-15:30 (solo almuerzo)
// Martes: cerrado
const SLOTS_MEDIODIA = ['13:00','13:30','14:00','14:30','15:00','15:30'];
const SLOTS_NOCHE    = ['20:00','20:30','21:00','21:30','22:00','22:30'];
const SLOTS_COMPLETO = [...SLOTS_MEDIODIA, ...SLOTS_NOCHE];

const horariosReservaPorDia = {
  '1': SLOTS_MEDIODIA,          // Lunes — solo almuerzo
  // '2': []                    // Martes — cerrado (no se incluye)
  '3': SLOTS_COMPLETO,          // Miércoles
  '4': SLOTS_COMPLETO,          // Jueves
  '5': SLOTS_COMPLETO,          // Viernes
  '6': SLOTS_COMPLETO,          // Sábado
  '7': SLOTS_MEDIODIA,          // Domingo — solo almuerzo
};

// ── Config principal (empresas/{EID}/configuracion/reservas) ──────────────────
const configReservas = {
  activo:                    true,
  aforo_maximo_por_franja:   8,
  dias_activos:              [1, 3, 4, 5, 6, 7],  // todos menos martes (2)
  dias_recurrentes_cerrados: [2],                   // martes siempre cerrado
  dias_cerrados:             [],
  motivos_cierre:            {},
  intervalos_cerrados:       [],
  duracion_slot_minutos:     30,
  horario: {
    '1': { apertura: '13:00', cierre: '15:30' },
    '3': { apertura: '13:00', cierre: '22:30' },
    '4': { apertura: '13:00', cierre: '22:30' },
    '5': { apertura: '13:00', cierre: '22:30' },
    '6': { apertura: '13:00', cierre: '22:30' },
    '7': { apertura: '13:00', cierre: '15:30' },
  },
  horarios_reserva: horariosReservaPorDia,
};

// ── Config web (empresas/{EID}/configuracion/reservas_web) ────────────────────
// Mismo formato que usa fluix-reservas-core.js y el reservas.html
const configReservasWeb = {
  activo:                    true,
  motivo_cierre:             '',
  aforo_maximo_por_franja:   8,
  dias_activos:              [1, 3, 4, 5, 6, 7],
  fechas_bloqueadas:         [],
  motivos_cierre:            {},
  dias_recurrentes_cerrados: [2],
  intervalos_cerrados:       [],
  duracion_slot_minutos:     30,
  horario_por_dia: {
    '1': { apertura: '13:00', cierre: '15:30' },
    '3': { apertura: '13:00', cierre: '22:30' },
    '4': { apertura: '13:00', cierre: '22:30' },
    '5': { apertura: '13:00', cierre: '22:30' },
    '6': { apertura: '13:00', cierre: '22:30' },
    '7': { apertura: '13:00', cierre: '15:30' },
  },
  horarios_reserva_por_dia: horariosReservaPorDia,
  actualizado: admin.firestore.FieldValue.serverTimestamp(),
};

async function main() {
  console.log('\n🍺 Juanita Taberna — Inicialización config reservas');
  console.log(`   Empresa: ${EMPRESA_ID}`);
  console.log(`   activo: false (cerrado temporalmente)`);
  console.log(`   Días activos: Lun, Mié–Dom (martes cerrado)`);
  if (!GUARDAR) {
    console.log('\n⚠️  DRY RUN — usa --guardar para escribir en Firestore\n');
    console.log('   Docs a crear/actualizar:');
    console.log(`   • empresas/${EMPRESA_ID}/configuracion/reservas`);
    console.log(`   • empresas/${EMPRESA_ID}/configuracion/reservas_web`);
    return;
  }

  const refReservas    = db.collection('empresas').doc(EMPRESA_ID)
                           .collection('configuracion').doc('reservas');
  const refReservasWeb = db.collection('empresas').doc(EMPRESA_ID)
                           .collection('configuracion').doc('reservas_web');

  await refReservas.set(configReservas, { merge: false });
  console.log('   ✅ configuracion/reservas creado');

  await refReservasWeb.set(configReservasWeb, { merge: false });
  console.log('   ✅ configuracion/reservas_web creado');

  console.log('\n✅ Listo. La web leerá activo:false en tiempo real desde Firestore.');
  console.log('   Para abrir reservas: vuelve a ejecutar con activo:true o usa la app Fluix.');
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
