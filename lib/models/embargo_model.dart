import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════════
// EMBARGO JUDICIAL — Modelo (art. 607 LEC)
// Persistencia: usuarios/{empleadoId}/embargos/{embargoId}
// ═════════════════════════════════════════════════════════════════════════════

class Embargo {
  final String id;

  /// Nombre del organismo que ordena el embargo.
  /// Ej: "Juzgado de Primera Instancia nº 2 de Guadalajara"
  final String organismo;

  /// Número de expediente / autos del juzgado.
  final String expediente;

  /// Si el juzgado fija un tope mensual máximo (€), se respeta aunque la
  /// tabla LEC permita embargar más.  null = sin tope (se aplica tabla LEC).
  final double? importeMensualMaximo;

  /// true = se aplica en las nóminas del período activo.
  final bool activo;

  final DateTime fechaInicio;

  /// null = sin fecha de fin prevista (vigente indefinidamente).
  final DateTime? fechaFin;

  const Embargo({
    required this.id,
    required this.organismo,
    required this.expediente,
    this.importeMensualMaximo,
    required this.activo,
    required this.fechaInicio,
    this.fechaFin,
  });

  // ── Serialización ──────────────────────────────────────────────────────────

  factory Embargo.fromMap(Map<String, dynamic> m) => Embargo(
        id: m['id'] as String? ?? '',
        organismo: m['organismo'] as String? ?? '',
        expediente: m['expediente'] as String? ?? '',
        importeMensualMaximo:
            (m['importe_mensual_maximo'] as num?)?.toDouble(),
        activo: m['activo'] as bool? ?? true,
        fechaInicio: _parseDate(m['fecha_inicio']),
        fechaFin:
            m['fecha_fin'] != null ? _parseDate(m['fecha_fin']) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'organismo': organismo,
        'expediente': expediente,
        if (importeMensualMaximo != null)
          'importe_mensual_maximo': importeMensualMaximo,
        'activo': activo,
        'fecha_inicio': Timestamp.fromDate(fechaInicio),
        if (fechaFin != null) 'fecha_fin': Timestamp.fromDate(fechaFin!),
      };

  Embargo copyWith({
    String? organismo,
    String? expediente,
    double? importeMensualMaximo,
    bool? activo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool clearImporteMaximo = false,
    bool clearFechaFin = false,
  }) =>
      Embargo(
        id: id,
        organismo: organismo ?? this.organismo,
        expediente: expediente ?? this.expediente,
        importeMensualMaximo: clearImporteMaximo
            ? null
            : importeMensualMaximo ?? this.importeMensualMaximo,
        activo: activo ?? this.activo,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFin:
            clearFechaFin ? null : (fechaFin ?? this.fechaFin),
      );

  // ── Helper ─────────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  /// true si el embargo está vigente en la fecha indicada.
  bool vigenteEn(DateTime fecha) {
    if (!activo) return false;
    if (fecha.isBefore(fechaInicio)) return false;
    if (fechaFin != null && fecha.isAfter(fechaFin!)) return false;
    return true;
  }
}

