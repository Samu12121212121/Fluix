/**
 * extractor.js — Extractor WordPress → master.json
 *
 * Usa la WordPress REST API para obtener noticias, entrevistas, autores
 * y libros de Editorial Nazarí, y vuelca todo en master.json.
 *
 * Uso:
 *   node scripts/nazari/extractor.js
 *   node scripts/nazari/extractor.js --url https://www.editorialnazari.com
 *   node scripts/nazari/extractor.js --url https://www.editorialnazari.com --out scripts/nazari/master.json
 *   node scripts/nazari/extractor.js --tipos noticias,entrevistas
 *   node scripts/nazari/extractor.js --verbose
 *   node scripts/nazari/extractor.js --wp-user admin --wp-pass "xxxx xxxx xxxx"  (credenciales opcionales)
 *
 * Salida: master.json (por defecto en el mismo directorio que este script)
 */

'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');

// ── CLI args ──────────────────────────────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const get  = (flag) => { const i = args.indexOf(flag); return i !== -1 ? args[i + 1] : null; };
  // Soporte para URL posicional: node extractor.js https://...
  const positional = args.find(a => a.startsWith('http'));
  return {
    wpBase:  (positional ?? get('--url') ?? 'https://www.editorialnazari.com').replace(/\/$/, ''),
    outFile: get('--out') ?? path.join(__dirname, 'master.json'),
    tipos:   (get('--tipos') ?? 'noticias,entrevistas,autores,libros').split(','),
    delay:   parseInt(get('--delay') ?? '300', 10),
    verbose: args.includes('--verbose'),
    wpUser:     get('--wp-user')     ?? null,
    wpPass:     get('--wp-pass')     ?? null,
    autoresFile: get('--autores-file') ?? null,  // ruta a autores-data.js como fallback
  };
}

const cfg = parseArgs();
const API = `${cfg.wpBase}/wp-json/wp/v2`;

// ── Utilidades ────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function log(msg)  { console.log(msg); }
function info(msg) { if (cfg.verbose) console.log(`  ℹ ${msg}`); }
function warn(msg) { console.warn(`  ⚠  ${msg}`); }

function buildHeaders() {
  const h = { 'User-Agent': 'Fluix-WP-Extractor/1.0', Accept: 'application/json' };
  if (cfg.wpUser && cfg.wpPass) {
    h['Authorization'] = 'Basic ' + Buffer.from(`${cfg.wpUser}:${cfg.wpPass}`).toString('base64');
  }
  return h;
}

