import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FINIQUITO Y LIQUIDACIÓN — ET arts. 49-53
// ═══════════════════════════════════════════════════════════════════════════════

/// Causa de baja del empleado.
enum CausaBaja {
  dimision,
  despidoImprocedente,
  despidoProcedente,
  finContrato,
  mutuoAcuerdo,
  ere,
  jubilacion,
}

extension CausaBajaExt on CausaBaja {
  String get etiqueta {
    switch (this) {
      case CausaBaja.dimision:            return 'Dimisión voluntaria';
      case CausaBaja.despidoImprocedente: return 'Despido improcedente';
      case CausaBaja.despidoProcedente:   return 'Despido procedente (obj.)';
      case CausaBaja.finContrato:         return 'Fin de contrato temporal';
      case CausaBaja.mutuoAcuerdo:        return 'Mutuo acuerdo';
      case CausaBaja.ere:                 return 'ERE / Fuerza mayor';
      case CausaBaja.jubilacion:          return 'Jubilación';
    }
  }

  String get descripcionLegal {
    switch (this) {
      case CausaBaja.dimision:
        return 'Art. 49.1.d) ET — Dimisión del trabajador';
      case CausaBaja.despidoImprocedente:
        return 'Art. 56 ET — Despido declarado improcedente';
      case CausaBaja.despidoProcedente:
        return 'Art. 52-53 ET — Despido por causas objetivas';
      case CausaBaja.finContrato:
        return 'Art. 49.1.c) ET — Expiración del tiempo convenido';
      case CausaBaja.mutuoAcuerdo:
        return 'Art. 49.1.a) ET — Mutuo acuerdo de las partes';
      case CausaBaja.ere:
        return 'Art. 51 ET — Despido colectivo / fuerza mayor';
      case CausaBaja.jubilacion:
        return 'Art. 49.1.f) ET — Jubilación del trabajador';
    }
  }

  /// ¿Tiene derecho a indemnización?
  bool get tieneIndemnizacion {
    switch (this) {
      case CausaBaja.despidoImprocedente:
      case CausaBaja.despidoProcedente:
      case CausaBaja.finContrato:
      case CausaBaja.ere:
        return true;
      case CausaBaja.dimision:
      case CausaBaja.mutuoAcuerdo:
      case CausaBaja.jubilacion:
        return false;
    }
  }

  /// Días de salario por año trabajado para indemnización.
  double get diasPorAnio {
    switch (this) {
      case CausaBaja.despidoImprocedente: return 33;
      case CausaBaja.despidoProcedente:   return 20;
      case CausaBaja.finContrato:         return 12;
      case CausaBaja.ere:                 return 20;
      default:                            return 0;
    }
  }

  /// Máximo de mensualidades para indemnización (0 = sin tope).
  double get maxMensualidades {
    switch (this) {
      case CausaBaja.despidoImprocedente: return 24;
      case CausaBaja.despidoProcedente:   return 12;
      case CausaBaja.ere:                 return 12;
      default:                            return 0;
    }
  }

  /// ¿La indemnización está exenta de IRPF? (art. 7.e LIRPF)
  bool get indemnizacionExentaIrpf {
    switch (this) {
      case CausaBaja.despidoImprocedente: return true;
      default:                            return false;
    }
  }
}

/// Estado del finiquito.
enum EstadoFiniquito { borrador, firmado, pagado }

extension EstadoFiniquitoExt on EstadoFiniquito {
  String get etiqueta {
    switch (this) {
      case EstadoFiniquito.borrador: return 'Borrador';
      case EstadoFiniquito.firmado:  return 'Firmado';
      case EstadoFiniquito.pagado:   return 'Pagado';
    }
  }
}

/// Detalle de una paga extra prorrateada en el finiquito.
class ProrataPagaExtra {
  final String nombre;       // "Paga extra julio", "Paga extra navidad", etc.
  final int diasDevengados;
  final double importe;

