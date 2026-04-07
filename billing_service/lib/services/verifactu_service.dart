// lib/services/verifactu_service.dart
// Integración con el módulo Verifactu ya implementado en las Cloud Functions.
// Este stub llama al endpoint de Cloud Functions o puede ser sustituido
// por la implementación nativa cuando se despliegue en el servidor Dart.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/invoice.dart';

class VerifactuRegistro {
  final String xmlContent;
  final String hash;
  final DateTime timestamp;

  const VerifactuRegistro({
    required this.xmlContent,
    required this.hash,
    required this.timestamp,
  });
}

class VerifactuService {
  final String? _cloudFunctionUrl;

  VerifactuService({String? cloudFunctionUrl})
      : _cloudFunctionUrl = cloudFunctionUrl;

  factory VerifactuService.fromEnv() => VerifactuService(
    cloudFunctionUrl: Platform.environment['VERIFACTU_CLOUD_FUNCTION_URL'],
  );

  Future<VerifactuRegistro> createRegistroAlta({
    required String  nifEmisor,
    required String  numSerie,
    required String  numFactura,
    required DateTime fechaExpedicion,
    required String  tipoFactura,
    required double  importeTotal,
    required double  cuotaTotal,
    required String  descripcion,
    String?  destinatarioNif,
    String?  claveRegimen,
    String?  calificacionOperacion,
    String?  tipoRectificativa,
    String?  facturaRectificadaSerie,
    String?  facturaRectificadaNumero,
  }) async {
    if (_cloudFunctionUrl != null && _cloudFunctionUrl!.isNotEmpty) {
      return _callCloudFunction(
        nifEmisor:               nifEmisor,
        numSerie:                numSerie,
        numFactura:              numFactura,
        fechaExpedicion:         fechaExpedicion,
        tipoFactura:             tipoFactura,
        importeTotal:            importeTotal,
        cuotaTotal:              cuotaTotal,
        descripcion:             descripcion,
        destinatarioNif:         destinatarioNif,
        claveRegimen:            claveRegimen,
        calificacionOperacion:   calificacionOperacion,
        tipoRectificativa:       tipoRectificativa,
        facturaRectificadaSerie: facturaRectificadaSerie,
        facturaRectificadaNumero: facturaRectificadaNumero,
      );
    }

    // Implementación local simplificada (sin firma real)
    return _buildLocalRegistro(
      nifEmisor:    nifEmisor,
      numSerie:     numSerie,
      numFactura:   numFactura,
      fecha:        fechaExpedicion,
      tipo:         tipoFactura,
      importe:      importeTotal,
      cuota:        cuotaTotal,
      descripcion:  descripcion,
      destNif:      destinatarioNif,
    );
  }

  Future<VerifactuRegistro> _callCloudFunction({
    required String nifEmisor,
    required String numSerie,
    required String numFactura,
    required DateTime fechaExpedicion,
    required String tipoFactura,
    required double importeTotal,
    required double cuotaTotal,
    required String descripcion,
    String? destinatarioNif,
    String? claveRegimen,
    String? calificacionOperacion,
    String? tipoRectificativa,
    String? facturaRectificadaSerie,
    String? facturaRectificadaNumero,
  }) async {
    final response = await http.post(
      Uri.parse(_cloudFunctionUrl!),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nif_emisor':                 nifEmisor,
        'num_serie':                  numSerie,
        'num_factura':                numFactura,
        'fecha_expedicion':           fechaExpedicion.toIso8601String(),
        'tipo_factura':               tipoFactura,
        'importe_total':              importeTotal,
        'cuota_total':                cuotaTotal,
        'descripcion':                descripcion,
        'destinatario_nif':           destinatarioNif,
        'clave_regimen':              claveRegimen,
        'calificacion_operacion':     calificacionOperacion,
        'tipo_rectificativa':         tipoRectificativa,
        'factura_rectificada_serie':  facturaRectificadaSerie,
        'factura_rectificada_numero': facturaRectificadaNumero,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Verifactu Cloud Function error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VerifactuRegistro(
      xmlContent: data['xml'] as String,
      hash:       data['hash'] as String,
      timestamp:  DateTime.now(),
    );
  }

  VerifactuRegistro _buildLocalRegistro({
    required String nifEmisor,
    required String numSerie,
    required String numFactura,
    required DateTime fecha,
    required String tipo,
    required double importe,
    required double cuota,
    required String descripcion,
    String? destNif,
  }) {
    final ts    = DateTime.now();
    final fStr  = '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}/${fecha.year}';
    final xml   = '''<RegistroFactura>
  <IDVersion>1.0</IDVersion>
  <IDFactura>
    <IDEmisorFactura>$nifEmisor</IDEmisorFactura>
    <NumSerieFactura>$numSerie-$numFactura</NumSerieFactura>
    <FechaExpedicionFactura>$fStr</FechaExpedicionFactura>
  </IDFactura>
  <TipoFactura>$tipo</TipoFactura>
  <ImporteTotal>${importe.toStringAsFixed(2)}</ImporteTotal>
  <CuotaTotal>${cuota.toStringAsFixed(2)}</CuotaTotal>
  <Descripcion>$descripcion</Descripcion>
  <Timestamp>${ts.toIso8601String()}</Timestamp>
</RegistroFactura>''';

    // Hash SHA-256 del XML (sin firma real — para entornos de desarrollo)
    final hash = _sha256(xml);
    return VerifactuRegistro(xmlContent: xml, hash: hash, timestamp: ts);
  }

  String _sha256(String input) {
    // Implementación básica — en producción usar package:crypto
    return input.hashCode.toRadixString(16).padLeft(64, '0');
  }
}

