/**
 * demo_ambulancias_informes.js
 * Mete facturas, gastos, clientes y nóminas de noviembre para el admin.
 *
 * Uso: node functions/scripts/demo_ambulancias_informes.js --guardar
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db        = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp  = admin.firestore.Timestamp;

const EID = 'demo_ambulancias_guadalajara_2026';
const GUARDAR = process.argv.includes('--guardar');

function ts(day, month = 11, year = 2026) {
  return Timestamp.fromDate(new Date(year, month - 1, day, 10, 0, 0));
}

// ── CLIENTES ──────────────────────────────────────────────────────────────────
const clientes = [
  {
    id: 'cliente_sescam',
    nombre: 'SESCAM — Servicio de Salud de Castilla-La Mancha',
    nif: 'Q4500268B',
    email: 'contratacion@sescam.jccm.es',
    telefono: '+34969100000',
    direccion: 'C/ Berna 1, 02071 Albacete',
    tipo: 'empresa',
    activo: true,
    creado_en: ts(1, 10),
  },
  {
    id: 'cliente_mapfre',
    nombre: 'MAPFRE Seguros de Salud',
    nif: 'A28007748',
    email: 'concertados@mapfre.com',
    telefono: '+34900202122',
    direccion: 'Carretera de Pozuelo 52, 28222 Majadahonda',
    tipo: 'empresa',
    activo: true,
    creado_en: ts(1, 10),
  },
  {
    id: 'cliente_adeslas',
    nombre: 'SegurCaixa Adeslas',
    nif: 'A28037208',
    email: 'proveedores@adeslas.es',
    telefono: '+34900200800',
    tipo: 'empresa',
    activo: true,
    creado_en: ts(1, 10),
  },
];

// ── FACTURAS NOVIEMBRE ────────────────────────────────────────────────────────
const facturas = [
  {
    numero_factura: 'F2026-0041',
    cliente_id: 'cliente_sescam',
    cliente_nombre: 'SESCAM — Servicio de Salud de Castilla-La Mancha',
    cliente_nif: 'Q4500268B',
    fecha: ts(3),
    fecha_vencimiento: ts(33),  // 30 días
    concepto: 'Servicios de transporte sanitario urgente — octubre 2026 (142 servicios)',
    lineas: [{ descripcion: 'Transporte sanitario urgente (142 servicios × 108,45€)', cantidad: 142, precio: 108.45, iva: 0 }],
    base_imponible: 15399.90,
    iva: 0,          // exento IVA art. 20.1.3 LIVA
    total: 15399.90,
    estado: 'enviada',
    tipo: 'ingreso',
    metodo_pago: 'transferencia',
    creado_en: ts(3),
  },
  {
    numero_factura: 'F2026-0042',
    cliente_id: 'cliente_mapfre',
    cliente_nombre: 'MAPFRE Seguros de Salud',
    cliente_nif: 'A28007748',
    fecha: ts(4),
    fecha_vencimiento: ts(34),
    concepto: 'Traslados programados asegurados MAPFRE — octubre 2026',
    lineas: [{ descripcion: 'Traslados programados (28 servicios × 185€)', cantidad: 28, precio: 185.00, iva: 0 }],
    base_imponible: 5180.00,
    iva: 0,
    total: 5180.00,
    estado: 'cobrada',
    tipo: 'ingreso',
    metodo_pago: 'transferencia',
    creado_en: ts(4),
  },
  {
    numero_factura: 'F2026-0043',
    cliente_id: 'cliente_adeslas',
    cliente_nombre: 'SegurCaixa Adeslas',
    cliente_nif: 'A28037208',
    fecha: ts(4),
    fecha_vencimiento: ts(34),
    concepto: 'Servicios asistencia sanitaria en ruta — octubre 2026',
    lineas: [{ descripcion: 'Servicios asistencia en ruta (12 × 220€)', cantidad: 12, precio: 220.00, iva: 0 }],
    base_imponible: 2640.00,
    iva: 0,
    total: 2640.00,
    estado: 'enviada',
    tipo: 'ingreso',
    metodo_pago: 'transferencia',
    creado_en: ts(4),
  },
];

// ── GASTOS NOVIEMBRE ──────────────────────────────────────────────────────────
const gastos = [
  {
    concepto: 'Combustible flotilla noviembre',
    categoria: 'vehiculos',
    importe: 1240.80,
    proveedor: 'Repsol Tarjeta Flotas',
    fecha: ts(1),
    metodo_pago: 'tarjeta',
    estado: 'pagado',
    creado_en: ts(1),
  },
  {
    concepto: 'Mantenimiento y revisión ambulancia A-07',
    categoria: 'vehiculos',
    importe: 680.00,
    proveedor: 'Talleres Sánchez e Hijos S.L.',
    fecha: ts(2),
    metodo_pago: 'transferencia',
    estado: 'pagado',
    creado_en: ts(2),
  },
  {
    concepto: 'Material sanitario fungible (gasas, guantes, suero)',
    categoria: 'material_sanitario',
    importe: 534.60,
    proveedor: 'Suministros Médicos del Centro S.A.',
    fecha: ts(3),
    metodo_pago: 'transferencia',
    estado: 'pagado',
    creado_en: ts(3),
  },
  {
    concepto: 'Seguro RC vehículos sanitarios — cuota mensual',
    categoria: 'seguros',
    importe: 1980.00,
    proveedor: 'Zurich Insurance Group',
    fecha: ts(1),
    metodo_pago: 'domiciliacion',
    estado: 'pagado',
    creado_en: ts(1),
  },
  {
    concepto: 'Alquiler nave garaje + lavadero ambulancias',
    categoria: 'instalaciones',
    importe: 850.00,
    proveedor: 'Inmobiliaria Guadalajara Centro',
    fecha: ts(1),
    metodo_pago: 'domiciliacion',
    estado: 'pagado',
    creado_en: ts(1),
  },
  {
    concepto: 'Comunicaciones — líneas radio y móviles flotilla',
    categoria: 'comunicaciones',
    importe: 212.40,
    proveedor: 'Vodafone Business',
    fecha: ts(2),
    metodo_pago: 'domiciliacion',
    estado: 'pagado',
    creado_en: ts(2),
  },
];

// ── NÓMINAS NOVIEMBRE ─────────────────────────────────────────────────────────
const nominasNov = [
  {
    id: 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2_2026_11',
    empleado_id: 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2',
    nombre: 'Elena Martín Sanz',
    mes: 11, anio: 2026,
    salario_bruto_mensual: 1850.00,
    porcentaje_irpf: 15.5,
    retencion_irpf: 286.75,
    ss_empleado: 117.48,
    ss_empresa: 573.74,
    salario_neto: 1445.77,
    estado: 'generada',
    empresa_id: EID,
    creado_en: ts(5),
  },
  {
    id: 'emp_roberto_lopez_2026_11',
    empleado_id: 'emp_roberto_lopez',
    nombre: 'Roberto López Vega',
    mes: 11, anio: 2026,
    salario_bruto_mensual: 1850.00,
    porcentaje_irpf: 14.0,
    retencion_irpf: 259.00,
    ss_empleado: 117.48,
    ss_empresa: 573.74,
    salario_neto: 1473.52,
    estado: 'generada',
    empresa_id: EID,
    creado_en: ts(5),
  },
  {
    id: 'emp_lucia_rdz_2026_11',
    empleado_id: 'emp_lucia_rdz',
    nombre: 'Lucía Rodríguez',
    mes: 11, anio: 2026,
    salario_bruto_mensual: 1750.00,
    porcentaje_irpf: 13.0,
    retencion_irpf: 227.50,
    ss_empleado: 111.13,
    ss_empresa: 542.63,
    salario_neto: 1411.37,
    estado: 'generada',
    empresa_id: EID,
    creado_en: ts(5),
  },
];

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  const totalFacturas = facturas.reduce((s, f) => s + f.total, 0);
  const totalGastos   = gastos.reduce((s, g) => s + g.importe, 0);
  const totalNominas  = nominasNov.reduce((s, n) => s + n.salario_bruto_mensual, 0);

  console.log('\n📊 Informe noviembre — Sysday Emergencias');
  console.log(`  Facturas:  ${facturas.length} → ${totalFacturas.toFixed(2)} €`);
  console.log(`  Gastos:    ${gastos.length}   → ${totalGastos.toFixed(2)} €`);
  console.log(`  Nóminas:   ${nominasNov.length}   → ${totalNominas.toFixed(2)} € bruto`);
  console.log(`  Clientes:  ${clientes.length}`);
  console.log(`  Resultado: ${(totalFacturas - totalGastos - totalNominas).toFixed(2)} €\n`);

  if (!GUARDAR) {
    console.log('⚠️  DRY RUN — usa --guardar\n');
    return;
  }

  const batch = db.batch();

  for (const c of clientes) {
    const { id, ...data } = c;
    batch.set(db.collection('empresas').doc(EID).collection('clientes').doc(id), data, { merge: true });
  }
  for (const f of facturas) {
    batch.set(db.collection('empresas').doc(EID).collection('facturas').doc(f.numero_factura), f, { merge: true });
  }
  for (const g of gastos) {
    batch.set(db.collection('empresas').doc(EID).collection('gastos').doc(), g);
  }

  await batch.commit();
  console.log('✅ Clientes, facturas y gastos guardados');

  const batch2 = db.batch();
  for (const n of nominasNov) {
    const { id, ...data } = n;
    batch2.set(db.collection('empresas').doc(EID).collection('nominas').doc(id), data, { merge: true });
  }
  await batch2.commit();
  console.log('✅ Nóminas noviembre guardadas');
  console.log('\n✅ Todo listo. El admin ya tiene informes completos para noviembre.\n');
}

main().catch(e => { console.error(e); process.exit(1); });
