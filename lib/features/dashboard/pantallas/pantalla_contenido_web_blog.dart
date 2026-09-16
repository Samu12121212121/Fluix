part of 'pantalla_contenido_web.dart';

// ─── Blog: vista dividida (lista | editor) ────────────────────────────────────

class _BlogSplitView extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final bool isDark;
  final String? seccionId;
  final String? filtroTipoFijo;
  final String? titulo;
  final void Function(EntradaBlog? entrada, List<CategoriaBlog> cats)? onAbrirEditor;

  const _BlogSplitView({
    required this.empresaId,
    required this.svc,
    this.isDark = false,
    this.seccionId,
    this.filtroTipoFijo,
    this.titulo,
    this.onAbrirEditor,
  });

  @override
  State<_BlogSplitView> createState() => _BlogSplitViewState();
}

class _BlogSplitViewState extends State<_BlogSplitView> {
  String? _filtroTipo; // null = todos | 'articulo' | 'noticia'
  String _busqueda = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _abrirEditor(BuildContext context, List<CategoriaBlog> cats, {EntradaBlog? entrada}) {
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(entrada, cats);
      return;
    }
    // fallback: Navigator.push (mantener por compatibilidad)
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: false,
        builder: (_) => PantallaEditorBlog(
          empresaId: widget.empresaId,
          svc: widget.svc,
          entrada: entrada,
          categorias: cats,
          embedded: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoriaBlog>>(
      stream: widget.svc.obtenerCategorias(widget.empresaId),
      builder: (_, catSnap) {
        final categorias = catSnap.data ?? [];
        return StreamBuilder<List<EntradaBlog>>(
          stream: widget.seccionId != null
              ? widget.svc.obtenerBlogSeccion(widget.empresaId, widget.seccionId!)
              : widget.filtroTipoFijo != null
                  ? widget.svc.obtenerBlogPorTipo(widget.empresaId, widget.filtroTipoFijo!)
                  : widget.svc.obtenerBlog(widget.empresaId),
          builder: (_, snap) {
            final isLoading = snap.connectionState == ConnectionState.waiting;
            final todos     = snap.data ?? [];
            // filtroTipoFijo: datos ya filtrados por Firestore; no se requiere filtro local
            final porTipo   = todos;
            final articulos = _busqueda.isEmpty
                ? porTipo
                : porTipo.where((e) {
                    final q = _busqueda.toLowerCase();
                    return e.titulo.toLowerCase().contains(q) ||
                           e.autor.toLowerCase().contains(q) ||
                           e.resumen.toLowerCase().contains(q);
                  }).toList();
            final dark = widget.isDark;
            final kBg     = dark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
            final kSurf   = dark ? const Color(0xFF1E293B) : Colors.white;
            final kText   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
            final kSub    = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final kBorder = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            return ColoredBox(
              color: kBg,
              child: Column(children: [
                _buildListHeader(context, porTipo, categorias,
                    isLoading: isLoading,
                    surf: kSurf, text: kText, sub: kSub, border: kBorder),
                _buildBuscador(surf: kSurf, border: kBorder, sub: kSub),
                if (widget.filtroTipoFijo == null)
                  _buildFiltroTipo(porTipo, surf: kSurf, border: kBorder),
                Expanded(child: _buildArticleGrid(context, articulos, categorias, dark: dark, isLoading: isLoading)),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildBuscador({
    Color surf = Colors.white,
    Color border = const Color(0xFFE2E8F0),
    Color sub  = const Color(0xFF64748B),
  }) {
    return Container(
      color: surf,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por título, autor o resumen…',
          hintStyle: TextStyle(color: sub, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded, size: 17, color: sub),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 15),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _busqueda = '');
                  })
              : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _busqueda = v),
      ),
    );
  }

  Widget _buildListHeader(BuildContext context, List<EntradaBlog> articulos,
      List<CategoriaBlog> cats, {
      bool isLoading = false,
      Color surf = Colors.white,
      Color text = const Color(0xFF0F172A),
      Color sub  = const Color(0xFF64748B),
      Color border = const Color(0xFFE2E8F0),
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: surf,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.titulo ?? 'Blog / Noticias',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
          if (isLoading && articulos.isEmpty)
            Row(children: [
              SizedBox(width: 10, height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5,
                      color: sub.withValues(alpha: 0.5))),
              const SizedBox(width: 5),
              Text('Cargando…', style: TextStyle(fontSize: 11, color: sub)),
            ])
          else
            Text('${articulos.length} entrada${articulos.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: sub)),
        ]),
        const Spacer(),
        if (widget.filtroTipoFijo != null)
          ElevatedButton.icon(
            onPressed: () {
              final stub = EntradaBlog(id: '', titulo: '',
                  fechaPublicacion: DateTime.now(), tipo: widget.filtroTipoFijo!);
              _abrirEditor(context, cats, entrada: stub);
            },
            icon: const Icon(Icons.add_rounded, size: 13),
            label: const Text('Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Crear entrada',
            onSelected: (tipo) {
              final stub = tipo == 'noticia'
                  ? EntradaBlog(id: '', titulo: '', fechaPublicacion: DateTime.now(), tipo: 'noticia')
                  : null;
              _abrirEditor(context, cats, entrada: stub);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'articulo', child: Row(children: [
                Icon(Icons.article_outlined, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Nuevo artículo'),
              ])),
              PopupMenuItem(value: 'noticia', child: Row(children: [
                Icon(Icons.newspaper_rounded, size: 16, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text('Nueva noticia'),
              ])),
            ],
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add_rounded, size: 13),
              label: const Text('Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF2563EB),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildFiltroTipo(List<EntradaBlog> todos, {Color surf = Colors.white, Color border = const Color(0xFFE2E8F0)}) {
    int cnt(String? t) => t == null
        ? todos.length
        : todos.where((a) => _tipoNorm(a.tipo) == t).length;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chipTipo(null,       'Todos',       Icons.apps_rounded,           const Color(0xFF475569), cnt(null)),
          const SizedBox(width: 6),
          _chipTipo('articulo', 'Artículos',   Icons.article_rounded,        const Color(0xFF2563EB), cnt('articulo')),
          const SizedBox(width: 6),
          _chipTipo('noticia',  'Noticias',    Icons.newspaper_rounded,      const Color(0xFF059669), cnt('noticia')),
          const SizedBox(width: 6),
          _chipTipo('entrevista','Entrevistas', Icons.record_voice_over_rounded, const Color(0xFF7C3AED), cnt('entrevista')),
          const SizedBox(width: 6),
          _chipTipo('resena',   'Reseñas',     Icons.rate_review_rounded,    const Color(0xFFD97706), cnt('resena')),
        ]),
      ),
    );
  }

