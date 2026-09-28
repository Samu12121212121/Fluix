/**
 * SEED DEMO BAR/RESTAURANTE — Fluix CRM
 *
 * Prepara la segunda cuenta demo para ventas a bares y restaurantes:
 *   • Nueva empresa bar (DIFERENTE al demo peluquería, mismo propietario)
 *   • tipo_tpv = bar
 *   • 12 mesas en el plano (Salón, Terraza, Barra) — 2 ya ocupadas con comandas
 *   • Catálogo de bar/tapas (cañas, vinos, tapas, raciones, bocadillos)
 *   • Caja abierta del día
 *   • Ficha pública en Explorar > Restaurantes
 *
 * Uso:
 *   cd functions
 *   node scripts/seed_demo_bar.js
 *
 * Requiere serviceAccountKey.json en functions/
 */

const admin = require('firebase-admin');

// Solo inicializar si no hay app ya activa
if (!admin.apps.length) {
  const serviceAccount = require('../serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'planeaapp-4bea4',
  });
}

const db = admin.firestore();

// ── CONSTANTES ───────────────────────────────────────────────────────────────
// ← ID DISTINTO al de la peluquería para que ambos aparezcan en el selector
const EMPRESA_ID     = 'demo_empresa_bar_2026';
const ADMIN_UID      = 'RjnhpAXBUWQhxlDgOm9PT0EcTIr2';  // mismo propietario
const NEGOCIO_PUB_ID = 'demo_bar_fluix2026';

// ── MESAS (floor plan) ───────────────────────────────────────────────────────
// pos_x, pos_y son ratios 0–1 dentro del plano visual
// Mesa 3 y Mesa 7 estarán "ocupadas" con comandas activas

const MESA_OCUPADA_1 = 'demo_mesa_003';
const MESA_OCUPADA_2 = 'demo_mesa_007';

const MESAS = [
  // ── Salón ────────────────────────────────────────────────────────────────
  { id: 'demo_mesa_001', nombre: 'Mesa 1',  numero: 1,  zona: 'Salón',   capacidad: 4, estado: 'libre',   forma: 'rect',   posX: 0.05, posY: 0.06, ancho: 0.18, alto: 0.14 },
  { id: 'demo_mesa_002', nombre: 'Mesa 2',  numero: 2,  zona: 'Salón',   capacidad: 4, estado: 'libre',   forma: 'rect',   posX: 0.28, posY: 0.06, ancho: 0.18, alto: 0.14 },
  { id: MESA_OCUPADA_1,  nombre: 'Mesa 3',  numero: 3,  zona: 'Salón',   capacidad: 6, estado: 'ocupada', forma: 'rect',   posX: 0.51, posY: 0.06, ancho: 0.22, alto: 0.14 },
  { id: 'demo_mesa_004', nombre: 'Mesa 4',  numero: 4,  zona: 'Salón',   capacidad: 2, estado: 'libre',   forma: 'circle', posX: 0.74, posY: 0.08, ancho: 0.13, alto: 0.13 },
  { id: 'demo_mesa_005', nombre: 'Mesa 5',  numero: 5,  zona: 'Salón',   capacidad: 4, estado: 'libre',   forma: 'rect',   posX: 0.05, posY: 0.38, ancho: 0.18, alto: 0.14 },
  { id: 'demo_mesa_006', nombre: 'Mesa 6',  numero: 6,  zona: 'Salón',   capacidad: 4, estado: 'libre',   forma: 'rect',   posX: 0.28, posY: 0.38, ancho: 0.18, alto: 0.14 },
  { id: MESA_OCUPADA_2,  nombre: 'Mesa 7',  numero: 7,  zona: 'Salón',   capacidad: 4, estado: 'ocupada', forma: 'rect',   posX: 0.51, posY: 0.38, ancho: 0.18, alto: 0.14 },
  { id: 'demo_mesa_008', nombre: 'Mesa 8',  numero: 8,  zona: 'Salón',   capacidad: 6, estado: 'libre',   forma: 'rect',   posX: 0.74, posY: 0.38, ancho: 0.22, alto: 0.14 },
  // ── Terraza ──────────────────────────────────────────────────────────────
  { id: 'demo_mesa_009', nombre: 'Terraza 1', numero: 9,  zona: 'Terraza', capacidad: 4, estado: 'libre',   forma: 'circle', posX: 0.08, posY: 0.08, ancho: 0.14, alto: 0.14 },
  { id: 'demo_mesa_010', nombre: 'Terraza 2', numero: 10, zona: 'Terraza', capacidad: 4, estado: 'libre',   forma: 'circle', posX: 0.36, posY: 0.08, ancho: 0.14, alto: 0.14 },
  { id: 'demo_mesa_011', nombre: 'Terraza 3', numero: 11, zona: 'Terraza', capacidad: 4, estado: 'libre',   forma: 'circle', posX: 0.64, posY: 0.08, ancho: 0.14, alto: 0.14 },
  // ── Barra ────────────────────────────────────────────────────────────────
  { id: 'demo_mesa_012', nombre: 'Barra',     numero: 12, zona: 'Barra',   capacidad: 8, estado: 'libre',   forma: 'bar',    posX: 0.05, posY: 0.05, ancho: 0.90, alto: 0.10 },
];

