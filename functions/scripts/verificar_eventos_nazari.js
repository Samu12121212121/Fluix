/**
 * verificar_eventos_nazari.js
 * Lee los eventos de Firestore y muestra su estado real.
 * Uso: node scripts/verificar_eventos_nazari.js
 */
const admin = require('firebase-admin');
const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

(async () => {
  const snap = await db.collection('empresas').doc(EID).collection('eventos').get();
  console.log(`\nTotal documentos en /eventos: ${snap.size}\n`);

  let conFecha = 0, sinFecha = 0, conEliminado = 0, sinEliminado = 0;
  const ejemplosSinFecha = [];

  snap.forEach(doc => {
    const d = doc.data();
    const fecha = d.fecha;
    const eliminado = d.eliminado;

    if (fecha && fecha.toDate) conFecha++;
    else { sinFecha++; if (ejemplosSinFecha.length < 5) ejemplosSinFecha.push(doc.id); }

    if (eliminado === false) conEliminado++;
    else sinEliminado++;
  });

  console.log(`Con fecha (Timestamp válido): ${conFecha}`);
  console.log(`Sin fecha / fecha nula:       ${sinFecha}`);
  console.log(`Con eliminado=false:          ${conEliminado}`);
  console.log(`Sin eliminado=false:          ${sinEliminado}`);

  if (ejemplosSinFecha.length) {
    console.log('\nEjemplos de eventos SIN fecha:');
    ejemplosSinFecha.forEach(id => console.log(' ', id));
  }

  // Simular la query exacta que usa Fluix
  console.log('\n── Simulando query de Fluix (eliminado==false + orderBy fecha) ──');
  try {
    const q = await db.collection('empresas').doc(EID).collection('eventos')
      .where('eliminado', '==', false)   // mismo filtro que la app
      .orderBy('fecha')
      .limit(500)
      .get();
    console.log(`Eventos que devolvería la query: ${q.size}`);
  } catch(e) {
    console.error('Error en la query:', e.message);
    console.error('→ Probablemente falta el índice compuesto en Firebase Console');
    console.error('  Ve a: https://console.firebase.google.com/ → Firestore → Índices');
  }

  process.exit(0);
})();
