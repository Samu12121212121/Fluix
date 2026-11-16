const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'planeaapp-4bea4' });
const db = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

async function main() {
  const snap = await db.collection('empresas').doc(EID)
    .collection('pedidos_web_nazari')
    .orderBy('fecha_creacion', 'desc')
    .limit(20)
    .get();

  console.log(`Pedidos recientes: ${snap.docs.length}`);
  console.log('---');
  const sospechosos = [];
  for (const d of snap.docs) {
    const data = d.data();
    const fecha = data.fecha_creacion?.toDate?.()?.toISOString().slice(0,10) ?? 'sin-fecha';
    const email = data.email ?? '??';
    const metodo = data.metodo_pago ?? '??';
    const sim = data.simulacion ? ' [SIMULACIÓN]' : '';
    const estado = data.estado ?? '??';
    const origen = data.origen ?? '';
    console.log(`${d.id.slice(0,8)} | ${fecha} | ${email} | ${metodo} | ${estado}${sim} | ${origen}`);
    if (data.simulacion || email.includes('test') || email.includes('spam') || !email.includes('@')) {
      sospechosos.push(d.id);
    }
  }
  if (sospechosos.length) {
    console.log('\nSospechosos:', sospechosos);
  }
}

main().catch(console.error).finally(() => process.exit());
