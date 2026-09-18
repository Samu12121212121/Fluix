import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

// ═════════════════════════════════════════════════════════════════════════════
// NÓMINAS DEL EMPLEADO
// Firestore: empresas/{empresaId}/nominas_empleados/{docId}
// Storage:   empresas/{empresaId}/nominas/{empleadoId}/{anio}{mes}_{file}
// ═════════════════════════════════════════════════════════════════════════════

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF59E0B);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

const _meses = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  'Paga extra 1', 'Paga extra 2',
];

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class NominasEmpleadoWidget {
  static Future<void> mostrar(
    BuildContext context, {
    required String empleadoId,
    required String empresaId,
    required String nombreEmpleado,
    bool soloLectura = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _NominasSheet(
        empleadoId:     empleadoId,
        empresaId:      empresaId,
        nombreEmpleado: nombreEmpleado,
        soloLectura:    soloLectura,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _NominasSheet extends StatefulWidget {
  final String empleadoId;
  final String empresaId;
  final String nombreEmpleado;
  final bool   soloLectura;

  const _NominasSheet({
    required this.empleadoId,
    required this.empresaId,
    required this.nombreEmpleado,
    required this.soloLectura,
  });

  @override
  State<_NominasSheet> createState() => _NominasSheetState();
}

class _NominasSheetState extends State<_NominasSheet> {
  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  bool _subiendo = false;
  int  _anioFiltro = DateTime.now().year;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('empresas').doc(widget.empresaId)
          .collection('nominas_empleados');

  // ── Subir ─────────────────────────────────────────────────────────────────
  Future<void> _subirNomina() async {
    final params = await _mostrarDialogoSubida();
    if (params == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _subiendo = true);
    try {
      final mes      = params['mes']  as int;
      final anio     = params['anio'] as int;
      final ext      = file.name.split('.').last.toLowerCase();
      final fileName = '${anio}${mes.toString().padLeft(2,'0')}_${file.name}';
      final storagePath =
          'empresas/${widget.empresaId}/nominas/${widget.empleadoId}/$fileName';

      final ref  = _storage.ref(storagePath);
      final snap = await ref.putData(
        file.bytes!,
        SettableMetadata(
          contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
          customMetadata: {
            'empleadoId': widget.empleadoId,
            'empresaId':  widget.empresaId,
            'mes':        '$mes',
            'anio':       '$anio',
          },
        ),
      );
      final url = await snap.ref.getDownloadURL();

      await _col.add({
        'empleado_id':    widget.empleadoId,
        'mes':            mes,
        'anio':           anio,
        'url':            url,
        'storage_path':   storagePath,
        'nombre_archivo': file.name,
        'extension':      ext,
        'tamano_bytes':   file.size,
        'importe_neto':   params['importe_neto'],
        'subido_en':      Timestamp.now(),
        'subido_por':     FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      if (mounted) {
        FluxToast.exito(context, 'Nómina de ${_meses[mes]} $anio subida');
        setState(() => _anioFiltro = anio);
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al subir: $e');
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<Map<String, dynamic>?> _mostrarDialogoSubida() {
    int mesSelec  = DateTime.now().month;
    int anioSelec = DateTime.now().year;
    final importeCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: const BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload_file_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Subir nómina', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Selecciona el período primero',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ])),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  // Info formatos
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: _kBlue),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Formatos admitidos: PDF, JPG, PNG · Máx. 20 MB',
                        style: TextStyle(fontSize: 11, color: _kBlue),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: mesSelec,
                    decoration: _inputDeco('Mes', Icons.calendar_month_rounded),
                    items: List.generate(14, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m,
                            child: Text(_meses[m],
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setModal(() => mesSelec = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: anioSelec,
                    decoration: _inputDeco('Año', Icons.event_rounded),
                    items: List.generate(5, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(value: y,
                            child: Text('$y',
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setModal(() => anioSelec = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: importeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration:
                        _inputDeco('Importe neto (€) — opcional', Icons.euro_rounded),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, {
                      'mes':         mesSelec,
                      'anio':        anioSelec,
                      'importe_neto': double.tryParse(importeCtrl.text.trim()),
                    }),
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Elegir archivo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────
  Future<void> _eliminar(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d     = doc.data();
    final mes   = (d['mes'] as int? ?? 1).clamp(1, 14);
    final anio  = d['anio'] as int? ?? 0;
    final label = '${_meses[mes]} $anio';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar nómina'),
        content: Text('¿Eliminar la nómina de $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final path = d['storage_path'] as String?;
      if (path != null && path.isNotEmpty) {
        await _storage.ref(path).delete();
      }
      await doc.reference.delete();
      if (mounted) FluxToast.aviso(context, 'Nómina eliminada');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al eliminar: $e');
    }
  }

  // ── Stream filtrado client-side — sin orderBy para evitar índice compuesto
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get _streamNominas =>
      _col
          .where('empleado_id', isEqualTo: widget.empleadoId)
          .snapshots()
          .map((s) {
            final filtradas = s.docs
                .where((d) => d.data()['anio'] == _anioFiltro)
                .toList();
            filtradas.sort((a, b) {
              final ma = a.data()['mes'] as int? ?? 0;
              final mb = b.data()['mes'] as int? ?? 0;
              return mb.compareTo(ma); // descendente
            });
            return filtradas;
          });

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            )),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: _kGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nóminas', style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold, color: _kText)),
                Text(widget.nombreEmpleado,
                    style: const TextStyle(fontSize: 11, color: _kSub)),
              ])),
              _buildAnioSelector(),
              if (!widget.soloLectura) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _subiendo ? null : _subirNomina,
                  icon: _subiendo
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.upload_rounded, size: 15),
                  label: const Text('Subir', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, size: 18, color: _kSub),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
          // Lista
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String,dynamic>>>>(
              stream: _streamNominas,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kGreen));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}',
                      style: const TextStyle(color: _kRed, fontSize: 12)));
                }
                final docs = snap.data ?? [];
                if (docs.isEmpty) return _buildVacio();
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildCard(docs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAnioSelector() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anioFiltro,
          style: const TextStyle(fontSize: 12, color: _kText),
          icon: const Icon(Icons.arrow_drop_down, size: 16, color: _kSub),
          items: List.generate(5, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (v) => setState(() => _anioFiltro = v!),
        ),
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d           = doc.data();
    final mes         = (d['mes'] as int? ?? 1).clamp(1, 14);
    final anio        = d['anio'] as int? ?? 0;
    final url         = d['url'] as String? ?? '';
    final nombre      = d['nombre_archivo'] as String? ?? '';
    final importeNeto = d['importe_neto'] as double?;
    final ext         = (d['extension'] as String? ?? 'pdf').toLowerCase();
    final bytes       = d['tamano_bytes'] as int? ?? 0;
    final subidoEn    = (d['subido_en'] as Timestamp?)?.toDate();
    final fechaStr    = subidoEn != null
        ? '${subidoEn.day.toString().padLeft(2,'0')}/'
          '${subidoEn.month.toString().padLeft(2,'0')}/${subidoEn.year}'
        : '';
    final isPdf       = ext == 'pdf';
    final sizeStr     = bytes > 0 ? _formatBytes(bytes) : '';

    return GestureDetector(
      onTap: url.isNotEmpty
          ? () => _abrirVisor(context, url: url, ext: ext,
              titulo: '${_meses[mes]} $anio', nombre: nombre)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(children: [
          // Preview superior
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: _buildPreview(url, ext, isPdf),
          ),

          // Info inferior
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(child: Text('${_meses[mes]} $anio',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: _kText))),
                if (importeNeto != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${importeNeto.toStringAsFixed(2)} €',
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: _kGreen),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(isPdf ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                    size: 12, color: isPdf ? _kRed : _kBlue),
                const SizedBox(width: 4),
                Text(isPdf ? 'PDF' : ext.toUpperCase(),
                    style: TextStyle(fontSize: 10,
                        color: isPdf ? _kRed : _kBlue,
                        fontWeight: FontWeight.w600)),
                if (sizeStr.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(fontSize: 10, color: _kSub)),
                  Text(sizeStr, style: const TextStyle(
                      fontSize: 10, color: _kSub)),
                ],
                if (fechaStr.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(fontSize: 10, color: _kSub)),
                  Text('Subida el $fechaStr',
                      style: const TextStyle(fontSize: 10, color: _kSub)),
                ],
              ]),
              if (nombre.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(nombre, style: const TextStyle(fontSize: 10, color: _kSub),
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              // Botones acción
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: url.isNotEmpty
                      ? () => _abrirVisor(context, url: url, ext: ext,
                          titulo: '${_meses[mes]} $anio', nombre: nombre)
                      : null,
                  icon: const Icon(Icons.visibility_rounded, size: 14),
                  label: const Text('Ver', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    side: BorderSide(color: _kBlue.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )),
                if (!widget.soloLectura) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _eliminar(doc),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Eliminar',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: BorderSide(color: _kRed.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // Miniatura de previsualización en la tarjeta
  Widget _buildPreview(String url, String ext, bool isPdf) {
    if (!isPdf && url.isNotEmpty) {
      return SizedBox(
        height: 120,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: _kBg,
            child: const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: _kBlue)),
          ),
          errorWidget: (_, __, ___) => _pdfPlaceholder(),
        ),
      );
    }
    return _pdfPlaceholder();
  }

  Widget _pdfPlaceholder() => Container(
        height: 100,
        color: const Color(0xFFFFF1F0),
        child: const Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: _kRed, size: 32),
            SizedBox(width: 10),
            Text('Documento PDF', style: TextStyle(
                color: _kRed, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
      );

  Widget _buildVacio() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No hay nóminas en $_anioFiltro',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 4),
          if (!widget.soloLectura)
            Text('Pulsa "Subir" para añadir la primera',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ]),
      );

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abre el visor correcto según tipo y plataforma
// ─────────────────────────────────────────────────────────────────────────────
void _abrirVisor(
  BuildContext context, {
  required String url,
  required String ext,
  required String titulo,
  required String nombre,
}) {
  final isPdf   = ext == 'pdf';
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (!isPdf) {
    // Imagen: photo_view en pantalla completa
    Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
        _VisorImagen(url: url, titulo: titulo)));
    return;
  }

  if (isPdf && isMobile) {
    // PDF en móvil: descargar + flutter_pdfview
    Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
        _VisorPDF(url: url, titulo: titulo, nombre: nombre)));
    return;
  }

  // PDF en desktop/web: abrir con sistema
  _abrirExterno(context, url);
}

