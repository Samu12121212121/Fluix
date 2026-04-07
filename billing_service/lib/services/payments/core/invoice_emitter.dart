// lib/services/payments/core/invoice_emitter.dart
// Genera PDF, envía email y registra en Verifactu.

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../models/invoice.dart';
import '../../notification_service.dart';
import '../../verifactu_service.dart';
import '../interfaces/payment_event.dart';
import '../../logger.dart';

class InvoiceEmitter {
  final NotificationService _notifications;

  InvoiceEmitter({required NotificationService notifications})
      : _notifications = notifications;

  Future<void> emit(
    Invoice invoice,
    VerifactuRegistro registro,
    CustomerInfo? customer,
  ) async {
    // 1. Generar PDF (stub — en producción usar pdf package)
    final pdfBytes = await _generatePdf(invoice);

    // 2. Enviar email al cliente si tiene email
    final email = invoice.destinatarioEmail ??
                  customer?.email;
    if (email != null && email.isNotEmpty) {
      await _sendEmail(email, invoice, pdfBytes);
    }

    // 3. Log de factura generada
    logger.info(
      'Factura ${invoice.serie}-${invoice.numero} generada — '
      '€${invoice.importeTotal.toStringAsFixed(2)} — '
      '${invoice.tipoVerifactu} — '
      'hash: ${registro.hash.substring(0, 8)}...',
    );
  }

  Future<List<int>> _generatePdf(Invoice invoice) async {
    // Stub: en producción usar el paquete pdf de Dart
    // pdf_service.dart ya existe en el módulo de facturación Flutter
    final content = '''FACTURA ${invoice.tipoVerifactu}
${'-' * 40}
Serie/Número: ${invoice.serie}-${invoice.numero}
Fecha:        ${_formatDate(invoice.fechaExpedicion)}
Emisor:       ${invoice.emisorNombre} (${invoice.emisorNif})
Destinatario: ${invoice.destinatarioNombre ?? 'Consumidor final'}
${invoice.destinatarioNif != null ? 'NIF: ${invoice.destinatarioNif}' : ''}

Descripción:  ${invoice.descripcion}
Base impon.:  €${invoice.baseImponible.toStringAsFixed(2)}
IVA (${invoice.tipoIva.toStringAsFixed(0)}%):    €${invoice.cuotaIva.toStringAsFixed(2)}
${invoice.retencionIrpf > 0 ? 'IRPF:         -€${invoice.retencionIrpf.toStringAsFixed(2)}\n' : ''}TOTAL:        €${invoice.importeTotal.toStringAsFixed(2)}

Hash Verifactu: ${invoice.hashVerifactu ?? 'N/A'}
''';
    return utf8.encode(content);
  }

  Future<void> _sendEmail(
    String email,
    Invoice invoice,
    List<int> pdfBytes,
  ) async {
    final endpoint = Platform.environment['EMAIL_SERVICE_ENDPOINT'];
    if (endpoint == null || endpoint.isEmpty) {
      logger.warn('EMAIL_SERVICE_ENDPOINT no configurado — email no enviado a $email');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to':      email,
          'subject': 'Tu factura ${invoice.serie}-${invoice.numero}',
          'invoice': invoice.toJson(),
          'pdf_base64': base64.encode(pdfBytes),
        }),
      );

      if (response.statusCode == 200) {
        logger.info('Email enviado a $email — factura ${invoice.serie}-${invoice.numero}');
      } else {
        logger.warn('Error enviando email a $email: ${response.statusCode}');
      }
    } catch (e) {
      logger.warn('Excepción enviando email a $email: $e');
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}


