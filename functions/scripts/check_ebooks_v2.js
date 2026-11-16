const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  // 1. Ver todos los tokens de descarga generados
  const tokens = await db.collection("empresas").doc(EID)
    .collection("descargas_ebook").get();
  console.log(`=== Tokens de descarga generados: ${tokens.size} ===`);
  for (const t of tokens.docs) {
    const d = t.data();
    console.log(`  ${d.email_comprador} — ${d.libro_titulo} — activo:${d.activo} — descargas:${d.descargas_realizadas}/${d.max_descargas}`);
  }

  // 2. Pedidos pagados con items que tienen es_ebook=true
  const pedidos = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari")
    .where("estado_pago", "==", "pagado").get();

  console.log(`\n=== Pedidos PAGADOS (${pedidos.size} total) — revisando items ebook ===`);
  for (const doc of pedidos.docs) {
    const d = doc.data();
    const itemsEbook = (d.items || []).filter(i => i.es_ebook === true);
    if (itemsEbook.length) {
      // Comprobar si tiene token generado
      const tok = await db.collection("empresas").doc(EID)
        .collection("descargas_ebook")
        .where("referencia", "==", d.stripe_session_id || doc.id).get();
      const icono = tok.size > 0 ? "✅" : "⚠️  SIN TOKEN";
      console.log(`  ${icono}  ${d.email} — ${itemsEbook.map(i=>i.titulo).join(", ")} — tokens:${tok.size}`);
    }
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
