import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/factura.dart';
import 'verifactu/xml_payload_verifactu_builder.dart';

enum EstadoVerifactu { pendiente, enviada, aceptada, rechazada, error }

/// Datos Verifactu asociados a una factura.
///
/// Se almacenan en Firestore como subdocumento `verifactu` dentro de la factura.
/// Referencia: Real Decreto 1007/2023 (sistema Verifactu).
class DatosVerifactu {
  /// Hash SHA-256 del registro de facturación (cadena encadenada).
  final String hashRegistro;

  /// Hash de la factura anterior en la cadena (vacío si es la primera).
  final String hashAnterior;

  /// Fecha y hora del registro en formato ISO 8601.
  final String fechaHoraRegistro;

  /// Identificador único del software de facturación.
  final String idSoftware;

  /// Nombre del software.
  final String nombreSoftware;

  /// Versión del software.
  final String versionSoftware;

  /// NIF del fabricante del software.
  final String nifFabricante;

  /// Número de factura en el sistema Verifactu.
  final String idFactura;

  /// NIF del emisor.
  final String nifEmisor;

  /// Fecha de expedición (formato YYYY-MM-DD).
  final String fechaExpedicion;

  /// Tipo de factura (F1: completa, F2: simplificada, R1-R5: rectificativas).
  final String tipoFactura;

  /// Clave de régimen fiscal (01: general, 02: exportación, etc.).
  final String claveRegimen;

  /// Estado del envío a la AEAT.
  final EstadoVerifactu estado;

  /// Código de respuesta de la AEAT (si se ha enviado).
  final String? codigoRespuesta;

  /// Mensaje de respuesta de la AEAT.
  final String? mensajeRespuesta;

  /// Fecha del último envío/intento.
  final DateTime? fechaEnvio;

  /// URL de verificación para el QR (cuando la AEAT la proporcione).
  final String? urlVerificacion;

  const DatosVerifactu({
    required this.hashRegistro,
    required this.hashAnterior,
    required this.fechaHoraRegistro,
    required this.idSoftware,
    required this.nombreSoftware,
    required this.versionSoftware,
    required this.nifFabricante,
    required this.idFactura,
    required this.nifEmisor,
    required this.fechaExpedicion,
    required this.tipoFactura,
    required this.claveRegimen,
    this.estado = EstadoVerifactu.pendiente,
    this.codigoRespuesta,
    this.mensajeRespuesta,
    this.fechaEnvio,
    this.urlVerificacion,
  });

  factory DatosVerifactu.fromMap(Map<String, dynamic> d) => DatosVerifactu(
        hashRegistro: d['hash_registro'] ?? '',
        hashAnterior: d['hash_anterior'] ?? '',
        fechaHoraRegistro: d['fecha_hora_registro'] ?? '',
        idSoftware: d['id_software'] ?? '',
        nombreSoftware: d['nombre_software'] ?? '',
        versionSoftware: d['version_software'] ?? '',
        nifFabricante: d['nif_fabricante'] ?? '',
        idFactura: d['id_factura'] ?? '',
        nifEmisor: d['nif_emisor'] ?? '',
        fechaExpedicion: d['fecha_expedicion'] ?? '',
        tipoFactura: d['tipo_factura'] ?? 'F1',
        claveRegimen: d['clave_regimen'] ?? '01',
        estado: EstadoVerifactu.values.firstWhere(
          (e) => e.name == d['estado'],
          orElse: () => EstadoVerifactu.pendiente,
        ),
        codigoRespuesta: d['codigo_respuesta'],
        mensajeRespuesta: d['mensaje_respuesta'],
        fechaEnvio: d['fecha_envio'] != null
            ? (d['fecha_envio'] is Timestamp
                ? (d['fecha_envio'] as Timestamp).toDate()
                : DateTime.tryParse(d['fecha_envio']))
            : null,
        urlVerificacion: d['url_verificacion'],
      );

