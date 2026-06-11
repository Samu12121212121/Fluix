import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../platform/platform_data_source.dart';

/// Helper que proporciona streams de Firestore adaptados por plataforma.
/// 
/// **En Android/iOS**: Usa `.snapshots()` (realtime nativo)  
/// **En Windows**: Usa polling con `.get()` (evita platform channel errors)
/// 
/// **USO**:
/// ```dart
/// final helper = FirestoreStreamHelper();
/// 
/// // En lugar de:
/// // stream: FirebaseFirestore.instance.collection('...').snapshots()
/// 
/// // Usar:
/// stream: helper.collectionStream(
///   collection: FirebaseFirestore.instance.collection('...'),
///   priority: PollingPriority.high,
/// )
/// ```
class FirestoreStreamHelper {
  final PlatformDataSource _platform = PlatformDataSource();
  
  /// Stream de una colección que se adapta automáticamente por plataforma.
  /// 
  /// [collection] Query de Firestore a escuchar
  /// [priority] Prioridad de actualización (solo para Windows polling)
  Stream<QuerySnapshot> collectionStream(
    Query collection, {
    PollingPriority priority = PollingPriority.normal,
  }) {
    if (_platform.supportsRealtimeStreams) {
      // Android/iOS: realtime nativo (sin problemas)
      debugPrint('🔥 Firestore: Usando realtime stream (mobile)');
      return collection.snapshots();
    } else {
      // Windows: polling manual (evita platform channel errors)
      final interval = _platform.pollingInterval(priority: priority);
      debugPrint('💻 Firestore: Usando polling ${interval.inSeconds}s (Windows)');
      return _pollingCollectionStream(collection, interval);
    }
  }
  
  /// Stream de un documento que se adapta automáticamente por plataforma.
  Stream<DocumentSnapshot> documentStream(
    DocumentReference document, {
    PollingPriority priority = PollingPriority.normal,
  }) {
    if (_platform.supportsRealtimeStreams) {
      return document.snapshots();
    } else {
      final interval = _platform.pollingInterval(priority: priority);
      return _pollingDocumentStream(document, interval);
    }
  }
  
  /// Implementación de polling para colecciones (Windows)
  Stream<QuerySnapshot> _pollingCollectionStream(
    Query collection,
    Duration interval,
  ) {
    late StreamController<QuerySnapshot> controller;
    Timer? timer;
    
    controller = StreamController<QuerySnapshot>(
      onListen: () {
        // Fetch inmediato al suscribirse
        _fetchCollection(collection, controller);
        
        // Luego polling periódico
        timer = Timer.periodic(interval, (_) {
          _fetchCollection(collection, controller);
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
      onPause: () => timer?.cancel(),
      onResume: () {
        if (timer == null || !timer!.isActive) {
          timer = Timer.periodic(interval, (_) {
            _fetchCollection(collection, controller);
          });
        }
      },
    );
    
    return controller.stream;
  }
  
  /// Implementació de polling para documentos (Windows)
  Stream<DocumentSnapshot> _pollingDocumentStream(
    DocumentReference document,
    Duration interval,
  ) {
    late StreamController<DocumentSnapshot> controller;
    Timer? timer;
    
    controller = StreamController<DocumentSnapshot>(
      onListen: () {
        _fetchDocument(document, controller);
        timer = Timer.periodic(interval, (_) {
          _fetchDocument(document, controller);
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
      onPause: () => timer?.cancel(),
      onResume: () {
        if (timer == null || !timer!.isActive) {
          timer = Timer.periodic(interval, (_) {
            _fetchDocument(document, controller);
          });
        }
      },
    );
    
    return controller.stream;
  }
  
  /// Fetch manual de colección (usa .get() en lugar de .snapshots())
  Future<void> _fetchCollection(
    Query collection,
    StreamController<QuerySnapshot> controller,
  ) async {
    try {
      // ✅ .get() NO causa platform channel errors
      final snapshot = await collection.get(
        const GetOptions(source: Source.server),
      );
      
      if (!controller.isClosed) {
        controller.add(snapshot);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
      debugPrint('❌ Error fetching collection: $e');
    }
  }
  
  /// Fetch manual de documento
  Future<void> _fetchDocument(
    DocumentReference document,
    StreamController<DocumentSnapshot> controller,
  ) async {
    try {
      final snapshot = await document.get(
        const GetOptions(source: Source.server),
      );
      
      if (!controller.isClosed) {
        controller.add(snapshot);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
      debugPrint('❌ Error fetching document: $e');
    }
  }
}

