import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 200 — Impuesto sobre Sociedades (declaración anual)
// Art. 25-29 LIS — Solo para personas jurídicas (S.L., S.A., S.L.U., etc.)
// Plazo: 25 días naturales tras los 6 meses siguientes al cierre del ejercicio.
// Para ejercicio cerrado 31/12 → presentación antes del 25/07 del año siguiente.
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoModelo200 { borrador, presentado }

/// Tipo de gravamen aplicable según perfil de la sociedad
enum TipoGravamenIS {
  general,       // 25% — tipo general (Art. 29.1 LIS)
  microempresa,  // 23% — entidades con cifra de negocios < 1M€ (desde 2023)
  nuevaEmpresa,  // 15% — entidades de nueva creación (Art. 29.1 LIS), primeros 2 ejerc. con BI > 0
}

extension TipoGravamenISExt on TipoGravamenIS {
  double get tipo => switch (this) {
    TipoGravamenIS.general      => 0.25,
    TipoGravamenIS.microempresa => 0.23,
    TipoGravamenIS.nuevaEmpresa => 0.15,
  };
  String get etiqueta => switch (this) {
    TipoGravamenIS.general      => 'General (25%)',
    TipoGravamenIS.microempresa => 'Microempresa (23%)',
    TipoGravamenIS.nuevaEmpresa => 'Nueva empresa (15%)',
  };
  String get id => name;
  static TipoGravamenIS fromId(String id) =>
      TipoGravamenIS.values.firstWhere((e) => e.id == id,
          orElse: () => TipoGravamenIS.general);
}

