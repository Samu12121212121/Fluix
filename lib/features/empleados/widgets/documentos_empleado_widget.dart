import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENTOS DEL EMPLEADO
// Almacena metadatos en Firestore: usuarios/{empleadoId}/documentos/{docId}
// Archivos en Storage: empleados/{empresaId}/{empleadoId}/docs/{filename}
// ─────────────────────────────────────────────────────────────────────────────

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF59E0B);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

const _categorias = [
  'Contrato',
  'Nómina',
  'DNI / Identificación',
  'Certificado',
  'Baja médica',
  'Permiso / Excedencia',
  'Formación',
  'Otro',
];

class DocumentosEmpleadoWidget extends StatefulWidget {
  final String empleadoId;
  final String empresaId;
  final String nombreEmpleado;

  const DocumentosEmpleadoWidget({
    super.key,
    required this.empleadoId,
    required this.empresaId,
    required this.nombreEmpleado,
  });

  @override
  State<DocumentosEmpleadoWidget> createState() => _DocumentosEmpleadoWidgetState();
}

class _DocumentosEmpleadoWidgetState extends State<DocumentosEmpleadoWidget> {
  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String _filtroCategoria = 'Todos';
  bool   _subiendo = false;

  CollectionReference get _col =>
      _db.collection('usuarios').doc(widget.empleadoId).collection('documentos');

  // ── Subir documento ───────────────────────────────────────────────────────