  const ProrataPagaExtra({
    required this.nombre,
    required this.diasDevengados,
    required this.importe,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'dias_devengados': diasDevengados,
    'importe': importe,
  };

  factory ProrataPagaExtra.fromMap(Map<String, dynamic> m) => ProrataPagaExtra(
    nombre: m['nombre'] as String? ?? '',
    diasDevengados: (m['dias_devengados'] as num?)?.toInt() ?? 0,
    importe: (m['importe'] as num?)?.toDouble() ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO FINIQUITO
// ═══════════════════════════════════════════════════════════════════════════════

class Finiquito {
  final String id;
  final String empresaId;
  final String empleadoId;
  final String empleadoNombre;
  final String? empleadoNif;
  final String? empleadoNss;

  // ── Datos de la empresa ──────────────────────────────────────────────────
  final String? empresaNombre;
  final String? empresaCif;

  // ── Inputs ──────────────────────────────────────────────────────────────
  final DateTime fechaBaja;
  final CausaBaja causaBaja;
  final DateTime fechaInicioContrato;
  final DateTime? fechaInicioContratoAnterior; // Para cálculo dual pre/post 12/02/2012

  final double salarioBrutoAnual;
  final int numPagas;
  final bool pagasProrrateadas;
  final double complementoFijoMensual;
  final String? convenioId;

  final int diasTrabajadosMes;
  final int diasMesBaja;
  final int diasVacacionesDisfrutadas;
  final int diasVacacionesConvenio;   // 30 por defecto, o lo que diga el convenio

  // ── Conceptos calculados ─────────────────────────────────────────────────
  final double salarioPendiente;
  final double importeVacaciones;
  final int diasVacacionesPendientes;
  final List<ProrataPagaExtra> prorrataPagasExtra;
  final double totalProrrataPagas;

  // ── Indemnización ──────────────────────────────────────────────────────
  final double indemnizacion;
  final double indemnizacionExenta;
  final double indemnizacionSujeta;
  final double diasIndemnizacion;      // Días totales de indemnización calculados
  final double? indemnizacionTramoAnterior; // Pre 12/02/2012 (45 días/año)
  final double? indemnizacionTramoPosterior; // Post 12/02/2012 (33 días/año)

  // ── Retenciones ──────────────────────────────────────────────────────────
  final double porcentajeIrpf;
  final double baseIrpf;              // Todo sujeto a retención
  final double importeIrpf;
  final double baseSS;
  final double cuotaObreraSSFiniquito;

  // ── Totales ──────────────────────────────────────────────────────────────
  double get totalBruto =>
      salarioPendiente + importeVacaciones + totalProrrataPagas + indemnizacion;

  double get totalRetenciones => importeIrpf + cuotaObreraSSFiniquito;
  double get liquidoPercibir => totalBruto - totalRetenciones;

  // ── Metadatos ────────────────────────────────────────────────────────────
  final EstadoFiniquito estado;
  final DateTime fechaCreacion;
  final DateTime? fechaPago;
  final String? notas;

  // ── Firma y documentos ─────────────────────────────────────────────────────
  final String? firmaUrl;
  final DateTime? fechaFirma;
  final String? firmaUid;
  final String? firmaGeolocalizacion;
  final bool firmado;
  final String? cartaCeseUrl;
  final String? certificadoSEPEUrl;
  final String? pdfFirmadoUrl;
  final String? emailEnviado;
  final DateTime? fechaEnvioEmail;
  final List<String> documentosEnviados;
  final bool bajaAplicada;
  final String? cargoEmpleado;
  final String? naf;

  // ── Datos auxiliares para antigüedad ──────────────────────────────────────
  double get aniosAntiguedad {
    final diff = fechaBaja.difference(fechaInicioContrato);
    return diff.inDays / 365.25;
  }

  String get antiguedadTexto {
    final anios = aniosAntiguedad;
    final a = anios.floor();
    final meses = ((anios - a) * 12).round();
    if (a == 0) return '$meses meses';
    if (meses == 0) return '$a años';
    return '$a años y $meses meses';
  }

  const Finiquito({
    required this.id,
    required this.empresaId,
    required this.empleadoId,
    required this.empleadoNombre,
    this.empleadoNif,
    this.empleadoNss,
    this.empresaNombre,
    this.empresaCif,
    required this.fechaBaja,
    required this.causaBaja,
    required this.fechaInicioContrato,
    this.fechaInicioContratoAnterior,
    required this.salarioBrutoAnual,
    this.numPagas = 14,
    this.pagasProrrateadas = false,
    this.complementoFijoMensual = 0,
    this.convenioId,
    required this.diasTrabajadosMes,
    required this.diasMesBaja,
    required this.diasVacacionesDisfrutadas,
    this.diasVacacionesConvenio = 30,
    required this.salarioPendiente,
    required this.importeVacaciones,
    required this.diasVacacionesPendientes,
    this.prorrataPagasExtra = const [],
    required this.totalProrrataPagas,
    required this.indemnizacion,
    this.indemnizacionExenta = 0,
    this.indemnizacionSujeta = 0,
    this.diasIndemnizacion = 0,
    this.indemnizacionTramoAnterior,
    this.indemnizacionTramoPosterior,
    required this.porcentajeIrpf,
    required this.baseIrpf,
    required this.importeIrpf,
    required this.baseSS,
    required this.cuotaObreraSSFiniquito,
    this.estado = EstadoFiniquito.borrador,
    required this.fechaCreacion,
    this.fechaPago,
    this.notas,
    this.firmaUrl,
    this.fechaFirma,
    this.firmaUid,
    this.firmaGeolocalizacion,
    this.firmado = false,
    this.cartaCeseUrl,
    this.certificadoSEPEUrl,
    this.pdfFirmadoUrl,
    this.emailEnviado,
    this.fechaEnvioEmail,
    this.documentosEnviados = const [],
    this.bajaAplicada = false,
    this.cargoEmpleado,
    this.naf,
  });

  // ── Serialización Firestore ──────────────────────────────────────────────

  factory Finiquito.fromMap(Map<String, dynamic> m) => Finiquito(
    id: m['id'] as String? ?? '',
    empresaId: m['empresa_id'] as String? ?? '',
    empleadoId: m['empleado_id'] as String? ?? '',
    empleadoNombre: m['empleado_nombre'] as String? ?? '',
    empleadoNif: m['empleado_nif'] as String?,
    empleadoNss: m['empleado_nss'] as String?,
    empresaNombre: m['empresa_nombre'] as String?,
    empresaCif: m['empresa_cif'] as String?,
    fechaBaja: _parseDate(m['fecha_baja']),
    causaBaja: CausaBaja.values.firstWhere(
      (e) => e.name == (m['causa_baja'] as String?),
      orElse: () => CausaBaja.dimision,
    ),
    fechaInicioContrato: _parseDate(m['fecha_inicio_contrato']),
    fechaInicioContratoAnterior: m['fecha_inicio_contrato_anterior'] != null
        ? _parseDate(m['fecha_inicio_contrato_anterior']) : null,
    salarioBrutoAnual: (m['salario_bruto_anual'] as num?)?.toDouble() ?? 0,
    numPagas: (m['num_pagas'] as num?)?.toInt() ?? 14,
    pagasProrrateadas: m['pagas_prorrateadas'] as bool? ?? false,
    complementoFijoMensual: (m['complemento_fijo_mensual'] as num?)?.toDouble() ?? 0,
    convenioId: m['convenio_id'] as String?,
    diasTrabajadosMes: (m['dias_trabajados_mes'] as num?)?.toInt() ?? 0,
    diasMesBaja: (m['dias_mes_baja'] as num?)?.toInt() ?? 30,
    diasVacacionesDisfrutadas: (m['dias_vacaciones_disfrutadas'] as num?)?.toInt() ?? 0,
    diasVacacionesConvenio: (m['dias_vacaciones_convenio'] as num?)?.toInt() ?? 30,
    salarioPendiente: (m['salario_pendiente'] as num?)?.toDouble() ?? 0,
    importeVacaciones: (m['importe_vacaciones'] as num?)?.toDouble() ?? 0,
    diasVacacionesPendientes: (m['dias_vacaciones_pendientes'] as num?)?.toInt() ?? 0,
    prorrataPagasExtra: (m['prorrata_pagas_extra'] as List<dynamic>?)
        ?.map((e) => ProrataPagaExtra.fromMap(e as Map<String, dynamic>))
        .toList() ?? [],
    totalProrrataPagas: (m['total_prorrata_pagas'] as num?)?.toDouble() ?? 0,
    indemnizacion: (m['indemnizacion'] as num?)?.toDouble() ?? 0,
    indemnizacionExenta: (m['indemnizacion_exenta'] as num?)?.toDouble() ?? 0,
    indemnizacionSujeta: (m['indemnizacion_sujeta'] as num?)?.toDouble() ?? 0,
    diasIndemnizacion: (m['dias_indemnizacion'] as num?)?.toDouble() ?? 0,
    indemnizacionTramoAnterior: (m['indemnizacion_tramo_anterior'] as num?)?.toDouble(),
    indemnizacionTramoPosterior: (m['indemnizacion_tramo_posterior'] as num?)?.toDouble(),
    porcentajeIrpf: (m['porcentaje_irpf'] as num?)?.toDouble() ?? 0,
    baseIrpf: (m['base_irpf'] as num?)?.toDouble() ?? 0,
    importeIrpf: (m['importe_irpf'] as num?)?.toDouble() ?? 0,
    baseSS: (m['base_ss'] as num?)?.toDouble() ?? 0,
    cuotaObreraSSFiniquito: (m['cuota_obrera_ss_finiquito'] as num?)?.toDouble() ?? 0,
    estado: EstadoFiniquito.values.firstWhere(
      (e) => e.name == (m['estado'] as String?),
      orElse: () => EstadoFiniquito.borrador,
    ),
    fechaCreacion: _parseDate(m['fecha_creacion']),
    fechaPago: m['fecha_pago'] != null ? _parseDate(m['fecha_pago']) : null,
    notas: m['notas'] as String?,
    firmaUrl: m['firma_url'] as String?,
    fechaFirma: m['fecha_firma'] != null ? _parseDate(m['fecha_firma']) : null,
    firmaUid: m['firma_uid'] as String?,
    firmaGeolocalizacion: m['firma_geo'] as String?,
    firmado: m['firmado'] as bool? ?? false,
    cartaCeseUrl: m['carta_cese_url'] as String?,
    certificadoSEPEUrl: m['certificado_sepe_url'] as String?,
    pdfFirmadoUrl: m['pdf_firmado_url'] as String?,
    emailEnviado: m['email_enviado'] as String?,
    fechaEnvioEmail: m['fecha_envio_email'] != null
        ? _parseDate(m['fecha_envio_email']) : null,
    documentosEnviados: (m['documentos_enviados'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? [],
    bajaAplicada: m['baja_aplicada'] as bool? ?? false,
    cargoEmpleado: m['cargo_empleado'] as String?,
    naf: m['naf'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'empleado_id': empleadoId,
    'empleado_nombre': empleadoNombre,
    if (empleadoNif != null) 'empleado_nif': empleadoNif,
    if (empleadoNss != null) 'empleado_nss': empleadoNss,
    if (empresaNombre != null) 'empresa_nombre': empresaNombre,
    if (empresaCif != null) 'empresa_cif': empresaCif,
    'fecha_baja': Timestamp.fromDate(fechaBaja),
    'causa_baja': causaBaja.name,
    'fecha_inicio_contrato': Timestamp.fromDate(fechaInicioContrato),
    if (fechaInicioContratoAnterior != null)
      'fecha_inicio_contrato_anterior': Timestamp.fromDate(fechaInicioContratoAnterior!),
    'salario_bruto_anual': salarioBrutoAnual,
    'num_pagas': numPagas,
    'pagas_prorrateadas': pagasProrrateadas,
    'complemento_fijo_mensual': complementoFijoMensual,
    if (convenioId != null) 'convenio_id': convenioId,
    'dias_trabajados_mes': diasTrabajadosMes,
    'dias_mes_baja': diasMesBaja,
    'dias_vacaciones_disfrutadas': diasVacacionesDisfrutadas,
    'dias_vacaciones_convenio': diasVacacionesConvenio,
    'salario_pendiente': salarioPendiente,
    'importe_vacaciones': importeVacaciones,
    'dias_vacaciones_pendientes': diasVacacionesPendientes,
    'prorrata_pagas_extra': prorrataPagasExtra.map((p) => p.toMap()).toList(),
    'total_prorrata_pagas': totalProrrataPagas,
    'indemnizacion': indemnizacion,
    'indemnizacion_exenta': indemnizacionExenta,
    'indemnizacion_sujeta': indemnizacionSujeta,
    'dias_indemnizacion': diasIndemnizacion,
    if (indemnizacionTramoAnterior != null) 'indemnizacion_tramo_anterior': indemnizacionTramoAnterior,
    if (indemnizacionTramoPosterior != null) 'indemnizacion_tramo_posterior': indemnizacionTramoPosterior,
    'porcentaje_irpf': porcentajeIrpf,
    'base_irpf': baseIrpf,
    'importe_irpf': importeIrpf,
    'base_ss': baseSS,
    'cuota_obrera_ss_finiquito': cuotaObreraSSFiniquito,
    'total_bruto': totalBruto,
    'total_retenciones': totalRetenciones,
    'liquido_percibir': liquidoPercibir,
    'estado': estado.name,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    if (fechaPago != null) 'fecha_pago': Timestamp.fromDate(fechaPago!),
    if (notas != null) 'notas': notas,
    if (firmaUrl != null) 'firma_url': firmaUrl,
    if (fechaFirma != null) 'fecha_firma': Timestamp.fromDate(fechaFirma!),
    if (firmaUid != null) 'firma_uid': firmaUid,
    if (firmaGeolocalizacion != null) 'firma_geo': firmaGeolocalizacion,
    'firmado': firmado,
    if (cartaCeseUrl != null) 'carta_cese_url': cartaCeseUrl,
    if (certificadoSEPEUrl != null) 'certificado_sepe_url': certificadoSEPEUrl,
    if (pdfFirmadoUrl != null) 'pdf_firmado_url': pdfFirmadoUrl,
    if (emailEnviado != null) 'email_enviado': emailEnviado,
    if (fechaEnvioEmail != null) 'fecha_envio_email': Timestamp.fromDate(fechaEnvioEmail!),
    'documentos_enviados': documentosEnviados,
    'baja_aplicada': bajaAplicada,
    if (cargoEmpleado != null) 'cargo_empleado': cargoEmpleado,
    if (naf != null) 'naf': naf,
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

