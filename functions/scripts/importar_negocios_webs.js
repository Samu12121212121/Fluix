/**
 * IMPORTAR NEGOCIOS DESDE WEBS → negocios_publicos
 *
 * 4 negocios con fichas completas extraídas de sus webs (oct 2026).
 * Estructura basada en plantilla Excel: Info, Contacto, Horario, Servicios, Extras, Formulario.
 *
 * Ejecutar: node scripts/importar_negocios_webs.js
 * Requisitos: serviceAccountKey.json en functions/
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const NEGOCIOS = [

  // ═══════════════════════════════════════════════════════════════
  // 1. LAUDE SERVIBELLEZA — servibelleza.es
  // ═══════════════════════════════════════════════════════════════
  {
    id: 'laude_servibelleza',

    // ── INFO ──────────────────────────────────────────────────────
    nombre: 'Laude Servibelleza',
    tagline: 'Sentirse mejor es la clave',
    descripcion: 'Centro de belleza y estética especializado en tratamientos personalizados de belleza facial y corporal. Uno de los salones más recomendados de Guadalajara y el corredor del Henares, con más de 10 años de experiencia.',
    descripcionCorta: 'Salón de belleza y estética en Guadalajara',
    categoria: 'esteticas',
    subcategorias: ['Medicina estética', 'Depilación láser', 'Tratamientos faciales', 'Tratamientos corporales'],
    especialidades: [
      'Tratamientos corporales', 'Tratamientos faciales', 'Medicina estética',
      'Depilación IPL fotodepilación', 'Peelings químicos', 'Mesoterapia',
      'Skin boosters', 'Tratamiento de melasma', 'Tratamiento de varices',
      'Tratamiento de bolsas y ojeras', 'Tratamiento capilar',
    ],
    serviciosDestacados: ['Skin Booster', 'Depilación IPL', 'Mesoterapia', 'Peeling químico'],

    // ── CONTACTO ──────────────────────────────────────────────────
    telefono: '640084004',
    whatsapp: '640084004',
    email: 'laude@servibelleza.es',
    emailPublico: 'laude@servibelleza.es',
    web: 'https://www.servibelleza.es/',
    website: 'https://www.servibelleza.es/',
    instagram: 'laude_guadalajara_',
    facebook: 'laude.servibelleza',
    direccion: 'Blvr. de Entrepeñas, 8, 19005 Guadalajara',
    calle: 'Blvr. de Entrepeñas',
    numero: '8',
    codigoPostal: '19005',
    localidad: 'Guadalajara',
    provincia: 'Guadalajara',

    // ── HORARIO (L-V continuo, fin de semana no publicado) ────────
    horario: {
      Lunes:     { apertura: '09:30', cierre: '19:30', cerrado: false },
      Martes:    { apertura: '09:30', cierre: '19:30', cerrado: false },
      Miércoles: { apertura: '09:30', cierre: '19:30', cerrado: false },
      Jueves:    { apertura: '09:30', cierre: '19:30', cerrado: false },
      Viernes:   { apertura: '09:30', cierre: '19:30', cerrado: false },
      Sábado:    { cerrado: true },
      Domingo:   { cerrado: true },
    },

    // ── SERVICIOS (bonos con precio confirmado en web) ────────────
    // Nota: precios son por bono/pack, no sesión individual
    camposPersonalizados: [
      { id: 'bono_vitaminas',         label: 'Vitaminas (3 sesiones)',               tipo: 'texto', obligatorio: false },
      { id: 'bono_doble_menton',      label: 'Doble mentón (3 sesiones)',            tipo: 'texto', obligatorio: false },
      { id: 'bono_varices',           label: 'Varices (4 sesiones)',                 tipo: 'texto', obligatorio: false },
      { id: 'bono_peeling_quimico',   label: 'Peeling químico (3 sesiones)',         tipo: 'texto', obligatorio: false },
      { id: 'bono_mesoterapia',       label: 'Mesoterapia (5 sesiones)',             tipo: 'texto', obligatorio: false },
      { id: 'bono_bolsas_ojos',       label: 'Bolsas ojos (3 sesiones)',             tipo: 'texto', obligatorio: false },
      { id: 'bono_capilar',           label: 'Capilar (7 sesiones)',                 tipo: 'texto', obligatorio: false },
      { id: 'bono_top_laude',         label: 'Top Laude',                            tipo: 'texto', obligatorio: false },
      { id: 'bono_alidya',            label: 'Alidya (3 sesiones)',                  tipo: 'texto', obligatorio: false },
      { id: 'bono_skin_booster',      label: 'Skin Booster (3 sesiones)',            tipo: 'texto', obligatorio: false },
      { id: 'bono_skin_booster_cce',  label: 'Skin Booster cuello/escote (3 ses.)', tipo: 'texto', obligatorio: false },
      { id: 'bono_melasma',           label: 'Tratamiento melasma',                  tipo: 'texto', obligatorio: false },
      { id: 'bono_peeling_ojera',     label: 'Peeling ojeras (2 sesiones)',          tipo: 'texto', obligatorio: false },
    ],

    // ── EXTRAS ────────────────────────────────────────────────────
    aceptaTarjeta: null,          // no verificado
    tieneParking: null,           // no verificado
    accesibleSillaRuedas: null,   // no verificado
    tieneWifi: null,              // no verificado
    admiteMascotas: null,         // no verificado
    tieneTerraza: null,           // no aplica / no verificado

    // ── FORMULARIO ────────────────────────────────────────────────
    formularioTitulo: 'Contacta con Laude Servibelleza',
    formularioBoton: 'Contacta con nosotras',
    atencionConCita: true,

    // ── EXTRAS SISTEMA ────────────────────────────────────────────
    activo: true,
    empresaIdVinculada: '',
    destacado: false,
    reservasOnlineActivas: false,   // verificar antes de activar
  },

  // ═══════════════════════════════════════════════════════════════
  // 2. CRISTINA AGUILERA AESTHETIC — cristinaguileraesthetic.es
  // ═══════════════════════════════════════════════════════════════
  {
    id: 'cristina_aguilera_aesthetic',

    // ── INFO ──────────────────────────────────────────────────────
    nombre: 'Cristina Aguilera Aesthetic',
    tagline: 'Salud & Belleza',
    descripcion: 'Clínica multidisciplinar de medicina estética en Guadalajara con tratamientos personalizados. El equilibrio perfecto entre belleza, salud y bienestar, con formación profesional continua y tecnología de última generación como HIFU 7D y Morpheus 8.',
    descripcionCorta: 'Clínica de medicina estética multidisciplinar en Guadalajara',
    categoria: 'clinicas',
    subcategorias: ['Medicina estética', 'Micropigmentación', 'Aparatología', 'Tratamientos capilares'],
    especialidades: [
      'Higiene facial profunda',
      'Radiofrecuencia',
      'HIFU 7D novena generación',
      'Morpheus 8',
      'Microblading',
      'Micropigmentación',
      'Presoterapia',
      'Electroestimulación',
      'Dermapen',
      'Nanopore',
      'Tratamientos capilares dermatológicos',
      'Tratamientos corporales personalizados',
    ],
    serviciosDestacados: ['HIFU 7D', 'Morpheus 8', 'Microblading', 'Radiofrecuencia'],

    // ── CONTACTO ──────────────────────────────────────────────────
    telefono: '659780980',
    whatsapp: '+34659780980',
    email: 'clinica@cristinaguileraesthetic.es',
    emailPublico: 'clinica@cristinaguileraesthetic.es',
    web: 'http://cristinaguileraesthetic.es/',
    website: 'http://cristinaguileraesthetic.es/',
    instagram: 'clinica.cristinaaguilera',
    facebook: 'clinica.cristinaaguilera',
    direccion: 'Plaza Pablo Iglesias, 4, 19001 Guadalajara',
    calle: 'Plaza Pablo Iglesias',
    numero: '4',
    codigoPostal: '19001',
    localidad: 'Guadalajara',
    provincia: 'Guadalajara',

    // ── HORARIO (no publicado en web — pendiente verificar) ───────
    horario: null,

    // ── EXTRAS ────────────────────────────────────────────────────
    aceptaTarjeta: null,          // no verificado
    tieneParking: null,           // no verificado
    accesibleSillaRuedas: null,
    tieneWifi: null,
    admiteMascotas: null,
    tieneTerraza: null,

    // ── RESEÑAS ───────────────────────────────────────────────────
    ratingGoogle: 5.0,
    numResenas: 40,

    // ── FORMULARIO ────────────────────────────────────────────────
    formularioTitulo: 'Agenda tu cita en Cristina Aguilera Aesthetic',
    formularioBoton: 'Agenda tu cita',
    atencionConCita: true,

    activo: true,
    empresaIdVinculada: '',
    destacado: false,
    reservasOnlineActivas: false,
  },

  // ═══════════════════════════════════════════════════════════════
  // 3. CLÍNICA CARLOS GÓMEZ (sede Guadalajara) — clinicacarlosgomez.com
  // ═══════════════════════════════════════════════════════════════
  {
    id: 'clinica_carlos_gomez_guadalajara',

    // ── INFO ──────────────────────────────────────────────────────
    nombre: 'Clínica Carlos Gómez',
    tagline: 'Un buen resultado debe mantener naturalidad',
    descripcion: 'Clínica de medicina estética y antienvejecimiento en Guadalajara. El Dr. Carlos Gómez, médico cirujano y formador internacional, combina técnicas de rejuvenecimiento mínimamente invasivas con resultados 100% naturales.',
    descripcionCorta: 'Medicina estética y antienvejecimiento en Guadalajara',
    categoria: 'clinicas',
    subcategorias: ['Medicina estética', 'Antienvejecimiento', 'Depilación láser', 'Rinomodelación'],
    especialidades: [
      'Fillers', 'Inductores de colágeno', 'Hilos de lifting', 'Firmeza facial',
      'Tratamiento de manchas', 'Rinomodelación', 'Limpieza facial', 'Maderoterapia',
      'Presoterapia', 'Body Shappe', 'Depilación eléctrica', 'Depilación láser',
    ],
    serviciosDestacados: ['Fillers', 'Hilos de lifting', 'Rinomodelación', 'Inductores de colágeno'],

    // ── CONTACTO ──────────────────────────────────────────────────
    telefono: '626655618',
    whatsapp: null,               // no publicado
    email: 'guadalajara@clinicacarlosgomez.com',
    emailPublico: 'guadalajara@clinicacarlosgomez.com',
    web: 'https://clinicacarlosgomez.com/',
    website: 'https://clinicacarlosgomez.com/',
    instagram: 'clinicacarlosgomez',
    facebook: 'clinicacarlosgomez',
    direccion: 'Calle Virgen del Amparo, 44, 19002 Guadalajara',
    calle: 'Calle Virgen del Amparo',
    numero: '44',
    codigoPostal: '19002',
    localidad: 'Guadalajara',
    provincia: 'Guadalajara',

    // ── HORARIO (no publicado en web — pendiente verificar) ───────
    horario: null,

    // ── EXTRAS ────────────────────────────────────────────────────
    aceptaTarjeta: null,
    tieneParking: null,
    accesibleSillaRuedas: null,
    tieneWifi: null,
    admiteMascotas: null,
    tieneTerraza: null,

    // ── FORMULARIO ────────────────────────────────────────────────
    formularioTitulo: '¿Hablamos?',
    formularioBoton: 'Enviar mensaje',
    atencionConCita: true,

    activo: true,
    empresaIdVinculada: '',
    destacado: false,
    reservasOnlineActivas: false,
  },

  // ═══════════════════════════════════════════════════════════════
  // 4. MEDICINA ESTÉTICA GLOW — medicinaesteticaglow.es
  // ═══════════════════════════════════════════════════════════════
  {
    id: 'medicina_estetica_glow',

    // ── INFO ──────────────────────────────────────────────────────
    nombre: 'Medicina Estética Glow',
    tagline: 'Hacemos realidad la belleza que te inspira',
    descripcion: 'Centro integral de medicina estética en Guadalajara con tratamientos faciales y corporales apoyados en tecnología avanzada. Integra servicios de salud mental, nutrición y psicología, reconociendo la conexión entre el bienestar emocional y la belleza.',
    descripcionCorta: 'Centro integral de medicina estética en Guadalajara',
    categoria: 'clinicas',
    subcategorias: ['Medicina estética', 'Microblading', 'Depilación láser', 'Nutrición y psicología'],
    especialidades: [
      'Estética avanzada', 'Medicina estética', 'Microblading', 'Micropigmentación',
      'Depilación láser', 'Nutrición', 'Psicología', 'Psiquiatría',
      'Rejuvenecimiento facial', 'Liposucción sin cirugía', 'Eliminación de manchas y acné',
    ],
    serviciosDestacados: ['Medicina estética', 'Depilación láser', 'Microblading', 'Nutrición'],

    // ── CONTACTO ──────────────────────────────────────────────────
    telefono: '949211172',
    whatsapp: null,               // mencionado pero sin número verificado
    email: 'asanchez@medicinaesteticaglow.es',
    emailPublico: 'asanchez@medicinaesteticaglow.es',
    web: 'https://medicinaesteticaglow.es/',
    website: 'https://medicinaesteticaglow.es/',
    instagram: null,              // no publicado en web
    facebook: null,               // no publicado en web
    direccion: 'Calle Virgen de la Soledad 3A 1º, 19003 Guadalajara',
    calle: 'Calle Virgen de la Soledad',
    numero: '3A',
    codigoPostal: '19003',
    localidad: 'Guadalajara',
    provincia: 'Guadalajara',
    latitud: 40.627367,
    longitud: -3.166038,

    // ── HORARIO (no publicado en web — pendiente verificar) ───────
    horario: null,

    // ── EXTRAS ────────────────────────────────────────────────────
    aceptaTarjeta: null,
    tieneParking: null,
    accesibleSillaRuedas: null,
    tieneWifi: null,
    admiteMascotas: null,
    tieneTerraza: null,

    // ── FORMULARIO ────────────────────────────────────────────────
    formularioTitulo: '¿En qué te podemos ayudar?',
    formularioBoton: 'Contactar',
    atencionConCita: true,

    activo: true,
    empresaIdVinculada: '',
    destacado: false,
    reservasOnlineActivas: false,
  },
];

// ── Limpia nulls para no escribir campos vacíos en Firestore ─────────────
function limpiarNulos(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== null && v !== undefined)
  );
}

async function main() {
  console.log(`\n🚀 Importando ${NEGOCIOS.length} negocios a negocios_publicos...\n`);
  let creados = 0, actualizados = 0, errores = 0;

  for (const n of NEGOCIOS) {
    try {
      const ref = db.collection('negocios_publicos').doc(n.id);
      const snap = await ref.get();
      const { id, ...datos } = limpiarNulos(n);

      if (snap.exists) {
        const existente = snap.data();
        const patch = {};
        for (const [k, v] of Object.entries(datos)) {
          if (existente[k] == null || existente[k] === '' || existente[k] === false) {
            patch[k] = v;
          }
        }
        if (Object.keys(patch).length > 0) {
          await ref.update(patch);
          console.log(`✏️  Actualizado: ${n.nombre} (${Object.keys(patch).length} campos nuevos)`);
        } else {
          console.log(`⏭️  Sin cambios: ${n.nombre}`);
        }
        actualizados++;
      } else {
        await ref.set({ ...datos, creadoEn: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`✅ Creado: ${n.nombre}`);
        creados++;
      }
    } catch (e) {
      console.error(`❌ Error en ${n.nombre}: ${e.message}`);
      errores++;
    }
  }

  console.log(`\n📊 Resumen: ${creados} creados · ${actualizados} actualizados · ${errores} errores`);
  process.exit(0);
}

main();
