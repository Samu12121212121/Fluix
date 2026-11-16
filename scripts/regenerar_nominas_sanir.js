#!/usr/bin/env node
/**
 * regenerar_nominas_sanir.js
 * ─────────────────────────────────────────────────────────────────
 * Regenera (o muestra una muestra de) las nóminas de Sanir CLM
 * usando las constantes SS/IRPF 2026 del NominasService Dart.
 *
 * SIN flags  → imprime UNA nómina de muestra (Elena, noviembre)
 * --todo     → borra las existentes y regenera jul–nov 2026
 *
 * USO:
 *   node scripts/regenerar_nominas_sanir.js
 *   node scripts/regenerar_nominas_sanir.js --todo
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');

const SA_PATH = path.join(__dirname, '..', 'credentials.json');
const EID     = 'demo_sanir_clm_2026';
const MODO_TODO = process.argv.includes('--todo');

try { admin.initializeApp({ credential: admin.credential.cert(require(SA_PATH)) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db = admin.firestore();
const TS = admin.firestore.Timestamp;
const FV = admin.firestore.FieldValue;

// ══════════════════════════════════════════════════════════════════════════════
// CONSTANTES SS 2026 — NominasService.dart
// ══════════════════════════════════════════════════════════════════════════════
const SS = {
  // Trabajador
  CC:         4.70,
  DESEMP:     1.55,  // indefinido
  DESEMP_T:   1.60,  // temporal
  FP:         0.10,
  MEI_TRA:    0.15,
  // Empresa
  EMP_CC:     23.60,
  EMP_DESEMP: 5.50,
  EMP_FOGASA: 0.20,
  EMP_FP:     0.60,
  EMP_AT:     1.75,  // CNAE 869 ambulancias (RDL 3/2026)
  EMP_MEI:    0.75,
  // Límites
  BASE_MIN:   1424.40,
  BASE_MAX:   5101.20,
};

// IRPF CLM 2026 — tarifa combinada (estatal + autonómica)
const TRAMOS_CLM = [
  [12450, 19.0], [20200, 24.0], [35200, 30.0],
  [60000, 37.0], [300000, 45.0], [Infinity, 47.0],
];

// Mínimos IRPF 2026
const MIN_PERSONAL = 5550;
const TAB_HIJOS    = [2400, 2700, 4000, 4500]; // hasta 4 hijos
const MIN_HIJO_3   = 2800; // hijo < 3 años
const SMI_ANUAL    = 17094; // RD 126/2026

// ── Helpers ───────────────────────────────────────────────────────────────────

function r2(n) { return Math.round(n * 100) / 100; }

function impuestoBruto(base, tramos) {
  if (base <= 0) return 0;
  let imp = 0, anterior = 0;
  for (const [lim, tipo] of tramos) {
    if (base <= anterior) break;
    const aplicable = Math.min(base, lim) - anterior;
    imp += aplicable * tipo / 100;
    anterior = lim;
    if (lim === Infinity) break;
  }
  return imp;
}

function reduccionRT(base) {
  if (base <= 14852)  return 2000 + 7302;
  if (base <= 19747)  return 2000 + Math.max(0, 7302 - 1.75 * (base - 14852));
  return 2000;
}

function minPersonalFamiliar(numHijos, numHijosMenores3) {
  let min = MIN_PERSONAL;
  for (let i = 0; i < numHijos; i++) {
    min += i < TAB_HIJOS.length ? TAB_HIJOS[i] : 4500;
  }
  min += numHijosMenores3 * MIN_HIJO_3;
  return min;
}

function calcularPctIrpf(brutoAnual, numHijos, numHijosMenores3) {
  if (brutoAnual <= 0) return 0;
  const redRT = reduccionRT(brutoAnual);
  const baseLiq = Math.max(0, brutoAnual - redRT);
  const minPF   = minPersonalFamiliar(numHijos, numHijosMenores3);
  const cuota   = Math.max(0, impuestoBruto(baseLiq, TRAMOS_CLM) - impuestoBruto(minPF, TRAMOS_CLM));
  let pct = cuota / brutoAnual * 100;
  if (brutoAnual > 14000 && pct < 2) pct = 2;
  return Math.min(55, Math.max(0, pct));
}

function tsMonthStart(year, month) { return TS.fromDate(new Date(year, month - 1, 1, 0, 0, 0)); }
function tsMonthEnd(year, month) {
  const last = new Date(year, month, 0, 23, 59, 59);
  return TS.fromDate(last);
}
function tsPagaDia(year, month, day) { return TS.fromDate(new Date(year, month - 1, day, 12, 0, 0)); }

// ── Función principal de cálculo de nómina ───────────────────────────────────

function calcNomina(emp, mes, anio) {
  const dn = emp.datos_nomina;
  const brutoAnual   = dn.salario_bruto_anual;
  const numPagas     = dn.num_pagas || 14;
  const prorrateado  = dn.pagas_prorrateadas === true;
  const horas        = dn.horas_semanales || 40;
  const coefParcial  = horas / 40;
  const brutoAjust   = brutoAnual * coefParcial;
  const tipoContrato = dn.tipo_contrato || 'indefinido';
  const esTemporal   = tipoContrato === 'temporal' || tipoContrato === 'practicas';
  const numHijos     = dn.num_hijos || 0;
  const numHijosMen3 = dn.num_hijos_menores_3 || 0;

  // Meses de paga extra: junio (6) y diciembre (12) para 14 pagas
  const esMesPagaExtra = !prorrateado && numPagas === 14 && (mes === 6 || mes === 12);

  const salarioBase = prorrateado ? brutoAjust / 12 : brutoAjust / numPagas;
  const pagaExtra   = esMesPagaExtra ? salarioBase : 0;
  const prorrata    = prorrateado && numPagas > 12 ? (brutoAjust / 12 - brutoAjust / numPagas) : 0;
  const totalDevengos = salarioBase + pagaExtra + prorrata;

  // Base cotización (grupo9 → base mínima es BASE_MIN)
  const baseCot = Math.max(SS.BASE_MIN, Math.min(SS.BASE_MAX, totalDevengos));

  // SS trabajador
  const ssCC     = r2(baseCot * SS.CC     / 100);
  const ssDesemp = r2(baseCot * (esTemporal ? SS.DESEMP_T : SS.DESEMP) / 100);
  const ssFP     = r2(baseCot * SS.FP     / 100);
  const ssMei    = r2(baseCot * SS.MEI_TRA / 100);
  const totalSSTra = r2(ssCC + ssDesemp + ssFP + ssMei);

  // IRPF — usar irpf_personalizado si existe, si no calcular
  const irpfPct  = dn.irpf_personalizado != null
    ? dn.irpf_personalizado
    : r2(calcularPctIrpf(brutoAnual, numHijos, numHijosMen3));
  const retIrpf  = r2(totalDevengos * irpfPct / 100);

  const totalDeducc = r2(totalSSTra + retIrpf);
  const salarioNeto = r2(totalDevengos - totalDeducc);

  // SS empresa
  const empCC     = r2(baseCot * SS.EMP_CC     / 100);
  const empDesemp = r2(baseCot * (esTemporal ? 6.70 : SS.EMP_DESEMP) / 100);
  const empFogasa = r2(baseCot * SS.EMP_FOGASA / 100);
  const empFP     = r2(baseCot * SS.EMP_FP     / 100);
  const empAT     = r2(baseCot * SS.EMP_AT     / 100);
  const empMei    = r2(baseCot * SS.EMP_MEI    / 100);
  const totalSSEmp = r2(empCC + empDesemp + empFogasa + empFP + empAT + empMei);
  const costeTotalEmpresa = r2(totalDevengos + totalSSEmp);

  const periodos = ['', 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

  const id = `${emp.id}_${anio}_${String(mes).padStart(2,'0')}`;

  return {
    id,
    empresa_id: EID,
    empleado_id: emp.id,
    empleado_nombre: emp.nombre,
    empleado_nif: dn.nif || '',
    empleado_nss: dn.nss || '',
    mes,
    anio,
    periodo: `${periodos[mes]} ${anio}`,
    periodo_desde: tsMonthStart(anio, mes),
    periodo_hasta: tsMonthEnd(anio, mes),
    fecha_emision: tsMonthEnd(anio, mes),
    fecha_pago: tsPagaDia(anio, mes, 28),

    // Devengos
    salario_bruto_mensual: r2(salarioBase),
    paga_extra: r2(pagaExtra),
    paga_extra_prorrateada: r2(prorrata),
    horas_extra: 0,
    precio_hora_extra: 0,
    importe_horas_extra: 0,
    complementos: 0,
    complementos_detallados: [],
    plus_antiguedad: 0,
    anios_antiguedad: 0,
    trienios_bienios: 0,
    retribuciones_especie: 0,
    total_devengos: r2(totalDevengos),
    lineas_devengos: [
      { concepto: 'Salario base', importe: r2(salarioBase), tipo: 'salario_base' },
      ...(pagaExtra > 0 ? [{ concepto: 'Paga extra', importe: r2(pagaExtra), tipo: 'paga_extra' }] : []),
      ...(prorrata > 0  ? [{ concepto: 'Prorrata pagas extra', importe: r2(prorrata), tipo: 'prorrata' }] : []),
    ],

    // Cotización SS
    base_cotizacion: r2(baseCot),
    ss_trabajador_cc:        ssCC,
    ss_trabajador_desempleo: ssDesemp,
    ss_trabajador_fp:        ssFP,
    ss_mei_trabajador:       ssMei,
    ss_solidaridad_trabajador: 0,
    ss_horas_extra_trabajador: 0,
    total_ss_trabajador: totalSSTra,

    // IRPF
    base_irpf: r2(totalDevengos),
    porcentaje_irpf: irpfPct,
    retencion_irpf: retIrpf,
    irpf_ajustado: false,
    regularizacion_irpf: 0,

    // IT / ausencias
    descuento_ausencias: 0,
    lineas_ausencias: [],
    dias_it: 0,
    importe_it: 0,
    importe_it_empresa: 0,
    importe_it_inss: 0,
    importe_it_mutua: 0,
    descuento_salario_por_it: 0,

    // Embargo
    embargo_judicial: 0,

    // Totales
    total_deducciones: totalDeducc,
    lineas_deducciones: [
      { concepto: 'Seg. Social (trabajador)', importe: totalSSTra, tipo: 'ss_trabajador',
        detalle: [
          { concepto: 'Contingencias comunes', importe: ssCC, tipo: 'ss_cc' },
          { concepto: 'Desempleo', importe: ssDesemp, tipo: 'ss_desempleo' },
          { concepto: 'Formación Profesional', importe: ssFP, tipo: 'ss_fp' },
          { concepto: 'MEI 2026', importe: ssMei, tipo: 'ss_mei' },
        ]
      },
      { concepto: `IRPF (${irpfPct.toFixed(1)}%)`, importe: retIrpf, tipo: 'irpf' },
    ],
    salario_neto: salarioNeto,
    liquido_final: salarioNeto,

    // Coste empresa
    ss_empresa_cc:       empCC,
    ss_empresa_desempleo: empDesemp,
    ss_empresa_fogasa:   empFogasa,
    ss_empresa_fp:       empFP,
    ss_empresa_at:       empAT,
    ss_mei_empresa:      empMei,
    ss_solidaridad_empresa: 0,
    ss_horas_extra_empresa: 0,
    total_ss_empresa:    totalSSEmp,
    coste_total_empresa: costeTotalEmpresa,

    tipo_hora_extra: 'noEstructural',
    base_acumulada_ytd: 0,
    irpf_acumulado_ytd: 0,
    notas: '',
    es_demo: true,
  };
}

// ── Formato humano para consola ───────────────────────────────────────────────

function imprimirNomina(n) {
  const sep = '─'.repeat(56);
  console.log(`\n${'═'.repeat(56)}`);
  console.log(`  NÓMINA — ${n.empleado_nombre}`);
  console.log(`  Período: ${n.periodo}  ·  ID: ${n.id}`);
  console.log(`${'═'.repeat(56)}`);
  console.log(`\n  DEVENGOS`);
  console.log(sep);
  n.lineas_devengos.forEach(l =>
    console.log(`  ${l.concepto.padEnd(36)} ${l.importe.toFixed(2).padStart(10)} €`));
  console.log(`${sep}`);
  console.log(`  ${'TOTAL DEVENGOS'.padEnd(36)} ${n.total_devengos.toFixed(2).padStart(10)} €`);

  console.log(`\n  BASE COTIZACIÓN SS                   ${n.base_cotizacion.toFixed(2).padStart(10)} €`);

  console.log(`\n  DEDUCCIONES`);
  console.log(sep);
  console.log(`  ${'Seg. Social trabajador'.padEnd(36)} ${n.total_ss_trabajador.toFixed(2).padStart(10)} €`);
  console.log(`    CC (${SS.CC}%)`.padEnd(38) + n.ss_trabajador_cc.toFixed(2).padStart(10) + ' €');
  console.log(`    Desempleo (${SS.DESEMP}%)`.padEnd(38) + n.ss_trabajador_desempleo.toFixed(2).padStart(10) + ' €');
  console.log(`    FP (${SS.FP}%)`.padEnd(38) + n.ss_trabajador_fp.toFixed(2).padStart(10) + ' €');
  console.log(`    MEI (${SS.MEI_TRA}%)`.padEnd(38) + n.ss_mei_trabajador.toFixed(2).padStart(10) + ' €');
  console.log(`  ${'IRPF (' + n.porcentaje_irpf.toFixed(1) + '%)'.padEnd(32)} ${n.retencion_irpf.toFixed(2).padStart(10)} €`);
  console.log(sep);
  console.log(`  ${'TOTAL DEDUCCIONES'.padEnd(36)} ${n.total_deducciones.toFixed(2).padStart(10)} €`);

  console.log(`\n${'═'.repeat(56)}`);
  console.log(`  ${'LÍQUIDO A PERCIBIR'.padEnd(36)} ${n.liquido_final.toFixed(2).padStart(10)} €`);
  console.log(`${'═'.repeat(56)}`);

  console.log(`\n  COSTE EMPRESA`);
  console.log(sep);
  console.log(`  CC empresa (${SS.EMP_CC}%)`.padEnd(38) + n.ss_empresa_cc.toFixed(2).padStart(10) + ' €');
  console.log(`  Desempleo empresa (${SS.EMP_DESEMP}%)`.padEnd(38) + n.ss_empresa_desempleo.toFixed(2).padStart(10) + ' €');
  console.log(`  FOGASA (${SS.EMP_FOGASA}%)`.padEnd(38) + n.ss_empresa_fogasa.toFixed(2).padStart(10) + ' €');
  console.log(`  FP empresa (${SS.EMP_FP}%)`.padEnd(38) + n.ss_empresa_fp.toFixed(2).padStart(10) + ' €');
  console.log(`  AT CNAE 869 (${SS.EMP_AT}%)`.padEnd(38) + n.ss_empresa_at.toFixed(2).padStart(10) + ' €');
  console.log(`  MEI empresa (${SS.EMP_MEI}%)`.padEnd(38) + n.ss_mei_empresa.toFixed(2).padStart(10) + ' €');
  console.log(sep);
  console.log(`  ${'Total SS empresa'.padEnd(36)} ${n.total_ss_empresa.toFixed(2).padStart(10)} €`);
  console.log(`  ${'COSTE TOTAL EMPRESA'.padEnd(36)} ${n.coste_total_empresa.toFixed(2).padStart(10)} €`);
  console.log();
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

async function main() {
  // Cargar empleados
  const usSnap = await db.collection('usuarios')
    .where('empresa_id', '==', EID)
    .where('activo', '==', true)
    .get();

  const empleados = usSnap.docs
    .filter(d => {
      const dn = d.data().datos_nomina;
      return dn && dn.salario_bruto_anual > 0 && d.data().nombre !== 'Coordinador Demo';
    })
    .filter((d, i, arr) => arr.findIndex(x => x.data().nombre === d.data().nombre) === i) // dedup por nombre
    .map(d => ({ id: d.id, nombre: d.data().nombre, datos_nomina: d.data().datos_nomina }));

  console.log(`\n🚑 Empleados a nominar (${empleados.length}):`);
  empleados.forEach(e => console.log(`   • ${e.nombre.padEnd(28)} ${e.datos_nomina.salario_bruto_anual}€/año`));

  // ── MODO MUESTRA: solo Elena, noviembre ──────────────────────────────────
  if (!MODO_TODO) {
    const elena = empleados.find(e => e.nombre.includes('Elena'));
    if (!elena) { console.log('⚠️  Elena no encontrada'); return; }
    const muestra = calcNomina(elena, 11, 2026);
    console.log('\n' + '═'.repeat(56));
    console.log('  MUESTRA — nómina generada (sin guardar todavía)');
    console.log('  Ejecuta con --todo para guardar todas en Firestore');
    imprimirNomina(muestra);
    return;
  }

  // ── MODO TODO: borrar existentes y regenerar jul–nov 2026 ───────────────
  console.log('\n🗑️  Borrando nóminas existentes...');
  const col = db.collection('empresas').doc(EID).collection('nominas');
  const existentes = await col.get();
  let lote = db.batch();
  let cnt = 0;
  for (const doc of existentes.docs) {
    lote.delete(doc.ref);
    cnt++;
    if (cnt % 400 === 0) { await lote.commit(); lote = db.batch(); }
  }
  if (cnt % 400 !== 0) await lote.commit();
  console.log(`   ✅ ${cnt} nóminas borradas`);

  // Meses a generar: jul(7) ago(8) sep(9) oct(10) → pagada | nov(11) → borrador
  const meses = [
    { mes: 7,  estado: 'pagada'  },
    { mes: 8,  estado: 'pagada'  },
    { mes: 9,  estado: 'pagada'  },
    { mes: 10, estado: 'pagada'  },
    { mes: 11, estado: 'borrador' },
  ];

  console.log('\n📄 Generando nóminas...\n');
  lote = db.batch(); cnt = 0;
  let total = 0;

  for (const { mes, estado } of meses) {
    const periodos = ['','Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    console.log(`  ${periodos[mes]} 2026 [${estado}]`);

    for (const emp of empleados) {
      const nom = calcNomina(emp, mes, 2026);
      nom.estado = estado;

      // Ajustar fecha_pago según estado
      if (estado === 'borrador') {
        nom.fecha_pago = null;
      }

      const ref = col.doc(nom.id);
      lote.set(ref, nom);
      cnt++;
      total++;

      console.log(`    ${emp.nombre.padEnd(28)} neto: ${nom.liquido_final.toFixed(2).padStart(9)} €  |  coste: ${nom.coste_total_empresa.toFixed(2).padStart(9)} €`);

      if (cnt >= 400) { await lote.commit(); lote = db.batch(); cnt = 0; }
    }
  }
  if (cnt > 0) await lote.commit();

  console.log(`\n${'═'.repeat(56)}`);
  console.log(`✅ ${total} nóminas generadas para ${empleados.length} empleados`);
  console.log(`   Jul–Oct 2026: estado "pagada"`);
  console.log(`   Nov 2026:     estado "borrador"\n`);
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error('\n❌', e.message); process.exit(1); });
