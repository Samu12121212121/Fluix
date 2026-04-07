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
    colorScheme: ColorScheme.fromSeed(
      seedColor: _colorPrimario,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 2,
      centerTitle: true,
    ),
  );
}