Future<void> _abrirExterno(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    if (context.mounted) {
      FluxToast.error(context, 'No se pudo abrir el archivo');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visor de imágenes — photo_view con pinch-to-zoom
// ─────────────────────────────────────────────────────────────────────────────
class _VisorImagen extends StatelessWidget {
  final String url;
  final String titulo;
  const _VisorImagen({required this.url, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(titulo,
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'Abrir en navegador',
            onPressed: () => _abrirExterno(context, url),
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, event) => Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
          ),
        ),
        errorBuilder: (_, __, ___) => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text('No se pudo cargar la imagen',
                style: TextStyle(color: Colors.white54)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visor de PDF (móvil) — descarga + flutter_pdfview
// ─────────────────────────────────────────────────────────────────────────────
class _VisorPDF extends StatefulWidget {
  final String url;
  final String titulo;
  final String nombre;
  const _VisorPDF(
      {required this.url, required this.titulo, required this.nombre});

  @override
  State<_VisorPDF> createState() => _VisorPDFState();
}

class _VisorPDFState extends State<_VisorPDF> {
  String? _localPath;
  String? _error;
  double  _progreso = 0;
  int     _paginas  = 0;
  int     _paginaActual = 0;

  @override
  void initState() {
    super.initState();
    _descargar();
  }

  Future<void> _descargar() async {
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/${widget.nombre.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      await Dio().download(
        widget.url, path,
        onReceiveProgress: (r, t) {
          if (mounted && t > 0) setState(() => _progreso = r / t);
        },
      );
      if (mounted) setState(() => _localPath = path);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.titulo,
              style: const TextStyle(fontSize: 15, color: Colors.white)),
          if (_paginas > 0)
            Text('Pág. ${_paginaActual + 1} de $_paginas',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'Abrir en navegador',
            onPressed: () => _abrirExterno(context, widget.url),
          ),
        ],
      ),
      body: _error != null
          ? _buildError()
          : _localPath == null
              ? _buildDescargando()
              : _buildPDF(),
    );
  }

  Widget _buildDescargando() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(
              value: _progreso > 0 ? _progreso : null,
              strokeWidth: 4,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _progreso > 0
                ? 'Cargando… ${(_progreso * 100).toStringAsFixed(0)}%'
                : 'Preparando documento…',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ]),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: _kRed, size: 48),
          const SizedBox(height: 12),
          const Text('No se pudo cargar el PDF',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _abrirExterno(context, widget.url),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Abrir en navegador'),
            style: FilledButton.styleFrom(backgroundColor: _kBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ]),
      );

  Widget _buildPDF() => PDFView(
        filePath: _localPath!,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        fitEachPage: true,
        onRender: (pages) {
          if (mounted) setState(() => _paginas = pages ?? 0);
        },
        onPageChanged: (page, _) {
          if (mounted) setState(() => _paginaActual = page ?? 0);
        },
        onError: (e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper deco campos
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: _kBlue),
      labelStyle: const TextStyle(fontSize: 13, color: _kSub),
      filled: true, fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 2)),
      isDense: true,
    );
