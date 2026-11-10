import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import '../../../services/documento_firma_service.dart';
import 'firma_documento_sheet.dart';
import 'firma_zona_selector_sheet.dart';

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
  final String empresaNombre;
  /// true = embedded en un ScrollView (no usa Expanded, shrinkWrap en lista)
  final bool embedded;

  const DocumentosEmpleadoWidget({
    super.key,
    required this.empleadoId,
    required this.empresaId,
    required this.nombreEmpleado,
    this.empresaNombre = '',
    this.embedded = false,
  });

  @override
  State<DocumentosEmpleadoWidget> createState() => _DocumentosEmpleadoWidgetState();
}

class _DocumentosEmpleadoWidgetState extends State<DocumentosEmpleadoWidget> {
  final _db       = FirebaseFirestore.instance;
  final _storage  = FirebaseStorage.instance;
  final _firmaSvc = DocumentoFirmaService();

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

      // 4. Guardar metadatos en Firestore (hash SHA-256 para integridad eIDAS)
      final uid        = FirebaseAuth.instance.currentUser?.uid ?? '';
      final esEmpleado = uid == widget.empleadoId;
      final hashDoc    = DocumentoFirmaService.hashDocumento(file.bytes!);
      await _col.add({
        'nombre':           nombreDoc.trim().isEmpty ? file.name : nombreDoc.trim(),
        'categoria':        categoria,
        'url':              url,
        'storage_path':     storagePath,
        'extension':        ext,
        'tamano_bytes':     file.size,
        'subido_en':        Timestamp.now(),
        'subido_por_uid':   uid,
        'subido_por':       widget.empresaId,
        'es_de_empresa':    !esEmpleado,
        'hash_documento':   hashDoc,       // SHA-256 — integridad documental eIDAS
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
            width: double.infinity,
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

  Future<void> _solicitarFirma(String docId, String docNombre, String docUrl) async {
    if (!mounted) return;

    // 1. Selector de zona (solo si es PDF y tiene URL)
    Map<String, dynamic>? zona;
    if (docUrl.isNotEmpty) {
      zona = await FirmaZonaSelectorSheet.show(
        context,
        docUrl:    docUrl,
        docNombre: docNombre,
      );
      if (!mounted) return;
      if (zona == null) return; // usuario canceló el sheet
    } else {
      // Sin URL no se puede mostrar el selector
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Solicitar firma',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            '¿Solicitar la firma de "$docNombre" a ${widget.nombreEmpleado}?\n\n'
            'El empleado recibirá una notificación para firmarlo desde su portal.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Solicitar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    // 2. Guardar zona (si se eligió) y solicitar
    try {
      final zonaFirma = (zona != null && zona['sin_zona'] != true) ? zona : null;
      await _firmaSvc.solicitarFirma(
        empleadoId: widget.empleadoId,
        docId: docId,
        zonaFirma: zonaFirma,
      );
      if (mounted) FluxToast.exito(context, 'Firma solicitada a ${widget.nombreEmpleado}');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _cancelarFirma(String docId) async {
    try {
      await _firmaSvc.cancelarSolicitud(empleadoId: widget.empleadoId, docId: docId);
      if (mounted) FluxToast.aviso(context, 'Solicitud de firma cancelada');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _abrirFirmaSheet(QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final firmado = await FirmaDocumentoSheet.show(
      context,
      empleadoId:    widget.empleadoId,
      empresaId:     widget.empresaId,
      docId:         doc.id,
      docNombre:     d['nombre']     as String? ?? 'Documento',
      docUrl:        d['url']        as String? ?? '',
      docCategoria:  d['categoria']  as String? ?? 'Otro',
      empresaNombre: widget.empresaNombre,
    );
    if (firmado && mounted) {
      FluxToast.exito(context, 'Documento firmado');
    }
  }

  Future<void> _abrirDocumento(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || uri.host.isEmpty && !uri.isScheme('file')) {
        if (mounted) FluxToast.aviso(context, 'URL de documento no válida');
        return;
      }
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
    if (widget.embedded) return _buildEmbedded(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // Header (solo en modal, no en embedded)
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
              if (snap.hasError) {
                return Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline_rounded, size: 36, color: _kRed),
                  const SizedBox(height: 8),
                  const Text('Sin acceso a documentos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kRed)),
                  const SizedBox(height: 4),
                  Text('${snap.error}', style: const TextStyle(fontSize: 10, color: _kSub), textAlign: TextAlign.center),
                ])));
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

  // ── Versión inline (portal del empleado) ─────────────────────────────────
  Widget _buildEmbedded(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.orderBy('subido_en', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: _kBlue)),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: _kRed),
              const SizedBox(width: 8),
              const Expanded(child: Text('Sin acceso a documentos (permisos)',
                  style: TextStyle(fontSize: 12, color: _kRed))),
            ]),
          );
        }
        final docs = snap.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra upload + contador
            Row(children: [
              Text('${docs.length} documento${docs.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _kSub)),
              const Spacer(),
              if (_subiendo)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))
              else
                GestureDetector(
                  onTap: _subirDocumento,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_rounded, size: 13, color: _kBlue),
                      SizedBox(width: 4),
                      Text('Subir', style: TextStyle(fontSize: 11, color: _kBlue,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_outlined, size: 36,
                      color: _kBorder.withValues(alpha: 2.0)),
                  const SizedBox(height: 6),
                  const Text('Sin documentos', style: TextStyle(fontSize: 12, color: _kSub)),
                ])),
              )
            else
              // shrinkWrap: la lista toma su altura natural dentro del scroll
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _docCard(docs[i]),
              ),
          ],
        );
      },
    );
  }

  Widget _docCard(QueryDocumentSnapshot doc) {
    final d           = doc.data() as Map<String, dynamic>;
    final nombre      = d['nombre']       as String? ?? 'Sin nombre';
    final cat         = d['categoria']    as String? ?? 'Otro';
    final ext         = d['extension']    as String? ?? '';
    final url         = d['url']          as String? ?? '';
    final bytes       = (d['tamano_bytes'] as num?)?.toInt() ?? 0;
    final ts          = d['subido_en']    as Timestamp?;
    final fecha       = ts != null ? _formatFecha(ts.toDate()) : '';
    final esDeEmpresa = d['es_de_empresa'] as bool? ?? false;

    // Firma
    final estadoFirma = d['estado_firma'] as String?;
    final firmado     = estadoFirma == 'firmado';
    final pendiente   = estadoFirma == 'pendiente';
    final firmaFecha  = (d['firma_fecha'] as Timestamp?)?.toDate();

    // color borde: verde si firmado, naranja si pendiente, verde tenue si de empresa, gris por defecto
    final borderColor = firmado  ? _kGreen.withValues(alpha: 0.6)
                      : pendiente ? _kOrange.withValues(alpha: 0.5)
                      : esDeEmpresa ? _kGreen.withValues(alpha: 0.4)
                      : _kBorder;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
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
            subtitle: Wrap(spacing: 5, runSpacing: 3, children: [
              if (esDeEmpresa)
                _badge('Empresa', _kGreen),
              _badge(cat, _kBlue),
              if (firmado)
                _badge('✓ Firmado${firmaFecha != null ? ' ${_formatFecha(firmaFecha)}' : ''}', _kGreen),
              if (pendiente)
                _badge('Firma pendiente', _kOrange),
              Text('${_formatBytes(bytes)} • $fecha',
                  style: const TextStyle(fontSize: 10, color: _kSub)),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (url.isNotEmpty)
                IconButton(
                  icon: Icon(
                    firmado ? Icons.picture_as_pdf_rounded : Icons.open_in_new_rounded,
                    size: 17,
                    color: firmado ? _kGreen : _kBlue,
                  ),
                  tooltip: firmado ? 'Ver PDF firmado' : 'Ver documento',
                  onPressed: () => _abrirDocumento(url),
                ),
              // Certificado de firma (cuando existe)
              if (firmado && (d['certificado_url'] as String? ?? '').isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.verified_rounded, size: 17, color: _kGreen),
                  tooltip: 'Descargar certificado de firma',
                  onPressed: () => _abrirDocumento(d['certificado_url'] as String),
                ),
              // Fallback: firmado pero aún procesando PDF → mostrar PNG de la firma
              if (firmado &&
                  (d['certificado_url'] as String? ?? '').isEmpty &&
                  (d['firma_url'] as String? ?? '').isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.draw_rounded, size: 17, color: _kGreen),
                  tooltip: 'Ver imagen de la firma',
                  onPressed: () => _abrirDocumento(d['firma_url'] as String),
                ),
              // Admin: solicitar / cancelar firma
              if (!widget.embedded && esDeEmpresa && !firmado)
                IconButton(
                  icon: Icon(
                    pendiente ? Icons.cancel_outlined : Icons.draw_rounded,
                    size: 17,
                    color: pendiente ? _kOrange : _kBlue,
                  ),
                  tooltip: pendiente ? 'Cancelar solicitud' : 'Solicitar firma',
                  onPressed: pendiente
                      ? () => _cancelarFirma(doc.id)
                      : () => _solicitarFirma(doc.id, nombre, url),
                ),
              if (!esDeEmpresa)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: _kRed),
                  tooltip: 'Eliminar',
                  onPressed: () => _eliminarDocumento(doc),
                ),
            ]),
          ),
          // Empleado portal: botón "Firmar ahora" si pendiente
          if (widget.embedded && pendiente && !firmado)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _abrirFirmaSheet(doc),
                  icon: const Icon(Icons.draw_rounded, size: 15),
                  label: const Text('Firmar ahora', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kOrange,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 3),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
  );

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
