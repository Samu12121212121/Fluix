const admin  = require("firebase-admin");
const Stripe = require("stripe");
const { execSync } = require("child_process");

const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function getStripeKey() {
  if (process.env.STRIPE_SECRET_KEY_NAZARI) return process.env.STRIPE_SECRET_KEY_NAZARI;
  try {
    const key = execSync(`firebase functions:secrets:access STRIPE_SECRET_KEY_NAZARI --project planeaapp-4bea4`, { encoding: "utf8", stdio: ["pipe","pipe","pipe"] }).trim();
    if (key.startsWith("sk_")) return key;
  } catch (_) {}
  throw new Error("No se pudo obtener la clave Stripe");
}

async function main() {
  const stripeKey = await getStripeKey();
  const stripe = new Stripe(stripeKey, { apiVersion: "2024-06-20" });

  const snap = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari").get();

  const incompletos = snap.docs.filter(d => {
    const data = d.data();
    return data.metodo_pago === "stripe" && data.estado_pago !== "pagado" && data.stripe_session_id;
  });

  console.log(`Pedidos "Incompleto" con stripe_session_id: ${incompletos.length}\n`);

  for (const doc of incompletos) {
    const d = doc.data();
    process.stdout.write(`  ${doc.id.slice(0,8)}  ${d.email}  (${(d.items||[]).map(i=>i.titulo).join(", ")})… `);
    try {
      const session = await stripe.checkout.sessions.retrieve(d.stripe_session_id);
      const pagado  = session.payment_status === "paid";
      const estado  = session.status;
      const total   = session.amount_total ? (session.amount_total / 100).toFixed(2) + " €" : "?";

      if (pagado) {
        console.log(`🚨 PAGADO EN STRIPE (${total}) pero Firestore dice pendiente`);
        console.log(`       → session.status: ${estado} | payment_status: ${session.payment_status}`);
        console.log(`       → Hay que marcar como pagado en Fluix y guardar dirección`);
      } else {
        console.log(`⬜ No pagado — status: ${estado} | payment: ${session.payment_status}`);
      }
    } catch (e) {
      console.log(`❌ Error consultando Stripe: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 100));
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
