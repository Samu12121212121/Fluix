/**
 * borrar_reservas_pasadas_juanita.js
 * Borra todas las reservas con fecha_hora < hoy de la cuenta de Juanita Taberna.
 *
 * Uso:
 *   node functions/scripts/borrar_reservas_pasadas_juanita.js          ← modo DRY RUN (solo cuenta)
 *   node functions/scripts/borrar_reservas_pasadas_juanita.js --borrar  ← borra de verdad
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EMPRESA_ID  = 'AP6JV9bxONgibrjaKzvrrk4xvWM2'; // juanitataberna@gmail.com
const BORRAR_DE_VERDAD = process.argv.includes('--borrar');
const BATCH_SIZE  = 400;
const DIAS_ATRAS  = 10;

// Filtro de cliente: se borran reservas pasadas cuyo email o teléfono coincida
const CLIENTE_EMAIL  = 'sacoor80@gmail.com';
const CLIENTE_TELEFS = ['684287980', '+34684287980', '684 287 980'];

function esDelCliente(data) {
  const email = (data.email_cliente || data.usuario_email || data.cliente_email || '').toLowerCase();
  const tel   = (data.telefono_cliente || data.telefono || data.cliente_telefono || data.usuario_telefono || '')
                  .replace(/\s/g, '');
  if (email === CLIENTE_EMAIL) return true;
  if (CLIENTE_TELEFS.some(t => tel.replace(/\s/g,'') === t.replace(/\s/g,''))) return true;
  return false;
}

async function main() {
  const corte = new Date();
  corte.setDate(corte.getDate() - DIAS_ATRAS);
  corte.setHours(0, 0, 0, 0);
  const cutoff = admin.firestore.Timestamp.fromDate(corte);

  console.log(`\n📅 Fecha actual: ${new Date().toLocaleString('es-ES', { timeZone: 'Europe/Madrid' })}`);
  console.log(`✂️  Corte: anteriores a ${corte.toLocaleDateString('es-ES')} (hace ${DIAS_ATRAS} días)`);
  console.log(`👤 Cliente: ${CLIENTE_EMAIL} / ${CLIENTE_TELEFS[0]}`);
  console.log(`🔍 Buscando en empresa: ${EMPRESA_ID}`);
  if (!BORRAR_DE_VERDAD) console.log('⚠️  DRY RUN — usa --borrar para eliminar de verdad\n');

  // Traemos todas las pasadas y filtramos por cliente en memoria
  // (Firestore no permite filtro compuesto sobre campos de texto alternativos)
  const snap = await db
    .collection('empresas')
    .doc(EMPRESA_ID)
    .collection('reservas')
    .where('fecha_hora', '<', cutoff)
    .get();

  if (snap.empty) {
    console.log('✅ No hay reservas pasadas. Nada que borrar.');
    return;
  }

  // Filtrar por cliente
  const docsCliente = snap.docs.filter(d => esDelCliente(d.data()));

  console.log(`📋 Reservas pasadas totales: ${snap.size}`);
  console.log(`👤 Reservas del cliente a borrar: ${docsCliente.length}`);

  if (!docsCliente.length) {
    console.log('✅ Ninguna reserva pasada coincide con ese cliente.');
    return;
  }

  // Resumen por estado
  const porEstado = {};
  docsCliente.forEach(d => {
    const estado = d.data().estado || 'sin_estado';
    porEstado[estado] = (porEstado[estado] || 0) + 1;
  });
  console.log('   Por estado:', JSON.stringify(porEstado));

  // Mostrar las 5 más recientes para verificar
  const docs = docsCliente.sort((a, b) => {
    const fa = a.data().fecha_hora?.toDate?.() ?? new Date(0);
    const fb = b.data().fecha_hora?.toDate?.() ?? new Date(0);
    return fb - fa;
  });
  console.log('\n   Últimas 5 a borrar (más recientes):');
  docs.slice(0, 5).forEach(d => {
    const data = d.data();
    const fh = data.fecha_hora?.toDate?.()?.toLocaleString('es-ES', { timeZone: 'Europe/Madrid' }) ?? 'sin fecha';
    console.log(`   • [${data.estado || '?'}] ${data.nombre_cliente || data.cliente_nombre || 'Sin nombre'} — ${fh}`);
  });

  if (!BORRAR_DE_VERDAD) {
    console.log('\n⚠️  DRY RUN completado. Ejecuta con --borrar para eliminarlas.');
    return;
  }

  // Borrar en batches
  console.log(`\n🗑️  Borrando ${docsCliente.length} reservas en batches de ${BATCH_SIZE}...`);
  let borradas = 0;
  const allDocs = docsCliente;

  for (let i = 0; i < allDocs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = allDocs.slice(i, i + BATCH_SIZE);
    chunk.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    borradas += chunk.length;
    console.log(`   ✓ Borradas ${borradas}/${snap.size}`);
  }

  console.log(`\n✅ Listo. ${borradas} reservas del cliente eliminadas de Juanita Taberna.`);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
