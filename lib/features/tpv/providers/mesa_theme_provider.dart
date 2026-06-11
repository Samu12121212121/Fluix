import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mesa_color_theme.dart';

class MesaThemeProvider extends ChangeNotifier {
  static const _prefKey = 'mesa_color_theme_id';

  MesaColorTheme _temaActual = MesaColorTheme.warmDark;

  MesaColorTheme get temaActual => _temaActual;

  Future<void> cargarTema() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKey) ?? MesaColorTheme.warmDark.id;
    _temaActual = MesaColorTheme.porId(id);
    notifyListeners();
  }

  Future<void> cambiarTema(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
    _temaActual = MesaColorTheme.porId(id);
    notifyListeners();
  }
}
