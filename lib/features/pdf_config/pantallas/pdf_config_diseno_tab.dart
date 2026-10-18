import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/modelos/pdf_configuracion.dart';

// ── Tab Diseño y Series ───────────────────────────────────────────────────────
// Gestiona: logo de empresa en PDFs + prefijos de series de numeración.
// El logo se sube a Firebase Storage: empresas/{id}/logo_pdf.jpg
// Los prefijos se escriben en el mismo doc configuracion/pdf junto con el resto.

class PdfConfigDisenoTab extends StatefulWidget {
  final PdfConfiguracion cfg;
  final void Function(PdfConfiguracion) onChanged;
  final String empresaId;

  const PdfConfigDisenoTab({
    super.key,
    required this.cfg,
    required this.onChanged,
    required this.empresaId,
  });

  @override
  State<PdfConfigDisenoTab> createState() => _State();
}

class _State extends State<PdfConfigDisenoTab> {
  static const _kPurple = Color(0xFF6D5EF8);

  // ── Prefijos ────────────────────────────────────────────────────────────────
  late final _pFac  = TextEditingController(text: widget.cfg.prefijoFactura);
  late final _pRect = TextEditingController(text: widget.cfg.prefijoRectificativa);
  late final _pPres = TextEditingController(text: widget.cfg.prefijoPresupuesto);
  late final _pPfo  = TextEditingController(text: widget.cfg.prefijoProforma);
  late final _pAlb  = TextEditingController(text: widget.cfg.prefijoAlbaran);

  // ── Logo ────────────────────────────────────────────────────────────────────
  bool _subiendoLogo = false;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _logoUrl = widget.cfg.logoUrl;
  }

  @override
  void dispose() {
    for (final c in [_pFac, _pRect, _pPres, _pPfo, _pAlb]) c.dispose();
    super.dispose();
  }

  void _notifyPrefijos() => widget.onChanged(widget.cfg.copyWith(
    prefijoFactura:        _pFac.text.trim().toUpperCase().ifEmpty('F'),
    prefijoRectificativa:  _pRect.text.trim().toUpperCase().ifEmpty('R'),
    prefijoPresupuesto:    _pPres.text.trim().toUpperCase().ifEmpty('PRES'),
    prefijoProforma:       _pPfo.text.trim().toUpperCase().ifEmpty('PF'),
    prefijoAlbaran:        _pAlb.text.trim().toUpperCase().ifEmpty('ALB'),
  ));

  // ── Subida de logo ───────────────────────────────────────────────────────────

  Future<void> _subirLogo() async {
    Uint8List? bytes;
    String? ext;

    if (kIsWeb) {
      // Web: FilePicker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      ext   = result.files.first.extension ?? 'jpg';
    } else {
      // Móvil: ImagePicker
      final picker = ImagePicker();
      final img = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
      if (img == null) return;
      bytes = await img.readAsBytes();
      ext   = img.path.split('.').last.toLowerCase();
    }

    if (bytes == null) return;
    setState(() => _subiendoLogo = true);
    try {
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final storagePath = 'empresas/${widget.empresaId}/logo_pdf.$ext';
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(bytes!, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      setState(() => _logoUrl = url);
      widget.onChanged(widget.cfg.copyWith(logoUrl: url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error subiendo logo: $e'),
              backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _eliminarLogo() async {
    setState(() => _logoUrl = null);
    widget.onChanged(widget.cfg.copyWith(logoUrl: ''));
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _section('Logo en los PDFs'),
        _buildLogoSection(),
        const SizedBox(height: 8),
        _hint('El logo aparece en la cabecera de facturas, presupuestos y albaranes. '
            'Tamaño recomendado: 300×100 px, fondo transparente (PNG) o blanco (JPG).'),
        const SizedBox(height: 24),

        _section('Series de numeración'),
        _hint('El número de factura se forma con PREFIJO-AÑO-NNNN (ej: F-2026-0042). '
            'Puedes usar letras y números. Máximo 8 caracteres.'),
        const SizedBox(height: 12),
        _buildSeriesTable(),
        const SizedBox(height: 8),
        _buildPreviewSeries(),
      ],
    );
  }

  // ── Logo ─────────────────────────────────────────────────────────────────────

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E2FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preview del logo
          Container(
            width: 110,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildLogoPreview(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_logoUrl != null && _logoUrl!.isNotEmpty) ...[
                  const Text('Logo configurado',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Color(0xFF059669), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _subiendoLogo ? null : _subirLogo,
                        icon: const Icon(Icons.image_rounded, size: 16),
                        label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kPurple,
                          side: const BorderSide(color: _kPurple),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _subiendoLogo ? null : _eliminarLogo,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ]),
                ] else ...[
                  const Text('Sin logo configurado',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Se usará solo el nombre de la empresa.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _subiendoLogo ? null : _subirLogo,
                      icon: _subiendoLogo
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_rounded, size: 16),
                      label: Text(_subiendoLogo ? 'Subiendo…' : 'Subir logo',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPurple,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (_subiendoLogo) {
      return const Center(
          child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0xFF6D5EF8))));
    }
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _logoUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
            child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined,
            color: Colors.grey),
      );
    }
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_outlined, color: Color(0xFFD1D5DB), size: 28),
        SizedBox(height: 2),
        Text('Sin logo', style: TextStyle(fontSize: 9, color: Color(0xFFD1D5DB))),
      ]),
    );
  }

  // ── Series ───────────────────────────────────────────────────────────────────

  Widget _buildSeriesTable() {
    final rows = [
      ('Factura',       _pFac,  'F',    Icons.receipt_rounded),
      ('Rectificativa', _pRect, 'R',    Icons.undo_rounded),
      ('Presupuesto',   _pPres, 'PRES', Icons.work_outline_rounded),
      ('Proforma',      _pPfo,  'PF',   Icons.description_outlined),
      ('Albarán',       _pAlb,  'ALB',  Icons.local_shipping_outlined),
    ];
    return Column(
      children: rows.map((row) {
        final (label, ctrl, def, icon) = row;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _kPurple, size: 18),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500, color: Color(0xFF374151))),
            ),
            Expanded(
              child: TextFormField(
                controller: ctrl,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _notifyPrefijos(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: def,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kPurple, width: 2),
                  ),
                ),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewSeries() {
    final year = DateTime.now().year;
    final ejemplos = [
      (_pFac.text.trim().toUpperCase().ifEmpty('F'),   'Factura'),
      (_pRect.text.trim().toUpperCase().ifEmpty('R'),  'Rectificativa'),
      (_pPres.text.trim().toUpperCase().ifEmpty('PRES'),'Presupuesto'),
      (_pPfo.text.trim().toUpperCase().ifEmpty('PF'),  'Proforma'),
      (_pAlb.text.trim().toUpperCase().ifEmpty('ALB'), 'Albarán'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF059669)),
            SizedBox(width: 6),
            Text('Vista previa de numeración',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF059669))),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ejemplos.map((e) {
              final (prefijo, label) = e;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 9,
                            color: Color(0xFF6B7280))),
                    Text('$prefijo-$year-0001',
                        style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            fontFamily: 'monospace')),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Helpers visuales ─────────────────────────────────────────────────────────

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.w700, color: _kPurple, letterSpacing: 0.3)),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(
        fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
  String? get nullIfEmpty => isEmpty ? null : this;
}
