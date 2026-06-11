import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class HeaderBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.header;

  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final Map<String, dynamic> props = block.properties;
    final factura = context.documentData as Factura;

    final backgroundColor = colorFromHex(props['background_color'] ?? '#1565C0');
    final borderRadius = (props['border_radius'] as num?)?.toDouble() ?? 12.0;
    final padding = (props['padding'] as num?)?.toDouble() ?? 18.0;

    final showLogo = props['show_logo'] as bool? ?? true;
    
    final companyNameVisible = props['company_name_visible'] as bool? ?? true;
    final companyNameSize = (props['company_name_size'] as num?)?.toDouble() ?? 16.0;
    final companyNameColor = colorFromHex(props['company_name_color'] ?? '#FFFFFF');

    final fiscalDataVisible = props['fiscal_data_visible'] as bool? ?? true;
    final fiscalDataSize = (props['fiscal_data_size'] as num?)?.toDouble() ?? 9.0;
    final fiscalDataColor = colorFromHex(props['fiscal_data_color'] ?? '#E0E0E0');

    final invoiceNumberVisible = props['invoice_number_visible'] as bool? ?? true;
    final invoiceNumberSize = (props['invoice_number_size'] as num?)?.toDouble() ?? 14.0;
    final invoiceNumberColor = colorFromHex(props['invoice_number_color'] ?? '#00ACC1');

    final datesVisible = props['dates_visible'] as bool? ?? true;
    final datesSize = (props['dates_size'] as num?)?.toDouble() ?? 9.0;
    final datesColor = colorFromHex(props['dates_color'] ?? '#E0E0E0');

    final statusBadgeVisible = props['status_badge_visible'] as bool? ?? true;

    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(padding),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(borderRadius),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── COLUMNA IZQUIERDA: Logo + Datos Empresa ──
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (showLogo && context.logoBytes != null) ...[
                  _buildLogo(context.logoBytes!, props),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (companyNameVisible)
                        pw.Text(
                          context.branding.companyName ?? 'Mi Empresa',
                          style: pw.TextStyle(
                            fontSize: companyNameSize,
                            color: companyNameColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (fiscalDataVisible) ..._buildFiscalData(
                        context,
                        fiscalDataSize,
                        fiscalDataColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // ── COLUMNA DERECHA: Datos Factura ──
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (invoiceNumberVisible)
                pw.Text(
                  factura.numeroFactura,
                  style: pw.TextStyle(
                    fontSize: invoiceNumberSize,
                    color: invoiceNumberColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (datesVisible) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Emisión: ${formatDate(factura.fechaEmision)}',
                  style: pw.TextStyle(fontSize: datesSize, color: datesColor),
                ),
                if (factura.fechaOperacion != null &&
                    formatDate(factura.fechaOperacion!) != formatDate(factura.fechaEmision))
                  pw.Text(
                    'Operación: ${formatDate(factura.fechaOperacion!)}',
                    style: pw.TextStyle(
                      fontSize: datesSize,
                      color: datesColor,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                if (factura.fechaVencimiento != null)
                  pw.Text(
                    'Vencimiento: ${formatDate(factura.fechaVencimiento!)}',
                    style: pw.TextStyle(fontSize: datesSize, color: datesColor),
                  ),
              ],
              if (statusBadgeVisible) ...[
                pw.SizedBox(height: 8),
                _buildStatusBadge(factura.estado),
              ],
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLogo(Uint8List logoBytes, Map<String, dynamic> props) {
    final logoWidth = (props['logo_width'] as num?)?.toDouble() ?? 58.0;
    final logoHeight = (props['logo_height'] as num?)?.toDouble() ?? 58.0;

    return pw.Container(
      width: logoWidth,
      height: logoHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      ),
    );
  }

  List<pw.Widget> _buildFiscalData(
      PdfRenderContext context,
      double fontSize,
      PdfColor color,
      ) {
    final widgets = <pw.Widget>[];

    if (context.branding.nif != null && context.branding.nif!.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 3));
      widgets.add(pw.Text(
        'NIF/CIF: ${context.branding.nif}',
        style: pw.TextStyle(fontSize: fontSize, color: color),
      ));
    }

    if (context.branding.domicilioFiscal != null &&
        context.branding.domicilioFiscal!.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 2));
      widgets.add(pw.Text(
        context.branding.domicilioFiscal!,
        style: pw.TextStyle(fontSize: fontSize - 1, color: color),
      ));
    }

    if (context.branding.telefono != null && context.branding.telefono!.isNotEmpty) {
      widgets.add(pw.Text(
        'Tel: ${context.branding.telefono}',
        style: pw.TextStyle(fontSize: fontSize - 1, color: colorFromHex('#BDBDBD')),
      ));
    }

    if (context.branding.correo != null && context.branding.correo!.isNotEmpty) {
      widgets.add(pw.Text(
        context.branding.correo!,
        style: pw.TextStyle(fontSize: fontSize - 1, color: colorFromHex('#BDBDBD')),
      ));
    }

    return widgets;
  }

  pw.Widget _buildStatusBadge(EstadoFactura estado) {
    final color = _estadoColor(estado);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        _lblEstado(estado),
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  PdfColor _estadoColor(EstadoFactura e) => switch (e) {
    EstadoFactura.pagada => colorFromHex('#2E7D32'),
    EstadoFactura.vencida => colorFromHex('#D32F2F'),
    EstadoFactura.anulada => colorFromHex('#757575'),
    EstadoFactura.rectificada => colorFromHex('#E65100'),
    EstadoFactura.pendiente => colorFromHex('#1565C0'),
  };

  String _lblEstado(EstadoFactura e) => switch (e) {
    EstadoFactura.pendiente => 'Pendiente',
    EstadoFactura.pagada => 'Pagada',
    EstadoFactura.anulada => 'Anulada',
    EstadoFactura.vencida => 'Vencida',
    EstadoFactura.rectificada => 'Rectificada',
  };
}