/**
 * ACTUALIZAR IMÁGENES — negocios cargados desde webs
 *
 * Asigna fotoUrl y logoUrl extraídos de las webs oficiales.
 * Solo actualiza campos nulos/vacíos.
 *
 * Ejecutar: node scripts/actualizar_imagenes_negocios_webs.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const IMAGENES = [
  {
    id: 'laude_servibelleza',
    logoUrl: 'https://www.servibelleza.es/wp-content/uploads/2023/06/laude-servibelleza.png',
    fotoUrl: 'https://www.servibelleza.es/wp-content/uploads/2023/06/laude-servibelleza-xl.png',
    // ⚠️ Solo tienen logo publicado en web. Sustituir fotoUrl por foto del local cuando la tengas.
  },
  {
    id: 'cristina_aguilera_aesthetic',
    logoUrl: 'https://cristinaguileraesthetic.es/wp-content/uploads/CAESTHETICLOGOMENU-blanco.webp',
    fotoUrl: 'https://cristinaguileraesthetic.es/wp-content/uploads/CAESTHETICQUIENESCA.jpg',
  },
  {
    id: 'clinica_carlos_gomez_guadalajara',
    // ⚠️ La web carga imágenes dinámicamente (JS). Añadir manualmente desde:
    //    https://clinicacarlosgomez.com  o  @clinicacarlosgomez (Instagram)
    logoUrl: null,
    fotoUrl: null,
  },
  {
    id: 'medicina_estetica_glow',
    logoUrl: 'https://medicinaesteticaglow.es/wp-content/uploads/2018/11/Captura_de_pantalla_2023-12-13_a_las_10.21.37-removebg-preview.png',
    fotoUrl: 'https://medicinaesteticaglow.es/wp-content/uploads/2023/12/sensual-glamour-retrato-mujer-hermosa-modelo-maquillaje-piel-limpia-sana-negro_158538-13831.jpg',
  },
];

async function main() {
  console.log('\n🖼️  Actualizando imágenes...\n');
  let ok = 0, skip = 0;

  for (const n of IMAGENES) {
    const patch = {};
    if (n.fotoUrl)  patch.fotoUrl  = n.fotoUrl;
    if (n.logoUrl)  patch.logoUrl  = n.logoUrl;

    if (Object.keys(patch).length === 0) {
      console.log(`⚠️  ${n.id} — sin imágenes disponibles (pendiente manual)`);
      skip++;
      continue;
    }

    await db.collection('negocios_publicos').doc(n.id).update(patch);
    console.log(`✅ ${n.id} — ${Object.keys(patch).join(', ')}`);
    ok++;
  }

  console.log(`\n📊 ${ok} actualizados · ${skip} sin imagen`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e); process.exit(1); });
