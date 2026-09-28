/**
 * subir_ebooks_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * 1. Lee todos los .epub de EBOOKS_DIR
 * 2. Los matchea con slugs de libros-data.js (Editorial Nazarí)
 * 3. Sube cada epub a Firebase Storage en ebooks/{slug}.epub
 * 4. Actualiza empresas/{EID}/catalogo_web/{slug} con ebook_storage_path
 *
 * Uso:
 *   cd functions
 *   node subir_ebooks_nazari.js            (sube + actualiza Firestore)
 *   node subir_ebooks_nazari.js --dry-run  (solo muestra matches, no escribe)
 *
 * Requiere: serviceAccountKey.json en functions/ (o firebase login activo)
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const vm    = require('vm');

const DRY_RUN   = process.argv.includes('--dry-run');
const EBOOKS_DIR = path.join(os.homedir(), 'Downloads', 'wetransfer_ebooks_2026-09-27_1248');
const HTML_DIR   = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');
const EID        = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET     = 'planeaapp-4bea4.appspot.com';

// ── Credenciales ──────────────────────────────────────────────────────────────
if (!DRY_RUN) {
  const saPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    const sa = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
  } else {
    function getRefreshToken() {
      const candidates = [
        path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
      ];
      for (const p of candidates) {
        try {
          const d = JSON.parse(fs.readFileSync(p, 'utf8'));
          const rt = d?.tokens?.refresh_token;
          if (rt) return rt;
        } catch (_) {}
      }
      return null;
    }
    const rt = getRefreshToken();
    if (!rt) {
      console.error('❌ No se encontró serviceAccountKey.json ni token de Firebase CLI.');
      process.exit(1);
    }
    admin.initializeApp({
      credential: admin.credential.refreshToken({
        type: 'authorized_user',
        client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
        client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p',
        refresh_token: rt,
      }),
      projectId: 'planeaapp-4bea4',
      storageBucket: BUCKET,
    });
  }
}

// ── Normalización ─────────────────────────────────────────────────────────────
function normalize(str) {
  return str
    .toLowerCase()
    // Reemplazar caracteres especiales que NFD no descompone
    .replace(/ø/g, 'o').replace(/å/g, 'a').replace(/æ/g, 'ae')
    .replace(/ð/g, 'd').replace(/þ/g, 'th').replace(/ß/g, 'ss')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')  // quitar tildes/diacríticos
    .replace(/[¿?¡!,.:;'"()[\]{}]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// Mapa manual para casos que el algoritmo no resuelve automáticamente
const MANUAL_MAP = {
  // Nombre del archivo (sin extensión, sin el " - eBook DD-MM-YYYY") → slug exacto en catálogo
  'Sit tibi terra levis I':          'sit-tibi-terra-levis',
  'Skørdåt I':                       'skordati-nueve-formas-de-morir-en-el-espacio',
  'Ultima batalla':                  'ultima-batalla-el-senor-de-las-bestias',
  'El Legado de los Dioses I':       'el-legado-de-los-dioses-i',
  'El Legado de los Dioses II':      'el-legado-de-los-dioses-ii',
};

function toSlug(str) {
  return normalize(str).replace(/\s+/g, '-');
}

// Extrae el título limpio del nombre del archivo epub
// Ejemplos:
//   "Asesinato en la Alhambra - eBook 29-03-2020.epub"  → "Asesinato en la Alhambra"
//   "Maldito vicio - Carlos de la Fe - eBook 31-03-2020.epub" → "Maldito vicio"
//   "Cómodamente adormecido - 14-07-2025.epub" → "Cómodamente adormecido"
//   "Sales a jugar un ratito - ebook 26-08-2020.epub" → "Sales a jugar un ratito"
function tituloDesdeFilename(filename) {
  let name = path.basename(filename, '.epub');
  // Eliminar " - eBook DD-MM-YYYY" o " - ebook DD-MM-YYYY" o " - DD-MM-YYYY"
  name = name.replace(/\s*-\s*e[Bb]ook\s+\d{2}-\d{2}-\d{4}$/i, '');
  name = name.replace(/\s*-\s*\d{2}-\d{2}-\d{4}$/i, '');
  // Eliminar autor extra tras segundo guion (ej: "Maldito vicio - Carlos de la Fe")
  // Solo si lo que queda tras el primer guion parece un nombre propio (mayúscula)
  const parts = name.split(' - ');
  if (parts.length > 1 && /^[A-ZÁÉÍÓÚÑÜ]/.test(parts[1])) {
    // Podría ser autor extra; lo descartamos solo si el título original matchea solo con parts[0]
    // Lo dejamos para resolución posterior vía fuzzy match
  }
  return name.trim();
}

// ── Cargar libros-data.js ─────────────────────────────────────────────────────
function loadLibrosData() {
  const filePath = path.join(HTML_DIR, 'libros-data.js');
  if (!fs.existsSync(filePath)) {
    console.error(`❌ No encontrado: ${filePath}`);
    process.exit(1);
  }
  const code = fs.readFileSync(filePath, 'utf8');
  const sandbox = {};
  vm.runInNewContext(code + '\nif(typeof LIBROS!=="undefined") module.LIBROS=LIBROS;', { module: sandbox });
  if (!sandbox.LIBROS) {
    // Fallback: parsear con regex
    const slugs   = [...code.matchAll(/slug:\s*"([^"]+)"/g)].map(m => m[1]);
    const titulos = [...code.matchAll(/titulo:\s*"([^"]+)"/g)].map(m => m[1]);
    return slugs.map((slug, i) => ({ slug, titulo: titulos[i] || '' }));
  }
  return sandbox.LIBROS;
}

// ── Match epub → libro ────────────────────────────────────────────────────────
function matchLibro(epubFile, libros) {
  const rawTitle = tituloDesdeFilename(epubFile);
  const normTitle = normalize(rawTitle);
  const slugCandidate = toSlug(rawTitle);

  // 0. Mapa manual para casos especiales
  const manualSlug = MANUAL_MAP[rawTitle] || MANUAL_MAP[normalize(rawTitle).replace(/\s+/g, '-')]
    || MANUAL_MAP[rawTitle.replace(/ø/g,'o').replace(/å/g,'a').replace(/æ/g,'ae')];
  if (manualSlug) {
    const libro = libros.find(l => l.slug === manualSlug);
    if (libro) return { libro, confidence: 'manual' };
    // Slug del mapa no existe en catálogo (ej: Legado de los Dioses no está en libros-data)
    return { libro: { slug: manualSlug, titulo: rawTitle }, confidence: 'manual-missing' };
  }

  // 1. Match exacto por slug derivado del título
  const exactSlug = libros.find(l => l.slug === slugCandidate);
  if (exactSlug) return { libro: exactSlug, confidence: 'exact-slug' };

  // 2. Match por título normalizado exacto
  const exactTitle = libros.find(l => normalize(l.titulo) === normTitle);
  if (exactTitle) return { libro: exactTitle, confidence: 'exact-title' };

  // 3. Match parcial: título del epub es prefijo palabra-completa del título del libro
  // Requiere que el título del epub ocupe al menos el 60% de las palabras del título del libro
  const partial = libros.find(l => {
    const lNorm = normalize(l.titulo);
    if (!lNorm.startsWith(normTitle + ' ') && lNorm !== normTitle) return false;
    const lWords = lNorm.split(' ').length;
    const tWords = normTitle.split(' ').length;
    return tWords / lWords >= 0.6;
  });
  if (partial) return { libro: partial, confidence: 'partial' };

  // 4. Fuzzy: mayor número de palabras en común
  const words = new Set(normTitle.split(' ').filter(w => w.length > 3));
  let best = null, bestScore = 0;
  for (const l of libros) {
    const lWords = normalize(l.titulo).split(' ').filter(w => w.length > 3);
    const score = lWords.filter(w => words.has(w)).length;
    if (score > bestScore) { bestScore = score; best = l; }
  }
  if (best && bestScore >= 2) return { libro: best, confidence: `fuzzy(${bestScore})` };

  return null;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n📚 Subida de ebooks a Firebase Storage — Editorial Nazarí`);
  console.log(`   Modo: ${DRY_RUN ? 'DRY-RUN (sin escritura)' : 'REAL'}\n`);

  if (!fs.existsSync(EBOOKS_DIR)) {
    console.error(`❌ No existe la carpeta: ${EBOOKS_DIR}`);
    process.exit(1);
  }

  const libros = loadLibrosData();
  console.log(`✅ ${libros.length} libros cargados de libros-data.js`);

  const epubs = fs.readdirSync(EBOOKS_DIR).filter(f => f.toLowerCase().endsWith('.epub'));
  console.log(`✅ ${epubs.length} archivos .epub encontrados\n`);

  const matches    = [];
  const noMatch    = [];
  const duplicates = new Map();

  for (const epub of epubs) {
    const result = matchLibro(epub, libros);
    if (!result) {
      noMatch.push(epub);
      continue;
    }
    const { libro, confidence } = result;
    if (duplicates.has(libro.slug)) {
      console.log(`⚠️  Duplicado: "${epub}" ya mapeado a slug "${libro.slug}" (se ignora)`);
      continue;
    }
    duplicates.set(libro.slug, true);
    matches.push({ epub, slug: libro.slug, titulo: libro.titulo, confidence });
  }

  // Mostrar tabla de matches
  console.log(`─── MATCHES (${matches.length}) ───────────────────────────────────────`);
  for (const m of matches) {
    const flag = m.confidence === 'exact-slug' ? '✅' : m.confidence === 'exact-title' ? '✅' : '🟡';
    console.log(`${flag} [${m.confidence.padEnd(14)}] ${m.epub.substring(0,45).padEnd(46)} → ${m.slug}`);
  }

  if (noMatch.length) {
    console.log(`\n─── SIN MATCH (${noMatch.length}) ────────────────────────────────────────`);
    noMatch.forEach(f => console.log(`  ❌ ${f}`));
  }

  console.log(`\nTotal: ${matches.length} matches, ${noMatch.length} sin match`);

  if (DRY_RUN) {
    console.log('\n[DRY-RUN] Nada se ha subido ni escrito en Firestore.');
    return;
  }

  // ── Subir a Storage y actualizar Firestore ──────────────────────────────────
  const bucket = admin.storage().bucket();
  const db     = admin.firestore();
  let uploaded = 0, skipped = 0, errors = 0;

  for (const m of matches) {
    const localPath   = path.join(EBOOKS_DIR, m.epub);
    const storagePath = `ebooks/${m.slug}.epub`;
    const destFile    = bucket.file(storagePath);

    process.stdout.write(`  ⬆  ${m.slug}.epub … `);
    try {
      // Verificar si ya existe
      const [exists] = await destFile.exists();
      if (exists) {
        process.stdout.write('ya existe, actualiza Firestore\n');
      } else {
        await bucket.upload(localPath, {
          destination: storagePath,
          metadata: {
            contentType: 'application/epub+zip',
            cacheControl: 'private, no-cache',
          },
        });
        process.stdout.write('subido ');
      }

      // Actualizar Firestore
      const docRef = db
        .collection('empresas').doc(EID)
        .collection('catalogo_web').doc(m.slug);

      const snap = await docRef.get();
      if (snap.exists) {
        await docRef.update({ ebook_storage_path: storagePath });
        process.stdout.write('→ Firestore OK\n');
      } else {
        // El libro puede no estar en catalogo_web todavía (solo en libros-data.js estático)
        process.stdout.write(`→ doc no existe en Firestore (solo Storage)\n`);
      }
      uploaded++;
    } catch (err) {
      process.stdout.write(`ERROR: ${err.message}\n`);
      errors++;
    }
  }

  console.log(`\n✅ ${uploaded} subidos/actualizados, ${skipped} omitidos, ${errors} errores`);
  if (noMatch.length) {
    console.log(`\n⚠️  Los siguientes ${noMatch.length} epub no encontraron match en el catálogo:`);
    noMatch.forEach(f => console.log(`   - ${f}`));
    console.log('   → Súbelos manualmente a Firebase Storage y añade ebook_storage_path en Firestore.');
  }
}

main().catch(err => { console.error('Fatal:', err); process.exit(1); });
