import 'package:cloud_firestore/cloud_firestore.dart';

enum PeriodoRecurrencia { semanal, mensual, bimestral, trimestral, semestral, anual }

extension PeriodoRecurrenciaExt on PeriodoRecurrencia {
  String get etiqueta => switch (this) {
    PeriodoRecurrencia.semanal     => 'Semanal',
    PeriodoRecurrencia.mensual     => 'Mensual',
    PeriodoRecurrencia.bimestral   => 'Bimestral',
    PeriodoRecurrencia.trimestral  => 'Trimestral',
    PeriodoRecurrencia.semestral   => 'Semestral',
    PeriodoRecurrencia.anual       => 'Anual',
  };

  /// Días entre emisiones
  int get diasCiclo => switch (this) {
    PeriodoRecurrencia.semanal    => 7,
    PeriodoRecurrencia.mensual    => 30,
    PeriodoRecurrencia.bimestral  => 60,
    PeriodoRecurrencia.trimestral => 90,
    PeriodoRecurrencia.semestral  => 180,
    PeriodoRecurrencia.anual      => 365,
  };

  String get firestoreKey => name;
  static PeriodoRecurrencia fromKey(String k) =>
      PeriodoRecurrencia.values.firstWhere((e) => e.name == k,
          orElse: () => PeriodoRecurrencia.mensual);
}

class FacturaRecurrente {
  final String id;
  final String empresaId;
  final String descripcion;
  final String clienteNombre;
  final String? clienteId;
  final String? clienteNif;
  final String? clienteEmail;
  final double importe;
  final double iva;
  final PeriodoRecurrencia periodo;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final DateTime proximaEmision;
  final bool activa;
  final List<String> facturasGeneradasIds;
  final DateTime? ultimaEmision;

  const FacturaRecurrente({
    required this.id,
    required this.empresaId,
    required this.descripcion,
    required this.clienteNombre,
    this.clienteId,
    this.clienteNif,
    this.clienteEmail,
    required this.importe,
    required this.iva,
    required this.periodo,
    required this.fechaInicio,
    this.fechaFin,
    required this.proximaEmision,
    required this.activa,
    this.facturasGeneradasIds = const [],
    this.ultimaEmision,
  });

  double get importeConIva => importe * (1 + iva / 100);

  factory FacturaRecurrente.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FacturaRecurrente(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      descripcion: d['descripcion'] ?? '',
      clienteNombre: d['cliente_nombre'] ?? '',
      clienteId: d['cliente_id'],
      clienteNif: d['cliente_nif'],
      clienteEmail: d['cliente_email'],
      importe: (d['importe'] as num?)?.toDouble() ?? 0,
      iva: (d['iva'] as num?)?.toDouble() ?? 21,
      periodo: PeriodoRecurrenciaExt.fromKey(d['periodo'] ?? 'mensual'),
      fechaInicio: (d['fecha_inicio'] as Timestamp).toDate(),
      fechaFin: d['fecha_fin'] != null ? (d['fecha_fin'] as Timestamp).toDate() : null,
      proximaEmision: (d['proxima_emision'] as Timestamp).toDate(),
      activa: d['activa'] ?? true,
      facturasGeneradasIds: List<String>.from(d['facturas_generadas_ids'] ?? []),
      ultimaEmision: d['ultima_emision'] != null
          ? (d['ultima_emision'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'descripcion': descripcion,
    'cliente_nombre': clienteNombre,
    'cliente_id': clienteId,
    'cliente_nif': clienteNif,
    'cliente_email': clienteEmail,
    'importe': importe,
    'iva': iva,
    'periodo': periodo.firestoreKey,
    'fecha_inicio': Timestamp.fromDate(fechaInicio),
    'fecha_fin': fechaFin != null ? Timestamp.fromDate(fechaFin!) : null,
    'proxima_emision': Timestamp.fromDate(proximaEmision),
    'activa': activa,
    'facturas_generadas_ids': facturasGeneradasIds,
    'ultima_emision': ultimaEmision != null ? Timestamp.fromDate(ultimaEmision!) : null,
  };

  FacturaRecurrente copyWith({
    bool? activa,
    DateTime? proximaEmision,
    DateTime? ultimaEmision,
    List<String>? facturasGeneradasIds,
    String? descripcion,
    double? importe,
    double? iva,
    PeriodoRecurrencia? periodo,
    DateTime? fechaFin,
  }) => FacturaRecurrente(
    id: id,
    empresaId: empresaId,
    descripcion: descripcion ?? this.descripcion,
    clienteNombre: clienteNombre,
    clienteId: clienteId,
    clienteNif: clienteNif,
    clienteEmail: clienteEmail,
    importe: importe ?? this.importe,
    iva: iva ?? this.iva,
    periodo: periodo ?? this.periodo,
    fechaInicio: fechaInicio,
    fechaFin: fechaFin ?? this.fechaFin,
    proximaEmision: proximaEmision ?? this.proximaEmision,
    activa: activa ?? this.activa,
    facturasGeneradasIds: facturasGeneradasIds ?? this.facturasGeneradasIds,
    ultimaEmision: ultimaEmision ?? this.ultimaEmision,
  );
}
