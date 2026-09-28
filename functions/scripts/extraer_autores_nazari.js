'use strict';

/**
 * extraer_autores_nazari.js  —  Script independiente
 * Extrae todos los autores de editorialnazari.com/team_group/autores/
 * Campos: nombre, bio (con saltos de línea), foto, roles, url
 *         genero = etiquetas únicas de sus libros en libros_nazari.json, separadas por /
 *
 * Uso:
 *   node scripts/extraer_autores_nazari.js [--json] [--delay ms]
 */

const https  = require('https');
const http   = require('http');
const path   = require('path');
const fs     = require('fs');

const GUARDAR_JSON  = process.argv.includes('--json');
const argVal        = f => { const i = process.argv.indexOf(f); return i >= 0 ? process.argv[i+1] : null; };
const DELAY_MS      = parseInt(argVal('--delay') || '1200', 10);
const DESDE         = parseInt(argVal('--desde') || '1', 10) - 1; // índice 0-based
const AUTORES_FILE  = path.join(__dirname, 'autores_nazari.json');
const LIBROS_FILE   = path.join(__dirname, 'libros_nazari.json');

// ── Cargar libros para calcular género ────────────────────────────────────────
let libros = [];
if (fs.existsSync(LIBROS_FILE)) {
  try { libros = JSON.parse(fs.readFileSync(LIBROS_FILE, 'utf8')).libros || []; }
  catch (_) {}
}
if (!libros.length) console.warn('  ⚠ libros_nazari.json no encontrado — campo genero estará vacío');

// ── HTTP ──────────────────────────────────────────────────────────────────────
function fetchHtml(url, hops) {
  hops = hops === undefined ? 4 : hops;
  return new Promise(resolve => {
    const lib = url.startsWith('https') ? https : http;
    try {
      const req = lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      }, res => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          const loc = res.headers.location.startsWith('http')
            ? res.headers.location
            : new URL(res.headers.location, url).href;
          res.resume(); fetchHtml(loc, hops - 1).then(resolve); return;
        }
        let raw = ''; res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => resolve({ status: res.statusCode, html: raw }));
        res.on('error', () => resolve({ status: 0, html: '' }));
      });
      req.on('error', e => resolve({ status: 0, html: '', error: e.message }));
      req.setTimeout(20000, () => { req.destroy(); resolve({ status: 0, html: '', error: 'timeout' }); });
    } catch (e) { resolve({ status: 0, html: '', error: e.message }); }
  });
}

// Puppeteer stealth — resuelve sgcaptcha automáticamente
let _browser = null;
async function puppeteerFetch(url) {
  if (!_browser) {
    try {
      const puppeteerExtra = require('puppeteer-extra');
      puppeteerExtra.use(require('puppeteer-extra-plugin-stealth')());
      _browser = await puppeteerExtra.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
        defaultViewport: { width: 1280, height: 800 },
      });
      process.stderr.write('  [puppeteer] Chrome iniciado\n');
    } catch (e) {
      process.stderr.write('  [puppeteer] no disponible: ' + e.message + '\n');
      _browser = false;
    }
  }
  if (!_browser) return null;
  const page = await _browser.newPage();
  try {
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120');
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 20000 }).catch(() => {});
    let waited = 0;
    while (waited < 35000) {
      const cu = page.url(), t = await page.title().catch(() => '');
      if (!cu.includes('captcha') && !cu.includes('.well-known') && t !== 'Robot Challenge Screen') break;
      await new Promise(r => setTimeout(r, 800)); waited += 800;
    }
    await page.waitForNetworkIdle({ idleTime: 500, timeout: 5000 }).catch(() => {});
    const title = await page.title().catch(() => '');
    const html  = await page.content();
    if (title === '403 - Forbidden' || html.length < 2000) return null;
    return html;
  } catch (_) { return null; }
  finally { await page.close(); }
}

