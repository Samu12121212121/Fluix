'use strict';

/**
 * inyectar_autor_prueba.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Prueba el pipeline completo en UN solo autor:
 *   1. Hace fetch a su página en editorialnazari.com/team/
 *   2. Extrae: nombre, rol, bio completa, etiquetas
 *   3. Muestra lo que encontraría
 *   4. Con --aplicar: lo inyecta/actualiza en Firestore
 *
 * Uso:
 *   cd functions
 *   node scripts/inyectar_autor_prueba.js                        ← solo muestra
 *   node scripts/inyectar_autor_prueba.js --aplicar              ← también guarda en Firestore
 *   node scripts/inyectar_autor_prueba.js --nombre "Ana García"  ← otro autor
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');
const os    = require('os');

const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE    = 'https://www.editorialnazari.com/team/';
const APLICAR = process.argv.includes('--aplicar');

// Nombre del autor a probar (puede sobreescribirse con --nombre "Nombre")
let NOMBRE_AUTOR = 'Óscar Borona';
const nombreIdx = process.argv.indexOf('--nombre');
if (nombreIdx !== -1 && process.argv[nombreIdx + 1]) {
  NOMBRE_AUTOR = process.argv[nombreIdx + 1];
}

// ── Firebase ───────────────────────────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
    return;
  }
  function getRefreshToken() {
    const candidates = [
      path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    ];
    for (const p of candidates) {
      try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); if (d?.tokens?.refresh_token) return d.tokens.refresh_token; } catch (_) {}
    }
    return null;
  }
  const rt = getRefreshToken();
  if (!rt) { console.error('❌ Sin credenciales Firebase. Necesita serviceAccountKey.json o firebase login.'); process.exit(1); }
  admin.initializeApp({
    credential: admin.credential.refreshToken({
      type: 'authorized_user',
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p',
      refresh_token: rt,
    }),
    projectId: 'planeaapp-4bea4',
  });
}

// ── Normalización ──────────────────────────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

function toSlug(nombre) {
  return norm(nombre)
    .replace(/[^a-z0-9\s-]/g, ' ')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function toDocSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ── HTTP fetch ─────────────────────────────────────────────────────────────────
function fetchHtml(url, hops) {
  hops = (hops === undefined) ? 4 : hops;
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Upgrade-Insecure-Requests': '1',
        }
      }, function(res) {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          var loc = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
          res.resume(); return fetchHtml(loc, hops - 1).then(resolve);
        }
        var raw = '';
        res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() { resolve({ status: res.statusCode, html: raw }); });
        res.on('error', function(e) { resolve({ status: res.statusCode, html: '', error: e.message }); });
      });
      req.on('error', function(e) { resolve({ status: 0, html: '', error: e.message }); });
      req.setTimeout(20000, function() { req.destroy(); resolve({ status: 0, html: '', error: 'timeout' }); });
    } catch(e) { resolve({ status: 0, html: '', error: e.message }); }
  });
}

// ── Fetch con fallback a Wayback Machine ──────────────────────────────────────
function fetchJson(url) {
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' } }, function(res) {
        var raw = ''; res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() { try { resolve({ status: res.statusCode, data: JSON.parse(raw) }); } catch(e) { resolve({ status: res.statusCode, data: null }); } });
      });
      req.on('error', function(e) { resolve({ status: 0, data: null }); });
      req.setTimeout(10000, function() { req.destroy(); resolve({ status: 0, data: null }); });
    } catch(e) { resolve({ status: 0, data: null }); }
  });
}

function isCloudflareBlocked(status, html) {
  if (!html || html.length < 3000) return true;
  return html.includes('sgcaptcha') || html.includes('cf-browser-verification') || html.includes('Checking your browser');
}

async function fetchConFallback(urlOriginal) {
  const direct = await fetchHtml(urlOriginal);
  const okDirect = direct.status >= 200 && direct.status < 300 && !isCloudflareBlocked(direct.status, direct.html);
  if (okDirect) return { html: direct.html, source: 'directo', status: direct.status };

  console.log('  [Cloudflare] Usando Wayback Machine como fallback...');
  const limpio = urlOriginal.replace(/^https?:\/\/(www\.)?/, '');
  const apiUrl = 'https://archive.org/wayback/available?url=' + limpio;
  const api = await fetchJson(apiUrl);
  const archiveUrl = api.data && api.data.archived_snapshots && api.data.archived_snapshots.closest && api.data.archived_snapshots.closest.url;

  if (!archiveUrl) {
    console.log('  [Wayback] No hay copia archivada para: ' + urlOriginal);
    return { html: '', source: 'sin_copia', status: 0 };
  }

  const ts = api.data.archived_snapshots.closest.timestamp || '';
  console.log('  [Wayback] Copia encontrada: ' + ts.substring(0, 8) + ' → ' + archiveUrl);
  const arch = await fetchHtml(archiveUrl);
  if (arch.status < 200 || arch.status >= 300) {
    console.log('  [Wayback] Error al obtener copia: HTTP ' + arch.status);
    return { html: '', source: 'wayback_error', status: arch.status };
  }

  // Quitar barra de herramientas del Wayback Machine
  var html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');

  return { html: html, source: 'wayback', archiveUrl: archiveUrl, timestamp: ts };
}

// ── HTML helpers ───────────────────────────────────────────────────────────────
function decodeEntities(s) {
  return s
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&#8217;|&#x2019;|&#8216;|&#x2018;/g, "'")
    .replace(/&#8220;|&#x201C;|&#8221;|&#x201D;/g, '"')
    .replace(/&#8230;|&#x2026;/g, '...').replace(/&#8212;|&#x2014;/g, '--')
    .replace(/&#8211;|&#x2013;/g, '-').replace(/&#160;|&nbsp;/g, ' ')
    .replace(/&#\d+;/g, ' ');
}
function stripTags(h) { return decodeEntities(h.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ')).trim(); }

function getContentZone(html) {
  // Tema propio de Nazari: post_content, page_content_wrap, wpb_text_column
  let m = html.match(/<div[^>]*class="[^"]*\bpost_content\b[^"]*"[^>]*>([\s\S]*)/i);
  if (m) return m[1];
  m = html.match(/<div[^>]*class="[^"]*\bpage_content_wrap\b[^"]*"[^>]*>([\s\S]*)/i);
  if (m) return m[1];
  m = html.match(/<div[^>]*class="[^"]*\bwpb_text_column\b[^"]*"[^>]*>([\s\S]*)/i);
  if (m) return m[1];
  // WordPress estandar
  m = html.match(/<(?:div|article)[^>]*class="[^"]*(?:entry.?content|post.?content|article.?body)[^"]*"[^>]*>([\s\S]*)/i);
  if (m) return m[1];
  // Divi
  m = html.match(/<div[^>]*class="[^"]*et_pb_member_description[^"]*"[^>]*>([\s\S]*)/i);
  if (m) return m[1];
  // Fallback: body
  m = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
  return m ? m[1] : html;
}

// ── Extraer ROL desde clases body (patron Nazari: team_group-autores, etc.) ────
function extraerRolDeClasesBody(html) {
  const bodyM = html.match(/<body[^>]+class="([^"]+)"/i);
  if (!bodyM) return '';
  const clases = bodyM[1];
  // team_group-autores → "Autor/Autora"
  // team_group-ilustradores → "Ilustrador/Ilustradora"
  // team_group-traductores → "Traductor/Traductora"
  // team_group-editores → "Editor/Editora"
  const map = {
    'autores': 'Autor', 'autor': 'Autor',
    'ilustradores': 'Ilustrador', 'ilustrador': 'Ilustrador',
    'traductores': 'Traductor', 'traductor': 'Traductor',
    'editores': 'Editor', 'editor': 'Editor',
    'coordinadores': 'Coordinador', 'prologuistas': 'Prologuista',
  };
  const m = clases.match(/team[_-]group[_-]([a-z]+)/i);
  if (m) {
    const key = m[1].toLowerCase();
    return map[key] || m[1];
  }
  return '';
}

// ── Extraer etiquetas desde clases body (team_group-*) ────────────────────────
function extraerEtiquetasDeClasesBody(html) {
  const bodyM = html.match(/<body[^>]+class="([^"]+)"/i);
  if (!bodyM) return [];
  const etiquetas = [];
  const re = /team[_-]group[_-]([a-z][a-z0-9_-]*)/gi;
  let m;
  while ((m = re.exec(bodyM[1])) !== null) {
    const val = m[1].replace(/[-_]/g, ' ');
    if (val.length > 1 && val !== 'autores' && val !== 'ilustradores' && val !== 'traductores' && val !== 'editores') {
      etiquetas.push(val);
    }
  }
  return etiquetas;
}

// ── Extractores ────────────────────────────────────────────────────────────────
const ROL_RE = /\b(autor[a]?|ilustrador[a]?|editor[a]?|traductor[a]?|prologuista|coordinador[a]?|compilador[a]?|fotógrafo|fotógrafa)\b/i;

// Parsea el título de Nazarí: "Autor/a Nombre Apellido | Editorial Nazarí"
// Devuelve { nombre, rolTitulo }
function parsearTituloNazari(html) {
  var result = { nombre: '', rolTitulo: '' };
  var t = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (!t) {
    var h1 = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    result.nombre = h1 ? stripTags(h1[1]).trim() : '';
    return result;
  }
  var titulo = stripTags(t[1]).split('|')[0].trim();  // "Autor/a Óscar Borona"
  // Intentar extraer rol del principio del titulo
  var rolM = titulo.match(/^(Autor\/a|Autora?|Ilustrador\/a|Ilustradore?s?|Editor\/a|Editore?s?|Traductor\/a|Traductore?s?|Prologuista|Coordinador\/a|Compilador\/a|Fotógrafo\/a)\s+/i);
  if (rolM) {
    result.rolTitulo = rolM[1].trim();
    result.nombre = titulo.slice(rolM[0].length).trim();
  } else {
    result.nombre = titulo;
  }
  return result;
}

function extraerNombre(html) {
  return parsearTituloNazari(html).nombre ||
    (html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) ? stripTags(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)[1]).trim() : '');
}

function extraerRol(html) {
  // 1. Titulo de pagina: "Autor/a Nombre | Editorial Nazarí" (patron principal Nazari)
  const rolTitulo = parsearTituloNazari(html).rolTitulo;
  if (rolTitulo) return rolTitulo;
  // 2. Clases body de Nazari: team_group-autores, etc.
  const rolBody = extraerRolDeClasesBody(html);
  if (rolBody) return rolBody;
  // 2. Divi .et_pb_member_position
  const diviM = html.match(/<[^>]+class="[^"]*et_pb_member_position[^"]*"[^>]*>([\s\S]*?)<\/[^>]+>/i);
  if (diviM) { const t = stripTags(diviM[1]).trim(); if (t) return t; }
  // 3. Clases genéricas job-title / cargo
  const clsM = html.match(/<[^>]+class="[^"]*(?:job.?title|position|cargo|rol(?:e)?)[^"]*"[^>]*>([\s\S]*?)<\/[^>]+>/i);
  if (clsM) { const t = stripTags(clsM[1]).trim(); if (t && t.length < 120) return t; }
  // 4. Primer párrafo corto con palabra de rol
  const zone = getContentZone(html);
  const pRe  = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm;
  while ((pm = pRe.exec(zone)) !== null) {
    const t = stripTags(pm[1]).trim();
    if (t.length > 0 && t.length < 80 && ROL_RE.test(t)) return t;
  }
  return '';
}

function extraerBio(html) {
  // Patron principal Nazari: wpb_text_column contiene la bio completa como texto plano
  const wpbRe = /<div[^>]*class="[^"]*\bwpb_text_column\b[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi;
  let wm; const candidatos = [];
  while ((wm = wpbRe.exec(html)) !== null) {
    const t = stripTags(wm[1]).replace(/\s+/g, ' ').trim();
    if (t.length >= 60 && !/(?:cookie|aviso|newsletter|carrito|catalogo|©)/i.test(t)) candidatos.push(t);
  }
  // Elegir el más largo (la bio real, no los bloques cortos)
  if (candidatos.length > 0) return candidatos.sort(function(a,b){return b.length-a.length;})[0];

  // Fallback: párrafos del contenido principal
  const zone = getContentZone(html);
  const textos = [];
  const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm;
  while ((pm = pRe.exec(zone)) !== null) {
    const t = stripTags(pm[1]).trim();
    if (t.length >= 30 && !/(?:cookie|política de privacidad|aviso legal|newsletter)/i.test(t)) textos.push(t);
  }
  return textos.join('\n\n');
}

function extraerEtiquetas(html) {
  const seen = new Set(), tags = [];
  function add(raw) {
    for (const p of stripTags(raw).split(/[,\/;|]/).map(s => s.trim()).filter(s => s.length > 0 && s.length < 80)) {
      const k = norm(p); if (!seen.has(k)) { seen.add(k); tags.push(p); }
    }
  }
  // 1. Categorías del tema Nazarí desde /team-group/ URLs (su taxonomia propia)
  const teamGroupRe = /<a[^>]+href="[^"]*\/team-group\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; let tg;
  while ((tg = teamGroupRe.exec(html)) !== null) add(tg[1]);
  // 2. Links a /category/ o /tag/ en la URL
  const catTagRe = /<a[^>]+href="[^"]*\/(?:category|tag|genero|etiqueta)\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; let ct;
  while ((ct = catTagRe.exec(html)) !== null) add(ct[1]);
  // 3. rel="tag" o rel="category"
  const relRe = /<a[^>]+rel="[^"]*(?:tag|category)[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; let rt;
  while ((rt = relRe.exec(html)) !== null) add(rt[1]);
  // 4. Bloques post-terms (Gutenberg)
  const termsRe = /<[^>]+class="[^"]*(?:wp-block-post-terms|post.?tags|entry.?tags|tag.?links|cat.?links)[^"]*"[^>]*>([\s\S]*?)<\/[^>]+>/gi;
  let tm; while ((tm = termsRe.exec(html)) !== null) { const aRe = /<a[^>]*>([\s\S]*?)<\/a>/gi; let am; while ((am = aRe.exec(tm[1])) !== null) add(am[1]); }
  return tags;
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  const slug    = toSlug(NOMBRE_AUTOR);
  const url     = `${BASE}${slug}/`;
  const docId   = `naz-${toDocSlug(NOMBRE_AUTOR)}`;

  console.log('\n' + '═'.repeat(70));
  console.log(` 🧪  PRUEBA — ${NOMBRE_AUTOR}${APLICAR ? ' [MODO APLICAR]' : ' [SOLO LECTURA]'}`);
  console.log('═'.repeat(70));
  console.log(`\n  URL intentada: ${url}`);
  console.log(`  Doc ID Firestore: ${docId}\n`);

  // ── Fetch web (con fallback automático a Wayback Machine) ────────────────────
  console.log('  🌐 Fetching página web…');
  const resultado = await fetchConFallback(url);

  if (!resultado.html) {
    console.log('  ❌ No se pudo obtener el contenido ni directamente ni desde Wayback Machine.');
    process.exit(1);
  }

  if (resultado.source === 'wayback') {
    console.log('  📦 Usando copia archivada del ' + (resultado.timestamp || '').substring(0, 8));
  }

  const html = resultado.html;

  await procesarHtml(html, url, docId);
}

async function procesarHtml(html, url, docId) {
  const nombre    = extraerNombre(html);
  const rol       = extraerRol(html);
  const bio       = extraerBio(html);
  const etiquetas = extraerEtiquetas(html);

  // Función para mostrar un texto respetando palabras y párrafos
  function mostrarTexto(texto, indent, ancho) {
    if (!texto) { console.log(indent + '(no encontrado)'); return; }
    const parrafos = texto.split('\n\n');
    parrafos.forEach((par, idx) => {
      const palabras = par.trim().split(/\s+/);
      let linea = '';
      for (const p of palabras) {
        if (linea.length + p.length + 1 > ancho && linea.length > 0) {
          console.log(indent + linea);
          linea = p;
        } else {
          linea = linea ? linea + ' ' + p : p;
        }
      }
      if (linea) console.log(indent + linea);
      if (idx < parrafos.length - 1) console.log(); // línea en blanco entre párrafos
    });
  }

  // Si no se extrajo nada → diagnóstico automático de estructura HTML
  if (!nombre && !bio) {
    console.log('\n  ⚠️  Los extractores no encontraron contenido. Diagnóstico:\n');

    // Mostrar clases CSS encontradas en el HTML
    const clases = new Set();
    const clsRe = /class="([^"]+)"/g; let cm;
    while ((cm = clsRe.exec(html)) !== null) {
      cm[1].split(/\s+/).forEach(function(c) { if (c.length > 3) clases.add(c); });
    }
    const clasesInteresantes = [...clases].filter(function(c) {
      return /content|entry|post|team|member|autor|bio|desc|text|body|main|article|page/i.test(c);
    });
    console.log('  Clases CSS relevantes encontradas (' + clasesInteresantes.length + '):');
    console.log('  ' + clasesInteresantes.slice(0, 30).join(', '));

    // Mostrar los primeros <h1>, <h2>, <p> del HTML
    console.log('\n  Primeros h1/h2:');
    var hRe = /<h[12][^>]*>([\s\S]*?)<\/h[12]>/gi; var hm; var hCnt = 0;
    while ((hm = hRe.exec(html)) !== null && hCnt < 5) {
      var t = hm[1].replace(/<[^>]+>/g, '').trim();
      if (t) { console.log('    ' + t); hCnt++; }
    }

    console.log('\n  Primeros 5 párrafos con texto:');
    var pRe2 = /<p[^>]*>([\s\S]*?)<\/p>/gi; var pm2; var pCnt = 0;
    while ((pm2 = pRe2.exec(html)) !== null && pCnt < 5) {
      var t2 = pm2[1].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
      if (t2.length > 20) { console.log('    [' + t2.length + 'c] ' + t2.substring(0, 100)); pCnt++; }
    }

    console.log('\n  HTML recibido (primeros 2000 chars):');
    console.log('  ' + html.substring(0, 2000).replace(/\n/g, '\n  '));
    process.exit(1);
  }

  console.log('\n' + '='.repeat(68));
  console.log('  DATOS EXTRAIDOS DE LA WEB');
  console.log('='.repeat(68));
  console.log('\n  nombre:    ' + (nombre || '(no encontrado)'));
  console.log('  rol:       ' + (rol || '(no detectado)'));
  console.log('  etiquetas: ' + (etiquetas.length ? etiquetas.join(' | ') : '(ninguna)'));
  console.log('\n  BIO (' + bio.length + ' caracteres):');
  console.log('  ' + '-'.repeat(64));
  mostrarTexto(bio, '  ', 70);
  console.log('  ' + '-'.repeat(64));

  if (!APLICAR) {
    console.log('\n  ─────────────────────────────────────────────────────────────');
    console.log('  ℹ️  Modo solo lectura. Para inyectar en Firestore:');
    console.log(`\n     node scripts/inyectar_autor_prueba.js --aplicar\n`);
    return;
  }

  // ── Leer estado actual en Firestore ─────────────────────────────────────────
  initFirebase();
  const db     = admin.firestore();
  const colRef = db.collection('empresas').doc(EID).collection('autores');

  // Buscar por doc ID (naz-oscar-borona) o por nombre normalizado
  let docRef = colRef.doc(docId);
  let docSnap = await docRef.get();

  if (!docSnap.exists) {
    // Buscar por nombre normalizado en todos los docs
    const all = await colRef.get();
    for (const d of all.docs) {
      if (norm(d.data().nombre || '') === norm(NOMBRE_AUTOR)) { docRef = d.ref; docSnap = d; break; }
    }
  }

  if (!docSnap.exists) {
    console.log(`\n  ⚠️  No existe en Firestore. Se creará como documento nuevo: ${docId}`);
  } else {
    const cur = docSnap.data();
    console.log(`\n  📋 Estado actual en Firestore (doc: ${docSnap.id}):`);
    console.log(`     bio (${(cur.bio || '').length}c):  "${(cur.bio || '(vacía)').substring(0, 80)}"`);
    console.log(`     rol:        "${cur.rol || '(campo ausente)'}"`);
    console.log(`     etiquetas:  ${JSON.stringify(cur.etiquetas || [])}`);
    console.log(`     genero:     "${cur.genero || ''}"`);
  }

  // ── Construir update ─────────────────────────────────────────────────────────
  const update = { fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp() };
  if (rol)                        update.rol = rol;
  if (bio && bio.length > 20) {
    update.bio         = bio;
    update.descripcion = bio.substring(0, 1500) + (bio.length > 1500 ? '…' : '');
  }
  if (etiquetas.length > 0)       update.etiquetas = etiquetas;

  // ── Aplicar ──────────────────────────────────────────────────────────────────
  if (docSnap.exists) {
    await docRef.update(update);
  } else {
    await docRef.set({
      nombre: nombre || NOMBRE_AUTOR,
      busqueda: nombre || NOMBRE_AUTOR,
      activo: true,
      ...update,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  const campos = Object.keys(update).filter(k => k !== 'fecha_actualizacion');
  console.log(`\n  ✅ Firestore actualizado:`);
  console.log(`     Documento:  ${docSnap.exists ? docSnap.id : docId}`);
  console.log(`     Campos:     ${campos.join(', ')}\n`);

  process.exit(0);
}

main().catch(e => { console.error('\n❌ Error:', e.message || e); process.exit(1); });
