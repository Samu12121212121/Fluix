import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

/// Servicio para enviar documentos PDF por email usando Cloud Functions.
///
/// Requisitos:
///   - Cloud Function `enviarEmailConPdf` desplegada
///   - Secrets SMTP configurados en Firebase
class EmailService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Envía un PDF por email llamando a la Cloud Function `enviarEmailConPdf`.
  ///
  /// [destinatario] — email del receptor
  /// [asunto] — asunto del email
  /// [pdfBytes] — bytes del PDF generado en el cliente
  /// [nombreArchivo] — nombre del archivo adjunto (ej: "Factura_FAC-2026-0001.pdf")
  /// [empresaId] — ID de la empresa (para personalizar el remitente)
  /// [cuerpoHtml] — HTML opcional del cuerpo del email
  static Future<String> enviarPdfPorEmail({
    required String destinatario,
    required String asunto,
    required Uint8List pdfBytes,
    String nombreArchivo = 'documento.pdf',
    String? empresaId,
    String? cuerpoHtml,
  }) async {
    final callable = _functions.httpsCallable('enviarEmailConPdf');

    final resultado = await callable.call<Map<String, dynamic>>({
      'destinatario': destinatario,
      'asunto': asunto,
      'pdfBase64': base64Encode(pdfBytes),
      'nombreArchivo': nombreArchivo,
      'empresaId': empresaId,
      'cuerpoHtml': cuerpoHtml,
    });

    return resultado.data['mensaje'] as String? ?? 'Email enviado';
  }

  /// Envía una factura por email. Genera el PDF y lo envía.
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

  /// Envía una nómina por email.
  static Future<String> enviarNomina({
    required String destinatario,
    required Uint8List pdfBytes,
    required String periodo,
    required String nombreEmpleado,
    String? empresaId,
  }) {
    return enviarPdfPorEmail(
      destinatario: destinatario,
      asunto: 'Nómina $periodo — $nombreEmpleado',
      pdfBytes: pdfBytes,
      nombreArchivo: 'Nomina_${periodo.replaceAll(' ', '_')}_$nombreEmpleado.pdf',
      empresaId: empresaId,
      cuerpoHtml: '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1976D2;">Nómina $periodo</h2>
          <p>Estimado/a $nombreEmpleado,</p>
          <p>Adjuntamos tu nómina correspondiente al período <strong>$periodo</strong>.</p>
          <p>Encontrarás el documento en el archivo adjunto.</p>
          <hr style="border: 1px solid #E0E0E0; margin: 20px 0;">
          <p style="color: #757575; font-size: 12px;">
            Este email ha sido generado automáticamente por Fluix CRM.<br>
            Si tienes cualquier duda, contacta con tu departamento de RRHH.
          </p>
        </div>
      ''',
    );
  }
}

