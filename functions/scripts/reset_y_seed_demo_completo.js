'use strict';
/**
 * reset_y_seed_demo_completo.js
 *
 * 1. Borra TODOS los datos de la empresa demo (sin filtro es_demo)
 * 2. Regenera datos realistas para captura de pantallas App Store:
 *    clientes · empleados · nóminas · fichajes · vacaciones ·
 *    reservas · servicios · profesionales · facturas · pedidos ·
 *    tareas · TPV (catálogo + ventas) · caja
 *
 * Uso:
 *   cd functions
 *   node scripts/reset_y_seed_demo_completo.js            ← dry-run
 *   node scripts/reset_y_seed_demo_completo.js --ejecutar ← aplica
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId: 'planeaapp-4bea4' });
const db   = admin.firestore();
const TS   = admin.firestore.Timestamp;
const SV   = admin.firestore.FieldValue.serverTimestamp();
const EJECUTAR = process.argv.includes('--ejecutar');

const EMPRESA_ID = 'demo_empresa_fluix2026';
const ADMIN_UID  = 'RjnhpAXBUWQhxlDgOm9PT0EcTIr2';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function dias(n) { const d = new Date(); d.setDate(d.getDate() + n); return d; }
function ts(d)   { return TS.fromDate(d instanceof Date ? d : new Date(d)); }
function rand(a, b) { return Math.floor(Math.random() * (b - a + 1)) + a; }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function hoy() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

async function borrarColeccion(colRef) {
  const snap = await colRef.limit(400).get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
  // recursivo si hay más
  if (snap.size === 400) return snap.size + await borrarColeccion(colRef);
  return snap.size;
}

// ─────────────────────────────────────────────────────────────────────────────
// DATOS
// ─────────────────────────────────────────────────────────────────────────────

const EMPLEADOS = [
  { id: 'demo_emp_001', nombre: 'María García López',    cargo: 'Encargada',        email: 'maria@fluixdemo.com',   tel: '612345678', salario: 24000, nif: '12345678A', nss: '281234567890', iban: 'ES9121000418450200051332', alta: '2024-01-15', irpf: 15 },
  { id: 'demo_emp_002', nombre: 'Carlos López Martínez', cargo: 'Estilista',         email: 'carlos@fluixdemo.com',  tel: '623456789', salario: 19500, nif: '23456789B', nss: '282345678901', iban: 'ES7921000813610123456789', alta: '2024-03-01', irpf: 13 },
  { id: 'demo_emp_003', nombre: 'Ana Martínez Ruiz',     cargo: 'Colorista',         email: 'ana@fluixdemo.com',     tel: '634567890', salario: 18000, nif: '34567890C', nss: '283456789012', iban: 'ES1720852066623456789011', alta: '2024-06-15', irpf: 12 },
  { id: 'demo_emp_004', nombre: 'Luis Fernández Mora',   cargo: 'Recepcionista',     email: 'luis@fluixdemo.com',    tel: '645678901', salario: 16800, nif: '45678901D', nss: '284567890123', iban: 'ES8023100001180000012345', alta: '2025-01-10', irpf: 10 },
];

const CLIENTES = [
  { nombre: 'Patricia Ruiz Sánchez',    tel: '656789012', email: 'patricia@email.com',    total: 380.50, visitas: 7  },
  { nombre: 'José Antonio Morales',     tel: '667890123', email: 'joseantonio@gmail.com', total: 210.00, visitas: 4  },
  { nombre: 'Elena Torres Vidal',       tel: '678901234', email: 'elena.torres@email.com',total: 540.75, visitas: 11 },
  { nombre: 'Roberto Jiménez Pardo',    tel: '689012345', email: 'roberto.j@empresa.es',  total: 125.00, visitas: 2  },
  { nombre: 'Sofía Navarro Blanco',     tel: '690123456', email: 'sofia.n@outlook.com',   total: 890.25, visitas: 18 },
  { nombre: 'Miguel Ángel Castro',      tel: '601234567', email: 'miguelangel@email.com', total: 320.00, visitas: 6  },
  { nombre: 'Carmen Delgado Fuentes',   tel: '612345679', email: 'carmen.d@email.com',    total: 155.00, visitas: 3  },
  { nombre: 'Francisco Ortega Gil',     tel: '623456780', email: 'fran.ortega@gmail.com', total: 445.50, visitas: 9  },
  { nombre: 'Estética Bella S.L.',      tel: '949123456', email: 'info@esteticabella.es', total: 1240.00,visitas: 15 },
  { nombre: 'Salón Image Guadalajara',  tel: '949234567', email: 'salon@imageguada.es',   total: 780.00, visitas: 12 },
];

const SERVICIOS = [
  { nombre: 'Corte de cabello mujer',    precio: 28,  duracion: 45,  cat: 'Corte',      iva: 21 },
  { nombre: 'Corte de cabello hombre',   precio: 16,  duracion: 30,  cat: 'Corte',      iva: 21 },
  { nombre: 'Tinte completo',            precio: 65,  duracion: 90,  cat: 'Color',      iva: 21 },
  { nombre: 'Mechas / Balayage',         precio: 95,  duracion: 120, cat: 'Color',      iva: 21 },
  { nombre: 'Tratamiento keratina',      precio: 120, duracion: 150, cat: 'Tratamiento',iva: 21 },
  { nombre: 'Peinado de fiesta',         precio: 45,  duracion: 60,  cat: 'Peinado',    iva: 21 },
  { nombre: 'Manicura clásica',          precio: 22,  duracion: 45,  cat: 'Manicura',   iva: 21 },
  { nombre: 'Pedicura completa',         precio: 30,  duracion: 60,  cat: 'Pedicura',   iva: 21 },
  { nombre: 'Depilación cejas',          precio: 10,  duracion: 15,  cat: 'Depilación', iva: 21 },
  { nombre: 'Masaje capilar express',    precio: 18,  duracion: 20,  cat: 'Tratamiento',iva: 21 },
];

const PROF_IDS = { sara: 'demo_prof_001', lucia: 'demo_prof_002', miguel: 'demo_prof_003' };

const PROFESIONALES = [
  { id: PROF_IDS.sara,   nombre: 'Sara Moreno Leal',    puesto: 'Estilista Senior', color_index: 0, entrada: '09:00', salida: '19:00' },
  { id: PROF_IDS.lucia,  nombre: 'Lucía Fernández Gil',  puesto: 'Colorista',        color_index: 1, entrada: '10:00', salida: '20:00' },
  { id: PROF_IDS.miguel, nombre: 'Miguel Torres Ruiz',   puesto: 'Estilista',        color_index: 2, entrada: '09:00', salida: '18:00' },
];

// ─────────────────────────────────────────────────────────────────────────────
// PASO 1 — BORRAR TODO
// ─────────────────────────────────────────────────────────────────────────────

async function borrarTodo() {
  console.log('\n🗑️  Borrando datos de empresa demo...');
  const emp = db.collection('empresas').doc(EMPRESA_ID);

  const colecciones = [
    'clientes', 'empleados', 'nominas', 'reservas', 'servicios',
    'profesionales', 'facturas', 'facturas_recibidas', 'pedidos',
    'tareas', 'comandas', 'apertura_caja', 'cierre_caja',
    'catalogo', 'fichajes', 'vacaciones', 'festivos',
    'configuracion', 'notificaciones', 'albaranes_recibidos',
  ];

  let total = 0;
  for (const col of colecciones) {
    const n = await borrarColeccion(emp.collection(col));
    if (n > 0) console.log(`  ✓ ${col}: ${n} docs`);
    total += n;
  }

  // Borrar usuarios demo (excepto admin)
  const usSnap = await db.collection('usuarios')
    .where('empresa_id', '==', EMPRESA_ID).get();
  const ubatch = db.batch();
  usSnap.docs.filter(d => d.id !== ADMIN_UID).forEach(d => ubatch.delete(d.ref));
  await ubatch.commit();
  console.log(`  ✓ usuarios: ${usSnap.size - 1} docs`);

  console.log(`✅ Total borrado: ${total} documentos\n`);
}

// ─────────────────────────────────────────────────────────────────────────────
// PASO 2 — SEED
// ─────────────────────────────────────────────────────────────────────────────

async function seedEmpleados() {
  console.log('👥 Creando empleados...');
  const batch = db.batch();

  for (const e of EMPLEADOS) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('empleados').doc(e.id);
    batch.set(ref, {
      uid: e.id, nombre: e.nombre, email: e.email, telefono: e.tel,
      cargo: e.cargo, activo: true, es_demo: true,
      fecha_alta: ts(e.alta),
      nif: e.nif, nss: e.nss,
      salario_bruto_anual: e.salario,
      horas_semanales: 40,
      convenio: 'peluqueria_estetica',
      categoria_convenio_id: 'oficial1',
      grupo_cotizacion: 'grupo5',
      datos_nomina: {
        salario_bruto_anual: e.salario,
        irpf_porcentaje: e.irpf,
        num_pagas: 14,
        horas_semanales: 40,
        pagas_prorrateadas: true,
        cuenta_bancaria: e.iban,
        sector_empresa: 'peluqueria_estetica',
        categoria_convenio_id: 'oficial1',
        grupo_cotizacion: 'grupo5',
      },
    });

    // usuario auth
    const uRef = db.collection('usuarios').doc(e.id);
    batch.set(uRef, {
      uid: e.id, nombre: e.nombre, correo: e.email,
      telefono: e.tel, empresa_id: EMPRESA_ID,
      rol: 'staff', activo: true, es_demo: true,
      fecha_creacion: SV, fcm_tokens: [], plataforma: 'demo',
      modulos_personalizados: ['reservas', 'clientes', 'fichajes', 'vacaciones'],
    });
  }

  await batch.commit();
  console.log(`  ✅ ${EMPLEADOS.length} empleados`);
}

async function seedNominas() {
  console.log('💰 Creando nóminas (6 meses)...');
  const meses = [
    [5,2026,'Mayo'],[4,2026,'Abril'],[3,2026,'Marzo'],
    [2,2026,'Febrero'],[1,2026,'Enero'],[12,2025,'Diciembre'],
  ];
  const batch = db.batch();
  let count = 0;
  for (const emp of EMPLEADOS) {
    const brutoMes = emp.salario / 14;
    for (const [mes, año, nombre] of meses) {
      const ref = db.collection('empresas').doc(EMPRESA_ID).collection('nominas').doc();
      batch.set(ref, {
        id: ref.id, empleado_id: emp.id, empleado_nombre: emp.nombre,
        empleado_nif: emp.nif, mes, año,
        periodo_nombre: `${nombre} ${año}`,
        salario_bruto:  +brutoMes.toFixed(2),
        salario_neto:   +(brutoMes * (1 - emp.irpf/100 - 0.0635)).toFixed(2),
        irpf:           +(brutoMes * emp.irpf/100).toFixed(2),
        ss_empleado:    +(brutoMes * 0.0635).toFixed(2),
        ss_empresa:     +(brutoMes * 0.30).toFixed(2),
        horas_trabajadas: 160, dias_trabajados: 22,
        estado: mes < 5 ? 'pagada' : 'generada',
        complementos: [], deducciones: [],
        es_demo: true,
        fecha_generacion: SV,
      });
      count++;
    }
  }
  await batch.commit();
  console.log(`  ✅ ${count} nóminas`);
}

async function seedClientes() {
  console.log('👤 Creando clientes...');
  const batch = db.batch();
  const ids = [];
  for (const c of CLIENTES) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('clientes').doc();
    ids.push(ref.id);
    batch.set(ref, {
      id: ref.id, nombre: c.nombre, telefono: c.tel, email: c.email,
      total_gastado: c.total, numero_visitas: c.visitas,
      activo: true, es_demo: true,
      fecha_registro: ts(dias(-rand(30, 365))),
      ultima_visita:  ts(dias(-rand(1, 30))),
      etiquetas: pick([['VIP'],['habitual'],['nuevo'],[]]),
      notas: '',
    });
  }
  await batch.commit();
  console.log(`  ✅ ${CLIENTES.length} clientes`);
  return ids;
}

async function seedServicios() {
  console.log('✂️  Creando servicios...');
  const batch = db.batch();
  const ids = [];
  for (const s of SERVICIOS) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('servicios').doc();
    ids.push(ref.id);
    batch.set(ref, {
      id: ref.id, nombre: s.nombre, descripcion: '',
      precio: s.precio, duracion_minutos: s.duracion,
      categoria: s.cat, activo: true, es_demo: true,
      iva: s.iva,
      fecha_creacion: SV,
    });
  }
  await batch.commit();
  console.log(`  ✅ ${SERVICIOS.length} servicios`);
  return ids;
}

async function seedProfesionales() {
  console.log('💈 Creando profesionales...');
  const batch = db.batch();
  const dias_semana = ['lunes','martes','miercoles','jueves','viernes'];
  for (const p of PROFESIONALES) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('profesionales').doc(p.id);
    const horario = {};
    dias_semana.forEach(d => { horario[d] = { activo: true, entrada: p.entrada, salida: p.salida }; });
    horario['sabado'] = { activo: true, entrada: '10:00', salida: '15:00' };
    horario['domingo'] = { activo: false };
    batch.set(ref, {
      id: p.id, nombre: p.nombre, puesto: p.puesto,
      color_index: p.color_index, activo: true, es_demo: true,
      horario, foto_url: null,
    });
  }
  await batch.commit();
  console.log(`  ✅ ${PROFESIONALES.length} profesionales`);
}

async function seedReservas(clienteIds, servicioIds) {
  console.log('📅 Creando reservas (pasadas + futuras)...');
  const batch = db.batch();
  const estados = ['CONFIRMADA','CONFIRMADA','CONFIRMADA','PENDIENTE','COMPLETADA','COMPLETADA'];
  let count = 0;

  // 20 reservas: 14 pasadas completadas + 6 futuras
  const offsets = [-45,-38,-30,-25,-20,-17,-14,-12,-10,-7,-5,-3,-2,-1, 1,2,3,5,7,10];
  for (let i = 0; i < offsets.length; i++) {
    const d = dias(offsets[i]);
    d.setHours(9 + (i % 6) * 2, i % 2 === 0 ? 0 : 30);
    const cli = CLIENTES[i % CLIENTES.length];
    const svc = SERVICIOS[i % SERVICIOS.length];
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('reservas').doc();
    const isPast = offsets[i] < 0;
    batch.set(ref, {
      id: ref.id,
      cliente_nombre: cli.nombre, cliente_telefono: cli.tel, cliente_email: cli.email,
      cliente_id: clienteIds[i % clienteIds.length],
      servicio_id:   servicioIds[i % servicioIds.length],
      servicio_nombre: svc.nombre, servicio_precio: svc.precio,
      prof_id: Object.values(PROF_IDS)[i % 3],
      prof_nombre: PROFESIONALES[i % 3].nombre,
      fecha: ts(d), duracion_minutos: svc.duracion,
      estado: isPast ? 'COMPLETADA' : pick(['CONFIRMADA','CONFIRMADA','PENDIENTE']),
      origen: 'demo', es_demo: true,
      notas: '',
    });
    count++;
  }
  await batch.commit();
  console.log(`  ✅ ${count} reservas`);
}

async function seedFichajes() {
  console.log('🕐 Creando fichajes (últimas 4 semanas)...');
  let batch = db.batch();
  let count = 0;

  for (let semana = 0; semana < 4; semana++) {
    for (let dia = 0; dia < 5; dia++) {
      const offset = -(semana * 7 + dia + 1);
      const fecha = dias(offset);
      const fechaStr = fecha.toISOString().split('T')[0];

      for (const emp of EMPLEADOS) {
        const entrada = new Date(fecha);
        entrada.setHours(8 + rand(0,1), rand(45,59));
        const salida = new Date(fecha);
        salida.setHours(17 + rand(0,1), rand(0,15));
        const minutos = Math.round((salida - entrada) / 60000);

        const ref = db.collection('empresas').doc(EMPRESA_ID).collection('fichajes').doc();
        batch.set(ref, {
          id: ref.id,
          empleado_id: emp.id, empleado_nombre: emp.nombre,
          fecha: fechaStr, fecha_ts: ts(fecha),
          hora_entrada: ts(entrada), hora_salida: ts(salida),
          minutos_totales: minutos,
          estado: 'completo', es_demo: true,
          tipo: 'normal',
          notas: '',
        });
        count++;

        if (count % 300 === 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
    }
  }
  await batch.commit();
  console.log(`  ✅ ${count} fichajes`);
}

async function seedVacaciones() {
  console.log('🌴 Creando vacaciones...');
  const batch = db.batch();
  const tipos = ['vacaciones','permiso_retribuido','baja_medica'];

  const solicitudes = [
    { emp: EMPLEADOS[0], desde: dias(-60), hasta: dias(-53), tipo: 'vacaciones',         estado: 'aprobada' },
    { emp: EMPLEADOS[1], desde: dias(-30), hasta: dias(-28), tipo: 'permiso_retribuido',  estado: 'aprobada' },
    { emp: EMPLEADOS[2], desde: dias(-90), hasta: dias(-75), tipo: 'vacaciones',          estado: 'aprobada' },
    { emp: EMPLEADOS[3], desde: dias(-10), hasta: dias(-8),  tipo: 'baja_medica',         estado: 'aprobada' },
    { emp: EMPLEADOS[0], desde: dias(30),  hasta: dias(43),  tipo: 'vacaciones',          estado: 'pendiente' },
    { emp: EMPLEADOS[2], desde: dias(15),  hasta: dias(17),  tipo: 'permiso_retribuido',  estado: 'pendiente' },
  ];

  for (const s of solicitudes) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('vacaciones').doc();
    const dias_total = Math.round((s.hasta - s.desde) / 86400000) + 1;
    batch.set(ref, {
      id: ref.id,
      empleado_id: s.emp.id, empleado_nombre: s.emp.nombre,
      tipo: s.tipo, estado: s.estado,
      fecha_inicio: ts(s.desde), fecha_fin: ts(s.hasta),
      dias_habiles: dias_total,
      motivo: '', comentario_admin: '',
      es_demo: true,
      fecha_solicitud: ts(dias(-(rand(1,5)))),
    });
  }
  await batch.commit();
  console.log(`  ✅ ${solicitudes.length} solicitudes vacaciones`);
}

async function seedFacturas(clienteIds) {
  console.log('🧾 Creando facturas (12 meses)...');
  const conceptos = [
    { nombre: 'Corte + Tinte',        precio: 93,  iva: 21 },
    { nombre: 'Tratamiento keratina', precio: 120, iva: 21 },
    { nombre: 'Mechas balayage',      precio: 95,  iva: 21 },
    { nombre: 'Peinado de fiesta',    precio: 45,  iva: 21 },
    { nombre: 'Manicura + Pedicura',  precio: 52,  iva: 21 },
    { nombre: 'Pack novias',          precio: 180, iva: 21 },
    { nombre: 'Corte hombre',         precio: 16,  iva: 21 },
    { nombre: 'Tinte raíces',         precio: 45,  iva: 21 },
  ];
  const estados = ['pagada','pagada','pagada','pagada','pendiente','vencida'];

  let batch = db.batch();
  let count = 0;

  for (let i = 0; i < 80; i++) {
    const d = dias(-rand(1, 365));
    const concepto = pick(conceptos);
    const base = concepto.precio;
    const ivaImporte = +(base * concepto.iva / 100).toFixed(2);
    const total = +(base + ivaImporte).toFixed(2);
    const num = String(i + 1).padStart(4, '0');
    const año = d.getFullYear();
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('facturas').doc();

    batch.set(ref, {
      id: ref.id,
      numero: `F-${año}-${num}`,
      serie: 'F',
      cliente_nombre: CLIENTES[i % CLIENTES.length].nombre,
      cliente_id: clienteIds[i % clienteIds.length],
      fecha_emision: ts(d),
      fecha_vencimiento: ts(new Date(d.getTime() + 30 * 86400000)),
      lineas: [{
        descripcion: concepto.nombre,
        cantidad: 1, precio_unitario: base,
        iva_porcentaje: concepto.iva, iva_importe: ivaImporte,
        subtotal: base, total,
      }],
      base_imponible: base, iva_total: ivaImporte, total,
      estado: pick(estados),
      tipo: 'factura', es_demo: true,
      notas: '',
    });
    count++;
    if (count % 300 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
  console.log(`  ✅ ${count} facturas`);
}

async function seedTareas() {
  console.log('✅ Creando tareas...');
  const batch = db.batch();
  const tareas = [
    { titulo: 'Renovar stock de tintes Loreal', prioridad: 'alta',   estado: 'pendiente',  asignado: EMPLEADOS[0] },
    { titulo: 'Preparar escaparate para San Valentín', prioridad: 'media',  estado: 'en_progreso', asignado: EMPLEADOS[1] },
    { titulo: 'Actualizar lista de precios 2026', prioridad: 'alta',  estado: 'completada', asignado: EMPLEADOS[0] },
    { titulo: 'Revisar agenda de citas de la semana', prioridad: 'baja',   estado: 'completada', asignado: EMPLEADOS[2] },
    { titulo: 'Llamar a proveedora de queratina', prioridad: 'media', estado: 'pendiente',  asignado: EMPLEADOS[3] },
    { titulo: 'Limpiar y organizar almacén de productos', prioridad: 'baja', estado: 'en_progreso', asignado: EMPLEADOS[2] },
    { titulo: 'Formación online técnicas color 2026', prioridad: 'media', estado: 'pendiente', asignado: EMPLEADOS[1] },
    { titulo: 'Preparar informe mensual de ventas', prioridad: 'alta', estado: 'completada', asignado: EMPLEADOS[0] },
  ];

  for (const t of tareas) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('tareas').doc();
    batch.set(ref, {
      id: ref.id, titulo: t.titulo, descripcion: '',
      prioridad: t.prioridad, estado: t.estado,
      asignado_a: t.asignado.id, asignado_nombre: t.asignado.nombre,
      fecha_creacion: ts(dias(-rand(1, 20))),
      fecha_limite: t.estado !== 'completada' ? ts(dias(rand(1, 14))) : null,
      completada: t.estado === 'completada',
      es_demo: true, etiquetas: [],
    });
  }
  await batch.commit();
  console.log(`  ✅ ${tareas.length} tareas`);
}

async function seedCatalogoCajaRapida() {
  console.log('🛍️  Creando catálogo TPV...');
  const batch = db.batch();
  const productos = [
    { nombre: 'Champú Loreal Professionnel 500ml', precio: 18.50, cat: 'Productos',  stock: 24 },
    { nombre: 'Mascarilla Nutritiva 250ml',         precio: 22.00, cat: 'Productos',  stock: 18 },
    { nombre: 'Aceite Argan Arganmidas 100ml',      precio: 28.00, cat: 'Productos',  stock: 12 },
    { nombre: 'Spray Protector Térmico',            precio: 15.50, cat: 'Productos',  stock: 30 },
    { nombre: 'Cepillo Tangle Teezer',              precio: 14.00, cat: 'Accesorios', stock: 8  },
    { nombre: 'Pinzas profesionales',               precio: 9.50,  cat: 'Accesorios', stock: 15 },
    { nombre: 'Corte de cabello mujer',             precio: 28.00, cat: 'Servicios',  stock: null },
    { nombre: 'Tinte completo',                     precio: 65.00, cat: 'Servicios',  stock: null },
    { nombre: 'Tratamiento keratina',               precio: 120.00,cat: 'Servicios',  stock: null },
    { nombre: 'Manicura clásica',                   precio: 22.00, cat: 'Servicios',  stock: null },
    { nombre: 'Peinado de fiesta',                  precio: 45.00, cat: 'Servicios',  stock: null },
    { nombre: 'Mechas / Balayage',                  precio: 95.00, cat: 'Servicios',  stock: null },
  ];

  for (const p of productos) {
    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('catalogo').doc();
    batch.set(ref, {
      id: ref.id, nombre: p.nombre, precio: p.precio,
      categoria: p.cat, activo: true, es_demo: true,
      stock: p.stock, controlar_stock: p.stock !== null,
      iva_porcentaje: 21,
      imagen_url: null,
    });
  }
  await batch.commit();
  console.log(`  ✅ ${productos.length} productos en catálogo`);
}

async function seedVentasTPV() {
  console.log('💳 Creando ventas TPV (últimos 14 días)...');
  const productosCatalogo = await db.collection('empresas')
    .doc(EMPRESA_ID).collection('catalogo').get();
  const prods = productosCatalogo.docs.map(d => d.data());

  let batch = db.batch();
  let count = 0;
  const metodos = ['efectivo','efectivo','tarjeta','tarjeta','bizum'];

  for (let d = 14; d >= 1; d--) {
    const ventasPorDia = rand(4, 10);
    for (let v = 0; v < ventasPorDia; v++) {
      const prod = pick(prods);
      const cantidad = rand(1, 2);
      const base = +(prod.precio * cantidad).toFixed(2);
      const iva = +(base * 0.21).toFixed(2);
      const total = +(base + iva).toFixed(2);
      const fecha = dias(-d);
      fecha.setHours(9 + rand(0, 9), rand(0, 59));

      const ref = db.collection('empresas').doc(EMPRESA_ID).collection('comandas').doc();
      batch.set(ref, {
        id: ref.id,
        lineas: [{ productoId: prod.id ?? ref.id, nombre: prod.nombre, cantidad, precioUnitario: prod.precio, ivaPorcentaje: 21 }],
        total, base_imponible: base, iva_total: iva,
        metodo_pago: pick(metodos),
        estado: 'cobrada', es_demo: true,
        fecha: ts(fecha), camarero_uid: ADMIN_UID,
        cliente_nombre: rand(0,1) ? pick(CLIENTES).nombre : null,
      });
      count++;
      if (count % 300 === 0) { await batch.commit(); batch = db.batch(); }
    }
  }
  await batch.commit();
  console.log(`  ✅ ${count} ventas TPV`);
}

async function seedAperturaCaja() {
  console.log('💰 Abriendo caja del día...');
  const ref = db.collection('empresas').doc(EMPRESA_ID)
    .collection('apertura_caja').doc(hoy());
  if (EJECUTAR) {
    await ref.set({
      fecha: hoy(), importe_inicial: 150.00,
      abierta_por: ADMIN_UID, abierta_en: SV,
      estado: 'abierta', es_demo: true,
    });
  }
  console.log(`  ✅ Caja abierta con 150€ de fondo`);
}

async function seedConfiguracionEmpresa() {
  console.log('⚙️  Configurando empresa...');
  const ref = db.collection('empresas').doc(EMPRESA_ID)
    .collection('configuracion').doc('general');
  await ref.set({
    tipo_negocio: 'peluqueria_estetica',
    tipo_tpv: 'peluqueria_estetica',
    nombre: 'Fluix Demo · Salón Estilo',
    descripcion: 'Salón de peluquería y estética en el centro de Guadalajara',
    moneda: 'EUR', pais: 'ES',
    modulos_activos: ['reservas','clientes','empleados','fichajes','vacaciones',
      'facturacion','tpv','tareas','nominas','servicios'],
    configurado: true, es_demo: true,
  }, { merge: true });
  console.log(`  ✅ Empresa configurada`);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  RESET + SEED DEMO — ${EMPRESA_ID}`);
  console.log(`  Modo: ${EJECUTAR ? '🚀 EJECUTAR (escribe en Firestore)' : '👁️  DRY-RUN (solo muestra pasos)'}`);
  console.log(`${'═'.repeat(60)}\n`);

  if (!EJECUTAR) {
    console.log('⚠️  Dry-run: pasa --ejecutar para aplicar los cambios\n');
    console.log('Pasos que se ejecutarían:');
    console.log('  1. Borrar todas las colecciones de demo_empresa_fluix2026');
    console.log('  2. Crear 4 empleados + usuarios');
    console.log('  3. Crear 24 nóminas (4 emp × 6 meses)');
    console.log('  4. Crear 10 clientes');
    console.log('  5. Crear 10 servicios');
    console.log('  6. Crear 3 profesionales');
    console.log('  7. Crear 20 reservas (pasadas + futuras)');
    console.log('  8. Crear ~320 fichajes (4 semanas × 5 días × 4 empleados)');
    console.log('  9. Crear 6 solicitudes de vacaciones');
    console.log(' 10. Crear 80 facturas (12 meses)');
    console.log(' 11. Crear 8 tareas');
    console.log(' 12. Crear 12 productos en catálogo TPV');
    console.log(' 13. Crear ~90 ventas TPV (14 días)');
    console.log(' 14. Abrir caja del día');
    console.log(' 15. Configurar empresa');
    return;
  }

  await borrarTodo();
  await seedEmpleados();
  await seedNominas();
  const clienteIds = await seedClientes();
  const servicioIds = await seedServicios();
  await seedProfesionales();
  await seedReservas(clienteIds, servicioIds);
  await seedFichajes();
  await seedVacaciones();
  await seedFacturas(clienteIds);
  await seedTareas();
  await seedCatalogoCajaRapida();
  await seedVentasTPV();
  await seedAperturaCaja();
  await seedConfiguracionEmpresa();

  console.log(`\n${'═'.repeat(60)}`);
  console.log('  ✅ SEED COMPLETO — listo para capturas de App Store');
  console.log(`${'═'.repeat(60)}\n`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e); process.exit(1); });
