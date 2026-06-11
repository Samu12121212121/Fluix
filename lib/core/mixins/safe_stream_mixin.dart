import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin que gestiona automáticamente la cancelación de StreamSubscriptions.
/// 
/// **Problema que resuelve**: Memory leaks por streams no cancelados.
/// 
/// **USO**:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
/// 
/// class _MyScreenState extends State<MyScreen> with SafeStreamMixin {
///   @override
///   void initState() {
///     super.initState();
///     
///     // En lugar de:
///     // _subscription = stream.listen((data) => ...);
///     
///     // Usar:
///     listenSafe(stream, (data) {
///       setState(() {
///         // actualizar estado
///       });
///     });
///   }
///   
///   // dispose() automático — no necesario escribirlo
/// }
/// ```
mixin SafeStreamMixin<T extends StatefulWidget> on State<T> {
  /// Lista de suscripciones registradas para auto-cancelación.
  final List<StreamSubscription> _subscriptions = [];
  
  /// Registra una suscripción a un stream que se cancela automáticamente
  /// cuando el widget se destruye.
  /// 
  /// [stream] Stream a escuchar
  /// [onData] Callback cuando llegan datos
  /// [onError] Callback opcional para errores
  /// [onDone] Callback opcional cuando stream se completa
  void listenSafe<S>(
    Stream<S> stream,
    void Function(S data) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _subscriptions.add(subscription);
  }
  
  /// Registra múltiples suscripciones de una vez.
  void listenSafeMultiple(List<StreamSubscription> subscriptions) {
    _subscriptions.addAll(subscriptions);
  }
  
  /// Cancela manualmente una suscripción específica antes del dispose.
  void cancelSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }
  
  @override
  void dispose() {
    // Cancelar todas las suscripciones registradas
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    if (_subscriptions.isNotEmpty) {
      debugPrint('✅ SafeStreamMixin: ${_subscriptions.length} streams cancelados');
    }
    
    super.dispose();
  }
}

