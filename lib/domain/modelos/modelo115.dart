import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 115 — Retenciones IRPF arrendamientos de locales de negocio
// Art. 101.6 LIRPF — Retención del 19% sobre arrendamientos
// Formato fichero: DR115e15v13
// ═══════════════════════════════════════════════════════════════════════════════

enum TipoDeclaracion115 {
  ingreso,        // I — Resultado positivo
  domiciliacion,  // U — Domiciliación bancaria
  ingresoCCT,     // G — Ingreso en CCT
  negativa,       // N — Sin arrendamientos
}

extension TipoDeclaracion115Ext on TipoDeclaracion115 {
  String get codigo {
    switch (this) {
      case TipoDeclaracion115.ingreso:       return 'I';
      case TipoDeclaracion115.domiciliacion: return 'U';
      case TipoDeclaracion115.ingresoCCT:    return 'G';
      case TipoDeclaracion115.negativa:      return 'N';
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoDeclaracion115.ingreso:       return 'A ingresar';
      case TipoDeclaracion115.domiciliacion: return 'Domiciliación';
      case TipoDeclaracion115.ingresoCCT:    return 'Ingreso CCT';
      case TipoDeclaracion115.negativa:      return 'Negativa';
    }
  }

  static TipoDeclaracion115 fromCodigo(String c) {
    switch (c.toUpperCase()) {
      case 'U': return TipoDeclaracion115.domiciliacion;
      case 'G': return TipoDeclaracion115.ingresoCCT;
      case 'N': return TipoDeclaracion115.negativa;
      default:  return TipoDeclaracion115.ingreso;
    }
  }
}

enum EstadoModelo115 { borrador, generado, presentado }

extension EstadoModelo115Ext on EstadoModelo115 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo115.borrador:   return 'Borrador';
      case EstadoModelo115.generado:   return 'Generado';
      case EstadoModelo115.presentado: return 'Presentado';
    }
  }
}

/// Detalle de un arrendador incluido en la declaración
class ArrendadorDetalle {
  final String nif;
  final String nombre;
  final double baseImponible;
  final double retencion;

  const ArrendadorDetalle({
    required this.nif,
    required this.nombre,
    required this.baseImponible,
    required this.retencion,
  });

  factory ArrendadorDetalle.fromMap(Map<String, dynamic> d) => ArrendadorDetalle(
    nif: d['nif'] ?? '',
    nombre: d['nombre'] ?? '',
    baseImponible: (d['base_imponible'] as num?)?.toDouble() ?? 0,
    retencion: (d['retencion'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'nif': nif,
    'nombre': nombre,
    'base_imponible': baseImponible,
    'retencion': retencion,
  };
}

class Modelo115 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final String trimestre; // "1T","2T","3T","4T"
  final DateTime fechaGeneracion;
  final EstadoModelo115 estado;

  /// [01] Nº de perceptores (arrendadores únicos)
  final int c01;

  /// [02] Base de retenciones
  final double c02;

  /// [03] Retenciones practicadas = [02] × 0.19
  final double c03;

  /// [04] A deducir (declaración anterior si complementaria)
  final double c04;

  /// [05] Resultado a ingresar = [03] - [04]
  double get c05 => _r2(c03 - c04);

  final TipoDeclaracion115 tipoDeclaracion;
  final bool esComplementaria;
  final String? nJustificanteAnterior; // 13 dígitos
  final String? ibanDomiciliacion;     // 34 chars o null

  /// Detalle de arrendadores (para control interno)
  final List<ArrendadorDetalle> arrendadores;

  const Modelo115({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.trimestre,
    required this.fechaGeneracion,
    this.estado = EstadoModelo115.borrador,
    this.c01 = 0,
    this.c02 = 0,
    this.c03 = 0,
    this.c04 = 0,
    this.tipoDeclaracion = TipoDeclaracion115.ingreso,
    this.esComplementaria = false,
    this.nJustificanteAnterior,
    this.ibanDomiciliacion,
    this.arrendadores = const [],
  });

  // ── Períodos y plazos ──

  static DateTime calcularPlazoLimite(int ejercicio, String trimestre) {
    switch (trimestre) {
      case '1T': return DateTime(ejercicio, 4, 20);
      case '2T': return DateTime(ejercicio, 7, 20);
      case '3T': return DateTime(ejercicio, 10, 20);
      case '4T': return DateTime(ejercicio + 1, 1, 20);
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

  static ({DateTime inicio, DateTime fin}) rangoTrimestre(int ejercicio, String trimestre) {
    final rango = rangoMeses(trimestre);
    return (
      inicio: DateTime(ejercicio, rango.mesInicio, 1),
      fin: DateTime(ejercicio, rango.mesFin + 1, 1),
    );
  }

  // ── Firestore ──

  factory Modelo115.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Modelo115(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      ejercicio: d['ejercicio'] ?? DateTime.now().year,
      trimestre: d['trimestre'] ?? '1T',
      fechaGeneracion: _parseTs(d['fecha_generacion']),
      estado: EstadoModelo115.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoModelo115.borrador,
      ),
      c01: (d['c01'] as num?)?.toInt() ?? 0,
      c02: (d['c02'] as num?)?.toDouble() ?? 0,
      c03: (d['c03'] as num?)?.toDouble() ?? 0,
      c04: (d['c04'] as num?)?.toDouble() ?? 0,
      tipoDeclaracion: TipoDeclaracion115Ext.fromCodigo(d['tipo_declaracion'] ?? 'I'),
      esComplementaria: d['es_complementaria'] ?? false,
      nJustificanteAnterior: d['n_justificante_anterior'],
      ibanDomiciliacion: d['iban_domiciliacion'],
      arrendadores: (d['arrendadores'] as List<dynamic>?)
              ?.map((a) => ArrendadorDetalle.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
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
    'tipo_declaracion': tipoDeclaracion.codigo,
    'es_complementaria': esComplementaria,
    'n_justificante_anterior': nJustificanteAnterior,
    'iban_domiciliacion': ibanDomiciliacion,
    'arrendadores': arrendadores.map((a) => a.toMap()).toList(),
  };

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

