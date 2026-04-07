import 'package:flutter/material.dart';
import '../../domain/modelos/empresa_config.dart';
import '../../services/empresa_config_service.dart';

class EmpresaConfigProvider extends ChangeNotifier {
  EmpresaConfigProvider(this.empresaId);

  final String empresaId;
  final EmpresaConfigService _service = EmpresaConfigService();

  EmpresaConfig _config = const EmpresaConfig();
  EmpresaConfig get config => _config;

  bool _cargando = false;
  bool get cargando => _cargando;

  bool _guardando = false;
  bool get guardando => _guardando;

  String? _error;
  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _config = await _service.obtenerConfig(empresaId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void actualizarLocal(EmpresaConfig config) {
    _config = config;
    notifyListeners();
  }

  Future<void> guardar(EmpresaConfig config) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      await _service.guardarConfig(empresaId, config);
      _config = config;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}

