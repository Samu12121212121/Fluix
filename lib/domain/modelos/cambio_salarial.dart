import 'package:cloud_firestore/cloud_firestore.dart';

/// Motivos de cambio salarial
enum MotivoCambioSalarial {
  subidaAnual,
  ascenso,
  convenio,
  ipc,
  reduccionJornada,
  otro,
}

extension MotivoCambioSalarialExt on MotivoCambioSalarial {
  String get nombre {
    switch (this) {
      case MotivoCambioSalarial.subidaAnual:      return 'Subida anual';
      case MotivoCambioSalarial.ascenso:           return 'Ascenso / Promoción';
      case MotivoCambioSalarial.convenio:          return 'Actualización convenio';
      case MotivoCambioSalarial.ipc:               return 'Revisión IPC';
      case MotivoCambioSalarial.reduccionJornada:  return 'Reducción de jornada';
      case MotivoCambioSalarial.otro:              return 'Otro';
    }
  }

  String get icono {
    switch (this) {
      case MotivoCambioSalarial.subidaAnual:      return '📈';
      case MotivoCambioSalarial.ascenso:           return '⬆️';
      case MotivoCambioSalarial.convenio:          return '📋';
      case MotivoCambioSalarial.ipc:               return '💹';
      case MotivoCambioSalarial.reduccionJornada:  return '⏰';
      case MotivoCambioSalarial.otro:              return '📝';
    }
  }
}

/// Registro de un cambio salarial en el historial
class CambioSalarial {
  final String id;
  final String empleadoId;
  final String empresaId;
  final double salarioAnterior;
  final double salarioNuevo;
  final DateTime fechaEfectividad;
  final DateTime fechaRegistro;
  final MotivoCambioSalarial motivo;
  final String? notas;
  final String registradoPor; // userId

  const CambioSalarial({
    required this.id,
    required this.empleadoId,
    required this.empresaId,
    required this.salarioAnterior,
    required this.salarioNuevo,
    required this.fechaEfectividad,
    required this.fechaRegistro,
    required this.motivo,
    this.notas,
    required this.registradoPor,
  });

  double get diferencia => salarioNuevo - salarioAnterior;
  double get porcentajeCambio =>
      salarioAnterior > 0 ? (diferencia / salarioAnterior) * 100 : 0;
  bool get esSubida => salarioNuevo > salarioAnterior;
  bool get esFuturo => fechaEfectividad.isAfter(DateTime.now());

  factory CambioSalarial.fromMap(Map<String, dynamic> map, String id) {
    return CambioSalarial(
      id: id,
      empleadoId: map['empleado_id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      salarioAnterior: (map['salario_anterior'] as num?)?.toDouble() ?? 0,
      salarioNuevo: (map['salario_nuevo'] as num?)?.toDouble() ?? 0,
      fechaEfectividad: _parseDate(map['fecha_efectividad']) ?? DateTime.now(),
      fechaRegistro: _parseDate(map['fecha_registro']) ?? DateTime.now(),
      motivo: MotivoCambioSalarial.values.firstWhere(
        (m) => m.name == (map['motivo'] as String?),
        orElse: () => MotivoCambioSalarial.otro,
      ),
      notas: map['notas'] as String?,
      registradoPor: map['registrado_por'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'empleado_id': empleadoId,
    'empresa_id': empresaId,
    'salario_anterior': salarioAnterior,
    'salario_nuevo': salarioNuevo,
    'fecha_efectividad': Timestamp.fromDate(fechaEfectividad),
    'fecha_registro': Timestamp.fromDate(fechaRegistro),
    'motivo': motivo.name,
    'notas': notas,
    'registrado_por': registradoPor,
  };

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    return null;
  }
}

