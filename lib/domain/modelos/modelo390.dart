import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 390 — Declaración-Resumen Anual IVA
// Consolida los 4 Mod.303 del ejercicio
// Presentación: 1–30 enero del año siguiente
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoModelo390 { borrador, presentado }

extension EstadoModelo390Ext on EstadoModelo390 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo390.borrador:   return 'Borrador';
      case EstadoModelo390.presentado: return 'Presentado';
    }
  }
}

class Modelo390 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final DateTime fechaGeneracion;
  final EstadoModelo390 estado;

  /// IDs de los 4 Mod.303 utilizados
  final List<String> mod303Ids;

  // ── IVA DEVENGADO (Sección 5) ──

  /// [01] Base imponible 4%
  final double c01;
  /// [02] Cuota 4%
  final double c02;
  /// [03] Base imponible 10%
  final double c03;
  /// [04] Cuota 10%
  final double c04;
  /// [05] Base imponible 21%
  final double c05;
  /// [06] Cuota 21%
  final double c06;
  /// [21] Base adq. intracom. bienes
  final double c21;
  /// [22] Cuota adq. intracom. bienes
  final double c22;
  /// [23] Base adq. intracom. servicios
  final double c23;
  /// [24] Cuota adq. intracom. servicios
  final double c24;
  /// [27] Base ISP otros supuestos
  final double c27;
  /// [28] Cuota ISP otros supuestos
  final double c28;

  /// [47] TOTAL CUOTA IVA DEVENGADA
  double get c47 => _r2(c02 + c04 + c06 + c22 + c24 + c28);

  // ── IVA DEDUCIBLE (Sección 5) ──

  /// [48] Base deducible interiores corrientes
  final double c48;
  /// [49] Cuota deducible interiores corrientes
  final double c49;
  /// [50] Base deducible interiores inversión
  final double c50;
  /// [51] Cuota deducible interiores inversión
  final double c51;
  /// [52] Base deducible importaciones corrientes
  final double c52;
  /// [53] Cuota deducible importaciones corrientes
  final double c53;
  /// [54] Base deducible importaciones inversión
  final double c54;
  /// [55] Cuota deducible importaciones inversión
  final double c55;
  /// [56] Base adq. intracom. bienes corrientes
  final double c56;
  /// [57] Cuota adq. intracom. bienes corrientes
  final double c57;
  /// [58] Base adq. intracom. bienes inversión
  final double c58;
  /// [59] Cuota adq. intracom. bienes inversión
  final double c59;
  /// [597] Base adq. intracom. servicios
  final double c597;
  /// [598] Cuota adq. intracom. servicios
  final double c598;
  /// [63] Regularización bienes inversión (manual)
  final double c63;
  /// [522] Regularización prorrata definitiva (manual)
  final double c522;

  /// [64] SUMA DEDUCCIONES
  double get c64 => _r2(c49 + c51 + c53 + c55 + c57 + c59 + c598 + c63 + c522);

  /// [65] RESULTADO RÉGIMEN GENERAL = [47] - [64]
  double get c65 => _r2(c47 - c64);

  // ── LIQUIDACIÓN ANUAL (Sección 7) ──

  /// [84] Suma de resultados = [65] (para PYMEs CLM sin simplificado)
  double get c84 => c65;

  /// [85] Compensación cuotas ejercicio anterior (manual)
  final double c85;

  /// [86] Resultado liquidación = [84] - [85]
  double get c86 => _r2(c84 - c85);

  // ── VOLUMEN OPERACIONES (Sección 10) ──

  /// [99] Operaciones régimen general
  final double c99;
  /// [103] Entregas intracomunitarias exentas
  final double c103;
  /// [104] Exportaciones y exentas con derecho a deducción
  final double c104;
  /// [105] Exentas sin derecho a deducción
  final double c105;
  /// [110] No sujetas por localización
  final double c110;

  // ── DATOS ESTADÍSTICOS (manual) ──
  final String actividadPrincipal;
  final String claveActividad;
  final String epigrafIAE;

  // ── ALERTAS ──
  final List<String> alertas;

  const Modelo390({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.fechaGeneracion,
    this.estado = EstadoModelo390.borrador,
    this.mod303Ids = const [],
    this.c01 = 0, this.c02 = 0,
    this.c03 = 0, this.c04 = 0,
    this.c05 = 0, this.c06 = 0,
    this.c21 = 0, this.c22 = 0,
    this.c23 = 0, this.c24 = 0,
    this.c27 = 0, this.c28 = 0,
    this.c48 = 0, this.c49 = 0,
    this.c50 = 0, this.c51 = 0,
    this.c52 = 0, this.c53 = 0,
    this.c54 = 0, this.c55 = 0,
    this.c56 = 0, this.c57 = 0,
    this.c58 = 0, this.c59 = 0,
    this.c597 = 0, this.c598 = 0,
    this.c63 = 0, this.c522 = 0,
    this.c85 = 0,
    this.c99 = 0, this.c103 = 0,
    this.c104 = 0, this.c105 = 0, this.c110 = 0,
    this.actividadPrincipal = '',
    this.claveActividad = 'A03',
    this.epigrafIAE = '',
    this.alertas = const [],
  });

  // Plazo presentación: 1-30 enero del año siguiente
  DateTime get plazoLimite => DateTime(ejercicio + 1, 1, 30);

  // ── Firestore ──

  factory Modelo390.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Modelo390(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      ejercicio: d['ejercicio'] ?? DateTime.now().year,
      fechaGeneracion: _parseTs(d['fecha_generacion']),
      estado: EstadoModelo390.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoModelo390.borrador,
      ),
      mod303Ids: List<String>.from(d['mod303_ids'] ?? []),
      c01: _d(d['c01']), c02: _d(d['c02']),
      c03: _d(d['c03']), c04: _d(d['c04']),
      c05: _d(d['c05']), c06: _d(d['c06']),
      c21: _d(d['c21']), c22: _d(d['c22']),
      c23: _d(d['c23']), c24: _d(d['c24']),
      c27: _d(d['c27']), c28: _d(d['c28']),
      c48: _d(d['c48']), c49: _d(d['c49']),
      c50: _d(d['c50']), c51: _d(d['c51']),
      c52: _d(d['c52']), c53: _d(d['c53']),
      c54: _d(d['c54']), c55: _d(d['c55']),
      c56: _d(d['c56']), c57: _d(d['c57']),
      c58: _d(d['c58']), c59: _d(d['c59']),
      c597: _d(d['c597']), c598: _d(d['c598']),
      c63: _d(d['c63']), c522: _d(d['c522']),
      c85: _d(d['c85']),
      c99: _d(d['c99']), c103: _d(d['c103']),
      c104: _d(d['c104']), c105: _d(d['c105']), c110: _d(d['c110']),
      actividadPrincipal: d['actividad_principal'] ?? '',
      claveActividad: d['clave_actividad'] ?? 'A03',
      epigrafIAE: d['epigraf_iae'] ?? '',
      alertas: List<String>.from(d['alertas'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'ejercicio': ejercicio,
    'fecha_generacion': Timestamp.fromDate(fechaGeneracion),
    'estado': estado.name,
    'mod303_ids': mod303Ids,
    // Devengado
    'c01': c01, 'c02': c02, 'c03': c03, 'c04': c04,
    'c05': c05, 'c06': c06, 'c21': c21, 'c22': c22,
    'c23': c23, 'c24': c24, 'c27': c27, 'c28': c28,
    'c47': c47,
    // Deducible
    'c48': c48, 'c49': c49, 'c50': c50, 'c51': c51,
    'c52': c52, 'c53': c53, 'c54': c54, 'c55': c55,
    'c56': c56, 'c57': c57, 'c58': c58, 'c59': c59,
    'c597': c597, 'c598': c598, 'c63': c63, 'c522': c522,
    'c64': c64, 'c65': c65,
    // Liquidación
    'c84': c84, 'c85': c85, 'c86': c86,
    // Volumen
    'c99': c99, 'c103': c103, 'c104': c104, 'c105': c105, 'c110': c110,
    // Datos
    'actividad_principal': actividadPrincipal,
    'clave_actividad': claveActividad,
    'epigraf_iae': epigrafIAE,
    'alertas': alertas,
  };

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

