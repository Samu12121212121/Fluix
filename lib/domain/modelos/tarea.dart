import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrencia_config.dart';

enum RolTarea { administrador, manager, empleado }
enum TipoTarea { normal, checklist, incidencia, proyecto }
enum PrioridadTarea { urgente, alta, media, baja }
enum EstadoTarea { pendiente, enProgreso, enRevision, completada, cancelada }

class Equipo {
  final String id;
  final String empresaId;
  final String nombre;
  final String? descripcion;
  final String responsableId;
  final List<String> miembrosIds;
  final DateTime fechaCreacion;

  Equipo({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.descripcion,
    required this.responsableId,
    required this.miembrosIds,
    required this.fechaCreacion,
  });

  factory Equipo.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Equipo(
        id: doc.id, empresaId: '', nombre: 'Sin nombre',
        responsableId: '', miembrosIds: [], fechaCreacion: DateTime.now(),
      );
    }
    final data = raw as Map<String, dynamic>;
    return Equipo(
      id: doc.id,
      empresaId: data['empresa_id'] ?? '',
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'],
      responsableId: data['responsable_id'] ?? '',
      miembrosIds: List<String>.from(data['miembros_ids'] ?? []),
      fechaCreacion: _parseTimestamp(data['fecha_creacion']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'nombre': nombre,
    'descripcion': descripcion,
    'responsable_id': responsableId,
    'miembros_ids': miembrosIds,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
  };
}

class Subtarea {
  final String id;
  final String titulo;
  bool completada;

  Subtarea({required this.id, required this.titulo, this.completada = false});

  factory Subtarea.fromMap(Map<String, dynamic> data) => Subtarea(
    id: data['id'] ?? '',
    titulo: data['titulo'] ?? '',
    completada: data['completada'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'completada': completada,
  };
}

class EntradaTiempo {
  final String usuarioId;
  final DateTime inicio;
  final DateTime? fin;
  final int? segundos;

  EntradaTiempo({required this.usuarioId, required this.inicio, this.fin, this.segundos});

  factory EntradaTiempo.fromMap(Map<String, dynamic> data) => EntradaTiempo(
    usuarioId: data['usuario_id'] ?? '',
    inicio: _parseTimestamp(data['inicio']),
    fin: data['fin'] != null ? _parseTimestamp(data['fin']) : null,
    segundos: data['segundos'],
  );

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'inicio': Timestamp.fromDate(inicio),
    'fin': fin != null ? Timestamp.fromDate(fin!) : null,
    'segundos': segundos,
  };
}

class EntradaHistorial {
  final String usuarioId;
  final String accion;
  final String descripcion;
  final DateTime fecha;

  EntradaHistorial({
    required this.usuarioId,
    required this.accion,
    required this.descripcion,
    required this.fecha,
  });

  factory EntradaHistorial.fromMap(Map<String, dynamic> data) => EntradaHistorial(
    usuarioId: data['usuario_id'] ?? '',
    accion: data['accion'] ?? '',
    descripcion: data['descripcion'] ?? '',
    fecha: _parseTimestamp(data['fecha']),
  );

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'accion': accion,
    'descripcion': descripcion,
    'fecha': Timestamp.fromDate(fecha),
  };
}

class Tarea {
  final String id;
  final String empresaId;
  final String titulo;
  final String? descripcion;
  final TipoTarea tipo;
  final EstadoTarea estado;
  final PrioridadTarea prioridad;
  final String? equipoId;
  final String? usuarioAsignadoId;
  final String creadoPorId;
  final DateTime? fechaLimite;
  final List<String> etiquetas;
  final String? ubicacion;
  final int? tiempoEstimadoMin;
  final List<Subtarea> subtareas;
  final List<EntradaTiempo> registroTiempo;
  final List<EntradaHistorial> historial;
  final bool esRecurrente;
  final String? frecuenciaRecurrencia;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  /// Cuando es true, la tarea solo es visible para el rol Propietario.
  final bool soloPropietario;

  /// ID de la sugerencia que originó esta tarea (si aplica).
  final String? sugerenciaId;

  // ── NUEVOS CAMPOS ────────────────────────────────────────────

  /// ID del cliente vinculado a esta tarea (opcional).
  final String? clienteId;

  /// Configuración completa de recurrencia (reemplaza los campos simples).
  final ConfiguracionRecurrencia? configuracionRecurrencia;

  /// Configuración del recordatorio de esta tarea.
  final RecordatorioTarea? recordatorio;

