import 'package:pdf/widgets.dart' as pw;
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';

class TextBlockBuilder extends PdfBlockBuilder {
  @override
  PdfBlockType get blockType => PdfBlockType.text;
  
  @override
  pw.Widget build(PdfBlock block, PdfRenderContext context) {
    final props = block.properties;
    
    final visibleIf = (props['visible_if'] as String?);
    if (visibleIf != null && !context.evaluateCondition(visibleIf)) {
      return pw.SizedBox.shrink();
    }
    
    final title = (props['title'] as String?);
    final titleSize = ((props['title_size'] as num?)?.toDouble()) ?? 9.0;
    final titleBold = (props['title_bold'] as bool?) ?? true;
    final titleColor = colorFromHex((props['title_color'] as String?) ?? '#1565C0');
    final titleLetterSpacing = ((props['title_letter_spacing'] as num?)?.toDouble()) ?? 1.0;
    
    final contentTemplate = (props['content_template'] as String?);
    final contentSize = ((props['content_size'] as num?)?.toDouble()) ?? 10.0;
    final contentColor = colorFromHex((props['content_color'] as String?) ?? '#000000');
    
    final backgroundColor = (props['background_color'] as String?);
    final borderColor = (props['border_color'] as String?);
    final borderRadius = ((props['border_radius'] as num?)?.toDouble());
    final padding = ((props['padding'] as num?)?.toDouble()) ?? 10.0;
    
    final contentText = contentTemplate != null
        ? context.resolveTemplate(contentTemplate)
        : '';
    
    final widgets = <pw.Widget>[];
    
    if (title != null && title.isNotEmpty) {
      widgets.add(pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: titleSize,
          fontWeight: titleBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: titleColor,
          letterSpacing: titleLetterSpacing,
        ),
      ));
      widgets.add(pw.SizedBox(height: 6));
    }
    
    if (contentText.isNotEmpty) {
      final contentWidget = pw.Text(
        contentText,
        style: pw.TextStyle(
          fontSize: contentSize,
          color: contentColor,
        ),
      );
      
      if (backgroundColor != null || borderColor != null) {
        widgets.add(pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(padding),
          decoration: pw.BoxDecoration(
            color: backgroundColor != null ? colorFromHex(backgroundColor) : null,
            border: borderColor != null
                ? pw.Border.all(color: colorFromHex(borderColor))
                : null,
            borderRadius: borderRadius != null
                ? pw.BorderRadius.circular(borderRadius)
                : null,
          ),
          child: contentWidget,
        ));
      } else {
        widgets.add(contentWidget);
      }
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
}





