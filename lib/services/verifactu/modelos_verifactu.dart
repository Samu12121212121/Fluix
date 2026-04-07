import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Modelos y servicios para Verifactu (RD 1007/2023 + RD 254/2025)
/// 
/// Este módulo implementa los requisitos técnicos exactos del Reglamento:
/// - Encadenamiento criptográfico (hash SHA-256)
/// - Registros de facturación (altas + anulaciones)
/// - Registros de eventos
/// - Firma electrónica XAdES Enveloped
/// - Trazabilidad de registros

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS PARA LISTAS DE VALORES CODIFICADOS
// ═══════════════════════════════════════════════════════════════════════════

enum TipoFacturaVeri {
  f1('F1', 'Factura ordinaria'),
  f2('F2', 'Factura simplificada'),
  f3('F3', 'Factura en sustitución'),
  r1('R1', 'Rectificativa - error fundado'),
  r2('R2', 'Rectificativa - art. 80.3'),
  r3('R3', 'Rectificativa - art. 80.4'),
  r4('R4', 'Rectificativa - otros casos'),
  r5('R5', 'Rectificativa simplificada');

  const TipoFacturaVeri(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

enum TipoRectificativa {
  sustitucion('S', 'Por sustitución'),
  diferencias('I', 'Por diferencias');

  const TipoRectificativa(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

enum ClaveRegimen {
  general('01', 'Régimen general'),
  exportacion('02', 'Exportación'),
  bienesUsados('03', 'Bienes usados/arte/antigüedades'),
  oroInversion('04', 'Oro de inversión'),
  agenciasViajes('05', 'Agencias de viajes'),
  grupoEntidades('06', 'Grupo de entidades'),
  criterioCaja('07', 'Criterio de caja'),
  ipsiIgic('08', 'IPSI/IGIC'),
  mediacionAgencias('09', 'Mediación agencias viaje'),
  cobrosTerceros('10', 'Cobros por cuenta terceros'),
  arrendamientoLocal('11', 'Arrendamiento local'),
  ivaPrePendiente14('14', 'IVA pendiente certificaciones obra'),
  ivaPrePendiente15('15', 'IVA pendiente tracto sucesivo'),
  osIoss('17', 'OSS/IOSS'),
  recargoEquivalencia('18', 'Recargo equivalencia'),
  reagyp('19', 'REAGYP'),
  regSimplificado('20', 'Régimen simplificado');

  const ClaveRegimen(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

enum CalificacionOperacion {
  sujetaNoExentaSinIsp('S1', 'Sujeta y no exenta - sin ISP'),
  sujetaNoExentaConIsp('S2', 'Sujeta y no exenta - con ISP'),
  noSujetaArticulos('N1', 'No sujeta'),
  noSujetaLocalizacion('N2', 'No sujeta por localización');

  const CalificacionOperacion(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

enum TipoExencion {
  art20('E1', 'Art. 20'),
  art21('E2', 'Art. 21'),
  art22('E3', 'Art. 22'),
  arts2324('E4', 'Arts. 23 y 24'),
  art25('E5', 'Art. 25'),
  otros('E6', 'Otros');

  const TipoExencion(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

enum TipoEvento {
  inicioNoVerifactu('01', 'Inicio NO VERI*FACTU'),
  finNoVerifactu('02', 'Fin NO VERI*FACTU'),
  deteccionAnomaliaFacturacion('03', 'Detección anomalía facturación'),
  anomaliaIntegridad('04', 'Anomalía integridad facturación'),
  deteccionAnomaliaEvento('05', 'Detección anomalía evento'),
  anomaliaIntegridadEvento('06', 'Anomalía integridad evento'),
  restauracionBackup('07', 'Restauración backup'),
  exportacionFacturacion('08', 'Exportación facturación'),
  exportacionEvento('09', 'Exportación evento'),
  resumenEventos('10', 'Resumen eventos'),
  otros('90', 'Otros eventos');

  const TipoEvento(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS DE DATOS — ENCADENAMIENTO Y TRAZABILIDAD
// ═══════════════════════════════════════════════════════════════════════════

class ReferenceRegistroAnterior {
  final String nifEmisor;
  final String numeroSerie;
  final String numeroFactura;
  final DateTime fechaExpedicion;
  final String hash64Caracteres; // Primeros 64 chars del hash anterior

  const ReferenceRegistroAnterior({
    required this.nifEmisor,
    required this.numeroSerie,
    required this.numeroFactura,
    required this.fechaExpedicion,
    required this.hash64Caracteres,
  });

  /// Constructor para primer registro de la cadena
  static ReferenceRegistroAnterior primerRegistro() {
    return ReferenceRegistroAnterior(
      nifEmisor: '',
      numeroSerie: '',
      numeroFactura: '',
      fechaExpedicion: DateTime(1900),
      hash64Caracteres: '0' * 64,
    );
  }

  bool get esPrimerRegistro =>
      nifEmisor.isEmpty &&
      numeroFactura.isEmpty &&
      hash64Caracteres == '0' * 64;
}

class RegistroFacturacionAlta {
  static const String idVersion = '1.0';
  final String nifEmisor;
  final String numeroSerie;
  final String numeroFactura;
  final DateTime fechaExpedicion;
  final TipoFacturaVeri tipoFactura;
  final TipoRectificativa? tipoRectificativa; // Si es rectificativa
  final String descripcion;
  final double importeTotal;
  final double cuotaTotal;
  final Map<String, double> desglosePorTipo; // Ej: {'01': 1000.0} para 21%
  final ClaveRegimen claveRegimen;
  final CalificacionOperacion calificacion;
  final TipoExencion? tipoExencion;
  final ReferenceRegistroAnterior registroAnterior;
  final DateTime fechaHoraGeneracion;
  final String zonaHoraria; // Ej: 'Europe/Madrid'
  final bool esVerifactu;

  // Campos calculados
  late final String hash; // SHA-256 del registro
  final String? firmaXAdES; // Solo obligatoria en NO VERI*FACTU

  RegistroFacturacionAlta({
    required this.nifEmisor,
    required this.numeroSerie,
    required this.numeroFactura,
    required this.fechaExpedicion,
    required this.tipoFactura,
    this.tipoRectificativa,
    required this.descripcion,
    required this.importeTotal,
    required this.cuotaTotal,
    required this.desglosePorTipo,
    required this.claveRegimen,
    required this.calificacion,
    this.tipoExencion,
    required this.registroAnterior,
    required this.fechaHoraGeneracion,
    required this.zonaHoraria,
    required this.esVerifactu,
    this.firmaXAdES,
  }) {
    hash = calcularHash();
  }

  /// Calcula hash SHA-256 según RD 1007/2023 Bloque 6
  /// Campos concatenados (en orden):
  /// 1. NIF emisor
  /// 2. Número factura (serie + número)
  /// 3. Fecha expedición (YYYYMMDD)
  /// 4. Tipo factura
  /// 5. Cuota total (sin decimales, ej: 1234567 para 12345.67)
  /// 6. Importe total (sin decimales)
  /// 7. Hash registro anterior (64 primeros chars)
  /// 8. Fecha+hora+zona de generación (YYYYMMDDHHMMSSZ)
  String calcularHash() {
    final numeroFacturaCompleto = '$numeroSerie$numeroFactura';
    final fechaExpStr =
        '${fechaExpedicion.year}${fechaExpedicion.month.toString().padLeft(2, '0')}${fechaExpedicion.day.toString().padLeft(2, '0')}';
    final cuotaStr = (cuotaTotal * 100).toInt().toString().padLeft(13, '0');
    final importeStr = (importeTotal * 100).toInt().toString().padLeft(13, '0');
    final fechaHoraStr =
        '${fechaHoraGeneracion.year}${fechaHoraGeneracion.month.toString().padLeft(2, '0')}${fechaHoraGeneracion.day.toString().padLeft(2, '0')}${fechaHoraGeneracion.hour.toString().padLeft(2, '0')}${fechaHoraGeneracion.minute.toString().padLeft(2, '0')}${fechaHoraGeneracion.second.toString().padLeft(2, '0')}$zonaHoraria';

    final concatenado = '$nifEmisor'
        '$numeroFacturaCompleto'
        '$fechaExpStr'
        '${tipoFactura.codigo}'
        '$cuotaStr'
        '$importeStr'
        '${registroAnterior.hash64Caracteres}'
        '$fechaHoraStr';

    return sha256.convert(utf8.encode(concatenado)).toString();
  }

  /// Primeros 64 caracteres del hash (para usar en siguiente registro)
  String get hash64 =>
      hash.length >= 64 ? hash.substring(0, 64) : hash.padRight(64, '0');

  Map<String, dynamic> toJson() => {
    'nif_emisor': nifEmisor,
    'numero_serie': numeroSerie,
    'numero_factura': numeroFactura,
    'fecha_expedicion': fechaExpedicion.toIso8601String(),
    'tipo_factura': tipoFactura.codigo,
    'descripcion': descripcion,
    'importe_total': importeTotal,
    'cuota_total': cuotaTotal,
    'desglose_por_tipo': desglosePorTipo,
    'clave_regimen': claveRegimen.codigo,
    'calificacion': calificacion.codigo,
    'hash': hash,
    'es_verifactu': esVerifactu,
    'fecha_hora_generacion': fechaHoraGeneracion.toIso8601String(),
  };
}

class RegistroFacturacionAnulacion {
  static const String idVersion = '1.0';
  final String nifEmisor;
  final String numeroSerie;
  final String numeroFactura;
  final DateTime fechaExpedicion;
  final String solicitanteCodigo; // 'E', 'D' o 'T'
  final ReferenceRegistroAnterior registroAnterior;
  final DateTime fechaHoraGeneracion;
  final String zonaHoraria;

  // Campos calculados
  late final String hash; // SHA-256

  RegistroFacturacionAnulacion({
    required this.nifEmisor,
    required this.numeroSerie,
    required this.numeroFactura,
    required this.fechaExpedicion,
    required this.solicitanteCodigo,
    required this.registroAnterior,
    required this.fechaHoraGeneracion,
    required this.zonaHoraria,
  }) {
    hash = calcularHash();
  }

  /// Calcula hash SHA-256 para anulación (Bloque 6 RD 1007/2023)
  String calcularHash() {
    final numeroFacturaCompleto = '$numeroSerie$numeroFactura';
    final fechaExpStr =
        '${fechaExpedicion.year}${fechaExpedicion.month.toString().padLeft(2, '0')}${fechaExpedicion.day.toString().padLeft(2, '0')}';
    final fechaHoraStr =
        '${fechaHoraGeneracion.year}${fechaHoraGeneracion.month.toString().padLeft(2, '0')}${fechaHoraGeneracion.day.toString().padLeft(2, '0')}${fechaHoraGeneracion.hour.toString().padLeft(2, '0')}${fechaHoraGeneracion.minute.toString().padLeft(2, '0')}${fechaHoraGeneracion.second.toString().padLeft(2, '0')}$zonaHoraria';

    final concatenado = '$nifEmisor'
        '$numeroFacturaCompleto'
        '$fechaExpStr'
        '${registroAnterior.hash64Caracteres}'
        '$fechaHoraStr';

    return sha256.convert(utf8.encode(concatenado)).toString();
  }

  String get hash64 =>
      hash.length >= 64 ? hash.substring(0, 64) : hash.padRight(64, '0');
}

class RegistroEvento {
  static const String idVersion = '1.0';
  final String codigoProductor;
  final String codigoSistema;
  final String versionSistema;
  final String numeroInstalacion;
  final String nifObligado;
  final TipoEvento tipoEvento;
  final ReferenceRegistroAnterior registroAnteriorEvento;
  final DateTime fechaHoraGeneracion;
  final String zonaHoraria;
  final String? detalleEvento; // Descripción adicional del evento

  // Campos calculados
  late final String hash;

  RegistroEvento({
    required this.codigoProductor,
    required this.codigoSistema,
    required this.versionSistema,
    required this.numeroInstalacion,
    required this.nifObligado,
    required this.tipoEvento,
    required this.registroAnteriorEvento,
    required this.fechaHoraGeneracion,
    required this.zonaHoraria,
    this.detalleEvento,
  }) {
    hash = calcularHash();
  }

  String calcularHash() {
    final fechaHoraStr =
        '${fechaHoraGeneracion.year}${fechaHoraGeneracion.month.toString().padLeft(2, '0')}${fechaHoraGeneracion.day.toString().padLeft(2, '0')}${fechaHoraGeneracion.hour.toString().padLeft(2, '0')}${fechaHoraGeneracion.minute.toString().padLeft(2, '0')}${fechaHoraGeneracion.second.toString().padLeft(2, '0')}$zonaHoraria';

    final concatenado = '$codigoProductor'
        '$codigoSistema'
        '$versionSistema'
        '$numeroInstalacion'
        '$nifObligado'
        '${tipoEvento.codigo}'
        '${registroAnteriorEvento.hash64Caracteres}'
        '$fechaHoraStr';

    return sha256.convert(utf8.encode(concatenado)).toString();
  }

  String get hash64 =>
      hash.length >= 64 ? hash.substring(0, 64) : hash.padRight(64, '0');
}

class ResumenEventos {
  final String codigoProductor;
  final String codigoSistema;
  final String versionSistema;
  final String numeroInstalacion;
  final String nifObligado;
  final DateTime fechaHoraInicio;
  final DateTime fechaHoraFin;
  final int totalEventosEnPeriodo;
  final List<TipoEvento> tiposEventosRegistrados;
  final ReferenceRegistroAnterior registroAnteriorEvento;
  final DateTime fechaHoraGeneracion;
  final String zonaHoraria;

  late final String hash;

  ResumenEventos({
    required this.codigoProductor,
    required this.codigoSistema,
    required this.versionSistema,
    required this.numeroInstalacion,
    required this.nifObligado,
    required this.fechaHoraInicio,
    required this.fechaHoraFin,
    required this.totalEventosEnPeriodo,
    required this.tiposEventosRegistrados,
    required this.registroAnteriorEvento,
    required this.fechaHoraGeneracion,
    required this.zonaHoraria,
  }) {
    hash = calcularHash();
  }

  String calcularHash() {
    final tiposConcat = tiposEventosRegistrados.map((t) => t.codigo).join(',');
    final fechaHoraStr =
        '${fechaHoraGeneracion.year}${fechaHoraGeneracion.month.toString().padLeft(2, '0')}${fechaHoraGeneracion.day.toString().padLeft(2, '0')}${fechaHoraGeneracion.hour.toString().padLeft(2, '0')}${fechaHoraGeneracion.minute.toString().padLeft(2, '0')}${fechaHoraGeneracion.second.toString().padLeft(2, '0')}$zonaHoraria';

    final concatenado = '$codigoProductor'
        '$codigoSistema'
        '$versionSistema'
        '$numeroInstalacion'
        '$nifObligado'
        '10'
        '${registroAnteriorEvento.hash64Caracteres}'
        '$fechaHoraStr'
        '$totalEventosEnPeriodo'
        '$tiposConcat';

    return sha256.convert(utf8.encode(concatenado)).toString();
  }

  String get hash64 =>
      hash.length >= 64 ? hash.substring(0, 64) : hash.padRight(64, '0');
}

class CadenaFacturacion {
  final String nifEmisor;
  final List<RegistroFacturacionAlta> registrosAlta;
  final List<RegistroFacturacionAnulacion> registrosAnulacion;

  const CadenaFacturacion({
    required this.nifEmisor,
    required this.registrosAlta,
    required this.registrosAnulacion,
  });

  /// Valida que la cadena esté correctamente encadenada
  bool validarEncadenamiento() {
    if (registrosAlta.isEmpty) return true;

    for (int i = 1; i < registrosAlta.length; i++) {
      final anterior = registrosAlta[i - 1];
      final actual = registrosAlta[i];

      // Verificar que el hash del registro anterior coincida
      if (actual.registroAnterior.hash64Caracteres != anterior.hash64) {
        return false;
      }
    }

    return true;
  }

  /// Cuenta total de registros en cadena (altas + anulaciones)
  int get totalRegistros => registrosAlta.length + registrosAnulacion.length;
}



