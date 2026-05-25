/**
 * seed_negocios_firebase.js
 * ─────────────────────────────────────────────────────────────────────────
 * Script Node.js para crear los 40 negocios públicos de Guadalajara
 * en la colección Firestore `negocios_publicos`.
 *
 * REQUISITOS:
 *   1. Node.js instalado (node -v)
 *   2. firebase-admin instalado:
 *        npm install firebase-admin
 *   3. Fichero de credenciales de cuenta de servicio descargado desde:
 *        Firebase Console → Configuración → Cuentas de servicio
 *        → Generar nueva clave privada → guarda como serviceAccountKey.json
 *        (en la misma carpeta que este script)
 *
 * USO:
 *   node seed_negocios_firebase.js
 *
 * El script usa merge:true, por lo que es seguro ejecutarlo varias veces
 * (no duplica datos, solo sobreescribe si el documento ya existe).
 * ─────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const serviceAccount = require('./credentials.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4',
});

const db = admin.firestore();
const COLLECTION = 'negocios_publicos';

// ── DATOS ────────────────────────────────────────────────────────────────────

const negocios = [

  // ── RESTAURANTES ─────────────────────────────────────────────────────────
  {
    id: 'restaurante_dama_juana',
    nombre: 'Restaurante Dama Juana',
    categoria: 'restaurantes',
    ratingGoogle: 4.7,
    descripcion: 'Cocina moderna española, carnes premium, arroces y platos elaborados.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'summer_guadalajara',
    nombre: 'Summer',
    categoria: 'restaurantes',
    ratingGoogle: 4.1,
    descripcion: 'Tapas, cenas, copas y ambiente moderno de terraza. Muy popular entre gente joven.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'botanico_guadalajara',
    nombre: 'Botánico',
    categoria: 'restaurantes',
    ratingGoogle: 4.5,
    descripcion: 'Brunch, cocina moderna, café y ambiente "instagrameable".',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'casa_palomo',
    nombre: 'Casa Palomo',
    categoria: 'restaurantes',
    ratingGoogle: 4.6,
    descripcion: 'Cocina castellana tradicional y carnes. De los clásicos más famosos de Guadalajara.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'biosfera_guadalajara',
    nombre: 'Biosfera Guadalajara',
    categoria: 'restaurantes',
    ratingGoogle: 4.4,
    descripcion: 'Cocina internacional, sushi y experiencia premium.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'restaurante_davalos',
    nombre: 'Restaurante Dávalos',
    categoria: 'restaurantes',
    ratingGoogle: 4.3,
    descripcion: 'Menú español tradicional, tapas y comidas de grupo. Muy conocido en el centro.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'puerta_gayola',
    nombre: 'Puerta Gayola',
    categoria: 'restaurantes',
    ratingGoogle: 4.1,
    descripcion: 'Tapas, raciones y cañas. Uno de los bares/restaurantes más populares de la ciudad.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'giovani_fratelli',
    nombre: 'Ristorante Trattoria Giovani Fratelli',
    categoria: 'restaurantes',
    ratingGoogle: 4.7,
    descripcion: 'Cocina italiana, pizzas artesanales y pasta fresca.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'la_duquesa',
    nombre: 'Restaurante La Duquesa',
    categoria: 'restaurantes',
    ratingGoogle: 4.3,
    descripcion: 'Cocina mediterránea, carnes y celebraciones.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'casa_victoria',
    nombre: 'Casa Victoria Restaurante',
    categoria: 'restaurantes',
    ratingGoogle: 4.8,
    descripcion: 'Cocina mediterránea moderna y tapas gourmet.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },

  // ── ESTÉTICAS ─────────────────────────────────────────────────────────────
  {
    id: 'estetica_belen',
    nombre: 'Estética Belén',
    categoria: 'esteticas',
    ratingGoogle: 5.0,
    descripcion: 'Tratamientos faciales, depilación y estética integral.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'beauty_by_patricia',
    nombre: 'Beauty by Patricia',
    categoria: 'esteticas',
    ratingGoogle: 4.9,
    descripcion: 'Uñas, maquillaje y estética facial.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'ic_belleza_pro',
    nombre: 'IC Belleza Pro',
    categoria: 'esteticas',
    ratingGoogle: 4.8,
    descripcion: 'Belleza avanzada y tratamientos corporales.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'aesthetic_center_alba',
    nombre: 'Aesthetic Center Alba',
    categoria: 'esteticas',
    ratingGoogle: 4.8,
    descripcion: 'Estética facial y corporal.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'centro_venus',
    nombre: 'Centro Venus',
    categoria: 'esteticas',
    ratingGoogle: 4.7,
    descripcion: 'Depilación y tratamientos faciales.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'natura_belleza',
    nombre: 'Natura Belleza',
    categoria: 'esteticas',
    ratingGoogle: 4.6,
    descripcion: 'Cosmética natural y bienestar.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'beauty_concept',
    nombre: 'Beauty Concept',
    categoria: 'esteticas',
    ratingGoogle: 4.7,
    descripcion: 'Manicura y estética premium.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'stylo_estetica',
    nombre: 'Stylo Estética',
    categoria: 'esteticas',
    ratingGoogle: 4.5,
    descripcion: 'Estética integral y tratamientos corporales.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'elena_beauty_center',
    nombre: 'Elena Beauty Center',
    categoria: 'esteticas',
    ratingGoogle: 4.6,
    descripcion: 'Skincare y belleza facial.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'luxury_beauty_studio',
    nombre: 'Luxury Beauty Studio',
    categoria: 'esteticas',
    ratingGoogle: 4.7,
    descripcion: 'Estética avanzada y maquillaje.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },

  // ── PELUQUERÍAS ───────────────────────────────────────────────────────────
  {
    id: 'alberto_hair_beauty',
    nombre: 'Alberto hair & beauty',
    categoria: 'peluquerias',
    ratingGoogle: 4.8,
    descripcion: 'Coloración, cortes modernos y tratamientos capilares premium.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'aurelia_estilistas',
    nombre: 'Aurelia Estilistas | Peluquería en Guadalajara',
    categoria: 'peluquerias',
    ratingGoogle: 4.9,
    descripcion: 'Mechas, balayage y estilismo femenino.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'vanessa_fernandez',
    nombre: 'Vanessa Fernández Peluqueros',
    categoria: 'peluquerias',
    ratingGoogle: 4.7,
    descripcion: 'Peluquería profesional, color y tratamientos de hidratación.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'la_pelu_de_roci',
    nombre: 'La pelu de Roci',
    categoria: 'peluquerias',
    ratingGoogle: 4.9,
    descripcion: 'Cortes modernos, peinados y atención personalizada.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'peluqueria_dellas',
    nombre: "Peluquería D'Ellas",
    categoria: 'peluquerias',
    ratingGoogle: 4.4,
    descripcion: 'Peluquería femenina y estética integral.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'blu_estilistas',
    nombre: 'Blu Estilistas',
    categoria: 'peluquerias',
    ratingGoogle: 4.7,
    descripcion: 'Coloración, cortes y peluquería de tendencia.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'la_pelu',
    nombre: 'La Pelu',
    categoria: 'peluquerias',
    ratingGoogle: 4.8,
    descripcion: 'Peluquería personalizada y tratamientos capilares.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'golden_estilistas',
    nombre: 'Golden Estilistas',
    categoria: 'peluquerias',
    ratingGoogle: 4.8,
    descripcion: 'Peluquería y estética profesional.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'rb_peluqueros',
    nombre: 'R & B Peluqueros',
    categoria: 'peluquerias',
    ratingGoogle: 4.9,
    descripcion: 'Estilismo y peluquería moderna.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'os_peluquerias_marios',
    nombre: "O'S Peluquerias Mario's",
    categoria: 'peluquerias',
    ratingGoogle: 4.7,
    descripcion: 'Cortes, color y productos capilares premium.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },

  // ── TATUAJES ──────────────────────────────────────────────────────────────
  {
    id: 'studio_madrid_tattoo',
    nombre: 'Studio Madrid Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 5.0,
    descripcion: 'Realismo, blackwork y tatuajes personalizados.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'studio_8_tattoo',
    nombre: 'Studio 8 - Tattoo and Piercing Studio',
    categoria: 'tatuajes',
    ratingGoogle: 4.9,
    descripcion: 'Tatuajes personalizados, piercing y fine line.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'la_boheme_tattoo',
    nombre: 'La Boheme Tattoo Studio',
    categoria: 'tatuajes',
    ratingGoogle: 5.0,
    descripcion: 'Tatuajes artísticos y tinta personalizada.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'estudio_checa',
    nombre: 'Estudio Checa',
    categoria: 'tatuajes',
    ratingGoogle: 4.8,
    descripcion: 'Blackwork, lettering y tatuaje tradicional.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'la_tinta_mona',
    nombre: 'La Tinta Mona Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 5.0,
    descripcion: 'Fine line, minimalista y diseños personalizados.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'magistral_tattoo',
    nombre: 'Magistral Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 4.8,
    descripcion: 'Realismo, color y cover up.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'ink_brotherhood',
    nombre: 'Ink Brotherhood Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 4.8,
    descripcion: 'Black & grey y tatuajes urbanos.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'dark_rose_tattoo',
    nombre: 'Dark Rose Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 4.7,
    descripcion: 'Neotradicional y color.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'old_skull_tattoo',
    nombre: 'Old Skull Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 4.7,
    descripcion: 'Old school y lettering.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
  {
    id: 'black_moon_tattoo',
    nombre: 'Black Moon Tattoo',
    categoria: 'tatuajes',
    ratingGoogle: 4.6,
    descripcion: 'Fine line y diseños personalizados.',
    activo: true,
    empresaIdVinculada: '',
    direccion: 'Guadalajara, España',
    fotoUrl: null,
    placeId: null,
    telefono: null,
  },
];

// ── SEED ─────────────────────────────────────────────────────────────────────

async function seed() {
  console.log(`🌱 Iniciando seed de ${negocios.length} negocios públicos de Guadalajara...`);
  console.log(`📦 Proyecto: planeaapp-4bea4 | Colección: ${COLLECTION}\n`);

  const batch = db.batch();
  const resumen = { restaurantes: 0, esteticas: 0, peluquerias: 0, tatuajes: 0 };

  for (const negocio of negocios) {
    const { id, ...data } = negocio;
    const ref = db.collection(COLLECTION).doc(id);
    batch.set(ref, data, { merge: true });
    resumen[negocio.categoria]++;
    console.log(`  ✅ ${negocio.categoria.padEnd(14)} → ${negocio.nombre}`);
  }

  await batch.commit();

  console.log('\n🎉 Seed completado con éxito!');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`  🍽️  Restaurantes : ${resumen.restaurantes}`);
  console.log(`  💅  Estéticas    : ${resumen.esteticas}`);
  console.log(`  💇  Peluquerías  : ${resumen.peluquerias}`);
  console.log(`  🎨  Tatuajes     : ${resumen.tatuajes}`);
  console.log(`  📊  TOTAL        : ${negocios.length}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Error durante el seed:', err);
  process.exit(1);
});


