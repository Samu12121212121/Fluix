const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  const snap = await db.collection("empresas").doc(EID)
    .collection("eventos").get();

  console.log(`Total eventos: ${snap.size}\n`);

  const problemas = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const fecha = d.fecha;
    const tipo  = d.tipo;
    const titulo = d.titulo || d.nombre || "(sin título)";
    const activo = d.activo;
    const eliminado = d.eliminado;

    // Detectar problemas
    const issues = [];
    if (!fecha) issues.push("SIN FECHA");
    else if (typeof fecha !== "string" && !(fecha && typeof fecha.toDate === "function")) {
      issues.push(`FECHA tipo incorrecto: ${typeof fecha}`);
    }
    if (!tipo) issues.push("SIN TIPO");
    if (eliminado === true) issues.push("eliminado=true");
    if (activo === false) issues.push("activo=false");

    if (issues.length) {
      problemas.push({ id: doc.id, titulo, issues });
      console.log(`⚠  ${doc.id.slice(0,8)} "${titulo}"`);
      console.log(`   Problemas: ${issues.join(", ")}`);
      console.log(`   fecha: ${JSON.stringify(fecha)}, tipo: ${tipo}, activo: ${activo}`);
      console.log();
    }
  }

  // Intentar la misma query que usa la web
  console.log("─── Probando query web (orderBy fecha desc, limit 500) ───");
  try {
    const test = await db.collection("empresas").doc(EID)
      .collection("eventos")
      .orderBy("fecha", "desc")
      .limit(500)
      .get();
    console.log(`✅ Query OK — devuelve ${test.size} eventos`);

    const recientes = test.docs.slice(0, 5).map(d => {
      const data = d.data();
      return `  ${d.id.slice(0,8)} "${data.titulo||data.nombre||'?'}" fecha:${data.fecha} tipo:${data.tipo}`;
    });
    console.log("Últimos 5:");
    recientes.forEach(r => console.log(r));
  } catch (e) {
    console.log(`❌ Query FALLA: ${e.message}`);
    if (e.message.includes("index")) {
      console.log("→ Falta un índice de Firestore");
    }
  }

  if (!problemas.length) console.log("\n✅ Sin datos malformados detectados");
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