// Wayback CDX — busca snapshot más reciente para una URL
async function waybackFetch(urlOrig) {
  const limpio = urlOrig.replace(/^https?:\/\/(www\.)?/, '');
  // API available (rápida)
  const avail = await new Promise(resolve => {
    https.get('https://archive.org/wayback/available?url=' + limpio, {
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
    }, res => {
      let raw = ''; res.setEncoding('utf8');
      res.on('data', c => raw += c);
      res.on('end', () => { try { resolve(JSON.parse(raw)); } catch (_) { resolve(null); } });
    }).on('error', () => resolve(null));
  });
  let snapUrl  = avail?.archived_snapshots?.closest?.url;
  let snapTs   = avail?.archived_snapshots?.closest?.timestamp?.substring(0, 8) || '';

  // CDX fallback si available no tiene snapshot
  if (!snapUrl) {
    const cdxData = await new Promise(resolve => {
      const q = 'https://web.archive.org/cdx/search/cdx?url=' + limpio +
        '&output=json&fl=timestamp,original&filter=statuscode:200&collapse=urlkey&from=20200101&limit=1';
      https.get(q, { headers: { 'User-Agent': 'Mozilla/5.0' } }, res => {
        let raw = ''; res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => { try { resolve(JSON.parse(raw)); } catch (_) { resolve(null); } });
      }).on('error', () => resolve(null));
    });
    if (cdxData && cdxData.length > 1) {
      const [ts, orig] = cdxData[1];
      snapUrl = 'https://web.archive.org/web/' + ts + '/' + orig;
      snapTs  = ts.substring(0, 8);
    }
  }

  if (!snapUrl) return null;
  const arch = await fetchHtml(snapUrl);
  if (!arch.html || arch.html.length < 2000) return null;
  const html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');
  return { html, fuente: 'wayback:' + snapTs };
}

async function obtenerHtml(url) {
  // 1. Directo
  const r = await fetchHtml(url);
  if (r.status >= 200 && r.status < 300 && r.html.length > 2000 && !r.html.includes('sgcaptcha'))
    return { html: r.html, fuente: 'directo' };
  // 2. Puppeteer (sgcaptcha)
  const ph = await puppeteerFetch(url);
  if (ph) return { html: ph, fuente: 'directo' };
  // 3. Wayback
  const wb = await waybackFetch(url);
  return wb || { html: '', fuente: 'sin_datos' };
}

