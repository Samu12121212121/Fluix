import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 111 — Retenciones e ingresos a cuenta del IRPF
// Art. 101 LIRPF + Art. 108 RIRPF
// ═══════════════════════════════════════════════════════════════════════════════

enum TipoDeclaracion111 {
  ingreso,        // I — Resultado positivo a ingresar
  negativa,       // N — Sin retenciones en el período
  complementaria, // C — Corrige declaración anterior
}

extension TipoDeclaracion111Ext on TipoDeclaracion111 {
  String get codigo {
    switch (this) {
      case TipoDeclaracion111.ingreso:        return 'I';
      case TipoDeclaracion111.negativa:       return 'N';
      case TipoDeclaracion111.complementaria: return 'C';
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoDeclaracion111.ingreso:        return 'A ingresar';
      case TipoDeclaracion111.negativa:       return 'Negativa';
      case TipoDeclaracion111.complementaria: return 'Complementaria';
    }
  }

  static TipoDeclaracion111 fromCodigo(String c) {
    switch (c.toUpperCase()) {
      case 'N': return TipoDeclaracion111.negativa;
      case 'C': return TipoDeclaracion111.complementaria;
      default:  return TipoDeclaracion111.ingreso;
    }
  }
}

enum EstadoModelo111 { borrador, presentado }

extension EstadoModelo111Ext on EstadoModelo111 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo111.borrador:    return 'Borrador';
      case EstadoModelo111.presentado:  return 'Presentado';
    }
  }
}

