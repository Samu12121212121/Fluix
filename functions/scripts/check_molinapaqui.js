const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  const snap = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari")
    .where("email", "==", "molinapaqui@msn.com").get();

  for (const doc of snap.docs) {
    const d = doc.data();
    console.log("Pedido:", doc.id);
    console.log("  estado:", d.estado, "| estado_pago:", d.estado_pago);
    console.log("  metodo:", d.metodo_pago, "| total:", d.total, "€");
    console.log("  items:", JSON.stringify(d.items, null, 2));
    console.log("  tiene_ebook:", d.tiene_ebook, "| tiene_libro:", d.tiene_libro);
    console.log("  stripe_session_id:", d.stripe_session_id);
    console.log("  fecha:", d.fecha_creacion?.toDate?.()?.toLocaleDateString("es-ES"));
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
