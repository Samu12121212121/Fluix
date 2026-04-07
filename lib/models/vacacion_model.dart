import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// VACACIONES Y AUSENCIAS — Modelo de datos
// ═══════════════════════════════════════════════════════════════════════════════

/// Tipo principal de solicitud de vacaciones/ausencia.
enum TipoAusencia {
  vacaciones,
  ausenciaJustificada,
  ausenciaInjustificada,
  permisoRetribuido,
  bajaMedica, // IT / baja médica
}

extension TipoAusenciaExt on TipoAusencia {
  String get etiqueta {
    switch (this) {
      case TipoAusencia.vacaciones:
        return 'Vacaciones';
      case TipoAusencia.ausenciaJustificada:
        return 'Ausencia justificada';
      case TipoAusencia.ausenciaInjustificada:
        return 'Ausencia injustificada';
      case TipoAusencia.permisoRetribuido:
        return 'Permiso retribuido';
      case TipoAusencia.bajaMedica:
        return 'IT / Baja médica';
    }
  }

  String get valor {
    switch (this) {
      case TipoAusencia.vacaciones:
        return 'vacaciones';
      case TipoAusencia.ausenciaJustificada:
        return 'ausencia_justificada';
      case TipoAusencia.ausenciaInjustificada:
        return 'ausencia_injustificada';
      case TipoAusencia.permisoRetribuido:
        return 'permiso_retribuido';
      case TipoAusencia.bajaMedica:
        return 'baja_medica';
    }
  }

  static TipoAusencia fromString(String? s) {
    switch (s) {
      case 'vacaciones':
        return TipoAusencia.vacaciones;
      case 'ausencia_justificada':
        return TipoAusencia.ausenciaJustificada;
      case 'ausencia_injustificada':
        return TipoAusencia.ausenciaInjustificada;
      case 'permiso_retribuido':
        return TipoAusencia.permisoRetribuido;
      case 'baja_medica':
        return TipoAusencia.bajaMedica;
      default:
        return TipoAusencia.vacaciones;
    }
  }

  /// ¿Descuenta salario?
  bool get descuentaSalario => this == TipoAusencia.ausenciaInjustificada;
}

/// Subtipo de permiso retribuido (art. 37 ET).
enum SubtipoPermiso {
  matrimonio,
  nacimiento,
  fallecimiento1erGrado,
  fallecimiento2oGrado,
  mudanza,
  deberInexcusable,
  examenOficial,
  otro,
}

extension SubtipoPermisoExt on SubtipoPermiso {
  String get etiqueta {
    switch (this) {
      case SubtipoPermiso.matrimonio:
        return 'Matrimonio (15 días)';
      case SubtipoPermiso.nacimiento:
        return 'Nacimiento/adopción hijo (2 días)';
      case SubtipoPermiso.fallecimiento1erGrado:
        return 'Fallecimiento familiar 1er grado (3-4 días)';
      case SubtipoPermiso.fallecimiento2oGrado:
        return 'Fallecimiento familiar 2º grado (2-3 días)';
      case SubtipoPermiso.mudanza:
        return 'Mudanza (1 día)';
      case SubtipoPermiso.deberInexcusable:
        return 'Deber inexcusable (tiempo necesario)';
      case SubtipoPermiso.examenOficial:
        return 'Examen oficial (tiempo necesario)';
      case SubtipoPermiso.otro:
        return 'Otro permiso retribuido';
    }
  }

  String get valor => name;

  /// Días máximos por defecto según art. 37 ET.
  int get diasMaxDefecto {
    switch (this) {
      case SubtipoPermiso.matrimonio:
        return 15;
      case SubtipoPermiso.nacimiento:
        return 2;
      case SubtipoPermiso.fallecimiento1erGrado:
        return 4; // con desplazamiento
      case SubtipoPermiso.fallecimiento2oGrado:
        return 3; // con desplazamiento
      case SubtipoPermiso.mudanza:
        return 1;
      case SubtipoPermiso.deberInexcusable:
        return 5; // estimación
      case SubtipoPermiso.examenOficial:
        return 1;
      case SubtipoPermiso.otro:
        return 1;
    }
  }

  static SubtipoPermiso fromString(String? s) {
    for (final v in SubtipoPermiso.values) {
      if (v.name == s) return v;
    }
    return SubtipoPermiso.otro;
  }
}

