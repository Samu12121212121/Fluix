/**
 * importar_payment_links_nazari.js
 * ────────────────────────────────────────────────────────────────────────────
 * Importa los Payment Links de Stripe exportados desde el dashboard de Stripe
 * y los asocia a los documentos correspondientes en catalogo_web de Nazarí.
 *
 * Estrategia de emparejamiento (en orden):
 *   1. slug === libro_id del CSV
 *   2. nombre/titulo normalizado === nombre del CSV normalizado
 *
 * USO:
 *   node scripts/importar_payment_links_nazari.js                 (dry-run)
 *   node scripts/importar_payment_links_nazari.js --apply         (aplica)
 * ────────────────────────────────────────────────────────────────────────────
 */

const admin  = require("../functions/node_modules/firebase-admin");
const fs     = require("fs");
const path   = require("path");

const SERVICE_ACCOUNT = path.join(__dirname, "..", "credentials.json");
const _csvArg         = process.argv.find(a => a.startsWith("--csv="));
const CSV_PATH        = _csvArg ? _csvArg.slice(6) : "C:\\Users\\Samu\\Downloads\\payment_links.csv";
const NAZARI_ID       = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const APPLY           = process.argv.includes("--apply");

admin.initializeApp({ credential: admin.credential.cert(require(SERVICE_ACCOUNT)) });
const db = admin.firestore();

function normalizar(s) {
  return (s || "")
    .toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Parsea CSV respetando campos entre comillas con comas internas */
function parseCSV(text) {
  const lines = text.replace(/\r/g, "").split("\n").filter(l => l.trim());
  const rows = [];
  for (const line of lines) {
    const cols = [];
    let cur = "", inQ = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') { inQ = !inQ; }
      else if (c === ',' && !inQ) { cols.push(cur); cur = ""; }
      else cur += c;
    }
    cols.push(cur);
    rows.push(cols);
  }
  return rows;
}

async function main() {
  console.log(`\n🔗 Payment Links Nazarí — ${APPLY ? "⚡ MODO REAL" : "👁️  DRY-RUN"}\n`);

  const csvText = fs.readFileSync(CSV_PATH, "utf8");
  const rows    = parseCSV(csvText);
  const header  = rows[0];
  const data    = rows.slice(1).filter(r => r.length >= 5);

  // Índices de columnas
  const iUrl     = header.findIndex(h => h.trim().toLowerCase() === "url");
  const iName    = header.findIndex(h => h.trim().toLowerCase() === "name");
  const iLibroId = header.findIndex(h => h.trim().toLowerCase().includes("libro_id"));
  const iActivo  = header.findIndex(h => h.trim().toLowerCase() === "active");

  console.log(`CSV: ${data.length} filas | cols: url=${iUrl} name=${iName} libro_id=${iLibroId}\n`);

  // Cargar todos los docs de catalogo_web
  const snap = await db.collection("empresas").doc(NAZARI_ID).collection("catalogo_web").get();
  const docs = snap.docs.map(d => ({ id: d.id, data: d.data(), ref: d.ref }));
  console.log(`Firestore: ${docs.length} documentos en catalogo_web\n`);

  // Índice por slug y por nombre normalizado
  const bySlug  = new Map();
  const byNombre = new Map();
  for (const doc of docs) {
    const slug = (doc.data.slug || doc.id).toLowerCase().trim();
    bySlug.set(slug, doc);
    const nb = normalizar(doc.data.nombre ?? doc.data.titulo ?? "");
    if (nb) byNombre.set(nb, doc);
  }

  let matched = 0, noMatch = 0, yaTeania = 0;
  const updates = [];

  for (const row of data) {
    const url     = (row[iUrl] || "").trim();
    const slug    = (row[iLibroId] || "").trim().toLowerCase();
    const nombre  = (row[iName] || "").trim();
    const activo  = (row[iActivo] || "").trim().toLowerCase();

    if (!url || activo === "false") continue;

    // Buscar doc
    let doc = bySlug.get(slug);
    if (!doc) doc = byNombre.get(normalizar(nombre));

    if (!doc) {
      console.log(`❌ NO ENCONTRADO: "${nombre}" (slug: ${slug})`);
      noMatch++;
      continue;
    }

    const linkActual = doc.data.payment_link || doc.data.stripe_link || "";
    if (linkActual === url) {
      yaTeania++;
      continue;
    }

    console.log(`✅ MATCH: "${nombre}"\n   slug:${slug} → doc:${doc.id}\n   link: ${url}\n`);
    updates.push({ ref: doc.ref, url, nombre });
    matched++;
  }

  console.log(`─────────────────────────────────────────`);
  console.log(`Encontrados:    ${matched}`);
  console.log(`Ya tenían link: ${yaTeania}`);
  console.log(`No encontrados: ${noMatch}`);
  console.log(`─────────────────────────────────────────\n`);

  if (!APPLY) {
    console.log("👁️  Dry-run. Ejecuta con --apply para guardar.\n");
    process.exit(0);
  }

  if (!updates.length) {
    console.log("Nada que actualizar.\n");
    process.exit(0);
  }

  // Aplicar en batches de 500
  const chunks = [];
  for (let i = 0; i < updates.length; i += 500) chunks.push(updates.slice(i, i + 500));
  for (const chunk of chunks) {
    const batch = db.batch();
    for (const u of chunk) {
      batch.update(u.ref, { payment_link: u.url, stripe_link: u.url });
    }
    await batch.commit();
  }

  console.log(`✅ ${updates.length} payment links guardados en catalogo_web.\n`);
  process.exit(0);
}

main().catch(e => { console.error("❌", e.message); process.exit(1); });