// ── CATÁLOGO ─────────────────────────────────────────────────────────────────
const CATALOGO = [
  // Bebidas frías
  { nombre: 'Caña',                precio: 2.0,  categoria: 'Cervezas',  iva: 10 },
  { nombre: 'Pinta',               precio: 3.5,  categoria: 'Cervezas',  iva: 10 },
  { nombre: 'Botellín',            precio: 2.5,  categoria: 'Cervezas',  iva: 10 },
  { nombre: 'Clara con limón',     precio: 2.0,  categoria: 'Cervezas',  iva: 10 },
  { nombre: 'Vino tinto (copa)',   precio: 2.5,  categoria: 'Vinos',     iva: 10 },
  { nombre: 'Vino blanco (copa)',  precio: 2.5,  categoria: 'Vinos',     iva: 10 },
  { nombre: 'Rioja crianza',       precio: 16.0, categoria: 'Vinos',     iva: 10 },
  { nombre: 'Agua 50cl',           precio: 1.5,  categoria: 'Sin alcohol', iva: 10 },
  { nombre: 'Refresco',            precio: 2.0,  categoria: 'Sin alcohol', iva: 10 },
  { nombre: 'Zumo natural',        precio: 3.0,  categoria: 'Sin alcohol', iva: 10 },
  // Calientes
  { nombre: 'Café solo',           precio: 1.5,  categoria: 'Cafés',     iva: 10 },
  { nombre: 'Café con leche',      precio: 1.8,  categoria: 'Cafés',     iva: 10 },
  { nombre: 'Cortado',             precio: 1.5,  categoria: 'Cafés',     iva: 10 },
  // Tapas
  { nombre: 'Tapa de jamón',       precio: 3.5,  categoria: 'Tapas',     iva: 10 },
  { nombre: 'Tapa de tortilla',    precio: 2.5,  categoria: 'Tapas',     iva: 10 },
  { nombre: 'Tapa de croquetas',   precio: 3.0,  categoria: 'Tapas',     iva: 10 },
  { nombre: 'Tapa del día',        precio: 2.0,  categoria: 'Tapas',     iva: 10 },
  // Raciones
  { nombre: 'Ración de patatas bravas', precio: 6.5,  categoria: 'Raciones', iva: 10 },
  { nombre: 'Ración de jamón serrano',  precio: 14.0, categoria: 'Raciones', iva: 10 },
  { nombre: 'Ración de queso mixto',    precio: 10.0, categoria: 'Raciones', iva: 10 },
  { nombre: 'Ración de croquetas (8u)', precio: 8.0,  categoria: 'Raciones', iva: 10 },
  { nombre: 'Tabla de embutidos',       precio: 16.0, categoria: 'Raciones', iva: 10 },
  // Bocadillos
  { nombre: 'Bocadillo de jamón',  precio: 5.0,  categoria: 'Bocadillos', iva: 10 },
  { nombre: 'Bocadillo de tortilla', precio: 4.0, categoria: 'Bocadillos', iva: 10 },
  { nombre: 'Montadito variado',   precio: 2.0,  categoria: 'Bocadillos', iva: 10 },
];

