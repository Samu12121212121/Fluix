import 'package:flutter/foundation.dart';

// Provider temporal simplificado para autenticación
enum EstadoAutenticacion {
  inicial,
  cargando,
  autenticado,
  noAutenticado,
  error,
  requiereOnboarding,
}

class ProviderAutenticacion with ChangeNotifier {
  EstadoAutenticacion _estado = EstadoAutenticacion.inicial;
  String? _mensajeError;

  // Getters
  EstadoAutenticacion get estado => _estado;
  String? get mensajeError => _mensajeError;
  bool get estaAutenticado => _estado == EstadoAutenticacion.autenticado;
  bool get estaCargando => _estado == EstadoAutenticacion.cargando;

  // Métodos simplificados temporales
  Future<void> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    _cambiarEstado(EstadoAutenticacion.cargando);
    _limpiarError();

    try {
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(seconds: 1)); // Simulación
      _cambiarEstado(EstadoAutenticacion.autenticado);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> registrarEmpresa({
    required String nombreEmpresa,
    required String correoEmpresa,
    required String telefonoEmpresa,
    required String direccionEmpresa,
    required String nombrePropietario,
    required String correoPropietario,
    required String telefonoPropietario,
    required String password,
  }) async {
    _cambiarEstado(EstadoAutenticacion.cargando);
    _limpiarError();

    try {
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(seconds: 2)); // Simulación
      _cambiarEstado(EstadoAutenticacion.requiereOnboarding);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> cerrarSesion() async {
    _cambiarEstado(EstadoAutenticacion.cargando);

    try {
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(milliseconds: 500)); // Simulación
      _cambiarEstado(EstadoAutenticacion.noAutenticado);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> enviarRecuperacionPassword(String correo) async {
    _limpiarError();

    try {
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(seconds: 1)); // Simulación
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  void completarOnboarding() {
    if (_estado == EstadoAutenticacion.requiereOnboarding) {
      _cambiarEstado(EstadoAutenticacion.autenticado);
    }
  }

  void _cambiarEstado(EstadoAutenticacion nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  void _manejarError(String error) {
    _mensajeError = error;
    _cambiarEstado(EstadoAutenticacion.error);
  }

  void _limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }


  void limpiarError() => _limpiarError();
}
