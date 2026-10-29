/**
 * importar_negocios_guadalajara.js
 * 1. Borra los negocios de prueba (sin empresaIdVinculada) de negocios_publicos
 * 2. Importa los 21 negocios mas completos de Guadalajara
 *
 * USO:  node scripts/importar_negocios_guadalajara.js
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, "..", "credentials.json"))),
});
const db = admin.firestore();

// ─── Helpers ────────────────────────────────────────────────────────────────
function dia(abierto, apertura, cierre, aperturaT, cierreT) {
  const d = { abierto };
  if (apertura)  d.horaApertura = apertura;
  if (cierre)    d.horaCierre   = cierre;
  if (aperturaT) d.horaAperturaTarde = aperturaT;
  if (cierreT)   d.horaCierreTarde   = cierreT;
  return d;
}
// 0=Lunes … 6=Domingo
function horarioLV(ap, ci, apT, ciT) {
  const h = {};
  for (let i = 0; i <= 4; i++) h[i] = dia(true, ap, ci, apT || null, ciT || null);
  h[5] = dia(false); h[6] = dia(false);
  return h;
}

// ─── Datos ──────────────────────────────────────────────────────────────────
const NEGOCIOS = [
  // ── ESTETICA ──────────────────────────────────────────────────────────────
  {
    id: "belen_nogueras_estetica",
    nombre: "Belen Nogueras Estetica",
    tagline: "Los mejores cuidados naturales para tu belleza",
    descripcion: "Centro especializado en estetica facial y corporal en Aguas Vivas, Guadalajara. Destacado por productos ecologicos y naturales.",
    categoria: "esteticas",
    activo: true,
    telefono: "722 26 27 08", whatsapp: "722 26 27 08",
    web: "https://www.belennoguerasestetica.es",
    direccion: "Av. de Belena, 10, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 5.0, numResenas: 117,
    especialidades: ["Tratamientos faciales", "Limpiezas faciales", "Depilacion cera", "Diseno cejas", "Manicura", "Pedicura", "Masajes RITUAL SARTORI"],
    horarios: { ...horarioLV("10:00","14:00","16:00","19:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Av.+de+Belena+10%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Tratamientos faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Limpiezas faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Diseno y depilacion de cejas", categoria: "Diseno de la mirada", activo: true },
      { nombre: "Depilacion con cera", categoria: "Depilacion", activo: true },
      { nombre: "Manicura", categoria: "Estilo personal", activo: true },
      { nombre: "Pedicura", categoria: "Estilo personal", activo: true },
      { nombre: "Masajes RITUAL SARTORI", categoria: "Bienestar", activo: true },
    ],
  },
  {
    id: "clinica_medico_estetica_cristina_aguilera",
    nombre: "Clinica Medico Estetica Cristina Aguilera",
    tagline: "Medicina estetica con resultados naturales",
    descripcion: "Centro de medicina estetica facial en el barrio Centro de Guadalajara. Uno de los centros mejor valorados de la zona.",
    categoria: "clinicas",
    activo: true,
    telefono: "659 78 09 80", whatsapp: "659 78 09 80",
    web: "https://www.cristinaguileraesthetic.es",
    direccion: "Pl. de Pablo Iglesias, 4, 19001 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19001",
    ratingGoogle: 5.0, numResenas: 41,
    especialidades: ["Limpieza profunda facial", "Tratamientos antiinflamatorios", "Masajes esteticos", "Medicina estetica facial"],
    horarios: { ...horarioLV("10:00","14:00","16:00","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Pl.+Pablo+Iglesias+4%2C+19001+Guadalajara",
    servicios: [
      { nombre: "Limpieza profunda facial", categoria: "Belleza facial", activo: true },
      { nombre: "Tratamientos antiinflamatorios", categoria: "Belleza facial", activo: true },
      { nombre: "Masajes esteticos", categoria: "Bienestar", activo: true },
      { nombre: "Medicina estetica facial", categoria: "Medicina estetica", activo: true },
    ],
  },
  {
    id: "sensorial_estetica_avanzada",
    nombre: "Sensorial Estetica Avanzada",
    tagline: "Estetica avanzada con trato cercano",
    descripcion: "Centro de estetica avanzada en el barrio de Amistad, Guadalajara. Especializado en tratamientos antiedad y bio lifting Nazarov.",
    categoria: "esteticas",
    activo: true,
    telefono: "613 17 79 18", whatsapp: "613 17 79 18",
    web: "https://www.sensorialesteticaavanzada.com",
    direccion: "Av. de Castilla, 18, G, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 5.0, numResenas: 125,
    especialidades: ["Tratamientos faciales antiedad", "Bio lifting Nazarov", "Cavitacion", "Laser estetico", "Limpieza facial"],
    horarios: { ...horarioLV("10:00","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Av.+Castilla+18%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Tratamientos faciales antiedad", categoria: "Belleza facial", activo: true },
      { nombre: "Bio lifting Nazarov", categoria: "Belleza facial", activo: true },
      { nombre: "Cavitacion", categoria: "Belleza corporal", activo: true },
      { nombre: "Laser estetico", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
    ],
  },
  {
    id: "clinica_dra_ana_sanchez_dominguez",
    nombre: "Clinica Medicina Estetica Dra. Ana Sanchez Dominguez",
    tagline: "Medicina estetica con tecnicas novedosas",
    descripcion: "Clinica de medicina estetica facial en el Centro de Guadalajara. Especializada en tecnicas novedosas y actualizadas.",
    categoria: "clinicas",
    activo: true,
    telefono: "638 05 28 11", whatsapp: "638 05 28 11",
    web: "https://www.doctoraanasanchez.es",
    direccion: "C. Angel Martin Puebla, 5, local A, 19001 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19001",
    ratingGoogle: 4.9, numResenas: 32,
    especialidades: ["Medicina estetica facial", "Tecnicas de rejuvenecimiento"],
    horarios: {
      0: dia(true, "10:00","14:00"),
      1: dia(true, "16:00","20:00"),
      2: dia(true, "10:00","16:00"),
      3: dia(true, "10:00","14:00","17:00","20:00"),
      4: dia(true, "10:00","14:00"),
      5: dia(false), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Angel+Martin+Puebla+5%2C+19001+Guadalajara",
    servicios: [
      { nombre: "Medicina estetica facial", categoria: "Medicina estetica", activo: true },
      { nombre: "Rejuvenecimiento facial", categoria: "Medicina estetica", activo: true },
      { nombre: "Diagnostico / valoracion inicial", categoria: "Diagnostico", activo: true },
    ],
  },
  {
    id: "anatura_bioestetica",
    nombre: "Anatura Bioestetica",
    tagline: "Estetica y bienestar, tambien para pacientes oncologicos",
    descripcion: "Centro de estetica en El Fuerte, Guadalajara. Unico en la zona en asesoramiento y venta de pelucas y turbantes oncologicos.",
    categoria: "esteticas",
    activo: true,
    telefono: "653 15 57 74", whatsapp: "653 15 57 74",
    direccion: "C. del Arrabal del Agua, 1, local 2, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 4.9, numResenas: 40,
    especialidades: ["Tratamientos faciales", "Masajes", "Depilacion", "Asesoria oncologica", "Pelucas y turbantes oncologicos"],
    horarios: {
      0: dia(true, "10:00","13:00","16:30","19:00"),
      1: dia(true, "10:30","13:00","16:30","19:00"),
      2: dia(true, "10:00","13:00","16:30","19:00"),
      3: dia(true, "10:30","13:00","16:30","19:00"),
      4: dia(true, "10:00","13:00","16:30","19:00"),
      5: dia(false), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Arrabal+del+Agua+1%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Tratamientos faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Exfoliacion punta de diamante", categoria: "Belleza facial", activo: true },
      { nombre: "Masajes", categoria: "Bienestar", activo: true },
      { nombre: "Depilacion", categoria: "Depilacion", activo: true },
      { nombre: "Asesoria pelucas oncologicas", categoria: "Oncologia estetica", activo: true },
      { nombre: "Venta pelucas y turbantes oncologicos", categoria: "Oncologia estetica", activo: true },
    ],
  },
  {
    id: "beauty_by_patricia_guadalajara",
    nombre: "Beauty by Patricia",
    tagline: "Tu centro de belleza en Entrepeñas",
    descripcion: "Centro de estetica y medicina estetica en Aguas Vivas, Guadalajara. Uno de los centros mejor valorados de la zona.",
    categoria: "esteticas",
    activo: true,
    telefono: "673 81 17 68", whatsapp: "673 81 17 68",
    web: "https://www.beautyguadalajara.es",
    direccion: "Blvr. de Entrepeñas, 1, B, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 4.9, numResenas: 97,
    especialidades: ["Depilacion laser", "Manicura", "Tratamientos faciales", "Limpieza facial", "Medicina estetica facial"],
    horarios: {
      0: dia(true, "15:30","18:00"),
      1: dia(true, "10:00","18:00"),
      2: dia(true, "10:00","18:00"),
      3: dia(true, "10:00","18:00"),
      4: dia(true, "10:00","18:00"),
      5: dia(true, "10:00","13:00"),
      6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Blvr.+Entrepeñas+1%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Manicura", categoria: "Estilo personal", activo: true },
      { nombre: "Tratamientos faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
      { nombre: "Medicina estetica facial", categoria: "Medicina estetica", activo: true },
    ],
  },
  {
    id: "centro_estetica_alba_guadalajara",
    nombre: "Centro de Estetica Alba Guadalajara",
    tagline: "Estetica profesional con marcas de lujo",
    descripcion: "Centro de estetica en el barrio Amistad de Guadalajara. Trabaja con Natura Bisse, Maria Galland y Sothys. Equipa Indiba, LPG, cavitacion y presoterapia.",
    categoria: "esteticas",
    activo: true,
    telefono: "949 21 02 37", whatsapp: "949 21 02 37",
    web: "https://www.albaesteticaguadalajara.es",
    direccion: "C. de Rufino Blanco, 9, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 4.8, numResenas: 66,
    especialidades: ["Limpiezas faciales profundas", "Peeling quimico", "Indiba", "LPG", "Cavitacion", "Presoterapia", "Natura Bisse", "Maria Galland", "Sothys"],
    horarios: {
      ...horarioLV("10:00","19:00"),
      5: dia(true, "10:00","14:00"),
      6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Rufino+Blanco+9%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Limpieza facial profunda", categoria: "Belleza facial", activo: true },
      { nombre: "Peeling quimico", categoria: "Belleza facial", activo: true },
      { nombre: "Tratamiento con Indiba", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Tratamiento con LPG", categoria: "Belleza corporal", activo: true },
      { nombre: "Cavitacion", categoria: "Belleza corporal", activo: true },
      { nombre: "Presoterapia", categoria: "Bienestar", activo: true },
    ],
  },
  {
    id: "centro_estetica_avanzada_cleo",
    nombre: "Centro Estetica Avanzada Cleo",
    tagline: "Estetica avanzada en Las Cañas",
    descripcion: "Centro de estetica avanzada en Las Cañas, Guadalajara. Depilacion laser, ondas de choque, viora y tratamientos de piel de ultima generacion.",
    categoria: "esteticas",
    activo: true,
    telefono: "949 03 38 94", whatsapp: "949 03 38 94",
    web: "https://www.esteticacleo.es",
    direccion: "C. Federica Montseny, 4, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 4.8, numResenas: 49,
    especialidades: ["Depilacion laser", "Limpieza facial", "Ondas de choque", "Capsula facial BDR", "Viora", "Presoterapia", "Perfilado cejas"],
    horarios: { ...horarioLV("10:00","13:30","16:30","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Federica+Montseny+4%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
      { nombre: "Ondas de choque", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Capsula facial BDR", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Viora", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Presoterapia", categoria: "Bienestar", activo: true },
      { nombre: "Perfilado de cejas con hilo", categoria: "Diseno de la mirada", activo: true },
    ],
  },
  {
    id: "clinica_carlos_gomez_guadalajara",
    nombre: "Clinica Carlos Gomez",
    tagline: "Medicina estetica para resultados naturales",
    descripcion: "Clinica de medicina estetica en el Centro de Guadalajara. Especializada en acido hialuronico, botox y tecnicas de rejuvenecimiento.",
    categoria: "clinicas",
    activo: true,
    telefono: "949 25 73 28", whatsapp: "949 25 73 28",
    web: "https://www.clinicacarlosgomez.com",
    direccion: "C. Virgen del Amparo, 44, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 4.7, numResenas: 92,
    especialidades: ["Depilacion laser", "Acido hialuronico", "Toxina botulinica", "Colágeno", "Lipolaser", "Ellanse"],
    horarios: { ...horarioLV("10:00","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Virgen+del+Amparo+44%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Acido hialuronico", categoria: "Medicina estetica", activo: true },
      { nombre: "Toxina botulinica (Botox)", categoria: "Medicina estetica", activo: true },
      { nombre: "Tratamientos con colageno", categoria: "Medicina estetica", activo: true },
      { nombre: "Lipolaser", categoria: "Medicina estetica", activo: true },
      { nombre: "Ellanse", categoria: "Medicina estetica", activo: true },
    ],
  },
  {
    id: "gn_estetica_avanzada",
    nombre: "GN Estetica Avanzada",
    tagline: "Tratamientos faciales de vanguardia",
    descripcion: "Centro de estetica avanzada en Los Valles, Guadalajara. Especializado en mesoterapia, dermapen, Hollywood peel y reduccion de papada.",
    categoria: "esteticas",
    activo: true,
    telefono: "624 40 49 09", whatsapp: "624 40 49 09",
    web: "https://www.gnesteticaavanzada.com",
    direccion: "Av. Bulevar del Alto Tajo, 9, local 4, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 4.7, numResenas: 24,
    especialidades: ["Maderoterapia", "Limpieza facial", "Mesoterapia inyectada", "Dermapen", "Hollywood peel", "Plasma", "Tratamiento acne", "Reduccion papada"],
    horarios: { ...horarioLV("10:30","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Av.+Bulevar+Alto+Tajo+9%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Maderoterapia con masaje drenante", categoria: "Bienestar", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
      { nombre: "Mesoterapia inyectada", categoria: "Medicina estetica", activo: true },
      { nombre: "Dermapen", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Hollywood peel", categoria: "Belleza facial", activo: true },
      { nombre: "Plasma", categoria: "Medicina estetica", activo: true },
      { nombre: "Tratamiento para acne", categoria: "Belleza facial", activo: true },
      { nombre: "Reduccion de papada", categoria: "Medicina estetica", activo: true },
    ],
  },
  {
    id: "samira_salud_y_belleza",
    nombre: "Samira Salud y Belleza",
    tagline: "Salud, belleza y bienestar en un solo centro",
    descripcion: "Centro integral de salud y belleza en Constitucion, Guadalajara. Combina estetica avanzada, depilacion laser, peluqueria y pilates.",
    categoria: "esteticas",
    activo: true,
    telefono: "949 25 53 79", whatsapp: "949 25 53 79",
    web: "https://www.samirasaludybelleza.es",
    direccion: "Av. del Ejercito, 9A, 19004 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19004",
    ratingGoogle: 4.6, numResenas: 327,
    especialidades: ["Tratamientos faciales", "LPG", "Indiba", "Depilacion laser", "Lifting pestanas", "Pilates", "Peluqueria"],
    horarios: { ...horarioLV("10:00","20:00"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Av.+del+Ejercito+9A%2C+19004+Guadalajara",
    servicios: [
      { nombre: "Tratamiento facial punta de diamante", categoria: "Belleza facial", activo: true },
      { nombre: "Tratamiento con LPG", categoria: "Belleza facial", activo: true },
      { nombre: "Tratamiento con Indiba", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Lifting de pestanas", categoria: "Diseno de la mirada", activo: true },
      { nombre: "Pilates", categoria: "Bienestar", activo: true },
      { nombre: "Peluqueria", categoria: "Estilo personal", activo: true },
    ],
  },
  {
    id: "laude_servibelleza",
    nombre: "Laude Servibelleza",
    tagline: "Tu centro de estetica en Entrepeñas",
    descripcion: "Centro de estetica facial en Aguas Vivas, Guadalajara. Limpiezas faciales, peelings, dermapen y venta de cosmeticos profesionales.",
    categoria: "esteticas",
    activo: true,
    telefono: "640 08 40 04", whatsapp: "640 08 40 04",
    web: "https://www.servibelleza.es",
    direccion: "Blvr. de Entrepeñas, 8, 19005 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19005",
    ratingGoogle: 4.6, numResenas: 153,
    precioMedio: "~65-70 EUR",
    especialidades: ["Limpiezas faciales", "Peelings", "Dermapen", "Cosmeticos", "Eliminacion quistes", "Pedicura"],
    horarios: { ...horarioLV("09:30","19:30"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Blvr.+Entrepeñas+8%2C+19005+Guadalajara",
    servicios: [
      { nombre: "Tratamientos faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
      { nombre: "Peeling", categoria: "Belleza facial", activo: true },
      { nombre: "Dermapen", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Venta serums y cremas", categoria: "Productos", activo: true },
      { nombre: "Eliminacion de quistes", categoria: "Medicina estetica", activo: true },
      { nombre: "Pedicura", categoria: "Estilo personal", activo: true },
    ],
  },
  {
    id: "glow_medicina_estetica",
    nombre: "GLOW Medicina Estetica",
    tagline: "Tu piel en manos expertas",
    descripcion: "Clinica de medicina estetica en el barrio de Amistad, Guadalajara. Especializada en tratamiento de manchas faciales y depilacion laser.",
    categoria: "clinicas",
    activo: true,
    telefono: "949 21 11 72", whatsapp: "949 21 11 72",
    web: "https://www.medicinaesteticaglow.es",
    direccion: "C. de la Virgen de la Soledad, 3a, 19003 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19003",
    ratingGoogle: 4.3, numResenas: 18,
    especialidades: ["Tratamiento manchas faciales", "Depilacion laser", "Medicina estetica facial"],
    horarios: { 0:dia(false),1:dia(false),2:dia(false),3:dia(false),4:dia(false),5:dia(false),6:dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Virgen+de+la+Soledad+3a%2C+19003+Guadalajara",
    servicios: [
      { nombre: "Tratamiento de manchas faciales", categoria: "Belleza facial", activo: true },
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Medicina estetica facial", categoria: "Medicina estetica", activo: true },
    ],
  },
  {
    id: "mizu_guadalajara",
    nombre: "Mizu Guadalajara",
    tagline: "Spa y medicina estetica en el corazon de Guadalajara",
    descripcion: "Spa y centro de medicina estetica en el barrio de Amistad, Guadalajara. Masajes en pareja, tratamientos faciales, fisioterapia estetica y cama de agua.",
    categoria: "esteticas",
    activo: true,
    telefono: "685 53 21 67", whatsapp: "685 53 21 67",
    web: "https://www.mizuspa.com",
    direccion: "C. Marques de Santillana, 2, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 4.2, numResenas: 349,
    especialidades: ["Medicina estetica facial", "Masajes", "Tratamientos faciales", "Laser estetico", "Fisioterapia estetica", "Cama de agua", "Manicura"],
    horarios: { ...horarioLV("10:00","20:30"), 5: dia(false), 6: dia(false) },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Marques+de+Santillana+2%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Medicina estetica facial", categoria: "Medicina estetica", activo: true },
      { nombre: "Masajes relajantes", categoria: "Bienestar", activo: true },
      { nombre: "Masajes en pareja", categoria: "Bienestar", activo: true },
      { nombre: "Tratamientos faciales acne", categoria: "Belleza facial", activo: true },
      { nombre: "Laser estetico", categoria: "Tratamientos avanzados", activo: true },
      { nombre: "Fisioterapia estetica", categoria: "Bienestar", activo: true },
      { nombre: "Cama de agua", categoria: "Bienestar", activo: true },
      { nombre: "Manicura", categoria: "Estilo personal", activo: true },
    ],
  },
  // ── DEPILACION LASER ──────────────────────────────────────────────────────
  {
    id: "lc_depilacion_laser",
    nombre: "LC Depilacion Laser",
    tagline: "Depilacion laser con los mejores resultados",
    descripcion: "Centro especializado en depilacion laser en el barrio de Amistad, Guadalajara. Horario ampliado hasta las 21:00.",
    categoria: "esteticas",
    activo: true,
    telefono: "949 25 57 14", whatsapp: "949 25 57 14",
    web: "https://www.laserbolinia.com",
    direccion: "C. Wenceslao Argumosa, 5, 19003 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19003",
    ratingGoogle: 5.0, numResenas: 24,
    especialidades: ["Depilacion laser"],
    horarios: {
      0: dia(true,"09:15","21:00"), 1: dia(true,"09:15","21:00"),
      2: dia(true,"09:15","21:00"), 3: dia(true,"09:15","21:00"),
      4: dia(true,"09:00","21:00"), 5: dia(false), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Wenceslao+Argumosa+5%2C+19003+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
    ],
  },
  {
    id: "alan_depilacion_laser",
    nombre: "ALAN Depilacion Laser",
    tagline: "Resultados excelentes sin dolor",
    descripcion: "Centro de depilacion laser facial y corporal en el barrio Centro de Guadalajara. Especializado en tratamiento de vello hormonal.",
    categoria: "esteticas",
    activo: true,
    telefono: "642 29 47 20", whatsapp: "642 29 47 20",
    direccion: "C. Miguel Fluiters, 45, 19001 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19001",
    ratingGoogle: 5.0, numResenas: 28,
    especialidades: ["Depilacion laser facial", "Depilacion laser corporal", "Tratamiento vello hormonal"],
    horarios: {
      0: dia(true,"10:00","19:00"), 1: dia(true,"10:00","19:00"),
      2: dia(true,"10:00","19:00"), 3: dia(true,"10:00","19:00"),
      4: dia(true,"10:00","19:00"), 5: dia(true,"10:00","19:00"),
      6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Miguel+Fluiters+45%2C+19001+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser facial", categoria: "Depilacion", activo: true },
      { nombre: "Depilacion laser corporal", categoria: "Depilacion", activo: true },
      { nombre: "Tratamiento vello hormonal", categoria: "Depilacion", activo: true },
    ],
  },
  {
    id: "centro_rubi_guadalajara",
    nombre: "Centro Rubi",
    tagline: "Depilacion laser con la mejor relacion calidad-precio",
    descripcion: "Centro de depilacion laser en el Centro de Guadalajara. Destacado por precios muy asequibles y excelentes resultados.",
    categoria: "esteticas",
    activo: true,
    telefono: "622 84 84 60", whatsapp: "622 84 84 60",
    web: "https://www.centrosrubi.com",
    direccion: "Pl. Virgen de la Antigua, 5, 19001 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19001",
    ratingGoogle: 5.0, numResenas: 34,
    especialidades: ["Depilacion laser"],
    horarios: {
      ...horarioLV("10:00","20:00"),
      5: dia(true,"10:00","14:00"), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=Pl.+Virgen+de+la+Antigua+5%2C+19001+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
    ],
  },
  {
    id: "laserya_el_casar",
    nombre: "Laserya",
    tagline: "Depilacion laser y estetica en El Casar",
    descripcion: "Centro de depilacion laser y estetica en El Casar, Guadalajara. Tambien ofrece manicura, tratamientos corporales y lifting de pestanas.",
    categoria: "esteticas",
    activo: true,
    telefono: "949 41 03 27", whatsapp: "949 41 03 27",
    web: "https://www.laserya.es",
    direccion: "C. el Salto, 13, 19170 El Casar, Guadalajara",
    localidad: "El Casar", provincia: "Guadalajara", codigoPostal: "19170",
    ratingGoogle: 5.0, numResenas: 190,
    precioMedio: "~35-40 EUR lifting pestanas",
    especialidades: ["Depilacion laser", "Manicura", "Tratamientos corporales", "Lifting pestanas", "Limpieza facial"],
    horarios: {
      ...horarioLV("10:00","20:00"),
      5: dia(true,"10:00","13:30"), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+el+Salto+13%2C+19170+El+Casar",
    servicios: [
      { nombre: "Depilacion laser", categoria: "Depilacion", activo: true },
      { nombre: "Manicura", categoria: "Estilo personal", activo: true },
      { nombre: "Tratamientos corporales", categoria: "Belleza corporal", activo: true },
      { nombre: "Lifting de pestanas", categoria: "Diseno de la mirada", activo: true },
      { nombre: "Limpieza facial", categoria: "Belleza facial", activo: true },
    ],
  },
  {
    id: "laser_azuqueca",
    nombre: "Laser Azuqueca",
    tagline: "Depilacion laser diodo en Azuqueca de Henares",
    descripcion: "Centro especializado en depilacion laser diodo en Azuqueca de Henares, Guadalajara. Horario amplio de 9:00 a 21:00.",
    categoria: "esteticas",
    activo: true,
    telefono: "641 13 60 50", whatsapp: "641 13 60 50",
    web: "https://www.laserazuqueca.es",
    direccion: "C. la Victoria, 4, 19200 Azuqueca de Henares, Guadalajara",
    localidad: "Azuqueca de Henares", provincia: "Guadalajara", codigoPostal: "19200",
    ratingGoogle: 4.9, numResenas: 80,
    especialidades: ["Depilacion laser diodo"],
    horarios: {
      ...horarioLV("09:00","21:00"),
      5: dia(true,"09:00","14:00"), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+la+Victoria+4%2C+19200+Azuqueca+de+Henares",
    servicios: [
      { nombre: "Depilacion laser diodo", categoria: "Depilacion", activo: true },
    ],
  },
  {
    id: "laserum_guadalajara",
    nombre: "Laserum Guadalajara",
    tagline: "Depilacion laser diodo con resultados desde la primera sesion",
    descripcion: "Franquicia de depilacion laser diodo en el barrio de Amistad, Guadalajara. Con 1.721 resenas en Google, es el centro mas valorado de la ciudad.",
    categoria: "esteticas",
    activo: true,
    telefono: "664 23 71 30", whatsapp: "664 23 71 30",
    web: "https://www.laserum.com",
    direccion: "C. Manuel Paez Xaramillo, 4, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 4.9, numResenas: 1721,
    especialidades: ["Depilacion laser diodo"],
    horarios: {
      0: dia(true,"10:00","20:00"),
      1: dia(true,"10:00","14:00","16:00","20:00"),
      2: dia(true,"10:00","14:00","16:00","20:00"),
      3: dia(true,"10:00","14:00","16:00","20:00"),
      4: dia(true,"10:00","20:00"),
      5: dia(true,"10:00","14:00"), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Manuel+Paez+Xaramillo+4%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser diodo", categoria: "Depilacion", activo: true },
    ],
  },
  {
    id: "sinvello_guadalajara",
    nombre: "SinVello Guadalajara",
    tagline: "Depilacion laser de cuerpo completo",
    descripcion: "Centro de depilacion laser diodo en el barrio de Amistad, Guadalajara. Con 564 resenas y horario hasta las 21:00 de lunes a viernes.",
    categoria: "esteticas",
    activo: true,
    telefono: "604 90 14 76", whatsapp: "604 90 14 76",
    web: "https://www.sinvelloporlaser.es",
    direccion: "C. Felipe Solano Antelo, 19, 19002 Guadalajara",
    localidad: "Guadalajara", provincia: "Guadalajara", codigoPostal: "19002",
    ratingGoogle: 4.9, numResenas: 564,
    especialidades: ["Depilacion laser diodo cuerpo completo"],
    horarios: {
      0: dia(true,"09:30","14:30","15:00","21:00"),
      1: dia(true,"09:30","14:30","15:00","21:00"),
      2: dia(true,"09:30","14:30","15:00","21:00"),
      3: dia(true,"09:30","14:30","15:00","21:00"),
      4: dia(true,"09:30","14:30","15:00","21:00"),
      5: dia(true,"10:00","14:00"), 6: dia(false),
    },
    googleMapsUrl: "https://www.google.com/maps/search/?api=1&query=C.+Felipe+Solano+Antelo+19%2C+19002+Guadalajara",
    servicios: [
      { nombre: "Depilacion laser diodo cuerpo completo", categoria: "Depilacion", activo: true },
    ],
  },
];

// ─── IDs a borrar (prueba sin empresa vinculada) ─────────────────────────────
const IDS_BORRAR = [
  "clinica_carlos_gomez_guadalajara",
  "cristina_aguilera_aesthetic",
  "laude_servibelleza",
  "medicina_estetica_glow",
];

async function main() {
  console.log("\n=== PASO 1: Borrar negocios de prueba ===");
  for (const id of IDS_BORRAR) {
    const ref = db.collection("negocios_publicos").doc(id);
    const snap = await ref.get();
    if (snap.exists) {
      // Borrar subcoleccion servicios si existe
      const srvsSnap = await ref.collection("servicios").get();
      if (!srvsSnap.empty) {
        const b = db.batch();
        srvsSnap.docs.forEach(d => b.delete(d.ref));
        await b.commit();
      }
      await ref.delete();
      console.log("  Borrado:", id);
    } else {
      console.log("  No existia:", id);
    }
  }

  console.log("\n=== PASO 2: Importar " + NEGOCIOS.length + " negocios ===");
  let ok = 0;
  for (const n of NEGOCIOS) {
    const { id, servicios, ...campos } = n;
    campos.fechaCreacion = admin.firestore.FieldValue.serverTimestamp();
    campos.mostrarResenasGoogle = true;
    campos.permitirResenas = true;
    campos.aparecerEnResultados = true;

    const ref = db.collection("negocios_publicos").doc(id);
    await ref.set(campos, { merge: false });

    // Servicios como subcoleccion
    if (servicios && servicios.length > 0) {
      const batch = db.batch();
      servicios.forEach((srv, idx) => {
        const sRef = ref.collection("servicios").doc();
        batch.set(sRef, {
          ...srv,
          orden: idx,
          publico: "todos",
          sincronizado_desde_empresa: false,
        });
      });
      await batch.commit();
    }

    ok++;
    process.stdout.write("\r  Importados: " + ok + "/" + NEGOCIOS.length + "  ");
  }

  console.log("\n\n===================================================");
  console.log("  LISTO");
  console.log("  Borrados:   " + IDS_BORRAR.length + " negocios de prueba");
  console.log("  Importados: " + ok + " negocios");
  console.log("  Conservados: demo_bar_fluix2026, demo_peluqueria_fluix2026");
  console.log("===================================================\n");
  process.exit(0);
}

main().catch(e => { console.error("Error:", e.message); process.exit(1); });
