/**
 * cotejo_autores_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Compara los autores en Firestore (empresas/{EID}/autores) con todos los
 * autores únicos que aparecen en los libros del catálogo (libros-data.js).
 *
 * Para cada autor en los libros que NO esté en Firestore, crea una entrada
 * básica con el nombre para que aparezca en el módulo web de Autores.
 *
 * Uso:
 *   cd functions
 *   node scripts/cotejo_autores_nazari.js              ← solo diagnóstico
 *   node scripts/cotejo_autores_nazari.js --importar   ← crea los que faltan
 *
 * Fuente de verdad de libros: Desktop/imagenes_nazari/html_nazari/libros-data.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const fs    = require('fs');
const vm    = require('vm');
const path  = require('path');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const IMPORTAR = process.argv.includes('--importar');

// Ruta al libros-data.js local
const LIBROS_PATH = path.resolve(
  __dirname,
  '../../../../Desktop/imagenes_nazari/html_nazari/libros-data.js'
);

function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

function cargarLibros() {
  let code = fs.readFileSync(LIBROS_PATH, 'utf8');
  // Eliminar el bloque _fixGrid al final (solo nos importa el array LIBROS)
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  // Truncar en el cierre del array para evitar ejecutar el IIFE del DOM
  const finArray = code.indexOf('\n];') ;
  if (finArray !== -1) code = code.slice(0, finArray + 3) + '\n';
  const ctx = {};
  try { vm.runInNewContext(code, ctx); } catch (_) {}
  return ctx['LIBROS'] || [];
}

// Extrae nombres únicos de autores de los libros (incluyendo autorExtra)
function extraerAutoresDeLibros(libros) {
  const autoresMap = new Map(); // norm(nombre) → nombre canónico

  for (const l of libros) {
    // Autor principal
    if (l.autor) {
      const n = norm(l.autor);
      if (n && !autoresMap.has(n)) autoresMap.set(n, l.autor.trim());
    }
    // Autor extra (traductores, ilustradores, etc.)
    if (l.autorExtra) {
      // Puede contener "Trad. X · Ilust. Y" — extraer nombres
      const partes = l.autorExtra.split(/[·,]/).map(p => {
        return p.replace(/^(Trad\.|Ilust\.|Prólogo de|Pról\.|Ed\.)\s*/i, '').trim();
      }).filter(p => p.length > 2);
      for (const p of partes) {
        const n = norm(p);
        if (n && !autoresMap.has(n)) autoresMap.set(n, p);
      }
    }
  }

  return autoresMap; // Map<normNombre, nombreCanónico>
}

async function run() {
  console.log('\n👥 Cotejo de autores Nazarí\n');

  // 1. Cargar libros-data.js
  console.log('📖 Cargando libros-data.js...');
  const libros = cargarLibros();
  if (libros.length === 0) {
    console.error('❌ No se pudo cargar LIBROS desde libros-data.js');
    console.error('   Ruta buscada:', LIBROS_PATH);
    process.exit(1);
  }
  console.log(`   → ${libros.length} libros cargados`);
  const autoresEnLibros = extraerAutoresDeLibros(libros);
  console.log(`   → ${autoresEnLibros.size} autores únicos en los libros\n`);

  // 2. Autores en Firestore
  console.log('🔥 Leyendo autores de Firestore...');
  const snapFS = await db.collection('empresas').doc(EID).collection('autores').get();
  const fsNombresNorm = new Set();
  for (const doc of snapFS.docs) {
    const nombre = (doc.data().nombre || '').trim();
    if (nombre) fsNombresNorm.add(norm(nombre));
  }
  console.log(`   → ${snapFS.size} autores en Firestore\n`);

  // 3. Encontrar los que faltan
  const faltantes = [];
  for (const [normNombre, nombreCanon] of autoresEnLibros) {
    if (!fsNombresNorm.has(normNombre)) {
      // Buscar los libros de este autor
      const susLibros = libros
        .filter(l => l.autor && norm(l.autor) === normNombre)
        .map(l => l.titulo).slice(0, 3);
      faltantes.push({ nombre: nombreCanon, libros: susLibros });
    }
  }

  console.log('📊 Resumen:');
  console.log(`   Autores en libros:   ${autoresEnLibros.size}`);
  console.log(`   En Firestore:        ${snapFS.size}`);
  console.log(`   Faltan:              ${faltantes.length}\n`);

  if (faltantes.length === 0) {
    console.log('✅ Todos los autores de los libros están en Firestore.\n');
    process.exit(0);
  }

  console.log('📋 Autores que faltan (primeros 30):');
  faltantes.slice(0, 30).forEach((a, i) => {
    console.log(`  ${String(i + 1).padStart(3)}. ${a.nombre}  [libros: ${a.libros.join(' / ')}]`);
  });
  if (faltantes.length > 30) console.log(`  ... y ${faltantes.length - 30} más`);

  if (!IMPORTAR) {
    console.log('\n💡 Ejecuta con --importar para crear los que faltan en Firestore.\n');
    process.exit(0);
  }

  // 4. Crear entradas básicas en Firestore para los autores que faltan
  console.log(`\n📥 Creando ${faltantes.length} autores en Firestore...`);
  const ahora = admin.firestore.Timestamp.now();
  const col   = db.collection('empresas').doc(EID).collection('autores');

  const LOTE = 500;
  let batch  = db.batch();
  let cnt    = 0;
  let ok     = 0;

  for (const a of faltantes) {
    // Generar slug a partir del nombre
    const slugBase = norm(a.nombre).replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
    const docId    = `auto_${slugBase}_${Date.now().toString(36)}`;
    const ref      = col.doc(docId);

    batch.set(ref, {
      nombre:        a.nombre,
      slug:          slugBase,
      bio:           '',
      descripcion:   '',
      foto_url:      null,
      foto:          null,
      genero:        '',
      lugar:         '',
      activo:        true,
      eliminado:     false,
      _fuente:       'cotejo_libros',
      _importado_en: ahora,
    });

    cnt++;
    ok++;

    if (cnt >= LOTE) {
      await batch.commit();
      console.log(`   Lote completado: ${ok} autores creados`);
      batch = db.batch();
      cnt   = 0;
    }
  }

  if (cnt > 0) await batch.commit();

  console.log(`\n🎉 Creados ${ok} autores nuevos en Firestore.`);
  console.log('   Aparecerán en el módulo web de Autores sin bio ni foto.');
  console.log('   Alejandro puede completar los perfiles desde la app.\n');
  process.exit(0);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