class Modelo200 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final DateTime fechaGeneracion;
  final EstadoModelo200 estado;

  // ── Determinación de la base imponible ─────────────────────────────────────

  /// [01] Resultado contable del ejercicio (ingresos - gastos, del libro P&G)
  final double c01ResultadoContable;

  /// [02] IS y otros impuestos a añadir al resultado contable
  /// (el IS del propio ejercicio no es gasto deducible, se añade de vuelta)
  final double c02AjusteIS;

  /// [03] Otros ajustes extracontables netos (reserva capitalización, etc.)
  final double c03OtrosAjustes;

  /// Base imponible previa = [01] + [02] + [03]
  double get baseImponiblePrevia => _r2(c01ResultadoContable + c02AjusteIS + c03OtrosAjustes);

  /// [547] Bases imponibles negativas de ejercicios anteriores a compensar
  final double c547BasesNegativas;

  /// [552] Base imponible = max(0, baseImponiblePrevia - [547])
  double get c552BaseImponible => _r2((baseImponiblePrevia - c547BasesNegativas).clamp(0, double.infinity));

  // ── Tipo de gravamen y cuota íntegra ───────────────────────────────────────

  final TipoGravamenIS tipoGravamen;

  /// [566] Cuota íntegra = [552] × tipo
  double get c566CuotaIntegra => _r2(c552BaseImponible * tipoGravamen.tipo);

  // ── Deducciones y bonificaciones ───────────────────────────────────────────

  /// [582] Deducción por doble imposición internacional
  final double c582DedDobleImposicion;

  /// [583] Bonificaciones (entidades navieras, Ceuta/Melilla, etc.)
  final double c583Bonificaciones;

  /// [585] Deducción por creación de empleo para trabajadores con discapacidad
  final double c585DedCreacionEmpleo;

  /// Total deducciones
  double get totalDeducciones => _r2(c582DedDobleImposicion + c583Bonificaciones + c585DedCreacionEmpleo);

  /// [592] Cuota líquida = max(0, [566] - deducciones)
  double get c592CuotaLiquida => _r2((c566CuotaIntegra - totalDeducciones).clamp(0, double.infinity));

  // ── Resultado ───────────────────────────────────────────────────────────────

  /// [598] Retenciones e ingresos a cuenta soportados durante el ejercicio
  final double c598Retenciones;

  /// [599] Pagos fraccionados ingresados (Modelo 202 × 3 durante el año)
  final double c599PagosFraccionados;

  /// [600] RESULTADO = [592] - [598] - [599]
  /// Positivo → a ingresar. Negativo → a devolver.
  double get c600Resultado => _r2(c592CuotaLiquida - c598Retenciones - c599PagosFraccionados);

  bool get esAIngresar => c600Resultado > 0;
  bool get esADevolver => c600Resultado < 0;

  // ── Metadatos ───────────────────────────────────────────────────────────────

  final double totalIngresosEjercicio;
  final double totalGastosEjercicio;
  final String? justificanteAeat;
  final bool esComplementaria;
  final String? nJustificanteAnterior;

  const Modelo200({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.fechaGeneracion,
    this.estado = EstadoModelo200.borrador,
    this.c01ResultadoContable = 0,
    this.c02AjusteIS = 0,
    this.c03OtrosAjustes = 0,
    this.c547BasesNegativas = 0,
    this.tipoGravamen = TipoGravamenIS.general,
    this.c582DedDobleImposicion = 0,
    this.c583Bonificaciones = 0,
    this.c585DedCreacionEmpleo = 0,
    this.c598Retenciones = 0,
    this.c599PagosFraccionados = 0,
    this.totalIngresosEjercicio = 0,
    this.totalGastosEjercicio = 0,
    this.justificanteAeat,
    this.esComplementaria = false,
    this.nJustificanteAnterior,
  });

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  String get resultadoTexto {
    if (c600Resultado > 0) return 'A ingresar: ${c600Resultado.toStringAsFixed(2)} €';
    if (c600Resultado < 0) return 'A devolver: ${(-c600Resultado).toStringAsFixed(2)} €';
    return 'Cuota cero';
  }

  /// ID del documento en Firestore: "200_{ejercicio}_anual"
  static String docId(int ejercicio) => '200_${ejercicio}_anual';

  /// Plazo de presentación: 25 días naturales tras los 6 meses del cierre.
  /// Para cierre 31/12 → 25 julio del año siguiente.
  static DateTime plazoLimite(int ejercicio) => DateTime(ejercicio + 1, 7, 25);

  // ── Firestore ───────────────────────────────────────────────────────────────

  factory Modelo200.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Modelo200(
      id:                       doc.id,
      empresaId:                d['empresa_id'] as String? ?? '',
      ejercicio:                d['ejercicio'] as int? ?? DateTime.now().year,
      fechaGeneracion:          (d['fecha_generacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado:                   d['estado'] == 'presentado'
                                    ? EstadoModelo200.presentado
                                    : EstadoModelo200.borrador,
      c01ResultadoContable:     (d['c01'] as num?)?.toDouble() ?? 0,
      c02AjusteIS:              (d['c02'] as num?)?.toDouble() ?? 0,
      c03OtrosAjustes:          (d['c03'] as num?)?.toDouble() ?? 0,
      c547BasesNegativas:       (d['c547'] as num?)?.toDouble() ?? 0,
      tipoGravamen:             TipoGravamenISExt.fromId(d['tipo_gravamen'] as String? ?? 'general'),
      c582DedDobleImposicion:   (d['c582'] as num?)?.toDouble() ?? 0,
      c583Bonificaciones:       (d['c583'] as num?)?.toDouble() ?? 0,
      c585DedCreacionEmpleo:    (d['c585'] as num?)?.toDouble() ?? 0,
      c598Retenciones:          (d['c598'] as num?)?.toDouble() ?? 0,
      c599PagosFraccionados:    (d['c599'] as num?)?.toDouble() ?? 0,
      totalIngresosEjercicio:   (d['total_ingresos'] as num?)?.toDouble() ?? 0,
      totalGastosEjercicio:     (d['total_gastos'] as num?)?.toDouble() ?? 0,
      justificanteAeat:         d['justificante_aeat'] as String?,
      esComplementaria:         d['es_complementaria'] as bool? ?? false,
      nJustificanteAnterior:    d['n_justificante_anterior'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id':              empresaId,
    'modelo':                  '200',
    'ejercicio':               ejercicio,
    'fecha_generacion':        Timestamp.fromDate(fechaGeneracion),
    'estado':                  estado == EstadoModelo200.presentado ? 'presentado' : 'borrador',
    // Casillas
    'c01':  c01ResultadoContable,
    'c02':  c02AjusteIS,
    'c03':  c03OtrosAjustes,
    'c547': c547BasesNegativas,
    'base_imponible_previa':   baseImponiblePrevia,
    'c552': c552BaseImponible,
    'tipo_gravamen':           tipoGravamen.id,
    'tipo_gravamen_pct':       tipoGravamen.tipo * 100,
    'c566': c566CuotaIntegra,
    'c582': c582DedDobleImposicion,
    'c583': c583Bonificaciones,
    'c585': c585DedCreacionEmpleo,
    'c592': c592CuotaLiquida,
    'c598': c598Retenciones,
    'c599': c599PagosFraccionados,
    'c600': c600Resultado,
    'resultado_ingresar':      esAIngresar ? c600Resultado : 0,
    // Metadatos
    'total_ingresos':          totalIngresosEjercicio,
    'total_gastos':            totalGastosEjercicio,
    'es_complementaria':       esComplementaria,
    if (justificanteAeat != null)      'justificante_aeat': justificanteAeat,
    if (nJustificanteAnterior != null) 'n_justificante_anterior': nJustificanteAnterior,
  };

  Modelo200 copyWith({
    TipoGravamenIS? tipoGravamen,
    double? c02AjusteIS,
    double? c03OtrosAjustes,
    double? c547BasesNegativas,
    double? c582DedDobleImposicion,
    double? c583Bonificaciones,
    double? c585DedCreacionEmpleo,
  }) => Modelo200(
    id:                     id,
    empresaId:              empresaId,
    ejercicio:              ejercicio,
    fechaGeneracion:        fechaGeneracion,
    estado:                 estado,
    c01ResultadoContable:   c01ResultadoContable,
    c02AjusteIS:            c02AjusteIS ?? this.c02AjusteIS,
    c03OtrosAjustes:        c03OtrosAjustes ?? this.c03OtrosAjustes,
    c547BasesNegativas:     c547BasesNegativas ?? this.c547BasesNegativas,
    tipoGravamen:           tipoGravamen ?? this.tipoGravamen,
    c582DedDobleImposicion: c582DedDobleImposicion ?? this.c582DedDobleImposicion,
    c583Bonificaciones:     c583Bonificaciones ?? this.c583Bonificaciones,
    c585DedCreacionEmpleo:  c585DedCreacionEmpleo ?? this.c585DedCreacionEmpleo,
    c598Retenciones:        c598Retenciones,
    c599PagosFraccionados:  c599PagosFraccionados,
    totalIngresosEjercicio: totalIngresosEjercicio,
    totalGastosEjercicio:   totalGastosEjercicio,
    justificanteAeat:       justificanteAeat,
    esComplementaria:       esComplementaria,
    nJustificanteAnterior:  nJustificanteAnterior,
  );
}
