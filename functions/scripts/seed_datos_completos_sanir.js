/**
 * SEED DATOS COMPLETOS — Sanir Transporte Sanitario CLM
 *
 * Añade a la cuenta demo (demo_sanir_clm_2026) datos realistas de:
 *   • 5 Clientes (entidades contratantes)
 *   • 5 Proveedores
 *   • 15 Facturas emitidas (jul-oct 2026, distintos estados)
 *   • 10 Facturas recibidas (proveedores)
 *   • 3 Presupuestos (aceptado, enviado, rechazado)
 *   • 20 Nóminas completas (5 empleados × 4 meses: jul-oct 2026)
 *   • Datos salariales actualizados por empleado
 *   • 8 Tareas de equipo
 *   • 20 Notificaciones (una por tipo)
 *
 * NOTA: Requiere que seed_demo_ambulancias.js haya sido ejecutado primero.
 *
 * Uso:
 *   cd functions
 *   node scripts/seed_datos_completos_sanir.js
 */

const admin = require('firebase-admin');
if (!admin.apps.length) {
  const serviceAccount = require('../serviceAccountKey.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId: 'planeaapp-4bea4' });
}
const db   = admin.firestore();
const FS   = admin.firestore.FieldValue;
const ts   = (d) => admin.firestore.Timestamp.fromDate(d);
const hoy  = new Date();
const EMPRESA_ID = 'demo_sanir_clm_2026';
const eRef = () => db.collection('empresas').doc(EMPRESA_ID);

function fecha(y, m, d) { return new Date(y, m - 1, d); }
function fmt(d) { return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }
function round2(n) { return Math.round(n * 100) / 100; }

// ════════════════════════════════════════════════════════════════════════════
// EMPRESA
// ════════════════════════════════════════════════════════════════════════════

const EMPRESA_DATA = {
  perfil: {
    nombre: 'Sanir Transporte Sanitario CLM',
    correo: 'info@sanirtransporte.es',
    telefono: '+34 925 220 100',
    direccion: 'Polígono Industrial, C/ Industria 1',
    descripcion: 'Empresa de transporte sanitario urgente y no urgente en Castilla-La Mancha',
    logo_url: null,
    ciudad: 'Toledo',
    codigo_postal: '45001',
    provincia: 'Toledo',
    pais: 'ES',
    web: 'https://www.sanirtransporte.es',
  },
  configuracion: {
    modulos_activos: {
      clientes: true, facturacion: true, empleados: true,
      nominas: true, fichajes: true, tareas: true,
      reservas: false, tpv: false, fiscal: true, pedidos: true,
    },
    configuracion_modulos: {},
    criterio_iva: 'devengo',
  },
  nif: 'B45000001',
  legal_name: 'Sanir Transporte Sanitario CLM S.L.',
  tax_id: 'B45000001',
  sector: 'ambulancia',
  cnae: '8621',
  actividad: 'Actividades de ambulancias',
  serie_factura: 'F',
  serie_rectificativa: 'R',
  serie_proforma: 'P',
  iban_empresa: 'ES12 2100 0418 4502 0005 1332',
  bic_empresa: 'CAIXESBBXXX',
  forma_juridica: 'sl',
  ccc_ss: '450000000001',
  cnae_ss: '8621',
  onboarding_completado: true,
  es_demo: true,
};

const FISCAL_DATA = {
  nif: 'B45000001',
  razon_social: 'Sanir Transporte Sanitario CLM S.L.',
  domicilio_fiscal: 'Polígono Industrial, C/ Industria 1, 45001 Toledo',
  codigo_postal: '45001',
  municipio: 'Toledo',
  provincia: 'Toledo',
  regimen_iva: 'general',
  epigraf_iae: '721',
  esta_en_sii: false,
  criterio_iva: 'devengo',
  forma_juridica: 'sl',
};

// ════════════════════════════════════════════════════════════════════════════
// CLIENTES (entidades que contratan servicios de Sanir)
// ════════════════════════════════════════════════════════════════════════════

const CLIENTES = [
  {
    id: 'cli_sescam',
    nombre: 'SESCAM — Servicio de Salud de CLM',
    nif: 'Q4500001H',
    tipo: 'empresa',
    email: 'contratacion@sescam.jccm.es',
    telefono: '+34 925 274 400',
    direccion: 'C/ Berna 1, 45071 Toledo',
    ciudad: 'Toledo',
    codigo_postal: '45071',
    notas: 'Principal cliente. Contrato marco de transporte sanitario urgente CLM. Pagos a 60 días.',
    total_facturado: 0,
    es_proveedor: false,
    es_demo: true,
  },
  {
    id: 'cli_hospital_virgen',
    nombre: 'Hospital Virgen de la Salud Toledo',
    nif: 'Q4500010F',
    tipo: 'empresa',
    email: 'gerencia@hvs.sescam.jccm.es',
    telefono: '+34 925 269 100',
    direccion: 'Av. de Barber s/n, 45004 Toledo',
    ciudad: 'Toledo',
    codigo_postal: '45004',
    notas: 'Traslados programados interhospitalarios. Contrato anual renovable.',
    total_facturado: 0,
    es_proveedor: false,
    es_demo: true,
  },
  {
    id: 'cli_mutua_universal',
    nombre: 'Mutua Universal Mugenat',
    nif: 'G28088160',
    tipo: 'empresa',
    email: 'accidentes@mutuauniversal.net',
    telefono: '+34 902 300 666',
    direccion: 'C/ Aragó 240, 08007 Barcelona',
    ciudad: 'Barcelona',
    codigo_postal: '08007',
    notas: 'Accidentes laborales zona CLM. Autorización previa por siniestro. Pago a 30 días.',
    total_facturado: 0,
    es_proveedor: false,
    es_demo: true,
  },
  {
    id: 'cli_clinica_san_juan',
    nombre: 'Clínica San Juan — Toledo',
    nif: 'B45189732',
    tipo: 'empresa',
    email: 'admin@clinicasanjuan.es',
    telefono: '+34 925 251 800',
    direccion: 'C/ Real del Arrabal 20, 45003 Toledo',
    ciudad: 'Toledo',
    codigo_postal: '45003',
    notas: 'Traslados de pacientes privados. Facturación mensual.',
    total_facturado: 0,
    es_proveedor: false,
    es_demo: true,
  },
  {
    id: 'cli_ayto_talavera',
    nombre: 'Ayuntamiento de Talavera de la Reina',
    nif: 'P4524600C',
    tipo: 'empresa',
    email: 'contratacion@talavera.org',
    telefono: '+34 925 814 400',
    direccion: 'Pl. del Pan 1, 45600 Talavera de la Reina',
    ciudad: 'Talavera de la Reina',
    codigo_postal: '45600',
    notas: 'Cobertura eventos y fiestas patronales. Contrato puntual por servicio.',
    total_facturado: 0,
    es_proveedor: false,
    es_demo: true,
  },
];

// ════════════════════════════════════════════════════════════════════════════
// PROVEEDORES
// ════════════════════════════════════════════════════════════════════════════

const PROVEEDORES = [
  {
    id: 'prov_repsol',
    nombre: 'Repsol YPF S.A.',
    nif: 'A78374725',
    tipo: 'empresa',
    email: 'clientes.empresa@repsol.com',
    telefono: '+34 912 348 000',
    direccion: 'C/ Méndez Álvaro 44, 28045 Madrid',
    ciudad: 'Madrid',
    codigo_postal: '28045',
    notas: 'Suministro de combustible flota de ambulancias. Tarjeta de flota. Facturación quincenal.',
    es_proveedor: true,
    es_demo: true,
  },
  {
    id: 'prov_autosal',
    nombre: 'Talleres Autosal CLM S.L.',
    nif: 'B45234567',
    tipo: 'empresa',
    email: 'taller@autosalclm.es',
    telefono: '+34 925 198 234',
    direccion: 'Polígono El Ruiseñor, Nave 7, 45007 Toledo',
    ciudad: 'Toledo',
    codigo_postal: '45007',
    notas: 'Mantenimiento y reparación de vehículos sanitarios. Revisiones programadas.',
    es_proveedor: true,
    es_demo: true,
  },
  {
    id: 'prov_sumin_medicos',
    nombre: 'Suministros Médicos Ibérica S.L.',
    nif: 'B28765432',
    tipo: 'empresa',
    email: 'pedidos@sumimedicaiberica.es',
    telefono: '+34 916 543 210',
    direccion: 'C/ Manufactura 15, Pol. Ind. Vallecas, 28031 Madrid',
    ciudad: 'Madrid',
    codigo_postal: '28031',
    notas: 'Material sanitario consumible: oxígeno, desfibriladores, botiquines, EPIs.',
    es_proveedor: true,
    es_demo: true,
  },
  {
    id: 'prov_mapfre',
    nombre: 'Mapfre Seguros',
    nif: 'A28019399',
    tipo: 'empresa',
    email: 'clientes.empresa@mapfre.com',
    telefono: '+34 915 816 000',
    direccion: 'Carretera de Pozuelo 52, 28222 Majadahonda, Madrid',
    ciudad: 'Majadahonda',
    codigo_postal: '28222',
    notas: 'Seguro de flota (8 ambulancias). Póliza anual. Prima mensual domiciliada.',
    es_proveedor: true,
    es_demo: true,
  },
  {
    id: 'prov_teltronic',
    nombre: 'Teltronic S.A.U.',
    nif: 'A50181606',
    tipo: 'empresa',
    email: 'soporte@teltronic.es',
    telefono: '+34 976 010 110',
    direccion: 'C/ Ebro 2, Pol. Malpica, 50016 Zaragoza',
    ciudad: 'Zaragoza',
    codigo_postal: '50016',
    notas: 'Sistemas de radiocomunicación TETRA para vehículos de emergencia. Contrato de mantenimiento.',
    es_proveedor: true,
    es_demo: true,
  },
];

// ════════════════════════════════════════════════════════════════════════════
// HELPERS FACTURA
// IVA: Transporte sanitario exento art. 20.1.3º LIVA (Art. 20 LIVA)
// ════════════════════════════════════════════════════════════════════════════

function linea(descripcion, precio, cantidad = 1, iva = 0) {
  const sub = round2(precio * cantidad);
  return { descripcion, precio_unitario: precio, cantidad, porcentaje_iva: iva, subtotal_sin_iva: sub };
}

function calcFactura(lineas, iva_pct = 0) {
  const sub = round2(lineas.reduce((s, l) => s + l.subtotal_sin_iva, 0));
  const ivaImporte = round2(sub * iva_pct / 100);
  return { subtotal: sub, total_iva: ivaImporte, total: round2(sub + ivaImporte) };
}

// ════════════════════════════════════════════════════════════════════════════
// FACTURAS EMITIDAS (15) — jul-oct 2026
// Transporte sanitario: exento IVA (art. 20.1.3º LIVA)
// ════════════════════════════════════════════════════════════════════════════

function factura(id, num, cliente, fecha_em, estado, lineas_data, notas = '', dias_vcto = 60) {
  const c = calcFactura(lineas_data);
  const fVcto = new Date(fecha_em);
  fVcto.setDate(fVcto.getDate() + dias_vcto);
  return {
    id,
    empresa_id: EMPRESA_ID,
    numero_factura: num,
    serie: 'fac',
    tipo: 'servicio',
    estado,
    cliente_nombre: CLIENTES.find(c2 => c2.id === cliente)?.nombre ?? cliente,
    datos_fiscales: {
      nif: CLIENTES.find(c2 => c2.id === cliente)?.nif,
      razon_social: CLIENTES.find(c2 => c2.id === cliente)?.nombre,
      direccion: CLIENTES.find(c2 => c2.id === cliente)?.direccion,
      ciudad: CLIENTES.find(c2 => c2.id === cliente)?.ciudad,
      pais: 'España',
    },
    lineas: lineas_data,
    subtotal: c.subtotal,
    total_iva: 0,
    total: c.subtotal,  // exento IVA
    descuento_global: 0,
    importe_descuento_global: 0,
    porcentaje_irpf: 0,
    retencion_irpf: 0,
    total_recargo_equivalencia: 0,
    dias_vencimiento: dias_vcto,
    notas_cliente: notas,
    notas_internas: 'Exento IVA — Art. 20.1.3º LIVA (transporte de enfermos en ambulancia)',
    fecha_emision: ts(fecha_em),
    fecha_vencimiento: ts(fVcto),
    fecha_pago: estado === 'pagada' ? ts(fVcto) : null,
    historial: [],
    es_demo: true,
  };
}

const FACTURAS = [
  // ── Julio 2026 ──────────────────────────────────────────────────────────────
  factura('fac_001', 'F/2026/001', 'cli_sescam', fecha(2026,7,1), 'pagada',
    [linea('Servicio transporte sanitario urgente — julio 2026 (zona Toledo)', 22400)],
    'Contrato marco 2026/TLO-001'),

  factura('fac_002', 'F/2026/002', 'cli_hospital_virgen', fecha(2026,7,5), 'pagada',
    [linea('Traslados programados interhospitalarios — julio 2026', 6800)],
    '34 servicios × 200€ tarifa pactada', 30),

  factura('fac_003', 'F/2026/003', 'cli_mutua_universal', fecha(2026,7,12), 'pagada',
    [
      linea('Traslado accidente laboral — expediente MU-2026-1247', 320),
      linea('Traslado accidente laboral — expediente MU-2026-1251', 280),
      linea('Traslado accidente laboral — expediente MU-2026-1298', 450),
    ],
    'Siniestros julio 2026', 30),

  // ── Agosto 2026 ─────────────────────────────────────────────────────────────
  factura('fac_004', 'F/2026/004', 'cli_sescam', fecha(2026,8,1), 'pagada',
    [linea('Servicio transporte sanitario urgente — agosto 2026 (zona Toledo)', 24100)],
    'Contrato marco 2026/TLO-001 — mes de agosto (+7.6% actividad verano)'),

  factura('fac_005', 'F/2026/005', 'cli_hospital_virgen', fecha(2026,8,4), 'pagada',
    [linea('Traslados programados interhospitalarios — agosto 2026', 5600)],
    '28 servicios', 30),

  factura('fac_006', 'F/2026/006', 'cli_ayto_talavera', fecha(2026,8,15), 'pagada',
    [
      linea('Cobertura sanitaria Fiestas de San Agustín 2026 (5 días)', 2400),
      linea('Ambulancia ALS 24h — días 15-19 agosto', 1800),
    ],
    'Fiestas patronales Talavera 2026', 30),

  factura('fac_007', 'F/2026/007', 'cli_mutua_universal', fecha(2026,8,20), 'pagada',
    [
      linea('Traslado accidente laboral — expediente MU-2026-1389', 390),
      linea('Traslado accidente laboral — expediente MU-2026-1401', 310),
    ], '', 30),

  // ── Septiembre 2026 ─────────────────────────────────────────────────────────
  factura('fac_008', 'F/2026/008', 'cli_sescam', fecha(2026,9,1), 'pagada',
    [linea('Servicio transporte sanitario urgente — septiembre 2026 (zona Toledo)', 21800)],
    'Contrato marco 2026/TLO-001'),

  factura('fac_009', 'F/2026/009', 'cli_hospital_virgen', fecha(2026,9,3), 'pendiente',
    [linea('Traslados programados interhospitalarios — septiembre 2026', 7200)],
    '36 servicios', 30),

  factura('fac_010', 'F/2026/010', 'cli_clinica_san_juan', fecha(2026,9,10), 'pendiente',
    [
      linea('Traslado paciente diálisis — septiembre 2026 (12 servicios)', 1680),
      linea('Traslado oncología — septiembre 2026 (8 servicios)', 1200),
    ], '', 30),

  factura('fac_011', 'F/2026/011', 'cli_mutua_universal', fecha(2026,9,15), 'pendiente',
    [linea('Traslados accidentes laborales — septiembre 2026 (expedientes varios)', 1420)],
    '5 siniestros septiembre', 30),

  // ── Octubre 2026 ────────────────────────────────────────────────────────────
  factura('fac_012', 'F/2026/012', 'cli_sescam', fecha(2026,10,1), 'pendiente',
    [linea('Servicio transporte sanitario urgente — octubre 2026 (zona Toledo)', 22600)],
    'Contrato marco 2026/TLO-001'),

  factura('fac_013', 'F/2026/013', 'cli_hospital_virgen', fecha(2026,10,2), 'pendiente',
    [linea('Traslados programados interhospitalarios — octubre 2026', 6400)],
    '32 servicios', 30),

  factura('fac_014', 'F/2026/014', 'cli_clinica_san_juan', fecha(2026,10,8), 'pendiente',
    [
      linea('Traslado paciente diálisis — octubre 2026 (10 servicios)', 1400),
      linea('Traslado oncología — octubre 2026 (6 servicios)', 900),
    ], '', 30),

  // Factura vencida (octubre → vencida en 30 días → nov 1 ya pasó aprox)
  factura('fac_015', 'F/2026/015', 'cli_mutua_universal', fecha(2026,9,25), 'vencida',
    [linea('Traslados accidentes laborales — septiembre 2026 (ampliación)', 980)],
    'VENCIDA — Reclamar pago', 30),
];

// ════════════════════════════════════════════════════════════════════════════
// FACTURAS RECIBIDAS (10) — proveedores
// ════════════════════════════════════════════════════════════════════════════

function facturaRec(id, num, provId, fecha_em, estado, base, iva_pct, concepto) {
  const iva = round2(base * iva_pct / 100);
  const prov = PROVEEDORES.find(p => p.id === provId);
  const fVcto = new Date(fecha_em);
  fVcto.setDate(fVcto.getDate() + 30);
  return {
    id, empresa_id: EMPRESA_ID,
    numero_factura: num,
    nombre_proveedor: prov?.nombre ?? provId,
    nif_proveedor: prov?.nif ?? '',
    direccion_proveedor: prov?.direccion,
    es_intracomunitario: false,
    concepto,
    base_imponible: base,
    porcentaje_iva: iva_pct,
    importe_iva: iva,
    importe_no_sujeto: 0,
    iva_deducible: true,
    descuento_global: 0,
    recargo_equivalencia: 0,
    total_con_impuestos: round2(base + iva),
    porcentaje_retencion: 0,
    importe_retencion: 0,
    estado,
    fecha_emision: ts(fecha_em),
    fecha_recepcion: ts(fecha_em),
    fecha_vencimiento: ts(fVcto),
    fecha_pago: estado === 'pagada' ? ts(fVcto) : null,
    categoria_gasto: 'operativo',
    es_demo: true,
  };
}

const FACTURAS_RECIBIDAS = [
  facturaRec('frec_001', 'REP-2026-08741', 'prov_repsol',  fecha(2026,7,15), 'pagada',  9840,  21, 'Combustible flota ambulancias — 1ª quincena julio 2026'),
  facturaRec('frec_002', 'REP-2026-09102', 'prov_repsol',  fecha(2026,8,1),  'pagada',  10200, 21, 'Combustible flota ambulancias — 2ª quincena julio + 1ª agosto 2026'),
  facturaRec('frec_003', 'AUT-2026-0312',  'prov_autosal', fecha(2026,7,20), 'pagada',  1840,  21, 'Revisión 100.000 km ambulancia VE-2234-CLM + cambio frenos'),
  facturaRec('frec_004', 'AUT-2026-0338',  'prov_autosal', fecha(2026,9,5),  'pagada',  2460,  21, 'Reparación sistema eléctrico ambulancia TLO-4421 + ITV'),
  facturaRec('frec_005', 'SMI-2026-1150',  'prov_sumin_medicos', fecha(2026,7,8), 'pagada', 3240, 21, 'Material sanitario consumible — julio 2026 (oxígeno, desfibriladores, botiquines)'),
  facturaRec('frec_006', 'SMI-2026-1298',  'prov_sumin_medicos', fecha(2026,9,10),'pagada', 2890, 21, 'Reposición material sanitario — septiembre 2026'),
  facturaRec('frec_007', 'MAP-2026-0784',  'prov_mapfre',  fecha(2026,7,1),  'pagada',  1480,  0,  'Prima seguro flota sanitaria julio 2026 — póliza F-28019399-2026'),
  facturaRec('frec_008', 'MAP-2026-0901',  'prov_mapfre',  fecha(2026,10,1), 'pagada',  1480,  0,  'Prima seguro flota sanitaria octubre 2026'),
  facturaRec('frec_009', 'TEL-2026-0421',  'prov_teltronic',fecha(2026,7,1), 'pagada',  980,   21, 'Mantenimiento sistemas TETRA ambulancias — 3T 2026'),
  facturaRec('frec_010', 'REP-2026-10543', 'prov_repsol',  fecha(2026,10,15),'recibida',10800, 21, 'Combustible flota ambulancias — octubre 2026'),
];

// ════════════════════════════════════════════════════════════════════════════
// PRESUPUESTOS (3)
// ════════════════════════════════════════════════════════════════════════════

const PRESUPUESTOS = [
  {
    id: 'pre_001',
    empresa_id: EMPRESA_ID,
    numero_factura: 'P/2026/001',
    serie: 'pro',
    tipo: 'proforma',
    estado: 'pendiente',
    estado_presupuesto: 'aceptado',
    cliente_nombre: 'SESCAM — Servicio de Salud de CLM',
    datos_fiscales: { nif: 'Q4500001H', razon_social: 'SESCAM — Servicio de Salud de CLM', pais: 'España' },
    lineas: [
      linea('Servicio transporte sanitario urgente 2027 — zona Toledo (12 meses)', 268800),
      linea('Cobertura guardia localizada 24h — zona Talavera (12 meses)', 48000),
    ],
    subtotal: 316800, total_iva: 0, total: 316800,
    descuento_global: 0, importe_descuento_global: 0,
    porcentaje_irpf: 0, retencion_irpf: 0, total_recargo_equivalencia: 0,
    dias_vencimiento: 30,
    notas_cliente: 'Propuesta renovación contrato marco 2027. Incremento 3% sobre 2026.',
    notas_internas: 'ACEPTADO verbalmente por SESCAM el 15/10/2026. Pendiente firma contrato.',
    fecha_emision: ts(fecha(2026,10,1)),
    fecha_vencimiento: ts(fecha(2026,11,30)),
    fecha_validez_presupuesto: ts(fecha(2026,11,30)),
    historial: [], es_demo: true,
  },
  {
    id: 'pre_002',
    empresa_id: EMPRESA_ID,
    numero_factura: 'P/2026/002',
    serie: 'pro',
    tipo: 'proforma',
    estado: 'pendiente',
    estado_presupuesto: 'enviado',
    cliente_nombre: 'Clínica San Juan — Toledo',
    datos_fiscales: { nif: 'B45189732', razon_social: 'Clínica San Juan — Toledo', pais: 'España' },
    lineas: [
      linea('Contrato transporte programado pacientes diálisis 2027 (12 meses)', 19200),
      linea('Contrato transporte oncología 2027 (12 meses)', 14400),
    ],
    subtotal: 33600, total_iva: 0, total: 33600,
    descuento_global: 0, importe_descuento_global: 0,
    porcentaje_irpf: 0, retencion_irpf: 0, total_recargo_equivalencia: 0,
    dias_vencimiento: 30,
    notas_cliente: 'Propuesta anual 2027. Incluye disponibilidad garantizada 7 días/semana.',
    notas_internas: 'Enviado por email el 25/10/2026. Pendiente respuesta.',
    fecha_emision: ts(fecha(2026,10,25)),
    fecha_vencimiento: ts(fecha(2026,11,25)),
    fecha_validez_presupuesto: ts(fecha(2026,11,25)),
    historial: [], es_demo: true,
  },
  {
    id: 'pre_003',
    empresa_id: EMPRESA_ID,
    numero_factura: 'P/2026/003',
    serie: 'pro',
    tipo: 'proforma',
    estado: 'pendiente',
    estado_presupuesto: 'rechazado',
    cliente_nombre: 'Diputación Provincial de Toledo',
    datos_fiscales: { nif: 'P4500000H', razon_social: 'Diputación Provincial de Toledo', pais: 'España' },
    lineas: [
      linea('Servicio transporte sanitario zona rural — Montes de Toledo (12 meses)', 86400),
    ],
    subtotal: 86400, total_iva: 0, total: 86400,
    descuento_global: 0, importe_descuento_global: 0,
    porcentaje_irpf: 0, retencion_irpf: 0, total_recargo_equivalencia: 0,
    dias_vencimiento: 30,
    notas_cliente: '',
    notas_internas: 'Rechazado — adjudicado a competidor en licitación pública 09/2026.',
    fecha_emision: ts(fecha(2026,8,1)),
    fecha_vencimiento: ts(fecha(2026,9,1)),
    fecha_validez_presupuesto: ts(fecha(2026,9,1)),
    historial: [], es_demo: true,
  },
];

// ════════════════════════════════════════════════════════════════════════════
// NÓMINAS COMPLETAS — 5 empleados × 4 meses (jul-oct 2026)
// ════════════════════════════════════════════════════════════════════════════

// Datos por empleado
const DATOS_NOMINA = {
  amb_emp_001: { // Elena — Conductora
    nombre: 'Elena Martín Sanz', nif: '11111111H', nss: '190000000001',
    salario_base: 1816.00, irpf_pct: 8.0,
    tipo_contrato: 'indefinido', pagas_prorrateadas: false,
    grupo_cot: 'grupo9', categoria: 'conductor',
    fecha_inicio: fecha(2021,3,1),
  },
  amb_emp_002: { // Roberto — Conductor
    nombre: 'Roberto López Vega', nif: '22222222J', nss: '190000000002',
    salario_base: 1816.00, irpf_pct: 12.0,
    tipo_contrato: 'indefinido', pagas_prorrateadas: false,
    grupo_cot: 'grupo9', categoria: 'conductor',
    fecha_inicio: fecha(2020,6,15),
  },
  amb_emp_003: { // Carmen — ATS
    nombre: 'Carmen Ruiz Molina', nif: '33333333K', nss: '190000000003',
    salario_base: 2395.00, irpf_pct: 15.0,
    tipo_contrato: 'indefinido', pagas_prorrateadas: false,
    grupo_cot: 'grupo4', categoria: 'ats-due',
    fecha_inicio: fecha(2019,1,10),
  },
  amb_emp_004: { // Javier — Jefe Equipo
    nombre: 'Javier Torres Pérez', nif: '44444444L', nss: '190000000004',
    salario_base: 1781.00, irpf_pct: 8.0,
    tipo_contrato: 'indefinido', pagas_prorrateadas: false,
    grupo_cot: 'grupo7', categoria: 'jefe-equipo',
    fecha_inicio: fecha(2018,4,1),
  },
  amb_emp_005: { // Laura — Auxiliar Admin
    nombre: 'Laura González Díaz', nif: '55555555M', nss: '190000000005',
    salario_base: 1612.00, irpf_pct: 10.0,
    tipo_contrato: 'indefinido', pagas_prorrateadas: false,
    grupo_cot: 'grupo7', categoria: 'auxiliar-admin',
    fecha_inicio: fecha(2022,9,1),
  },
};

function calcNomina(empId, mes, anio) {
  const d = DATOS_NOMINA[empId];
  const base = d.salario_base;
  // Paga extra en julio (mes 7) — convenio pagas en julio y diciembre
  const pagaExtra = mes === 7 ? base : 0;
  const totalBruto = base + pagaExtra;

  // SS trabajador (base cotización = salario bruto)
  const baseCot = Math.max(1424.40, Math.min(5101.20, totalBruto));
  const ssCC        = round2(baseCot * 0.0470);
  const ssDesempleo = round2(baseCot * 0.0155);
  const ssFP        = round2(baseCot * 0.0010);
  const ssMei       = round2(baseCot * 0.0015);
  const totalSS     = round2(ssCC + ssDesempleo + ssFP + ssMei);

  // IRPF
  const retencion   = round2(totalBruto * d.irpf_pct / 100);
  const totalDeduc  = round2(totalSS + retencion);
  const neto        = round2(totalBruto - totalDeduc);

  // SS empresa
  const ssEmpCC        = round2(baseCot * 0.2360);
  const ssEmpDesempleo = round2(baseCot * 0.0550);
  const ssEmpFogasa    = round2(baseCot * 0.0020);
  const ssEmpFP        = round2(baseCot * 0.0060);
  const ssEmpAT        = round2(baseCot * 0.0175);  // CNAE 869
  const ssEmpMei       = round2(baseCot * 0.0075);
  const totalSSEmp     = round2(ssEmpCC + ssEmpDesempleo + ssEmpFogasa + ssEmpFP + ssEmpAT + ssEmpMei);

  const meses = ['','Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  const periodo = `${meses[mes]} ${anio}`;

  return {
    id: `${empId}_${anio}_${String(mes).padStart(2,'0')}`,
    empresa_id: EMPRESA_ID,
    empleado_id: empId,
    empleado_nombre: d.nombre,
    empleado_nif: d.nif,
    empleado_nss: d.nss,
    mes, anio, periodo,
    salario_bruto_mensual: base,
    paga_extra: pagaExtra,
    horas_extra: 0,
    precio_hora_extra: 0,
    importe_horas_extra: 0,
    complementos: 0,
    paga_extra_prorrateada: 0,
    retribuciones_especie: 0,
    base_cotizacion: baseCot,
    ss_trabajador_cc: ssCC,
    ss_trabajador_desempleo: ssDesempleo,
    ss_trabajador_fp: ssFP,
    ss_mei_trabajador: ssMei,
    ss_solidaridad_trabajador: 0,
    ss_horas_extra_trabajador: 0,
    base_irpf: round2(totalBruto),
    porcentaje_irpf: d.irpf_pct,
    retencion_irpf: retencion,
    irpf_ajustado: false,
    ss_empresa_cc: ssEmpCC,
    ss_empresa_desempleo: ssEmpDesempleo,
    ss_empresa_fogasa: ssEmpFogasa,
    ss_empresa_fp: ssEmpFP,
    ss_empresa_at: ssEmpAT,
    ss_mei_empresa: ssEmpMei,
    ss_solidaridad_empresa: 0,
    ss_horas_extra_empresa: 0,
    tipo_hora_extra: 'noEstructural',
    descuento_ausencias: 0,
    lineas_ausencias: [],
    plus_antiguedad: 0,
    anios_antiguedad: 0,
    trienios_bienios: 0,
    embargo_judicial: 0,
    dias_it: 0,
    importe_it: 0,
    importe_it_empresa: 0,
    importe_it_inss: 0,
    importe_it_mutua: 0,
    descuento_salario_por_it: 0,
    regularizacion_irpf: 0,
    complementos_detallados: [],
    salario_neto: neto,
    liquido_final: neto,
    total_ss_empresa: totalSSEmp,
    coste_total_empresa: round2(neto + totalDeduc + totalSSEmp),
    estado: mes < 10 ? 'pagada' : 'aprobada',
    fecha_creacion: ts(fecha(anio, mes, 28)),
    fecha_pago: mes < 10 ? ts(fecha(anio, mes, 28)) : null,
    es_demo: true,
  };
}

const NOMINAS = [];
const MESES_NOMINA = [7, 8, 9, 10, 11]; // noviembre = mes actual
for (const empId of Object.keys(DATOS_NOMINA)) {
  for (const mes of MESES_NOMINA) {
    NOMINAS.push(calcNomina(empId, mes, 2026));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAREAS (8)
// ════════════════════════════════════════════════════════════════════════════

const TAREAS = [
  { id: 'tarea_001', titulo: 'Renovar ITV — Ambulancia VE-2234-CLM', descripcion: 'Fecha límite ITV: 15 de diciembre. Pedir cita en estación Calidad Automoción Toledo.', estado: 'pendiente', prioridad: 'alta', asignado_a: 'amb_emp_004', fecha_vencimiento: ts(fecha(2026,12,10)), modulo: 'vehiculos', es_demo: true },
  { id: 'tarea_002', titulo: 'Formación RCP avanzada — equipo operativo', descripcion: 'Renovación certificación RCP + DEA para los 4 conductores y ATS. Centro de formación Cruz Roja Toledo.', estado: 'en_progreso', prioridad: 'alta', asignado_a: 'amb_emp_004', fecha_vencimiento: ts(fecha(2026,11,30)), modulo: 'formacion', es_demo: true },
  { id: 'tarea_003', titulo: 'Revisión stock material sanitario Q4 2026', descripcion: 'Inventario oxígeno (10 botellas mínimo), botiquines, EPIs. Hacer pedido a Suministros Médicos Ibérica si stock bajo.', estado: 'pendiente', prioridad: 'media', asignado_a: 'amb_emp_005', fecha_vencimiento: ts(fecha(2026,11,15)), modulo: 'almacen', es_demo: true },
  { id: 'tarea_004', titulo: 'Cobrar factura vencida Mutua Universal (F/2026/015)', descripcion: 'Factura F/2026/015 vencida el 25/10/2026. Importe: 980€. Contactar responsable: pagos@mutuauniversal.net', estado: 'pendiente', prioridad: 'alta', asignado_a: 'amb_emp_005', fecha_vencimiento: ts(fecha(2026,11,10)), modulo: 'facturacion', es_demo: true },
  { id: 'tarea_005', titulo: 'Preparar propuesta renovación contrato SESCAM 2027', descripcion: 'Presupuesto P/2026/001 aceptado verbalmente. Preparar contrato formal para firma antes de fin de año.', estado: 'en_progreso', prioridad: 'alta', asignado_a: 'amb_emp_004', fecha_vencimiento: ts(fecha(2026,11,30)), modulo: 'contratos', es_demo: true },
  { id: 'tarea_006', titulo: 'Actualizar protocolos SESCAM — nueva normativa 2026', descripcion: 'Revisar e implementar actualizaciones del protocolo de actuación SESCAM publicadas en octubre 2026.', estado: 'pendiente', prioridad: 'media', asignado_a: 'amb_emp_003', fecha_vencimiento: ts(fecha(2026,12,1)), modulo: 'calidad', es_demo: true },
  { id: 'tarea_007', titulo: 'Nóminas noviembre 2026', descripcion: 'Generar y aprobar nóminas de los 5 empleados correspondientes a noviembre 2026. Fecha límite pago: 28/11.', estado: 'pendiente', prioridad: 'media', asignado_a: 'amb_emp_005', fecha_vencimiento: ts(fecha(2026,11,25)), modulo: 'nominas', es_demo: true },
  { id: 'tarea_008', titulo: 'Revisión póliza Mapfre — renovación anual 2027', descripcion: 'Póliza F-28019399-2026 vence el 31/12/2026. Solicitar nueva cotización a Mapfre y comparar con corredores alternativos.', estado: 'pendiente', prioridad: 'baja', asignado_a: 'amb_emp_005', fecha_vencimiento: ts(fecha(2026,12,15)), modulo: 'seguros', es_demo: true },
];

// ════════════════════════════════════════════════════════════════════════════
// NOTIFICACIONES (una por tipo)
// ════════════════════════════════════════════════════════════════════════════

function notif(tipo, titulo, cuerpo, modulo, leida = false) {
  return { tipo, titulo, cuerpo, modulo_destino: modulo, leida, timestamp: ts(hoy), es_demo: true };
}

const NOTIFICACIONES = [
  notif('tareaAsignada',         '📌 Nueva tarea asignada',              'Se te ha asignado: Renovar ITV ambulancia VE-2234-CLM',              'tareas'),
  notif('facturaVencida',        '💰 Factura vencida',                   'F/2026/015 de Mutua Universal (980€) lleva 12 días vencida',         'facturacion'),
  notif('reservaNueva',          '📅 Nueva solicitud de servicio',        'SESCAM solicita cobertura extra el 10/11/2026 en Talavera',          'reservas'),
  notif('alertaFiscal',          '⚠️ Alerta fiscal',                     'El plazo del modelo 303 (3T 2026) vence el 30/10/2026',              'fiscal'),
  notif('nominaPendiente',       '🧾 Nóminas pendientes de aprobar',     '5 nóminas de octubre 2026 están en estado "aprobada" sin pagar',    'nominas'),
  notif('clienteNuevo',          '🤝 Nuevo cliente',                     'Clínica San Juan ha sido registrada como cliente',                   'clientes'),
  notif('vacacionesSolicitadas', '🏖️ Solicitud de vacaciones',           'Elena Martín solicita vacaciones del 22/12 al 03/01/2027',          'vacaciones'),
  notif('suscripcionPorVencer',  '⏰ Suscripción por vencer',            'Tu suscripción Enterprise vence el 06/11/2027',                     ''),
  notif('stockBajo',             '📦 Stock bajo',                        'Quedan menos de 3 botellas de oxígeno en almacén Toledo',           'almacen'),
  notif('fichajeCorregido',      '✏️ Fichaje corregido',                  'Se corrigió el fichaje de Roberto López del 04/11/2026',            'fichajes'),
  notif('vencimientoFiscal',     '📋 Vencimiento fiscal próximo',        'Modelo 111 (retenciones IRPF 3T) vence el 20/10/2026',              'fiscal'),
  notif('generica',              'ℹ️ Recordatorio',                      'Revisión programada flota de ambulancias — martes 10/11/2026',       ''),
  notif('trofeo',                '🏆 ¡Objetivo alcanzado!',              'Sanir supera las 1.000 intervenciones en 2026',                     ''),
  notif('pedidoNuevo',           '🛒 Nuevo pedido recibido',             'Suministros Médicos Ibérica confirma pedido de material octubre',   'pedidos'),
  notif('contactoWeb',           '💬 Mensaje desde la web',              'Interesado en servicios de ambulancia privada para empresa',         'web'),
];

// ════════════════════════════════════════════════════════════════════════════
// FICHAJES / JORNADAS — octubre 2026 (mes completo, 5 empleados)
// Turno diurno: 07:00-19:00 (conductores + jefe)
// Turno nocturno: 19:00-07:00 (rota entre conductores)
// ATS: 08:00-20:00 (jornada clínica)
// Admin: 09:00-17:00 (L-V)
// ════════════════════════════════════════════════════════════════════════════

function dtOct(dia, h, min = 0) {
  return new Date(2026, 9, dia, h, min); // octubre = mes 9 (0-indexed)
}

// Genera un fichaje con pausa de 30 min a mitad de turno
function fichaje(id, empId, empNombre, dia, hEntrada, hSalida, correccion = false) {
  const e  = dtOct(dia, hEntrada);
  // Turnos de noche (hSalida < hEntrada) terminan al día siguiente
  const diaSalida = hSalida <= hEntrada ? dia + 1 : dia;
  const s  = dtOct(diaSalida, hSalida);
  const midH = Math.floor((hEntrada + hEntrada + 6) / 2); // pausa ~3h después de entrada
  const pausaI = new Date(2026, 9, dia, midH % 24, 0);
  const pausaF = new Date(2026, 9, dia, midH % 24, 30);
  // fecha como string 'YYYY-MM-DD' — coincide con el formato que usa la query Dart
  const fechaStr = `2026-10-${String(dia).padStart(2,'0')}`;
  return {
    id,
    empresa_id: EMPRESA_ID,
    empleado_id: empId,
    empleado_nombre: empNombre,
    fecha: fechaStr,          // string 'YYYY-MM-DD' para compatibilidad con query
    fecha_ts: ts(e),          // timestamp para ordenación
    entrada: ts(e),
    salida: ts(s),
    pausas: [{ inicio: ts(pausaI), fin: ts(pausaF) }],
    es_correccion: correccion,
    correcto: true,
    minutos_pausa: 30,
    es_demo: true,
  };
}

// Días laborables octubre 2026 (L-V: 1,2,5,6,7,8,9,12,13,14,15,16,19,20,21,22,23,26,27,28,29,30)
// Ambulancias: también fines de semana (3,4,10,11,17,18,24,25,31)
const FICHAJES = [
  // ── Elena (amb_emp_001) — Conductora, turnos diurnos L-V + alternos fds ──
  fichaje('fich_e_01', 'amb_emp_001', 'Elena Martín Sanz',  1, 7, 19),
  fichaje('fich_e_02', 'amb_emp_001', 'Elena Martín Sanz',  2, 7, 19),
  fichaje('fich_e_03', 'amb_emp_001', 'Elena Martín Sanz',  5, 7, 19),
  fichaje('fich_e_04', 'amb_emp_001', 'Elena Martín Sanz',  6, 7, 19),
  fichaje('fich_e_05', 'amb_emp_001', 'Elena Martín Sanz',  7, 7, 19),
  fichaje('fich_e_06', 'amb_emp_001', 'Elena Martín Sanz',  8, 7, 19),
  fichaje('fich_e_07', 'amb_emp_001', 'Elena Martín Sanz',  9, 7, 19),
  fichaje('fich_e_08', 'amb_emp_001', 'Elena Martín Sanz', 10, 7, 19), // sáb
  fichaje('fich_e_09', 'amb_emp_001', 'Elena Martín Sanz', 12, 7, 19),
  fichaje('fich_e_10', 'amb_emp_001', 'Elena Martín Sanz', 13, 7, 19),
  fichaje('fich_e_11', 'amb_emp_001', 'Elena Martín Sanz', 14, 7, 19),
  fichaje('fich_e_12', 'amb_emp_001', 'Elena Martín Sanz', 15, 7, 19),
  fichaje('fich_e_13', 'amb_emp_001', 'Elena Martín Sanz', 16, 7, 19),
  fichaje('fich_e_14', 'amb_emp_001', 'Elena Martín Sanz', 19, 7, 19),
  fichaje('fich_e_15', 'amb_emp_001', 'Elena Martín Sanz', 20, 7, 19),
  fichaje('fich_e_16', 'amb_emp_001', 'Elena Martín Sanz', 21, 7, 19),
  fichaje('fich_e_17', 'amb_emp_001', 'Elena Martín Sanz', 22, 7, 19),
  fichaje('fich_e_18', 'amb_emp_001', 'Elena Martín Sanz', 23, 7, 19),
  fichaje('fich_e_19', 'amb_emp_001', 'Elena Martín Sanz', 26, 7, 19),
  fichaje('fich_e_20', 'amb_emp_001', 'Elena Martín Sanz', 27, 7, 19),
  fichaje('fich_e_21', 'amb_emp_001', 'Elena Martín Sanz', 28, 7, 19),
  fichaje('fich_e_22', 'amb_emp_001', 'Elena Martín Sanz', 29, 7, 19),
  fichaje('fich_e_23', 'amb_emp_001', 'Elena Martín Sanz', 30, 7, 19),

  // ── Roberto (amb_emp_002) — Conductor, turno rotatorio (días/noches) ──────
  fichaje('fich_r_01', 'amb_emp_002', 'Roberto López Vega',  1, 19, 7),  // noche 1→2
  fichaje('fich_r_02', 'amb_emp_002', 'Roberto López Vega',  3, 19, 7),  // fds
  fichaje('fich_r_03', 'amb_emp_002', 'Roberto López Vega',  5, 7, 19),
  fichaje('fich_r_04', 'amb_emp_002', 'Roberto López Vega',  6, 7, 19),
  fichaje('fich_r_05', 'amb_emp_002', 'Roberto López Vega',  7, 19, 7),
  fichaje('fich_r_06', 'amb_emp_002', 'Roberto López Vega',  9, 19, 7),
  fichaje('fich_r_07', 'amb_emp_002', 'Roberto López Vega', 11, 7, 19),  // dom
  fichaje('fich_r_08', 'amb_emp_002', 'Roberto López Vega', 12, 7, 19),
  fichaje('fich_r_09', 'amb_emp_002', 'Roberto López Vega', 13, 7, 19),
  fichaje('fich_r_10', 'amb_emp_002', 'Roberto López Vega', 14, 19, 7),
  fichaje('fich_r_11', 'amb_emp_002', 'Roberto López Vega', 16, 7, 19),
  fichaje('fich_r_12', 'amb_emp_002', 'Roberto López Vega', 17, 7, 19),  // sáb
  fichaje('fich_r_13', 'amb_emp_002', 'Roberto López Vega', 19, 7, 19),
  fichaje('fich_r_14', 'amb_emp_002', 'Roberto López Vega', 20, 7, 19),
  fichaje('fich_r_15', 'amb_emp_002', 'Roberto López Vega', 21, 19, 7),
  fichaje('fich_r_16', 'amb_emp_002', 'Roberto López Vega', 23, 19, 7),
  fichaje('fich_r_17', 'amb_emp_002', 'Roberto López Vega', 24, 7, 19),  // sáb
  fichaje('fich_r_18', 'amb_emp_002', 'Roberto López Vega', 26, 7, 19),
  fichaje('fich_r_19', 'amb_emp_002', 'Roberto López Vega', 27, 7, 19),
  fichaje('fich_r_20', 'amb_emp_002', 'Roberto López Vega', 28, 19, 7),
  fichaje('fich_r_21', 'amb_emp_002', 'Roberto López Vega', 30, 7, 19),
  // Fichaje corregido (el 4/10 registró salida incorrecta → corregido por admin)
  { ...fichaje('fich_r_c1', 'amb_emp_002', 'Roberto López Vega', 4, 7, 19, true),
    notas_correccion: 'Salida registrada a las 17:00 por error. Jornada real 07:00-19:00.' },

  // ── Carmen (amb_emp_003) — ATS, turno clínico 08:00-20:00 L-V ─────────────
  fichaje('fich_c_01', 'amb_emp_003', 'Carmen Ruiz Molina',  1, 8, 20),
  fichaje('fich_c_02', 'amb_emp_003', 'Carmen Ruiz Molina',  2, 8, 20),
  fichaje('fich_c_03', 'amb_emp_003', 'Carmen Ruiz Molina',  5, 8, 20),
  fichaje('fich_c_04', 'amb_emp_003', 'Carmen Ruiz Molina',  6, 8, 20),
  fichaje('fich_c_05', 'amb_emp_003', 'Carmen Ruiz Molina',  7, 8, 20),
  fichaje('fich_c_06', 'amb_emp_003', 'Carmen Ruiz Molina',  8, 8, 20),
  fichaje('fich_c_07', 'amb_emp_003', 'Carmen Ruiz Molina',  9, 8, 20),
  fichaje('fich_c_08', 'amb_emp_003', 'Carmen Ruiz Molina', 12, 8, 20),
  fichaje('fich_c_09', 'amb_emp_003', 'Carmen Ruiz Molina', 13, 8, 20),
  fichaje('fich_c_10', 'amb_emp_003', 'Carmen Ruiz Molina', 14, 8, 20),
  fichaje('fich_c_11', 'amb_emp_003', 'Carmen Ruiz Molina', 15, 8, 20),
  fichaje('fich_c_12', 'amb_emp_003', 'Carmen Ruiz Molina', 16, 8, 20),
  fichaje('fich_c_13', 'amb_emp_003', 'Carmen Ruiz Molina', 19, 8, 20),
  fichaje('fich_c_14', 'amb_emp_003', 'Carmen Ruiz Molina', 20, 8, 20),
  fichaje('fich_c_15', 'amb_emp_003', 'Carmen Ruiz Molina', 21, 8, 20),
  fichaje('fich_c_16', 'amb_emp_003', 'Carmen Ruiz Molina', 22, 8, 20),
  fichaje('fich_c_17', 'amb_emp_003', 'Carmen Ruiz Molina', 23, 8, 20),
  fichaje('fich_c_18', 'amb_emp_003', 'Carmen Ruiz Molina', 26, 8, 20),
  fichaje('fich_c_19', 'amb_emp_003', 'Carmen Ruiz Molina', 27, 8, 20),
  fichaje('fich_c_20', 'amb_emp_003', 'Carmen Ruiz Molina', 28, 8, 20),
  fichaje('fich_c_21', 'amb_emp_003', 'Carmen Ruiz Molina', 29, 8, 20),
  fichaje('fich_c_22', 'amb_emp_003', 'Carmen Ruiz Molina', 30, 8, 20),

  // ── Javier (amb_emp_004) — Jefe de equipo, turno día + coordinación ────────
  fichaje('fich_j_01', 'amb_emp_004', 'Javier Torres Pérez',  1, 7, 19),
  fichaje('fich_j_02', 'amb_emp_004', 'Javier Torres Pérez',  2, 7, 19),
  fichaje('fich_j_03', 'amb_emp_004', 'Javier Torres Pérez',  3, 7, 19),  // sáb (guardia)
  fichaje('fich_j_04', 'amb_emp_004', 'Javier Torres Pérez',  5, 7, 19),
  fichaje('fich_j_05', 'amb_emp_004', 'Javier Torres Pérez',  6, 7, 19),
  fichaje('fich_j_06', 'amb_emp_004', 'Javier Torres Pérez',  7, 7, 19),
  fichaje('fich_j_07', 'amb_emp_004', 'Javier Torres Pérez',  8, 7, 19),
  fichaje('fich_j_08', 'amb_emp_004', 'Javier Torres Pérez',  9, 7, 19),
  fichaje('fich_j_09', 'amb_emp_004', 'Javier Torres Pérez', 12, 7, 19),
  fichaje('fich_j_10', 'amb_emp_004', 'Javier Torres Pérez', 13, 7, 19),
  fichaje('fich_j_11', 'amb_emp_004', 'Javier Torres Pérez', 14, 7, 19),
  fichaje('fich_j_12', 'amb_emp_004', 'Javier Torres Pérez', 15, 7, 19),
  fichaje('fich_j_13', 'amb_emp_004', 'Javier Torres Pérez', 16, 7, 19),
  fichaje('fich_j_14', 'amb_emp_004', 'Javier Torres Pérez', 17, 7, 19),  // sáb (guardia)
  fichaje('fich_j_15', 'amb_emp_004', 'Javier Torres Pérez', 19, 7, 19),
  fichaje('fich_j_16', 'amb_emp_004', 'Javier Torres Pérez', 20, 7, 19),
  fichaje('fich_j_17', 'amb_emp_004', 'Javier Torres Pérez', 21, 7, 19),
  fichaje('fich_j_18', 'amb_emp_004', 'Javier Torres Pérez', 22, 7, 19),
  fichaje('fich_j_19', 'amb_emp_004', 'Javier Torres Pérez', 23, 7, 19),
  fichaje('fich_j_20', 'amb_emp_004', 'Javier Torres Pérez', 26, 7, 19),
  fichaje('fich_j_21', 'amb_emp_004', 'Javier Torres Pérez', 27, 7, 19),
  fichaje('fich_j_22', 'amb_emp_004', 'Javier Torres Pérez', 28, 7, 19),
  fichaje('fich_j_23', 'amb_emp_004', 'Javier Torres Pérez', 29, 7, 19),
  fichaje('fich_j_24', 'amb_emp_004', 'Javier Torres Pérez', 30, 7, 19),

  // ── Laura (amb_emp_005) — Auxiliar admin, 09:00-17:00 L-V ─────────────────
  fichaje('fich_l_01', 'amb_emp_005', 'Laura González Díaz',  1, 9, 17),
  fichaje('fich_l_02', 'amb_emp_005', 'Laura González Díaz',  2, 9, 17),
  fichaje('fich_l_03', 'amb_emp_005', 'Laura González Díaz',  5, 9, 17),
  fichaje('fich_l_04', 'amb_emp_005', 'Laura González Díaz',  6, 9, 17),
  fichaje('fich_l_05', 'amb_emp_005', 'Laura González Díaz',  7, 9, 17),
  fichaje('fich_l_06', 'amb_emp_005', 'Laura González Díaz',  8, 9, 17),
  fichaje('fich_l_07', 'amb_emp_005', 'Laura González Díaz',  9, 9, 17),
  fichaje('fich_l_08', 'amb_emp_005', 'Laura González Díaz', 12, 9, 17),
  fichaje('fich_l_09', 'amb_emp_005', 'Laura González Díaz', 13, 9, 17),
  fichaje('fich_l_10', 'amb_emp_005', 'Laura González Díaz', 14, 9, 17),
  fichaje('fich_l_11', 'amb_emp_005', 'Laura González Díaz', 15, 9, 17),
  fichaje('fich_l_12', 'amb_emp_005', 'Laura González Díaz', 16, 9, 17),
  fichaje('fich_l_13', 'amb_emp_005', 'Laura González Díaz', 19, 9, 17),
  fichaje('fich_l_14', 'amb_emp_005', 'Laura González Díaz', 20, 9, 17),
  fichaje('fich_l_15', 'amb_emp_005', 'Laura González Díaz', 21, 9, 17),
  fichaje('fich_l_16', 'amb_emp_005', 'Laura González Díaz', 22, 9, 17),
  fichaje('fich_l_17', 'amb_emp_005', 'Laura González Díaz', 23, 9, 17),
  fichaje('fich_l_18', 'amb_emp_005', 'Laura González Díaz', 26, 9, 17),
  fichaje('fich_l_19', 'amb_emp_005', 'Laura González Díaz', 27, 9, 17),
  fichaje('fich_l_20', 'amb_emp_005', 'Laura González Díaz', 28, 9, 17),
  fichaje('fich_l_21', 'amb_emp_005', 'Laura González Díaz', 29, 9, 17),
  fichaje('fich_l_22', 'amb_emp_005', 'Laura González Díaz', 30, 9, 17),
];

// ════════════════════════════════════════════════════════════════════════════
// LIMPIEZA + ESCRITURA
// ════════════════════════════════════════════════════════════════════════════

async function seedEmpresa() {
  console.log('\n🏢 Creando/actualizando empresa y configuración fiscal...');
  await eRef().set(EMPRESA_DATA, { merge: true });
  await eRef().collection('configuracion').doc('fiscal').set(FISCAL_DATA, { merge: true });
  console.log('✅ Empresa y fiscal OK (NIF: B45000001)');
}

async function limpiar() {
  console.log('\n🧹 Limpiando datos demo anteriores...');
  const ref = eRef();
  async function borrar(col, campo) {
    const snap = await ref.collection(col).where(campo, '==', true).get();
    if (snap.empty) return 0;
    const b = db.batch(); snap.docs.forEach(d => b.delete(d.ref)); await b.commit();
    return snap.size;
  }
  async function borrarCol(col) {
    const snap = await ref.collection(col).get();
    if (snap.empty) return 0;
    const b = db.batch(); snap.docs.forEach(d => b.delete(d.ref)); await b.commit();
    return snap.size;
  }
  async function borrarClientes() {
    const snap = await db.collection('clientes').where('empresa_id', '==', EMPRESA_ID).where('es_demo', '==', true).get();
    if (snap.empty) return 0;
    const b = db.batch(); snap.docs.forEach(d => b.delete(d.ref)); await b.commit();
    return snap.size;
  }

  const n1 = await borrar('facturas',          'es_demo');
  const n2 = await borrar('facturas_recibidas','es_demo');
  const n3 = await borrar('nominas',           'es_demo');
  const n4 = await borrar('tareas',            'es_demo');
  const n5 = await borrarCol('bandeja_notificaciones');
  const n6 = await borrarClientes();
  const n7 = await borrar('fichajes',          'es_demo');
  console.log(`✅ Limpieza: ${n1} facturas, ${n2} fact.recibidas, ${n3} nóminas, ${n4} tareas, ${n5} notifs, ${n6} clientes/prov, ${n7} fichajes`);
}

async function seedClientes() {
  console.log('\n👥 Creando clientes y proveedores...');
  const b = db.batch();
  for (const c of [...CLIENTES, ...PROVEEDORES]) {
    b.set(db.collection('clientes').doc(c.id), { ...c, empresa_id: EMPRESA_ID, fecha_creacion: ts(hoy) });
  }
  await b.commit();
  console.log(`✅ ${CLIENTES.length} clientes + ${PROVEEDORES.length} proveedores`);
}

async function seedFacturas() {
  console.log('\n🧾 Creando facturas emitidas...');
  const ref = eRef().collection('facturas');
  for (let i = 0; i < FACTURAS.length; i += 450) {
    const chunk = FACTURAS.slice(i, i + 450);
    const b = db.batch();
    chunk.forEach(f => b.set(ref.doc(f.id), f));
    await b.commit();
  }
  console.log(`✅ ${FACTURAS.length} facturas emitidas`);
}

async function seedFacturasRecibidas() {
  console.log('\n📥 Creando facturas recibidas...');
  const ref = eRef().collection('facturas_recibidas');
  const b = db.batch();
  FACTURAS_RECIBIDAS.forEach(f => b.set(ref.doc(f.id), f));
  await b.commit();
  console.log(`✅ ${FACTURAS_RECIBIDAS.length} facturas recibidas`);
}

async function seedPresupuestos() {
  console.log('\n📄 Creando presupuestos...');
  const ref = eRef().collection('facturas');
  const b = db.batch();
  PRESUPUESTOS.forEach(p => b.set(ref.doc(p.id), p));
  await b.commit();
  console.log(`✅ ${PRESUPUESTOS.length} presupuestos`);
}

async function seedNominas() {
  console.log('\n💰 Creando nóminas completas (jul-oct 2026)...');
  const ref = eRef().collection('nominas');
  for (let i = 0; i < NOMINAS.length; i += 450) {
    const chunk = NOMINAS.slice(i, i + 450);
    const b = db.batch();
    chunk.forEach(n => b.set(ref.doc(n.id), n));
    await b.commit();
  }
  console.log(`✅ ${NOMINAS.length} nóminas (${Object.keys(DATOS_NOMINA).length} empleados × ${MESES_NOMINA.length} meses)`);
}

async function actualizarDatosNomina() {
  console.log('\n👤 Actualizando datos salariales de empleados...');
  // Usamos set+merge en lugar de update para no fallar si el doc no tiene datos_nomina aún
  for (const [empId, d] of Object.entries(DATOS_NOMINA)) {
    const ref = db.collection('usuarios').doc(empId);
    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`  ⚠️  ${empId} no existe — ejecuta seed_demo_ambulancias.js primero`);
      continue;
    }
    const datosPrevios = snap.data().datos_nomina || {};
    await ref.update({
      datos_nomina: {
        ...datosPrevios,
        tipo_contrato:         d.tipo_contrato,
        grupo_cotizacion:      d.grupo_cot,
        convenio_codigo_cat:   d.categoria,
        categoria_convenio_id: d.categoria,
        pagas_prorrateadas:    d.pagas_prorrateadas,
        sector_empresa:        'ambulancia',
        comunidad_autonoma:    'castillaMancha',
        irpf_personalizado:    d.irpf_pct,
        nif:                   d.nif,
        nss:                   d.nss,
        salario_bruto_anual:   datosPrevios.salario_bruto_anual ?? (d.salario_base * 14),
        num_pagas:             14,
        horas_semanales:       40,
        antiguedad_manual:     false,
      },
      fecha_inicio_contrato: ts(d.fecha_inicio),
    });
  }
  console.log(`✅ Datos salariales actualizados — ${Object.keys(DATOS_NOMINA).length} empleados`);
}

async function seedFichajes() {
  console.log('\n📋 Creando fichajes de octubre 2026...');
  const ref = eRef().collection('fichajes');
  for (let i = 0; i < FICHAJES.length; i += 450) {
    const chunk = FICHAJES.slice(i, i + 450);
    const b = db.batch();
    chunk.forEach(f => b.set(ref.doc(f.id), f));
    await b.commit();
  }
  const correcciones = FICHAJES.filter(f => f.es_correccion).length;
  console.log(`✅ ${FICHAJES.length} fichajes (incluye ${correcciones} corrección)`);
}

async function seedTareas() {
  console.log('\n✅ Creando tareas...');
  const ref = eRef().collection('tareas');
  const b = db.batch();
  TAREAS.forEach(t => b.set(ref.doc(t.id), { ...t, empresa_id: EMPRESA_ID, fecha_creacion: ts(hoy) }));
  await b.commit();
  console.log(`✅ ${TAREAS.length} tareas creadas`);
}

async function seedNotificaciones() {
  console.log('\n🔔 Creando notificaciones...');
  const ref = db.collection('notificaciones').doc(EMPRESA_ID).collection('items');
  const b = db.batch();
  NOTIFICACIONES.forEach(n => b.set(ref.doc(), n));
  await b.commit();
  console.log(`✅ ${NOTIFICACIONES.length} notificaciones`);
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log('\n🚑 SEED DATOS COMPLETOS — SANIR CLM');
  console.log(`📦 Empresa : ${EMPRESA_ID}`);
  try {
    await seedEmpresa();
    await limpiar();
    await seedClientes();
    await seedFacturas();
    await seedFacturasRecibidas();
    await seedPresupuestos();
    await seedNominas();
    await actualizarDatosNomina();
    await seedFichajes();
    await seedTareas();
    await seedNotificaciones();

    console.log('\n✅ ¡Datos completos cargados!\n');
    console.log('📊 Resumen:');
    console.log(`   • Clientes: ${CLIENTES.length} + Proveedores: ${PROVEEDORES.length}`);
    console.log(`   • Facturas emitidas: ${FACTURAS.length} (jul-oct 2026)`);
    console.log(`   • Facturas recibidas: ${FACTURAS_RECIBIDAS.length}`);
    console.log(`   • Presupuestos: ${PRESUPUESTOS.length} (aceptado, enviado, rechazado)`);
    console.log(`   • Nóminas: ${NOMINAS.length} (5 empleados × 4 meses)`);
    console.log(`   • Fichajes: ${FICHAJES.length} jornadas octubre 2026 (5 empleados)`);
    console.log(`   • Tareas: ${TAREAS.length}`);
    console.log(`   • Notificaciones: ${NOTIFICACIONES.length} (una por tipo)`);
    console.log('\n💡 Ejecuta también seed_demo_ambulancias.js si no lo has hecho ya.\n');
  } catch (e) {
    console.error('\n❌ Error:', e.message || e);
    process.exit(1);
  }
  process.exit(0);
}

main();
