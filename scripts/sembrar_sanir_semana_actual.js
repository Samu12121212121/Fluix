#!/usr/bin/env node
/**
 * sembrar_sanir_semana_actual.js
 * ─────────────────────────────────────────────────────────────────
 * Para Sanir Transporte Sanitario CLM (demo_sanir_clm_2026):
 *
 *  0. Crea/actualiza configuracion/pdf con datos del emisor (razón social, CIF,
 *     dirección, IBAN, pie legal específico de transporte sanitario exento IVA)
 *  1. Crea plantilla PDF activa para facturas (con bloques y branding Sanir)
 *  2. Genera fichajes de la semana actual (desde el lunes hasta hoy)
 *     — Días pasados: fichajes completos (entrada + salida)
 *     — Hoy: estado real según hora actual (en jornada / cerrado)
 *  3. Crea horarios_empleados para los 8 empleados activos
 *     para que puedan consultar su turno semanal desde el portal
 *
 * USO:
 *   node scripts/sembrar_sanir_semana_actual.js
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('../functions/node_modules/firebase-admin');
const path  = require('path');

const SA_PATH = path.join(__dirname, '..', 'credentials.json');
const EID     = 'demo_sanir_clm_2026';

let sa;
try { sa = require(SA_PATH); }
catch (e) { console.error('❌ No se encontró credentials.json en la raíz del proyecto'); process.exit(1); }

try { admin.initializeApp({ credential: admin.credential.cert(sa) }); }
catch (e) { if (!e.message.includes('already exists')) throw e; }

const db = admin.firestore();
const TS = admin.firestore.Timestamp;

// ── Helpers ──────────────────────────────────────────────────────────────────

function dateStr(d) {
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

function jitter(seed, min, max) {
  const hash = ((seed * 2654435761) >>> 0) % (max - min + 1);
  return min + hash;
}

// Devuelve el lunes de la semana que contiene `desde` (a medianoche)
function getLunesSemana(desde) {
  const d = new Date(desde);
  const dow = d.getDay(); // 0=dom, 1=lun…6=sab
  const offset = dow === 0 ? 6 : dow - 1;
  d.setDate(d.getDate() - offset);
  d.setHours(0, 0, 0, 0);
  return d;
}

// ── Empleados ─────────────────────────────────────────────────────────────────
// nextDay: true  → turno noche, salida al día siguiente
// dias[]: 0=lun…6=dom, 1=trabaja / 0=libre

const EMPLEADOS = [
  // 5 empleados demo (ID propio)
  { id: 'amb_emp_001', nombre: 'Elena Martín Sanz',   turno: 'manana', entrada: 7,  salida: 19, nextDay: false, jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_002', nombre: 'Roberto López Vega',  turno: 'noche',  entrada: 19, salida: 7,  nextDay: true,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_003', nombre: 'Carmen Ruiz Molina',  turno: 'noche',  entrada: 19, salida: 7,  nextDay: true,  jornada: 720, dias: [1,1,1,1,1,1,1] },
  { id: 'amb_emp_004', nombre: 'Javier Torres Pérez', turno: 'manana', entrada: 8,  salida: 15, nextDay: false, jornada: 420, dias: [1,1,1,1,1,0,0] },
  { id: 'amb_emp_005', nombre: 'Laura González Díaz', turno: 'manana', entrada: 8,  salida: 14, nextDay: false, jornada: 360, dias: [1,1,1,1,1,0,0] },
  // 3 empleados con UID real de Firebase (acceden al portal)
  { id: 'SpnOb0ySgRa7Zqe308u0bZx0YJ63', nombre: 'Coordinador Demo',   turno: 'manana', entrada: 8,  salida: 17, nextDay: false, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'U5TgqYNniEXV6sbqPTWSq3oSQYQ2', nombre: 'Roberto López Vega', turno: 'tarde',  entrada: 14, salida: 22, nextDay: false, jornada: 480, dias: [1,1,1,1,1,0,0] },
  { id: 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2', nombre: 'Elena Martín Sanz',  turno: 'manana', entrada: 7,  salida: 15, nextDay: false, jornada: 480, dias: [1,1,1,1,1,0,0] },
];

// ══════════════════════════════════════════════════════════════════════════════
// 0. CONFIGURACIÓN PDF DEL EMISOR
//    Ruta: empresas/{EID}/configuracion/pdf
//    Contiene razón social, CIF, dirección, IBAN y config por tipo de documento.
//    PdfConfigService.cargar() la lee al generar cada PDF de factura/presupuesto.
//    Sin este doc, el PDF puede salir con datos vacíos o incompletos.
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarConfiguracionPdf() {
  console.log('\n⚙️  0. Configurando datos del emisor Sanir (configuracion/pdf)...');

  const ref = db.collection('empresas').doc(EID)
                .collection('configuracion').doc('pdf');

  await ref.set({
    // ── Emisor ──────────────────────────────────────────────────────────────
    razon_social:        'Sanir Transporte Sanitario CLM S.L.',
    nombre_comercial:    'Sanir Ambulancias',
    cif:                 'B45198752',
    tipo_via:            'Calle',
    nombre_via:          'Cardenal Lorenzana',
    numero:              '4',
    piso_porta:          null,
    codigo_postal:       '45002',
    localidad:           'Toledo',
    provincia:           'Toledo',
    pais:                'España',
    telefono:            '+34 925 274 400',
    email:               'info@sanirtransporte.es',
    web:                 'www.sanirtransporte.es',
    registro_mercantil:  'Reg. Mercantil de Toledo, Tomo 1245, Folio 87',

    // ── Pago ────────────────────────────────────────────────────────────────
    iban:                'ES91 2100 0418 4502 0005 1332',
    iban_titular:        'Sanir Transporte Sanitario CLM S.L.',
    iban_banco:          'CaixaBank',
    metodos_aceptados:   ['transferencia', 'domiciliacion'],
    texto_pago_adicional: 'Pagos a 60 días mediante transferencia bancaria. Ref.: número de factura.',

    // ── Series de numeración ─────────────────────────────────────────────────
    prefijo_factura:        'F',
    prefijo_rectificativa:  'R',
    prefijo_presupuesto:    'P',
    prefijo_proforma:       'PF',
    prefijo_albaran:        'ALB',

    // ── Config por tipo de documento ─────────────────────────────────────────
    // El transporte de enfermos en ambulancias está exento de IVA (art. 20.1.3º LIVA)
    config_por_tipo: {
      factura: {
        titulo:              'Factura',
        etiqueta_cliente:    'Cliente',
        dias_vencimiento:    60,
        pie_legal:           'Operación exenta de IVA según art. 20.1.3º de la LIVA (transporte de enfermos en ambulancias o vehículos con equipamiento sanitario). Factura emitida conforme al Real Decreto 1619/2012.',
        mostrar_pago:        true,
        mostrar_columna_iva: true,
        mostrar_importes:    true,
        mostrar_firma:       false,
        mostrar_verifactu:   true,
        tipo_iva_defecto:    0.0,
      },
      presupuesto: {
        titulo:              'Presupuesto',
        etiqueta_cliente:    'Cliente',
        dias_vencimiento:    30,
        pie_legal:           'Documento sin validez fiscal. Válido 30 días desde su emisión.',
        mostrar_pago:        false,
        mostrar_columna_iva: true,
        mostrar_importes:    true,
        mostrar_firma:       false,
        mostrar_verifactu:   false,
        tipo_iva_defecto:    0.0,
        condiciones:         'Presupuesto sujeto a disponibilidad de flota. Precios sin IVA (exento art. 20.1.3º LIVA).',
      },
      rectificativa: {
        titulo:              'Factura Rectificativa',
        etiqueta_cliente:    'Cliente',
        dias_vencimiento:    0,
        pie_legal:           'Factura rectificativa emitida conforme al Art. 15 del R.D. 1619/2012.',
        mostrar_pago:        false,
        mostrar_columna_iva: true,
        mostrar_importes:    true,
        mostrar_firma:       false,
        mostrar_verifactu:   true,
        tipo_iva_defecto:    0.0,
      },
    },

    // ── Diseño: layout y color por tipo (coincide con la plantilla) ──────────
    layout_por_tipo: { factura: 'clasico', presupuesto: 'clasico' },
    color_por_tipo:  { factura: '#1565C0', presupuesto: '#1565C0', rectificativa: '#1565C0' },

    updated_at: TS.fromDate(new Date()),
  }, { merge: true });

  console.log('   ✅ configuracion/pdf creada/actualizada con datos de Sanir');
  console.log('   • Razón social: Sanir Transporte Sanitario CLM S.L. | CIF: B45198752');
  console.log('   • Pie legal facturas: exento IVA art. 20.1.3º LIVA');
  console.log('   • Layout/color heredado por tpl_sanir_factura_estandar');
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. PLANTILLA PDF PARA FACTURAS
//    Almacenada en pdf_templates/{tplId} (global, filtrada por empresa_id)
//    La app la usa como default al generar facturas cuando no hay plantilla
//    explícita asignada en la config TPV de la empresa.
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarPlantillaPdf() {
  console.log('\n📄 1. Creando plantilla PDF para facturas Sanir...');

  const tplId = 'tpl_sanir_factura_estandar';
  await db.collection('pdf_templates').doc(tplId).set({
    id:                 tplId,
    empresa_id:         EID,
    nombre:             'Plantilla Estándar Sanir',
    descripcion:        'Plantilla oficial para facturas de transporte sanitario CLM',
    tipo:               'factura',
    es_default:         true,
    activa:             true,
    fecha_creacion:     TS.fromDate(new Date(2026, 0, 1)),
    fecha_modificacion: TS.fromDate(new Date()),
    color_primario:     '#1565C0',
    color_secundario:   '#0D47A1',
    color_texto:        '#212121',
    color_fondo:        '#FFFFFF',
    margen_horizontal:  36,
    margen_vertical:    36,
    estilo_layout:      'clasico',
    bloques: [
      {
        tipo: 'header', visible: true, orden: 1,
        props: { mostrar_logo: true, color_fondo: '#1565C0', color_texto: '#FFFFFF', padding: 18, border_radius: 12 },
      },
      {
        tipo: 'info_documento', visible: true, orden: 2,
        props: { mostrar_numero: true, mostrar_fecha_emision: true, mostrar_fecha_vencimiento: true },
      },
      {
        tipo: 'cliente', visible: true, orden: 3,
        props: { titulo: 'FACTURAR A:', mostrar_nif: true, mostrar_direccion: true, mostrar_email: true, color_fondo: '#F5F9FF', border_radius: 8 },
      },
      {
        tipo: 'tabla_lineas', visible: true, orden: 4,
        props: { mostrar_cantidad: true, mostrar_precio_unitario: true, mostrar_iva: true, color_cabecera: '#0D47A1', color_fila_par: '#FFFFFF', color_fila_impar: '#FAFBFC' },
      },
      {
        tipo: 'totales', visible: true, orden: 5,
        props: { mostrar_base: true, mostrar_iva: true, mostrar_irpf: false, mostrar_total: true },
      },
      {
        tipo: 'forma_pago', visible: true, orden: 6,
        props: { mostrar_metodo: true, mostrar_iban: true, color_fondo: '#F5F9FF' },
      },
      {
        tipo: 'notas', visible: true, orden: 7,
        props: { placeholder: 'Exento IVA art. 20.1.3º LIVA — Transporte sanitario' },
      },
      {
        tipo: 'qr_verifactu', visible: true, orden: 8,
        props: { tamano: 57, mostrar_etiqueta: true },
      },
      {
        tipo: 'footer', visible: true, orden: 9,
        props: { contenido: 'Sanir Transporte Sanitario CLM · CIF: B45198752 · C/ Cardenal Lorenzana 4, 45002 Toledo', tamano_fuente: 7, color_texto: '#BDBDBD' },
      },
    ],
    es_demo: true,
  }, { merge: true });

  console.log(`   ✅ Plantilla "${tplId}" creada/actualizada como default para facturas`);
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. FICHAJES SEMANA ACTUAL
//    Itera desde el lunes de la semana actual hasta hoy (inclusive).
//    — Días pasados: fichaje con salida definida (jornada cerrada).
//    — Hoy: salida = null si la jornada sigue en curso, o timestamp si ya terminó.
//    — Turnos noche de hoy: solo si su hora de entrada ya ha ocurrido.
//    Usa merge:true → idempotente si se ejecuta varias veces.
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarFichajesSemana() {
  console.log('\n⏱️  2. Generando fichajes semana actual...');

  const hoy    = new Date();
  const ahoraH = hoy.getHours();
  const lunes  = getLunesSemana(hoy);

  console.log(`   Semana : lun ${dateStr(lunes)}  →  hoy ${dateStr(hoy)}  (${ahoraH}h aprox)`);

  const col = db.collection('empresas').doc(EID).collection('fichajes');

  // Consultar los fichajes que ya existen en el rango para evitar duplicados
  const snap = await col
    .where('fecha', '>=', dateStr(lunes))
    .where('fecha', '<=', dateStr(hoy))
    .get();
  const existentes = new Set(snap.docs.map(d => `${d.data().fecha}_${d.data().empleado_id}`));

  let lote   = db.batch();
  let enLote = 0;
  let total  = 0;

  const cursor = new Date(lunes);

  while (cursor <= hoy) {
    const year   = cursor.getFullYear();
    const month  = cursor.getMonth() + 1;
    const day    = cursor.getDate();
    const dStr   = dateStr(cursor);
    const dow    = cursor.getDay();
    const dowIdx = dow === 0 ? 6 : dow - 1; // 0=lun…6=dom
    const esHoy  = dStr === dateStr(hoy);

    for (const emp of EMPLEADOS) {
      // ¿Trabaja este día de la semana?
      if (!emp.dias[dowIdx]) continue;

      // Turno noche HOY: si su hora de entrada aún no ha llegado, omitir
      if (esHoy && emp.nextDay && ahoraH < emp.entrada) continue;

      // ¿Ya existe este fichaje?
      if (existentes.has(`${dStr}_${emp.id}`)) continue;

      // Entrada con pequeño jitter determinista (0-7 min)
      const jit = jitter(emp.id.charCodeAt(0) + day + month, 0, 7);
      const entradaDate = new Date(year, month - 1, day, emp.entrada, jit, 0);

      // Pausa a mitad de jornada (30 min fijos)
      const pausaInicio = new Date(entradaDate.getTime() + (emp.jornada / 2) * 60000);
      const pausaFin    = new Date(pausaInicio.getTime() + 30 * 60000);

      // ── Calcular salida ─────────────────────────────────────────────────────
      let salidaTs = null;

      if (!esHoy) {
        // Día pasado → siempre con salida
        if (emp.nextDay) {
          // Turno noche: salida al día siguiente (hora emp.salida)
          const jitSal = jitter(emp.id.charCodeAt(0) + day * 3, 0, 8);
          salidaTs = TS.fromDate(new Date(year, month - 1, day + 1, emp.salida, jitSal, 0));
        } else {
          // Turno diurno: salida = entrada + jornada + pausa + jitter
          const jitSal  = jitter(emp.id.charCodeAt(0) + day * 7, -3, 8);
          const salidaMs = entradaDate.getTime() + (emp.jornada + 30) * 60000 + jitSal * 60000;
          salidaTs = TS.fromDate(new Date(salidaMs));
        }
      } else if (!emp.nextDay) {
        // Hoy, turno diurno: cerrado si la hora de salida ya pasó
        const jitSal   = jitter(emp.id.charCodeAt(0) + day * 5, -2, 6);
        const salidaMs = entradaDate.getTime() + (emp.jornada + 30) * 60000 + jitSal * 60000;
        const salidaDate = new Date(salidaMs);
        if (salidaDate.getHours() <= ahoraH) {
          salidaTs = TS.fromDate(salidaDate);
        }
        // Si la jornada no ha terminado → salidaTs = null (en curso)
      }
      // Hoy, turno noche que ya empezó → salidaTs = null (en curso hasta mañana)

      const fichajeId = `fich_${year}${String(month).padStart(2,'0')}${String(day).padStart(2,'0')}_${emp.id}`;

      lote.set(col.doc(fichajeId), {
        id:              fichajeId,
        empresa_id:      EID,
        empleado_id:     emp.id,
        empleado_nombre: emp.nombre,
        fecha:           dStr,
        fecha_ts:        TS.fromDate(entradaDate),
        entrada:         TS.fromDate(entradaDate),
        salida:          salidaTs,
        pausas: [{
          inicio: TS.fromDate(pausaInicio),
          fin:    TS.fromDate(pausaFin),
        }],
        tipo_horas:    'ordinarias',
        dispositivo_id: 'demo_tablet',
        creado_at:     TS.fromDate(entradaDate),
        es_correccion: false,
        correcto:      true,
        minutos_pausa: 30,
        es_demo:       true,
      });

      enLote++;
      total++;
      const estado = salidaTs ? '→ cerrado' : '→ EN JORNADA';
      console.log(`   ${dStr}  ${emp.nombre.padEnd(25)} ${String(emp.entrada).padStart(2,'0')}:${String(jit).padStart(2,'0')} ${estado}`);

      if (enLote >= 400) {
        await lote.commit();
        lote   = db.batch();
        enLote = 0;
      }
    }

    cursor.setDate(cursor.getDate() + 1);
  }

  if (enLote > 0) await lote.commit();

  if (total === 0) {
    console.log('   ℹ️  Todos los fichajes de la semana ya existían');
  } else {
    console.log(`   ✅ ${total} fichaje(s) nuevos creados`);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. HORARIOS SEMANALES
//    Colección: empresas/{EID}/horarios_empleados/{uid}
//    Estructura: { lun: {entrada:"07:00", salida:"19:00"}, ..., dom: {libre:true} }
//    El portal empleado lee este documento para mostrar "Mi horario esta semana".
// ══════════════════════════════════════════════════════════════════════════════

async function sembrarHorarios() {
  console.log('\n📅 3. Configurando horarios semanales para empleados...');

  const col     = db.collection('empresas').doc(EID).collection('horarios_empleados');
  const batch   = db.batch();
  const diasKey = ['lun','mar','mie','jue','vie','sab','dom'];

  for (const emp of EMPLEADOS) {
    const horario = {};

    for (let i = 0; i < 7; i++) {
      if (emp.dias[i]) {
        horario[diasKey[i]] = {
          libre:   false,
          entrada: `${String(emp.entrada).padStart(2,'0')}:00`,
          salida:  `${String(emp.salida).padStart(2,'0')}:00`,
        };
      } else {
        horario[diasKey[i]] = { libre: true };
      }
    }

    batch.set(col.doc(emp.id), {
      uid:            emp.id,
      nombre:         emp.nombre,
      empresa_id:     EID,
      turno:          emp.turno,
      jornada_diaria: emp.jornada,
      actualizado_at: TS.fromDate(new Date()),
      es_demo:        true,
      ...horario,
    }, { merge: true });

    const diasStr = emp.dias
      .map((v, i) => v ? ['L','M','X','J','V','S','D'][i] : '·')
      .join('');
    console.log(`   ✅ ${emp.nombre.padEnd(28)} [${diasStr}] ${String(emp.entrada).padStart(2,'0')}:00–${String(emp.salida).padStart(2,'0')}:00`);
  }

  await batch.commit();
  console.log(`   ✅ ${EMPLEADOS.length} horarios semanales configurados`);
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

async function main() {
  const hoy   = new Date();
  const lunes = getLunesSemana(hoy);

  console.log('\n🚑 SEMANA ACTUAL + PLANTILLA PDF — Sanir Transporte Sanitario CLM');
  console.log(`   empresaId : ${EID}`);
  console.log(`   Semana    : ${dateStr(lunes)} (lun) → ${dateStr(hoy)} (hoy)`);
  console.log('═'.repeat(60));

  await sembrarConfiguracionPdf();
  await sembrarPlantillaPdf();
  await sembrarFichajesSemana();
  await sembrarHorarios();

  console.log('\n' + '═'.repeat(60));
  console.log('✅ Completado');
  console.log(`   • Emisor Sanir en empresas/${EID}/configuracion/pdf`);
  console.log(`   • Plantilla PDF activa para facturas → pdf_templates/tpl_sanir_factura_estandar`);
  console.log(`   • Fichajes semana (${dateStr(lunes)}–${dateStr(hoy)}) generados`);
  console.log(`   • 8 horarios en empresas/${EID}/horarios_empleados/`);
  console.log('   • Las facturas existentes ya usarán la plantilla al generarse el PDF\n');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    process.exit(1);
  });