  Map<String, dynamic> toMap() => {
        'hash_registro': hashRegistro,
        'hash_anterior': hashAnterior,
        'fecha_hora_registro': fechaHoraRegistro,
        'id_software': idSoftware,
        'nombre_software': nombreSoftware,
        'version_software': versionSoftware,
        'nif_fabricante': nifFabricante,
        'id_factura': idFactura,
        'nif_emisor': nifEmisor,
        'fecha_expedicion': fechaExpedicion,
        'tipo_factura': tipoFactura,
        'clave_regimen': claveRegimen,
        'estado': estado.name,
        'codigo_respuesta': codigoRespuesta,
        'mensaje_respuesta': mensajeRespuesta,
        'fecha_envio': fechaEnvio?.toIso8601String(),
        'url_verificacion': urlVerificacion,
      };
}

/// Configuración de Verifactu para una empresa.
class ConfigVerifactu {
  final String nifEmisor;
  final String nombreEmisor;
  final String idSoftware;
  final String nombreSoftware;
  final String versionSoftware;
  final String nifFabricante;
  final bool habilitado;

  const ConfigVerifactu({
    required this.nifEmisor,
    required this.nombreEmisor,
    this.idSoftware = 'FLUIXCRM-001',
    this.nombreSoftware = 'Fluix CRM',
    this.versionSoftware = '1.0.0',
    this.nifFabricante = '',
    this.habilitado = false,
  });

  factory ConfigVerifactu.fromMap(Map<String, dynamic> d) => ConfigVerifactu(
        nifEmisor: d['nif_emisor'] ?? '',
        nombreEmisor: d['nombre_emisor'] ?? '',
        idSoftware: d['id_software'] ?? 'FLUIXCRM-001',
        nombreSoftware: d['nombre_software'] ?? 'Fluix CRM',
        versionSoftware: d['version_software'] ?? '1.0.0',
        nifFabricante: d['nif_fabricante'] ?? '',
        habilitado: d['habilitado'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'nif_emisor': nifEmisor,
        'nombre_emisor': nombreEmisor,
        'id_software': idSoftware,
        'nombre_software': nombreSoftware,
        'version_software': versionSoftware,
        'nif_fabricante': nifFabricante,
        'habilitado': habilitado,
      };
}

/// Servicio de facturación electrónica Verifactu (RD 1007/2023).
///
/// Implementa:
/// - Generación del hash encadenado SHA-256 (Art. 30)
/// - Registro de facturación con campos obligatorios (Art. 25-29)
/// - Almacenamiento en Firestore de los datos Verifactu
/// - Preparación del XML para envío a AEAT (la firma y envío SOAP
///   se delegan a una Cloud Function para seguridad del certificado)
class VerifactuService {
  static final _db = FirebaseFirestore.instance;

  final String empresaId;

  VerifactuService({required this.empresaId});

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene la configuración Verifactu de una empresa.
  static Future<ConfigVerifactu?> obtenerConfig(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('verifactu')
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return ConfigVerifactu.fromMap(doc.data()!);
  }