  String _tipoNorm(String t) => (t.isEmpty || t == 'articulo') ? 'articulo' : t;

  Widget _chipTipo(String? tipo, String label, IconData icon, Color color, int count) {
    final sel = _filtroTipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _filtroTipo = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: sel ? color : color.withValues(alpha: 0.25),
            width: sel ? 1.5 : 1,
          ),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.25),
              blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : color,
            fontSize: 12, fontWeight: FontWeight.w600,
          )),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w700,
                color: sel ? Colors.white : color,
              )),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildArticleGrid(BuildContext context, List<EntradaBlog> articulos,
      List<CategoriaBlog> cats, {bool dark = false, bool isLoading = false}) {
    final filtrados = _filtroTipo == null
        ? articulos
        : articulos.where((a) => _tipoNorm(a.tipo) == _filtroTipo).toList();

    if (isLoading && filtrados.isEmpty) {
      return _buildSkeletonList(dark: dark);
    }

    final esNoticia = _filtroTipo == 'noticia';
    if (filtrados.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: esNoticia ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18)),
          child: Icon(
            esNoticia ? Icons.newspaper_rounded : Icons.article_rounded,
            size: 36,
            color: esNoticia ? const Color(0xFF059669) : const Color(0xFF2563EB)),
        ),
        const SizedBox(height: 16),
        Text(
          esNoticia ? 'Sin noticias todavía' : 'Sin artículos todavía',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text(
          esNoticia
              ? 'Publica tu primera noticia para mantener informados a tus lectores'
              : 'Crea tu primer artículo y publícalo en tu sitio web',
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton.icon(
            onPressed: () => _abrirEditor(context, cats),
            icon: const Icon(Icons.article_outlined, size: 15),
            label: const Text('Crear artículo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              final stub = EntradaBlog(id: '', titulo: '', fechaPublicacion: DateTime.now(), tipo: 'noticia');
              _abrirEditor(context, cats, entrada: stub);
            },
            icon: const Icon(Icons.newspaper_rounded, size: 15),
            label: const Text('Nueva noticia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(
            onPressed: () async {
              await widget.svc.crearEntradaBlogEjemplo(widget.empresaId);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✅ Artículo de ejemplo creado'),
                backgroundColor: Colors.green,
              ));
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF2563EB)),
            label: const Text('Artículo ejemplo', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () async {
              await widget.svc.crearNoticiaEjemplo(widget.empresaId);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✅ Noticia de ejemplo creada'),
                backgroundColor: Colors.green,
              ));
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF059669)),
            label: const Text('Noticia ejemplo', style: TextStyle(color: Color(0xFF059669), fontSize: 12)),
          ),
        ]),
      ]));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final a = filtrados[i];
        return _ArticleListItem(
          articulo: a,
          onTap: () => _abrirEditor(context, cats, entrada: a),
          svc: widget.svc,
          empresaId: widget.empresaId,
          isDark: dark,
        );
      },
    );
  }

  Widget _buildSkeletonList({bool dark = false}) {
    final bg      = dark ? const Color(0xFF1E293B) : Colors.white;
    final shimmer = dark ? const Color(0xFF334155) : const Color(0xFFE8ECF0);
    final border  = dark ? const Color(0xFF334155) : const Color(0xFFE8EDF2);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 84,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 60, height: 60,
              decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(height: 9, width: 80,
                decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 7),
            Container(height: 11, width: double.infinity,
                decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 5),
            Container(height: 9, width: 180,
                decoration: BoxDecoration(color: shimmer.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 7),
            Container(height: 8, width: 120,
                decoration: BoxDecoration(color: shimmer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
          ])),
        ]),
      ),
    );
  }
}

