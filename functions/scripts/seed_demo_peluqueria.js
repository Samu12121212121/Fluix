/**
 * SEED DEMO PELUQUERÍA — Fluix CRM
 *
 * Prepara la cuenta demo para ventas a peluquerías:
 *   • Configura tipo_tpv = peluqueria_estetica en la empresa
 *   • Crea 3 profesionales con horarios
 *   • Crea 10 servicios de peluquería
 *   • Crea citas de hoy en la agenda (colección reservas)
 *   • Abre la caja del día (apertura_caja)
 *   • Crea ficha pública en negocios_publicos (aparece en Explorar)
 *
 * Uso:
 *   cd functions
 *   node scripts/seed_demo_peluqueria.js
 *
 * Requiere serviceAccountKey.json en functions/
 */

const admin = require('firebase-admin');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4',
});

const db = admin.firestore();

// ── CONSTANTES ──────────────────────────────────────────────────────────────
const EMPRESA_ID    = 'demo_empresa_fluix2026';
const ADMIN_UID     = 'RjnhpAXBUWQhxlDgOm9PT0EcTIr2';
const NEGOCIO_PUB_ID = 'demo_peluqueria_fluix2026'; // doc en negocios_publicos

// Fecha de hoy como string "yyyy-MM-dd"
const hoy = new Date();
const HOY_STR = `${hoy.getFullYear()}-${String(hoy.getMonth()+1).padStart(2,'0')}-${String(hoy.getDate()).padStart(2,'0')}`;

// ── PROFESIONALES ────────────────────────────────────────────────────────────
// Nota: Los IDs se usan también en prof_id de las reservas
const PROF_IDS = {
  sara:   'demo_prof_sara_001',
  lucia:  'demo_prof_lucia_002',
  miguel: 'demo_prof_miguel_003',
};

const PROFESIONALES = [
  {
    id:          PROF_IDS.sara,
    nombre:      'Sara Moreno',
    puesto:      'Estilista Senior',
    hora_entrada: '09:00',
    hora_salida:  '19:00',
    color_index:  0,
    activo:       true,
  },
  {
    id:          PROF_IDS.lucia,
    nombre:      'Lucía Fernández',
    puesto:      'Colorista',
    hora_entrada: '10:00',
    hora_salida:  '20:00',
    color_index:  1,
    activo:       true,
  },
  {
    id:          PROF_IDS.miguel,
    nombre:      'Miguel Torres',
    puesto:      'Peluquero',
    hora_entrada: '09:00',
    hora_salida:  '18:00',
    color_index:  2,
    activo:       true,
  },
];

// ── SERVICIOS ────────────────────────────────────────────────────────────────
const SERVICIOS = [
  { nombre: 'Corte de cabello',         precio: 18,  duracion: 30,  categoria: 'Corte',    publico: 'todos' },
  { nombre: 'Corte + lavado',           precio: 25,  duracion: 45,  categoria: 'Corte',    publico: 'todos' },
  { nombre: 'Tinte completo',           precio: 55,  duracion: 90,  categoria: 'Color',    publico: 'femenino' },
  { nombre: 'Mechas / balayage',        precio: 80,  duracion: 120, categoria: 'Color',    publico: 'femenino' },
  { nombre: 'Retoque de raíz',          precio: 35,  duracion: 60,  categoria: 'Color',    publico: 'femenino' },
  { nombre: 'Peinado especial',         precio: 40,  duracion: 60,  categoria: 'Peinado',  publico: 'todos' },
  { nombre: 'Tratamiento keratina',     precio: 95,  duracion: 150, categoria: 'Tratamiento', publico: 'todos' },
  { nombre: 'Manicura',                 precio: 22,  duracion: 45,  categoria: 'Estética', publico: 'femenino' },
  { nombre: 'Corte caballero',          precio: 15,  duracion: 25,  categoria: 'Corte',    publico: 'masculino' },
  { nombre: 'Barba + corte caballero',  precio: 22,  duracion: 40,  categoria: 'Corte',    publico: 'masculino' },
];

