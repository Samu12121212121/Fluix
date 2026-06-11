import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/modelos/pdf_template.dart';
import 'pdf_block_registry.dart';
import 'blocks/pdf_block_builder.dart';

/// Motor de renderizado de PDFs basado en plantillas dinámicas
class PdfRenderer {
  final _registry = PdfBlockRegistry();
  
  /// Renderiza un documento PDF usando una plantilla dinámica
  Future<Uint8List> render({
    required PdfTemplate template,
    required PdfBranding branding,
    required dynamic documentData,
    Uint8List? logoBytes,
    Uint8List? qrBytes,
  }) async {
    final pdf = pw.Document(
      title: template.name,
      author: branding.companyName,
      creator: 'FluixCRM',
    );
    
    // Crear contexto de renderizado
    final context = PdfRenderContext(
      template: template,
      branding: branding,
      documentData: documentData,
      logoBytes: logoBytes,
      qrBytes: qrBytes,
    );
    
    // Renderizar página única con todos los bloques
    pdf.addPage(
      pw.Page(
        pageFormat: _getPageFormat(template.page.format),
        margin: pw.EdgeInsets.only(
          top: template.page.margins.top,
          right: template.page.margins.right,
          bottom: template.page.margins.bottom,
          left: template.page.margins.left,
        ),
        build: (ctx) {
          // Renderizar bloques
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: template.blocks.map((block) {
              final builder = _registry.getBuilder(block.type);
              if (builder == null) {
                return pw.Text(
                  '⚠️ Bloque "${block.type}" no disponible',
                  style: const pw.TextStyle(color: PdfColors.red),
                );
              }
              return builder.build(block, context);
            }).toList(),
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  PdfPageFormat _getPageFormat(String format) {
    return switch (format.toLowerCase()) {
      'a4' => PdfPageFormat.a4,
      'letter' => PdfPageFormat.letter,
      'a3' => PdfPageFormat.a3,
      'a5' => PdfPageFormat.a5,
      _ => PdfPageFormat.a4,
    };
  }
}



