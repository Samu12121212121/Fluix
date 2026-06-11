import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../domain/modelos/pdf_template.dart';
import '../../domain/modelos/factura.dart';

/// Contexto compartido para todos los bloques
class PdfRenderContext {
  final PdfTemplate template;
  final PdfBranding branding;
  final dynamic documentData;
  final Uint8List? logoBytes;
  final Uint8List? qrBytes;

  const PdfRenderContext({
    required this.template,
    required this.branding,
    required this.documentData,
    this.logoBytes,
    this.qrBytes,
  });

  T getProp<T>(PdfBlock block, String key, T defaultValue) {
    final value = block.properties[key];
    if (value is T) return value;
    return defaultValue;
  }

  bool evaluateCondition(String? condition) {
    if (condition == null || condition.isEmpty) return true;

    try {
      if (documentData is Factura) {
        final factura = documentData as Factura;

        if (condition.contains('factura.estado == ')) {
          final estado = condition.split("'")[1];
          return factura.estado.name == estado;
        }

        if (condition.contains('factura.es_proforma == true')) {
          return factura.esProforma;
        }

        if (condition.contains('factura.verifactu != null')) {
          return factura.verifactu != null;
        }

        if (condition.contains('factura.metodo_pago != null')) {
          return factura.metodoPago != null;
        }

        if (condition.contains('has_discount')) {
          return factura.lineas.any((l) => l.descuento > 0);
        }
      }

      return true;
    } catch (e) {
      return true;
    }
  }

  String resolveTemplate(String template) {
    String result = template;

    if (documentData is Factura) {
      final factura = documentData as Factura;

      result = result.replaceAll('{{metodo_pago}}', factura.metodoPago?.name ?? '');
      result = result.replaceAll('{{iban_empresa}}', branding.iban ?? '');
      result = result.replaceAll('{{numero_factura}}', factura.numeroFactura);
      result = result.replaceAll('{{cliente_nombre}}', factura.clienteNombre);
      result = result.replaceAll('{{total}}', factura.total.toStringAsFixed(2));
    }

    return result;
  }
}

abstract class PdfBlockBuilder {
  PdfBlockType get blockType;

  pw.Widget build(PdfBlock block, PdfRenderContext context);

  bool validate(PdfBlock block) => block.type == blockType;

  PdfColor colorFromHex(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255.0;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255.0;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255.0;
    return PdfColor(r, g, b);
  }

  pw.FontWeight? fontWeight(bool bold) {
    return bold ? pw.FontWeight.bold : pw.FontWeight.normal;
  }

  pw.EdgeInsets paddingFromProps(Map<String, dynamic> props, {double defaultValue = 12.0}) {
    final padding = props['padding'];
    if (padding is double || padding is int) {
      final val = (padding as num).toDouble();
      return pw.EdgeInsets.all(val);
    }
    return pw.EdgeInsets.all(defaultValue);
  }

  pw.BorderRadius? borderRadiusFromProps(Map<String, dynamic> props) {
    final radius = props['border_radius'];
    if (radius is double || radius is int) {
      final val = (radius as num).toDouble();
      return pw.BorderRadius.circular(val);
    }
    return null;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatCurrency(double amount, {String symbol = '€'}) {
    return '${amount.toStringAsFixed(2)} $symbol';
  }
}

class PdfBlockRenderException implements Exception {
  final String blockId;
  final PdfBlockType blockType;
  final String message;

  const PdfBlockRenderException({
    required this.blockId,
    required this.blockType,
    required this.message,
  });

  @override
  String toString() => 'PdfBlockRenderException: [$blockType] $blockId - $message';
}