// ── CITAS DE HOY ─────────────────────────────────────────────────────────────
// Se crean en empresas/{id}/reservas con fecha = HOY_STR y prof_id
const CITAS_HOY = [
  // Sara
  { prof_id: PROF_IDS.sara,  hora: '09:30', duracion: 30,  cliente: 'Carmen López',   telefono: '612 345 678', servicio: 'Corte de cabello',  precio: 18  },
  { prof_id: PROF_IDS.sara,  hora: '10:30', duracion: 90,  cliente: 'Marta Sánchez',  telefono: '623 456 789', servicio: 'Tinte completo',    precio: 55  },
  { prof_id: PROF_IDS.sara,  hora: '12:30', duracion: 45,  cliente: 'Ana Ruiz',       telefono: '634 567 890', servicio: 'Corte + lavado',    precio: 25  },
  { prof_id: PROF_IDS.sara,  hora: '16:00', duracion: 120, cliente: 'Elena Martín',   telefono: '645 678 901', servicio: 'Mechas / balayage', precio: 80  },
  // Lucía
  { prof_id: PROF_IDS.lucia, hora: '10:00', duracion: 60,  cliente: 'Isabel García',  telefono: '656 789 012', servicio: 'Retoque de raíz',   precio: 35  },
  { prof_id: PROF_IDS.lucia, hora: '11:30', duracion: 90,  cliente: 'Sofía Pérez',    telefono: '667 890 123', servicio: 'Tinte completo',    precio: 55  },
  { prof_id: PROF_IDS.lucia, hora: '15:00', duracion: 150, cliente: 'Paula Díaz',     telefono: '678 901 234', servicio: 'Tratamiento keratina', precio: 95 },
  // Miguel
  { prof_id: PROF_IDS.miguel, hora: '09:00', duracion: 40, cliente: 'Jorge Romero',   telefono: '689 012 345', servicio: 'Barba + corte caballero', precio: 22 },
  { prof_id: PROF_IDS.miguel, hora: '10:00', duracion: 25, cliente: 'David Herrero',  telefono: '690 123 456', servicio: 'Corte caballero',   precio: 15  },
  { prof_id: PROF_IDS.miguel, hora: '11:00', duracion: 30, cliente: 'Álvaro Jiménez', telefono: '601 234 567', servicio: 'Corte de cabello',  precio: 18  },
  { prof_id: PROF_IDS.miguel, hora: '12:00', duracion: 40, cliente: 'Raúl Morales',   telefono: '612 345 679', servicio: 'Barba + corte caballero', precio: 22 },
  { prof_id: PROF_IDS.miguel, hora: '16:30', duracion: 30, cliente: 'Luis González',  telefono: '623 456 790', servicio: 'Corte caballero',   precio: 15  },
];

// ── CLIENTES ─────────────────────────────────────────────────────────────────
const CLIENTES = [
  { nombre: 'Carmen López',   telefono: '612 345 678', email: 'carmen@email.com',   num_visitas: 8,  total_gastado: 180 },
  { nombre: 'Marta Sánchez',  telefono: '623 456 789', email: 'marta@email.com',    num_visitas: 12, total_gastado: 420 },
  { nombre: 'Ana Ruiz',       telefono: '634 567 890', email: 'ana.ruiz@email.com', num_visitas: 5,  total_gastado: 135 },
  { nombre: 'Elena Martín',   telefono: '645 678 901', email: '',                   num_visitas: 3,  total_gastado: 240 },
  { nombre: 'Isabel García',  telefono: '656 789 012', email: 'isabel@email.com',   num_visitas: 15, total_gastado: 510 },
  { nombre: 'Jorge Romero',   telefono: '689 012 345', email: '',                   num_visitas: 6,  total_gastado: 130 },
];

// ── HORARIO DE LA PELUQUERÍA (para negocios_publicos y para el badge Abierto/Cerrado) ──
const HORARIO_NEGOCIO = {
  Lunes:     { apertura: '09:00', cierre: '14:00', apertura_tarde: '16:00', cierre_tarde: '20:00', cerrado: false },
  Martes:    { apertura: '09:00', cierre: '14:00', apertura_tarde: '16:00', cierre_tarde: '20:00', cerrado: false },
  Miércoles: { apertura: '09:00', cierre: '14:00', apertura_tarde: '16:00', cierre_tarde: '20:00', cerrado: false },
  Jueves:    { apertura: '09:00', cierre: '14:00', apertura_tarde: '16:00', cierre_tarde: '20:00', cerrado: false },
  Viernes:   { apertura: '09:00', cierre: '14:00', apertura_tarde: '16:00', cierre_tarde: '20:00', cerrado: false },
  Sábado:    { apertura: '09:00', cierre: '15:00', cerrado: false },
  Domingo:   { cerrado: true },
};

