import '../modelos/empresa.dart';
import '../../core/errores/excepciones.dart';
import '../../core/enums/enums.dart';

abstract class RepositorioEmpresa {
  // CRUD básico
  Future<Resultado<Empresa>> obtenerEmpresa(String empresaId);
  Future<Resultado<Empresa>> crearEmpresa(Empresa empresa);
  Future<Resultado<void>> actualizarEmpresa(Empresa empresa);
  Future<Resultado<void>> eliminarEmpresa(String empresaId);

  // Perfil de empresa
  Future<Resultado<PerfilEmpresa>> obtenerPerfil(String empresaId);
  Future<Resultado<void>> actualizarPerfil({
    required String empresaId,
    required PerfilEmpresa perfil,
  });

  // Suscripción
  Future<Resultado<SuscripcionEmpresa>> obtenerSuscripcion(String empresaId);
  Future<Resultado<void>> actualizarSuscripcion({
    required String empresaId,
    required SuscripcionEmpresa suscripcion,
  });

  Future<Resultado<void>> renovarSuscripcion({
    required String empresaId,
    required double monto,
    required String transaccionId,
  });

  Future<Resultado<bool>> validarSuscripcionActiva(String empresaId);

  // Configuración
  Future<Resultado<ConfiguracionEmpresa>> obtenerConfiguracion(String empresaId);
  Future<Resultado<void>> actualizarConfiguracion({
    required String empresaId,
    required ConfiguracionEmpresa configuracion,
  });

  Future<Resultado<void>> toggleModulo({
    required String empresaId,
    required ModuloEmpresa modulo,
  });

  Future<Resultado<List<ModuloEmpresa>>> obtenerModulosActivos(String empresaId);

  // Estadísticas
  Future<Resultado<EstadisticasEmpresa>> obtenerEstadisticas(String empresaId);
  Future<Resultado<void>> actualizarEstadisticas({
    required String empresaId,
    required EstadisticasEmpresa estadisticas,
  });

  Future<Resultado<void>> incrementarContador({
    required String empresaId,
    required String campo,
    int incremento = 1,
  });

  // Búsqueda y filtrado
  Future<Resultado<List<Empresa>>> buscarEmpresas({
    String? termino,
    int limite = 20,
    String? ultimoDocumento,
  });

  Future<Resultado<List<Empresa>>> obtenerEmpresasPorEstado(
    EstadoSuscripcion estado,
  );

  // Streaming para tiempo real
  Stream<Empresa> streamEmpresa(String empresaId);
  Stream<SuscripcionEmpresa> streamSuscripcion(String empresaId);
  Stream<EstadisticasEmpresa> streamEstadisticas(String empresaId);

  // Validaciones de negocio
  Future<Resultado<bool>> validarNombreDisponible(String nombre);
  Future<Resultado<bool>> puedeUsarModulo({
    required String empresaId,
    required ModuloEmpresa modulo,
  });

  // Reportes y exportación
  Future<Resultado<Map<String, dynamic>>> generarReporteEstadisticas({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<List<Map<String, dynamic>>>> exportarDatos(String empresaId);
}
