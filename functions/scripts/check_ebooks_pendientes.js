const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  const snap = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari")
    .where("tiene_ebook", "==", true)
    .get();

  console.log(`Total pedidos con ebook: ${snap.size}\n`);

  for (const doc of snap.docs) {
    const d = doc.data();
    const ref = doc.id.slice(0, 8).toUpperCase();

    // Ver tokens de descarga generados para este pedido
    const refBuscar = d.stripe_session_id || doc.id;
    const tokens = await db.collection("empresas").doc(EID)
      .collection("descargas_ebook")
      .where("referencia", "==", refBuscar)
      .get();

    const entregado = tokens.size > 0;
    const icono = d.estado_pago === "pagado"
      ? (entregado ? "✅" : "⚠️ PAGADO SIN ENTREGAR")
      : "⏳";

    console.log(`${icono}  #${ref}  ${d.email}`);
    console.log(`       estado_pago: ${d.estado_pago} | metodo: ${d.metodo_pago}`);
    console.log(`       items: ${(d.items||[]).map(i => i.titulo).join(", ")}`);
    console.log(`       tokens generados: ${tokens.size}`);
    if (!entregado && d.estado_pago === "pagado") {
      console.log(`       ▶ stripe_session_id: ${d.stripe_session_id}`);
    }
    console.log();
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