// ════════════════════════════════════════════════════════════════════════════
// FUNCIONES
// ════════════════════════════════════════════════════════════════════════════

async function configurarEmpresa() {
  console.log('🏢 Configurando empresa demo como peluquería...');
  await db.collection('empresas').doc(EMPRESA_ID).set({
    nombre:     'Fluix Peluquería Demo',
    tipo_tpv:   'peluqueria_estetica',
    activo:     true,
    nif:        'B12345678',
    ciudad:     'Madrid',
    telefono:   '91 123 45 67',
    propietario_uid: ADMIN_UID,
    modulos_activos: ['tpv', 'clientes', 'reservas', 'web', 'empleados'],
  }, { merge: true });
  console.log('✅ Empresa configurada con tipo_tpv = peluqueria_estetica');
}

async function limpiarDemoAnterior() {
  console.log('🧹 Limpiando datos demo anteriores...');
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  // Limpiar colecciones en paralelo
  await Promise.all([
    _borrarColeccion(empresaRef.collection('empleados').where('es_demo', '==', true)),
    _borrarColeccion(empresaRef.collection('servicios').where('es_demo', '==', true)),
    _borrarColeccion(empresaRef.collection('clientes').where('es_demo', '==', true)),
    _borrarColeccion(empresaRef.collection('reservas').where('fecha', '==', HOY_STR)),
    _borrarColeccion(empresaRef.collection('aperturas_caja')
      .where('fecha', '>=', admin.firestore.Timestamp.fromDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 0,0,0)))
      .where('fecha', '<',  admin.firestore.Timestamp.fromDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate()+1, 0,0,0)))
    ),
  ]);

  // Limpiar ficha pública
  await db.collection('negocios_publicos').doc(NEGOCIO_PUB_ID).delete().catch(() => {});
  console.log('✅ Limpieza completada');
}

async function _borrarColeccion(query) {
  const snap = await query.get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
}

