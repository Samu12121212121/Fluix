import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Helper para detectar la plataforma actual y adaptar la UI
class PlatformHelper {
  /// Indica si estamos en una plataforma desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Indica si estamos en móvil (iOS o Android)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Indica si estamos en Windows
  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// Indica si estamos en macOS
  static bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// Indica si estamos en Linux
  static bool get isLinux {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }

  /// Indica si estamos en web
  static bool get isWeb => kIsWeb;

  /// Retorna true si el ancho de pantalla es mayor a 800px (desktop típico)
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 800;
  }

  /// Retorna true si debemos mostrar NavigationRail en lugar de TabBar
  static bool shouldUseNavigationRail(BuildContext context) {
    return isDesktop && isWideScreen(context);
  }

  /// Padding horizontal adaptativo según plataforma
  static double getHorizontalPadding(BuildContext context) {
    if (shouldUseNavigationRail(context)) {
      return 24.0; // Más padding en desktop
    }
    return 16.0; // Padding estándar en móvil
  }

  /// Ancho máximo de contenido en desktop para evitar que se estire demasiado
  static double getMaxContentWidth(BuildContext context) {
    if (shouldUseNavigationRail(context)) {
      return 1200.0; // Limitar ancho en desktop
    }
    return double.infinity; // Sin límite en móvil
  }
}

