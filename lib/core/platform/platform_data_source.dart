import 'dart:io';
import 'package:flutter/foundation.dart';

/// Detecta la plataforma actual y proporciona información sobre
/// capacidades soportadas.
/// 
/// **USO**:
/// ```dart
/// final platform = PlatformDataSource();
/// if (platform.supportsRealtimeStreams) {
///   // Android/iOS: usar .snapshots()
/// } else {
///   // Windows: usar polling con .get()
/// }
/// ```
class PlatformDataSource {
  /// Indica si la plataforma actual soporta Firebase Realtime Streams
  /// sin problemas de platform channels.
  /// 
  /// - **true**: Android, iOS (SDK nativo)
  /// - **false**: Windows, Linux, macOS (platform channels inestables)
  bool get supportsRealtimeStreams {
    if (kIsWeb) return false; // Web no soporta realtime bien
    
    try {
      // Windows, Linux, macOS tienen problemas con platform channels
      return !(Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    } catch (e) {
      // Si falla Platform check, asumir no soportado
      return false;
    }
  }
  
  /// Indica si estamos en Windows Desktop
  bool get isWindows {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (e) {
      return false;
    }
  }
  
  /// Indica si estamos en mobile (Android o iOS)
  bool get isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }
  
  /// Intervalo de polling recomendado para Windows según prioridad
  Duration pollingInterval({PollingPriority priority = PollingPriority.normal}) {
    switch (priority) {
      case PollingPriority.critical:
        return const Duration(seconds: 5);  // TPV, citas del día
      case PollingPriority.high:
        return const Duration(seconds: 10); // Reservas, clientes
      case PollingPriority.normal:
        return const Duration(seconds: 30); // Dashboard, estadísticas
      case PollingPriority.low:
        return const Duration(minutes: 2);  // Configuración
    }
  }
}

/// Prioridad de actualización para polling en Windows
enum PollingPriority {
  /// Cada 5s - Para datos críticos tiempo real (TPV, citas activas)
  critical,
  
  /// Cada 10s - Para datos importantes (reservas del día, clientes activos)
  high,
  
  /// Cada 30s - Para datos normales (dashboard, listas generales)
  normal,
  
  /// Cada 2min - Para datos que cambian poco (configuración, catálogos)
  low,
}