// Comandas activas para las 2 mesas ocupadas
const COMANDA_MESA_3 = [
  { nombre: 'Caña',              precio: 2.0,  cantidad: 3 },
  { nombre: 'Ración de patatas bravas', precio: 6.5, cantidad: 1 },
  { nombre: 'Ración de croquetas (8u)', precio: 8.0, cantidad: 1 },
];

const COMANDA_MESA_7 = [
  { nombre: 'Vino tinto (copa)',  precio: 2.5, cantidad: 2 },
  { nombre: 'Agua 50cl',          precio: 1.5, cantidad: 2 },
  { nombre: 'Tabla de embutidos', precio: 16.0, cantidad: 1 },
  { nombre: 'Ración de jamón serrano', precio: 14.0, cantidad: 1 },
];

// ════════════════════════════════════════════════════════════════════════════
// FUNCIONES
// ════════════════════════════════════════════════════════════════════════════

async function configurarEmpresa() {
  console.log('🍺 Configurando empresa demo bar...');
  await db.collection('empresas').doc(EMPRESA_ID).set({
    nombre:          'Fluix Bar Demo',
    tipo_tpv:        'bar',
    activo:          true,
    nif:             'B98765432',
    ciudad:          'Madrid',
    telefono:        '91 987 65 43',
    propietario_uid: ADMIN_UID,
    modulos_activos: ['tpv', 'clientes', 'reservas', 'web', 'empleados'],
  }, { merge: true });
  console.log('✅ Empresa bar configurada');
}

async function limpiarDemoAnterior() {
  console.log('🧹 Limpiando datos demo bar anteriores...');
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);

  await Promise.all([
    _borrarColeccion(empresaRef.collection('mesas')),
    _borrarColeccion(empresaRef.collection('catalogo').where('es_demo', '==', true)),
    _borrarColeccion(empresaRef.collection('comandas').where('estado', '==', 'abierta')),
    _borrarColeccion(empresaRef.collection('aperturas_caja')
      .where('fecha', '>=', admin.firestore.Timestamp.fromDate(_inicioDia()))
      .where('fecha', '<',  admin.firestore.Timestamp.fromDate(_finDia()))
    ),
  ]);

  await db.collection('negocios_publicos').doc(NEGOCIO_PUB_ID).delete().catch(() => {});
  console.log('✅ Limpieza completada');
}

function _inicioDia() {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
}
function _finDia() {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, 0, 0, 0);
}

async function _borrarColeccion(query) {
  const snap = await query.get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
}

