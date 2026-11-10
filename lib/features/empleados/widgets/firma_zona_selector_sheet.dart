import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTOR DE ZONA DE FIRMA
//
// Muestra las páginas del PDF como imágenes. El admin toca el punto exacto
// donde debe aparecer la firma del empleado. Devuelve coordenadas normalizadas
// {pagina, left_pct, top_pct} para incrustar la firma en ese punto.
// ═══════════════════════════════════════════════════════════════════════════════

class FirmaZonaSelectorSheet extends StatefulWidget {
  final String docUrl;
  final String docNombre;

  const FirmaZonaSelectorSheet({
    super.key,
    required this.docUrl,
    required this.docNombre,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String docUrl,
    required String docNombre,
  }) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FirmaZonaSelectorSheet(docUrl: docUrl, docNombre: docNombre),
      );

  @override
  State<FirmaZonaSelectorSheet> createState() => _FirmaZonaSelectorSheetState();
}

class _FirmaZonaSelectorSheetState extends State<FirmaZonaSelectorSheet> {
  static const _kBlue   = Color(0xFF3B82F6);
  static const _kBorder = Color(0xFFE5E7EB);
  static const _kText   = Color(0xFF111827);
  static const _kSub    = Color(0xFF6B7280);

  List<Uint8List> _pages = [];
  bool _cargando = true;
  String? _error;

  // Zona seleccionada (null = sin seleccionar)
  int?    _paginaIdx;
  Offset? _centro; // fracción 0.0–1.0 sobre la imagen

  @override
  void initState() {
    super.initState();
    _cargarPaginas();
  }

  Future<void> _cargarPaginas() async {
    try {
      final resp = await http.get(Uri.parse(widget.docUrl));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final pdfBytes = resp.bodyBytes;
      final pages = <Uint8List>[];
      await for (final raster in Printing.raster(pdfBytes, dpi: 110)) {
        pages.add(await raster.toPng());
      }
      if (mounted) setState(() { _pages = pages; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  void _onTapPagina(int idx, TapDownDetails det, Size widgetSize) {
    final x = (det.localPosition.dx / widgetSize.width).clamp(0.0, 1.0);
    final y = (det.localPosition.dy / widgetSize.height).clamp(0.0, 1.0);
    setState(() {
      _paginaIdx = idx;
      _centro    = Offset(x, y);
    });
  }

  void _confirmar() {
    if (_paginaIdx == null || _centro == null) return;
    Navigator.pop(context, {
      'pagina':    _paginaIdx,
      'left_pct':  _centro!.dx,
      'top_pct':   _centro!.dy,
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq   = MediaQuery.of(context);
    final maxH = mq.size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
        )),
        // Cabecera
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(children: [
            const Icon(Icons.touch_app_rounded, size: 18, color: _kBlue),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Marcar zona de firma',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
              Text('Toca el lugar del documento donde debe firmar el empleado',
                  style: const TextStyle(fontSize: 11, color: _kSub)),
            ])),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: _kSub),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(height: 1),

        // Contenido
        Expanded(child: _cargando
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _kBlue),
                SizedBox(height: 12),
                Text('Cargando documento…', style: TextStyle(fontSize: 12, color: _kSub)),
              ]))
            : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      const Text('No se pudo cargar el PDF',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_error!, style: const TextStyle(fontSize: 11, color: _kSub),
                          textAlign: TextAlign.center),
                    ]),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pages.length,
                    itemBuilder: (_, idx) => _buildPaginaWidget(idx),
                  ),
        ),

        // Botones
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + mq.padding.bottom),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, <String, dynamic>{'sin_zona': true}),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sin zona específica', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: _paginaIdx != null ? _confirmar : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Usar esta zona', style: TextStyle(fontSize: 13)),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPaginaWidget(int idx) {
    final esSeleccionada = _paginaIdx == idx;
    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Text('Página ${idx + 1}',
            style: TextStyle(fontSize: 11, color: esSeleccionada ? _kBlue : _kSub,
                fontWeight: esSeleccionada ? FontWeight.w700 : FontWeight.w400)),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: esSeleccionada ? _kBlue : _kBorder,
            width: esSeleccionada ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LayoutBuilder(builder: (ctx, cst) {
            final widgetSize = Size(cst.maxWidth,
                cst.maxWidth * 1.414); // aprox A4
            return GestureDetector(
              onTapDown: (det) => _onTapPagina(idx, det, widgetSize),
              child: Stack(children: [
                // Imagen de la página
                SizedBox(
                  width: widgetSize.width,
                  height: widgetSize.height,
                  child: Image.memory(_pages[idx],
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium),
                ),
                // Overlay semitransparente si es otra página
                if (_paginaIdx != null && _paginaIdx != idx)
                  Positioned.fill(child: Container(
                    color: Colors.white.withValues(alpha: 0.5),
                  )),
                // Marcador de firma
                if (esSeleccionada && _centro != null)
                  Positioned(
                    left: _centro!.dx * widgetSize.width - 60,
                    top:  _centro!.dy * widgetSize.height - 20,
                    child: _buildMarcadorFirma(widgetSize.width),
                  ),
                // Instrucción si no hay selección
                if (_paginaIdx == null)
                  Positioned.fill(child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Toca para marcar la firma',
                            style: TextStyle(fontSize: 11, color: Colors.white)),
                      ]),
                    ),
                  )),
              ]),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _buildMarcadorFirma(double pageWidth) {
    final w = (pageWidth * 0.4).clamp(100.0, 200.0);
    return Container(
      width: w, height: 40,
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.15),
        border: Border.all(color: _kBlue, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.draw_rounded, size: 14, color: _kBlue),
        SizedBox(width: 6),
        Text('Firma aquí', style: TextStyle(
            fontSize: 11, color: _kBlue, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
