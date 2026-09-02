import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/mixins/safe_stream_mixin.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/utils/app_settings.dart';
import '../../../services/contenido_web_service.dart';
import '../../../services/demo_cuenta_service.dart';
import '../../../services/catalogo_web_sync_service.dart';
import '../../../domain/modelos/seccion_web.dart';
import '../../../domain/modelos/evento_web.dart';
import 'tab_config_web.dart';
import 'tab_campanas_email.dart';
import '../../../services/contacto_web_service.dart';
import 'tab_mensajes_contacto.dart';
import 'tab_eventos_web.dart';
import 'tab_catalogo_web.dart';
import 'tab_seleccion_nazari.dart';
import 'pantalla_editor_blog.dart';
import 'tab_analytics_web.dart';
import 'tab_seo_web.dart';
import 'pantalla_items_seccion.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL — Gestión de Contenido Web
// ═════════════════════════════════════════════════════════════════════════════

class PantallaContenidoWeb extends StatefulWidget {
  final String empresaId;
  final ValueChanged<String?>? onSubModuloChanged;
  final ValueNotifier<int>? volverAlHub;

  const PantallaContenidoWeb({
    super.key,
    required this.empresaId,
    this.onSubModuloChanged,
    this.volverAlHub,
  });

  @override
  State<PantallaContenidoWeb> createState() => _PantallaContenidoWebState();
}