/// Estado de la solicitud.
enum EstadoSolicitud { solicitado, aprobado, rechazado }

extension EstadoSolicitudExt on EstadoSolicitud {
  String get etiqueta {
    switch (this) {
      case EstadoSolicitud.solicitado:
        return 'Solicitado';
      case EstadoSolicitud.aprobado:
        return 'Aprobado';
      case EstadoSolicitud.rechazado:
        return 'Rechazado';
    }
  }
}

// ── MODELO SOLICITUD ──────────────────────────────────────────────────────────

class SolicitudVacaciones {
  final String id;
  final String empleadoId;
  final String empresaId;
  final TipoAusencia tipo;
  final SubtipoPermiso? subtipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int diasNaturales;
  final int diasLaborables;
  final EstadoSolicitud estado;
  final String? notas;
  final String? motivoRechazo;
  final double descuentoSalario;
  final String? nominaAfectada;
  final DateTime fechaCreacion;
  final String? empleadoNombre; // desnormalizado para listados

  const SolicitudVacaciones({
    required this.id,
    required this.empleadoId,
    required this.empresaId,
    required this.tipo,
    this.subtipo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.diasNaturales,
    this.diasLaborables = 0,
    this.estado = EstadoSolicitud.solicitado,
    this.notas,
    this.motivoRechazo,
    this.descuentoSalario = 0.0,
    this.nominaAfectada,
    required this.fechaCreacion,
    this.empleadoNombre,
  });

  factory SolicitudVacaciones.fromMap(Map<String, dynamic> m) {
    return SolicitudVacaciones(
      id: m['id'] as String? ?? '',
      empleadoId: m['empleado_id'] as String? ?? '',
      empresaId: m['empresa_id'] as String? ?? '',
      tipo: TipoAusenciaExt.fromString(m['tipo'] as String?),
      subtipo: m['subtipo'] != null
          ? SubtipoPermisoExt.fromString(m['subtipo'] as String?)
          : null,
      fechaInicio: _parseDate(m['fecha_inicio']),
      fechaFin: _parseDate(m['fecha_fin']),
      diasNaturales: (m['dias_naturales'] as num?)?.toInt() ?? 0,
      diasLaborables: (m['dias_laborables'] as num?)?.toInt() ?? 0,
      estado: EstadoSolicitud.values.firstWhere(
        (e) => e.name == (m['estado'] as String?),
        orElse: () => EstadoSolicitud.solicitado,
      ),
      notas: m['notas'] as String?,
      motivoRechazo: m['motivo_rechazo'] as String?,
      descuentoSalario: (m['descuento_salario'] as num?)?.toDouble() ?? 0,
      nominaAfectada: m['nomina_afectada'] as String?,
      fechaCreacion: _parseDate(m['fecha_creacion']),
      empleadoNombre: m['empleado_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'empleado_id': empleadoId,
        'empresa_id': empresaId,
        'tipo': tipo.valor,
        if (subtipo != null) 'subtipo': subtipo!.valor,
        'fecha_inicio': Timestamp.fromDate(fechaInicio),
        'fecha_fin': Timestamp.fromDate(fechaFin),
        'dias_naturales': diasNaturales,
        'dias_laborables': diasLaborables,
        'estado': estado.name,
        if (notas != null) 'notas': notas,
        if (motivoRechazo != null) 'motivo_rechazo': motivoRechazo,
        'descuento_salario': descuentoSalario,
        'fecha_creacion': Timestamp.fromDate(fechaCreacion),
        if (empleadoNombre != null) 'empleado_nombre': empleadoNombre,
      };

  SolicitudVacaciones copyWith({
    String? id,
    EstadoSolicitud? estado,
    double? descuentoSalario,
    String? nominaAfectada,
    String? notas,
    String? motivoRechazo,
  }) =>
      SolicitudVacaciones(
        id: id ?? this.id,
        empleadoId: empleadoId,
        empresaId: empresaId,
        tipo: tipo,
        subtipo: subtipo,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        diasNaturales: diasNaturales,
        diasLaborables: diasLaborables,
        estado: estado ?? this.estado,
        notas: notas ?? this.notas,
        motivoRechazo: motivoRechazo ?? this.motivoRechazo,
        descuentoSalario: descuentoSalario ?? this.descuentoSalario,
        nominaAfectada: nominaAfectada ?? this.nominaAfectada,
        fechaCreacion: fechaCreacion,
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}


