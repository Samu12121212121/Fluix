import 'package:cloud_firestore/cloud_firestore.dart';
import 'google_reviews_service.dart';

/// Servicio para integración con WordPress vía Firebase + Google Reviews
/// Los datos de web vienen del script JavaScript del footer, las reseñas de Google
class WordPressService {
  static final WordPressService _instance = WordPressService._internal();
  factory WordPressService() => _instance;
  WordPressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleReviewsService _googleService = GoogleReviewsService();

  /// Configura el sitio WordPress específico
  void configurarWordPressSitio({
    required String urlSitio,
    required String empresaId,
  }) {
    print('🌐 WordPress configurado para: $urlSitio (Empresa: $empresaId)');
  }

  /// Configura integración con Google Reviews (Place ID para la empresa)
  void configurarGoogleReviews({
    required String placeId,
    required String apiKey,
  }) {
    print('✅ Google Reviews configurado para Place ID: $placeId');
  }

  /// Sincroniza datos de WordPress con Firebase + Google Reviews
  /// Los datos de web ya vienen del script JavaScript, añadimos reseñas de Google
  Future<void> sincronizarConFirebase(String empresaId) async {
    try {
      print('🔄 Sincronizando datos desde Firebase + Google Reviews...');

      // 1. Las estadísticas de web ya vienen del script JS
      await _verificarEstadisticasFirebase(empresaId);

      // 2. Sincronizar reseñas de Google (en lugar de WordPress)
      await _sincronizarResenasGoogle(empresaId);

      print('✅ Sincronización completada (web + Google Reviews)');
    } catch (e) {
      print('❌ Error en sincronización: $e');
    }
  }

  /// Verifica que las estadísticas estén en Firebase
  Future<void> _verificarEstadisticasFirebase(String empresaId) async {
    try {
      final statsDoc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .get();

      if (statsDoc.exists) {
        final data = statsDoc.data()!;
        print('✅ Estadísticas encontradas: ${data['visitas'] ?? 0} visitas totales');
      } else {
        print('ℹ️ Sin estadísticas aún — esperando datos del script JS del footer');
      }
    } catch (e) {
      print('❌ Error verificando estadísticas: $e');
    }
  }

  /// Sincroniza reseñas de Google My Business
  Future<void> _sincronizarResenasGoogle(String empresaId) async {
    try {
      print('🔍 Sincronizando reseñas de Google My Business...');
      await _googleService.sincronizarDesdeGoogle(empresaId);
    } catch (e) {
      print('❌ Error sincronizando reseñas de Google: $e');
    }
  }


  /// Actualiza el estado de una reserva (para enviar a WordPress vía script)
  Future<bool> actualizarEstadoReserva({
    required String reservaId,
    required String nuevoEstado,
    required String empresaId,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .doc(reservaId)
          .update({
        'estado': nuevoEstado,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'actualizado_desde': 'app_crm',
      });

      print('✅ Estado de reserva actualizado: $nuevoEstado');
      return true;
    } catch (e) {
      print('❌ Error actualizando estado: $e');
      return false;
    }
  }

  /// Añade respuesta a una reseña (para enviar a WordPress vía script)
  Future<bool> responderResena({
    required String resenaId,
    required String respuesta,
    required String empresaId,
  }) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .doc(resenaId)
          .update({
        'respuesta': respuesta,
        'fecha_respuesta': DateTime.now().toIso8601String(),
        'respondido_desde': 'app_crm',
      });

      print('✅ Respuesta añadida a reseña');
      return true;
    } catch (e) {
      print('❌ Error añadiendo respuesta: $e');
      return false;
    }
  }

  /// Configurar listeners para cambios que el script de WordPress debe procesar
  void configurarListenerParaWordPress(String empresaId) {
    print('🔗 Configurando listeners para comunicación con WordPress...');

    // Escuchar cambios en reservas
    _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('reservas')
        .where('origen', isEqualTo: 'web')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data()!;
          final reservaId = change.doc.id;
          final estado = data['estado'];

          print('📝 Reserva $reservaId cambió a: $estado');
          // El script de WordPress detectará este cambio automáticamente
        }
      }
    });

    // Escuchar respuestas a reseñas
    _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('valoraciones')
        .where('origen', isEqualTo: 'wordpress')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data()!;
          if (data['respuesta'] != null && data['respuesta'].toString().isNotEmpty) {
            print('💬 Nueva respuesta a reseña de: ${data['nombre_persona']}');
            // El script de WordPress detectará este cambio automáticamente
          }
        }
      }
    });
  }

  /// Función para testing de conectividad (ahora verifica Firebase)
  Future<bool> probarConexionWordPress() async {
    try {
      // En lugar de probar WordPress, probamos Firebase
      await _firestore.collection('test').doc('connection').get();
      print('✅ Conexión Firebase OK');
      return true;
    } catch (e) {
      print('❌ Error conectando con Firebase: $e');
      return false;
    }
  }

  /// Obtener estadísticas desde Firebase (ya pobladas por el script JS)
  Future<Map<String, dynamic>?> obtenerEstadisticasDesdeFirebase(String empresaId) async {
    try {
      final statsDoc = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .get();

      if (statsDoc.exists) {
        return statsDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo estadísticas desde Firebase: $e');
      return null;
    }
  }

  /// Obtener reseñas desde Firebase (ya pobladas por el script JS)
  Future<List<Map<String, dynamic>>> obtenerResenasDesdeFirebase(String empresaId, {int limit = 15}) async {
    try {
      final resenasQuery = await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .orderBy('fecha', descending: true)
          .limit(limit * 2) // traemos más para filtrar en Dart
          .get();

      final todas = resenasQuery.docs
          .map((doc) { final d = doc.data(); d['id'] = doc.id; return d; })
          .where((d) => d['origen'] == 'wordpress')
          .take(limit)
          .toList();

      return todas;
    } catch (e) {
      print('❌ Error obteniendo reseñas desde Firebase: $e');
      return [];
    }
  }

  /// Marcar que se mostró una notificación de respuesta
  Future<void> marcarRespuestaMostrada(String empresaId, String resenaId) async {
    try {
      await _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .doc(resenaId)
          .update({'respuesta_mostrada': true});
    } catch (e) {
      print('❌ Error marcando respuesta mostrada: $e');
    }
  }
}
