'use strict';

const https  = require('https');
const http   = require('http');
const path   = require('path');
const fs     = require('fs');
const crypto = require('crypto');

// ── CLI args ──────────────────────────────────────────────────────────────────
const URL_ARG      = process.argv.find(a => a.startsWith('http'));
const GUARDAR_JSON  = process.argv.includes('--json');
const COMPLETO      = process.argv.includes('--completo');
const argVal        = f => { const i = process.argv.indexOf(f); return i >= 0 ? process.argv[i + 1] : null; };
const PERFIL_FILE   = argVal('--perfil');
const CDX_PATRON    = argVal('--cdx');   // e.g. "editorialnazari.com/libro/*"
const UMBRAL        = Math.min(100, Math.max(0, parseInt(argVal('--umbral') || '100', 10)));
const DELAY_MS      = Math.max(0, parseInt(argVal('--delay') || '1000', 10));
let   SESSION_COOKIES = argVal('--cookies') || '';

if (!URL_ARG && !CDX_PATRON) {
  console.log('Uso: node scripts/extraer_url.js <URL> [--json] [--completo] [--perfil file.json] [--umbral N] [--delay ms]');
  console.log('     node scripts/extraer_url.js --cdx "dominio.com/path/*" [--json] [--umbral N] [--delay ms]');
  process.exit(1);
}

let perfil = null;
if (PERFIL_FILE) {
  try { perfil = JSON.parse(fs.readFileSync(PERFIL_FILE, 'utf8')); }
  catch (e) { console.error('Error leyendo perfil:', e.message); process.exit(1); }
}

// ── Puppeteer (navegador real — resuelve sgcaptcha automáticamente) ──────────
let _browser = null;
let _puppeteerOk = null; // null=sin probar, true/false
const _puppeteerBlocked = new Set(); // dominios que devuelven 403 — no reintentar

async function puppeteerFetch(url) {
  if (_puppeteerOk === null) {
    try {
      // puppeteer-extra con stealth oculta los indicadores de headless Chrome
      const puppeteerExtra = require('puppeteer-extra');
      const stealth = require('puppeteer-extra-plugin-stealth');
      puppeteerExtra.use(stealth());
      process.stderr.write('  [puppeteer] iniciando Chrome stealth...\n');
      _browser = await puppeteerExtra.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--window-size=1280,800'],
        defaultViewport: { width: 1280, height: 800 },
      });
      _puppeteerOk = true;
      process.stderr.write('  [puppeteer] listo\n');
    } catch (e) {
      _puppeteerOk = false;
      process.stderr.write('  [puppeteer] no disponible: ' + e.message + '\n');
    }
  }
  if (!_puppeteerOk || !_browser) return null;
  try { const host = new URL(url).hostname; if (_puppeteerBlocked.has(host)) return null; } catch (_) {}

  const page = await _browser.newPage();
  try {
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36');
    await page.setExtraHTTPHeaders({ 'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8' });
    // networkidle2 puede disparar mientras los workers PoW aún corren en JS local
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {});

    // Esperar a que los workers JS resuelvan el PoW y naveguen al destino (hasta 40s)
    let waited = 0;
    while (waited < 40000) {
      const cu = page.url(), title = await page.title().catch(() => '');
      if (!cu.includes('captcha') && !cu.includes('.well-known') && title !== 'Robot Challenge Screen') break;
      await new Promise(r => setTimeout(r, 800));
      waited += 800;
    }
    await page.waitForNetworkIdle({ idleTime: 500, timeout: 8000 }).catch(() => {});

    const finalUrl = page.url();
    const html = await page.content();
    const title = await page.title().catch(() => '');
    process.stderr.write('  [puppeteer] url final: ' + finalUrl + ' title: ' + title + ' (' + html.length + ' chars)\n');
    // Rechazar solo si seguimos en una página de challenge o error
    if (finalUrl.includes('.well-known') || finalUrl.includes('captcha')) return null;
    if (title === 'Robot Challenge Screen' || title === '403 - Forbidden') {
      try { _puppeteerBlocked.add(new URL(url).hostname); } catch (_) {}
      return null;
    }
    if (html.length < 2000) return null;
    return html;
  } catch (e) {
    process.stderr.write('  [puppeteer] error: ' + e.message + '\n');
    return null;
  } finally {
    await page.close();
  }
}

