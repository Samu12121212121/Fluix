'use strict';

/**
 * master.js  —  Script maestro de extraccion web para Fluix
 * ─────────────────────────────────────────────────────────────────────────────
 * Orquesta el pipeline completo para cualquier web de cliente:
 *   1. Extrae datos de la URL principal (y subpaginas si se indica)
 *   2. Si es un listado de autores Nazari, descarga cada pagina individual
 *   3. Registra CADA error con contexto, causa y sugerencia de solucion
 *   4. Genera tres archivos de salida:
 *        master_datos.json    → todos los datos extraidos
 *        master_errores.json  → todos los errores con detalle
 *        master_informe.txt   → informe legible completo
 *
 * Modos:
 *   node scripts/master.js <URL>                         ← pagina simple
 *   node scripts/master.js <URL> --subpaginas            ← + subpaginas internas
 *   node scripts/master.js <URL> --completo              ← listado + individuales
 *   node scripts/master.js --autores-nazari              ← todos los autores Nazari
 *   node scripts/master.js --autores-nazari --aplicar    ← + actualiza Firestore
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https  = require('https');
const http   = require('http');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const URL_ARG         = process.argv.find(function(a) { return a.startsWith('http'); });
const CON_SUBPAGINAS  = process.argv.includes('--subpaginas');
const CON_COMPLETO    = process.argv.includes('--completo');
const AUTORES_NAZARI  = process.argv.includes('--autores-nazari');
const APLICAR_FS      = process.argv.includes('--aplicar');
const DELAY           = 1100;

if (!URL_ARG && !AUTORES_NAZARI) {
  console.log('\nUso: node scripts/master.js <URL> [opciones]');
  console.log('     node scripts/master.js --autores-nazari [--aplicar]\n');
  console.log('  <URL>               analiza una pagina web');
  console.log('  --subpaginas        tambien sigue links internos clave');
  console.log('  --completo          si es listado, descarga cada pagina individual');
  console.log('  --autores-nazari    pipeline completo de autores Nazari');
  console.log('  --aplicar           (con --autores-nazari) actualiza Firestore\n');
  process.exit(0);
}

// ── Registro de errores ────────────────────────────────────────────────────────
var ERRORES = [];
var WARNINGS = [];

function registrarError(tipo, url, campo, detalle, sugerencia) {
  ERRORES.push({
    timestamp: new Date().toISOString(),
    tipo: tipo,
    url: url || '',
    campo: campo || '',
    detalle: detalle || '',
    sugerencia: sugerencia || '',
  });
}

function registrarWarning(url, campo, detalle) {
  WARNINGS.push({ timestamp: new Date().toISOString(), url: url || '', campo: campo || '', detalle: detalle || '' });
}

var TIPOS_ERROR = {
  HTTP_ERROR:        'Error HTTP (servidor no accesible)',
  CLOUDFLARE_BLOCK:  'Bloqueado por Cloudflare / captcha',
  TIMEOUT:           'Timeout — el servidor no respondio',
  SIN_CONTENIDO:     'Pagina vacia o sin HTML util',
  SIN_WAYBACK:       'URL bloqueada y sin copia en Wayback Machine',
  CAMPO_NO_EXTRAIDO: 'Campo no detectado en la pagina',
  PARSE_ERROR:       'Error al parsear el HTML',
  FIRESTORE_ERROR:   'Error al escribir en Firestore',
  REDIRECT_LOOP:     'Demasiadas redirecciones',
};

// ── HTTP fetch ─────────────────────────────────────────────────────────────────
function fetchHtml(url, hops) {
  hops = hops === undefined ? 4 : hops;
  if (hops <= 0) { registrarError(TIPOS_ERROR.REDIRECT_LOOP, url, '', 'Demasiadas redirecciones', 'Verificar la URL manualmente'); return Promise.resolve({ status: 0, html: '', error: 'redirect_loop' }); }
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, { headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html', 'Accept-Language': 'es-ES,es;q=0.9',
      }}, function(res) {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          var loc = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
          res.resume(); return fetchHtml(loc, hops - 1).then(resolve);
        }
        var raw = ''; res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() { resolve({ status: res.statusCode, html: raw }); });
        res.on('error', function(e) { resolve({ status: 0, html: '', error: e.message }); });
      });
      req.on('error', function(e) { resolve({ status: 0, html: '', error: e.message }); });
      req.setTimeout(18000, function() { req.destroy(); resolve({ status: 0, html: '', error: 'timeout' }); });
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

async function fetchConFallback(urlOriginal) {
  var r = await fetchHtml(urlOriginal);

  // Exito directo
  if (r.status >= 200 && r.status < 300 && r.html && r.html.length > 2000 && !r.html.includes('sgcaptcha')) {
    return { html: r.html, fuente: 'directo', ok: true };
  }

  // Diagnosticar el tipo de fallo
  var motivo = '';
  if (r.error === 'timeout') {
    motivo = TIPOS_ERROR.TIMEOUT;
    registrarError(TIPOS_ERROR.TIMEOUT, urlOriginal, '', 'El servidor tardo mas de 18s', 'Probar en otro momento o verificar que la web esta activa');
  } else if (r.html && r.html.includes('sgcaptcha')) {
    motivo = TIPOS_ERROR.CLOUDFLARE_BLOCK;
    registrarError(TIPOS_ERROR.CLOUDFLARE_BLOCK, urlOriginal, '', 'Captcha sgcaptcha detectado', 'Usando Wayback Machine como alternativa');
  } else if (r.status >= 400) {
    motivo = TIPOS_ERROR.HTTP_ERROR;
    registrarError(TIPOS_ERROR.HTTP_ERROR, urlOriginal, '', 'HTTP ' + r.status, r.status === 404 ? 'Verificar que la URL existe' : 'Problema temporal del servidor');
  } else if (!r.html || r.html.length < 500) {
    motivo = TIPOS_ERROR.SIN_CONTENIDO;
    registrarError(TIPOS_ERROR.SIN_CONTENIDO, urlOriginal, '', 'HTML recibido: ' + (r.html||'').length + 'c', 'Puede ser pagina protegida o requiere JavaScript');
  }

  // Intentar Wayback Machine
  var limpio = urlOriginal.replace(/^https?:\/\/(www\.)?/, '');
  var api = await fetchJson('https://archive.org/wayback/available?url=' + limpio);
  var archiveUrl = api.data && api.data.archived_snapshots && api.data.archived_snapshots.closest && api.data.archived_snapshots.closest.url;

  if (!archiveUrl) {
    registrarError(TIPOS_ERROR.SIN_WAYBACK, urlOriginal, '', motivo || 'Sin copia archivada', 'Acceder manualmente e introducir los datos en Fluix');
    return { html: r.html || '', fuente: 'sin_wayback', ok: false };
  }

  var arch = await fetchHtml(archiveUrl);
  if (!arch.html || arch.html.length < 500) {
    registrarError(TIPOS_ERROR.SIN_CONTENIDO, urlOriginal, '', 'Wayback Machine devolvio HTML vacio', 'La pagina puede no tener copia util archivada');
    return { html: '', fuente: 'wayback_error', ok: false };
  }

  var html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');

  var ts = (api.data.archived_snapshots.closest.timestamp || '').substring(0, 8);
  return { html: html, fuente: 'wayback:' + ts, ok: true };
}

function st(h) {
  return (h||'').replace(/<[^>]+>/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#\d+;/g,' ').replace(/\s+/g,' ').trim();
}
function sleep(ms) { return new Promise(function(r) { setTimeout(r, ms); }); }

// ── Extraer datos de autor individual ─────────────────────────────────────────
function extraerAutor(html, url) {
  var nombre = '', bio = '', rol = '', etiquetas = [];

  var titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (titleM) {
    var titulo = st(titleM[1]).split('|')[0].trim();
    var rolM = titulo.match(/^(Autor\/a|Autora?|Ilustrador\/a|Ilustradore?s?|Editor\/a|Editore?s?|Traductor\/a|Traductore?s?|Prologuista|Coordinador\/a)\s+/i);
    if (rolM) { rol = rolM[1]; nombre = titulo.slice(rolM[0].length).trim(); }
    else { nombre = titulo; }
  }
  if (!nombre) { var h1 = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i); if (h1) nombre = st(h1[1]).trim(); }

  var wpbRe = /<div[^>]*class="[^"]*\bwpb_text_column\b[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi;
  var wm; var candidatos = [];
  while ((wm = wpbRe.exec(html)) !== null) {
    var t = st(wm[1]).replace(/\s([.,;:])/g,'$1').replace(/\s+/g,' ').trim();
    if (t.length >= 60 && !/cookie|aviso|newsletter|carrito|copyright/i.test(t)) candidatos.push(t);
  }
  if (candidatos.length > 0) bio = candidatos.sort(function(a,b){return b.length-a.length;})[0];

  var tgRe = /<a[^>]+href="[^"]*\/team-group\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; var tgm;
  var seenEt = new Set();
  while ((tgm = tgRe.exec(html)) !== null) {
    var et = st(tgm[1]).trim();
    if (et.length > 0 && et.length < 60 && !seenEt.has(et.toLowerCase())) { seenEt.add(et.toLowerCase()); etiquetas.push(et); }
  }

  // Registrar warnings por campos vacios
  if (!nombre)           registrarWarning(url, 'nombre',    'No se encontro h1 ni titulo parseable');
  if (!bio)              registrarWarning(url, 'bio',       'No se encontro bloque wpb_text_column con texto sustancial');
  if (!rol)              registrarWarning(url, 'rol',       'Titulo no contiene prefijo de rol (Autor/a, etc.)');
  if (etiquetas.length === 0) registrarWarning(url, 'etiquetas', 'No se encontraron links /team-group/ en la pagina');

  return { nombre: nombre, rol: rol, bio: bio, etiquetas: etiquetas, bioChars: bio.length };
}

// ── Extraer URLs de autores de una pagina de listado ──────────────────────────
function extraerUrlsListado(html) {
  var urls = [];
  var re = /href=["'](https?:\/\/[^"']*\/team\/[^"'/][^"']+\/)["']/gi; var m;
  var seen = new Set();
  while ((m = re.exec(html)) !== null) { if (!seen.has(m[1])) { seen.add(m[1]); urls.push(m[1]); } }
  return urls;
}

// ── Pipeline autores Nazari ────────────────────────────────────────────────────
const CATEGORIAS_NAZARI = [
  { url: 'https://www.editorialnazari.com/team_group/autores/',       rol: 'Autor/a' },
  { url: 'https://www.editorialnazari.com/team_group/ilustradores/',  rol: 'Ilustrador/a' },
  { url: 'https://www.editorialnazari.com/team_group/traductores/',   rol: 'Traductor/a' },
  { url: 'https://www.editorialnazari.com/team_group/editores/',      rol: 'Editor/a' },
  { url: 'https://www.editorialnazari.com/team_group/coordinadores/', rol: 'Coordinador/a' },
  { url: 'https://www.editorialnazari.com/team_group/prologuistas/',  rol: 'Prologuista' },
];

async function pipelineAutoresNazari() {
  console.log('\n PIPELINE AUTORES NAZARI — extraccion completa\n');

  // Fase 1: descubrir todos los URLs por categoria
  var todosAutores = [];
  var urlsVistas = new Set();

  for (var ci = 0; ci < CATEGORIAS_NAZARI.length; ci++) {
    var cat = CATEGORIAS_NAZARI[ci];
    process.stdout.write('\n[Listado] ' + cat.rol + ' — ' + cat.url + ' ...');
    var res = await fetchConFallback(cat.url);
    if (!res.ok || !res.html) { console.log(' FALLO'); continue; }

    var urls = extraerUrlsListado(res.html);
    console.log(' ' + urls.length + ' autores [' + res.fuente + ']');

    // Paginacion
    var pagRe = /href=["'][^"']*\/page\/(\d+)\/["']/gi; var pm2; var maxPag = 1;
    while ((pm2 = pagRe.exec(res.html)) !== null) { maxPag = Math.max(maxPag, parseInt(pm2[1])); }
    for (var pg = 2; pg <= maxPag; pg++) {
      var pgUrl = cat.url.replace(/\/?$/, '/') + 'page/' + pg + '/';
      await sleep(DELAY);
      var pgRes = await fetchConFallback(pgUrl);
      if (!pgRes.ok) continue;
      var pgUrls = extraerUrlsListado(pgRes.html);
      urls = urls.concat(pgUrls);
      console.log('    pagina ' + pg + ': +' + pgUrls.length + ' (total: ' + urls.length + ')');
    }

    for (var ui = 0; ui < urls.length; ui++) {
      if (!urlsVistas.has(urls[ui])) { urlsVistas.add(urls[ui]); todosAutores.push({ url: urls[ui], rol: cat.rol }); }
    }
    await sleep(DELAY);
  }

  console.log('\n Total URLs descubiertas: ' + todosAutores.length);

  // Fase 2: descargar cada pagina individual
  console.log('\n Descargando paginas individuales...\n');
  var ok = 0, sinBio = 0, errWeb = 0;

  for (var ai = 0; ai < todosAutores.length; ai++) {
    var autor = todosAutores[ai];
    var slug = autor.url.replace(/.*\/team\//, '').replace(/\/$/, '');
    process.stdout.write('\r [' + String(ai+1).padStart(3) + '/' + todosAutores.length + '] ' +
      slug.substring(0, 32).padEnd(32) + '  ok:' + ok + ' sinBio:' + sinBio + ' err:' + errWeb);

    await sleep(DELAY);
    var ar = await fetchConFallback(autor.url);

    if (!ar.ok || !ar.html) { errWeb++; autor.error = ar.fuente; continue; }

    var datos = extraerAutor(ar.html, autor.url);
    autor.nombre    = datos.nombre;
    autor.rol       = datos.rol || autor.rol;  // si la pagina tiene rol mas especifico, usarlo
    autor.bio       = datos.bio;
    autor.etiquetas = datos.etiquetas;
    autor.bioChars  = datos.bioChars;
    autor.fuente    = ar.fuente;
    if (datos.bio) ok++; else sinBio++;
  }
  console.log('\n');

  // Ordenar alfabeticamente
  todosAutores.sort(function(a, b) {
    var na = (a.nombre||a.url).toLowerCase().normalize('NFD').replace(/[^\x00-\x7F]/g,'');
    var nb = (b.nombre||b.url).toLowerCase().normalize('NFD').replace(/[^\x00-\x7F]/g,'');
    return na.localeCompare(nb, 'es');
  });
  todosAutores.forEach(function(a, i) { a.posicion = i + 1; });

  return todosAutores;
}

// ── Generar informe ────────────────────────────────────────────────────────────
function generarInforme(datos, modoDescripcion) {
  var lineas = [];
  lineas.push('INFORME MASTER — ' + new Date().toLocaleString('es-ES'));
  lineas.push('Modo: ' + modoDescripcion);
  lineas.push('='.repeat(72));
  lineas.push('');

  // Resumen general
  var totalAutores = Array.isArray(datos) ? datos.length : 1;
  var conBio       = Array.isArray(datos) ? datos.filter(function(d){return d.bio;}).length : (datos.bio ? 1 : 0);
  var conRol       = Array.isArray(datos) ? datos.filter(function(d){return d.rol;}).length : (datos.rol ? 1 : 0);
  var conEt        = Array.isArray(datos) ? datos.filter(function(d){return d.etiquetas && d.etiquetas.length;}).length : 0;
  var conError     = Array.isArray(datos) ? datos.filter(function(d){return d.error;}).length : 0;

  lineas.push('RESUMEN:');
  lineas.push('  Total procesados: ' + totalAutores);
  if (Array.isArray(datos)) {
    lineas.push('  Con bio:          ' + conBio + ' (' + Math.round(conBio/totalAutores*100) + '%)');
    lineas.push('  Con rol:          ' + conRol + ' (' + Math.round(conRol/totalAutores*100) + '%)');
    lineas.push('  Con etiquetas:    ' + conEt  + ' (' + Math.round(conEt/totalAutores*100)  + '%)');
    lineas.push('  Con error:        ' + conError);
  }
  lineas.push('  Errores totales:  ' + ERRORES.length);
  lineas.push('  Warnings totales: ' + WARNINGS.length);
  lineas.push('');

  // Errores por tipo
  if (ERRORES.length > 0) {
    lineas.push('ERRORES (' + ERRORES.length + '):');
    lineas.push('-'.repeat(72));
    var porTipo = {};
    ERRORES.forEach(function(e) { porTipo[e.tipo] = (porTipo[e.tipo] || 0) + 1; });
    Object.keys(porTipo).forEach(function(t) { lineas.push('  [' + porTipo[t] + 'x] ' + t); });
    lineas.push('');
    lineas.push('DETALLE DE ERRORES:');
    ERRORES.forEach(function(e, i) {
      lineas.push('');
      lineas.push('  ERROR #' + (i+1) + ' — ' + e.tipo);
      lineas.push('  URL:       ' + (e.url || 'N/A'));
      if (e.campo)      lineas.push('  Campo:     ' + e.campo);
      if (e.detalle)    lineas.push('  Detalle:   ' + e.detalle);
      if (e.sugerencia) lineas.push('  Solucion:  ' + e.sugerencia);
    });
    lineas.push('');
  } else {
    lineas.push('ERRORES: ninguno');
    lineas.push('');
  }

  // Warnings agrupados por campo
  if (WARNINGS.length > 0) {
    lineas.push('WARNINGS — Campos no detectados (' + WARNINGS.length + '):');
    lineas.push('-'.repeat(72));
    var porCampo = {};
    WARNINGS.forEach(function(w) { (porCampo[w.campo] = porCampo[w.campo] || []).push(w.url); });
    Object.keys(porCampo).sort().forEach(function(campo) {
      var urls = porCampo[campo];
      lineas.push('  [' + campo + '] sin dato en ' + urls.length + ' paginas:');
      urls.slice(0, 5).forEach(function(u) { lineas.push('    • ' + u); });
      if (urls.length > 5) lineas.push('    ... y ' + (urls.length - 5) + ' mas');
    });
    lineas.push('');
  }

  // URLs con error de descarga
  if (Array.isArray(datos)) {
    var conErrorArr = datos.filter(function(d) { return d.error; });
    if (conErrorArr.length > 0) {
      lineas.push('PAGINAS NO DESCARGADAS (' + conErrorArr.length + '):');
      conErrorArr.forEach(function(d) { lineas.push('  • ' + d.url + ' [' + d.error + ']'); });
      lineas.push('');
    }
  }

  lineas.push('='.repeat(72));
  lineas.push('FIN DEL INFORME');
  return lineas.join('\n');
}

// ── Guardar resultados ─────────────────────────────────────────────────────────
function guardarResultados(datos, informe, modo) {
  var ts = new Date().toISOString().slice(0, 19).replace(/[T:]/g, '-');
  var baseName = 'master-' + ts;
  var dirOut = __dirname;

  var datosFile   = path.join(dirOut, baseName + '-datos.json');
  var erroresFile = path.join(dirOut, baseName + '-errores.json');
  var informeFile = path.join(dirOut, baseName + '-informe.txt');

  fs.writeFileSync(datosFile,   JSON.stringify({ fecha: new Date().toISOString(), modo: modo, datos: datos }, null, 2), 'utf8');
  fs.writeFileSync(erroresFile, JSON.stringify({ fecha: new Date().toISOString(), errores: ERRORES, warnings: WARNINGS }, null, 2), 'utf8');
  fs.writeFileSync(informeFile, informe, 'utf8');

  console.log('\n Archivos generados:');
  console.log('   datos:    ' + datosFile);
  console.log('   errores:  ' + erroresFile);
  console.log('   informe:  ' + informeFile);
  return { datosFile, erroresFile, informeFile };
}

// ── MAIN ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '='.repeat(72));
  console.log(' MASTER — Pipeline de extraccion web para Fluix');
  console.log('='.repeat(72));

  var datos, modo;

  if (AUTORES_NAZARI) {
    modo = 'autores-nazari' + (APLICAR_FS ? ' + aplicar-firestore' : '');
    datos = await pipelineAutoresNazari();

    // Mostrar resumen rapido
    console.log('\n Primeros 8 en orden alfabetico:');
    datos.slice(0, 8).forEach(function(a) {
      console.log('  #' + String(a.posicion).padStart(3) + ' ' + (a.nombre||'?').padEnd(30) +
        ' rol: ' + (a.rol||'?').padEnd(14) +
        ' bio: ' + (a.bioChars ? a.bioChars + 'c' : '---') +
        ' tags: ' + (a.etiquetas ? a.etiquetas.length : 0));
    });

  } else {
    modo = 'url-simple' + (CON_SUBPAGINAS ? '+subpaginas' : '') + (CON_COMPLETO ? '+completo' : '');
    console.log('\n URL: ' + URL_ARG);
    var res = await fetchConFallback(URL_ARG);
    if (!res.ok || !res.html) { console.log('\n Error: no se pudo obtener contenido. Ver informe de errores.'); }
    else {
      var camposWeb = require('./web_a_fluix.js'); // solo si existe; si no, extraccion basica
    }
    // Extraccion basica de autor si parece una pagina /team/
    if (URL_ARG.includes('/team/')) {
      datos = extraerAutor(res.html || '', URL_ARG);
      datos.url = URL_ARG; datos.fuente = res.fuente;
    } else {
      datos = { url: URL_ARG, fuente: res.fuente || 'error', html_length: (res.html || '').length };
    }
  }

  // Generar y guardar informe
  var informe = generarInforme(datos, modo);
  console.log('\n' + '─'.repeat(72));
  console.log(informe);
  var archivos = guardarResultados(datos, informe, modo);

  // Si hay errores, mostrar resumen final destacado
  if (ERRORES.length > 0) {
    console.log('\n' + '!'.repeat(72));
    console.log(' ATENCION: ' + ERRORES.length + ' errores y ' + WARNINGS.length + ' warnings');
    console.log(' Ver informe completo: ' + archivos.informeFile);
    console.log('!'.repeat(72));
  } else {
    console.log('\n OK — sin errores criticos');
  }
}

main().catch(function(e) {
  registrarError('ERROR_CRITICO', URL_ARG || '', 'main', e.message || String(e), 'Revisar el script');
  var informe = generarInforme(null, 'error-critico');
  var informeFile = path.join(__dirname, 'master-error-critico.txt');
  fs.writeFileSync(informeFile, informe, 'utf8');
  console.error('\n ERROR CRITICO:', e.message || e);
  console.error(' Informe guardado en: ' + informeFile);
  process.exit(1);
});
