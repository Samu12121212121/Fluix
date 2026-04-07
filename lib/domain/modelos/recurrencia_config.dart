/// Frecuencia de recurrencia de una tarea.
enum FrecuenciaRecurrencia { diaria, semanal, quincenal, mensual, anual }

extension FrecuenciaRecurrenciaExt on FrecuenciaRecurrencia {
  String get etiqueta {
    switch (this) {
      case FrecuenciaRecurrencia.diaria:    return 'Diaria';
      case FrecuenciaRecurrencia.semanal:   return 'Semanal';
      case FrecuenciaRecurrencia.quincenal: return 'Quincenal';
      case FrecuenciaRecurrencia.mensual:   return 'Mensual';
      case FrecuenciaRecurrencia.anual:     return 'Anual';
    }
  }
}

/// Tipo de recordatorio para tareas.
enum TipoRecordatorio { ninguno, alCrear, antesVencimiento, personalizado }

extension TipoRecordatorioExt on TipoRecordatorio {
  String get etiqueta {
    switch (this) {
      case TipoRecordatorio.ninguno:           return 'Ninguno';
      case TipoRecordatorio.alCrear:           return 'Al crear';
      case TipoRecordatorio.antesVencimiento:  return 'Antes del vencimiento';
      case TipoRecordatorio.personalizado:     return 'Personalizado';
    }
  }
}

/// Configuración completa de recurrencia de una tarea.
class ConfiguracionRecurrencia {
  final FrecuenciaRecurrencia frecuencia;
  final List<int> diasSemana;   // 1=Lun…7=Dom (ISO)
  final int? diaMes;            // 1-31 para mensual
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool pausada;
  final DateTime? ultimaGeneracion;

  const ConfiguracionRecurrencia({
    required this.frecuencia,
    this.diasSemana = const [],
    this.diaMes,
    this.fechaInicio,
    this.fechaFin,
    this.pausada = false,
    this.ultimaGeneracion,
  });

  factory ConfiguracionRecurrencia.fromMap(Map<String, dynamic> m) {
    return ConfiguracionRecurrencia(
      frecuencia: FrecuenciaRecurrencia.values.firstWhere(
        (e) => e.name == (m['frecuencia'] as String?),
        orElse: () => FrecuenciaRecurrencia.semanal,
      ),
      diasSemana: (m['dias_semana'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      diaMes: (m['dia_mes'] as num?)?.toInt(),
      fechaInicio: m['fecha_inicio'] != null
          ? DateTime.tryParse(m['fecha_inicio'].toString())
          : null,
      fechaFin: m['fecha_fin'] != null
          ? DateTime.tryParse(m['fecha_fin'].toString())
          : null,
      pausada: m['pausada'] as bool? ?? false,
      ultimaGeneracion: m['ultima_generacion'] != null
          ? DateTime.tryParse(m['ultima_generacion'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'frecuencia': frecuencia.name,
        'dias_semana': diasSemana,
        if (diaMes != null) 'dia_mes': diaMes,
        if (fechaInicio != null)
          'fecha_inicio': fechaInicio!.toIso8601String(),
        if (fechaFin != null) 'fecha_fin': fechaFin!.toIso8601String(),
        'pausada': pausada,
        if (ultimaGeneracion != null)
          'ultima_generacion': ultimaGeneracion!.toIso8601String(),
      };

  ConfiguracionRecurrencia copyWith({
    FrecuenciaRecurrencia? frecuencia,
    List<int>? diasSemana,
    int? diaMes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? pausada,
    DateTime? ultimaGeneracion,
  }) =>
      ConfiguracionRecurrencia(
        frecuencia: frecuencia ?? this.frecuencia,
        diasSemana: diasSemana ?? this.diasSemana,
        diaMes: diaMes ?? this.diaMes,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFin: fechaFin ?? this.fechaFin,
        pausada: pausada ?? this.pausada,
        ultimaGeneracion: ultimaGeneracion ?? this.ultimaGeneracion,
      );
}

/// Configuración de recordatorio para una tarea.
class RecordatorioTarea {
  final TipoRecordatorio tipo;
  final int? minutosAntes;
  final DateTime? fechaPersonalizada;

  const RecordatorioTarea({
    required this.tipo,
    this.minutosAntes,
    this.fechaPersonalizada,
  });

  factory RecordatorioTarea.fromMap(Map<String, dynamic> m) {
    return RecordatorioTarea(
      tipo: TipoRecordatorio.values.firstWhere(
        (e) => e.name == (m['tipo'] as String?),
        orElse: () => TipoRecordatorio.ninguno,
      ),
      minutosAntes: (m['minutos_antes'] as num?)?.toInt(),
      fechaPersonalizada: m['fecha_personalizada'] != null
          ? DateTime.tryParse(m['fecha_personalizada'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.name,
        if (minutosAntes != null) 'minutos_antes': minutosAntes,
        if (fechaPersonalizada != null)
          'fecha_personalizada': fechaPersonalizada!.toIso8601String(),
      };
}

