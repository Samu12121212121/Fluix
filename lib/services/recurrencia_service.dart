import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/tarea.dart';
import '../domain/modelos/recurrencia_config.dart';

/// Servicio que gestiona la lógica de recurrencia de tareas.
///
/// Responsabilidades:
/// - Calcular la próxima fecha de una instancia recurrente.
/// - Crear instancias a partir de una plantilla.
/// - Pausar / reanudar / cancelar la recurrencia.
class RecurrenciaService {
  static final RecurrenciaService _i = RecurrenciaService._();
  factory RecurrenciaService() => _i;
  RecurrenciaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── CÁLCULO DE PRÓXIMA FECHA ─────────────────────────────────────────────

  /// Devuelve la próxima fecha en que se debe generar una instancia,
  /// calculada a partir de [desde] (normalmente la fecha de completado
  /// de la instancia anterior o DateTime.now()).
  ///
  /// Devuelve null si la recurrencia ha expirado (fechaFin superada).
  DateTime? calcularProximaFecha(
    ConfiguracionRecurrencia config,
    DateTime desde,
  ) {
    if (config.pausada) return null;
    if (config.fechaFin != null && desde.isAfter(config.fechaFin!)) return null;

    DateTime candidata;

    switch (config.frecuencia) {
      case FrecuenciaRecurrencia.diaria:
        candidata = DateTime(desde.year, desde.month, desde.day + 1, 8, 0);
        break;

      case FrecuenciaRecurrencia.semanal:
        candidata = _proximoDiaSemana(desde, config.diasSemana.isNotEmpty
            ? config.diasSemana
            : [DateTime.monday]);
        break;

      case FrecuenciaRecurrencia.quincenal:
        candidata = _proximoDiaSemana(
          desde.add(const Duration(days: 7)),
          config.diasSemana.isNotEmpty ? config.diasSemana : [DateTime.monday],
        );
        break;

      case FrecuenciaRecurrencia.mensual:
        candidata = _proximoDiaMes(desde, config.diaMes ?? 1);
        break;

      case FrecuenciaRecurrencia.anual:
        candidata = DateTime(desde.year + 1, desde.month, desde.day, 8, 0);
        break;
    }

    if (config.fechaFin != null && candidata.isAfter(config.fechaFin!)) return null;
    return candidata;
  }

  // ── HELPERS PRIVADOS ─────────────────────────────────────────────────────

  /// Devuelve el próximo día de la semana que coincida con uno de [dias]
  /// (1=Lun…7=Dom en formato ISO), comenzando el día SIGUIENTE a [desde].
  DateTime _proximoDiaSemana(DateTime desde, List<int> dias) {
    var siguiente = desde.add(const Duration(days: 1));
    for (var i = 0; i < 14; i++) {
      final iso = siguiente.weekday; // 1=Lun…7=Dom
      if (dias.contains(iso)) {
        return DateTime(siguiente.year, siguiente.month, siguiente.day, 8, 0);
      }
      siguiente = siguiente.add(const Duration(days: 1));
    }
    return siguiente;
  }

  /// Devuelve el siguiente mes con el día indicado.
  /// Si [dia] == 0, usa el último día del mes.
  DateTime _proximoDiaMes(DateTime desde, int dia) {
    var nextMonth = desde.month + 1;
    var nextYear = desde.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    final diaEfectivo = dia == 0
        ? DateTime(nextYear, nextMonth + 1, 0).day // último día
        : dia;
    final maxDia = DateTime(nextYear, nextMonth + 1, 0).day;
    return DateTime(nextYear, nextMonth, diaEfectivo.clamp(1, maxDia), 8, 0);
  }

  // ── CREAR INSTANCIA ──────────────────────────────────────────────────────

