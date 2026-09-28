import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración global persistente de la app (dark mode, etc.)
/// Usa ValueNotifier para que los widgets se reconstruyan automáticamente.
class AppSettings {
  AppSettings._();

  // ── Dark mode ──────────────────────────────────────────────────────────────
  static final darkMode = ValueNotifier<bool>(false);

  // ── Número de empresas accesibles (para mostrar/ocultar selector) ──────────
  static final numEmpresas = ValueNotifier<int>(0);

  // ── Tab del dashboard al que ir cuando se hace pop desde un módulo ──────────
  // null = sin target (el dashboard conserva su estado actual)
  static final targetTab = ValueNotifier<int?>(null);

  static void setTargetTab(int tab) {
    targetTab.value = tab;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cargar desde SharedPreferences al inicio (llamar en main.dart o en login)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    darkMode.value   = p.getBool('dark_mode')    ?? false;
    numEmpresas.value = p.getInt('num_empresas')  ?? 0;
  }

  static Future<void> setDark(bool value) async {
    darkMode.value = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark_mode', value);
  }

  static Future<void> setNumEmpresas(int count) async {
    numEmpresas.value = count;
    final p = await SharedPreferences.getInstance();
    await p.setInt('num_empresas', count);
  }

  /// true si debe mostrarse el botón de "Cambiar empresa"
  static bool get puedeVerSelectorEmpresas =>
      numEmpresas.value > 1;
}
