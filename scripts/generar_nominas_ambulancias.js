#!/usr/bin/env node
/**
 * Genera nóminas de noviembre 2026 para Sysday Emergencias Sanitarias
 * usando el motor de cálculo del RDL 8/2019 y normativa SS 2026.
 *
 * Uso: node scripts/generar_nominas_ambulancias.js
 */

const { execSync } = require('child_process');
const path = require('path');
const { v4: uuidv4 } = require('crypto');

// ── Token del usuario logueado en gcloud ──────────────────────────────────────
const TOKEN = execSync(
  'gcloud auth print-access-token sacoor80@gmail.com 2>/dev/null',
  { encoding: 'utf8' }
).trim();

if (!TOKEN) { console.error('❌ No hay token gcloud.'); process.exit(1); }

const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));
const PROJECT_ID  = 'planeaapp-4bea4';
const EMPRESA_ID  = 'demo_ambulancias_guadalajara_2026';
const MES         = 11;
const ANIO        = 2026;
const PERIODO     = 'noviembre 2026';

// Usar el token gcloud como credencial del SDK
admin.initializeApp({
  credential: {
    getAccessToken: () => Promise.resolve({ access_token: TOKEN, expires_in: 3600 })
  },
  projectId: PROJECT_ID,
});

const db    = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTES NORMATIVA SS 2026
// ═══════════════════════════════════════════════════════════════════════════════
const SS_TRAB = 0.0470 + 0.0155 + 0.0010 + 0.0012; // 6.47%
const SS_EMP  = 0.2360 + 0.0550 + 0.0020 + 0.0060 + 0.0150 + 0.0058; // 33.98% aprox
const BC_MIN  = 1260.0;
const BC_MAX  = 4720.5;
const SMI_MES = 1134.0; // SMI mensual 2026 (15876/14 pagas)
const HORAS_ANO_AMBULANCIA = 1736;

// ── Tramos IRPF 2026 ────────────────────────────────────────────────────────
function calcularIrpfAnual(baseImponible) {
  const tramos = [
    { hasta: 12450,  tipo: 0.19 },
    { hasta: 20200,  tipo: 0.24 },
    { hasta: 35200,  tipo: 0.30 },
    { hasta: 60000,  tipo: 0.37 },
    { hasta: 300000, tipo: 0.45 },
    { hasta: Infinity, tipo: 0.47 },
  ];
  let cuota = 0;
  let anterior = 0;
  for (const tramo of tramos) {
    if (baseImponible <= anterior) break;
    const aplicable = Math.min(baseImponible, tramo.hasta) - anterior;
    cuota += aplicable * tramo.tipo;
    anterior = tramo.hasta;
    if (baseImponible <= tramo.hasta) break;
  }
  return cuota;
}

// ── Reducción por rendimientos del trabajo (Art. 20 LIRPF) ─────────────────
function reduccionRendimientosTrabajo(rentoIntegra) {
  if (rentoIntegra <= 14450) return 7302;
  if (rentoIntegra <= 19747.5) return Math.max(0, 7302 - 1.75 * (rentoIntegra - 14450));
  return 0;
}

// ── Mínimo personal y familiar ─────────────────────────────────────────────
function minimoPersonalFamiliar(config) {
  let minimo = 5550; // mínimo personal base
  const hijos = config.num_hijos || 0;
  if (hijos >= 1) minimo += 2400;
  if (hijos >= 2) minimo += 2700;
  if (hijos >= 3) minimo += 4000;
  if (hijos >= 4) minimo += 4500;
  if (config.num_hijos_menores_3 > 0) minimo += 2800 * config.num_hijos_menores_3;
  if (config.discapacidad) minimo += 3000;
  return minimo;
}

