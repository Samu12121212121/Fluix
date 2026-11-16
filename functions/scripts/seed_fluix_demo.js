'use strict';
/**
 * seed_fluix_demo.js
 * Rellena/crea el negocio "Fluix Peluquería Demo" en negocios_publicos.
 *
 * Uso:
 *   node scripts/seed_fluix_demo.js            ← dry-run (muestra sin escribir)
 *   node scripts/seed_fluix_demo.js --ejecutar ← aplica los cambios
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const EJECUTAR = process.argv.includes('--ejecutar');

const DEMO_DATA = {
  nombre: 'Fluix Peluquería Demo',
  activo: true,
  categoria: 'peluquerias',
  descripcion: 'Salón de peluquería moderno en el centro de la ciudad, especializado en corte, coloración y tratamientos capilares de alta calidad. Un espacio donde el estilo se encuentra con el cuidado personal.',
  serviciosDestacados: ['Corte de cabello', 'Coloración', 'Mechas', 'Tratamientos'],
  precioMedio: '35€',
  ratingGoogle: 4.8,
  ratingFluix: 4.9,
  numResenas: 187,
  direccion: 'Calle Mayor 12, Madrid',
  telefono: '+34 911 234 567',
  email: 'hola@fluixpeluqueria.com',
  web: 'https://fluixpeluqueria.com',
  horario: {
    'Lunes':     { apertura: '09:00', cierre: '20:00', cerrado: false },
    'Martes':    { apertura: '09:00', cierre: '20:00', cerrado: false },
    'Miércoles': { apertura: '09:00', cierre: '20:00', cerrado: false },
    'Jueves':    { apertura: '09:00', cierre: '20:00', cerrado: false },
    'Viernes':   { apertura: '09:00', cierre: '20:00', cerrado: false },
    'Sábado':    { apertura: '10:00', cierre: '18:00', cerrado: false },
    'Domingo':   { cerrado: true },
  },
  seccionesVisibles: {
    tab_servicios: true,
    tab_resenas:   true,
    tab_productos: false,
    tab_equipo:    true,
    tab_galeria:   true,
    tab_ofertas:   false,
    tab_politicas: true,
    descripcion:   true,
    contacto:      true,
    horarios:      true,
    ubicacion:     true,
    servicios:     true,
    reservas:      true,
    galeria:       true,
    profesionales: true,
    resenas_google: true,
    resenas_fluix:  true,
    politicas:     true,
  },
  especialidades: ['Corte moderno', 'Color y mechas', 'Keratina', 'Extensiones'],
  tieneDatosMinimos: true,
};

async function run() {
  const snap = await db.collection('negocios_publicos')
    .where('nombre', '==', 'Fluix Peluquería Demo')
    .limit(1)
    .get();

  if (snap.empty) {
    console.log('📋 No existe — se CREARÍA un documento nuevo');
    if (EJECUTAR) {
      const ref = await db.collection('negocios_publicos').add(DEMO_DATA);
      console.log('✅ Creado con ID:', ref.id);
    }
  } else {
    const doc = snap.docs[0];
    console.log('📋 Encontrado ID:', doc.id, '— se ACTUALIZARÍA');
    if (EJECUTAR) {
      await doc.ref.set(DEMO_DATA, { merge: true });
      console.log('✅ Actualizado correctamente');
    }
  }

  if (!EJECUTAR) console.log('\n⚠️  DRY RUN — añade --ejecutar para aplicar los cambios');
  process.exit(0);
}

run().catch(e => { console.error('❌', e); process.exit(1); });
