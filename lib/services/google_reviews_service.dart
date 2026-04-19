import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_historial_service.dart';

/// Servicio para reseñas de Google Places API (New) + gestión en Firestore.
///
/// ✅ MIGRADO A LA NUEVA PLACES API (New):
/// - Endpoint: https://places.googleapis.com/v1/places/{placeId}
/// - API Key en header X-Goog-Api-Key (no en query param)
/// - Campos renombrados: userRatingCount, authorAttribution, publishTime, etc.
/// - Respuesta directa (sin wrapper "status" y "result")
class GoogleReviewsService {
  static final GoogleReviewsService _i = GoogleReviewsService._();
/// El rating global (rating / userRatingCount) SÍ viene siempre en la respuesta.
  GoogleReviewsService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final FirebaseFirestore _db = FirebaseFirestore.instance;

/// El rating global (4.7 / 632) SÍ viene siempre en la respuesta.

  // ── Configuración de Google por empresa ───────────────────────────────────

  /// Versión pública de _obtenerConfig para la pantalla de configuración
  Future<Map<String, String>> obtenerConfigPublica(String empresaId) =>
  static const int _maxResenas = 20; // Límite: cuando hay más de 20, se borran las más antiguas

  /// Lee la configuración de Google Reviews de Firestore para esta empresa.
  /// Si no existe, usa los valores hardcodeados de Fluix CRM como demo.
  Future<Map<String, String>> _obtenerConfig(String empresaId) async {
    try {
      final doc = await _db
  static const int _maxResenas = 50;
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
      print('🔄 Sincronizando Google Places (New API) para empresa $empresaId...');
          '&key=$apiKey';
      // ✅ NUEVA API: Places API (New)
      final url = 'https://places.googleapis.com/v1/places/$placeId';
        print('❌ Google Places status: $status — $errorMsg');
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'displayName,rating,userRatingCount,reviews.authorAttribution,reviews.text,reviews.rating,reviews.publishTime,reviews.name',
          },
        ),
        queryParameters: {
          'languageCode': 'es',
        },
      );
          '?place_id=$placeId'
      // ✅ Nueva API no tiene "status", devuelve el objeto directamente
      // Si hay error, lanzará DioException que capturamos abajo
      
      final ratingGlobal = (response.data['rating'] as num?)?.toDouble() ?? 0;
      final totalGlobal = (response.data['userRatingCount'] as num?)?.toInt() ?? 0;
      final reviews = response.data['reviews'] as List<dynamic>? ?? [];
      print('⭐ Rating Google: $ratingGlobal ($totalGlobal reseñas) — ${reviews.length} descargadas');
      print('⭐ Rating Google (New API): $ratingGlobal ($totalGlobal reseñas) — ${reviews.length} descargadas');
        return (rating: cache.$1, total: cache.$2, error: 'Google: $status');
      }

      final result = response.data['result'] as Map<String, dynamic>;
      final ratingGlobal = (result['rating'] as num?)?.toDouble() ?? 0;
      final totalGlobal = (result['user_ratings_total'] as num?)?.toInt() ?? 0;
      final reviews = result['reviews'] as List<dynamic>? ?? [];
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
            // Formato: accounts/XXX/locations/YYY/reviews/ZZZ
            // Por ahora guardamos el time como identificador
            'google_review_id': r['time']?.toString() ?? '',
          }, SetOptions(merge: true));
        }
        await batch.commit();
          
          // ✅ Nueva API: campos renombrados
          final authorAttr = r['authorAttribution'] as Map<String, dynamic>?;
          final textObj = r['text'] as Map<String, dynamic>?;
          final publishTime = r['publishTime'] as String?;
          final reviewName = r['name'] as String?; // Nuevo: ID único del review
          
          // Generar ID único basado en publishTime o reviewName
          final timestamp = publishTime != null 
              ? DateTime.parse(publishTime).millisecondsSinceEpoch ~/ 1000
              : DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final id = 'google_$timestamp';
          
        print('✅ $nuevas reseñas nuevas acumuladas');
      }

      // Guardar snapshot mensual del rating (para historial y gráfico)
      await RatingHistorialService().guardarOActualizarSnapshotMes(empresaId);
            'cliente': authorAttr?['displayName'] as String? ?? 'Usuario de Google',
            'calificacion': (r['rating'] as num?)?.toDouble().round() ?? 5,
            'comentario': textObj?['text'] as String? ?? '',
            'fecha': publishTime != null 
                ? Timestamp.fromDate(DateTime.parse(publishTime))
                : Timestamp.now(),
      return (rating: cache.$1, total: cache.$2,
            'avatar_url': authorAttr?['photoUri'] as String? ?? '',
            'author_url': authorAttr?['uri'] as String? ?? '',
            'google_time': timestamp,
            // ✅ Nuevo campo: name único del review (formato: places/{placeId}/reviews/{reviewId})
            'google_review_name': reviewName ?? '',
            'google_review_id': reviewName?.split('/').last ?? timestamp.toString(),
          .collection('empresas')
          .doc(empresaId)
            'avatar_url': r['profile_photo_url'],
            'author_url': r['author_url'],
            'google_time': r['time'],
            // google_review_name se rellena cuando el usuario configura Business Profile API
            // Formato: accounts/XXX/locations/YYY/reviews/ZZZ
            // Por ahora guardamos el time como identificador
            'google_review_id': r['time']?.toString() ?? '',
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
