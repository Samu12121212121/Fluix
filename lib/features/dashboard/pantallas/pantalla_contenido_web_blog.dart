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
  String? _filtroTipo;
  EstadoBlog? _filtroEstado;
  String _busqueda = '';
  final _searchCtrl = TextEditingController();

  static const int _primeraPagina = 200;
  static const int _tamPagina     = 200;
  int _pagina = 0;

  // Paginación server-side
  List<EntradaBlog> _articulosPagina = [];
  bool _cargandoPagina = false;
  bool _hayMasPaginas  = true;
  // Cursor por índice de página: null = inicio
  final Map<int, DocumentSnapshot<Map<String,dynamic>>?> _cursors = {0: null};

  @override
  void initState() {
    super.initState();
    // Solo usar paginación server-side si NO es sección especial ni tiene búsqueda
    if (widget.seccionId == null) _fetchPagina(0);
  }

  Future<void> _fetchPagina(int pagina) async {
    if (_cargandoPagina) return;
    setState(() => _cargandoPagina = true);
    try {
      final limit = pagina == 0 ? _primeraPagina : _tamPagina;
      final cursor = _cursors[pagina];
      final tipo = widget.filtroTipoFijo;
      final result = await widget.svc.fetchBlogPaginado(
        widget.empresaId, limit: limit, cursor: cursor, tipo: tipo,
      );
      if (!mounted) return;
      if (result.nextCursor != null) {
        _cursors[pagina + 1] = result.nextCursor;
      }
      setState(() {
        _articulosPagina = result.items;
        _pagina          = pagina;
        _hayMasPaginas   = result.items.length >= limit;
        _cargandoPagina  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoPagina = false);
    }
  }

  void _irAPagina(int pagina) {
    if (!_cursors.containsKey(pagina)) return; // cursor no conocido aún
    _fetchPagina(pagina);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _abrirEditor(BuildContext context, List<CategoriaBlog> cats, {EntradaBlog? entrada}) {
    // Si es entrada nueva y hay tipo fijo (noticias/entrevistas), precargarlo
    final entradaEfectiva = entrada ??
        (widget.filtroTipoFijo != null
            ? EntradaBlog(
                id: '',
                titulo: '',
                fechaPublicacion: DateTime.now(),
                tipo: widget.filtroTipoFijo!,
              )
            : null);
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(entradaEfectiva, cats);
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
          entrada: entradaEfectiva,
          categorias: cats,
          embedded: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Con búsqueda activa: stream completo para buscar en todo el catálogo
    // Sin búsqueda: paginación server-side (ya cargada en _articulosPagina)
    // filtroTipoFijo (noticias/entrevistas) también usa stream para ordenar
    // por fechaPublicacion desc (client-side) en lugar de por document ID
    final usarStream = _busqueda.isNotEmpty || widget.seccionId != null || widget.filtroTipoFijo != null;

    return StreamBuilder<List<CategoriaBlog>>(
      stream: widget.svc.obtenerCategorias(widget.empresaId),
      builder: (_, catSnap) {
        final categorias = catSnap.data ?? [];
        return StreamBuilder<List<EntradaBlog>>(
          stream: usarStream
              ? (widget.seccionId != null
                  ? widget.svc.obtenerBlogSeccion(widget.empresaId, widget.seccionId!)
                  : widget.svc.obtenerBlog(widget.empresaId))
              : const Stream.empty(),
          builder: (_, snap) {
            final isLoading = usarStream
                ? snap.connectionState == ConnectionState.waiting
                : _cargandoPagina;
            final streamTodos = snap.data ?? [];

            // Sin búsqueda: usar datos de paginación server-side
            final todos = usarStream ? streamTodos : _articulosPagina;

            final porFiltro = widget.filtroTipoFijo == null
                ? todos
                : todos.where((e) {
                    if (!e.publicada) return false;
                    if (e.tipo == widget.filtroTipoFijo) return true;
                    if (e.tipo.isEmpty && widget.filtroTipoFijo == 'entrevista') {
                      return e.urlExterna != null && e.urlExterna!.isNotEmpty;
                    }
                    return false;
                  }).toList();
            // Deduplicar por slug y título (igual que la web)
            final _vistos = <String>{};
            final porTipo = porFiltro.where((e) {
              final k  = e.slug.isNotEmpty ? e.slug : e.id;
              final kt = 't:${e.titulo.trim().toLowerCase()}';
              if (_vistos.contains(k) || (e.titulo.isNotEmpty && _vistos.contains(kt))) return false;
              _vistos.add(k);
              if (e.titulo.isNotEmpty) _vistos.add(kt);
              return true;
            }).toList();
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
                _buildFiltroEstado(porTipo, surf: kSurf, border: kBorder),
                Expanded(child: _buildArticleGrid(context, articulos, categorias, dark: dark, isLoading: isLoading, usarStream: usarStream)),
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
                    setState(() { _busqueda = ''; _pagina = 0; });
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
        onChanged: (v) => setState(() { _busqueda = v; _pagina = 0; }),
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
        // ── Papelera ────────────────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded, size: 20),
          tooltip: 'Papelera',
          color: const Color(0xFF94A3B8),
          style: IconButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(36, 36),
          ),
          onPressed: () => _mostrarPapelera(context),
        ),
        const SizedBox(width: 6),
        // ── Limpiar duplicados (solo cuando hay tipo fijo: noticias/entrevistas)
        if (widget.filtroTipoFijo != null)
          _BtnDedupBlog(
            empresaId: widget.empresaId,
            svc: widget.svc,
            tipo: widget.filtroTipoFijo!,
            total: articulos.length,
          ),
        if (widget.filtroTipoFijo != null) const SizedBox(width: 6),
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

  void _mostrarPapelera(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PapeleraBlog(
        empresaId: widget.empresaId,
        svc: widget.svc,
        filtroTipo: widget.filtroTipoFijo,
      ),
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
      onTap: () => setState(() { _filtroTipo = tipo; _pagina = 0; }),
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

  Widget _buildFiltroEstado(List<EntradaBlog> todos, {Color surf = Colors.white, Color border = const Color(0xFFE2E8F0)}) {
    final cntBorrador   = todos.where((a) => a.estado == EstadoBlog.borrador).length;
    final cntPublicado  = todos.where((a) => a.estado == EstadoBlog.publicado).length;
    final cntProgramado = todos.where((a) => a.estado == EstadoBlog.programado).length;
    if (cntBorrador == 0 && cntProgramado == 0) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: surf, border: Border(bottom: BorderSide(color: border))),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chipEstado(null, 'Todos', Icons.apps_rounded, const Color(0xFF475569), todos.length),
          if (cntBorrador > 0) ...[
            const SizedBox(width: 6),
            _chipEstado(EstadoBlog.borrador, 'Borradores', Icons.edit_note_rounded, const Color(0xFFF59E0B), cntBorrador),
          ],
          if (cntPublicado > 0) ...[
            const SizedBox(width: 6),
            _chipEstado(EstadoBlog.publicado, 'Publicados', Icons.public_rounded, const Color(0xFF059669), cntPublicado),
          ],
          if (cntProgramado > 0) ...[
            const SizedBox(width: 6),
            _chipEstado(EstadoBlog.programado, 'Programados', Icons.schedule_rounded, const Color(0xFF2563EB), cntProgramado),
          ],
        ]),
      ),
    );
  }

  Widget _chipEstado(EstadoBlog? estado, String label, IconData icon, Color color, int count) {
    final sel = _filtroEstado == estado;
    return GestureDetector(
      onTap: () => setState(() { _filtroEstado = estado; _pagina = 0; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.25), width: sel ? 1.5 : 1),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: sel ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600)),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : color)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildArticleGrid(BuildContext context, List<EntradaBlog> articulos,
      List<CategoriaBlog> cats, {bool dark = false, bool isLoading = false, bool usarStream = false}) {
    var filtrados = _filtroTipo == null
        ? articulos
        : articulos.where((a) => _tipoNorm(a.tipo) == _filtroTipo).toList();
    if (_filtroEstado != null) {
      filtrados = filtrados.where((a) => a.estado == _filtroEstado).toList();
    }

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

    // ── Paginación ────────────────────────────────────────────────
    // Sin búsqueda: paginación server-side (los artículos ya son solo la página actual)
    // Con búsqueda: paginación client-side sobre resultados filtrados
    final List<EntradaBlog> visible;
    final int pagina;
    final bool paginacionServer = !usarStream;

    if (paginacionServer) {
      visible = filtrados; // Ya son los de la página actual
      pagina  = _pagina;
    } else {
      final total = filtrados.length;
      pagina = _pagina.clamp(0, total <= _primeraPagina
          ? 0
          : ((total - _primeraPagina) / _tamPagina).ceil());
      final inicio = pagina == 0 ? 0 : _primeraPagina + (pagina - 1) * _tamPagina;
      final fin    = (pagina == 0 ? _primeraPagina : _primeraPagina + pagina * _tamPagina)
          .clamp(0, total);
      visible = filtrados.sublist(inicio, fin);
    }

    final kBgPag  = dark ? const Color(0xFF1E293B) : Colors.white;
    final kBorder = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(children: [
      // ── Tabs de página ─────────────────────────────────────────
      // Botones de página: server-side usa cursores conocidos; client-side usa total
      if (paginacionServer
          ? (_pagina > 0 || _hayMasPaginas)
          : filtrados.length > _primeraPagina)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          decoration: BoxDecoration(
            color: kBgPag,
            border: Border(bottom: BorderSide(color: kBorder))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (int p = 0; p <= (paginacionServer ? _cursors.length - 1 : (filtrados.length <= _primeraPagina ? 0 : ((filtrados.length - _primeraPagina) / _tamPagina).ceil())); p++) ...[
                if (p > 0) const SizedBox(width: 4),
                // En paginación server-side, solo mostrar páginas cuyo cursor es conocido
                if (!paginacionServer || _cursors.containsKey(p))
                GestureDetector(
                  onTap: () => paginacionServer
                      ? _irAPagina(p)
                      : setState(() => _pagina = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: pagina == p
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF2563EB).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: pagina == p
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF2563EB).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${(p == 0 ? 0 : _primeraPagina + (p - 1) * _tamPagina) + 1}'
                      '–'
                      '${(p == 0 ? _primeraPagina : _primeraPagina + p * _tamPagina).clamp(0, filtrados.length)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pagina == p
                            ? Colors.white
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text('${paginacionServer ? "..." : filtrados.length} entradas',
                  style: TextStyle(
                      fontSize: 11,
                      color: dark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8))),
            ]),
          ),
        ),
      // ── Lista de la página actual ──────────────────────────────
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = visible[i];
            return _ArticleListItem(
              articulo: a,
              onTap: () => _abrirEditor(context, cats, entrada: a),
              svc: widget.svc,
              empresaId: widget.empresaId,
              isDark: dark,
            );
          },
        ),
      ),
    ]);
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
    // Todas las imágenes disponibles para el carrusel
    final todasImagenes = [
      if (a.imagenUrl != null) a.imagenUrl!,
      ...a.imagenes.where((u) => u != a.imagenUrl),
      if (a.imagenUrl == null && a.imagenes.isEmpty && _ytThumb(a.videoUrl) != null)
        _ytThumb(a.videoUrl)!,
    ];
    final imgUrl = todasImagenes.isNotEmpty ? todasImagenes.first : null;
    final tieneCarrusel = todasImagenes.length > 1;

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
            // ── Thumbnail con carrusel si hay más de 1 imagen ───────────
            GestureDetector(
              onTap: tieneCarrusel
                  ? () => _mostrarCarrusel(context, todasImagenes)
                  : null,
              child: Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imgUrl != null
                      ? Image.network(
                          imgUrl, width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPh(a),
                        )
                      : _thumbPh(a),
                ),
                if (tieneCarrusel)
                  Positioned(
                    bottom: 3, right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.photo_library_outlined,
                            size: 9, color: Colors.white),
                        const SizedBox(width: 2),
                        Text('${todasImagenes.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
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
                  // Duplicate shortcut — visible without opening the ⋮ menu
                  _DuplicateBtn(svc: svc, empresaId: empresaId, articulo: a, color: metaColor),
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

  void _mostrarCarrusel(BuildContext context, List<String> urls) {
    final ctrl = PageController();
    int pagina = 0;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 420,
            child: Stack(children: [
              PageView.builder(
                controller: ctrl,
                onPageChanged: (i) => setSt(() => pagina = i),
                itemCount: urls.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  child: Image.network(
                    urls[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 48)),
                  ),
                ),
              ),
              // Flechas
              if (pagina > 0)
                Positioned(left: 8, top: 0, bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                      onPressed: () => ctrl.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut),
                    ),
                  )),
              if (pagina < urls.length - 1)
                Positioned(right: 8, top: 0, bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      onPressed: () => ctrl.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut),
                    ),
                  )),
              // Dots
              Positioned(bottom: 12, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(urls.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: pagina == i ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: pagina == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                )),
              // Cerrar
              Positioned(top: 8, right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                )),
              // Contador
              Positioned(top: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${pagina + 1} / ${urls.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                )),
            ]),
          ),
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
        try {
          switch (action) {
            case 'publicar':
              await svc.togglePublicarBlog(empresaId, a.id, !a.publicada);
            case 'duplicar':
              await svc.duplicarEntradaBlog(empresaId, a);
            case 'url':
              final url = a.urlExterna ?? '';
              if (url.isEmpty) return;
              final uri = Uri.tryParse(url);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            case 'eliminar':
              await svc.eliminarEntradaBlog(empresaId, a.id);
          }
        } catch (_) {}
      },
    );
  }
}

