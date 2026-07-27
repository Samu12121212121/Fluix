import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// EDITOR DE BLOG — UI PROFESIONAL
// ═════════════════════════════════════════════════════════════════════════════

class PantallaEditorBlog extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final EntradaBlog? entrada;
  final List<CategoriaBlog> categorias;

  const PantallaEditorBlog({
    super.key,
    required this.empresaId,
    required this.svc,
    required this.categorias,
    this.entrada,
  });

  @override
  State<PantallaEditorBlog> createState() => _PantallaEditorBlogState();
}

class _PantallaEditorBlogState extends State<PantallaEditorBlog> {
  final _scrollCtrl = ScrollController();
  final _tituloCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _resumenCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _autorCtrl = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final _seoTituloCtrl = TextEditingController();
  final _seoDescCtrl = TextEditingController();

  String? _imagenUrl;
  EstadoBlog _estado = EstadoBlog.borrador;
  String _categoriaId = '';
  DateTime _fechaPublicacion = DateTime.now();
  List<String> _etiquetas = [];
  bool _slugManual = false;
  bool _slugOk = true;
  bool _guardando = false;
  bool _subiendoImg = false;
  bool _seoExpanded = false;
  bool _preview = false;
  Timer? _slugTimer;

  bool get _esNuevo => widget.entrada == null;
  int get _palabras => _contenidoCtrl.text.trim().isEmpty
      ? 0
      : _contenidoCtrl.text.trim().split(RegExp(r'\s+')).length;
  int get _minLectura => (_palabras / 200).ceil().clamp(1, 99);

