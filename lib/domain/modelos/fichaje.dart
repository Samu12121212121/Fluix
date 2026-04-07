import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de fichaje
enum TipoFichaje { entrada, salida }

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
  });

  factory RegistroFichaje.fromMap(Map<String, dynamic> map, String id) {
    return RegistroFichaje(
      id: id,
      empleadoId: map['empleado_id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      empleadoNombre: map['empleado_nombre'] ?? '',
      tipo: (map['tipo'] as String?) == 'salida'
          ? TipoFichaje.salida
          : TipoFichaje.entrada,
      timestamp: _parseDate(map['timestamp']) ?? DateTime.now(),
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      editadoPorAdmin: map['editado_por_admin'] as bool? ?? false,
      notas: map['notas'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'empleado_id': empleadoId,
    'empresa_id': empresaId,
    'empleado_nombre': empleadoNombre,
    'tipo': tipo == TipoFichaje.entrada ? 'entrada' : 'salida',
    'timestamp': Timestamp.fromDate(timestamp),
    'latitud': latitud,
    'longitud': longitud,
    'editado_por_admin': editadoPorAdmin,
    'notas': notas,
  };

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
  final double horasTrabajadas;
  final double? horasExtra;
  final bool fichajePendiente; // entrada sin salida

  const ResumenDiaFichaje({
    required this.fecha,
    required this.empleadoId,
    this.empleadoNombre = '',
    this.entrada,
    this.salida,
    this.horasTrabajadas = 0,
    this.horasExtra,
    this.fichajePendiente = false,
  });
}

