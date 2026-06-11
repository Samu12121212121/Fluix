import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class TableBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.table;

  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final Map<String, dynamic> props = block.properties;
    final factura = context.documentData as Factura;

    final columns = props['columns'] as List<dynamic>? ?? [];

    final headerBgColor = colorFromHex(props['header_background_color'] ?? '#0D47A1');
    final headerTextColor = colorFromHex(props['header_text_color'] ?? '#FFFFFF');
    final headerFontSize = (props['header_font_size'] as num?)?.toDouble() ?? 9.0;
    final headerBold = props['header_bold'] as bool? ?? true;
    final headerPadding = (props['header_padding'] as num?)?.toDouble() ?? 8.0;
    final headerBorderRadiusTop = (props['header_border_radius_top'] as num?)?.toDouble() ?? 8.0;

    final rowFontSize = (props['row_font_size'] as num?)?.toDouble() ?? 10.0;
    final rowPadding = (props['row_padding'] as num?)?.toDouble() ?? 9.0;
    final rowAlternateColors = props['row_alternate_colors'] as bool? ?? true;
    final rowColorEven = colorFromHex(props['row_color_even'] ?? '#FFFFFF');
    final rowColorOdd = colorFromHex(props['row_color_odd'] ?? '#FAFBFC');
    final rowBorderColor = colorFromHex(props['row_border_color'] ?? '#E0E0E0');
    final rowBorderWidth = (props['row_border_width'] as num?)?.toDouble() ?? 0.5;

    // Detectar si hay descuentos
    final hasDiscount = factura.lineas.any((l) => l.descuento > 0);

    // Filtrar columnas según visibilidad condicional
    final visibleColumns = columns.where((col) {
      final visibleIf = col['visible_if'] as String?;
      if (visibleIf != null) {
        if (visibleIf == 'has_discount') return hasDiscount;
        return context.evaluateCondition(visibleIf);
      }
      return true;
    }).toList();

    return pw.Column(
      children: [
        // ── HEADER ──
        pw.Container(
          decoration: pw.BoxDecoration(
            color: headerBgColor,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(headerBorderRadiusTop),
              topRight: pw.Radius.circular(headerBorderRadiusTop),
            ),
          ),
          padding: pw.EdgeInsets.symmetric(
            horizontal: 12,
            vertical: headerPadding,
          ),
          child: pw.Row(
            children: visibleColumns.map((col) {
              final label = col['label'] as String? ?? '';
              final flex = col['flex'] as int?;
              final width = (col['width'] as num?)?.toDouble();
              final align = col['align'] as String? ?? 'left';

              final widget = pw.Text(
                label,
                style: pw.TextStyle(
                  color: headerTextColor,
                  fontSize: headerFontSize,
                  fontWeight: headerBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  letterSpacing: 0.5,
                ),
                textAlign: _parseAlign(align),
              );

              if (flex != null) {
                return pw.Expanded(flex: flex, child: widget);
              } else if (width != null) {
                return pw.SizedBox(width: width, child: widget);
              } else {
                return widget;
              }
            }).toList(),
          ),
        ),
        // ── ROWS ──
        ...factura.lineas.asMap().entries.map((entry) {
          final index = entry.key;
          final linea = entry.value;

          final bgColor = rowAlternateColors && index.isEven
              ? rowColorEven
              : rowColorOdd;

          return pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: rowPadding,
            ),
            decoration: pw.BoxDecoration(
              color: bgColor,
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: rowBorderColor,
                  width: rowBorderWidth,
                ),
              ),
            ),
            child: pw.Row(
              children: visibleColumns.map((col) {
                final key = col['key'] as String?;
                final flex = col['flex'] as int?;
                final width = (col['width'] as num?)?.toDouble();
                final align = col['align'] as String? ?? 'left';

                final text = _getCellText(key, linea);

                final widget = pw.Text(
                  text,
                  style: pw.TextStyle(
                    fontSize: rowFontSize,
                    color: PdfColors.black,
                  ),
                  textAlign: _parseAlign(align),
                );

                if (flex != null) {
                  return pw.Expanded(flex: flex, child: widget);
                } else if (width != null) {
                  return pw.SizedBox(width: width, child: widget);
                } else {
                  return widget;
                }
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  String _getCellText(String? key, LineaFactura linea) {
    return switch (key) {
      'description' => linea.descripcion,
      'quantity' => '${linea.cantidad}',
      'unit_price' => formatCurrency(linea.precioUnitario),
      'discount' => linea.descuento > 0
          ? '${linea.descuento.toStringAsFixed(0)}%'
          : '—',
      'tax_rate' => '${linea.porcentajeIva.toStringAsFixed(0)}%',
      'subtotal' => formatCurrency(linea.subtotalSinIva),
      _ => '',
    };
  }

  pw.TextAlign _parseAlign(String align) {
    return switch (align) {
      'center' => pw.TextAlign.center,
      'right' => pw.TextAlign.right,
      _ => pw.TextAlign.left,
    };
  }
}