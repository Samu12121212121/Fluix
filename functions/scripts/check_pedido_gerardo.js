const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  // Pedidos de Gerardo
  const snap = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari")
    .where("email", "==", "gerardomartinrodriguez@gmail.com")
    .get();

  for (const doc of snap.docs) {
    const d = doc.data();
    console.log("\n── Pedido:", doc.id);
    console.log("  estado:", d.estado, "| estado_pago:", d.estado_pago);
    console.log("  metodo_pago:", d.metodo_pago);
    console.log("  total:", d.total, "€");
    console.log("  items:", JSON.stringify(d.items));
    console.log("  tiene_ebook:", d.tiene_ebook, "| tiene_libro:", d.tiene_libro);
    console.log("  stripe_session_id:", d.stripe_session_id);
    console.log("  pedido_fluix_id:", d.pedido_fluix_id);
    console.log("  fecha:", d.fecha_creacion?.toDate?.()?.toLocaleDateString("es-ES"));

    // Ver si tiene tokens de descarga generados
    const tokens = await db.collection("empresas").doc(EID)
      .collection("descargas_ebook")
      .where("referencia", "==", d.stripe_session_id || doc.id)
      .get();
    console.log("  tokens_descarga:", tokens.size, tokens.docs.map(t => t.data().libro_titulo + " → " + (t.data().email_comprador)));
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
