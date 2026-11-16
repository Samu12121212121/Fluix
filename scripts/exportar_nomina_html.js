#!/usr/bin/env node
/**
 * exportar_nomina_html.js
 * Genera un HTML con formato BOE-A-2014-11637 (Orden ESS/2098/2014)
 * para una nómina de Sanir CLM y lo abre en el navegador.
 *
 * USO:
 *   node scripts/exportar_nomina_html.js [empleadoNombre] [mes] [anio]
 *   node scripts/exportar_nomina_html.js "Elena" 11 2026
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');
const fs    = require('fs');
const { execSync } = require('child_process');

const SA_PATH = path.join(__dirname, '..', 'credentials.json');
const EID     = 'demo_sanir_clm_2026';

try { admin.initializeApp({ credential: admin.credential.cert(require(SA_PATH)) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db = admin.firestore();

const ARG_NOMBRE = process.argv[2] || 'Elena';
const ARG_MES    = parseInt(process.argv[3] || '11');
const ARG_ANIO   = parseInt(process.argv[4] || '2026');

// ── Helpers ──────────────────────────────────────────────────────────────────

function f(n, dec = 2) {
  if (n == null || n === 0) return '—';
  return Number(n).toLocaleString('es-ES', { minimumFractionDigits: dec, maximumFractionDigits: dec });
}

function fE(n) { return n != null && n !== 0 ? f(n) + ' €' : '—'; }

function ts2date(ts) {
  if (!ts) return '—';
  const d = ts._seconds ? new Date(ts._seconds * 1000) : new Date(ts);
  return d.toLocaleDateString('es-ES', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function periodoLabel(mes, anio) {
  const meses = ['','Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  return `${meses[mes]} ${anio}`;
}

// ── Generador de HTML ─────────────────────────────────────────────────────────

function generarHtml(n, empresa) {
  const esPagaExtra = n.paga_extra > 0;

  const filaDevengos = [
    ['Salario base',                       n.salario_bruto_mensual, ''],
    ...(esPagaExtra ? [['Paga extraordinaria', n.paga_extra, '']] : []),
    ...(n.paga_extra_prorrateada > 0 ? [['Prorrata pagas extra', n.paga_extra_prorrateada, '']] : []),
    ...(n.plus_antiguedad > 0 ? [['Plus antigüedad', n.plus_antiguedad, '']] : []),
    ...(n.horas_extra > 0 ? [['Horas extraordinarias', n.importe_horas_extra, '']] : []),
    ...(n.complementos > 0 ? [['Complementos', n.complementos, '']] : []),
  ];

  const fila = (concepto, importe, nota) => `
    <tr>
      <td>${concepto}</td>
      <td class="num">${importe > 0 ? f(importe) : '—'}</td>
      <td class="num">${nota}</td>
    </tr>`;

  const filaD = (concepto, base, pct, importe) => `
    <tr>
      <td>${concepto}</td>
      <td class="num">${base ? f(base) : ''}</td>
      <td class="num">${pct ? pct + ' %' : ''}</td>
      <td class="num red">${importe > 0 ? f(importe) : '—'}</td>
    </tr>`;

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Nómina ${n.empleado_nombre} — ${periodoLabel(n.mes, n.anio)}</title>
<style>
  @page { size: A4; margin: 15mm 15mm 15mm 15mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 8pt; color: #000; background: #fff; }
  h1 { font-size: 10pt; text-align: center; text-transform: uppercase; letter-spacing: 1px; border-top: 1.5pt solid #000; border-bottom: 1.5pt solid #000; padding: 2mm 0; margin-bottom: 3mm; }
  .subtitulo { font-size: 7pt; text-align: center; color: #444; margin-bottom: 4mm; }
  table { width: 100%; border-collapse: collapse; }
  td, th { border: 0.5pt solid #ccc; padding: 1mm 2mm; vertical-align: top; }
  th { background: #e8e8e8; font-weight: bold; font-size: 7.5pt; text-align: left; }
  .header-table td { border: none; padding: 0.5mm 2mm; }
  .section-title { background: #333; color: #fff; font-weight: bold; font-size: 8pt; padding: 1.5mm 2mm; margin-top: 3mm; margin-bottom: 0; letter-spacing: 0.5px; }
  .num { text-align: right; font-family: 'Courier New', monospace; }
  .red { color: #c00; font-weight: bold; }
  .green { color: #006600; font-weight: bold; }
  .total-row td { background: #f0f0f0; font-weight: bold; border-top: 1pt solid #000; }
  .neto-row td { background: #1a1a2e; color: #fff; font-weight: bold; font-size: 9pt; padding: 2mm 2mm; }
  .neto-row td.num { font-size: 10pt; }
  .footer { margin-top: 5mm; font-size: 7pt; color: #666; border-top: 0.5pt solid #ccc; padding-top: 2mm; }
  .firma { margin-top: 10mm; display: flex; justify-content: space-between; }
  .firma-box { border: 0.5pt solid #ccc; width: 60mm; padding: 2mm; }
  .firma-box p { font-size: 7pt; color: #666; }
  .firma-box .linea { border-bottom: 0.5pt solid #000; margin-top: 10mm; margin-bottom: 1mm; }
  .reverso { margin-top: 10mm; border-top: 2pt dashed #000; padding-top: 5mm; }
  .reverso h2 { font-size: 9pt; text-align: center; margin-bottom: 3mm; }
  .badge { display: inline-block; padding: 0.5mm 2mm; border-radius: 2px; font-size: 7pt; font-weight: bold; }
  .badge-pagada { background: #d4edda; color: #155724; border: 0.3pt solid #c3e6cb; }
  .badge-borrador { background: #fff3cd; color: #856404; border: 0.3pt solid #ffc107; }
  @media print { .no-print { display: none; } }
</style>
</head>
<body>

<!-- BOTÓN IMPRIMIR -->
<div class="no-print" style="text-align:right;margin-bottom:5mm">
  <button onclick="window.print()" style="background:#1a1a2e;color:#fff;border:none;padding:6px 16px;font-size:10pt;cursor:pointer;border-radius:3px">
    🖨️ Imprimir / Guardar PDF
  </button>
</div>

<!-- TÍTULO -->
<h1>Recibo de Salarios</h1>
<div class="subtitulo">
  Modelo BOE-A-2014-11637 · Orden ESS/2098/2014 · RD 2064/1995
  &nbsp;|&nbsp;
  <span class="badge ${n.estado === 'pagada' ? 'badge-pagada' : 'badge-borrador'}">${(n.estado || 'borrador').toUpperCase()}</span>
</div>

<!-- CABECERA EMPRESA / TRABAJADOR -->
<div class="section-title">DATOS DE LA EMPRESA Y DEL TRABAJADOR</div>
<table style="margin-top:0">
  <tr>
    <th style="width:50%">EMPRESA</th>
    <th style="width:50%">TRABAJADOR/A</th>
  </tr>
  <tr>
    <td>
      <strong>${empresa.nombre || 'Sanir Transporte Sanitario CLM S.L.'}</strong><br>
      CIF: ${empresa.nif || empresa.cif || 'B45000001'}<br>
      ${empresa.direccion || 'Polígono Industrial, C/ Industria 1, 45001 Toledo'}<br>
      Cód. Cuenta Cotización: ${empresa.ccc_ss || '450000000001'}
    </td>
    <td>
      <strong>${n.empleado_nombre}</strong><br>
      NIF: ${n.empleado_nif || '—'}&nbsp;&nbsp;&nbsp;NSS: ${n.empleado_nss || '—'}<br>
      Categoría: Técnico en Transporte Sanitario<br>
      Tipo contrato: Indefinido &nbsp;·&nbsp; Grupo cotización: 9
    </td>
  </tr>
  <tr>
    <td>
      <strong>Período de liquidación:</strong><br>
      Del ${ts2date(n.periodo_desde)} al ${ts2date(n.periodo_hasta)}<br>
      <strong>Fecha de pago:</strong> ${ts2date(n.fecha_pago) || '28/' + String(n.mes).padStart(2,'0') + '/' + n.anio}
    </td>
    <td>
      Nº días trabajados: ${n.mes === 2 ? 28 : [4,6,9,11].includes(n.mes) ? 30 : 31}&nbsp;&nbsp;
      Jornada: Completa (40h/sem)
    </td>
  </tr>
</table>

<!-- DEVENGOS -->
<div class="section-title" style="margin-top:4mm">I. DEVENGOS</div>
<table>
  <thead>
    <tr>
      <th style="width:65%">Concepto</th>
      <th class="num" style="width:17.5%">Unidades / Base</th>
      <th class="num" style="width:17.5%">Importe €</th>
    </tr>
  </thead>
  <tbody>
    ${filaDevengos.map(([c, i]) => fila(c, i, f(i))).join('')}
    ${n.retribuciones_especie > 0 ? fila('Retribuciones en especie', n.retribuciones_especie, f(n.retribuciones_especie)) : ''}
  </tbody>
  <tfoot>
    <tr class="total-row">
      <td colspan="2"><strong>TOTAL DEVENGADO</strong></td>
      <td class="num green"><strong>${f(n.total_devengos)} €</strong></td>
    </tr>
  </tfoot>
</table>

<!-- DEDUCCIONES -->
<div class="section-title" style="margin-top:3mm">II. DEDUCCIONES</div>
<table>
  <thead>
    <tr>
      <th style="width:46%">Concepto</th>
      <th class="num" style="width:18%">Base €</th>
      <th class="num" style="width:12%">Tipo %</th>
      <th class="num" style="width:24%">Importe €</th>
    </tr>
  </thead>
  <tbody>
    ${filaD('Contingencias comunes (trabajador)', n.base_cotizacion, '4,70', n.ss_trabajador_cc)}
    ${filaD('Desempleo (indefinido)', n.base_cotizacion, '1,55', n.ss_trabajador_desempleo)}
    ${filaD('Formación Profesional', n.base_cotizacion, '0,10', n.ss_trabajador_fp)}
    ${filaD('MEI 2026', n.base_cotizacion, '0,15', n.ss_mei_trabajador)}
    ${n.ss_solidaridad_trabajador > 0 ? filaD('Cotización solidaridad', n.base_cotizacion, '—', n.ss_solidaridad_trabajador) : ''}
    ${n.horas_extra > 0 ? filaD('SS horas extraordinarias', n.importe_horas_extra, '4,70', n.ss_horas_extra_trabajador) : ''}
    ${filaD(`Retención IRPF (${f(n.porcentaje_irpf, 1)} %)`, n.base_irpf, f(n.porcentaje_irpf, 1), n.retencion_irpf)}
    ${n.regularizacion_irpf > 0 ? filaD('Regularización IRPF', '', '', n.regularizacion_irpf) : ''}
    ${n.embargo_judicial > 0 ? filaD('Embargo judicial', '', '', n.embargo_judicial) : ''}
    ${n.descuento_ausencias > 0 ? filaD('Descuentos por ausencias', '', '', n.descuento_ausencias) : ''}
  </tbody>
  <tfoot>
    <tr class="total-row">
      <td colspan="3"><strong>TOTAL A DEDUCIR</strong></td>
      <td class="num red"><strong>${f(n.total_deducciones)} €</strong></td>
    </tr>
  </tfoot>
</table>

<!-- LÍQUIDO -->
<table style="margin-top:3mm">
  <tr class="neto-row">
    <td style="width:76%"><strong>III. LÍQUIDO TOTAL A PERCIBIR (I − II)</strong></td>
    <td class="num green" style="font-size:11pt"><strong>${f(n.liquido_final)} €</strong></td>
  </tr>
</table>

<!-- FIRMAS -->
<div class="firma">
  <div class="firma-box">
    <p>FIRMA Y SELLO DE LA EMPRESA</p>
    <div class="linea"></div>
    <p>Fecha:</p>
  </div>
  <div class="firma-box" style="text-align:right">
    <p>EL/LA TRABAJADOR/A — RECIBÍ</p>
    <div class="linea"></div>
    <p>Fecha:</p>
  </div>
</div>

<!-- ───────────── REVERSO ───────────── -->
<div class="reverso">
<h2>BASES DE COTIZACIÓN Y CUOTAS A LA SEGURIDAD SOCIAL (Art. 109 LGSS)</h2>

<table>
  <thead>
    <tr>
      <th>Concepto</th>
      <th class="num">Base €</th>
      <th class="num">Tipo %</th>
      <th class="num">Cuota empresa €</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Contingencias comunes</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">23,60</td>
      <td class="num">${f(n.ss_empresa_cc)}</td>
    </tr>
    <tr>
      <td>Desempleo (empresa, contrato indefinido)</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">5,50</td>
      <td class="num">${f(n.ss_empresa_desempleo)}</td>
    </tr>
    <tr>
      <td>FOGASA</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">0,20</td>
      <td class="num">${f(n.ss_empresa_fogasa)}</td>
    </tr>
    <tr>
      <td>Formación Profesional (empresa)</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">0,60</td>
      <td class="num">${f(n.ss_empresa_fp)}</td>
    </tr>
    <tr>
      <td>Accidentes trabajo / Enf. prof. CNAE 869 (RDL 3/2026)</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">1,75</td>
      <td class="num">${f(n.ss_empresa_at)}</td>
    </tr>
    <tr>
      <td>MEI 2026 (empresa)</td>
      <td class="num">${f(n.base_cotizacion)}</td>
      <td class="num">0,75</td>
      <td class="num">${f(n.ss_mei_empresa)}</td>
    </tr>
  </tbody>
  <tfoot>
    <tr class="total-row">
      <td colspan="3"><strong>TOTAL CUOTAS EMPRESA</strong></td>
      <td class="num red"><strong>${f(n.total_ss_empresa)} €</strong></td>
    </tr>
    <tr style="background:#f8f8f8">
      <td colspan="3"><strong>COSTE TOTAL EMPRESA</strong> (devengado + cuotas SS empresa)</td>
      <td class="num" style="font-weight:bold">${f(n.coste_total_empresa)} €</td>
    </tr>
  </tfoot>
</table>

<div style="margin-top:3mm;font-size:7pt;color:#666">
  <strong>Base de cotización:</strong> ${f(n.base_cotizacion)} €/mes ·
  <strong>Base mínima grupo 9:</strong> 1.424,40 €/mes ·
  <strong>Base máxima:</strong> 5.101,20 €/mes (RDL 3/2026)<br>
  Empresa acogida al régimen de seguros sociales de empresa: NO<br>
  Referencia normativa: RDL 3/2026 · Orden PJC/297/2026 · RD 2064/1995 · Orden ESS/2098/2014
</div>
</div>

<div class="footer">
  Generado por Fluix · fluixtech.es · ${new Date().toLocaleDateString('es-ES')}
  &nbsp;·&nbsp; Este documento tiene valor de recibo de salarios a todos los efectos legales.
</div>

</body>
</html>`;
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

async function main() {
  console.log(`\n📄 Buscando nómina de "${ARG_NOMBRE}" — ${ARG_MES}/${ARG_ANIO}...`);

  // Buscar nómina en Firestore
  const snap = await db.collection('empresas').doc(EID).collection('nominas')
    .where('mes', '==', ARG_MES)
    .where('anio', '==', ARG_ANIO)
    .get();

  const doc = snap.docs.find(d =>
    d.data().empleado_nombre.toLowerCase().includes(ARG_NOMBRE.toLowerCase()));

  if (!doc) {
    console.error(`❌ No se encontró nómina para "${ARG_NOMBRE}" en ${ARG_MES}/${ARG_ANIO}`);
    console.log('   Nóminas disponibles:');
    snap.docs.forEach(d => console.log(`   • ${d.data().empleado_nombre}`));
    process.exit(1);
  }

  const nomina = doc.data();
  console.log(`   ✅ Encontrada: ${nomina.empleado_nombre} — ${nomina.periodo}`);

  // Datos empresa
  const empDoc = await db.collection('empresas').doc(EID).get();
  const empresa = empDoc.data() || {};

  // Generar HTML
  const html   = generarHtml(nomina, empresa);
  const nombre = `nomina_${nomina.empleado_nombre.split(' ')[0].toLowerCase()}_${ARG_ANIO}${String(ARG_MES).padStart(2,'0')}.html`;
  const outDir = path.join(__dirname, '..', 'tmp');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir);
  const outPath = path.join(outDir, nombre);
  fs.writeFileSync(outPath, html, 'utf-8');

  console.log(`\n   📁 HTML guardado: ${outPath}`);

  // Abrir en el navegador
  try {
    const cmd = process.platform === 'win32'
      ? `start "" "${outPath}"`
      : process.platform === 'darwin'
        ? `open "${outPath}"`
        : `xdg-open "${outPath}"`;
    execSync(cmd);
    console.log('   🌐 Abierto en el navegador — usa "Imprimir → Guardar como PDF"\n');
  } catch (e) {
    console.log(`\n   Abre manualmente: ${outPath}\n`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error('\n❌', e.message); process.exit(1); });
