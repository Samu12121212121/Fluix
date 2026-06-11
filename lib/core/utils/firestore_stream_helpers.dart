// ═══════════════════════════════════════════════════════════════════════════════
// FIRESTORE STREAM HELPERS - Manejo robusto de errores en Windows
// ═══════════════════════════════════════════════════════════════════════════════
//
// Problema: En Windows, cuando se cierra la sesión de Firebase Auth, los listeners
// de Firestore que siguen activos lanzan errores "permission-denied" que cierran
// la aplicación si no se manejan correctamente.
//
// Solución: Estas funciones envuelven los streams de Firestore con manejo de
// errores robusto que previene el crash de la aplicación.
//
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:io';

/// Extensión para añadir manejo de errores robusto a streams de Firestore
extension FirestoreStreamSafeExtension<T> on Stream<T> {
  
  /// 🔥 CRÍTICO PARA WINDOWS: Fuerza los callbacks a ejecutarse en el thread principal
  /// 
  /// Problema: firebase_firestore Windows envía callbacks desde threads nativos
  /// Solución: Interceptar cada evento y re-emitirlo desde el thread principal
  /// 
  /// Uso:
  /// ```dart
  /// FirebaseFirestore.instance
  ///   .collection('empresas')
  ///   .snapshots()
  ///   .ensurePlatformThread() // ← Forzar thread principal
  ///   .handleFirestoreErrors()
  ///   .listen((snapshot) { ... });
  /// ```
  Stream<T> ensurePlatformThread() {
    // Si no es Windows, no hace falta este workaround
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return this;
    }
    
    // Crear un StreamController que re-emite eventos en el thread principal
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    
    controller = StreamController<T>(
      onListen: () {
        debugPrint('🔄 [FIRESTORE THREAD FIX] Stream iniciado con protección de threading');
        
        subscription = listen(
          (data) {
            // Forzar ejecución en el thread principal usando scheduler
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!controller.isClosed) {
                controller.add(data);
              }
            });
            // Trigger inmediato del scheduler
            SchedulerBinding.instance.scheduleFrame();
          },
          onError: (error, stackTrace) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            });
            SchedulerBinding.instance.scheduleFrame();
          },
          onDone: () {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!controller.isClosed) {
                controller.close();
              }
            });
            SchedulerBinding.instance.scheduleFrame();
          },
        );
      },
      onCancel: () {
        debugPrint('🛑 [FIRESTORE THREAD FIX] Stream cancelado - limpiando');
        subscription?.cancel();
      },
    );
    
    return controller.stream;
  }
  
  /// Envuelve el stream con manejo de errores que previene crashes en Windows
  /// 
  /// Captura específicamente:
  /// - permission-denied (cuando se cierra sesión con listeners activos)
  /// - network errors (pérdida de conexión)
  /// - unknown errors (errores internos de Firestore)
  /// 
  /// Uso:
  /// ```dart
  /// FirebaseFirestore.instance
  ///   .collection('empresas')
  ///   .doc(empresaId)
  ///   .snapshots()
  ///   .handleFirestoreErrors() // ← Añadir esto
  ///   .listen((doc) { ... });
  /// ```
  Stream<T> handleFirestoreErrors({String? contexto}) {
    return handleError((error, stackTrace) {
      final errorStr = error.toString();
      final ctx = contexto != null ? '[$contexto] ' : '';
      
      // ── ERROR: Permission Denied ──────────────────────────────────────
      // Causa: Sesión cerrada pero listener aún activo
      // Acción: Log y continuar (no crashear)
      if (errorStr.contains('permission-denied')) {
        debugPrint('⚠️ ${ctx}Firestore: permission-denied (sesión cerrada con listener activo)');
        debugPrint('   → Stream continuará pero sin datos');
        return; // No relanzar - marcar como manejado
      }
      
      // ── ERROR: Network ────────────────────────────────────────────────
      // Causa: Pérdida de conexión
      // Acción: Log y continuar (Firestore reintentará automáticamente)
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        debugPrint('⚠️ ${ctx}Firestore: error de red - reintentando...');
        return; // No relanzar
      }
      
      // ── ERROR: Unavailable ────────────────────────────────────────────
      // Causa: Servicio temporalmente no disponible
      // Acción: Log y continuar
      if (errorStr.contains('unavailable')) {
        debugPrint('⚠️ ${ctx}Firestore: servicio no disponible temporalmente');
        return; // No relanzar
      }
      
      // ── ERROR: Unknown ────────────────────────────────────────────────
      // Causa: Error interno de Firestore o Firebase Auth
      // Acción: Log completo pero no crashear
      if (errorStr.contains('unknown-error')) {
        debugPrint('⚠️ ${ctx}Firestore: error desconocido - $error');
        debugPrint('   Stack: $stackTrace');
        return; // No relanzar
      }
      
      // ── ERROR: No index ───────────────────────────────────────────────
      // Causa: Falta crear índice compuesto en Firestore
      // Acción: Log con instrucciones
      if (errorStr.contains('index')) {
        debugPrint('🔴 ${ctx}Firestore: ERROR - Falta crear índice');
        debugPrint('   → Crear índice en Firebase Console');
        debugPrint('   → Error: $error');
        return; // No relanzar - la UI debe manejar datos vacíos
      }
      
      // ── ERROR: Otros ──────────────────────────────────────────────────
      // Cualquier otro error: log completo pero NO relanzar en Windows
      debugPrint('🔴 ${ctx}Firestore: error no catalogado - $error');
      debugPrint('   Stack: $stackTrace');
      
      // En Windows, NUNCA relanzar errores de Firestore
      // Esto previene el crash de la aplicación
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint('   → Error manejado sin crash (Windows)');
        return; // NO relanzar
      }
      
      // En otras plataformas, relanzar para que la UI lo maneje
      // throw error;  // Descomentado si quieres propagarlo en mobile
      return; // Por seguridad, no relanzamos ni en mobile
    });
  }
}

