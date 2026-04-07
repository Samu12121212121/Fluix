import '../repositorios/repositorio_empresa.dart';
import '../modelos/empresa.dart';
import '../../core/errores/excepciones.dart';
import '../../core/enums/enums.dart';

class CasoUsoGestionarModulos {
  final RepositorioEmpresa _repositorioEmpresa;

  CasoUsoGestionarModulos(this._repositorioEmpresa);

  Future<Resultado<List<ModuloEmpresa>>> obtenerModulosDisponibles() async {
    try {
      // Retornar todos los módulos disponibles
      return Resultado.exitoso(ModuloEmpresa.values);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<List<ModuloEmpresa>>> obtenerModulosActivos(
    String empresaId,
  ) async {
    try {
      final resultado = await _repositorioEmpresa.obtenerModulosActivos(empresaId);
      return resultado;
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<void>> activarModulo({
    required String empresaId,
    required ModuloEmpresa modulo,
  }) async {
    try {
      // 1. Validar suscripción activa
      final validacionSuscripcion = await _repositorioEmpresa.validarSuscripcionActiva(
        empresaId,
      );

      if (validacionSuscripcion.esFallo || !validacionSuscripcion.datosOError) {
        return Resultado.error(const ExcepcionSuscripcion(
          'Suscripción vencida. No se pueden activar módulos.',
        ));
      }

      // 2. Activar módulo
      final resultado = await _repositorioEmpresa.toggleModulo(
        empresaId: empresaId,
        modulo: modulo,
      );

      return resultado;
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<void>> desactivarModulo({
    required String empresaId,
    required ModuloEmpresa modulo,
  }) async {
    try {
      // Validar que no sea un módulo crítico
      if (_esModuloCritico(modulo)) {
        return Resultado.error(const ExcepcionValidacion(
          'Este módulo es esencial y no puede desactivarse.',
        ));
      }

      final resultado = await _repositorioEmpresa.toggleModulo(
        empresaId: empresaId,
        modulo: modulo,
      );

      return resultado;
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<Map<ModuloEmpresa, bool>>> obtenerEstadoModulos(
    String empresaId,
  ) async {
    try {
      final resultadoConfiguracion = await _repositorioEmpresa.obtenerConfiguracion(
        empresaId,
      );

      if (resultadoConfiguracion.esFallo) {
        return Resultado.error(resultadoConfiguracion.excepcion!);
      }

      final configuracion = resultadoConfiguracion.datosOError;
      return Resultado.exitoso(configuracion.modulosActivos);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  bool _esModuloCritico(ModuloEmpresa modulo) {
    // Módulos que siempre deben estar activos
    final modulosCriticos = [
      ModuloEmpresa.reservas,
      ModuloEmpresa.clientes,
    ];

    return modulosCriticos.contains(modulo);
  }
}

class CasoUsoValidarSuscripcion {
  final RepositorioEmpresa _repositorioEmpresa;

  CasoUsoValidarSuscripcion(this._repositorioEmpresa);

  Future<Resultado<EstadoSuscripcion>> validarEstado(String empresaId) async {
    try {
      final resultadoSuscripcion = await _repositorioEmpresa.obtenerSuscripcion(
        empresaId,
      );

      if (resultadoSuscripcion.esFallo) {
        return Resultado.error(resultadoSuscripcion.excepcion!);
      }

      final suscripcion = resultadoSuscripcion.datosOError;

      // Verificar estado según fecha actual
      final ahora = DateTime.now();

      if (suscripcion.fechaFin.isBefore(ahora)) {
        // Suscripción vencida - actualizar estado
        final suscripcionActualizada = suscripcion.copyWith(
          estado: EstadoSuscripcion.vencida,
        );

        await _repositorioEmpresa.actualizarSuscripcion(
          empresaId: empresaId,
          suscripcion: suscripcionActualizada,
        );

        return Resultado.exitoso(EstadoSuscripcion.vencida);
      }

      return Resultado.exitoso(suscripcion.estado);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<bool>> requiereAviso(String empresaId) async {
    try {
      final resultadoSuscripcion = await _repositorioEmpresa.obtenerSuscripcion(
        empresaId,
      );

      if (resultadoSuscripcion.esFallo) {
        return Resultado.error(resultadoSuscripcion.excepcion!);
      }

      final suscripcion = resultadoSuscripcion.datosOError;
      return Resultado.exitoso(suscripcion.requiereAviso);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<int>> diasRestantes(String empresaId) async {
    try {
      final resultadoSuscripcion = await _repositorioEmpresa.obtenerSuscripcion(
        empresaId,
      );

      if (resultadoSuscripcion.esFallo) {
        return Resultado.error(resultadoSuscripcion.excepcion!);
      }

      final suscripcion = resultadoSuscripcion.datosOError;
      return Resultado.exitoso(suscripcion.diasRestantes);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  Future<Resultado<void>> marcarAvisoEnviado(String empresaId) async {
    try {
      final resultadoSuscripcion = await _repositorioEmpresa.obtenerSuscripcion(
        empresaId,
      );

      if (resultadoSuscripcion.esFallo) {
        return Resultado.error(resultadoSuscripcion.excepcion!);
      }

      final suscripcion = resultadoSuscripcion.datosOError;
      final suscripcionActualizada = suscripcion.copyWith(
        avisoEnviado: true,
      );

      return await _repositorioEmpresa.actualizarSuscripcion(
        empresaId: empresaId,
        suscripcion: suscripcionActualizada,
      );
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }
}
