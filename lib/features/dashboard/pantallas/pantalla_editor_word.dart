import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Editor Word — WYSIWYG, lo que escribes es lo que se publica
// ─────────────────────────────────────────────────────────────────────────────

class PantallaEditorWord extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final EntradaBlog? entrada;
  final List<CategoriaBlog> categorias;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const PantallaEditorWord({
    super.key,
    required this.empresaId,
    required this.svc,
    required this.categorias,
    this.entrada,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<PantallaEditorWord> createState() => _PantallaEditorWordState();
}

class _PantallaEditorWordState extends State<PantallaEditorWord> {
  // ── Controladores ────────────────────────────────────────────────────────
  final _scrollCtrl       = ScrollController();
  final _editorScrollCtrl = ScrollController();
  final _editorFocusNode  = FocusNode();
  final _tituloCtrl   = TextEditingController();
  final _resumenCtrl  = TextEditingController();
  final _autorCtrl    = TextEditingController();
  final _slugCtrl     = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  late final QuillController _quillCtrl;

  // ── Estado ───────────────────────────────────────────────────────────────
  String?      _imagenUrl;
  List<String> _etiquetas        = [];
  EstadoBlog   _estado           = EstadoBlog.borrador;
  String       _categoriaId      = '';
  String       _tipo             = 'articulo';
  DateTime     _fechaPublicacion = DateTime.now();
  String?      _autorId;
  String?      _libroId;
  bool         _preview          = false;
  bool         _guardando        = false;
  bool         _subiendoImg      = false;
  bool         _slugManual       = false;
  bool         _slugOk           = true;
  Timer?       _slugTimer;
  Timer?       _autoguardadoTimer;
  DateTime?    _ultimoAutoguardado;
  bool         _autoguardadoPendiente = false;

  bool get _esNuevo => widget.entrada == null || widget.entrada!.id.isEmpty;
  int  get _palabras {
    final txt = _quillCtrl.document.toPlainText().trim();
    return txt.isEmpty ? 0 : txt.split(RegExp(r'\s+')).length;
  }
  int get _minLectura => (_palabras / 200).ceil().clamp(1, 99);

  // ═══════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _quillCtrl = _inicializarQuill(widget.entrada?.contenido);

    if (widget.entrada != null) {
      final e = widget.entrada!;
      _tituloCtrl.text  = e.titulo;
      _slugCtrl.text    = e.slug;
      _resumenCtrl.text = e.resumen;
      _autorCtrl.text   = e.autor;
      _etiquetas         = List.from(e.etiquetas);
      _imagenUrl         = e.imagenUrl;
      _videoUrlCtrl.text = e.videoUrl ?? '';
      _estado            = e.estado;
      _categoriaId      = e.categoriaId;
      _autorId           = e.autorId;
      _libroId           = e.libroId;
      _tipo             = e.tipo.isEmpty ? 'articulo' : e.tipo;
      _fechaPublicacion = e.fechaPublicacion;
      _slugManual       = e.slug.isNotEmpty;
    }

    _tituloCtrl.addListener(_onTituloChanged);
    _slugCtrl.addListener(_onSlugChanged);
    _quillCtrl.addListener(() {
      if (mounted) {
        setState(() { _autoguardadoPendiente = true; });
      }
    });
    // Autoguardado silencioso cada 45 segundos si hay cambios
    _autoguardadoTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _autoguardadoPendiente && _tituloCtrl.text.trim().isNotEmpty) {
        _autoguardar();
      }
    });
  }

  QuillController _inicializarQuill(String? contenido) {
    if (contenido == null || contenido.trim().isEmpty) {
      return QuillController.basic();
    }
    // Intentar cargar como Delta JSON (artículos guardados con Quill)
    try {
      final json = jsonDecode(contenido);
      if (json is List) {
        final doc = Document.fromJson(json);
        return QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {}
    // Fallback: convertir HTML o Markdown a texto plano legible
    final plain = _contenidoToPlainText(contenido);
    final doc = Document();
    if (plain.isNotEmpty) doc.insert(0, plain);
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  static String _contenidoToPlainText(String input) {
    // Si parece HTML, convertir etiquetas a saltos de línea y eliminar tags
    if (input.contains('<')) {
      return input
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>',   caseSensitive: false), '')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>',      caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</li>',     caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</div>',    caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</blockquote>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;',  '&')
          .replaceAll('&lt;',   '<')
          .replaceAll('&gt;',   '>')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;',  "'")
          .replaceAll('&apos;', "'")
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    // Si parece Markdown, limpiar marcadores
    return input
        .replaceAll('**', '')
        .replaceAll(RegExp(r'(?<!\w)_(?!\w)'), '')
        .replaceAll(RegExp(r'^#{1,3} ', multiLine: true), '')
        .replaceAll(RegExp(r'^> ', multiLine: true), '')
        .replaceAll(RegExp(r'^- ', multiLine: true), '')
        .replaceAll('---', '')
        .trim();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _editorScrollCtrl.dispose();
    _editorFocusNode.dispose();
    _tituloCtrl.dispose();
    _resumenCtrl.dispose();
    _autorCtrl.dispose();
    _slugCtrl.dispose();
    _etiquetaCtrl.dispose();
    _videoUrlCtrl.dispose();
    _quillCtrl.dispose();
    _slugTimer?.cancel();
    _autoguardadoTimer?.cancel();
    super.dispose();
  }

  void _onTituloChanged() {
    if (!_slugManual) {
      final s = widget.svc.slugFromTituloPublic(_tituloCtrl.text);
      if (_slugCtrl.text != s) _slugCtrl.text = s;
    }
    if (mounted) setState(() {});
  }

  void _onSlugChanged() {
    _slugTimer?.cancel();
    _slugTimer = Timer(const Duration(milliseconds: 600), () async {
      if (_slugCtrl.text.isEmpty) return;
      final ok = await widget.svc.slugDisponible(
          widget.empresaId, _slugCtrl.text,
          excludeId: widget.entrada?.id);
      if (mounted) setState(() => _slugOk = ok);
    });
  }

  // ── Imagen ───────────────────────────────────────────────────────────────

  Future<void> _subirPortada() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'blog/portadas');
    if (mounted) setState(() { _imagenUrl = url; _subiendoImg = false; });
  }

  Future<void> _insertarImagenEnContenido() async {
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'blog/imagenes');
    if (url != null && mounted) {
      final idx = _quillCtrl.selection.baseOffset;
      _quillCtrl.document.insert(idx, BlockEmbed.image(url));
    }
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _autoguardar() async {
    if (_guardando) return;
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) return;
    try {
      final deltaJson = jsonEncode(_quillCtrl.document.toDelta().toJson());
      final entrada = EntradaBlog(
        id:               widget.entrada?.id ?? '',
        titulo:           titulo,
        slug:             _slugCtrl.text.trim(),
        resumen:          _resumenCtrl.text.trim(),
        contenido:        deltaJson,
        imagenUrl:        _imagenUrl,
        estado:           _estado == EstadoBlog.publicado ? EstadoBlog.publicado : EstadoBlog.borrador,
        fechaPublicacion: _fechaPublicacion,
        etiquetas:        _etiquetas,
        autor:            _autorCtrl.text.trim(),
        categoriaId:      _categoriaId,
        tipo:             _tipo,
        destacado:        widget.entrada?.destacado ?? false,
        videoUrl:         _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
        visitas:          widget.entrada?.visitas ?? 0,
        autorId:          _autorId,
        libroId:          _libroId,
      );
      await widget.svc.guardarEntradaBlog(widget.empresaId, entrada);
      if (mounted) setState(() {
        _autoguardadoPendiente = false;
        _ultimoAutoguardado = DateTime.now();
      });
    } catch (_) {} // silencioso
  }

  Future<void> _guardar(BuildContext context, {bool publicar = false}) async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El artículo necesita un título'),
          backgroundColor: Colors.red));
      return;
    }
    if (publicar) setState(() => _estado = EstadoBlog.publicado);
    setState(() => _guardando = true);

    // Serializar Quill Delta como JSON → almacenar en contenido
    final deltaJson = jsonEncode(_quillCtrl.document.toDelta().toJson());
    final videoUrl  = _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim();
    // Convertir a HTML para la web, auto-enlazando referencias al vídeo
    final rawHtml = _deltaToHtml(_quillCtrl.document.toDelta().toJson());
    final html = _autoLinkVideo(rawHtml, videoUrl);

    try {
      final entrada = EntradaBlog(
        id:               widget.entrada?.id ?? '',
        titulo:           titulo,
        slug:             _slugCtrl.text.trim(),
        resumen:          _resumenCtrl.text.trim(),
        contenido:        deltaJson,
        imagenUrl:        _imagenUrl,
        estado:           _estado,
        fechaPublicacion: _fechaPublicacion,
        etiquetas:        _etiquetas,
        autor:            _autorCtrl.text.trim(),
        categoriaId:      _categoriaId,
        tipo:             _tipo,
        destacado:        widget.entrada?.destacado ?? false,
        visitas:          widget.entrada?.visitas ?? 0,
        videoUrl:         videoUrl,
        autorId:          _autorId,
        libroId:          _libroId,
      );
      await widget.svc.guardarEntradaBlog(widget.empresaId, entrada);
      // Guardar también el HTML pre-renderizado para la web
      await widget.svc.actualizarCamposExtra(widget.empresaId, entrada.id.isEmpty
          ? '' : entrada.id, {'contenido_html': html});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_estado == EstadoBlog.publicado
              ? '✅ Publicado — visible en la web en breve'
              : '✅ Borrador guardado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onGuardado?.call();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Delta → HTML (para web, sin dependencias externas) ──────────────────

  static String _deltaToHtml(List<dynamic> ops) {
    final buf        = StringBuffer();
    final lineBuf    = StringBuffer();
    bool  inUl       = false;
    bool  inOl       = false;

    void flushLine(Map<String, dynamic>? blockAttrs) {
      final content = lineBuf.toString();
      lineBuf.clear();
      final header    = blockAttrs?['header'];
      final listType  = blockAttrs?['list'];
      final blockquote = blockAttrs?['blockquote'];

      if (listType == 'bullet') {
        if (!inUl) { if (inOl) { buf.write('</ol>'); inOl = false; } buf.write('<ul>'); inUl = true; }
        buf.write('<li>$content</li>');
      } else if (listType == 'ordered') {
        if (!inOl) { if (inUl) { buf.write('</ul>'); inUl = false; } buf.write('<ol>'); inOl = true; }
        buf.write('<li>$content</li>');
      } else {
        if (inUl) { buf.write('</ul>'); inUl = false; }
        if (inOl) { buf.write('</ol>'); inOl = false; }
        if (header == 1)       buf.write('<h1 style="font-size:2em;font-weight:800;margin:1em 0 .4em">$content</h1>');
        else if (header == 2)  buf.write('<h2 style="font-size:1.5em;font-weight:700;margin:.9em 0 .35em">$content</h2>');
        else if (header == 3)  buf.write('<h3 style="font-size:1.2em;font-weight:600;margin:.8em 0 .3em">$content</h3>');
        else if (blockquote == true)
          buf.write('<blockquote style="border-left:3px solid #d1d5db;padding:8px 16px;color:#6b7280;margin:12px 0;font-style:italic">$content</blockquote>');
        else if (content.isNotEmpty)
          buf.write('<p style="margin:0 0 1.4em;line-height:1.8">$content</p>');
      }
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs  = (op['attributes'] as Map?)?.cast<String, dynamic>();

      if (insert is Map) {
        // Imágenes embebidas
        final img = insert['image'];
        if (img != null) lineBuf.write('<img src="$img" style="max-width:100%;border-radius:6px;margin:8px 0">');
        continue;
      }
      if (insert is! String) continue;

      if (insert == '\n') {
        flushLine(attrs);
      } else {
        var text = insert.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
        if (attrs?['bold']      == true) text = '<strong>$text</strong>';
        if (attrs?['italic']    == true) text = '<em>$text</em>';
        if (attrs?['strike']    == true) text = '<del>$text</del>';
        if (attrs?['underline'] == true) text = '<u>$text</u>';
        if (attrs?['code']      == true)
          text = '<code style="background:#f3f4f6;padding:2px 5px;border-radius:3px;font-size:.9em">$text</code>';
        final link = attrs?['link'];
        if (link != null) text = '<a href="$link" target="_blank">$text</a>';
        lineBuf.write(text);
      }
    }
    // Vaciar buffer restante
    flushLine(null);
    if (inUl) buf.write('</ul>');
    if (inOl) buf.write('</ol>');
    return buf.toString();
  }

  // Reemplaza frases tipo "podéis ver el vídeo aquí" con un <a> al videoUrl
  static String _autoLinkVideo(String html, String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return html;
    const _patrones = [
      'podéis ver el vídeo aquí',
      'podeis ver el video aqui',
      'podéis ver el video aquí',
      'ver el vídeo aquí',
      'ver el video aquí',
      'ver el video aqui',
      'ver el vídeo',
      'ver el video',
      '(ver vídeo)',
      '(ver video)',
    ];
    var result = html;
    for (final p in _patrones) {
      result = result.replaceAllMapped(
        RegExp(RegExp.escape(p), caseSensitive: false),
        (m) {
          final matched = m.group(0)!;
          // No doble-enlazar si ya está dentro de <a
          final start = result.lastIndexOf('<a ', m.start);
          final close = result.lastIndexOf('</a>', m.start);
          if (start > close) return matched; // ya dentro de un <a>
          return '<a href="$videoUrl" target="_blank" rel="noopener">$matched</a>';
        },
      );
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    final body = Column(children: [
      _topBar(context, color),
      _toolbar(color),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: _preview ? _buildPreview() : _buildPagina(color),
      ),
      _statusBar(color),
    ]);

    if (widget.onGuardado != null || widget.onCancelar != null) {
      return LayoutBuilder(builder: (_, c) {
        final h = c.maxHeight.isInfinite ? null : c.maxHeight;
        return SizedBox(width: double.infinity, height: h,
            child: ColoredBox(color: const Color(0xFFF0F2F5), child: body));
      });
    }
    return Scaffold(backgroundColor: const Color(0xFFF0F2F5), body: body);
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _topBar(BuildContext context, Color color) {
    final titulo = _tituloCtrl.text.trim();
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onCancelar ?? () => Navigator.pop(context),
          child: const Row(children: [
            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF6B7280)),
            SizedBox(width: 4),
            Text('Blog', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 15, color: Color(0xFFD1D5DB))),
        Expanded(
          child: Text(titulo.isEmpty ? (_esNuevo ? 'Nuevo artículo' : 'Sin título') : titulo,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis),
        ),
        _estadoBadge(),
        const SizedBox(width: 8),
        _barBtn(
          icon: _preview ? Icons.edit_note_rounded : Icons.visibility_outlined,
          label: _preview ? 'Editar' : 'Preview',
          onTap: () => setState(() => _preview = !_preview),
        ),
        const SizedBox(width: 6),
        _barBtn(
          icon: Icons.tune_rounded,
          label: 'Configurar',
          onTap: () => _mostrarConfiguracion(context, color),
        ),
        const SizedBox(width: 8),
        _publishButton(context, color),
      ]),
    );
  }

  Widget _estadoBadge() {
    final (bg, fg, label) = switch (_estado) {
      EstadoBlog.publicado  => (const Color(0xFFDCFCE7), const Color(0xFF059669), 'Publicado'),
      EstadoBlog.programado => (const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'Programado'),
      _                     => (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Borrador'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _barBtn({required IconData icon, required String label, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: const Color(0xFF374151)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151))),
          ]),
        ),
      );

  Widget _publishButton(BuildContext context, Color color) =>
      PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'publicar') _guardar(context, publicar: true);
          if (v == 'borrador') _guardar(context);
          if (v == 'programar') {
            final fecha = await showDatePicker(
              context: context,
              initialDate: _fechaPublicacion.isAfter(DateTime.now())
                  ? _fechaPublicacion
                  : DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: 'Fecha de publicación programada',
            );
            if (fecha != null && mounted) {
              setState(() {
                _fechaPublicacion = fecha;
                _estado = EstadoBlog.programado;
              });
              _guardar(context);
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'publicar', child: Row(children: [
            const Icon(Icons.publish_rounded, size: 15, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            const Text('Publicar ahora',
                style: TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
          ])),
          PopupMenuItem(value: 'programar', child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Text('Programar publicación',
                style: TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
          ])),
          PopupMenuItem(value: 'borrador', child: Row(children: [
            const Icon(Icons.save_outlined, size: 15, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            const Text('Guardar borrador', style: TextStyle(fontSize: 13)),
          ])),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_guardando)
              const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.publish_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(_estado == EstadoBlog.publicado ? 'Actualizar' : 'Publicar',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ]),
        ),
      );

  // ── Toolbar WYSIWYG ───────────────────────────────────────────────────────

  Widget _toolbar(Color color) => Container(
    height: 36,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        // Tipo de bloque
        PopupMenuButton<String>(
          tooltip: 'Tipo de bloque',
          onSelected: (tipo) {
            final a = switch (tipo) {
              'Título 1' => Attribute.h1,
              'Título 2' => Attribute.h2,
              'Título 3' => Attribute.h3,
              _          => Attribute.header,
            };
            if (tipo == 'Párrafo') {
              _quillCtrl.formatSelection(Attribute.clone(Attribute.header, null));
            } else {
              _quillCtrl.formatSelection(a);
            }
          },
          itemBuilder: (_) => ['Párrafo','Título 1','Título 2','Título 3']
              .map((t) => PopupMenuItem(value: t,
                  child: Text(t, style: const TextStyle(fontSize: 13))))
              .toList(),
          child: _dropBtn('Párrafo'),
        ),
        _vsep(),
        _tb(Icons.format_bold,          'Negrita',         () => _quillCtrl.formatSelection(Attribute.bold)),
        _tb(Icons.format_italic,        'Cursiva',         () => _quillCtrl.formatSelection(Attribute.italic)),
        _tb(Icons.format_strikethrough, 'Tachado',         () => _quillCtrl.formatSelection(Attribute.strikeThrough)),
        _tb(Icons.format_underline,     'Subrayado',       () => _quillCtrl.formatSelection(Attribute.underline)),
        _vsep(),
        _tb(Icons.format_quote,         'Cita',            () => _quillCtrl.formatSelection(Attribute.blockQuote)),
        _tb(Icons.format_list_bulleted, 'Lista viñetas',   () => _quillCtrl.formatSelection(Attribute.ul)),
        _tb(Icons.format_list_numbered, 'Lista numerada',  () => _quillCtrl.formatSelection(Attribute.ol)),
        _vsep(),
        Builder(builder: (ctx) =>
            _tb(Icons.link_rounded,     'Insertar enlace', () => _mostrarDialogoEnlace(ctx))),
        _tb(Icons.add_photo_alternate_outlined, 'Insertar imagen', _insertarImagenEnContenido),
        _vsep(),
        _tb(Icons.undo_rounded, 'Deshacer', () => _quillCtrl.undo()),
        _tb(Icons.redo_rounded, 'Rehacer',  () => _quillCtrl.redo()),
      ]),
    ),
  );

  Widget _vsep() => Container(width: 1, height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE5E7EB));

  Widget _tb(IconData icon, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: fn,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Icon(icon, size: 17, color: const Color(0xFF374151)),
      ),
    ),
  );

  Widget _dropBtn(String label) => Container(
    margin: const EdgeInsets.only(right: 2),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
      const SizedBox(width: 3),
      const Icon(Icons.arrow_drop_down, size: 13, color: Color(0xFF9CA3AF)),
    ]),
  );

  // ── Página de escritura (estilo Word) ─────────────────────────────────────

  Widget _buildPagina(Color color) => SingleChildScrollView(
    controller: _scrollCtrl,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 36, 48, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 1. Meta row (tipo · autor · fecha)
              _metaRow(color),
              const SizedBox(height: 20),
              // 2. Título — primero, como en Nazarí
              TextField(
                controller: _tituloCtrl,
                maxLines: null,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                    height: 1.2, color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.zero,
                  hintText: 'Título del artículo',
                  hintStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                      height: 1.2, color: Color(0xFFE5E7EB)),
                ),
              ),
              const SizedBox(height: 10),
              // 3. Subtítulo / resumen
              TextField(
                controller: _resumenCtrl,
                maxLines: null,
                style: const TextStyle(fontSize: 16, height: 1.6,
                    color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
                decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.zero,
                  hintText: 'Añade un subtítulo o resumen breve…',
                  hintStyle: TextStyle(fontSize: 16, height: 1.6,
                      color: Color(0xFFE5E7EB), fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 20),
              // 4. Imagen de portada — después del título
              _portadaWidget(color),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 28),
              // 5. Contenido WYSIWYG (Quill)
              // GestureDetector asegura que el foco llega al editor en Windows desktop
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (!_editorFocusNode.hasFocus) {
                    _editorFocusNode.requestFocus();
                  }
                },
                child: QuillEditor(
                  controller: _quillCtrl,
                  scrollController: _editorScrollCtrl,
                  focusNode: _editorFocusNode,
                  config: const QuillEditorConfig(
                    scrollable: false,
                    autoFocus: false,
                    expands: false,
                    padding: EdgeInsets.zero,
                    placeholder: 'Empieza a escribir...',
                    enableInteractiveSelection: true,
                    detectWordBoundary: true,
                    customStyles: DefaultStyles(
                      paragraph: DefaultTextBlockStyle(
                        TextStyle(fontSize: 16, height: 1.9, color: Color(0xFF1F2937)),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(0, 12),
                        VerticalSpacing(0, 0),
                        null,
                      ),
                      h1: DefaultTextBlockStyle(
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(12, 6),
                        VerticalSpacing(0, 0),
                        null,
                      ),
                      h2: DefaultTextBlockStyle(
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(10, 5),
                        VerticalSpacing(0, 0),
                        null,
                      ),
                      h3: DefaultTextBlockStyle(
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        HorizontalSpacing(0, 0),
                        VerticalSpacing(8, 4),
                        VerticalSpacing(0, 0),
                        null,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _portadaWidget(Color color) {
    if (_imagenUrl != null) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(_imagenUrl!, height: 200,
              width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(top: 8, right: 8,
          child: Row(children: [
            _portadaBtn(Icons.swap_horiz_rounded, _subirPortada),
            const SizedBox(width: 6),
            _portadaBtn(Icons.close_rounded, () => setState(() => _imagenUrl = null)),
          ]),
        ),
      ]);
    }
    return GestureDetector(
      onTap: _subiendoImg ? null : _subirPortada,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: _subiendoImg
            ? Center(child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, size: 17,
                    color: color.withValues(alpha: 0.45)),
                const SizedBox(width: 8),
                Text('Añadir imagen de portada',
                    style: TextStyle(fontSize: 12,
                        color: color.withValues(alpha: 0.55))),
              ]),
      ),
    );
  }

  Widget _portadaBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 14, color: Colors.white),
    ),
  );

  Widget _metaRow(Color color) {
    const tipoLabels = {
      'articulo':'Artículo','noticia':'Noticia','entrevista':'Entrevista','resena':'Reseña',
    };
    final fecha = '${_fechaPublicacion.day} ${_mesLabel(_fechaPublicacion.month)} ${_fechaPublicacion.year}';
    return Wrap(children: [
      Text((tipoLabels[_tipo] ?? 'Artículo').toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: .6)),
      if (_autorCtrl.text.isNotEmpty) ...[
        Text('  ·  ', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        Text(_autorCtrl.text, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ],
      Text('  ·  ', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      Text(fecha, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
    ]);
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    final deltaOps = _quillCtrl.document.toDelta().toJson();
    final html     = _deltaToHtml(deltaOps);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _metaRow(context.read<AppConfigProvider>().colorPrimario),
                const SizedBox(height: 20),
                if (_tituloCtrl.text.isNotEmpty)
                  Text(_tituloCtrl.text,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                          height: 1.2, color: Color(0xFF111827))),
                if (_resumenCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_resumenCtrl.text,
                      style: const TextStyle(fontSize: 16, height: 1.6,
                          color: Color(0xFF6B7280), fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 20),
                if (_imagenUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(_imagenUrl!, height: 200,
                        width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 28),
                // Vista previa del contenido renderizado
                QuillEditor(
                  controller: _quillCtrl,
                  scrollController: _editorScrollCtrl,
                  focusNode: _editorFocusNode,
                  config: const QuillEditorConfig(
                    scrollable: false,
                    autoFocus: false,
                    expands: false,
                    padding: EdgeInsets.zero,
                    showCursor: false,
                    enableInteractiveSelection: false,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────────

  Widget _statusBar(Color color) {
    String autoguardadoLabel = '';
    if (_ultimoAutoguardado != null) {
      final mins = DateTime.now().difference(_ultimoAutoguardado!).inMinutes;
      autoguardadoLabel = mins == 0 ? 'Guardado' : 'Guardado hace ${mins}min';
    } else if (_autoguardadoPendiente) {
      autoguardadoLabel = 'Sin guardar';
    }
    return Container(
      height: 28,
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text('$_palabras palabras',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
        _dot(),
        Text('$_minLectura min',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
        if (_slugCtrl.text.isNotEmpty) ...[
          _dot(),
          Text('/${_slugCtrl.text}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFB0BEC5), fontFamily: 'monospace')),
        ],
        const Spacer(),
        if (autoguardadoLabel.isNotEmpty) ...[
          Text(autoguardadoLabel,
              style: TextStyle(fontSize: 10, color: _autoguardadoPendiente && _ultimoAutoguardado == null
                  ? const Color(0xFFD97706)
                  : const Color(0xFF10B981))),
          _dot(),
        ],
        Text(_estado == EstadoBlog.publicado ? '● Publicado' : _estado == EstadoBlog.programado ? '⏱ Programado' : '○ Borrador',
            style: TextStyle(fontSize: 10.5,
                color: _estado == EstadoBlog.publicado ? const Color(0xFF059669)
                    : _estado == EstadoBlog.programado ? const Color(0xFF2563EB)
                    : const Color(0xFFD97706),
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _dot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(width: 3, height: 3,
        decoration: const BoxDecoration(color: Color(0xFFD1D5DB), shape: BoxShape.circle)),
  );

  // ── Panel de configuración ────────────────────────────────────────────────

  void _mostrarConfiguracion(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.97,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => StatefulBuilder(
          builder: (ctx2, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 10, bottom: 2),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 14, 8),
                child: Row(children: [
                  const Text('Configurar artículo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(onPressed: () { Navigator.pop(ctx2); _guardar(context); },
                      child: const Text('Guardar borrador')),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () { Navigator.pop(ctx2); _guardar(context, publicar: true); },
                    style: FilledButton.styleFrom(backgroundColor: color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    child: const Text('Publicar'),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Tipo
                    _cfgLabel('Tipo de contenido'),
                    Wrap(spacing: 6, runSpacing: 6,
                      children: {'articulo':'Artículo','noticia':'Noticia',
                                 'entrevista':'Entrevista','resena':'Reseña'}.entries.map((t) =>
                        ChoiceChip(
                          label: Text(t.value),
                          selected: _tipo == t.key,
                          onSelected: (_) => setState(() => _tipo = t.key),
                          selectedColor: color.withValues(alpha: 0.15),
                        )).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Autor
                    _cfgLabel('Autor'),
                    TextField(
                      controller: _autorCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _cfgDeco('Nombre del autor'),
                    ),
                    const SizedBox(height: 16),
                    // Autor vinculado (colección autores)
                    if (_tipo == 'entrevista' || _tipo == 'noticia') ...[
                      _cfgLabel('Autor vinculado'),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.svc.obtenerAutores(widget.empresaId),
                        builder: (_, snap) {
                          final autores = snap.data ?? [];
                          final selNombre = _autorId == null ? null
                              : autores.where((a) => a['id']?.toString() == _autorId).map((a) => a['nombre']?.toString() ?? _autorId!).firstOrNull;
                          return _selectorVinculado(
                            ctx2,
                            label: selNombre ?? 'Seleccionar autor…',
                            seleccionado: _autorId != null,
                            onTap: () => _abrirSelectorGenerico(
                              ctx2, 'Autor', autores, 'nombre', _autorId,
                              onSelect: (id, nombre) => setState(() { _autorId = id; _autorCtrl.text = nombre; }),
                              onClear: () => setState(() { _autorId = null; }),
                            ),
                            onClear: () => setState(() { _autorId = null; }),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Libro vinculado (colección libros)
                      _cfgLabel('Libro vinculado'),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.svc.obtenerLibros(widget.empresaId),
                        builder: (_, snap) {
                          // Normalizar: algunos libros tienen 'nombre', otros 'titulo'
                          final libros = (snap.data ?? []).map((l) {
                            final t = (l['titulo'] as String? ?? '').trim();
                            final n = (l['nombre'] as String? ?? '').trim();
                            return t.isNotEmpty ? l : {...l, 'titulo': n.isNotEmpty ? n : (l['id'] ?? '')};
                          }).toList();
                          final selTitulo = _libroId == null ? null
                              : libros.where((l) => l['id']?.toString() == _libroId)
                                  .map((l) => l['titulo']?.toString() ?? _libroId!).firstOrNull;
                          return _selectorVinculado(
                            ctx2,
                            label: selTitulo ?? 'Seleccionar libro…',
                            seleccionado: _libroId != null,
                            onTap: () => _abrirSelectorGenerico(
                              ctx2, 'Libro', libros, 'titulo', _libroId,
                              onSelect: (id, titulo) => setState(() { _libroId = id; }),
                              onClear: () => setState(() { _libroId = null; }),
                            ),
                            onClear: () => setState(() { _libroId = null; }),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Categoría
                    if (widget.categorias.isNotEmpty) ...[
                      _cfgLabel('Categoría'),
                      DropdownButtonFormField<String>(
                        value: _categoriaId.isEmpty ? null : _categoriaId,
                        hint: const Text('Sin categoría'),
                        decoration: _cfgDeco(null),
                        items: widget.categorias.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre, style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setState(() => _categoriaId = v ?? ''),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Fecha
                    _cfgLabel('Fecha de publicación'),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx2,
                          initialDate: _fechaPublicacion,
                          firstDate: DateTime(2020), lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _fechaPublicacion = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8), color: Colors.white,
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, size: 14,
                              color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 8),
                          Text(
                            '${_fechaPublicacion.day} ${_mesLabel(_fechaPublicacion.month)} ${_fechaPublicacion.year}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Etiquetas
                    _cfgLabel('Etiquetas'),
                    TextField(
                      controller: _etiquetaCtrl,
                      decoration: _cfgDeco('Escribe y pulsa Enter para añadir'),
                      onSubmitted: (v) {
                        final tag = v.trim().toLowerCase();
                        if (tag.isNotEmpty && !_etiquetas.contains(tag)) {
                          setState(() => _etiquetas.add(tag));
                        }
                        _etiquetaCtrl.clear();
                      },
                    ),
                    if (_etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6,
                        children: _etiquetas.map((t) => Chip(
                          label: Text('#$t', style: const TextStyle(fontSize: 11.5)),
                          onDeleted: () => setState(() => _etiquetas.remove(t)),
                          deleteIconColor: Colors.grey[500],
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Vídeo
                    _cfgLabel('URL del vídeo (YouTube, Vimeo…)'),
                    TextField(
                      controller: _videoUrlCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _cfgDeco('https://www.youtube.com/watch?v=...'),
                    ),
                    if (_videoUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _videoUrlCtrl.text.contains('youtube') || _videoUrlCtrl.text.contains('youtu.be')
                            ? '✓ YouTube detectado · se usará como portada si no hay imagen'
                            : _videoUrlCtrl.text.contains('vimeo') ? '✓ Vimeo detectado' : '✓ Vídeo externo',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Slug
                    _cfgLabel('URL (slug)'),
                    TextField(
                      controller: _slugCtrl,
                      decoration: _cfgDeco('url-del-articulo').copyWith(
                        prefixText: '/',
                        prefixStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        suffixIcon: _slugOk
                            ? const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18)
                            : const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]'))],
                      onChanged: (_) => setState(() => _slugManual = true),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _cfgLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: Color(0xFF374151), letterSpacing: .2)),
  );

  InputDecoration _cfgDeco(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6B7280))),
    filled: true, fillColor: Colors.white,
  );

  // ── Selector vinculado (autor / libro) ───────────────────────────────────

  Widget _selectorVinculado(
    BuildContext ctx, {
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFFF0FDF4)
              : Colors.white,
          border: Border.all(
            color: seleccionado
                ? const Color(0xFF86EFAC)
                : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
            seleccionado ? Icons.check_circle_rounded : Icons.search_rounded,
            size: 15,
            color: seleccionado ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: seleccionado
                    ? const Color(0xFF15803D)
                    : const Color(0xFF9CA3AF),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (seleccionado)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
            ),
        ]),
      ),
    );
  }

  Future<void> _abrirSelectorGenerico(
    BuildContext context,
    String titulo,
    List<Map<String, dynamic>> items,
    String campoLabel,
    String? seleccionadoId, {
    required void Function(String id, String label) onSelect,
    required VoidCallback onClear,
  }) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = ctrl.text.toLowerCase();
          final filtrados = q.isEmpty
              ? items
              : items.where((a) =>
                  (a[campoLabel]?.toString() ?? '').toLowerCase().contains(q))
                  .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vincular $titulo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    onChanged: (_) => setModal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () { ctrl.clear(); setModal(() {}); })
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8F9FB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: Text('— Sin $titulo vinculado —',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    onTap: () { onClear(); Navigator.pop(ctx); },
                  ),
                  ...filtrados.map((item) {
                    final id = item['id']?.toString() ?? '';
                    final label = item[campoLabel]?.toString() ?? '';
                    final isSelected = seleccionadoId == id;
                    return ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded,
                          size: 18,
                          color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]),
                      title: Text(label, style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                      selected: isSelected,
                      selectedTileColor: const Color(0xFF2563EB).withValues(alpha: 0.06),
                      onTap: () { onSelect(id, label); Navigator.pop(ctx); },
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)))),
                ],
              )),
            ]),
          );
        },
      ),
    );
  }

  // ── Diálogo enlace ────────────────────────────────────────────────────────

  void _mostrarDialogoEnlace(BuildContext context) {
    final textoCtrl = TextEditingController();
    final urlCtrl   = TextEditingController();
    final sel = _quillCtrl.selection;
    if (sel.isValid && sel.start != sel.end) {
      textoCtrl.text = _quillCtrl.document.getPlainText(sel.start, sel.end - sel.start);
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insertar enlace'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: textoCtrl,
              decoration: const InputDecoration(labelText: 'Texto del enlace')),
          const SizedBox(height: 8),
          TextField(controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL', hintText: 'https://...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                _quillCtrl.formatSelection(LinkAttribute(url));
              }
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _mesLabel(int m) {
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return meses[m - 1];
  }
}
