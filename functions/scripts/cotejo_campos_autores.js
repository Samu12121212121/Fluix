'use strict';

/**
 * cotejo_campos_autores.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Para cada autor cuyo nombre queda > M (alfabéticamente):
 *   1. Lee sus campos actuales en Firestore (app Fluix / Nazari)
 *   2. Busca su página en la web de Nazari (con fallback a Wayback Machine)
 *   3. Extrae: nombre exacto, rol, bio completa, etiquetas
 *   4. Compara y muestra TODOS los campos que faltan o difieren
 *
 * Al final: resumen total de campos incompletos.
 * Con --aplicar: actualiza los campos que faltan en Firestore.
 *
 * Uso:
 *   cd functions
 *   node scripts/cotejo_campos_autores.js             <- solo reporte
 *   node scripts/cotejo_campos_autores.js --aplicar   <- reporte + corrige
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');
const os    = require('os');
const vm    = require('vm');

const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE    = 'https://www.editorialnazari.com/team/';
const APLICAR = process.argv.includes('--aplicar');
const HTML_DIR = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');
const DELAY_WB = 1200; // ms entre peticiones al Wayback Machine

// ── Firebase ───────────────────────────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) { admin.initializeApp({ credential: admin.credential.cert(require(saPath)) }); return; }
  function getToken() {
    for (const p of [
      path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
      path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    ]) { try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); if (d?.tokens?.refresh_token) return d.tokens.refresh_token; } catch (_) {} }
    return null;
  }
  const rt = getToken();
  if (!rt) { console.error('Sin credenciales Firebase.'); process.exit(1); }
  admin.initializeApp({ credential: admin.credential.refreshToken({ type: 'authorized_user', client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com', client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p', refresh_token: rt }), projectId: 'planeaapp-4bea4' });
}

// ── Normalización ──────────────────────────────────────────────────────────────
function norm(s) { return (s||'').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').trim(); }
function toSlug(n) { return norm(n).replace(/[^a-z0-9\s-]/g,' ').replace(/\s+/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,''); }
function toDocId(n) { return 'naz-' + n.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,''); }
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function stripTags(h) { return (h||'').replace(/<[^>]+>/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#\d+;/g,' ').replace(/\s+/g,' ').trim(); }

// ── HTTP fetch sin compresión ──────────────────────────────────────────────────
function fetchHtml(url, hops) {
  hops = hops === undefined ? 4 : hops;
  return new Promise(function(resolve) {
    var lib = url.startsWith('https') ? https : http;
    try {
      var req = lib.get(url, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Accept': 'text/html', 'Accept-Language': 'es-ES,es;q=0.9' } }, function(res) {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops > 0) {
          var loc = res.headers.location.startsWith('http') ? res.headers.location : new URL(res.headers.location, url).href;
          res.resume(); return fetchHtml(loc, hops - 1).then(resolve);
        }
        var raw = ''; res.setEncoding('utf8');
        res.on('data', function(c) { raw += c; });
        res.on('end', function() { resolve({ status: res.statusCode, html: raw }); });
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

// ── Fetch con fallback a Wayback Machine ──────────────────────────────────────
async function fetchConFallback(urlOriginal) {
  var direct = await fetchHtml(urlOriginal);
  var okDirect = direct.status >= 200 && direct.status < 300 && direct.html && direct.html.length > 3000 && !direct.html.includes('sgcaptcha');
  if (okDirect) return { html: direct.html, source: 'directo' };

  var limpio = urlOriginal.replace(/^https?:\/\/(www\.)?/, '');
  var api = await fetchJson('https://archive.org/wayback/available?url=' + limpio);
  var archiveUrl = api.data && api.data.archived_snapshots && api.data.archived_snapshots.closest && api.data.archived_snapshots.closest.url;
  if (!archiveUrl) return { html: '', source: 'sin_copia' };

  await sleep(DELAY_WB);
  var arch = await fetchHtml(archiveUrl);
  if (!arch.html || arch.status < 200 || arch.status >= 300) return { html: '', source: 'wayback_error' };

  var html = arch.html
    .replace(/<!-- BEGIN WAYBACK TOOLBAR[\s\S]*?END WAYBACK TOOLBAR -->/gi, '')
    .replace(/<div[^>]+id="wm-ipp[\s\S]*?<\/div>/gi, '')
    .replace(/https?:\/\/web\.archive\.org\/web\/\d+\//g, '');

  var ts = (api.data.archived_snapshots.closest.timestamp || '').substring(0, 8);
  return { html: html, source: 'wayback:' + ts };
}

// ── Extractores ────────────────────────────────────────────────────────────────
function extraerDatosWeb(html) {
  var nombre = '', rol = '', bio = '', etiquetas = [];

  // Nombre y rol desde el titulo: "Autor/a Nombre Apellido | Editorial Nazari"
  var titleM = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (titleM) {
    var titulo = stripTags(titleM[1]).split('|')[0].trim();
    var rolM = titulo.match(/^(Autor\/a|Autora?|Ilustrador\/a|Ilustradore?s?|Editor\/a|Editore?s?|Traductor\/a|Traductore?s?|Prologuista|Coordinador\/a|Compilador\/a|Fotógrafo\/a|Diseñador\/a)\s+/i);
    if (rolM) { rol = rolM[1].trim(); nombre = titulo.slice(rolM[0].length).trim(); }
    else { nombre = titulo; }
  }
  if (!nombre) {
    var h1M = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    if (h1M) nombre = stripTags(h1M[1]).trim();
  }

  // Bio desde wpb_text_column (el bloque mas largo con texto sustancial)
  var wpbRe = /<div[^>]*class="[^"]*\bwpb_text_column\b[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/gi;
  var wm; var candidatos = [];
  while ((wm = wpbRe.exec(html)) !== null) {
    var t = stripTags(wm[1]).replace(/\s([.,;:])/g, '$1').replace(/\s+/g, ' ').trim();
    if (t.length >= 60 && !/cookie|aviso|newsletter|carrito|catalogo|©|copyright/i.test(t)) candidatos.push(t);
  }
  if (candidatos.length > 0) bio = candidatos.sort(function(a,b){return b.length-a.length;})[0];

  // Etiquetas desde /team-group/ URLs
  var tgRe = /<a[^>]+href="[^"]*\/team-group\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi; var tgm;
  var seen = new Set();
  while ((tgm = tgRe.exec(html)) !== null) {
    var et = stripTags(tgm[1]).trim();
    if (et.length > 0 && et.length < 60 && !seen.has(norm(et))) { seen.add(norm(et)); etiquetas.push(et); }
  }
  // Fallback: rel=tag links
  var tagRe = /<a[^>]+rel="tag"[^>]*>([\s\S]*?)<\/a>/gi; var tm2;
  while ((tm2 = tagRe.exec(html)) !== null) {
    var et2 = stripTags(tm2[1]).trim();
    if (et2.length > 0 && et2.length < 60 && !seen.has(norm(et2))) { seen.add(norm(et2)); etiquetas.push(et2); }
  }

  // Links externos en la bio
  var linksWeb = [];
  var linkRe = /<a[^>]+href="(https?:\/\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/gi; var lm;
  var seenLinks = new Set();
  while ((lm = linkRe.exec(html)) !== null) {
    var href = lm[1]; var text = stripTags(lm[2]).trim();
    if (!seenLinks.has(href) && !/editorialnazari\.com|web\.archive\.org/i.test(href)) {
      seenLinks.add(href);
      linksWeb.push(text ? text + ' → ' + href : href);
    }
  }

  return { nombre: nombre, rol: rol, bio: bio, etiquetas: etiquetas, links: linksWeb };
}

// ── Cargar autores-data.js completo (nombre + bio + genero) ──────────────────
function loadAutoresData() {
  var fp = path.join(HTML_DIR, 'autores-data.js');
  if (!fs.existsSync(fp)) { console.warn('  ⚠️  No encontrado: ' + fp); return []; }
  var code = fs.readFileSync(fp, 'utf8').replace(/^const\s+/gm,'var ').replace(/^let\s+/gm,'var ');
  var ctx = {};
  try { vm.runInNewContext(code, ctx); } catch(_) {}
  return ctx['AUTORES'] || [];
}

function loadLocalNames() {
  return loadAutoresData().map(function(a) { return a && a.nombre ? a.nombre.trim() : ''; }).filter(Boolean);
}

const NOMBRES_EXTRA = [
  'Pedro Cantero y Esteban Ruiz Ballesteros','David Cidoncha','Mercedes Maroto Marquez','Federico Zurita Martinez',
  'Maria Alcazar Rodriguez','Elisa de Armas','Enrique Palomo Atance','Sofia Perez Martinez','Francisco Manuel Miranda',
  'Ruth Gomez','David Vegue','Oscar Borona','Francisco Javier Fernandez Espinosa','Juan Antonio Trillo Lopez',
  'Carmen M. Leon Lopa','Enrique J. Vercher Garcia','Francisco Rojas Santos','Xanath Caraza','Eduardo Calvo',
  'Hector Pose','Carmen Gijon Herrera','Ismael Contreras Carmona','Guillermo Rubio Martin','Victor Espuny',
  'Saul Roas Deus','Pedro Blanco Naveros','Slavko Zupcic','Juan Jose Cuenca Lopez','Jon Sigurdur Eyjolfsson',
  'Jordi Navarro Fisas','Lucia Marin','Antonio Cobos Ruz','Maria Belen Adarve Ramirez','Francisco Castilla Torres',
  'Dori Hernandez Montalban','Consuelo de la Torre','Juan Jose Castro Martin','Francisco Beltran Sanchez',
  'Alicia Maria Exposito','Julia Martinez Sanchez','Teresa Martin Estevez','Francisco Urbano','Guillermo Gomez Munoz',
  'Fermin Lopez Costero','Pilar Quirosa-Cheyrouze','Cristina Galvez','Jone Miren Asteinza','Francisco Gil Craviotto',
  'Sandra Clavel','Santi Perez Isasi','Angel Olgoso','Salvador Perez Duenas','Emilio Ballesteros',
  'Fernando de Villena','Antonio Espinosa Ubeda','Jose Luis Lopez Enamorado','Mar de los Rios','Miguel Angel Malo',
  'Antonio Fernandez Ferrer','Jose Loma','Felix Delgado Ropero','Carmen Hernandez Montalban','Cristina Leon Lopa',
  'Sergi G. Oset','Paz Monserrat Revillo','Juan Carlos Garvayo','Reza Emilio Juma','Carmina Moreno Arenas',
  'Juan Carlos Friebe','Emilio Rodriguez Linares','Francisco J. Martinez-Lopez','Luis Lopez-Quinones Ruiz',
  'Angel Fabregas Garcia','Encarni Barragan Sanchez','Pedro Ruiz-Cabello Fernandez','Jose R. Reyes',
  'Borja Angosto Rubio','Jose Luis Gartner','Beatriz Alonso Aranzabal','Jose Antonio Santano',
  'Juan Torres Colomera','Jorge Pastor','Giancarlo Remorini','Felix Terrones','Josefina Martos Peregrin',
  'Francisco Morales Lomas','Carlos Almira Picazo','Jose Zamora Linares','Vitaliano de la Cruz',
  'Gabriel T. Rojo','Carolina Molina','Marina Tapia','Fernando Morales Nunez','Doceat','Carlos de la Fe',
  'Jose Maria Garcia Linares','Miha Mazzini','Miguel Angel Ulecia Martinez','Juan Naveros Sanchez',
];

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '='.repeat(72));
  console.log(' COTEJO CAMPOS AUTORES > M | web Nazari vs app Fluix');
  console.log(APLICAR ? ' [MODO APLICAR: si todo OK, actualiza Firestore]' : ' [SOLO REPORTE: sin cambios]');
  console.log('='.repeat(72) + '\n');

  initFirebase();
  const db     = admin.firestore();
  const colRef = db.collection('empresas').doc(EID).collection('autores');

  // Leer autores-data.js (fuente 1)
  const autoresDataArr = loadAutoresData();
  const autoresDataMap = new Map();
  for (var ad of autoresDataArr) {
    if (ad && ad.nombre) autoresDataMap.set(norm(ad.nombre), ad);
  }
  console.log('autores-data.js: ' + autoresDataArr.length + ' autores');

  // Leer Firestore (fuente 2)
  process.stdout.write('Leyendo Firestore...');
  const snap = await colRef.get();
  const fsMap = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.nombre) fsMap.set(norm(d.nombre), { docId: doc.id, data: d });
  }
  console.log(' ' + snap.size + ' autores\n');

  // Construir lista de todos los nombres conocidos, filtrar > M
  const todosNombres = new Set([...loadLocalNames(), ...NOMBRES_EXTRA]);
  const sorted = [...todosNombres]
    .filter(Boolean)
    .sort(function(a, b) { return norm(a).localeCompare(norm(b), 'es'); });
  const despuesM = sorted.filter(function(n) { return norm(n).charAt(0) > 'm'; });

  console.log('Autores conocidos > M: ' + despuesM.length + '\n');
  console.log('-'.repeat(72));

  var stats = { total: despuesM.length, conDiscrepancia: 0, sinBioWeb: 0, sinPaginaWeb: 0,
    faltaRol: 0, bioIncompleta: 0, faltaEtiquetas: 0 };
  var actualizaciones = [];

  for (var i = 0; i < despuesM.length; i++) {
    var nombre = despuesM[i];
    var slug   = toSlug(nombre);
    var url    = BASE + slug + '/';
    var fsEntry = fsMap.get(norm(nombre));

    process.stdout.write('\r[' + String(i+1).padStart(3) + '/' + despuesM.length + '] ' + nombre.substring(0, 40).padEnd(40) + '  ');

    await sleep(300); // pausa minima
    var resultado = await fetchConFallback(url);

    if (!resultado.html) {
      stats.sinPaginaWeb++;
      console.log('\n  ⚠️  Sin pagina web (' + resultado.source + ')');
      continue;
    }

    var web = extraerDatosWeb(resultado.html);
    var src = resultado.source === 'directo' ? 'directo' : resultado.source;

    if (!web.bio) { stats.sinBioWeb++; }

    // Fuente 1: autores-data.js
    var adEntry = autoresDataMap.get(norm(nombre));
    var ad_ = adEntry || {};

    // Fuente 2: Firestore
    var fs_ = fsEntry ? fsEntry.data : null;

    // Acumular stats de discrepancias
    var rolFS  = fs_ ? (fs_.rol || '') : '';
    var bioFS  = fs_ ? (fs_.bio || '') : '';
    var etFS   = fs_ ? (Array.isArray(fs_.etiquetas) ? fs_.etiquetas : (fs_.genero ? [fs_.genero] : [])) : [];
    var bioAD  = ad_.bio || ad_.descripcion || '';
    var genAD  = ad_.genero || '';
    var bioWeb = web.bio || '';
    var etWeb  = web.etiquetas || [];
    var rolWeb = web.rol || '';

    if (rolWeb && !rolFS) stats.faltaRol++;
    if (bioWeb && bioFS.length < bioWeb.length - 50) stats.bioIncompleta++;
    var etFaltantesFS = etWeb.filter(function(e) { return !etFS.map(norm).includes(norm(e)); });
    if (etWeb.length > 0 && (etFS.length === 0 || etFaltantesFS.length > 0)) stats.faltaEtiquetas++;

    var hayDiscrepancia = (rolWeb && !rolFS) ||
      (bioWeb && bioFS.length < bioWeb.length - 50) ||
      (etWeb.length > 0 && (etFS.length === 0 || etFaltantesFS.length > 0));

    if (hayDiscrepancia) stats.conDiscrepancia++;

    // Siempre mostrar el bloque completo de cada autor
    process.stdout.write('\n');
    var flags = (fsEntry ? '' : ' [SIN FS]') + (adEntry ? '' : ' [SIN autores-data]');
    console.log('= '.repeat(36));
    console.log('[' + String(i+1).padStart(3) + '] ' + nombre + '  (' + src + ')' + flags);
    console.log('= '.repeat(36));

    // ── AUTORES-DATA.JS ────────────────────────────────────────────────────────
    var adCampos = 0;
    if (adEntry) {
      if (ad_.nombre)      { adCampos++; }
      if (ad_.genero)      { adCampos++; }
      if (ad_.lugar)       { adCampos++; }
      if (ad_.bio)         { adCampos++; }
      if (ad_.descripcion) { adCampos++; }
      if (ad_.foto)        { adCampos++; }
    }
    console.log('  [1] autores-data.js  (' + (adEntry ? adCampos + ' campos' : 'NO ENCONTRADO') + ')');
    if (adEntry) {
      console.log('      nombre:      "' + (ad_.nombre || '') + '"');
      console.log('      genero:      "' + (ad_.genero || '--') + '"');
      console.log('      lugar:       "' + (ad_.lugar  || '--') + '"');
      console.log('      bio:         ' + (ad_.bio ? ad_.bio.length + 'c' : '--'));
      console.log('      descripcion: ' + (ad_.descripcion ? ad_.descripcion.length + 'c' : '--'));
      console.log('      foto:        ' + (ad_.foto || '--'));
      console.log('      rol:         (campo no existe)');
      console.log('      etiquetas:   ' + (ad_.genero ? '["' + ad_.genero + '"] (solo genero, sin campo etiquetas)' : '--'));
    }

    // ── FIRESTORE ──────────────────────────────────────────────────────────────
    var fsCampos = 0;
    if (fs_) {
      var fsFields = ['nombre','bio','descripcion','genero','lugar','rol','etiquetas','foto','foto_url','busqueda','activo','orden'];
      fsCampos = fsFields.filter(function(f) { return fs_[f] !== undefined && fs_[f] !== '' && fs_[f] !== null; }).length;
    }
    console.log('  [2] Firestore        (' + (fs_ ? fsCampos + ' campos con dato' : 'NO ENCONTRADO') + ')');
    if (fs_) {
      console.log('      nombre:      "' + (fs_.nombre || '') + '"');
      console.log('      rol:         ' + (fs_.rol ? '"' + fs_.rol + '"' : '(ausente) ⚠'));
      console.log('      bio:         ' + (fs_.bio ? fs_.bio.length + 'c' : '(ausente)'));
      console.log('      descripcion: ' + (fs_.descripcion ? fs_.descripcion.length + 'c' : '--'));
      console.log('      genero:      "' + (fs_.genero || '--') + '"');
      console.log('      etiquetas:   ' + (Array.isArray(fs_.etiquetas) && fs_.etiquetas.length ? JSON.stringify(fs_.etiquetas) : (fs_.genero ? '["' + fs_.genero + '"] (de genero)' : '(ausente) ⚠')));
      console.log('      lugar:       "' + (fs_.lugar || '--') + '"');
      console.log('      foto:        ' + (fs_.foto || fs_.foto_url || '--'));
    }

    // ── WEB ────────────────────────────────────────────────────────────────────
    var webCampos = (web.nombre ? 1 : 0) + (web.rol ? 1 : 0) + (web.bio ? 1 : 0) + (web.etiquetas.length ? 1 : 0);
    console.log('  [3] Web              (' + webCampos + ' campos extraidos)');
    console.log('      nombre:      "' + (web.nombre || '--') + '"');
    console.log('      rol:         ' + (web.rol ? '"' + web.rol + '"' : '(no extraido)') + (rolWeb && !rolFS ? ' ⚠ FALTA EN FS' : ''));
    console.log('      bio:         ' + (web.bio ? web.bio.length + 'c' : '(no extraida)') + (bioWeb && bioFS.length < bioWeb.length - 50 ? ' ⚠ FS TIENE ' + (bioWeb.length - bioFS.length) + 'c MENOS' : ''));
    console.log('      etiquetas:   ' + (etWeb.length ? JSON.stringify(etWeb) : '(no extraidas)') + (etFaltantesFS.length ? ' ⚠ FALTAN EN FS: ' + etFaltantesFS.join(', ') : ''));
    if (web.links && web.links.length > 0) {
      console.log('      links web:   ' + web.links.length + ' enlace(s) externo(s)');
      web.links.slice(0, 4).forEach(function(l) { console.log('                   • ' + l.substring(0, 90)); });
    } else {
      console.log('      links web:   (ninguno)');
    }

    if (APLICAR && fsEntry && (web.bio || web.rol || web.etiquetas.length > 0)) {
      actualizaciones.push({ docId: fsEntry.docId, web: web, ad: adEntry || null, fs: fs_ || null, nombre: nombre });
    }
  }

  // Resumen
  console.log('\n\n' + '='.repeat(72));
  console.log(' RESUMEN COTEJO AUTORES > M');
  console.log('='.repeat(72));
  console.log('  Total autores > M analizados: ' + stats.total);
  console.log('  Con algun campo distinto/faltante: ' + stats.conDiscrepancia);
  console.log('  Sin pagina en web/archivo:  ' + stats.sinPaginaWeb);
  console.log('  Sin bio en web:             ' + stats.sinBioWeb);
  console.log('');
  console.log('  Campos que faltan en Fluix:');
  console.log('    rol ausente o diferente:  ' + stats.faltaRol);
  console.log('    bio ausente/incompleta:   ' + stats.bioIncompleta);
  console.log('    etiquetas ausentes/cortas:' + stats.faltaEtiquetas);

  if (!APLICAR) {
    console.log('\n  Para aplicar las correcciones:');
    console.log('  node scripts/cotejo_campos_autores.js --aplicar\n');
    process.exit(0);
  }

  // Aplicar
  if (actualizaciones.length === 0) {
    console.log('\n  Nada que actualizar.\n');
    process.exit(0);
  }

  // Backup antes de aplicar
  var backupPath = path.join(__dirname, 'autores-backup-' + new Date().toISOString().slice(0,10) + '.json');
  var backupData = {};
  for (var bk = 0; bk < actualizaciones.length; bk++) {
    var bAct = actualizaciones[bk];
    if (bAct.fs) backupData[bAct.docId] = bAct.fs;
  }
  fs.writeFileSync(backupPath, JSON.stringify(backupData, null, 2), 'utf8');
  console.log('\n  Backup guardado: ' + backupPath);
  console.log('  Actualizando ' + actualizaciones.length + ' documentos...\n');

  var batch = db.batch(); var cnt = 0; var ok = 0;
  for (var k = 0; k < actualizaciones.length; k++) {
    var act = actualizaciones[k];
    var web_ = act.web || {};
    var ad_  = act.ad  || {};
    var fs__ = act.fs  || {};

    // Merge: web > autores-data > Firestore actual (fotos y orden siempre se mantienen)
    var upd = { fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp() };

    // nombre: web si es más preciso (viene del <title>), si no el que ya hay
    var nombreMejor = web_.nombre || fs__.nombre || act.nombre || '';
    if (nombreMejor) upd.nombre = nombreMejor;

    // busqueda: igual que nombre
    upd.busqueda = nombreMejor;

    // rol: solo lo tiene la web → siempre del web
    if (web_.rol) upd.rol = web_.rol;

    // bio: la más larga entre web y autores-data (sin tocar foto)
    var bioWeb_  = web_.bio || '';
    var bioAD_   = ad_.bio || ad_.descripcion || '';
    var bioMejor = bioWeb_.length >= bioAD_.length ? bioWeb_ : bioAD_;
    if (bioMejor.length > 20) {
      upd.bio = bioMejor;
      upd.descripcion = bioMejor.substring(0, 1500) + (bio.length > 1500 ? '...' : '');
    }

    // etiquetas: de la web (lista completa)
    if (web_.etiquetas && web_.etiquetas.length > 0) upd.etiquetas = web_.etiquetas;

    // genero: de autores-data si existe, si no primera etiqueta web, si no lo que había
    var generoMejor = ad_.genero || (web_.etiquetas && web_.etiquetas[0]) || fs__.genero || '';
    if (generoMejor) upd.genero = generoMejor;

    // lugar: de autores-data si existe (la web no lo tiene), si no lo que había
    var lugarMejor = ad_.lugar || fs__.lugar || '';
    if (lugarMejor) upd.lugar = lugarMejor;

    // activo: mantener Firestore o true por defecto
    upd.activo = fs__.activo !== undefined ? fs__.activo : true;

    // NUNCA tocar: foto, foto_url, orden (se mantienen como están en Firestore)

    var camposActualizados = Object.keys(upd).filter(function(c) { return c !== 'fecha_actualizacion'; });
    console.log('  [' + String(k+1).padStart(3) + '] ' + (act.nombre || act.docId).substring(0, 35).padEnd(35) + ' → ' + camposActualizados.join(', '));

    batch.update(colRef.doc(act.docId), upd);
    cnt++; ok++;
    if (cnt >= 400) { await batch.commit(); batch = db.batch(); cnt = 0; }
  }
  if (cnt > 0) await batch.commit();
  console.log('\n  Completado: ' + ok + ' documentos actualizados.');
  process.exit(0);
}

main().catch(function(e) { console.error('\nError:', e.message || e); process.exit(1); });
