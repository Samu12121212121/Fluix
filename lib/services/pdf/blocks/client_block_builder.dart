import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class ClientBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.client;
  
  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final Map<String, dynamic> props = block.properties;
    final factura = context.documentData as Factura;
    
    final title = props['title'] as String? ?? 'FACTURAR A:';
    final titleSize = (props['title_size'] as num?)?.toDouble() ?? 10.0;
    final titleColor = colorFromHex(props['title_color'] as String? ?? '#1565C0');
    final titleBold = props['title_bold'] as bool? ?? true;
    final titleLetterSpacing = (props['title_letter_spacing'] as num?)?.toDouble() ?? 1.2;
    
    final nameSize = (props['name_size'] as num?)?.toDouble() ?? 12.0;
    final nameBold = props['name_bold'] as bool? ?? true;
    
    final fiscalSize = (props['fiscal_size'] as num?)?.toDouble() ?? 10.0;
    final fiscalColor = colorFromHex(props['fiscal_color'] as String? ?? '#757575');
    
    final backgroundColor = colorFromHex(props['background_color'] as String? ?? '#F5F9FF');
    final borderColor = colorFromHex(props['border_color'] as String? ?? '#E0E0E0');
    final borderRadius = (props['border_radius'] as num?)?.toDouble() ?? 8.0;
    final padding = (props['padding'] as num?)?.toDouble() ?? 12.0;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: titleSize,
            fontWeight: titleBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: titleColor,
            letterSpacing: titleLetterSpacing,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(padding),
          decoration: pw.BoxDecoration(
            color: backgroundColor,
            border: pw.Border.all(color: borderColor),
            borderRadius: pw.BorderRadius.circular(borderRadius),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Nombre cliente
              if (props['show_name'] as bool? ?? true)
                pw.Text(
                  factura.clienteNombre,
                  style: pw.TextStyle(
                    fontSize: nameSize,
                    fontWeight: nameBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              // Razón social (si es distinta)
              if ((props['show_razon_social'] as bool? ?? true) &&
                  factura.datosFiscales?.razonSocial != null &&
                  factura.datosFiscales!.razonSocial!.trim().isNotEmpty &&
                  factura.datosFiscales!.razonSocial!.trim() != factura.clienteNombre.trim())
                pw.Text(
                  factura.datosFiscales!.razonSocial!,
                  style: pw.TextStyle(
                    fontSize: fiscalSize,
                    color: fiscalColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              // NIF
              if ((props['show_nif'] as bool? ?? true) &&
                  factura.datosFiscales?.nif != null)
                pw.Text(
                  'NIF/CIF: ${factura.datosFiscales!.nif}',
                  style: pw.TextStyle(
                    fontSize: fiscalSize,
                    color: fiscalColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              // Dirección
              if ((props['show_direccion'] as bool? ?? true) &&
                  factura.datosFiscales?.direccion != null)
                pw.Text(
                  factura.datosFiscales!.direccion!,
                  style: pw.TextStyle(
                    fontSize: fiscalSize,
                    color: fiscalColor,
                  ),
                ),
              // Correo
              if ((props['show_correo'] as bool? ?? true) &&
                  factura.clienteCorreo != null)
                pw.Text(
                  factura.clienteCorreo!,
                  style: pw.TextStyle(
                    fontSize: fiscalSize,
                    color: fiscalColor,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}








