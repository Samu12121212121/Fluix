const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  const doc = await db.collection("empresas").doc(EID)
    .collection("eventos").doc("klPSP0pW1zL2fZo7ePDU").get();

  if (!doc.exists) { console.log("No encontrado"); process.exit(1); }
  const d = doc.data();
  console.log("Campos del evento:");
  Object.entries(d).forEach(([k, v]) => {
    const val = typeof v === "object" && v?.toDate ? v.toDate().toISOString() : v;
    const str = String(val || "");
    // Detectar caracteres problemáticos para JS
    const problemas = [];
    if (str.includes("'")) problemas.push("comilla simple");
    if (str.includes('"')) problemas.push("comilla doble");
    if (str.includes("\n") || str.includes("\r")) problemas.push("salto de línea");
    if (str.includes("\\")) problemas.push("barra invertida");
    if (str.includes("`")) problemas.push("backtick");
    const flag = problemas.length ? ` ⚠ ${problemas.join(", ")}` : "";
    console.log(`  ${k}: ${str.slice(0, 120)}${flag}`);
  });
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