// ── HTML utils ────────────────────────────────────────────────────────────────
function stripHtmlPreserveLines(h) {
  return (h || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(?:p|div|li|h[1-6]|blockquote|section|article)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
    .replace(/&[a-z]{2,8};/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/(^|\n) /g, '$1').replace(/ (\n|$)/g, '$1')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function stripTags(h) {
  return stripHtmlPreserveLines(h).replace(/\n+/g, ' ').replace(/  +/g, ' ').trim();
}

const escRe = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Extrae innerHTML del primer elemento con selector simple (tag, .class, tag.class)
function extractBlock(html, selector) {
  const s = selector.trim();
  let tagPat = '[a-z][a-z0-9]*', attrPre = '';
  if (s.startsWith('.')) {
    attrPre = '(?=[^>]*class=["\'][^"\']*\\b' + escRe(s.slice(1)) + '\\b)';
  } else if (s.includes('.')) {
    const [t, c] = s.split('.', 2);
    tagPat = escRe(t); attrPre = '(?=[^>]*class=["\'][^"\']*\\b' + escRe(c) + '\\b)';
  } else { tagPat = escRe(s); }
  const openRe = new RegExp('<(' + tagPat + ')' + attrPre + '[^>]*>', 'i');
  const m = openRe.exec(html); if (!m) return null;
  const tag = m[1].toLowerCase(), start = m.index + m[0].length;
  const oRe = new RegExp('<' + escRe(tag) + '[\\s>]', 'gi');
  const cRe = new RegExp('<\\/' + escRe(tag) + '\\s*>', 'gi');
  let depth = 1, pos = start;
  while (depth > 0 && pos < html.length) {
    oRe.lastIndex = pos; cRe.lastIndex = pos;
    const no = oRe.exec(html), nc = cRe.exec(html);
    if (!nc) break;
    if (no && no.index < nc.index) { depth++; pos = no.index + no[0].length; }
    else { depth--; if (depth === 0) return html.slice(start, nc.index); pos = nc.index + nc[0].length; }
  }
  return null;
}

// ── Extracción de datos del autor ─────────────────────────────────────────────
function parsearAutor(html, url) {
  // Nombre: desde el título de la página
  const titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  let nombre = titleM ? stripTags(titleM[1]).replace(/\s*[\-|]\s*Editorial Nazar[ií]\s*$/i, '').replace(/^Autor\/a\s+/i, '').trim() : '';
  if (!nombre) {
    const h1M = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    if (h1M) nombre = stripTags(h1M[1]).trim();
  }

  // Foto: og:image o primera img de la ficha
  const ogImgM = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
               || html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
  const foto = ogImgM ? ogImgM[1].replace(/https?:\/\/web\.archive\.org\/web\/\d+im_\//, '') : '';

  // Roles: enlaces /team-group/ en la página
  const roles = [];
  const tgRe = /<a[^>]+href="[^"]*\/team[-_]group\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; let tgm;
  const seenRol = new Set();
  while ((tgm = tgRe.exec(html)) !== null) {
    const r = stripTags(tgm[1]).trim();
    if (r && r.length < 60 && !seenRol.has(r.toLowerCase())) { seenRol.add(r.toLowerCase()); roles.push(r); }
  }

  // Biografía: bloque wpb_text_column más largo, conservando saltos de línea
  let bio = '';
  const candidatos = [];
  const wpbRe = /<div[^>]*class="[^"]*\bwpb_text_column\b[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi; let wm;
  while ((wm = wpbRe.exec(html)) !== null) {
    const t = stripHtmlPreserveLines(wm[1]);
    if (t.length >= 60 && !/cookie|aviso|newsletter|carrito|copyright/i.test(t)) candidatos.push(t);
  }
  if (candidatos.length) {
    bio = candidatos.sort((a, b) => b.length - a.length)[0];
  } else {
    // Fallback: bloque entry-content o main
    for (const sel of ['.entry-content', '.team-member-content', 'main', 'article']) {
      const blk = extractBlock(html, sel);
      if (blk) { bio = stripHtmlPreserveLines(blk); break; }
    }
    // Fallback final: párrafos sustanciales
    if (!bio) {
      const parrafos = [];
      const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm;
      while ((pm = pRe.exec(html)) !== null) {
        const t = stripHtmlPreserveLines(pm[1]);
        if (t.length >= 40 && !/cookie|aviso|newsletter/i.test(t)) parrafos.push(t);
      }
      bio = parrafos.join('\n\n');
    }
  }

  return { nombre, bio, foto, roles, url };
}

// ── Género: categorías individuales de todos los libros del autor ─────────────
// Separa por coma Y por / para tratar cada item como individual
// Descarta valores organizativos que no son género literario
const NO_GENERO = /^(ebooks?|más vendidos|proximamente|próximamente|colección\s|coleccion\s)/i;

function splitCategorias(raw) {
  return (raw || '')
    .split(/[,\/]/)
    .map(c => c.trim())
    .filter(c => c && !NO_GENERO.test(c));
}

function calcularGenero(nombreAutor) {
  if (!libros.length || !nombreAutor) return '';
  const norm = s => (s || '').toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim();
  const normNombre = norm(nombreAutor);
  const set = new Set();
  libros.forEach(l => {
    const normAutor = norm(l.autor || '');
    if (normAutor === normNombre || normAutor.includes(normNombre) || normNombre.includes(normAutor)) {
      // etiquetas = géneros literarios reales (Ficción, Poesía, Ensayo...)
      // split por coma Y por / para tratar cada una como individual
      (l.etiquetas || '').split(/[,\/]/).map(e => e.trim()).filter(Boolean)
        .forEach(e => set.add(e));
    }
  });
  return [...set].sort().join(' / ');
}

// ── Descubrir URLs de autores desde la página de listado ──────────────────────
function extraerUrlsAutores(html) {
  const urls = new Set();
  const re = /href=["'](https?:\/\/[^"']*\/team\/[^"'/][^"']+\/)["']/gi; let m;
  while ((m = re.exec(html)) !== null) urls.add(m[1]);
  return [...urls];
}

function maxPaginaListado(html) {
  const re = /href=["'][^"']*\/page\/(\d+)\/["']/gi; let m, max = 1;
  while ((m = re.exec(html)) !== null) max = Math.max(max, parseInt(m[1]));
  return max;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const BASE_URL = 'https://www.editorialnazari.com/team_group/autores/';

  // Cargar autores ya scrapeados si existe el JSON (para merge / reanudación)
  let yaEscrapeados = [];
  if (fs.existsSync(AUTORES_FILE)) {
    try { yaEscrapeados = JSON.parse(fs.readFileSync(AUTORES_FILE, 'utf8')).autores || []; }
    catch (_) {}
    console.log('\nJSON existente cargado: ' + yaEscrapeados.length + ' autores');
  }

  // Recalcular genero para los ya scrapeados con la lógica actual
  yaEscrapeados = yaEscrapeados.map(a => ({ ...a, genero: calcularGenero(a.nombre) }));

  console.log('Obteniendo listado de autores: ' + BASE_URL);
  const r1 = await obtenerHtml(BASE_URL);
  if (!r1.html) { console.error('No se pudo obtener el listado'); process.exit(1); }

  let todasUrls = extraerUrlsAutores(r1.html);
  const maxPag  = maxPaginaListado(r1.html);
  console.log(' Fuente listado: ' + r1.fuente + ' | Autores p.1: ' + todasUrls.length + ' | Páginas: ' + maxPag);

  for (let pg = 2; pg <= maxPag; pg++) {
    const pgUrl = BASE_URL + 'page/' + pg + '/';
    const pgR   = await obtenerHtml(pgUrl);
    if (!pgR.html) continue;
    const pgUrls = extraerUrlsAutores(pgR.html);
    pgUrls.forEach(u => { if (!todasUrls.includes(u)) todasUrls.push(u); });
    console.log(' Página ' + pg + ': +' + pgUrls.length + ' (total: ' + todasUrls.length + ')');
    await new Promise(r => setTimeout(r, DELAY_MS));
  }

  // URLs ya scrapeadas (para no repetir)
  const urlsYaHechas = new Set(yaEscrapeados.map(a => a.url));
  const pendientes   = todasUrls.slice(DESDE).filter(u => !urlsYaHechas.has(u));

  console.log('\n Total autores en listado: ' + todasUrls.length);
  console.log(' Ya scrapeados: ' + yaEscrapeados.length);
  console.log(' Pendientes:    ' + pendientes.length + (DESDE > 0 ? ' (desde posición ' + (DESDE+1) + ')' : '') + '\n');

  const nuevos = [], stats = { directo: 0, wayback: 0, sin_datos: 0 };

  for (let i = 0; i < pendientes.length; i++) {
    const url  = pendientes[i];
    const slug = url.split('/').filter(Boolean).pop();
    process.stdout.write('\r  [' + String(i+1).padStart(3) + '/' + pendientes.length + '] ' +
      slug.substring(0, 40).padEnd(40) + ' dir:' + stats.directo + ' wb:' + stats.wayback + ' err:' + stats.sin_datos + '  ');

    const r = await obtenerHtml(url);
    if (!r.html) {
      stats.sin_datos++;
      nuevos.push({ nombre: slug, bio: '', foto: '', roles: [], genero: '', url, _fuente: 'sin_datos', _error: true });
    } else {
      if (r.fuente === 'directo') stats.directo++;
      else if (r.fuente.startsWith('wayback')) stats.wayback++;
      else stats.sin_datos++;
      const a = parsearAutor(r.html, url);
      a.genero  = calcularGenero(a.nombre);
      a._fuente = r.fuente;
      nuevos.push(a);
    }
    if (i < pendientes.length - 1) await new Promise(r => setTimeout(r, DELAY_MS));
  }
  if (pendientes.length) process.stdout.write('\n');

  // Merge: ya scrapeados + nuevos
  const todos = [...yaEscrapeados, ...nuevos]
    .sort((a, b) => (a.nombre||'').localeCompare(b.nombre||'', 'es'));

  // ── Mostrar — bio completa sin truncar ────────────────────────────────────
  const sep = '─'.repeat(72);
  todos.filter(a => !a._error).forEach((a, i) => {
    console.log('\n' + sep);
    console.log(String(i+1).padStart(3) + '. ' + (a.nombre || '(sin nombre)'));
    if (a.roles.length)  console.log('    Roles:   ' + a.roles.join(', '));
    if (a.genero)        console.log('    Género:  ' + a.genero);
    if (a.foto)          console.log('    Foto:    ' + a.foto.substring(0, 80));
    if (a.bio) {
      console.log('    Bio (' + a.bio.length + ' chars):');
      // Bio completa — sin truncar ningún carácter
      a.bio.split('\n').forEach(l => console.log('      ' + l));
    }
  });

  console.log('\n' + '═'.repeat(72));
  console.log(' TOTAL: ' + todos.filter(a => !a._error).length + ' autores');
  console.log(' Con bio: '   + todos.filter(a => a.bio && a.bio.length > 50).length);
  console.log(' Con género: ' + todos.filter(a => a.genero).length);
  if (pendientes.length)
    console.log(' Fuentes nuevas — directo: ' + stats.directo + ' | wayback: ' + stats.wayback + ' | sin datos: ' + stats.sin_datos);

  if (GUARDAR_JSON) {
    fs.writeFileSync(AUTORES_FILE, JSON.stringify({
      fecha:  new Date().toISOString(),
      total:  todos.length,
      autores: todos,
    }, null, 2), 'utf8');
    console.log('\nGuardado: ' + AUTORES_FILE);
  }
}

main()
  .catch(e => { console.error('Error:', e.message || e); })
  .finally(async () => { if (_browser) await _browser.close(); process.exit(0); });
