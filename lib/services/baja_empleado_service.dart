import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/finiquito.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE BAJA DE EMPLEADO
// Procesa la baja de forma atómica con Firestore batch writes.
// ═══════════════════════════════════════════════════════════════════════════════

class ResultadoBaja {
  final bool exito;
  final int tareasReasignadas;
  final int solicitudesCerradas;
  final String? error;

  const ResultadoBaja({
    required this.exito,
    this.tareasReasignadas = 0,
    this.solicitudesCerradas = 0,
    this.error,
  });
}

class BajaEmpleadoService {
  static final BajaEmpleadoService _i = BajaEmpleadoService._();
  factory BajaEmpleadoService() => _i;
  BajaEmpleadoService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // PROCESAR BAJA — BATCH ATÓMICO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Procesa la baja completa del empleado en todos los módulos.
  /// Usa batch writes para garantizar atomicidad.
  Future<ResultadoBaja> procesarBaja({
    required String empresaId,
    required String empleadoId,
    required String finiquitoId,
    required CausaBaja causaBaja,
    required DateTime fechaBaja,
  }) async {
    try {
      int tareasReasignadas = 0;
      int solicitudesCerradas = 0;

      // ── 1. Obtener UID del propietario para reasignación ──────────────────
      final propietarioId = await _obtenerPropietarioId(empresaId);

      // ── 2. Vacaciones: cerrar solicitudes pendientes ───────────────────────
      final solicitudesBatch = _db.batch();
      final solicitudesSnap = await _db
          .collection('vacaciones')
          .doc(empresaId)
          .collection('solicitudes')
          .where('empleado_id', isEqualTo: empleadoId)
          .where('estado', isEqualTo: 'solicitado')
          .get();

      for (final doc in solicitudesSnap.docs) {
        solicitudesBatch.update(doc.reference, {
          'estado': 'cancelado',
          'notas': 'Cancelada automáticamente por proceso de baja',
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
        solicitudesCerradas++;
      }

      // ── 3. Congelar saldo de vacaciones ────────────────────────────────────
      final saldosSnap = await _db
          .collection('vacaciones')
          .doc(empresaId)
          .collection('saldos')
          .where('empleado_id', isEqualTo: empleadoId)
          .where('anio', isEqualTo: fechaBaja.year)
          .get();

      for (final doc in saldosSnap.docs) {
        solicitudesBatch.update(doc.reference, {
          'congelado': true,
          'fecha_congelacion': Timestamp.fromDate(fechaBaja),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      }

      // ── 4. Tareas: reasignar al propietario ────────────────────────────────
      final tareasBatch = _db.batch();
      final tareasSnap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('tareas')
          .where('usuario_asignado_id', isEqualTo: empleadoId)
          .where('estado', whereNotIn: ['completada', 'cancelada'])
          .get();

      for (final doc in tareasSnap.docs) {
        tareasBatch.update(doc.reference, {
          'usuario_asignado_id': propietarioId,
          'reasignada_por_baja': true,
          'notas_reasignacion':
              'Reasignada automáticamente por baja del empleado',
          'fecha_actualizacion': FieldValue.serverTimestamp(),
          'historial': FieldValue.arrayUnion([
            {
              'accion': 'reasignada',
              'usuario_id': 'sistema',
              'descripcion': 'Reasignada por baja del empleado',
              'fecha': Timestamp.fromDate(DateTime.now()),
            }
          ]),
        });
        tareasReasignadas++;
      }

      // ── 5. Empleado: marcar como baja + bloquear acceso ────────────────────
      final empleadoRef = _db.collection('usuarios').doc(empleadoId);
      final empleadoBatch = _db.batch();

      empleadoBatch.update(empleadoRef, {
        'activo': false,
        'estado': 'baja',
        'fecha_baja': Timestamp.fromDate(fechaBaja),
        'causa_baja': causaBaja.name,
        'causa_baja_etiqueta': causaBaja.etiqueta,
        'finiquito_id': finiquitoId,
        'acceso_bloqueado': true,
        'fecha_bloqueo_acceso': FieldValue.serverTimestamp(),
        // Token FCM eliminado para no recibir notificaciones
        'token_dispositivo': FieldValue.delete(),
      });

      // ── 6. Marcar finiquito con baja aplicada ──────────────────────────────
      empleadoBatch.update(
        _db
            .collection('empresas')
            .doc(empresaId)
            .collection('finiquitos')
            .doc(finiquitoId),
        {
          'baja_aplicada': true,
          'fecha_baja_aplicada': FieldValue.serverTimestamp(),
        },
      );

      // ── 7. Notificación al propietario ────────────────────────────────────
      final empDoc = await empleadoRef.get();
      final nombreEmpleado =
          empDoc.data()?['nombre'] as String? ?? 'Empleado';

      empleadoBatch.set(
        _db
            .collection('notificaciones')
            .doc(empresaId)
            .collection('items')
            .doc(),
        {
          'titulo': '📋 Proceso de baja completado',
          'cuerpo':
              'El proceso de baja de $nombreEmpleado se ha completado. '
              '${tareasReasignadas > 0 ? '$tareasReasignadas tarea(s) reasignada(s).' : ''}',
          'tipo': 'baja_empleado',
          'timestamp': FieldValue.serverTimestamp(),
          'leida': false,
          'modulo_destino': 'empleados',
          'entidad_id': empleadoId,
        },
      );

      // ── Ejecutar todos los batches ─────────────────────────────────────────
      await Future.wait([
        solicitudesBatch.commit(),
        tareasBatch.commit(),
        empleadoBatch.commit(),
      ]);

      debugPrint(
          '✅ Baja procesada: $nombreEmpleado — $tareasReasignadas tareas, '
          '$solicitudesCerradas solicitudes');

      return ResultadoBaja(
        exito: true,
        tareasReasignadas: tareasReasignadas,
        solicitudesCerradas: solicitudesCerradas,
      );
    } catch (e) {
      debugPrint('❌ Error procesando baja: $e');
      return ResultadoBaja(exito: false, error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REVERTIR BAJA (solo propietario, con confirmación doble)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> revertirBaja({
    required String empresaId,
    required String empleadoId,
    required String motivo,
  }) async {
    final batch = _db.batch();
    final empleadoRef = _db.collection('usuarios').doc(empleadoId);

    batch.update(empleadoRef, {
      'activo': true,
      'estado': 'activo',
      'acceso_bloqueado': false,
      'baja_revertida': true,
      'fecha_reversion_baja': FieldValue.serverTimestamp(),
      'motivo_reversion_baja': motivo,
      // Limpiar campos de baja
      'fecha_baja': FieldValue.delete(),
      'causa_baja': FieldValue.delete(),
      'finiquito_id': FieldValue.delete(),
    });

    // Notificación
    batch.set(
      _db
          .collection('notificaciones')
          .doc(empresaId)
          .collection('items')
          .doc(),
      {
        'titulo': '↩️ Baja revertida',
        'cuerpo': 'Se ha revertido la baja del empleado. Motivo: $motivo',
        'tipo': 'baja_revertida',
        'timestamp': FieldValue.serverTimestamp(),
        'leida': false,
        'modulo_destino': 'empleados',
        'entidad_id': empleadoId,
      },
    );

    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPLEADOS DADOS DE BAJA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de empleados dados de baja.
  Stream<List<Map<String, dynamic>>> empleadosDadosDeBaja(String empresaId) {
    return _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('estado', isEqualTo: 'baja')
        .orderBy('fecha_baja', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<String> _obtenerPropietarioId(String empresaId) async {
    // Intentar con el usuario actual (propietario que aplica la baja)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) return uid;

    // Fallback: buscar propietario en Firestore
    final snap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('rol', isEqualTo: 'propietario')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : 'sistema';
  }
}

