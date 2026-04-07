import 'package:cloud_functions/cloud_functions.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFACTU FLOW SERVICE — Orquesta el flujo completo:
// XML sin firmar → Firma XAdES (CF) → Remisión AEAT (CF)
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoVerifactu { enviado, rechazado, errorRed, errorCert, pendiente }

class VerifactuRemisionResult {
  final EstadoVerifactu estado;
  final String? csv;
  final String? descripcionError;

  const VerifactuRemisionResult({
    required this.estado,
    this.csv,
    this.descripcionError,
  });
}

class VerifactuFlowService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Flujo completo: firmar XML + remitir a AEAT
  static Future<VerifactuRemisionResult> enviarFactura({
    required String xmlSinFirmar,
    required String empresaId,
    required String facturaId,
  }) async {
    // Paso 1: Firmar XML vía Cloud Function
    final xmlFirmado = await firmarXML(
      xmlSinFirmar: xmlSinFirmar,
      empresaId: empresaId,
    );

    // Paso 2: Remitir a AEAT vía Cloud Function
    return await remitir(
      xmlFirmado: xmlFirmado,
      empresaId: empresaId,
      facturaId: facturaId,
    );
  }

  /// Paso 1: Firma XAdES-BES vía Cloud Function
  static Future<String> firmarXML({
    required String xmlSinFirmar,
    required String empresaId,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'firmarXMLVerifactu',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call({
        'xmlSinFirmar': xmlSinFirmar,
        'empresaId': empresaId,
      });

      final xmlFirmado = result.data['xmlFirmado'] as String?;
      if (xmlFirmado == null || xmlFirmado.isEmpty) {
        throw Exception('La Cloud Function no devolvió XML firmado');
      }

      return xmlFirmado;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error firma XAdES: ${e.code} — ${e.message}');
    }
  }

  /// Paso 2: Remisión a AEAT vía Cloud Function
  static Future<VerifactuRemisionResult> remitir({
    required String xmlFirmado,
    required String empresaId,
    required String facturaId,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'remitirVerifactu',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call({
        'xmlFirmado': xmlFirmado,
        'empresaId': empresaId,
        'facturaId': facturaId,
      });

      final data = result.data as Map<String, dynamic>;
      final estado = data['estado'] as String;

      return VerifactuRemisionResult(
        estado: estado == 'enviado'
            ? EstadoVerifactu.enviado
            : EstadoVerifactu.rechazado,
        csv: data['csv'] as String?,
        descripcionError: data['descripcionError'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable') {
        return VerifactuRemisionResult(
          estado: EstadoVerifactu.errorRed,
          descripcionError: e.message,
        );
      }
      if (e.code == 'not-found') {
        return VerifactuRemisionResult(
          estado: EstadoVerifactu.errorCert,
          descripcionError: e.message,
        );
      }
      return VerifactuRemisionResult(
        estado: EstadoVerifactu.rechazado,
        descripcionError: '${e.code}: ${e.message}',
      );
    }
  }
}