// ── Botón duplicar entrada ────────────────────────────────────────────────────

class _DuplicateBtn extends StatefulWidget {
  final ContenidoWebService svc;
  final String empresaId;
  final EntradaBlog articulo;
  final Color color;

  const _DuplicateBtn({
    required this.svc, required this.empresaId,
    required this.articulo, required this.color,
  });

  @override
  State<_DuplicateBtn> createState() => _DuplicateBtnState();
}

class _DuplicateBtnState extends State<_DuplicateBtn> {
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28, height: 28,
      child: _cargando
          ? Padding(
              padding: const EdgeInsets.all(6),
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: widget.color))
          : IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_outlined, size: 15, color: widget.color),
              tooltip: 'Duplicar entrada',
              onPressed: () async {
                setState(() => _cargando = true);
                try {
                  await widget.svc.duplicarEntradaBlog(
                      widget.empresaId, widget.articulo);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Entrada duplicada como borrador'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _cargando = false);
                }
              },
            ),
    );
  }
}

// ── Botón limpiar duplicados de blog ─────────────────────────────────────────

class _BtnDedupBlog extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final String tipo;
  final int total;

  const _BtnDedupBlog({
    required this.empresaId,
    required this.svc,
    required this.tipo,
    required this.total,
  });

  @override
  State<_BtnDedupBlog> createState() => _BtnDedupBlogState();
}