  Future<void> _subirDocumento() async {
    // 1. Elegir archivo
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'xlsx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    // 2. Elegir categoría y nombre
    String? categoria = 'Otro';
    String nombreDoc  = file.name;

    if (!mounted) return;
    final datos = await _mostrarFormularioSubida(
        nombreInicial: _sinExtension(file.name),
        categoriaInicial: categoria);
    if (datos == null) return;
    categoria = datos['categoria'] as String;
    nombreDoc = datos['nombre'] as String;

    setState(() => _subiendo = true);
    try {
      // 3. Subir a Storage
      final ext      = _extension(file.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath =
          'empleados/${widget.empresaId}/${widget.empleadoId}/docs/$fileName';
      final ref = _storage.ref(storagePath);
      final task = ref.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _contentType(ext),
          customMetadata: {
            'empleadoId': widget.empleadoId,
            'empresaId':  widget.empresaId,
            'categoria':  categoria,
          },
        ),
      );
      final snap = await task;
      final url  = await snap.ref.getDownloadURL();

      // 4. Guardar metadatos en Firestore
      await _col.add({
        'nombre':       nombreDoc.trim().isEmpty ? file.name : nombreDoc.trim(),
        'categoria':    categoria,
        'url':          url,
        'storage_path': storagePath,
        'extension':    ext,
        'tamano_bytes': file.size,
        'subido_en':    Timestamp.now(),
        'subido_por':   widget.empresaId,
      });

      if (mounted) {
        FluxToast.exito(context, 'Documento subido correctamente');
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error al subir: $e');
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<Map<String, String>?> _mostrarFormularioSubida({
    required String nombreInicial,
    required String categoriaInicial,
  }) {
    final nombreCtrl = TextEditingController(text: nombreInicial);
    String catSel    = categoriaInicial;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(children: [
            Icon(Icons.upload_file_outlined, size: 20, color: _kBlue),
            SizedBox(width: 8),
            Text('Subir documento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre del documento',
                  prefixIcon: const Icon(Icons.description_outlined, size: 17),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: catSel,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: const Icon(Icons.label_outline, size: 17),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  isDense: true,
                ),
                items: _categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setModal(() => catSel = v ?? 'Otro'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx2, {'nombre': nombreCtrl.text, 'categoria': catSel}),
              style: FilledButton.styleFrom(backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Subir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarDocumento(QueryDocumentSnapshot doc) async {
    final data  = doc.data() as Map<String, dynamic>;
    final nombre = data['nombre'] as String? ?? 'este documento';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar documento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // Eliminar de Storage
      final path = data['storage_path'] as String?;
      if (path != null && path.isNotEmpty) {
        await _storage.ref(path).delete();
      }
      // Eliminar metadatos de Firestore
      await doc.reference.delete();
      if (mounted) {
        FluxToast.error(context, 'Documento eliminado');
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error al eliminar: $e');
      }
    }
  }

  Future<void> _abrirDocumento(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        FluxToast.aviso(context, 'No se pudo abrir el documento');
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_outlined, color: _kBlue, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Documentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
                Text(widget.nombreEmpleado, style: const TextStyle(fontSize: 11, color: _kSub)),
              ])),
              if (_subiendo)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))
              else
                FilledButton.icon(
                  onPressed: _subirDocumento,
                  icon: const Icon(Icons.upload_rounded, size: 14),
                  label: const Text('Subir', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _kSub),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Filtro de categorías
          StreamBuilder<QuerySnapshot>(
            stream: _col.orderBy('subido_en', descending: true).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)));
              }
              final docs = snap.data?.docs ?? [];
              final categoriasDocs = {'Todos',
                ...docs.map((d) => (d.data() as Map)['categoria'] as String? ?? 'Otro')}.toList();

              final filtrados = _filtroCategoria == 'Todos'
                  ? docs
                  : docs.where((d) =>
                      ((d.data() as Map)['categoria'] as String? ?? '') == _filtroCategoria).toList();

              return Expanded(
                child: Column(children: [
                  // Barra de filtros
                  if (categoriasDocs.length > 1)
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: categoriasDocs.map((cat) {
                          final sel = _filtroCategoria == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, top: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _filtroCategoria = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel ? _kBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: sel ? _kBlue : _kBorder),
                                ),
                                child: Text(cat, style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: sel ? Colors.white : _kSub)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Lista
                  Expanded(
                    child: filtrados.isEmpty
                        ? _buildVacio()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _docCard(filtrados[i]),
                          ),
                  ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _docCard(QueryDocumentSnapshot doc) {
    final d        = doc.data() as Map<String, dynamic>;
    final nombre   = d['nombre']    as String? ?? 'Sin nombre';
    final cat      = d['categoria'] as String? ?? 'Otro';
    final ext      = d['extension'] as String? ?? '';
    final url      = d['url']       as String? ?? '';
    final bytes    = (d['tamano_bytes'] as num?)?.toInt() ?? 0;
    final ts       = d['subido_en'] as Timestamp?;
    final fecha    = ts != null ? _formatFecha(ts.toDate()) : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _colorExt(ext).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(ext.toUpperCase().isNotEmpty ? ext.toUpperCase() : 'DOC',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                  color: _colorExt(ext)))),
        ),
        title: Text(nombre, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600, color: _kText),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(cat, style: const TextStyle(fontSize: 9, color: _kBlue, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Text('${_formatBytes(bytes)} • $fecha',
              style: const TextStyle(fontSize: 10, color: _kSub)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (url.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 17, color: _kBlue),
              tooltip: 'Ver / Descargar',
              onPressed: () => _abrirDocumento(url),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: _kRed),
            tooltip: 'Eliminar',
            onPressed: () => _eliminarDocumento(doc),
          ),
        ]),
      ),
    );
  }

  Widget _buildVacio() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.folder_open_outlined, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 12),
      const Text('Sin documentos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 6),
      const Text('Pulsa "Subir" para añadir el primer documento',
          style: TextStyle(fontSize: 12, color: _kSub)),
    ],
  ));

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _sinExtension(String name) {
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }

  String _extension(String name) {
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(idx + 1).toLowerCase() : '';
  }

  String _contentType(String ext) {
    return switch (ext) {
      'pdf'  => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'  => 'image/png',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _      => 'application/octet-stream',
    };
  }

  Color _colorExt(String ext) => switch (ext) {
    'pdf'  => _kRed,
    'jpg' || 'jpeg' || 'png' => _kOrange,
    'docx' => _kBlue,
    'xlsx' => _kGreen,
    _      => _kSub,
  };

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