async function crearCatalogo() {
  console.log('🍽️  Creando catálogo de bar...');
  const batch = db.batch();
  const col = db.collection('empresas').doc(EMPRESA_ID).collection('catalogo');

  for (const p of CATALOGO) {
    const ref = col.doc();
    batch.set(ref, {
      nombre:          p.nombre,
      categoria:       p.categoria,
      precio:          p.precio,
      iva_porcentaje:  p.iva,
      activo:          true,
      es_demo:         true,
      fecha_creacion:  admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ ${CATALOGO.length} productos creados`);
}

async function crearMesasYComandas() {
  console.log('🪑 Creando mesas y comandas activas...');
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);
  const mesasRef   = empresaRef.collection('mesas');
  const comandasRef = empresaRef.collection('comandas');

  // Crear comandas activas primero para tener sus IDs
  const comanda3Ref = comandasRef.doc();
  const comanda7Ref = comandasRef.doc();

  const lineas3 = COMANDA_MESA_3.map(l => ({
    producto_id: '',
    nombre:       l.nombre,
    cantidad:     l.cantidad,
    precio_unitario: l.precio,
    iva_porcentaje: 10,
    subtotal:     l.precio * l.cantidad,
    es_nuevo:     false,
  }));
  const total3 = lineas3.reduce((s, l) => s + l.subtotal, 0);

  const lineas7 = COMANDA_MESA_7.map(l => ({
    producto_id: '',
    nombre:       l.nombre,
    cantidad:     l.cantidad,
    precio_unitario: l.precio,
    iva_porcentaje: 10,
    subtotal:     l.precio * l.cantidad,
    es_nuevo:     false,
  }));
  const total7 = lineas7.reduce((s, l) => s + l.subtotal, 0);

  const batch = db.batch();

  // Comandas
  batch.set(comanda3Ref, {
    mesa_id:       MESA_OCUPADA_1,
    camarero_uid:  ADMIN_UID,
    lineas:        lineas3,
    estado:        'abierta',
    apertura:      admin.firestore.Timestamp.fromDate(new Date(Date.now() - 35 * 60000)), // abierta hace 35min
    importe_total: total3,
    es_demo:       true,
  });

  batch.set(comanda7Ref, {
    mesa_id:       MESA_OCUPADA_2,
    camarero_uid:  ADMIN_UID,
    lineas:        lineas7,
    estado:        'abierta',
    apertura:      admin.firestore.Timestamp.fromDate(new Date(Date.now() - 12 * 60000)), // abierta hace 12min
    importe_total: total7,
    es_demo:       true,
  });

  // Mesas
  for (const m of MESAS) {
    const ref = mesasRef.doc(m.id);
    const data = {
      numero:     m.numero,
      nombre:     m.nombre,
      zona:       m.zona,
      capacidad:  m.capacidad,
      estado:     m.estado,
      forma:      m.forma,
      pos_x:      m.posX,
      pos_y:      m.posY,
      mesa_ancho: m.ancho,
      mesa_alto:  m.alto,
    };

    // Vincular comandas a las mesas ocupadas
    if (m.id === MESA_OCUPADA_1) {
      data.comanda_id    = comanda3Ref.id;
      data.fecha_apertura = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 35 * 60000));
      data.comensales    = 3;
    }
    if (m.id === MESA_OCUPADA_2) {
      data.comanda_id    = comanda7Ref.id;
      data.fecha_apertura = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 12 * 60000));
      data.comensales    = 4;
    }

    batch.set(ref, data);
  }

  await batch.commit();
  console.log(`✅ ${MESAS.length} mesas creadas (2 ocupadas con comandas activas)`);
  console.log(`   Mesa 3: ${total3.toFixed(2)} € pendientes | Mesa 7: ${total7.toFixed(2)} € pendientes`);
}

async function abrirCajaHoy() {
  console.log('💰 Abriendo caja del día...');
  const ref = db.collection('empresas').doc(EMPRESA_ID).collection('aperturas_caja').doc();
  await ref.set({
    fecha:         admin.firestore.Timestamp.fromDate(new Date()),
    fondo_inicial: 300,
    usuario_uid:   ADMIN_UID,
    notas:         'Apertura demo bar',
    es_demo:       true,
  });
  console.log('✅ Caja abierta con fondo inicial de 300 €');
}

async function crearFichaPublica() {
  console.log('🌐 Creando ficha en negocios_publicos (Explorar)...');
  await db.collection('negocios_publicos').doc(NEGOCIO_PUB_ID).set({
    nombre:             'Fluix Bar Demo',
    categoria:          'restaurantes',
    activo:             true,
    empresaIdVinculada: EMPRESA_ID,
    descripcion:        'Bar de tapas y raciones en el centro de Madrid. Ambiente animado, buenas cañas y tapas caseras.',
    tagline:            'Donde el buen ambiente está servido',
    direccion:          'Calle Fuencarral 89, Madrid',
    telefono:           '91 987 65 43',
    ratingGoogle:       4.4,
    ratingFluix:        4.5,
    numResenas:         143,
    fotoUrl:            'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=600&q=80',
    fotosGaleria: [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
      'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f?w=600&q=80',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
    ],
    horario: {
      Lunes:     { apertura: '10:00', cierre: '16:00', apertura_tarde: '19:00', cierre_tarde: '01:00', cerrado: false },
      Martes:    { apertura: '10:00', cierre: '16:00', apertura_tarde: '19:00', cierre_tarde: '01:00', cerrado: false },
      Miércoles: { apertura: '10:00', cierre: '16:00', apertura_tarde: '19:00', cierre_tarde: '01:00', cerrado: false },
      Jueves:    { apertura: '10:00', cierre: '16:00', apertura_tarde: '19:00', cierre_tarde: '01:30', cerrado: false },
      Viernes:   { apertura: '10:00', cierre: '16:00', apertura_tarde: '19:00', cierre_tarde: '02:00', cerrado: false },
      Sábado:    { apertura: '11:00', cierre: '17:00', apertura_tarde: '19:00', cierre_tarde: '02:00', cerrado: false },
      Domingo:   { apertura: '11:00', cierre: '17:00', cerrado: false },
    },
    reservasOnline:   true,
    aceptaTarjeta:    true,
    tieneTerraza:     true,
    tieneWifi:        true,
    nivelPrecio:      '€€',
    precioMedio:      '€€',
    latitud:          40.4231,
    longitud:         -3.6999,
    serviciosDestacados: ['Tapas del día', 'Ración de jamón', 'Vinos de la casa', 'Cañas en terraza'],
    destacado:        true,
  });
  console.log('✅ Ficha pública creada — aparecerá en Explorar > Restaurantes');
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════
async function main() {
  console.log('\n🚀 SEED DEMO BAR/RESTAURANTE\n');
  console.log(`📦 Empresa: ${EMPRESA_ID}`);
  console.log(`👤 Propietario: ${ADMIN_UID} (mismo que la peluquería)\n`);

  try {
    await limpiarDemoAnterior();
    await configurarEmpresa();
    await crearCatalogo();
    await crearMesasYComandas();
    await abrirCajaHoy();
    await crearFichaPublica();

    console.log('\n✅ ¡Cuenta demo bar lista!\n');
    console.log('📊 Resumen:');
    console.log(`   • tipo_tpv = bar ✓`);
    console.log(`   • ${MESAS.length} mesas (Salón, Terraza, Barra) — 2 ya ocupadas`);
    console.log(`   • ${CATALOGO.length} productos (cañas, vinos, tapas, raciones, bocadillos)`);
    console.log(`   • 2 comandas activas con pedidos en curso`);
    console.log(`   • Caja abierta con 300 € de fondo`);
    console.log(`   • Ficha pública en Explorar > Restaurantes ✓`);
    console.log('\n🎯 En el selector TPV ahora aparecen DOS negocios:');
    console.log('   → "Fluix Bar Demo"         (tipo: Bar/Restaurante)');
    console.log('   → "Fluix Peluquería Demo"  (tipo: Peluquería/Estética)');
    console.log('\n🎯 Flujo demo bar recomendado:');
    console.log('   1. Abre TPV → elige "Fluix Bar Demo"');
    console.log('   2. Enseña el plano de mesas (2 ya ocupadas con comandas)');
    console.log('   3. Abre Mesa 3 → muestra la comanda activa');
    console.log('   4. Añade productos desde el catálogo y cobra');
    console.log('   5. Abre una mesa libre → toma pedido desde cero\n');
  } catch (e) {
    console.error('❌ Error:', e);
    process.exit(1);
  }
  process.exit(0);
}

main();
