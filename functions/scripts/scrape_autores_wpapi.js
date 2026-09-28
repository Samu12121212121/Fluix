'use strict';

/**
 * scrape_autores_wpapi.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Usa la WordPress REST API de editorialnazari.com para obtener todos los
 * autores sin pasar por el captcha/Cloudflare que bloquea el scraping HTML.
 *
 * Endpoints probados en orden:
 *   1. /wp-json/wp/v2/team          (CPT "team")
 *   2. /wp-json/wp/v2/team-member   (CPT "team-member")
 *   3. /wp-json/wp/v2/miembro       (CPT "miembro")
 *   4. /wp-json/wp/v2/autor         (CPT "autor")
 *   5. /wp-json/wp/v2/posts?type=team (fallback genérico)
 *
 * Para cada entrada extrae:
 *   • nombre  (title.rendered)
 *   • bio     (content.rendered limpio, COMPLETO)
 *   • rol     (excerpt.rendered o meta o primer párrafo corto de content)
 *   • etiquetas (términos de taxonomías asociadas)
 *
 * Guarda en: scripts/autores-web-scraped.json  (misma ruta que el scraper HTML)
 *
 * Uso:
 *   cd functions
 *   node scripts/scrape_autores_wpapi.js
 *   node scripts/scrape_autores_wpapi.js --test   (solo muestra los 5 primeros)
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

const BASE_API = 'https://www.editorialnazari.com/wp-json/wp/v2/';
const OUT_FILE = path.join(__dirname, 'autores-web-scraped.json');
const TEST     = process.argv.includes('--test');

// ── Normalización ──────────────────────────────────────────────────────────────
function norm(s) {
  return (s || '').toLowerCase().normalize('NFD').replace(/[^\x00-\x7F]/g, '').trim();
}

// ── HTTP GET JSON ──────────────────────────────────────────────────────────────
function fetchJson(url, hops) {
  hops = hops === undefined ? 4 : hops;
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
          'Accept-Language': 'es-ES,es;q=0.9',
        }
      }, function(res) {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          var loc = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
          res.resume();
          return fetchJson(loc, hops - 1).then(resolve);
        }
        var raw = '';
        res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() {
          try {
            var data = JSON.parse(raw);
            resolve({ status: res.statusCode, data: data, raw: raw, headers: res.headers });
          } catch(e) {
            resolve({ status: res.statusCode, data: null, raw: raw, error: 'invalid JSON' });
          }
        });
      });
      req.on('error', function(e) { resolve({ status: 0, data: null, error: e.message }); });
      req.setTimeout(20000, function() { req.destroy(); resolve({ status: 0, data: null, error: 'timeout' }); });
    } catch(e) {
      resolve({ status: 0, data: null, error: e.message });
    }
  });
}

// ── Limpiar HTML → texto plano ────────────────────────────────────────────────
function htmlToText(html) {
  if (!html) return '';
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&#8217;|&#8216;/g, "'")
    .replace(/&#8220;|&#8221;/g, '"')
    .replace(/&#8230;/g, '...').replace(/&#8212;/g, '--').replace(/&#8211;/g, '-')
    .replace(/&#160;|&nbsp;/g, ' ').replace(/&#\d+;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/ {2,}/g, ' ')
    .split('\n').map(function(l) { return l.trim(); }).filter(Boolean).join('\n')
    .trim();
}

// ── Extraer ROL del texto de la bio ───────────────────────────────────────────
var ROL_RE = /\b(autor[a]?|ilustrador[a]?|editor[a]?|traductor[a]?|prologuista|coordinador[a]?|compilador[a]?)\b/i;

function extraerRolDeTexto(excerpt, content) {
  // 1. Excerpt (WordPress muestra el "cargo" como excerpt en muchos temas)
  if (excerpt) {
    var ex = htmlToText(excerpt).trim();
    if (ex.length > 0 && ex.length < 100 && ROL_RE.test(ex)) return ex;
    // A veces es solo el rol directamente
    if (ex.length > 0 && ex.length < 60) return ex;
  }
  // 2. Primer párrafo corto del contenido que contenga palabra de rol
  var parrafos = htmlToText(content).split('\n').filter(function(l) { return l.trim().length > 0; });
  for (var i = 0; i < Math.min(3, parrafos.length); i++) {
    var p = parrafos[i].trim();
    if (p.length > 0 && p.length < 80 && ROL_RE.test(p)) return p;
  }
  return '';
}

// ── Descubrir qué endpoint CPT usa Nazarí ─────────────────────────────────────
async function findTeamEndpoint() {
  // Primero verificar que la API está accesible
  var root = await fetchJson(BASE_API.replace(/\/$/, ''));
  if (root.status !== 200 || !root.data) {
    console.log('  ❌ WordPress REST API no accesible (HTTP ' + root.status + ')');
    if (root.raw && root.raw.length < 500) console.log('  Respuesta:', root.raw.substring(0, 300));
    return null;
  }
  console.log('  ✅ WordPress REST API accesible');

  // Listar todos los tipos de post disponibles
  var types = await fetchJson(BASE_API + 'types');
  if (types.status === 200 && types.data) {
    var typeKeys = Object.keys(types.data).filter(function(k) {
      return types.data[k].rest_base && !['post','page','attachment','revision','nav_menu_item','wp_block','wp_template','wp_template_part','wp_navigation','wp_font_face','wp_font_family'].includes(k);
    });
    if (typeKeys.length > 0) {
      console.log('  Post types disponibles en REST API:', typeKeys.join(', '));
      // Preferir el que tenga "team" o "autor" o "miembro" en el nombre
      var teamType = typeKeys.find(function(k) { return /team|autor|miembro/i.test(k); });
      if (teamType) return BASE_API + types.data[teamType].rest_base;
      // Devolver el primero que no sea estándar
      return BASE_API + types.data[typeKeys[0]].rest_base;
    }
  }

  // Probar endpoints conocidos
  var candidates = ['team', 'team-member', 'team_member', 'miembro', 'autor', 'autores', 'member'];
  for (var i = 0; i < candidates.length; i++) {
    var url = BASE_API + candidates[i] + '?per_page=1';
    var r = await fetchJson(url);
    if (r.status === 200 && Array.isArray(r.data) && r.data.length >= 0) {
      console.log('  ✅ Endpoint encontrado: /wp/v2/' + candidates[i]);
      return BASE_API + candidates[i];
    }
  }

  console.log('  ⚠️  No se encontró endpoint CPT de equipo. Intentando con posts...');
  return BASE_API + 'posts';
}

// ── Obtener todos los items de un endpoint con paginación ──────────────────────
async function fetchAllItems(endpoint) {
  var all = [];
  var page = 1;
  var perPage = 100;

  while (true) {
    var url = endpoint + '?per_page=' + perPage + '&page=' + page + '&_fields=id,title,content,excerpt,slug,meta,acf,link,categories,tags,_links';
    process.stdout.write('\r  Página ' + page + '... (' + all.length + ' items)     ');
    var r = await fetchJson(url);

    if (r.status === 400 && r.data && r.data.code === 'rest_post_invalid_page_number') break;
    if (r.status !== 200 || !Array.isArray(r.data) || r.data.length === 0) break;

    all = all.concat(r.data);

    // Leer cabecera X-WP-TotalPages para saber cuántas páginas hay
    var totalPages = parseInt(r.headers && r.headers['x-wp-totalpages']) || 999;
    if (page >= totalPages || r.data.length < perPage) break;
    page++;
  }

  console.log('\r  Total items obtenidos: ' + all.length + '                    ');
  return all;
}

// ── Obtener términos de taxonomía de un item ──────────────────────────────────
async function fetchTerms(item) {
  var tags = [];
  if (!item._links) return tags;

  var termLinks = [];
  if (item._links['wp:term']) {
    termLinks = item._links['wp:term'];
  }

  for (var i = 0; i < termLinks.length; i++) {
    var href = termLinks[i].href;
    if (!href) continue;
    var r = await fetchJson(href);
    if (r.status === 200 && Array.isArray(r.data)) {
      r.data.forEach(function(t) {
        if (t.name && t.name.length > 0 && t.name.length < 80) {
          tags.push(t.name);
        }
      });
    }
  }
  return tags;
}

// ── Mostrar bio con saltos de línea correctos ─────────────────────────────────
function mostrarBio(bio, indent) {
  if (!bio) { console.log(indent + '(no encontrada)'); return; }
  var parrafos = bio.split('\n');
  parrafos.forEach(function(par, idx) {
    var palabras = par.trim().split(/\s+/);
    var linea = '';
    palabras.forEach(function(p) {
      if (linea.length + p.length + 1 > 72 && linea.length > 0) {
        console.log(indent + linea);
        linea = p;
      } else {
        linea = linea ? linea + ' ' + p : p;
      }
    });
    if (linea) console.log(indent + linea);
    if (idx < parrafos.length - 1 && parrafos[idx + 1] && parrafos[idx + 1].trim()) {
      // solo linea en blanco si el siguiente párrafo tiene texto
    }
  });
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '='.repeat(70));
  console.log(' WordPress REST API — Editorial Nazari autores');
  console.log('='.repeat(70) + '\n');

  console.log('  Verificando acceso a la API...');
  var endpoint = await findTeamEndpoint();
  if (!endpoint) {
    console.log('\n  ❌ No se puede acceder a la API. Opciones:');
    console.log('     1. La API REST de WordPress puede estar deshabilitada');
    console.log('     2. Prueba mas tarde con el scraper HTML (node scripts/scrape_autores_nazari.js)');
    console.log('     3. Abre editorialnazari.com en el navegador, copia las cookies');
    console.log('        y ejecuta: node scripts/scrape_con_cookies.js "cookie=valor..."');
    process.exit(1);
  }

  console.log('\n  Descargando todos los items...');
  var items = await fetchAllItems(endpoint);

  if (items.length === 0) {
    console.log('  ⚠️  Ningún item encontrado en ' + endpoint);
    console.log('  Posibles causas:');
    console.log('  - El CPT no tiene entradas publicadas en la API');
    console.log('  - Requiere autenticación');
    console.log('  - El endpoint correcto es otro');
    process.exit(1);
  }

  console.log('\n  Procesando ' + items.length + ' items...\n');

  var autores = [];
  var muestra = TEST ? items.slice(0, 5) : items;

  for (var i = 0; i < muestra.length; i++) {
    var item = muestra[i];
    var nombre = htmlToText(item.title ? item.title.rendered : '') || item.slug || '';
    var bioRaw = htmlToText(item.content ? item.content.rendered : '');
    var rol    = extraerRolDeTexto(item.excerpt ? item.excerpt.rendered : '', item.content ? item.content.rendered : '');

    // Limpiar la bio: quitar el rol si aparece como primer párrafo
    var bioLineas = bioRaw.split('\n').filter(function(l) { return l.trim().length > 0; });
    if (bioLineas.length > 0 && bioLineas[0].trim() === rol.trim()) {
      bioLineas = bioLineas.slice(1);
    }
    var bio = bioLineas.join('\n').trim();

    // Etiquetas via _links (hace fetch a cada taxonomía)
    var etiquetas = await fetchTerms(item);

    // También intentar ACF o meta para rol si está disponible
    if (!rol && item.acf) {
      var acfKeys = Object.keys(item.acf);
      for (var k = 0; k < acfKeys.length; k++) {
        var val = item.acf[acfKeys[k]];
        if (typeof val === 'string' && val.length > 0 && val.length < 80 && ROL_RE.test(val)) {
          rol = val; break;
        }
      }
    }

    autores.push({ posicion: 0, nombre: nombre, slug: item.slug, rol: rol, bio: bio, etiquetas: etiquetas, bioChars: bio.length, url: item.link });

    if (TEST) {
      console.log('  ─── ' + (i + 1) + '. ' + nombre);
      console.log('  rol:       ' + (rol || '(no detectado)'));
      console.log('  etiquetas: ' + (etiquetas.length ? etiquetas.join(' | ') : '(ninguna)'));
      console.log('  BIO (' + bio.length + 'c):');
      mostrarBio(bio, '    ');
      console.log();
    }
  }

  if (TEST) {
    console.log('  (Modo --test: solo primeros 5. Ejecuta sin --test para todos.)');
    process.exit(0);
  }

  // Ordenar alfabéticamente
  autores.sort(function(a, b) { return norm(a.nombre).localeCompare(norm(b.nombre), 'es', { sensitivity: 'base' }); });
  autores.forEach(function(a, i) { a.posicion = i + 1; });

  // Guardar JSON
  var out = {
    fecha_scraping: new Date().toISOString(),
    fuente: 'WordPress REST API',
    endpoint: endpoint,
    total_validos: autores.length,
    sin_rol: autores.filter(function(a) { return !a.rol; }).length,
    sin_bio: autores.filter(function(a) { return !a.bio; }).length,
    sin_etiquetas: autores.filter(function(a) { return a.etiquetas.length === 0; }).length,
    errores: [],
    sin_datos: [],
    autores: autores,
  };
  fs.writeFileSync(OUT_FILE, JSON.stringify(out, null, 2), 'utf8');

  console.log('='.repeat(70));
  console.log(' Completado');
  console.log('  Total autores:   ' + autores.length);
  console.log('  Con rol:         ' + autores.filter(function(a) { return a.rol; }).length);
  console.log('  Con bio:         ' + autores.filter(function(a) { return a.bio; }).length);
  console.log('  Con etiquetas:   ' + autores.filter(function(a) { return a.etiquetas.length > 0; }).length);
  console.log('  Guardado en:     ' + OUT_FILE);
  console.log('='.repeat(70));
  console.log('\n  Siguiente paso: node scripts/sync_autores_firestore.js\n');
}

main().catch(function(e) { console.error('\n❌ Error:', e.message || e); process.exit(1); });
