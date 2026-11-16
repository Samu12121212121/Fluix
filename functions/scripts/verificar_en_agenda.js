/**
 * verificar_en_agenda.js
 * Comprueba si ciertos posts del blog tienen su evento equivalente en la agenda.
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

function norm(s=''){return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9\s]/g,'').replace(/\s+/g,' ').trim();}

(async () => {
  // Posts a verificar
  const posts = [
    { blogSlug: 'preludio-muerte-fuga-almeria',         eventoSlug: 'preludio-muerte-y-fuga-en-la-feria-del-libro-de-almeria' },
    { blogSlug: 'letras-celestes-antigona-marquez',     eventoSlug: 'ciudades-y-tierras-salvajes-de-andalucia-en-e-vii-encuentro-letras-celestes' },
  ];

  const col = db.collection('empresas').doc(EID);

  for (const p of posts) {
    console.log(`\n── ${p.blogSlug}`);

    // 1. Comprobar que el post de blog existe
    const blogSnap = await col.collection('blog').where('slug','==',p.blogSlug).limit(1).get();
    if (blogSnap.empty) console.log('  Blog: ✗ no encontrado');
    else console.log(`  Blog: ✓ "${blogSnap.docs[0].data().titulo}"`);

    // 2. Comprobar que el evento existe en la agenda (por slug exacto)
    const evSnap = await col.collection('eventos').doc(p.eventoSlug).get();
    if (evSnap.exists) {
      const d = evSnap.data();
      console.log(`  Agenda (slug exacto): ✓ "${d.titulo}" — fecha: ${d.fecha?.toDate?.().toISOString().substring(0,10) ?? d.fecha}`);
    } else {
      // Búsqueda por título normalizado
      const allEv = await col.collection('eventos').get();
      const normSlug = norm(p.eventoSlug.replace(/-/g,' '));
      let found = null;
      allEv.forEach(doc => {
        if (norm(doc.data().titulo||'').includes(normSlug.substring(0,20))) found = doc;
      });
      if (found) console.log(`  Agenda (búsqueda): ✓ "${found.data().titulo}"`);
      else        console.log(`  Agenda: ✗ NO encontrado con slug "${p.eventoSlug}"`);
    }
  }

  process.exit(0);
})();
