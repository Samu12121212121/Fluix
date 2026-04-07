import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 130 — Pago fraccionado IRPF autónomos
// Art. 110 LIRPF — Estimación directa normal/simplificada
// Cálculo ACUMULATIVO YTD (enero → fin trimestre)
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoModelo130 { borrador, presentado }

extension EstadoModelo130Ext on EstadoModelo130 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo130.borrador:   return 'Borrador';
      case EstadoModelo130.presentado: return 'Presentado';
    }
  }
}

class Modelo130 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final String trimestre; // "1T","2T","3T","4T"
  final DateTime fechaGeneracion;
  final EstadoModelo130 estado;

  // ── SECCIÓN I — Actividades económicas (estimación directa) ──

  /// [01] Ingresos computables acumulados YTD
  final double c01;

  /// [02] Gastos fiscalmente deducibles acumulados YTD
  final double c02;

  /// [03] Rendimiento neto = [01] - [02] (puede ser negativo)
  double get c03 => c01 - c02;

  /// [04] 20% de [03] (solo si [03] > 0, si no: 0)
  double get c04 => c03 > 0 ? _r2(c03 * 0.20) : 0;

  /// [05] Pagos fraccionados anteriores del mismo ejercicio
  final double c05;

  /// [06] Retenciones soportadas acumuladas YTD
  final double c06;

  /// [07] Resultado previo = [04] - [05] - [06] (puede ser negativo)
  double get c07 => _r2(c04 - c05 - c06);

  // Casillas [08]-[11] Sección II (agrícola/ganadera) — NO aplica PYMEs CLM
  // Siempre 0 para el ámbito de esta app

  /// [12] Suma pagos fraccionados = [07] + 0 (sección II = 0)
  double get c12 => c07;

  /// [13] Minoración por rendimientos bajos (manual, default 0)
  final double c13;

  /// [14] = [12] - [13]
  double get c14 => _r2(c12 - c13);

  /// [15] Resultados negativos trimestres anteriores (manual)
  final double c15;

  /// [16] Deducción vivienda habitual (max 660.14€ por trimestre, manual)
  final double c16;

  /// [17] = [14] - [15] - [16]
  double get c17 => _r2(c14 - c15 - c16);

  /// [18] Autoliquidaciones anteriores mismo período (complementaria)
  final double c18;

  /// [19] RESULTADO FINAL = [17] - [18]
  double get c19 => _r2(c17 - c18);

  /// true si es declaración complementaria
  final bool esComplementaria;

  /// Nº justificante declaración anterior (13 dígitos) si complementaria
  final String? nJustificanteAnterior;

  /// IDs de las facturas emitidas usadas en el cálculo
  final List<String> facturasEmitidasIds;

  /// IDs de las facturas recibidas usadas en el cálculo
  final List<String> facturasRecibidasIds;

  const Modelo130({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.trimestre,
    required this.fechaGeneracion,
    this.estado = EstadoModelo130.borrador,
    this.c01 = 0,
    this.c02 = 0,
    this.c05 = 0,
    this.c06 = 0,
    this.c13 = 0,
    this.c15 = 0,
    this.c16 = 0,
    this.c18 = 0,
    this.esComplementaria = false,
    this.nJustificanteAnterior,
    this.facturasEmitidasIds = const [],
    this.facturasRecibidasIds = const [],
  });

  // ── Resultado legible ──

  bool get esADeducir => c19 < 0;
  bool get esAIngresar => c19 > 0;
  String get resultadoTexto =>
      esADeducir
          ? 'A deducir: ${(-c19).toStringAsFixed(2)} €'
          : 'A ingresar: ${c19.toStringAsFixed(2)} €';

  // ── Períodos y plazos ──

  static DateTime calcularPlazoLimite(int ejercicio, String trimestre) {
    switch (trimestre) {
      case '1T': return DateTime(ejercicio, 4, 20);
      case '2T': return DateTime(ejercicio, 7, 20);
      case '3T': return DateTime(ejercicio, 10, 20);
      case '4T': return DateTime(ejercicio + 1, 1, 30);
      default:   return DateTime(ejercicio, 4, 20);
    }
  }

  static ({int mesInicio, int mesFin}) rangoMeses(String trimestre) {
    switch (trimestre) {
      case '1T': return (mesInicio: 1, mesFin: 3);
      case '2T': return (mesInicio: 4, mesFin: 6);
      case '3T': return (mesInicio: 7, mesFin: 9);
      case '4T': return (mesInicio: 10, mesFin: 12);
      default:   return (mesInicio: 1, mesFin: 3);
    }
  }

  /// YTD: desde 1 enero hasta el último día del trimestre
  static ({DateTime inicio, DateTime fin}) rangoYTD(int ejercicio, String trimestre) {
    final inicio = DateTime(ejercicio, 1, 1);
    final rango = rangoMeses(trimestre);
    final fin = DateTime(ejercicio, rango.mesFin + 1, 1); // primer día mes siguiente
    return (inicio: inicio, fin: fin);
  }

  static List<String> trimestresAnteriores(String trimestre) {
    switch (trimestre) {
      case '2T': return ['1T'];
      case '3T': return ['1T', '2T'];
      case '4T': return ['1T', '2T', '3T'];
      default:   return [];
    }
  }

  // ── Firestore ──

  factory Modelo130.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Modelo130(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      ejercicio: d['ejercicio'] ?? DateTime.now().year,
      trimestre: d['trimestre'] ?? '1T',
      fechaGeneracion: _parseTs(d['fecha_generacion']),
      estado: EstadoModelo130.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoModelo130.borrador,
      ),
      c01: (d['c01'] as num?)?.toDouble() ?? 0,
      c02: (d['c02'] as num?)?.toDouble() ?? 0,
      c05: (d['c05'] as num?)?.toDouble() ?? 0,
      c06: (d['c06'] as num?)?.toDouble() ?? 0,
      c13: (d['c13'] as num?)?.toDouble() ?? 0,
      c15: (d['c15'] as num?)?.toDouble() ?? 0,
      c16: (d['c16'] as num?)?.toDouble() ?? 0,
      c18: (d['c18'] as num?)?.toDouble() ?? 0,
      esComplementaria: d['es_complementaria'] ?? false,
      nJustificanteAnterior: d['n_justificante_anterior'],
      facturasEmitidasIds: List<String>.from(d['facturas_emitidas_ids'] ?? []),
      facturasRecibidasIds: List<String>.from(d['facturas_recibidas_ids'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'ejercicio': ejercicio,
    'trimestre': trimestre,
    'fecha_generacion': Timestamp.fromDate(fechaGeneracion),
    'estado': estado.name,
    'c01': c01,
    'c02': c02,
    'c03': c03,
    'c04': c04,
    'c05': c05,
    'c06': c06,
    'c07': c07,
    'c12': c12,
    'c13': c13,
    'c14': c14,
    'c15': c15,
    'c16': c16,
    'c17': c17,
    'c18': c18,
    'c19': c19,
    'es_complementaria': esComplementaria,
    'n_justificante_anterior': nJustificanteAnterior,
    'facturas_emitidas_ids': facturasEmitidasIds,
    'facturas_recibidas_ids': facturasRecibidasIds,
  };

  Modelo130 copyWith({
    EstadoModelo130? estado,
    double? c01,
    double? c02,
    double? c05,
    double? c06,
    double? c13,
    double? c15,
    double? c16,
    double? c18,
    bool? esComplementaria,
    String? nJustificanteAnterior,
  }) {
    return Modelo130(
      id: id,
      empresaId: empresaId,
      ejercicio: ejercicio,
      trimestre: trimestre,
      fechaGeneracion: fechaGeneracion,
      estado: estado ?? this.estado,
      c01: c01 ?? this.c01,
      c02: c02 ?? this.c02,
      c05: c05 ?? this.c05,
      c06: c06 ?? this.c06,
      c13: c13 ?? this.c13,
      c15: c15 ?? this.c15,
      c16: c16 ?? this.c16,
      c18: c18 ?? this.c18,
      esComplementaria: esComplementaria ?? this.esComplementaria,
      nJustificanteAnterior: nJustificanteAnterior ?? this.nJustificanteAnterior,
      facturasEmitidasIds: facturasEmitidasIds,
      facturasRecibidasIds: facturasRecibidasIds,
    );
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