  /// true si esta tarea es una plantilla de recurrencia (no una instancia).
  final bool esPlantillaRecurrencia;

  /// ID de la plantilla de la que se generó esta instancia (null si es plantilla o no es recurrente).
  final String? plantillaId;

  /// Fecha calculada de la próxima instancia a generar.
  final DateTime? proximaFechaRecurrencia;

  Tarea({
    required this.id,
    required this.empresaId,
    required this.titulo,
    this.descripcion,
    required this.tipo,
    required this.estado,
    required this.prioridad,
    this.equipoId,
    this.usuarioAsignadoId,
    required this.creadoPorId,
    this.fechaLimite,
    required this.etiquetas,
    this.ubicacion,
    this.tiempoEstimadoMin,
    required this.subtareas,
    required this.registroTiempo,
    required this.historial,
    this.esRecurrente = false,
    this.frecuenciaRecurrencia,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.soloPropietario = false,
    this.sugerenciaId,
    this.clienteId,
    this.configuracionRecurrencia,
    this.recordatorio,
    this.esPlantillaRecurrencia = false,
    this.plantillaId,
    this.proximaFechaRecurrencia,
  });

  bool get estaAtrasada =>
      fechaLimite != null &&
      fechaLimite!.isBefore(DateTime.now()) &&
      estado != EstadoTarea.completada &&
      estado != EstadoTarea.cancelada;

  int get totalSegundosTrabajados => registroTiempo
      .where((e) => e.segundos != null)
      .fold(0, (sum, e) => sum + (e.segundos ?? 0));

  int get subtareasCompletadas => subtareas.where((s) => s.completada).length;

