import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/tarea.dart';
import '../domain/modelos/recurrencia_config.dart';

class TareasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── EQUIPOS ──────────────────────────────────────────────────

  Stream<List<Equipo>> equiposStream(String empresaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('equipos')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs.map(Equipo.fromFirestore).toList());

  Future<Equipo> crearEquipo({
    required String empresaId,
    required String nombre,
    required String responsableId,
    String? descripcion,
    List<String> miembrosIds = const [],
  }) async {
    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('equipos')
        .doc();
    final equipo = Equipo(
      id: ref.id,
      empresaId: empresaId,
      nombre: nombre,
      descripcion: descripcion,
      responsableId: responsableId,
      miembrosIds: [...miembrosIds, responsableId],
      fechaCreacion: DateTime.now(),
    );
    await ref.set(equipo.toFirestore());
    return equipo;
  }

  Future<void> actualizarEquipo(String empresaId, String equipoId, Map<String, dynamic> datos) =>
      _db.collection('empresas').doc(empresaId).collection('equipos').doc(equipoId).update(datos);

  Future<void> eliminarEquipo(String empresaId, String equipoId) =>
      _db.collection('empresas').doc(empresaId).collection('equipos').doc(equipoId).delete();

  // ── TAREAS ──────────────────────────────────────────────────

  Stream<List<Tarea>> tareasStream(String empresaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('tareas')
      .orderBy('fecha_creacion', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Tarea.fromFirestore).toList());

  Stream<List<Tarea>> tareasPorEstadoStream(String empresaId, EstadoTarea estado) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('tareas')
      .orderBy('fecha_creacion', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map(Tarea.fromFirestore)
          .where((t) => t.estado == estado)
          .toList());

  Stream<List<Tarea>> tareasPorEquipoStream(String empresaId, String equipoId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('tareas')
      .where('equipo_id', isEqualTo: equipoId)
      .snapshots()
      .map((s) => s.docs.map(Tarea.fromFirestore).toList());

  Stream<List<Tarea>> tareasPorUsuarioStream(String empresaId, String usuarioId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('tareas')
      .where('usuario_asignado_id', isEqualTo: usuarioId)
      .snapshots()
      .map((s) => s.docs.map(Tarea.fromFirestore).toList());

  /// Devuelve todas las tareas filtrando las de soloPropietario si el usuario no lo es.
  Stream<List<Tarea>> tareasVisiblesStream(String empresaId, {bool esPropietario = false}) =>
      tareasStream(empresaId).map((tareas) {
        if (esPropietario) return tareas;
        return tareas.where((t) => !t.soloPropietario).toList();
      });

  Future<Tarea> crearTarea({
    required String empresaId,
    required String titulo,
    required String creadoPorId,
    TipoTarea tipo = TipoTarea.normal,
    PrioridadTarea prioridad = PrioridadTarea.media,
    String? descripcion,
    String? equipoId,
    String? usuarioAsignadoId,
    DateTime? fechaLimite,
    List<String> etiquetas = const [],
    String? ubicacion,
    int? tiempoEstimadoMin,
    List<Subtarea> subtareas = const [],
    /// Si true, la tarea solo es visible para el rol Propietario.
    bool soloPropietario = false,
    /// ID de la sugerencia que originó esta tarea.
    String? sugerenciaId,
    String? clienteId,
    ConfiguracionRecurrencia? configuracionRecurrencia,
    bool esPlantillaRecurrencia = false,
    RecordatorioTarea? recordatorio,
  }) async {
    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc();
    final ahora = DateTime.now();
    final tarea = Tarea(
      id: ref.id,
      empresaId: empresaId,
      titulo: titulo,
      descripcion: descripcion,
      tipo: tipo,
      estado: EstadoTarea.pendiente,
      prioridad: prioridad,
      equipoId: equipoId,
      usuarioAsignadoId: usuarioAsignadoId,
      creadoPorId: creadoPorId,
      fechaLimite: fechaLimite,
      etiquetas: etiquetas,
      ubicacion: ubicacion,
      tiempoEstimadoMin: tiempoEstimadoMin,
      subtareas: subtareas,
      registroTiempo: [],
      historial: [
        EntradaHistorial(
          usuarioId: creadoPorId,
          accion: 'creacion',
          descripcion: 'Tarea creada',
          fecha: ahora,
        ),
      ],
      fechaCreacion: ahora,
      soloPropietario: soloPropietario,
      sugerenciaId: sugerenciaId,
      clienteId: clienteId,
      configuracionRecurrencia: configuracionRecurrencia,
      esRecurrente: configuracionRecurrencia != null,
      esPlantillaRecurrencia: esPlantillaRecurrencia,
      recordatorio: recordatorio,
    );
    await ref.set(tarea.toFirestore());
    return tarea;
  }

  Future<void> cambiarEstado(
    String empresaId,
    String tareaId,
    EstadoTarea nuevoEstado,
    String usuarioId,
  ) async {
    final entrada = EntradaHistorial(
      usuarioId: usuarioId,
      accion: 'cambio_estado',
      descripcion: 'Estado cambiado a ${_nombreEstado(nuevoEstado)}',
      fecha: DateTime.now(),
    );
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .update({
      'estado': nuevoEstado.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
  }

  Future<void> actualizarTarea(
    String empresaId,
    String tareaId,
    Map<String, dynamic> datos,
    String usuarioId,
    String descripcionCambio,
  ) async {
    final entrada = EntradaHistorial(
      usuarioId: usuarioId,
      accion: 'actualizacion',
      descripcion: descripcionCambio,
      fecha: DateTime.now(),
    );
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .update({
      ...datos,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
  }

  Future<void> eliminarTarea(String empresaId, String tareaId) =>
      _db.collection('empresas').doc(empresaId).collection('tareas').doc(tareaId).delete();

  Future<void> actualizarSubtareas(
    String empresaId,
    String tareaId,
    List<Subtarea> subtareas,
  ) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .update({
      'subtareas': subtareas.map((s) => s.toMap()).toList(),
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── MENSAJES DE CHAT ──────────────────────────────────────────

  Stream<QuerySnapshot> mensajesTareaStream(String empresaId, String tareaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('tareas')
      .doc(tareaId)
      .collection('mensajes')
      .orderBy('fecha')
      .snapshots();

  Future<void> enviarMensaje({
    required String empresaId,
    required String tareaId,
    required String usuarioId,
    required String nombreUsuario,
    required String texto,
    String? imagenUrl,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .collection('mensajes')
        .add({
      'usuario_id': usuarioId,
      'nombre_usuario': nombreUsuario,
      'texto': texto,
      'imagen_url': imagenUrl,
      'fecha': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── ESTADÍSTICAS ──────────────────────────────────────────────

  Future<Map<String, dynamic>> obtenerResumenTareas(String empresaId) async {
    final snapshot = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .get();

    final tareas = snapshot.docs.map(Tarea.fromFirestore).toList();
    final ahora = DateTime.now();

    return {
      'total': tareas.length,
      'pendientes': tareas.where((t) => t.estado == EstadoTarea.pendiente).length,
      'en_progreso': tareas.where((t) => t.estado == EstadoTarea.enProgreso).length,
      'en_revision': tareas.where((t) => t.estado == EstadoTarea.enRevision).length,
      'completadas': tareas.where((t) => t.estado == EstadoTarea.completada).length,
      'canceladas': tareas.where((t) => t.estado == EstadoTarea.cancelada).length,
      'atrasadas': tareas.where((t) => t.estaAtrasada).length,
      'completadas_hoy': tareas.where((t) =>
        t.estado == EstadoTarea.completada &&
        t.fechaActualizacion != null &&
        t.fechaActualizacion!.day == ahora.day &&
        t.fechaActualizacion!.month == ahora.month &&
        t.fechaActualizacion!.year == ahora.year
      ).length,
    };
  }

  String _nombreEstado(EstadoTarea e) {
    switch (e) {
      case EstadoTarea.pendiente: return 'Pendiente';
      case EstadoTarea.enProgreso: return 'En Progreso';
      case EstadoTarea.enRevision: return 'En Revisión';
      case EstadoTarea.completada: return 'Completada';
      case EstadoTarea.cancelada: return 'Cancelada';
    }
  }
}

