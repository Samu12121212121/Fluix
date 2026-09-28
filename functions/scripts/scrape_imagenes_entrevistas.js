/**
 * scrape_imagenes_entrevistas.js
 * Busca el og:image de cada entrevista sin imagen y actualiza Firestore.
 *
 * Uso:
 *   node scripts/scrape_imagenes_entrevistas.js           (procesa todas)
 *   node scripts/scrape_imagenes_entrevistas.js --dry-run (solo muestra, no escribe)
 *   node scripts/scrape_imagenes_entrevistas.js --limite 10
 */

const admin = require('firebase-admin');
const fetch = require('node-fetch');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const DRY_RUN = process.argv.includes('--dry-run');
const LIMITE  = (() => {
  const i = process.argv.indexOf('--limite');
  return i !== -1 ? parseInt(process.argv[i + 1]) : Infinity;
})();

// Pausa entre peticiones para no sobrecargar el servidor
const PAUSA_MS = 600;
const sleep = ms => new Promise(r => setTimeout(r, ms));

/* Extrae og:image o primera imagen wp-content del HTML */
function extraerImagen(html, urlBase) {
  // 1. og:image (más fiable)
  const ogMatch = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
                || html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
  if (ogMatch && ogMatch[1] && !ogMatch[1].includes('logo') && ogMatch[1].length > 10)
    return ogMatch[1].trim();

  // 2. Primera imagen de wp-content/uploads en el contenido
  const wpMatch = html.match(/https?:\/\/[^"'\s]+wp-content\/uploads\/[^"'\s]+\.(?:jpg|jpeg|png|webp)/i);
  if (wpMatch) return wpMatch[0];

  // 3. Twitter card
  const twMatch = html.match(/<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i);
  if (twMatch) return twMatch[1].trim();

  return null;
}

async function fetchImagen(url) {
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; NazariBot/1.0)' },
      timeout: 10000,
    });
    if (!res.ok) return null;
    const html = await res.text();
    return extraerImagen(html, url);
  } catch {
    return null;
  }
}

async function main() {
  console.log(`\n${ DRY_RUN ? '[DRY-RUN] ' : ''}Scraping imágenes para entrevistas sin imagen\n`);

  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'entrevista').get();

  const sinImg = snap.docs
    .filter(d => { const x = d.data(); return !x.imagen_url && !x.thumbnail_url; })
    .slice(0, LIMITE);

  console.log(`Encontradas: ${sinImg.length} entrevistas sin imagen\n`);

  let ok = 0, noEncontrada = 0, errores = 0;

  for (let i = 0; i < sinImg.length; i++) {
    const doc  = sinImg[i];
    const data = doc.data();
    const url  = data.url_original || data.url_externa;
    const titulo = (data.titulo || doc.id).substring(0, 60);

    process.stdout.write(`[${String(i+1).padStart(3,'0')}/${sinImg.length}] ${titulo}\n`);

    if (!url) {
      process.stdout.write(`  ⚠ sin URL\n`);
      noEncontrada++;
      continue;
    }

    const imgUrl = await fetchImagen(url);

    if (!imgUrl) {
      process.stdout.write(`  ✗ no se encontró imagen en ${url}\n`);
      noEncontrada++;
    } else {
      process.stdout.write(`  ✓ ${imgUrl.substring(0, 80)}\n`);
      if (!DRY_RUN) {
        try {
          await db.collection('empresas').doc(EID).collection('blog')
            .doc(doc.id).update({ imagen_url: imgUrl });
          ok++;
        } catch (e) {
          process.stdout.write(`  ✗ error al guardar: ${e.message}\n`);
          errores++;
        }
      } else {
        ok++;
      }
    }

    await sleep(PAUSA_MS);
  }

  console.log(`\n══════════════════════════════════════════`);
  console.log(` Procesadas : ${sinImg.length}`);
  console.log(` Con imagen : ${ok}${DRY_RUN ? ' (dry-run, no guardadas)' : ' (guardadas)'}`);
  console.log(` Sin imagen : ${noEncontrada}`);
  console.log(` Errores    : ${errores}`);
  console.log(`══════════════════════════════════════════\n`);
}

main().catch(e => { console.error(e); process.exit(1); });
