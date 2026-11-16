/**
 * importar_eventos_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Scrapea eventos pasados de editorialnazari.com y los sube a la colección
 * `eventos` de Firestore (empresa 0PoomHYDUJf5w8tDFRLhFi9iURF3).
 *
 * - Usa JSON-LD de cada página de evento para extraer todos los campos
 * - ID de documento = slug de WordPress (evita duplicados al re-ejecutar)
 * - Salta eventos ya existentes salvo que pases --forzar
 *
 * Uso:
 *   cd functions
 *   node scripts/importar_eventos_nazari.js
 *   node scripts/importar_eventos_nazari.js --desde=3 --hasta=7
 *   node scripts/importar_eventos_nazari.js --desde=3 --hasta=7 --forzar
 *
 * Parámetros opcionales:
 *   --desde=N   Página de inicio del listado (defecto: 3)
 *   --hasta=N   Página final del listado     (defecto: 7)
 *   --forzar    Sobreescribe eventos ya existentes en Firestore
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const https = require('https');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID      = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE_URL = 'https://www.editorialnazari.com';
const FORZAR   = process.argv.includes('--forzar');
const DELAY_MS = 400; // ms entre peticiones para no saturar el servidor

const arg = (name, def) => {
  const a = process.argv.find(x => x.startsWith(`--${name}=`));
  return a ? parseInt(a.split('=')[1]) : def;
};
const PAGINA_INICIO = arg('desde', 3);
const PAGINA_FIN    = arg('hasta', 7);

// ── HTTP helper ───────────────────────────────────────────────────────────────
function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    const options = { headers: { 'User-Agent': 'NazariImporter/1.0', 'Accept': 'text/html' } };
    https.get(url, options, res => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return resolve(fetchHtml(res.headers.location));
      }
      if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode} — ${url}`));
      res.setEncoding('utf8');
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Extraer URLs de eventos del listado ───────────────────────────────────────
function extraerUrls(html) {
  const re = /href="(https:\/\/www\.editorialnazari\.com\/evento\/[^"#?]+)"/g;
  const visto = new Set();
  const urls  = [];
  let m;
  while ((m = re.exec(html)) !== null) {
    const u = m[1].replace(/\/$/, '') + '/';
    if (!visto.has(u)) { visto.add(u); urls.push(u); }
  }
  return urls;
}

// ── Slug del evento (usado como ID de Firestore) ──────────────────────────────
function slugDesdeUrl(url) {
  return url.replace(/.*\/evento\//, '').replace(/\/$/, '');
}

// ── Eliminar boilerplate del site antes de guardar la descripción ─────────────
// El site header de Editorial Nazarí incluye siempre este párrafo fijo.
// Si aparece al inicio de la descripción extraída, lo quitamos.
const BOILERPLATE_MARKERS = [
  'Narrativa, poesía, relato',
  'Editorial Nazarí encontrarás',
  'amamos los libros y la buena literatura',
  '« Todos los Eventos',
  'Todos los Eventos Este evento',
];
function limpiarDesc(texto = '') {
  let t = texto;
  // Eliminar párrafos iniciales que contengan marcadores del boilerplate
  const parrafos = t.split('\n\n');
  const limpios = parrafos.filter(p =>
    !BOILERPLATE_MARKERS.some(marker => p.includes(marker))
  );
  return limpios.join('\n\n').trim();
}

// ── Limpiar texto HTML ────────────────────────────────────────────────────────
function stripHtml(s = '') {
  return s.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#8216;/g, '‘').replace(/&#8217;/g, '’')
    .replace(/&#8220;/g, '“').replace(/&#8221;/g, '”').replace(/&hellip;/g, '…')
    .replace(/&ntilde;/g, 'ñ').replace(/&aacute;/g, 'á').replace(/&eacute;/g, 'é')
    .replace(/&iacute;/g, 'í').replace(/&oacute;/g, 'ó').replace(/&uacute;/g, 'ú')
    .replace(/&Aacute;/g, 'Á').replace(/&Eacute;/g, 'É').replace(/&Iacute;/g, 'Í')
    .replace(/&Oacute;/g, 'Ó').replace(/&Uacute;/g, 'Ú');
}

// ── Detectar tipo de evento desde el título ────────────────────────────────────
function detectarTipo(titulo = '', desc = '') {
  const t = (titulo + ' ' + desc).toLowerCase();
  if (/firma/.test(t))                         return 'firma';
  if (/taller|curso|talleres/.test(t))          return 'taller';
  if (/feria/.test(t))                          return 'feria';
  if (/lectura|recital|poesia|poesía/.test(t))  return 'lectura';
  if (/presentaci/.test(t))                     return 'presentacion';
  return 'presentacion'; // la mayoría son presentaciones
}

// ── Extraer libro desde el título (suele ir entre comillas) ───────────────────
function extraerLibro(titulo = '') {
  const m = titulo.match(/['‘’“”]([^'‘’“”]+)['‘’“”]/);
  return m ? m[1].trim() : '';
}

// ── Detectar si una URL de imagen es foto de presentación (tiene fecha) ───────
// Fotos de evento:  .../2026-04-07-la-gestion-del-silencio-1.jpg
// Portadas de libro: .../la-gestion-del-silencio-portada-72ppp.jpg
function esFotoEvento(url = '') {
  const file = url.split('/').pop().split('?')[0];
  return /^\d{4}-\d{2}-\d{2}/.test(file);
}

// ── Parsear página de detalle → objeto evento ─────────────────────────────────
function parsearDetalle(html, url) {
  const slug = slugDesdeUrl(url);

  // — 1. JSON-LD (fuente principal) —
  let ld = null;
  const ldRe = /<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = ldRe.exec(html)) !== null) {
    try {
      const obj = JSON.parse(m[1]);
      if (obj['@type'] === 'Event') { ld = obj; break; }
      if (Array.isArray(obj['@graph'])) {
        const ev = obj['@graph'].find(x => x['@type'] === 'Event');
        if (ev) { ld = ev; break; }
      }
    } catch (_) {}
  }

  // — 2. og:image (imagen principal) —
  const ogImg = (html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/) ||
                 html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:image"/))?.[1] || '';

  // — 3. og:description como fallback de descripción —
  const ogDesc = stripHtml(
    (html.match(/<meta[^>]+property="og:description"[^>]+content="([^"]+)"/) ||
     html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:description"/))?.[1] || ''
  );

  // — 4. Extractor de bloques HTML con conteo de profundidad ──────────────────
  function extraerBloque(htmlStr, classFragment) {
    const re = new RegExp('<div[^>]+class="[^"]*' + classFragment + '[^"]*"[^>]*>', 'i');
    const m2 = re.exec(htmlStr);
    if (!m2) return '';
    let pos = m2.index + m2[0].length, depth = 1;
    while (pos < htmlStr.length && depth > 0) {
      const open  = htmlStr.indexOf('<div',  pos);
      const close = htmlStr.indexOf('</div>', pos);
      if (close === -1) break;
      if (open !== -1 && open < close) { depth++; pos = open + 4; }
      else { depth--; pos = close + 6; }
    }
    return htmlStr.substring(m2.index + m2[0].length, pos - 6);
  }

  // — 5. Extraer fecha y hora ───────────────────────────────────────────────
  function parsearFechaHora(htmlStr) {
    // 1. href de Google Calendar: dates=20260320T200000/20260320T213000
    const gcalHref = htmlStr.match(/dates=(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
    if (gcalHref) {
      const [, y, mo, d, h, mi] = gcalHref;
      return { fechaStr: `${y}-${mo}-${d}`, hora: `${h}:${mi}` };
    }
    // 2. datetime attribute compacto: datetime="20260320T200000/..."
    const gcalAttr = htmlStr.match(/datetime="(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
    if (gcalAttr) {
      const [, y, mo, d, h, mi] = gcalAttr;
      return { fechaStr: `${y}-${mo}-${d}`, hora: `${h}:${mi}` };
    }
    // 3. ISO estándar: datetime="2026-03-20T20:00:00+01:00"
    const iso = htmlStr.match(/datetime="(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
    if (iso) return { fechaStr: iso[1], hora: iso[2] };
    return { fechaStr: '', hora: '' };
  }

  // — 6. Descripción: extraer solo entre el link Google Calendar y <address> ─
  function extraerDescripcion(htmlStr) {
    // A. Clases conocidas (Tribe + Gutenberg) — rápido si existen
    for (const cls of ['tribe-events-content','entry-content','post-content','singular-content']) {
      const raw = extraerBloque(htmlStr, cls);
      if (raw && raw.length > 100) return raw;
    }
    // B. <p> entre <h1> y <address> — evita tagline del header del sitio
    const h1Idx  = htmlStr.search(/<h1[\s>]/i);
    const addrIdx = htmlStr.search(/<address[\s>]/i);
    const desde  = h1Idx  > 0 ? h1Idx  : 0;
    const hasta  = addrIdx > desde ? addrIdx : htmlStr.length;
    const seccion = htmlStr.substring(desde, hasta);
    const ps = [];
    const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi;
    let pm;
    while ((pm = pRe.exec(seccion)) !== null) {
      const t = stripHtml(pm[1]).trim();
      if (t.length > 40) ps.push(t);
    }
    if (ps.length > 0) return ps.join('\n\n');
    // C. Todos los <p> del documento como último recurso
    const ps2 = [];
    const pRe2 = /<p[^>]*>([\s\S]*?)<\/p>/gi;
    let pm2;
    while ((pm2 = pRe2.exec(htmlStr)) !== null) {
      const t = stripHtml(pm2[1]).trim();
      if (t.length > 80) ps2.push(t);
    }
    return ps2.join('\n\n');
  }
  // extraerDescripcion ya devuelve texto limpio con \n\n entre párrafos
  // NO aplicar stripHtml de nuevo (colapsaría los saltos y rompería limpiarDesc)
  const descBody = extraerDescripcion(html);

  // — 7. Localización ────────────────────────────────────────────────────────
  function extraerLugarCiudad(htmlStr) {
    // A. tribe spans
    const venueName = htmlStr.match(/<span[^>]*class="[^"]*tribe-venue[^"]*"[^>]*>([^<]+)<\/span>/i)?.[1]?.trim();
    const venueCity = htmlStr.match(/<span[^>]*class="[^"]*tribe-city[^"]*"[^>]*>([^<]+)<\/span>/i)?.[1]?.trim();
    if (venueName) return { lugar: venueName, ciudad: venueCity || '' };
    // B. <address>: limpiar y separar
    const addrM = htmlStr.match(/<address[^>]*>([\s\S]*?)<\/address>/i);
    if (addrM) {
      const txt = stripHtml(addrM[1])
        .replace(/\+\s*Google\s*Map/gi, '')
        .replace(/\bSpain\b/gi, '')
        .replace(/\s{2,}/g, ' ').trim();
      // Extraer ciudad: palabra(s) antes de "Ciudad , Provincia CP"
      // Patrón: "... Ciudad , Provincia NNNNN"
      // "Calle X  Ciudad , Provincia CP Spain" → ciudad = última palabra antes de la coma
      // Ciudad = texto justo antes de ", Provincia NNNNN"
      const ciudadMatch = txt.match(/([A-ZÁÉÍÓÚÑ\w()][^,]{1,35}?)\s*,\s*[A-ZÁÉÍÓÚÑ][a-záéíóúñA-Z\s]+\s+\d{5}/);
      const ciudad = ciudadMatch ? ciudadMatch[1].trim() : '';
      // Lugar = todo lo anterior a la ciudad (dirección completa)
      let lugar = txt;
      if (ciudad) {
        const idx = txt.lastIndexOf(ciudad);
        if (idx > 0) lugar = txt.substring(0, idx).replace(/[,\s]+$/, '').trim();
      }
      return { lugar: lugar || txt, ciudad };
    }
    return { lugar: '', ciudad: '' };
  }

  if (ld) {
    const loc   = ld.location || {};
    const addr  = loc.address  || {};
    const start = ld.startDate || '';
    let fecha = null, hora = '';
    if (start) {
      try {
        const horaMatch = start.match(/T(\d{2}:\d{2})/);
        hora = horaMatch ? horaMatch[1] : '';
        const fechaStr = start.substring(0, 10);
        fecha = admin.firestore.Timestamp.fromDate(new Date(fechaStr + 'T12:00:00Z'));
      } catch (_) {}
    }
    // Si JSON-LD no tiene fecha, intentar con Google Calendar link
    if (!fecha) {
      const { fechaStr, hora: horaGcal } = parsearFechaHora(html);
      if (fechaStr) {
        hora  = hora || horaGcal;
        fecha = admin.firestore.Timestamp.fromDate(new Date(fechaStr + 'T12:00:00Z'));
      }
    }
    const titulo = stripHtml(ld.name || '') || stripHtml(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/)?.[1] || slug);
    const descLd  = stripHtml(ld.description || '');
    const desc    = [descBody, descLd, ogDesc].reduce((a, b) => b.length > a.length ? b : a, '');
    const ciudad  = addr.addressLocality || addr.addressRegion || extraerLugarCiudad(html).ciudad;
    const lugarNombre = loc.name || extraerLugarCiudad(html).lugar;
    const lugarDir    = addr.streetAddress || '';
    const lugar = lugarNombre && lugarDir && !lugarNombre.includes(lugarDir)
      ? `${lugarNombre}, ${lugarDir}` : lugarNombre || lugarDir;
    const imagen = (Array.isArray(ld.image) ? ld.image[0] : ld.image) || ogImg || '';
    return {
      _slug:       slug, titulo, descripcion: limpiarDesc(desc), fecha, hora,
      lugar, ciudad, imagen_url: imagen,
      tipo: detectarTipo(titulo, desc), libro_titulo: extraerLibro(titulo),
      activo: true, eliminado: false, url_web: url,
    };
  }

  // — Sin JSON-LD: extraer todo desde el HTML (sitio Gutenberg) ────────────
  const titulo = stripHtml(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/)?.[1] || slug);
  const { fechaStr: fechaStrMain, hora } = parsearFechaHora(html);
  // Fallback de fecha: buscar patrón YYYY-MM-DD en la URL de la imagen (ej: 2026-03-20-evento.jpg)
  const fechaStrFinal = fechaStrMain ||
    (ogImg.match(/\/(\d{4}-\d{2}-\d{2})-/) || [])[1] || '';
  let fecha = null;
  if (fechaStrFinal) {
    try { fecha = admin.firestore.Timestamp.fromDate(new Date(fechaStrFinal + 'T12:00:00Z')); } catch(_) {}
  }
  const { lugar, ciudad } = extraerLugarCiudad(html);
  const desc   = descBody || ogDesc;

  return {
    _slug:       slug,
    titulo,
    descripcion: limpiarDesc(desc),
    fecha,
    hora,
    lugar,
    ciudad,
    imagen_url:  ogImg,
    tipo:        detectarTipo(titulo, desc),
    libro_titulo: extraerLibro(titulo),
    activo:      true,
    eliminado:   false,
    url_web:     url,
  };
}

// ── Subir a Firestore ─────────────────────────────────────────────────────────
async function subirEvento(ev) {
  const ref = db.collection('empresas').doc(EID).collection('eventos').doc(ev._slug);
  if (!FORZAR) {
    const snap = await ref.get();
    if (snap.exists) return 'saltado';
  }
  const { _slug, ...doc } = ev;
  await ref.set(doc, { merge: true });
  return 'subido';
}

// ── MAIN ──────────────────────────────────────────────────────────────────────
(async () => {
  console.log(`\n📅 Importando eventos — páginas ${PAGINA_INICIO} a ${PAGINA_FIN}${FORZAR ? ' (--forzar)' : ''}\n`);

  let totalUrls = 0, subidos = 0, saltados = 0, errores = 0;

  for (let pag = PAGINA_INICIO; pag <= PAGINA_FIN; pag++) {
    const listUrl = pag === 1
      ? `${BASE_URL}/eventos/lista/?eventDisplay=past`
      : `${BASE_URL}/eventos/lista/p%C3%A1gina/${pag}/?eventDisplay=past`;

    console.log(`\n── Página ${pag}: ${listUrl}`);
    let listHtml;
    try { listHtml = await fetchHtml(listUrl); }
    catch (e) { console.error(`  ✗ Error cargando listado: ${e.message}`); continue; }

    const urls = extraerUrls(listHtml);
    console.log(`  → ${urls.length} eventos encontrados`);
    totalUrls += urls.length;

    for (const url of urls) {
      await sleep(DELAY_MS);
      const slug = slugDesdeUrl(url);
      try {
        const html = await fetchHtml(url);
        const ev   = parsearDetalle(html, url);
        const res  = await subirEvento(ev);
        if (res === 'subido') {
          subidos++;
          console.log(`  ✓ ${slug}`);
        } else {
          saltados++;
          console.log(`  · ${slug} (ya existe)`);
        }
      } catch (e) {
        errores++;
        console.error(`  ✗ ${slug}: ${e.message}`);
      }
    }
  }

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`Total URLs procesadas: ${totalUrls}`);
  console.log(`  ✓ Subidos:   ${subidos}`);
  console.log(`  · Saltados:  ${saltados}`);
  console.log(`  ✗ Errores:   ${errores}`);
  console.log('');
  process.exit(0);
})();
