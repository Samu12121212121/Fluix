/**
 * vincular_blog_libros_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Auto-vincula entradas de blog (noticias/entrevistas) a libros del catálogo
 * rellenando el campo `libro_id` y `autor_id` en las entradas sin vincular.
 *
 * Estrategia:
 *   1. Coincidencia exacta de autor (normalizado: sin tildes, minúsculas)
 *   2. Si hay 1 libro del autor → vincula automáticamente
 *   3. Si hay varios → lista los candidatos para revisión manual
 *   4. Si no hay coincidencia → lista como sin resolver
 *
 * Modos:
 *   --dry-run   (defecto) Solo muestra el plan, no escribe nada
 *   --confirmar Escribe los cambios en Firestore
 *   --todos     Procesa también entradas ya vinculadas (--confirmar reemplaza)
 *
 * Uso:
 *   cd functions
 *   node scripts/vincular_blog_libros_nazari.js
 *   node scripts/vincular_blog_libros_nazari.js --confirmar
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');

const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
const sa     = require(saPath);
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID       = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const CONFIRMAR = process.argv.includes('--confirmar');
const TODOS     = process.argv.includes('--todos');

// ── Normalizar texto para comparación ────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// ── Extraer posible nombre de autor del título del blog ───────────────────────
// "Juan Pérez en Radio X" → "Juan Pérez"
// "«Libro X» de Juan Pérez en..." → "Juan Pérez"
function extraerAutorDelTitulo(titulo = '') {
  // Intentar extraer "Autor en ..." al principio del título
  const mEn = titulo.match(/^(.+?)\s+en\s+/i);
  if (mEn) {
    const cand = mEn[1].replace(/[«»"']/g, '').trim();
    // Descartar si parece un título de libro (empieza con mayúscula + contiene artículos)
    if (cand.split(' ').length >= 2 && cand.split(' ').length <= 5) return cand;
  }
  // "«Libro» con/por Autor en ..."
  const mCon = titulo.match(/(?:con|por)\s+([A-ZÁÉÍÓÚÑÜ][^,«»]+?)(?:\s+en|\s*$)/i);
  if (mCon) return mCon[1].trim();
  return null;
}

async function run() {
  console.log('\n📚 Vincular entradas de blog a libros — Editorial Nazarí');
  console.log(`   Empresa : ${EID}`);
  console.log(`   Modo    : ${CONFIRMAR ? '✏️  CONFIRMAR (escribe en Firestore)' : '🔍 DRY-RUN (solo muestra el plan)'}\n`);

  // 1. Cargar todos los libros
  const librosSnap = await db.collection('empresas').doc(EID).collection('libros').get();
  const libros = librosSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  console.log(`📖 ${libros.length} libros en catálogo`);

  // Índice: autor_norm → lista de libros
  const librosPorAutor = {};
  for (const l of libros) {
    const autorRaw = l.autor || l.campo_autor || '';
    if (!autorRaw) continue;
    const k = norm(autorRaw);
    if (!librosPorAutor[k]) librosPorAutor[k] = [];
    librosPorAutor[k].push(l);
  }

  // 2. Cargar entradas de blog sin libro_id (o todas si --todos)
  let query = db.collection('empresas').doc(EID).collection('blog');
  const blogSnap = await query.get();
  const entradas = blogSnap.docs
    .map(d => ({ _docId: d.id, ...d.data() }))
    .filter(e => !e.eliminado)
    .filter(e => TODOS || !e.libro_id);

  console.log(`📝 ${entradas.length} entradas${TODOS ? '' : ' sin libro_id'} a procesar\n`);

  // 3. Intentar vincular
  const vinculadas   = [];
  const ambiguas     = [];
  const sinAutor     = [];
  const sinLibro     = [];

  for (const entrada of entradas) {
    let autorBuscar = (entrada.autor || '').trim();

    // Si no tiene autor, intentar extraerlo del título
    if (!autorBuscar) {
      const extraido = extraerAutorDelTitulo(entrada.titulo || '');
      if (extraido) autorBuscar = extraido;
    }

    if (!autorBuscar) {
      sinAutor.push({ titulo: entrada.titulo, id: entrada._docId });
      continue;
    }

    const k = norm(autorBuscar);
    const candidatos = librosPorAutor[k] || [];

    // Búsqueda parcial si no hay exacta (apellido principal)
    let listaCandidatos = candidatos;
    if (!candidatos.length) {
      const partes = k.split(' ').filter(p => p.length > 3);
      for (const parte of partes) {
        const parciales = Object.keys(librosPorAutor)
          .filter(ak => ak.includes(parte))
          .flatMap(ak => librosPorAutor[ak]);
        if (parciales.length) { listaCandidatos = parciales; break; }
      }
    }

    if (!listaCandidatos.length) {
      sinLibro.push({ titulo: entrada.titulo, autor: autorBuscar, id: entrada._docId });
    } else if (listaCandidatos.length === 1) {
      vinculadas.push({
        entradaId: entrada._docId,
        titulo:    entrada.titulo,
        autor:     autorBuscar,
        libroId:   listaCandidatos[0].id,
        libroTit:  listaCandidatos[0].titulo || listaCandidatos[0].nombre || '',
      });
    } else {
      ambiguas.push({
        titulo:    entrada.titulo,
        autor:     autorBuscar,
        id:        entrada._docId,
        candidatos: listaCandidatos.map(l => `${l.id} — ${l.titulo || l.nombre || ''}`),
      });
    }
  }

  // 4. Mostrar resultado
  console.log(`✅ Vinculaciones automáticas : ${vinculadas.length}`);
  console.log(`⚠️  Ambiguas (varios libros)  : ${ambiguas.length}`);
  console.log(`❌ Sin autor identificado    : ${sinAutor.length}`);
  console.log(`🔍 Sin libro en catálogo     : ${sinLibro.length}\n`);

  if (vinculadas.length) {
    console.log('── VINCULACIONES AUTOMÁTICAS ────────────────────────────────');
    for (const v of vinculadas) {
      console.log(`  [${v.entradaId}] "${v.titulo.substring(0,60)}" → libro: "${v.libroTit}" (${v.libroId})`);
    }
    console.log('');
  }

  if (ambiguas.length) {
    console.log('── AMBIGUAS (requieren selección manual) ────────────────────');
    for (const a of ambiguas) {
      console.log(`  [${a.id}] "${a.titulo.substring(0,60)}" (autor: ${a.autor})`);
      for (const c of a.candidatos) console.log(`    · ${c}`);
    }
    console.log('');
  }

  if (sinLibro.length) {
    console.log('── SIN LIBRO EN CATÁLOGO ─────────────────────────────────────');
    for (const s of sinLibro) {
      console.log(`  [${s.id}] "${s.titulo.substring(0,60)}" (autor: ${s.autor})`);
    }
    console.log('');
  }

  // 5. Escribir si --confirmar
  if (!CONFIRMAR) {
    console.log('💡 Ejecuta con --confirmar para aplicar las vinculaciones automáticas.\n');
    return;
  }

  if (!vinculadas.length) {
    console.log('ℹ️  Sin vinculaciones automáticas que aplicar.\n');
    return;
  }

  console.log(`\n✏️  Escribiendo ${vinculadas.length} vinculaciones en Firestore…`);
  const col = db.collection('empresas').doc(EID).collection('blog');

  // Procesar en lotes de 500 (límite Firestore batch)
  for (let i = 0; i < vinculadas.length; i += 400) {
    const chunk = vinculadas.slice(i, i + 400);
    const batch = db.batch();
    for (const v of chunk) {
      batch.update(col.doc(v.entradaId), {
        libro_id:           v.libroId,
        fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    console.log(`  … ${Math.min(i + 400, vinculadas.length)} / ${vinculadas.length} escritas`);
  }

  console.log(`\n🎉 Listo. ${vinculadas.length} entradas vinculadas a su libro.\n`);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
