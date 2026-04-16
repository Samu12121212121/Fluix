import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_historial_service.dart';

/// Servicio para reseñas de Google Places API + gestión en Firestore.
///
/// LIMITACIÓN: Places API devuelve máximo 5 reseñas por petición.
/// El rating global (4.7 / 632) SÍ viene siempre en la respuesta.
///
/// MULTIEMPRESA: cada empresa configura su propio placeId y apiKey
/// en empresas/{empresaId}/configuracion/google_reviews
class GoogleReviewsService {
  static final GoogleReviewsService _i = GoogleReviewsService._();
  factory GoogleReviewsService() => _i;
  GoogleReviewsService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _maxResenas = 50;

  // ── Configuración de Google por empresa ───────────────────────────────────

  /// Versión pública de _obtenerConfig para la pantalla de configuración
  Future<Map<String, String>> obtenerConfigPublica(String empresaId) =>
      _obtenerConfig(empresaId);

  /// Lee la configuración de Google Reviews de Firestore para esta empresa.
  /// Si no existe, usa los valores hardcodeados de Fluix CRM como demo.
  Future<Map<String, String>> _obtenerConfig(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('google_reviews')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'apiKey': data['api_key'] as String? ?? '',
          'placeId': data['place_id'] as String? ?? '',
        };
      }
    } catch (_) {}

    // Sin config → sin datos (empresa no tiene Google Reviews configurado aún)
    return {'apiKey': '', 'placeId': ''};
  }

  /// Guarda la configuración de Google Reviews para una empresa
  Future<void> guardarConfig(String empresaId, {
    required String apiKey,
    required String placeId,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('google_reviews')
        .set({
      'api_key': apiKey,
      'place_id': placeId,
      'actualizado': FieldValue.serverTimestamp(),
    });
  }

  // ── Borrar reseñas de prueba ──────────────────────────────────────────────

  Future<void> borrarResenasDePrueba(String empresaId) async {
    try {
      final col = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones');

      final todos = await col.get();
      final batch = _db.batch();
      int borradas = 0;

      final nombresDePrueba = {
        'Laura Martínez', 'Carlos Gómez', 'Ana López',
        'María García Rodríguez', 'Carlos Martínez', 'Ana López Fernández',
        'Pedro Sánchez', 'Sofía Hernández', 'Javier González',
        'Carmen Ruiz', 'Miguel Ángel Torres', 'Elena Morales',
        'Roberto Jiménez', 'Lucía Vega', 'Alejandro Díaz',
        'Isabel Romero', 'Francisco Herrera', 'Marta Delgado',
      };

      for (final doc in todos.docs) {
        final data = doc.data();
        final origen = data['origen'] as String? ?? '';
        final googleTime = data['google_time'];
        final cliente = (data['cliente'] ?? '').toString();

        final esFalsa = origen == 'google' && googleTime == null;
        final esPrueba = nombresDePrueba.contains(cliente);
        final esScript = data['fake'] == true;

        if (esFalsa || esPrueba || esScript) {
          batch.delete(doc.reference);
          borradas++;
        }
      }

      if (borradas > 0) {
        await batch.commit();
        print('🗑️ $borradas reseñas de prueba eliminadas');
      }
    } catch (e) {
      print('❌ Error borrando reseñas de prueba: $e');
    }
  }

  // ── Sincronizar con Google Places ────────────────────────────────────────

  /// Resultado de la sincronización — siempre devuelve rating/total
  /// aunque falle la descarga de reseñas
  Future<({double rating, int total, String? error})> sincronizarDesdeGoogle(
      String empresaId) async {
    final config = await _obtenerConfig(empresaId);
    final apiKey = config['apiKey']!;
    final placeId = config['placeId']!;

    if (apiKey.isEmpty || placeId.isEmpty) {
      return (rating: 0.0, total: 0, error: 'No hay API Key configurada para esta empresa');
    }

    try {
      print('🔄 Sincronizando Google Places para empresa $empresaId...');

      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,rating,user_ratings_total,reviews'
          '&language=es'
          '&reviews_sort=newest'
          '&key=$apiKey';

      final response = await _dio.get(url);
      final status = response.data['status'] as String? ?? 'ERROR';

      if (status != 'OK') {
        final errorMsg = response.data['error_message'] as String? ?? status;
        print('❌ Google Places status: $status — $errorMsg');
        // Intentar devolver el cache guardado
        final cache = await _leerRatingCache(empresaId);
        return (rating: cache.$1, total: cache.$2, error: 'Google: $status');
      }

      final result = response.data['result'] as Map<String, dynamic>;
      final ratingGlobal = (result['rating'] as num?)?.toDouble() ?? 0;
      final totalGlobal = (result['user_ratings_total'] as num?)?.toInt() ?? 0;
      final reviews = result['reviews'] as List<dynamic>? ?? [];

      print('⭐ Rating Google: $ratingGlobal ($totalGlobal reseñas) — ${reviews.length} descargadas');

      // 1. Guardar rating/total en estadisticas/resumen (siempre, incluso sin reseñas)
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .set({
        'rating_google': ratingGlobal,
        'total_resenas_google': totalGlobal,
        'ultima_sync_google': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Acumular las reseñas nuevas
      if (reviews.isNotEmpty) {
        final colRef = _db
            .collection('empresas')
            .doc(empresaId)
            .collection('valoraciones');

        final batch = _db.batch();
        int nuevas = 0;

        for (final review in reviews) {
          final r = review as Map<String, dynamic>;
          final id = 'google_${r['time']}';
          final existe = await colRef.doc(id).get();
          if (!existe.exists) nuevas++;

          batch.set(colRef.doc(id), {
            'id': id,
            'cliente': r['author_name'] ?? 'Usuario de Google',
            'calificacion': (r['rating'] as num?)?.toInt() ?? 5,
            'comentario': r['text'] ?? '',
            'fecha': Timestamp.fromMillisecondsSinceEpoch(
                ((r['time'] as int?) ?? 0) * 1000),
            'origen': 'google',
            'avatar_url': r['profile_photo_url'],
            'author_url': r['author_url'],
            'google_time': r['time'],
            // google_review_name se rellena cuando el usuario configura Business Profile API
            // Formato: accounts/XXX/locations/YYY/reviews/ZZZ
            // Por ahora guardamos el time como identificador
            'google_review_id': r['time']?.toString() ?? '',
          }, SetOptions(merge: true));
        }
        await batch.commit();
        if (nuevas > 0) await _limpiarResenasSobrantes(empresaId);
        print('✅ $nuevas reseñas nuevas acumuladas');
      }

      // Guardar snapshot mensual del rating (para historial y gráfico)
      await RatingHistorialService().guardarOActualizarSnapshotMes(empresaId);

      return (rating: ratingGlobal, total: totalGlobal, error: null);
    } on DioException catch (e) {
      print('❌ Error de red sincronizando Google: $e');
      final cache = await _leerRatingCache(empresaId);
      return (rating: cache.$1, total: cache.$2,
          error: 'Sin conexión — mostrando último dato guardado');
    } catch (e) {
      print('❌ Error inesperado: $e');
      final cache = await _leerRatingCache(empresaId);
      return (rating: cache.$1, total: cache.$2, error: e.toString());
    }
  }

  /// Lee el rating guardado en cache (para cuando falla la API)
  Future<(double, int)> _leerRatingCache(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return (
          (data['rating_google'] as num?)?.toDouble() ?? 0.0,
          (data['total_resenas_google'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return (0.0, 0);
  }

  // ── Limpiar sobrantes ────────────────────────────────────────────────────

  Future<void> _limpiarResenasSobrantes(String empresaId) async {
    try {
      final colRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones');

      // Ordenar ascendente → las más antiguas primero
      final todas = await colRef.orderBy('fecha', descending: false).get();
      final total = todas.docs.length;

      if (total <= _maxResenas) {
        print('📊 Reseñas en Firestore: $total / $_maxResenas');
        return;
      }

      final aBorrar = total - _maxResenas;
      final batch = _db.batch();
      for (final doc in todas.docs.take(aBorrar)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('🗑️ $aBorrar reseñas antiguas eliminadas → quedan $_maxResenas');
    } catch (e) {
      print('❌ Error limpiando sobrantes: $e');
    }
  }

  // ── Paginación ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> cargarResenas(
    String empresaId, {
    int limite = 25,
    DocumentSnapshot? cursor,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('valoraciones')
        .orderBy('fecha', descending: true)
        .limit(limite);

    if (cursor != null) q = q.startAfterDocument(cursor);

    final snap = await q.get();
    return snap.docs.map((d) => {'_snap': d, 'id': d.id, ...d.data()}).toList();
  }

  // ── Responder ─────────────────────────────────────────────────────────────

  Future<void> guardarRespuesta({
    required String empresaId,
    required String valoracionId,
    required String respuesta,
  }) async {
    // Leer el documento para saber si es de Google
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('valoraciones')
        .doc(valoracionId)
        .get();

    final esGoogle = doc.exists && (doc.data()?['origen'] as String?) == 'google';

    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('valoraciones')
        .doc(valoracionId)
        .update({
      'respuesta': respuesta,
      'fecha_respuesta': FieldValue.serverTimestamp(),
      'respuesta_mostrada_web': false,
      // Si es de Google, marcamos como pendiente de subir al script web
      if (esGoogle) 'respuesta_subida_google': false,
    });
  }

  // ── Responder reseña (Business Profile API) ──────────────────────────────

  /// Responde una reseña usando Google Business Profile API.
  /// Requiere accessToken válido (OAuth2).
  /// [reviewName]: Identificador recurso (accounts/X/locations/Y/reviews/Z)
  Future<void> responderResena(
      String reviewName, String respuesta, String accessToken) async {
    try {
      // Endpoint v4: update reply
      final url = 'https://mybusiness.googleapis.com/v4/$reviewName/reply';

      await _dio.put(
        url,
        data: {'comment': respuesta},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print('✅ Respuesta enviada a Google: $reviewName');
    } catch (e) {
      print('❌ Error respondiendo reseña: $e');
      rethrow;
    }
  }

  // ── Añadir manual ─────────────────────────────────────────────────────────

  Future<void> anadirValoracionManual({
    required String empresaId,
    required String cliente,
    required int calificacion,
    required String comentario,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('valoraciones')
        .add({
      'cliente': cliente,
      'calificacion': calificacion,
      'comentario': comentario,
      'fecha': FieldValue.serverTimestamp(),
      'origen': 'app',
      'respuesta': null,
    });

    // Actualizar estadísticas
    try {
      final ref = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen');
      final doc = await ref.get();
      final data = doc.data() ?? {};
      final total = (data['total_valoraciones'] as num?)?.toInt() ?? 0;
      final suma = (data['suma_calificaciones'] as num?)?.toDouble() ?? 0;
      await ref.set({
        'total_valoraciones': total + 1,
        'suma_calificaciones': suma + calificacion,
        'valoracion_promedio': (suma + calificacion) / (total + 1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
