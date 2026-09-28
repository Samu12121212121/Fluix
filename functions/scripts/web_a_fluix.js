'use strict';

/**
 * web_a_fluix.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Extractor universal: mete cualquier URL y saca TODOS los campos detectables,
 * medidos y mapeados a los campos de la aplicacion Fluix.
 *
 * Detecta automaticamente:
 *   - Nombre / razon social          - Descripcion / bio
 *   - Logo / foto principal           - Telefono(s)
 *   - Email(s)                        - Direccion / ciudad / CP
 *   - Horario                         - Redes sociales (FB, IG, TW, LK, YT...)
 *   - Links importantes (catalogo,    - Precios
 *     reservas, tienda, etc.)         - Servicios / productos listados
 *   - Etiquetas / categorias          - Schema.org estructurado
 *   - CTA buttons (textos de botones) - OG / SEO meta tags
 *
 * Uso:
 *   cd functions
 *   node scripts/web_a_fluix.js https://www.cliente.com/
 *   node scripts/web_a_fluix.js https://www.cliente.com/ --json
 *   node scripts/web_a_fluix.js https://www.cliente.com/ --json --fluix
 *
 *   --json   guarda resultado en scripts/web_a_fluix_resultado.json
 *   --fluix  ademas guarda scripts/web_a_fluix_campos_fluix.json
 *            (objeto listo para subir a Firestore)
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');

const URL_ARG     = process.argv.find(function(a) { return a.startsWith('http'); });
const GUARDAR     = process.argv.includes('--json');
const PARA_FLUIX  = process.argv.includes('--fluix');
const SUBPAGINAS  = process.argv.includes('--subpaginas');  // sigue links internos clave

// Palabras clave de paginas que suelen tener datos utiles
const SUBPAGINAS_KEYWORDS = /(?:contacto?|contact|about|sobre.?(?:mi|nos)|quienes?|historia|nosotros|quien-somos|servicios?|services|precios?|tarifas?|productos?|catalogo|tienda|shop|menu|carta)/i;

if (!URL_ARG) {
  console.log('\nUso: node scripts/web_a_fluix.js <URL> [opciones]\n');
  console.log('  <URL>          pagina web del cliente');
  console.log('  --json         guarda JSON completo de todos los datos');
  console.log('  --fluix        genera JSON listo para Firestore/Fluix');
  console.log('  --subpaginas   tambien analiza subpaginas clave (contacto, servicios, etc.)');
  console.log('');
  console.log('Ejemplos:');
  console.log('  node scripts/web_a_fluix.js https://www.cliente.es/');
  console.log('  node scripts/web_a_fluix.js https://www.cliente.es/ --subpaginas --json --fluix\n');
  process.exit(0);
}

// ── Mapa de campos Fluix ────────────────────────────────────────────────────────
const CAMPOS_FLUIX = {
  nombre:          { label: 'Nombre del negocio',        tipo: 'texto_corto' },
  nombre_legal:    { label: 'Razon social / NIF',         tipo: 'texto_corto' },
  descripcion:     { label: 'Descripcion corta',          tipo: 'texto' },
  bio:             { label: 'Texto largo / historia',     tipo: 'texto_largo' },
  logo_url:        { label: 'Logo (URL)',                  tipo: 'imagen_url' },
  foto_url:        { label: 'Foto principal (URL)',        tipo: 'imagen_url' },
  telefono:        { label: 'Telefono principal',          tipo: 'telefono' },
  telefono_2:      { label: 'Telefono secundario',         tipo: 'telefono' },
  email:           { label: 'Email principal',             tipo: 'email' },
  email_2:         { label: 'Email secundario',            tipo: 'email' },
  web:             { label: 'Web',                         tipo: 'url' },
  direccion:       { label: 'Direccion',                   tipo: 'texto_corto' },
  ciudad:          { label: 'Ciudad',                      tipo: 'texto_corto' },
  provincia:       { label: 'Provincia',                   tipo: 'texto_corto' },
  cp:              { label: 'Codigo postal',               tipo: 'texto_corto' },
  pais:            { label: 'Pais',                        tipo: 'texto_corto' },
  horario:         { label: 'Horario',                     tipo: 'texto' },
  facebook:        { label: 'Facebook',                    tipo: 'url_social' },
  instagram:       { label: 'Instagram',                   tipo: 'url_social' },
  twitter:         { label: 'Twitter / X',                 tipo: 'url_social' },
  linkedin:        { label: 'LinkedIn',                    tipo: 'url_social' },
  youtube:         { label: 'YouTube',                     tipo: 'url_social' },
  tiktok:          { label: 'TikTok',                      tipo: 'url_social' },
  pinterest:       { label: 'Pinterest',                   tipo: 'url_social' },
  whatsapp:        { label: 'WhatsApp (link)',              tipo: 'url_social' },
  catalogo:        { label: 'Link al catalogo',            tipo: 'url' },
  reservas:        { label: 'Link de reservas',            tipo: 'url' },
  tienda:          { label: 'Tienda online',               tipo: 'url' },
  precio_desde:    { label: 'Precio desde',                tipo: 'numero' },
  etiquetas:       { label: 'Etiquetas / categorias',      tipo: 'array' },
  servicios:       { label: 'Servicios / productos',       tipo: 'array' },
  cta_principal:   { label: 'Boton CTA principal (texto)', tipo: 'texto_corto' },
  cta_url:         { label: 'Boton CTA principal (link)',  tipo: 'url' },
  schema_tipo:     { label: 'Tipo de negocio (Schema)',    tipo: 'texto_corto' },
  meta_descripcion:{ label: 'Meta description SEO',        tipo: 'texto' },
  og_imagen:       { label: 'Imagen OG (redes sociales)',  tipo: 'imagen_url' },
};

// ── HTTP fetch ─────────────────────────────────────────────────────────────────
function fetchHtml(url, hops) {
  hops = hops === undefined ? 4 : hops;
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, { headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html', 'Accept-Language': 'es-ES,es;q=0.9',
      }}, function(res) {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          var loc = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
          res.resume(); return fetchHtml(loc, hops - 1).then(resolve);
        }
        var raw = ''; res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() { resolve({ status: res.statusCode, html: raw, finalUrl: url }); });
        res.on('error', function() { resolve({ status: 0, html: '' }); });
      });
      req.on('error', function(e) { resolve({ status: 0, html: '', error: e.message }); });
      req.setTimeout(20000, function() { req.destroy(); resolve({ status: 0, html: '', error: 'timeout' }); });
    } catch(e) { resolve({ status: 0, html: '', error: e.message }); }
  });
}

function fetchJson(url) {
  return new Promise(function(resolve) {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' } }, function(res) {
      var raw = ''; res.setEncoding('utf8');
      res.on('data', function(c) { raw += c; });
      res.on('end', function() { try { resolve({ status: res.statusCode, data: JSON.parse(raw) }); } catch(e) { resolve({ status: res.statusCode, data: null }); } });
    }).on('error', function() { resolve({ status: 0, data: null }); });
  });
}

async function fetchConWayback(urlOriginal) {
  var r = await fetchHtml(urlOriginal);
  if (r.status >= 200 && r.status < 300 && r.html && r.html.length > 2000 && !r.html.includes('sgcaptcha')) {
    return { html: r.html, fuente: 'directo' };
  }
  var limpio = urlOriginal.replace(/^https?:\/\/(www\.)?/, '');
  var api = await fetchJson('https://archive.org/wayback/available?url=' + limpio);
  var archiveUrl = api.data && api.data.archived_snapshots && api.data.archived_snapshots.closest && api.data.archived_snapshots.closest.url;
  if (!archiveUrl) return { html: r.html || '', fuente: 'sin_wayback' };
  var arch = await fetchHtml(archiveUrl);
  if (!arch.html) return { html: '', fuente: 'error' };
  var html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');
  return { html: html, fuente: 'wayback:' + (api.data.archived_snapshots.closest.timestamp || '').substring(0, 8) };
}

function st(h) {
  return (h||'').replace(/<[^>]+>/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#\d+;/g,' ').replace(/\s+/g,' ').trim();
}

function meta(html, name) {
  var m = html.match(new RegExp('<meta[^>]+(?:name|property)=["\']' + name + '["\'][^>]+content=["\']([^"\']+)["\']', 'i')) ||
          html.match(new RegExp('<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:name|property)=["\']' + name + '["\']', 'i'));
  return m ? st(m[1]) : '';
}

function primero(arr) { return arr && arr.length > 0 ? arr[0] : null; }

// ── EXTRACTOR PRINCIPAL ────────────────────────────────────────────────────────
function extraerCampos(html, urlBase) {
  var campos = {};

  // ── NOMBRE ──────────────────────────────────────────────────────────────────
  // Schema.org > OG title > H1 > Title
  var schemaOrg = [];
  var schemaRe = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi; var sm;
  while ((sm = schemaRe.exec(html)) !== null) {
    try { var s = JSON.parse(sm[1]); schemaOrg.push(s); } catch(_) {}
  }
  var schemaNegocio = schemaOrg.find(function(s) { return s['@type'] && /Organization|LocalBusiness|Person|Company|Store/i.test(s['@type']); });

  if (schemaNegocio && schemaNegocio.name) campos.nombre = schemaNegocio.name;
  else {
    var ogTitle = meta(html, 'og:title');
    var h1M = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    var h1 = h1M ? st(h1M[1]) : '';
    var titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    var title = titleM ? st(titleM[1]).split(/[|\-–—:]/).map(function(t){return t.trim();}).filter(Boolean)[0] : '';
    campos.nombre = h1 || ogTitle || title || '';
  }

  // ── DESCRIPCION ─────────────────────────────────────────────────────────────
  campos.meta_descripcion = meta(html, 'description');
  campos.og_imagen = meta(html, 'og:image');

  if (schemaNegocio && schemaNegocio.description) {
    campos.bio = schemaNegocio.description;
  } else {
    // Buscar el parrafo mas largo que parezca descripcion del negocio
    var pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi; var pm; var parrafos = [];
    while ((pm = pRe.exec(html)) !== null) {
      var t = st(pm[1]);
      if (t.length >= 80 && !/cookie|aviso|newsletter|politica/i.test(t)) parrafos.push(t);
    }
    if (parrafos.length > 0) {
      var masLargo = parrafos.sort(function(a,b){return b.length-a.length;})[0];
      campos.bio = masLargo;
    }
  }
  // Descripcion corta = meta o primeros 220c del bio
  if (!campos.descripcion) {
    campos.descripcion = campos.meta_descripcion || (campos.bio ? campos.bio.substring(0, 1500) + (campos.bio.length > 1500 ? '...' : '') : '');
  }

  // ── LOGO / FOTO ──────────────────────────────────────────────────────────────
  if (schemaNegocio && schemaNegocio.logo) {
    campos.logo_url = typeof schemaNegocio.logo === 'string' ? schemaNegocio.logo : (schemaNegocio.logo.url || '');
  } else {
    var logoRe = /<img[^>]+(?:class|id|alt)=["'][^"']*logo[^"']*["'][^>]*src=["']([^"']+)["']/i ||
                 /<img[^>]+src=["']([^"']*logo[^"']*)["']/i;
    var logoM = html.match(/<img[^>]+src=["']([^"']*)["'][^>]*(?:class|id|alt)=["'][^"']*logo[^"']*["']/i) ||
                html.match(/<img[^>]+(?:class|id|alt)=["'][^"']*logo[^"']*["'][^>]*src=["']([^"']*)["']/i) ||
                html.match(/<img[^>]+src=["']([^"']*(?:logo|brand)[^"']*)["']/i);
    if (logoM) campos.logo_url = logoM[1];
  }
  if (schemaNegocio && schemaNegocio.image) {
    campos.foto_url = typeof schemaNegocio.image === 'string' ? schemaNegocio.image : (schemaNegocio.image.url || '');
  }
  if (!campos.foto_url && campos.og_imagen) campos.foto_url = campos.og_imagen;

  // ── CONTACTO ─────────────────────────────────────────────────────────────────
  // Telefono(s)
  var telefonos = [];
  // Schema.org
  if (schemaNegocio && schemaNegocio.telephone) telefonos.push(schemaNegocio.telephone);
  // href="tel:..."
  var telRe = /href=["']tel:([+\d\s\-().]+)["']/gi; var telM;
  while ((telM = telRe.exec(html)) !== null) { var tel = telM[1].replace(/\s/g,''); if (!telefonos.includes(tel)) telefonos.push(tel); }
  // Texto libre: +34 XXX, 6XX XXX XXX, 9XX XX XX XX
  var telTextRe = /(?<![a-z0-9@])(\+34\s?)?[6789]\d{2}[\s.\-]?\d{3}[\s.\-]?\d{3}(?!\d)/g; var tt;
  while ((tt = telTextRe.exec(html)) !== null) {
    var t = tt[0].replace(/<[^>]+>/g,'').replace(/\s+/g,'').trim();
    if (t.length >= 9 && !telefonos.find(function(x){return x.replace(/\s/g,'') === t.replace(/\s/g,'');})) telefonos.push(t);
  }
  if (telefonos[0]) campos.telefono   = telefonos[0];
  if (telefonos[1]) campos.telefono_2 = telefonos[1];

  // Email(s)
  var emails = [];
  if (schemaNegocio && schemaNegocio.email) emails.push(schemaNegocio.email);
  var emailRe = /href=["']mailto:([^"'?]+)["']/gi; var em;
  while ((em = emailRe.exec(html)) !== null) { if (!emails.includes(em[1])) emails.push(em[1]); }
  var emailTextRe = /\b([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})\b/g; var et;
  while ((et = emailTextRe.exec(html)) !== null) {
    var e = et[1]; if (!emails.includes(e) && !/\.(png|jpg|webp|gif|svg)$/i.test(e)) emails.push(e);
  }
  if (emails[0]) campos.email   = emails[0];
  if (emails[1]) campos.email_2 = emails[1];

  // Direccion
  if (schemaNegocio && schemaNegocio.address) {
    var addr = schemaNegocio.address;
    if (typeof addr === 'string') {
      campos.direccion = addr;
    } else {
      if (addr.streetAddress)   campos.direccion  = addr.streetAddress;
      if (addr.addressLocality) campos.ciudad      = addr.addressLocality;
      if (addr.addressRegion)   campos.provincia   = addr.addressRegion;
      if (addr.postalCode)      campos.cp          = addr.postalCode;
      if (addr.addressCountry)  campos.pais        = addr.addressCountry;
    }
  }
  // Horario
  if (schemaNegocio && schemaNegocio.openingHours) {
    campos.horario = Array.isArray(schemaNegocio.openingHours) ? schemaNegocio.openingHours.join(', ') : schemaNegocio.openingHours;
  } else {
    var horarioRe = /<[^>]*>([^<]*(?:lunes|martes|miercoles|lun|mar|mie|jue|vie|sab|dom)[^<]*\d{1,2}:\d{2}[^<]*)<\/[^>]*>/gi;
    var hm; var horarioTextos = [];
    while ((hm = horarioRe.exec(html)) !== null && horarioTextos.length < 3) {
      var ht = st(hm[1]);
      if (ht.length < 100) horarioTextos.push(ht);
    }
    if (horarioTextos.length > 0) campos.horario = horarioTextos.join(' | ');
  }

  // ── REDES SOCIALES ───────────────────────────────────────────────────────────
  var redes = {
    facebook:  /(?:facebook\.com\/(?!sharer|share|tr\b)[a-zA-Z0-9@._\-/]+)/i,
    instagram: /(?:instagram\.com\/[a-zA-Z0-9@._\-/]+)/i,
    twitter:   /(?:twitter\.com\/[a-zA-Z0-9@._\-]+|x\.com\/[a-zA-Z0-9@._\-]+)/i,
    linkedin:  /(?:linkedin\.com\/(?:company|in)\/[a-zA-Z0-9@._\-/]+)/i,
    youtube:   /(?:youtube\.com\/(?:channel|c|user|@)[a-zA-Z0-9@._\-/]+)/i,
    tiktok:    /(?:tiktok\.com\/@[a-zA-Z0-9@._\-/]+)/i,
    pinterest: /(?:pinterest\.(?:es|com)\/[a-zA-Z0-9@._\-/]+)/i,
    whatsapp:  /(?:wa\.me\/[0-9+]+|api\.whatsapp\.com\/send[^"']+)/i,
  };
  var hrefRe = /href=["']([^"']+)["']/gi; var hm2;
  while ((hm2 = hrefRe.exec(html)) !== null) {
    var href = hm2[1];
    for (var red in redes) {
      if (!campos[red] && redes[red].test(href)) {
        campos[red] = href.startsWith('http') ? href : 'https://' + href;
      }
    }
  }
  // Schema.org sameAs
  if (schemaNegocio && Array.isArray(schemaNegocio.sameAs)) {
    schemaNegocio.sameAs.forEach(function(sa) {
      for (var red in redes) {
        if (!campos[red] && redes[red].test(sa)) campos[red] = sa;
      }
    });
  }

  // ── LINKS IMPORTANTES ────────────────────────────────────────────────────────
  var linksImportantes = [];
  var ctaKeywords = /(?:catalogo|catalog|tienda|shop|store|reserva|reservar|book|comprar|buy|pedir|encargar|menu|carta|precios|tarifa|contacto|contact|suscrib)/i;
  var aRe = /<a[^>]+href=["']([^"'#][^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi; var am;
  while ((am = aRe.exec(html)) !== null) {
    var href = am[1], texto = st(am[2]).replace(/\s+/g,' ').trim();
    if (!href || href.startsWith('javascript') || href.startsWith('tel:') || href.startsWith('mailto:')) continue;
    if (ctaKeywords.test(href) || ctaKeywords.test(texto)) {
      var fullHref = href.startsWith('http') ? href : (urlBase.replace(/\/$/, '') + (href.startsWith('/') ? '' : '/') + href);
      linksImportantes.push({ texto: texto.substring(0, 60), url: fullHref.substring(0, 120), tipo: clasificarLink(href, texto) });
    }
  }
  // Deduplicar y asignar campos
  var seen = new Set();
  linksImportantes = linksImportantes.filter(function(l) {
    if (seen.has(l.url)) return false; seen.add(l.url); return true;
  });
  campos._links_importantes = linksImportantes;
  var linkCatalogo = linksImportantes.find(function(l) { return l.tipo === 'catalogo'; });
  var linkReservas = linksImportantes.find(function(l) { return l.tipo === 'reservas'; });
  var linkTienda   = linksImportantes.find(function(l) { return l.tipo === 'tienda'; });
  var linkCTA      = primero(linksImportantes);
  if (linkCatalogo) campos.catalogo = linkCatalogo.url;
  if (linkReservas) campos.reservas = linkReservas.url;
  if (linkTienda)   campos.tienda   = linkTienda.url;
  if (linkCTA)      { campos.cta_principal = linkCTA.texto; campos.cta_url = linkCTA.url; }

  // ── PRECIOS ──────────────────────────────────────────────────────────────────
  var precioRe = /(?:desde|from|price|precio)[^0-9€$£]*([0-9]+(?:[.,][0-9]{1,2})?)\s*(?:€|\$|£|EUR)/gi; var prm;
  var precios = [];
  while ((prm = precioRe.exec(html)) !== null) { precios.push(parseFloat(prm[1].replace(',', '.'))); }
  if (precios.length > 0) campos.precio_desde = Math.min.apply(null, precios);

  // ── SCHEMA tipo ──────────────────────────────────────────────────────────────
  if (schemaNegocio) campos.schema_tipo = schemaNegocio['@type'];

  // ── SERVICIOS / PRODUCTOS ────────────────────────────────────────────────────
  var h2Re = /<h[23][^>]*>([\s\S]*?)<\/h[23]>/gi; var hm3; var headings = [];
  while ((hm3 = h2Re.exec(html)) !== null) {
    var t = st(hm3[1]).trim();
    if (t.length > 2 && t.length < 80) headings.push(t);
  }
  if (headings.length > 0) campos.servicios = headings.slice(0, 10);

  // ── ETIQUETAS ────────────────────────────────────────────────────────────────
  var etKeywords = meta(html, 'keywords');
  if (etKeywords) campos.etiquetas = etKeywords.split(/[,;]/).map(function(k){return k.trim();}).filter(Boolean);

  return campos;
}

// ── Detectar subpaginas clave en el HTML ──────────────────────────────────────
function detectarSubpaginas(html, urlBase) {
  var host = '';
  try { host = new URL(urlBase).origin; } catch(_) { return []; }

  var subpaginas = [];
  var seen = new Set();
  var aRe = /href=["']([^"'#?][^"']*)["']/gi; var am;

  while ((am = aRe.exec(html)) !== null) {
    var href = am[1].trim();
    // Convertir relativas a absolutas
    var full = '';
    if (href.startsWith('http')) {
      full = href;
    } else if (href.startsWith('/')) {
      full = host + href;
    } else {
      continue;
    }
    // Solo del mismo dominio
    if (!full.startsWith(host)) continue;
    // Limpiar trailing slash para deduplicar
    var key = full.replace(/\/$/, '').toLowerCase();
    if (seen.has(key) || key === urlBase.replace(/\/$/, '').toLowerCase()) continue;
    seen.add(key);

    // Solo las que parezcan paginas clave
    if (SUBPAGINAS_KEYWORDS.test(full)) {
      var tipo = clasificarSubpagina(full);
      subpaginas.push({ url: full, tipo: tipo });
    }
  }

  // Prioridad: contacto > sobre > servicios > catalogo > resto
  var orden = ['contacto', 'sobre', 'servicios', 'precios', 'catalogo', 'tienda', 'otro'];
  subpaginas.sort(function(a, b) {
    return orden.indexOf(a.tipo) - orden.indexOf(b.tipo);
  });

  // Maximo 8 subpaginas para no tardar demasiado
  return subpaginas.slice(0, 8);
}

function clasificarSubpagina(url) {
  if (/contacto?|contact/i.test(url))        return 'contacto';
  if (/sobre|about|nosotros|historia|quienes?/i.test(url)) return 'sobre';
  if (/servicios?|services/i.test(url))      return 'servicios';
  if (/precios?|tarifas?/i.test(url))        return 'precios';
  if (/catalogo|catalog|coleccion/i.test(url)) return 'catalogo';
  if (/tienda|shop|store/i.test(url))        return 'tienda';
  return 'otro';
}

// ── Merge de campos: el segundo llena los huecos del primero ──────────────────
function mergeCampos(base, extra) {
  var resultado = Object.assign({}, base);
  for (var k in extra) {
    if (k.startsWith('_')) continue;
    var valBase  = resultado[k];
    var valExtra = extra[k];
    if (valExtra === undefined || valExtra === '' || valExtra === null) continue;
    if (Array.isArray(valExtra) && valExtra.length === 0) continue;

    if (!valBase || valBase === '') {
      // Campo vacio en base → tomar del extra
      resultado[k] = valExtra;
    } else if (k === 'bio' && typeof valExtra === 'string' && valExtra.length > (valBase || '').length) {
      // Bio mas larga en subpagina → preferir la mas larga
      resultado[k] = valExtra;
    } else if (k === 'servicios' && Array.isArray(valExtra) && valExtra.length > (Array.isArray(valBase) ? valBase.length : 0)) {
      resultado[k] = valExtra;
    }
    // Para el resto: si ya tiene dato en base, lo mantiene (la home tiene prioridad)
  }
  // Fusionar links importantes
  if (extra._links_importantes && base._links_importantes) {
    var allLinks = (base._links_importantes || []).concat(extra._links_importantes || []);
    var seenLinks = new Set();
    resultado._links_importantes = allLinks.filter(function(l) {
      if (seenLinks.has(l.url)) return false; seenLinks.add(l.url); return true;
    });
  }
  return resultado;
}

function clasificarLink(href, texto) {
  if (/catalogo|catalog|coleccion|collection|libros|books|productos|products/i.test(href + texto)) return 'catalogo';
  if (/reserva|reservar|book|agenda|cita|appointment/i.test(href + texto)) return 'reservas';
  if (/tienda|shop|store|comprar|buy|carrito|cart/i.test(href + texto)) return 'tienda';
  if (/menu|carta|platos/i.test(href + texto)) return 'menu';
  if (/contact/i.test(href + texto)) return 'contacto';
  return 'otro';
}

// ── MOSTRAR INFORME ───────────────────────────────────────────────────────────
function mostrarInforme(campos, url, fuente) {
  console.log('\n' + '='.repeat(72));
  console.log(' WEB → FLUIX | ' + url);
  console.log(' Fuente: ' + fuente);
  console.log('='.repeat(72));

  var grupos = [
    { titulo: 'IDENTIDAD', keys: ['nombre', 'descripcion', 'bio', 'logo_url', 'foto_url', 'schema_tipo'] },
    { titulo: 'CONTACTO',  keys: ['telefono', 'telefono_2', 'email', 'email_2', 'web', 'direccion', 'ciudad', 'provincia', 'cp', 'pais', 'horario'] },
    { titulo: 'REDES SOCIALES', keys: ['facebook', 'instagram', 'twitter', 'linkedin', 'youtube', 'tiktok', 'pinterest', 'whatsapp'] },
    { titulo: 'LINKS Y CTAs', keys: ['catalogo', 'reservas', 'tienda', 'cta_principal', 'cta_url', 'precio_desde'] },
    { titulo: 'CONTENIDO', keys: ['etiquetas', 'servicios', 'meta_descripcion', 'og_imagen'] },
  ];

  var totalCampos = 0;
  grupos.forEach(function(g) {
    var tieneAlgo = g.keys.some(function(k) { return campos[k] !== undefined && campos[k] !== '' && (Array.isArray(campos[k]) ? campos[k].length > 0 : true); });
    if (!tieneAlgo) return;
    console.log('\n  ' + g.titulo);
    console.log('  ' + '─'.repeat(60));
    g.keys.forEach(function(k) {
      var v = campos[k];
      if (v === undefined || v === '' || v === null) {
        console.log('  ' + k.padEnd(18) + ' (no detectado)');
        return;
      }
      totalCampos++;
      var fluixLabel = CAMPOS_FLUIX[k] ? CAMPOS_FLUIX[k].label : k;
      var fluixTipo  = CAMPOS_FLUIX[k] ? CAMPOS_FLUIX[k].tipo  : '?';
      if (Array.isArray(v)) {
        console.log('  ' + k.padEnd(18) + ' [' + fluixTipo + '] (' + v.length + ' items): ' + v.slice(0, 4).join(' | ') + (v.length > 4 ? '...' : ''));
      } else {
        var display = String(v);
        var len = display.length;
        if (len > 200) display = display.substring(0, 200) + '...';
        console.log('  ' + k.padEnd(18) + ' [' + fluixTipo + '] (' + len + 'c) "' + display + '"');
      }
    });
  });

  // Links importantes detectados
  if (campos._links_importantes && campos._links_importantes.length > 0) {
    console.log('\n  LINKS IMPORTANTES DETECTADOS (' + campos._links_importantes.length + ')');
    console.log('  ' + '─'.repeat(60));
    campos._links_importantes.forEach(function(l) {
      console.log('  [' + l.tipo.padEnd(9) + '] "' + l.texto.substring(0, 30).padEnd(30) + '" → ' + l.url.substring(0, 55));
    });
  }

  console.log('\n' + '='.repeat(72));
  console.log(' RESUMEN: ' + totalCampos + ' campos detectados de ' + Object.keys(CAMPOS_FLUIX).length + ' posibles');
  var faltantes = Object.keys(CAMPOS_FLUIX).filter(function(k) { return !campos[k] && !k.startsWith('_'); });
  if (faltantes.length > 0) console.log(' Sin datos: ' + faltantes.join(', '));
  console.log('='.repeat(72) + '\n');
}

// ── GENERAR OBJETO FLUIX ──────────────────────────────────────────────────────
function generarObjetoFluix(campos, url) {
  var obj = { _fuente_url: url, _fecha_extraccion: new Date().toISOString() };
  for (var k in CAMPOS_FLUIX) {
    if (campos[k] !== undefined && campos[k] !== '') obj[k] = campos[k];
  }
  return obj;
}

// ── MAIN ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n[1/1] Pagina principal: ' + URL_ARG);
  var res = await fetchConWayback(URL_ARG);

  if (!res.html || res.html.length < 500) {
    console.log('Error: no se pudo obtener contenido de ' + URL_ARG);
    process.exit(1);
  }

  var campos = extraerCampos(res.html, URL_ARG);
  var paginas_analizadas = [{ url: URL_ARG, tipo: 'home', fuente: res.fuente }];

  // ── Subpaginas ──────────────────────────────────────────────────────────────
  if (SUBPAGINAS) {
    var subpags = detectarSubpaginas(res.html, URL_ARG);
    if (subpags.length > 0) {
      console.log('\nSubpaginas detectadas: ' + subpags.length);
      subpags.forEach(function(sp) { console.log('  [' + sp.tipo + '] ' + sp.url); });
      console.log('');

      for (var si = 0; si < subpags.length; si++) {
        var sp = subpags[si];
        process.stdout.write('[' + (si+2) + '/' + (subpags.length+1) + '] ' + sp.tipo + ': ' + sp.url + ' ...');
        var spRes = await fetchConWayback(sp.url);
        if (!spRes.html || spRes.html.length < 200) { console.log(' sin datos'); continue; }
        var spCampos = extraerCampos(spRes.html, sp.url);
        var antesVacios = Object.keys(CAMPOS_FLUIX).filter(function(k) { return !campos[k]; }).length;
        campos = mergeCampos(campos, spCampos);
        var despuesVacios = Object.keys(CAMPOS_FLUIX).filter(function(k) { return !campos[k]; }).length;
        var nuevos = antesVacios - despuesVacios;
        console.log(' ' + (nuevos > 0 ? '+' + nuevos + ' campos nuevos' : 'sin campos nuevos') + ' [' + spRes.fuente + ']');
        paginas_analizadas.push({ url: sp.url, tipo: sp.tipo, fuente: spRes.fuente, campos_nuevos: nuevos });
      }
      console.log('');
    } else {
      console.log('No se detectaron subpaginas relevantes.\n');
    }
  }

  mostrarInforme(campos, URL_ARG, paginas_analizadas.map(function(p) { return p.tipo; }).join(' + '));

  if (GUARDAR || PARA_FLUIX) {
    var outRaw   = path.join(__dirname, 'web_a_fluix_resultado.json');
    var outFluix = path.join(__dirname, 'web_a_fluix_campos_fluix.json');

    if (GUARDAR) {
      fs.writeFileSync(outRaw, JSON.stringify({ url: URL_ARG, fuente: res.fuente, campos: campos }, null, 2), 'utf8');
      console.log('JSON completo guardado: ' + outRaw);
    }
    if (PARA_FLUIX) {
      var fluixObj = generarObjetoFluix(campos, URL_ARG);
      fs.writeFileSync(outFluix, JSON.stringify(fluixObj, null, 2), 'utf8');
      console.log('Objeto Fluix guardado:  ' + outFluix);
    }
  }
}

main().catch(function(e) { console.error('Error:', e.message || e); process.exit(1); });
