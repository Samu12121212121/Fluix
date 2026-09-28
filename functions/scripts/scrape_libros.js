'use strict';

/**
 * scrape_libros.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Descubre TODAS las páginas de libros en editorialnazari.com/catalogo/,
 * hace un fetch INDIVIDUAL a cada una (/libro/[slug]/), extrae:
 *   • titulo       (desde el <title> / <h1>)
 *   • slug         (de la URL)
 *   • autor        (enlace al perfil del autor)
 *   • isbn         (ISBN13 del bloque de metadatos)
 *   • precio       (en euros)
 *   • categorias   (Categorías: — colección/sección)
 *   • etiquetas    (Etiquetas: — géneros/temáticas)
 *   • id_producto  (WooCommerce product ID)
 *   • sinopsis     (tab-description, texto completo verbatim, sin IA)
 * NO extrae: Colección, Tamaño, Páginas, Idioma, Edición, Fecha, Encuadernación
 * Ordena alfabéticamente por título normalizado,
 * asigna posición final (1…N) y guarda en:
 *   functions/scripts/libros-web-scraped.json
 *
 * Uso:
 *   cd functions
 *   node scripts/scrape_libros.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

const LIBRO_BASE    = 'https://www.editorialnazari.com/libro/';
// libros-data.js — mismo patrón que scrape_autores usa para HTML_DIR
const os = require('os');
const LIBROS_DATA_JS = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari', 'img', 'html_nazari', 'libros-data.js');
const DELAY         = 600;   // ms entre peticiones
const OUT_FILE      = path.join(__dirname, 'libros-web-scraped.json');

// ── Normalización ──────────────────────────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^ -~]/g, '')
    .trim();
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Decodificar entidades HTML ────────────────────────────────────────────────
function decodeEntities(s) {
  return s
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&#8217;|&#x2019;|&#8216;|&#x2018;/g, "'")
    .replace(/&#8220;|&#x201C;|&#8221;|&#x201D;/g, '"')
    .replace(/&#8230;|&#x2026;/g, '…').replace(/&#8212;|&#x2014;/g, '—')
    .replace(/&#8211;|&#x2013;/g, '–').replace(/&#160;|&nbsp;/g, ' ')
    .replace(/&#\d+;/g, ' ').replace(/&[a-z]+;/g, ' ');
}

function stripTags(html) {
  return decodeEntities(html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ')).trim();
}

// ── HTTP GET con seguimiento de redirecciones ──────────────────────────────────
function fetchHtml(url, hops = 4) {
  return new Promise(resolve => {
    const lib = url.startsWith('https') ? https : http;
    try {
      const req = lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; NazariScraper/2.0)',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        }
      }, res => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          const loc = res.headers.location.startsWith('http')
            ? res.headers.location
            : new URL(res.headers.location, url).href;
          res.resume();
          return fetchHtml(loc, hops - 1).then(resolve);
        }
        let raw = '';
        res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => resolve({ status: res.statusCode, html: raw }));
      });
      req.on('error', e => resolve({ status: 0, html: '', error: e.message }));
      req.setTimeout(18000, () => { req.destroy(); resolve({ status: 0, html: '', error: 'timeout' }); });
    } catch (e) {
      resolve({ status: 0, html: '', error: e.message });
    }
  });
}

// ── Extraer TÍTULO ─────────────────────────────────────────────────────────────
function extraerTitulo(html) {
  // <title> — "Título del libro | Editorial Nazarí"
  const titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (titleM) {
    const t = stripTags(titleM[1]).split(/[|–—»]/).map(s => s.trim()).filter(Boolean)[0] || '';
    if (t.length > 1 && t.length < 120) return t;
  }
  // h1.entry-title
  const h1M = html.match(/<h1[^>]*class="[^"]*entry.?title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1M) return stripTags(h1M[1]).trim();
  // Primer h1
  const anyH1 = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  if (anyH1) return stripTags(anyH1[1]).trim();
  return '';
}

// ── Extraer AUTOR ──────────────────────────────────────────────────────────────
function extraerAutor(html) {
  // <a href="/team/[slug]/">Nombre Autor</a>
  const m = html.match(/href="https?:\/\/www\.editorialnazari\.com\/team\/[^"]+">([^<]+)<\/a>/i);
  if (m) return stripTags(m[1]).trim();
  // WooCommerce: campo custom pa_autor o similar
  const paM = html.match(/pa_autor[^>]*>[^<]*<a[^>]*>([^<]+)<\/a>/i);
  if (paM) return stripTags(paM[1]).trim();
  return '';
}

// ── Extraer ISBN ───────────────────────────────────────────────────────────────
function extraerISBN(html) {
  // "ISBN13:   9781234567890" o "ISBN: 978..."
  const m = html.match(/ISBN1?3?\s*[:：]\s*([\d-]{10,20})/i);
  if (m) return m[1].replace(/\s/g, '').trim();
  // sku de WooCommerce
  const skuM = html.match(/class="[^"]*sku[^"]*"[^>]*>([\d-]{10,20})<\/span>/i);
  if (skuM) return skuM[1].trim();
  return '';
}

// ── Extraer PRECIO ─────────────────────────────────────────────────────────────
function extraerPrecio(html) {
  // .woocommerce-Price-amount o .amount
  const m = html.match(/<span[^>]*class="[^"]*(?:woocommerce-Price-amount|amount)[^"]*"[^>]*>([\s\S]*?)<\/span>/i);
  if (m) {
    const t = stripTags(m[1]).replace(/\s+/g, ' ').trim();
    // Normalizar: "10,00 €" o "10.00€"
    const numM = t.match(/([\d.,]+)\s*€/);
    if (numM) return `${numM[1]} €`;
    if (t) return t;
  }
  // Fallback: buscar patrón "NN,NN €" en el HTML
  const rawM = html.match(/([\d]{1,3}[.,][\d]{2})\s*€/);
  if (rawM) return `${rawM[1]} €`;
  return '';
}

// ── Extraer CATEGORÍAS ─────────────────────────────────────────────────────────
function extraerCategorias(html) {
  // "Categorías: <a href="/libros/catalogo/coleccion-X/">Colección X</a>, ..."
  // Busca el bloque después de "Categoría" antes de "Etiqueta"
  const blockM = html.match(/Categor[íi]a[s]?\s*[:：]([\s\S]*?)(?=Etiqueta|<\/p>|<br|$)/i);
  if (!blockM) return [];
  const cats = new Set();
  const aRe = /<a[^>]*>([^<]+)<\/a>/gi;
  let m;
  while ((m = aRe.exec(blockM[1])) !== null) {
    const t = stripTags(m[1]).trim();
    if (t && t.length < 80) cats.add(t);
  }
  return [...cats];
}

// ── Extraer ETIQUETAS ──────────────────────────────────────────────────────────
function extraerEtiquetas(html) {
  // Links a /libros-de-tematica/ (evita novedades, colecciones, etc.)
  const tags = new Set();

  // Bloque "Etiquetas:" — sólo links de temática
  const etqBlockM = html.match(/Etiqueta[s]?\s*[:：]([\s\S]*?)(?=<\/p>|<br|$)/i);
  if (etqBlockM) {
    const aRe = /<a[^>]*href="[^"]*libros-de-tematica[^"]*"[^>]*>([^<]+)<\/a>/gi;
    let m;
    while ((m = aRe.exec(etqBlockM[1])) !== null) {
      const t = stripTags(m[1]).trim();
      if (t) tags.add(t);
    }
  }

  // Fallback: cualquier link de temática en toda la página
  if (tags.size === 0) {
    const globalRe = /<a[^>]*href="[^"]*libros-de-tematica[^"]*"[^>]*>([^<]+)<\/a>/gi;
    let m;
    while ((m = globalRe.exec(html)) !== null) {
      const t = stripTags(m[1]).trim();
      if (t) tags.add(t);
    }
  }

  return [...tags];
}

// ── Extraer ID PRODUCTO (WooCommerce) ─────────────────────────────────────────
function extraerIdProducto(html) {
  // data-product_id="12345"
  const m1 = html.match(/data-product[_-]id="(\d+)"/i);
  if (m1) return m1[1];
  // ?add-to-cart=12345
  const m2 = html.match(/\?add-to-cart=(\d+)/);
  if (m2) return m2[1];
  // <input name="product_id" value="12345">
  const m3 = html.match(/name="product_id"\s+value="(\d+)"/i);
  if (m3) return m3[1];
  // postid-NNNNN en class del body
  const m4 = html.match(/class="[^"]*postid-(\d+)[^"]*"/i);
  if (m4) return m4[1];
  return '';
}

// ── Extraer SINOPSIS COMPLETA (tab-description) ───────────────────────────────
function extraerSinopsis(html) {
  // Localiza div id="tab-description" y extrae su contenido respetando anidación
  const tabIdx = html.indexOf('id="tab-description"');
  if (tabIdx === -1) return '';

  const contentStart = html.indexOf('>', tabIdx) + 1;
  let depth = 1, pos = contentStart;

  while (depth > 0 && pos < html.length) {
    const nextOpen  = html.indexOf('<div', pos);
    const nextClose = html.indexOf('</div>', pos);
    if (nextClose === -1) break;
    if (nextOpen !== -1 && nextOpen < nextClose) {
      depth++;
      pos = nextOpen + 4;
    } else {
      depth--;
      if (depth === 0) { pos = nextClose; break; }
      pos = nextClose + 6;
    }
  }

  const content = html.slice(contentStart, pos);

  // Une todos los <p> con espacio (mismo formato que _update_101_199.js)
  const parts = [];
  const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let m;
  while ((m = pRe.exec(content)) !== null) {
    const t = stripTags(m[1]).trim();
    if (t) parts.push(t);
  }
  return parts.join(' ');
}

// ── Leer slugs desde libros-data.js (el catálogo renderiza con JS, no es crawleable) ──
function loadSlugsDeLibrosData() {
  if (!fs.existsSync(LIBROS_DATA_JS)) {
    throw new Error(`No se encuentra libros-data.js en:\n  ${LIBROS_DATA_JS}\nVerifica la ruta.`);
  }
  const code = fs.readFileSync(LIBROS_DATA_JS, 'utf8');
  const slugs = [...code.matchAll(/slug:\s*"([^"]+)"/g)].map(m => m[1]);
  if (slugs.length === 0) throw new Error('No se encontraron slugs en libros-data.js');
  console.log(`  → ${slugs.length} slugs leídos de libros-data.js`);
  return slugs.map(s => `${LIBRO_BASE}${s}/`);
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '═'.repeat(72));
  console.log(' 🕷  SCRAPING COMPLETO — editorialnazari.com/libro/[slug]/');
  console.log('     Fuente de slugs: libros-data.js (catálogo renderiza con JS)');
  console.log('     Extrae: título · autor · isbn · precio · categorias · etiquetas · id_producto · sinopsis');
  console.log('═'.repeat(72) + '\n');

  // Fase 1: Leer slugs desde libros-data.js
  const libroUrls = loadSlugsDeLibrosData();
  console.log(`\n  📋 Total libros a scrapear: ${libroUrls.length}\n`);
  console.log('─'.repeat(72));

  // Fase 2: Fetch individual por cada libro
  const results = [];
  let cntOk = 0, cntErr = 0, cntVacio = 0;

  for (let i = 0; i < libroUrls.length; i++) {
    const url  = libroUrls[i];
    const slug = url.replace(/.*\/libro\//, '').replace(/\/$/, '');
    process.stdout.write(`\r  [${String(i + 1).padStart(3)}/${libroUrls.length}] ${slug.substring(0, 40).padEnd(40)}  ✅${cntOk} ❌${cntErr} ⬜${cntVacio}`);

    await sleep(DELAY);
    const { status, html, error } = await fetchHtml(url);

    if (status !== 200) {
      cntErr++;
      results.push({ url, slug, status: status || 0, _error: error || `HTTP ${status}` });
      continue;
    }

    const titulo      = extraerTitulo(html).trim();
    const autor       = extraerAutor(html).trim();
    const isbn        = extraerISBN(html).trim();
    const precio      = extraerPrecio(html).trim();
    const categorias  = extraerCategorias(html);
    const etiquetas   = extraerEtiquetas(html);
    const id_producto = extraerIdProducto(html).trim();
    const sinopsis    = extraerSinopsis(html).trim();

    if (!titulo && !sinopsis) {
      cntVacio++;
      results.push({ url, slug, status, titulo: slug, autor: '', isbn: '', precio: '', categorias: [], etiquetas: [], id_producto: '', sinopsis: '', _sinDatos: true });
      continue;
    }

    cntOk++;
    results.push({ url, slug, titulo, autor, isbn, precio, categorias, etiquetas, id_producto, sinopsis });
  }

  console.log('\n');

  // Fase 3: Filtrar válidos, ordenar alfabéticamente por título, asignar posición
  const valid = results
    .filter(r => !r._error && !r._sinDatos && r.titulo)
    .sort((a, b) => norm(a.titulo).localeCompare(norm(b.titulo), 'es', { sensitivity: 'base' }));
  valid.forEach((r, i) => { r.posicion = i + 1; });

  const errores  = results.filter(r => r._error);
  const sinDatos = results.filter(r => r._sinDatos);

  // Fase 4: Guardar JSON
  const out = {
    fecha_scraping:      new Date().toISOString(),
    total_validos:       valid.length,
    total_errores:       errores.length,
    total_sin_datos:     sinDatos.length,
    sin_sinopsis:        valid.filter(r => !r.sinopsis).length,
    sin_isbn:            valid.filter(r => !r.isbn).length,
    sin_precio:          valid.filter(r => !r.precio).length,
    sin_autor:           valid.filter(r => !r.autor).length,
    sin_etiquetas:       valid.filter(r => r.etiquetas.length === 0).length,
    sin_id_producto:     valid.filter(r => !r.id_producto).length,
    errores:             errores.map(r => ({ url: r.url, slug: r.slug, error: r._error })),
    sin_datos:           sinDatos.map(r => ({ url: r.url, slug: r.slug })),
    libros:              valid,
  };
  fs.writeFileSync(OUT_FILE, JSON.stringify(out, null, 2), 'utf8');

  // Fase 5: Resumen en consola
  console.log('═'.repeat(72));
  console.log(` ✅  Scraping completado — ${new Date().toLocaleTimeString()}`);
  console.log(`     Válidos:          ${valid.length}`);
  console.log(`     Errores HTTP:     ${errores.length}`);
  console.log(`     Sin datos:        ${sinDatos.length}`);
  console.log(`     Con sinopsis:     ${valid.filter(r => r.sinopsis).length} / ${valid.length}`);
  console.log(`     Con ISBN:         ${valid.filter(r => r.isbn).length} / ${valid.length}`);
  console.log(`     Con precio:       ${valid.filter(r => r.precio).length} / ${valid.length}`);
  console.log(`     Con autor:        ${valid.filter(r => r.autor).length} / ${valid.length}`);
  console.log(`     Con etiquetas:    ${valid.filter(r => r.etiquetas.length > 0).length} / ${valid.length}`);
  console.log(`     Con id_producto:  ${valid.filter(r => r.id_producto).length} / ${valid.length}`);
  console.log(`\n     Guardado en:      ${OUT_FILE}`);
  console.log('═'.repeat(72));

  console.log('\n📋 Primeros 10 en orden alfabético:');
  valid.slice(0, 10).forEach(r => {
    console.log(`  #${String(r.posicion).padStart(3)}  ${r.titulo.padEnd(40)}  isbn:${r.isbn || '—'}  precio:${r.precio || '—'}  sin:${r.sinopsis.length}c`);
  });

  if (errores.length > 0) {
    console.log(`\n⚠️  URLs con error (${errores.length}):`);
    errores.forEach(e => console.log(`  ${String(e.error).padEnd(14)} ${e.slug}`));
  }
  if (sinDatos.length > 0) {
    console.log(`\n⬜  Sin datos (${sinDatos.length}):`);
    sinDatos.forEach(e => console.log(`  ${e.slug}`));
  }

  console.log('\n→ JSON listo. Siguiente: aplicar con el script de update a libros-data.js\n');
}

main().catch(e => { console.error('\n❌ Error:', e.message || e); process.exit(1); });
