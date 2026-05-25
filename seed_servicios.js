/**
 * seed_servicios.js
 * ─────────────────────────────────────────────────────────────────
 * Inyecta servicios de ejemplo en la subcolección
 *   negocios_publicos/{negocioId}/servicios
 *
 * USO:
 *   1. npm install firebase-admin
 *   2. Descarga tu serviceAccountKey.json desde Firebase Console
 *      → Configuración del proyecto → Cuentas de servicio
 *   3. node seed_servicios.js
 *
 * CONFIGURACIÓN:
 *   Edita el array NEGOCIOS_TARGET con los IDs de los negocios
 *   que quieras rellenar, y elige el TIPO de negocio para cada uno.
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // ← pon tu ruta aquí

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // Si usas europe-west1, no necesitas cambiar nada más.
});

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════
// CONFIGURA AQUÍ LOS NEGOCIOS QUE QUIERES RELLENAR
// Tipos disponibles: 'peluqueria_femenina' | 'barberia' | 'estetica'
//                    'peluqueria_mixta' | 'spa' | 'restaurante'
// ═══════════════════════════════════════════════════════════════════
const NEGOCIOS_TARGET = [
  { id: 'TU_NEGOCIO_ID_1', tipo: 'peluqueria_femenina' },
  { id: 'TU_NEGOCIO_ID_2', tipo: 'barberia'            },
  { id: 'TU_NEGOCIO_ID_3', tipo: 'estetica'            },
  // añade más aquí...
];

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGOS DE SERVICIOS POR TIPO DE NEGOCIO
// Campos usados en _ServicioUI.fromMap():
//   nombre, descripcion, categoria, precio | precio_desde,
//   duracion (minutos), publico, activo, orden
// ═══════════════════════════════════════════════════════════════════
const CATALOGO = {

  peluqueria_femenina: [
    // ── Corte ────────────────────────────────────────────────────
    { nombre: 'Corte de cabello mujer',        categoria: 'Corte',  precio: 25,   duracion: 45,  publico: 'femenino', descripcion: 'Corte personalizado con acabado profesional' },
    { nombre: 'Corte + peinado',               categoria: 'Corte',  precio: 35,   duracion: 60,  publico: 'femenino', descripcion: 'Corte y peinado liso, rizado o brushing' },
    { nombre: 'Flequillo',                     categoria: 'Corte',  precio: 8,    duracion: 15,  publico: 'femenino', descripcion: 'Retoque o creación de flequillo' },
    // ── Color ────────────────────────────────────────────────────
    { nombre: 'Tinte raíz',                    categoria: 'Color',  precio: 35,   duracion: 90,  publico: 'femenino', descripcion: 'Aplicación de tinte en raíces' },
    { nombre: 'Tinte completo',                categoria: 'Color',  precio: 55,   duracion: 120, publico: 'femenino', descripcion: 'Cobertura total de color' },
    { nombre: 'Mechas balayage',               categoria: 'Color',  precio_desde: 80, duracion: 150, publico: 'femenino', descripcion: 'Técnica de mechas degradadas naturales' },
    { nombre: 'Mechas californianas',          categoria: 'Color',  precio_desde: 70, duracion: 120, publico: 'femenino', descripcion: 'Mechas clásicas con papel de aluminio' },
    { nombre: 'Baño de color / Gloss',         categoria: 'Color',  precio: 30,   duracion: 60,  publico: 'femenino', descripcion: 'Tono semipermanente para brillo y uniformidad' },
    // ── Tratamientos ─────────────────────────────────────────────
    { nombre: 'Alisado brasileño',             categoria: 'Tratamientos', precio: 120, duracion: 180, publico: 'femenino', descripcion: 'Alisado de larga duración con queratina' },
    { nombre: 'Hidratación profunda',          categoria: 'Tratamientos', precio: 40,  duracion: 60,  publico: 'femenino', descripcion: 'Mascarilla nutritiva + vapor' },
    { nombre: 'Permanente',                    categoria: 'Tratamientos', precio_desde: 60, duracion: 150, publico: 'femenino', descripcion: 'Ondulación permanente' },
    // ── Peinados ─────────────────────────────────────────────────
    { nombre: 'Recogido',                      categoria: 'Peinados', precio: 50, duracion: 60, publico: 'femenino', descripcion: 'Moño, trenza o recogido de novia/fiesta' },
    { nombre: 'Peinado de fiesta',             categoria: 'Peinados', precio: 40, duracion: 45, publico: 'femenino', descripcion: 'Ondas, liso perfecto o semi-recogido' },
  ],

  barberia: [
    // ── Corte ────────────────────────────────────────────────────
    { nombre: 'Corte de cabello',              categoria: 'Corte',   precio: 15,  duracion: 30,  publico: 'masculino', descripcion: 'Corte clásico o moderno con máquina y tijera' },
    { nombre: 'Corte + arreglo de barba',      categoria: 'Corte',   precio: 22,  duracion: 45,  publico: 'masculino', descripcion: 'Pack completo: corte y barba perfilada' },
    { nombre: 'Corte degradado (fade)',        categoria: 'Corte',   precio: 18,  duracion: 35,  publico: 'masculino', descripcion: 'Low fade, mid fade o high fade' },
    { nombre: 'Corte infantil (< 12 años)',    categoria: 'Corte',   precio: 10,  duracion: 20,  publico: 'todos',     descripcion: 'Corte para niños con tijera o máquina' },
    // ── Barba ────────────────────────────────────────────────────
    { nombre: 'Arreglo de barba',              categoria: 'Barba',   precio: 10,  duracion: 20,  publico: 'masculino', descripcion: 'Perfilado y definición de líneas' },
    { nombre: 'Afeitado clásico con navaja',   categoria: 'Barba',   precio: 18,  duracion: 40,  publico: 'masculino', descripcion: 'Afeitado a navaja con toalla caliente' },
    { nombre: 'Barba completa (modelado)',     categoria: 'Barba',   precio: 15,  duracion: 30,  publico: 'masculino', descripcion: 'Modelado, relleno y arreglo completo' },
    // ── Tratamientos ─────────────────────────────────────────────
    { nombre: 'Tratamiento anti-caída',        categoria: 'Tratamientos', precio: 30, duracion: 45, publico: 'masculino', descripcion: 'Ampollas + masaje capilar' },
    { nombre: 'Hidratación de barba',          categoria: 'Tratamientos', precio: 12, duracion: 20, publico: 'masculino', descripcion: 'Aceite y acondicionador para barba' },
  ],

  estetica: [
    // ── Manicura ─────────────────────────────────────────────────
    { nombre: 'Manicura spa',                  categoria: 'Manicura', precio: 20,  duracion: 45,  publico: 'todos',    descripcion: 'Limado, cutícula, masaje y esmalte' },
    { nombre: 'Manicura semipermanente',       categoria: 'Manicura', precio: 28,  duracion: 60,  publico: 'todos',    descripcion: 'Gel/semipermanente de larga duración' },
    { nombre: 'Uñas de gel (construcción)',    categoria: 'Manicura', precio_desde: 45, duracion: 90, publico: 'femenino', descripcion: 'Extensiones en gel natural o acrílico' },
    { nombre: 'Nail Art (decoración)',         categoria: 'Manicura', precio_desde: 10, duracion: 30, publico: 'femenino', descripcion: 'Diseños, degradados, piedras y efectos' },
    // ── Pedicura ─────────────────────────────────────────────────
    { nombre: 'Pedicura spa',                  categoria: 'Pedicura', precio: 25,  duracion: 50,  publico: 'todos',    descripcion: 'Exfoliación, lima, masaje y esmalte' },
    { nombre: 'Pedicura semipermanente',       categoria: 'Pedicura', precio: 32,  duracion: 70,  publico: 'todos',    descripcion: 'Esmalte semipermanente en pies' },
    // ── Depilación ───────────────────────────────────────────────
    { nombre: 'Depilación labio superior',     categoria: 'Depilación', precio: 6,  duracion: 10,  publico: 'femenino', descripcion: 'Cera o hilo' },
    { nombre: 'Depilación cejas',              categoria: 'Depilación', precio: 8,  duracion: 15,  publico: 'todos',    descripcion: 'Diseño y depilación de cejas' },
    { nombre: 'Depilación media pierna',       categoria: 'Depilación', precio: 18, duracion: 30,  publico: 'femenino', descripcion: 'Cera tibia en medias piernas' },
    { nombre: 'Depilación pierna completa',    categoria: 'Depilación', precio: 28, duracion: 50,  publico: 'femenino', descripcion: 'Cera en pierna completa' },
    { nombre: 'Depilación axilas',             categoria: 'Depilación', precio: 10, duracion: 15,  publico: 'todos',    descripcion: 'Cera en ambas axilas' },
    // ── Facial ───────────────────────────────────────────────────
    { nombre: 'Limpieza facial básica',        categoria: 'Facial',  precio: 35,  duracion: 60,  publico: 'todos',    descripcion: 'Limpieza, vapor y extracción de impurezas' },
    { nombre: 'Tratamiento anti-edad',         categoria: 'Facial',  precio: 55,  duracion: 75,  publico: 'todos',    descripcion: 'Serum, mascarilla y masaje lifting' },
    { nombre: 'Microdermoabrasión',            categoria: 'Facial',  precio: 65,  duracion: 60,  publico: 'todos',    descripcion: 'Exfoliación mecánica para renovar la piel' },
  ],

  peluqueria_mixta: [
    // Combina algunos de femenina + barbería
    { nombre: 'Corte mujer',                   categoria: 'Corte',   precio: 25,  duracion: 45,  publico: 'femenino',  descripcion: 'Corte personalizado mujer' },
    { nombre: 'Corte hombre',                  categoria: 'Corte',   precio: 15,  duracion: 30,  publico: 'masculino', descripcion: 'Corte clásico o moderno hombre' },
    { nombre: 'Corte infantil',                categoria: 'Corte',   precio: 10,  duracion: 20,  publico: 'todos',     descripcion: 'Corte para niños' },
    { nombre: 'Tinte raíz',                    categoria: 'Color',   precio: 35,  duracion: 90,  publico: 'femenino',  descripcion: 'Aplicación de tinte en raíces' },
    { nombre: 'Tinte completo',                categoria: 'Color',   precio: 55,  duracion: 120, publico: 'femenino',  descripcion: 'Cobertura total' },
    { nombre: 'Mechas balayage',               categoria: 'Color',   precio_desde: 80, duracion: 150, publico: 'femenino', descripcion: 'Mechas degradadas naturales' },
    { nombre: 'Arreglo de barba',              categoria: 'Barba',   precio: 10,  duracion: 20,  publico: 'masculino', descripcion: 'Perfilado y definición' },
    { nombre: 'Hidratación profunda',          categoria: 'Tratamientos', precio: 40, duracion: 60, publico: 'todos', descripcion: 'Mascarilla nutritiva + vapor' },
    { nombre: 'Peinado de fiesta',             categoria: 'Peinados', precio: 40, duracion: 45, publico: 'femenino', descripcion: 'Ondas, liso o semi-recogido' },
    { nombre: 'Recogido novia/fiesta',         categoria: 'Peinados', precio: 55, duracion: 60, publico: 'femenino', descripcion: 'Recogido profesional para eventos' },
  ],

  spa: [
    { nombre: 'Masaje relajante (60 min)',      categoria: 'Masajes', precio: 65,  duracion: 60,  publico: 'todos',    descripcion: 'Técnica sueca, aceites esenciales' },
    { nombre: 'Masaje relajante (90 min)',      categoria: 'Masajes', precio: 90,  duracion: 90,  publico: 'todos',    descripcion: 'Masaje completo cuerpo + cuero cabelludo' },
    { nombre: 'Masaje descontracturante',       categoria: 'Masajes', precio: 75,  duracion: 60,  publico: 'todos',    descripcion: 'Liberación de tensiones profundas' },
    { nombre: 'Masaje con piedras calientes',   categoria: 'Masajes', precio: 85,  duracion: 75,  publico: 'todos',    descripcion: 'Basalto volcánico + aromaterapia' },
    { nombre: 'Masaje drenaje linfático',       categoria: 'Masajes', precio: 70,  duracion: 60,  publico: 'todos',    descripcion: 'Reducir retención y mejorar circulación' },
    { nombre: 'Ritual de chocolate',           categoria: 'Rituales', precio: 95, duracion: 90,  publico: 'todos',    descripcion: 'Exfoliación + envoltura + masaje con cacao' },
    { nombre: 'Ritual hammam',                 categoria: 'Rituales', precio: 80, duracion: 90,  publico: 'todos',    descripcion: 'Vapor + arcilla + exfoliación kessa' },
    { nombre: 'Acceso zona de aguas',          categoria: 'Instalaciones', precio: 25, duracion: 120, publico: 'todos', descripcion: 'Jacuzzi, sauna, baño turco y piscina' },
    { nombre: 'Circuito pareja',               categoria: 'Instalaciones', precio: 80, duracion: 120, publico: 'todos', descripcion: 'Zona de aguas + masaje 30min para dos' },
  ],

  restaurante: [
    { nombre: 'Reserva mesa (2 pax)',          categoria: 'Reservas', precio: 0,  duracion: 90,  publico: 'todos', descripcion: 'Reserva estándar para dos personas' },
    { nombre: 'Reserva mesa (4 pax)',          categoria: 'Reservas', precio: 0,  duracion: 90,  publico: 'todos', descripcion: 'Reserva para cuatro personas' },
    { nombre: 'Reserva mesa (6+ pax)',         categoria: 'Reservas', precio: 0,  duracion: 120, publico: 'todos', descripcion: 'Grupos grandes, consultar disponibilidad' },
    { nombre: 'Menú degustación (8 pasos)',    categoria: 'Experiencias', precio: 95, duracion: 150, publico: 'todos', descripcion: 'Experiencia gastronómica con maridaje opcional' },
    { nombre: 'Brunch dominical',             categoria: 'Experiencias', precio: 32, duracion: 120, publico: 'todos', descripcion: 'Buffet brunch todos los domingos de 10:00 a 13:00' },
    { nombre: 'Cena romántica privada',       categoria: 'Experiencias', precio_desde: 150, duracion: 120, publico: 'todos', descripcion: 'Reserva de sala privada con decoración especial' },
  ],
};

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
async function seedServicios() {
  console.log('\n🌱 Fluix Seed — Servicios de ejemplo');
  console.log('═'.repeat(50));

  for (const { id: negocioId, tipo } of NEGOCIOS_TARGET) {
    const servicios = CATALOGO[tipo];
    if (!servicios) {
      console.warn(`⚠️  Tipo "${tipo}" no reconocido para negocio ${negocioId}`);
      continue;
    }

    console.log(`\n📍 Negocio: ${negocioId} (${tipo})`);

    const colRef = db
      .collection('negocios_publicos')
      .doc(negocioId)
      .collection('servicios');

    // Borra los servicios existentes primero (opcional, comenta si no quieres)
    const existentes = await colRef.get();
    if (!existentes.empty) {
      const batch = db.batch();
      existentes.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
      console.log(`   🗑️  Borrados ${existentes.size} servicios previos`);
    }

    // Inserta los nuevos en batches de 500
    let batch = db.batch();
    let count = 0;

    for (let i = 0; i < servicios.length; i++) {
      const svc = servicios[i];
      const docRef = colRef.doc(); // ID autogenerado
      const data = {
        nombre:       svc.nombre,
        descripcion:  svc.descripcion  ?? '',
        categoria:    svc.categoria    ?? '',
        duracion:     svc.duracion     ?? null,
        publico:      svc.publico      ?? 'todos',
        activo:       true,
        orden:        i,
        creadoEn:     admin.firestore.FieldValue.serverTimestamp(),
      };

      // Precio: o precio fijo o precio_desde
      if (svc.precio !== undefined)       data.precio        = svc.precio;
      if (svc.precio_desde !== undefined) data.precio_desde  = svc.precio_desde;

      batch.set(docRef, data);
      count++;

      if (count % 499 === 0) {
        await batch.commit();
        batch = db.batch();
        console.log(`   ✅ Batch parcial de ${count} servicios enviado`);
      }
    }

    await batch.commit();
    console.log(`   ✅ ${servicios.length} servicios insertados`);
  }

  console.log('\n═'.repeat(50));
  console.log('✅ Seed completado.\n');
  process.exit(0);
}

seedServicios().catch(err => {
  console.error('❌ Error en seed:', err);
  process.exit(1);
});
