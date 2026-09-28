'use strict';

/**
 * test_autores_preview.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Script de prueba (solo lectura, no modifica nada).
 *
 * Coge 5 autores cuyo nombre queda alfabéticamente después de la 'M',
 * muestra para cada uno:
 *   - Posición en el orden alfabético final
 *   - Lo que hay actualmente en autores-data.js  (rol, bio, etiquetas)
 *   - Lo que dice la web oficial de Nazarí       (rol, bio completa, etiquetas)
 *
 * Uso:
 *   cd functions
 *   node scripts/test_autores_preview.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https = require('https');
const http  = require('http');
const path  = require('path');
const fs    = require('fs');
const os    = require('os');
const vm    = require('vm');

const HTML_DIR = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');
const BASE     = 'https://www.editorialnazari.com/team/';
const DELAY    = 800; // ms entre peticiones

// ── Cargar autores-data.js ─────────────────────────────────────────────────────
function loadAutoresData() {
  const filePath = path.join(HTML_DIR, 'autores-data.js');
  if (!fs.existsSync(filePath)) {
    console.error(`❌ No encontrado: ${filePath}`);
    process.exit(1);
  }
  let code = fs.readFileSync(filePath, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx['AUTORES'] || [];
}

// ── Normalizar texto para comparación/slug ──────────────────────────────────
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

// ── HTTP GET con seguimiento de redirecciones (max 3) ──────────────────────────
function fetchHtml(url, redirectsLeft = 3) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https') ? https : http;
    try {
      lib.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 NazariBotTest/1.0',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        }
      }, res => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && redirectsLeft > 0) {
          const loc = res.headers.location.startsWith('http')
            ? res.headers.location
            : new URL(res.headers.location, url).href;
          res.resume();
          return fetchHtml(loc, redirectsLeft - 1).then(resolve);
        }
        let raw = '';
        res.setEncoding('utf8');
        res.on('data', c => raw += c);
        res.on('end', () => resolve({ status: res.statusCode, html: raw, finalUrl: url }));
      }).on('error', err => resolve({ status: 0, html: '', finalUrl: url, error: err.message }));
    } catch (e) {
      resolve({ status: 0, html: '', finalUrl: url, error: e.message });
    }
  });
}

// ── Decodificar entidades HTML ────────────────────────────────────────────────
function decodeEntities(s) {
  return s
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&#8217;/g, '’').replace(/&#8216;/g, '‘')
    .replace(/&#8220;/g, '“').replace(/&#8221;/g, '”')
    .replace(/&#8230;/g, '…').replace(/&#8212;/g, '—')
    .replace(/&#8211;/g, '–').replace(/&#160;/g, ' ')
    .replace(/&#\d+;/g, ' ');
}

function stripTags(html) {
  return decodeEntities(html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ')).trim();
}

// ── Extraer ROL del HTML ───────────────────────────────────────────────────────
// Busca: subtítulo de perfil, primer párrafo corto con palabra clave de rol,
// o metadatos de tipo WordPress team member.
function extraerRol(html) {
  const ROL_RE = /\b(autor[a]?|ilustrador[a]?|editor[a]?|traductor[a]?|prologuista|coordinador[a]?|compilador[a]?)\b/i;

  // 1. Clase típica de job-title / cargo en temas WordPress/Divi/Elementor
  const jobClasses = /(?:job.?title|position|cargo|role|subtitle|subtitle-team|team.?role|member.?position)/i;
  const jobRe = new RegExp(
    '<(?:span|p|div|h[1-6])[^>]*class="[^"]*' + jobClasses.source + '[^"]*"[^>]*>([\\s\\S]*?)</(?:span|p|div|h[1-6])>',
    'i'
  );
  const jobM = html.match(jobRe);
  if (jobM) {
    const t = stripTags(jobM[1]).trim();
    if (t.length > 0 && t.length < 100) return t;
  }

  // 2. Zona entry-content: primer <h2>/<h3>/<h4> que sea un rol
  const entryZone = (() => {
    const m = html.match(/<(?:div|article)[^>]*class="[^"]*entry.?content[^"]*"[^>]*>([\s\S]*)/i);
    return m ? m[1] : html;
  })();

  const headingRe = /<h[2-4][^>]*>([\s\S]*?)<\/h[2-4]>/gi;
  let hm;
  while ((hm = headingRe.exec(entryZone)) !== null) {
    const t = stripTags(hm[1]).trim();
    if (t.length > 0 && t.length < 80 && ROL_RE.test(t)) return t;
  }

  // 3. Primer <p> muy corto (< 60 chars) que contenga palabra de rol
  const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let pm;
  while ((pm = pRe.exec(entryZone)) !== null) {
    const t = stripTags(pm[1]).trim();
    if (t.length > 0 && t.length < 60 && ROL_RE.test(t)) return t;
  }

  // 4. Metabox o custom field "role" en WordPress
  const metaRe = /<(?:span|td|div)[^>]*(?:data-key|name)="role"[^>]*>([\s\S]*?)<\/(?:span|td|div)>/i;
  const metaM = html.match(metaRe);
  if (metaM) {
    const t = stripTags(metaM[1]).trim();
    if (t.length > 0 && t.length < 80) return t;
  }

  return '';
}

// ── Extraer BIO COMPLETA del HTML ─────────────────────────────────────────────
// Recoge TODOS los párrafos de la zona de contenido principal, sin límite de chars.
function extraerBioCompleta(html) {
  // Aislar la zona de contenido principal (entry-content o similar)
  const contentRe = /<(?:div|article)[^>]*class="[^"]*(?:entry.?content|post.?content|article.?content)[^"]*"[^>]*>([\s\S]*)/i;
  const contentM = html.match(contentRe);
  const zone = contentM ? contentM[1] : html;

  const textos = [];
  const pRe = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let pm;
  while ((pm = pRe.exec(zone)) !== null) {
    const t = stripTags(pm[1]).trim();
    // Filtrar párrafos de sistema: cookies, nav, meta vacías
    if (
      t.length >= 40 &&
      !/(?:cookie|política de privacidad|aviso legal|newsletter|suscri)/i.test(t)
    ) {
      textos.push(t);
    }
  }

  // También capturar bloques <div> con texto largo si no hay <p>
  if (textos.length === 0) {
    const divRe = /<div[^>]*>([\s\S]*?)<\/div>/gi;
    let dm;
    while ((dm = divRe.exec(zone)) !== null) {
      const t = stripTags(dm[1]).trim();
      if (t.length >= 100 && !/(?:cookie|política)/i.test(t)) {
        textos.push(t);
        if (textos.length >= 3) break;
      }
    }
  }

  return textos.join('\n\n');
}

// ── Extraer ETIQUETAS del HTML ────────────────────────────────────────────────
// Busca en múltiples lugares: post-terms, rel="tag", /tag/ URLs, categorías.
function extraerEtiquetas(html) {
  const vistas = new Set();
  const tags   = [];

  function addTag(raw) {
    const t = stripTags(raw).trim();
    if (t.length === 0 || t.length > 80) return;
    // Normalizar: puede venir "Narrativa / Poesía" → dividir
    const partes = t.split(/[,\/;|]/).map(p => p.trim()).filter(p => p.length > 0);
    for (const p of partes) {
      const key = norm(p);
      if (!vistas.has(key)) {
        vistas.add(key);
        tags.push(p);
      }
    }
  }

  // 1. Bloques post-terms (Gutenberg block editor)
  const termsBlockRe = /<(?:p|div|span)[^>]*class="[^"]*(?:wp-block-post-terms|post-tags|entry-tags|tag-links|tag-cloud|terms)[^"]*"[^>]*>([\s\S]*?)<\/(?:p|div|span)>/gi;
  let tbm;
  while ((tbm = termsBlockRe.exec(html)) !== null) {
    const aRe = /<a[^>]*>([\s\S]*?)<\/a>/gi;
    let am;
    while ((am = aRe.exec(tbm[1])) !== null) addTag(am[1]);
  }

  // 2. Cualquier <a> con rel="tag"
  const relTagRe = /<a[^>]+rel="[^"]*tag[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
  let rtm;
  while ((rtm = relTagRe.exec(html)) !== null) addTag(rtm[1]);

  // 3. Links cuya URL contiene /tag/ o /etiqueta/
  const tagUrlRe = /<a[^>]+href="[^"]*\/(?:tag|etiqueta)\/[^"]*"[^>]*>([\s\S]*?)<\/a>/gi;
  let tum;
  while ((tum = tagUrlRe.exec(html)) !== null) addTag(tum[1]);

  // 4. Links a URLs de género/categoría típicos en Nazarí
  //    (narrativa, poesia, relato, ilustracion, traduccion, ensayo, etc.)
  const genreUrlRe = /<a[^>]+href="[^"]*\/(?:narrativa|poesia|poesía|relato|ilustracion|ilustración|traduccion|traducción|microrrelato|ensayo|teatro|novela|infantil|juvenil|comic|cómic|categoria|category)[^/"]*\/"[^>]*>([\s\S]*?)<\/a>/gi;
  let gm;
  while ((gm = genreUrlRe.exec(html)) !== null) addTag(gm[1]);

  // 5. Clase "cat-links" o "tags-links" (temas clásicos WordPress)
  const catLinksRe = /<(?:span|div)[^>]*class="[^"]*(?:cat-links|tags-links|genre-links)[^"]*"[^>]*>([\s\S]*?)<\/(?:span|div)>/gi;
  let clm;
  while ((clm = catLinksRe.exec(html)) !== null) {
    const aRe2 = /<a[^>]*>([\s\S]*?)<\/a>/gi;
    let am2;
    while ((am2 = aRe2.exec(clm[1])) !== null) addTag(am2[1]);
  }

  return tags;
}

// ── Pausa ──────────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Wrap texto largo para consola ─────────────────────────────────────────────
function wrapText(text, width = 72, indent = '       ') {
  if (!text) return `${indent}(vacío)`;
  const words  = text.split(/\s+/);
  const lines  = [];
  let current  = '';
  for (const w of words) {
    if (current.length + w.length + 1 > width) {
      lines.push(current);
      current = w;
    } else {
      current = current ? current + ' ' + w : w;
    }
  }
  if (current) lines.push(current);
  return lines.map(l => indent + l).join('\n');
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n' + '═'.repeat(80));
  console.log(' 🔍  TEST PREVIEW — autores > M | autores-data.js vs web Nazarí');
  console.log('     Solo lectura. No modifica nada.');
  console.log('═'.repeat(80) + '\n');

  const autores = loadAutoresData();
  console.log(`📄 ${autores.length} autores cargados de autores-data.js\n`);

  // Ordenar alfabéticamente por nombre normalizado (sin acentos, minúsculas)
  const sorted = [...autores].sort((a, b) =>
    norm(a.nombre).localeCompare(norm(b.nombre), 'es')
  );

  // Asignar posición alfabética final
  sorted.forEach((a, i) => { a._posAlfa = i + 1; });

  // Filtrar los que vienen DESPUÉS de M (inicial > 'm')
  const despuesDeM = sorted.filter(a => {
    const ini = norm(a.nombre).charAt(0);
    return ini > 'm';
  });

  console.log(`📋 Autores con nombre > M: ${despuesDeM.length} (de ${sorted.length} total)`);
  console.log(`   Probando con los primeros 5:\n`);
  despuesDeM.slice(0, 5).forEach((a, i) => {
    console.log(`   ${i + 1}. "${a.nombre}"  [#${a._posAlfa} alfabético]`);
  });
  console.log();

  const muestra = despuesDeM.slice(0, 5);

  for (const autor of muestra) {
    const slug = toSlug(autor.nombre);
    const url  = `${BASE}${slug}/`;

    console.log('\n' + '─'.repeat(80));
    console.log(`\n👤  ${autor.nombre}`);
    console.log(`    Posición alfabética: #${autor._posAlfa} de ${sorted.length}`);
    console.log(`    URL: ${url}`);

    // ── Estado actual ──────────────────────────────────────────────────────────
    console.log('\n  📁  ACTUAL (autores-data.js):');
    // El campo 'genero' en autores-data.js se usa como etiqueta de género temático.
    // No hay campo 'rol' — eso es justo lo que falta.
    const bioActual  = autor.bio || '';
    const descActual = autor.descripcion || '';
    const genActual  = autor.genero || '';

    console.log(`      rol:       (campo no existe aún)`);
    console.log(`      genero:    "${genActual}"`);
    console.log(`      bio (${bioActual.length}c):`);
    console.log(wrapText(bioActual || descActual || '(vacío)', 72));
    console.log(`      etiquetas: ${genActual ? JSON.stringify([genActual]) : '[]'}`);
    console.log(`                 ← solo 1 etiqueta (completado a mano)`);

    await sleep(DELAY);

    // ── Fetch web ──────────────────────────────────────────────────────────────
    console.log(`\n  🌐  WEB (fetching…)`);
    let result = await fetchHtml(url);

    // Intentar slug alternativo si falla
    if (result.status !== 200) {
      const slug2 = slug.replace(/[aeiou]/g, match => {
        // Variante: eliminar acentos ya normalizados (ya lo hace norm), probar sin guiones dobles
        return match;
      });
      // Intentar sin la última parte del apellido compuesto
      const partes = slug.split('-');
      if (partes.length > 2) {
        const slugCorto = partes.slice(0, 2).join('-');
        const r2 = await fetchHtml(`${BASE}${slugCorto}/`);
        if (r2.status === 200) {
          result = { ...r2, _altUrl: `${BASE}${slugCorto}/` };
        }
      }
    }

    if (result.status !== 200) {
      console.log(`      ❌ HTTP ${result.status}${result.error ? ' — ' + result.error : ''}`);
      console.log(`         URL: ${url}`);
      if (result.status === 0) {
        console.log(`         (Sin conexión o servidor no responde)`);
      } else {
        console.log(`         → Comprobar slug manualmente en la web`);
      }
      continue;
    }

    if (result._altUrl) {
      console.log(`      ℹ️  Respondió en URL alternativa: ${result._altUrl}`);
    }

    const rolWeb  = extraerRol(result.html);
    const bioWeb  = extraerBioCompleta(result.html);
    const tagsWeb = extraerEtiquetas(result.html);

    console.log('\n  🌐  WEB OFICIAL (editorialnazari.com):');
    console.log(`      rol detectado: "${rolWeb || '(no encontrado — ver nota abajo)'}"`);
    console.log(`      bio completa (${bioWeb.length}c):`);
    if (bioWeb.length > 0) {
      console.log(wrapText(bioWeb, 72));
    } else {
      console.log(`       (no encontrada)`);
    }
    console.log(`      etiquetas (${tagsWeb.length}): ${JSON.stringify(tagsWeb)}`);

    // ── Comparación ────────────────────────────────────────────────────────────
    console.log('\n  📊  DIFERENCIAS:');

    // Bio
    if (bioWeb.length === 0) {
      console.log(`      bio:      ⚠️  No se extrajo bio de la web`);
    } else if (bioActual.length === 0) {
      console.log(`      bio:      ⚠️  Vacía en local → web tiene ${bioWeb.length}c`);
    } else {
      const diff = bioWeb.length - bioActual.length;
      const pct  = Math.round((diff / Math.max(bioActual.length, 1)) * 100);
      if (Math.abs(diff) < 30) {
        console.log(`      bio:      ✅  Longitudes similares (local ${bioActual.length}c, web ${bioWeb.length}c)`);
      } else {
        console.log(`      bio:      ⚠️  Local ${bioActual.length}c → Web ${bioWeb.length}c (${diff > 0 ? '+' : ''}${diff}c, ${pct > 0 ? '+' : ''}${pct}%)`);
      }
    }

    // Rol
    if (!rolWeb) {
      console.log(`      rol:      ℹ️  No detectado automáticamente`);
      console.log(`                → Puede estar en subtítulo, primer h2, o no visible en HTML`);
    } else {
      console.log(`      rol:      → "${rolWeb}" (campo nuevo a añadir)`);
    }

    // Etiquetas
    if (tagsWeb.length === 0) {
      console.log(`      etiquetas: ℹ️  No detectadas automáticamente`);
      console.log(`                 → Pueden estar en categorías WP o no publicadas en HTML`);
    } else {
      const ahora = genActual ? [genActual] : [];
      const nuevas = tagsWeb.filter(t => !ahora.map(norm).includes(norm(t)));
      console.log(`      etiquetas: actual [${ahora.join(', ')}] → web [${tagsWeb.join(', ')}]`);
      if (nuevas.length > 0) {
        console.log(`                 ${nuevas.length} etiqueta(s) nueva(s): [${nuevas.join(', ')}]`);
      } else {
        console.log(`                 ✅ Sin etiquetas nuevas detectadas`);
      }
    }

    // Nota si rol no detectado — mostrar candidatos del HTML para diagnóstico
    if (!rolWeb) {
      console.log('\n  🔬  DIAGNÓSTICO ROL (candidatos brutos del HTML):');
      const candidatos = [];

      // h1-h4 del body
      const hRe2 = /<h[1-4][^>]*>([\s\S]*?)<\/h[1-4]>/gi;
      let hm2;
      while ((hm2 = hRe2.exec(result.html)) !== null) {
        const t = stripTags(hm2[1]).trim();
        if (t.length > 0 && t.length < 120 && norm(t) !== norm(autor.nombre)) {
          candidatos.push(`h-tag: "${t}"`);
        }
        if (candidatos.length >= 6) break;
      }

      // Primeros 3 <p> del entry-content
      const entryZ2 = (() => {
        const m = result.html.match(/<(?:div|article)[^>]*class="[^"]*entry.?content[^"]*"[^>]*>([\s\S]*)/i);
        return m ? m[1] : '';
      })();
      if (entryZ2) {
        const pRe2 = /<p[^>]*>([\s\S]*?)<\/p>/gi;
        let pm2; let cnt = 0;
        while ((pm2 = pRe2.exec(entryZ2)) !== null && cnt < 3) {
          const t = stripTags(pm2[1]).trim();
          if (t.length > 0 && t.length < 150) { candidatos.push(`p: "${t.substring(0, 100)}"`); cnt++; }
        }
      }

      if (candidatos.length > 0) {
        candidatos.forEach(c => console.log(`      ${c}`));
      } else {
        console.log(`      (sin candidatos — entry-content no detectado o página vacía)`);
      }
    }
  }

  console.log('\n\n' + '═'.repeat(80));
  console.log(' ✅  Test completado. Cero modificaciones realizadas.');
  console.log('     Si los datos se ven correctos, confirma para ejecutar el');
  console.log('     script completo con backup + validación + rollback.');
  console.log('═'.repeat(80) + '\n');
}

main().catch(e => {
  console.error('\n❌ Error inesperado:', e.message || e);
  process.exit(1);
});