class _BtnDedupBlogState extends State<_BtnDedupBlog> {
  bool _corriendo = false;

  Future<void> _dedup() async {
    final tipoLabel = widget.tipo == 'noticia' ? 'noticias' : 'entrevistas';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar duplicados'),
        content: Text(
          'Hay ${widget.total} $tipoLabel.\n\n'
          'Esta operación buscará entradas duplicadas (mismo slug o título) '
          'y conservará la más completa de cada una.\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _corriendo = true);
    try {
      final deleted = await widget.svc.dedupBlogPorTipo(widget.empresaId, widget.tipo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deleted == 0
              ? '✅ Sin duplicados encontrados'
              : '✅ $deleted entradas duplicadas eliminadas'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _corriendo ? null : _dedup,
      icon: _corriendo
          ? const SizedBox(width: 11, height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.5))
          : const Icon(Icons.auto_fix_high_rounded, size: 13,
              color: Color(0xFFD97706)),
      label: Text(_corriendo ? '…' : 'Limpiar dup.',
          style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
      ),
    );
  }
}

// ── Papelera de blog ──────────────────────────────────────────────────────────

class _PapeleraBlog extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final String? filtroTipo;

  const _PapeleraBlog({
    required this.empresaId,
    required this.svc,
    this.filtroTipo,
  });

