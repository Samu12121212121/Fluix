import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de fichaje
enum TipoFichaje { 
  entrada, 
  salida,
  pausaInicio,
  pausaFin
}

/// Modelo de un registro de fichaje (control horario)
class RegistroFichaje {
  final String id;
  final String empleadoId;
  final String empresaId;
  final String empleadoNombre;
  final TipoFichaje tipo;
  final DateTime timestamp;
  final double? latitud;
  final double? longitud;
  final bool editadoPorAdmin;
  final String? notas;
  final String? editadoPor;
  final DateTime? editadoEn;
  final String? firmaTipo;
  final bool? firmaConfirmada;
  final bool eliminado;

  const RegistroFichaje({
    required this.id,
    required this.empleadoId,
    required this.empresaId,
    this.empleadoNombre = '',
    required this.tipo,
    required this.timestamp,
    this.latitud,
    this.longitud,
    this.editadoPorAdmin = false,
    this.notas,
    this.editadoPor,
    this.editadoEn,
    this.firmaTipo,
    this.firmaConfirmada,
    this.eliminado = false,
  });

  /// Getter: indica si el fichaje es de tipo pausa
  bool get esPausa => tipo == TipoFichaje.pausaInicio || tipo == TipoFichaje.pausaFin;

  factory RegistroFichaje.fromMap(Map<String, dynamic> map, String id) {
    // Parsear el tipo de fichaje
    TipoFichaje tipoFichaje = TipoFichaje.entrada;
    final tipoStr = map['tipo'] as String?;
    if (tipoStr == 'salida') {
      tipoFichaje = TipoFichaje.salida;
    } else if (tipoStr == 'pausaInicio' || tipoStr == 'pausa_inicio') {
      tipoFichaje = TipoFichaje.pausaInicio;
    } else if (tipoStr == 'pausaFin' || tipoStr == 'pausa_fin') {
      tipoFichaje = TipoFichaje.pausaFin;
    }

    return RegistroFichaje(
      id: id,
      empleadoId: map['empleado_id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      empleadoNombre: map['empleado_nombre'] ?? '',
      tipo: tipoFichaje,
      timestamp: _parseDate(map['timestamp']) ?? DateTime.now(),
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      editadoPorAdmin: map['editado_por_admin'] as bool? ?? false,
      notas: map['notas'] as String?,
      editadoPor: map['editado_por'] as String?,
      editadoEn: _parseDate(map['editado_en']),
      firmaTipo: map['firma_tipo'] as String?,
      firmaConfirmada: map['firma_confirmada'] as bool?,
      eliminado: map['eliminado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    String tipoStr = 'entrada';
    if (tipo == TipoFichaje.salida) {
      tipoStr = 'salida';
    } else if (tipo == TipoFichaje.pausaInicio) {
      tipoStr = 'pausa_inicio';
    } else if (tipo == TipoFichaje.pausaFin) {
      tipoStr = 'pausa_fin';
    }

    return {
      'empleado_id': empleadoId,
      'empresa_id': empresaId,
      'empleado_nombre': empleadoNombre,
      'tipo': tipoStr,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitud': latitud,
      'longitud': longitud,
      'editado_por_admin': editadoPorAdmin,
      'notas': notas,
      'editado_por': editadoPor,
      'editado_en': editadoEn != null ? Timestamp.fromDate(editadoEn!) : null,
      'firma_tipo': firmaTipo,
      'firma_confirmada': firmaConfirmada,
      'eliminado': eliminado,
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    return null;
  }
}

/// Resumen de un día de trabajo de un empleado
class ResumenDiaFichaje {
  final DateTime fecha;
  final String empleadoId;
  final String empleadoNombre;
  final DateTime? entrada;
  final DateTime? salida;
  final double horasTrabajadas; // horas brutas
  final double? horasExtra;
  final bool fichajePendiente; // entrada sin salida
  final double horasBrutas;
  final int minutasPausa;
  final double horasNetas;
  final List<Map<String, dynamic>> pausas;

  const ResumenDiaFichaje({
    required this.fecha,
    required this.empleadoId,
    this.empleadoNombre = '',
    this.entrada,
    this.salida,
    this.horasTrabajadas = 0,
    this.horasExtra,
    this.fichajePendiente = false,
    this.horasBrutas = 0,
    this.minutasPausa = 0,
    this.horasNetas = 0,
    this.pausas = const [],
  });
}

