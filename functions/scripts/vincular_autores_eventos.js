/**
 * vincular_autores_eventos.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Para cada evento que tenga libro_titulo pero no autor_nombre:
 *  1. Busca el libro en `catalogo` (por título normalizado)
 *  2. Saca el nombre del autor del libro (atributos_extra.autor)
 *  3. Busca el autor en `autores` (por nombre normalizado)
 *  4. Actualiza el evento con autor_nombre + autor_id + libro_id
 *
 * Uso:
 *   cd functions
 *   node scripts/vincular_autores_eventos.js          ← ver qué vincularía
 *   node scripts/vincular_autores_eventos.js --aplicar ← aplicar cambios
 * ─────────────────────────────────────────────────────────────────────────────
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db      = admin.firestore();
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const APLICAR = process.argv.includes('--aplicar');

function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/['''"""]/g, '').replace(/\s+/g, ' ').trim();
}

(async () => {
  // ── 1. Cargar catálogo (libros) ────────────────────────────────────────────
  console.log('Cargando catálogo...');
  const catSnap = await db.collection('empresas').doc(EID).collection('catalogo').get();
  const libros  = new Map(); // norm(titulo) → { id, nombre, autor }
  catSnap.forEach(doc => {
    const d = doc.data();
    const nombre = d.nombre || '';
    const autor  = d.atributos_extra?.autor || d.campo_autor || '';
    if (nombre) libros.set(norm(nombre), { id: doc.id, nombre, autor });
  });
  // También intentar catalogo_web
  const catWebSnap = await db.collection('empresas').doc(EID).collection('catalogo_web').get();
  catWebSnap.forEach(doc => {
    const d = doc.data();
    const nombre = d.titulo || d.nombre || '';
    const autores = d.autores && d.autores.length ? d.autores.map(a => a.nombre||'').filter(Boolean).join(', ') : (d.campo_autor || d.autor || '');
    if (nombre && !libros.has(norm(nombre))) libros.set(norm(nombre), { id: doc.id, nombre, autor: autores });
  });
  console.log(`  → ${libros.size} libros indexados\n`);

  // ── 2. Cargar autores ───────────────────────────────────────────────────────
  console.log('Cargando autores...');
  const autSnap  = await db.collection('empresas').doc(EID).collection('autores').get();
  const autores  = new Map(); // norm(nombre) → { id, nombre }
  autSnap.forEach(doc => {
    const d = doc.data();
    const nombre = d.nombre || '';
    if (nombre) autores.set(norm(nombre), { id: doc.id, nombre });
  });
  console.log(`  → ${autores.size} autores indexados\n`);

  // ── 3. Cargar eventos sin autor ─────────────────────────────────────────────
  console.log('Cargando eventos...');
  const evSnap = await db.collection('empresas').doc(EID).collection('eventos').get();
  const sinAutor = [];
  evSnap.forEach(doc => {
    const d = doc.data();
    if (d.eliminado === true) return;
    // Sin autor pero con libro_titulo
    if (!d.autor_nombre && d.libro_titulo) sinAutor.push({ id: doc.id, ...d });
  });
  console.log(`  → ${evSnap.size} eventos totales`);
  console.log(`  → ${sinAutor.length} sin autor pero con libro_titulo\n`);

  // ── 4. Cruzar y vincular ────────────────────────────────────────────────────
  let vinculados = 0, sinLibro = 0, sinAutorMatch = 0;
  const batch   = db.batch();
  let batchSize = 0;

  for (const ev of sinAutor) {
    const tituloNorm = norm(ev.libro_titulo || '');
    const libro = libros.get(tituloNorm);

    if (!libro) {
      // Búsqueda parcial: libro cuyo título normalizado contiene el del evento
      let mejorMatch = null;
      for (const [k, v] of libros) {
        if (k.includes(tituloNorm) || tituloNorm.includes(k)) { mejorMatch = v; break; }
      }
      if (!mejorMatch) {
        sinLibro++;
        console.log(`  ✗ Libro no encontrado: "${ev.libro_titulo}" (evento: ${ev.id})`);
        continue;
      }
      // Usar el match parcial
      libros.set(tituloNorm, mejorMatch); // cachear para próximas iteraciones
      const autor  = mejorMatch.autor;
      const autorDoc = autores.get(norm(autor)) || buscarAutorParcial(autores, norm(autor));
      if (!autor) { sinAutorMatch++; continue; }
      aplicarVinculo(ev, mejorMatch, autorDoc);
    } else {
      const autor    = libro.autor;
      if (!autor) { sinAutorMatch++; continue; }
      const autorDoc = autores.get(norm(autor)) || buscarAutorParcial(autores, norm(autor));
      aplicarVinculo(ev, libro, autorDoc);
    }

    function aplicarVinculo(evento, lib, autorDoc) {
      const update = {
        libro_id:     lib.id,
        libro_titulo: lib.nombre,
        autor_nombre: lib.autor,
        ...(autorDoc ? { autor_id: autorDoc.id } : {}),
      };
      console.log(`  ✓ ${evento.id.substring(0,35).padEnd(36)} → autor: ${lib.autor}${autorDoc ? ` (${autorDoc.id.substring(0,12)})` : ' (sin ID)'}`);
      if (APLICAR) {
        batch.update(
          db.collection('empresas').doc(EID).collection('eventos').doc(evento.id),
          update
        );
        batchSize++;
        vinculados++;
      } else {
        vinculados++;
      }
    }
  }

  function buscarAutorParcial(mapaAutores, nombreNorm) {
    for (const [k, v] of mapaAutores) {
      const partes = nombreNorm.split(' ');
      if (partes.some(p => p.length > 3 && k.includes(p))) return v;
    }
    return null;
  }

  // ── 5. Resultado ────────────────────────────────────────────────────────────
  console.log(`\n${'─'.repeat(55)}`);
  console.log(`Vinculables:        ${vinculados}`);
  console.log(`Sin libro en cat.:  ${sinLibro}`);
  console.log(`Sin autor en cat.:  ${sinAutorMatch}`);

  if (APLICAR && batchSize > 0) {
    await batch.commit();
    console.log(`\n✓ ${batchSize} eventos actualizados en Firestore`);
  } else if (!APLICAR) {
    console.log('\nEjecuta con --aplicar para guardar los cambios.');
  }

  process.exit(0);
})();
