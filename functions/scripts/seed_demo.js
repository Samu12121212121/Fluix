/**
 * SEED DE DATOS DEMO — Fluix CRM
 *
 * Script para crear datos de prueba realistas en la empresa demo.
 * Ejecutar: node seed_demo.js
 *
 * Requisitos:
 * - npm install firebase-admin
 * - Tener serviceAccountKey.json en la raíz del proyecto functions
 */

const admin = require('firebase-admin');
const path = require('path');

// Inicializar Firebase Admin SDK
// El archivo debe estar en functions/serviceAccountKey.json (un nivel arriba)
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4',
});

const db = admin.firestore();

// ═════════════════════════════════════════════════════════════════════════════
// CONSTANTES
// ═════════════════════════════════════════════════════════════════════════════

const EMPRESA_DEMO_ID = 'demo_empresa_fluix2026';
const ADMIN_DEMO_UID = 'RjnhpAXBUWQhxlDgOm9PT0EcTIr2';

// ═════════════════════════════════════════════════════════════════════════════
// DATOS DEMO
// ═════════════════════════════════════════════════════════════════════════════

const EMPLEADOS_DEMO = [
  {
    uid: 'demo_emp_maria_001',
    nombre: 'María García López',
    email: 'maria.garcia@demo.fluix.com',
    telefono: '+34 612 345 678',
    cargo: 'Encargada de Salón',
    salario_bruto_anual: 24000,
    nif: '12345678A',
    nss: '281234567890',
    cuenta_bancaria: 'ES9121000418450200051332', // IBAN válido
    convenio: 'hosteleria', // Convenio de hostelería
    categoria_convenio: 'grupo5', // Grupo 5 - Encargado
    grupo_cotizacion: 'grupo5',
    horas_semanales: 40,
    fecha_alta: new Date('2024-01-15'),
  },
  {
    uid: 'demo_emp_carlos_002',
    nombre: 'Carlos López Martínez',
    email: 'carlos.lopez@demo.fluix.com',
    telefono: '+34 623 456 789',
    cargo: 'Camarero',
    salario_bruto_anual: 18000,
    nif: '23456789B',
    nss: '282345678901',
    cuenta_bancaria: 'ES7921000813610123456789', // IBAN válido
    convenio: 'hosteleria', // Convenio de hostelería
    categoria_convenio: 'grupo7', // Grupo 7 - Camarero
    grupo_cotizacion: 'grupo7',
    horas_semanales: 40,
    fecha_alta: new Date('2024-03-01'),
  },
  {
    uid: 'demo_emp_ana_003',
    nombre: 'Ana Martínez Ruiz',
    email: 'ana.martinez@demo.fluix.com',
    telefono: '+34 634 567 890',
    cargo: 'Ayudante de Cocina',
    salario_bruto_anual: 16800,
    nif: '34567890C',
    nss: '283456789012',
    cuenta_bancaria: 'ES1720852066623456789011', // IBAN válido
    convenio: 'hosteleria', // Convenio de hostelería
    categoria_convenio: 'grupo8', // Grupo 8 - Ayudante
    grupo_cotizacion: 'grupo8',
    horas_semanales: 40,
    fecha_alta: new Date('2024-06-15'),
  },
];

const CLIENTES_DEMO = [
  {
    nombre: 'Pedro Sánchez',
    telefono: '+34 645 123 456',
    email: 'pedro.sanchez@email.com',
    total_gastado: 250.50,
    numero_reservas: 5,
    fecha_registro: new Date('2025-01-10'),
    notas: 'Cliente habitual, prefiere mesa junto a ventana',
  },
  {
    nombre: 'Laura González',
    telefono: '+34 656 234 567',
    email: 'laura.gonzalez@email.com',
    total_gastado: 180.00,
    numero_reservas: 3,
    fecha_registro: new Date('2025-02-15'),
    notas: 'Alérgica al gluten',
  },
  {
    nombre: 'Roberto Fernández',
    telefono: '+34 667 345 678',
    email: 'roberto.fernandez@email.com',
    total_gastado: 420.75,
    numero_reservas: 8,
    fecha_registro: new Date('2024-11-20'),
    notas: 'Cliente VIP, pide siempre vino de la casa',
  },
];