async function closeBrowser() {
  if (_browser) { try { await _browser.close(); } catch (_) {} _browser = null; }
}

// ── HTTP plano (para Wayback y URLs sin sgcaptcha) ────────────────────────────
function fetchHtml(url, hops, _accCk) {
  hops = hops === undefined ? 4 : hops; _accCk = _accCk || [];
  return new Promise(resolve => {
    const lib = url.startsWith('https') ? https : http;
    try {
      const req = lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          ...(SESSION_COOKIES ? { 'Cookie': SESSION_COOKIES } : {}),
        },
      }, res => {
        const ck = _accCk.concat(res.headers['set-cookie'] || []);
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          const loc = res.headers.location.startsWith('http')
            ? res.headers.location
            : new URL(res.headers.location, url).href;
          res.resume(); fetchHtml(loc, hops - 1, ck).then(resolve); return;
        }
        let raw = ''; res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => resolve({ status: res.statusCode, html: raw, url, setCookies: ck }));
        res.on('error', () => resolve({ status: 0, html: '', setCookies: ck }));
      });
      req.on('error', e => resolve({ status: 0, html: '', error: e.message, setCookies: [] }));
      req.setTimeout(20000, () => { req.destroy(); resolve({ status: 0, html: '', error: 'timeout', setCookies: [] }); });
    } catch (e) { resolve({ status: 0, html: '', error: e.message, setCookies: [] }); }
  });
}

async function fetchConWayback(urlOrig) {
  // 1. Intento directo con HTTP plano
  const r = await fetchHtml(urlOrig);
  if (r.status >= 200 && r.status < 300 && r.html && r.html.length > 2000 && !r.html.includes('sgcaptcha')) {
    return { html: r.html, fuente: 'directo' };
  }

  // 2. Si hay sgcaptcha, usar Puppeteer (Chrome real — auto-resuelve el challenge)
  if (r.html && (r.html.includes('sgcaptcha') || r.status === 202)) {
    const html = await puppeteerFetch(urlOrig);
    if (html) return { html, fuente: 'directo' };
  }

  // 3. Fallback: Wayback Machine
  const limpio = urlOrig.replace(/^https?:\/\/(www\.)?/, '');

  function waybackGet(url) {
    return new Promise(resolve => {
      https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' } }, res => {
        let raw = ''; res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => { try { resolve(JSON.parse(raw)); } catch (_) { resolve(null); } });
      }).on('error', () => resolve(null));
    });
  }

  // 3a. API "available" (rápida, cubre páginas populares)
  let snapUrl = null, snapTs = '';
  const avail = await waybackGet('https://archive.org/wayback/available?url=' + limpio);
  const snap = avail && avail.archived_snapshots && avail.archived_snapshots.closest;
  if (snap && snap.url) { snapUrl = snap.url; snapTs = (snap.timestamp || '').substring(0, 8); }

  // 3b. CDX API (índice completo — encuentra páginas que "available" no devuelve)
  if (!snapUrl) {
    const cdx = await waybackGet(
      'https://web.archive.org/cdx/search/cdx?url=' + limpio +
      '&output=json&limit=1&filter=statuscode:200&fl=timestamp,original&from=20200101'
    );
    if (cdx && cdx.length > 1) {
      const [ts, orig] = cdx[1];
      snapUrl = 'https://web.archive.org/web/' + ts + '/' + orig;
      snapTs = ts.substring(0, 8);
    }
  }

  if (!snapUrl) return { html: '', fuente: 'sin_datos' };
  const arch = await fetchHtml(snapUrl);
  if (!arch.html) return { html: '', fuente: 'wayback_error' };
  const html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');
  return { html, fuente: 'wayback:' + snapTs };
}

// ── HTML utils ────────────────────────────────────────────────────────────────
function stripTagsPreserveLines(h) {
  return (h || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(?:p|div|li|dt|dd|tr|blockquote|h[1-6]|section|article|header|footer)>/gi, '\n')
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
  return stripTagsPreserveLines(h).replace(/\n+/g, ' ').replace(/  +/g, ' ').trim();
}

