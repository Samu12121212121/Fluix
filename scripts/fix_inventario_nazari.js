/**
 * fix_inventario_nazari.js
 * ────────────────────────────────────────────────────────────────────────────
 * 1. Lee todos los docs de empresas/NAZARI_ID/catalogo
 * 2. Detecta duplicados por nombre (normalizado)
 * 3. Por cada grupo de duplicados: conserva el que tiene más datos, borra el resto
 * 4. Pone stock = 10 en TODOS los documentos restantes
 *
 * USO (modo dry-run, solo imprime lo que haría):
 *   node scripts/fix_inventario_nazari.js
 *
 * USO (modo real, aplica cambios):
 *   node scripts/fix_inventario_nazari.js --apply
 * ────────────────────────────────────────────────────────────────────────────
 */

const admin = require("../functions/node_modules/firebase-admin");
const path  = require("path");

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "..", "credentials.json");
const NAZARI_ID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const APPLY = process.argv.includes("--apply");

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});
const db = admin.firestore();

function normalizar(nombre) {
  return (nombre || "")
    .toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")  // quitar tildes
    .replace(/[^a-z0-9]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Puntúa un doc según cuántos campos relevantes tiene (para quedarnos con el más completo) */
function puntuacion(data) {
  let p = 0;
  if (data.nombre)       p++;
  if (data.descripcion)  p++;
  if (data.imagen_url)   p++;
  if (data.precio)       p++;
  if (data.stock != null) p++;
  if (data.stripe_product_id) p += 2;
  if (data.payment_link) p += 2;
  if (data.stripe_price_id)   p++;
  return p;
}

async function main() {
  console.log(`\n📦 Inventario Nazarí — ${APPLY ? "⚡ MODO REAL" : "👁️  DRY-RUN (añade --apply para aplicar)"}\n`);

  const snap = await db.collection("empresas").doc(NAZARI_ID).collection("catalogo").get();
  const docs = snap.docs.map(d => ({ id: d.id, data: d.data(), ref: d.ref }));

  console.log(`Total documentos leídos: ${docs.length}\n`);

  // Agrupar por nombre normalizado
  const grupos = new Map();
  for (const doc of docs) {
    const key = normalizar(doc.data.nombre);
    if (!key) { grupos.set(`__sin_nombre_${doc.id}`, [doc]); continue; }
    if (!grupos.has(key)) grupos.set(key, []);
    grupos.get(key).push(doc);
  }

  const duplicados = [...grupos.values()].filter(g => g.length > 1);
  const unicos     = [...grupos.values()].filter(g => g.length === 1);

  console.log(`Grupos únicos:     ${unicos.length}`);
  console.log(`Grupos duplicados: ${duplicados.length}`);

  let totalBorrar = 0;
  const aBorrar = [];
  const aConservar = [];

  for (const grupo of duplicados) {
    // Ordenar: más puntuación primero → conservamos ese
    grupo.sort((a, b) => puntuacion(b.data) - puntuacion(a.data));
    const [conservar, ...borrar] = grupo;
    aConservar.push(conservar);
    aBorrar.push(...borrar);
    totalBorrar += borrar.length;

    console.log(`\n🔁 DUPLICADO: "${conservar.data.nombre}"`);
    console.log(`   ✅ Conservar: ${conservar.id} (puntos: ${puntuacion(conservar.data)})`);
    for (const b of borrar) {
      console.log(`   🗑️  Borrar:    ${b.id} (puntos: ${puntuacion(b.data)})`);
    }
  }

  // Docs a actualizar stock = 10 (todos los que quedan)
  const docsFinales = [
    ...unicos.map(g => g[0]),
    ...aConservar,
  ];

  console.log(`\n─────────────────────────────────────────`);
  console.log(`Documentos a conservar: ${docsFinales.length}`);
  console.log(`Documentos a borrar:    ${totalBorrar}`);
  console.log(`Stock final en todos:   10`);
  console.log(`─────────────────────────────────────────\n`);

  if (!APPLY) {
    console.log("👁️  Dry-run completado. Ejecuta con --apply para aplicar los cambios.\n");
    process.exit(0);
  }

  // ── APLICAR ──────────────────────────────────────────────────────────────

  // 1. Borrar duplicados en batches de 500
  if (aBorrar.length > 0) {
    console.log(`🗑️  Borrando ${aBorrar.length} duplicados...`);
    const chunks = [];
    for (let i = 0; i < aBorrar.length; i += 500) chunks.push(aBorrar.slice(i, i + 500));
    for (const chunk of chunks) {
      const batch = db.batch();
      for (const doc of chunk) batch.delete(doc.ref);
      await batch.commit();
    }
    console.log(`   ✅ ${aBorrar.length} duplicados eliminados.`);
  }

  // 2. Poner stock = 10 en todos los documentos restantes
  console.log(`📦 Poniendo stock = 10 en ${docsFinales.length} productos...`);
  const chunks2 = [];
  for (let i = 0; i < docsFinales.length; i += 500) chunks2.push(docsFinales.slice(i, i + 500));
  for (const chunk of chunks2) {
    const batch = db.batch();
    for (const doc of chunk) batch.update(doc.ref, { stock: 10 });
    await batch.commit();
  }
  console.log(`   ✅ Stock actualizado.`);

  console.log(`\n✅ COMPLETADO: ${docsFinales.length} productos, stock = 10, ${totalBorrar} duplicados eliminados.\n`);
  process.exit(0);
}

main().catch(e => { console.error("❌ Error:", e); process.exit(1); });
