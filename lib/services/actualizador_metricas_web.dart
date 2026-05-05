import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para calcular y actualizar métricas web en tiempo real
class ActualizadorMetricasWeb {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Recalcula las métricas de tráfico web leyendo los documentos diarios
  Future<void> recalcularMetricas(String empresaId) async {
    try {
      final hoy = DateTime.now();
      final fechaHoyStr = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
      
      // Fechas para cálculos
      final hace7Dias = hoy.subtract(const Duration(days: 7));
      final inicioMes = DateTime(hoy.year, hoy.month, 1);
      
      // Leer documento de HOY
      final docHoy = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('visitas_$fechaHoyStr')
          .get();
      
      final visitasHoy = (docHoy.data()?['visitas'] as num?)?.toInt() ?? 0;
      
      // Leer documentos de la semana (últimos 7 días)
      final docsRecientes = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'visitas_')
          .where(FieldPath.documentId, isLessThan: 'visitas_~')
          .get();
      
      int visitasSemana = 0;
      int visitasMes = 0;
      int visitasTotal = 0;
      
      for (final doc in docsRecientes.docs) {
        final visitas = (doc.data()['visitas'] as num?)?.toInt() ?? 0;
        final fechaStr = doc.data()['fecha'] as String?;
        
        if (fechaStr != null) {
          final fecha = DateTime.tryParse(fechaStr);
          if (fecha != null) {
            visitasTotal += visitas;
            
            // Últimos 7 días
            if (fecha.isAfter(hace7Dias.subtract(const Duration(days: 1)))) {
              visitasSemana += visitas;
            }
            
            // Este mes
            if (fecha.year == hoy.year && fecha.month == hoy.month) {
              visitasMes += visitas;
            }
          }
        }
      }
      
      // Actualizar documento de resumen
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('trafico_web')
          .set({
        'visitas_hoy': visitasHoy,
        'visitas_semana': visitasSemana,
        'visitas_mes': visitasMes,
        'visitas_total': visitasTotal,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Métricas web actualizadas: Hoy=$visitasHoy, Semana=$visitasSemana, Mes=$visitasMes, Total=$visitasTotal');
    } catch (e) {
      print('❌ Error recalculando métricas web: $e');
    }
  }
  
  /// Inicia un listener que recalcula métricas cuando llegan nuevas visitas
  void iniciarListenerAutomatico(String empresaId) {
    // Escuchar cambios en visitas de hoy
    final hoy = DateTime.now();
    final fechaHoyStr = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    
    _db
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('visitas_$fechaHoyStr')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        // Recalcular cuando cambian las visitas de hoy
        recalcularMetricas(empresaId);
      }
    });
  }
}

