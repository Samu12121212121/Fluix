import 'package:flutter/material.dart';
import '../../services/app_config_service.dart';

/// Provider global que gestiona ThemeMode y color primario en tiempo real.
/// Escúchalo con context.watch<AppConfigProvider>() en MaterialApp.
class AppConfigProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _colorPrimario = const Color(0xFF1976D2);

  ThemeMode get themeMode => _themeMode;
  Color get colorPrimario => _colorPrimario;

  final AppConfigService _svc = AppConfigService();

  /// Llamar una sola vez al arrancar la app
  Future<void> inicializar() async {
    _themeMode    = await _svc.cargarTema();
    _colorPrimario = await _svc.cargarColor();
    notifyListeners();
  }

  Future<void> cambiarTema(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _svc.guardarTema(mode);
  }

  Future<void> cambiarColor(Color color) async {
    _colorPrimario = color;
    notifyListeners();
    await _svc.guardarColor(color);
  }

  // Genera ThemeData a partir del color elegido
  ThemeData get temaClaro => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _colorPrimario,
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _colorPrimario,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
    ),
  );

  ThemeData get temaOscuro => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      // Colores principales
      primary: Color(0xFF6C63FF),              // Morado vibrante
      onPrimary: Color(0xFFFFFFFF),            // Blanco
      primaryContainer: Color(0xFF4B42CC),     // Morado más oscuro
      onPrimaryContainer: Color(0xFFE6E4FF),   // Morado muy claro
      
      // Colores secundarios
      secondary: Color(0xFFFF6584),             // Rosado
      onSecondary: Color(0xFFFFFFFF),           // Blanco
      secondaryContainer: Color(0xFFCC5169),    // Rosado más oscuro
      onSecondaryContainer: Color(0xFFFFE4EA),  // Rosado muy claro
      
      // Color de acento/terciario
      tertiary: Color(0xFF00D9FF),              // Azul claro vibrante
      onTertiary: Color(0xFF003545),            // Azul oscuro para contraste
      tertiaryContainer: Color(0xFF00A8CC),     // Azul medio
      onTertiaryContainer: Color(0xFFD0F7FF),   // Azul muy claro
      
      // Colores de estado
      error: Color(0xFFFF5252),                 // Rojo
      onError: Color(0xFFFFFFFF),               // Blanco
      errorContainer: Color(0xFFCC4141),        // Rojo más oscuro
      onErrorContainer: Color(0xFFFFDADA),      // Rojo muy claro
      
      // Fondos y superficies
      surface: Color(0xFF151932),               // Azul más oscuro
      onSurface: Color(0xFFFFFFFF),             // Texto primario blanco
      surfaceContainerHighest: Color(0xFF1E2139), // Tarjeta gris azulado
      surfaceDim: Color(0xFF0A0E27),            // Fondo principal azul oscuro
      
      // Colores de texto y bordes
      onSurfaceVariant: Color(0xFFB0B3C1),      // Texto secundario gris claro
      outline: Color(0xFF6B6E82),               // Texto sugerencia/gris medio
      outlineVariant: Color(0xFF2A2E45),        // Divisores sutiles
      
      // Inversiones para algunos componentes
      inverseSurface: Color(0xFFFFFFFF),
      onInverseSurface: Color(0xFF0A0E27),
      inversePrimary: Color(0xFF6C63FF),
      
      // Shadow y scrim
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0E27), // Fondo principal
    cardColor: const Color(0xFF1E2139),               // Color de tarjetas
    dividerColor: const Color(0xFF2A2E45),            // Divisores
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF151932),  // Superficie para AppBar
      foregroundColor: Color(0xFFFFFFFF),  // Texto blanco
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
    ),
    // Tema de botones
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF), // Primario morado
        foregroundColor: const Color(0xFFFFFFFF), // Texto blanco
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E2139), // Tarjeta
        foregroundColor: const Color(0xFFFFFFFF), // Texto blanco
      ),
    ),
    // Tema de inputs
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1E2139),       // Tarjeta
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF6B6E82)), // Outline
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF6B6E82)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2), // Primario
      ),
    ),
    // Tema de navegación
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF151932), // Superficie
      indicatorColor: Color(0xFF6C63FF),  // Primario
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: Color(0xFFB0B3C1), fontSize: 12), // Texto secundario
      ),
    ),
    // Tema de chips
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFF1E2139),  // Tarjeta
      selectedColor: Color(0xFF6C63FF),    // Primario
      labelStyle: TextStyle(color: Color(0xFFFFFFFF)),
    ),
  );
}


