'use strict';
const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const HTML = path.join('C:', 'Users', 'Samu', 'Desktop', 'imagenes_nazari', 'html_nazari', 'blog.html');

const norm = s => (s||'').toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu,'').replace(/[^a-z0-9 ]+/g,' ');

// Slugs cortos del HTML → slug/id real de Firestore (busqueda por pista de título)
const MAPA = [
  { corto: 'caminando-tus-ojos-atarfe',             hint: 'caminando tus ojos cafe literario' },
  { corto: 'nostalgias-madrid',                      hint: 'nostalgias madrid' },
  { corto: 'mesa-redonda-albolote',                  hint: 'tiempo para ti escribe albolote' },
  { corto: 'huyendo-granada-temporada',              hint: 'huyendo granada reinicia temporada' },
  { corto: 'presentacion-cronica-profesor',          hint: 'presentacion cronica profesor' },
  { corto: 'dia-poesia-canal-sur',                   idReal: 'dia-de-la-poesia-en-canal-sur' },
  { corto: 'politicamente-correcto-cadena-ser',      idReal: 'politicamente-correcto-en-la-ventana-cadena-ser' },
  { corto: 'sergi-g-oset-paracuentos',               hint: 'sergi oset paracuentos' },
  { corto: 'taller-legado-principe-cachemira',       hint: 'taller legado principe cachemira' },
  { corto: 'ultima-jose-maria-bellido',              hint: 'ultima jose maria bellido' },
  { corto: 'sierra-irta-jesus-avila',               hint: 'sierra irta avila' },
];

async function run() {
  const snap = await db.collection('empresas').doc(EID).collection('blog').get();

  const buscar = hint => {
    const h = norm(hint);
    const words = h.split(' ').filter(w => w.length > 4);
    return snap.docs.find(d => {
      const t = norm(d.data().titulo || '');
      return words.length > 0 && words.every(w => t.includes(w));
    });
  };

  let html = fs.readFileSync(HTML, 'utf8');
  let cambios = 0;

  for (const entry of MAPA) {
    let docReal = null;
    if (entry.idReal) {
      docReal = snap.docs.find(d => d.id === entry.idReal);
    }
    if (!docReal && entry.hint) {
      docReal = buscar(entry.hint);
    }

    if (!docReal) {
      console.log('  ⚠️  No encontrado en FS: ' + (entry.hint || entry.idReal));
      continue;
    }

    const slugReal = docReal.data().slug || docReal.id;
    const before = html;
    // Reemplazar id: y slug: con el correcto
    html = html.replace(new RegExp("id:'" + entry.corto + "'", 'g'), "id:'" + docReal.id + "'");
    html = html.replace(new RegExp("slug:'" + entry.corto + "'", 'g'), "slug:'" + slugReal + "'");
    if (html !== before) {
      console.log('  ✅ ' + entry.corto + ' → id:' + docReal.id + ' slug:' + slugReal);
      cambios++;
    } else {
      console.log('  (no en HTML): ' + entry.corto);
    }
  }

  fs.writeFileSync(HTML, html, 'utf8');
  console.log('\n' + cambios + ' entradas actualizadas en blog.html');
  console.log('Sube este archivo a Hostinger para que surta efecto.');
}

run().catch(e => { console.error(e.message); process.exit(1); });
