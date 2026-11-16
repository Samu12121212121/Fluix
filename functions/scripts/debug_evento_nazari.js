/**
 * debug_evento_nazari.js
 * Entra a una URL de evento y pinta TODO lo que puede extraer.
 *
 * Uso:
 *   cd functions
 *   node scripts/debug_evento_nazari.js https://www.editorialnazari.com/evento/el-canto-triste-del-cuervo-en-granada/
 */

const https = require('https');

const url = process.argv[2];
if (!url) {
  console.error('Uso: node scripts/debug_evento_nazari.js <URL>');
  process.exit(1);
}

function fetchHtml(u) {
  return new Promise((resolve, reject) => {
    https.get(u, { headers: { 'User-Agent': 'NazariDebug/1.0', 'Accept': 'text/html' } }, res => {
      if (res.statusCode === 301 || res.statusCode === 302)
        return resolve(fetchHtml(res.headers.location));
      res.setEncoding('utf8');
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve(d));
    }).on('error', reject);
  });
}

function stripHtml(s = '') {
  return s.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
    .replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>')
    .replace(/&quot;/g,'"').replace(/&#8216;/g,'‘').replace(/&#8217;/g,'’')
    .replace(/&#8220;/g,'“').replace(/&#8221;/g,'”').replace(/&hellip;/g,'…')
    .replace(/&ntilde;/g,'ñ').replace(/&aacute;/g,'á').replace(/&eacute;/g,'é')
    .replace(/&iacute;/g,'í').replace(/&oacute;/g,'ó').replace(/&uacute;/g,'ú');
}

function extraerBloque(html, classFragment) {
  const re = new RegExp('<div[^>]+class="[^"]*' + classFragment + '[^"]*"[^>]*>', 'i');
  const m = re.exec(html);
  if (!m) return null;
  let pos = m.index + m[0].length, depth = 1;
  while (pos < html.length && depth > 0) {
    const open  = html.indexOf('<div',  pos);
    const close = html.indexOf('</div>', pos);
    if (close === -1) break;
    if (open !== -1 && open < close) { depth++; pos = open + 4; }
    else { depth--; pos = close + 6; }
  }
  return html.substring(m.index + m[0].length, pos - 6);
}

(async () => {
  console.log('\n🔍 Fetching:', url, '\n');
  const html = await fetchHtml(url);

  // ── 1. JSON-LD ────────────────────────────────────────────────────────────
  console.log('═'.repeat(60));
  console.log('1. JSON-LD  (application/ld+json)');
  console.log('═'.repeat(60));
  const ldRe = /<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi;
  let m, ldEvento = null, ldCount = 0;
  while ((m = ldRe.exec(html)) !== null) {
    ldCount++;
    let obj;
    try { obj = JSON.parse(m[1]); } catch(e) { console.log(`  bloque ${ldCount}: JSON inválido —`, e.message); continue; }
    const tipo = obj['@type'] || (obj['@graph'] ? '@graph' : '?');
    console.log(`  bloque ${ldCount}: @type = ${tipo}`);
    if (obj['@type'] === 'Event') { ldEvento = obj; console.log('  → EVENTO encontrado'); }
    if (Array.isArray(obj['@graph'])) {
      const ev = obj['@graph'].find(x => x['@type'] === 'Event');
      if (ev) { ldEvento = ev; console.log('  → EVENTO en @graph'); }
    }
  }
  if (!ldCount) console.log('  ✗ Ningún bloque JSON-LD encontrado');

  if (ldEvento) {
    console.log('\n  Campos del evento JSON-LD:');
    console.log('  name:       ', ldEvento.name || '—');
    console.log('  startDate:  ', ldEvento.startDate || '—');
    console.log('  endDate:    ', ldEvento.endDate   || '—');
    console.log('  description:', ldEvento.description ? ldEvento.description.substring(0,120)+'…' : '—');
    console.log('  image:      ', ldEvento.image || '—');
    const loc  = ldEvento.location || {};
    const addr = loc.address || {};
    console.log('  location.name:          ', loc.name || '—');
    console.log('  location.address:       ', JSON.stringify(addr));
  }

  // ── 2. Meta tags OG ───────────────────────────────────────────────────────
  console.log('\n' + '═'.repeat(60));
  console.log('2. Meta tags OpenGraph');
  console.log('═'.repeat(60));
  const metas = {
    'og:title':       html.match(/<meta[^>]+property="og:title"[^>]+content="([^"]+)"/)?.[1]
                   || html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:title"/)?.[1],
    'og:description': html.match(/<meta[^>]+property="og:description"[^>]+content="([^"]+)"/)?.[1]
                   || html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:description"/)?.[1],
    'og:image':       html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/)?.[1]
                   || html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:image"/)?.[1],
  };
  for (const [k, v] of Object.entries(metas))
    console.log(`  ${k.padEnd(20)}: ${v || '—'}`);

  // ── 3. Bloque de descripción HTML ─────────────────────────────────────────
  console.log('\n' + '═'.repeat(60));
  console.log('3. Búsqueda de descripción por clases CSS');
  console.log('═'.repeat(60));
  const bloques = [
    'tribe-events-content', 'tribe-events-single-section', 'tribe_events_cat',
    'entry-content', 'wp-block-group', 'post-content', 'article-content',
    'singular-content', 'main-content', 'page-content',
  ];
  for (const cls of bloques) {
    const raw = extraerBloque(html, cls);
    if (raw) {
      const txt = stripHtml(raw);
      console.log(`\n  ✓ Clase "${cls}" (${txt.length} chars):`);
      console.log('  ' + txt.substring(0, 300) + (txt.length > 300 ? '…' : ''));
    } else {
      console.log(`  ✗ "${cls}": no encontrada`);
    }
  }

  // Todos los <p> del documento como fallback
  console.log('\n  — Párrafos <p> con más de 80 chars encontrados en la página:');
  const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let pCount = 0;
  while ((m = pRe.exec(html)) !== null && pCount < 8) {
    const txt = stripHtml(m[1]);
    if (txt.length > 80) {
      console.log(`  [p${++pCount}] ${txt.substring(0,200)}${txt.length>200?'…':''}`);
    }
  }

  // Estructura de la <article> o <main>
  const articleMatch = html.match(/<article[^>]*class="([^"]+)"/i);
  if (articleMatch) console.log(`\n  <article> class: "${articleMatch[1]}"`);
  const mainMatch = html.match(/<main[^>]*class="([^"]+)"/i);
  if (mainMatch) console.log(`  <main> class:    "${mainMatch[1]}"`);

  // Todas las clases de divs del contenido principal
  console.log('\n  Clases de divs encontrados en la página (primeros 15):');
  const divRe = /<div[^>]+class="([^"]+)"/gi;
  const divClases = new Set();
  while ((m = divRe.exec(html)) !== null && divClases.size < 15) {
    m[1].split(/\s+/).forEach(c => { if(c && !c.startsWith('wp-block') && divClases.size<15) divClases.add(c); });
  }
  [...divClases].forEach(c => console.log(`    .${c}`));

  // ── 4. Todos los <img> de la página ──────────────────────────────────────
  console.log('\n' + '═'.repeat(60));
  console.log('4. Imágenes encontradas en la página');
  console.log('═'.repeat(60));
  const imgRe = /<img[^>]+src="([^"]+)"/gi;
  const imgs = new Set();
  while ((m = imgRe.exec(html)) !== null) {
    const src = m[1];
    if (src.includes('wp-content/uploads')) imgs.add(src);
  }
  if (imgs.size === 0) console.log('  — ninguna imagen wp-content/uploads');
  [...imgs].forEach(i => console.log(' ', i));

  // ── 5. datetime attributes ────────────────────────────────────────────────
  console.log('\n' + '═'.repeat(60));
  console.log('5. Atributos datetime en el HTML');
  console.log('═'.repeat(60));
  const dtRe = /datetime="([^"]+)"/g;
  let dtFound = false;
  while ((m = dtRe.exec(html)) !== null) {
    console.log(' ', m[1]);
    dtFound = true;
  }
  if (!dtFound) console.log('  — ninguno encontrado');
  // Formato compacto Google Calendar
  const gcal = html.match(/datetime="(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
  if (gcal) {
    const [,y,mo,d,h,mi] = gcal;
    console.log(`  → Google Calendar format detectado: ${y}-${mo}-${d} ${h}:${mi}`);
  }

  // ── 6. Resumen: lo que importaría el script (lógica real con todos los fallbacks)
  console.log('\n' + '═'.repeat(60));
  console.log('6. ✅ LO QUE SE IMPORTARÍA A FIRESTORE (lógica completa)');
  console.log('═'.repeat(60));

  // Título: JSON-LD → H1
  const titulo6 = stripHtml(ldEvento?.name || '') ||
    stripHtml(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/)?.[1] || '') || '—';

  // Fecha y hora: JSON-LD → Google Calendar datetime → ISO datetime
  let fecha6 = '—', hora6 = '—';
  const startLd = ldEvento?.startDate || '';
  if (startLd) {
    const hm = startLd.match(/T(\d{2}:\d{2})/);
    hora6   = hm ? hm[1] : '—';
    fecha6  = startLd.substring(0, 10);
  } else {
    // href Google Calendar: dates=20260320T200000/...
    const gcalHref = html.match(/dates=(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
    if (gcalHref) {
      const [,y,mo,d,h,mi] = gcalHref;
      fecha6 = `${y}-${mo}-${d}`; hora6 = `${h}:${mi}`;
    } else {
      const gcal2 = html.match(/datetime="(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
      if (gcal2) { const [,y,mo,d,h,mi] = gcal2; fecha6=`${y}-${mo}-${d}`; hora6=`${h}:${mi}`; }
      else {
        const iso2 = html.match(/datetime="(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
        if (iso2) { fecha6 = iso2[1]; hora6 = iso2[2]; }
      }
    }
  }

  // Descripción: misma lógica que el importador
  let descBodyBest = '';
  for (const cls of ['tribe-events-content','entry-content','post-content','singular-content']) {
    const raw = extraerBloque(html, cls);
    if (raw && raw.length > 100) { descBodyBest = raw; break; }
  }
  if (!descBodyBest) {
    const gcalIdx = html.indexOf('google.com/calendar');
    const addrIdx = html.search(/<address[\s>]/i);
    if (gcalIdx > 0) {
      const fin = addrIdx > gcalIdx ? addrIdx : html.length;
      const seccion = html.substring(gcalIdx, fin);
      const ps2 = []; const pRe2 = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm2;
      while ((pm2 = pRe2.exec(seccion)) !== null) {
        const t = stripHtml(pm2[1]).trim(); if (t.length > 40) ps2.push(t);
      }
      if (ps2.length > 0) { descBodyBest = ps2.join('\n\n'); console.log(`  — Extraídos ${ps2.length} <p> entre gcal link y <address>`); }
    }
  }
  if (!descBodyBest) {
    // <p> solo entre <h1> y <address> para evitar tagline del site
    const h1Idx6 = html.search(/<h1[\s>]/i);
    const addrIdx6 = html.search(/<address[\s>]/i);
    const desde6 = h1Idx6 > 0 ? h1Idx6 : 0;
    const hasta6 = addrIdx6 > desde6 ? addrIdx6 : html.length;
    const sec6 = html.substring(desde6, hasta6);
    const ps3 = []; const pRe3 = /<p[^>]*>([\s\S]*?)<\/p>/gi; let pm3;
    while ((pm3 = pRe3.exec(sec6)) !== null) {
      const t = stripHtml(pm3[1]).trim(); if (t.length > 40) ps3.push(t);
    }
    descBodyBest = ps3.join('\n\n');
    console.log(`  — Fallback h1→address: ${ps3.length} <p> encontrados`);
  }
  const BOILERPLATE = ['Narrativa, poesía, relato','Editorial Nazarí encontrarás','amamos los libros','« Todos los Eventos','Todos los Eventos Este evento'];
  function limpiarDesc6(t=''){return t.split('\n\n').filter(p=>!BOILERPLATE.some(m=>p.includes(m))).join('\n\n').trim();}
  const descLd6   = limpiarDesc6(stripHtml(ldEvento?.description || ''));
  const descOg6   = limpiarDesc6(stripHtml(metas['og:description'] || ''));
  const descBody6 = limpiarDesc6(descBodyBest); // ya viene limpio de stripHtml por párrafos
  const desc6     = [descBody6, descLd6, descOg6].reduce((a,b) => b.length > a.length ? b : a, '');

  // Lugar y ciudad: JSON-LD → tribe → address → texto libre
  const loc6  = ldEvento?.location || {};
  const addr6 = loc6.address || {};
  let lugar6  = loc6.name || (html.match(/<span[^>]*class="[^"]*tribe-venue[^"]*"[^>]*>([^<]+)<\/span>/i)?.[1]?.trim()) || '';
  let ciudad6 = addr6.addressLocality || (html.match(/<span[^>]*class="[^"]*tribe-city[^"]*"[^>]*>([^<]+)<\/span>/i)?.[1]?.trim()) || '';
  const addrEl = html.match(/<address[^>]*>([\s\S]*?)<\/address>/i);
  if (addrEl && (!lugar6 || !ciudad6)) {
    const addrTxt = stripHtml(addrEl[1]).replace(/\+\s*Google\s*Map/gi,'').replace(/\bSpain\b/gi,'').replace(/\s{2,}/g,' ').trim();
    const anteComa = addrTxt.split(',')[0].trim();
    const pals = anteComa.split(/\s+/).filter(Boolean);
    if (!ciudad6) ciudad6 = pals.slice(-1).join(' ');
    if (!lugar6)  lugar6  = pals.slice(0,-1).join(' ') || anteComa;
  }

  // Imagen
  const img6 = ldEvento ? ((Array.isArray(ldEvento.image)?ldEvento.image[0]:ldEvento.image)||metas['og:image']||'') : (metas['og:image']||'');

  console.log('  titulo:      ', titulo6);
  console.log('  fecha:       ', fecha6);
  console.log('  hora:        ', hora6);
  console.log('  lugar:       ', lugar6 || '—');
  console.log('  ciudad:      ', ciudad6 || '—');
  console.log('  imagen_url:  ', img6 || '—');
  console.log(`  desc fuentes → body: ${descBody6.length}c | ld: ${descLd6.length}c | og: ${descOg6.length}c`);
  console.log('  desc chars:  ', desc6.length);
  console.log('  descripcion: ');
  console.log('  ' + desc6.substring(0, 600) + (desc6.length > 600 ? '\n  …' : ''));
  console.log('');
})();
