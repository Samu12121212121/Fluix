const admin = require("firebase-admin");
const sa = require("../serviceAccountKey.json");
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = "0PoomHYDUJf5w8tDFRLhFi9iURF3";

async function main() {
  const snap = await db.collection("empresas").doc(EID)
    .collection("eventos")
    .orderBy("fecha", "desc").limit(500).get();

  const ahora = new Date();
  const hoy   = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
  console.log(`Hoy: ${hoy.toISOString().slice(0,10)}\n`);

  let proximos = 0, pasados = 0;
  const proximosEv = [];

  snap.docs.forEach(doc => {
    const d = doc.data();
    if (d.eliminado === true || d.activo === false) return;

    let fecha;
    if (d.fecha && typeof d.fecha.toDate === "function") {
      fecha = d.fecha.toDate();
    } else if (typeof d.fecha === "string") {
      fecha = new Date(d.fecha);
    } else {
      return;
    }

    const tipo  = d.tipo || "";
    const esProximo = fecha >= hoy;

    if (esProximo) {
      proximos++;
      proximosEv.push({ id: doc.id, titulo: d.titulo||d.nombre||"?", fecha: fecha.toISOString().slice(0,10), tipo });
    } else {
      pasados++;
    }
  });

  console.log(`Próximos: ${proximos}`);
  console.log(`Pasados:  ${pasados}\n`);

  if (proximosEv.length) {
    console.log("─── Eventos próximos (visibles en la web) ───");
    proximosEv.sort((a,b) => new Date(a.fecha) - new Date(b.fecha));
    proximosEv.forEach(e => console.log(`  ${e.fecha}  [${e.tipo}]  "${e.titulo}"`));
  } else {
    console.log("⚠ NO HAY EVENTOS PRÓXIMOS — la lista aparece vacía en la web");
  }
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
