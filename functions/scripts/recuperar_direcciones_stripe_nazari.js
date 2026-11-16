/**
 * recuperar_direcciones_stripe_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Recupera la dirección de envío de Stripe para todos los pedidos de
 * pedidos_web_nazari que tienen stripe_session_id pero no tienen
 * direccion_envio guardada.
 *
 * Uso:
 *   cd functions
 *   node scripts/recuperar_direcciones_stripe_nazari.js
 *   node scripts/recuperar_direcciones_stripe_nazari.js --dry-run
 *
 * La clave de Stripe se lee automáticamente desde Firebase Secret Manager.
 * Requiere estar autenticado con: firebase login
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin   = require("firebase-admin");
const Stripe  = require("stripe");
const { SecretManagerServiceClient } = require("@google-cloud/secret-manager");

const PROJECT_ID = "planeaapp-4bea4";
const EID        = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const DRY_RUN    = process.argv.includes("--dry-run");

// ── Inicializar Firebase Admin con service account ────────────────────────
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function getStripeKey() {
  if (process.env.STRIPE_SECRET_KEY_NAZARI) return process.env.STRIPE_SECRET_KEY_NAZARI;

  // Intentar via Secret Manager (requiere gcloud auth application-default login)
  try {
    const client = new SecretManagerServiceClient();
    const name   = `projects/${PROJECT_ID}/secrets/STRIPE_SECRET_KEY_NAZARI/versions/latest`;
    const [version] = await client.accessSecretVersion({ name });
    return version.payload.data.toString("utf8").trim();
  } catch (_e) {}

  // Fallback: usar Firebase CLI (no requiere gcloud)
  const { execSync } = require("child_process");
  try {
    const key = execSync(
      `firebase functions:secrets:access STRIPE_SECRET_KEY_NAZARI --project ${PROJECT_ID}`,
      { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
    ).trim();
    if (key && key.startsWith("sk_")) return key;
  } catch (e) {
    throw new Error(`No se pudo obtener la clave Stripe.\nEjecuta: firebase login\nO pásala manualmente: STRIPE_SECRET_KEY_NAZARI=sk_live_... node scripts/...`);
  }

  throw new Error("Clave Stripe vacía o inválida");
}

async function main() {
  console.log(DRY_RUN ? "🔍 DRY-RUN — no se escribirá nada en Firestore\n" : "🚀 Iniciando recuperación de direcciones...\n");

  console.log("  Leyendo clave Stripe desde Secret Manager…");
  const stripeKey = await getStripeKey();
  const stripe = new Stripe(stripeKey, { apiVersion: "2024-06-20" });
  console.log("  ✅ Clave obtenida\n");

  const snap = await db
    .collection("empresas").doc(EID)
    .collection("pedidos_web_nazari")
    .get();

  const sinDireccion = snap.docs.filter(d => {
    const data = d.data();
    return data.metodo_pago === "stripe" && data.stripe_session_id && !data.direccion_envio;
  }).sort((a, b) => {
    const ta = a.data().fecha_creacion?.toMillis() || 0;
    const tb = b.data().fecha_creacion?.toMillis() || 0;
    return tb - ta;
  });

  console.log(`Total pedidos Stripe: ${snap.size}`);
  console.log(`Sin dirección: ${sinDireccion.length}\n`);

  if (!sinDireccion.length) {
    console.log("✅ Todos los pedidos Stripe ya tienen dirección.");
    return;
  }

  let ok = 0, sinAddr = 0, errores = 0;

  for (const doc of sinDireccion) {
    const data = doc.data();
    const sessionId = data.stripe_session_id;
    const nombre    = data.nombre || data.nombre_comprador || data.email || "";

    process.stdout.write(`  Pedido ${doc.id.slice(0,8)} (${nombre || "sin nombre"})… `);

    try {
      const session = await stripe.checkout.sessions.retrieve(sessionId);
      const shippingRaw = session.shipping_details || session.shipping;

      if (!shippingRaw?.address) {
        console.log("⚠ Sin dirección en Stripe (probable ebook)");
        sinAddr++;
        continue;
      }

      const dir = {
        nombre:  shippingRaw.name || session.customer_details?.name || nombre,
        linea1:  shippingRaw.address.line1         || "",
        linea2:  shippingRaw.address.line2         || "",
        ciudad:  shippingRaw.address.city          || "",
        cp:      shippingRaw.address.postal_code   || "",
        pais:    shippingRaw.address.country       || "",
      };

      const dirStr = [dir.nombre, dir.linea1, dir.linea2,
        `${dir.cp} ${dir.ciudad}`.trim(), dir.pais].filter(Boolean).join(", ");

      if (!DRY_RUN) {
        await doc.ref.update({ direccion_envio: dir });

        // Actualizar también el pedido espejado en `pedidos` si existe
        const fluixId = data.pedido_fluix_id;
        if (fluixId) {
          await db.collection("empresas").doc(EID)
            .collection("pedidos").doc(fluixId)
            .update({ direccion_envio: dirStr });
        }
      }

      console.log(`✅ ${dirStr}`);
      ok++;
    } catch (err) {
      console.log(`❌ Error: ${err.message}`);
      errores++;
    }

    // Pausa para no saturar la API de Stripe
    await new Promise(r => setTimeout(r, 120));
  }

  console.log(`\n─── Resumen ───────────────────────────────`);
  console.log(`  ✅ Direcciones recuperadas: ${ok}`);
  console.log(`  ⚠  Sin dirección en Stripe: ${sinAddr}  (probablemente ebooks)`);
  console.log(`  ❌ Errores:                 ${errores}`);
  if (DRY_RUN) console.log(`\n  (DRY-RUN: no se ha escrito nada)`);
}

main().catch(err => { console.error("Error fatal:", err); process.exit(1); });
