import 'package:flutter/material.dart';

// Clase para el tema principal de la aplicación - versión simple
class TemaApp {
  static const Color _colorPrimario = Color(0xFF1976D2);

  static ThemeData get temaClaro {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _colorPrimario,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
    );
  }

  static ThemeData get temaOscuro {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _colorPrimario,
        brightness: Brightness.dark,
      ),
    );
  }

  // Colores de estado para indicadores
  static const Color colorExito = Color(0xFF4CAF50);
  static const Color colorError = Color(0xFFF44336);
  static const Color colorAdvertencia = Color(0xFFFF9800);
  static const Color colorInfo = Color(0xFF2196F3);
}

// Extensiones para el contexto
extension TemaContext on BuildContext {
  ThemeData get tema => Theme.of(this);
  ColorScheme get colores => tema.colorScheme;
  TextTheme get textos => tema.textTheme;
}

// Espaciado consistente
class Espaciado {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