  @override
  void initState() {
    super.initState();
    if (widget.entrada != null) {
      final e = widget.entrada!;
      _tituloCtrl.text = e.titulo;
      _slugCtrl.text = e.slug;
      _resumenCtrl.text = e.resumen;
      _contenidoCtrl.text = e.contenido;
      _autorCtrl.text = e.autor;
      _etiquetas = List.from(e.etiquetas);
      _imagenUrl = e.imagenUrl;
      _estado = e.estado;
      _categoriaId = e.categoriaId;
      _fechaPublicacion = e.fechaPublicacion;
      _seoTituloCtrl.text = e.seoMetaTitle;
      _seoDescCtrl.text = e.seoMetaDescription;
      _slugManual = e.slug.isNotEmpty;
    }
    _tituloCtrl.addListener(_onTitulo);
    _slugCtrl.addListener(_onSlug);
    _contenidoCtrl.addListener(() => setState(() {}));
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

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _tituloCtrl.dispose(); _slugCtrl.dispose(); _resumenCtrl.dispose();
    _contenidoCtrl.dispose(); _autorCtrl.dispose(); _etiquetaCtrl.dispose();
    _seoTituloCtrl.dispose(); _seoDescCtrl.dispose();
    _slugTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(color),
      body: Column(
        children: [
          _buildStatusBar(color),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPortada(color),
                  const SizedBox(height: 12),
                  _buildSeccionTitulo(color),
                  const SizedBox(height: 12),
                  _buildEditorContenido(color),
                  const SizedBox(height: 12),
                  _buildDetalles(color),
                  const SizedBox(height: 12),
                  _buildSeo(color),
                ],
              ),
            ),
          ),
          _buildFooterBar(color),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(Color color) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE8EAED)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _esNuevo ? 'Nuevo artículo' : 'Editando artículo',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (!_esNuevo && _tituloCtrl.text.isNotEmpty)
            Text(
              _tituloCtrl.text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A8FA3)),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        // Toggle preview
        IconButton(
          icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
          tooltip: _preview ? 'Volver a editar' : 'Vista previa',
          onPressed: () => setState(() => _preview = !_preview),
        ),
        // Selector de estado
        _EstadoChip(
          estado: _estado,
          onChanged: (e) => setState(() => _estado = e),
        ),
        const SizedBox(width: 8),
        // Guardar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: _guardando ? null : () => _guardar(context),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _guardando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Publicar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Barra de estado ────────────────────────────────────────────────────────

  Widget _buildStatusBar(Color color) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _estado.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _estado.color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _estado.color)),
              const SizedBox(width: 5),
              Text(_estado.label,
                  style: TextStyle(fontSize: 11, color: _estado.color, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          Text('$_palabras palabras · $_minLectura min lectura',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A8FA3))),
          const Spacer(),
          if (_tituloCtrl.text.isNotEmpty)
            Text(
              '/${_slugCtrl.text}',
              style: TextStyle(
                fontSize: 11,
                color: _slugOk ? const Color(0xFF8A8FA3) : Colors.red,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  // ── Imagen de portada ──────────────────────────────────────────────────────

  Widget _buildPortada(Color color) {
    return _Card(
      label: 'Imagen de portada',
      child: _imagenUrl != null
          ? Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_imagenUrl!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(top: 8, right: 8,
                child: Row(children: [
                  _MiniBtn(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Cambiar',
                    onTap: _subiendoImg ? null : _subirImagen,
                  ),
                  const SizedBox(width: 6),
                  _MiniBtn(
                    icon: Icons.delete_outline,
                    label: 'Eliminar',
                    danger: true,
                    onTap: () => setState(() => _imagenUrl = null),
                  ),
                ]),
              ),
            ])
          : GestureDetector(
              onTap: _subiendoImg ? null : _subirImagen,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _subiendoImg
                    ? Center(child: CircularProgressIndicator(color: color, strokeWidth: 2))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: color, size: 32),
                        const SizedBox(height: 8),
                        Text('Toca para añadir imagen de portada',
                            style: TextStyle(color: color, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('JPG, PNG · Recomendado 1200×630px',
                            style: TextStyle(color: Color(0xFF8A8FA3), fontSize: 11)),
                      ]),
              ),
            ),
    );
  }

  // ── Título y URL ───────────────────────────────────────────────────────────

  Widget _buildSeccionTitulo(Color color) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _tituloCtrl,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Título del artículo',
            hintStyle: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: Color(0xFFCDD0D8)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFFEEF0F3)),
        const SizedBox(height: 10),
        Row(children: [
          const Text('URL del artículo',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8FA3), fontWeight: FontWeight.w500)),
          const Spacer(),
          if (!_slugOk)
            const Text('⚠ Esta URL ya está en uso',
                style: TextStyle(fontSize: 11, color: Colors.red)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('blog/', style: TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _slugCtrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: _slugOk ? const Color(0xFFDDE1E8) : Colors.red,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: _slugOk ? const Color(0xFFDDE1E8) : Colors.red,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                suffixIcon: _slugOk
                    ? const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 16)
                    : const Icon(Icons.error, color: Colors.red, size: 16),
              ),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]'))],
              onChanged: (_) => _slugManual = true,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _resumenCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, color: Color(0xFF4A4E5A), height: 1.5),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Escribe un breve resumen del artículo (aparece en el listado y en Google)…',
            hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCDD0D8)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ]),
    );
  }

  // ── Editor de contenido ────────────────────────────────────────────────────

  Widget _buildEditorContenido(Color color) {
    return _Card(
      label: 'Contenido',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_preview)
          _Toolbar(ctrl: _contenidoCtrl, color: color, onChanged: () => setState(() {})),
        if (!_preview) const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFFEEF0F3)),
        const SizedBox(height: 8),
        if (_preview)
          _contenidoCtrl.text.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('El artículo está vacío',
                        style: TextStyle(color: Color(0xFFCDD0D8))),
                  ),
                )
              : MarkdownBody(
                  data: _contenidoCtrl.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF2D3142)),
                    h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                    h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
                    h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                    blockquote: const TextStyle(color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
                    code: const TextStyle(fontFamily: 'monospace', fontSize: 13,
                        backgroundColor: Color(0xFFEEF0F3)),
                    tableHead: const TextStyle(fontWeight: FontWeight.w700),
                    tableBorder: TableBorder.all(color: const Color(0xFFDDE1E8)),
                    tableHeadAlign: TextAlign.left,
                  ),
                )
        else
          TextField(
            controller: _contenidoCtrl,
            maxLines: null,
            minLines: 16,
            style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF2D3142),
                fontFamily: 'monospace'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Empieza a escribir tu artículo aquí…\n\n'
                  'Usa # para títulos, **negrita**, _cursiva_\n'
                  'Usa el toolbar de arriba para formatear rápido',
              hintStyle: TextStyle(color: Color(0xFFCDD0D8), fontSize: 14),
            ),
          ),
      ]),
    );
  }

  // ── Detalles del artículo ──────────────────────────────────────────────────

  Widget _buildDetalles(Color color) {
    return _Card(
      label: 'Detalles del artículo',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Categoría
        _FieldLabel('Categoría'),
        DropdownButtonFormField<String>(
          value: _categoriaId.isEmpty ? null : _categoriaId,
          decoration: _inputDeco('Sin categoría'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Sin categoría')),
            ...widget.categorias.map((c) => DropdownMenuItem(
                  value: c.id, child: Text(c.nombre))),
          ],
          onChanged: (v) => setState(() => _categoriaId = v ?? ''),
        ),
        const SizedBox(height: 14),

        // Autor
        _FieldLabel('Autor'),
        TextField(
          controller: _autorCtrl,
          decoration: _inputDeco('Nombre del autor o autora'),
        ),
        const SizedBox(height: 14),

        // Fecha
        _FieldLabel('Fecha de publicación'),
        GestureDetector(
          onTap: () => _seleccionarFecha(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDE1E8)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: color),
              const SizedBox(width: 10),
              Text(
                '${_fechaPublicacion.day.toString().padLeft(2, '0')} / '
                '${_fechaPublicacion.month.toString().padLeft(2, '0')} / '
                '${_fechaPublicacion.year}',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF8A8FA3)),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Etiquetas
        _FieldLabel('Etiquetas'),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            ..._etiquetas.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => setState(() => _etiquetas.remove(t)),
              backgroundColor: color.withValues(alpha: 0.08),
              side: BorderSide(color: color.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _etiquetaCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _inputDeco('+ Añadir etiqueta'),
                onSubmitted: (v) {
                  final tag = v.trim();
                  if (tag.isNotEmpty && !_etiquetas.contains(tag)) {
                    setState(() { _etiquetas.add(tag); _etiquetaCtrl.clear(); });
                  }
                },
              ),
            ),
          ],
        ),

        // Estado
        const SizedBox(height: 14),
        _FieldLabel('Estado'),
        Row(children: EstadoBlog.values.map((e) {
          final sel = e == _estado;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _estado = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? e.color : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? e.color : const Color(0xFFDDE1E8)),
                ),
                child: Column(children: [
                  Icon(
                    e == EstadoBlog.borrador ? Icons.edit_note :
                    e == EstadoBlog.publicado ? Icons.public :
                    Icons.schedule,
                    size: 18,
                    color: sel ? Colors.white : e.color,
                  ),
                  const SizedBox(height: 4),
                  Text(e.label,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : e.color,
                      )),
                ]),
              ),
            ),
          ));
        }).toList()),

        if (_estado == EstadoBlog.programado) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: EstadoBlog.programado.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: EstadoBlog.programado.color.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'El artículo se publicará automáticamente en la fecha indicada arriba.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4A4E5A)),
            ),
          ),
        ],
      ]),
    );
  }

  // ── SEO ───────────────────────────────────────────────────────────────────

  Widget _buildSeo(Color color) {
    final descLen = _seoDescCtrl.text.length;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _seoExpanded = !_seoExpanded),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A8FA3)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('SEO y redes sociales',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const Text('Cómo te ve Google al compartir',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A8FA3))),
            const SizedBox(width: 6),
            Icon(_seoExpanded ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF8A8FA3)),
          ]),
        ),
        if (_seoExpanded) ...[
          const SizedBox(height: 14),
          _FieldLabel('Título en Google (si es diferente al título del artículo)'),
          TextField(controller: _seoTituloCtrl, decoration: _inputDeco('Título SEO')),
          const SizedBox(height: 12),
          _FieldLabel(
            'Descripción para buscadores · ${descLen}/160 caracteres',
            color: descLen > 0 && descLen <= 160 ? const Color(0xFF34A853) : null,
          ),
          TextField(
            controller: _seoDescCtrl,
            maxLines: 3,
            decoration: _inputDeco(
                'Describe el artículo en 1-2 frases. Aparece en los resultados de Google.'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8EAED)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF8A8FA3)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La imagen de portada se usa automáticamente al compartir en WhatsApp, '
                  'Twitter y redes sociales.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A8FA3)),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Footer con estadísticas ────────────────────────────────────────────────

  Widget _buildFooterBar(Color color) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _palabras == 0
              ? const Text('Empieza a escribir…',
                  style: TextStyle(fontSize: 12, color: Color(0xFFCDD0D8)))
              : Text('$_palabras palabras · aprox. $_minLectura min de lectura',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
          const Spacer(),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            style: TextButton.styleFrom(foregroundColor: color),
            child: const Text('Guardar borrador', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _guardando ? null : () {
              setState(() => _estado = EstadoBlog.publicado);
              _guardar(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _estado == EstadoBlog.publicado ? 'Actualizar' : 'Publicar ahora',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'web/blog');
    if (mounted) setState(() { _imagenUrl = url; _subiendoImg = false; });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaPublicacion,
      firstDate: DateTime(2020), lastDate: DateTime(2035),
    );
    if (d != null && mounted) setState(() => _fechaPublicacion = d);
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
    );
    try {
      await widget.svc.guardarEntradaBlog(widget.empresaId, entrada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_estado == EstadoBlog.publicado
              ? '✅ Artículo publicado' : '✅ Borrador guardado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFCDD0D8), fontSize: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE1E8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE1E8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: context.read<AppConfigProvider>().colorPrimario),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    isDense: true,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS DE APOYO
// ═════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  final String? label;

  const _Card({required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF8A8FA3), letterSpacing: 0.4,
            )),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const _FieldLabel(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
      style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: color ?? const Color(0xFF4A4E5A),
      )),
  );
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  const _MiniBtn({required this.icon, required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: danger ? Colors.red : Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ]),
    ),
  );
}

