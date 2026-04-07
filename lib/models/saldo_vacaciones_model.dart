import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SALDO DE VACACIONES — Modelo de datos con soporte de arrastre (carryover)
// ═══════════════════════════════════════════════════════════════════════════════

class SaldoVacaciones {
  final String empleadoId;
  final int anio;
  final double diasDevengados;
  final double diasDisfrutados;
  final double diasPendientes;
  final double diasPendientesAnoAnterior;
  final DateTime ultimaActualizacion;

  // ── Campos de arrastre (carryover) ──────────────────────────────────────────
  final double diasArrastre;            // Días traspasados del año anterior
  final double diasArrastreConsumidos;  // De esos, cuántos ya se han disfrutado
  final DateTime? fechaExpiracionArrastre; // Fecha límite para disfrutarlos

  const SaldoVacaciones({
    required this.empleadoId,
    required this.anio,
    required this.diasDevengados,
    this.diasDisfrutados = 0,
    this.diasPendientes = 0,
    this.diasPendientesAnoAnterior = 0,
    required this.ultimaActualizacion,
    this.diasArrastre = 0,
    this.diasArrastreConsumidos = 0,
    this.fechaExpiracionArrastre,
  });

  /// Días de arrastre restantes (no consumidos).
  double get diasArrastreRestantes =>
      (diasArrastre - diasArrastreConsumidos).clamp(0, double.infinity);

  /// ¿Los días de arrastre ya expiraron?
  bool get arrastreExpirado {
    if (fechaExpiracionArrastre == null) return false;
    return DateTime.now().isAfter(fechaExpiracionArrastre!);
  }

  /// Total disponible = devengados + arrastre vigente - disfrutados
  double get totalDisponible {
    final arrastre = arrastreExpirado ? 0.0 : diasArrastreRestantes;
    return (diasDevengados + arrastre + diasPendientesAnoAnterior - diasDisfrutados)
        .clamp(0, double.infinity);
  }

  /// Días ordinarios disponibles (sin contar arrastre).
  double get diasOrdinariosPendientes =>
      (diasDevengados - diasDisfrutados).clamp(0, double.infinity);

  factory SaldoVacaciones.fromMap(Map<String, dynamic> m) {
    return SaldoVacaciones(
      empleadoId: m['empleado_id'] as String? ?? '',
      anio: (m['anio'] as num?)?.toInt() ?? DateTime.now().year,
      diasDevengados: (m['dias_devengados'] as num?)?.toDouble() ?? 0,
      diasDisfrutados: (m['dias_disfrutados'] as num?)?.toDouble() ?? 0,
      diasPendientes: (m['dias_pendientes'] as num?)?.toDouble() ?? 0,
      diasPendientesAnoAnterior:
          (m['dias_pendientes_ano_anterior'] as num?)?.toDouble() ?? 0,
      ultimaActualizacion: _parseDate(m['ultima_actualizacion']),
      diasArrastre: (m['dias_arrastre'] as num?)?.toDouble() ?? 0,
      diasArrastreConsumidos:
          (m['dias_arrastre_consumidos'] as num?)?.toDouble() ?? 0,
      fechaExpiracionArrastre: m['fecha_expiracion_arrastre'] != null
          ? _parseDate(m['fecha_expiracion_arrastre'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'empleado_id': empleadoId,
        'anio': anio,
        'dias_devengados': diasDevengados,
        'dias_disfrutados': diasDisfrutados,
        'dias_pendientes': diasPendientes,
        'dias_pendientes_ano_anterior': diasPendientesAnoAnterior,
        'ultima_actualizacion': Timestamp.fromDate(ultimaActualizacion),
        'dias_arrastre': diasArrastre,
        'dias_arrastre_consumidos': diasArrastreConsumidos,
        if (fechaExpiracionArrastre != null)
          'fecha_expiracion_arrastre':
              Timestamp.fromDate(fechaExpiracionArrastre!),
      };

  SaldoVacaciones copyWith({
    double? diasDevengados,
    double? diasDisfrutados,
    double? diasPendientes,
    double? diasPendientesAnoAnterior,
    DateTime? ultimaActualizacion,
    double? diasArrastre,
    double? diasArrastreConsumidos,
    DateTime? fechaExpiracionArrastre,
  }) =>
      SaldoVacaciones(
        empleadoId: empleadoId,
        anio: anio,
        diasDevengados: diasDevengados ?? this.diasDevengados,
        diasDisfrutados: diasDisfrutados ?? this.diasDisfrutados,
        diasPendientes: diasPendientes ?? this.diasPendientes,
        diasPendientesAnoAnterior:
            diasPendientesAnoAnterior ?? this.diasPendientesAnoAnterior,
        ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
        diasArrastre: diasArrastre ?? this.diasArrastre,
        diasArrastreConsumidos:
            diasArrastreConsumidos ?? this.diasArrastreConsumidos,
        fechaExpiracionArrastre:
            fechaExpiracionArrastre ?? this.fechaExpiracionArrastre,
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN DE ARRASTRE (CARRYOVER)
// ═══════════════════════════════════════════════════════════════════════════════

class ConfiguracionCarryover {
  final int diasMaximosTraspasar; // máx días a traspasar (default 5)
  final int mesExpiracion; // mes límite (default 3 = marzo)
  final int diaExpiracion; // día límite (default 31)
  final bool notificarAnteDeExpirar; // enviar notificación 7 días antes
  final bool permitirTraspasManual; // el propietario puede hacerlo manualmente

  const ConfiguracionCarryover({
    this.diasMaximosTraspasar = 5,
    this.mesExpiracion = 3,
    this.diaExpiracion = 31,
    this.notificarAnteDeExpirar = true,
    this.permitirTraspasManual = true,
  });

  /// Fecha de expiración para un año dado.
  DateTime fechaExpiracion(int anio) =>
      DateTime(anio, mesExpiracion, diaExpiracion);

  factory ConfiguracionCarryover.fromMap(Map<String, dynamic> m) {
    return ConfiguracionCarryover(
      diasMaximosTraspasar:
          (m['dias_maximos_traspasar'] as num?)?.toInt() ?? 5,
      mesExpiracion: (m['mes_expiracion'] as num?)?.toInt() ?? 3,
      diaExpiracion: (m['dia_expiracion'] as num?)?.toInt() ?? 31,
      notificarAnteDeExpirar:
          m['notificar_antes_expirar'] as bool? ?? true,
      permitirTraspasManual:
          m['permitir_traspaso_manual'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'dias_maximos_traspasar': diasMaximosTraspasar,
        'mes_expiracion': mesExpiracion,
        'dia_expiracion': diaExpiracion,
        'notificar_antes_expirar': notificarAnteDeExpirar,
        'permitir_traspaso_manual': permitirTraspasManual,
      };
}
