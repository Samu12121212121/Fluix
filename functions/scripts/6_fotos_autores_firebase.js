/**
 * 6_fotos_autores_firebase.js
 * Actualiza foto_url + imagen en los autores de Acentuarte en Firebase
 * usando las imágenes extraídas del SQL de la web descargada.
 *
 * Uso:
 *   cd functions
 *   node scripts/6_fotos_autores_firebase.js            ← muestra qué haría
 *   node scripts/6_fotos_autores_firebase.js --aplicar  ← escribe en Firestore
 */
'use strict';
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID_AC   = 'pU4wGaElcyoDR5dA0YNO';
const BASE_URL = 'https://editorialacentuarte.es/';
const APLICAR  = process.argv.includes('--aplicar');

// ── Mapa slug → URL completa ─────────────────────────────────────────────────
// Extraído del SQL de la web descargada (patrón *-web.jpg/png)
const FOTO_MAP = {
  'alex-bernal':                          'wp-content/uploads/2023/11/Alex-Bernal-web.png',
  'andres-velasco-zambrana':              'wp-content/uploads/2023/11/Andres-Velasco-Zambrana-web.png',
  'antonio-custodio':                     'wp-content/uploads/2023/11/Antonio-Custodio-web.png',
  'antonio-custodio-rodriguez-chacon':    'wp-content/uploads/2023/11/Antonio-Custodio-web.png',
  'antonio-marin':                        'wp-content/uploads/2023/11/Antonio-Marin-web.jpg',
  'antonio-marin-sanchez':               'wp-content/uploads/2023/11/Antonio-Marin-web.jpg',
  'beatriz-gaya':                         'wp-content/uploads/2023/11/Beatriz-Gaya-web.png',
  'beatriz-gaya-juan':                    'wp-content/uploads/2023/11/Beatriz-Gaya-web.png',
  'claudio-m-ramos':                      'wp-content/uploads/2023/11/Claudio-M.-Ramos-web.jpg',
  'cristina-alabarce':                    'wp-content/uploads/2023/11/Cristina-Alabarce-web.jpg',
  'cristina-bravo':                       'wp-content/uploads/2023/11/Cristina-Bravo-web.jpg',
  'diego-garcia':                         'wp-content/uploads/2023/11/Diego-Garcia-web.png',
  'eduardo-castro':                       'wp-content/uploads/2023/11/Eduardo-Castro-web.jpg',
  'eugenio-coll-del-rey':                 'wp-content/uploads/2023/11/Eugenio-Coll-del-Rey-web.png',
  'felicidad-maldonado':                  'wp-content/uploads/2023/11/Felicidad-Maldonado-web.png',
  'francisco-martinez-sanchez':           'wp-content/uploads/2023/11/Francisco-Martinez-Sanchez-web.jpg',
  'irene-molina':                         'wp-content/uploads/2023/11/Irene-Molina-web.jpg',
  'jaime-alonso':                         'wp-content/uploads/2023/11/Jaime-Alonso-web.jpg',
  'jaime-alonso-veliz':                   'wp-content/uploads/2023/11/Jaime-Alonso-web.jpg',
  'jose-reinon':                          'wp-content/uploads/2023/11/Jose-Reinon-web.jpg',
  'jose-reinan':                          'wp-content/uploads/2023/11/Jose-Reinon-web.jpg',
  'juan-carlos-marin-martos':             'wp-content/uploads/2023/11/Juan-Carlos-Marin-Martos-web.png',
  'juan-carlos-martin-martos':            'wp-content/uploads/2023/11/Juan-Carlos-Marin-Martos-web.png',
  'laura-ramos':                          'wp-content/uploads/2023/11/Laura-Ramos-web.jpg',
  'maria-del-carmen-moreno':              'wp-content/uploads/2023/11/Maria-Del-Carmen-Moreno-web.jpg',
  'maria-del-carmen-moreno-perez':        'wp-content/uploads/2023/11/Maria-Del-Carmen-Moreno-web.jpg',
  'maria-jose-ruiz':                      'wp-content/uploads/2023/11/Maria-Jose-Ruiz-web.jpg',
  'maribel-martin':                       'wp-content/uploads/2023/11/Maribel-Martin-web.jpg',
  'maribel-martin-pelegrina':             'wp-content/uploads/2023/11/Maribel-Martin-web.jpg',
  'paco-galan':                           'wp-content/uploads/2023/11/Paco-Galan-web.jpg',
  'pedro-rojas':                          'wp-content/uploads/2023/11/Pedro-Rojas-web.jpg',
  'pedro-rojas-pedregosa':               'wp-content/uploads/2023/11/Pedro-Rojas-web.jpg',
  'rafael-bailon':                        'wp-content/uploads/2023/11/Rafael-Bailon-web.png',
  'rafael-bailon-ruiz':                   'wp-content/uploads/2023/11/Rafael-Bailon-web.png',
  'rosario-f-cartes':                     'wp-content/uploads/2023/11/Rosario-F.-Cartes-web.jpg',
  'ma-carmen-baena-chirosa':              'wp-content/uploads/2024/05/Ma-Carmen-Baena-Chirosa-Web.jpg',
  'maria-carmen-baena-chirosa':           'wp-content/uploads/2024/05/Ma-Carmen-Baena-Chirosa-Web.jpg',
  'manuel-martin-lafuente':               'wp-content/uploads/2024/05/Manuel-Martin-Lafuente-web.jpg',
  'fernando-villalobos-rojas':            'wp-content/uploads/2024/08/Fernando-Villalobos-Rojas-web.jpg',
  'antonio-arenas':                       'wp-content/uploads/2024/10/Antonio-Arenas-web.jpg',
  'antonio-gamez-lopez':                  'wp-content/uploads/2024/10/Antonio-Gamez-Lopez-web.jpg',
  'sofia-maldonado-moron':               'wp-content/uploads/2024/10/Sofia-Maldonado-Moron-web.jpg',
  'edith-pinas':                          'wp-content/uploads/2024/12/Edith-Pinas-web.jpg',
  'teodoro-martin-de-molina':            'wp-content/uploads/2024/12/Teodoro-Martin-de-Molina-web.jpg',
  'rafael-reche':                         'wp-content/uploads/2025/01/Rafael-Reche-web.jpg',
  'juan-manuel-reina-moreno':            'wp-content/uploads/2026/03/Juan-Manuel-Reina-Moreno-web.jpg',
  'rosa-chillon':                         'wp-content/uploads/2026/03/Rosa-Chillon-web.jpg',
  'asociacion-de-mujeres-el-nacimiento-de-yegen': 'wp-content/uploads/2026/06/Asociacion-de-Mujeres-El-Nacimiento-de-Yegen-web.jpg',
  'belen-esturla':                        'wp-content/uploads/2026/06/Belen-Esturla-web.jpg',
  'encarnacion-fernandez-olea':           'wp-content/uploads/2026/06/Encarnacion-Fernandez-Olea-web.jpg',
  'fernando-dumont-cruz':                 'wp-content/uploads/2026/06/Fernando-Dumont-Cruz-web.jpg',
  'jose-andres-ciruela-raya':            'wp-content/uploads/2026/06/Jose-Andres-Ciruela-Raya-web.jpg',
  // extras from live site scrape
  'juan-jose-gallego-tribaldos':          'wp-content/uploads/2024/10/Juan-Jose-Gallego-web-2.jpg',
  'ana-maria-callejon-callejon':          'wp-content/uploads/2023/11/Ana-Maria-Callejon.jpg',
  'antonio-cobos-ruz':                    'wp-content/uploads/2025/05/Antonio-Cobos.jpg',
  'luis-sionda':                          'wp-content/uploads/2025/05/Luis-Sionda.jpg',
  'maria-victoria-romero-hidalgo':        'wp-content/uploads/2025/10/Maria-Victoria-Romero-Hidalgo.jpg',
  'baldomero-fernandez-montoya':          'wp-content/uploads/2025/10/Baldomero-Fernandez-Montoya.jpg',
  'juan-bueno-perez':                     'wp-content/uploads/2025/09/Juan-Bueno-Autor.jpg',
  'manuel-fernandez-guzman':              'wp-content/uploads/2025/06/Manuel-Fernandez-Guzman.jpg',
  // Slugs con apellido extra en Firestore vs nombre corto en la imagen
  'edith-pinas-navarro':                  'wp-content/uploads/2024/12/Edith-Pinas-web.jpg',
  'antonio-cobos-ru':                     'wp-content/uploads/2025/05/Antonio-Cobos.jpg',
  'antonio-cobos-ruz':                    'wp-content/uploads/2025/05/Antonio-Cobos.jpg',
  'diego-garcia-martinez':                'wp-content/uploads/2023/11/Diego-Garcia-web.png',
  'rafael-reche-silva':                   'wp-content/uploads/2025/01/Rafael-Reche-web.jpg',
  'maria-jose-ruiz-diaz':                 'wp-content/uploads/2023/11/Maria-Jose-Ruiz-web.jpg',
  'laura-ramos-garcia':                   'wp-content/uploads/2023/11/Laura-Ramos-web.jpg',
  'escuela-remiendo':                     'wp-content/uploads/2024/10/Escuela-Remiendo-web.jpg',
};

