import 'package:flutter/material.dart';

// Clase para el tema principal de la aplicación
class TemaApp {
  static const Color _colorPrimario = Color(0xFF1976D2);
  static const Color _colorSecundario = Color(0xFFFFC107);
  static const Color _colorExito = Color(0xFF4CAF50);
  static const Color _colorError = Color(0xFFF44336);
  static const Color _colorAdvertencia = Color(0xFFFF9800);
  static const Color _colorInfo = Color(0xFF2196F3);

  static ThemeData get temaClaro {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _colorPrimario,
        brightness: Brightness.light,
      ).copyWith(
        primary: _colorPrimario,
        secondary: _colorSecundario,
        error: _colorError,
        surface: Colors.white,
        onSurface: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorPrimario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _colorPrimario,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _colorPrimario,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get temaOscuro {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _colorPrimario,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _colorPrimario,
        secondary: _colorSecundario,
        error: _colorError,
        surface: const Color(0xFF121212),
        onSurface: Colors.white70,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  // Colores de estado para indicadores
  static const Color colorExito = _colorExito;
  static const Color colorError = _colorError;
  static const Color colorAdvertencia = _colorAdvertencia;
  static const Color colorInfo = _colorInfo;

  // Colores por estado de reserva
  static Color colorEstadoReserva(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return _colorAdvertencia;
      case 'confirmada':
        return _colorInfo;
      case 'completada':
        return _colorExito;
      case 'cancelada':
        return _colorError;
      default:
        return Colors.grey;
    }
  }

  // Colores por estado de suscripción
  static Color colorEstadoSuscripcion(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return _colorExito;
      case 'vencida':
        return _colorError;
      case 'pendiente':
        return _colorAdvertencia;
      case 'suspendida':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
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