// ── Cálculo principal ──────────────────────────────────────────────────────
function calcularNomina({ empresaId, empleadoId, empleadoNombre, empleadoNif, empleadoNss, mes, anio, config }) {
  const salarioBrutoAnual = config.salario_bruto_anual;
  const numPagas          = config.num_pagas || 14;
  const pagasProrrateadas = config.pagas_prorrateadas === true;
  const complementoFijo   = config.complemento_fijo || 0;
  const horasSemanales    = config.horas_semanales || 40;
  const coefParcial       = horasSemanales / 40;

  const salarioMensualBruto = pagasProrrateadas
    ? (salarioBrutoAnual / 12) * coefParcial
    : (salarioBrutoAnual / (numPagas === 14 ? 12 : 12)) * coefParcial;

  // Devengo: salario base + complemento
  const salarioBase  = salarioMensualBruto;
  const totalDevengos = salarioBase + complementoFijo;

  // Base de cotización (clamp entre BC_MIN y BC_MAX)
  const baseCotizacion = Math.max(BC_MIN, Math.min(BC_MAX, totalDevengos));

  // SS trabajador
  const ssTrabajador = baseCotizacion * SS_TRAB;

  // IRPF: calcular sobre base anual
  const baseAnualRendimiento = salarioBrutoAnual + complementoFijo * 12;
  const reduccionTrabajo = reduccionRendimientosTrabajo(baseAnualRendimiento);
  const minimoFamiliar   = minimoPersonalFamiliar(config);
  const baseImponibleAnual = Math.max(0, baseAnualRendimiento - reduccionTrabajo - 7302 - minimoFamiliar);
  const irpfAnualBruto  = calcularIrpfAnual(baseAnualRendimiento - reduccionTrabajo);
  const irpfBonificacion = calcularIrpfAnual(minimoFamiliar) * 0.19;
  const irpfAnualNeto   = Math.max(0, irpfAnualBruto - irpfBonificacion);
  const tipoIrpf        = baseAnualRendimiento > 0 ? irpfAnualNeto / baseAnualRendimiento : 0;
  const retIrpfMes      = totalDevengos * tipoIrpf;

  // Neto
  const totalDeducciones = ssTrabajador + retIrpfMes;
  const salarioNeto      = totalDevengos - totalDeducciones;

  // Coste empresa
  const ssEmpresa        = baseCotizacion * SS_EMP;
  const costeTotalEmpresa = totalDevengos + ssEmpresa;

  const id = db.collection('empresas').doc(empresaId).collection('nominas').doc().id;

  return {
    id,
    empresa_id:         empresaId,
    empleado_id:        empleadoId,
    empleado_nombre:    empleadoNombre,
    empleado_nif:       empleadoNif || '',
    empleado_nss:       empleadoNss || '',
    mes,
    anio,
    periodo:            PERIODO,
    estado:             'borrador',
    salario_bruto_mensual: salarioBase,
    complemento_fijo:   complementoFijo,
    total_devengos:     totalDevengos,
    base_cotizacion:    baseCotizacion,
    ss_trabajador:      parseFloat(ssTrabajador.toFixed(2)),
    total_ss_trabajador: parseFloat(ssTrabajador.toFixed(2)),
    retencion_irpf:     parseFloat(retIrpfMes.toFixed(2)),
    tipo_irpf:          parseFloat(tipoIrpf.toFixed(4)),
    total_deducciones:  parseFloat(totalDeducciones.toFixed(2)),
    salario_neto:       parseFloat(salarioNeto.toFixed(2)),
    ss_empresa:         parseFloat(ssEmpresa.toFixed(2)),
    total_ss_empresa:   parseFloat(ssEmpresa.toFixed(2)),
    coste_total_empresa: parseFloat(costeTotalEmpresa.toFixed(2)),
    salario_bruto_anual: salarioBrutoAnual,
    horas_extra:        0,
    precio_hora_extra:  0,
    importe_horas_extra: 0,
    complementos_variables: 0,
    descuento_ausencias: 0,
    lineas_ausencias:   [],
    lineas_devengos:    [
      { concepto: 'Salario base', importe: parseFloat(salarioBase.toFixed(2)), tipo: 'salario_base' },
      ...(complementoFijo > 0 ? [{ concepto: 'Complemento fijo', importe: complementoFijo, tipo: 'complemento_fijo' }] : []),
    ],
    lineas_deducciones: [
      { concepto: 'Seg. Social (trabajador)', importe: parseFloat(ssTrabajador.toFixed(2)), tipo: 'ss_trabajador' },
      { concepto: `IRPF ${(tipoIrpf * 100).toFixed(1)}%`, importe: parseFloat(retIrpfMes.toFixed(2)), tipo: 'irpf' },
    ],
    irpf_ajustado:      false,
    base_acumulada_ytd: salarioBrutoAnual / 12 * (mes - 1),
    irpf_acumulado_ytd: retIrpfMes * (mes - 1),
    es_correccion:      false,
    notas:              '',
    tipo_hora_extra:    'no_estructural',
    created_at:         FieldValue.serverTimestamp(),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log('\n🚀 Generando nóminas para Sysday Emergencias Sanitarias');
  console.log(`   empresaId: ${EMPRESA_ID}`);
  console.log(`   Período:   ${PERIODO}\n`);

  // Verificar que no existen ya
  const existentes = await db.collection('empresas').doc(EMPRESA_ID)
    .collection('nominas')
    .where('mes', '==', MES)
    .where('anio', '==', ANIO)
    .where('es_correccion', '==', false)
    .get();

  if (!existentes.empty) {
    console.log(`⚠️  Ya existen ${existentes.size} nóminas para ${PERIODO}. Abortando.`);
    return;
  }

  // Obtener empleados
  const empSnap = await db.collection('usuarios')
    .where('empresa_id', '==', EMPRESA_ID)
    .where('activo', '==', true)
    .get();

  console.log(`👥 Empleados activos encontrados: ${empSnap.size}`);

  const conDatos = empSnap.docs.filter(d => d.data().datos_nomina);
  console.log(`📋 Con datos_nomina: ${conDatos.length}`);

  if (conDatos.length === 0) {
    console.log('⚠️  Ningún empleado tiene datos_nomina. Nada que generar.');
    return;
  }

  // Generar en lotes de 500 (límite Firestore batch)
  const BATCH_SIZE = 400;
  let generadas = 0;
  let lote = db.batch();
  let enLote = 0;

  for (const empDoc of conDatos) {
    const data = empDoc.data();
    const config = data.datos_nomina;

    if (!config.salario_bruto_anual || config.salario_bruto_anual <= 0) {
      console.log(`  ⚠️  ${data.nombre}: salario_bruto_anual=0 → omitido`);
      continue;
    }
    if (config.salario_bruto_anual < 15876) {
      console.log(`  ⚠️  ${data.nombre}: salario ${config.salario_bruto_anual}€ < SMI → omitido`);
      continue;
    }

    const nomina = calcularNomina({
      empresaId: EMPRESA_ID,
      empleadoId: empDoc.id,
      empleadoNombre: data.nombre || 'Sin nombre',
      empleadoNif: config.nif,
      empleadoNss: config.nss,
      mes: MES,
      anio: ANIO,
      config,
    });

    const ref = db.collection('empresas').doc(EMPRESA_ID)
      .collection('nominas').doc(nomina.id);

    lote.set(ref, nomina);
    enLote++;
    generadas++;

    console.log(`  ✅ ${data.nombre.padEnd(32)} | ${nomina.salario_neto.toFixed(2)}€ neto | IRPF ${(nomina.tipo_irpf * 100).toFixed(1)}%`);

    if (enLote >= BATCH_SIZE) {
      await lote.commit();
      lote = db.batch();
      enLote = 0;
      console.log(`  [commit lote intermedio]`);
    }
  }

  if (enLote > 0) await lote.commit();

  console.log(`\n✅ ${generadas} nóminas generadas para ${PERIODO}`);
  console.log(`   Estado: borrador (aprobación pendiente desde la app)\n`);
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error('❌', e.message); process.exit(1); });
