import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// REMESA SEPA — Modelo de datos para remesas de pago de nóminas
// Esquema: pain.001.001.03 (ISO 20022) — Cuaderno 34 CaixaBank
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoRemesa { generada, enviada, confirmada, rechazada }

extension EstadoRemesaExt on EstadoRemesa {
  String get etiqueta {
    switch (this) {
      case EstadoRemesa.generada:   return 'Generada';
      case EstadoRemesa.enviada:    return 'Enviada al banco';
      case EstadoRemesa.confirmada: return 'Confirmada';
      case EstadoRemesa.rechazada:  return 'Rechazada';
    }
  }
}

class RemesaSepa {
  final String id;
  final String empresaId;
  final int mes;
  final int anio;
  final DateTime fechaEjecucion;
  final List<String> nominasIds;
  final int nTransferencias;
  final double importeTotal;
  final EstadoRemesa estado;
  final String msgId;
  final String? xmlGenerado;
  final DateTime fechaCreacion;
  final DateTime? fechaEnvio;

  const RemesaSepa({
    required this.id,
    required this.empresaId,
    required this.mes,
    required this.anio,
    required this.fechaEjecucion,
    required this.nominasIds,
    required this.nTransferencias,
    required this.importeTotal,
    this.estado = EstadoRemesa.generada,
    required this.msgId,
    this.xmlGenerado,
    required this.fechaCreacion,
    this.fechaEnvio,
  });

  factory RemesaSepa.fromMap(Map<String, dynamic> m) => RemesaSepa(
    id:               m['id'] as String? ?? '',
    empresaId:        m['empresa_id'] as String? ?? '',
    mes:              (m['mes'] as num?)?.toInt() ?? 1,
    anio:             (m['anio'] as num?)?.toInt() ?? 2026,
    fechaEjecucion:   _parseDate(m['fecha_ejecucion']),
    nominasIds:       List<String>.from(m['nominas_ids'] ?? []),
    nTransferencias:  (m['n_transferencias'] as num?)?.toInt() ?? 0,
    importeTotal:     (m['importe_total'] as num?)?.toDouble() ?? 0,
    estado:           EstadoRemesa.values.firstWhere(
                        (e) => e.name == (m['estado'] as String?),
                        orElse: () => EstadoRemesa.generada),
    msgId:            m['msg_id'] as String? ?? '',
    xmlGenerado:      m['xml_generado'] as String?,
    fechaCreacion:    _parseDate(m['fecha_creacion']),
    fechaEnvio:       m['fecha_envio'] != null ? _parseDate(m['fecha_envio']) : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'mes': mes,
    'anio': anio,
    'fecha_ejecucion': Timestamp.fromDate(fechaEjecucion),
    'nominas_ids': nominasIds,
    'n_transferencias': nTransferencias,
    'importe_total': importeTotal,
    'estado': estado.name,
    'msg_id': msgId,
    if (xmlGenerado != null) 'xml_generado': xmlGenerado,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    if (fechaEnvio != null) 'fecha_envio': Timestamp.fromDate(fechaEnvio!),
  };

  RemesaSepa copyWith({
    EstadoRemesa? estado,
    DateTime? fechaEnvio,
    String? xmlGenerado,
  }) => RemesaSepa(
    id: id,
    empresaId: empresaId,
    mes: mes,
    anio: anio,
    fechaEjecucion: fechaEjecucion,
    nominasIds: nominasIds,
    nTransferencias: nTransferencias,
    importeTotal: importeTotal,
    estado: estado ?? this.estado,
    msgId: msgId,
    xmlGenerado: xmlGenerado ?? this.xmlGenerado,
    fechaCreacion: fechaCreacion,
    fechaEnvio: fechaEnvio ?? this.fechaEnvio,
  );

  String get periodoTexto => '${_meses[mes.clamp(1, 12)]} $anio';

  static const List<String> _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