/// Helper para crear StreamBuilder con manejo de errores incluido
/// 
/// **IMPORTANTE:** Este widget automáticamente aplica el fix de threading 
/// para Windows, previniendo el error "non-platform thread"
/// 
/// Uso:
/// ```dart
/// SafeStreamBuilder<QuerySnapshot>(
///   stream: FirebaseFirestore.instance.collection('...').snapshots(),
///   builder: (context, snapshot) {
///     if (!snapshot.hasData) return CircularProgressIndicator();
///     return ListView(...);
///   },
///   contexto: 'Lista de productos',
/// )
/// ```
class SafeStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;
  final String? contexto;
  final Widget Function(BuildContext context, Object error)? onError;
  
  const SafeStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.contexto,
    this.onError,
  });
  
  @override
  Widget build(BuildContext context) {
    // Aplicar fix de threading + manejo de errores
    final safeStream = stream
        .ensurePlatformThread() // ← Fix crítico para Windows
        .handleFirestoreErrors(contexto: contexto);
    
    return StreamBuilder<T>(
      stream: safeStream,
      builder: (context, snapshot) {
        // Manejo de errores específico
        if (snapshot.hasError) {
          debugPrint('🔴 StreamBuilder error: ${snapshot.error}');
          
          // Si hay callback personalizado de error, usarlo
          if (onError != null) {
            return onError!(context, snapshot.error!);
          }
          
          // Widget por defecto para errores
          return _buildErrorWidget(context, snapshot.error!);
        }
        
        // Construcción normal del widget
        return builder(context, snapshot);
      },
    );
  }
  
  Widget _buildErrorWidget(BuildContext context, Object error) {
    final errorStr = error.toString();
    
    // Error de permisos → mostrar mensaje amigable
    if (errorStr.contains('permission-denied')) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Sesión expirada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Por favor, vuelve a iniciar sesión',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }
    
    // Error de conexión → mostrar mensaje de red
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Sin conexión',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifica tu conexión a internet',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }
    
    // Error genérico
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error al cargar datos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta recargar la pantalla',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}







