import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de contrato según legislación española
enum TipoContratoAlerta {
  indefinido,
  temporal,
  obraServicio,
  practicas,
  formacion,
}

extension TipoContratoAlertaExt on TipoContratoAlerta {
  String get nombre {
    switch (this) {
      case TipoContratoAlerta.indefinido:    return 'Indefinido';
      case TipoContratoAlerta.temporal:      return 'Temporal';
      case TipoContratoAlerta.obraServicio:  return 'Obra y servicio';
      case TipoContratoAlerta.practicas:     return 'Prácticas';
      case TipoContratoAlerta.formacion:     return 'Formación';
    }
  }

  bool get tieneVencimiento => this != TipoContratoAlerta.indefinido;
}

/// Nivel de alerta por proximidad al vencimiento
enum NivelAlertaContrato {
  verde,     // > 30 días
  amarillo,  // <= 30 días
  naranja,   // <= 15 días
  rojo,      // <= 7 días
  vencido,   // <= 0 días
}

extension NivelAlertaContratoExt on NivelAlertaContrato {
  String get nombre {
    switch (this) {
      case NivelAlertaContrato.verde:    return 'OK';
      case NivelAlertaContrato.amarillo: return 'Atención';
      case NivelAlertaContrato.naranja:  return 'Próximo';
      case NivelAlertaContrato.rojo:     return 'Urgente';
      case NivelAlertaContrato.vencido:  return 'Vencido';
    }
  }
}

/// Alerta de vencimiento de contrato
class AlertaContrato {
  final String empleadoId;
  final String empleadoNombre;
  final TipoContratoAlerta tipoContrato;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int diasRestantes;
  final NivelAlertaContrato nivel;

  const AlertaContrato({
    required this.empleadoId,
    required this.empleadoNombre,
    required this.tipoContrato,
    required this.fechaInicio,
    required this.fechaFin,
    required this.diasRestantes,
    required this.nivel,
  });

  static NivelAlertaContrato calcularNivel(int dias) {
    if (dias <= 0) return NivelAlertaContrato.vencido;
    if (dias <= 7) return NivelAlertaContrato.rojo;
    if (dias <= 15) return NivelAlertaContrato.naranja;
    if (dias <= 30) return NivelAlertaContrato.amarillo;
    return NivelAlertaContrato.verde;
  }
}

/// Registro de renovación de contrato
class RenovacionContrato {
  final String id;
  final String empleadoId;
  final TipoContratoAlerta tipoAnterior;
  final TipoContratoAlerta tipoNuevo;
  final DateTime fechaFinAnterior;
  final DateTime fechaFinNueva;
  final DateTime fechaRenovacion;
  final String? notas;
  final String renovadoPor;

  const RenovacionContrato({
    required this.id,
    required this.empleadoId,
    required this.tipoAnterior,
    required this.tipoNuevo,
    required this.fechaFinAnterior,
    required this.fechaFinNueva,
    required this.fechaRenovacion,
    this.notas,
    required this.renovadoPor,
  });

  factory RenovacionContrato.fromMap(Map<String, dynamic> map, String id) {
    return RenovacionContrato(
      id: id,
      empleadoId: map['empleado_id'] ?? '',
      tipoAnterior: TipoContratoAlerta.values.firstWhere(
        (t) => t.name == (map['tipo_anterior'] as String?),
        orElse: () => TipoContratoAlerta.temporal,
      ),
      tipoNuevo: TipoContratoAlerta.values.firstWhere(
        (t) => t.name == (map['tipo_nuevo'] as String?),
        orElse: () => TipoContratoAlerta.temporal,
      ),
      fechaFinAnterior: _parseDate(map['fecha_fin_anterior']) ?? DateTime.now(),
      fechaFinNueva: _parseDate(map['fecha_fin_nueva']) ?? DateTime.now(),
      fechaRenovacion: _parseDate(map['fecha_renovacion']) ?? DateTime.now(),
      notas: map['notas'] as String?,
      renovadoPor: map['renovado_por'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'empleado_id': empleadoId,
    'tipo_anterior': tipoAnterior.name,
    'tipo_nuevo': tipoNuevo.name,
    'fecha_fin_anterior': Timestamp.fromDate(fechaFinAnterior),
    'fecha_fin_nueva': Timestamp.fromDate(fechaFinNueva),
    'fecha_renovacion': Timestamp.fromDate(fechaRenovacion),
    'notas': notas,
    'renovado_por': renovadoPor,
  };

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    return null;
  }
}