async function run() {
  const col  = db.collection('empresas').doc(EID_AC).collection('autores');
  const snap = await col.get();
  console.log(`Autores en Firebase: ${snap.size}`);

  let matched = 0, notFound = 0;
  const batch = db.batch();

  snap.forEach(doc => {
    const d = doc.data();
    const slug = (d.slug || '').toLowerCase();

    // Try exact slug match first, then partial matches
    let fotoPath = FOTO_MAP[slug];

    // Partial: try stripping accents + common variants
    if (!fotoPath) {
      const normalized = slug
        .replace(/á/g,'a').replace(/é/g,'e').replace(/í/g,'i')
        .replace(/ó/g,'o').replace(/ú/g,'u').replace(/ñ/g,'n')
        .replace(/ü/g,'u').replace(/[«»"']/g,'');
      fotoPath = FOTO_MAP[normalized];
    }

    if (fotoPath) {
      const url = BASE_URL + fotoPath;
      console.log(`✓ ${d.nombre} → ${url}`);
      matched++;
      if (APLICAR) {
        batch.update(doc.ref, { foto_url: url, imagen: url });
      }
    } else {
      console.log(`✗ SIN FOTO: ${d.nombre} (slug: ${slug})`);
      notFound++;
    }
  });

  console.log(`\nMatched: ${matched} | Sin foto: ${notFound}`);

  if (APLICAR) {
    await batch.commit();
    console.log('✅ Firestore actualizado');
  } else {
    console.log('\n⚠️  DRY-RUN — Para actualizar Firebase: --aplicar');
  }
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