  /// Guarda la configuración Verifactu.
  static Future<void> guardarConfig(
      String empresaId, ConfigVerifactu config) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('verifactu')
        .set(config.toMap(), SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HASH ENCADENADO (Art. 30 RD 1007/2023)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera el hash SHA-256 del registro de facturación.
  static String generarHash({
    required String idFactura,
    required String nifEmisor,
    required String numeroFactura,
    required String fechaExpedicion,
    required String tipoFactura,
    required double cuotaTotal,
    required double importeTotal,
    required String hashAnterior,
    required String fechaHoraHuella,
  }) {
    final cadena = '$idFactura&$nifEmisor&$numeroFactura&$fechaExpedicion'
        '&$tipoFactura&${cuotaTotal.toStringAsFixed(2)}'
        '&${importeTotal.toStringAsFixed(2)}&$hashAnterior&$fechaHoraHuella';

    final bytes = utf8.encode(cadena);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Obtiene el hash de la última factura registrada en la cadena Verifactu.
  static Future<String> obtenerUltimoHash(String empresaId) async {
    final snapshot = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('verifactu.hash_registro', isNotEqualTo: '')
        .orderBy('verifactu.fecha_hora_registro', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return '';

    final verifactu = snapshot.docs.first.data()['verifactu'];
    return verifactu?['hash_registro'] ?? '';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRO DE FACTURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Registra una factura en el sistema Verifactu.
  static Future<DatosVerifactu> registrarFactura({
    required String empresaId,
    required Factura factura,
  }) async {
    final config = await obtenerConfig(empresaId);
    if (config == null || !config.habilitado) {
      throw Exception(
          'Verifactu no está configurado o habilitado para esta empresa');
    }

    // Determinar tipo de factura Verifactu
    String tipoFacturaVf;
    if (factura.esRectificativa) {
      tipoFacturaVf = 'R1';
    } else if (factura.esProforma) {
      throw Exception('Las facturas proforma no se registran en Verifactu');
    } else if (factura.total < 400 && factura.datosFiscales?.nif == null) {
      tipoFacturaVf = 'F2';
    } else {
      tipoFacturaVf = 'F1';
    }

    final hashAnterior = await obtenerUltimoHash(empresaId);

    final ahora = DateTime.now();
    final fechaHoraRegistro = ahora.toUtc().toIso8601String();
    final fechaExpedicion =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';

    final hash = generarHash(
      idFactura: factura.id,
      nifEmisor: config.nifEmisor,
      numeroFactura: factura.numeroFactura,
      fechaExpedicion: fechaExpedicion,
      tipoFactura: tipoFacturaVf,
      cuotaTotal: factura.totalIva,
      importeTotal: factura.total,
      hashAnterior: hashAnterior,
      fechaHoraHuella: fechaHoraRegistro,
    );

    final datos = DatosVerifactu(
      hashRegistro: hash,
      hashAnterior: hashAnterior,
      fechaHoraRegistro: fechaHoraRegistro,
      idSoftware: config.idSoftware,
      nombreSoftware: config.nombreSoftware,
      versionSoftware: config.versionSoftware,
      nifFabricante: config.nifFabricante,
      idFactura: factura.id,
      nifEmisor: config.nifEmisor,
      fechaExpedicion: fechaExpedicion,
      tipoFactura: tipoFacturaVf,
      claveRegimen: '01',
      estado: EstadoVerifactu.pendiente,
    );

    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .doc(factura.id)
        .update({'verifactu': datos.toMap()});

    return datos;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN XML PARA AEAT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera el XML del registro de facturación para envío a AEAT.
  static String generarXml({
    required Factura factura,
    required DatosVerifactu datos,
    required ConfigVerifactu config,
  }) {
    return XmlPayloadVerifactuBuilder.construirSuministroSingleAltaLegacy(
      factura: factura,
      nifEmisor: config.nifEmisor,
      nombreEmisor: config.nombreEmisor,
      tipoFactura: datos.tipoFactura,
      claveRegimen: datos.claveRegimen,
      hashRegistro: datos.hashRegistro,
      hashAnterior: datos.hashAnterior,
      fechaExpedicion: datos.fechaExpedicion,
      fechaHoraRegistro: datos.fechaHoraRegistro,
      nombreSoftware: datos.nombreSoftware,
      idSoftware: datos.idSoftware,
      versionSoftware: datos.versionSoftware,
      nifFabricante: datos.nifFabricante,
      esSoloVerifactu: true,
    );
  }

  /// Genera la URL para el código QR Verifactu de una factura.
  static String generarUrlQr({
    required String nifEmisor,
    required String numeroFactura,
    required String fechaExpedicion,
    required double importeTotal,
  }) {
    final params = Uri(queryParameters: {
      'nif': nifEmisor,
      'numserie': numeroFactura,
      'fecha': fechaExpedicion,
      'importe': importeTotal.toStringAsFixed(2),
    }).query;
    return 'https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR?$params';
  }
}