// ── Tarjeta de artículo — fila compacta horizontal ───────────────────────────

class _ArticleListItem extends StatelessWidget {
  final EntradaBlog articulo;
  final VoidCallback onTap;
  final ContenidoWebService svc;
  final String empresaId;
  final bool isDark;

  const _ArticleListItem({
    required this.articulo,
    required this.onTap,
    required this.svc,
    required this.empresaId,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = articulo;
    final cardBg     = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF2);
    final titleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subColor   = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final metaColor  = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final imgUrl     = a.imagenUrl
        ?? (a.imagenes.isNotEmpty ? a.imagenes.first : null)
        ?? _ytThumb(a.videoUrl);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Thumbnail 60×60 ─────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imgUrl != null
                  ? Image.network(
                      imgUrl, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPh(a),
                    )
                  : _thumbPh(a),
            ),
            const SizedBox(width: 12),
            // ── Contenido ───────────────────────────────────────────────
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                // Badges + menú
                Row(children: [
                  _badge(a.estado.label, a.estado.color),
                  const SizedBox(width: 5),
                  _badgeTipo(a.tipo),
                  if (a.destacado) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, size: 13, color: Colors.amber[600]),
                  ],
                  const Spacer(),
                  _buildPopup(context, a, metaColor),
                ]),
                const SizedBox(height: 5),
                // Título
                Text(
                  a.titulo.isEmpty ? 'Sin título' : a.titulo,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: titleColor, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                // Resumen — 1 línea (sin etiquetas HTML)
                if (a.resumen.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(_plainText(a.resumen),
                      style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 5),
                // Meta: tipo · fecha · tiempo
                Text(
                  _metaLine(a),
                  style: TextStyle(fontSize: 11, color: metaColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static String? _ytThumb(String? url) {
    if (url == null) return null;
    final m = RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m != null) return 'https://img.youtube.com/vi/${m.group(1)}/hqdefault.jpg';
    return null;
  }

  static String _plainText(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .trim();

  String _metaLine(EntradaBlog a) {
    const tipos = <String, String>{
      'noticia': 'Noticia', 'entrevista': 'Entrevista', 'resena': 'Reseña',
    };
    final partes = <String>[tipos[a.tipo] ?? 'Artículo', a.fechaFormateada];
    if (a.tiempoLecturaMin > 0) partes.add('${a.tiempoLecturaMin} min');
    return partes.join(' · ');
  }

  Widget _thumbPh(EntradaBlog a) {
    final (Color bg, Color fg, IconData ico) = switch (a.tipo) {
      'noticia'    => (const Color(0xFFD1FAE5), const Color(0xFF059669), Icons.newspaper_rounded),
      'entrevista' => (const Color(0xFFEDE9FE), const Color(0xFF7C3AED), Icons.record_voice_over_rounded),
      'resena'     => (const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.rate_review_rounded),
      _            => (const Color(0xFFEFF6FF), const Color(0xFF2563EB), Icons.article_rounded),
    };
    return Container(
      width: 60, height: 60,
      color: bg,
      child: Icon(ico, size: 28, color: fg),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(
        fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _badgeTipo(String tipo) {
    const map = <String, (String, Color)>{
      'noticia':    ('Noticia',    Color(0xFF059669)),
      'entrevista': ('Entrevista', Color(0xFF7C3AED)),
      'resena':     ('Reseña',     Color(0xFFD97706)),
    };
    final info = map[tipo];
    if (info == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: info.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(info.$1, style: TextStyle(
          fontSize: 10, color: info.$2, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildPopup(BuildContext context, EntradaBlog a, Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: iconColor),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'publicar',
          child: Row(children: [
            Icon(a.publicada ? Icons.unpublished_outlined : Icons.publish_rounded,
                size: 14, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(a.publicada ? 'Despublicar' : 'Publicar',
                style: const TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'duplicar',
          child: Row(children: [
            Icon(Icons.copy_outlined, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 8),
            const Text('Duplicar', style: TextStyle(fontSize: 13)),
          ]),
        ),
        if ((a.urlExterna ?? '').isNotEmpty)
          PopupMenuItem(
            value: 'url',
            child: Row(children: [
              const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF6B1E2A)),
              const SizedBox(width: 8),
              const Text('Ver artículo original',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B1E2A))),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'eliminar',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Eliminar', style: TextStyle(fontSize: 13, color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'publicar':
            await svc.togglePublicarBlog(empresaId, a.id, !a.publicada);
          case 'duplicar':
            await svc.duplicarEntradaBlog(empresaId, a);
          case 'url':
            final uri = Uri.tryParse(a.urlExterna!);
            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          case 'eliminar':
            await svc.eliminarEntradaBlog(empresaId, a.id);
        }
      },
    );
  }
}
