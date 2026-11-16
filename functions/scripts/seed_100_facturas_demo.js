/**
 * SEED 100 FACTURAS DEMO — demo_empresa_fluix2026
 *
 * Genera 100 facturas distribuidas en 18 meses (ene 2025 – jun 2026),
 * con variedad realista: importes, tipos de IVA, estados, clientes, servicios.
 *
 * Ejecutar: node scripts/seed_100_facturas_demo.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const EMPRESA_ID = 'demo_empresa_fluix2026';

// ── Datos de prueba ─────────────────────────────────────────────────────────

const CLIENTES = [
  { nombre: 'María García López',       telefono: '612345678', correo: 'maria.garcia@email.com' },
  { nombre: 'José Martínez Ruiz',       telefono: '623456789', correo: 'jose.martinez@gmail.com' },
  { nombre: 'Ana Rodríguez Sánchez',    telefono: '634567890', correo: 'ana.rodriguez@outlook.com' },
  { nombre: 'Carlos Fernández Torres',  telefono: '645678901', correo: 'carlos.fdez@empresa.es' },
  { nombre: 'Laura González Pérez',     telefono: '656789012', correo: 'laura.gonzalez@email.com' },
  { nombre: 'Pedro López Díaz',         telefono: '667890123', correo: 'pedro.lopez@gmail.com' },
  { nombre: 'Carmen Sánchez Jiménez',   telefono: '678901234', correo: 'carmen.sanchez@email.com' },
  { nombre: 'Antonio Pérez García',     telefono: '689012345', correo: 'antonio.perez@empresa.es' },
  { nombre: 'Isabel Martín Moreno',     telefono: '690123456', correo: 'isabel.martin@outlook.com' },
  { nombre: 'Francisco Jiménez Ruiz',   telefono: '601234567', correo: 'francisco.jimenez@email.com' },
  { nombre: 'Construcciones Alcarria S.L.', telefono: '949123456', correo: 'info@alcarria.es' },
  { nombre: 'Diseño Digital Gua S.L.',  telefono: '949234567', correo: 'contacto@disenodg.es' },
  { nombre: 'Catering La Alcarria',     telefono: '949345678', correo: 'catering@alcarria.es' },
  { nombre: 'Farmacia López García',    telefono: '949456789', correo: null },
  { nombre: 'Taller Mecánico Norte',    telefono: '949567890', correo: null },
];

const SERVICIOS_POR_TIPO = {
  consultoría: [
    { nombre: 'Consultoría de negocio (2h)', precio: 180, iva: 21 },
    { nombre: 'Asesoramiento estratégico', precio: 350, iva: 21 },
    { nombre: 'Auditoría de procesos', precio: 520, iva: 21 },
  ],
  diseño: [
    { nombre: 'Diseño de logotipo', precio: 280, iva: 21 },
    { nombre: 'Diseño web responsive', precio: 950, iva: 21 },
    { nombre: 'Campaña redes sociales (mes)', precio: 420, iva: 21 },
  ],
  desarrollo: [
    { nombre: 'Desarrollo app móvil (sprint)', precio: 1800, iva: 21 },
    { nombre: 'Mantenimiento web (mes)', precio: 150, iva: 21 },
    { nombre: 'Integración API externa', precio: 650, iva: 21 },
  ],
  formación: [
    { nombre: 'Formación presencial (4h)', precio: 320, iva: 21 },
    { nombre: 'Curso online (acceso anual)', precio: 180, iva: 21 },
    { nombre: 'Taller práctico (empresa)', precio: 480, iva: 21 },
  ],
  otros: [
    { nombre: 'Servicio de soporte técnico', precio: 90, iva: 21 },
    { nombre: 'Licencia software anual', precio: 240, iva: 21 },
    { nombre: 'Gestión de contenidos (mes)', precio: 200, iva: 21 },
    { nombre: 'Pack publicidad digital', precio: 380, iva: 21 },
    { nombre: 'Informe de análisis', precio: 260, iva: 21 },
  ],
};

const ESTADOS = ['pagada', 'pagada', 'pagada', 'pendiente', 'pendiente', 'anulada'];

// ── Helpers ─────────────────────────────────────────────────────────────────

function rnd(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr) { return arr[rnd(0, arr.length - 1)]; }

function fechaAleatoria(anio, mes) {
  const diasEnMes = new Date(anio, mes, 0).getDate();
  const dia = rnd(1, diasEnMes);
  return new Date(anio, mes - 1, dia, rnd(9, 18), rnd(0, 59), 0);
}

function nFactura(serie, num) {
  return `${serie}-${String(num).padStart(4, '0')}`;
}

function crearLineas(servicio, cantidad = 1) {
  const subtotalSinIva = servicio.precio * cantidad;
  const importeIva = (subtotalSinIva * servicio.iva) / 100;
  return [{
    descripcion: servicio.nombre,
    cantidad,
    precio_unitario: servicio.precio,
    porcentaje_iva: servicio.iva,
    subtotal_sin_iva: subtotalSinIva,
    importe_iva: importeIva,
    subtotal: subtotalSinIva + importeIva,
    recargo_equivalencia: 0,
  }];
}

// ── Distribución temporal: 100 facturas en 18 meses ─────────────────────────
// Distribuye más facturas en Q2-Q4 (meses de más actividad)

const DISTRIBUCION = [
  // 2025
  { anio: 2025, mes: 1,  cantidad: 3 },
  { anio: 2025, mes: 2,  cantidad: 4 },
  { anio: 2025, mes: 3,  cantidad: 5 },
  { anio: 2025, mes: 4,  cantidad: 6 },
  { anio: 2025, mes: 5,  cantidad: 7 },
  { anio: 2025, mes: 6,  cantidad: 6 },
  { anio: 2025, mes: 7,  cantidad: 4 },
  { anio: 2025, mes: 8,  cantidad: 3 },
  { anio: 2025, mes: 9,  cantidad: 6 },
  { anio: 2025, mes: 10, cantidad: 7 },
  { anio: 2025, mes: 11, cantidad: 8 },
  { anio: 2025, mes: 12, cantidad: 9 },
  // 2026
  { anio: 2026, mes: 1,  cantidad: 6 },
  { anio: 2026, mes: 2,  cantidad: 7 },
  { anio: 2026, mes: 3,  cantidad: 8 },
  { anio: 2026, mes: 4,  cantidad: 7 },
  { anio: 2026, mes: 5,  cantidad: 6 },
  { anio: 2026, mes: 6,  cantidad: 8 },
  // Resto en oct 2026
];

async function main() {
  const SERIE = 'fac';
  console.log(`\n🚀 Seeding 100 facturas demo en empresa: ${EMPRESA_ID}\n`);

  // Limpiar facturas demo anteriores si existen
  const existentes = await db
    .collection('empresas').doc(EMPRESA_ID)
    .collection('facturas')
    .where('_seed', '==', true)
    .get();
  if (!existentes.empty) {
    const batch0 = db.batch();
    existentes.docs.forEach(d => batch0.delete(d.ref));
    await batch0.commit();
    console.log(`🗑️  Eliminadas ${existentes.docs.length} facturas seed anteriores`);
  }

  let numeroGlobal = 1;
  let totalCreadas = 0;
  const todosLosServicios = Object.values(SERVICIOS_POR_TIPO).flat();

  const BATCH_SIZE = 450;
  let batch = db.batch();
  let ops = 0;

  for (const { anio, mes, cantidad } of DISTRIBUCION) {
    for (let i = 0; i < cantidad; i++) {
      const cliente = pick(CLIENTES);
      const servicio = pick(todosLosServicios);
      const cantidad_servicios = pick([1, 1, 1, 2, 3]);
      const lineas = crearLineas(servicio, cantidad_servicios);
      const subtotalSinIva = lineas.reduce((s, l) => s + l.subtotal_sin_iva, 0);
      const importeIva = lineas.reduce((s, l) => s + l.importe_iva, 0);
      const importeTotal = subtotalSinIva + importeIva;
      const fecha = fechaAleatoria(anio, mes);
      const estado = pick(ESTADOS);
      const numero = nFactura(SERIE, numeroGlobal++);

      const factura = {
        _seed: true,
        numero_factura: numero,
        serie: SERIE,
        tipo_factura: 'servicio',
        flujo: 'ingreso',
        estado,
        cliente_nombre: cliente.nombre,
        cliente_telefono: cliente.telefono ?? null,
        cliente_correo: cliente.correo ?? null,
        lineas,
        subtotal_sin_iva: parseFloat(subtotalSinIva.toFixed(2)),
        importe_iva: parseFloat(importeIva.toFixed(2)),
        importe_total: parseFloat(importeTotal.toFixed(2)),
        porcentaje_iva: servicio.iva,
        retencion_irpf: 0,
        total_recargo_equivalencia: 0,
        fecha_emision: admin.firestore.Timestamp.fromDate(fecha),
        fecha_vencimiento: estado === 'pendiente'
          ? admin.firestore.Timestamp.fromDate(new Date(fecha.getTime() + 30 * 24 * 3600 * 1000))
          : null,
        fecha_pago: estado === 'pagada'
          ? admin.firestore.Timestamp.fromDate(new Date(fecha.getTime() + rnd(1, 15) * 24 * 3600 * 1000))
          : null,
        metodo_pago: estado === 'pagada' ? pick(['transferencia', 'tarjeta', 'efectivo']) : null,
        notas: null,
        created_at: admin.firestore.Timestamp.fromDate(fecha),
      };

      const ref = db
        .collection('empresas').doc(EMPRESA_ID)
        .collection('facturas').doc();
      batch.set(ref, factura);
      ops++;
      totalCreadas++;

      if (ops >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
  }

  // Añadir facturas extra para llegar a 100 si hace falta
  while (totalCreadas < 100) {
    const cliente = pick(CLIENTES);
    const servicio = pick(todosLosServicios);
    const lineas = crearLineas(servicio, 1);
    const subtotalSinIva = lineas[0].subtotal_sin_iva;
    const importeIva = lineas[0].importe_iva;
    const importeTotal = importeIva + subtotalSinIva;
    const fecha = fechaAleatoria(2026, rnd(7, 10));
    const estado = pick(ESTADOS);

    const factura = {
      _seed: true,
      numero_factura: nFactura(SERIE, numeroGlobal++),
      serie: SERIE,
      tipo_factura: 'servicio',
      flujo: 'ingreso',
      estado,
      cliente_nombre: cliente.nombre,
      cliente_telefono: cliente.telefono ?? null,
      cliente_correo: cliente.correo ?? null,
      lineas,
      subtotal_sin_iva: parseFloat(subtotalSinIva.toFixed(2)),
      importe_iva: parseFloat(importeIva.toFixed(2)),
      importe_total: parseFloat(importeTotal.toFixed(2)),
      porcentaje_iva: servicio.iva,
      retencion_irpf: 0,
      total_recargo_equivalencia: 0,
      fecha_emision: admin.firestore.Timestamp.fromDate(fecha),
      fecha_pago: estado === 'pagada'
        ? admin.firestore.Timestamp.fromDate(new Date(fecha.getTime() + rnd(1, 10) * 24 * 3600 * 1000))
        : null,
      metodo_pago: estado === 'pagada' ? pick(['transferencia', 'tarjeta', 'efectivo']) : null,
      notas: null,
      created_at: admin.firestore.Timestamp.fromDate(fecha),
    };

    const ref = db.collection('empresas').doc(EMPRESA_ID).collection('facturas').doc();
    batch.set(ref, factura);
    ops++;
    totalCreadas++;
  }

  if (ops > 0) await batch.commit();

  console.log(`✅ ${totalCreadas} facturas creadas`);
  console.log(`📅 Distribución: ene 2025 → oct 2026`);
  console.log(`👥 ${CLIENTES.length} clientes distintos`);
  console.log(`🛠️  ${todosLosServicios.length} tipos de servicio`);
  console.log(`📊 Estados: ~50% pagadas, ~33% pendientes, ~17% anuladas`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e); process.exit(1); });