  factory Tarea.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Tarea(
        id: doc.id, empresaId: '', titulo: 'Sin título',
        tipo: TipoTarea.normal, estado: EstadoTarea.cancelada,
        prioridad: PrioridadTarea.media, creadoPorId: '',
        etiquetas: [], subtareas: [], registroTiempo: [],
        historial: [], fechaCreacion: DateTime.now(),
      );
    }
    final data = raw as Map<String, dynamic>;
    return Tarea(
      id: doc.id,
      empresaId: data['empresa_id'] ?? '',
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'],
      tipo: TipoTarea.values.firstWhere(
        (e) => e.name == data['tipo'],
        orElse: () => TipoTarea.normal,
      ),
      estado: EstadoTarea.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoTarea.pendiente,
      ),
      prioridad: PrioridadTarea.values.firstWhere(
        (e) => e.name == data['prioridad'],
        orElse: () => PrioridadTarea.media,
      ),
      equipoId: data['equipo_id'],
      usuarioAsignadoId: data['usuario_asignado_id'],
      creadoPorId: data['creado_por_id'] ?? '',
      fechaLimite: data['fecha_limite'] != null ? _parseTimestamp(data['fecha_limite']) : null,
      etiquetas: List<String>.from(data['etiquetas'] ?? []),
      ubicacion: data['ubicacion'],
      tiempoEstimadoMin: data['tiempo_estimado_min'],
      subtareas: (data['subtareas'] as List<dynamic>? ?? [])
          .map((s) => Subtarea.fromMap(s as Map<String, dynamic>))
          .toList(),
      registroTiempo: (data['registro_tiempo'] as List<dynamic>? ?? [])
          .map((e) => EntradaTiempo.fromMap(e as Map<String, dynamic>))
          .toList(),
      historial: (data['historial'] as List<dynamic>? ?? [])
          .map((e) => EntradaHistorial.fromMap(e as Map<String, dynamic>))
          .toList(),
      esRecurrente: data['es_recurrente'] ?? false,
      frecuenciaRecurrencia: data['frecuencia_recurrencia'],
      fechaCreacion: _parseTimestamp(data['fecha_creacion']),
      fechaActualizacion: data['fecha_actualizacion'] != null
          ? _parseTimestamp(data['fecha_actualizacion'])
          : null,
      soloPropietario: data['solo_propietario'] as bool? ?? false,
      sugerenciaId: data['sugerencia_id'] as String?,
      clienteId: data['cliente_id'] as String?,
      configuracionRecurrencia: data['configuracion_recurrencia'] != null
          ? ConfiguracionRecurrencia.fromMap(
              data['configuracion_recurrencia'] as Map<String, dynamic>)
          : null,
      recordatorio: data['recordatorio'] != null
          ? RecordatorioTarea.fromMap(data['recordatorio'] as Map<String, dynamic>)
          : null,
      esPlantillaRecurrencia: data['es_plantilla_recurrencia'] as bool? ?? false,
      plantillaId: data['plantilla_id'] as String?,
      proximaFechaRecurrencia: data['proxima_fecha_recurrencia'] != null
          ? _parseTimestamp(data['proxima_fecha_recurrencia'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'titulo': titulo,
    'descripcion': descripcion,
    'tipo': tipo.name,
    'estado': estado.name,
    'prioridad': prioridad.name,
    'equipo_id': equipoId,
    'usuario_asignado_id': usuarioAsignadoId,
    'creado_por_id': creadoPorId,
    'fecha_limite': fechaLimite != null ? Timestamp.fromDate(fechaLimite!) : null,
    'etiquetas': etiquetas,
    'ubicacion': ubicacion,
    'tiempo_estimado_min': tiempoEstimadoMin,
    'subtareas': subtareas.map((s) => s.toMap()).toList(),
    'registro_tiempo': registroTiempo.map((e) => e.toMap()).toList(),
    'historial': historial.map((e) => e.toMap()).toList(),
    'es_recurrente': esRecurrente,
    'frecuencia_recurrencia': frecuenciaRecurrencia,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': fechaActualizacion != null ? Timestamp.fromDate(fechaActualizacion!) : null,
    'solo_propietario': soloPropietario,
    'sugerencia_id': sugerenciaId,
    'cliente_id': clienteId,
    'configuracion_recurrencia': configuracionRecurrencia?.toMap(),
    'recordatorio': recordatorio?.toMap(),
    'es_plantilla_recurrencia': esPlantillaRecurrencia,
    'plantilla_id': plantillaId,
    'proxima_fecha_recurrencia': proximaFechaRecurrencia != null
        ? Timestamp.fromDate(proximaFechaRecurrencia!)
        : null,
  };

  Tarea copyWith({
    String? titulo,
    String? descripcion,
    TipoTarea? tipo,
    EstadoTarea? estado,
    PrioridadTarea? prioridad,
    String? equipoId,
    String? usuarioAsignadoId,
    DateTime? fechaLimite,
    List<String>? etiquetas,
    String? ubicacion,
    int? tiempoEstimadoMin,
    List<Subtarea>? subtareas,
    List<EntradaTiempo>? registroTiempo,
    List<EntradaHistorial>? historial,
    bool? esRecurrente,
    String? frecuenciaRecurrencia,
    bool? soloPropietario,
    String? sugerenciaId,
    String? clienteId,
    ConfiguracionRecurrencia? configuracionRecurrencia,
    RecordatorioTarea? recordatorio,
    bool? esPlantillaRecurrencia,
    String? plantillaId,
    DateTime? proximaFechaRecurrencia,
  }) => Tarea(
    id: id,
    empresaId: empresaId,
    creadoPorId: creadoPorId,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    tipo: tipo ?? this.tipo,
    estado: estado ?? this.estado,
    prioridad: prioridad ?? this.prioridad,
    equipoId: equipoId ?? this.equipoId,
    usuarioAsignadoId: usuarioAsignadoId ?? this.usuarioAsignadoId,
    fechaLimite: fechaLimite ?? this.fechaLimite,
    ubicacion: ubicacion ?? this.ubicacion,
    tiempoEstimadoMin: tiempoEstimadoMin ?? this.tiempoEstimadoMin,
    subtareas: subtareas ?? this.subtareas,
    registroTiempo: registroTiempo ?? this.registroTiempo,
    historial: historial ?? this.historial,
    esRecurrente: esRecurrente ?? this.esRecurrente,
    frecuenciaRecurrencia: frecuenciaRecurrencia ?? this.frecuenciaRecurrencia,
    etiquetas: etiquetas ?? this.etiquetas,
    sugerenciaId: sugerenciaId ?? this.sugerenciaId,
    clienteId: clienteId ?? this.clienteId,
    configuracionRecurrencia: configuracionRecurrencia ?? this.configuracionRecurrencia,
    recordatorio: recordatorio ?? this.recordatorio,
    esPlantillaRecurrencia: esPlantillaRecurrencia ?? this.esPlantillaRecurrencia,
    plantillaId: plantillaId ?? this.plantillaId,
    proximaFechaRecurrencia: proximaFechaRecurrencia ?? this.proximaFechaRecurrencia,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: DateTime.now(),
  );
}

DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}