async function apiFetch(url) {
  const res = await fetch(url, { headers: buildHeaders() });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} — ${url}\n${body.slice(0, 200)}`);
  }
  const total      = parseInt(res.headers.get('X-WP-Total') ?? '0', 10);
  const totalPages = parseInt(res.headers.get('X-WP-TotalPages') ?? '1', 10);
  const data       = await res.json();
  return { data, total, totalPages };
}

/**
 * Obtiene todos los items de un endpoint paginado.
 * Maneja automáticamente la paginación hasta agotar todos los resultados.
 */
async function fetchAll(endpoint, params = {}) {
  const items = [];
  let page = 1;

  const qs = new URLSearchParams({ per_page: '100', ...params });

  while (true) {
    qs.set('page', String(page));
    const url = `${API}${endpoint}?${qs}`;
    info(`GET ${url}`);

    let res;
    try {
      res = await apiFetch(url);
    } catch (err) {
      // "rest_post_invalid_page_number" → hemos pasado la última página
      if (err.message.includes('400') || err.message.includes('invalid_page')) break;
      throw err;
    }

    items.push(...res.data);
    process.stdout.write(`\r    página ${page}/${res.totalPages || 1} — ${items.length}/${res.total || '?'} items`);

    if (page >= res.totalPages || res.totalPages === 0) break;
    page++;
    await sleep(cfg.delay);
  }

  process.stdout.write('\n');
  return items;
}

// ── Decodificador de entidades HTML ──────────────────────────────────────────
function htmlDecode(str) {
  if (!str) return '';
  return str
    .replace(/&amp;/g,  '&')
    .replace(/&lt;/g,   '<')
    .replace(/&gt;/g,   '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g,  "'")
    .replace(/&#8216;/g, '‘') // '
    .replace(/&#8217;/g, '’') // '
    .replace(/&#8218;/g, '‚') // ‚
    .replace(/&#8220;/g, '“') // "
    .replace(/&#8221;/g, '”') // "
    .replace(/&#8211;/g, '–') // –
    .replace(/&#8212;/g, '—') // —
    .replace(/&#8230;/g, '…') // …
    .replace(/&nbsp;/g,  ' ')
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(parseInt(code)))
    .replace(/<[^>]+>/g, '')       // eliminar cualquier etiqueta HTML residual
    .replace(/\s+/g, ' ')
    .trim();
}

// ── Extracción de imágenes del HTML ──────────────────────────────────────────
const IMG_SRC_RE    = /<img[^>]+src=["']([^"']+)["']/gi;
const SRCSET_RE     = /srcset=["']([^"']+)["']/gi;
const BACKGROUND_RE = /url\(['"]?([^'")]+)['"]?\)/gi;
const WP_UPLOAD_RE  = /https?:\/\/[^/\s"')>]+\/wp-content\/uploads\/[^\s"')<>]+/gi;
const IMG_EXT_RE    = /\.(jpe?g|png|gif|webp|svg|avif)(\?[^"'\s]*)?$/i;

function extractImageUrls(html) {
  if (!html) return [];
  const found = new Set();

  const addUrl = (raw) => {
    if (!raw) return;
    const clean = raw.split('?')[0];
    if (IMG_EXT_RE.test(clean)) found.add(clean);
  };

  for (const m of html.matchAll(IMG_SRC_RE))  addUrl(m[1]);

  for (const m of html.matchAll(SRCSET_RE)) {
    for (const part of m[1].split(',')) {
      addUrl(part.trim().split(/\s+/)[0]);
    }
  }

  for (const m of html.matchAll(BACKGROUND_RE)) addUrl(m[1]);
  for (const m of html.matchAll(WP_UPLOAD_RE))  addUrl(m[0]);

  return [...found];
}

function makeImg(url) { return { wp_url: url, fluix_url: null, descargada: false }; }

// ── Normalización de posts ────────────────────────────────────────────────────
function normalizarPost(post, tipo, mapaCateg, mapaEtiquetas, mapaAutores) {
  const html            = post.content?.rendered ?? '';
  const featuredMedia   = post._embedded?.['wp:featuredmedia'];
  const imgPrincipalUrl = Array.isArray(featuredMedia) ? featuredMedia[0]?.source_url ?? null : null;

  const autorEmbedded = post._embedded?.author?.[0];
  const autorNombre   = autorEmbedded?.name ?? mapaAutores[post.author]?.name ?? '';

  const categNombres = (post.categories ?? []).map(id => mapaCateg[id]).filter(Boolean);
  const etiqNombres  = (post.tags      ?? []).map(id => mapaEtiquetas[id]).filter(Boolean);

  const imagenesContenido = extractImageUrls(html)
    .filter(u => u !== imgPrincipalUrl)
    .map(makeImg);

  return {
    // Identificadores y estado de importación
    wp_id:              post.id,
    fluix_id:           null,
    importado_en_fluix: false,

    // Tipo
    tipo,                             // 'noticia' | 'entrevista' | 'blog'

    // Metadatos
    titulo:             htmlDecode(post.title?.rendered ?? ''),
    slug:               post.slug              ?? '',
    fecha:              post.date              ?? '',
    fecha_modificado:   post.modified          ?? '',
    url_original:       post.link              ?? `${cfg.wpBase}/${post.slug}/`,

    // Contenido
    extracto:           post.excerpt?.rendered ?? '',
    contenido_html:     html,

    // Taxonomías
    categorias:         categNombres,
    categoria_ids_wp:   post.categories        ?? [],
    etiquetas:          etiqNombres,
    etiqueta_ids_wp:    post.tags              ?? [],

    // Autor
    autor:              autorNombre,
    autor_wp_id:        post.author            ?? null,

    // Estado WP
    estado_wp:          post.status            ?? 'publish',

    // Imágenes
    imagen_principal:   imgPrincipalUrl ? makeImg(imgPrincipalUrl) : null,
    imagenes_contenido: imagenesContenido,

    // SEO (Yoast si está disponible)
    seo: {
      meta_title:       post.yoast_head_json?.title          ?? '',
      meta_description: post.yoast_head_json?.description    ?? '',
      og_image:         post.yoast_head_json?.og_image?.[0]?.url ?? '',
    },
  };
}

function normalizarAutor(user) {
  const avatarUrl = user.avatar_urls
    ? Object.values(user.avatar_urls).pop()
    : null;

  return {
    wp_id:              user.id,
    fluix_id:           null,
    importado_en_fluix: false,
    tipo:               'autor',

    nombre:             user.name        ?? '',
    slug:               user.slug        ?? '',
    descripcion:        user.description ?? '',
    url_web:            user.url         ?? '',
    url_original:       user.link        ?? '',
    avatar_url:         avatarUrl        ?? null,

    imagen_principal:   avatarUrl ? makeImg(avatarUrl) : null,
    imagenes_contenido: [],
  };
}

function normalizarLibro(post, mapaCateg, mapaEtiquetas) {
  const html            = post.content?.rendered ?? '';
  const featuredMedia   = post._embedded?.['wp:featuredmedia'];
  const imgPrincipalUrl = Array.isArray(featuredMedia) ? featuredMedia[0]?.source_url ?? null : null;
  const meta            = post.meta ?? {};

  // Los campos ACF varían; intentamos los más comunes
  const campo = (keys) => {
    for (const k of keys) { if (meta[k]) return meta[k]; }
    return '';
  };

  return {
    wp_id:              post.id,
    fluix_id:           null,
    importado_en_fluix: false,
    tipo:               'libro',

    titulo:             htmlDecode(post.title?.rendered ?? ''),
    slug:               post.slug            ?? '',
    fecha:              post.date            ?? '',
    url_original:       post.link            ?? `${cfg.wpBase}/${post.slug}/`,

    sinopsis:           post.excerpt?.rendered ?? '',
    contenido_html:     html,

    // Campos editoriales (ACF / custom meta)
    isbn:               campo(['isbn', '_isbn', 'book_isbn']),
    precio:             campo(['precio', '_precio', 'price']),
    paginas:            campo(['paginas', '_paginas', 'page_count', 'num_pages']),
    encuadernacion:     campo(['encuadernacion', '_encuadernacion', 'binding']),
    anio_publicacion:   campo(['anio', 'año', 'year', 'publication_year']),

    categorias:         (post.categories ?? []).map(id => mapaCateg[id]).filter(Boolean),
    etiquetas:          (post.tags       ?? []).map(id => mapaEtiquetas[id]).filter(Boolean),

    imagen_principal:   imgPrincipalUrl ? makeImg(imgPrincipalUrl) : null,
    imagenes_contenido: extractImageUrls(html).filter(u => u !== imgPrincipalUrl).map(makeImg),
  };
}

// ── Detectar tipo de post por categoría ──────────────────────────────────────
function detectarTipo(post, idCategEntrevistas) {
  if (!idCategEntrevistas) return 'noticia';
  return (post.categories ?? []).includes(idCategEntrevistas) ? 'entrevista' : 'noticia';
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  log(`\n═══════════════════════════════════════════════════`);
  log(`  Fluix WP Extractor`);
  log(`  Fuente : ${cfg.wpBase}`);
  log(`  Tipos  : ${cfg.tipos.join(', ')}`);
  log(`  Salida : ${cfg.outFile}`);
  log(`═══════════════════════════════════════════════════\n`);

  const master = {
    _meta: {
      fuente:      cfg.wpBase,
      extraido_en: new Date().toISOString(),
      version:     '1.0',
    },
    noticias:    [],
    entrevistas: [],
    autores:     [],
    libros:      [],
  };

  // ── 1. Taxonomías ─────────────────────────────────────────────────────────
  log('📂 Cargando categorías y etiquetas...');

  const [categorias, etiquetas] = await Promise.all([
    fetchAll('/categories', { per_page: '100' }).catch(() => []),
    fetchAll('/tags',        { per_page: '100' }).catch(() => []),
  ]);

  const mapaCateg     = Object.fromEntries(categorias.map(c => [c.id, c.name]));
  const mapaEtiquetas = Object.fromEntries(etiquetas.map(t => [t.id, t.name]));

  const idCategEntrevistas = categorias.find(c =>
    /entrevista/i.test(c.name) || /interview/i.test(c.name)
  )?.id ?? null;

  log(`   Categorías: ${categorias.length} | Etiquetas: ${etiquetas.length}`);
  log(`   ID categoría "Entrevistas": ${idCategEntrevistas ?? '(no encontrada — todos los posts serán "noticia")'}`);

  // ── 2. Posts (noticias + entrevistas) — siempre incluir _embed author ────
  const extraerPosts = cfg.tipos.includes('noticias') || cfg.tipos.includes('entrevistas') || cfg.tipos.includes('autores');
  let allPosts = [];
  if (extraerPosts) {
    log('\n📰 Extrayendo posts (noticias + entrevistas)...');
    allPosts = await fetchAll('/posts', {
      _embed: 'wp:featuredmedia,author',
      status: 'publish',
    });
    log(`   ${allPosts.length} posts descargados`);
  }

  // ── 3. Autores — primero desde /users; si falla (403), desde embedded ────
  let mapaAutores = {};
  if (cfg.tipos.includes('autores')) {
    log('\n👤 Extrayendo autores...');
    let usersFromEndpoint = [];
    try {
      usersFromEndpoint = await fetchAll('/users');
      master.autores = usersFromEndpoint.map(normalizarAutor);
      mapaAutores    = Object.fromEntries(usersFromEndpoint.map(u => [u.id, u]));
      log(`   ✅ ${master.autores.length} autores (endpoint /users)`);
    } catch (err) {
      warn(`/users bloqueado (${err.message.split('\n')[0]})`);

      // 1. Intentar desde --autores-file (autores-data.js)
      const autoresJs = cfg.autoresFile ?? (() => {
        // ruta por defecto si existe
        const def = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari', 'autores-data.js');
        return fs.existsSync(def) ? def : null;
      })();

      if (autoresJs && fs.existsSync(autoresJs)) {
        warn(`   Cargando autores desde ${autoresJs}`);
        try {
          // autores-data.js expone const AUTORES = [...]; lo evaluamos en sandbox
          // autores-data.js usa `const AUTORES` — en vm.runInContext const es block-scoped
          // y no se expone en el sandbox; lo extraemos con require() si es posible,
          // o reemplazando const → var antes de evaluar
          const vm = require('vm');
          const rawCode = fs.readFileSync(autoresJs, 'utf8');
          // Reemplazar const/let → var para que el binding quede en el global del sandbox
          const code = rawCode.replace(/\b(const|let)\s+/g, 'var ');
          const sandbox = { module: {}, exports: {} };
          vm.createContext(sandbox);
          vm.runInContext(code, sandbox);
          const arr = sandbox.AUTORES ?? sandbox.autores ?? [];
          master.autores = arr.map((a, i) => ({
            wp_id:              a.id ?? (i + 1),
            fluix_id:           null,
            importado_en_fluix: false,
            tipo:               'autor',
            nombre:             htmlDecode(a.nombre ?? ''),
            slug:               (a.nombre ?? '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''),
            descripcion:        a.descripcion ?? '',
            bio:                a.bio ?? '',
            genero:             a.genero ?? '',
            lugar:              a.lugar ?? '',
            url_original:       '',
            avatar_url:         null,
            imagen_principal:   null,
            imagenes_contenido: [],
          }));
          log(`   ✅ ${master.autores.length} autores desde autores-data.js`);
        } catch (e2) {
          warn(`No se pudo cargar autores-data.js: ${e2.message}`);
        }
      } else {
        // 2. Extraer autores únicos de los posts embebidos
        const autorMap = new Map();
        for (const post of allPosts) {
          const a = post._embedded?.author?.[0];
          if (a && a.id && !autorMap.has(a.id)) {
            autorMap.set(a.id, a);
            mapaAutores[a.id] = a;
          }
        }
        master.autores = [...autorMap.values()].map(normalizarAutor);
        log(`   ✅ ${master.autores.length} autores (de posts embebidos)`);
      }
    }
  }

  // ── Clasificar posts en noticias / entrevistas ────────────────────────────
  if (cfg.tipos.includes('noticias') || cfg.tipos.includes('entrevistas')) {
    log('\n   Clasificando posts por categoría...');
    for (const post of allPosts) {
      const tipo = detectarTipo(post, idCategEntrevistas);
      const norm = normalizarPost(post, tipo, mapaCateg, mapaEtiquetas, mapaAutores);
      if (tipo === 'entrevista') master.entrevistas.push(norm);
      else                       master.noticias.push(norm);
    }
    log(`   ✅ ${master.noticias.length} noticias | ${master.entrevistas.length} entrevistas`);
  }

  // ── 4. Libros (custom post type) ──────────────────────────────────────────
  if (cfg.tipos.includes('libros')) {
    log('\n📚 Extrayendo libros (custom post type)...');

    // Primero intentamos descubrir el slug correcto consultando /types
    let cptSlug = null;
    try {
      const { data: types } = await apiFetch(`${API}/types`);
      const libroType = Object.values(types).find(t =>
        /libro|book|publ/i.test(t.slug) && t.rest_base
      );
      if (libroType) {
        cptSlug = libroType.rest_base;
        log(`   Descubierto CPT: /${cptSlug}`);
      }
    } catch { /* continuar con candidatos manuales */ }

    const candidatos = cptSlug
      ? [cptSlug]
      : ['libro', 'libros', 'book', 'books', 'publicacion', 'publicaciones'];

    let librosRaw = [];
    for (const slug of candidatos) {
      try {
        const lotes = await fetchAll(`/${slug}`, { _embed: 'wp:featuredmedia', status: 'publish' });
        if (lotes.length > 0) {
          librosRaw = lotes;
          log(`   CPT activo: /${slug}`);
          break;
        }
      } catch { info(`   /${slug} no disponible`); }
    }

    if (librosRaw.length === 0) {
      warn('No se encontró CPT para libros. Si existe, indícalo con: node extractor.js --tipos libros --url ...');
    }

    master.libros = librosRaw.map(p => normalizarLibro(p, mapaCateg, mapaEtiquetas));
    log(`   ✅ ${master.libros.length} libros`);
  }

  // ── 5. Stats de imágenes ──────────────────────────────────────────────────
  const totalImagenes = [...master.noticias, ...master.entrevistas, ...master.libros, ...master.autores]
    .reduce((acc, item) => {
      if (item.imagen_principal) acc++;
      acc += item.imagenes_contenido?.length ?? 0;
      return acc;
    }, 0);

  master._meta.stats = {
    noticias:            master.noticias.length,
    entrevistas:         master.entrevistas.length,
    autores:             master.autores.length,
    libros:              master.libros.length,
    imagenes_detectadas: totalImagenes,
    imagenes_migradas:   0,
  };

  // ── 6. Escribir master.json ───────────────────────────────────────────────
  log('\n💾 Escribiendo master.json...');
  const outDir = path.dirname(cfg.outFile);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const json    = JSON.stringify(master, null, 2);
  const sizeKB  = Math.round(Buffer.byteLength(json) / 1024);
  fs.writeFileSync(cfg.outFile, json, 'utf8');

  log('\n═══════════════════════════════════════════════════');
  log('✅  Extracción completada');
  log('═══════════════════════════════════════════════════');
  log(`   Noticias    : ${master.noticias.length}`);
  log(`   Entrevistas : ${master.entrevistas.length}`);
  log(`   Autores     : ${master.autores.length}`);
  log(`   Libros      : ${master.libros.length}`);
  log(`   Imágenes    : ${totalImagenes} detectadas`);
  log(`   Tamaño      : ${sizeKB} KB`);
  log(`   Archivo     : ${cfg.outFile}`);
  log('\n👉 Siguiente paso:');
  log('   node scripts/nazari/migrar_imagenes.js');
  log('═══════════════════════════════════════════════════\n');
}

main().catch(err => {
  console.error('\n❌ Error:', err.message ?? String(err));
  process.exit(1);
});
