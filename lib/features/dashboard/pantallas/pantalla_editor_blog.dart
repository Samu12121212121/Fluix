import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _scrollCtrl    = ScrollController();
  final _tituloCtrl    = TextEditingController();
  final _slugCtrl      = TextEditingController();
  final _resumenCtrl   = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _autorCtrl     = TextEditingController();
  final _etiquetaCtrl  = TextEditingController();
  final _seoTituloCtrl = TextEditingController();
  final _seoDescCtrl   = TextEditingController();

  String?      _imagenUrl;
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
  int          _leftTab          = 0;
  int          _rightTab         = 0;
  Timer?       _slugTimer;

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
      _autorCtrl.text     = e.autor;
      _etiquetas          = List.from(e.etiquetas);
      _imagenUrl          = e.imagenUrl;
      _estado             = e.estado;
      _categoriaId        = e.categoriaId;
      _fechaPublicacion   = e.fechaPublicacion;
      _seoTituloCtrl.text = e.seoMetaTitle;
      _seoDescCtrl.text   = e.seoMetaDescription;
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
    _tituloCtrl.dispose();    _slugCtrl.dispose();      _resumenCtrl.dispose();
    _contenidoCtrl.dispose(); _autorCtrl.dispose();     _etiquetaCtrl.dispose();
    _seoTituloCtrl.dispose(); _seoDescCtrl.dispose();
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

    final body = Column(children: [
      _topBar(context, color),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _leftPanel(color),
          Expanded(child: _centerPanel(color)),
          _rightPanel(context, color),
        ]),
      ),
      _statusBar(color),
    ]);

    // Con callbacks = modo embebido completo (sin Scaffold)
    if (widget.onGuardado != null || widget.onCancelar != null) {
      return LayoutBuilder(builder: (_, c) {
        final h = c.maxHeight.isInfinite ? null : c.maxHeight;
        return SizedBox(width: double.infinity, height: h,
            child: ColoredBox(color: const Color(0xFFF5F7FA), child: body));
      });
    }

    return Scaffold(backgroundColor: const Color(0xFFF5F7FA), body: body);
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
        ]),
      )),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _topBar(BuildContext context, Color color) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Breadcrumb
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
          child: Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
        ),
        Text(
          _esNuevo ? 'Nuevo artículo' : 'Editar artículo',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: Color(0xFF111827)),
        ),
        const Spacer(),
        // Vista previa
        _topBtn(
          icon: _preview ? Icons.edit_note_rounded : Icons.visibility_outlined,
          label: _preview ? 'Editar' : 'Vista previa',
          onTap: () => setState(() => _preview = !_preview),
        ),
        const SizedBox(width: 6),
        // Vista web (fullscreen como visitante)
        _topBtn(
          icon: Icons.open_in_full_rounded,
          label: 'Vista web',
          onTap: () => _mostrarPreviewWeb(context),
        ),
        const SizedBox(width: 6),
        // Abrir en la web real
        if (_estado == EstadoBlog.publicado)
          _topBtn(
            icon: Icons.open_in_browser_rounded,
            label: 'Ver en la web',
            onTap: () => _abrirEnSitioWeb(context),
          ),
        const SizedBox(width: 8),
        // Guardar borrador
        _topBtn(
          icon: Icons.save_outlined,
          label: 'Guardar borrador',
          color: color,
          borderColor: color.withValues(alpha: 0.5),
          onTap: _guardando ? null : () => _guardar(context),
        ),
        const SizedBox(width: 8),
        // Publicar con dropdown
        SizedBox(
          height: 36,
          child: Row(children: [
            // Botón principal
            FilledButton(
              onPressed: _guardando ? null : () {
                setState(() => _estado = EstadoBlog.publicado);
                _guardar(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: _guardando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _estado == EstadoBlog.publicado ? 'Actualizar' : 'Publicar',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ]),
            ),
            // Dropdown arrow
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: color,
                border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
              ),
              child: PopupMenuButton<EstadoBlog>(
                tooltip: 'Opciones',
                onSelected: (e) => setState(() => _estado = e),
                itemBuilder: (_) => EstadoBlog.values.map((e) => PopupMenuItem(
                  value: e,
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: e.color),
                        margin: const EdgeInsets.only(right: 8)),
                    Text(e.label),
                  ]),
                )).toList(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ]),
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

  // ══════════════════════════════════════════════════════════════════════════
  // LEFT PANEL — Biblioteca de bloques
  // ══════════════════════════════════════════════════════════════════════════
  Widget _leftPanel(Color color) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Column(children: [
        _tabRow(['Bloques', 'Plantillas'], _leftTab, color,
            (i) => setState(() => _leftTab = i)),
        Expanded(
          child: _leftTab == 0 ? _blockLibrary(color) : _plantillaEmpty(),
        ),
        // Consejo Pro
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shield_outlined, size: 12, color: color),
              const SizedBox(width: 5),
              Text('Consejo Pro',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
            ]),
            const SizedBox(height: 5),
            const Text('Usa / para abrir el menú rápido y añadir contenido al instante',
                style: TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), height: 1.4)),
            const SizedBox(height: 6),
            Text('Ver atajos de teclado →',
                style: TextStyle(fontSize: 9.5, color: color,
                    decoration: TextDecoration.underline)),
          ]),
        ),
      ]),
    );
  }

  Widget _blockLibrary(Color color) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      children: [
        _libLabel('BLOQUES DE CONTENIDO'),
        _blockGrid([
          ['T',   'Párrafo',    null,                  () => _ins('\n\n')],
          ['H',   'Título',     null,                  () => _ins('# ')],
          [null,  'Lista',      Icons.format_list_bulleted, () => _ins('- ')],
          [null,  'Imagen',     Icons.image_outlined,  () => _ins('![alt](url)')],
          [null,  'Galería',    Icons.photo_library_outlined, () => _insertGaleria()],
          [null,  'Vídeo',      Icons.videocam_outlined, () => _insertVideo()],
          [null,  'Cita',       Icons.format_quote,    () => _ins('> ')],
          [null,  'Separador',  Icons.horizontal_rule, () => _ins('\n\n---\n\n')],
          [null,  'Código',     Icons.code,            () => _ins('```\n\n```')],
          [null,  'Tabla',      Icons.table_chart_outlined, _insertTabla],
          [null,  'Acordeón',   Icons.expand_more,     () => _ins('## Pregunta\n\nRespuesta\n')],
          [null,  'Tarjeta',    Icons.view_agenda_outlined, () => _ins('\n\n> 📋 **Título de la tarjeta**\n> \n> Contenido de la tarjeta...\n\n')],
          [null,  'Iconos',     Icons.star_border,     () => _ins('\n\n⭐ **Punto destacado**\nDescripción del primer punto.\n\n⚡ **Otro punto**\nDescripción del segundo punto.\n\n🎯 **Tercer punto**\nDescripción del tercer punto.\n\n')],
          [null,  'Timeline',   Icons.timeline,        () => _ins('\n\n📅 **${DateTime.now().year}** — Evento actual\n\n📅 **${DateTime.now().year - 1}** — Evento anterior\n\n📅 **${DateTime.now().year - 2}** — Evento histórico\n\n')],
          [null,  'Mapa',       Icons.map_outlined,    () => _insertMapa()],
          [null,  'Formulario', Icons.dynamic_form_outlined, () => _insertFormulario()],
          [null,  'Artículos',  Icons.view_list_outlined, () => _ins('\n\n<!-- fluix-articulos: cantidad=3 titulo="Artículos relacionados" -->\n\n')],
          ['<>',  'HTML',       null,                  () => _ins('<div>\n\n</div>')],
        ]),
        _libLabel('DISEÑO'),
        _blockGrid([
          [null, 'Espaciador', Icons.space_bar,              () => _ins('\n\n&nbsp;\n\n')],
          [null, 'Divisor',    Icons.horizontal_rule,         () => _ins('\n---\n')],
          [null, 'Caja',       Icons.crop_square_outlined,    () => _ins('> **Caja**\n> ')],
          [null, 'Fondo',      Icons.format_color_fill,       () => _insertFondo()],
          [null, 'Ancla',      Icons.anchor,                  () => _ins('<a id="ancla"></a>\n')],
        ]),
        _libLabel('REUTILIZABLES'),
        _reuseRow(Icons.radio_button_unchecked, 'Mis bloques'),
        _reuseRow(Icons.star_border_rounded,    'Bloques guardados'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _libLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Text(t, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF), letterSpacing: 0.6)),
  );

  Widget _blockGrid(List<List<dynamic>> defs) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.88,
    children: defs.map((d) => _blockTile(
      label:  d[1] as String,
      textIcon: d[0] as String?,
      icon:   d[2] as IconData?,
      onTap:  d[3] as VoidCallback,
    )).toList(),
  );

  Widget _blockTile({
    required String label,
    String? textIcon,
    IconData? icon,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (textIcon != null)
          Text(textIcon, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: Color(0xFF374151)))
        else if (icon != null)
          Icon(icon, size: 20, color: const Color(0xFF4B5563)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8.5, color: Color(0xFF4B5563)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _reuseRow(IconData icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(children: [
      Icon(icon, size: 15, color: const Color(0xFF6B7280)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151))),
    ]),
  );

  Widget _plantillaEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.dashboard_customize_outlined, size: 36, color: Colors.grey[300]),
      const SizedBox(height: 8),
      Text('Sin plantillas', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ],
  ));

  // ══════════════════════════════════════════════════════════════════════════
  // CENTER — Editor
  // ══════════════════════════════════════════════════════════════════════════
  Widget _centerPanel(Color color) {
    return Column(children: [
      // Título + Slug (fondo blanco)
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
        child: _titleSlugBlock(color),
      ),
      // Toolbar fila 1
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
        child: _toolbarRow1(color),
      ),
      // Toolbar fila 2
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
        child: _toolbarRow2(color),
      ),
      Container(height: 1, color: const Color(0xFFE8EAED)),
      // Área de contenido
      Expanded(
        child: _preview ? _buildPreview() : _buildEditor(),
      ),
    ]);
  }

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

  // Toolbar fila 1: tipo de bloque + formato inline
  Widget _toolbarRow1(Color color) {
    return Builder(builder: (ctx) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _buildTipoDropdown(),
        _vsep(),
        _tb(Icons.format_bold,         'Negrita (Ctrl+B)',   () => _wrapSel('**')),
        _tb(Icons.format_italic,       'Cursiva (Ctrl+I)',   () => _wrapSel('_')),
        _tb(Icons.format_underline,    'Subrayado',          () => _wrapSel('__')),
        _tb(Icons.format_strikethrough,'Tachado',            () => _wrapSel('~~')),
        _tb(Icons.code,                'Código inline',      () => _wrapSel('`')),
        _vsep(),
        _buildFontDropdown(),
        _buildSizeDropdown(),
        _vsep(),
        _tb(Icons.format_color_text,   'Color de texto',     () => _mostrarColorTexto(ctx)),
        _vsep(),
        _tb(Icons.format_indent_increase, 'Indentar',        () => _linePrefix('  ')),
        _tb(Icons.format_indent_decrease, 'Quitar sangría',  _sacarIndent),
        _tb(Icons.format_quote,        'Cita',               () => _linePrefix('> ')),
        _tb(Icons.format_list_bulleted,'Lista con viñetas',  () => _linePrefix('- ')),
        _tb(Icons.format_list_numbered,'Lista numerada',     () => _linePrefix('1. ')),
        _tb(Icons.table_chart_outlined,'Tabla',              _insertTabla),
        _tb(Icons.grid_on,             'Columnas (2 col)',   _insertarColumnas),
        _vsep(),
        _tb(Icons.undo_rounded,        'Deshacer (Ctrl+Z)',  _undo),
        _tb(Icons.redo_rounded,        'Rehacer (Ctrl+Y)',   _redo),
        _vsep(),
        _buildVariableDropdown(ctx),
      ]),
    ));
  }

  // Toolbar fila 2: mover bloques + media
  Widget _toolbarRow2(Color color) {
    return Builder(builder: (ctx) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _tb(Icons.circle_outlined,       'Punto especial',    () => _linePrefix('• ')),
        _tb(Icons.checklist_rounded,     'Casilla de check',  () => _linePrefix('- [ ] ')),
        _vsep(),
        _tb(Icons.arrow_upward_rounded,  'Subir línea',       _subirBloque),
        _tb(Icons.arrow_downward_rounded,'Bajar línea',       _bajarBloque),
        _vsep(),
        _tb(Icons.link_rounded,          'Insertar enlace',   () => _ins('[texto](url)')),
        _tb(Icons.image_outlined,        'Imagen por URL',    () => _ins('![alt](url)')),
        _tb(Icons.add_photo_alternate_outlined, 'Subir imagen', () => _insertGaleria()),
        _tb(Icons.videocam_outlined,     'Vídeo (YouTube/Vimeo)', () => _insertVideo()),
        _tb(Icons.attach_file_rounded,   'Adjunto / PDF',     () => _ins('\n[📎 archivo.pdf](url-del-archivo)\n')),
        _vsep(),
        _tb(Icons.refresh_rounded,       'Actualizar preview', () => setState(() => _preview = true)),
        _tb(Icons.settings_outlined,     'Info del bloque',   () => _mostrarAjustes(ctx)),
      ]),
    ));
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

  Widget _buildEditor() => SingleChildScrollView(
    controller: _scrollCtrl,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Hint cuando está vacío
            if (_contenidoCtrl.text.isEmpty)
              GestureDetector(
                onTap: () {},
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Empieza a escribir el contenido del artículo...',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 15, height: 1.85)),
                  SizedBox(height: 8),
                  Text('Usa / para añadir bloques rápidamente o escribe Markdown directamente.',
                      style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 13, height: 1.6)),
                ]),
              ),
            TextField(
              controller: _contenidoCtrl,
              maxLines: null, minLines: 22,
              style: const TextStyle(fontSize: 15, height: 1.85, color: Color(0xFF1F2937),
                  fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
        ),
      ),
    ),
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

                // Imagen hero con handles de selección y toolbar flotante
                if (_imagenUrl != null)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                      child: CachedNetworkImage(imageUrl: _imagenUrl!,
                        width: double.infinity, height: 260, fit: BoxFit.cover,
                        errorWidget: (_, e, s) => Container(height: 260,
                            color: const Color(0xFFF3F4F6))),
                    ),
                    // Toolbar flotante de imagen
                    Positioned(top: 14, left: 0, right: 0, child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 10)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min,
                          children: [Icons.image_outlined, Icons.photo_size_select_large_rounded,
                            Icons.link_rounded, Icons.edit_outlined, Icons.delete_outline]
                              .map((ic) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(ic, size: 16, color: const Color(0xFF374151))))
                              .toList()),
                      ),
                    )),
                    // Borde azul de selección
                    Positioned.fill(child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: color, width: 2),
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                      ),
                    )),
                  ]),

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
            TextField(
              controller: _autorCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: _rDeco('Nombre del autor'),
            ),
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
                    onPressed: _subiendoImg ? null : _subirImagen,
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
                onTap: _subiendoImg ? null : _subirImagen,
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

  /// Preview fullscreen como lo verá el visitante de la web.
  Future<String?> _obtenerDominio() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('web_avanzada')
          .get();
      return doc.data()?['dominio_propio_url'] as String?;
    } catch (_) { return null; }
  }

  Future<void> _abrirEnSitioWeb(BuildContext ctx) async {
    final dominio = await _obtenerDominio();
    if (dominio == null || dominio.isEmpty) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Configura el dominio en la sección "Configuración" para abrir en el sitio'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final slug = _slugCtrl.text.trim();
    final base = dominio.endsWith('/') ? dominio : '$dominio/';
    final url = Uri.parse('${base}blog/$slug');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _mostrarPreviewWeb(BuildContext ctx) {
    final color = context.read<AppConfigProvider>().colorPrimario;
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dCtx) => Dialog(
        insetPadding: const EdgeInsets.all(0),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF9FAFB),
          child: Column(children: [
            // ── Barra superior ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.language_rounded, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'tusitio.com/blog/${_slugCtrl.text.isEmpty ? 'tu-articulo' : _slugCtrl.text}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace',
                        color: Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text('Vista previa web',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(dCtx),
                  child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
                ),
              ]),
            ),
            const Divider(height: 1),
            // ── Contenido del artículo ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Imagen destacada
                      if (_imagenUrl != null)
                        CachedNetworkImage(imageUrl: _imagenUrl!,
                            width: double.infinity, height: 380, fit: BoxFit.cover,
                            errorWidget: (_, e, s) => const SizedBox.shrink()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 60),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Categoría
                          if (_categoriaId.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.categorias
                                    .where((c) => c.id == _categoriaId)
                                    .firstOrNull?.nombre ?? '',
                                style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
                              ),
                            ),
                          // Título
                          Text(
                            _tituloCtrl.text.isEmpty ? 'Sin título' : _tituloCtrl.text,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                                height: 1.2, color: Color(0xFF111827), letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 16),
                          // Metadata
                          Row(children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle),
                              child: Center(child: Text(
                                _autorCtrl.text.isEmpty ? 'A' : _autorCtrl.text[0].toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                              )),
                            ),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_autorCtrl.text.isEmpty ? 'Autor' : _autorCtrl.text,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151))),
                              Text(
                                '${_fechaPublicacion.day}/${_fechaPublicacion.month}/${_fechaPublicacion.year} · $_minLectura min de lectura · $_palabras palabras',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                              ),
                            ]),
                          ]),
                          // Etiquetas
                          if (_etiquetas.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(spacing: 6, runSpacing: 4, children: _etiquetas.map((t) =>
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('#$t', style: const TextStyle(fontSize: 11.5,
                                    color: Color(0xFF6B7280))),
                              )
                            ).toList()),
                          ],
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 32),
                          // Contenido Markdown
                          if (_contenidoCtrl.text.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('Sin contenido todavía',
                                  style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 16)),
                            ))
                          else
                            MarkdownBody(
                              data: _contenidoCtrl.text,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                h1: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                                    height: 1.3, color: Color(0xFF111827)),
                                h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                                    height: 1.35, color: Color(0xFF111827)),
                                h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                                    height: 1.4, color: Color(0xFF1F2937)),
                                p: const TextStyle(fontSize: 17, height: 1.85,
                                    color: Color(0xFF374151)),
                                strong: const TextStyle(fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827)),
                                em: const TextStyle(fontStyle: FontStyle.italic),
                                a: TextStyle(color: color, decoration: TextDecoration.underline),
                                blockquote: const TextStyle(fontSize: 17, height: 1.85,
                                    color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
                                blockquoteDecoration: BoxDecoration(
                                  border: const Border(left: BorderSide(color: Color(0xFFE5E7EB), width: 4)),
                                  color: const Color(0xFFF9FAFB),
                                ),
                                code: const TextStyle(fontFamily: 'monospace', fontSize: 14,
                                    backgroundColor: Color(0xFFF3F4F6), color: Color(0xFFD1477A)),
                                codeblockDecoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                listBullet: const TextStyle(fontSize: 17, color: Color(0xFF374151)),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'web/blog');
    if (mounted) setState(() { _imagenUrl = url ?? _imagenUrl; _subiendoImg = false; });
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
    setState(() => _guardando = true);
    final entrada = EntradaBlog(
      id: widget.entrada?.id ?? '',
      titulo: _tituloCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      resumen: _resumenCtrl.text.trim(),
      contenido: _contenidoCtrl.text,
      imagenUrl: _imagenUrl,
      estado: _estado,
      fechaPublicacion: _fechaPublicacion,
      etiquetas: _etiquetas,
      autor: _autorCtrl.text.trim(),
      categoriaId: _categoriaId,
      seoMetaTitle: _seoTituloCtrl.text.trim(),
      seoMetaDescription: _seoDescCtrl.text.trim(),
      seoKeywords: const [],
      eliminado: false,
      tipo: widget.entrada?.tipo ?? 'articulo',
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
            Expanded(child: Text(
              '¡Artículo publicado! Aparecerá en tu web en segundos '
              '(requiere el script instalado en tu sitio).',
            )),
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

  void _insertVideo() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insertar vídeo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'URL del vídeo',
            hintText: 'https://www.youtube.com/watch?v=...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              String embed = url;
              final yt = RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)').firstMatch(url);
              if (yt != null) embed = 'https://www.youtube.com/embed/${yt.group(1)}';
              final vm = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
              if (vm != null) embed = 'https://player.vimeo.com/video/${vm.group(1)}';
              _ins('\n\n<iframe src="$embed" width="100%" height="360" '
                  'frameborder="0" allowfullscreen '
                  'style="border-radius:8px;display:block"></iframe>\n\n');
              Navigator.pop(ctx);
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
  }

  void _insertMapa() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insertar mapa'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Dirección o nombre del lugar',
            hintText: 'Ej: Gran Vía, Madrid',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lugar = ctrl.text.trim();
              if (lugar.isEmpty) return;
              final q = Uri.encodeComponent(lugar);
              _ins('\n\n<iframe '
                  'src="https://maps.google.com/maps?q=$q&output=embed" '
                  'width="100%" height="350" '
                  'style="border:0;border-radius:8px;display:block" '
                  'allowfullscreen loading="lazy"></iframe>\n\n');
              Navigator.pop(ctx);
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
  }

  void _insertFormulario() {
    final tituloCtrl = TextEditingController(text: 'Contacta con nosotros');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insertar formulario de contacto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: tituloCtrl,
            decoration: const InputDecoration(
              labelText: 'Título del formulario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Se insertará el formulario Fluix con campos: nombre, email y mensaje.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final titulo = tituloCtrl.text.trim().isEmpty ? 'Contacto' : tituloCtrl.text.trim();
              _ins('\n\n<!-- fluix-form titulo="$titulo" campos="nombre,email,mensaje" boton="Enviar" -->\n\n');
              Navigator.pop(ctx);
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
  }

  void _insertFondo() {
    const opciones = [
      ('Azul suave',    'EFF6FF', 'DBEAFE'),
      ('Verde suave',   'F0FDF4', 'BBF7D0'),
      ('Amarillo suave','FFFBEB', 'FDE68A'),
      ('Rosa suave',    'FDF2F8', 'FBCFE8'),
      ('Morado suave',  'F5F3FF', 'DDD6FE'),
      ('Gris claro',    'F8FAFC', 'E2E8F0'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color de fondo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: opciones.map((o) {
          final bg = Color(int.parse('FF${o.$2}', radix: 16));
          final border = Color(int.parse('FF${o.$3}', radix: 16));
          return ListTile(
            dense: true,
            leading: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border),
              ),
            ),
            title: Text(o.$1, style: const TextStyle(fontSize: 13)),
            onTap: () {
              _ins('\n\n<div style="background:#${o.$2};border:1px solid #${o.$3};'
                  'padding:20px;border-radius:10px;margin:16px 0">\n\n'
                  'Contenido sobre fondo ${o.$1.toLowerCase()}...\n\n'
                  '</div>\n\n');
              Navigator.pop(ctx);
            },
          );
        }).toList()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
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

  /// Envuelve la selección (o inserta placeholder) con etiquetas HTML.
  void _wrapConHtml(String before, String after) {
    _snapshot();
    final sel = _contenidoCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _ins('${before}texto$after');
      return;
    }
    final t = _contenidoCtrl.text;
    final selected = t.substring(sel.start, sel.end);
    final wrapped = '$before$selected$after';
    _contenidoCtrl.text = t.substring(0, sel.start) + wrapped + t.substring(sel.end);
    _contenidoCtrl.selection = TextSelection.collapsed(offset: sel.start + wrapped.length);
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

  /// Elimina el prefijo de la línea actual (indent, bullet, cita, etc.).
  void _sacarIndent() {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid ? _contenidoCtrl.selection.start : t.length;
    final ls = t.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final at = ls < 0 ? 0 : ls + 1;
    final resto = t.substring(at);
    final prefijos = ['  ', '> ', '• ', '- ', '1. ', '# ', '## ', '### '];
    for (final p in prefijos) {
      if (resto.startsWith(p)) {
        _contenidoCtrl.text = t.substring(0, at) + resto.substring(p.length);
        _contenidoCtrl.selection = TextSelection.collapsed(
            offset: (pos - p.length).clamp(at, _contenidoCtrl.text.length));
        setState(() {});
        return;
      }
    }
  }

  void _ins(String text) {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid
        ? _contenidoCtrl.selection.end : t.length;
    _contenidoCtrl.text = t.substring(0, pos) + text + t.substring(pos);
    _contenidoCtrl.selection =
        TextSelection.collapsed(offset: pos + text.length);
  }

  void _insertTabla() => _ins(
    '\n\n| Columna 1 | Columna 2 | Columna 3 |\n'
    '|-----------|-----------|----------|\n'
    '| Celda 1   | Celda 2   | Celda 3  |\n\n',
  );

  void _insertarColumnas() => _ins(
    '\n\n<div style="display:grid;grid-template-columns:1fr 1fr;'
    'gap:24px;margin:20px 0;align-items:start">\n'
    '<div>\n\nContenido de la columna izquierda...\n\n</div>\n'
    '<div>\n\nContenido de la columna derecha...\n\n</div>\n'
    '</div>\n\n',
  );

  // ── Subir / Bajar bloque (línea) ──────────────────────────────────────────

  void _subirBloque() {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid ? _contenidoCtrl.selection.start : t.length;
    final lines = t.split('\n');
    int charPos = 0;
    int lineIdx = lines.length - 1;
    for (int i = 0; i < lines.length; i++) {
      if (charPos + lines[i].length >= pos) { lineIdx = i; break; }
      charPos += lines[i].length + 1;
    }
    if (lineIdx == 0) return;
    final temp = lines[lineIdx];
    lines[lineIdx] = lines[lineIdx - 1];
    lines[lineIdx - 1] = temp;
    _contenidoCtrl.text = lines.join('\n');
    int newPos = 0;
    for (int i = 0; i < lineIdx - 1; i++) newPos += lines[i].length + 1;
    _contenidoCtrl.selection = TextSelection.collapsed(offset: newPos);
    setState(() {});
  }

  void _bajarBloque() {
    _snapshot();
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid ? _contenidoCtrl.selection.start : t.length;
    final lines = t.split('\n');
    int charPos = 0;
    int lineIdx = lines.length - 1;
    for (int i = 0; i < lines.length; i++) {
      if (charPos + lines[i].length >= pos) { lineIdx = i; break; }
      charPos += lines[i].length + 1;
    }
    if (lineIdx >= lines.length - 1) return;
    final temp = lines[lineIdx];
    lines[lineIdx] = lines[lineIdx + 1];
    lines[lineIdx + 1] = temp;
    _contenidoCtrl.text = lines.join('\n');
    int newPos = 0;
    for (int i = 0; i <= lineIdx; i++) newPos += lines[i].length + 1;
    _contenidoCtrl.selection = TextSelection.collapsed(offset: newPos.clamp(0, _contenidoCtrl.text.length));
    setState(() {});
  }

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

  void _mostrarColorTexto(BuildContext ctx) {
    const opciones = [
      ('Rojo',    Color(0xFFEF4444)),
      ('Naranja', Color(0xFFF97316)),
      ('Amarillo',Color(0xFFEAB308)),
      ('Verde',   Color(0xFF10B981)),
      ('Azul',    Color(0xFF3B82F6)),
      ('Morado',  Color(0xFF8B5CF6)),
      ('Rosa',    Color(0xFFEC4899)),
      ('Gris',    Color(0xFF6B7280)),
      ('Negro',   Color(0xFF111827)),
    ];
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Color de texto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Wrap(
          spacing: 10, runSpacing: 10,
          children: opciones.map((o) {
            final hex = o.$2.value.toRadixString(16).substring(2).toUpperCase();
            return Tooltip(
              message: o.$1,
              child: GestureDetector(
                onTap: () {
                  _wrapConHtml('<span style="color:#$hex">', '</span>');
                  Navigator.pop(dCtx);
                },
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: o.$2, shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300))),
              ),
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar'))],
      ),
    );
  }

  void _mostrarVariables(BuildContext ctx) {
    const vars = [
      ('{{nombre_empresa}}', 'Nombre de la empresa'),
      ('{{telefono}}',       'Teléfono de contacto'),
      ('{{email}}',          'Email de contacto'),
      ('{{web}}',            'URL del sitio web'),
      ('{{direccion}}',      'Dirección postal'),
      ('{{ciudad}}',         'Ciudad'),
      ('{{horario}}',        'Horario de apertura'),
      ('{{fecha}}',          'Fecha de hoy'),
      ('{{año}}',            'Año actual'),
      ('{{mes}}',            'Mes actual'),
    ];
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Insertar variable dinámica',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: ListView(shrinkWrap: true, children: vars.map((v) =>
            ListTile(
              dense: true,
              title: Text(v.$1, style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Color(0xFF3B82F6))),
              subtitle: Text(v.$2, style: const TextStyle(fontSize: 11)),
              onTap: () {
                _ins(v.$1);
                Navigator.pop(dCtx);
              },
            )
          ).toList()),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cerrar'))],
      ),
    );
  }

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

  void _mostrarAjustes(BuildContext ctx) {
    final t = _contenidoCtrl.text;
    final pos = _contenidoCtrl.selection.isValid ? _contenidoCtrl.selection.start : t.length;
    final ls = t.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final at = ls < 0 ? 0 : ls + 1;
    final end = t.indexOf('\n', pos).let((i) => i < 0 ? t.length : i);
    final line = t.substring(at, end);
    final tipo = line.startsWith('# ') ? 'Título 1'
        : line.startsWith('## ') ? 'Título 2'
        : line.startsWith('### ') ? 'Título 3'
        : line.startsWith('> ') ? 'Cita'
        : line.startsWith('- ') ? 'Lista'
        : line.startsWith('![') ? 'Imagen'
        : 'Párrafo';
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Bloque actual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Tipo', tipo),
          _infoRow('Línea', '${t.substring(0, at).split('\n').length}'),
          _infoRow('Caracteres', '${line.length}'),
          _infoRow('Palabras', '${line.trim().isEmpty ? 0 : line.trim().split(RegExp(r'\s+')).length}'),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
              child: Text(line.length > 80 ? '${line.substring(0, 80)}...' : line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF374151))),
            ),
          ],
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cerrar'))],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)))),
      Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    ]),
  );

  // ── Dropdowns funcionales ──────────────────────────────────────────────────

  Widget _buildTipoDropdown() => PopupMenuButton<String>(
    tooltip: 'Tipo de bloque',
    onSelected: _cambiarTipoBloque,
    itemBuilder: (_) => ['Párrafo', 'Título 1', 'Título 2', 'Título 3', 'Cita']
        .map((t) => PopupMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
        .toList(),
    child: _dropBtn('Párrafo'),
  );

  Widget _buildFontDropdown() {
    const fonts = ['Inter', 'Georgia', 'Arial', 'Courier New', 'Verdana'];
    return PopupMenuButton<String>(
      tooltip: 'Fuente del texto',
      onSelected: (f) => _wrapConHtml('<span style="font-family:\'$f\',sans-serif">', '</span>'),
      itemBuilder: (_) => fonts.map((f) => PopupMenuItem(
        value: f,
        child: Text(f, style: TextStyle(fontFamily: f, fontSize: 13)),
      )).toList(),
      child: _dropBtn('Inter'),
    );
  }

  Widget _buildSizeDropdown() {
    const sizes = ['12', '14', '16', '18', '20', '24', '28', '32'];
    return PopupMenuButton<String>(
      tooltip: 'Tamaño de texto',
      onSelected: (s) => _wrapConHtml('<span style="font-size:${s}px">', '</span>'),
      itemBuilder: (_) => sizes.map((s) => PopupMenuItem(
        value: s,
        child: Text('$s px', style: TextStyle(fontSize: (double.tryParse(s) ?? 13).clamp(10, 18))),
      )).toList(),
      child: _dropBtn('16'),
    );
  }

  Widget _buildVariableDropdown(BuildContext ctx) => GestureDetector(
    onTap: () => _mostrarVariables(ctx),
    child: _dropBtn('Insertar variable'),
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
