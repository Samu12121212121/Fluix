import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ignore_for_file: prefer_const_constructors

class PantallaEditorBlog extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final EntradaBlog? entrada;
  final List<CategoriaBlog> categorias;
  final bool embedded;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const PantallaEditorBlog({
    super.key,
    required this.empresaId,
    required this.svc,
    required this.categorias,
    this.entrada,
    this.embedded = false,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<PantallaEditorBlog> createState() => _PantallaEditorBlogState();
}

class _PantallaEditorBlogState extends State<PantallaEditorBlog> {
  final _scrollCtrl      = ScrollController();
  final _portadaPageCtrl = PageController();
  final _tituloCtrl    = TextEditingController();
  final _slugCtrl      = TextEditingController();
  final _resumenCtrl   = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _etiquetaCtrl  = TextEditingController();
  String  _autorNombre = '';
  String? _autorId;
  String? _libroId;
  final _seoTituloCtrl = TextEditingController();
  final _seoDescCtrl   = TextEditingController();
  final _videoUrlCtrl  = TextEditingController();
  final _audioUrlCtrl  = TextEditingController();

  String?      _imagenUrl;
  List<String> _imagenes         = [];
  EstadoBlog   _estado           = EstadoBlog.borrador;
  String       _categoriaId      = '';
  DateTime     _fechaPublicacion = DateTime.now();
  List<String> _etiquetas        = [];
  bool         _slugManual       = false;
  bool         _slugOk           = true;
  bool         _guardando        = false;
  bool         _subiendoImg      = false;
  bool         _preview          = false;
  bool         _seoExpanded      = true;
  bool         _opcionesExpanded = false;
  bool         _compartirExp     = false;
  int          _rightTab         = 0;
  Timer?       _slugTimer;
  int          _carouselPage     = 0;

  // Undo / Redo stacks
  final _history   = <String>[];
  final _redoStack = <String>[];

  bool get _esNuevo    => widget.entrada == null || widget.entrada!.id.isEmpty;
  int  get _palabras   => _contenidoCtrl.text.trim().isEmpty ? 0
      : _contenidoCtrl.text.trim().split(RegExp(r'\s+')).length;
  int  get _minLectura => (_palabras / 200).ceil().clamp(1, 99);
  int  get _seoScore {
    int s = 0;
    final titulo    = _tituloCtrl.text.trim();
    final contenido = _contenidoCtrl.text;
    final seoTitulo = _seoTituloCtrl.text.trim();
    final seoDesc   = _seoDescCtrl.text.trim();

    // Título y slug (15 pts)
    if (titulo.isNotEmpty)                                        s += 8;
    if (_slugCtrl.text.isNotEmpty)                                s += 7;

    // Resumen corto (10 pts)
    if (_resumenCtrl.text.isNotEmpty)                             s += 10;

    // Longitud del contenido: > 300 palabras = bueno (15 pts)
    if (_palabras >= 300)                                         s += 15;
    else if (_palabras >= 100)                                    s += 7;

    // H1 en el contenido (10 pts)
    if (contenido.contains(RegExp(r'^# ', multiLine: true)))      s += 10;

    // Imagen destacada presente (10 pts)
    if (_imagenUrl != null)                                       s += 10;

    // Imagen en el contenido con alt text (5 pts)
    if (contenido.contains(RegExp(r'!\[.+\]')))                   s += 5;

    // SEO meta title con longitud óptima 30-60 chars (15 pts)
    if (seoTitulo.isNotEmpty && seoTitulo.length >= 30 && seoTitulo.length <= 60) {
      s += 15;
    } else if (seoTitulo.isNotEmpty) {
      s += 7;
    }

    // SEO meta description 80-160 chars (15 pts)
    if (seoDesc.length >= 80 && seoDesc.length <= 160)            s += 15;
    else if (seoDesc.length >= 50)                                s += 7;

    // Etiquetas presentes (5 pts)
    if (_etiquetas.isNotEmpty)                                    s += 5;

    // Categoría asignada (5 pts)
    if (_categoriaId.isNotEmpty)                                  s += 5;

    return s.clamp(0, 100);
  }

  /// Lista de checks SEO para mostrar en el panel
  List<(String label, bool ok, String ayuda)> get _seoChecks => [
    ('Título del artículo', _tituloCtrl.text.isNotEmpty, 'Escribe un título descriptivo'),
    ('URL (slug) configurada', _slugCtrl.text.isNotEmpty, 'Se genera automáticamente desde el título'),
    ('Resumen / descripción corta', _resumenCtrl.text.isNotEmpty, 'Aparece en la lista del blog'),
    ('> 300 palabras en el contenido', _palabras >= 300, 'Los artículos largos posicionan mejor'),
    ('Encabezado H1 en el contenido', _contenidoCtrl.text.contains(RegExp(r'^# ', multiLine: true)), 'Usa # al inicio del contenido'),
    ('Imagen destacada', _imagenUrl != null, 'Mejora el CTR en redes sociales'),
    ('Meta título SEO (30-60 chars)', _seoTituloCtrl.text.length >= 30 && _seoTituloCtrl.text.length <= 60, 'Longitud óptima para buscadores'),
    ('Meta descripción (80-160 chars)', _seoDescCtrl.text.length >= 80 && _seoDescCtrl.text.length <= 160, 'Aparece en los resultados de búsqueda'),
    ('Etiquetas asignadas', _etiquetas.isNotEmpty, 'Ayudan a clasificar el artículo'),
    ('Categoría asignada', _categoriaId.isNotEmpty, 'Organiza el contenido del blog'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.entrada != null) {
      final e = widget.entrada!;
      _tituloCtrl.text    = e.titulo;
      _slugCtrl.text      = e.slug;
      _resumenCtrl.text   = e.resumen;
      _contenidoCtrl.text = e.contenido;
      _autorNombre        = e.autor;
      _autorId            = e.autorId;
      _libroId            = e.libroId;
      _etiquetas          = List.from(e.etiquetas);
      _imagenUrl          = e.imagenUrl;
      _imagenes           = List.from(e.imagenes);
      _estado             = e.estado;
      _categoriaId        = e.categoriaId;
      _fechaPublicacion   = e.fechaPublicacion;
      _seoTituloCtrl.text = e.seoMetaTitle;
      _seoDescCtrl.text   = e.seoMetaDescription;
      _videoUrlCtrl.text  = e.videoUrl ?? '';
      _audioUrlCtrl.text  = e.audioUrl ?? '';
      _slugManual         = e.slug.isNotEmpty;
      // Mostrar renderizado por defecto cuando hay contenido
      _preview            = e.contenido.isNotEmpty;
    }
    _tituloCtrl.addListener(_onTitulo);
    _slugCtrl.addListener(_onSlug);
    _contenidoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _portadaPageCtrl.dispose();
    _tituloCtrl.dispose();    _slugCtrl.dispose();      _resumenCtrl.dispose();
    _contenidoCtrl.dispose(); _etiquetaCtrl.dispose();
    _seoTituloCtrl.dispose(); _seoDescCtrl.dispose();
    _videoUrlCtrl.dispose();  _audioUrlCtrl.dispose();
    _slugTimer?.cancel();
    super.dispose();
  }

  void _onTitulo() {
    if (!_slugManual) {
      final s = widget.svc.slugFromTituloPublic(_tituloCtrl.text);
      if (_slugCtrl.text != s) _slugCtrl.text = s;
    }
    setState(() {});
  }

  void _onSlug() {
    _slugTimer?.cancel();
    _slugTimer = Timer(const Duration(milliseconds: 600), () async {
      if (_slugCtrl.text.isEmpty) return;
      final ok = await widget.svc.slugDisponible(
          widget.empresaId, _slugCtrl.text, excludeId: widget.entrada?.id);
      if (mounted) setState(() => _slugOk = ok);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    if (widget.embedded) return _buildEmbedded(context, color);

    // Layout Word — aplica tanto en modo standalone como embebido con callbacks
    final wordBody = Column(children: [
      _topBarWord(context, color),
      _toolbarCompacto(color),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: _preview ? _buildPreview() : _buildAreaWord(color),
      ),
      _statusBar(color),
    ]);

    // Con callbacks = embebido en el panel lateral sin Scaffold propio
    if (widget.onGuardado != null || widget.onCancelar != null) {
      return LayoutBuilder(builder: (_, c) {
        final h = c.maxHeight.isInfinite ? null : c.maxHeight;
        return SizedBox(width: double.infinity, height: h,
            child: ColoredBox(color: const Color(0xFFF0F2F5), child: wordBody));
      });
    }

    return Scaffold(backgroundColor: const Color(0xFFF0F2F5), body: wordBody);
  }

  // ── Top bar Word (simplificado) ───────────────────────────────────────────

  Widget _topBarWord(BuildContext context, Color color) {
    final titulo = _tituloCtrl.text.trim();
    final label  = _esNuevo ? 'Nuevo artículo' : (titulo.isNotEmpty ? titulo : 'Sin título');

    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        // Volver
        GestureDetector(
          onTap: widget.onCancelar ?? () => Navigator.pop(context),
          child: Row(children: const [
            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF6B7280)),
            SizedBox(width: 4),
            Text('Blog', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 15, color: Color(0xFFD1D5DB)),
        ),
        // Título truncado
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis),
        ),
        // Estado badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _estado == EstadoBlog.publicado
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _estado == EstadoBlog.publicado ? 'Publicado' : 'Borrador',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _estado == EstadoBlog.publicado
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Preview / Edit toggle
        _topBtn(
          icon: _preview ? Icons.edit_note_rounded : Icons.visibility_outlined,
          label: _preview ? 'Editar' : 'Preview',
          onTap: () => setState(() => _preview = !_preview),
        ),
        const SizedBox(width: 6),
        // Configuración (metadata)
        _topBtn(
          icon: Icons.tune_rounded,
          label: 'Configurar',
          onTap: () => _mostrarPanelOpciones(context, color),
        ),
        const SizedBox(width: 8),
        // Publicar / Guardar
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'publicar') {
              setState(() => _estado = EstadoBlog.publicado);
              await _guardar(context);
            } else if (v == 'borrador') {
              setState(() => _estado = EstadoBlog.borrador);
              await _guardar(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'publicar', child: Row(children: [
              const Icon(Icons.publish_rounded, size: 15, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              const Text('Publicar', style: TextStyle(fontSize: 13, color: Color(0xFF059669),
                  fontWeight: FontWeight.w600)),
            ])),
            PopupMenuItem(value: 'borrador', child: Row(children: [
              const Icon(Icons.save_outlined, size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              const Text('Guardar borrador', style: TextStyle(fontSize: 13)),
            ])),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _estado == EstadoBlog.publicado ? color : color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_guardando)
                const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.publish_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _estado == EstadoBlog.publicado ? 'Publicar' : 'Guardar',
                style: const TextStyle(color: Colors.white, fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Toolbar compacta (una fila, esenciales) ──────────────────────────────

  Widget _toolbarCompacto(Color color) {
    return Container(
      height: 38,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Tipo de bloque
          PopupMenuButton<String>(
            tooltip: 'Tipo de bloque',
            onSelected: _cambiarTipoBloque,
            itemBuilder: (_) => ['Párrafo', 'Título 1', 'Título 2', 'Título 3', 'Cita']
                .map((t) => PopupMenuItem(value: t, child: Text(t,
                    style: const TextStyle(fontSize: 13))))
                .toList(),
            child: _dropBtn('Párrafo'),
          ),
          _vsep(),
          _tb(Icons.format_bold,          'Negrita',        () => _wrapSel('**')),
          _tb(Icons.format_italic,        'Cursiva',        () => _wrapSel('_')),
          _tb(Icons.format_strikethrough, 'Tachado',        () => _wrapSel('~~')),
          _vsep(),
          _tb(Icons.format_quote,         'Cita',           () => _linePrefix('> ')),
          _tb(Icons.format_list_bulleted, 'Lista viñetas',  () => _linePrefix('- ')),
          _tb(Icons.format_list_numbered, 'Lista numerada', () => _linePrefix('1. ')),
          _tb(Icons.horizontal_rule,      'Separador',      () => _ins('\n\n---\n\n')),
          _vsep(),
          _tb(Icons.link_rounded,         'Enlace',         () => _ins('[texto](url)')),
          _tb(Icons.add_photo_alternate_outlined, 'Subir imagen', () => _insertGaleria()),
          _vsep(),
          _tb(Icons.undo_rounded,         'Deshacer',       _undo),
          _tb(Icons.redo_rounded,         'Rehacer',        _redo),
        ]),
      ),
    );
  }

  // ── Área de escritura estilo Word ────────────────────────────────────────

  Widget _buildAreaWord(Color color) {
    final tipoLabel = {
      'noticia':    'Noticia',
      'entrevista': 'Entrevista',
      'resena':     'Reseña',
      'articulo':   'Artículo',
    }[widget.entrada?.tipo ?? ''] ?? 'Artículo';

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 20, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Carrusel de portada ───────────────────────────────────────
              _buildCarruselPortadaEditor(color),
              // ── Barra de gestión de fotos ─────────────────────────────────
              _barraFotosAdicionales(color),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 32, 48, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Meta: tipo · autor · fecha ────────────────────────────
                  Row(children: [
                    Text(tipoLabel.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                            color: color, letterSpacing: .6)),
                    if (_autorNombre.isNotEmpty) ...[
                      Text('  ·  ', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                      Text(_autorNombre,
                          style: const TextStyle(fontSize: 10,
                              color: Color(0xFF9CA3AF))),
                    ],
                    Text('  ·  ', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                    Text(
                      '${_fechaPublicacion.day} ${_nombreMes(_fechaPublicacion.month)} ${_fechaPublicacion.year}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // ── Título ─────────────────────────────────────────────────
                  TextField(
                    controller: _tituloCtrl,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w800,
                      height: 1.15, color: Color(0xFF111827),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none, contentPadding: EdgeInsets.zero,
                      hintText: 'Título del artículo',
                      hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                          height: 1.15, color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  // ── Resumen / subtítulo ────────────────────────────────────
                  const SizedBox(height: 8),
                  TextField(
                    controller: _resumenCtrl,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 17, height: 1.6,
                      color: Color(0xFF6B7280), fontStyle: FontStyle.italic,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none, contentPadding: EdgeInsets.zero,
                      hintText: 'Añade un subtítulo o resumen breve…',
                      hintStyle: TextStyle(fontSize: 17, height: 1.6,
                          color: Color(0xFFE5E7EB), fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey[200], height: 1),
                  const SizedBox(height: 24),
                  // ── Contenido ──────────────────────────────────────────────
                  TextField(
                    controller: _contenidoCtrl,
                    maxLines: null,
                    minLines: 18,
                    style: const TextStyle(
                      fontSize: 16, height: 1.85,
                      color: Color(0xFF1F2937),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none, contentPadding: EdgeInsets.zero,
                      hintText: 'Empieza a escribir...',
                      hintStyle: TextStyle(fontSize: 16, height: 1.85,
                          color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _nombreMes(int m) {
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return meses[m - 1];
  }

  // ── Panel de opciones (metadata) ─────────────────────────────────────────

  void _mostrarPanelOpciones(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Cabecera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                const Text('Configurar artículo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton(
                  onPressed: _guardando ? null : () {
                    Navigator.pop(ctx);
                    _guardar(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  child: _guardando
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ]),
            ),
            const Divider(height: 1),
            // Contenido del panel
            Expanded(child: _rightPanel(ctx, color)),
          ]),
        ),
      ),
    );
  }

  Future<void> _subirImagenDestacada() async {
    setState(() => _subiendoImg = true);
    final urls = await widget.svc.subirMultiplesImagenes(widget.empresaId, 'blog/portadas');
    if (mounted) setState(() {
      if (urls.isNotEmpty) {
        _imagenUrl = urls.first;
        _imagenes.addAll(urls.skip(1));
      }
      _subiendoImg = false;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMBEDDED
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEmbedded(BuildContext context, Color color) => ColoredBox(
    color: const Color(0xFFF0F2F5),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        color: Colors.white,
        child: Row(children: [
          Text(_esNuevo ? 'Nuevo artículo' : 'Editando artículo',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton(
            onPressed: _guardando ? null : () => _guardar(context),
            style: FilledButton.styleFrom(backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: _guardando
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar'),
          ),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _titleSlugBlock(color),
          const SizedBox(height: 12),
          _contentBlock(color),
          const SizedBox(height: 12),
          _imagenesBlock(color),
        ]),
      )),
    ]),
  );


  Widget _paymentLinkWidget(String libroId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('libros')
          .doc(libroId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final live  = data['payment_link']      as String? ?? '';
        final test  = data['payment_link_test'] as String? ?? '';
        if (live.isEmpty && test.isEmpty) return const SizedBox.shrink();

        void copiar(String url, String label) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label copiado'), duration: const Duration(seconds: 2)));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment Links Stripe',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (live.isNotEmpty)
            _linkRow('LIVE', live, const Color(0xFF059669), () => copiar(live, 'Link LIVE')),
          if (test.isNotEmpty) ...[
            const SizedBox(height: 4),
            _linkRow('TEST', test, const Color(0xFF7C3AED), () => copiar(test, 'Link TEST')),
          ],
        ]);
      },
    );
  }

  Widget _linkRow(String label, String url, Color color, VoidCallback onCopy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
          child: Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: color, fontFamily: 'monospace')),
        ),
        IconButton(
          icon: Icon(Icons.copy_rounded, size: 14, color: color),
          onPressed: onCopy,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Copiar',
        ),
      ]),
    );
  }

  Widget _imagenesBlock(Color color) {
    final todas = [
      if (_imagenUrl != null) _imagenUrl!,
      ..._imagenes,
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.photo_library_outlined, size: 14, color: Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text('Imágenes', style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const Spacer(),
          if (todas.isNotEmpty)
            Text('${todas.length} imagen${todas.length == 1 ? '' : 'es'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Thumbnails existentes
              ...List.generate(todas.length, (i) {
                final url = todas[i];
                final esPortada = url == _imagenUrl;
                return Stack(clipBehavior: Clip.none, children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(children: [
                        Image.network(url, width: 72, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 72, height: 72,
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.broken_image_outlined,
                                    color: Color(0xFFD1D5DB)))),
                        if (esPortada)
                          Positioned(bottom: 0, left: 0, right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: const Text('Portada', textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 8,
                                      fontWeight: FontWeight.w600)),
                            )),
                      ]),
                    ),
                  ),
                  // Eliminar (solo imágenes adicionales)
                  if (!esPortada)
                    Positioned(top: -6, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          final idx = _imagenes.indexOf(url);
                          if (idx >= 0) _imagenes.removeAt(idx);
                        }),
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 11, color: Colors.white),
                        ),
                      )),
                ]);
              }),
              // Botón añadir
              GestureDetector(
                onTap: _subiendoImagenesExtra ? null : _subirImagenesAdicionales,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2), style: BorderStyle.solid),
                  ),
                  child: _subiendoImagenesExtra
                      ? Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: color)))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: color, size: 20),
                          const SizedBox(height: 3),
                          Text('Añadir', style: TextStyle(color: color, fontSize: 10,
                              fontWeight: FontWeight.w600)),
                        ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _topBtn({
    required IconData icon,
    required String label,
    Color? color,
    Color? borderColor,
    VoidCallback? onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: color ?? const Color(0xFF374151),
      side: BorderSide(color: borderColor ?? const Color(0xFFD1D5DB)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );


  Widget _titleSlugBlock(Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Título ──────────────────────────────────────────────────────────
      const Text('Título del artículo',
          style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: TextField(
              controller: _tituloCtrl,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                  height: 1.4, color: Color(0xFF111827)),
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.zero,
                hintText: 'Escribe el título aquí...',
                hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                    color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
          Text('${_tituloCtrl.text.length}/80',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ]),
      ),
      const SizedBox(height: 8),
      // ── Slug ────────────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5), bottomLeft: Radius.circular(5)),
              border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text('Slug',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _slugCtrl,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                    color: _slugOk ? const Color(0xFF374151) : Colors.red),
                decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]'))],
                onChanged: (_) => setState(() => _slugManual = true),
              ),
            ),
          ),
          if (!_slugOk)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text('⚠ en uso', style: TextStyle(fontSize: 10, color: Colors.red)),
            ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: () => setState(() => _slugManual = true),
              style: TextButton.styleFrom(
                foregroundColor: context.read<AppConfigProvider>().colorPrimario,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Editar'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }


  Widget _vsep() => Container(width: 1, height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE5E7EB));

  Widget _tb(IconData icon, String tooltip, VoidCallback fn) => Tooltip(
    message: tooltip,
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151))),
      const SizedBox(width: 3),
      const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF6B7280)),
    ]),
  );


  // ══════════════════════════════════════════════════════════════════════════
  // BLOCK RENDERER — Renderizado visual tipo Gutenberg
  // ══════════════════════════════════════════════════════════════════════════

  // Tipos de bloque
  static const _bH1 = 'h1'; static const _bH2 = 'h2'; static const _bH3 = 'h3';
  static const _bP  = 'p';  static const _bCallout = 'callout';
  static const _bCheck = 'check'; static const _bBullet = 'bullet';
  static const _bImg = 'img'; static const _bCode = 'code'; static const _bHr = 'hr';
  static const _bNum = 'num';

  List<Map<String, dynamic>> _parseBlocks(String text) {
    final blocks = <Map<String, dynamic>>[];
    final lines = text.split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.startsWith('# '))       { blocks.add({t: _bH1, 'v': line.substring(2)}); }
      else if (line.startsWith('## ')) { blocks.add({t: _bH2, 'v': line.substring(3)}); }
      else if (line.startsWith('### ')){ blocks.add({t: _bH3, 'v': line.substring(4)}); }
      else if (line.startsWith('> '))  { blocks.add({t: _bCallout, 'v': line.substring(2)}); }
      else if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        blocks.add({t: _bCheck, 'v': line.substring(6), 'ok': true});
      } else if (line.startsWith('- [ ] ')) {
        blocks.add({t: _bCheck, 'v': line.substring(6), 'ok': false});
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        final m = RegExp(r'^\d+\. (.+)').firstMatch(line);
        blocks.add({t: _bNum, 'v': m?.group(1) ?? line, 'n': blocks.where((b) => b[t] == _bNum).length + 1});
      } else if (line.startsWith('- ')) {
        blocks.add({t: _bBullet, 'v': line.substring(2)});
      } else if (line.startsWith('![')) {
        final m = RegExp(r'!\[([^\]]*)\]\(([^\)]+)\)').firstMatch(line);
        if (m != null) blocks.add({t: _bImg, 'v': m.group(1) ?? '', 'url': m.group(2)});
      } else if (line.trim() == '---') {
        blocks.add({t: _bHr, 'v': ''});
      } else if (line.startsWith('```')) {
        final lang = line.substring(3).trim();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) { code.add(lines[i]); i++; }
        blocks.add({t: _bCode, 'v': code.join('\n'), 'lang': lang});
      } else if (line.trim().isNotEmpty) {
        blocks.add({t: _bP, 'v': line});
      }
      i++;
    }
    return blocks;
  }

  static const t = 'type';

  Widget _renderBlock(Map<String, dynamic> b, Color color) {
    switch (b[t] as String) {
      // ── Headings ─────────────────────────────────────────────────────────
      case _bH1: return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Text(b['v'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
            height: 1.3, color: Color(0xFF111827))));
      case _bH2: return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(b['v'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            height: 1.3, color: Color(0xFF111827))));
      case _bH3: return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(b['v'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            height: 1.3, color: Color(0xFF1F2937))));

      // ── Párrafo ───────────────────────────────────────────────────────────
      case _bP: return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: MarkdownBody(
          data: b['v'],
          selectable: false,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 15, height: 1.85, color: Color(0xFF374151)),
            strong: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            em: const TextStyle(fontStyle: FontStyle.italic),
            a: TextStyle(color: color, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
            code: const TextStyle(fontFamily: 'monospace', fontSize: 13,
                backgroundColor: Color(0xFFF3F4F6), color: Color(0xFFD1477A)),
          ),
        ));

      // ── Callout / Cita ────────────────────────────────────────────────────
      case _bCallout:
        final raw    = b['v'] as String;
        final isEmoji = raw.isNotEmpty && _isEmoji(raw[0]);
        final icon   = isEmoji ? raw.substring(0, 2).trim() : '💡';
        final texto  = isEmoji ? raw.substring(icon.length).trim() : raw;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(
                fontSize: 14, height: 1.65, color: Color(0xFF374151)))),
          ]),
        );

      // ── Checklist ─────────────────────────────────────────────────────────
      case _bCheck:
        final checked = b['ok'] as bool;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 20, height: 20, margin: const EdgeInsets.only(top: 1.5),
              decoration: BoxDecoration(
                color: checked ? const Color(0xFF16A34A) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: checked ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF), width: 1.5),
              ),
              child: checked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(b['v'],
                style: TextStyle(fontSize: 15, height: 1.7, color: const Color(0xFF374151),
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0xFF9CA3AF)))),
          ]),
        );

      // ── Bullet list ───────────────────────────────────────────────────────
      case _bBullet: return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 10, right: 12),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF374151))),
          Expanded(child: Text(b['v'],
              style: const TextStyle(fontSize: 15, height: 1.75, color: Color(0xFF374151)))),
        ]));

      // ── Numbered list ─────────────────────────────────────────────────────
      case _bNum: return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 22, height: 22, margin: const EdgeInsets.only(top: 4, right: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Text('${b['n']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
          Expanded(child: Text(b['v'],
              style: const TextStyle(fontSize: 15, height: 1.75, color: Color(0xFF374151)))),
        ]));

      // ── Imagen ────────────────────────────────────────────────────────────
      case _bImg:
        final url = b['url'] as String? ?? '';
        if (url.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity,
            errorWidget: (_, e, s) => Container(height: 200,
              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
              child: const Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFFD1D5DB)))),
        );

      // ── Código ────────────────────────────────────────────────────────────
      case _bCode: return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
        child: Text(b['v'], style: const TextStyle(fontFamily: 'monospace', fontSize: 13,
            color: Color(0xFFE2E8F0), height: 1.6)));

      // ── Divisor ───────────────────────────────────────────────────────────
      case _bHr: return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Container(height: 1.5, color: const Color(0xFFE5E7EB)));

      default: return const SizedBox.shrink();
    }
  }

  bool _isEmoji(String char) {
    final code = char.codeUnitAt(0);
    return code > 0x2000;
  }

  Widget _buildPreview() {
    final color = context.read<AppConfigProvider>().colorPrimario;
    final blocks = _parseBlocks(_contenidoCtrl.text);

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            // ── Tarjeta de contenido ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Portada (carrusel si hay más de 1 imagen) ─────────────
                Builder(builder: (ctx) {
                  final todasPortada = [
                    if (_imagenUrl != null) _imagenUrl!,
                    ..._imagenes,
                  ];
                  if (todasPortada.isEmpty) return const SizedBox.shrink();
                  if (todasPortada.length == 1) {
                    return Stack(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                        child: CachedNetworkImage(imageUrl: todasPortada.first,
                          width: double.infinity, height: 260, fit: BoxFit.cover,
                          errorWidget: (_, e, s) => Container(height: 260,
                              color: const Color(0xFFF3F4F6))),
                      ),
                      Positioned.fill(child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                        ),
                      )),
                    ]);
                  }
                  // Carrusel
                  return SizedBox(
                    height: 260,
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                        child: PageView.builder(
                          itemCount: todasPortada.length,
                          onPageChanged: (i) => setState(() => _carouselPage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: todasPortada[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (_, __, ___) =>
                                Container(color: const Color(0xFFF3F4F6)),
                          ),
                        ),
                      ),
                      // Indicadores de página
                      Positioned(
                        bottom: 12, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(todasPortada.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == _carouselPage ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _carouselPage ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        ),
                      ),
                      // Contador
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_carouselPage + 1} / ${todasPortada.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      Positioned.fill(child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                        ),
                      )),
                    ]),
                  );
                }),

                // Contenido renderizado como bloques
                GestureDetector(
                  onTap: () => setState(() => _preview = false),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 28, 36, 36),
                    child: _contenidoCtrl.text.isEmpty
                        ? Column(children: [
                            const SizedBox(height: 24),
                            Icon(Icons.edit_note_rounded, size: 48, color: Colors.grey[200]),
                            const SizedBox(height: 12),
                            Text('Toca para empezar a escribir...',
                                style: TextStyle(color: Colors.grey[300], fontSize: 15)),
                            const SizedBox(height: 48),
                          ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: blocks.map((b) => _renderBlock(b, color)).toList(),
                          ),
                  ),
                ),

              ]),
            ),

            // Botón + añadir bloque (entre secciones)
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => setState(() => _preview = false),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                ),
                child: const Icon(Icons.add, size: 18, color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  // ── Carrusel en el editor (modo Word) ─────────────────────────────────────────
  Widget _buildCarruselPortadaEditor(Color color) {
    final todas = [
      if (_imagenUrl != null) _imagenUrl!,
      ..._imagenes,
    ];
    if (todas.isEmpty) {
      // Placeholder cuando no hay ninguna foto
      return GestureDetector(
        onTap: _subiendoImg ? null : _subirImagenDestacada,
        child: Container(
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 20, color: color.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('Añadir fotos al carrusel',
                style: TextStyle(fontSize: 12.5,
                    color: color.withValues(alpha: 0.6))),
          ]),
        ),
      );
    }
    // Una sola foto → imagen fija
    if (todas.length == 1) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: Image.network(todas.first, height: 220,
            width: double.infinity, fit: BoxFit.cover),
      );
    }
    // Varias → carrusel deslizable con controller persistente
    return SizedBox(
      height: 220,
      child: Stack(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: PageView.builder(
            controller: _portadaPageCtrl,
            itemCount: todas.length,
            onPageChanged: (i) => setState(() => _carouselPage = i),
            itemBuilder: (_, i) => Image.network(
              todas[i], fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6)),
            ),
          ),
        ),
        // Indicadores
        Positioned(
          bottom: 10, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(todas.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == _carouselPage ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _carouselPage
                    ? Colors.white : Colors.white54,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
        ),
        // Contador
        Positioned(top: 10, right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(14)),
            child: Text('${_carouselPage + 1} / ${todas.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          )),
      ]),
    );
  }

  // ── Barra de gestión de fotos del carrusel ─────────────────────────────────
  Widget _barraFotosAdicionales(Color color) {
    final todas = [
      if (_imagenUrl != null) _imagenUrl!,
      ..._imagenes,
    ];
    return Container(
      color: const Color(0xFFFAFAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // Label
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Carrusel', style: TextStyle(fontSize: 9,
              letterSpacing: .3, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            todas.isEmpty
                ? 'Sin fotos'
                : '${todas.length} foto${todas.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
          ),
        ]),
        const SizedBox(width: 12),
        Container(width: 1, height: 42, color: const Color(0xFFE5E7EB)),
        const SizedBox(width: 12),
        // Thumbnails
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // Thumb portada (primera, con marca "P")
              if (_imagenUrl != null)
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(children: [
                        Image.network(_imagenUrl!, width: 42, height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fotoPlaceholder(color, 42)),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: Container(
                            color: Colors.black45,
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: const Text('1ª', textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 7,
                                    fontWeight: FontWeight.w700)),
                          )),
                      ]),
                    ),
                  ),
                  Positioned(top: -5, right: 1,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        // Si hay extras, la segunda pasa a ser portada
                        if (_imagenes.isNotEmpty) {
                          _imagenUrl = _imagenes.removeAt(0);
                        } else {
                          _imagenUrl = null;
                        }
                        _carouselPage = 0;
                      }),
                      child: _xBtn(),
                    )),
                ]),
              // Thumbs adicionales
              ..._imagenes.asMap().entries.map((e) {
                final idx = e.key;
                final url = e.value;
                return Stack(clipBehavior: Clip.none, children: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(url, width: 42, height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fotoPlaceholder(color, 42)),
                    ),
                  ),
                  Positioned(top: -5, right: 1,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagenes.removeAt(idx)),
                      child: _xBtn(),
                    )),
                ]);
              }),
              // Botón + (añadir una foto más al carrusel)
              GestureDetector(
                onTap: (_subiendoImg || _subiendoImagenesExtra) ? null
                    : _subirUnaImagenAdicional,
                child: (_subiendoImg || _subiendoImagenesExtra)
                    ? _fotoPlaceholderLoading(color, 42)
                    : _fotoPlaceholder(color, 42,
                        icon: Icons.add_photo_alternate_outlined),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _xBtn() => Container(
    width: 15, height: 15,
    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
    child: const Icon(Icons.close, size: 9, color: Colors.white),
  );

  Widget _fotoPlaceholder(Color color, double size, {IconData? icon}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25), style: BorderStyle.solid),
    ),
    child: Icon(icon ?? Icons.add_photo_alternate_outlined, color: color, size: size * 0.42),
  );

  Widget _fotoPlaceholderLoading(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Center(child: SizedBox(width: size * 0.35, height: size * 0.35,
        child: CircularProgressIndicator(strokeWidth: 2, color: color))),
  );

  /// Añade UNA imagen a `_imagenes` usando picker de imagen única (más fiable en desktop).
  Future<void> _subirUnaImagenAdicional() async {
    setState(() => _subiendoImagenesExtra = true);
    final url = await widget.svc.subirImagenDesdeGaleria(
        widget.empresaId, 'web/blog/imagenes');
    if (mounted) setState(() {
      if (url != null) _imagenes.add(url);
      _subiendoImagenesExtra = false;
    });
  }

  Widget _buildGaleriaDebajo(Color color) {
    return Column(children: [
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Padding(
        padding: const EdgeInsets.fromLTRB(36, 20, 36, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.photo_library_outlined, size: 15, color: color),
            const SizedBox(width: 6),
            Text('Galería', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 6),
            Text('${_imagenes.length} ${_imagenes.length == 1 ? "foto" : "fotos"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
          const SizedBox(height: 12),
          _imagenes.length == 1
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _imagenes.first,
                    width: double.infinity, height: 200, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(height: 200,
                        color: const Color(0xFFF3F4F6)),
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: _imagenes.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(right: i < _imagenes.length - 1 ? 8 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _imagenes[i],
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6)),
                        ),
                      ),
                    ),
                  ),
                ),
        ]),
      ),
    ]);
  }

  Widget _contentBlock(Color color) => TextField(
    controller: _contenidoCtrl,
    maxLines: null, minLines: 14,
    style: const TextStyle(fontSize: 14, height: 1.75, color: Color(0xFF1F2937)),
    decoration: const InputDecoration(
      border: InputBorder.none, contentPadding: EdgeInsets.zero,
      hintText: 'Escribe el contenido...',
      hintStyle: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // RIGHT PANEL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _rightPanel(BuildContext context, Color color) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Column(children: [
        _tabRow(['Documento', 'Bloque'], _rightTab, color,
            (i) => setState(() => _rightTab = i)),
        Expanded(
          child: _rightTab == 0
              ? _docScroll(context, color)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Selecciona un bloque para editar sus opciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  )),
        ),
      ]),
    );
  }

  Widget _docScroll(BuildContext context, Color color) {
    return SingleChildScrollView(
      child: Column(children: [
        // ── Publicación ──────────────────────────────────────────────────
        _rSection(
          'Publicación',
          children: [
            _rLabel('Estado'),
            _estadoDropdown(color),
            const SizedBox(height: 10),
            _rLabel('Fecha de publicación'),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => _seleccionarFecha(context),
                child: _dateBox(Icons.calendar_today_outlined,
                    '${_fechaPublicacion.day.toString().padLeft(2,'0')}/'
                    '${_fechaPublicacion.month.toString().padLeft(2,'0')}/'
                    '${_fechaPublicacion.year}', color),
              )),
              const SizedBox(width: 6),
              _dateBox(Icons.access_time_outlined,
                  '${_fechaPublicacion.hour.toString().padLeft(2,'0')}:'
                  '${_fechaPublicacion.minute.toString().padLeft(2,'0')}', color),
            ]),
            const SizedBox(height: 10),
            _rLabel('Autor'),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerAutores(widget.empresaId),
              builder: (_, snap) {
                final autores = snap.data ?? [];
                return GestureDetector(
                  onTap: () => _abrirSelectorAutor(context, autores),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(
                        _autorNombre.isEmpty ? 'Seleccionar autor…' : _autorNombre,
                        style: TextStyle(
                          fontSize: 12,
                          color: _autorNombre.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                      const Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                      if (_autorNombre.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() { _autorNombre = ''; _autorId = null; }),
                          child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _rLabel('Libro vinculado'),
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
                        .map((l) => l['titulo']?.toString() ?? _libroId!)
                        .firstOrNull;
                return GestureDetector(
                  onTap: () => _abrirSelectorLibro(context, libros),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: _libroId != null
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _libroId != null
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _libroId != null ? Icons.menu_book_rounded : Icons.search_rounded,
                        size: 15,
                        color: _libroId != null ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        selTitulo ?? 'Seleccionar libro…',
                        style: TextStyle(
                          fontSize: 12,
                          color: _libroId != null ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                      if (_libroId != null)
                        GestureDetector(
                          onTap: () => setState(() => _libroId = null),
                          child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ),
                    ]),
                  ),
                );
              },
            ),
            // Payment link del libro asociado
            if (_libroId != null) ...[
              const SizedBox(height: 10),
              _paymentLinkWidget(_libroId!),
            ],
            if (!_esNuevo) ...[
              const SizedBox(height: 10),
              // Historial de versiones
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _mostrarHistorialVersiones(context),
                  icon: const Icon(Icons.history_rounded, size: 15, color: Color(0xFF3B82F6)),
                  label: const Text('Ver historial',
                      style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmarEliminar(context),
                  icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                  label: const Text('Mover a la papelera',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ],
        ),
        _rDivider(),

        // ── Categorías ───────────────────────────────────────────────────
        _rSection(
          'Categorías',
          trailing: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              ...widget.categorias
                  .where((c) => c.id == _categoriaId)
                  .map((c) => _chip(c.nombre, color,
                      () => setState(() => _categoriaId = ''))),
              if (_categoriaId.isEmpty)
                PopupMenuButton<String>(
                  onSelected: (id) => setState(() => _categoriaId = id),
                  itemBuilder: (_) => widget.categorias.isEmpty
                      ? [const PopupMenuItem(enabled: false,
                          child: Text('Sin categorías',
                              style: TextStyle(fontSize: 12, color: Colors.grey)))]
                      : widget.categorias.map((c) => PopupMenuItem(
                          value: c.id, child: Text(c.nombre,
                              style: const TextStyle(fontSize: 13)))).toList(),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text('Añadir categoría',
                        style: TextStyle(fontSize: 11, color: color)),
                  ]),
                ),
            ]),
          ],
        ),
        _rDivider(),

        // ── Etiquetas ────────────────────────────────────────────────────
        _rSection(
          'Etiquetas',
          trailing: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              ..._etiquetas.map((t) => _chip(t, color,
                  () => setState(() => _etiquetas.remove(t)))),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _etiquetaCtrl,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: InputDecoration(
                    hintText: '+ Añadir etiqueta',
                    hintStyle: TextStyle(fontSize: 11.5, color: color),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  ),
                  onSubmitted: (v) {
                    final tag = v.trim();
                    if (tag.isNotEmpty && !_etiquetas.contains(tag)) {
                      setState(() { _etiquetas.add(tag); _etiquetaCtrl.clear(); });
                    }
                  },
                ),
              ),
            ]),
          ],
        ),
        _rDivider(),

        // ── Imagen destacada ──────────────────────────────────────────────
        _rSection(
          'Imagen destacada',
          children: [
            if (_imagenUrl != null) ...[
              GestureDetector(
                onTap: () => _verImagenCompleta(context, _imagenUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: _imagenUrl!,
                      height: 120, width: double.infinity, fit: BoxFit.cover,
                      errorWidget: (_, e, s) => Container(height: 120,
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFFD1D5DB)))),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Center(
                  child: TextButton(
                    onPressed: _subiendoImg ? null : _subirImagenDestacada,
                    style: TextButton.styleFrom(foregroundColor: color,
                        textStyle: const TextStyle(fontSize: 12)),
                    child: _subiendoImg
                        ? SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: color))
                        : const Text('Cambiar imagen'),
                  ),
                )),
                IconButton(
                  onPressed: () => setState(() => _imagenUrl = null),
                  icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red),
                  visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                ),
              ]),
            ] else
              InkWell(
                onTap: _subiendoImg ? null : _subirImagenDestacada,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 80, width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: context.read<AppConfigProvider>().colorPrimario
                            .withValues(alpha: 0.2)),
                  ),
                  child: _subiendoImg
                      ? Center(child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.read<AppConfigProvider>().colorPrimario))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: context.read<AppConfigProvider>().colorPrimario,
                              size: 22),
                          const SizedBox(height: 4),
                          Text('Añadir imagen',
                              style: TextStyle(
                                  color: context.read<AppConfigProvider>().colorPrimario,
                                  fontSize: 11)),
                        ]),
                ),
              ),
          ],
        ),
        _rDivider(),

        // ── Imágenes adicionales (carrusel) ───────────────────────────────
        _rSection(
          'Imágenes adicionales',
          children: [
            const Text(
              'Se muestran como carrusel junto a la imagen de portada.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            if (_imagenes.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagenes.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == _imagenes.length) {
                      return _addImagenBtn(color);
                    }
                    final url = _imagenes[i];
                    return Stack(clipBehavior: Clip.none, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url,
                            width: 90, height: 90, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.broken_image_outlined,
                                  color: Color(0xFFD1D5DB)),
                            )),
                      ),
                      Positioned(
                        top: -6, right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagenes.removeAt(i)),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              )
            else
              _addImagenBtn(color),
          ],
        ),
        _rDivider(),

        // ── SEO (colapsable) ──────────────────────────────────────────────
        _collapseHeader('SEO', _seoExpanded,
            () => setState(() => _seoExpanded = !_seoExpanded)),
        if (_seoExpanded) _seoBody(color),
        _rDivider(),

        // ── Opciones del artículo (colapsable) ────────────────────────────
        _collapseHeader('Opciones del artículo', _opcionesExpanded,
            () => setState(() => _opcionesExpanded = !_opcionesExpanded)),
        if (_opcionesExpanded) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _rLabel('Resumen / descripción corta'),
            TextField(
              controller: _resumenCtrl,
              maxLines: 3, style: const TextStyle(fontSize: 12),
              decoration: _rDeco('Breve resumen del artículo'),
            ),
            const SizedBox(height: 12),
            // ── Media embebida ──────────────────────────────────────
            Row(children: [
              const Icon(Icons.videocam_outlined, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text('Media embebida', style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151),
                letterSpacing: .3)),
            ]),
            const SizedBox(height: 6),
            _rLabel('Vídeo (YouTube, Vimeo o URL directa de vídeo)'),
            TextField(
              controller: _videoUrlCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: _rDeco('https://www.youtube.com/watch?v=... o URL .mp4'),
              onChanged: (_) => setState(() {}),
            ),
            if (_videoUrlCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _videoUrlCtrl.text.contains('youtube') || _videoUrlCtrl.text.contains('youtu.be')
                    ? '✓ YouTube detectado'
                    : _videoUrlCtrl.text.contains('vimeo')
                        ? '✓ Vimeo detectado'
                        : '✓ Vídeo directo',
                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A)),
              ),
            ],
            const SizedBox(height: 8),
            _rLabel('Audio (URL directa .mp3, .m4a, .ogg…)'),
            TextField(
              controller: _audioUrlCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: _rDeco('https://... .mp3'),
              onChanged: (_) => setState(() {}),
            ),
            if (_audioUrlCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('✓ Audio añadido',
                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
            ],
          ]),
        ),
        _rDivider(),

        // ── Compartir en redes (colapsable con iconos visibles) ───────────
        _compartirHeader(color),
        if (_compartirExp) _compartirBody(color),
        _rDivider(),

        const SizedBox(height: 20),
      ]),
    );
  }

  // Estado dropdown
  Widget _estadoDropdown(Color color) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EstadoBlog>(
          value: _estado,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          onChanged: (v) { if (v != null) setState(() => _estado = v); },
          items: EstadoBlog.values.map((e) => DropdownMenuItem(
            value: e,
            child: Row(children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: e.color)),
              Text(e.label, style: const TextStyle(fontSize: 12)),
            ]),
          )).toList(),
        ),
      ),
    );
  }

  // SEO body
  Widget _seoBody(Color color) {
    final descLen = _seoDescCtrl.text.length;
    final score = _seoScore;
    final scoreColor = score >= 80 ? const Color(0xFF16A34A)
        : score >= 50 ? const Color(0xFFD97706) : Colors.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rLabel('Título SEO'),
        TextField(controller: _seoTituloCtrl, style: const TextStyle(fontSize: 12),
            decoration: _rDeco('Título para buscadores')),
        const SizedBox(height: 4),
        // Barra de calidad SEO título
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _seoTituloCtrl.text.isEmpty ? 0
                : (_seoTituloCtrl.text.length / 60).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 10),
        _rLabel('Descripción SEO · $descLen/160'),
        TextField(
          controller: _seoDescCtrl,
          maxLines: 3, style: const TextStyle(fontSize: 12),
          decoration: _rDeco('Describe el artículo en 1-2 frases'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        _rLabel('URL canónica'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            'https://tusitio.com/blog/${_slugCtrl.text}',
            style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace',
                color: Color(0xFF6B7280)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        // Score total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.analytics_outlined, size: 15, color: scoreColor),
            const SizedBox(width: 8),
            Expanded(child: Text('Análisis SEO',
                style: TextStyle(fontSize: 12, color: scoreColor,
                    fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scoreColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$score/100',
                  style: const TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // Checklist SEO
        ..._seoChecks.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(c.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: c.$2 ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB)),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.$1, style: TextStyle(
                  fontSize: 10.5,
                  color: c.$2 ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                  fontWeight: c.$2 ? FontWeight.w600 : FontWeight.normal)),
              if (!c.$2)
                Text(c.$3, style: const TextStyle(fontSize: 9.5, color: Color(0xFFB0B5BF))),
            ])),
          ]),
        )),
      ]),
    );
  }

  // Compartir header (siempre muestra los iconos sociales)
  Widget _compartirHeader(Color color) {
    return InkWell(
      onTap: () => setState(() => _compartirExp = !_compartirExp),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          const Expanded(
            child: Text('Compartir en redes sociales',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
          ),
          // Iconos sociales siempre visibles
          _socialCircle(const Color(0xFF1877F2), Icons.facebook),
          const SizedBox(width: 5),
          _socialCircle(Colors.black87, Icons.close),
          const SizedBox(width: 5),
          _socialCircle(const Color(0xFF0A66C2), Icons.business_center_outlined),
          const SizedBox(width: 6),
          Icon(_compartirExp ? Icons.expand_less : Icons.expand_more,
              size: 16, color: const Color(0xFF9CA3AF)),
        ]),
      ),
    );
  }

  Widget _compartirBody(Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('La imagen de portada se usará al compartir en redes sociales.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
      const SizedBox(height: 8),
      Row(children: [
        _socialCircle(const Color(0xFF1877F2), Icons.facebook),
        const SizedBox(width: 8),
        Text('Facebook', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _socialCircle(Colors.black87, Icons.close),
        const SizedBox(width: 8),
        Text('X / Twitter', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _socialCircle(const Color(0xFF0A66C2), Icons.business_center_outlined),
        const SizedBox(width: 8),
        Text('LinkedIn', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    ]),
  );

  Widget _socialCircle(Color c, IconData icon) => Container(
    width: 26, height: 26,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white, size: 14),
  );

  // Cabecera colapsable genérica
  Widget _collapseHeader(String title, bool expanded, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
            const Spacer(),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                size: 16, color: const Color(0xFF9CA3AF)),
          ]),
        ),
      );

  // Sección con título y contenido
  Widget _rSection(String title, {required List<Widget> children, Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
            if (trailing != null) ...[const Spacer(), trailing],
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _rDivider() => Container(height: 1, color: const Color(0xFFF3F4F6));

  Widget _rLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280),
        fontWeight: FontWeight.w500)),
  );

  Widget _dateBox(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11.5)),
    ]),
  );

  Widget _chip(String label, Color color, VoidCallback onDelete) =>
      Container(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.w500)),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 13, color: color),
          ),
        ]),
      );

  InputDecoration _rDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: context.read<AppConfigProvider>().colorPrimario)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    isDense: true,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _statusBar(Color color) => Container(
    height: 34,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE8EAED))),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Text(
        _palabras == 0
            ? 'Empieza a escribir...'
            : '$_palabras palabras · Tiempo de lectura: $_minLectura min',
        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
      ),
      const Spacer(),
      Icon(Icons.check_circle_outline_rounded, size: 13,
          color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 4),
      Text('Guardado automático hace 1 min',
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGET
  // ══════════════════════════════════════════════════════════════════════════
  Widget _tabRow(List<String> labels, int sel, Color color, ValueChanged<int> onTap) =>
      Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8EAED)))),
        child: Row(
          children: List.generate(labels.length, (i) => Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: sel == i ? color : Colors.transparent, width: 2)),
                ),
                child: Text(labels[i], textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel == i ? color : const Color(0xFF6B7280))),
              ),
            ),
          )),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ══════════════════════════════════════════════════════════════════════════


  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'web/blog');
    if (mounted) setState(() { _imagenUrl = url ?? _imagenUrl; _subiendoImg = false; });
  }

  bool _subiendoImagenesExtra = false;

  Future<void> _subirImagenesAdicionales() async {
    setState(() => _subiendoImagenesExtra = true);
    final urls = await widget.svc.subirMultiplesImagenes(
        widget.empresaId, 'web/blog/imagenes');
    if (mounted) setState(() {
      _imagenes.addAll(urls);
      _subiendoImagenesExtra = false;
    });
  }

  Widget _addImagenBtn(Color color) {
    return InkWell(
      onTap: _subiendoImagenesExtra ? null : _subirImagenesAdicionales,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25), style: BorderStyle.solid),
        ),
        child: _subiendoImagenesExtra
            ? Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: color)))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: color, size: 22),
                const SizedBox(height: 4),
                Text('Añadir\nvarias', textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 10,
                        fontWeight: FontWeight.w600, height: 1.2)),
              ]),
      ),
    );
  }

  void _verImagenCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black, insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain,
                width: double.infinity, height: double.infinity),
          ),
          Positioned(top: 16, right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            )),
        ]),
      ),
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaPublicacion,
      firstDate: DateTime(2020), lastDate: DateTime(2035),
    );
    if (d != null && mounted) setState(() => _fechaPublicacion = d);
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover a la papelera'),
        content: Text('¿Eliminar "${_tituloCtrl.text}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.svc.eliminarEntradaBlog(
                  widget.empresaId, widget.entrada!.id);
              if (!mounted) return;
              Navigator.pop(this.context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirSelectorAutor(
      BuildContext context, List<Map<String, dynamic>> autores) async {
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
              ? autores
              : autores.where((a) =>
                  (a['nombre']?.toString() ?? '').toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seleccionar autor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar autor…',
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
                    onChanged: (_) => setModal(() {}),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: const Text('— Sin autor vinculado —',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    onTap: () {
                      setState(() { _autorNombre = ''; _autorId = null; });
                      Navigator.pop(ctx);
                    },
                  ),
                  ...filtrados.map((a) {
                    final id = a['id']?.toString() ?? '';
                    final nombre = a['nombre']?.toString() ?? '';
                    return ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _autorId == id ? const Color(0xFF2563EB) : Colors.grey[300]),
                      title: Text(nombre, style: TextStyle(
                        fontSize: 13,
                        fontWeight: _autorId == id ? FontWeight.w600 : FontWeight.normal,
                      )),
                      selected: _autorId == id,
                      selectedTileColor: const Color(0xFF2563EB).withValues(alpha: 0.06),
                      onTap: () {
                        setState(() { _autorNombre = nombre; _autorId = id; });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados para "${ctrl.text}"',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)))),
                ],
              )),
            ]),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _abrirSelectorLibro(
      BuildContext context, List<Map<String, dynamic>> libros) async {
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
              ? libros
              : libros.where((l) =>
                  (l['titulo']?.toString() ?? l['nombre']?.toString() ?? '').toLowerCase().contains(q) ||
                  (l['autor']?.toString() ?? l['campo_autor']?.toString() ?? '').toLowerCase().contains(q))
                  .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seleccionar libro',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título o autor…',
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
                    onChanged: (_) => setModal(() {}),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: const Text('— Sin libro vinculado —',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    onTap: () {
                      setState(() => _libroId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...filtrados.map((l) {
                    final id     = l['id']?.toString() ?? '';
                    final titulo = l['titulo']?.toString() ?? l['nombre']?.toString() ?? '';
                    final autor  = l['autor']?.toString() ?? l['campo_autor']?.toString() ?? '';
                    return ListTile(
                      leading: Icon(Icons.menu_book_rounded,
                          size: 18,
                          color: _libroId == id ? const Color(0xFF2563EB) : Colors.grey[300]),
                      title: Text(titulo, style: TextStyle(
                        fontSize: 13,
                        fontWeight: _libroId == id ? FontWeight.w600 : FontWeight.normal,
                      )),
                      subtitle: autor.isNotEmpty
                          ? Text(autor, style: const TextStyle(fontSize: 11.5, color: Colors.grey))
                          : null,
                      selected: _libroId == id,
                      selectedTileColor: const Color(0xFF2563EB).withValues(alpha: 0.06),
                      onTap: () {
                        setState(() => _libroId = id);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados para "${ctrl.text}"',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)))),
                ],
              )),
            ]),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _guardar(BuildContext context) async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El artículo necesita un título'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (!_slugOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La URL ya está en uso — elige otra'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    // Vaciar el campo de etiqueta pendiente antes de guardar
    final _tagPendiente = _etiquetaCtrl.text.trim();
    if (_tagPendiente.isNotEmpty && !_etiquetas.contains(_tagPendiente)) {
      _etiquetas.add(_tagPendiente);
      _etiquetaCtrl.clear();
    }
    setState(() => _guardando = true);
    final entrada = EntradaBlog(
      id: widget.entrada?.id ?? '',
      titulo: _tituloCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      resumen: _resumenCtrl.text.trim(),
      contenido: _contenidoCtrl.text,
      imagenUrl: _imagenUrl,
      imagenes: _imagenes,
      estado: _estado,
      fechaPublicacion: _fechaPublicacion,
      etiquetas: _etiquetas,
      autor: _autorNombre.trim(),
      categoriaId: _categoriaId,
      seoMetaTitle: _seoTituloCtrl.text.trim(),
      seoMetaDescription: _seoDescCtrl.text.trim(),
      seoKeywords: const [],
      eliminado: false,
      tipo: widget.entrada?.tipo ?? 'articulo',
      videoUrl: _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
      audioUrl: _audioUrlCtrl.text.trim().isEmpty ? null : _audioUrlCtrl.text.trim(),
      autorId: _autorId,
      libroId: _libroId,
    );
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.svc.guardarEntradaBlog(widget.empresaId, entrada);
      if (!mounted) return;
      if (_estado == EstadoBlog.publicado) {
        messenger.showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('✅ Publicado — visible en la web en breve')),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(_estado == EstadoBlog.programado
              ? '🕐 Artículo programado — se publicará automáticamente en la fecha indicada'
              : '✅ Borrador guardado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
      if (widget.onGuardado != null) {
        widget.onGuardado!();
      } else if (!widget.embedded) {
        nav.pop();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOCK INSERT HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _insertGaleria() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'blog');
    if (mounted) {
      setState(() => _subiendoImg = false);
      if (url != null) _ins('\n![imagen]($url)\n');
    }
  }


  // ══════════════════════════════════════════════════════════════════════════
  // TOOLBAR HELPERS — con soporte undo/redo
  // ══════════════════════════════════════════════════════════════════════════

  /// Guarda una snapshot del contenido actual para poder hacer undo.
  void _snapshot() {
    final current = _contenidoCtrl.text;
    if (_history.isEmpty || _history.last != current) {
      _history.add(current);
      if (_history.length > 60) _history.removeAt(0);
      _redoStack.clear();
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    _redoStack.add(_contenidoCtrl.text);
    _contenidoCtrl.text = _history.removeLast();
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _history.add(_contenidoCtrl.text);
    _contenidoCtrl.text = _redoStack.removeLast();
    setState(() {});
  }

  void _wrapSel(String mark) {
    _snapshot();
    final sel = _contenidoCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) { _ins('${mark}texto$mark'); return; }
    final t = _contenidoCtrl.text;
    final wrapped = '$mark${t.substring(sel.start, sel.end)}$mark';
    _contenidoCtrl.text = t.substring(0, sel.start) + wrapped + t.substring(sel.end);
    _contenidoCtrl.selection =
        TextSelection.collapsed(offset: sel.start + wrapped.length);
  }

  void _linePrefix(String prefix) {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid
        ? _contenidoCtrl.selection.start : t.length;
    final ls = t.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final at = ls < 0 ? 0 : ls + 1;
    _contenidoCtrl.text = t.substring(0, at) + prefix + t.substring(at);
    _contenidoCtrl.selection =
        TextSelection.collapsed(offset: at + prefix.length + (pos - at));
  }

  void _ins(String text) {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid
        ? _contenidoCtrl.selection.baseOffset : t.length;
    _contenidoCtrl.text = t.substring(0, pos) + text + t.substring(pos);
    _contenidoCtrl.selection =
        TextSelection.collapsed(offset: pos + text.length);
  }

  /// Elimina el prefijo de la línea actual (indent, bullet, cita, etc.).



  // ── Cambiar tipo de bloque ─────────────────────────────────────────────────

  void _cambiarTipoBloque(String tipo) {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid ? _contenidoCtrl.selection.start : t.length;
    final ls = t.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final at = ls < 0 ? 0 : ls + 1;
    final end = t.indexOf('\n', pos).let((i) => i < 0 ? t.length : i);
    var line = t.substring(at, end);
    // Remove existing Markdown prefix
    line = line.replaceFirst(RegExp(r'^#{1,3}\s|^>\s'), '');
    final prefixMap = {
      'Párrafo': '',
      'Título 1': '# ',
      'Título 2': '## ',
      'Título 3': '### ',
      'Cita': '> ',
    };
    final newLine = '${prefixMap[tipo] ?? ''}$line';
    _contenidoCtrl.text = t.substring(0, at) + newLine + t.substring(end);
    _contenidoCtrl.selection = TextSelection.collapsed(offset: at + newLine.length);
    setState(() {});
  }

  // ── Diálogos ───────────────────────────────────────────────────────────────


  Future<void> _mostrarHistorialVersiones(BuildContext ctx) async {
    if (widget.entrada?.id == null || widget.entrada!.id.isEmpty) return;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDlg) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.history_rounded, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text('Historial de versiones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            content: SizedBox(
              width: 380,
              height: 320,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.svc.obtenerVersiones(widget.empresaId, widget.entrada!.id),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final versiones = snap.data ?? [];
                  if (versiones.isEmpty) {
                    return const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 40, color: Color(0xFFD1D5DB)),
                        SizedBox(height: 12),
                        Text('Sin versiones guardadas todavía',
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                        SizedBox(height: 6),
                        Text('El historial se crea automáticamente al guardar',
                            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11)),
                      ],
                    ));
                  }
                  return ListView.separated(
                    itemCount: versiones.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = versiones[i];
                      final titulo = v['titulo'] as String? ?? 'Sin título';
                      final ts = v['guardada_en'];
                      DateTime? fecha;
                      if (ts is Timestamp) fecha = ts.toDate();
                      final palabras = (v['contenido'] as String? ?? '').split(RegExp(r'\s+')).length;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('${versiones.length - i}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6)))),
                        ),
                        title: Text(titulo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          fecha != null
                              ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')} · $palabras palabras'
                              : '$palabras palabras',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: dCtx,
                              builder: (confirmCtx) => AlertDialog(
                                title: const Text('Restaurar versión'),
                                content: const Text('¿Sobreescribir el artículo actual con esta versión?\n\nLa versión actual se guardará en el historial.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('Cancelar')),
                                  FilledButton(onPressed: () => Navigator.pop(confirmCtx, true), child: const Text('Restaurar')),
                                ],
                              ),
                            );
                            if (confirm != true || !mounted) return;
                            await widget.svc.restaurarVersion(widget.empresaId, widget.entrada!.id, v);
                            if (!mounted) return;
                            Navigator.pop(dCtx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('✅ Versión restaurada. Recarga el editor para ver los cambios.'),
                              backgroundColor: Color(0xFF10B981),
                            ));
                          },
                          child: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cerrar')),
            ],
          );
        },
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
