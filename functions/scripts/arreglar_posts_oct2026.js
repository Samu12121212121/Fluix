/**
 * arreglar_posts_oct2026.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Ajustes del 19/10/2026 según revisión de Alejandro:
 *
 *  OCULTAR (eliminado: true):
 *   - mesa-redonda-tienes-tiempo-albolote  → va a agenda, no al blog
 *   - huyendo-granada-dia-mujer            → quitar
 *
 *  CREAR (falta en Firestore):
 *   - huyendo-a-granada-y-la-mujer-en-al-andalus  → noticia 2026-03-09
 *
 * Uso: cd functions && node scripts/arreglar_posts_oct2026.js
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// Búsqueda por campo slug (doc IDs son noticia-XX)
const OCULTAR_SLUGS = [
  'preludio-muerte-fuga-almeria',         // noticia-17 → va a agenda
  'letras-celestes-antigona-marquez',     // noticia-23 → va a agenda
  'los-rios-nunca-miran-atras-granada',   // noticia-24 → va a agenda
  'la-vieja-inquietud-del-aire-cordoba',  // noticia-33 → va a agenda
  'las-doce-cosechas-granada',            // noticia-35 → va a agenda
  'mesa-redonda-tienes-tiempo-albolote',  // noticia-42 → va a agenda (ya hecho)
  'huyendo-granada-dia-mujer',            // noticia-41 → quitar (ya hecho)
];

// Existen en Firestore pero con eliminado:true — publicar
const PUBLICAR_SLUGS = [
  'asi-fue-el-vii-encuentro-letras-celestes-con-antigona-marquez-pascual',
  'asi-fue-la-presentacion-de-los-rios-nunca-miran-atras-en-granada',
  'asi-fue-la-presentacion-de-la-vieja-inquietud-del-aire-en-cordoba',
  'huyendo-a-granada-y-la-mujer-en-al-andalus',  // ya hecho
];

(async () => {
  const col = db.collection('empresas').doc(EID).collection('blog');

  // ── 1. Ocultar posts (buscar por campo slug, no por doc ID) ─────────────────
  console.log('\n── OCULTANDO POSTS ────────────────────────────────────────');
  for (const slug of OCULTAR_SLUGS) {
    const q    = await col.where('slug', '==', slug).limit(1).get();
    if (q.empty) {
      console.log(`  ⚠️  No encontrado: ${slug}`);
      continue;
    }
    const doc = q.docs[0];
    const d   = doc.data();
    if (d.eliminado === true) {
      console.log(`  ⏭  Ya estaba oculto: ${slug} (doc:${doc.id})`);
      continue;
    }
    await doc.ref.update({ eliminado: true, publicada: false });
    console.log(`  🙈 Ocultado: ${slug}  doc:${doc.id}  tipo:${d.tipo}`);
  }

  // ── 2. Publicar posts que estaban ocultos ────────────────────────────────────
  console.log('\n── PUBLICANDO POSTS OCULTOS ────────────────────────────────');
  for (const slug of PUBLICAR_SLUGS) {
    const ref  = col.doc(slug);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`  ⚠️  No encontrado por doc ID: ${slug}`);
      continue;
    }
    const d = snap.data();
    if (d.eliminado === false && d.publicada === true) {
      console.log(`  ⏭  Ya estaba publicado: ${slug}`);
      continue;
    }
    await ref.update({ eliminado: false, publicada: true });
    console.log(`  ✅ Publicado: ${slug}`);
  }

  console.log('\n✔ Listo\n');
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