  String _tipoLabel(String tipo) => switch (tipo) {
    'noticia'     => 'Noticia',
    'entrevista'  => 'Entrevista',
    'articulo'    => 'Artículo',
    _             => tipo,
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(children: [
        // Handle + header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.delete_sweep_rounded, size: 20, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Papelera',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)))),
              TextButton(
                onPressed: () => _vaciarPapelera(context),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                child: const Text('Vaciar todo', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ]),
        ),
        // Lista
        Expanded(
          child: StreamBuilder<List<EntradaBlog>>(
            stream: svc.obtenerPapeleraBlog(empresaId, tipo: filtroTipo),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('La papelera está vacía',
                        style: TextStyle(fontSize: 15, color: Colors.grey[500],
                            fontWeight: FontWeight.w500)),
                  ]),
                );
              }
              return ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.titulo.isEmpty ? '(sin título)' : e.titulo,
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_tipoLabel(e.tipo),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 6),
                          if (e.fechaEliminacion != null)
                            Text(
                              'Eliminado el ${e.fechaEliminacion!.day}/${e.fechaEliminacion!.month}/${e.fechaEliminacion!.year}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                        ]),
                      ])),
                      const SizedBox(width: 8),
                      // Restaurar
                      OutlinedButton(
                        onPressed: () async {
                          await svc.restaurarEntradaBlog(empresaId, e.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('✅ "${e.titulo.isEmpty ? 'Entrada' : e.titulo}" restaurada como borrador'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Restaurar'),
                      ),
                      const SizedBox(width: 6),
                      // Eliminar definitivo
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, size: 18,
                            color: Color(0xFFEF4444)),
                        tooltip: 'Eliminar definitivamente',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmarEliminacionPermanente(context, e),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _vaciarPapelera(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar papelera'),
        content: const Text(
            'Se eliminarán permanentemente todas las entradas de la papelera.\n\n'
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vaciar todo',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final snap = await svc.obtenerPapeleraBlog(empresaId, tipo: filtroTipo).first;
      for (final e in snap) {
        await svc.eliminarPermanenteEntradaBlog(empresaId, e.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Papelera vaciada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmarEliminacionPermanente(
      BuildContext context, EntradaBlog entrada) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar permanentemente'),
        content: Text('¿Eliminar "${entrada.titulo.isEmpty ? 'esta entrada' : entrada.titulo}" para siempre?\n\nNo podrá recuperarse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await svc.eliminarPermanenteEntradaBlog(empresaId, entrada.id);
  }
}
