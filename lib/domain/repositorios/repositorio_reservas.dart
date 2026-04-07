import '../modelos/reserva.dart';
import '../../core/errores/excepciones.dart';
import '../../core/enums/enums.dart';

abstract class RepositorioReservas {
  // CRUD básico
  Future<Resultado<List<Reserva>>> obtenerReservas({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int limite = 20,
    String? ultimoDocumento,
  });

  Future<Resultado<Reserva>> obtenerReserva({
    required String empresaId,
    required String reservaId,
  });

  Future<Resultado<String>> crearReserva({
    required String empresaId,
    required Reserva reserva,
  });

  Future<Resultado<void>> actualizarReserva({
    required String empresaId,
    required Reserva reserva,
  });

  Future<Resultado<void>> eliminarReserva({
    required String empresaId,
    required String reservaId,
  });

  // Gestión de estados
  Future<Resultado<void>> cambiarEstadoReserva({
    required String empresaId,
    required String reservaId,
    required EstadoReserva nuevoEstado,
    String? notas,
  });

  Future<Resultado<void>> confirmarReserva({
    required String empresaId,
    required String reservaId,
  });

  Future<Resultado<void>> cancelarReserva({
    required String empresaId,
    required String reservaId,
    String? motivoCancelacion,
  });

  Future<Resultado<void>> completarReserva({
    required String empresaId,
    required String reservaId,
    String? notasComplecion,
  });

  // Consultas por fecha y estado
  Future<Resultado<List<Reserva>>> obtenerReservasDelDia({
    required String empresaId,
    DateTime? fecha,
  });

  Future<Resultado<List<Reserva>>> obtenerReservasSemana({
    required String empresaId,
    DateTime? inicioSemana,
  });

  Future<Resultado<List<Reserva>>> obtenerReservasPorEstado({
    required String empresaId,
    required EstadoReserva estado,
    int limite = 20,
  });

  Future<Resultado<List<Reserva>>> obtenerReservasPendientes({
    required String empresaId,
  });

  // Consultas por entidades relacionadas
  Future<Resultado<List<Reserva>>> obtenerReservasPorCliente({
    required String empresaId,
    required String clienteId,
    int limite = 20,
  });

  Future<Resultado<List<Reserva>>> obtenerReservasPorServicio({
    required String empresaId,
    required String servicioId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<List<Reserva>>> obtenerReservasPorEmpleado({
    required String empresaId,
    required String empleadoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  // Validaciones de disponibilidad
  Future<Resultado<bool>> validarDisponibilidad({
    required String empresaId,
    required DateTime fechaHora,
    required Duration duracion,
    String? empleadoId,
    String? reservaIdExistente,
  });

  Future<Resultado<List<DateTime>>> obtenerHorariosDisponibles({
    required String empresaId,
    required DateTime fecha,
    required Duration duracionServicio,
    String? empleadoId,
  });

  Future<Resultado<Map<String, List<DateTime>>>> obtenerDisponibilidadSemana({
    required String empresaId,
    required DateTime inicioSemana,
    required Duration duracionServicio,
  });

  // Estadísticas y reportes
  Future<Resultado<Map<String, dynamic>>> obtenerEstadisticasReservas({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<List<Map<String, dynamic>>>> generarReporteIngresos({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<Map<String, int>>> obtenerReservasPorMes({
    required String empresaId,
    int anio,
  });

  // Recordatorios y notificaciones
  Future<Resultado<List<Reserva>>> obtenerReservasParaRecordatorio({
    required String empresaId,
    Duration tiempoAntelacion = const Duration(hours: 2),
  });

  Future<Resultado<void>> marcarRecordatorioEnviado({
    required String empresaId,
    required String reservaId,
  });

  // Streaming para tiempo real
  Stream<List<Reserva>> streamReservasDelDia({
    required String empresaId,
    DateTime? fecha,
  });

  Stream<List<Reserva>> streamReservasPorEstado({
    required String empresaId,
    required EstadoReserva estado,
  });

  Stream<Reserva> streamReserva({
    required String empresaId,
    required String reservaId,
  });

  // Búsqueda avanzada
  Future<Resultado<List<Reserva>>> buscarReservas({
    required String empresaId,
    String? clienteNombre,
    String? servicioNombre,
    EstadoReserva? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int limite = 20,
  });

  // Gestión de conflictos
  Future<Resultado<List<Reserva>>> detectarConflictosHorarios({
    required String empresaId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Resultado<List<DateTime>>> sugerirHorrariosAlternativos({
    required String empresaId,
    required DateTime fechaPreferida,
    required Duration duracion,
    String? empleadoId,
  });
}
