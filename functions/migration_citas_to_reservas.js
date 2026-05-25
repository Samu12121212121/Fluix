// ═════════════════════════════════════════════════════════════════════════════
// MIGRACIÓN: citas/ → reservas/ (Unificación Fluix CRM)
// ═════════════════════════════════════════════════════════════════════════════
// Ejecutar: node migration_citas_to_reservas.js
// Requisito: npm install firebase-admin
// ═════════════════════════════════════════════════════════════════════════════

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://planeaapp-4bea4.firebaseio.com'
});

const db = admin.firestore();

let stats = {
  empresas: 0,
  citasLeidas: 0,
  reservasCreadas: 0,
  reservasActualizadas: 0,
  citasMarcadas: 0,
  errores: 0
};

async function migrarCitasAReservas() {
  console.log('🚀 Iniciando migración citas → reservas...\n');

  try {
    // Obtener todas las empresas
    const empresasSnap = await db.collection('empresas').get();

    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      stats.empresas++;

      console.log(`📂 Procesando empresa: ${empresaId}`);

      // Obtener todas las citas de la empresa
      const citasSnap = await db
        .collection('empresas')
        .doc(empresaId)
        .collection('citas')
        .get();

      if (citasSnap.empty) {
        console.log(`   ℹ️  Sin citas en esta empresa\n`);
        continue;
      }

      console.log(`   📋 ${citasSnap.size} citas encontradas`);

      const batch = db.batch();
      let batchCount = 0;
      const BATCH_SIZE = 500;

      for (const citaDoc of citasSnap.docs) {
        try {
          stats.citasLeidas++;
          const cita = citaDoc.data();

          // ── PASO 1: Verificar si ya tiene reserva vinculada ────────────────
          let reservaId = cita.reserva_id;
          let reservaExiste = false;

          if (reservaId) {
            const reservaRef = db
              .collection('empresas')
              .doc(empresaId)
              .collection('reservas')
              .doc(reservaId);
            const reservaDoc = await reservaRef.get();
            reservaExiste = reservaDoc.exists;
          }

          // ── PASO 2: Crear o actualizar documento unificado ─────────────────
          const datosUnificados = {
            // Campos comunes
            cliente_nombre: cita.cliente_nombre || 'Cliente',
            cliente_telefono: cita.cliente_telefono || null,
            fecha: cita.fecha || '', // yyyy-MM-dd
            hora_inicio: cita.hora_inicio || '09:00',
            duracion_minutos: cita.duracion_minutos || 30,
            estado: cita.estado || 'pendiente',
            origen: cita.origen || 'tpv_peluqueria',
            precio: calcularPrecioTotal(cita.servicios || []),
            notas: cita.nota || cita.notas || null,

            // Campos unificados prof_id + profesional_id
            prof_id: cita.prof_id || cita.profesional_id || null,
            profesional_id: cita.prof_id || cita.profesional_id || null,

            // Servicios
            servicios: cita.servicios || [],
            servicio_nombre: cita.servicio_nombre ||
                            derivarNombreServicio(cita.servicios),

            // Campos del TPV peluquería
            recordatorio_enviado: cita.recordatorio_enviado || cita.recordatorioEnviado || false,
            recordatorio_cliente_enviado: cita.recordatorio_cliente_enviado || false,
            es_walkin: cita.es_walkin || false,

            // Metadata
            fecha_creacion: cita.fecha_creacion || admin.firestore.FieldValue.serverTimestamp(),

            // Marca de migración
            migrado_de_citas: true,
            cita_id_original: citaDoc.id,
            fecha_migracion: admin.firestore.FieldValue.serverTimestamp()
          };

          if (reservaExiste) {
            // ── Actualizar reserva existente con campos que faltan ──
            batch.update(
              db.collection('empresas').doc(empresaId).collection('reservas').doc(reservaId),
              {
                ...datosUnificados,
                // No sobrescribir campos B2C si ya existen
                ...Object.fromEntries(
                  Object.entries({
                    cliente_uid: null,
                    email_cliente: null,
                    zona: null,
                    num_personas: null,
                    alergenos: null,
                    empresa_id_vinculada: null
                  }).filter(([_, v]) => v === null)  // Solo merge si no existen
                )
              }
            );
            stats.reservasActualizadas++;
            console.log(`   ✏️  Actualizada reserva ${reservaId}`);
          } else {
            // ── Crear nueva reserva unificada ──
            const nuevaReservaRef = db
              .collection('empresas')
              .doc(empresaId)
              .collection('reservas')
              .doc();

            batch.set(nuevaReservaRef, datosUnificados);
            reservaId = nuevaReservaRef.id;
            stats.reservasCreadas++;
            console.log(`   ✅ Creada nueva reserva ${reservaId}`);
          }

          // ── PASO 3: Marcar cita como migrada (NO borrar todavía) ──
          batch.update(citaDoc.ref, {
            migrado: true,
            reserva_unificada_id: reservaId,
            fecha_migracion: admin.firestore.FieldValue.serverTimestamp()
          });
          stats.citasMarcadas++;

          batchCount++;

          // Ejecutar batch cada 500 operaciones
          if (batchCount >= BATCH_SIZE) {
            await batch.commit();
            console.log(`   💾 Batch commit: ${batchCount} operaciones`);
            batchCount = 0;
          }

        } catch (error) {
          stats.errores++;
          console.error(`   ❌ Error procesando cita ${citaDoc.id}:`, error.message);
        }
      }

      // Commit batch final
      if (batchCount > 0) {
        await batch.commit();
        console.log(`   💾 Batch final commit: ${batchCount} operaciones`);
      }

      console.log(`   ✅ Empresa ${empresaId} completada\n`);
    }

    // ── RESUMEN FINAL ──────────────────────────────────────────────────────
    console.log('\n═════════════════════════════════════════════════════════════');
    console.log('✅ MIGRACIÓN COMPLETADA');
    console.log('═════════════════════════════════════════════════════════════');
    console.log(`📊 ESTADÍSTICAS:`);
    console.log(`   • Empresas procesadas:     ${stats.empresas}`);
    console.log(`   • Citas leídas:            ${stats.citasLeidas}`);
    console.log(`   • Reservas creadas:        ${stats.reservasCreadas}`);
    console.log(`   • Reservas actualizadas:   ${stats.reservasActualizadas}`);
    console.log(`   • Citas marcadas:          ${stats.citasMarcadas}`);
    console.log(`   • Errores:                 ${stats.errores}`);
    console.log('═════════════════════════════════════════════════════════════');
    console.log('\n⚠️  IMPORTANTE:');
    console.log('   Las citas antiguas NO han sido borradas (solo marcadas).');
    console.log('   Espera 30 días y ejecuta el script de limpieza si todo funciona OK.');
    console.log('   Script de limpieza: node cleanup_citas_migradas.js\n');

  } catch (error) {
    console.error('❌ ERROR FATAL:', error);
    process.exit(1);
  }

  process.exit(0);
}

// ── HELPERS ────────────────────────────────────────────────────────────────

function calcularPrecioTotal(servicios) {
  if (!Array.isArray(servicios) || servicios.length === 0) return 0;
  return servicios.reduce((sum, s) => sum + (s.precio || 0), 0);
}

function derivarNombreServicio(servicios) {
  if (!Array.isArray(servicios) || servicios.length === 0) return 'Servicio';
  if (servicios.length === 1) return servicios[0].nombre || 'Servicio';
  return servicios.map(s => s.nombre || 'Servicio').join(', ');
}

// ═════════════════════════════════════════════════════════════════════════════
// EJECUTAR
// ═════════════════════════════════════════════════════════════════════════════

migrarCitasAReservas();

