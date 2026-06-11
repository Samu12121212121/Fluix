import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class TotalsBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.totals;

  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final Map<String, dynamic> props = block.properties;
    final factura = context.documentData as Factura;

    final width = (props['width'] as num?)?.toDouble() ?? 240.0;
    final alignment = props['alignment'] as String? ?? 'right';

    final labelFontSize = (props['label_font_size'] as num?)?.toDouble() ?? 11.0;
    final valueFontSize = (props['value_font_size'] as num?)?.toDouble() ?? 11.0;
    final labelColor = colorFromHex(props['label_color'] ?? '#757575');
    final valueColor = colorFromHex(props['value_color'] ?? '#000000');

    final totalLabelFontSize = (props['total_label_font_size'] as num?)?.toDouble() ?? 14.0;
    final totalValueFontSize = (props['total_value_font_size'] as num?)?.toDouble() ?? 16.0;
    final totalColor = colorFromHex(props['total_color'] ?? '#1565C0');
    final totalBold = props['total_bold'] as bool? ?? true;

    final dividerColor = colorFromHex(props['divider_color'] ?? '#757575');
    final dividerWidth = (props['divider_width'] as num?)?.toDouble() ?? 1.0;

    final rowSpacing = (props['row_spacing'] as num?)?.toDouble() ?? 2.0;

    // Calcular desglose IVA
    final Map<double, double> basesPorIva = {};
    final Map<double, double> cuotasPorIva = {};
    final factor = factura.descuentoGlobal > 0
        ? (1.0 - factura.descuentoGlobal / 100.0)
        : 1.0;

    for (final l in factura.lineas) {
      final pct = l.porcentajeIva;
      basesPorIva[pct] = (basesPorIva[pct] ?? 0) + l.subtotalSinIva * factor;
      cuotasPorIva[pct] = (cuotasPorIva[pct] ?? 0) + l.importeIva * factor;
    }

    final sortedRates = basesPorIva.keys.toList()..sort();
    final baseImponibleTotal = factura.subtotal - factura.importeDescuentoGlobal;

    final totalsWidget = pw.SizedBox(
      width: width,
      child: pw.Column(
        children: [
          // Base imponible
          if (props['show_base_imponible'] as bool? ?? true)
            _rowTotal(
              'Base imponible',
              formatCurrency(baseImponibleTotal),
              labelColor,
              valueColor,
              labelFontSize,
              valueFontSize,
              rowSpacing,
            ),
          // Descuento global
          if (factura.descuentoGlobal > 0 &&
              (props['show_descuento_global'] as bool? ?? true))
            _rowTotal(
              'Descuento (${factura.descuentoGlobal.toStringAsFixed(0)}%)',
              '-${formatCurrency(factura.importeDescuentoGlobal)}',
              colorFromHex('#E65100'),
              colorFromHex('#E65100'),
              labelFontSize,
              valueFontSize,
              rowSpacing,
            ),
          // IVA desglosado
          if (props['show_iva_breakdown'] as bool? ?? true) ...[
            if (sortedRates.length <= 1)
              _rowTotal(
                'IVA ${sortedRates.isNotEmpty ? sortedRates.first.toStringAsFixed(0) : '0'}%',
                formatCurrency(factura.totalIva),
                labelColor,
                valueColor,
                labelFontSize,
                valueFontSize,
                rowSpacing,
              )
            else
              ...sortedRates.map((rate) => _rowTotal(
                'IVA ${rate.toStringAsFixed(0)}%',
                formatCurrency(cuotasPorIva[rate] ?? 0),
                labelColor,
                valueColor,
                labelFontSize,
                valueFontSize,
                rowSpacing,
              )),
          ],
          // Recargo equivalencia
          if (factura.totalRecargoEquivalencia > 0 &&
              (props['show_recargo_equivalencia'] as bool? ?? true))
            _rowTotal(
              'Recargo equiv.',
              formatCurrency(factura.totalRecargoEquivalencia),
              labelColor,
              valueColor,
              labelFontSize,
              valueFontSize,
              rowSpacing,
            ),
          // IRPF
          if (factura.porcentajeIrpf > 0 &&
              (props['show_irpf'] as bool? ?? true))
            _rowTotal(
              'IRPF ${factura.porcentajeIrpf.toStringAsFixed(0)}%',
              '-${formatCurrency(factura.retencionIrpf)}',
              labelColor,
              valueColor,
              labelFontSize,
              valueFontSize,
              rowSpacing,
            ),
          // Divider
          pw.SizedBox(height: rowSpacing),
          pw.Divider(color: dividerColor, height: dividerWidth),
          pw.SizedBox(height: rowSpacing),
          // TOTAL
          if (props['show_total'] as bool? ?? true)
            _rowTotal(
              'TOTAL',
              formatCurrency(factura.total),
              totalColor,
              totalColor,
              totalLabelFontSize,
              totalValueFontSize,
              rowSpacing,
              bold: totalBold,
            ),
        ],
      ),
    );

    return pw.Align(
      alignment: _parseAlignment(alignment),
      child: totalsWidget,
    );
  }

  pw.Widget _rowTotal(
      String label,
      String value,
      PdfColor labelColor,
      PdfColor valueColor,
      double labelFontSize,
      double valueFontSize,
      double spacing, {
        bool bold = false,
      }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: spacing),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: labelFontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: labelColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueFontSize,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Alignment _parseAlignment(String alignment) {
    return switch (alignment) {
      'left' => pw.Alignment.centerLeft,
      'center' => pw.Alignment.center,
      _ => pw.Alignment.centerRight,
    };
  }
}