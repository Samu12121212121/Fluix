import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 202 — Pago fraccionado Impuesto de Sociedades
// Art. 40 LIS — Solo para sociedades (S.L., S.A., S.L.P., Cooperativa)
// Períodos: 1P (abril), 2P (octubre), 3P (diciembre)
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoModelo202 { borrador, presentado }

extension EstadoModelo202Ext on EstadoModelo202 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo202.borrador:   return 'Borrador';
      case EstadoModelo202.presentado: return 'Presentado';
    }
  }
}

enum PeriodoModelo202 {
  p1('1P', 'Abril'),
  p2('2P', 'Octubre'),
  p3('3P', 'Diciembre');

  final String codigo;
  final String nombre;
  const PeriodoModelo202(this.codigo, this.nombre);

  static PeriodoModelo202 fromCodigo(String c) {
    return PeriodoModelo202.values.firstWhere(
      (p) => p.codigo == c,
      orElse: () => PeriodoModelo202.p1,
    );
  }
}

class Modelo202 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final PeriodoModelo202 periodo;
  final DateTime fechaGeneracion;
  final EstadoModelo202 estado;

  // ── Modalidad A (art. 40.2 LIS) — Para pymes ──

  /// [01] Base pago fraccionado = cuota íntegra IS del último ejercicio
  ///      declarado - deducciones - bonificaciones + pagos a cuenta
  final double c01;

  /// [02] Declaración anterior (si complementaria)
  final double c02;

  /// Tipo gravamen aplicable (general 25%, micro 23%, etc.)
  final double tipoGravamen;

  /// [03] A INGRESAR = 18% de casilla 01 (mínimo 0)
  double get c03 => c01 > 0 ? _r2(c01 * 0.18) : 0;

  /// [04] Deducciones y bonificaciones (si aplica)
  final double c04;

  /// [05] Retenciones e ingresos a cuenta
  final double c05;

  /// [06] Pagos fraccionados anteriores mismo ejercicio
  final double c06;

  /// [07] Complementaria: a deducir
  final double c07;

  /// [08] RESULTADO = c03 - c04 - c05 - c06 - c07
  double get c08 => _r2(c03 - c04 - c05 - c06 - c07);

  /// Resultado final a ingresar (mínimo 0 para pago fraccionado)
  double get resultadoIngresar => c08 > 0 ? c08 : 0;

  final bool esComplementaria;
  final String? nJustificanteAnterior;
  final String? justificanteAeat;

  const Modelo202({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.periodo,
    required this.fechaGeneracion,
    this.estado = EstadoModelo202.borrador,
    this.c01 = 0,
    this.c02 = 0,
    this.tipoGravamen = 0.25,
    this.c04 = 0,
    this.c05 = 0,
    this.c06 = 0,
    this.c07 = 0,
    this.esComplementaria = false,
    this.nJustificanteAnterior,
    this.justificanteAeat,
  });

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  String get resultadoTexto =>
      resultadoIngresar > 0
          ? 'A ingresar: ${resultadoIngresar.toStringAsFixed(2)} €'
          : 'Sin ingreso: 0,00 €';

  // ── Plazos ──

  static DateTime calcularPlazoLimite(int ejercicio, PeriodoModelo202 periodo) {
    switch (periodo) {
      case PeriodoModelo202.p1: return DateTime(ejercicio, 4, 20);
      case PeriodoModelo202.p2: return DateTime(ejercicio, 10, 20);
      case PeriodoModelo202.p3: return DateTime(ejercicio, 12, 20);
    }
  }

  // ── Firestore ──

  factory Modelo202.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Modelo202(
      id: doc.id,
      empresaId: d['empresa_id'] as String? ?? '',
      ejercicio: d['ejercicio'] as int? ?? DateTime.now().year,
      periodo: PeriodoModelo202.fromCodigo(d['periodo'] as String? ?? '1P'),
      fechaGeneracion: (d['fecha_generacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: d['estado'] == 'presentado'
          ? EstadoModelo202.presentado
          : EstadoModelo202.borrador,
      c01: (d['c01'] as num?)?.toDouble() ?? 0,
      c02: (d['c02'] as num?)?.toDouble() ?? 0,
      tipoGravamen: (d['tipo_gravamen'] as num?)?.toDouble() ?? 0.25,
      c04: (d['c04'] as num?)?.toDouble() ?? 0,
      c05: (d['c05'] as num?)?.toDouble() ?? 0,
      c06: (d['c06'] as num?)?.toDouble() ?? 0,
      c07: (d['c07'] as num?)?.toDouble() ?? 0,
      esComplementaria: d['es_complementaria'] as bool? ?? false,
      nJustificanteAnterior: d['n_justificante_anterior'] as String?,
      justificanteAeat: d['justificante_aeat'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'empresa_id': empresaId,
        'modelo': '202',
        'ejercicio': ejercicio,
        'periodo': periodo.codigo,
        'fecha_generacion': Timestamp.fromDate(fechaGeneracion),
        'estado': estado == EstadoModelo202.presentado ? 'presentado' : 'borrador',
        'c01': c01,
        'c02': c02,
        'c03': c03,
        'tipo_gravamen': tipoGravamen,
        'c04': c04,
        'c05': c05,
        'c06': c06,
        'c07': c07,
        'c08': c08,
        'resultado_ingresar': resultadoIngresar,
        'es_complementaria': esComplementaria,
        if (nJustificanteAnterior != null)
          'n_justificante_anterior': nJustificanteAnterior,
        if (justificanteAeat != null)
          'justificante_aeat': justificanteAeat,
      };
}

