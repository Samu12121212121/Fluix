import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INCAPACIDAD TEMPORAL (IT) — Modelo de datos
// Normativa: art. 169-176 LGSS · RD 625/2014 · Orden TAS/399/2004
// ═══════════════════════════════════════════════════════════════════════════════

/// Tipo de contingencia a efectos del cálculo de IT.
enum TipoContingencia {
  enfermedadComun,
  accidenteNoLaboral,
  accidenteLaboral,
  enfermedadProfesional,
  maternidad,
  paternidad,
}

extension TipoContingenciaExt on TipoContingencia {
  String get etiqueta {
    switch (this) {
      case TipoContingencia.enfermedadComun:       return 'Enfermedad común';
      case TipoContingencia.accidenteNoLaboral:    return 'Accidente no laboral';
      case TipoContingencia.accidenteLaboral:      return 'Accidente laboral';
      case TipoContingencia.enfermedadProfesional: return 'Enfermedad profesional';
      case TipoContingencia.maternidad:            return 'Maternidad';
      case TipoContingencia.paternidad:            return 'Paternidad';
    }
  }

  /// true = contingencia profesional (AT / EP). false = común.
  bool get esProfesional =>
      this == TipoContingencia.accidenteLaboral ||
      this == TipoContingencia.enfermedadProfesional;

  /// true = maternidad / paternidad (100% base reguladora, INSS).
  bool get esMaternidadPaternidad =>
      this == TipoContingencia.maternidad ||
      this == TipoContingencia.paternidad;

  /// true = contingencia común (enfermedad común / acc. no laboral).
  bool get esComun =>
      this == TipoContingencia.enfermedadComun ||
      this == TipoContingencia.accidenteNoLaboral;
}

/// Modelo de baja laboral / incapacidad temporal.
/// Subcolección Firestore: `usuarios/{empleadoId}/bajas_laborales/{id}`
class BajaLaboral {
  final String id;
  final String empleadoId;
  final TipoContingencia tipo;
  final DateTime fechaInicio;
  final DateTime? fechaFin;        // null = baja activa
  final String? numeroParteMedico;
  final String? diagnostico;
  final String? observaciones;
  /// Base reguladora diaria = base cotización mes anterior / 30.
  final double baseReguladoraDiaria;
  /// Si el convenio mejora voluntariamente los días 1-3.
  final bool mejoraConvenioDias1a3;
  /// Porcentaje de mejora voluntaria días 1-3 (ej: 60% o 100%).
  final double porcentajeMejoraDias1a3;
  final DateTime fechaCreacion;

  const BajaLaboral({
    required this.id,
    required this.empleadoId,
    required this.tipo,
    required this.fechaInicio,
    this.fechaFin,
    this.numeroParteMedico,
    this.diagnostico,
    this.observaciones,
    required this.baseReguladoraDiaria,
    this.mejoraConvenioDias1a3 = false,
    this.porcentajeMejoraDias1a3 = 0,
    required this.fechaCreacion,
  });

  bool get activa => fechaFin == null;

  /// Número total de días de baja hasta la fecha dada (o hasta hoy si activa).
  int diasTotales([DateTime? hasta]) {
    final fin = fechaFin ?? hasta ?? DateTime.now();
    // Usar UTC para evitar problemas con cambio de hora (DST)
    final a = DateTime.utc(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final b = DateTime.utc(fin.year, fin.month, fin.day);
    return b.difference(a).inDays + 1;
    final fin       = fechaFin ?? DateTime.now();

    if (fechaInicio.isAfter(finMes) || fin.isBefore(inicioMes)) return 0;

    final start = fechaInicio.isBefore(inicioMes) ? inicioMes : fechaInicio;
    final end   = fin.isAfter(finMes) ? finMes : fin;

    return end.difference(start).inDays + 1;
  }

  /// Día de baja en el que empieza el mes (relativo al inicio de la baja).
  /// Ejemplo: baja empezó el 20/01, mes febrero → diaInicioRelativo = 12.
  int diaInicioRelativo(int mes, int anio) {
    // Usar aritmética de días de calendario (start y end están en el mismo mes)
    // para evitar errores por cambio de hora (DST).
    return end.day - start.day + 1;
    if (fechaInicio.isAfter(inicioMes)) return 1;
    return inicioMes.difference(fechaInicio).inDays + 1;
  }

    return end.difference(start).inDays + 1;
    tipo: TipoContingencia.values.firstWhere(
      (e) => e.name == (m['tipo'] as String?),
    // Usar UTC para evitar problemas con cambio de hora (DST)
    final a = DateTime.utc(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final b = DateTime.utc(anio, mes, 1);
    return b.difference(a).inDays + 1;
    ),
    fechaInicio:            _parseDate(m['fecha_inicio']),
    fechaFin:               m['fecha_fin'] != null ? _parseDate(m['fecha_fin']) : null,
    numeroParteMedico:      m['numero_parte_medico'] as String?,
    diagnostico:            m['diagnostico'] as String?,
    return inicioMes.difference(fechaInicio).inDays + 1;
    porcentajeMejoraDias1a3: (m['porcentaje_mejora_dias_1a3'] as num?)?.toDouble() ?? 0,
    fechaCreacion:          _parseDate(m['fecha_creacion']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empleado_id': empleadoId,
    'tipo': tipo.name,
    'fecha_inicio': Timestamp.fromDate(fechaInicio),
    if (fechaFin != null) 'fecha_fin': Timestamp.fromDate(fechaFin!),
    'numero_parte_medico': numeroParteMedico,
    'diagnostico': diagnostico,
    'observaciones': observaciones,
    'base_reguladora_diaria': baseReguladoraDiaria,
    'mejora_convenio_dias_1a3': mejoraConvenioDias1a3,
    'porcentaje_mejora_dias_1a3': porcentajeMejoraDias1a3,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

/// Resultado del cálculo de IT para un mes concreto.
class ResultadoIT {
  final int diasBaja;                // días de baja en este mes
  final int diasTrabajados;          // días del mes - días baja
  final double importeIT;            // prestación total IT del mes
  final double importeCargoEmpresa;  // lo que paga directamente la empresa
  final double importeCargoINSS;     // lo que anticipa la empresa (descuenta en TC1)
  final double importeCargoMutua;    // contingencias profesionales
  final double descuentoSalario;     // proporción del salario que se descuenta
  final TipoContingencia tipo;
  final List<TramoIT> tramos;        // desglose por tramos

  const ResultadoIT({
    required this.diasBaja,
    required this.diasTrabajados,
    required this.importeIT,
    required this.importeCargoEmpresa,
    required this.importeCargoINSS,
    required this.importeCargoMutua,
    required this.descuentoSalario,
    required this.tipo,
    required this.tramos,
  });

  static const ResultadoIT vacio = ResultadoIT(
    diasBaja: 0, diasTrabajados: 30, importeIT: 0,
    importeCargoEmpresa: 0, importeCargoINSS: 0, importeCargoMutua: 0,
    descuentoSalario: 0, tipo: TipoContingencia.enfermedadComun,
    tramos: [],
  );
}

/// Tramo individual de cálculo de IT.
class TramoIT {
  final int diaDesde;
  final int diaHasta;
  final double porcentaje;
  final double importeDiario;
  final int dias;
  final String pagador; // 'trabajador', 'empresa', 'inss', 'mutua'
  final String descripcion;

  const TramoIT({
    required this.diaDesde,
    required this.diaHasta,
    required this.porcentaje,
    required this.importeDiario,
    required this.dias,
    required this.pagador,
    required this.descripcion,
  });

  double get importe => importeDiario * dias;
}

