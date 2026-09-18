import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
import 'tab_archivo_historico.dart';
import 'pantalla_editor_blog.dart';
import 'pantalla_editor_word.dart';
import 'tab_analytics_web.dart';
import 'pantalla_items_seccion.dart';

part 'pantalla_contenido_web_blog.dart';
part 'pantalla_contenido_web_secciones.dart';
part 'pantalla_contenido_web_galeria.dart';
part 'pantalla_contenido_web_autores.dart';

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

  List<_WebSeccionDin> _webSecciones = [];
  StreamSubscription<QuerySnapshot>? _seccionesSub;

  // Cache del blog compartido por todas las fichas del hub.
  List<EntradaBlog> _blogCache = [];
  StreamSubscription<List<EntradaBlog>>? _blogSub;
  List<EntradaBlog> _noticiasCache    = [];
  List<EntradaBlog> _entrevistasCache = [];
  StreamSubscription<List<EntradaBlog>>? _noticiasSub;
  StreamSubscription<List<EntradaBlog>>? _entrevistasSub;

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
    _seccionesSub = FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('web_secciones')
        .orderBy('orden')
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() {
        _webSecciones = snap.docs.map(_WebSeccionDin.fromDoc).toList();
      });
    }, onError: (_) {});
    _autoSeedNazariSecciones();
    _blogSub = _svc.obtenerBlog(widget.empresaId).listen(
      (entries) { if (mounted) setState(() => _blogCache = entries); },
      onError: (_) {},
    );
    _noticiasSub = _svc.obtenerBlogPorTipo(widget.empresaId, 'noticia', limite: 300).listen(
      (entries) { if (mounted) setState(() => _noticiasCache = _dedup(entries)); },
      onError: (_) {},
    );
    _entrevistasSub = _svc.obtenerBlogPorTipo(widget.empresaId, 'entrevista', limite: 300).listen(
      (entries) { if (mounted) setState(() => _entrevistasCache = _dedup(entries)); },
      onError: (_) {},
    );
  }

  Future<void> _autoSeedNazariSecciones() async {
    if (widget.empresaId != _kNazariId) return;
    try {
      final col = FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('web_secciones');
      final snap = await col.limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      final seed = [
        {'nombre': 'Catálogo', 'tipo': 'catalogo', 'orden': 0, 'activa': true},
        {'nombre': 'Blog',     'tipo': 'blog',     'orden': 1, 'activa': true},
      ];
      for (final s in seed) { batch.set(col.doc(), s); }
      await batch.commit();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(PantallaContenidoWeb old) {
    super.didUpdateWidget(old);
    if (old.volverAlHub != widget.volverAlHub) {
      old.volverAlHub?.removeListener(_onVolverAlHub);
      widget.volverAlHub?.addListener(_onVolverAlHub);
    }
  }

  static List<EntradaBlog> _dedup(List<EntradaBlog> entries) {
    final vistos = <String>{};
    return entries.where((e) {
      final k  = e.slug.isNotEmpty ? e.slug : e.id;
      final kt = 't:${e.titulo.trim().toLowerCase()}';
      if (vistos.contains(k) || (e.titulo.isNotEmpty && vistos.contains(kt))) return false;
      vistos.add(k);
      if (e.titulo.isNotEmpty) vistos.add(kt);
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _seccionesSub?.cancel();
    _blogSub?.cancel();
    _noticiasSub?.cancel();
    _entrevistasSub?.cancel();
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
    final subMod = (tipo == 'editar_blog' || tipo == 'editar_blog_clasico') ? 'editor_blog'
        : tipo == 'editar_catalogo' ? 'editor_catalogo'
        : 'editor_seccion';
    widget.onSubModuloChanged?.call(subMod);
  }

  void _cerrarSubVista() {
    setState(() => _subVista = null);
    widget.onSubModuloChanged?.call(_moduloActivo);
  }

  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  // Módulos fijos (siempre presentes, sin importar el HTML de la empresa)
  static const _modsFixed = [
    _WebMod('mensajes',  'Mensajes',      '',                                                     Icons.chat_bubble_rounded,  Color(0xFF059669)),
    _WebMod('analytics', 'Analytics',     'Tráfico, visitas y estadísticas\nde tu sitio web',    Icons.bar_chart_rounded,    Color(0xFF0EA5E9)),
    _WebMod('campanas',  'Email',          'Crea y envía campañas de\nemail marketing',            Icons.campaign_rounded,     Color(0xFFE11D48)),
    _WebMod('config',    'Configuración',  'Personaliza tu sitio web y\nsus ajustes',             Icons.settings_rounded,     Color(0xFF7C3AED)),
  ];

  // Módulos dinámicos generados desde web_secciones (data-fluix-Nombre-Tipo)
  List<_WebMod> get _mods {
    // Para Nazarí, los módulos de contenido son fijos; excluir wsc_* que dupliquen.
    final esNazari = widget.empresaId == _kNazariId;
    final dinamicos = _webSecciones
        .where((s) => !esNazari || (s.tipo != 'catalogo' && s.tipo != 'blog'))
        .map((s) => s.toWebMod())
        .toList();
    final base = [...dinamicos, ..._modsFixed];
    if (!esNazari) return base;
    return [
      const _WebMod('catalogo',    'Catálogo',        'Gestiona los libros\ny el catálogo editorial',        Icons.menu_book_rounded,         Color(0xFF6B1E2A)),
      const _WebMod('agenda',      'Agenda',          'Presentaciones, firmas\ny eventos',                   Icons.event_rounded,             Color(0xFF1E4D6B)),
      const _WebMod('noticias',    'Noticias',        'Crónicas, reseñas\ny actualidad editorial',           Icons.newspaper_rounded,         Color(0xFF059669)),
      const _WebMod('entrevistas', 'Entrevistas',     'Entrevistas a autores\ny protagonistas',              Icons.record_voice_over_rounded, Color(0xFF7C3AED)),
      const _WebMod('autores',     'Autores',         'Fichas de autores\ny colaboradores',                  Icons.person_rounded,            Color(0xFF0EA5E9)),
      ...base,
      const _WebMod('seleccion',   'Selección Nazarí','Gestiona la curaduría editorial\ny el libro del mes', Icons.stars_rounded,             Color(0xFF6B1E2A)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (DemoCuentaService().esDemo(email)) return _buildDemoScreen(context);

    // Hub: 2 páginas paginables (5 fichas + 1 slot flecha en página 1)
    final page1    = _mods.take(5).toList();
    final page2    = _mods.skip(5).toList();
    final hayPag2  = page2.isNotEmpty;

    final hub = ColoredBox(
      key: const ValueKey('hub'),
      color: _kBg,
      child: Column(children: [
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _hubPage = p),
            children: [
              _buildHubPagina(page1, pageIndex: 0, conFlechaSiguiente: hayPag2),
              _buildHubPagina(page2, pageIndex: 1, conFlechaSiguiente: false, rellenarA6: true),
            ],
          ),
        ),
        _buildHubIndicador(page1, page2),
      ]),
    );

    final modulo = _moduloActivo != null
        ? KeyedSubtree(key: ValueKey(_moduloActivo), child: _buildVistaModulo())
        : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve:  Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end:   Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: modulo ?? hub,
    );
  }

  // ── Hub helpers ──────────────────────────────────────────────────────────

  Widget _buildHubPagina(List<_WebMod> mods, {
    required int pageIndex,
    required bool conFlechaSiguiente,
    bool rellenarA6 = false,
  }) {
    // AnimatedBuilder lee directamente del PageController — no llama setState en el padre
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (_, child) {
        final offset = _pageCtrl.hasClients
            ? (_pageCtrl.page ?? pageIndex.toDouble())
            : pageIndex.toDouble();
        final dist  = (offset - pageIndex).abs().clamp(0.0, 1.0);
        final scale = 1.0 - dist * 0.035;
        return Transform.scale(scale: scale, child: child);
      },
      child: LayoutBuilder(builder: (ctx, constraints) {
          final ancho = constraints.maxWidth;
          final cols = ancho >= 700 ? 3 : 2;
          const targetSlots = 6;
          final realSlots = mods.length + (conFlechaSiguiente ? 1 : 0);
          final totalSlots = rellenarA6 ? targetSlots : realSlots;
          const pad = 12.0;
          const gap = 10.0;
          final rows = (totalSlots / cols).ceil();
          final cardW = (ancho - pad * 2 - gap * (cols - 1)) / cols;
          final cardH = (constraints.maxHeight - pad * 2 - gap * (rows - 1)) / rows;
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
            itemCount: totalSlots,
            itemBuilder: (_, i) {
              if (i < mods.length) return _buildModuloCard(mods[i]);
              if (conFlechaSiguiente && i == mods.length) return _buildNextArrowCard();
              return _buildGhostCard();
            },
          );
        }),
    );
  }

  // Flecha estática (la animación está en el swipe, no aquí)
  Widget _buildNextArrowCard() {
    return GestureDetector(
      onTap: () => _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEDF0F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _kBorder.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: 0.07),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF334155).withValues(alpha: 0.10),
              border: Border.all(
                  color: const Color(0xFF334155).withValues(alpha: 0.20), width: 1.5),
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                size: 26, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Text('Más módulos',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: _kTextSec, letterSpacing: .2)),
          const SizedBox(height: 3),
          Text('Analytics · Email · Config',
              style: TextStyle(fontSize: 9.5,
                  color: _kTextSec.withValues(alpha: 0.55))),
        ]),
      ),
    );
  }

  // Slot fantasma — mantiene el grid completo a 6 fichas en página 2
  Widget _buildGhostCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.5),
        border: Border.all(
            color: _kBorder.withValues(alpha: 0.3),
            style: BorderStyle.solid),
      ),
    );
  }

  Widget _buildHubIndicador(List<_WebMod> p1, List<_WebMod> p2) {
    final numPaginas = p2.isEmpty ? 1 : 2;
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Dots de página
        Row(children: List.generate(numPaginas, (i) {
          final sel = _hubPage == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(right: 5),
            width: sel ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: sel
                  ? (_isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155))
                  : (_isDark ? const Color(0xFF334155) : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        })),
        // Botón volver solo visible en página 2
        if (_hubPage > 0)
          TextButton.icon(
            onPressed: () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic),
            icon: const Icon(Icons.arrow_back_rounded, size: 13),
            label: const Text('Volver'),
            style: TextButton.styleFrom(
              foregroundColor: _kTextSec,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 11.5),
            ),
          )
        else
          const SizedBox.shrink(),
      ]),
    );
  }

  // ── Vista de módulo con sidebar ───────────────────────────────────────────

  Widget _buildVistaModulo() {
    final mod = _mods.firstWhere(
        (m) => m.id == _moduloActivo && m.id != '__add__',
        orElse: () => _modsFixed.first);

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
        // Editor Word — nuevo editor limpio por defecto
        content = PantallaEditorWord(
          empresaId: widget.empresaId,
          svc: _svc,
          entrada: sv.entrada,
          categorias: sv.categorias,
          onGuardado: _cerrarSubVista,
          onCancelar: _cerrarSubVista,
        );
      } else if (sv.tipo == 'editar_blog_clasico') {
        // Editor clásico 3 paneles (para usuarios avanzados)
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
      case 'agenda':    return TabEventosWeb(
          empresaId: widget.empresaId,
          svc: _svc,
          onAbrirEditorWord: (entrada, cats) => _abrirSubVista(
            tipo: 'editar_blog',
            entrada: entrada,
            categorias: cats.cast<CategoriaBlog>(),
          ),
        );
      case 'blog':      return _BlogSplitView(
          empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
          onAbrirEditor: (entrada, cats) => _abrirSubVista(
            tipo: 'editar_blog', entrada: entrada, categorias: cats),
        );
      case 'noticias':    return _BlogSplitView(
          empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
          filtroTipoFijo: 'noticia', titulo: 'Noticias',
          onAbrirEditor: (entrada, cats) => _abrirSubVista(
            tipo: 'editar_blog', entrada: entrada, categorias: cats));
      case 'entrevistas': return _BlogSplitView(
          empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
          filtroTipoFijo: 'entrevista', titulo: 'Entrevistas',
          onAbrirEditor: (entrada, cats) => _abrirSubVista(
            tipo: 'editar_blog', entrada: entrada, categorias: cats));
      case 'autores':     return _AutoresNazariTab(
          empresaId: widget.empresaId, svc: _svc, color: mod.color);
      case 'archivo':     return TabArchivoHistorico(
          empresaId: widget.empresaId, color: mod.color);
      case 'mensajes':  return TabMensajesContacto(empresaId: widget.empresaId, color: mod.color);
      case 'campanas':  return TabCampanasEmail(empresaId: widget.empresaId, color: mod.color);
      case 'galeria':    return _TabGaleriaWeb(empresaId: widget.empresaId, svc: _svc, color: mod.color);
      case 'analytics':  return TabAnalyticsWeb(empresaId: widget.empresaId);
      case 'config':     return TabConfigWeb(empresaId: widget.empresaId, svc: _svc);
      case 'seleccion':  return TabSeleccionNazari(empresaId: widget.empresaId);
      default:
        if (mod.id.startsWith('wsc_')) {
          final seccionId = mod.id.substring(4);
          _WebSeccionDin? sec;
          for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
          if (sec == null) return const Center(child: Text('Sección no encontrada'));
          if (sec.tipo == 'blog') {
            return _BlogSplitView(
              empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
              seccionId: seccionId,
              onAbrirEditor: (entrada, cats) => _abrirSubVista(
                tipo: 'editar_blog', entrada: entrada, categorias: cats),
            );
          } else {
            return TabCatalogoWeb(
              empresaId: widget.empresaId, svc: _svc, color: mod.color,
              seccionId: seccionId,
              onAbrirEditor: (item) => _abrirSubVista(tipo: 'editar_catalogo', itemCatalogo: item));
          }
        }
        return const Center(child: Text('Módulo no disponible'));
    }
  }


  // ── Header compacto ───────────────────────────────────────────────────────

  // ── Tarjeta de módulo (estilo screenshot) ────────────────────────────────

  Widget _buildModuloCard(_WebMod mod) {
    if (mod.id == '__add__') return _buildAddCard();
    final esDinamica = mod.id.startsWith('wsc_');
    return GestureDetector(
      onTap: () => _abrirModulo(mod),
      onLongPress: esDinamica ? () => _mostrarOpcionesSeccion(context, mod) : null,
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
      case 'blog':        return _previewBlog(mod.color);
      case 'noticias':    return _previewBlogPorTipo(mod.color, 'noticia');
      case 'entrevistas': return _previewBlogPorTipo(mod.color, 'entrevista');
      case 'autores':     return _previewAutores(mod.color);
      case 'archivo':     return _previewArchivoWp(mod.color);
      case 'mensajes':   return _previewMensajes(mod.color);
      case 'campanas':   return _previewCampanas(mod.color);
      case 'analytics':  return _previewAnalytics(mod.color);
      case 'config':     return _previewConfig();
      case '__add__':    return _previewAdd();
      default:
        if (mod.id.startsWith('wsc_')) {
          final seccionId = mod.id.substring(4);
          _WebSeccionDin? sec;
          for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
          return sec?.tipo == 'blog'
              ? _previewBlog(mod.color)
              : _previewCatalogoScoped(mod.color, seccionId);
        }
        return const SizedBox.shrink();
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
    const meses = ['Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    return StreamBuilder<List<EventoWeb>>(
      stream: _svc.obtenerEventos(widget.empresaId),
      builder: (_, snap) {
        final todos    = snap.data ?? [];
        final proximos = todos.where((e) => e.activo && !e.eliminado && e.esFuturo).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        final muestra  = proximos.take(3).toList();
        final restantes = proximos.length - muestra.length;

        if (muestra.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_available_rounded, size: 28, color: c.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('Sin eventos próximos',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ]));
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...muestra.map((e) {
              final dia = e.fecha.day.toString().padLeft(2, '0');
              final mes = meses[e.fecha.month - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(dia, style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w800, height: 1)),
                      Text(mes.toUpperCase(), style: const TextStyle(color: Colors.white70,
                          fontSize: 7.5, fontWeight: FontWeight.w600, letterSpacing: .3)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.titulo,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if ((e.ciudad ?? '').isNotEmpty)
                      Text(e.ciudad!,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                  ])),
                ]),
              );
            }),
            if (restantes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+ $restantes evento${restantes == 1 ? '' : 's'} más',
                    style: TextStyle(fontSize: 10, color: c,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        );
      },
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
    const tipoConfig = {
      'entrevista': (Icons.record_voice_over_rounded, Color(0xFF7C3AED), 'Entrevistas'),
      'noticia':    (Icons.newspaper_rounded,          Color(0xFF059669), 'Noticias'),
      'articulo':   (Icons.article_rounded,            Color(0xFF2563EB), 'Artículos'),
      'resena':     (Icons.rate_review_rounded,        Color(0xFFD97706), 'Reseñas'),
    };

    // Usar los mismos caches deduplicados que usan los tabs
    final conteos = <String, int>{};
    if (_entrevistasCache.isNotEmpty) conteos['entrevista'] = _entrevistasCache.length;
    if (_noticiasCache.isNotEmpty)    conteos['noticia']    = _noticiasCache.length;
    // Otros tipos (artículo, reseña) siguen viniendo de _blogCache
    for (final a in _blogCache) {
      if (a.tipo != 'entrevista' && a.tipo != 'noticia') {
        final t = a.tipo.isEmpty ? 'articulo' : a.tipo;
        conteos[t] = (conteos[t] ?? 0) + 1;
      }
    }

    // Última publicación: la más reciente entre todos los caches
    final arts = [
      ..._entrevistasCache,
      ..._noticiasCache,
      ..._blogCache.where((a) => a.tipo != 'entrevista' && a.tipo != 'noticia'),
    ]..sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion));

    if (arts.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.article_rounded, size: 28, color: c.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text('Sin publicaciones', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ]));
    }

    final ultima = arts.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Mini tarjeta última entrada
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.article_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ultima.titulo,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A), height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(_fmt(ultima.fechaPublicacion),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        // Desglose por categoría
        Wrap(spacing: 6, runSpacing: 4, children: conteos.entries.map((e) {
          final cfg = tipoConfig[e.key];
          final ico  = cfg?.$1 ?? Icons.article_rounded;
          final clr  = cfg?.$2 ?? c;
          final lbl  = cfg?.$3 ?? e.key;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: clr.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: clr.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ico, size: 10, color: clr),
              const SizedBox(width: 3),
              Text('$lbl ${e.value}',
                  style: TextStyle(fontSize: 9.5, color: clr,
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList()),
      ]),
    );
  }

  Widget _previewAutores(Color c) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerAutores(widget.empresaId),
      builder: (_, snap) {
        final total = snap.data?.length ?? 0;
        return _previewContador(
          label:    'Autores del catálogo',
          valor:    '$total',
          sublabel: 'poetas, narradores, ensayistas',
          icon:     Icons.person_rounded,
          color:    c,
        );
      },
    );
  }

  Widget _previewArchivoWp(Color c) {
    final noticias    = _noticiasCache.length;
    final entrevistas = _entrevistasCache.length;
    final total       = noticias + entrevistas;
    return _previewContador(
      label:    'Archivo histórico web',
      valor:    total > 0 ? '$total' : '—',
      sublabel: total > 0
          ? '$noticias noticias · $entrevistas entrevistas'
          : 'Noticias · Entrevistas · Autores · Libros',
      icon:     Icons.archive_rounded,
      color:    c,
    );
  }

  Widget _previewBlogPorTipo(Color c, String tipo) {
    final arts = (tipo == 'noticia' ? _noticiasCache : _entrevistasCache);
    if (arts.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.article_rounded, size: 28, color: c.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text('Sin publicaciones', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ]));
    }
    final ultima = arts.first;
    final sinImg = arts.where((e) =>
        (e.imagenUrl == null || e.imagenUrl!.isEmpty) && e.imagenes.isEmpty).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.article_rounded, size: 16, color: Colors.white)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ultima.titulo,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A), height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(_fmt(ultima.fechaPublicacion),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ])),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${arts.length} entrada${arts.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w600)),
          if (sinImg > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text('$sinImg sin imagen',
                  style: const TextStyle(fontSize: 9, color: Color(0xFFD97706),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
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


  Widget _previewCampanas(Color c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.campaign_rounded, color: c, size: 24),
        ),
        const SizedBox(height: 10),
        Text('Campañas de email',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Crea y envía newsletters\na tus clientes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: _kTextSec, height: 1.4)),
      ]),
    );
  }

  Widget _previewAnalytics(Color c) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('estadisticas').doc('trafico_web')
          .snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final visitas  = (d?['visitas_totales'] as num?)?.toInt()
            ?? (d?['visitas'] as num?)?.toInt() ?? 0;
        final sesiones = (d?['sesiones_total'] as num?)?.toInt()
            ?? (d?['sesiones'] as num?)?.toInt() ?? 0;
        final rebote   = (d?['tasa_rebote'] as num?)?.toDouble() ?? 0.0;
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
      case 'blog': {
        final n = _entrevistasCache.length + _noticiasCache.length;
        return _dot('$n artículo${n == 1 ? '' : 's'} publicado${n == 1 ? '' : 's'}',
            const Color(0xFF10B981));
      }
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
      case 'noticias': {
        final cnt = _noticiasCache.length;
        return _dot('$cnt noticia${cnt == 1 ? '' : 's'} publicada${cnt == 1 ? '' : 's'}',
            const Color(0xFF059669));
      }
      case 'entrevistas': {
        final cnt = _entrevistasCache.length;
        return _dot('$cnt entrevista${cnt == 1 ? '' : 's'}', const Color(0xFF7C3AED));
      }
      case 'autores':
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _svc.obtenerAutores(widget.empresaId),
          builder: (_, s) => _dot('${s.data?.length ?? 0} autores registrados',
              const Color(0xFF0EA5E9)));
      case 'campanas':
        return _dot('Campañas de email marketing', const Color(0xFFE11D48));
      case 'analytics':
        return _dot('Ver tráfico y métricas', const Color(0xFF0EA5E9));
      case 'config':
        return _dot('Personalizar ajustes', const Color(0xFF10B981));
      case '__add__':
        return _dot('Toca para añadir una sección', const Color(0xFF94A3B8));
      default:
        if (mod.id.startsWith('wsc_')) {
          final seccionId = mod.id.substring(4);
          _WebSeccionDin? sec;
          for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
          if (sec == null) return const SizedBox.shrink();
          if (sec.tipo == 'blog') {
            return StreamBuilder<List<EntradaBlog>>(
              stream: _svc.obtenerBlogSeccion(widget.empresaId, seccionId),
              builder: (_, s) => _dot(
                '${s.data?.length ?? 0} entrada${(s.data?.length ?? 0) == 1 ? '' : 's'}',
                const Color(0xFF2563EB)));
          } else {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _svc.obtenerCatalogoWebSeccion(widget.empresaId, seccionId),
              builder: (_, s) => _dot(
                '${s.data?.where((i) => i['activo'] == true).length ?? 0} elementos visibles',
                const Color(0xFF6B1E2A)));
          }
        }
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
    if (mod.id == '__add__') {
      _mostrarDialogoSeccion(context);
      return;
    }
    _setModuloActivo(mod.id);
  }

  // ── Card especial "+" ──────────────────────────────────────────────────────

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: () => _mostrarDialogoSeccion(context),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_rounded, size: 28, color: _kTextSec),
          ),
          const SizedBox(height: 10),
          Text('Nueva sección',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
          const SizedBox(height: 4),
          Text('data-fluix-Nombre-Tipo',
              style: TextStyle(fontSize: 10, color: _kTextSec.withValues(alpha: 0.5),
                  fontFamily: 'monospace')),
        ]),
      ),
    );
  }

  Widget _previewAdd() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_circle_outline_rounded, size: 32, color: _kTextSec.withValues(alpha: 0.3)),
      const SizedBox(height: 8),
      Text('Añadir sección web', style: TextStyle(fontSize: 11, color: _kTextSec.withValues(alpha: 0.4))),
    ]));
  }

  Widget _previewCatalogoScoped(Color c, String seccionId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerCatalogoWebSeccion(widget.empresaId, seccionId),
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

  // ── Diálogo crear/editar sección ───────────────────────────────────────────

  void _mostrarDialogoSeccion(BuildContext context, {_WebSeccionDin? existente}) {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    String tipo = existente?.tipo ?? 'blog';
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _kSurf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existente == null ? 'Nueva sección web' : 'Editar sección',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Info formato
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
              ),
              child: Text(
                'En tu HTML: data-fluix-${nombreCtrl.text.isNotEmpty ? nombreCtrl.text : "Nombre"}-${tipo == 'blog' ? 'Blog' : 'Catalogo'}',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace',
                    color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              onChanged: (_) => setDlg(() {}),
              style: TextStyle(fontSize: 13, color: _kText),
              decoration: InputDecoration(
                labelText: 'Nombre de la sección',
                hintText: 'Ej: Agenda, Libros, Revista…',
                hintStyle: TextStyle(color: _kTextSec),
                labelStyle: TextStyle(color: _kTextSec),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tipo,
              decoration: InputDecoration(
                labelText: 'Tipo de funcionamiento',
                labelStyle: TextStyle(color: _kTextSec),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              dropdownColor: _kSurf,
              style: TextStyle(fontSize: 13, color: _kText),
              items: const [
                DropdownMenuItem(value: 'blog',     child: Text('Blog — artículos y entradas')),
                DropdownMenuItem(value: 'catalogo', child: Text('Catálogo — productos e ítems')),
              ],
              onChanged: (v) { if (v != null) setDlg(() => tipo = v); },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: _kTextSec)),
            ),
            FilledButton(
              onPressed: guardando ? null : () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                setDlg(() => guardando = true);
                try {
                  final col = FirebaseFirestore.instance
                      .collection('empresas').doc(widget.empresaId)
                      .collection('web_secciones');
                  if (existente == null) {
                    final orden = _webSecciones.length;
                    await col.add({ 'nombre': nombre, 'tipo': tipo, 'orden': orden, 'activa': true });
                  } else {
                    await col.doc(existente.id).update({ 'nombre': nombre, 'tipo': tipo });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  setDlg(() => guardando = false);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: tipo == 'blog' ? const Color(0xFF2563EB) : const Color(0xFF6B1E2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: guardando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(existente == null ? 'Crear' : 'Guardar',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesSeccion(BuildContext context, _WebMod mod) {
    final seccionId = mod.id.substring(4);
    _WebSeccionDin? sec;
    for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
    if (sec == null) return;
    final seccion = sec;

    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: mod.color),
            title: Text('Editar "${seccion.nombre}"', style: TextStyle(color: _kText)),
            onTap: () {
              Navigator.pop(context);
              _mostrarDialogoSeccion(context, existente: seccion);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: const Text('Eliminar sección', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: _kSurf,
                  title: Text('Eliminar "${seccion.nombre}"', style: TextStyle(color: _kText, fontSize: 15)),
                  content: Text('Se eliminará la sección del hub. Los datos (entradas/ítems) no se borran.',
                      style: TextStyle(color: _kTextSec, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar', style: TextStyle(color: _kTextSec))),
                    FilledButton(onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Eliminar')),
                  ],
                ),
              );
              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('empresas').doc(widget.empresaId)
                    .collection('web_secciones').doc(seccionId).delete();
              }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
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

// ─── Modelo de módulo web ─────────────────────────────────────────────────────

// ── Sección web dinámica (leída de Firestore web_secciones) ─────────────────
// Creada via data-fluix-{Nombre}-{Tipo} en el HTML del cliente
class _WebSeccionDin {
  final String id;
  final String nombre;
  final String tipo; // 'blog' | 'catalogo'
  final int orden;

  const _WebSeccionDin({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.orden,
  });

  factory _WebSeccionDin.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return _WebSeccionDin(
      id:     doc.id,
      nombre: d['nombre'] as String? ?? 'Sección',
      tipo:   (d['tipo'] as String? ?? 'blog').toLowerCase(),
      orden:  (d['orden'] as num?)?.toInt() ?? 0,
    );
  }

  static const _colorBlog     = Color(0xFF2563EB);
  static const _colorCatalogo = Color(0xFF6B1E2A);

  Color get color => tipo == 'blog' ? _colorBlog : _colorCatalogo;
  IconData get icono => tipo == 'blog' ? Icons.article_rounded : Icons.menu_book_rounded;

  String get _desc => tipo == 'blog'
      ? 'Entradas y artículos\nde $nombre'
      : 'Catálogo de\n$nombre';

  _WebMod toWebMod() => _WebMod('wsc_$id', nombre, _desc, icono, color);
}

class _WebMod {
  final String id;
  final String titulo;
  final String desc;
  final IconData icono;
  final Color color;
  const _WebMod(this.id, this.titulo, this.desc, this.icono, this.color);
}