const escRe = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function extractBlock(html, selector) {
  const s = selector.trim();
  let tagPat = '[a-z][a-z0-9]*', attrPre = '';
  if (s.startsWith('#')) {
    attrPre = '(?=[^>]*\\bid=["\']' + escRe(s.slice(1)) + '["\'])';
  } else if (s.startsWith('.')) {
    attrPre = '(?=[^>]*class=["\'][^"\']*\\b' + escRe(s.slice(1)) + '\\b)';
  } else if (s.includes('.')) {
    const [t, c] = s.split('.', 2);
    tagPat = escRe(t);
    attrPre = '(?=[^>]*class=["\'][^"\']*\\b' + escRe(c) + '\\b)';
  } else {
    tagPat = escRe(s);
  }
  const openRe = new RegExp('<(' + tagPat + ')' + attrPre + '[^>]*>', 'i');
  const m = openRe.exec(html);
  if (!m) return null;
  const tag = m[1].toLowerCase();
  const start = m.index + m[0].length;
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

function wrapText(text, width) {
  width = width || 76;
  return text.split('\n').map(line => {
    if (line.length <= width) return line;
    const words = line.split(/\s+/); let cur = '';
    const out = [];
    for (const w of words) {
      if (cur.length + w.length + (cur ? 1 : 0) > width && cur) { out.push(cur); cur = w; }
      else { cur = cur ? cur + ' ' + w : w; }
    }
    if (cur) out.push(cur);
    return out.join('\n');
  }).join('\n');
}

// ── Extraction ────────────────────────────────────────────────────────────────
function extraerMeta(html, url) {
  const get = re => { const m = re.exec(html); return m ? m[1] : ''; };
  return {
    titulo:   stripTags(get(/<title[^>]*>([\s\S]*?)<\/title>/i)),
    meta_desc: get(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i)
            || get(/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/i),
    og_title: stripTags(
                get(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i)
             || get(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/i) || ''),
    og_image: get(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
           || get(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i),
    baseHost: (() => { try { return new URL(url).hostname; } catch (_) { return ''; } })(),
  };
}

function extraerJsonLd(html) {
  const re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  const out = []; let m;
  while ((m = re.exec(html)) !== null) { try { out.push(JSON.parse(m[1])); } catch (_) {} }
  return out;
}

function bloqueContenido(html) {
  const candidatos = ['main', 'article', '.entry-content', '.post-content', '.page-content',
    '.content-area', '#content', '.wpb_text_column', '.single-content', '.product-description'];
  for (const sel of candidatos) {
    const b = extractBlock(html, sel);
    if (b && stripTags(b).length > 200) return b;
  }
  const divRe = /<div[^>]*>([\s\S]*?)<\/div>/gi;
  let m2, maxLen = 0, best = null;
  while ((m2 = divRe.exec(html)) !== null) {
    const len = stripTags(m2[1]).length;
    if (len > maxLen) { maxLen = len; best = m2[1]; }
  }
  return best;
}

function detectarListado(html, url, perf) {
  if (perf && perf.listado_selector) {
    const m = perf.listado_selector.match(/a\[href\*=["']([^"']+)["']\]/);
    if (m) {
      const re = new RegExp('href=["\']([^"\']*' + escRe(m[1]) + '[^"\']*)["\']', 'gi');
      const links = new Set(); let mm;
      while ((mm = re.exec(html)) !== null) links.add(mm[1]);
      return [...links];
    }
  }
  let base = ''; try { const u = new URL(url); base = u.protocol+'//'+ u.host; } catch(_) {}
  const allLinks = [], re = /href=["'](https?:\/\/[^"'#?]+|\/[^"'#?][^"']*)['"]/gi; let m;
  while ((m = re.exec(html)) !== null) allLinks.push(m[1].startsWith('/') ? base+m[1] : m[1]);
  const prefixMap = {};
  for (const link of allLinks) {
    try {
      const u = new URL(link);
      if (u.hostname !== new URL(base||'http://x').hostname) continue;
      const segs = u.pathname.split('/').filter(Boolean); if (!segs.length) continue;
      const p = segs.slice(0,-1).join('/');
      if (!prefixMap[p]) prefixMap[p] = new Set();
      prefixMap[p].add(link);
    } catch(_) {}
  }
  let best = null, bestN = 0;
  for (const links of Object.values(prefixMap)) {
    if (links.size > bestN && links.size >= 4) { bestN = links.size; best = [...links]; }
  }
  return best || [];
}

function extraerFicha(html, url, perf) {
  const meta = extraerMeta(html, url), jsonLd = extraerJsonLd(html), ld = jsonLd[0] || {};
  const ficha = { url, titulo: meta.titulo||meta.og_title||ld.name||'', meta_desc: meta.meta_desc||'', og_image: meta.og_image||'', json_ld: jsonLd };
  if (ld.description)   ficha.descripcion_ld   = ld.description;
  if (ld.datePublished) ficha.fecha_publicacion = ld.datePublished;
  const ldPrecio = ld.price || (ld.offers && ld.offers.price); if (ldPrecio) ficha.precio = String(ldPrecio);
  const contenedor = (perf && perf.contenedor) ? (extractBlock(html, perf.contenedor) || html) : html;

  if (perf && perf.campos) {
    for (const [campo, selector] of Object.entries(perf.campos)) {
      const bloque = extractBlock(contenedor, selector);
      if (bloque !== null) ficha[campo] = stripTagsPreserveLines(bloque);
    }
  } else {
    const bloque = bloqueContenido(html);
    if (bloque) {
      ficha.contenido_principal = stripTagsPreserveLines(bloque);
      if (!ficha.precio) { const pm=bloque.match(/(\d[\d.]*[,]\d{2})\s*€|€\s*(\d[\d.]*[,]\d{2})/); if(pm) ficha.precio=(pm[1]||pm[2]).replace(',','.'); }
      if (!ficha.fecha_publicacion) { const fm=bloque.match(/(\d{4}-\d{2}-\d{2}|\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})/); if(fm) ficha.fecha_publicacion=fm[1]; }
    }
    const h1m = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    if (h1m && !ficha.titulo) ficha.titulo = stripTags(h1m[1]);
    const parrafos = [], pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm2;
    while ((pm2 = pRe.exec(html)) !== null) {
      const txt = stripTagsPreserveLines(pm2[1]);
      if (txt.length >= 40 && !/cookie|aviso legal|newsletter|política de privacidad/i.test(txt)) parrafos.push(txt);
    }
    if (parrafos.length) ficha.parrafos = parrafos;
  }
  const imagenes = [], imgRe = /<img[^>]+src=["']([^"']+)["'][^>]*/gi; let imgM;
  while ((imgM = imgRe.exec(html)) !== null) {
    if (!imgM[1].startsWith('data:')) { const a=imgM[0].match(/alt=["']([^"']*)["']/); imagenes.push({ src: imgM[1], alt: a?a[1]:'' }); }
  }
  ficha.imagenes = imagenes;
  const links_int = [], links_ext = [], seen = new Set(), aRe = /<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi; let am;
  while ((am = aRe.exec(html)) !== null) {
    const href = am[1].trim();
    if (!href || href.startsWith('#') || href.startsWith('javascript') || seen.has(href)) continue;
    seen.add(href);
    const entry = { href, texto: stripTags(am[2]) };
    if (href.startsWith('/') || (meta.baseHost && href.includes(meta.baseHost))) links_int.push(entry);
    else if (href.startsWith('http')) links_ext.push(entry);
  }
  ficha.links_internos = links_int; ficha.links_externos = links_ext;
  return ficha;
}

// ── Inferencia de tipos y análisis de cobertura ──────────────────────────────
function inferirTipo(valores) {
  const vals = valores
    .map(v => (v === null || v === undefined) ? '' : (typeof v === 'object' ? JSON.stringify(v) : String(v)).trim())
    .filter(v => v !== '');
  if (!vals.length) return 'String';
  if (vals.every(v => /^(true|false|si|sí|no|yes|1|0)$/i.test(v)))  return 'Booleano';
  if (vals.every(v => /^https?:\/\/\S+$/.test(v)))                   return 'URL';
  const dateRe = /^(\d{4}-\d{2}-\d{2}(T[\d:.Z+-]+)?|\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{1,2} de \w+ de \d{4})$/i;
  if (vals.every(v => dateRe.test(v)))                                return 'Fecha';
  if (vals.every(v => /^-?\d+$/.test(v)))                            return 'Int';
  if (vals.every(v => /^-?[\d]+[.,][\d]+$/.test(v) || /^-?\d+$/.test(v))) return 'Double';
  return 'String';
}

function analizarCampos(registros, umbral) {
  if (!registros.length) return [];
  const excluir = new Set(['url', '_fuente', '_error']), allKeys = new Set();
  registros.forEach(r => r && Object.keys(r).forEach(k => allKeys.add(k)));
  return [...allKeys].filter(k => !excluir.has(k)).map(k => {
      const vals = registros.map(r => r ? r[k] : undefined);
      const nPresentes = vals.filter(v => {
        if (v === null || v === undefined) return false;
        if (typeof v === 'string' && !v.trim()) return false;
        if (Array.isArray(v) && !v.length) return false;
        return true;
      }).length;
      const pct = Math.round(nPresentes / registros.length * 100);
      return {
        campo: k,
        tipo: inferirTipo(vals),
        presentes: nPresentes,
        total: registros.length,
        porcentaje: pct,
        esNucleo: pct >= umbral,
      };
    })
    .sort((a, b) => b.porcentaje - a.porcentaje || a.campo.localeCompare(b.campo, 'es'));
}

// ── Display ───────────────────────────────────────────────────────────────────
function mostrarFicha(ficha, fuente) {
  const sep = '─'.repeat(72);
  console.log('\n' + sep);
  console.log(' URL:    ' + ficha.url);
  if (fuente) console.log(' Fuente: ' + fuente);
  console.log(sep);
  if (ficha.titulo)            console.log('\n Título:    ' + ficha.titulo);
  if (ficha.meta_desc)         console.log(' Meta desc: ' + ficha.meta_desc);
  if (ficha.og_image)          console.log(' OG image:  ' + ficha.og_image);
  if (ficha.precio)            console.log(' Precio:    ' + ficha.precio);
  if (ficha.fecha_publicacion) console.log(' Fecha:     ' + ficha.fecha_publicacion);

  const omitir = new Set(['url','titulo','meta_desc','og_image','precio','fecha_publicacion','contenido_principal','parrafos','json_ld','imagenes','links_internos','links_externos','_fuente','_error','descripcion_ld']);

  if (ficha.contenido_principal) {
    console.log('\n Contenido principal (' + ficha.contenido_principal.length + ' chars):');
    console.log(wrapText(ficha.contenido_principal, 72).split('\n').map(l => '  ' + l).join('\n'));
  }
  if (ficha.parrafos && ficha.parrafos.length) {
    console.log('\n Párrafos (' + ficha.parrafos.length + '):');
    ficha.parrafos.forEach((p, i) => {
      console.log('\n  [' + (i + 1) + '] (' + p.length + ' chars)');
      console.log(wrapText(p, 72).split('\n').map(l => '  ' + l).join('\n'));
    });
  }
  for (const [k, v] of Object.entries(ficha)) {
    if (omitir.has(k) || typeof v !== 'string' || !v.trim()) continue;
    console.log('\n ' + k + ' (' + v.length + ' chars):');
    console.log(wrapText(v, 72).split('\n').map(l => '  ' + l).join('\n'));
  }
  if (ficha.json_ld && ficha.json_ld.length) {
    console.log('\n JSON-LD (' + ficha.json_ld.length + ' bloques):');
    ficha.json_ld.forEach(s => console.log('  @type: ' + (s['@type'] || '?') + (s.name ? ' — "' + s.name + '"' : '')));
  }
  console.log('\n Links: ' + ficha.links_internos.length + ' internos  |  ' + ficha.links_externos.length + ' externos');
  console.log(' Imágenes: ' + ficha.imagenes.length);
}

function mostrarResumen(analisis, stats, umbral) {
  const sep = '═'.repeat(72);
  const total = analisis.length ? analisis[0].total : 0;
  console.log('\n' + sep);
  console.log(' RESUMEN — ' + total + ' registros  |  umbral núcleo: ' + umbral + '%');
  console.log(sep);

  const porTipo = {};
  analisis.forEach(c => { porTipo[c.tipo] = (porTipo[c.tipo] || 0) + 1; });
  const tiposStr = Object.entries(porTipo).sort((a, b) => b[1] - a[1]).map(([t, n]) => n + ' ' + t).join(', ');
  console.log('\n ' + tiposStr + ' — total ' + analisis.length + ' campos');

  const nucleo = analisis.filter(c => c.esNucleo);
  console.log(' Campos núcleo (' + nucleo.length + '): ' + (nucleo.map(c => c.campo).join(', ') || '—'));

  console.log('\n ' + 'Campo'.padEnd(28) + 'Tipo'.padEnd(12) + 'Presencia         Núcleo');
  console.log(' ' + '─'.repeat(62));
  analisis.forEach(c => {
    const pct = String(c.porcentaje).padStart(3) + '% (' + c.presentes + '/' + c.total + ')';
    console.log(' ' + c.campo.substring(0, 27).padEnd(28) + c.tipo.padEnd(12) + pct.padEnd(20) + (c.esNucleo ? '✓' : ''));
  });

  if (stats) {
    console.log('\n Fuentes de datos:');
    if (stats.directo  > 0) console.log('   Directas:               ' + stats.directo);
    if (stats.wayback  > 0) console.log('   Wayback (caché archivada): ' + stats.wayback + '  ⚠ datos pueden estar desactualizados');
    if (stats.sin_datos > 0) console.log('   Sin datos / error:      ' + stats.sin_datos);
  }
}

function guardarJson(data, nombre) {
  const outFile = path.join(__dirname, nombre);
  fs.writeFileSync(outFile, JSON.stringify(data, null, 2), 'utf8');
  console.log('\nGuardado: ' + outFile);
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\nFetching: ' + URL_ARG + ' ...');
  const res = await fetchConWayback(URL_ARG);
  if (!res.html) {
    console.error('Error: sin contenido (fuente: ' + (res.fuente || 'error') + ')');
    process.exit(1);
  }

  const ficha = extraerFicha(res.html, URL_ARG, perfil);
  ficha._fuente = res.fuente;
  mostrarFicha(ficha, res.fuente);

  const listaLinks = detectarListado(res.html, URL_ARG, perfil);
  if (listaLinks.length) {
    console.log('\n Listado detectado: ' + listaLinks.length + ' enlaces');
    listaLinks.slice(0, 10).forEach((u, i) => console.log('  ' + String(i + 1).padStart(3) + '. ' + u));
    if (listaLinks.length > 10) console.log('  ... y ' + (listaLinks.length - 10) + ' más');
  }

  if (!COMPLETO || !listaLinks.length) {
    if (GUARDAR_JSON) guardarJson({ ficha, listado: listaLinks }, 'extraer_url_resultado.json');
    return;
  }

  let todasUrls = [...new Set(listaLinks)];
  const pRe = /href=["'][^"']*\/page\/(\d+)\/["']/gi; let pm; let maxPag = 1;
  while ((pm = pRe.exec(res.html)) !== null) maxPag = Math.max(maxPag, parseInt(pm[1]));
  for (let pg = 2; pg <= maxPag; pg++) {
    const pgUrl = (perfil && perfil.paginacion)
      ? URL_ARG.replace(/\/?$/, '/') + perfil.paginacion.replace('{n}', pg)
      : URL_ARG.replace(/\/?$/, '/') + 'page/' + pg + '/';
    const pgRes = await fetchConWayback(pgUrl);
    if (!pgRes.html) continue;
    const pgLinks = detectarListado(pgRes.html, pgUrl, perfil);
    pgLinks.forEach(u => { if (!todasUrls.includes(u)) todasUrls.push(u); });
    console.log('  Página ' + pg + ': +' + pgLinks.length + ' (total: ' + todasUrls.length + ')');
  }

  console.log('\n DESCARGANDO ' + todasUrls.length + ' páginas (~' + Math.round(todasUrls.length * DELAY_MS / 60000) + ' min)\n');
  const registros = [], stats = { directo: 0, wayback: 0, sin_datos: 0 };

  for (let i = 0; i < todasUrls.length; i++) {
    const u = todasUrls[i];
    process.stdout.write('\r  [' + String(i+1).padStart(3) + '/' + todasUrls.length + '] ' +
      (u.split('/').filter(Boolean).pop() || u).substring(0, 36).padEnd(36) +
      ' dir:' + stats.directo + ' wb:' + stats.wayback + ' err:' + stats.sin_datos + '  ');
    const ir = await fetchConWayback(u);
    if (!ir.html) {
      stats.sin_datos++;
      registros.push({ url: u, _fuente: ir.fuente, _error: true });
    } else {
      if (ir.fuente === 'directo') stats.directo++;
      else if (ir.fuente.startsWith('wayback')) stats.wayback++;
      else stats.sin_datos++;
      const f = extraerFicha(ir.html, u, perfil);
      f._fuente = ir.fuente;
      registros.push(f);
    }
    if (i < todasUrls.length - 1) await new Promise(r => setTimeout(r, DELAY_MS));
  }
  process.stdout.write('\n');

  const analisis = analizarCampos(registros, UMBRAL);
  mostrarResumen(analisis, stats, UMBRAL);
  if (GUARDAR_JSON) {
    guardarJson({ fecha: new Date().toISOString(), url_listado: URL_ARG, total: registros.length,
      umbral_nucleo: UMBRAL, stats_fuentes: stats, analisis_campos: analisis, registros },
      'extraer_url_resultado.json');
  }
}

// ── Modo --cdx: obtener TODAS las URLs de un patrón vía CDX API ───────────────
async function getCdxUrls(patron) {
  const encoded = encodeURIComponent(patron);
  const apiUrl = 'https://web.archive.org/cdx/search/cdx?url=' + encoded +
    '&output=json&fl=original,timestamp&filter=statuscode%3A200&collapse=urlkey&from=20200101&limit=1000';
  return new Promise(resolve => {
    https.get(apiUrl, { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' } }, res => {
      let raw = ''; res.setEncoding('utf8');
      res.on('data', c => raw += c);
      res.on('end', () => {
        try {
          const rows = JSON.parse(raw);
          // row[0] = header ["original","timestamp"], resto son datos
          const urls = rows.slice(1).map(r => ({ url: r[0], timestamp: r[1] }));
          resolve(urls);
        } catch (_) { resolve([]); }
      });
    }).on('error', () => resolve([]));
  });
}

async function mainCdx() {
  console.log('\nConsultando CDX para patrón: ' + CDX_PATRON + ' ...');
  const cdxUrls = await getCdxUrls(CDX_PATRON);
  if (!cdxUrls.length) {
    console.error('CDX no devolvió URLs. Verifica el patrón o que archive.org esté disponible.');
    return;
  }
  console.log(' URLs encontradas en CDX: ' + cdxUrls.length);

  const registros = [], stats = { directo: 0, wayback: 0, sin_datos: 0 };
  for (let i = 0; i < cdxUrls.length; i++) {
    const { url, timestamp } = cdxUrls[i];
    const slug = url.split('/').filter(Boolean).pop() || url;
    process.stdout.write('\r  [' + String(i+1).padStart(3) + '/' + cdxUrls.length + '] ' +
      slug.substring(0, 38).padEnd(38) + ' wb:' + stats.wayback + ' err:' + stats.sin_datos + '  ');

    // Usar directamente el snapshot que ya conocemos del CDX (más rápido)
    const snapUrl = 'https://web.archive.org/web/' + timestamp + '/' + url;
    const arch = await fetchHtml(snapUrl);
    if (!arch.html || arch.html.length < 2000) {
      // Intentar la ruta normal con fallback CDX
      const r = await fetchConWayback(url);
      if (!r.html) { stats.sin_datos++; registros.push({ url, _fuente: 'sin_datos', _error: true }); }
      else {
        stats.wayback++;
        const f = extraerFicha(r.html, url, perfil);
        f._fuente = r.fuente; registros.push(f);
      }
    } else {
      stats.wayback++;
      const html = arch.html
        .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
        .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
        .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');
      const f = extraerFicha(html, url, perfil);
      f._fuente = 'wayback:' + timestamp.substring(0, 8);
      registros.push(f);
    }
    if (i < cdxUrls.length - 1) await new Promise(r => setTimeout(r, DELAY_MS));
  }
  process.stdout.write('\n');

  const analisis = analizarCampos(registros, UMBRAL);
  mostrarResumen(analisis, stats, UMBRAL);
  if (GUARDAR_JSON) {
    guardarJson({ fecha: new Date().toISOString(), cdx_patron: CDX_PATRON,
      total: registros.length, umbral_nucleo: UMBRAL,
      stats_fuentes: stats, analisis_campos: analisis, registros },
      'extraer_url_resultado.json');
  }
}

if (CDX_PATRON) {
  mainCdx().catch(e => { console.error('Error:', e.message || e); }).finally(() => closeBrowser().then(() => process.exit(0)));
} else {
  main().catch(e => { console.error('Error:', e.message || e); }).finally(() => closeBrowser().then(() => process.exit(0)));
}
