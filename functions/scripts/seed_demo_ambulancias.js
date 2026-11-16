/**
 * SEED DEMO AMBULANCIAS — Sanir / Castilla-La Mancha
 *
 * Crea la cuenta de demo para empresas de transporte sanitario:
 *   • Auth: Test_Sanir_CLM@fluixtest.com / DemoSeed1972
 *   • Empresa: "Sanir Transporte Sanitario CLM"
 *   • 5 empleados (Conductor, Conductor, ATS, Jefe de Equipo, Administrativo)
 *   • Convenio CLM ambulancias en Firestore (II Convenio CLM, ultraactividad 2026)
 *   • Fichajes de esta semana (lunes-hoy)
 *   • Nóminas de octubre 2026 ya calculadas
 *   • Suscripción enterprise con todos los módulos RRHH activos
 *
 * Uso:
 *   cd functions
 *   node scripts/seed_demo_ambulancias.js
 *
 * Requiere serviceAccountKey.json en functions/
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4',
});

const db   = admin.firestore();
const auth = admin.auth();

// ── CONSTANTES ──────────────────────────────────────────────────────────────
const DEMO_EMAIL    = 'Test_Sanir_CLM@fluixtest.com';
const DEMO_PASSWORD = 'DemoSeed1972';
const EMPRESA_ID    = 'demo_sanir_clm_2026';
const CONVENIO_ID   = 'transporte-sanitario-estatal';

const hoy      = new Date();
const HOY_STR  = fmt(hoy);
const MES_STR  = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}`;

function fmt(d) {
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}
function ts(d) { return admin.firestore.Timestamp.fromDate(d); }

// ── EMPLEADOS ────────────────────────────────────────────────────────────────
const EMPLEADOS = [
  {
    id:         'amb_emp_001',
    nombre:     'Elena Martín Sanz',
    correo:     'elena.martin@fluixtest.com',
    puesto:     'Conductora de Ambulancia',
    departamento: 'Operaciones',
    dni:        '11111111H',
    nss:        '190000000001',
    iban:       'ES7600750000060200051139',
    fecha_alta: new Date('2021-03-01'),
    salario_bruto_anual: 25424.00,  // 1.816€ × 14 (conductor 2026 est.)
    tipo_contrato: 'indefinido',
    num_pagas: 14,
    horas_semanales: 40,
    categoria_convenio: 'conductor',
    situacion_familiar: 'casado',
    num_hijos: 2,
  },
  {
    id:         'amb_emp_002',
    nombre:     'Roberto López Vega',
    correo:     'roberto.lopez@fluixtest.com',
    puesto:     'Conductor de Ambulancia',
    departamento: 'Operaciones',
    dni:        '22222222J',
    nss:        '190000000002',
    iban:       'ES7600750000060200051140',
    fecha_alta: new Date('2020-06-15'),
    salario_bruto_anual: 25424.00,  // 1.816€ × 14 (conductor 2026 est.)
    tipo_contrato: 'indefinido',
    num_pagas: 14,
    horas_semanales: 40,
    categoria_convenio: 'conductor',
    situacion_familiar: 'soltero',
    num_hijos: 0,
  },
  {
    id:         'amb_emp_003',
    nombre:     'Carmen Ruiz Molina',
    correo:     'carmen.ruiz@fluixtest.com',
    puesto:     'ATS — Ayudante Técnico Sanitario',
    departamento: 'Operaciones',
    dni:        '33333333K',
    nss:        '190000000003',
    iban:       'ES7600750000060200051141',
    fecha_alta: new Date('2019-01-10'),
    salario_bruto_anual: 33530.00,  // 2.395€ × 14 (ATS/DUE 2026 est.)
    tipo_contrato: 'indefinido',
    num_pagas: 14,
    horas_semanales: 40,
    categoria_convenio: 'ats-due',
    situacion_familiar: 'casado',
    num_hijos: 1,
  },
  {
    id:         'amb_emp_004',
    nombre:     'Javier Torres Pérez',
    correo:     'javier.torres@fluixtest.com',
    puesto:     'Jefe de Equipo',
    departamento: 'Operaciones',
    dni:        '44444444L',
    nss:        '190000000004',
    iban:       'ES7600750000060200051142',
    fecha_alta: new Date('2018-04-01'),
    salario_bruto_anual: 24934.00,  // 1.781€ × 14 (jefe equipo 2026 est.)
    tipo_contrato: 'indefinido',
    num_pagas: 14,
    horas_semanales: 40,
    categoria_convenio: 'jefe-equipo',
    situacion_familiar: 'casado',
    num_hijos: 3,
  },
  {
    id:         'amb_emp_005',
    nombre:     'Laura González Díaz',
    correo:     'laura.gonzalez@fluixtest.com',
    puesto:     'Auxiliar Administrativo',
    departamento: 'Administración',
    dni:        '55555555M',
    nss:        '190000000005',
    iban:       'ES7600750000060200051143',
    fecha_alta: new Date('2022-09-01'),
    salario_bruto_anual: 22568.00,  // 1.612€ × 14 (auxiliar admin 2026 est.)
    tipo_contrato: 'indefinido',
    num_pagas: 14,
    horas_semanales: 40,
    categoria_convenio: 'auxiliar-admin',
    situacion_familiar: 'soltero',
    num_hijos: 0,
  },
];

// ── CONVENIO CLM AMBULANCIAS ─────────────────────────────────────────────────
// Art. 22 II Convenio CLM: personal de movimiento → 1800h/año trabajo efectivo
const HORAS_ANUALES = 1800;

const CONVENIO_DATA = {
  nombre: 'II Convenio Colectivo de Trabajo para Empresas y Trabajadores de Transporte de Enfermos y Accidentados en Ambulancia — Castilla-La Mancha',
  codigo: '77100175012013',
  ambito: 'autonomico',
  sector: 'ambulancia',
  tipo_convenio: 'sectorial_autonomico',
  vigencia: {
    inicio: '2009-01-01',
    fin: '2026-12-31',
    estado_dato: 'ultraactividad_2026',
    nota: 'Único convenio CLM ambulancias. Vigente por ultraactividad (Art. 4) hasta nuevo acuerdo.',
  },
  fuente: {
    documento: 'DOCM núm. 222, 17/11/2010 — Resolución 08/11/2010 Dirección General de Trabajo e Inmigración CLM.',
    codigo_convenio: '77100175012013',
    fecha_extraccion: '2026-11-06',
    version: 'v2',
    nota: 'Tablas 2026 estimadas (IPC acumulado ~38% sobre provisional 2010). Verificar con empresa.',
  },
  provincia_aplicacion: 'Castilla-La Mancha',
  pagas: 14,
  jornada_horas_anuales: HORAS_ANUALES,
  cnae: '869',
  at_porcentaje: 1.75,
};

// Tablas salariales 2026 estimadas — IPC acumulado ~38% sobre tablas provisionales 2010
// Fuente base: DOCM 17/11/2010 (tabla provisional 2010). Actualizar con tablas reales de Sanir.
const CATEGORIAS = [
  { id: 'medico',         nombre: 'Médico',                               grupo_profesional: 'sanitario',       salario_base_mensual: 3194.00 },
  { id: 'ats-due',        nombre: 'ATS / Ayudante Técnico Sanitario',     grupo_profesional: 'sanitario',       salario_base_mensual: 2395.00 },
  { id: 'jefe-trafico',   nombre: 'Jefe de Tráfico',                      grupo_profesional: 'mando',           salario_base_mensual: 1950.00 },
  { id: 'oficial-admin',  nombre: 'Oficial Administrativo',               grupo_profesional: 'administrativo',  salario_base_mensual: 1904.00 },
  { id: 'jefe-equipo',    nombre: 'Jefe de Equipo',                       grupo_profesional: 'mando',           salario_base_mensual: 1781.00 },
  { id: 'jefe-taller',    nombre: 'Jefe de Taller',                       grupo_profesional: 'mantenimiento',   salario_base_mensual: 1864.00 },
  { id: 'conductor',      nombre: 'Conductor de Ambulancias',             grupo_profesional: 'operativo',       salario_base_mensual: 1816.00 },
  { id: 'mecanico',       nombre: 'Mecánico',                             grupo_profesional: 'mantenimiento',   salario_base_mensual: 1741.00 },
  { id: 'auxiliar-admin', nombre: 'Auxiliar Administrativo',              grupo_profesional: 'administrativo',  salario_base_mensual: 1612.00 },
  { id: 'telefonista',    nombre: 'Telefonista / Despachador',            grupo_profesional: 'administrativo',  salario_base_mensual: 1627.00 },
  { id: 'ayudante',       nombre: 'Ayudante / Camillero',                 grupo_profesional: 'operativo',       salario_base_mensual: 1577.00 },
];

// Pluses del II Convenio CLM — importes 2026 estimados (IPC ~38% sobre 2010)
const PLUSES = [
  { id: 'transporte',       nombre: 'Plus de Transporte',               tipo: 'fijo',       importe: 138.00, base_calculo: 'mes',                 nota: 'Art. 18 — 11 meses/año' },
  { id: 'nocturnidad',      nombre: 'Nocturnidad (22h-6h)',             tipo: 'porcentaje', importe: 10.0,   base_calculo: 'salario_base_hora',   nota: 'Art. 21 — 10% s/ salario base + pluses' },
  { id: 'dieta-comida',     nombre: 'Dieta de Comida',                  tipo: 'fijo',       importe: 16.70,  base_calculo: 'servicio',            nota: 'Art. 17' },
  { id: 'dieta-cena',       nombre: 'Dieta de Cena',                    tipo: 'fijo',       importe: 16.70,  base_calculo: 'servicio',            nota: 'Art. 17' },
  { id: 'dieta-pernocta',   nombre: 'Pernocta y Desayuno',              tipo: 'fijo',       importe: 25.00,  base_calculo: 'servicio',            nota: 'Art. 17' },
  { id: 'festivo-especial', nombre: 'Plus Festividades Especiales',     tipo: 'fijo',       importe: 50.00,  base_calculo: 'dia_festivo',         nota: 'Art. 23 — 24,25,31 dic; 1 ene; J.Santo; V.Santo' },
  { id: 'alim-urgencias',   nombre: 'Complemento Alimenticio Urgencias', tipo: 'fijo',      importe: 104.00, base_calculo: 'mes',                 nota: 'Art. 20 — exclusivo urgencias/emergencias' },
  { id: 'uniformidad',      nombre: 'Plus Complemento Uniformidad',     tipo: 'fijo',       importe: 138.00, base_calculo: 'anual',               nota: 'Art. 19 — pago único anual' },
  { id: 'localizacion',     nombre: 'Dispositivo de Localización',      tipo: 'fijo',       importe: 55.00,  base_calculo: 'dia_localizacion',    nota: 'Art. 22' },
];

// ── FICHAJES — lunes de esta semana hasta hoy ────────────────────────────────
function diasDesdeLunes() {
  const dias = [];
  const diaSemana = hoy.getDay() === 0 ? 6 : hoy.getDay() - 1; // 0=lun
  for (let i = 0; i <= diaSemana; i++) {
    const d = new Date(hoy);
    d.setDate(hoy.getDate() - diaSemana + i);
    dias.push(d);
  }
  return dias;
}

function fichajesDia(empleadoId, fecha, entradaH, entradaM, salidaH, salidaM, nocturno = false) {
  const entrada = new Date(fecha);
  entrada.setHours(entradaH, entradaM, 0);
  const salida = new Date(fecha);
  if (nocturno) salida.setDate(salida.getDate() + 1); // turno noche: salida al día siguiente
  salida.setHours(salidaH, salidaM, 0);
  const minutos = (salida - entrada) / 60000;
  const nombreEmp = EMPLEADOS.find(e => e.id === empleadoId)?.nombre ?? '';
  return {
    empleado_id:     empleadoId,   // campo que usa fichaje_service.dart
    empleado_nombre: nombreEmp,
    fecha: fmt(fecha),
    entrada: ts(entrada),
    salida: ts(salida),
    minutos_trabajados: minutos,
    tipo: 'normal',
    estado: 'completado',
    es_correccion: false,
    origen: 'demo',
    es_demo: true,
  };
}

// ════════════════════════════════════════════════════════════════════════════
// FUNCIONES
// ════════════════════════════════════════════════════════════════════════════

async function crearOIniciarSesionAuth() {
  console.log(`\n🔐 Creando Auth: ${DEMO_EMAIL}...`);
  try {
    const user = await auth.createUser({
      email:         DEMO_EMAIL,
      password:      DEMO_PASSWORD,
      displayName:   'Coordinador Sysday Demo',
      emailVerified: true,
    });
    console.log(`✅ Usuario Auth creado — UID: ${user.uid}`);
    return user.uid;
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const user = await auth.getUserByEmail(DEMO_EMAIL);
      console.log(`ℹ️  Auth ya existía — UID: ${user.uid}`);
      return user.uid;
    }
    throw e;
  }
}

async function crearAuthEmpleados() {
  console.log('\n🔐 Creando Auth para empleados demo (para pruebas de firma)...');
  const empleadosAuth = [
    { email: 'elena.martin@fluixtest.com',  password: 'ElenaTES2026',   nombre: 'Elena Martín Sanz',    id: 'amb_emp_001' },
    { email: 'roberto.lopez@fluixtest.com', password: 'RobertoConduTES', nombre: 'Roberto López Vega', id: 'amb_emp_002' },
  ];

  for (const emp of empleadosAuth) {
    try {
      let user;
      try {
        user = await auth.createUser({ email: emp.email, password: emp.password, displayName: emp.nombre, emailVerified: true });
        console.log(`✅ Auth empleado: ${emp.email} — UID: ${user.uid}`);
      } catch (e) {
        if (e.code === 'auth/email-already-exists') {
          user = await auth.getUserByEmail(emp.email);
          console.log(`ℹ️  Auth ya existía: ${emp.email} — UID: ${user.uid}`);
        } else throw e;
      }
      // Actualizar el doc de Firestore con el UID real de Auth
      const snap = await db.collection('usuarios').doc(emp.id).get();
      if (snap.exists && snap.data().uid !== user.uid) {
        // Crear doc con el UID real si es diferente al ID artificial
        await db.collection('usuarios').doc(user.uid).set({
          ...snap.data(),
          uid: user.uid,
          empresa_id: EMPRESA_ID,
        });
        console.log(`  → Doc Firestore actualizado para UID real: ${user.uid}`);
      }
    } catch (e) {
      console.warn(`⚠️  Error creando auth para ${emp.email}: ${e.message}`);
    }
  }
}

async function crearEmpresa(uid) {
  console.log('\n🏢 Configurando empresa...');
  const ref = db.collection('empresas').doc(EMPRESA_ID);
  await ref.set({
    nombre:                'Sanir Transporte Sanitario CLM',
    cif:                   'B45000001',
    correo:                DEMO_EMAIL,
    telefono:              '+34 925 220 100',
    direccion:             'Polígono Industrial, C/ Industria 1, 45001 Toledo',
    ciudad:                'Toledo',
    provincia:             'Toledo',
    descripcion:           'Empresa de transporte sanitario urgente y no urgente en Castilla-La Mancha',
    categoria:             'Transporte Sanitario',
    sector:                'ambulancia',
    tipo_negocio:          'transporte_sanitario',
    propietario_uid:       uid,
    onboarding_completado: true,
    activa:                true,
    es_demo:               true,
    fecha_creacion:        ts(hoy),
  }, { merge: true });

  // Usuario admin
  await db.collection('usuarios').doc(uid).set({
    nombre:       'Coordinador Demo',
    correo:       DEMO_EMAIL,
    telefono:     '+34 925 220 100',
    rol:          'admin',
    empresa_id:   EMPRESA_ID,
    activo:       true,
    es_demo:      true,
    puesto:       'Coordinador de Operaciones',
    departamento: 'Administración',
    fecha_creacion: hoy.toISOString(),
    datos_nomina: {
      salario_bruto_anual: 28000.0,
      tipo_contrato:       'indefinido',
      num_pagas:           14,
      horas_semanales:     40.0,
      sector_empresa:      'ambulancia',
      nif:                 '00000000T',
      nss:                 '190000000000',
      situacion_familiar:  'casado',
      num_hijos:           1,
      num_hijos_menores_3: 0,
      discapacidad:        false,
      pagas_prorrateadas:  false,
    },
  }, { merge: true });

  // Módulos
  await ref.collection('configuracion').doc('modulos').set({
    modulos: [
      { id: 'dashboard',    activo: true },
      { id: 'empleados',    activo: true },
      { id: 'nominas',      activo: true },
      { id: 'facturacion',  activo: true },
      { id: 'tareas',       activo: true },
      { id: 'clientes',     activo: true },
    ],
    ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Suscripción
  await ref.collection('suscripcion').doc('actual').set({
    estado:         'ACTIVA',
    plan:           'enterprise',
    plan_base:      'basico',
    packs_activos:  ['gestion', 'fiscal'],
    addons_activos: ['nominas', 'tareas'],
    es_demo:        true,
    precio_total:   0,
    fecha_inicio:   ts(hoy),
    fecha_fin:      ts(new Date(hoy.getFullYear() + 1, hoy.getMonth(), hoy.getDate())),
    aviso_enviado:  false,
  }, { merge: true });

  console.log('✅ Empresa y usuario admin configurados');
}

async function crearEmpleados() {
  console.log('\n👥 Creando 5 empleados...');
  const batch = db.batch();
  for (const emp of EMPLEADOS) {
    const ref = db.collection('usuarios').doc(emp.id);
    batch.set(ref, {
      nombre:       emp.nombre,
      correo:       emp.correo,
      telefono:     '',
      rol:          'staff',
      empresa_id:   EMPRESA_ID,
      activo:       true,
      es_demo:      true,
      puesto:       emp.puesto,
      departamento: emp.departamento,
      dni:          emp.dni,
      nss:          emp.nss,
      iban:         emp.iban,
      fecha_alta:   ts(emp.fecha_alta),
      fecha_creacion: hoy.toISOString(),
      datos_nomina: {
        salario_bruto_anual:  emp.salario_bruto_anual,
        tipo_contrato:        emp.tipo_contrato,
        num_pagas:            emp.num_pagas,
        horas_semanales:      emp.horas_semanales,
        sector_empresa:       'ambulancia',
        convenio_codigo_cat:  emp.categoria_convenio,
        nif:                  emp.dni,
        nss:                  emp.nss,
        situacion_familiar:   emp.situacion_familiar,
        num_hijos:            emp.num_hijos,
        num_hijos_menores_3:  0,
        discapacidad:         false,
        complemento_fijo:     0,
        pagas_prorrateadas:   false,
      },
    });
  }
  await batch.commit();
  console.log(`✅ ${EMPLEADOS.length} empleados creados`);
}

async function seedConvenio() {
  console.log('\n📋 Sembrando convenio CLM ambulancias en Firestore...');
  const convenioRef = db.collection('convenios').doc(CONVENIO_ID);
  const batch = db.batch();

  batch.set(convenioRef, CONVENIO_DATA, { merge: true });

  for (const cat of CATEGORIAS) {
    const catDoc = {
      ...cat,
      salario_anual:   cat.salario_base_mensual * 14,
      num_pagas:       14,
      hora_ordinaria:  (cat.salario_base_mensual * 14) / HORAS_ANUALES,
    };
    batch.set(convenioRef.collection('categorias').doc(cat.id), catDoc, { merge: true });
  }

  for (const plus of PLUSES) {
    batch.set(convenioRef.collection('pluses').doc(plus.id), plus, { merge: true });
  }

  await batch.commit();
  console.log('✅ Convenio creado — 11 categorías, 9 pluses');
}

// ── CONFIGURACIÓN HORARIOS POR EMPLEADO ──────────────────────────────────────
// Se guarda en empresas/{id}/empleados_fichaje/{empleadoId}
// Estructura idéntica a la que crea fichaje_service.dart (registrarEmpleado)
const HORARIOS_EMPLEADOS = [
  {
    id: 'amb_emp_001',
    nombre: 'Elena Martín Sanz',
    jornada_diaria: 720,            // 12h en minutos
    horario_entrada: '07:00',
    horario_salida: '19:00',
    dias_laborables: [true, true, true, true, true, true, true], // todos
  },
  {
    id: 'amb_emp_002',
    nombre: 'Roberto López Vega',
    jornada_diaria: 720,
    horario_entrada: '07:00',
    horario_salida: '19:00',
    dias_laborables: [true, true, true, true, true, true, true],
  },
  {
    id: 'amb_emp_003',
    nombre: 'Carmen Ruiz Molina',
    jornada_diaria: 720,            // turno noche 19h→7h (+1 día)
    horario_entrada: '19:00',
    horario_salida: '07:00',        // salida al día siguiente
    dias_laborables: [true, true, true, true, true, true, true],
  },
  {
    id: 'amb_emp_004',
    nombre: 'Javier Torres Pérez',
    jornada_diaria: 420,            // 7h
    horario_entrada: '08:00',
    horario_salida: '15:00',
    dias_laborables: [true, true, true, true, true, false, false],
  },
  {
    id: 'amb_emp_005',
    nombre: 'Laura González Díaz',
    jornada_diaria: 360,            // 6h
    horario_entrada: '08:30',
    horario_salida: '14:30',
    dias_laborables: [true, true, true, true, true, false, false],
  },
];

async function crearConfiguracionFichajes() {
  console.log('\n📅 Configurando horarios por empleado...');
  const batch = db.batch();
  const fichajeRef = db.collection('empresas').doc(EMPRESA_ID).collection('empleados_fichaje');

  for (const h of HORARIOS_EMPLEADOS) {
    batch.set(fichajeRef.doc(h.id), {
      empleado_id:    h.id,
      nombre:         h.nombre,
      empresa_id:     EMPRESA_ID,
      activo:         true,
      jornada_diaria: h.jornada_diaria,
      horario_entrada: h.horario_entrada,
      horario_salida:  h.horario_salida,
      dias_laborables: h.dias_laborables,
      actualizado_at:  admin.firestore.FieldValue.serverTimestamp(),
      es_demo:        true,
    }, { merge: true });
  }

  await batch.commit();
  console.log(`✅ Horarios configurados — ${HORARIOS_EMPLEADOS.length} empleados`);
}

async function crearFichajesSemana() {
  console.log('\n⏱️  Creando fichajes de la semana...');
  const dias = diasDesdeLunes();
  const batch = db.batch();
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  // Turnos por empleado (ambulancia: 12h mañana / 12h noche / jornada oficina)
  const turnos = [
    { id: 'amb_emp_001', hI: 7,  mI: 0,  hS: 19, mS: 0,  nocturno: false }, // Elena — turno mañana
    { id: 'amb_emp_002', hI: 7,  mI: 15, hS: 19, mS: 10, nocturno: false }, // Roberto — turno mañana
    { id: 'amb_emp_003', hI: 19, mI: 0,  hS: 7,  mS: 0,  nocturno: true  }, // Carmen — turno noche (+1 día)
    { id: 'amb_emp_004', hI: 8,  mI: 0,  hS: 15, mS: 0,  nocturno: false }, // Javier — jornada 7h
    { id: 'amb_emp_005', hI: 8,  mI: 30, hS: 14, mS: 30, nocturno: false }, // Laura — jornada oficina
  ];

  for (const dia of dias) {
    const esFin = dia.getDay() === 0 || dia.getDay() === 6;
    for (const t of turnos) {
      if (esFin && t.id === 'amb_emp_005') continue; // admin no trabaja fines
      const esHoy = fmt(dia) === HOY_STR;
      const fichaje = fichajesDia(t.id, dia, t.hI, t.mI, t.hS, t.mS, t.nocturno);
      if (esHoy) {
        // Hoy solo entrada (turno en curso)
        delete fichaje.salida;
        delete fichaje.minutos_trabajados;
        fichaje.estado = 'en_curso';
      }
      const ref = empresaRef.collection('fichajes').doc();
      batch.set(ref, fichaje);
    }
  }

  await batch.commit();
  console.log(`✅ Fichajes creados — ${dias.length} días × ${EMPLEADOS.length} empleados`);
}

async function crearNominasOctubre() {
  console.log('\n💰 Generando nóminas octubre 2026 (pre-calculadas)...');
  const batch = db.batch();
  const mesRef = db.collection('empresas').doc(EMPRESA_ID).collection('nominas');

  const nominasDatos = [
    { empId: 'amb_emp_001', nombre: 'Elena Martín Sanz',   bruto: 21873.04 / 14, irpf_pct: 12.0 },
    { empId: 'amb_emp_002', nombre: 'Roberto López Vega',  bruto: 18229.26 / 14, irpf_pct:  8.5 },
    { empId: 'amb_emp_003', nombre: 'Carmen Ruiz Molina',  bruto: 24043.60 / 14, irpf_pct: 15.0 },
    { empId: 'amb_emp_004', nombre: 'Javier Torres Pérez', bruto: 18330.48 / 14, irpf_pct: 10.0 },
    { empId: 'amb_emp_005', nombre: 'Laura González Díaz', bruto: 16800.00 / 14, irpf_pct:  7.0 },
  ];

  for (const n of nominasDatos) {
    const bruto  = Math.round(n.bruto * 100) / 100;
    const ss_emp = Math.round(bruto * 0.0635 * 100) / 100; // 6,35% empleado
    const irpf   = Math.round(bruto * (n.irpf_pct / 100) * 100) / 100;
    const neto   = Math.round((bruto - ss_emp - irpf) * 100) / 100;

    const ref = mesRef.doc(`${n.empId}_2026_10`);
    batch.set(ref, {
      empleado_uid:  n.empId,
      empleado_nombre: n.nombre,
      mes:           10,
      anio:          2026,
      mes_str:       '2026-10',
      salario_bruto: bruto,
      ss_empleado:   ss_emp,
      irpf:          irpf,
      salario_neto:  neto,
      estado:        'generada',
      es_demo:       true,
      fecha_generacion: ts(hoy),
    });
  }

  await batch.commit();
  console.log(`✅ ${nominasDatos.length} nóminas de octubre generadas`);
}

async function limpiarDemoAnterior() {
  console.log('\n🧹 Limpiando datos demo anteriores...');
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  async function borrar(query) {
    const snap = await query.get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  }

  async function borrarColeccion(colRef) {
    const snap = await colRef.get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  }

  const n1 = await borrar(empresaRef.collection('fichajes').where('es_demo', '==', true));
  const n2 = await borrar(empresaRef.collection('nominas').where('es_demo', '==', true));
  const n3 = await borrarColeccion(empresaRef.collection('empleados_fichaje'));

  // Empleados demo anteriores
  for (const emp of EMPLEADOS) {
    await db.collection('usuarios').doc(emp.id).delete().catch(() => {});
  }

  console.log(`✅ Limpieza: ${n1} fichajes, ${n2} nóminas, ${n3} horarios eliminados`);
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log('\n🚑 SEED DEMO AMBULANCIAS — SANIR / CASTILLA-LA MANCHA');
  console.log(`📦 Empresa ID : ${EMPRESA_ID}`);
  console.log(`📧 Email      : ${DEMO_EMAIL}`);
  console.log(`🔑 Password   : ${DEMO_PASSWORD}`);
  console.log(`📅 Fecha hoy  : ${HOY_STR}\n`);

  try {
    await limpiarDemoAnterior();
    const uid = await crearOIniciarSesionAuth();
    await crearEmpresa(uid);
    await crearEmpleados();
    await crearAuthEmpleados();
    await seedConvenio();
    await crearConfiguracionFichajes();
    await crearFichajesSemana();
    await crearNominasOctubre();

    console.log('\n✅ ¡Cuenta demo lista!\n');
    console.log('📊 Resumen:');
    console.log(`   • Auth : ${DEMO_EMAIL} / ${DEMO_PASSWORD}`);
    console.log(`   • Empresa: "Sanir Transporte Sanitario CLM" (Toledo)`);
    console.log(`   • Sector: ambulancia (II Convenio CLM, ultraactividad 2026)`);
    console.log(`   • 5 empleados: 2 Conductores, ATS, Jefe de Equipo, Auxiliar Admin`);
    console.log(`   • Convenio CLM: 11 categorías + 9 pluses en Firestore (tablas 2026 est.)`);
    console.log(`   • Horas anuales: 1800h (Art. 22 — personal de movimiento)`);
    console.log(`   • Fichajes: semana actual (turnos de 12h)`);
    console.log(`   • Nóminas oct 2026: 5 nóminas pre-calculadas`);
    console.log('\n🎯 Flujo demo recomendado:');
    console.log('   1. Login con la cuenta demo');
    console.log('   2. Módulo Empleados → muestra ficha TES con categoría de convenio');
    console.log('   3. Módulo Nóminas → Este Mes → genera nómina de Elena (TES Nivel I)');
    console.log('   4. Módulo Fichajes → Informe mensual → turnos de 12h');
    console.log('   5. Portal Empleado (móvil) → Mis Horas + Vacaciones');
    console.log('   6. Módulo Facturación → Factura de servicio sanitario\n');
  } catch (e) {
    console.error('\n❌ Error:', e.message || e);
    process.exit(1);
  }
  process.exit(0);
}

main();
