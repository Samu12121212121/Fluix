import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para gestionar reservas y actualizar estadísticas de empleados
class ReservasEmpleadosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Actualizar estadísticas del empleado cuando se le asigna una reserva
  Future<void> actualizarEstadisticasEmpleado({
    required String empresaId,
    required String? empleadoId,
    required String? empleadoNombre,
    String? empleadoIdAnterior,
    bool esNueva = true,
  }) async {
    if (empleadoId == null) {
      // Si se desasigna el empleado, decrementar el contador del empleado anterior
      if (!esNueva && empleadoIdAnterior != null) {
        await _decrementarReservasEmpleado(empresaId, empleadoIdAnterior);
      }
      return;
    }

    try {
      // Si es una edición y cambió el empleado, decrementar del anterior
      if (!esNueva && empleadoIdAnterior != null && empleadoIdAnterior != empleadoId) {
        await _decrementarReservasEmpleado(empresaId, empleadoIdAnterior);
      }

      // Incrementar reservas del nuevo empleado
      await _incrementarReservasEmpleado(empresaId, empleadoId, empleadoNombre);

      // Recalcular estadísticas generales (se puede hacer de forma asíncrona)
      _recalcularEstadisticasAsync(empresaId);
    } catch (e) {
      print('❌ Error actualizando estadísticas de empleado: $e');
    }
  }

  /// Incrementar contador de reservas del empleado
  Future<void> _incrementarReservasEmpleado(
    String empresaId,
    String empleadoId,
    String? empleadoNombre,
  ) async {
    final docRef = _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('empleados_rendimiento');

    await docRef.set({
      'empleados': {
        empleadoNombre ?? empleadoId: {
          'empleado_id': empleadoId,
          'total_reservas': FieldValue.increment(1),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        }
      },
    }, SetOptions(merge: true));
  }

  /// Decrementar contador de reservas del empleado
  Future<void> _decrementarReservasEmpleado(
    String empresaId,
    String empleadoId,
  ) async {
    // Buscar el nombre del empleado en las estadísticas actuales
    final docRef = _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('empleados_rendimiento');

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final empleados = data['empleados'] as Map<String, dynamic>? ?? {};

    // Buscar el empleado por ID
    String? empleadoKey;
    for (final entry in empleados.entries) {
      final empleadoData = entry.value as Map<String, dynamic>;
      if (empleadoData['empleado_id'] == empleadoId) {
        empleadoKey = entry.key;
        break;
      }
    }

    if (empleadoKey == null) return;

    // Decrementar el contador
    await docRef.set({
      'empleados': {
        empleadoKey: {
          'total_reservas': FieldValue.increment(-1),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        }
      },
    }, SetOptions(merge: true));
  }

  /// Recalcular estadísticas de forma asíncrona (sin bloquear)
  void _recalcularEstadisticasAsync(String empresaId) {
    // Ejecutar en segundo plano
    Future.delayed(Duration.zero, () async {
      try {
        // Importar dinámicamente el servicio de estadísticas
        // para evitar dependencias circulares
        await _firestore
            .collection('empresas')
            .doc(empresaId)
            .collection('estadisticas')
            .doc('resumen')
            .set({
          'ultima_actualizacion_reservas': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ Error recalculando estadísticas async: $e');
      }
    });
  }

  /// Obtener estadísticas en tiempo real de un empleado
  Stream<Map<String, dynamic>> watchEstadisticasEmpleado(
    String empresaId,
    String empleadoId,
  ) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('empleados_rendimiento')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return {};

      final empleados = data['empleados'] as Map<String, dynamic>? ?? {};

      // Buscar el empleado por ID
      for (final entry in empleados.entries) {
        final empleadoData = entry.value as Map<String, dynamic>;
        if (empleadoData['empleado_id'] == empleadoId) {
          return empleadoData;
        }
      }

      return {};
    });
  }

  /// Obtener todas las estadísticas de empleados
  Stream<Map<String, dynamic>> watchEstadisticasEmpleados(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('empleados_rendimiento')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};
      return (doc.data() as Map<String, dynamic>?)?['empleados'] as Map<String, dynamic>? ?? {};
    });
  }
}