class _EstadoChip extends StatelessWidget {
  final EstadoBlog estado;
  final ValueChanged<EstadoBlog> onChanged;
  const _EstadoChip({required this.estado, required this.onChanged});

  @override
  Widget build(BuildContext context) => PopupMenuButton<EstadoBlog>(
    tooltip: 'Cambiar estado',
    initialValue: estado,
    onSelected: onChanged,
    itemBuilder: (_) => EstadoBlog.values.map((e) => PopupMenuItem(
      value: e,
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: e.color)),
        const SizedBox(width: 10),
        Text(e.label),
        if (e == estado) ...[
          const Spacer(),
          const Icon(Icons.check, size: 16),
        ],
      ]),
    )).toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estado.color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: estado.color)),
        const SizedBox(width: 6),
        Text(estado.label,
          style: TextStyle(color: estado.color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Icon(Icons.arrow_drop_down, color: estado.color, size: 16),
      ]),
    ),
  );
}

// ── Toolbar de formato Markdown ───────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final TextEditingController ctrl;
  final Color color;
  final VoidCallback onChanged;
  const _Toolbar({required this.ctrl, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Encabezados + Formato de texto
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            // ── Encabezados ──
            _ToolBtn(label: 'T1', tooltip: 'Título principal (H1)', onTap: () => _insertLineStart('# ', ctrl, onChanged)),
            _ToolBtn(label: 'T2', tooltip: 'Subtítulo (H2)', onTap: () => _insertLineStart('## ', ctrl, onChanged)),
            _ToolBtn(label: 'T3', tooltip: 'Sección (H3)', onTap: () => _insertLineStart('### ', ctrl, onChanged)),
            _sep(),
            // ── Formato inline ──
            _ToolBtn(icon: Icons.format_bold, tooltip: 'Negrita', onTap: () => _wrap('**', ctrl, onChanged)),
            _ToolBtn(icon: Icons.format_italic, tooltip: 'Cursiva', onTap: () => _wrap('_', ctrl, onChanged)),
            _ToolBtn(icon: Icons.format_strikethrough, tooltip: 'Tachado', onTap: () => _wrap('~~', ctrl, onChanged)),
            _ToolBtn(icon: Icons.code, tooltip: 'Código', onTap: () => _wrap('`', ctrl, onChanged)),
            _ToolBtn(icon: Icons.format_underline, tooltip: 'Subrayado', onTap: () => _wrap('__', ctrl, onChanged)),
          ]),
        ),
        const SizedBox(height: 4),
        // Fila 2: Listas + Bloques + Media
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            // ── Listas ──
            _ToolBtn(icon: Icons.format_list_bulleted, tooltip: 'Lista de puntos', onTap: () => _insertLineStart('- ', ctrl, onChanged)),
            _ToolBtn(icon: Icons.format_list_numbered, tooltip: 'Lista numerada', onTap: () => _insertLineStart('1. ', ctrl, onChanged)),
            _ToolBtn(icon: Icons.checklist, tooltip: 'Lista de tareas', onTap: () => _insertLineStart('- [ ] ', ctrl, onChanged)),
            _sep(),
            // ── Bloques ──
            _ToolBtn(icon: Icons.format_quote, tooltip: 'Cita / Destacado', onTap: () => _insertBlock('\n> ', ctrl, onChanged)),
            _ToolBtn(icon: Icons.data_object, tooltip: 'Bloque de código', onTap: () => _insertBlock('\n```\n', ctrl, onChanged, closing: '\n```')),
            _ToolBtn(icon: Icons.table_chart_outlined, tooltip: 'Tabla', onTap: () => _insertTabla(ctrl, onChanged)),
            _sep(),
            // ── Media / Otros ──
            _ToolBtn(icon: Icons.link, tooltip: 'Enlace', onTap: () => _insertEnlace(ctrl, onChanged)),
            _ToolBtn(icon: Icons.image_outlined, tooltip: 'Imagen', onTap: () => _insertTexto('![descripción](url)', ctrl, onChanged)),
            _ToolBtn(icon: Icons.horizontal_rule, tooltip: 'Línea separadora', onTap: () => _insertTexto('\n\n---\n\n', ctrl, onChanged)),
            _ToolBtn(icon: Icons.space_bar, tooltip: 'Salto de línea', onTap: () => _insertTexto('\n\n', ctrl, onChanged)),
          ]),
        ),
      ],
    );
  }

  Widget _sep() => Container(
    width: 1, height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: const Color(0xFFE0E4EC),
  );

  void _insertTexto(String text, TextEditingController c, VoidCallback cb) {
    final sel = c.selection;
    final t = c.text;
    final pos = sel.isValid ? sel.end : t.length;
    c.text = t.substring(0, pos) + text + t.substring(pos);
    c.selection = TextSelection.collapsed(offset: pos + text.length);
    cb();
  }

  // Inserta al inicio de la línea actual
  void _insertLineStart(String prefix, TextEditingController c, VoidCallback cb) {
    final sel = c.selection;
    final t = c.text;
    final pos = sel.isValid ? sel.start : t.length;
    // Encontrar inicio de línea
    final lineStart = t.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final insertAt = lineStart < 0 ? 0 : lineStart + 1;
    c.text = t.substring(0, insertAt) + prefix + t.substring(insertAt);
    c.selection = TextSelection.collapsed(offset: insertAt + prefix.length + (pos - insertAt));
    cb();
  }

  void _insertBlock(String opening, TextEditingController c, VoidCallback cb, {String closing = ''}) {
    final full = opening + (closing.isEmpty ? '' : closing);
    _insertTexto(full, c, cb);
  }

  void _wrap(String mark, TextEditingController c, VoidCallback cb) {
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _insertTexto('${mark}texto$mark', c, cb);
      return;
    }
    final t = c.text;
    final selected = t.substring(sel.start, sel.end);
    final wrapped = '$mark$selected$mark';
    c.text = t.substring(0, sel.start) + wrapped + t.substring(sel.end);
    c.selection = TextSelection.collapsed(offset: sel.start + wrapped.length);
    cb();
  }

  void _insertEnlace(TextEditingController c, VoidCallback cb) {
    final sel = c.selection;
    final t = c.text;
    if (sel.isValid && !sel.isCollapsed) {
      final selected = t.substring(sel.start, sel.end);
      final link = '[$selected](url)';
      c.text = t.substring(0, sel.start) + link + t.substring(sel.end);
      c.selection = TextSelection.collapsed(offset: sel.start + link.length);
    } else {
      _insertTexto('[texto del enlace](url)', c, cb);
      return;
    }
    cb();
  }

  void _insertTabla(TextEditingController c, VoidCallback cb) {
    const tabla = '\n\n| Columna 1 | Columna 2 | Columna 3 |\n'
        '|-----------|-----------|----------|\n'
        '| Celda 1   | Celda 2   | Celda 3  |\n'
        '| Celda 4   | Celda 5   | Celda 6  |\n\n';
    _insertTexto(tabla, c, cb);
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolBtn({this.icon, this.label, required this.tooltip, required this.onTap})
      : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: icon != null
            ? Icon(icon, size: 17, color: const Color(0xFF4A4E5A))
            : Text(label!,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Color(0xFF4A4E5A), fontFamily: 'monospace',
                )),
      ),
    ),
  );
}
