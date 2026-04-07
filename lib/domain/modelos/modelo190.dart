import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO 190 — Resumen anual retenciones e ingresos a cuenta IRPF
// Orden HAC/1431/2025 (BOE 12/12/2025)
// Formato fichero: DISENOS_LOGICOS_190_2025.pdf
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoModelo190 { borrador, presentado }

extension EstadoModelo190Ext on EstadoModelo190 {
  String get etiqueta {
    switch (this) {
      case EstadoModelo190.borrador:   return 'Borrador';
      case EstadoModelo190.presentado: return 'Presentado';
    }
  }
}

/// Datos de un perceptor (empleado) dentro del Modelo 190.
class Perceptor190 {
  final String empleadoId;
  final String nifPerceptor;
  final String apellidosNombre;       // "GARCIA LOPEZ JUAN" (mayúsc, sin acentos)
  final String codigoProvincia;       // "19" = Guadalajara, etc.
  final String clavePercepcion;       // "A" para empleados por cuenta ajena
  final String subclave;              // "  " (blancos para clave A)

  // ── Percepciones dinerarias (no IT) ──────────────────────────────────────
  final double percepcionDinIntegra;  // bruto anual dinerario
  final double retencionesPracticadas;// retenciones IRPF anuales

  // ── Percepciones en especie (no IT) ──────────────────────────────────────
  final double valoracionEspecie;     // retrib. especie anual
  final double ingresosCuentaEspecie; // ingresos a cuenta especie
  final double ingresosCuentaRepercutidosEspecie; // repercutidos al empleado

  // ── Datos adicionales clave A ────────────────────────────────────────────
  final int ejercicioDevengo;         // 0 si no hay atrasos
  final bool ceutaMelilla;            // false para CLM
  final int anioNacimiento;
  final int situacionFamiliar;        // 1, 2 o 3
  final String nifConyuge;            // solo si sit. familiar = 2
  final int discapacidad;             // 0, 1, 2 o 3
  final int contrato;                 // 1=general, 2=<1año, 3=especial, 4=jornalero
  final bool movilidadGeografica;
  final double reducciones;           // reducción rto. trabajo aplicada
  final double gastosDeducibles;      // cuotas SS obrera anuales
  final double pensionesCompensatorias;
  final double anualidadesAlimentos;

  // ── Descendientes ────────────────────────────────────────────────────────
  final int descendientesMenores3;
  final int descendientesMenores3Entero;
  final int descendientesResto;
  final int descendientesRestoEntero;
  final int descDiscap33_65;
  final int descDiscap33_65Entero;
  final int descDiscapMovilidad;
  final int descDiscapMovilidadEntero;
  final int descDiscap65;
  final int descDiscap65Entero;

  // ── Ascendientes ─────────────────────────────────────────────────────────
  final int ascendientesMenor75;
  final int ascendientesMenor75Entero;
  final int ascendientesMayor75;
  final int ascendientesMayor75Entero;
  final int ascDiscap33_65;
  final int ascDiscap33_65Entero;
  final int ascDiscapMovilidad;
  final int ascDiscapMovilidadEntero;
  final int ascDiscap65;
  final int ascDiscap65Entero;

  // ── Hijos computados (para deducción) ────────────────────────────────────
  final int hijo1; // 0=no, 1=entero, 2=mitad
  final int hijo2;
  final int hijo3;
  final bool prestamoVivienda;

  // ── Incapacidad temporal ─────────────────────────────────────────────────
  final double percepcionITDineraria;
  final double retencionesIT;
  final double valoracionITEspecie;
  final double ingresosCuentaITEspecie;
  final double ingresosCuentaRepercutidosITEspecie;

  const Perceptor190({
    required this.empleadoId,
    required this.nifPerceptor,
    required this.apellidosNombre,
    this.codigoProvincia = '19',
    this.clavePercepcion = 'A',
    this.subclave = '  ',
    this.percepcionDinIntegra = 0,
    this.retencionesPracticadas = 0,
    this.valoracionEspecie = 0,
    this.ingresosCuentaEspecie = 0,
    this.ingresosCuentaRepercutidosEspecie = 0,
    this.ejercicioDevengo = 0,
    this.ceutaMelilla = false,
    required this.anioNacimiento,
    this.situacionFamiliar = 3,
    this.nifConyuge = '',
    this.discapacidad = 0,
    this.contrato = 1,
    this.movilidadGeografica = false,
    this.reducciones = 0,
    this.gastosDeducibles = 0,
    this.pensionesCompensatorias = 0,
    this.anualidadesAlimentos = 0,
    this.descendientesMenores3 = 0,
    this.descendientesMenores3Entero = 0,
    this.descendientesResto = 0,
    this.descendientesRestoEntero = 0,
    this.descDiscap33_65 = 0,
    this.descDiscap33_65Entero = 0,
    this.descDiscapMovilidad = 0,
    this.descDiscapMovilidadEntero = 0,
    this.descDiscap65 = 0,
    this.descDiscap65Entero = 0,
    this.ascendientesMenor75 = 0,
    this.ascendientesMenor75Entero = 0,
    this.ascendientesMayor75 = 0,
    this.ascendientesMayor75Entero = 0,
    this.ascDiscap33_65 = 0,
    this.ascDiscap33_65Entero = 0,
    this.ascDiscapMovilidad = 0,
    this.ascDiscapMovilidadEntero = 0,
    this.ascDiscap65 = 0,
    this.ascDiscap65Entero = 0,
    this.hijo1 = 0,
    this.hijo2 = 0,
    this.hijo3 = 0,
    this.prestamoVivienda = false,
    this.percepcionITDineraria = 0,
    this.retencionesIT = 0,
    this.valoracionITEspecie = 0,
    this.ingresosCuentaITEspecie = 0,
    this.ingresosCuentaRepercutidosITEspecie = 0,
  });

