// ═══════════════════════════════════════════════════════════════════════════════
// COMPLEMENTOS VARIABLES — Modelo de datos
// ═══════════════════════════════════════════════════════════════════════════════

/// Tipos de complemento salarial variable.
enum TipoComplemento {
  productividad,
  horasExtra,
  plusTransporte,
  plusMantencion,
  comisionVentas,
  pagaExtraProrrateada,
  otro,
}

extension TipoComplementoExt on TipoComplemento {
  String get etiqueta {
    switch (this) {
      case TipoComplemento.productividad:       return 'Bonus de productividad';
      case TipoComplemento.horasExtra:          return 'Horas extra';
      case TipoComplemento.plusTransporte:       return 'Plus de transporte';
      case TipoComplemento.plusMantencion:       return 'Plus de manutención';
      case TipoComplemento.comisionVentas:      return 'Comisión de ventas';
      case TipoComplemento.pagaExtraProrrateada: return 'Paga extra prorrateada';
      case TipoComplemento.otro:                return 'Otro complemento';
    }
  }

  /// Por defecto, ¿cotiza a la SS?
  bool get cotizaSSPorDefecto {
    switch (this) {
      case TipoComplemento.productividad:
      case TipoComplemento.horasExtra:
      case TipoComplemento.comisionVentas:
      case TipoComplemento.pagaExtraProrrateada:
      case TipoComplemento.otro:
        return true;
      case TipoComplemento.plusTransporte:
      case TipoComplemento.plusMantencion:
        return false; // exentos hasta los límites legales
    }
  }

  /// Por defecto, ¿tributa en IRPF?
  bool get tributaIRPFPorDefecto {
    switch (this) {
      case TipoComplemento.productividad:
      case TipoComplemento.horasExtra:
      case TipoComplemento.comisionVentas:
      case TipoComplemento.pagaExtraProrrateada:
      case TipoComplemento.otro:
        return true;
      case TipoComplemento.plusTransporte:
      case TipoComplemento.plusMantencion:
        return false; // exentos hasta los límites legales
    }
  }
}

/// Complemento variable individual para una nómina concreta.
class ComplementoNomina {
  final String id;
  final TipoComplemento tipo;
  final String descripcion;
  final double importe;
  /// Importe que cotiza a la SS (puede ser parcial si hay exención).
  final double importeCotizaSS;
  /// Importe que tributa en IRPF (puede ser parcial si hay exención).
  final double importeTributaIRPF;
  /// Si el usuario ha forzado manualmente la cotización/tributación.
  final bool cotizaSSManual;
  final bool tributaIRPFManual;

  const ComplementoNomina({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.importe,
    this.importeCotizaSS = 0,
    this.importeTributaIRPF = 0,
    this.cotizaSSManual = false,
    this.tributaIRPFManual = false,
  });

  factory ComplementoNomina.fromMap(Map<String, dynamic> m) => ComplementoNomina(
    id:               m['id'] as String? ?? '',
    tipo: TipoComplemento.values.firstWhere(
      (e) => e.name == (m['tipo'] as String?),
      orElse: () => TipoComplemento.otro,
    ),
    descripcion:      m['descripcion'] as String? ?? '',
    importe:          (m['importe'] as num?)?.toDouble() ?? 0,
    importeCotizaSS:  (m['importe_cotiza_ss'] as num?)?.toDouble() ?? 0,
    importeTributaIRPF: (m['importe_tributa_irpf'] as num?)?.toDouble() ?? 0,
    cotizaSSManual:   m['cotiza_ss_manual'] as bool? ?? false,
    tributaIRPFManual: m['tributa_irpf_manual'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'tipo': tipo.name,
    'descripcion': descripcion,
    'importe': importe,
    'importe_cotiza_ss': importeCotizaSS,
    'importe_tributa_irpf': importeTributaIRPF,
    'cotiza_ss_manual': cotizaSSManual,
    'tributa_irpf_manual': tributaIRPFManual,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTES LEGALES 2026 — Límites de exención
// ═══════════════════════════════════════════════════════════════════════════════

class ConstantesComplementos2026 {
  /// Plus de transporte: exento hasta 0,26 €/km.
  static const double transporteExentoPorKm = 0.26;

  /// Plus de transporte: exento hasta 1.500 €/año.
  static const double transporteExentoAnual = 1500.0;

  /// Plus de manutención: exentos hasta estos importes diarios.
  /// Pernocta en España: 53,34 €/día.
  static const double manutencionPernoctaEspana = 53.34;

  /// Sin pernocta en España: 26,67 €/día.
  static const double manutencionSinPernoctaEspana = 26.67;

  /// Pernocta en el extranjero: 91,35 €/día.
  static const double manutencionPernoctaExtranjero = 91.35;

  /// Sin pernocta en el extranjero: 48,08 €/día.
  static const double manutencionSinPernoctaExtranjero = 48.08;

  /// Ticket restaurante: exento hasta 11,00 €/día laborable (2026).
  static const double ticketRestauranteExentoDia = 11.00;
}


