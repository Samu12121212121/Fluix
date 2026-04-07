import '../modelos/cliente.dart';
import '../../core/errores/excepciones.dart';

abstract class RepositorioClientes {
  // CRUD básico
  Future<Resultado<List<Cliente>>> obtenerClientes({
    required String empresaId,
    int limite = 20,
    String? ultimoDocumento,
  });

  Future<Resultado<Cliente>> obtenerCliente({
    required String empresaId,
    required String clienteId,
  });

  Future<Resultado<String>> crearCliente({
    required String empresaId,
    required Cliente cliente,
  });

  Future<Resultado<void>> actualizarCliente({
    required String empresaId,
    required Cliente cliente,
  });

  Future<Resultado<void>> eliminarCliente({
    required String empresaId,
    required String clienteId,
  });

  // Búsqueda y filtrado
  Future<Resultado<List<Cliente>>> buscarClientes({
    required String empresaId,
    required String termino,
    int limite = 20,
  });

  Future<Resultado<List<Cliente>>> obtenerClientesPorEtiqueta({
    required String empresaId,
    required String etiqueta,
  });

  Future<Resultado<List<Cliente>>> obtenerClientesFrecuentes({
    required String empresaId,
    int minReservas = 5,
  });

  Future<Resultado<List<Cliente>>> obtenerClientesVip({
    required String empresaId,
    double minGasto = 1000.0,
  });

  // Gestión de etiquetas
  Future<Resultado<void>> agregarEtiqueta({
    required String empresaId,
    required String clienteId,
    required String etiqueta,
  });

  Future<Resultado<void>> removerEtiqueta({
    required String empresaId,
    required String clienteId,
    required String etiqueta,
  });

  Future<Resultado<List<String>>> obtenerTodasEtiquetas(String empresaId);

  // Estadísticas de cliente
  Future<Resultado<void>> actualizarEstadisticasCliente({
    required String empresaId,
    required String clienteId,
    double? gastoAdicional,
    bool? nuevaVisita,
  });

  Future<Resultado<Map<String, dynamic>>> obtenerEstadisticasGenerales(
    String empresaId,
  );

  // Historial y actividad
  Future<Resultado<List<Map<String, dynamic>>>> obtenerHistorialCliente({
    required String empresaId,
    required String clienteId,
  });

  Future<Resultado<List<Cliente>>> obtenerClientesRecientes({
    required String empresaId,
    int dias = 30,
  });

  // Streaming para tiempo real
  Stream<List<Cliente>> streamClientes({
    required String empresaId,
    int limite = 20,
  });

  Stream<Cliente> streamCliente({
    required String empresaId,
    required String clienteId,
  });

  // Validaciones
  Future<Resultado<bool>> validarTelefonoUnico({
    required String empresaId,
    required String telefono,
    String? clienteIdExistente,
  });

  Future<Resultado<bool>> validarCorreoUnico({
    required String empresaId,
    required String correo,
    String? clienteIdExistente,
  });

  // Importación y exportación
  Future<Resultado<List<Cliente>>> importarClientes({
    required String empresaId,
    required List<Map<String, dynamic>> datosClientes,
  });

  Future<Resultado<List<Map<String, dynamic>>>> exportarClientes(
    String empresaId,
  );

  // Análisis y reportes
  Future<Resultado<Map<String, dynamic>>> generarReporteClientes({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<List<Cliente>>> obtenerClientesInactivos({
    required String empresaId,
    int diasInactividad = 90,
  });
}
