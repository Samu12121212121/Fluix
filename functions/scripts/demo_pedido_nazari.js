/**
 * demo_pedido_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Inserta un pedido de prueba completo para la demo de Editorial Nazarí.
 *
 * Flujo que demuestra:
 *  1. El pedido aparece en la app (estado: pendiente)
 *  2. El stock del libro se decrementa
 *  3. Salta una notificación interna
 *  4. Al marcar como cobrado en la app → sube en facturación (flujo normal)
 *
 * Uso:
 *   cd functions
 *   node scripts/demo_pedido_nazari.js
 *
 * Para eliminar el pedido de demo después:
 *   node scripts/demo_pedido_nazari.js --limpiar
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');

const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db  = admin.firestore();
const now = admin.firestore.Timestamp.now();

const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const LIMPIAR = process.argv.includes('--limpiar');

// ── Limpiar pedido de demo ────────────────────────────────────────────────────
async function limpiarDemo() {
  console.log('\n🗑  Limpiando pedido de demo...');
  const pedidosRef = db.collection('empresas').doc(EID).collection('pedidos');
  const snap = await pedidosRef.where('notas_internas', '==', 'PEDIDO DE DEMO — eliminar tras la presentación').get();
  if (snap.empty) {
    console.log('  ℹ️  No se encontró ningún pedido de demo.');
    return;
  }
  for (const doc of snap.docs) {
    await doc.ref.delete();
    console.log(`  ✅ Eliminado: ${doc.id}`);
  }

  // Limpiar notificación
  const notifSnap = await db.collection('notificaciones').doc(EID).collection('items')
    .where('titulo', '==', '📦 Nuevo pedido web — demo')
    .get();
  for (const d of notifSnap.docs) { await d.ref.delete(); }
  console.log('  ✅ Notificación de demo eliminada.');
  process.exit(0);
}

// ── Buscar primer producto activo del catálogo ────────────────────────────────
async function obtenerProductoDemo() {
  const snap = await db.collection('empresas').doc(EID)
    .collection('catalogo')
    .where('activo', '==', true)
    .limit(5)
    .get();

  if (!snap.empty) {
    // Preferir un libro (tiene precio > 0)
    const withPrice = snap.docs.filter(d => (d.data().precio || 0) > 0);
    const doc = withPrice.length ? withPrice[0] : snap.docs[0];
    const d = doc.data();
    return {
      id:     doc.id,
      nombre: d.nombre || d.titulo || 'Libro Nazarí',
      precio: parseFloat(d.precio) || 14.95,
      stock:  typeof d.stock === 'number' ? d.stock : null,
      iva:    parseFloat(d.iva) || 4.0,  // IVA libros España = 4%
    };
  }

  // Fallback: usar un libro genérico si el catálogo está vacío
  console.log('  ⚠️  No hay productos en el catálogo — usando datos genéricos');
  return {
    id:     'libro-demo',
    nombre: 'La gestión del silencio — Manuel Bayona',
    precio: 18.00,
    stock:  null,
    iva:    4.0,
  };
}

// ── Crear pedido de demo ──────────────────────────────────────────────────────
async function crearPedidoDemo() {
  const producto = await obtenerProductoDemo();
  console.log(`\n📦 Producto seleccionado: "${producto.nombre}" — ${producto.precio.toFixed(2)} €\n`);

  const cantidad = 2;
  const subtotal = producto.precio * cantidad;
  const gastos   = 3.90;
  const total    = subtotal + gastos;

  // ── 1. Crear pedido ─────────────────────────────────────────────────────────
  console.log('1/3  Creando pedido...');
  const pedidoRef = db.collection('empresas').doc(EID).collection('pedidos').doc();
  const pedido = {
    empresa_id:       EID,
    numero_ticket:    1001,
    cliente_nombre:   'Librería Pérez (Demo)',
    cliente_telefono: '+34 611 222 333',
    cliente_correo:   'libreria.perez@ejemplo.com',
    lineas: [{
      producto_id:      producto.id,
      producto_nombre:  producto.nombre,
      precio_unitario:  producto.precio,
      cantidad:         cantidad,
      iva_porcentaje:   producto.iva,
      coste_unitario:   null,
      variante:         null,
      notas_linea:      null,
      descuento_linea:  null,
      descuento_linea_pct: null,
    }],
    total:            parseFloat(total.toFixed(2)),
    gastos_envio:     gastos,
    estado:           'pendiente',
    estado_pago:      'pendiente',
    origen:           'web',
    metodo_pago:      'tarjeta',
    es_fiado:         false,
    en_espera:        false,
    notas_cliente:    'Entrega urgente antes del viernes.',
    notas_internas:   'PEDIDO DE DEMO — eliminar tras la presentación',
    historial: [{
      usuario_id:    '',
      usuario_nombre: 'Sistema',
      accion:        'creacion',
      descripcion:   'Pedido recibido desde la tienda online',
      fecha:         now,
    }],
    fecha_creacion:   now,
  };
  await pedidoRef.set(pedido);
  console.log(`  ✅ Pedido creado: ${pedidoRef.id} — Total: ${total.toFixed(2)} €`);

  // ── 2. Decrementar stock (si tiene stock) ──────────────────────────────────
  console.log('2/3  Actualizando stock...');
  if (producto.stock !== null && producto.id !== 'libro-demo') {
    const productoRef = db.collection('empresas').doc(EID)
      .collection('catalogo').doc(producto.id);
    await productoRef.update({
      stock: admin.firestore.FieldValue.increment(-cantidad),
    });
    console.log(`  ✅ Stock decrementado: ${producto.stock} → ${producto.stock - cantidad}`);
  } else {
    console.log('  ℹ️  Sin stock registrado — no se decrementa');
  }

  // ── 3. Crear notificación interna ──────────────────────────────────────────
  console.log('3/3  Creando notificación...');
  const notifRef = db.collection('notificaciones').doc(EID).collection('items').doc();
  await notifRef.set({
    titulo:    '📦 Nuevo pedido web — demo',
    cuerpo:    `"${producto.nombre}" × ${cantidad} — ${total.toFixed(2)} € · Librería Pérez (Demo)`,
    tipo:      'pedido_nuevo',
    leida:     false,
    timestamp: now,
    pedido_id: pedidoRef.id,
  });
  console.log(`  ✅ Notificación creada: ${notifRef.id}`);

  console.log('\n' + '═'.repeat(55));
  console.log('  ✅ DEMO LISTA');
  console.log('');
  console.log(`  Pedido ID : ${pedidoRef.id}`);
  console.log(`  Total     : ${total.toFixed(2)} € (IVA ${producto.iva}% incl.)`);
  console.log(`  Estado    : PENDIENTE de cobro`);
  console.log('');
  console.log('  Flujo a mostrar en la app:');
  console.log('  1. 🔔 Notificación en la campana → tap');
  console.log('  2. 📋 Pedidos → ver el pedido "Librería Pérez"');
  console.log('  3. ✅ Confirmar pedido → "En preparación"');
  console.log('  4. 💳 Cobrar → genera factura en Facturación');
  console.log('  5. 📦 Stock ya decrementado (ve a Catálogo)');
  console.log('');
  console.log('  Para limpiar después:');
  console.log('  node scripts/demo_pedido_nazari.js --limpiar');
  console.log('═'.repeat(55) + '\n');
}

// ── Main ──────────────────────────────────────────────────────────────────────
if (LIMPIAR) {
  limpiarDemo().catch(e => { console.error(e); process.exit(1); });
} else {
  crearPedidoDemo().catch(e => { console.error(e); process.exit(1); });
}