  /// Crea una nueva instancia de tarea a partir de la [plantilla], asignando
  /// [fechaLimite] como fecha límite de la nueva instancia.
  Future<Tarea> crearInstanciaDesde({
    required Tarea plantilla,
    required DateTime fechaLimite,
    required String generadoPorId,
  }) async {
    final ref = _db
        .collection('empresas')
        .doc(plantilla.empresaId)
        .collection('tareas')
        .doc();

    final ahora = DateTime.now();
    final config = plantilla.configuracionRecurrencia!;
    final proximaFecha = calcularProximaFecha(config, fechaLimite);

    final instancia = Tarea(
      id: ref.id,
      empresaId: plantilla.empresaId,
      titulo: plantilla.titulo,
      descripcion: plantilla.descripcion,
      tipo: plantilla.tipo,
      estado: EstadoTarea.pendiente,
      prioridad: plantilla.prioridad,
      equipoId: plantilla.equipoId,
      usuarioAsignadoId: plantilla.usuarioAsignadoId,
      creadoPorId: generadoPorId,
      fechaLimite: fechaLimite,
      etiquetas: List.from(plantilla.etiquetas),
      ubicacion: plantilla.ubicacion,
      tiempoEstimadoMin: plantilla.tiempoEstimadoMin,
      subtareas: plantilla.subtareas
          .map((s) => Subtarea(id: s.id, titulo: s.titulo, completada: false))
          .toList(),
      registroTiempo: [],
      historial: [
        EntradaHistorial(
          usuarioId: generadoPorId,
          accion: 'creacion_recurrente',
          descripcion: 'Instancia generada automáticamente',
          fecha: ahora,
        ),
      ],
      esRecurrente: true,
      configuracionRecurrencia: config,
      esPlantillaRecurrencia: false,
      plantillaId: plantilla.id,
      proximaFechaRecurrencia: proximaFecha,
      clienteId: plantilla.clienteId,
      recordatorio: plantilla.recordatorio,
      fechaCreacion: ahora,
    );

    await ref.set(instancia.toFirestore());

    // Actualizar la plantilla con ultima_generacion y proxima_fecha
    await _db
        .collection('empresas')
        .doc(plantilla.empresaId)
        .collection('tareas')
        .doc(plantilla.id)
        .update({
      'configuracion_recurrencia': config
          .copyWith(ultimaGeneracion: ahora)
          .toMap(),
      'proxima_fecha_recurrencia': proximaFecha != null
          ? Timestamp.fromDate(proximaFecha)
          : null,
    });

    return instancia;
  }

  // ── CONTROLES DE RECURRENCIA ─────────────────────────────────────────────

  Future<void> pausarRecurrencia(String empresaId, String tareaId) =>
      _actualizarPausada(empresaId, tareaId, true);

  Future<void> reanudarRecurrencia(String empresaId, String tareaId) =>
      _actualizarPausada(empresaId, tareaId, false);

  Future<void> _actualizarPausada(
    String empresaId,
    String tareaId,
    bool pausada,
  ) async {
    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;
    final configMap = data['configuracion_recurrencia'] as Map<String, dynamic>?;
    if (configMap == null) return;
    configMap['pausada'] = pausada;
    await ref.update({'configuracion_recurrencia': configMap});
  }

  /// Cancela la recurrencia de una plantilla.
  /// Si [eliminarInstanciasFuturas] es true, elimina las instancias pendientes.
  Future<void> cancelarRecurrencia(
    String empresaId,
    String tareaId, {
    bool eliminarInstanciasFuturas = false,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .update({
      'es_recurrente': false,
      'configuracion_recurrencia': null,
      'es_plantilla_recurrencia': false,
    });

    if (eliminarInstanciasFuturas) {
      final futuras = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('tareas')
          .where('plantilla_id', isEqualTo: tareaId)
          .where('estado', isEqualTo: EstadoTarea.pendiente.name)
          .get();
      final batch = _db.batch();
      for (final doc in futuras.docs) {
        batch.update(doc.reference, {'estado': EstadoTarea.cancelada.name});
      }
      await batch.commit();
    }
  }

  // ── STREAM DE INSTANCIAS ─────────────────────────────────────────────────

  /// Stream de todas las instancias generadas a partir de una plantilla.
  Stream<List<Tarea>> instanciasStream(String empresaId, String plantillaId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('tareas')
          .where('plantilla_id', isEqualTo: plantillaId)
          .orderBy('fecha_creacion', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Tarea.fromFirestore).toList());
}

