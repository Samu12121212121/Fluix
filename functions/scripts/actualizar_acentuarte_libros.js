/**
 * actualizar_acentuarte_libros.js
 * Actualiza los 135 libros de Acentuarte en Firebase con sinopsis e imagen.
 * Uso: node scripts/actualizar_acentuarte_libros.js
 */
'use strict';
const admin = require('firebase-admin');
const fs    = require('fs');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID_AC   = 'pU4wGaElcyoDR5dA0YNO';
const DATA_FILE = 'C:\\Users\\Samu\\Downloads\\wpress_extracted\\acentuarte_libros_completos.json';

async function run() {
  const libros = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  console.log(`Libros a sincronizar: ${libros.length}`);

  const col  = db.collection('empresas').doc(EID_AC).collection('catalogo_web');
  const snap = await col.get();

  // Mapa slug → docId
  const bySlug = new Map();
  const byWpId = new Map();
  snap.forEach(doc => {
    const d = doc.data();
    if (d.slug)  bySlug.set(d.slug,  doc.id);
    if (d.wp_id) byWpId.set(d.wp_id, doc.id);
  });
  console.log(`Docs existentes en Firebase: ${snap.size}`);

  let updated = 0, created = 0;
  const BATCH = 250;
  let batch = db.batch();
  let cnt = 0;

  async function flush() {
    if (cnt > 0) { await batch.commit(); batch = db.batch(); cnt = 0; }
  }

  for (const l of libros) {
    const docId = bySlug.get(l.slug) || byWpId.get(l.wp_id);
    const update = {
      titulo:        l.titulo    || '',
      nombre:        l.titulo    || '',
      slug:          l.slug      || '',
      autor:         l.autor     || '',
      campo_autor:   l.autor     || '',
      genero:        l.genero    || '',
      categoria:     l.genero    || '',
      coleccion:     l.coleccion || '',
      precio:        l.precio    || '',
      isbn:          l.isbn      || '',
      isbn13:        l.isbn13    || '',
      encuadernacion: l.encuadernacion || 'Rústica con solapas',
      sinopsis:      l.sinopsis  || '',
      descripcion:   l.sinopsis  || '',
      descripcionLarga: l.sinopsis || '',
      imagen:        l.imagen    || '',
      imagen_url:    l.imagen    || '',
      activo:        true,
      wp_id:         l.wp_id || null,
    };

    if (docId) {
      batch.update(col.doc(docId), update);
      updated++;
    } else {
      batch.set(col.doc(), { ...update, created_at: admin.firestore.FieldValue.serverTimestamp() });
      created++;
    }
    cnt++;
    if (cnt >= BATCH) await flush();
  }
  await flush();

  console.log(`✓ Actualizados: ${updated} | Creados: ${created}`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
