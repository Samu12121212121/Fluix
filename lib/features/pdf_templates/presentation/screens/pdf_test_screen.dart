import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../services/pdf_service.dart';
import '../../domain/models/pdf_template.dart';
import '../../../../core/widgets/fluix_app_bar.dart';

// ── Pantalla de prueba de PDFs ─────────────────────────────────────────────
// Genera las 7 tipos × 8 diseños con datos de demo y los muestra en pantalla.
// Para uso interno — accesible desde el botón 🧪 en la lista de plantillas.
class PdfTestScreen extends StatelessWidget {
  final String empresaId;

  const PdfTestScreen({super.key, required this.empresaId});

  // Diseños disponibles: id interno, etiqueta, color de botón
  static const _layouts = <(String, String, Color)>[
    ('clasico',    'Clásico',  Color(0xFF1565C0)),
    ('d1_corp',    'D1 Corp',  Color(0xFF1B2A4A)),
    ('d2_minimal', 'D2 Min',   Color(0xFF444444)),
    ('d3_hero',    'D3 Hero',  Color(0xFF7C6CF0)),
    ('d4_sidebar', 'D4 Side',  Color(0xFF2D6A4F)),
    ('d5_cards',   'D5 Cards', Color(0xFF3E9C63)),
    ('d6_dark',    'D6 Dark',  Color(0xFF1A0F2E)),
    ('d7_exec',    'D7 Exec',  Color(0xFF374151)),
  ];

  // Tipos de documento: enum, etiqueta, color de sección
  static const _tipos = <(TipoDocumentoPdf, String, Color)>[
    (TipoDocumentoPdf.factura,              '🧾 Factura',       Color(0xFF1565C0)),
    (TipoDocumentoPdf.facturaRectificativa, '🔄 Rectificativa', Color(0xFFD32F2F)),
    (TipoDocumentoPdf.presupuesto,          '💼 Presupuesto',   Color(0xFF006D77)),
    (TipoDocumentoPdf.proforma,             '📋 Proforma',      Color(0xFFE76F51)),
    (TipoDocumentoPdf.albaran,              '📦 Albarán',       Color(0xFF795548)),
    (TipoDocumentoPdf.fichajes,             '⏱️ Fichajes',      Color(0xFF7B2FBE)),
    (TipoDocumentoPdf.informeInterno,       '📄 Informe',       Color(0xFF546E7A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FluixAppBar(
        titulo: '🧪 Test PDFs — 7 tipos × 8 diseños',
        showLeading: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        itemCount: _tipos.length,
        itemBuilder: (ctx, i) {
          final (tipo, label, color) = _tipos[i];
          return _TipoSection(
            tipo: tipo,
            label: label,
            color: color,
            layouts: _layouts,
            empresaId: empresaId,
          );
        },
      ),
    );
  }
}

// ── Sección por tipo de documento ──────────────────────────────────────────
class _TipoSection extends StatelessWidget {
  final TipoDocumentoPdf tipo;
  final String label;
  final Color color;
  final List<(String, String, Color)> layouts;
  final String empresaId;

  const _TipoSection({
    required this.tipo,
    required this.label,
    required this.color,
    required this.layouts,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de sección
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color)),
          ),
          // Fila de chips de diseño
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: layouts.map((layout) {
                final (id, lbl, bgColor) = layout;
                return _PdfChip(
                  tipo: tipo,
                  layoutId: id,
                  label: lbl,
                  color: bgColor,
                  empresaId: empresaId,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip individual: genera y muestra el PDF al pulsar ─────────────────────
class _PdfChip extends StatefulWidget {
  final TipoDocumentoPdf tipo;
  final String layoutId;
  final String label;
  final Color color;
  final String empresaId;

  const _PdfChip({
    required this.tipo,
    required this.layoutId,
    required this.label,
    required this.color,
    required this.empresaId,
  });

  @override
  State<_PdfChip> createState() => _PdfChipState();
}

class _PdfChipState extends State<_PdfChip> {
  bool _loading = false;

  PdfTemplate _mockTemplate() => PdfTemplate(
    id: 'test_${widget.layoutId}_${widget.tipo.name}',
    empresaId: widget.empresaId,
    nombre: '${widget.tipo.label} — ${widget.label}',
    descripcion: 'Test interno',
    tipo: widget.tipo,
    esDefault: false,
    activa: true,
    fechaCreacion: DateTime.now(),
    fechaModificacion: DateTime.now(),
    colorPrimario: _hex(widget.color),
    colorSecundario: _hex(_darken(widget.color)),
    colorTexto: '#000000',
    colorFondo: '#FFFFFF',
    margenHorizontal: 36,
    margenVertical: 36,
    bloques: const [],
    estiloLayout: widget.layoutId,
  );

  static String _hex(Color c) =>
      '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color _darken(Color c) => Color.fromARGB(
    255,
    (c.red * 0.7).round(),
    (c.green * 0.7).round(),
    (c.blue * 0.7).round(),
  );

  Future<void> _generate() async {
    if (_loading) return;
    debugPrint('🧪 PDF test: ${widget.tipo.name} / ${widget.layoutId}');
    if (mounted) setState(() => _loading = true);
    try {
      final tpl = _mockTemplate();
      final bytes = await PdfService.generarPreviewBytes(tpl, widget.empresaId);
      debugPrint('🧪 PDF listo: ${bytes.length} bytes');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(bytes: bytes, titulo: tpl.nombre),
      ));
    } catch (e, st) {
      debugPrint('🧪 ERROR: $e\n$st');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error generando PDF'),
          content: SingleChildScrollView(
            child: Text('$e\n\nTipo: ${widget.tipo.name}\nLayout: ${widget.layoutId}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _generate,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: widget.color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(),
        elevation: 3,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              widget.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
    );
  }
}

// ── Pantalla de previsualización ───────────────────────────────────────────
class _PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String titulo;

  const _PdfPreviewScreen({required this.bytes, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: () => Printing.sharePdf(
              bytes: bytes,
              filename: '$titulo.pdf',
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => Uint8List.fromList(bytes),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
