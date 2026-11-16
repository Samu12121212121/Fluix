#!/usr/bin/env node
/**
 * sembrar_sanir_datos_prueba.js
 * ─────────────────────────────────────────────────────────────────
 * Rellena la empresa demo_sanir_clm_2026 (Sanir Transporte Sanitario CLM)
 * con todos los datos de prueba que necesita para demostrar la app.
 *
 * Añade / completa:
 *   • Empresa doc: perfil, suscripcion, configuracion, estadisticas, regimen_fiscal
 *   • fiscal_config subcollección
 *   • Clientes adicionales (hospitales, mutuas, residencias, ayuntamientos)
 *   • Servicios / productos del catálogo (TSU, TSNU, TSP, etc.)
 *   • Facturas emitidas adicionales (oct–nov 2026)
 *   • Facturas recibidas adicionales (proveedores combustible, material, etc.)
 *   • Albaranes recibidos
 *   • Pedidos de compra
 *   • Reservas de transporte programado
 *   • Tareas (mantenimiento, ITV, contratos, formación)
 *
 * USO:
 *   node scripts/sembrar_sanir_datos_prueba.js
 *
 * Requisitos:
 *   - credentials.json en la raíz del proyecto
 *   - firebase-admin en functions/node_modules
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');

const SA_PATH  = path.join(__dirname, '..', 'credentials.json');
const EID      = 'demo_sanir_clm_2026';
const NOW      = new Date();

let sa;
try { sa = require(SA_PATH); }
catch (e) { console.error('❌ No se encontró credentials.json'); process.exit(1); }

try { admin.initializeApp({ credential: admin.credential.cert(sa) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db  = admin.firestore();
const TS  = admin.firestore.Timestamp;
const FV  = admin.firestore.FieldValue;

// ── Helpers ────────────────────────────────────────────────────────────────────

function ts(year, month, day, hour = 8, min = 0) {
  return TS.fromDate(new Date(year, month - 1, day, hour, min, 0));
}

function daysFromNow(days) {
  const d = new Date(NOW);
  d.setDate(d.getDate() + days);
  d.setHours(9, 0, 0, 0);
  return TS.fromDate(d);
}

let _batchOps = 0;
let _currentBatch = null;

function getBatch() {
  if (!_currentBatch) _currentBatch = db.batch();
  return _currentBatch;
}

async function flushBatch() {
  if (_currentBatch && _batchOps > 0) {
    await _currentBatch.commit();
    _batchOps = 0;
    _currentBatch = null;
  }
}

function batchSet(ref, data) {
  if (_batchOps >= 450) {
    // Auto-flush on next tick is not possible, caller must flushBatch()
    // We rely on callers flushing between sections
  }
  getBatch().set(ref, data, { merge: true });
  _batchOps++;
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. EMPRESA DOC — completar campos estructurados
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarEmpresaDoc() {
  console.log('\n📋 1. Completando doc de empresa...');
  const ref = db.collection('empresas').doc(EID);
  batchSet(ref, {
    perfil: {
      nombre: 'Sanir Transporte Sanitario CLM',
      correo: 'info@sanirtransporte.es',
      telefono: '+34 925 220 100',
      direccion: 'Polígono Industrial, C/ Industria 1',
      descripcion: 'Empresa de transporte sanitario urgente y no urgente en Castilla-La Mancha',
      logo_url: null,
      fecha_creacion: ts(2018, 3, 15),
      ciudad: 'Toledo',
      codigo_postal: '45001',
      provincia: 'Toledo',
      pais: 'ES',
      web: 'https://www.sanirtransporte.es',
    },
    suscripcion: {
      fecha_inicio: ts(2026, 1, 1),
      fecha_fin: ts(2027, 1, 1),
      aviso_enviado: false,
      monto: 199.0,
      transaccion_id: 'txn_sanir_2026',
      estado: 'activa',
    },
    configuracion: {
      modulos_activos: {
        clientes: true,
        facturacion: true,
        empleados: true,
        nominas: true,
        fichajes: true,
        tareas: true,
        reservas: false,
        tpv: false,
        fiscal: true,
        pedidos: true,
      },
      configuracion_modulos: {},
      criterio_iva: 'devengo',
    },
    estadisticas: {
      total_clientes: 12,
      total_reservas: 8,
      total_servicios: 5,
      ingresos_mes: 68500,
      ingresos_anio: 712000,
      valoracion_promedio: 4.7,
      total_valoraciones: 23,
      fecha_actualizacion: TS.fromDate(NOW),
    },
    regimen_fiscal: {
      tipo: 'general',
      periodicidad_iva: 'trimestral',
      obligado_sii: false,
      obligado_verifactu: false,
      es_nueva_creacion: false,
      codigos_cnae: ['8621'],
    },
    nif: 'B45000001',
    legal_name: 'Sanir Transporte Sanitario CLM S.L.',
    tax_id: 'B45000001',
    sector: 'ambulancia',
    cnae: '8621',
    actividad: 'Actividades de ambulancias',
    tipo_tpv: 'bar',
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
  });
  await flushBatch();
  console.log('   ✅ Empresa doc actualizado');
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. CONFIGURACIÓN FISCAL
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFiscalConfig() {
  console.log('\n🏛️  2. Configuración fiscal...');
  const ref = db.collection('empresas').doc(EID).collection('configuracion').doc('fiscal');
  batchSet(ref, {
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
    es_demo: true,
  });
  await flushBatch();
  console.log('   ✅ Fiscal config creada');
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. CLIENTES ADICIONALES
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarClientes() {
  console.log('\n👥 3. Clientes adicionales...');
  const col = db.collection('empresas').doc(EID).collection('clientes');

  const clientes = [
    {
      id: 'sanir_cl_001',
      nombre: 'Hospital General de Albacete',
      correo: 'compras@hgalbacete.jccm.es',
      telefono: '+34 967 597 100',
      nif: 'Q0200051D',
      direccion: 'C/ Hermanos Falcó 37, 02006 Albacete',
      localidad: 'Albacete',
      etiquetas: ['hospital', 'contrato_marco', 'sescam'],
      total_gastado: 345000,
      numero_reservas: 0,
      ultima_visita: ts(2026, 10, 28),
      estado: 'activo',
    },
    {
      id: 'sanir_cl_002',
      nombre: 'Residencia Mayores Virgen del Valle',
      correo: 'administracion@rv-valle.es',
      telefono: '+34 925 265 180',
      nif: 'G45118430',
      direccion: 'C/ Recogidas 12, 45004 Toledo',
      localidad: 'Toledo',
      etiquetas: ['residencia', 'tsnu', 'recurrente'],
      total_gastado: 48200,
      numero_reservas: 24,
      ultima_visita: ts(2026, 11, 5),
      estado: 'activo',
    },
    {
      id: 'sanir_cl_003',
      nombre: 'Fraternidad Muprespa',
      correo: 'prestaciones@fraternidad.es',
      telefono: '+34 902 110 212',
      nif: 'G28029005',
      direccion: 'C/ Hernández Pacheco 5, 28002 Madrid',
      localidad: 'Madrid',
      etiquetas: ['mutua', 'accidentes_laborales'],
      total_gastado: 22600,
      numero_reservas: 0,
      ultima_visita: ts(2026, 10, 15),
      estado: 'activo',
    },
    {
      id: 'sanir_cl_004',
      nombre: 'Ayuntamiento de Ciudad Real',
      correo: 'contratacion@ciudadreal.es',
      telefono: '+34 926 229 000',
      nif: 'P1300100J',
      direccion: 'Plaza Mayor 1, 13001 Ciudad Real',
      localidad: 'Ciudad Real',
      etiquetas: ['administracion_publica', 'eventos'],
      total_gastado: 15800,
      numero_reservas: 0,
      ultima_visita: ts(2026, 9, 20),
      estado: 'activo',
    },
    {
      id: 'sanir_cl_005',
      nombre: 'Cruz Roja — Comité Provincial Toledo',
      correo: 'toledo@cruzroja.es',
      telefono: '+34 925 225 519',
      nif: 'Q2866001H',
      direccion: 'C/ Plata 20, 45001 Toledo',
      localidad: 'Toledo',
      etiquetas: ['ong', 'colaboracion', 'subcontrata'],
      total_gastado: 9400,
      numero_reservas: 0,
      ultima_visita: ts(2026, 10, 3),
      estado: 'activo',
    },
    {
      id: 'sanir_cl_006',
      nombre: 'Clínica Nuestra Señora del Prado',
      correo: 'clinica@nsprado.es',
      telefono: '+34 925 599 300',
      nif: 'B45096801',
      direccion: 'Ctra. Madrid s/n, 45600 Talavera de la Reina',
      localidad: 'Talavera de la Reina',
      etiquetas: ['clinica', 'privada', 'tsnu'],
      total_gastado: 31500,
      numero_reservas: 18,
      ultima_visita: ts(2026, 11, 4),
      estado: 'activo',
    },
  ];

  for (const cl of clientes) {
    const { id, ...data } = cl;
    batchSet(col.doc(id), {
      ...data,
      activo: true,
      fecha_registro: ts(2024, 1, 10),
      ultima_actividad: cl.ultima_visita,
      estado_cliente: cl.estado,
      ficha_incompleta: false,
      no_contactar: false,
      estado_fusionado: false,
      fusionado_con_id: null,
      telefono_norm: cl.telefono,
      origen: 'manual',
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${clientes.length} clientes añadidos`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. SERVICIOS / CATÁLOGO
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarServicios() {
  console.log('\n🚑 4. Servicios del catálogo...');
  const col = db.collection('empresas').doc(EID).collection('servicios');

  const servicios = [
    {
      id: 'serv_tsu',
      nombre: 'Transporte Sanitario Urgente (TSU)',
      descripcion: 'Traslado urgente en ambulancia medicalizada con médico/enfermero a bordo. Zona Castilla-La Mancha.',
      precio: 420.0,
      duracion_minutos: 90,
      categoria: 'transporte',
      iva: 0,
      activo: true,
      unidad: 'servicio',
      codigo: 'TSU-01',
    },
    {
      id: 'serv_tsnu',
      nombre: 'Transporte Sanitario No Urgente (TSNU)',
      descripcion: 'Traslado programado en ambulancia convencional para pacientes estables. Incluye grúa si necesario.',
      precio: 180.0,
      duracion_minutos: 60,
      categoria: 'transporte',
      iva: 0,
      activo: true,
      unidad: 'servicio',
      codigo: 'TSNU-01',
    },
    {
      id: 'serv_tsp',
      nombre: 'Transporte Sanitario Programado — Silla',
      descripcion: 'Traslado en vehículo adaptado para pacientes en silla de ruedas. Accesible para movilidad reducida.',
      precio: 95.0,
      duracion_minutos: 45,
      categoria: 'transporte',
      iva: 0,
      activo: true,
      unidad: 'servicio',
      codigo: 'TSP-01',
    },
    {
      id: 'serv_contrato_mensual',
      nombre: 'Contrato Marco Mensual — Zona Toledo',
      descripcion: 'Servicio de guardia 24h con ambulancia dedicada en la zona de Toledo capital. Facturación mensual.',
      precio: 22400.0,
      duracion_minutos: 0,
      categoria: 'contrato',
      iva: 0,
      activo: true,
      unidad: 'mes',
      codigo: 'CTR-MEN-TLO',
    },
    {
      id: 'serv_formacion',
      nombre: 'Formación SVB — Soporte Vital Básico',
      descripcion: 'Curso de SVB y DEA para personal no sanitario. Homologado Cruz Roja / SESCAM. Grupos de 10-20 personas.',
      precio: 1200.0,
      duracion_minutos: 480,
      categoria: 'formacion',
      iva: 21,
      activo: true,
      unidad: 'grupo',
      codigo: 'FOR-SVB',
    },
    {
      id: 'serv_cobertura_eventos',
      nombre: 'Cobertura Sanitaria Eventos',
      descripcion: 'Presencia de ambulancia + técnico en eventos deportivos, fiestas patronales o concentraciones.',
      precio: 650.0,
      duracion_minutos: 480,
      categoria: 'eventos',
      iva: 21,
      activo: true,
      unidad: 'jornada',
      codigo: 'EVT-COB',
    },
  ];

  for (const sv of servicios) {
    const { id, ...data } = sv;
    batchSet(col.doc(id), {
      ...data,
      empresa_id: EID,
      imagen_url: null,
      variantes: [],
      etiquetas: [],
      fecha_creacion: ts(2024, 1, 10),
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${servicios.length} servicios creados`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 5. FACTURAS EMITIDAS ADICIONALES (oct–nov 2026)
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFacturas() {
  console.log('\n🧾 5. Facturas emitidas adicionales...');
  const col = db.collection('empresas').doc(EID).collection('facturas');

  const facturas = [
    // ── Octubre 2026 ─────────────────────────────────────────────
    {
      id: 'fac_oct_001',
      numero_factura: 'F/2026/019',
      cliente_nombre: 'SESCAM — Servicio de Salud de CLM',
      nif_cliente: 'Q4500001H',
      concepto: 'Servicio transporte sanitario urgente — octubre 2026 (zona Toledo)',
      base: 22400, iva_pct: 0, estado: 'pagada',
      fecha: ts(2026, 10, 1), vencimiento: ts(2026, 11, 30),
    },
    {
      id: 'fac_oct_002',
      numero_factura: 'F/2026/020',
      cliente_nombre: 'Residencia Mayores Virgen del Valle',
      nif_cliente: 'G45118430',
      concepto: 'Traslados TSNU residentes — octubre 2026 (12 servicios)',
      base: 2160, iva_pct: 0, estado: 'pagada',
      fecha: ts(2026, 10, 31), vencimiento: ts(2026, 11, 15),
    },
    {
      id: 'fac_oct_003',
      numero_factura: 'F/2026/021',
      cliente_nombre: 'Hospital General de Albacete',
      nif_cliente: 'Q0200051D',
      concepto: 'Transporte urgente interhospitalario — 8 servicios octubre',
      base: 3360, iva_pct: 0, estado: 'pagada',
      fecha: ts(2026, 10, 31), vencimiento: ts(2026, 11, 30),
    },
    {
      id: 'fac_oct_004',
      numero_factura: 'F/2026/022',
      cliente_nombre: 'Fraternidad Muprespa',
      nif_cliente: 'G28029005',
      concepto: 'Traslado por accidente laboral — expediente MUP-26-04481',
      base: 540, iva_pct: 0, estado: 'pagada',
      fecha: ts(2026, 10, 14), vencimiento: ts(2026, 11, 14),
    },
    {
      id: 'fac_oct_005',
      numero_factura: 'F/2026/023',
      cliente_nombre: 'Clínica Nuestra Señora del Prado',
      nif_cliente: 'B45096801',
      concepto: 'Traslados TSNU — 2ª quincena octubre (9 servicios)',
      base: 1620, iva_pct: 0, estado: 'pendiente',
      fecha: ts(2026, 10, 31), vencimiento: ts(2026, 11, 30),
    },
    {
      id: 'fac_oct_006',
      numero_factura: 'F/2026/024',
      cliente_nombre: 'Ayuntamiento de Ciudad Real',
      nif_cliente: 'P1300100J',
      concepto: 'Cobertura sanitaria Feria Octubre 2026 — 3 jornadas',
      base: 1950, iva_pct: 21, estado: 'pagada',
      fecha: ts(2026, 10, 10), vencimiento: ts(2026, 10, 25),
    },
    // ── Noviembre 2026 ────────────────────────────────────────────
    {
      id: 'fac_nov_001',
      numero_factura: 'F/2026/025',
      cliente_nombre: 'SESCAM — Servicio de Salud de CLM',
      nif_cliente: 'Q4500001H',
      concepto: 'Servicio transporte sanitario urgente — noviembre 2026 (zona Toledo)',
      base: 22400, iva_pct: 0, estado: 'emitida',
      fecha: ts(2026, 11, 1), vencimiento: ts(2026, 12, 31),
    },
    {
      id: 'fac_nov_002',
      numero_factura: 'F/2026/026',
      cliente_nombre: 'Residencia Mayores Virgen del Valle',
      nif_cliente: 'G45118430',
      concepto: 'Traslados TSNU residentes — noviembre 2026 (1ª quincena, 7 servicios)',
      base: 1260, iva_pct: 0, estado: 'emitida',
      fecha: ts(2026, 11, 15), vencimiento: ts(2026, 11, 30),
    },
    {
      id: 'fac_nov_003',
      numero_factura: 'F/2026/027',
      cliente_nombre: 'Cruz Roja — Comité Provincial Toledo',
      nif_cliente: 'Q2866001H',
      concepto: 'Curso Soporte Vital Básico — 15 asistentes — 8 nov 2026',
      base: 1200, iva_pct: 21, estado: 'emitida',
      fecha: ts(2026, 11, 8), vencimiento: ts(2026, 11, 23),
    },
    {
      id: 'fac_nov_004',
      numero_factura: 'F/2026/028',
      cliente_nombre: 'Clínica Nuestra Señora del Prado',
      nif_cliente: 'B45096801',
      concepto: 'Traslados TSNU — 1ª quincena noviembre (6 servicios)',
      base: 1080, iva_pct: 0, estado: 'emitida',
      fecha: ts(2026, 11, 15), vencimiento: ts(2026, 11, 30),
    },
    // ── Rectificativas ────────────────────────────────────────────
    {
      id: 'fac_rec_001',
      numero_factura: 'R/2026/001',
      cliente_nombre: 'Hospital Virgen de la Salud Toledo',
      nif_cliente: 'Q4500001H',
      concepto: 'Rectificativa fac_006 — corrección precio km desplazamiento',
      base: -180, iva_pct: 0, estado: 'pagada',
      fecha: ts(2026, 9, 10), vencimiento: ts(2026, 9, 10),
    },
  ];

  for (const f of facturas) {
    const ivaImporte = f.base * (f.iva_pct / 100);
    batchSet(col.doc(f.id), {
      id: f.id,
      empresa_id: EID,
      numero_factura: f.numero_factura,
      serie: f.numero_factura.startsWith('R') ? 'R' : 'F',
      tipo: 'servicio',
      estado: f.estado,
      cliente_nombre: f.cliente_nombre,
      datos_fiscales: { nif: f.nif_cliente, razon_social: f.cliente_nombre, pais: 'España' },
      lineas: [{
        descripcion: f.concepto,
        precio_unitario: Math.abs(f.base),
        cantidad: f.base < 0 ? -1 : 1,
        porcentaje_iva: f.iva_pct,
        subtotal_sin_iva: f.base,
      }],
      subtotal: f.base,
      total_iva: parseFloat(ivaImporte.toFixed(2)),
      total: parseFloat((f.base + ivaImporte).toFixed(2)),
      descuento_global: 0,
      importe_descuento_global: 0,
      porcentaje_irpf: 0,
      retencion_irpf: 0,
      total_recargo_equivalencia: 0,
      dias_vencimiento: 30,
      notas_internas: f.iva_pct === 0 ? 'Exento IVA — Art. 20.1.3º LIVA' : '',
      notas_cliente: '',
      historial: [],
      fecha_emision: f.fecha,
      fecha_vencimiento: f.vencimiento,
      fecha_pago: f.estado === 'pagada' ? f.vencimiento : null,
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${facturas.length} facturas emitidas añadidas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 6. FACTURAS RECIBIDAS ADICIONALES
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFacturasRecibidas() {
  console.log('\n📥 6. Facturas recibidas adicionales...');
  const col = db.collection('empresas').doc(EID).collection('facturas_recibidas');

  const facturas = [
    // ── Octubre 2026 ─────────────────────────────────────────────
    {
      id: 'frec_oct_001',
      numero: 'REP-2026-10921', proveedor: 'Repsol YPF S.A.',
      nif: 'A78374725', concepto: 'Combustible flota ambulancias — octubre 2026',
      base: 10200, iva_pct: 21, estado: 'pagada', categoria: 'operativo',
      fecha: ts(2026, 10, 1), vencimiento: ts(2026, 10, 31),
    },
    {
      id: 'frec_oct_002',
      numero: 'B-26-004192', proveedor: 'B.Braun Medical S.A.',
      nif: 'A28038733', concepto: 'Material médico consumible — botiquines ambulancias',
      base: 2840, iva_pct: 10, estado: 'pagada', categoria: 'material_sanitario',
      fecha: ts(2026, 10, 7), vencimiento: ts(2026, 11, 7),
    },
    {
      id: 'frec_oct_003',
      numero: 'TLF-26-10-4455', proveedor: 'Telefónica España S.A.U.',
      nif: 'A28015865', concepto: 'Líneas móviles flota + GPS despacho — octubre 2026',
      base: 740, iva_pct: 21, estado: 'pagada', categoria: 'comunicaciones',
      fecha: ts(2026, 10, 5), vencimiento: ts(2026, 10, 20),
    },
    {
      id: 'frec_oct_004',
      numero: 'MOTO-2026-00341', proveedor: 'Talleres Automoción García S.L.',
      nif: 'B45092140', concepto: 'Revisión 100.000 km + frenos — Ambulancia MA-5582-CLM',
      base: 1850, iva_pct: 21, estado: 'pagada', categoria: 'mantenimiento',
      fecha: ts(2026, 10, 12), vencimiento: ts(2026, 10, 27),
    },
    {
      id: 'frec_oct_005',
      numero: 'ALD-TLO-26-0812', proveedor: 'ALD Automotive S.L.',
      nif: 'A28748015', concepto: 'Renting vehículo de apoyo — Furgoneta Ford Transit oct 2026',
      base: 980, iva_pct: 21, estado: 'pagada', categoria: 'vehiculos',
      fecha: ts(2026, 10, 1), vencimiento: ts(2026, 10, 31),
    },
    // ── Noviembre 2026 ────────────────────────────────────────────
    {
      id: 'frec_nov_001',
      numero: 'REP-2026-11108', proveedor: 'Repsol YPF S.A.',
      nif: 'A78374725', concepto: 'Combustible flota ambulancias — noviembre 2026',
      base: 9840, iva_pct: 21, estado: 'recibida', categoria: 'operativo',
      fecha: ts(2026, 11, 1), vencimiento: ts(2026, 11, 30),
    },
    {
      id: 'frec_nov_002',
      numero: 'PHT-26-5891', proveedor: 'Physio-Control España S.L.',
      nif: 'B28951204', concepto: 'Mantenimiento desfibriladores LIFEPAK — 4 unidades',
      base: 1560, iva_pct: 21, estado: 'recibida', categoria: 'material_sanitario',
      fecha: ts(2026, 11, 3), vencimiento: ts(2026, 12, 3),
    },
    {
      id: 'frec_nov_003',
      numero: 'INS-26-CLM-0048', proveedor: 'Mapfre Vida S.A.',
      nif: 'A28017522', concepto: 'Seguro flota 5 ambulancias — prima trimestral oct-dic 2026',
      base: 4200, iva_pct: 0, estado: 'pagada', categoria: 'seguros',
      fecha: ts(2026, 10, 1), vencimiento: ts(2026, 10, 15),
    },
    {
      id: 'frec_nov_004',
      numero: 'TLF-26-11-4612', proveedor: 'Telefónica España S.A.U.',
      nif: 'A28015865', concepto: 'Líneas móviles flota + GPS despacho — noviembre 2026',
      base: 740, iva_pct: 21, estado: 'pendiente', categoria: 'comunicaciones',
      fecha: ts(2026, 11, 5), vencimiento: ts(2026, 11, 20),
    },
    {
      id: 'frec_nov_005',
      numero: 'ALD-TLO-26-0901', proveedor: 'ALD Automotive S.L.',
      nif: 'A28748015', concepto: 'Renting vehículo de apoyo — Furgoneta Ford Transit nov 2026',
      base: 980, iva_pct: 21, estado: 'pendiente', categoria: 'vehiculos',
      fecha: ts(2026, 11, 1), vencimiento: ts(2026, 11, 30),
    },
  ];

  for (const f of facturas) {
    const ivaImporte = parseFloat((f.base * f.iva_pct / 100).toFixed(2));
    batchSet(col.doc(f.id), {
      id: f.id,
      empresa_id: EID,
      numero_factura: f.numero,
      nombre_proveedor: f.proveedor,
      nif_proveedor: f.nif,
      direccion_proveedor: null,
      es_intracomunitario: false,
      concepto: f.concepto,
      base_imponible: f.base,
      porcentaje_iva: f.iva_pct,
      importe_iva: ivaImporte,
      importe_no_sujeto: 0,
      iva_deducible: true,
      descuento_global: 0,
      recargo_equivalencia: 0,
      total_con_impuestos: parseFloat((f.base + ivaImporte).toFixed(2)),
      porcentaje_retencion: 0,
      importe_retencion: 0,
      estado: f.estado,
      fecha_emision: f.fecha,
      fecha_recepcion: f.fecha,
      fecha_vencimiento: f.vencimiento,
      fecha_pago: f.estado === 'pagada' ? f.vencimiento : null,
      categoria_gasto: f.categoria,
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${facturas.length} facturas recibidas añadidas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 7. ALBARANES RECIBIDOS
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarAlbaranes() {
  console.log('\n📦 7. Albaranes recibidos...');
  const col = db.collection('empresas').doc(EID).collection('albaranes_recibidos');

  const albaranes = [
    {
      id: 'alb_001',
      numero: 'AL-BB-26-09821',
      proveedor: 'B.Braun Medical S.A.',
      nif_proveedor: 'A28038733',
      concepto: 'Suministro material médico — set vías iv, gasas, apósitos estériles',
      lineas: [
        { descripcion: 'Set vías intravenosas 18G (caja 100 uds)', cantidad: 5, precio_unitario: 48.5 },
        { descripcion: 'Gasas estériles 10x10 (caja 100 uds)', cantidad: 10, precio_unitario: 12.0 },
        { descripcion: 'Apósitos estériles surtido (caja 50 uds)', cantidad: 8, precio_unitario: 22.0 },
      ],
      total: 537.5,
      estado: 'recibido',
      fecha: ts(2026, 10, 7),
    },
    {
      id: 'alb_002',
      numero: 'AL-REP-26-50912',
      proveedor: 'Repsol YPF S.A.',
      nif_proveedor: 'A78374725',
      concepto: 'Tarjetas combustible recarga — flota 5 ambulancias oct 2026',
      lineas: [
        { descripcion: 'Recarga tarjeta combustible VE-2234-CLM', cantidad: 1, precio_unitario: 2160 },
        { descripcion: 'Recarga tarjeta combustible MA-5582-CLM', cantidad: 1, precio_unitario: 2040 },
        { descripcion: 'Recarga tarjeta combustible TO-7891-CLM', cantidad: 1, precio_unitario: 1980 },
        { descripcion: 'Recarga tarjeta combustible AB-3341-CLM', cantidad: 1, precio_unitario: 2100 },
        { descripcion: 'Recarga tarjeta combustible CR-6612-CLM', cantidad: 1, precio_unitario: 1920 },
      ],
      total: 10200,
      estado: 'recibido',
      fecha: ts(2026, 10, 1),
    },
    {
      id: 'alb_003',
      numero: 'AL-UNI-26-01112',
      proveedor: 'Uniformes Sanitarios Peninsular S.L.',
      nif_proveedor: 'B46290140',
      concepto: 'Uniformes personal técnico — pedido anual invierno 2026',
      lineas: [
        { descripcion: 'Pantalón verde quirúrgico talla M (uds)', cantidad: 12, precio_unitario: 24.0 },
        { descripcion: 'Chaqueta polar fleece SANITARIO talla L (uds)', cantidad: 8, precio_unitario: 42.0 },
        { descripcion: 'Calzado de seguridad sanitario par talla 42', cantidad: 6, precio_unitario: 68.0 },
      ],
      total: 1200,
      estado: 'recibido',
      fecha: ts(2026, 10, 20),
    },
    {
      id: 'alb_004',
      numero: 'AL-PHY-26-5201',
      proveedor: 'Physio-Control España S.L.',
      nif_proveedor: 'B28951204',
      concepto: 'Electrodos y consumibles DEA LIFEPAK CR2 — reposición Q4',
      lineas: [
        { descripcion: 'Electrodos adhesivos LIFEPAK (pack 10 pares)', cantidad: 8, precio_unitario: 48.0 },
        { descripcion: 'Batería LIFEPAK CR2 (ud)', cantidad: 2, precio_unitario: 110.0 },
      ],
      total: 604,
      estado: 'pendiente_revision',
      fecha: ts(2026, 11, 3),
    },
    {
      id: 'alb_005',
      numero: 'AL-TAL-26-00351',
      proveedor: 'Talleres Automoción García S.L.',
      nif_proveedor: 'B45092140',
      concepto: 'Repuestos revisión — pastillas freno + filtros VE-2234-CLM',
      lineas: [
        { descripcion: 'Pastillas freno delanteras Bosch (juego)', cantidad: 1, precio_unitario: 68.0 },
        { descripcion: 'Pastillas freno traseras Bosch (juego)', cantidad: 1, precio_unitario: 54.0 },
        { descripcion: 'Filtro aceite (ud)', cantidad: 1, precio_unitario: 18.0 },
        { descripcion: 'Filtro aire (ud)', cantidad: 1, precio_unitario: 22.0 },
        { descripcion: 'Aceite 5W30 (bidón 5L)', cantidad: 2, precio_unitario: 42.0 },
      ],
      total: 246,
      estado: 'recibido',
      fecha: ts(2026, 10, 12),
    },
  ];

  for (const alb of albaranes) {
    const { id, ...data } = alb;
    batchSet(col.doc(id), {
      ...data,
      empresa_id: EID,
      factura_recibida_id: null,
      fecha_creacion: data.fecha,
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${albaranes.length} albaranes recibidos añadidos`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 8. PEDIDOS DE COMPRA
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarPedidos() {
  console.log('\n🛒 8. Pedidos de compra...');
  const col = db.collection('empresas').doc(EID).collection('pedidos');

  const pedidos = [
    {
      id: 'ped_001',
      numero: 'PED-2026-0041',
      proveedor: 'B.Braun Medical S.A.',
      nif_proveedor: 'A28038733',
      concepto: 'Reposición material médico Q4 2026',
      lineas: [
        { descripcion: 'Set vías intravenosas 18G (caja 100 uds)', cantidad: 10, precio: 48.5 },
        { descripcion: 'Máscaras oxígeno adulto no recirculación', cantidad: 50, precio: 2.8 },
        { descripcion: 'Collarines cervicales surtido (juego)', cantidad: 5, precio: 38.0 },
      ],
      total: 775,
      estado: 'enviado',
      fecha_pedido: ts(2026, 10, 25),
      fecha_entrega_estimada: ts(2026, 11, 8),
    },
    {
      id: 'ped_002',
      numero: 'PED-2026-0042',
      proveedor: 'Physio-Control España S.L.',
      nif_proveedor: 'B28951204',
      concepto: 'Ampliación kit DEA — 2 nuevas unidades',
      lineas: [
        { descripcion: 'Desfibrilador LIFEPAK CR2 completo (ud)', cantidad: 2, precio: 1680.0 },
        { descripcion: 'Maletín transporte DEA acolchado (ud)', cantidad: 2, precio: 85.0 },
      ],
      total: 3530,
      estado: 'pendiente',
      fecha_pedido: ts(2026, 11, 4),
      fecha_entrega_estimada: ts(2026, 11, 20),
    },
    {
      id: 'ped_003',
      numero: 'PED-2026-0043',
      proveedor: 'Uniformes Sanitarios Peninsular S.L.',
      nif_proveedor: 'B46290140',
      concepto: 'Ropa de verano 2027 — pedido anticipado',
      lineas: [
        { descripcion: 'Polo manga corta SANITARIO (12 uds talla M)', cantidad: 12, precio: 18.0 },
        { descripcion: 'Pantalón cargo sanitario verano (10 uds)', cantidad: 10, precio: 28.0 },
      ],
      total: 496,
      estado: 'borrador',
      fecha_pedido: ts(2026, 11, 6),
      fecha_entrega_estimada: ts(2027, 1, 15),
    },
    {
      id: 'ped_004',
      numero: 'PED-2026-0040',
      proveedor: 'Talleres Automoción García S.L.',
      nif_proveedor: 'B45092140',
      concepto: 'Cambio neumáticos invierno flota ambulancias',
      lineas: [
        { descripcion: 'Neumático invierno 215/65R16C (ud)', cantidad: 20, precio: 92.0 },
        { descripcion: 'Montaje + equilibrado por neumático', cantidad: 20, precio: 12.0 },
      ],
      total: 2080,
      estado: 'recibido',
      fecha_pedido: ts(2026, 10, 18),
      fecha_entrega_estimada: ts(2026, 10, 28),
    },
  ];

  for (const ped of pedidos) {
    const { id, ...data } = ped;
    batchSet(col.doc(id), {
      ...data,
      empresa_id: EID,
      albaranes_vinculados: [],
      notas: '',
      fecha_creacion: data.fecha_pedido,
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${pedidos.length} pedidos añadidos`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 9. RESERVAS DE TRANSPORTE PROGRAMADO
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarReservas() {
  console.log('\n📅 9. Reservas de transporte...');
  const col = db.collection('empresas').doc(EID).collection('reservas');

  const reservas = [
    {
      id: 'rsv_001',
      cliente: 'Residencia Mayores Virgen del Valle',
      servicio: 'TSNU — Traslado a consulta',
      origen: 'Residencia Virgen del Valle, C/ Recogidas 12, Toledo',
      destino: 'Hospital Virgen de la Salud, Avda. de Barber s/n, Toledo',
      paciente: 'D. Antonio Moreno García',
      ambulancia: 'VE-2234-CLM',
      conductor: 'Javier Torres Pérez',
      tecnico: 'Elena Martín Sanz',
      estado: 'confirmada',
      fecha: ts(2026, 11, 10, 9, 30),
      duracion: 60,
    },
    {
      id: 'rsv_002',
      cliente: 'Clínica Nuestra Señora del Prado',
      servicio: 'TSNU — Alta hospitalaria',
      origen: 'Clínica NSP, Ctra. Madrid s/n, Talavera de la Reina',
      destino: 'C/ Cazalegas 4, 45600 Talavera de la Reina',
      paciente: 'Dña. Carmen Rodríguez Pinto',
      ambulancia: 'MA-5582-CLM',
      conductor: 'Roberto López Vega',
      tecnico: 'Carmen Ruiz Molina',
      estado: 'confirmada',
      fecha: ts(2026, 11, 10, 11, 0),
      duracion: 45,
    },
    {
      id: 'rsv_003',
      cliente: 'Residencia Mayores Virgen del Valle',
      servicio: 'TSP — Silla — Traslado diálisis',
      origen: 'Residencia Virgen del Valle, C/ Recogidas 12, Toledo',
      destino: 'Clínica Averroes (diálisis), C/ Maqueda 8, Toledo',
      paciente: 'D. José Luis Pérez Cazorla',
      ambulancia: 'TO-7891-CLM',
      conductor: 'Laura González Díaz',
      tecnico: null,
      estado: 'confirmada',
      fecha: ts(2026, 11, 10, 7, 30),
      duracion: 30,
    },
    {
      id: 'rsv_004',
      cliente: 'Hospital General de Albacete',
      servicio: 'TSU — Traslado interhospitalario',
      origen: 'Hospital General Albacete, C/ Hermanos Falcó 37, Albacete',
      destino: 'Hospital 12 de Octubre, Avda. de Córdoba s/n, Madrid',
      paciente: 'Paciente código B-2026-1182 (confidencial)',
      ambulancia: 'AB-3341-CLM',
      conductor: 'Roberto López Vega',
      tecnico: 'Elena Martín Sanz',
      estado: 'pendiente',
      fecha: ts(2026, 11, 11, 8, 0),
      duracion: 150,
    },
    {
      id: 'rsv_005',
      cliente: 'Residencia Mayores Virgen del Valle',
      servicio: 'TSNU — Traslado a consulta',
      origen: 'Residencia Virgen del Valle, C/ Recogidas 12, Toledo',
      destino: 'Hospital Virgen de la Salud, Avda. de Barber s/n, Toledo',
      paciente: 'Dña. Pilar Martínez Soria',
      ambulancia: 'VE-2234-CLM',
      conductor: 'Javier Torres Pérez',
      tecnico: 'Carmen Ruiz Molina',
      estado: 'pendiente',
      fecha: ts(2026, 11, 12, 10, 0),
      duracion: 60,
    },
    {
      id: 'rsv_006',
      cliente: 'Clínica Nuestra Señora del Prado',
      servicio: 'TSNU — Traslado diagnóstico',
      origen: 'Clínica NSP, Ctra. Madrid s/n, Talavera de la Reina',
      destino: 'Clínica de RM San Pablo, C/ Los Ángeles 3, Toledo',
      paciente: 'D. Francisco Lara Medina',
      ambulancia: 'CR-6612-CLM',
      conductor: 'Laura González Díaz',
      tecnico: null,
      estado: 'cancelada',
      fecha: ts(2026, 11, 8, 14, 0),
      duracion: 90,
    },
    {
      id: 'rsv_007',
      cliente: 'Fraternidad Muprespa',
      servicio: 'TSU — Accidente laboral',
      origen: 'Polígono El Ruiseñor, Nave 14, Villacañas, Toledo',
      destino: 'Hospital Virgen de la Salud, Avda. de Barber s/n, Toledo',
      paciente: 'Accidentado expediente MUP-26-04812',
      ambulancia: 'MA-5582-CLM',
      conductor: 'Roberto López Vega',
      tecnico: 'Elena Martín Sanz',
      estado: 'realizada',
      fecha: ts(2026, 11, 5, 15, 30),
      duracion: 70,
    },
    {
      id: 'rsv_008',
      cliente: 'Ayuntamiento de Ciudad Real',
      servicio: 'Cobertura sanitaria evento',
      origen: 'Pabellón Polideportivo Sur, C/ Ronda Norte 4, Ciudad Real',
      destino: null,
      paciente: null,
      ambulancia: 'CR-6612-CLM',
      conductor: 'Laura González Díaz',
      tecnico: 'Carmen Ruiz Molina',
      estado: 'confirmada',
      fecha: ts(2026, 11, 15, 9, 0),
      duracion: 480,
    },
  ];

  for (const r of reservas) {
    const { id, ...data } = r;
    batchSet(col.doc(id), {
      ...data,
      empresa_id: EID,
      precio: 0,
      notas: '',
      fecha_creacion: TS.fromDate(NOW),
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${reservas.length} reservas añadidas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 10. TAREAS ADICIONALES
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarTareas() {
  console.log('\n📝 10. Tareas adicionales...');
  const col = db.collection('empresas').doc(EID).collection('tareas');

  const tareas = [
    {
      id: 'tarea_009',
      titulo: 'Renovar ITV — Ambulancia MA-5582-CLM',
      descripcion: 'ITV vence el 28 de noviembre. Estación Calidad Automoción Toledo. Cita pendiente.',
      prioridad: 'alta', estado: 'pendiente', modulo: 'vehiculos',
      vencimiento: daysFromNow(21),
    },
    {
      id: 'tarea_010',
      titulo: 'Solicitar presupuesto nueva ambulancia 2027',
      descripcion: 'Contactar con Mercedes-Benz Ambulancias y Volkswagen Crafter. Presupuesto antes del 15 dic para aprobar en comité.',
      prioridad: 'media', estado: 'pendiente', modulo: 'compras',
      vencimiento: daysFromNow(38),
    },
    {
      id: 'tarea_011',
      titulo: 'Renovar contrato SESCAM — zona Talavera 2027',
      descripcion: 'Pliego de condiciones publicado en DOCM. Fecha límite presentación oferta: 20 de diciembre.',
      prioridad: 'alta', estado: 'enProgreso', modulo: 'contratos',
      vencimiento: daysFromNow(43),
    },
    {
      id: 'tarea_012',
      titulo: 'Formación RCP actualización — 6 técnicos pendientes',
      descripcion: 'Elena, Roberto (x2), Carmen, Javier y Laura deben renovar certificación antes de fin de año. Contactar Cruz Roja.',
      prioridad: 'alta', estado: 'pendiente', modulo: 'rrhh',
      vencimiento: daysFromNow(55),
    },
    {
      id: 'tarea_013',
      titulo: 'Cambio neumáticos invierno — 5 ambulancias',
      descripcion: 'Pedido ya realizado (PED-2026-0040). Coordinar con taller para cita semana del 10-14 nov.',
      prioridad: 'media', estado: 'enProgreso', modulo: 'vehiculos',
      vencimiento: daysFromNow(7),
    },
    {
      id: 'tarea_014',
      titulo: 'Auditoría interna materiales sanitarios',
      descripcion: 'Revisión caducidades botiquines 5 ambulancias. Registrar en hoja control. Retirar vencidos.',
      prioridad: 'media', estado: 'pendiente', modulo: 'calidad',
      vencimiento: daysFromNow(14),
    },
    {
      id: 'tarea_015',
      titulo: 'Presentar liquidación IVA 3T 2026 (Mod. 303)',
      descripcion: 'Plazo hasta 20 de noviembre. Preparar datos con gestora Asesores Toledo S.L.',
      prioridad: 'alta', estado: 'completada', modulo: 'fiscal',
      vencimiento: ts(2026, 11, 20),
    },
    {
      id: 'tarea_016',
      titulo: 'Actualizar plan de emergencias internas',
      descripcion: 'Revisión anual obligatoria según ISO 9001:2015. Incluir nuevos protocolos COVID-19 actualización 2026.',
      prioridad: 'baja', estado: 'pendiente', modulo: 'calidad',
      vencimiento: daysFromNow(60),
    },
    {
      id: 'tarea_017',
      titulo: 'Reclamar factura impagada — Mutua Universal Mugenat',
      descripcion: 'Factura F/2026/016 (3.280 €) lleva 45 días de retraso. Enviar burofax si no se resuelve esta semana.',
      prioridad: 'alta', estado: 'enProgreso', modulo: 'facturacion',
      vencimiento: daysFromNow(5),
    },
    {
      id: 'tarea_018',
      titulo: 'Certificación ISO 9001 — renovación anual',
      descripcion: 'Auditoría externa AENOR programada para el 18 de diciembre. Preparar documentación con responsable calidad.',
      prioridad: 'alta', estado: 'pendiente', modulo: 'calidad',
      vencimiento: daysFromNow(41),
    },
  ];

  for (const t of tareas) {
    const { id, vencimiento, ...data } = t;
    batchSet(col.doc(id), {
      ...data,
      empresa_id: EID,
      descripcion: data.descripcion,
      asignado_a: null,
      etiquetas: [],
      fecha_creacion: TS.fromDate(NOW),
      fecha_vencimiento: vencimiento,
      es_demo: true,
    });
  }

  await flushBatch();
  console.log(`   ✅ ${tareas.length} tareas añadidas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 11. FICHAJES ADICIONALES (completar noviembre 2026)
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFichajes() {
  console.log('\n⏱️  11. Fichajes noviembre 2026...');
  const col = db.collection('empresas').doc(EID).collection('fichajes');

  // Empleados activos con sus IDs en Firestore
  const empleados = [
    { nombre: 'Elena Martín Sanz',   id: 'amb_emp_001', turno: 'manana' },
    { nombre: 'Roberto López Vega',  id: 'amb_emp_002', turno: 'tarde'  },
    { nombre: 'Carmen Ruiz Molina',  id: 'amb_emp_003', turno: 'noche'  },
    { nombre: 'Javier Torres Pérez', id: 'amb_emp_004', turno: 'manana' },
    { nombre: 'Laura González Díaz', id: 'amb_emp_005', turno: 'tarde'  },
  ];

  const turnos = {
    manana: { entrada: [6, 0],  salida: [14, 0],  pausa: [10, 0, 10, 30] },
    tarde:  { entrada: [14, 0], salida: [22, 0],  pausa: [18, 0, 18, 30] },
    noche:  { entrada: [22, 0], salida: [6, 0],   pausa: [2, 0, 2, 30]   },
  };

  const diasNov = [3, 4, 5, 6, 7]; // lunes a viernes primera semana nov
  let count = 0;
  const batch = db.batch();

  for (const emp of empleados) {
    for (const dia of diasNov) {
      const turno = turnos[emp.turno];
      const fechaStr = `2026-11-${String(dia).padStart(2, '0')}`;
      const entradaDate = new Date(2026, 10, dia, turno.entrada[0], turno.entrada[1], 0);
      let salidaDate;
      if (emp.turno === 'noche') {
        salidaDate = new Date(2026, 10, dia + 1, turno.salida[0], turno.salida[1], 0);
      } else {
        salidaDate = new Date(2026, 10, dia, turno.salida[0], turno.salida[1], 0);
      }
      const pausaInicio = new Date(2026, 10, dia, turno.pausa[0], turno.pausa[1], 0);
      const pausaFin    = new Date(2026, 10, dia, turno.pausa[2], turno.pausa[3], 0);

      const fichajeId = `fich_nov_${emp.id}_${dia}`;
      const ref = col.doc(fichajeId);
      batch.set(ref, {
        id: fichajeId,
        empresa_id: EID,
        empleado_id: emp.id,
        empleado_nombre: emp.nombre,
        fecha: fechaStr,
        fecha_ts: TS.fromDate(entradaDate),
        entrada: TS.fromDate(entradaDate),
        salida: TS.fromDate(salidaDate),
        pausas: [{
          inicio: TS.fromDate(pausaInicio),
          fin: TS.fromDate(pausaFin),
        }],
        es_correccion: false,
        correcto: true,
        minutos_pausa: 30,
        es_demo: true,
      }, { merge: false });
      count++;
    }
  }

  await batch.commit();
  console.log(`   ✅ ${count} fichajes noviembre añadidos`);
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

async function main() {
  console.log('\n🚑 SEMBRAR DATOS DE PRUEBA — Sanir Transporte Sanitario CLM');
  console.log(`   empresaId: ${EID}`);
  console.log('═'.repeat(60));

  await sembrarEmpresaDoc();
  await sembrarFiscalConfig();
  await sembrarClientes();
  await sembrarServicios();
  await sembrarFacturas();
  await sembrarFacturasRecibidas();
  await sembrarAlbaranes();
  await sembrarPedidos();
  await sembrarReservas();
  await sembrarTareas();
  await sembrarFichajes();

  console.log('\n' + '═'.repeat(60));
  console.log('✅ Todos los datos de prueba cargados en Sanir Transporters');
  console.log('\nResumen de datos ahora disponibles:');
  console.log('  • Empresa: perfil completo + fiscal + suscripción');
  console.log('  • Clientes: +6 (hospitales, residencias, mutuas, ayuntamientos)');
  console.log('  • Servicios: 6 (TSU, TSNU, TSP, contrato, formación, eventos)');
  console.log('  • Facturas emitidas: +11 (oct-nov 2026)');
  console.log('  • Facturas recibidas: +10 (combustible, material, seguros, etc.)');
  console.log('  • Albaranes recibidos: 5 (proveedores varios)');
  console.log('  • Pedidos compra: 4 (material, DEA, neumáticos, uniformes)');
  console.log('  • Reservas transporte: 8 (TSU, TSNU, TSP, cobertura evento)');
  console.log('  • Tareas: +10 (mantenimiento, contratos, fiscal, calidad)');
  console.log('  • Fichajes: +25 (nov 2026, 5 empleados × 5 días)\n');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    if (e.message?.includes('credentials') || e.message?.includes('UNAUTHENTICATED')) {
      console.error('   Verifica que credentials.json está en la raíz del proyecto');
    }
    process.exit(1);
  });
