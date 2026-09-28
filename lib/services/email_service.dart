import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio para enviar documentos PDF por email usando Cloud Functions.
///
/// En Windows usa HTTP directamente porque cloud_functions 6.x no implementa
/// el canal Pigeon en el plugin Windows (bug conocido de FlutterFire 6.x).
class EmailService {
  static const _projectId = 'planeaapp-4bea4';
  static const _region = 'europe-west1';
  static final _functions = FirebaseFunctions.instanceFor(region: _region);

  // ── Detectar si estamos en Windows desktop ──────────────────────────────────
  static bool get _esWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  // ── Refresh de token (necesario tras upgrade Firebase 6.x) ─────────────────
  static Future<String?> _idToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');
      return await user.getIdToken(true); // forceRefresh
    } catch (e) {
      debugPrint('📧 [EMAIL] ⚠️ Error obteniendo token: $e');
      rethrow;
    }
  }

  // ── Llamada directa por HTTP para Windows ───────────────────────────────────
  // cloud_functions 6.x no implementa el canal Pigeon en Windows → fallback HTTP.
  // El protocolo de Firebase callable es idéntico al del SDK.
  static Future<String> _llamarHttpWindows({
    required String functionName,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final url = 'https://$_region-$_projectId.cloudfunctions.net/$functionName';

    debugPrint('📧 [EMAIL-WIN] POST $url');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': data}),
    ).timeout(const Duration(seconds: 60));

    debugPrint('📧 [EMAIL-WIN] HTTP ${response.statusCode}');

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final result = body['result'] as Map<String, dynamic>? ?? {};
      return result['mensaje'] as String? ?? 'Email enviado';
    }

    // Error de la función — parsear el formato callable de Firebase
    final error = body['error'] as Map<String, dynamic>? ?? {};
    final msg = error['message'] as String? ?? 'Error ${response.statusCode}';
    throw Exception(msg);
  }

  // ── Método principal ────────────────────────────────────────────────────────

  static Future<String> enviarPdfPorEmail({
    required String destinatario,
    required String asunto,
    required Uint8List pdfBytes,
    String nombreArchivo = 'documento.pdf',
    String? empresaId,
    String? cuerpoHtml,
  }) async {
    final payload = {
      'destinatario': destinatario,
      'asunto': asunto,
      'pdfBase64': base64Encode(pdfBytes),
      'nombreArchivo': nombreArchivo,
      'empresaId': empresaId,
      'cuerpoHtml': cuerpoHtml,
    };

    if (_esWindows) {
      // Windows: HTTP directo — cloud_functions 6.x no funciona en Windows
      return _llamarHttpWindows(
        functionName: 'enviarEmailConPdf',
        data: payload,
      );
    }

    // Mobile/Web: SDK estándar
    await _idToken(); // refresca el token antes de llamar
    final callable = _functions.httpsCallable('enviarEmailConPdf');
    final resultado = await callable.call<Map<String, dynamic>>(payload);
    return resultado.data['mensaje'] as String? ?? 'Email enviado';
  }

  // ── Helpers específicos ─────────────────────────────────────────────────────

  static Future<String> enviarFactura({
    required String destinatario,
    required Uint8List pdfBytes,
    required String numeroFactura,
    required double total,
    String? empresaId,
    String? nombreCliente,
  }) {
    return enviarPdfPorEmail(
      destinatario: destinatario,
      asunto: 'Factura $numeroFactura',
      pdfBytes: pdfBytes,
      nombreArchivo: 'Factura_$numeroFactura.pdf',
      empresaId: empresaId,
      cuerpoHtml: '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1976D2;">Factura $numeroFactura</h2>
          <p>Estimado/a ${nombreCliente ?? 'cliente'},</p>
          <p>Adjuntamos la factura <strong>$numeroFactura</strong> por un importe de <strong>${total.toStringAsFixed(2)} €</strong>.</p>
          <p>Puede encontrar el documento en el archivo adjunto a este email.</p>
          <hr style="border: 1px solid #E0E0E0; margin: 20px 0;">
          <p style="color: #757575; font-size: 12px;">
            Este email ha sido generado automáticamente por Fluix CRM.<br>
            Si tiene cualquier duda, responda a este email.
          </p>
        </div>
      ''',
    );
  }

  static Future<void> enviarConfirmacionReservaManual({
    required String empresaId,
    required String reservaId,
  }) async {
    final payload = {'empresaId': empresaId, 'reservaId': reservaId};

    if (_esWindows) {
      await _llamarHttpWindows(
        functionName: 'reenviarConfirmacionReserva',
        data: payload,
      );
      return;
    }

    await _idToken();
    final callable = _functions.httpsCallable('reenviarConfirmacionReserva');
    await callable.call<Map<String, dynamic>>(payload);
  }

  static Future<String> enviarNomina({
    required String destinatario,
    required Uint8List pdfBytes,
    required String periodo,
    required String nombreEmpleado,
    String? empresaId,
  }) {
    return enviarPdfPorEmail(
      destinatario: destinatario,
      asunto: 'Nomina $periodo — $nombreEmpleado',
      pdfBytes: pdfBytes,
      nombreArchivo: 'Nomina_${periodo.replaceAll(' ', '_')}_$nombreEmpleado.pdf',
      empresaId: empresaId,
      cuerpoHtml: '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1976D2;">Nomina $periodo</h2>
          <p>Estimado/a $nombreEmpleado,</p>
          <p>Adjuntamos tu nomina correspondiente al periodo <strong>$periodo</strong>.</p>
          <p>Encontraras el documento en el archivo adjunto.</p>
          <hr style="border: 1px solid #E0E0E0; margin: 20px 0;">
          <p style="color: #757575; font-size: 12px;">
            Este email ha sido generado automaticamente por Fluix CRM.<br>
            Si tienes cualquier duda, contacta con tu departamento de RRHH.
          </p>
        </div>
      ''',
    );
  }
}