class _PantallaContenidoWebState extends State<PantallaContenidoWeb>
    with SafeStreamMixin {
  final ContenidoWebService _svc = ContenidoWebService();
  final ContactoWebService _contactoSvc = ContactoWebService();

  String? _moduloActivo;
  int _lastVolverSignal = 0;
  bool _isDark = false;
  int _hubPage = 0;
  final _pageCtrl = PageController();

  // Sub-vista activa (editor sin Scaffold)
  // tipo: 'editar_seccion' | 'editar_blog' | 'editar_catalogo'
  ({
    String tipo,
    SeccionWeb? seccion,
    EntradaBlog? entrada,
    List<CategoriaBlog> categorias,
    String paginaInicial,
    Map<String, dynamic>? itemCatalogo,
  })? _subVista;

  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  Color get _kBg      => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
  Color get _kSurf    => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _kText    => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _kTextSec => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _kBorder  => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
    widget.volverAlHub?.addListener(_onVolverAlHub);
  }

  @override
  void didUpdateWidget(PantallaContenidoWeb old) {
    super.didUpdateWidget(old);
    if (old.volverAlHub != widget.volverAlHub) {
      old.volverAlHub?.removeListener(_onVolverAlHub);
      widget.volverAlHub?.addListener(_onVolverAlHub);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    AppSettings.darkMode.removeListener(_onDark);
    widget.volverAlHub?.removeListener(_onVolverAlHub);
    super.dispose();
  }

  void _onVolverAlHub() {
    final sig = widget.volverAlHub?.value ?? 0;
    if (sig != _lastVolverSignal) {
      _lastVolverSignal = sig;
      if (_subVista != null) {
        _cerrarSubVista();
      } else if (_moduloActivo != null) {
        _setModuloActivo(null);
      }
    }
  }

  void _setModuloActivo(String? mod) {
    setState(() => _moduloActivo = mod);
    widget.onSubModuloChanged?.call(mod);
  }

  void _abrirSubVista({
    required String tipo,
    SeccionWeb? seccion,
    EntradaBlog? entrada,
    List<CategoriaBlog> categorias = const [],
    String paginaInicial = 'inicio',
    Map<String, dynamic>? itemCatalogo,
  }) {
    setState(() => _subVista = (
      tipo: tipo,
      seccion: seccion,
      entrada: entrada,
      categorias: categorias,
      paginaInicial: paginaInicial,
      itemCatalogo: itemCatalogo,
    ));
    final subMod = tipo == 'editar_blog' ? 'editor_blog'
        : tipo == 'editar_catalogo' ? 'editor_catalogo'
        : 'editor_seccion';
    widget.onSubModuloChanged?.call(subMod);
  }

  void _cerrarSubVista() {
    setState(() => _subVista = null);
    widget.onSubModuloChanged?.call(_moduloActivo);
  }

  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  static const _modsBase = [
    // Página 1 — siempre visible
    _WebMod('secciones', 'Secciones',    'Crea y organiza las secciones\nde tu sitio web',      Icons.dashboard_customize_rounded, Color(0xFF7C3AED)),
    _WebMod('catalogo',  'Catálogo',     'Gestiona el catálogo\nde tu sitio web',                Icons.menu_book_rounded,           Color(0xFF6B1E2A)),
    _WebMod('agenda',    'Agenda',       'Añade y edita eventos:\npresentaciones, firmas y ferias', Icons.event_rounded,            Color(0xFF1E4D6B)),
    _WebMod('blog',      'Blog/Revista', 'Publica entrevistas, noticias\ny artículos de actualidad', Icons.article_rounded,          Color(0xFF2563EB)),
    _WebMod('mensajes',  'Mensajes',     '',                                                      Icons.chat_bubble_rounded,         Color(0xFF059669)),
    // Página 2
    _WebMod('analytics', 'Analytics',   'Tráfico, visitas y estadísticas\nde tu sitio web',     Icons.bar_chart_rounded,           Color(0xFF0EA5E9)),
    _WebMod('campanas',  'Email',        'Crea y envía campañas de\nemail marketing',             Icons.campaign_rounded,            Color(0xFFE11D48)),
    _WebMod('config',    'Configuración','Personaliza tu sitio web y\nsus ajustes',              Icons.settings_rounded,            Color(0xFF7C3AED)),
  ];

  List<_WebMod> get _mods => widget.empresaId == _kNazariId
      ? [
          ..._modsBase,
          const _WebMod('seleccion', 'Selección Nazarí',
              'Gestiona la curaduría editorial\ny el libro del mes',
              Icons.stars_rounded, Color(0xFF6B1E2A)),
        ]
      : _modsBase;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (DemoCuentaService().esDemo(email)) return _buildDemoScreen(context);

    // Vista de módulo (con sidebar lateral)
    if (_moduloActivo != null) return _buildVistaModulo();

    // Hub: 2 páginas paginables
    final page1 = _mods.take(5).toList();
    final page2 = _mods.skip(5).toList();

    return ColoredBox(
      color: _kBg,
      child: Column(children: [
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _hubPage = p),
            children: [
              _buildHubPagina(page1, rows: 2),
              _buildHubPagina(page2, rows: 1),
            ],
          ),
        ),
        _buildHubIndicador(page1, page2),
      ]),
    );
  }

  // ── Hub helpers ──────────────────────────────────────────────────────────

  Widget _buildHubPagina(List<_WebMod> mods, {required int rows}) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final ancho = constraints.maxWidth;
      // Responsive: 2 columnas en móvil (<700dp), 3 en tablet/desktop
      final cols = ancho >= 700 ? 3 : 2;
      const pad  = 12.0;
      const gap  = 10.0;
      final cardW = (ancho - pad * 2 - gap * (cols - 1)) / cols;
      final rowsEfectivos = (mods.length / cols).ceil();
      final cardH = (constraints.maxHeight - pad * 2 - gap * (rowsEfectivos - 1)) / rowsEfectivos;
      final ratio = cardW / cardH.clamp(60, double.infinity);
      return GridView.builder(
        padding: const EdgeInsets.all(pad),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: ratio,
        ),
        itemCount: mods.length,
        itemBuilder: (_, i) => _buildModuloCard(mods[i]),
      );
    });
  }

  Widget _buildHubIndicador(List<_WebMod> p1, List<_WebMod> p2) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(children: [
        // Dots
        Row(children: [0, 1].map((i) {
          final sel = _hubPage == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            width: sel ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF6B1E2A) : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }).toList()),
        const Spacer(),
        // Botones prev/next
        if (_hubPage > 0)
          OutlinedButton.icon(
            onPressed: () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: const Text('Principal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kTextSec,
              side: BorderSide(color: _kBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        if (_hubPage == 0) ...[
          Text('Analytics · Email · Config',
              style: TextStyle(fontSize: 11.5, color: _kTextSec)),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Más módulos'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Vista de módulo con sidebar ───────────────────────────────────────────

  Widget _buildVistaModulo() {
    final mod = _mods.firstWhere((m) => m.id == _moduloActivo,
        orElse: () => _mods.first);

    // Contenido principal: editor o módulo
    Widget content;
    if (_subVista != null) {
      final sv = _subVista!;
      if (sv.tipo == 'editar_seccion') {
        content = PantallaEditorSeccion(
          empresaId: widget.empresaId,
          seccion: sv.seccion,
          svc: _svc,
          paginaInicial: sv.paginaInicial,
          noScaffold: true,
          onGuardado: _cerrarSubVista,
          onCancelar: _cerrarSubVista,
        );
      } else if (sv.tipo == 'items_seccion') {
        content = PantallaItemsSeccion(
          empresaId: widget.empresaId,
          seccion: sv.seccion!,
          svc: _svc,
          noScaffold: true,
          onCerrar: _cerrarSubVista,
        );
      } else if (sv.tipo == 'eventos_seccion') {
        content = _EmbeddedEventos(
          empresaId: widget.empresaId,
          seccion: sv.seccion!,
          svc: _svc,
          onCerrar: _cerrarSubVista,
          color: mod.color,
        );
      } else if (sv.tipo == 'editar_blog') {
        content = PantallaEditorBlog(
          empresaId: widget.empresaId,
          svc: _svc,
          entrada: sv.entrada,
          categorias: sv.categorias,
          embedded: false,
          onGuardado: _cerrarSubVista,
          onCancelar: _cerrarSubVista,
        );
      } else if (sv.tipo == 'editar_catalogo') {
        content = _EditorCatalogoEmbebido(
          empresaId: widget.empresaId,
          svc: _svc,
          item: sv.itemCatalogo,
          color: mod.color,
          onGuardado: _cerrarSubVista,
          onCancelar: _cerrarSubVista,
        );
      } else {
        content = _buildWebModuloContent(mod);
      }
    } else {
      content = _buildWebModuloContent(mod);
    }

    // El sidebar y AppBar del dashboard ya envuelven este widget desde el layout padre.
    // Solo renderizamos el contenido en el área disponible.
    return ColoredBox(color: _kBg, child: content);
  }

  Widget _buildWebSidebar(_WebMod modActual) {
    return Container(
      width: 88,
      color: const Color(0xFF0D1829),
      child: Column(children: [
        GestureDetector(
          onTap: () => _setModuloActivo(null),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
            child: Column(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white60, size: 18),
              ),
              const SizedBox(height: 4),
              const Text('Inicio', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 9)),
            ]),
          ),
        ),
        Container(height: 1, color: Colors.white12,
            margin: const EdgeInsets.symmetric(horizontal: 12)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _mods.map((mod) {
              final sel = modActual.id == mod.id;
              return GestureDetector(
                onTap: () => _setModuloActivo(mod.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: sel ? mod.color.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: sel ? Border.all(color: mod.color.withValues(alpha: 0.35)) : null,
                  ),
                  child: Column(children: [
                    Icon(mod.icono,
                        color: sel ? mod.color : Colors.white.withValues(alpha: 0.45),
                        size: 20),
                    const SizedBox(height: 3),
                    Text(mod.titulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel ? mod.color : Colors.white.withValues(alpha: 0.45),
                            fontSize: 9,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildWebModuloContent(_WebMod mod) {
    switch (mod.id) {
      case 'secciones': return _TabSecciones(
          empresaId: widget.empresaId, svc: _svc, color: mod.color,
          onAbrirEditor: (seccion, pagina) {
            if (seccion == null) {
              _abrirSubVista(tipo: 'editar_seccion', paginaInicial: pagina ?? 'inicio');
              return;
            }
            if (seccion.tipo == TipoSeccion.generico) {
              _abrirSubVista(tipo: 'items_seccion', seccion: seccion);
            } else if (seccion.tipo == TipoSeccion.eventos) {
              _abrirSubVista(tipo: 'eventos_seccion', seccion: seccion);
            } else {
              _abrirSubVista(tipo: 'editar_seccion', seccion: seccion,
                  paginaInicial: pagina ?? seccion.pagina);
            }
          },
        );
      case 'catalogo':  return TabCatalogoWeb(
          empresaId: widget.empresaId, svc: _svc, color: mod.color,
          onAbrirEditor: (item) => _abrirSubVista(tipo: 'editar_catalogo', itemCatalogo: item));
      case 'agenda':    return TabEventosWeb(empresaId: widget.empresaId, svc: _svc);
      case 'blog':      return _BlogSplitView(
          empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
          onAbrirEditor: (entrada, cats) => _abrirSubVista(
            tipo: 'editar_blog', entrada: entrada, categorias: cats),
        );
      case 'mensajes':  return TabMensajesContacto(empresaId: widget.empresaId, color: mod.color);
      case 'campanas':  return TabCampanasEmail(empresaId: widget.empresaId, color: mod.color);
      case 'galeria':    return _TabGaleriaWeb(empresaId: widget.empresaId, svc: _svc, color: mod.color);
      case 'analytics':  return TabAnalyticsWeb(empresaId: widget.empresaId);
      case 'config':     return TabConfigWeb(empresaId: widget.empresaId, svc: _svc);
      case 'seleccion':  return TabSeleccionNazari(empresaId: widget.empresaId);
      default:          return const Center(child: Text('Módulo no disponible'));
    }
  }

  Widget _buildBlogEmbebido() {
    return StreamBuilder<List<CategoriaBlog>>(
      stream: _svc.obtenerCategorias(widget.empresaId),
      builder: (_, snap) => PantallaEditorBlog(
        empresaId: widget.empresaId,
        svc: _svc,
        entrada: null,
        categorias: snap.data ?? [],
        embedded: true,
      ),
    );
  }

  // ── Header compacto ───────────────────────────────────────────────────────

  // ── Tarjeta de módulo (estilo screenshot) ────────────────────────────────

  Widget _buildModuloCard(_WebMod mod) {
    return GestureDetector(
      onTap: () => _abrirModulo(mod),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
              blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: icono + título + desc ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: mod.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mod.icono, color: mod.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mod.titulo,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kText),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (mod.desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(mod.desc,
                      maxLines: 2,
                      style: TextStyle(fontSize: 10.5, color: _kTextSec, height: 1.35)),
                ],
              ])),
            ]),
          ),
          // ── Preview (fondo ligeramente diferenciado) ─────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildPreview(mod),
            ),
          ),
          // ── Bottom: estado + botón Abrir ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(children: [
              Expanded(child: _buildStatRow(mod)),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: () => _abrirModulo(mod),
                style: FilledButton.styleFrom(
                  backgroundColor: mod.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                child: const Text('Abrir →'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Previews por módulo ───────────────────────────────────────────────────

  Widget _buildPreview(_WebMod mod) {
    switch (mod.id) {
      case 'secciones':  return _previewSecciones(mod.color);
      case 'catalogo':   return _previewCatalogo(mod.color);
      case 'agenda':     return _previewAgenda(mod.color);
      case 'blog':       return _previewBlog(mod.color);
      case 'mensajes':   return _previewMensajes(mod.color);
      case 'analytics':  return _previewAnalytics(mod.color);
      case 'config':     return _previewConfig();
      default:           return const SizedBox.shrink();
    }
  }

  Widget _previewCatalogo(Color c) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerCatalogoWeb(widget.empresaId),
      builder: (_, snap) {
        final total    = snap.data?.length ?? 0;
        final visibles = snap.data?.where((i) => i['activo'] == true).length ?? 0;
        return _previewContador(
          label:   'Elementos registrados',
          valor:   '$total',
          sublabel: '$visibles visibles en la web',
          icon:    Icons.grid_view_rounded,
          color:   c,
        );
      },
    );
  }

  Widget _previewAgenda(Color c) {
    return StreamBuilder<List<EventoWeb>>(
      stream: _svc.obtenerEventos(widget.empresaId),
      builder: (_, snap) {
        final eventos = (snap.data ?? [])
            .where((e) => e.activo && !e.eliminado)
            .take(3).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _previewTitle('Próximos eventos'),
          if (eventos.isEmpty)
            Expanded(child: Center(
              child: Text('Sin eventos próximos',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ))
          else
            ...eventos.map((e) => _eventoRow(e, c)),
        ]);
      },
    );
  }

  Widget _eventoRow(EventoWeb e, Color c) {
    final fecha = '${e.fecha.day.toString().padLeft(2,'0')}/'
        '${e.fecha.month.toString().padLeft(2,'0')}/'
        '${e.fecha.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Row(children: [
        Container(width: 7, height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Text(e.titulo,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155),
                fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(fecha, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _previewSecciones(Color c) {
    return StreamBuilder<List<SeccionWeb>>(
      stream: _svc.obtenerSecciones(widget.empresaId),
      builder: (_, snap) {
        final total  = snap.data?.length ?? 0;
        final activas = snap.data?.where((s) => s.activa).length ?? 0;
        return _previewContador(
          label:    'Catálogo de secciones',
          valor:    '$total',
          sublabel: '$activas activa${activas == 1 ? '' : 's'}',
          icon:     Icons.dashboard_customize_rounded,
          color:    c,
        );
      },
    );
  }

  // Widget reutilizable para mostrar un contador grande + icono (estilo screenshot)
  Widget _previewContador({
    required String label,
    required String valor,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: _kTextSec),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w800,
                    color: _kText, height: 1.0)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
          ]),
          const SizedBox(height: 6),
          Text(sublabel, style: TextStyle(fontSize: 10.5, color: _kTextSec),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _previewBlog(Color c) {
    return StreamBuilder<List<EntradaBlog>>(
      stream: _svc.obtenerBlog(widget.empresaId),
      builder: (_, snap) {
        final arts = snap.data ?? [];
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            _previewTitle('Últimas publicaciones'),
            ...List.generate(2, (i) {
              if (i < arts.length) {
                final a = arts[i];
                return _blogRow(a.titulo, _fmt(a.fechaPublicacion), c);
              }
              return _blogRowPh();
            }),
          ]),
        );
      },
    );
  }

  Widget _blogRow(String titulo, String fecha, Color c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(Icons.article_rounded, color: c, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(fecha, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
        ])),
      ]),
    );
  }

  Widget _blogRowPh() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ph(double.infinity), const SizedBox(height: 5), _ph(80),
        ])),
      ]),
    );
  }

  Widget _previewMensajes(Color c) {
    return StreamBuilder<List<MensajeContactoWeb>>(
      stream: _contactoSvc.obtenerMensajes(widget.empresaId),
      builder: (_, snap) {
        final msgs = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _previewTitle('Mensajes recientes'),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: msgs.isEmpty ? 4 : msgs.take(4).length,
              itemBuilder: (_, i) {
                if (msgs.isEmpty) return _msgRowPh();
                final m = msgs[i];
                return _msgRow(m.nombre, m.mensaje, c, leido: m.leido);
              },
            ),
          ),
        ]);
      },
    );
  }

  Widget _msgRow(String nombre, String texto, Color c, {bool leido = true}) {
    final dotColor = leido ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Row(children: [
        Container(
          width: 7, height: 7,
          margin: const EdgeInsets.only(right: 6, top: 1),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        CircleAvatar(radius: 12,
            backgroundColor: c.withValues(alpha: 0.1),
            child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 9.5, color: c, fontWeight: FontWeight.w700))),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: leido ? FontWeight.w500 : FontWeight.w700,
                  color: leido ? const Color(0xFF64748B) : const Color(0xFF334155))),
          Text(texto, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _msgRowPh() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Row(children: [
        Container(width: 26, height: 26,
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ph(70), const SizedBox(height: 4), _ph(double.infinity),
        ])),
      ]),
    );
  }

  Widget _previewGaleria(Color c) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerGaleriaStream(widget.empresaId),
      builder: (_, snap) {
        final imgs = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _previewTitle('Archivos recientes'),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 5, mainAxisSpacing: 5,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(6, (i) {
                if (i < imgs.length) {
                  final url = imgs[i]['url'] as String? ?? '';
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: c.withValues(alpha: 0.08),
                            child: Icon(Icons.image_rounded, color: c.withValues(alpha: 0.3), size: 16))),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: c.withValues(alpha: 0.15)),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined, color: c.withValues(alpha: 0.25), size: 16),
                );
              }),
            ),
          )),
        ]);
      },
    );
  }

  Widget _previewAnalytics(Color c) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('estadisticas').doc('resumen')
          .snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final visitas   = d?['visitas'] as int? ?? 0;
        final sesiones  = d?['sesiones'] as int? ?? 0;
        final rebote    = d?['tasa_rebote'] as double? ?? 0.0;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            _previewTitle('Estadísticas del sitio'),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _analyticsRow(Icons.visibility_rounded, c, 'Visitas totales', '$visitas'),
                _analyticsRow(Icons.person_rounded, c, 'Sesiones', '$sesiones'),
                _analyticsRow(Icons.exit_to_app_rounded, c, 'Tasa de rebote', '${rebote.toStringAsFixed(1)}%'),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _analyticsRow(IconData ico, Color c, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(ico, size: 14, color: c),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }

  Widget _previewConfig() {
    const items = [
      'Información general', 'Diseño y apariencia', 'SEO y metadatos',
      'Formularios', 'Integraciones', 'Dominio y hosting',
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _previewTitle('Ajustes del sitio'),
        ...items.map((item) => Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0), width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            child: Row(children: [
              Expanded(child: Text(item,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)))),
              const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFCBD5E1)),
            ]),
          ),
        )),
      ],
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStatRow(_WebMod mod) {
    switch (mod.id) {
      case 'secciones':
        return StreamBuilder<List<SeccionWeb>>(
          stream: _svc.obtenerSecciones(widget.empresaId),
          builder: (_, s) => _dot(
              '${s.data?.where((x) => x.activa).length ?? 0} secciones activas',
              const Color(0xFF10B981)));
      case 'blog':
        return StreamBuilder<List<EntradaBlog>>(
          stream: _svc.obtenerBlog(widget.empresaId),
          builder: (_, s) => _dot(
              '${s.data?.length ?? 0} artículo${(s.data?.length ?? 0) == 1 ? '' : 's'} publicado${(s.data?.length ?? 0) == 1 ? '' : 's'}',
              const Color(0xFF10B981)));
      case 'mensajes':
        return StreamBuilder<List<MensajeContactoWeb>>(
          stream: _contactoSvc.obtenerMensajes(widget.empresaId),
          builder: (_, s) {
            final sinLeer = s.data?.where((m) => !m.leido).length ?? 0;
            return _dot('$sinLeer mensajes sin leer',
                sinLeer > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
          });
      case 'catalogo':
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.obtenerCatalogoWeb(widget.empresaId),
          builder: (_, s) => _dot(
              '${s.data?.where((i) => i['activo'] == true).length ?? 0} elementos visibles en la web',
              const Color(0xFF6B1E2A)));
      case 'agenda':
        return _dot('Gestionar presentaciones y ferias', const Color(0xFF1E4D6B));
      case 'analytics':
        return _dot('Ver tráfico y métricas', const Color(0xFF0EA5E9));

      case 'config':
        return _dot('Personalizar ajustes', const Color(0xFF10B981));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _dot(String texto, Color color) {
    return Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Text(texto,
          style: TextStyle(fontSize: 11.5, color: _kTextSec),
          overflow: TextOverflow.ellipsis)),
    ]);
  }

  // ── Footer banner ─────────────────────────────────────────────────────────

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _previewTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
      child: Text(texto,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kTextSec)),
    );
  }

  Widget _ph(double width) {
    return Container(
      width: width == double.infinity ? null : width,
      height: 8,
      decoration: BoxDecoration(color: const Color(0xFFE8ECF0), borderRadius: BorderRadius.circular(4)),
    );
  }

  String _fmt(DateTime dt) {
    const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  // ── Abrir módulo en panel lateral (sin Navigator) ────────────────────────

  void _abrirModulo(_WebMod mod) {
    _setModuloActivo(mod.id);
  }

  Widget _buildDemoScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Contenido Web'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.web_rounded, color: Colors.white, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Módulo de Contenido Web',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuenta de demostración',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _demoCard(
              icon: Icons.travel_explore_rounded,
              color: const Color(0xFF1976D2),
              titulo: 'Mapeo automático de tu web',
              descripcion:
                  'Analizamos tu página web y la mapeamos dentro de la app. '
                  'Desde ese momento podrás ver y editar el contenido de tu '
                  'sitio directamente desde el móvil, sin tocar código.',
            ),
            const SizedBox(height: 16),
            _demoCard(
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF388E3C),
              titulo: 'Edición al instante',
              descripcion:
                  'Cambia textos, imágenes, precios o descripciones de tu web '
                  'con un par de toques. Los cambios se publican en tiempo real '
                  'sin necesidad de acceder al panel de tu proveedor de hosting.',
            ),
            const SizedBox(height: 16),
            _demoCard(
              icon: Icons.search_rounded,
              color: const Color(0xFFE64A19),
              titulo: 'SEO integrado',
              descripcion:
                  'Gestiona los metadatos, títulos y descripciones de cada '
                  'página para mejorar tu posicionamiento en Google, todo '
                  'desde la misma aplicación.',
            ),
            const SizedBox(height: 16),
            _demoCard(
              icon: Icons.devices_rounded,
              color: const Color(0xFF7B1FA2),
              titulo: 'Previsualización en tiempo real',
              descripcion:
                  'Antes de publicar cualquier cambio podrás previsualizarlo '
                  'tal y como lo verán tus clientes, tanto en móvil como en '
                  'escritorio.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.amber[700], size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activa tu cuenta completa para conectar tu página web '
                      'y empezar a gestionarla desde el móvil.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoCard({
    required IconData icon,
    required Color color,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(descripcion,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blog: vista dividida (lista | editor) ────────────────────────────────────

class _BlogSplitView extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final bool isDark;
  final void Function(EntradaBlog? entrada, List<CategoriaBlog> cats)? onAbrirEditor;

  const _BlogSplitView({
    required this.empresaId,
    required this.svc,
    this.isDark = false,
    this.onAbrirEditor,
  });

  @override
  State<_BlogSplitView> createState() => _BlogSplitViewState();
}

class _BlogSplitViewState extends State<_BlogSplitView> {
  String? _filtroTipo; // null = todos | 'articulo' | 'noticia'

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
          stream: widget.svc.obtenerBlog(widget.empresaId),
          builder: (_, snap) {
            final articulos = snap.data ?? [];
            final dark = widget.isDark;
            final kBg     = dark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
            final kSurf   = dark ? const Color(0xFF1E293B) : Colors.white;
            final kText   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
            final kSub    = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final kBorder = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            return ColoredBox(
              color: kBg,
              child: Column(children: [
                _buildListHeader(context, articulos, categorias,
                    surf: kSurf, text: kText, sub: kSub, border: kBorder),
                _buildFiltroTipo(surf: kSurf, border: kBorder),
                Expanded(child: _buildArticleGrid(context, articulos, categorias, dark: dark)),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildListHeader(BuildContext context, List<EntradaBlog> articulos,
      List<CategoriaBlog> cats, {
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
          Text('Blog / Noticias', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
          Text('${articulos.length} entrada${articulos.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: sub)),
        ]),
        const Spacer(),
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

  Widget _buildFiltroTipo({Color surf = Colors.white, Color border = const Color(0xFFE2E8F0)}) {
    return Container(
      color: surf,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        _chipTipo(null, 'Todos', const Color(0xFF475569)),
        const SizedBox(width: 6),
        _chipTipo('articulo', 'Artículos', const Color(0xFF2563EB)),
        const SizedBox(width: 6),
        _chipTipo('noticia', 'Noticias', const Color(0xFF059669)),
      ]),
    );
  }

  Widget _chipTipo(String? tipo, String label, Color color) {
    final sel = _filtroTipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _filtroTipo = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : color,
          fontSize: 11.5, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  Widget _buildArticleGrid(BuildContext context, List<EntradaBlog> articulos,
      List<CategoriaBlog> cats, {bool dark = false}) {
    final filtrados = _filtroTipo == null
        ? articulos
        : articulos.where((a) => a.tipo == _filtroTipo).toList();

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

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 700 ? 3 : 2;
        const gap = 12.0;
        const pad = 16.0;
        final cardW = (constraints.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
        final ratio = (cardW / (cardW * 1.45)).clamp(0.55, 1.0);
        return GridView.builder(
          padding: const EdgeInsets.all(pad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: ratio,
          ),
          itemCount: filtrados.length,
          itemBuilder: (_, i) {
            final a = filtrados[i];
            return _ArticleCard(
              articulo: a,
              onTap: () => _abrirEditor(context, cats, entrada: a),
              svc: widget.svc,
              empresaId: widget.empresaId,
              isDark: dark,
            );
          },
        );
      },
    );
  }
}

// ── Tarjeta de artículo en grid ────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final EntradaBlog articulo;
  final VoidCallback onTap;
  final ContenidoWebService svc;
  final String empresaId;
  final bool isDark;

  const _ArticleCard({
    required this.articulo,
    required this.onTap,
    required this.svc,
    required this.empresaId,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = articulo;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF2);
    final titleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subColor   = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final metaColor  = isDark ? const Color(0xFF64748B) : Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Imagen de portada (flexible, máx 30% de la card)
          Flexible(
            flex: 3,
            child: SizedBox(
              width: double.infinity,
              child: a.imagenUrl != null
                  ? Image.network(a.imagenUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh())
                  : _imgPh(),
            ),
          ),
          // Contenido
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                // Badge tipo + estado
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: a.estado.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a.estado.label, style: TextStyle(
                        fontSize: 9, color: a.estado.color, fontWeight: FontWeight.w700)),
                  ),
                  if (a.tipo == 'noticia') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Noticia', style: TextStyle(
                          fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (a.destacado) Icon(Icons.star_rounded, size: 13, color: Colors.amber[600]),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 14, color: metaColor),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'publicar', child: Row(children: [
                        Icon(a.publicada ? Icons.unpublished_outlined : Icons.publish_rounded,
                            size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(a.publicada ? 'Despublicar' : 'Publicar',
                            style: const TextStyle(fontSize: 12)),
                      ])),
                      PopupMenuItem(value: 'duplicar', child: Row(children: [
                        Icon(Icons.copy_outlined, size: 14, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        const Text('Duplicar', style: TextStyle(fontSize: 12)),
                      ])),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'eliminar', child: Row(children: [
                        const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ])),
                    ],
                    onSelected: (action) async {
                      switch (action) {
                        case 'publicar': await svc.togglePublicarBlog(empresaId, a.id, !a.publicada);
                        case 'duplicar': await svc.duplicarEntradaBlog(empresaId, a);
                        case 'eliminar': await svc.eliminarEntradaBlog(empresaId, a.id);
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 4),
                // Título
                Text(
                  a.titulo.isEmpty ? 'Sin título' : a.titulo,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: titleColor, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (a.resumen.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(a.resumen,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: subColor, height: 1.35)),
                ],
                const SizedBox(height: 4),
                // Fecha
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 9, color: metaColor),
                  const SizedBox(width: 3),
                  Flexible(child: Text('${a.fechaFormateada} · ${a.tiempoLecturaMin} min',
                      style: TextStyle(fontSize: 9, color: metaColor),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPh() => Container(
    color: const Color(0xFFEFF6FF),
    child: const Center(child: Icon(Icons.article_rounded, size: 32, color: Color(0xFFBFDBFE))),
  );
}

// ─── Modelo de módulo web ─────────────────────────────────────────────────────

class _WebMod {
  final String id;
  final String titulo;
  final String desc;
  final IconData icono;
  final Color color;
  const _WebMod(this.id, this.titulo, this.desc, this.icono, this.color);
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB SECCIONES (lógica existente extraída a clase separada)
// ═════════════════════════════════════════════════════════════════════════════


class _TabSecciones extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  final void Function(SeccionWeb? seccion, String? pagina)? onAbrirEditor;

  const _TabSecciones({
    required this.empresaId,
    required this.svc,
    required this.color,
    this.onAbrirEditor,
  });

  @override
  State<_TabSecciones> createState() => _TabSeccionesState();
}

class _TabSeccionesState extends State<_TabSecciones> {
  String _paginaFiltro = 'todas';

  static const _paginasBase = [
    ('todas', 'Todas'),
    ('inicio', 'Inicio'),
    ('sobre-nosotros', 'Sobre nosotros'),
    ('servicios', 'Servicios'),
    ('galeria', 'Galería'),
    ('contacto', 'Contacto'),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeccionWeb>>(
      stream: widget.svc.obtenerSecciones(widget.empresaId),
      builder: (_, snap) {
        final todas = snap.data ?? [];
        // Recoger páginas personalizadas que no están en la lista base
        final baseIds = _paginasBase.map((p) => p.$1).toSet();
        final paginasExtra = todas.map((s) => s.pagina)
            .where((p) => !baseIds.contains(p))
            .toSet()
            .toList()..sort();
        final todasPaginas = [..._paginasBase, ...paginasExtra.map((p) => (p, p))];

        final secciones = _paginaFiltro == 'todas'
            ? todas
            : todas.where((s) => s.pagina == _paginaFiltro).toList();
        final activas = secciones.where((s) => s.activa).length;

        return Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${secciones.length} secciones',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                Text('$activas activa${activas == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ]),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirEditor(context, null),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Nueva sección'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          // ── Filtro por página ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: todasPaginas.map((p) {
                  final sel = _paginaFiltro == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _paginaFiltro = p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? widget.color : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? Colors.white : const Color(0xFF64748B))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: secciones.isEmpty
                ? _buildVacio(context)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: secciones.length,
                    onReorder: (oldIdx, newIdx) async {
                      if (newIdx > oldIdx) newIdx--;
                      final lista = List<SeccionWeb>.from(secciones);
                      final item = lista.removeAt(oldIdx);
                      lista.insert(newIdx, item);
                      // Recalcular orden sobre la lista global (todas), no solo el filtro
                      final completa = List<SeccionWeb>.from(todas);
                      for (var i = 0; i < lista.length; i++) {
                        final idx = completa.indexWhere((s) => s.id == lista[i].id);
                        if (idx >= 0) {
                          completa[idx] = lista[i];
                        }
                      }
                      await widget.svc.reordenarSecciones(widget.empresaId, lista);
                    },
                    itemBuilder: (_, i) => _TarjetaSeccion(
                      key: ValueKey(secciones[i].id),
                      seccion: secciones[i],
                      empresaId: widget.empresaId,
                      svc: widget.svc,
                      color: widget.color,
                      onAbrirEditor: (s) => widget.onAbrirEditor?.call(s, s.pagina),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.web_outlined,
              size: 34, color: widget.color.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 16),
        const Text('Sin secciones todavía',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF334155))),
        const SizedBox(height: 6),
        const Text('Añade secciones para que se muestren en tu web',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirEditor(context, null),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Crear primera sección'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ]),
    );
  }

  void _abrirEditor(BuildContext context, SeccionWeb? seccion) {
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(seccion,
          seccion?.pagina ?? (_paginaFiltro == 'todas' ? 'inicio' : _paginaFiltro));
      return;
    }
    // NO Navigator.push cuando hay callback
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PantallaEditorSeccion(
        empresaId: widget.empresaId,
        seccion: seccion,
        svc: widget.svc,
        paginaInicial: seccion?.pagina ?? (_paginaFiltro == 'todas' ? 'inicio' : _paginaFiltro),
      ),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA de cada sección en la lista principal
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaSeccion extends StatefulWidget {
  final SeccionWeb seccion;
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  final void Function(SeccionWeb seccion)? onAbrirEditor;

  const _TarjetaSeccion({
    super.key,
    required this.seccion,
    required this.empresaId,
    required this.svc,
    required this.color,
    this.onAbrirEditor,
  });

  @override
  State<_TarjetaSeccion> createState() => _TarjetaSeccionState();
}

class _TarjetaSeccionState extends State<_TarjetaSeccion> {
  // Estado local del sync (se lee de Firestore al iniciar)
  bool _catalogoSync = false;
  bool _loadingSync  = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadoSync();
  }

  Future<void> _cargarEstadoSync() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('contenido_web').doc(widget.seccion.id)
          .get();
      if (mounted) {
        setState(() => _catalogoSync = doc.data()?['catalogo_sync'] == true);
      }
    } catch (_) {}
  }

  Future<void> _toggleCatalogoSync(BuildContext context) async {
    setState(() => _loadingSync = true);
    final nuevoEstado = !_catalogoSync;
    final syncSvc = CatalogoWebSyncService();
    try {
      if (nuevoEstado) {
        await syncSvc.activarSincronizacion(widget.empresaId, widget.seccion.id);
      } else {
        await syncSvc.desactivarSincronizacion(widget.empresaId, widget.seccion.id);
      }
      if (mounted) {
        setState(() => _catalogoSync = nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(nuevoEstado ? Icons.link_rounded : Icons.link_off_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(nuevoEstado
                ? '✅ Catálogo vinculado — los productos se sincronizarán automáticamente'
                : '⏹ Sincronización desactivada'),
          ]),
          backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loadingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc      = widget.seccion.tipo.color;
    final activa  = widget.seccion.activa;
    final pagina  = widget.seccion.pagina;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _catalogoSync
            ? const Color(0xFF10B981).withValues(alpha: 0.4)
            : const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => _irAEditar(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            // Icono de tipo
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: tc.withValues(alpha: activa ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.seccion.tipo.icono,
                  color: activa ? tc : const Color(0xFFCBD5E1), size: 19),
            ),
            const SizedBox(width: 12),
            // Nombre + tipo + página
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(widget.seccion.nombre,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: activa ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis),
                ),
                if (_catalogoSync) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.link_rounded, size: 9, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text('Sync', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: tc.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(widget.seccion.tipo.nombre,
                      style: TextStyle(fontSize: 10, color: tc, fontWeight: FontWeight.w600)),
                ),
                if (pagina.isNotEmpty && pagina != 'inicio') ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 2),
                  Text(pagina,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            // Switch activo/inactivo
            Switch(
              value: activa,
              onChanged: (v) async {
                try {
                  await widget.svc.toggleSeccion(widget.empresaId, widget.seccion.id, v);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              activeThumbColor: tc,
              activeTrackColor: tc.withValues(alpha: 0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Color(0xFFCBD5E1), size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'editar')    _irAEditar(context);
                if (v == 'sync')      _toggleCatalogoSync(context);
                if (v == 'historial') _mostrarHistorial(context);
                if (v == 'eliminar')  _confirmarEliminar(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF334155)),
                  SizedBox(width: 10),
                  Text('Editar'),
                ])),
                const PopupMenuItem(value: 'historial', child: Row(children: [
                  Icon(Icons.history_rounded, size: 18, color: Color(0xFF6366F1)),
                  SizedBox(width: 10),
                  Text('Ver historial', style: TextStyle(color: Color(0xFF6366F1))),
                ])),
                PopupMenuItem(value: 'sync', child: Row(children: [
                  _loadingSync
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _catalogoSync ? Icons.link_off_rounded : Icons.link_rounded,
                          size: 18, color: _catalogoSync ? Colors.orange : const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Text(_catalogoSync ? 'Desconectar catálogo' : 'Vincular al catálogo',
                      style: TextStyle(
                          color: _catalogoSync ? Colors.orange : const Color(0xFF10B981))),
                ])),
                const PopupMenuItem(value: 'eliminar', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _irAEditar(BuildContext context) {
    final s   = widget.seccion;
    final eid = widget.empresaId;
    final sv  = widget.svc;
    final col = widget.color;

    // Preferir callback embebido (sin Navigator.push) para todos los tipos
    if (widget.onAbrirEditor != null) {
      widget.onAbrirEditor!(s);
      return;
    }

    // Fallback a Navigator.push cuando no hay callback (uso externo al módulo web)
    if (s.tipo == TipoSeccion.generico) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaItemsSeccion(empresaId: eid, seccion: s, svc: sv),
      ));
    } else if (s.tipo == TipoSeccion.eventos) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(title: Text(s.nombre),
              backgroundColor: col, foregroundColor: Colors.white, elevation: 0),
          body: TabEventosWeb(empresaId: eid, svc: sv),
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaEditorSeccion(empresaId: eid, seccion: s, svc: sv),
      ));
    }
  }

  void _mostrarHistorial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Historial de versiones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Últimas 10 versiones guardadas',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerHistorial(widget.empresaId, widget.seccion.id),
              builder: (ctx, snap) {
                final versiones = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (versiones.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 48, color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    const Text('Sin versiones guardadas todavía',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    const Text('Las versiones se crean automáticamente\ncada vez que guardas cambios',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                  ]));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: versiones.length,
                  itemBuilder: (_, i) {
                    final v = versiones[i];
                    final ts = v['guardado_en'];
                    DateTime? fecha;
                    if (ts is Timestamp) fecha = ts.toDate();
                    final nombre = v['nombre'] as String? ?? 'Sin nombre';
                    final tipo = v['tipo'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('v${versiones.length - i}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1))),
                        ),
                      ),
                      title: Text(nombre,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: fecha == null
                          ? Text(tipo, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                          : Text(
                              '$tipo · ${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      trailing: i == 0
                          ? const Chip(
                              label: Text('Anterior', style: TextStyle(fontSize: 10)),
                              backgroundColor: Color(0xFFEEF2FF),
                              labelStyle: TextStyle(color: Color(0xFF6366F1)),
                              padding: EdgeInsets.zero,
                            )
                          : TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await widget.svc.restaurarVersionSeccion(
                                    widget.empresaId, widget.seccion.id, v);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                    content: Text('✅ Versión restaurada'),
                                    backgroundColor: Colors.green,
                                  ));
                                }
                              },
                              child: const Text('Restaurar',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool eliminando = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar sección'),
            ]),
            content: Text(
              '¿Eliminar "${widget.seccion.nombre}"?\n\n'
              'El contenido desaparecerá de tu web inmediatamente y no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: eliminando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: eliminando
                    ? null
                    : () async {
                        setDlg(() => eliminando = true);
                        try {
                          await widget.svc.eliminarSeccion(widget.empresaId, widget.seccion.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('"${widget.seccion.nombre}" eliminada'),
                                ]),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          setDlg(() => eliminando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('❌ Error al eliminar: $e'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        }
                      },
                child: eliminando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sí, eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DE EDICIÓN — Formulario por tipo
// ═════════════════════════════════════════════════════════════════════════════

class PantallaEditorSeccion extends StatefulWidget {
  final String empresaId;
  final SeccionWeb? seccion; // null = nueva
  final ContenidoWebService svc;
  final String paginaInicial;
  final bool noScaffold;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const PantallaEditorSeccion({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.svc,
    this.paginaInicial = 'inicio',
    this.noScaffold = false,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<PantallaEditorSeccion> createState() => _PantallaEditorSeccionState();
}

class _PantallaEditorSeccionState extends State<PantallaEditorSeccion> {
  late TipoSeccion _tipo;
  late String _pagina;
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _idCtrl = TextEditingController(); // ID personalizado para genérico
  final _paginaCtrl = TextEditingController();

  // ── Tipo TEXTO ────────────────────────────────────────────────────────────
  final _tituloCtrl = TextEditingController();
  final _textoCtrl  = TextEditingController();
  String? _imagenUrl;
  bool _subiendoImagen = false;

  // ── Tipo CARTA ────────────────────────────────────────────────────────────
  List<ItemCarta> _carta = [];

  // ── Tipo GALERIA ──────────────────────────────────────────────────────────
  List<ItemGaleria> _galeria = [];

  // ── Tipo OFERTAS ──────────────────────────────────────────────────────────
  List<ItemOferta> _ofertas = [];

  // ── Tipo HORARIOS ─────────────────────────────────────────────────────────
  List<ItemHorario> _horarios = [];

  static const _paginasOpciones = [
    ('inicio', 'Inicio'),
    ('sobre-nosotros', 'Sobre nosotros'),
    ('servicios', 'Servicios'),
    ('galeria', 'Galería'),
    ('contacto', 'Contacto'),
    ('personalizada', 'Otra página…'),
  ];

  bool _guardando = false;

  bool get _esNueva => widget.seccion == null;

  @override
  void initState() {
    super.initState();
    if (widget.seccion != null) {
      final s = widget.seccion!;
      _tipo = s.tipo;
      _pagina = s.pagina;
      _nombreCtrl.text = s.nombre;
      _tituloCtrl.text = s.contenido.titulo;
      _textoCtrl.text  = s.contenido.texto;
      _imagenUrl = s.contenido.imagenUrl;
      _carta   = List.from(s.contenido.itemsCarta);
      _galeria = List.from(s.contenido.imagenesGaleria);
      _ofertas = List.from(s.contenido.ofertas);
      _horarios = s.contenido.horarios.isEmpty
          ? ItemHorario.porDefecto()
          : List.from(s.contenido.horarios);
      // Si la página no está entre las predefinidas, poner modo personalizada
      final conocida = _paginasOpciones.any((p) => p.$1 == _pagina && p.$1 != 'personalizada');
      if (!conocida) _paginaCtrl.text = _pagina;
    } else {
      _tipo = TipoSeccion.texto;
      _pagina = widget.paginaInicial;
      _nombreCtrl.text = TipoSeccion.texto.nombre; // auto-fill inicial
      _horarios = ItemHorario.porDefecto();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _tituloCtrl.dispose(); _textoCtrl.dispose();
    _idCtrl.dispose(); _paginaCtrl.dispose();
    super.dispose();
  }

  Widget _buildFormBody(BuildContext context) {
    final tipoColor = _tipo.color;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            // ── Selector de tipo (solo en nuevas secciones) ───────────────
            if (_esNueva) ...[
              _buildCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('¿Qué tipo de sección quieres añadir?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: TipoSeccion.values.map((t) {
                      final sel = t == _tipo;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _tipo = t;
                          // Auto-rellenar nombre con el del tipo
                          _nombreCtrl.text = t.nombre;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.color
                                : t.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? t.color
                                  : t.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(t.icono,
                                color: sel ? Colors.white : t.color, size: 16),
                            const SizedBox(width: 6),
                            Text(t.nombre,
                                style: TextStyle(
                                    color: sel ? Colors.white : t.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  // Nombre editable (pre-rellenado con el tipo)
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sección',
                      hintText: 'Se rellena automáticamente con el tipo',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.label_outline, color: _tipo.color),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                  ),
                ],
              )),
              const SizedBox(height: 12),
            ] else ...[
              // Edición — mostrar tipo + nombre editable
              _buildCard(child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_tipo.icono, color: tipoColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tipo.nombre,
                          style: TextStyle(color: tipoColor,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text('Tipo fijo — no se puede cambiar',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  )),
                ]),
                const Divider(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la sección',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.label_outline),
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                ),
              ])),
              const SizedBox(height: 12),
            ],

            // ── Selector de página ────────────────────────────────────────
            _buildSelectorPagina(tipoColor),
            const SizedBox(height: 12),

            // ── Editor específico por tipo ─────────────────────────────────
            _buildEditorPorTipo(context, tipoColor),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    final body = _buildFormBody(context);

    if (widget.noScaffold) {
      return LayoutBuilder(builder: (_, constraints) {
        final h = constraints.maxHeight.isInfinite ? null : constraints.maxHeight;
        return SizedBox(
          width: double.infinity,
          height: h,
          child: Column(children: [
            // Barra de acciones: sin color propio, integrada con el layout del dashboard
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _esNueva ? 'Nueva sección' : (_nombreCtrl.text.isEmpty ? 'Editar sección' : _nombreCtrl.text),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (_guardando)
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color))
                else
                  FilledButton(
                    onPressed: () => _guardar(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Guardar cambios'),
                  ),
              ]),
            ),
            Expanded(child: body),
          ]),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva sección' : 'Editar sección'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(
              _guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSelectorPagina(Color c) {
    final esPersonalizada = !_paginasOpciones
        .where((p) => p.$1 != 'personalizada')
        .any((p) => p.$1 == _pagina);
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.folder_open_rounded, color: c, size: 18),
          const SizedBox(width: 8),
          const Text('¿En qué página de WordPress aparece?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7, runSpacing: 7,
          children: _paginasOpciones.map((op) {
            final selActual = op.$1 == 'personalizada' ? esPersonalizada : _pagina == op.$1;
            return GestureDetector(
              onTap: () => setState(() {
                if (op.$1 == 'personalizada') {
                  _pagina = _paginaCtrl.text.trim().isEmpty ? 'personalizada' : _paginaCtrl.text.trim();
                } else {
                  _pagina = op.$1;
                  _paginaCtrl.clear();
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selActual ? c : c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selActual ? c : c.withValues(alpha: 0.25)),
                ),
                child: Text(op.$2,
                    style: TextStyle(
                        color: selActual ? Colors.white : c,
                        fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            );
          }).toList(),
        ),
        if (esPersonalizada) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _paginaCtrl,
            decoration: InputDecoration(
              labelText: 'Slug de la página (ej: mi-pagina)',
              hintText: 'solo-minusculas-y-guiones',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_rounded, color: c),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _pagina = v.trim().isEmpty ? 'personalizada' : v.trim()),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'data-fluix-pagina="${esPersonalizada && _paginaCtrl.text.isNotEmpty ? _paginaCtrl.text.trim() : _pagina}"',
          style: TextStyle(fontSize: 10.5, color: Colors.grey[400], fontFamily: 'monospace'),
        ),
      ],
    ));
  }

  Widget _buildEditorPorTipo(BuildContext context, Color tipoColor) {
    switch (_tipo) {
      case TipoSeccion.texto:    return _buildEditorTexto(context, tipoColor);
      case TipoSeccion.carta:    return _buildEditorCarta(context, tipoColor);
      case TipoSeccion.galeria:  return _buildEditorGaleria(context, tipoColor);
      case TipoSeccion.ofertas:  return _buildEditorOfertas(context, tipoColor);
      case TipoSeccion.horarios: return _buildEditorHorarios(tipoColor);
      case TipoSeccion.generico: return _buildEditorGenericoInfo(tipoColor);
      case TipoSeccion.eventos:  return _buildEditorEventosInfo(tipoColor);
    }
  }

  Widget _buildEditorEventosInfo(Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.event_note_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'Sección de Eventos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          )),
        ]),
        const SizedBox(height: 10),
        Text(
          'Esta sección mostrará los próximos eventos de tu negocio en la web.\n\n'
          'Los eventos se gestionan desde la tarjeta — al guardar y pulsar "Editar" '
          'accederás directamente al gestor de eventos.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
        ),
      ],
    ));
  }

  // ── INFO GENÉRICO (solo informativo — la edición real es en PantallaItemsSeccion)
  Widget _buildEditorGenericoInfo(Color c) {
    return Column(children: [
      _buildCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: c, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Sección genérica (Data-Fluix)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            )),
          ]),
          const SizedBox(height: 10),
          if (_esNueva) ...[
            TextFormField(
              controller: _idCtrl,
              decoration: InputDecoration(
                labelText: 'ID de la sección (slug)',
                hintText: 'ej: carta_entrantes, nuestros_vinos',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, color: c),
                helperText: 'Este ID se usará en data-fluix-seccion="..."',
                helperMaxLines: 2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Escribe un ID (solo minúsculas y _)' : null,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _esNueva
                ? 'Guarda esta sección y después pulsa "Editar" en la tarjeta para gestionar los items.'
                : 'Pulsa "Editar" en la tarjeta para gestionar los items.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Los items se sincronizan en tiempo real con la web del cliente '
            'mediante los atributos data-fluix-*.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      )),
    ]);
  }

  // ── EDITOR TEXTO ──────────────────────────────────────────────────────────
  Widget _buildEditorTexto(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _tituloCtrl,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: InputBorder.none,
          ),
        ),
        const Divider(height: 1),
        TextFormField(
          controller: _textoCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Texto / descripción',
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Imagen
        if (_imagenUrl != null && _imagenUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_imagenUrl!, height: 160, width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextButton.icon(
              onPressed: () => _subirImagen(context, 'texto'),
              icon: Icon(Icons.swap_horiz, color: c),
              label: Text('Cambiar imagen', style: TextStyle(color: c)),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _imagenUrl = null),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Quitar', style: TextStyle(color: Colors.red)),
            ),
          ]),
        ] else
          OutlinedButton.icon(
            onPressed: _subiendoImagen ? null : () => _subirImagen(context, 'texto'),
            icon: _subiendoImagen
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_photo_alternate, color: c),
            label: Text(_subiendoImagen ? 'Subiendo...' : 'Añadir imagen',
                style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.withValues(alpha: 0.4))),
          ),
      ],
    ));
  }

  // ── EDITOR CARTA ──────────────────────────────────────────────────────────
  Widget _buildEditorCarta(BuildContext context, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._carta.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return _buildCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: item.imagenUrl != null
                        ? null : c.withValues(alpha: 0.1),
                    image: item.imagenUrl != null
                        ? DecorationImage(
                            image: NetworkImage(item.imagenUrl!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: item.imagenUrl == null
                      ? Icon(Icons.restaurant, color: c, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nombre.isEmpty ? 'Nuevo plato' : item.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${item.precio.toStringAsFixed(2)}€',
                        style: TextStyle(color: c, fontWeight: FontWeight.w600)),
                  ],
                )),
                Switch(
                  value: item.disponible,
                  onChanged: (v) => setState(() {
                    _carta[i] = item.copyWith(disponible: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarItemCarta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _carta.removeAt(i)),
                ),
              ]),
              if (!item.disponible)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('No disponible temporalmente',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editarItemCarta(context, null, c),
            icon: Icon(Icons.add, color: c),
            label: Text('Añadir plato', style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: c.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  // ── EDITOR GALERÍA ────────────────────────────────────────────────────────
  Widget _buildEditorGaleria(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos de la galería',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Las fotos aparecen en tu web en tiempo real',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: _galeria.length + 1,
          itemBuilder: (ctx, i) {
            if (i == _galeria.length) {
              // Botón añadir
              return GestureDetector(
                onTap: _subiendoImagen ? null : () => _subirFotoGaleria(context, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: _subiendoImagen
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate, color: c, size: 28),
                          const SizedBox(height: 4),
                          Text('Añadir', style: TextStyle(color: c, fontSize: 11)),
                        ]),
                ),
              );
            }
            final img = _galeria[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(img.url, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _galeria.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text('${_galeria.length} foto(s)',
            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    ));
  }

  // ── EDITOR OFERTAS ────────────────────────────────────────────────────────
  Widget _buildEditorOfertas(BuildContext context, Color c) {
    return Column(
      children: [
        ..._ofertas.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          return _buildCard(child: Column(
            children: [
              Row(children: [
                if (o.imagenUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(o.imagenUrl!,
                        width: 56, height: 56, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_offer, color: c, size: 28),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.titulo.isEmpty ? 'Nueva oferta' : o.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      if (o.precioOriginal != null)
                        Text('${o.precioOriginal!.toStringAsFixed(2)}€ ',
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey, fontSize: 12)),
                      if (o.precioOferta != null)
                        Text('${o.precioOferta!.toStringAsFixed(2)}€',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ],
                )),
                Switch(
                  value: o.activa,
                  onChanged: (v) => setState(() {
                    _ofertas[i] = o.copyWith(activa: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarOferta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _ofertas.removeAt(i)),
                ),
              ]),
            ],
          ));
        }),
        const SizedBox(height: 8),
        // Botón "Añadir oferta" ELIMINADO - Las ofertas las añade el administrador
      ],
    );
  }

  // ── EDITOR HORARIOS ───────────────────────────────────────────────────────
  Widget _buildEditorHorarios(Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horarios de apertura',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ..._horarios.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 84,
                child: Text(h.dia,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (h.cerrado)
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cerrado',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ))
              else ...[
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.apertura,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey[400])),
                ),
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.cierre,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _horarios[i] = h.copyWith(cerrado: !h.cerrado);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: h.cerrado
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    h.cerrado ? Icons.lock_open : Icons.lock,
                    color: h.cerrado ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ]),
          );
        }),
      ],
    ));
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Future<void> _seleccionarHora(int idx, bool esApertura) async {
    final h = _horarios[idx];
    final parts = (esApertura ? h.apertura : h.cierre).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (picked == null) return;
    final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _horarios[idx] = esApertura
          ? h.copyWith(apertura: str)
          : h.copyWith(cierre: str);
    });
  }

  Future<void> _subirImagen(BuildContext context, String carpeta) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, carpeta);
    if (mounted) {
      setState(() { _imagenUrl = url; _subiendoImagen = false; });
    }
  }

  Future<void> _subirFotoGaleria(BuildContext context, Color c) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(
        widget.empresaId, 'galeria');
    if (url != null && mounted) {
      setState(() {
        _galeria.add(ItemGaleria(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: url,
        ));
      });
    }
    if (mounted) setState(() => _subiendoImagen = false);
  }

  void _editarItemCarta(BuildContext context, int? idx, Color c) {
    final item        = idx != null ? _carta[idx] : null;
    final nombreCtrl  = TextEditingController(text: item?.nombre ?? '');
    final descCtrl    = TextEditingController(text: item?.descripcion ?? '');
    final precioCtrl  = TextEditingController(
        text: item != null ? item.precio.toStringAsFixed(2) : '');
    final catCtrl     = TextEditingController(text: item?.categoria ?? 'General');

    // Estado local del modal (imagen + spinner)
    String? imagenLocal = item?.imagenUrl;
    bool   subiendoImg  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {

          Future<void> subirImg() async {
            setModalState(() => subiendoImg = true);
            final url = await widget.svc.subirImagenDesdeGaleria(
                widget.empresaId, 'carta/${widget.seccion?.id ?? 'items'}');
            if (url != null) imagenLocal = url;
            setModalState(() => subiendoImg = false);
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Handle
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),

                Text(idx == null ? 'Nuevo producto' : 'Editar producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // ── IMAGEN ───────────────────────────────────────────────
                GestureDetector(
                  onTap: subiendoImg ? null : subirImg,
                  child: Container(
                    width: double.infinity, height: 160,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: imagenLocal != null
                              ? Colors.transparent
                              : c.withValues(alpha: 0.3),
                          style: BorderStyle.solid),
                      image: imagenLocal != null
                          ? DecorationImage(
                              image: NetworkImage(imagenLocal!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: subiendoImg
                        ? Center(child: CircularProgressIndicator(color: c))
                        : imagenLocal == null
                            ? Column(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: c, size: 36),
                                  const SizedBox(height: 6),
                                  Text('Toca para añadir imagen\ndesde la galería',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: c, fontSize: 13)),
                                ])
                            : Align(
                                alignment: Alignment.topRight,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => imagenLocal = null),
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                  ),
                ),
                if (imagenLocal != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: subiendoImg ? null : subirImg,
                    child: Text('Cambiar imagen',
                        style: TextStyle(color: c, fontSize: 12,
                            decoration: TextDecoration.underline)),
                  ),
                ],
                const SizedBox(height: 14),

                // ── CAMPOS ───────────────────────────────────────────────
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                      controller: precioCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                          labelText: 'Precio (€)',
                          border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 16),

                // ── BOTÓN GUARDAR ────────────────────────────────────────
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      final precio = double.tryParse(
                          precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
                      final nuevo = ItemCarta(
                        id:          item?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre:      nombre,
                        descripcion: descCtrl.text.trim(),
                        precio:      precio,
                        categoria:   catCtrl.text.trim().isEmpty
                            ? 'General' : catCtrl.text.trim(),
                        imagenUrl:   imagenLocal,
                        disponible:  item?.disponible ?? true,
                      );
                      setState(() {
                        if (idx != null) _carta[idx] = nuevo;
                        else _carta.add(nuevo);
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _editarOferta(BuildContext context, int? idx, Color c) {
    final o = idx != null ? _ofertas[idx] : null;
    final tituloCtrl = TextEditingController(text: o?.titulo ?? '');
    final descCtrl   = TextEditingController(text: o?.descripcion ?? '');
    final precOrigCtrl = TextEditingController(
        text: o?.precioOriginal?.toStringAsFixed(2) ?? '');
    final precOfCtrl = TextEditingController(
        text: o?.precioOferta?.toStringAsFixed(2) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(idx == null ? 'Nueva oferta' : 'Editar oferta',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(controller: tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título de la oferta',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: precOrigCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Precio original (€)',
                    border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: precOfCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                    labelText: 'Precio oferta (€)',
                    border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final titulo = tituloCtrl.text.trim();
                if (titulo.isEmpty) return;
                final nuevo = ItemOferta(
                  id: o?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  titulo: titulo,
                  descripcion: descCtrl.text.trim(),
                  precioOriginal: double.tryParse(
                      precOrigCtrl.text.replaceAll(',', '.')),
                  precioOferta: double.tryParse(
                      precOfCtrl.text.replaceAll(',', '.')),
                  imagenUrl: o?.imagenUrl,
                  activa: o?.activa ?? true,
                );
                setState(() {
                  if (idx != null) _ofertas[idx] = nuevo;
                  else _ofertas.add(nuevo);
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: c, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final contenido = ContenidoSeccion(
      titulo: _tituloCtrl.text.trim(),
      texto:  _textoCtrl.text.trim(),
      imagenUrl: _imagenUrl,
      itemsCarta: _carta,
      imagenesGaleria: _galeria,
      ofertas: _ofertas,
      horarios: _horarios,
      items: widget.seccion?.contenido.items ?? [],
    );

    // Para genéricos nuevos, usar el ID personalizado
    String seccionId = widget.seccion?.id ?? '';
    if (_esNueva && _tipo == TipoSeccion.generico && _idCtrl.text.trim().isNotEmpty) {
      seccionId = _idCtrl.text.trim();
    }

    final seccion = SeccionWeb(
      id: seccionId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: '',
      activa: widget.seccion?.activa ?? true,
      tipo: _tipo,
      contenido: contenido,
      fechaCreacion: widget.seccion?.fechaCreacion ?? DateTime.now(),
      fechaActualizacion: DateTime.now(),
      pagina: _pagina,
    );

    try {
      await widget.svc.guardarSeccion(widget.empresaId, seccion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Guardado! Los cambios ya se ven en tu web'),
          ]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
        if (widget.noScaffold) {
          widget.onGuardado?.call();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB GALERÍA WEB — imágenes y medios del sitio
// ═════════════════════════════════════════════════════════════════════════════

class _TabGaleriaWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;

  const _TabGaleriaWeb({required this.empresaId, required this.svc, required this.color});

  @override
  State<_TabGaleriaWeb> createState() => _TabGaleriaWebState();
}

class _TabGaleriaWebState extends State<_TabGaleriaWeb> {
  List<Map<String, dynamic>> _imagenes = [];
  bool _cargando = false;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final imgs = await widget.svc.obtenerGaleria(widget.empresaId);
      if (mounted) setState(() { _imagenes = imgs; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendo = true);
    try {
      final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'web/galeria');
      if (url != null && mounted) {
        await widget.svc.agregarAGaleria(widget.empresaId, url);
        await _cargar();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.photo_library_rounded, color: widget.color, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Galería', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_imagenes.length} imagen${_imagenes.length != 1 ? 'es' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          FilledButton.icon(
            onPressed: _subiendo ? null : _subirImagen,
            icon: _subiendo
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Subir imagen', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _cargando
          ? Center(child: CircularProgressIndicator(color: widget.color))
          : _imagenes.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: Icon(Icons.photo_library_outlined, size: 34, color: widget.color.withValues(alpha: 0.45))),
                  const SizedBox(height: 16),
                  const Text('Sin imágenes todavía', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  const Text('Sube imágenes para usarlas en tu web', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _subirImagen,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Subir primera imagen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: _imagenes.length,
                  itemBuilder: (_, i) {
                    final img = _imagenes[i];
                    final url = img['url'] as String? ?? '';
                    return Stack(children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          image: url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                        ),
                        child: url.isEmpty ? Center(child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 32)) : null,
                      ),
                      Positioned(top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            await widget.svc.eliminarDeGaleria(widget.empresaId, img['id'] as String? ?? '');
                            await _cargar();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        )),
                    ]);
                  },
                )),
    ]);
  }
}

// ─── Eventos embebidos (sin Scaffold) ────────────────────────────────────────

class _EmbeddedEventos extends StatelessWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService svc;
  final VoidCallback onCerrar;
  final Color color;

  const _EmbeddedEventos({
    required this.empresaId,
    required this.seccion,
    required this.svc,
    required this.onCerrar,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TabEventosWeb(empresaId: empresaId, svc: svc);
  }
}

// ─── Editor catálogo embebido (sin Scaffold propio) ──────────────────────────

class _EditorCatalogoEmbebido extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Map<String, dynamic>? item;
  final Color color;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const _EditorCatalogoEmbebido({
    required this.empresaId, required this.svc, required this.color,
    this.item, this.onGuardado, this.onCancelar,
  });

  @override
  State<_EditorCatalogoEmbebido> createState() => _EditorCatalogoEmbebidoState();
}

class _EditorCatalogoEmbebidoState extends State<_EditorCatalogoEmbebido> {
  final _nombreCtrl      = TextEditingController();
  final _slugCtrl        = TextEditingController();
  final _categoriaCtrl   = TextEditingController();
  final _tagCtrl         = TextEditingController();
  final _precioCtrl      = TextEditingController();
  final _precioDigCtrl   = TextEditingController();
  final _stripeLinkCtrl  = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _autorCtrl       = TextEditingController();
  final _isbnCtrl        = TextEditingController();
  final _paginasCtrl     = TextEditingController();
  final _formatoCtrl     = TextEditingController();
  final _dimensionesCtrl = TextEditingController();
  final _mesCtrl         = TextEditingController();
  int    _anio  = DateTime.now().year;
  bool   _activo = true;
  bool   _extraExpanded = false;
  bool   _guardando = false;
  bool   _subiendoImg = false;
  String? _imagenUrl;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _nombreCtrl.text      = it['nombre'] ?? '';
      _slugCtrl.text        = it['slug'] ?? '';
      _categoriaCtrl.text   = it['categoria'] ?? '';
      _tagCtrl.text         = it['tag'] ?? '';
      _imagenUrl            = it['imagen_url'] as String?;
      _precioCtrl.text      = it['precio'] ?? '';
      _precioDigCtrl.text   = it['precio_digital'] ?? '';
      _stripeLinkCtrl.text  = it['stripe_link'] ?? '';
      _descCtrl.text        = it['descripcion'] ?? '';
      _autorCtrl.text       = it['campo_autor'] ?? '';
      _isbnCtrl.text        = it['campo_isbn'] ?? '';
      _paginasCtrl.text     = it['campo_paginas'] ?? '';
      _formatoCtrl.text     = it['campo_formato'] ?? '';
      _dimensionesCtrl.text = it['campo_dimensiones'] ?? '';
      _mesCtrl.text         = it['campo_mes'] ?? '';
      _anio   = int.tryParse(it['campo_anio']?.toString() ?? '') ?? DateTime.now().year;
      _activo = it['activo'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _slugCtrl, _categoriaCtrl, _tagCtrl,
        _precioCtrl, _precioDigCtrl, _stripeLinkCtrl, _descCtrl,
        _autorCtrl, _isbnCtrl, _paginasCtrl, _formatoCtrl, _dimensionesCtrl, _mesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    try {
      final url = await widget.svc.subirImagenDesdeGaleria(
          widget.empresaId, 'catalogo_web');
      if (!mounted) return;
      if (url != null) {
        setState(() => _imagenUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Imagen subida correctamente'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se seleccionó ninguna imagen'),
          behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al subir: $e'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _subiendoImg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Column(children: [
      // Mini-appbar del editor (sin Scaffold propio)
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onCancelar,
          ),
          const SizedBox(width: 4),
          Text(
            widget.item == null ? 'Nuevo elemento' : 'Editar elemento',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: _guardando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _guardando ? null : () => _guardar(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            ),
            child: const Text('Publicar en web'),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _card(Column(children: [
              _campo(_nombreCtrl, 'Nombre / Título *'),
              const Divider(height: 1),
              _campo(_slugCtrl, 'Slug URL', hint: 'titulo-sin-espacios'),
              const Divider(height: 1),
              _campo(_categoriaCtrl, 'Categoría / Tipo'),
              const Divider(height: 1),
              _campo(_tagCtrl, 'Badge (ej: Novedad, Recomendado)'),
              const Divider(height: 1),
              // Imagen — subida desde archivos
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  // Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imagenUrl != null && _imagenUrl!.isNotEmpty
                        ? Image.network(_imagenUrl!, width: 56, height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgFallback(color))
                        : _imgFallback(color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_imagenUrl != null ? 'Imagen seleccionada' : 'Sin imagen',
                        style: TextStyle(fontSize: 13,
                            color: _imagenUrl != null ? const Color(0xFF0F172A) : Colors.grey[400])),
                    const SizedBox(height: 6),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: _subiendoImg ? null : _subirImagen,
                        icon: _subiendoImg
                            ? const SizedBox(width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_rounded, size: 14),
                        label: Text(_imagenUrl != null ? 'Cambiar imagen' : 'Subir imagen',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color, side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_imagenUrl != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _imagenUrl = null),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Quitar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ]),
                  ])),
                ]),
              ),
            ])),
            const SizedBox(height: 10),
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _campo(_precioCtrl, 'Precio (ej: 14,50 €)'),
              const Divider(height: 1),
              _campo(_precioDigCtrl, 'Precio digital / ebook (ej: 4,99 €)'),
              const Divider(height: 1),
              _campo(_stripeLinkCtrl, 'Link de pago Stripe',
                  hint: 'https://buy.stripe.com/…'),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 5),
                  Expanded(child: Text(
                    'Con Stripe link el cliente verá un botón "Comprar" en la web.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  )),
                ]),
              ),
            ])),
            const SizedBox(height: 10),
            _card(TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Descripción / sinopsis…',
                border: InputBorder.none, contentPadding: EdgeInsets.zero),
            )),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _extraExpanded = !_extraExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Icon(Icons.tune_rounded, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Datos adicionales (autor, ISBN, páginas…)',
                      style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
                  Icon(_extraExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18, color: color),
                ]),
              ),
            ),
            if (_extraExpanded) ...[
              const SizedBox(height: 4),
              _card(Column(children: [
                _campo(_autorCtrl, 'Autor / Responsable'),
                const Divider(height: 1),
                _campo(_isbnCtrl, 'ISBN / Referencia'),
                const Divider(height: 1),
                _campo(_paginasCtrl, 'Páginas / Unidades'),
                const Divider(height: 1),
                _campo(_formatoCtrl, 'Formato'),
                const Divider(height: 1),
                _campo(_dimensionesCtrl, 'Dimensiones'),
                const Divider(height: 1),
                _campo(_mesCtrl, 'Mes'),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    const Text('Año', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _anio,
                      underline: const SizedBox(),
                      items: List.generate(30, (i) => DateTime.now().year - i + 2)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) => setState(() => _anio = v ?? _anio),
                    ),
                  ]),
                ),
              ])),
            ],
            const SizedBox(height: 10),
            _card(SwitchListTile(
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              title: Text(_activo ? '✅ Visible en la web' : '⏸ Oculto en la web',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                _activo ? 'Aparece en el catálogo de tu sitio web'
                        : 'No aparece en el catálogo de tu sitio web',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              contentPadding: EdgeInsets.zero,
              activeColor: color,
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ]);
  }

  Widget _imgFallback(Color color) => Container(
    width: 56, height: 72,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
    child: Icon(Icons.image_outlined, color: color.withValues(alpha: 0.4), size: 24),
  );

  Widget _campo(TextEditingController ctrl, String label, {String? hint}) =>
      TextField(controller: ctrl,
        decoration: InputDecoration(
          hintText: hint ?? label, labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10)));

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Future<void> _guardar(BuildContext context) async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    final docId = widget.item?['id'] as String?;
    final data = <String, dynamic>{
      'nombre':         _nombreCtrl.text.trim(),
      'slug':           _slugCtrl.text.trim(),
      'categoria':      _categoriaCtrl.text.trim(),
      'tag':            _tagCtrl.text.trim(),
      'imagen_url':     _imagenUrl ?? '',
      'precio':         _precioCtrl.text.trim(),
      'precio_digital': _precioDigCtrl.text.trim(),
      'stripe_link':    _stripeLinkCtrl.text.trim(),
      'descripcion':    _descCtrl.text.trim(),
      'activo':         _activo,
      'campo_anio':     _anio.toString(),
    };
    void opt(String k, String v) { if (v.isNotEmpty) data[k] = v; }
    opt('campo_autor',       _autorCtrl.text.trim());
    opt('campo_isbn',        _isbnCtrl.text.trim());
    opt('campo_paginas',     _paginasCtrl.text.trim());
    opt('campo_formato',     _formatoCtrl.text.trim());
    opt('campo_dimensiones', _dimensionesCtrl.text.trim());
    opt('campo_mes',         _mesCtrl.text.trim());
    try {
      await widget.svc.guardarItemCatalogo(widget.empresaId, docId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Guardado — visible en la web en segundos'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        widget.onGuardado?.call();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
















