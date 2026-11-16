/**
 * reparar_pagados_stripe_nazari.js
 * Marca como pagados en Firestore los pedidos que Stripe confirma como cobrados
 * pero que el webhook no procesó. También crea el mirror en `pedidos` si falta.
 *
 * Uso: node scripts/reparar_pagados_stripe_nazari.js [--dry-run]
 */
const admin  = require("firebase-admin");
const Stripe = require("stripe");
const { execSync } = require("child_process");

const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const DRY = process.argv.includes("--dry-run");

async function getStripeKey() {
  if (process.env.STRIPE_SECRET_KEY_NAZARI) return process.env.STRIPE_SECRET_KEY_NAZARI;
  const key = execSync(`firebase functions:secrets:access STRIPE_SECRET_KEY_NAZARI --project planeaapp-4bea4`, { encoding: "utf8", stdio: ["pipe","pipe","pipe"] }).trim();
  if (key.startsWith("sk_")) return key;
  throw new Error("Clave Stripe inválida");
}

function parseDirMap(shippingRaw, nombre) {
  if (!shippingRaw?.address) return null;
  return {
    nombre:  shippingRaw.name || nombre || "",
    linea1:  shippingRaw.address.line1         || "",
    linea2:  shippingRaw.address.line2         || "",
    ciudad:  shippingRaw.address.city          || "",
    cp:      shippingRaw.address.postal_code   || "",
    pais:    shippingRaw.address.country       || "",
  };
}

async function main() {
  console.log(DRY ? "🔍 DRY-RUN\n" : "🔧 Reparando pedidos pagados...\n");
  const stripe = new Stripe(await getStripeKey(), { apiVersion: "2024-06-20" });

  const snap = await db.collection("empresas").doc(EID)
    .collection("pedidos_web_nazari").get();

  const incompletos = snap.docs.filter(d => {
    const v = d.data();
    return v.metodo_pago === "stripe" && v.estado_pago !== "pagado" && v.stripe_session_id;
  });

  let reparados = 0;
  for (const doc of incompletos) {
    const d = doc.data();
    const session = await stripe.checkout.sessions.retrieve(d.stripe_session_id);
    if (session.payment_status !== "paid") continue;

    const nombre = session.customer_details?.name || d.nombre || "";
    const email  = session.customer_email || session.customer_details?.email || d.email || "";
    const shippingRaw = session.shipping_details || session.shipping;
    const dir    = parseDirMap(shippingRaw, nombre);
    const dirStr = dir ? [dir.nombre, dir.linea1, dir.linea2,
      `${dir.cp} ${dir.ciudad}`.trim(), dir.pais].filter(Boolean).join(", ") : null;

    const totalPagado    = session.amount_total    != null ? session.amount_total    / 100 : d.total;
    const subtotalPagado = session.amount_subtotal != null ? session.amount_subtotal / 100 : d.subtotal;
    const envioPagado    = session.shipping_cost?.amount_total != null
      ? session.shipping_cost.amount_total / 100
      : (totalPagado - subtotalPagado) || d.envio || 0;

    console.log(`✅ ${doc.id.slice(0,8)}  ${email}  ${totalPagado} €`);
    console.log(`   nombre: ${nombre}`);
    console.log(`   dirección: ${dirStr || "(sin dirección)"}`);

    if (!DRY) {
      await doc.ref.update({
        estado:           "pendiente",   // pendiente de preparar/enviar
        estado_pago:      "pagado",
        nombre_comprador: nombre,
        email,
        total:            totalPagado,
        subtotal:         subtotalPagado,
        envio:            envioPagado,
        fecha_pago:       admin.firestore.FieldValue.serverTimestamp(),
        ...(dir ? { direccion_envio: dir } : {}),
      });

      // Mirror en pedidos si no existe
      if (!d.pedido_fluix_id) {
        const lineas = (d.items || []).map((i) => ({
          libro_id:        i.catalogo_id || "",
          producto_nombre: i.titulo || "",
          descripcion:     i.titulo || "",
          cantidad:        i.cantidad || 1,
          precio_unitario: i.precio || 0,
          porcentaje_iva:  4,
        }));
        const fluixRef = await db.collection("empresas").doc(EID).collection("pedidos").add({
          empresa_id:          EID,
          cliente_nombre:      nombre || email,
          cliente_correo:      email,
          origen:              "web_nazari",
          estado:              "pendiente",
          estado_pago:         "pagado",
          metodo_pago:         "tarjeta",
          lineas,
          total:               totalPagado,
          subtotal:            subtotalPagado,
          gastos_envio:        envioPagado,
          stripe_session_id:   d.stripe_session_id,
          pedido_web_id:       doc.id,
          ...(dirStr ? { direccion_envio: dirStr } : {}),
          fecha_creacion:      admin.firestore.FieldValue.serverTimestamp(),
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          notas_internas:      `Reparado manualmente. Web ID: ${doc.id}`,
        });
        await doc.ref.update({ pedido_fluix_id: fluixRef.id });
        console.log(`   → Mirror creado: pedidos/${fluixRef.id}`);
      }
    }
    reparados++;
    await new Promise(r => setTimeout(r, 150));
  }

  console.log(`\n─── ${reparados} pedidos reparados${DRY ? " (DRY-RUN)" : ""} ───`);
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
