import 'dart:math';
import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class StampBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.stamp;
  
  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final props = block.properties;
    
    final visibleIf = (props['visible_if'] as String?);
    if (visibleIf != null && !context.evaluateCondition(visibleIf)) {
      return pw.SizedBox.shrink();
    }
    
    final text = (props['text'] as String?) ?? 'PAGADA';
    final fontSize = ((props['font_size'] as num?)?.toDouble()) ?? 28.0;
    final color = colorFromHex((props['color'] as String?) ?? '#2E7D32');
    final borderColor = colorFromHex((props['border_color'] as String?) ?? '#2E7D32');
    final borderWidth = ((props['border_width'] as num?)?.toDouble()) ?? 3.0;
    final borderRadius = ((props['border_radius'] as num?)?.toDouble()) ?? 6.0;
    final paddingH = ((props['padding_horizontal'] as num?)?.toDouble()) ?? 16.0;
    final paddingV = ((props['padding_vertical'] as num?)?.toDouble()) ?? 6.0;
    final rotationDegrees = ((props['rotation_angle'] as num?)?.toDouble()) ?? 0.0;
    final letterSpacing = ((props['letter_spacing'] as num?)?.toDouble()) ?? 4.0;
    
    final rotationRadians = rotationDegrees * pi / 180.0;
    
    final stampWidget = pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: paddingH,
        vertical: paddingV,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: borderWidth),
        borderRadius: pw.BorderRadius.circular(borderRadius),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: letterSpacing,
        ),
      ),
    );
    
    if (rotationDegrees != 0) {
      return pw.Center(
        child: pw.Transform.rotate(
          angle: rotationRadians,
          child: stampWidget,
        ),
      );
    }
    
    return pw.Center(child: stampWidget);
  }
}