const SERVICIOS_DEMO = [
  {
    nombre: 'Menú del Día',
    descripcion: 'Primer plato, segundo plato, postre y bebida',
    precio: 12.50,
    duracion_minutos: 60,
    activo: true,
    categoria: 'Restaurante',
  },
  {
    nombre: 'Menú Degustación',
    descripcion: 'Menú especial de 5 platos con maridaje',
    precio: 45.00,
    duracion_minutos: 120,
    activo: true,
    categoria: 'Restaurante',
  },
  {
    nombre: 'Reserva Sala Privada',
    descripcion: 'Sala privada para eventos (hasta 20 personas)',
    precio: 150.00,
    duracion_minutos: 180,
    activo: true,
    categoria: 'Eventos',
  },
];

// ═════════════════════════════════════════════════════════════════════════════
// FUNCIONES AUXILIARES
// ═════════════════════════════════════════════════════════════════════════════

function generarFechaFutura(diasAdelante) {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() + diasAdelante);
  fecha.setHours(13 + Math.floor(Math.random() * 8)); // Entre 13:00 y 21:00
  fecha.setMinutes(Math.random() > 0.5 ? 0 : 30);
  fecha.setSeconds(0);
  return admin.firestore.Timestamp.fromDate(fecha);
}

function calcularNominaMes(empleado, mes, año) {
  const salarioBrutoMensual = empleado.salario_bruto_anual / 14; // 14 pagas
  const irpf = salarioBrutoMensual * 0.15; // 15% IRPF estimado
  const ssEmpleado = salarioBrutoMensual * 0.0635; // 6.35% SS trabajador
  const ssEmpresa = salarioBrutoMensual * 0.30; // 30% SS empresa
  const salarioNeto = salarioBrutoMensual - irpf - ssEmpleado;

  return {
    empleado_id: empleado.uid,
    empleado_nombre: empleado.nombre,
    empleado_nif: empleado.nif,
    mes,
    año,
    salario_bruto: Number(salarioBrutoMensual.toFixed(2)),
    salario_neto: Number(salarioNeto.toFixed(2)),
    irpf: Number(irpf.toFixed(2)),
    ss_empleado: Number(ssEmpleado.toFixed(2)),
    ss_empresa: Number(ssEmpresa.toFixed(2)),
    estado: 'generada',
    fecha_generacion: admin.firestore.FieldValue.serverTimestamp(),
    es_demo: true,
    // Datos específicos del convenio
    convenio: empleado.convenio,
    categoria_convenio_id: empleado.categoria_convenio,
    grupo_cotizacion: empleado.grupo_cotizacion,
    horas_trabajadas: 160, // 40h/semana * 4 semanas
    dias_trabajados: 22,
    complementos: [],
    deducciones: [],
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// FUNCIONES DE SEED
// ═════════════════════════════════════════════════════════════════════════════

async function limpiarDatosDemo() {
  console.log('🧹 Limpiando datos demo anteriores...');

  const batch = db.batch();

  // Limpiar usuarios demo
  const usuariosDemo = await db.collection('usuarios')
    .where('es_demo', '==', true)
    .where('empresa_id', '==', EMPRESA_DEMO_ID)
    .get();

  usuariosDemo.docs.forEach(doc => {
    if (doc.id !== ADMIN_DEMO_UID) { // No borrar el admin
      batch.delete(doc.ref);
    }
  });

  // Limpiar empleados
  const empleadosDemo = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('empleados')
    .where('es_demo', '==', true)
    .get();

  empleadosDemo.docs.forEach(doc => batch.delete(doc.ref));

  // Limpiar clientes
  const clientesDemo = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('clientes')
    .where('es_demo', '==', true)
    .get();

  clientesDemo.docs.forEach(doc => batch.delete(doc.ref));

  // Limpiar nóminas
  const nominasDemo = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('nominas')
    .where('es_demo', '==', true)
    .get();

  nominasDemo.docs.forEach(doc => batch.delete(doc.ref));

  // Limpiar reservas
  const reservasDemo = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('reservas')
    .where('origen', '==', 'demo')
    .get();

  reservasDemo.docs.forEach(doc => batch.delete(doc.ref));

  // Limpiar servicios
  const serviciosDemo = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('servicios')
    .where('es_demo', '==', true)
    .get();

  serviciosDemo.docs.forEach(doc => batch.delete(doc.ref));

  await batch.commit();
  console.log('✅ Datos demo anteriores eliminados');
}

async function crearUsuariosEmpleados() {
  console.log('👥 Creando usuarios empleados...');

  const batch = db.batch();

  for (const emp of EMPLEADOS_DEMO) {
    const usuarioRef = db.collection('usuarios').doc(emp.uid);

    batch.set(usuarioRef, {
      uid: emp.uid,
      nombre: emp.nombre,
      correo: emp.email,
      telefono: emp.telefono,
      empresa_id: EMPRESA_DEMO_ID,
      rol: 'staff',
      activo: true,
      es_demo: true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      token_dispositivo: null,
      fcm_tokens: [],
      plataforma: 'demo',
      permisos: [],
      modulos_personalizados: ['reservas', 'citas', 'clientes', 'valoraciones'],
    });
  }

  await batch.commit();
  console.log(`✅ ${EMPLEADOS_DEMO.length} usuarios creados`);
}

async function crearEmpleados() {
  console.log('💼 Creando empleados en la empresa...');

  const batch = db.batch();

  for (const emp of EMPLEADOS_DEMO) {
    const empleadoRef = db.collection('empresas')
      .doc(EMPRESA_DEMO_ID)
      .collection('empleados')
      .doc(emp.uid);

    batch.set(empleadoRef, {
      uid: emp.uid,
      nombre: emp.nombre,
      email: emp.email,
      telefono: emp.telefono,
      cargo: emp.cargo,
      activo: true,
      es_demo: true,
      fecha_alta: admin.firestore.Timestamp.fromDate(emp.fecha_alta),
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      // Datos fiscales
      nif: emp.nif,
      nss: emp.nss,
      salario_bruto_anual: emp.salario_bruto_anual,
      // Convenio
      convenio: emp.convenio,
      categoria_convenio_id: emp.categoria_convenio,
      grupo_cotizacion: emp.grupo_cotizacion,
      horas_semanales: emp.horas_semanales,
      // Nómina
      datos_nomina: {
        salario_bruto_anual: emp.salario_bruto_anual,
        grupo_cotizacion: emp.grupo_cotizacion,
        irpf_porcentaje: 15,
        num_pagas: 14,
        horas_semanales: emp.horas_semanales,
        categoria_convenio_id: emp.categoria_convenio,
        sector_empresa: emp.convenio,
        pagas_prorrateadas: true,
        cuenta_bancaria: emp.cuenta_bancaria, // IBAN para transferencias SEPA
      },
    });
  }

  await batch.commit();
  console.log(`✅ ${EMPLEADOS_DEMO.length} empleados creados`);
}

async function crearNominas() {
  console.log('💰 Creando nóminas...');

  const batch = db.batch();
  const meses = [
    { mes: 1, año: 2026, nombre: 'Enero' },
    { mes: 2, año: 2026, nombre: 'Febrero' },
    { mes: 3, año: 2026, nombre: 'Marzo' },
    { mes: 4, año: 2026, nombre: 'Abril' },
    { mes: 5, año: 2026, nombre: 'Mayo' },
  ];

  let count = 0;

  for (const empleado of EMPLEADOS_DEMO) {
    for (const periodo of meses) {
      const nominaData = calcularNominaMes(empleado, periodo.mes, periodo.año);

      const nominaRef = db.collection('empresas')
        .doc(EMPRESA_DEMO_ID)
        .collection('nominas')
        .doc();

      batch.set(nominaRef, {
        ...nominaData,
        id: nominaRef.id,
        periodo_nombre: `${periodo.nombre} ${periodo.año}`,
      });

      count++;
    }
  }

  await batch.commit();
  console.log(`✅ ${count} nóminas creadas (${EMPLEADOS_DEMO.length} empleados × 5 meses)`);
}

async function crearClientes() {
  console.log('👤 Creando clientes...');

  const batch = db.batch();

  for (const cliente of CLIENTES_DEMO) {
    const clienteRef = db.collection('empresas')
      .doc(EMPRESA_DEMO_ID)
      .collection('clientes')
      .doc();

    batch.set(clienteRef, {
      ...cliente,
      id: clienteRef.id,
      activo: true,
      es_demo: true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      ultima_visita: admin.firestore.Timestamp.fromDate(cliente.fecha_registro),
    });
  }

  await batch.commit();
  console.log(`✅ ${CLIENTES_DEMO.length} clientes creados`);
}

async function crearServicios() {
  console.log('🍽️ Creando servicios...');

  const batch = db.batch();

  for (const servicio of SERVICIOS_DEMO) {
    const servicioRef = db.collection('empresas')
      .doc(EMPRESA_DEMO_ID)
      .collection('servicios')
      .doc();

    batch.set(servicioRef, {
      ...servicio,
      id: servicioRef.id,
      es_demo: true,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${SERVICIOS_DEMO.length} servicios creados`);
}

async function crearReservas() {
  console.log('📅 Creando reservas...');

  const batch = db.batch();

  // Obtener servicios creados
  const serviciosSnap = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('servicios')
    .where('es_demo', '==', true)
    .get();

  const servicios = serviciosSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  // Obtener clientes creados
  const clientesSnap = await db.collection('empresas')
    .doc(EMPRESA_DEMO_ID)
    .collection('clientes')
    .where('es_demo', '==', true)
    .get();

  const clientes = clientesSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  const reservas = [
    {
      cliente: clientes[0],
      servicio: servicios[0],
      dias: 2,
      estado: 'PENDIENTE',
    },
    {
      cliente: clientes[1],
      servicio: servicios[1],
      dias: 5,
      estado: 'CONFIRMADA',
    },
    {
      cliente: clientes[2],
      servicio: servicios[0],
      dias: 7,
      estado: 'PENDIENTE',
    },
    {
      cliente: clientes[0],
      servicio: servicios[2],
      dias: 10,
      estado: 'PENDIENTE',
    },
    {
      cliente: clientes[1],
      servicio: servicios[1],
      dias: 15,
      estado: 'CONFIRMADA',
    },
  ];

  for (const reserva of reservas) {
    const fechaHora = generarFechaFutura(reserva.dias);

    const reservaRef = db.collection('empresas')
      .doc(EMPRESA_DEMO_ID)
      .collection('reservas')
      .doc();

    batch.set(reservaRef, {
      id: reservaRef.id,
      nombre_cliente: reserva.cliente.nombre,
      telefono_cliente: reserva.cliente.telefono,
      email_cliente: reserva.cliente.email || '',
      cliente_id: reserva.cliente.id,
      servicio: reserva.servicio.nombre,
      servicio_id: reserva.servicio.id,
      precio: reserva.servicio.precio,
      fecha: fechaHora,
      fecha_hora: fechaHora,
      estado: reserva.estado,
      origen: 'demo',
      notas: 'Reserva de prueba generada automáticamente',
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${reservas.length} reservas creadas`);
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN
// ═════════════════════════════════════════════════════════════════════════════

async function main() {
  console.log('🚀 Iniciando seed de datos demo...\n');
  console.log(`📦 Empresa: ${EMPRESA_DEMO_ID}`);
  console.log(`👤 Admin: ${ADMIN_DEMO_UID}\n`);

  try {
    await limpiarDatosDemo();
    await crearUsuariosEmpleados();
    await crearEmpleados();
    await crearNominas();
    await crearClientes();
    await crearServicios();
    await crearReservas();

    console.log('\n✅ Seed completado exitosamente!');
    console.log('\n📊 Resumen:');
    console.log(`   • ${EMPLEADOS_DEMO.length} empleados`);
    console.log(`   • ${EMPLEADOS_DEMO.length * 5} nóminas (5 meses)`);
    console.log(`   • ${CLIENTES_DEMO.length} clientes`);
    console.log(`   • ${SERVICIOS_DEMO.length} servicios`);
    console.log(`   • 5 reservas`);
    console.log('\n🎯 Ahora puedes probar todos los módulos en la app!');
  } catch (error) {
    console.error('❌ Error en el seed:', error);
    process.exit(1);
  }

  process.exit(0);
}

main();




