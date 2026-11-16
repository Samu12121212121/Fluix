/**
 * crear_empresa_acentuarte.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Crea la empresa "Editorial Acentuarte" en Firestore y migra:
 *   - 135 libros → empresas/{EID_AC}/catalogo_web
 *   - 68 autores → empresas/{EID_AC}/autores
 *   - 6 posts blog → empresas/{EID_AC}/blog
 *
 * Uso:
 *   cd functions
 *   node scripts/crear_empresa_acentuarte.js            ← dry-run (solo muestra)
 *   node scripts/crear_empresa_acentuarte.js --importar ← crea en Firebase
 *   node scripts/crear_empresa_acentuarte.js --vincular-nazari ← vincula al usuario
 *
 * El EID de Acentuarte se genera automáticamente la primera vez y se imprime.
 * Guárdalo para configurar la web.
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const IMPORTAR        = process.argv.includes('--importar');
const VINCULAR_NAZARI = process.argv.includes('--vincular-nazari');
const EID_NAZARI      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// ── Rutas a los JSON generados por prep2.py ──────────────────────────────────
const DATA_DIR    = 'C:\\Users\\Samu\\Downloads\\wpress_extracted';
const LIBROS_JSON = path.join(DATA_DIR, 'acentuarte_libros.json');
const AUTORES_JSON = path.join(DATA_DIR, 'acentuarte_autores.json');

// ── Helper: ejecutar en batches de 250 ───────────────────────────────────────
async function importarEnBatches(col, items, buildDoc, label) {
  const BATCH_SIZE = 250;
  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (const item of items) {
    const ref = col.doc();
    batch.set(ref, buildDoc(item));
    count++;
    total++;
    if (count >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      count = 0;
      process.stdout.write(`   → ${total}/${items.length} ${label}...\r`);
    }
  }
  if (count > 0) await batch.commit();
  console.log(`   ✓ ${total} ${label} importados`);
}

// ── Builder: libro → documento catalogo_web ───────────────────────────────────
function buildLibro(l) {
  const precioNum = parseFloat((l.precio || '16,99').replace(',', '.').replace(/[€\s]/g, '')) || 16.99;
  return {
    titulo:        l.titulo || '',
    nombre:        l.titulo || '',
    slug:          l.slug   || '',
    autor:         l.autor  || '',
    campo_autor:   l.autor  || '',
    genero:        l.genero || '',
    categoria:     l.genero || '',
    coleccion:     l.coleccion || '',
    campo_coleccion: l.coleccion || '',
    precio:        l.precio || '16,99 €',
    precio_num:    precioNum,
    isbn:          l.isbn   || '',
    isbn13:        l.isbn13 || '',
    encuadernacion: l.encuadernacion || 'Rústica con solapas',
    formato:       l.formato || '14 × 21 cm',
    imagen:        l.imagen || '',
    imagen_url:    l.imagen || '',
    sinopsis:      l.sinopsis || '',
    descripcion:   l.sinopsis || '',
    descripcionLarga: l.sinopsis || '',
    activo:        true,
    destacado:     false,
    iva_porcentaje: 4,
    stock:         15,
    tipo:          'producto',
    editorial:     'acentuarte',
    wp_id:         l.wp_id || null,
    orden:         0,
    created_at:    admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ── Builder: autor → documento autores ───────────────────────────────────────
function buildAutor(a) {
  return {
    nombre:    a.nombre   || '',
    slug:      a.slug     || '',
    bio:       a.bio      || '',
    descripcion: a.bio    || '',
    foto_url:  a.foto_url || '',
    imagen:    a.foto_url || '',
    activo:    true,
    editorial: 'acentuarte',
    wp_id:     a.wp_id   || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ── Documento de empresa ──────────────────────────────────────────────────────
function buildEmpresaDoc() {
  const ahora = admin.firestore.FieldValue.serverTimestamp();
  const fechaFin = new Date();
  fechaFin.setFullYear(fechaFin.getFullYear() + 5);

  return {
    perfil: {
      nombre:      'Editorial Acentuarte',
      correo:      'info@editorialacentuarte.es',
      telefono:    '+34 620 32 75 27',
      direccion:   'Granada, España',
      descripcion: 'Editorial independiente especializada en autoedición. Tu imaginación, convertida en libro.',
      logo_url:    '',
      fecha_creacion: ahora,
      ciudad:      'Granada',
      provincia:   'Granada',
      pais:        'ES',
      web:         'https://editorialacentuarte.es',
    },
    suscripcion: {
      fecha_inicio: ahora,
      fecha_fin:    fechaFin.toISOString(),
      aviso_enviado: false,
      monto:        0,
      estado:       'activa',
    },
    configuracion: {
      modulos_activos: {
        catalogo_web:  true,
        autores:       true,
        blog:          true,
        eventos:       false,
        pedidos:       false,
        facturacion:   false,
      },
      configuracion_modulos: {},
      criterio_iva: 'devengo',
    },
    estadisticas: {
      total_clientes: 0,
      total_reservas: 0,
      total_servicios: 0,
      ingresos_mes: 0,
      ingresos_anio: 0,
      valoracion_promedio: 0,
      total_valoraciones: 0,
      fecha_actualizacion: ahora,
    },
    sector:    'editorial',
    actividad: 'Editorial autoedición',
    estado:    'activa',
    created_by: EID_NAZARI,
    empresa_madre: EID_NAZARI,
    tipo_tpv: 'tienda',
    created_at: ahora,
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function run() {
  console.log('═══════════════════════════════════════════════════');
  console.log('  Editorial Acentuarte — Importador Firebase');
  console.log('═══════════════════════════════════════════════════\n');

  // Cargar datos
  const libros  = JSON.parse(fs.readFileSync(LIBROS_JSON,  'utf8'));
  const autores = JSON.parse(fs.readFileSync(AUTORES_JSON, 'utf8'));

  console.log(`📚 Libros:  ${libros.length}`);
  console.log(`👤 Autores: ${autores.length}`);
  console.log();

  if (!IMPORTAR) {
    console.log('⚠️  DRY-RUN — Para importar de verdad: --importar\n');
    console.log('Muestra de libros:');
    libros.slice(0, 5).forEach(l =>
      console.log(`  · ${l.titulo.substring(0,45).padEnd(45)} | ${(l.autor||'').substring(0,25).padEnd(25)} | ${l.precio} | ${l.genero}`)
    );
    console.log('  ...');
    console.log('\nMuestra de autores:');
    autores.slice(0, 5).forEach(a => console.log(`  · ${a.nombre}`));
    return;
  }

  // ── 1. Crear empresa ───────────────────────────────────────────────────────
  console.log('1️⃣  Creando empresa Acentuarte en Firestore...');
  const empresaRef = db.collection('empresas').doc();
  const EID_AC = empresaRef.id;
  await empresaRef.set(buildEmpresaDoc());
  console.log(`   ✓ Empresa creada con ID: ${EID_AC}\n`);
  console.log('   ⚠️  GUARDA ESTE ID para configurar la web y el app:');
  console.log(`   EID_ACENTUARTE = '${EID_AC}'\n`);

  // ── 2. Importar libros ─────────────────────────────────────────────────────
  console.log('2️⃣  Importando libros...');
  const librosCol = empresaRef.collection('catalogo_web');
  await importarEnBatches(librosCol, libros, buildLibro, 'libros');
  console.log();

  // ── 3. Importar autores ────────────────────────────────────────────────────
  console.log('3️⃣  Importando autores...');
  const autoresCol = empresaRef.collection('autores');
  await importarEnBatches(autoresCol, autores, buildAutor, 'autores');
  console.log();

  // ── 4. Crear blog posts básicos ────────────────────────────────────────────
  console.log('4️⃣  Creando posts de blog...');
  const blogPosts = [
    { titulo: 'Consejos para publicar tu libro',    slug: 'consejos-para-publicar-tu-libro',    tipo: 'noticia' },
    { titulo: 'Pasos para publicar tu libro',        slug: 'pasos-para-publicar-tu-libro',        tipo: 'noticia' },
    { titulo: 'Ebook: todo lo que necesitas saber', slug: 'ebook',                              tipo: 'noticia' },
    { titulo: 'Nuestros Servicios',                  slug: 'nuestros-servicios',                  tipo: 'noticia' },
    { titulo: 'Consejos para escribir una novela',   slug: 'consejos-para-escribir-una-novela',   tipo: 'noticia' },
  ];
  const blogCol = empresaRef.collection('blog');
  let blogBatch = db.batch();
  blogPosts.forEach(p => {
    blogBatch.set(blogCol.doc(), {
      titulo: p.titulo,
      slug: p.slug,
      tipo: p.tipo,
      contenido: '',
      publicada: true,
      fecha_publicacion: admin.firestore.FieldValue.serverTimestamp(),
      editorial: 'acentuarte',
    });
  });
  await blogBatch.commit();
  console.log(`   ✓ ${blogPosts.length} posts creados\n`);

  // ── 5. Vincular al usuario Nazarí (opcional) ───────────────────────────────
  if (VINCULAR_NAZARI) {
    console.log('5️⃣  Vinculando empresa a usuarios de Nazarí...');
    const usersSnap = await db.collection('usuarios')
      .where('empresa_id', '==', EID_NAZARI)
      .get();
    let vinculados = 0;
    const vBatch = db.batch();
    usersSnap.forEach(doc => {
      vBatch.update(doc.ref, {
        empresa_ids: admin.firestore.FieldValue.arrayUnion(EID_AC),
      });
      vinculados++;
    });
    await vBatch.commit();
    console.log(`   ✓ ${vinculados} usuarios vinculados a Acentuarte\n`);
  }

  console.log('═══════════════════════════════════════════════════');
  console.log('✅ IMPORTACIÓN COMPLETADA');
  console.log(`   EID_ACENTUARTE = '${EID_AC}'`);
  console.log('═══════════════════════════════════════════════════');
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