  factory Perceptor190.fromMap(Map<String, dynamic> m) => Perceptor190(
    empleadoId: m['empleado_id'] as String? ?? '',
    nifPerceptor: m['nif_perceptor'] as String? ?? '',
    apellidosNombre: m['apellidos_nombre'] as String? ?? '',
    codigoProvincia: m['codigo_provincia'] as String? ?? '19',
    clavePercepcion: m['clave_percepcion'] as String? ?? 'A',
    subclave: m['subclave'] as String? ?? '  ',
    percepcionDinIntegra: (m['percepcion_din_integra'] as num?)?.toDouble() ?? 0,
    retencionesPracticadas: (m['retenciones_practicadas'] as num?)?.toDouble() ?? 0,
    valoracionEspecie: (m['valoracion_especie'] as num?)?.toDouble() ?? 0,
    ingresosCuentaEspecie: (m['ingresos_cuenta_especie'] as num?)?.toDouble() ?? 0,
    ingresosCuentaRepercutidosEspecie: (m['ingresos_cuenta_repercutidos_especie'] as num?)?.toDouble() ?? 0,
    ejercicioDevengo: (m['ejercicio_devengo'] as num?)?.toInt() ?? 0,
    ceutaMelilla: m['ceuta_melilla'] as bool? ?? false,
    anioNacimiento: (m['anio_nacimiento'] as num?)?.toInt() ?? 1990,
    situacionFamiliar: (m['situacion_familiar'] as num?)?.toInt() ?? 3,
    nifConyuge: m['nif_conyuge'] as String? ?? '',
    discapacidad: (m['discapacidad'] as num?)?.toInt() ?? 0,
    contrato: (m['contrato'] as num?)?.toInt() ?? 1,
    movilidadGeografica: m['movilidad_geografica'] as bool? ?? false,
    reducciones: (m['reducciones'] as num?)?.toDouble() ?? 0,
    gastosDeducibles: (m['gastos_deducibles'] as num?)?.toDouble() ?? 0,
    pensionesCompensatorias: (m['pensiones_compensatorias'] as num?)?.toDouble() ?? 0,
    anualidadesAlimentos: (m['anualidades_alimentos'] as num?)?.toDouble() ?? 0,
    descendientesMenores3: (m['descendientes_menores_3'] as num?)?.toInt() ?? 0,
    descendientesMenores3Entero: (m['descendientes_menores_3_entero'] as num?)?.toInt() ?? 0,
    descendientesResto: (m['descendientes_resto'] as num?)?.toInt() ?? 0,
    descendientesRestoEntero: (m['descendientes_resto_entero'] as num?)?.toInt() ?? 0,
    descDiscap33_65: (m['desc_discap_33_65'] as num?)?.toInt() ?? 0,
    descDiscap33_65Entero: (m['desc_discap_33_65_entero'] as num?)?.toInt() ?? 0,
    descDiscapMovilidad: (m['desc_discap_movilidad'] as num?)?.toInt() ?? 0,
    descDiscapMovilidadEntero: (m['desc_discap_movilidad_entero'] as num?)?.toInt() ?? 0,
    descDiscap65: (m['desc_discap_65'] as num?)?.toInt() ?? 0,
    descDiscap65Entero: (m['desc_discap_65_entero'] as num?)?.toInt() ?? 0,
    ascendientesMenor75: (m['ascendientes_menor_75'] as num?)?.toInt() ?? 0,
    ascendientesMenor75Entero: (m['ascendientes_menor_75_entero'] as num?)?.toInt() ?? 0,
    ascendientesMayor75: (m['ascendientes_mayor_75'] as num?)?.toInt() ?? 0,
    ascendientesMayor75Entero: (m['ascendientes_mayor_75_entero'] as num?)?.toInt() ?? 0,
    ascDiscap33_65: (m['asc_discap_33_65'] as num?)?.toInt() ?? 0,
    ascDiscap33_65Entero: (m['asc_discap_33_65_entero'] as num?)?.toInt() ?? 0,
    ascDiscapMovilidad: (m['asc_discap_movilidad'] as num?)?.toInt() ?? 0,
    ascDiscapMovilidadEntero: (m['asc_discap_movilidad_entero'] as num?)?.toInt() ?? 0,
    ascDiscap65: (m['asc_discap_65'] as num?)?.toInt() ?? 0,
    ascDiscap65Entero: (m['asc_discap_65_entero'] as num?)?.toInt() ?? 0,
    hijo1: (m['hijo1'] as num?)?.toInt() ?? 0,
    hijo2: (m['hijo2'] as num?)?.toInt() ?? 0,
    hijo3: (m['hijo3'] as num?)?.toInt() ?? 0,
    prestamoVivienda: m['prestamo_vivienda'] as bool? ?? false,
    percepcionITDineraria: (m['percepcion_it_dineraria'] as num?)?.toDouble() ?? 0,
    retencionesIT: (m['retenciones_it'] as num?)?.toDouble() ?? 0,
    valoracionITEspecie: (m['valoracion_it_especie'] as num?)?.toDouble() ?? 0,
    ingresosCuentaITEspecie: (m['ingresos_cuenta_it_especie'] as num?)?.toDouble() ?? 0,
    ingresosCuentaRepercutidosITEspecie: (m['ingresos_cuenta_repercutidos_it_especie'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'empleado_id': empleadoId,
    'nif_perceptor': nifPerceptor,
    'apellidos_nombre': apellidosNombre,
    'codigo_provincia': codigoProvincia,
    'clave_percepcion': clavePercepcion,
    'subclave': subclave,
    'percepcion_din_integra': percepcionDinIntegra,
    'retenciones_practicadas': retencionesPracticadas,
    'valoracion_especie': valoracionEspecie,
    'ingresos_cuenta_especie': ingresosCuentaEspecie,
    'ingresos_cuenta_repercutidos_especie': ingresosCuentaRepercutidosEspecie,
    'ejercicio_devengo': ejercicioDevengo,
    'ceuta_melilla': ceutaMelilla,
    'anio_nacimiento': anioNacimiento,
    'situacion_familiar': situacionFamiliar,
    'nif_conyuge': nifConyuge,
    'discapacidad': discapacidad,
    'contrato': contrato,
    'movilidad_geografica': movilidadGeografica,
    'reducciones': reducciones,
    'gastos_deducibles': gastosDeducibles,
    'pensiones_compensatorias': pensionesCompensatorias,
    'anualidades_alimentos': anualidadesAlimentos,
    'descendientes_menores_3': descendientesMenores3,
    'descendientes_menores_3_entero': descendientesMenores3Entero,
    'descendientes_resto': descendientesResto,
    'descendientes_resto_entero': descendientesRestoEntero,
    'desc_discap_33_65': descDiscap33_65,
    'desc_discap_33_65_entero': descDiscap33_65Entero,
    'desc_discap_movilidad': descDiscapMovilidad,
    'desc_discap_movilidad_entero': descDiscapMovilidadEntero,
    'desc_discap_65': descDiscap65,
    'desc_discap_65_entero': descDiscap65Entero,
    'ascendientes_menor_75': ascendientesMenor75,
    'ascendientes_menor_75_entero': ascendientesMenor75Entero,
    'ascendientes_mayor_75': ascendientesMayor75,
    'ascendientes_mayor_75_entero': ascendientesMayor75Entero,
    'asc_discap_33_65': ascDiscap33_65,
    'asc_discap_33_65_entero': ascDiscap33_65Entero,
    'asc_discap_movilidad': ascDiscapMovilidad,
    'asc_discap_movilidad_entero': ascDiscapMovilidadEntero,
    'asc_discap_65': ascDiscap65,
    'asc_discap_65_entero': ascDiscap65Entero,
    'hijo1': hijo1, 'hijo2': hijo2, 'hijo3': hijo3,
    'prestamo_vivienda': prestamoVivienda,
    'percepcion_it_dineraria': percepcionITDineraria,
    'retenciones_it': retencionesIT,
    'valoracion_it_especie': valoracionITEspecie,
    'ingresos_cuenta_it_especie': ingresosCuentaITEspecie,
    'ingresos_cuenta_repercutidos_it_especie': ingresosCuentaRepercutidosITEspecie,
  };
}

/// Modelo 190 completo (Tipo 1 + lista de Tipo 2).
class Modelo190 {
  final String id;
  final String empresaId;
  final int ejercicio;
  final DateTime plazoLimite;     // 31 enero del año siguiente
  final EstadoModelo190 estado;
  final int nTotalPercepciones;
  final double importeTotalPercepciones;
  final double totalRetenciones;
  final bool declaracionComplementaria;
  final bool declaracionSustitutiva;
  final String nJustificanteAnterior;
  final List<Perceptor190> perceptores;
  final DateTime fechaCreacion;
  final DateTime? fechaPresentacion;

  const Modelo190({
    required this.id,
    required this.empresaId,
    required this.ejercicio,
    required this.plazoLimite,
    this.estado = EstadoModelo190.borrador,
    this.nTotalPercepciones = 0,
    this.importeTotalPercepciones = 0,
    this.totalRetenciones = 0,
    this.declaracionComplementaria = false,
    this.declaracionSustitutiva = false,
    this.nJustificanteAnterior = '',
    this.perceptores = const [],
    required this.fechaCreacion,
    this.fechaPresentacion,
  });

  /// Plazo límite: 31 de enero del año siguiente al ejercicio.
  static DateTime calcularPlazoLimite(int ejercicio) =>
      DateTime(ejercicio + 1, 1, 31);

  int get diasHastaVencimiento =>
      plazoLimite.difference(DateTime.now()).inDays;

  String get plazoTexto {
    final d = plazoLimite;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  factory Modelo190.fromMap(Map<String, dynamic> m) => Modelo190(
    id: m['id'] as String? ?? '',
    empresaId: m['empresa_id'] as String? ?? '',
    ejercicio: (m['ejercicio'] as num?)?.toInt() ?? 2025,
    plazoLimite: _parseDate(m['plazo_limite']),
    estado: EstadoModelo190.values.firstWhere(
      (e) => e.name == (m['estado'] as String?),
      orElse: () => EstadoModelo190.borrador,
    ),
    nTotalPercepciones: (m['n_total_percepciones'] as num?)?.toInt() ?? 0,
    importeTotalPercepciones: (m['importe_total_percepciones'] as num?)?.toDouble() ?? 0,
    totalRetenciones: (m['total_retenciones'] as num?)?.toDouble() ?? 0,
    declaracionComplementaria: m['declaracion_complementaria'] as bool? ?? false,
    declaracionSustitutiva: m['declaracion_sustitutiva'] as bool? ?? false,
    nJustificanteAnterior: m['n_justificante_anterior'] as String? ?? '',
    perceptores: (m['perceptores'] as List<dynamic>?)
        ?.map((p) => Perceptor190.fromMap(p as Map<String, dynamic>))
        .toList() ?? [],
    fechaCreacion: _parseDate(m['fecha_creacion']),
    fechaPresentacion: m['fecha_presentacion'] != null
        ? _parseDate(m['fecha_presentacion']) : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'ejercicio': ejercicio,
    'plazo_limite': Timestamp.fromDate(plazoLimite),
    'estado': estado.name,
    'n_total_percepciones': nTotalPercepciones,
    'importe_total_percepciones': importeTotalPercepciones,
    'total_retenciones': totalRetenciones,
    'declaracion_complementaria': declaracionComplementaria,
    'declaracion_sustitutiva': declaracionSustitutiva,
    'n_justificante_anterior': nJustificanteAnterior,
    'perceptores': perceptores.map((p) => p.toMap()).toList(),
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    if (fechaPresentacion != null)
      'fecha_presentacion': Timestamp.fromDate(fechaPresentacion!),
  };

  Modelo190 copyWith({
    EstadoModelo190? estado,
    List<Perceptor190>? perceptores,
    int? nTotalPercepciones,
    double? importeTotalPercepciones,
    double? totalRetenciones,
    DateTime? fechaPresentacion,
    bool? declaracionComplementaria,
    bool? declaracionSustitutiva,
    String? nJustificanteAnterior,
  }) => Modelo190(
    id: id,
    empresaId: empresaId,
    ejercicio: ejercicio,
    plazoLimite: plazoLimite,
    estado: estado ?? this.estado,
    nTotalPercepciones: nTotalPercepciones ?? this.nTotalPercepciones,
    importeTotalPercepciones: importeTotalPercepciones ?? this.importeTotalPercepciones,
    totalRetenciones: totalRetenciones ?? this.totalRetenciones,
    declaracionComplementaria: declaracionComplementaria ?? this.declaracionComplementaria,
    declaracionSustitutiva: declaracionSustitutiva ?? this.declaracionSustitutiva,
    nJustificanteAnterior: nJustificanteAnterior ?? this.nJustificanteAnterior,
    perceptores: perceptores ?? this.perceptores,
    fechaCreacion: fechaCreacion,
    fechaPresentacion: fechaPresentacion ?? this.fechaPresentacion,
  );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