/// Datos de un trimestre para el Modelo 111.
class Modelo111 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final String trimestre; // "1T","2T","3T","4T"
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final DateTime plazoLimite;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN I — Rendimientos del trabajo
  // ═══════════════════════════════════════════════════════════════════════════
  final int c01;       // Nº perceptores RT dinerarios
  final double c02;    // Importe percepciones dinerarias
  final double c03;    // Retenciones dinerarias

  final int c04;       // Nº perceptores RT en especie
  final double c05;    // Valor retribuciones en especie
  final double c06;    // Ingresos a cuenta sobre especie

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN II — Rendimientos actividades económicas
  // ═══════════════════════════════════════════════════════════════════════════
  final int c07;
  final double c08;
  final double c09;
  final int c10;
  final double c11;
  final double c12;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN III — Premios juegos/concursos/rifas
  // ═══════════════════════════════════════════════════════════════════════════
  final int c13;
  final double c14;
  final double c15;
  final int c16;
  final double c17;
  final double c18;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN IV — Ganancias patrimoniales forestales
  // ═══════════════════════════════════════════════════════════════════════════
  final int c19;
  final double c20;
  final double c21;
  final int c22;
  final double c23;
  final double c24;

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN V — Contraprestaciones cesión derechos imagen
  // ═══════════════════════════════════════════════════════════════════════════
  final int c25;
  final double c26;
  final double c27;

  // ═══════════════════════════════════════════════════════════════════════════
  // TOTALES
  // ═══════════════════════════════════════════════════════════════════════════
  /// Casilla 28: Suma de retenciones (03+06+09+12+15+18+21+24+27)
  double get c28 => c03 + c06 + c09 + c12 + c15 + c18 + c21 + c24 + c27;

  /// Casilla 29: A deducir (solo complementarias: importe declaración anterior)
  final double c29;

  /// Casilla 30: Resultado a ingresar = max(c28 - c29, 0)
  double get c30 => (c28 - c29).clamp(0.0, double.infinity);

  // ═══════════════════════════════════════════════════════════════════════════
  // METADATOS
  // ═══════════════════════════════════════════════════════════════════════════
  final TipoDeclaracion111 tipo;
  final String? justificanteComplementaria;
  final EstadoModelo111 estado;
  final DateTime fechaCreacion;
  final List<String> nominasIncluidas; // IDs de nóminas que componen el trimestre

  /// Tipo automático según resultado.
  TipoDeclaracion111 get tipoAutomatico {
    if (tipo == TipoDeclaracion111.complementaria) return tipo;
    return c28 > 0 ? TipoDeclaracion111.ingreso : TipoDeclaracion111.negativa;
  }

  /// Período en formato AEAT: "1T", "2T", "3T", "4T".
  String get periodoAeat => trimestre;

  /// Texto del plazo límite.
  String get plazoTexto {
    final d = plazoLimite;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Días restantes hasta el plazo.
  int get diasHastaVencimiento => plazoLimite.difference(DateTime.now()).inDays;

  /// Rango de meses del trimestre.
  static ({int mesInicio, int mesFin}) rangoMeses(String trimestre) {
    switch (trimestre) {
      case '1T': return (mesInicio: 1, mesFin: 3);
      case '2T': return (mesInicio: 4, mesFin: 6);
      case '3T': return (mesInicio: 7, mesFin: 9);
      case '4T': return (mesInicio: 10, mesFin: 12);
      default:   return (mesInicio: 1, mesFin: 3);
    }
  }

  /// Plazo límite de presentación.
  static DateTime calcularPlazoLimite(int ejercicio, String trimestre) {
    switch (trimestre) {
      case '1T': return DateTime(ejercicio, 4, 20);
      case '2T': return DateTime(ejercicio, 7, 20);
      case '3T': return DateTime(ejercicio, 10, 20);
      case '4T': return DateTime(ejercicio + 1, 1, 20);
      default:   return DateTime(ejercicio, 4, 20);
    }
  }

  const Modelo111({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.trimestre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.plazoLimite,
    this.c01 = 0, this.c02 = 0, this.c03 = 0,
    this.c04 = 0, this.c05 = 0, this.c06 = 0,
    this.c07 = 0, this.c08 = 0, this.c09 = 0,
    this.c10 = 0, this.c11 = 0, this.c12 = 0,
    this.c13 = 0, this.c14 = 0, this.c15 = 0,
    this.c16 = 0, this.c17 = 0, this.c18 = 0,
    this.c19 = 0, this.c20 = 0, this.c21 = 0,
    this.c22 = 0, this.c23 = 0, this.c24 = 0,
    this.c25 = 0, this.c26 = 0, this.c27 = 0,
    this.c29 = 0,
    this.tipo = TipoDeclaracion111.ingreso,
    this.justificanteComplementaria,
    this.estado = EstadoModelo111.borrador,
    required this.fechaCreacion,
    this.nominasIncluidas = const [],
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SERIALIZACIÓN FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  factory Modelo111.fromMap(Map<String, dynamic> m) => Modelo111(
    id: m['id'] as String? ?? '',
    empresaId: m['empresa_id'] as String? ?? '',
    ejercicio: (m['ejercicio'] as num?)?.toInt() ?? 2026,
    trimestre: m['trimestre'] as String? ?? '1T',
    fechaInicio: _parseDate(m['fecha_inicio']),
    fechaFin: _parseDate(m['fecha_fin']),
    plazoLimite: _parseDate(m['plazo_limite']),
    c01: (m['c01'] as num?)?.toInt() ?? 0,
    c02: (m['c02'] as num?)?.toDouble() ?? 0,
    c03: (m['c03'] as num?)?.toDouble() ?? 0,
    c04: (m['c04'] as num?)?.toInt() ?? 0,
    c05: (m['c05'] as num?)?.toDouble() ?? 0,
    c06: (m['c06'] as num?)?.toDouble() ?? 0,
    c07: (m['c07'] as num?)?.toInt() ?? 0,
    c08: (m['c08'] as num?)?.toDouble() ?? 0,
    c09: (m['c09'] as num?)?.toDouble() ?? 0,
    c10: (m['c10'] as num?)?.toInt() ?? 0,
    c11: (m['c11'] as num?)?.toDouble() ?? 0,
    c12: (m['c12'] as num?)?.toDouble() ?? 0,
    c13: (m['c13'] as num?)?.toInt() ?? 0,
    c14: (m['c14'] as num?)?.toDouble() ?? 0,
    c15: (m['c15'] as num?)?.toDouble() ?? 0,
    c16: (m['c16'] as num?)?.toInt() ?? 0,
    c17: (m['c17'] as num?)?.toDouble() ?? 0,
    c18: (m['c18'] as num?)?.toDouble() ?? 0,
    c19: (m['c19'] as num?)?.toInt() ?? 0,
    c20: (m['c20'] as num?)?.toDouble() ?? 0,
    c21: (m['c21'] as num?)?.toDouble() ?? 0,
    c22: (m['c22'] as num?)?.toInt() ?? 0,
    c23: (m['c23'] as num?)?.toDouble() ?? 0,
    c24: (m['c24'] as num?)?.toDouble() ?? 0,
    c25: (m['c25'] as num?)?.toInt() ?? 0,
    c26: (m['c26'] as num?)?.toDouble() ?? 0,
    c27: (m['c27'] as num?)?.toDouble() ?? 0,
    c29: (m['c29'] as num?)?.toDouble() ?? 0,
    tipo: TipoDeclaracion111.values.firstWhere(
      (e) => e.name == (m['tipo'] as String?),
      orElse: () => TipoDeclaracion111.ingreso,
    ),
    justificanteComplementaria: m['justificante_complementaria'] as String?,
    estado: EstadoModelo111.values.firstWhere(
      (e) => e.name == (m['estado'] as String?),
      orElse: () => EstadoModelo111.borrador,
    ),
    fechaCreacion: _parseDate(m['fecha_creacion']),
    nominasIncluidas: (m['nominas_incluidas'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? [],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'ejercicio': ejercicio,
    'trimestre': trimestre,
    'fecha_inicio': Timestamp.fromDate(fechaInicio),
    'fecha_fin': Timestamp.fromDate(fechaFin),
    'plazo_limite': Timestamp.fromDate(plazoLimite),
    'c01': c01, 'c02': c02, 'c03': c03,
    'c04': c04, 'c05': c05, 'c06': c06,
    'c07': c07, 'c08': c08, 'c09': c09,
    'c10': c10, 'c11': c11, 'c12': c12,
    'c13': c13, 'c14': c14, 'c15': c15,
    'c16': c16, 'c17': c17, 'c18': c18,
    'c19': c19, 'c20': c20, 'c21': c21,
    'c22': c22, 'c23': c23, 'c24': c24,
    'c25': c25, 'c26': c26, 'c27': c27,
    'c28': c28, 'c29': c29, 'c30': c30,
    'tipo': tipo.name,
    if (justificanteComplementaria != null)
      'justificante_complementaria': justificanteComplementaria,
    'estado': estado.name,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'nominas_incluidas': nominasIncluidas,
  };

  Modelo111 copyWith({
    int? c01, double? c02, double? c03,
    int? c04, double? c05, double? c06,
    int? c07, double? c08, double? c09,
    int? c10, double? c11, double? c12,
    int? c13, double? c14, double? c15,
    int? c16, double? c17, double? c18,
    int? c19, double? c20, double? c21,
    int? c22, double? c23, double? c24,
    int? c25, double? c26, double? c27,
    double? c29,
    TipoDeclaracion111? tipo,
    String? justificanteComplementaria,
    EstadoModelo111? estado,
    List<String>? nominasIncluidas,
  }) => Modelo111(
    id: id, empresaId: empresaId, ejercicio: ejercicio, trimestre: trimestre,
    fechaInicio: fechaInicio, fechaFin: fechaFin, plazoLimite: plazoLimite,
    c01: c01 ?? this.c01, c02: c02 ?? this.c02, c03: c03 ?? this.c03,
    c04: c04 ?? this.c04, c05: c05 ?? this.c05, c06: c06 ?? this.c06,
    c07: c07 ?? this.c07, c08: c08 ?? this.c08, c09: c09 ?? this.c09,
    c10: c10 ?? this.c10, c11: c11 ?? this.c11, c12: c12 ?? this.c12,
    c13: c13 ?? this.c13, c14: c14 ?? this.c14, c15: c15 ?? this.c15,
    c16: c16 ?? this.c16, c17: c17 ?? this.c17, c18: c18 ?? this.c18,
    c19: c19 ?? this.c19, c20: c20 ?? this.c20, c21: c21 ?? this.c21,
    c22: c22 ?? this.c22, c23: c23 ?? this.c23, c24: c24 ?? this.c24,
    c25: c25 ?? this.c25, c26: c26 ?? this.c26, c27: c27 ?? this.c27,
    c29: c29 ?? this.c29,
    tipo: tipo ?? this.tipo,
    justificanteComplementaria: justificanteComplementaria ?? this.justificanteComplementaria,
    estado: estado ?? this.estado,
    fechaCreacion: fechaCreacion,
    nominasIncluidas: nominasIncluidas ?? this.nominasIncluidas,
  );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