async function crearProfesionales() {
  console.log('💇 Creando profesionales...');
  const batch = db.batch();
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  for (const p of PROFESIONALES) {
    const ref = empresaRef.collection('empleados').doc(p.id);
    batch.set(ref, {
      uid:          p.id,
      nombre:       p.nombre,
      puesto:       p.puesto,
      especialidad: p.puesto,
      hora_entrada: p.hora_entrada,
      hora_salida:  p.hora_salida,
      color_index:  p.color_index,
      activo:       true,
      es_demo:      true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${PROFESIONALES.length} profesionales creados`);
}

async function crearServicios() {
  console.log('✂️  Creando servicios...');
  const batch = db.batch();
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);
  const serviciosRefs = [];

  for (const s of SERVICIOS) {
    const ref = empresaRef.collection('servicios').doc();
    serviciosRefs.push({ ref, ...s });
    batch.set(ref, {
      nombre:    s.nombre,
      precio:    s.precio,
      duracion:  s.duracion,
      categoria: s.categoria,
      publico:   s.publico,
      activo:    true,
      es_demo:   true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${SERVICIOS.length} servicios creados`);
  return serviciosRefs;
}

async function crearClientes() {
  console.log('👤 Creando clientes...');
  const batch = db.batch();
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  for (const c of CLIENTES) {
    const ref = empresaRef.collection('clientes').doc();
    batch.set(ref, {
      nombre:        c.nombre,
      telefono:      c.telefono,
      email:         c.email,
      num_visitas:   c.num_visitas,
      total_gastado: c.total_gastado,
      activo:        true,
      es_demo:       true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${CLIENTES.length} clientes creados`);
}

async function crearCitasHoy() {
  console.log(`📅 Creando ${CITAS_HOY.length} citas para hoy (${HOY_STR})...`);
  const batch = db.batch();
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  for (const c of CITAS_HOY) {
    const ref = empresaRef.collection('reservas').doc();
    batch.set(ref, {
      fecha:             HOY_STR,
      prof_id:           c.prof_id,
      cliente_nombre:    c.cliente,
      cliente_telefono:  c.telefono,
      servicio_nombre:   c.servicio,
      hora_inicio:       c.hora,
      duracion_minutos:  c.duracion,
      estado:            'pendiente',
      importe:           c.precio,
      servicios: [{
        nombre: c.servicio,
        precio: c.precio,
        duracion: c.duracion,
      }],
      origen: 'demo',
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${CITAS_HOY.length} citas creadas en la agenda de hoy`);
}

async function abrirCajaHoy() {
  console.log('💰 Abriendo caja del día...');
  const ref = db.collection('empresas').doc(EMPRESA_ID).collection('aperturas_caja').doc();
  await ref.set({
    fecha:         admin.firestore.Timestamp.fromDate(new Date()),
    fondo_inicial: 200,
    usuario_uid:   ADMIN_UID,
    notas:         'Apertura demo',
    es_demo:       true,
  });
  console.log('✅ Caja abierta con fondo inicial de 200 €');
}

async function crearFichaPublica() {
  console.log('🌐 Creando ficha en negocios_publicos (Explorar)...');
  await db.collection('negocios_publicos').doc(NEGOCIO_PUB_ID).set({
    nombre:              'Fluix Peluquería Demo',
    categoria:           'peluquerias',
    activo:              true,
    empresaIdVinculada:  EMPRESA_ID,
    descripcion:         'Peluquería y estética en el corazón de Madrid. Especialistas en corte, color y tratamientos capilares.',
    tagline:             'Tu cabello, nuestro arte',
    direccion:           'Calle Gran Vía 45, Madrid',
    telefono:            '91 123 45 67',
    ratingGoogle:        4.7,
    ratingFluix:         4.8,
    numResenas:          87,
    // Foto pública: una imagen de peluquería de dominio público (Unsplash CDN)
    fotoUrl:             'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&q=80',
    fotosGaleria: [
      'https://images.unsplash.com/photo-1595476108010-b4d1f102b1b1?w=600&q=80',
      'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&q=80',
      'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=600&q=80',
    ],
    horario:             HORARIO_NEGOCIO,
    reservasOnline:      true,
    aceptaTarjeta:       true,
    tieneWifi:           true,
    nivelPrecio:         '€€',
    precioMedio:         '€€',
    latitud:             40.4168,
    longitud:            -3.7038,
    serviciosDestacados: ['Corte de cabello', 'Tinte completo', 'Mechas / balayage', 'Tratamiento keratina'],
    especialidades:      ['Color', 'Corte', 'Keratina', 'Extensiones'],
    destacado:           true,
    formularioTitulo:    'Reserva tu cita',
    formularioBoton:     'Confirmar cita',
    duracionPromedio:    60,
  });
  console.log('✅ Ficha pública creada — aparecerá en Explorar > Peluquerías');
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log('\n🚀 SEED DEMO PELUQUERÍA\n');
  console.log(`📦 Empresa: ${EMPRESA_ID}`);
  console.log(`📅 Fecha:   ${HOY_STR}\n`);

  try {
    await limpiarDemoAnterior();
    await configurarEmpresa();
    await crearProfesionales();
    await crearServicios();
    await crearClientes();
    await crearCitasHoy();
    await abrirCajaHoy();
    await crearFichaPublica();

    console.log('\n✅ ¡Cuenta demo lista para peluquerías!\n');
    console.log('📊 Resumen:');
    console.log(`   • tipo_tpv = peluqueria_estetica ✓`);
    console.log(`   • ${PROFESIONALES.length} profesionales (Sara, Lucía, Miguel)`);
    console.log(`   • ${SERVICIOS.length} servicios (corte, tinte, mechas, manicura...)`);
    console.log(`   • ${CLIENTES.length} clientes`);
    console.log(`   • ${CITAS_HOY.length} citas en la agenda de hoy`);
    console.log(`   • Caja abierta con 200 € de fondo`);
    console.log(`   • Ficha pública en Explorar > Peluquerías ✓`);
    console.log('\n🎯 Flujo demo recomendado:');
    console.log('   1. Abre TPV → selecciona "Peluquería / Estética"');
    console.log('   2. Enseña la agenda con las citas de hoy');
    console.log('   3. Cobra una cita (caja ya está abierta)');
    console.log('   4. Cambia a la app Explorar → filtra por Peluquerías → entra en "Fluix Peluquería Demo"');
    console.log('   5. Reserva desde la app → vuelve al TPV y aparece en la agenda');
    console.log('   6. (Opcional) Módulo Web → enseña catálogo y reservas online\n');
  } catch (e) {
    console.error('❌ Error:', e);
    process.exit(1);
  }
  process.exit(0);
}

main();
