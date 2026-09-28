/**
 * enriquecer_autores.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Scrapes individual author profile pages from editorialnazari.com and updates
 * Firestore with bio and photo data for authors that currently lack it.
 *
 * Uso:
 *   cd functions
 *   node scripts/enriquecer_autores.js --dry-run   ← muestra lo que haría
 *   node scripts/enriquecer_autores.js               ← actualiza Firestore
 *   node scripts/enriquecer_autores.js --todos       ← sobreescribe aunque ya tenga datos
 *
 * Requiere: serviceAccountKey.json en functions/
 * ──────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const https  = require('https');
const path   = require('path');
const fs     = require('fs');
const os     = require('os');

const DRY_RUN = process.argv.includes('--dry-run');
const TODOS   = process.argv.includes('--todos');
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BASE    = 'https://www.editorialnazari.com/team/';
const DELAY   = 500; // ms entre peticiones

// ── Firebase ──────────────────────────────────────────────────────────────────
if (!DRY_RUN) {
  const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
  } else {
    function getRefreshToken() {
      const candidates = [
        path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
      ];
      for (const p of candidates) {
        try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); const rt = d?.tokens?.refresh_token; if (rt) return rt; } catch (_) {}
      }
      return null;
    }
    const rt = getRefreshToken();
    if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token Firebase CLI.'); process.exit(1); }
    if (!admin.apps.length) admin.initializeApp({
      credential: admin.credential.refreshToken({ type: 'authorized_user', client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com', client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p', refresh_token: rt }),
      projectId: 'planeaapp-4bea4',
    });
  }
}

// ── Slug desde nombre ──────────────────────────────────────────────────────────
function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[«»,\.]/g, '')
    .replace(/[^a-z0-9\s-]/g, ' ')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

// ── HTTP GET → texto plano ─────────────────────────────────────────────────────
function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'NazariBot/1.0 (enriquecedor interno)' } }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => resolve({ status: res.statusCode, html: raw }));
    }).on('error', err => resolve({ status: 0, html: '' }));
  });
}

// ── Limpia tags HTML ──────────────────────────────────────────────────────────
function stripTags(html) {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>').replace(/&#8217;/g, '’').replace(/&#8220;/g, '«')
    .replace(/&#8221;/g, '»').replace(/&#8230;/g, '…').replace(/&#\d+;/g, '')
    .trim();
}

// ── Extrae bio del HTML ────────────────────────────────────────────────────────
function extraerBio(html) {
  // Buscar el bloque .entry-content
  const contentM = html.match(/<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>([\s\S]*?)<\/div\s*>/i);
  const zone = contentM ? contentM[1] : html;

  // Extraer todos los <p> con texto sustancial
  const texts = [];
  const re = /<p[^>]*>([\s\S]*?)<\/p>/gi;
  let m;
  while ((m = re.exec(zone)) !== null) {
    const t = stripTags(m[1]);
    if (t.length > 60 && !t.toLowerCase().includes('cookies') && !t.toLowerCase().includes('política')) {
      texts.push(t);
    }
  }

  if (!texts.length) return '';

  // Juntar párrafos sustanciales (hasta 800 chars)
  let bio = '';
  for (const t of texts) {
    if ((bio + ' ' + t).length > 800) break;
    bio += (bio ? ' ' : '') + t;
  }
  return bio;
}

// ── Extrae URL de foto del HTML (solo wp-content/uploads, no data: URIs) ──────
function extraerFoto(html) {
  const re = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const src = m[1];
    if (src && src.startsWith('https://') && src.includes('/wp-content/uploads/')) {
      // Preferir imágenes que parecen retratos (no logos, iconos, banners)
      if (!/logo|icon|banner|favicon|arrow|btn|button/i.test(src)) {
        return src;
      }
    }
  }
  return null;
}

// ── Pausa ─────────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🖊  ${DRY_RUN ? '[DRY-RUN] ' : ''}Enriqueciendo autores desde editorialnazari.com...\n`);

  // 1. Leer autores de Firestore
  let autores = [];
  if (!DRY_RUN) {
    const db  = admin.firestore();
    const col = db.collection('empresas').doc(EID).collection('autores');
    const snap = await col.get();
    for (const doc of snap.docs) {
      const d = doc.data();
      if (!d.nombre) continue;
      const sinBio  = !d.bio  || d.bio.length < 10;
      const sinFoto = !d.foto && !d.foto_url;
      if (!TODOS && !sinBio && !sinFoto) continue; // ya tiene datos
      autores.push({ id: doc.id, nombre: d.nombre, data: d });
    }
    console.log(`   Autores sin bio o foto en Firestore: ${autores.length}\n`);
  } else {
    // En dry-run, lista todos los EXTRA_AUTORES como muestra
    const MUESTRA = [
      'David Cidoncha','Ruth Gómez','Óscar Borona','Federico Zurita Martínez',
      'María Alcázar Rodríguez','Enrique Palomo Atance','Pedro Cantero y Esteban Ruiz Ballesteros',
      'Ángel Olgoso','José María García Linares','Miha Mazzini',
      'Miguel Ángel Ulecia Martínez','Juan Naveros Sánchez',
    ];
    autores = MUESTRA.map(n => ({ id: `naz-${toSlug(n)}`, nombre: n, data: {} }));
    console.log(`   [DRY-RUN] Probando con ${autores.length} autores de muestra\n`);
  }

  let ok = 0, sinDatos = 0, errores = 0;
  const db  = !DRY_RUN ? admin.firestore() : null;
  const col = db ? db.collection('empresas').doc(EID).collection('autores') : null;

  let batch    = db ? db.batch() : null;
  let batchCnt = 0;

  async function flushBatch() {
    if (!batch || batchCnt === 0) return;
    await batch.commit();
    batch    = db.batch();
    batchCnt = 0;
  }

  for (const autor of autores) {
    const slug = toSlug(autor.nombre);
    const url  = `${BASE}${slug}/`;

    await sleep(DELAY);

    const { status, html } = await fetchHtml(url);

    if (status !== 200) {
      // Intentar variantes del slug (ej: guiones dobles, caracteres especiales)
      const slug2 = slug.replace(/[^a-z0-9-]/g, '').replace(/-+/g, '-');
      if (slug2 !== slug) {
        const { status: st2, html: h2 } = await fetchHtml(`${BASE}${slug2}/`);
        if (st2 === 200) {
          const bio  = extraerBio(h2);
          const foto = extraerFoto(h2);
          await procesar(autor, bio, foto, `${BASE}${slug2}/`);
          continue;
        }
      }
      console.log(`  ❌ [${status}] ${autor.nombre}`);
      errores++;
      continue;
    }

    const bio  = extraerBio(html);
    const foto = extraerFoto(html);
    await procesar(autor, bio, foto, url);
  }

  await flushBatch();

  console.log(`\n✅ Resultados:`);
  console.log(`   Actualizados:  ${ok}`);
  console.log(`   Sin datos:     ${sinDatos}`);
  console.log(`   Errores HTTP:  ${errores}`);
  if (!DRY_RUN) console.log(`\nDestino: empresas/${EID}/autores`);

  async function procesar(autor, bio, foto, url) {
    const sinBio  = !autor.data.bio  || autor.data.bio.length < 10;
    const sinFoto = !autor.data.foto && !autor.data.foto_url;

    const update = {};
    if (bio  && (sinBio  || TODOS)) {
      update.bio = bio;
      if (!autor.data.descripcion || TODOS) {
        update.descripcion = bio.substring(0, 180) + (bio.length > 180 ? '…' : '');
      }
    }
    if (foto && (sinFoto || TODOS)) update.foto_url = foto;

    const fotoIcon = foto ? '🖼' : '  ';
    const bioInfo  = bio  ? `bio(${bio.length}c)` : 'sin bio';

    if (!Object.keys(update).length) {
      console.log(`  ⚠️  ${autor.nombre} → ${url} → ${bioInfo}, sin foto`);
      sinDatos++;
      return;
    }

    if (DRY_RUN) {
      console.log(`  📋 ${fotoIcon} ${autor.nombre} → ${bioInfo}${foto ? ', foto ✓' : ''}`);
    } else {
      batch.update(col.doc(autor.id), update);
      batchCnt++;
      console.log(`  ✅ ${fotoIcon} ${autor.nombre} → ${Object.keys(update).join(', ')}`);
      ok++;
      if (batchCnt >= 400) await flushBatch();
    }
  }

  process.exit(0);
}

main().catch(e => { console.error('❌', e.message || e); process.exit(1); });
