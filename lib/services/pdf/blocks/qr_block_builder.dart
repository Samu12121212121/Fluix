import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class QrBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.qr;

  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final Map<String, dynamic> props = block.properties;
    
    // Si no hay QR disponible, no renderizar nada
    if (context.qrBytes == null) {
      return pw.SizedBox.shrink();
    }
    
    final double size = (props['size'] as num?)?.toDouble() ?? 80.0;
    final String alignment = props['alignment'] as String? ?? 'center';
    final String? label = props['label'] as String?;
    final double labelSize = (props['label_size'] as num?)?.toDouble() ?? 8.0;
    final String labelColor = props['label_color'] as String? ?? '#757575';
    
    final qrWidget = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Image(
          pw.MemoryImage(context.qrBytes!),
          width: size,
          height: size,
        ),
        if (label != null && label.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: labelSize,
              color: colorFromHex(labelColor),
            ),
          ),
        ],
      ],
    );
    
    return pw.Align(
      alignment: _parseAlignment(alignment),
      child: qrWidget,
    );
  }
  
  pw.Alignment _parseAlignment(String alignment) {
    return switch (alignment) {
      'left' => pw.Alignment.centerLeft,
      'center' => pw.Alignment.center,
      'right' => pw.Alignment.centerRight,
      _ => pw.Alignment.center,
    };
  }
}

