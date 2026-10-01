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
import 'tab_carta_web.dart';
import 'tab_menu_semanal_web.dart';
import 'tab_reservas_web.dart';
import 'tab_seleccion_nazari.dart';
import 'tab_archivo_historico.dart';
import 'pantalla_editor_blog.dart';
import 'pantalla_editor_word.dart';
import 'tab_analytics_web.dart';
import 'pantalla_items_seccion.dart';
import '../../../core/widgets/fluix_app_bar.dart';

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
  final bool noScaffold;

  const PantallaContenidoWeb({
    super.key,
    required this.empresaId,
    this.onSubModuloChanged,
    this.volverAlHub,
    this.noScaffold = false,
  });

  @override
  State<PantallaContenidoWeb> createState() => _PantallaContenidoWebState();
}

class _PantallaContenidoWebState extends State<PantallaContenidoWeb>
    with SafeStreamMixin {
  final ContenidoWebService _svc = ContenidoWebService();
  final ContactoWebService _contactoSvc = ContactoWebService();

  String? _moduloActivo;
  String? _moduloActivoNombre;
  int _lastVolverSignal = 0;
  bool _isDark = false;
  final _hubPageCtrl = PageController();
  int _hubPage = 0;

  List<_WebSeccionDin> _webSecciones = [];
  StreamSubscription<QuerySnapshot>? _seccionesSub;

  // Cache del blog compartido por todas las fichas del hub.
  List<EntradaBlog> _blogCache = [];
  StreamSubscription<List<EntradaBlog>>? _blogSub;
  List<EntradaBlog> _noticiasCache    = [];
  List<EntradaBlog> _entrevistasCache = [];
  StreamSubscription<List<EntradaBlog>>? _noticiasSub;
  StreamSubscription<List<EntradaBlog>>? _entrevistasSub;

  Set<String> _modulosWeb = {};

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
    _svc.detectarModulosWeb(widget.empresaId).then((m) {
      if (mounted) setState(() => _modulosWeb = m);
      if (m.isNotEmpty) _autoSeedModulosDetectados(m);
    });
    widget.volverAlHub?.addListener(_onVolverAlHub);
    _hubPageCtrl.addListener(() {
      if (!mounted) return;
      final p = _hubPageCtrl.page?.round() ?? 0;
      if (p != _hubPage) setState(() => _hubPage = p);
    });
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
    _autoSeedSecciones();
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

  /// Añade galería y menú semanal si no existen (idempotente para cuentas antiguas).
  Future<void> _asegurarSeccionesBase(
      CollectionReference<Map<String, dynamic>> col) async {
    const necesarias = [
      {'tipo': 'galeria',      'nombre': 'Galería',       'orden': 20},
      {'tipo': 'menu_semanal', 'nombre': 'Menú Semanal',  'orden': 21},
    ];
    final snap = await col.get();
    final tiposExistentes = snap.docs
        .map((d) => (d.data()['tipo'] as String? ?? '').toLowerCase())
        .toSet();
    final batch = FirebaseFirestore.instance.batch();
    bool cambios = false;
    for (final s in necesarias) {
      if (!tiposExistentes.contains(s['tipo'])) {
        batch.set(col.doc(), {...s, 'activa': true});
        cambios = true;
      }
    }
    if (cambios) await batch.commit();
  }

  // Mapeo módulo detectado → tipo de sección + nombre para mostrar
  static const _moduloASeed = <String, Map<String, String>>{
    'galeria':      {'tipo': 'galeria',      'nombre': 'Galería'},
    'menu-semanal': {'tipo': 'menu_semanal', 'nombre': 'Menú Semanal'},
    'carta':        {'tipo': 'carta',        'nombre': 'Carta'},
    'reservas':     {'tipo': 'reservas',     'nombre': 'Reservas'},
    'contacto':     {'tipo': 'contacto',     'nombre': 'Contacto'},
  };

  /// Cuando la detección de la web devuelve módulos:
  /// 1. Añade secciones que falten
  /// 2. Marca como activa:false secciones cuyo tipo no aparece en la web
  /// 3. Reactiva secciones que sí aparecen (por si las habían desactivado a mano)
  Future<void> _autoSeedModulosDetectados(Set<String> modulos) async {
    if (widget.empresaId == _kNazariId) return;
    if (modulos.isEmpty) return;
    try {
      final col = FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('web_secciones');
      final snap = await col.get();

      // Tipos detectados normalizados (menu-semanal → menu_semanal)
      final tiposDetectados = modulos
          .map((m) => m.replaceAll('-', '_'))
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      bool cambios = false;

      // 1. Marcar activa/inactiva según detección
      for (final doc in snap.docs) {
        final tipo = (doc.data()['tipo'] as String? ?? '').toLowerCase();
        final activaActual = doc.data()['activa'] as bool? ?? true;
        // Tipos fijos que siempre están activos (Nazarí, PDFs, etc.)
        const siempre = {'seleccion', 'plantillas_pdf', 'analytics', 'config'};
        if (siempre.contains(tipo)) continue;
        final debeActiva = tiposDetectados.contains(tipo);
        if (activaActual != debeActiva) {
          batch.update(doc.reference, {'activa': debeActiva});
          cambios = true;
        }
      }

      // 2. Añadir secciones que falten
      final tiposExistentes = snap.docs
          .map((d) => (d.data()['tipo'] as String? ?? '').toLowerCase())
          .toSet();
      for (final modulo in modulos) {
        final seed = _moduloASeed[modulo];
        if (seed == null) continue;
        final tipo = seed['tipo']!;
        if (tiposExistentes.contains(tipo)) continue;
        batch.set(col.doc(), {
          'nombre': seed['nombre'],
          'tipo':   tipo,
          'orden':  snap.docs.length,
          'activa': true,
        });
        cambios = true;
      }

      if (cambios) await batch.commit();
    } catch (_) {}
  }

  Future<void> _autoSeedSecciones() async {
    try {
      final col = FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('web_secciones');

      if (widget.empresaId == _kNazariId) {
        await _migrarSeccionesNazari(col);
        return;
      }
      if (widget.empresaId == _kJuanitaId) {
        await _migrarSeccionesJuanita(col);
        return;
      }

      // Asegurar que galería y menú semanal existen para cualquier empresa
      await _asegurarSeccionesBase(col);

      // Resto de empresas: solo sembrar el set completo si la colección está vacía
      final snap = await col.limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      const seed = [
        {'nombre': 'Catálogo',     'tipo': 'catalogo',    'orden': 0, 'activa': true},
        {'nombre': 'Blog',         'tipo': 'blog',         'orden': 1, 'activa': true},
        {'nombre': 'Carta',        'tipo': 'carta',        'orden': 2, 'activa': true},
        {'nombre': 'Menú Semanal', 'tipo': 'menu_semanal', 'orden': 3, 'activa': true},
        {'nombre': 'Reservas',     'tipo': 'reservas',     'orden': 4, 'activa': true},
        {'nombre': 'Agenda',       'tipo': 'agenda',       'orden': 5, 'activa': true},
        {'nombre': 'Noticias',     'tipo': 'noticias',     'orden': 6, 'activa': true},
        {'nombre': 'Entrevistas',  'tipo': 'entrevistas',  'orden': 7, 'activa': true},
        {'nombre': 'Autores',      'tipo': 'autores',      'orden': 8, 'activa': true},
      ];
      for (final s in seed) { batch.set(col.doc(), s); }
      await batch.commit();
    } catch (_) {}
  }

  /// Para Nazarí: migración idempotente que corrige `tipo` en docs existentes
  /// y añade secciones que falten. Corre en cada arranque de la pantalla.
  Future<void> _migrarSeccionesNazari(
      CollectionReference<Map<String, dynamic>> col) async {
    const esperadas = [
      {'nombre': 'Catálogo',    'tipo': 'catalogo',      'orden': 0},
      {'nombre': 'Agenda',      'tipo': 'agenda',         'orden': 1},
      {'nombre': 'Noticias',    'tipo': 'noticias',       'orden': 2},
      {'nombre': 'Entrevistas', 'tipo': 'entrevistas',    'orden': 3},
      {'nombre': 'Autores',     'tipo': 'autores',        'orden': 4},
      {'nombre': 'Selección',   'tipo': 'seleccion',      'orden': 5},
      {'nombre': 'PDF',         'tipo': 'plantillas_pdf', 'orden': 6},
    ];

    final snap    = await col.get();
    final batch   = FirebaseFirestore.instance.batch();
    bool  cambios = false;

    // Nombres normalizados permitidos en Nazarí
    final permitidos = esperadas
        .map((e) => _normNombre(e['nombre'] as String))
        .toSet();

    // 1. Corregir tipos y añadir secciones faltantes
    for (final exp in esperadas) {
      final nombreEsp = _normNombre(exp['nombre'] as String);
      final tipoEsp   = (exp['tipo'] as String).toLowerCase();

      QueryDocumentSnapshot<Map<String, dynamic>>? existente;
      for (final d in snap.docs) {
        if (_normNombre(d.data()['nombre'] as String? ?? '') == nombreEsp) {
          existente = d;
          break;
        }
      }

      if (existente == null) {
        batch.set(col.doc(), {...exp, 'activa': true});
        cambios = true;
      } else {
        final tipoActual = (existente.data()['tipo'] as String? ?? '').toLowerCase();
        if (tipoActual != tipoEsp) {
          batch.update(existente.reference, {'tipo': tipoEsp});
          cambios = true;
        }
      }
    }

    // 2. Eliminar secciones no permitidas (ej: "Blog" que no existe en Nazarí)
    for (final d in snap.docs) {
      final nombre = _normNombre(d.data()['nombre'] as String? ?? '');
      if (!permitidos.contains(nombre)) {
        batch.delete(d.reference);
        cambios = true;
      }
    }

    if (cambios) await batch.commit();
  }

  /// Para Juanita Taberna: solo carta, reservas, galería, menú semanal, contacto
  Future<void> _migrarSeccionesJuanita(
      CollectionReference<Map<String, dynamic>> col) async {
    const esperadas = [
      {'nombre': 'Carta',        'tipo': 'carta',        'orden': 0},
      {'nombre': 'Reservas',     'tipo': 'reservas',     'orden': 1},
      {'nombre': 'Galería',      'tipo': 'galeria',      'orden': 2},
      {'nombre': 'Menú Semanal', 'tipo': 'menu_semanal', 'orden': 3},
    ];

    final snap   = await col.get();
    final batch  = FirebaseFirestore.instance.batch();
    bool cambios = false;

    final permitidos = esperadas
        .map((e) => _normNombre(e['nombre'] as String))
        .toSet();

    for (final exp in esperadas) {
      final nombreEsp = _normNombre(exp['nombre'] as String);
      final tipoEsp   = (exp['tipo'] as String).toLowerCase();
      QueryDocumentSnapshot<Map<String, dynamic>>? existente;
      for (final d in snap.docs) {
        if (_normNombre(d.data()['nombre'] as String? ?? '') == nombreEsp) {
          existente = d; break;
        }
      }
      if (existente == null) {
        batch.set(col.doc(), {...exp, 'activa': true});
        cambios = true;
      } else {
        final tipoActual = (existente.data()['tipo'] as String? ?? '').toLowerCase();
        if (tipoActual != tipoEsp) {
          batch.update(existente.reference, {'tipo': tipoEsp});
          cambios = true;
        }
        // Reactivar si estaba desactivada
        if (existente.data()['activa'] == false) {
          batch.update(existente.reference, {'activa': true});
          cambios = true;
        }
      }
    }

    // Eliminar secciones no permitidas (Blog, Agenda, Noticias, Entrevistas, etc.)
    for (final d in snap.docs) {
      final nombre = _normNombre(d.data()['nombre'] as String? ?? '');
      if (!permitidos.contains(nombre)) {
        batch.delete(d.reference);
        cambios = true;
      }
    }

    if (cambios) await batch.commit();
  }

  static String _normNombre(String s) => s
      .toLowerCase().trim()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u');

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
    _hubPageCtrl.dispose();
    _seccionesSub?.cancel();
    _blogSub?.cancel();
    _noticiasSub?.cancel();
    _entrevistasSub?.cancel();
    AppSettings.darkMode.removeListener(_onDark);
    widget.volverAlHub?.removeListener(_onVolverAlHub);
    super.dispose();
  }

  /// Abre directamente la sección de tipo galería del módulo web (Secciones).
  /// Si no existe, muestra el editor de secciones para que el usuario la cree.
  Widget _buildEditorSeccionGaleria() {
    return StreamBuilder<List<SeccionWeb>>(
      stream: _svc.obtenerSecciones(widget.empresaId),
      builder: (ctx, snap) {
        final secciones = snap.data ?? [];
        final galeria = secciones.cast<SeccionWeb?>().firstWhere(
          (s) => s?.tipo == TipoSeccion.galeria, orElse: () => null);
        if (galeria != null) {
          return PantallaEditorSeccion(
            empresaId: widget.empresaId,
            seccion: galeria,
            svc: _svc,
            noScaffold: true,
            onGuardado: () {},
            modulosWeb: _modulosWeb,
          );
        }
        // No existe sección galería → ofrecer crearla
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.photo_library_outlined, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('No hay sección de galería',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          const Text('Créala desde la pestaña Secciones',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _moduloActivo = 'secciones'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ir a Secciones'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]));
      },
    );
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

  String _subVistaTitulo(({
    String tipo, SeccionWeb? seccion, EntradaBlog? entrada,
    List<CategoriaBlog> categorias, String paginaInicial,
    Map<String, dynamic>? itemCatalogo,
  }) sv) => switch (sv.tipo) {
    'editar_seccion'    => sv.seccion != null ? 'Editar sección' : 'Nueva sección',
    'items_seccion'     => sv.seccion?.nombre ?? 'Items',
    'eventos_seccion'   => sv.seccion?.nombre ?? 'Eventos',
    'editar_blog'       => sv.entrada != null ? 'Editar entrada' : 'Nueva entrada',
    'editar_blog_clasico' => 'Editor clásico',
    'editar_catalogo'   => sv.itemCatalogo != null ? 'Editar producto' : 'Nuevo producto',
    _                   => 'Editar',
  };

  void _cerrarSubVista() {
    setState(() => _subVista = null);
    widget.onSubModuloChanged?.call(_moduloActivoNombre ?? _moduloActivo);
  }

  static const _kNazariId   = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
  static const _kJuanitaId  = 'AP6JV9bxONgibrjaKzvrrk4xvWM2';

  // Módulos fijos (siempre presentes, sin importar el HTML de la empresa)
  static const _modsFixed = [
    _WebMod('mensajes',  'Mensajes',      '',                                                     Icons.chat_bubble_rounded,  Color(0xFF059669)),
    _WebMod('analytics', 'Analytics',     'Tráfico, visitas y estadísticas\nde tu sitio web',    Icons.bar_chart_rounded,    Color(0xFF0EA5E9)),
    _WebMod('campanas',  'Email',          'Crea y envía campañas de\nemail marketing',            Icons.campaign_rounded,     Color(0xFFE11D48)),
    _WebMod('config',    'Configuración',  'Personaliza tu sitio web y\nsus ajustes',             Icons.settings_rounded,     Color(0xFF7C3AED)),
  ];

  // Filtra secciones: solo muestra las marcadas como activa: true en Firestore
  List<_WebSeccionDin> get _seccionesFiltradas =>
      _webSecciones.where((s) => s.activa).toList();

  // Módulos leídos directamente de web_secciones + utilidades fijas al final
  List<_WebMod> get _mods => [
    ..._seccionesFiltradas.map((s) => s.toWebMod()),
    ..._modsFixed,
  ];

  String get _appBarTitulo {
    if (_subVista != null) return _subVistaTitulo(_subVista!);
    if (_moduloActivo != null) return _moduloActivoNombre ?? 'Contenido Web';
    return 'Contenido Web';
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (DemoCuentaService().esDemo(email)) return _buildDemoScreen(context);

    final hub = ColoredBox(
      key: const ValueKey('hub'),
      color: _kBg,
      child: _buildHubGrid(),
    );

    final modulo = _moduloActivo != null
        ? KeyedSubtree(key: ValueKey(_moduloActivo), child: _buildVistaModulo())
        : null;

    final child = AnimatedSwitcher(
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

    if (widget.noScaffold) return child;

    return Scaffold(
      appBar: FluixAppBar(
        titulo: _appBarTitulo,
        showLeading: true,
        onLeadingPressed: () {
          if (_subVista != null) {
            _cerrarSubVista();
          } else if (_moduloActivo != null) {
            _setModuloActivo(null);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      body: child,
    );
  }

  // ── Hub paginado — N fichas por página con flechas y dots ─────────────────

  // ── Lista de módulos para móvil (<600px) — sin overflow, sin área negra ─────
  Widget _buildHubListaMobile(List<_WebMod> mods) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: mods.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i < mods.length) return _buildModuloTileMobile(mods[i]);
        // Tarjeta "añadir sección"
        return GestureDetector(
          onTap: () => _mostrarDialogoSeccion(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, style: BorderStyle.solid),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Color(0xFF64748B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Añadir sección',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: _kText)),
                const SizedBox(height: 2),
                Text('Crea una nueva sección personalizada',
                    style: TextStyle(fontSize: 11, color: _kTextSec)),
              ])),
              Icon(Icons.chevron_right_rounded, color: _kTextSec),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildModuloTileMobile(_WebMod mod) {
    return GestureDetector(
      onTap: () => _abrirModulo(mod),
      onLongPress: mod.id.startsWith('wsc_')
          ? () => _mostrarOpcionesSeccion(context, mod)
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: mod.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(mod.icono, color: mod.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(mod.titulo,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _kText)),
            if (mod.desc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(mod.desc,
                  style: TextStyle(fontSize: 11, color: _kTextSec, height: 1.3),
                  maxLines: 2),
            ],
            const SizedBox(height: 6),
            _buildStatRow(mod),
          ])),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _abrirModulo(mod),
            style: FilledButton.styleFrom(
              backgroundColor: mod.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Abrir'),
          ),
        ]),
      ),
    );
  }

  Widget _buildHubGrid() {
    final mods = _mods;
    final totalItems = mods.length + 1; // +1 tarjeta "añadir"

    return LayoutBuilder(builder: (ctx, constraints) {
      // MÓVIL (<600px): lista vertical scrollable — sin overflows, sin área negra
      if (constraints.maxWidth < 600) {
        return _buildHubListaMobile(mods);
      }

      // DESKTOP / TABLET ANCHA: grid paginado con previews
      // 3 columnas × 2 filas = 6 fichas por página en pantalla ancha
      final cols = constraints.maxWidth >= 700 ? 3 : 2;
      const rows = 2;
      final perPage = cols * rows;
      final totalPages = (totalItems / perPage).ceil();
      final page = _hubPage.clamp(0, totalPages - 1);

      const gap = 10.0;
      const arrowW = 40.0;
      final cardW = (constraints.maxWidth - arrowW * 2 - gap * (cols - 1)) / cols;
      final cardH = (cardW * 0.88).clamp(160.0, 300.0);
      final gridH = cardH * rows + gap * (rows - 1);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: gridH,
              child: Stack(alignment: Alignment.center, children: [
                PageView.builder(
                  controller: _hubPageCtrl,
                  itemCount: totalPages,
                  itemBuilder: (_, pageIdx) {
                    final start = pageIdx * perPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: arrowW),
                      child: Column(
                        children: List.generate(rows, (r) {
                          return Expanded(child: Padding(
                            padding: EdgeInsets.only(bottom: r < rows - 1 ? gap : 0),
                            child: Row(
                              children: List.generate(cols, (c) {
                                final idx = start + r * cols + c;
                                if (idx >= totalItems) {
                                  return Expanded(child: Padding(
                                    padding: EdgeInsets.only(right: c < cols - 1 ? gap : 0),
                                    child: const SizedBox.shrink(),
                                  ));
                                }
                                return Expanded(child: Padding(
                                  padding: EdgeInsets.only(right: c < cols - 1 ? gap : 0),
                                  child: idx < mods.length
                                      ? _buildModuloCard(mods[idx])
                                      : _buildAddCard(),
                                ));
                              }),
                            ),
                          ));
                        }),
                      ),
                    );
                  },
                ),
                if (page > 0) Positioned(
                  left: 0,
                  child: _buildHubNavBtn(isNext: false),
                ),
                if (page < totalPages - 1) Positioned(
                  right: 0,
                  child: _buildHubNavBtn(isNext: true),
                ),
              ]),
            ),
          ),
          if (totalPages > 1) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) => GestureDetector(
                onTap: () => _hubPageCtrl.animateToPage(i,
                    duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: i == page
                        ? (_isDark ? Colors.white70 : const Color(0xFF475569))
                        : (_isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHubNavBtn({required bool isNext}) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => isNext
          ? _hubPageCtrl.nextPage(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
          : _hubPageCtrl.previousPage(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      child: Container(
        width: 34, height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.08),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(
          isNext ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          color: _kTextSec, size: 20,
        ),
      ),
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
          modulosWeb: _modulosWeb,
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

    return ColoredBox(
      color: _kBg,
      child: Column(children: [
        Expanded(child: content),
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
      // 'galeria' — se gestiona desde Secciones (tipo galeria) y se sincroniza
      // automáticamente a galeria_web al guardar. Tab separado eliminado.
      case 'galeria':    return _buildEditorSeccionGaleria();
      case 'analytics':  return TabAnalyticsWeb(empresaId: widget.empresaId);
      case 'config':     return TabConfigWeb(empresaId: widget.empresaId, svc: _svc);
      case 'seleccion':       return TabSeleccionNazari(empresaId: widget.empresaId);
      case 'plantillas_pdf':  return _TabPlantillasPdfNazari(empresaId: widget.empresaId, color: mod.color);
      default:
        if (mod.id.startsWith('wsc_')) {
          final seccionId = mod.id.substring(4);
          _WebSeccionDin? sec;
          for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
          if (sec == null) return const Center(child: Text('Sección no encontrada'));
          switch (sec.tipo) {
            case 'blog':
              return _BlogSplitView(
                empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
                seccionId: seccionId,
                onAbrirEditor: (entrada, cats) => _abrirSubVista(
                  tipo: 'editar_blog', entrada: entrada, categorias: cats));
            case 'noticias':
              return _BlogSplitView(
                empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
                filtroTipoFijo: 'noticia', titulo: sec.nombre,
                onAbrirEditor: (entrada, cats) => _abrirSubVista(
                  tipo: 'editar_blog', entrada: entrada, categorias: cats));
            case 'entrevistas':
              return _BlogSplitView(
                empresaId: widget.empresaId, svc: _svc, isDark: _isDark,
                filtroTipoFijo: 'entrevista', titulo: sec.nombre,
                onAbrirEditor: (entrada, cats) => _abrirSubVista(
                  tipo: 'editar_blog', entrada: entrada, categorias: cats));
            case 'agenda':
              return TabEventosWeb(
                empresaId: widget.empresaId, svc: _svc,
                onAbrirEditorWord: (entrada, cats) => _abrirSubVista(
                  tipo: 'editar_blog', entrada: entrada,
                  categorias: cats.cast<CategoriaBlog>()));
            case 'autores':
              return _AutoresNazariTab(
                empresaId: widget.empresaId, svc: _svc, color: mod.color);
            case 'carta':
              return TabCartaWeb(
                empresaId: widget.empresaId, svc: _svc, color: mod.color,
                seccionId: seccionId);
            case 'menu_semanal':
              return TabMenuSemanalWeb(
                empresaId: widget.empresaId, svc: _svc, color: mod.color);
            case 'reservas':
              return TabReservasWeb(
                empresaId: widget.empresaId, svc: _svc, color: mod.color);
            case 'catalogo':
              return TabCatalogoWeb(
                empresaId: widget.empresaId, svc: _svc, color: mod.color,
                onAbrirEditor: (item) => _abrirSubVista(
                  tipo: 'editar_catalogo', itemCatalogo: item));
            case 'seleccion':
              return TabSeleccionNazari(empresaId: widget.empresaId);
            case 'plantillas_pdf':
              return _TabPlantillasPdfNazari(
                empresaId: widget.empresaId, color: mod.color);
            default:
              return TabCatalogoWeb(
                empresaId: widget.empresaId, svc: _svc, color: mod.color,
                seccionId: seccionId,
                onAbrirEditor: (item) => _abrirSubVista(
                  tipo: 'editar_catalogo', itemCatalogo: item));
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
      case 'config':         return _previewConfig();
      case 'seleccion':      return _previewSeleccion(mod.color);
      case 'plantillas_pdf': return _previewPlantillasPdf(mod.color);
      case '__add__':        return _previewAdd();
      default:
        if (mod.id.startsWith('wsc_')) {
          final seccionId = mod.id.substring(4);
          _WebSeccionDin? sec;
          for (final s in _webSecciones) { if (s.id == seccionId) { sec = s; break; } }
          switch (sec?.tipo) {
            case 'blog':        return _previewBlog(mod.color);
            case 'noticias':    return _previewBlogPorTipo(mod.color, 'noticia');
            case 'entrevistas': return _previewBlogPorTipo(mod.color, 'entrevista');
            case 'agenda':      return _previewAgenda(mod.color);
            case 'autores':     return _previewAutores(mod.color);
            case 'catalogo':    return _previewCatalogo(mod.color);
            case 'carta':         return _previewCarta(mod.color);
            case 'menu_semanal':  return _previewMenuSemanal(mod.color);
            case 'reservas':      return _previewReservas(mod.color);
            case 'seleccion':   return _previewSeleccion(mod.color);
            case 'plantillas_pdf': return _previewPlantillasPdf(mod.color);
            default:            return _previewCatalogoScoped(mod.color, seccionId);
          }
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
        return ClipRect(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...muestra.map((e) {
              final dia = e.fecha.day.toString().padLeft(2, '0');
              final mes = meses[e.fecha.month - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 34, height: 34,
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
        ));
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

  Widget _previewCarta(Color c) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerCartaWeb(widget.empresaId),
      builder: (_, snap) {
        final items = snap.data ?? [];
        final cats = items.map((i) => i['categoria'] as String? ?? '').toSet().length;
        return _previewContador(
          label:    'Platos en la carta',
          valor:    '${items.length}',
          sublabel: '$cats categoría${cats == 1 ? '' : 's'}',
          icon:     Icons.restaurant_menu_rounded,
          color:    c,
        );
      },
    );
  }

  Widget _previewMenuSemanal(Color c) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _svc.obtenerMenuSemanal(widget.empresaId),
      builder: (_, snap) {
        final dias = snap.data ?? [];
        final activos = dias.where((d) => d['activo'] as bool? ?? true).length;
        return _previewContador(
          label:    'Días con menú',
          valor:    '${dias.length}',
          sublabel: '$activos activos esta semana',
          icon:     Icons.restaurant_rounded,
          color:    c,
        );
      },
    );
  }

  Widget _previewReservas(Color c) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('reservas')
          .orderBy('fecha_hora', descending: false)
          .limit(5)
          .snapshots(),
      builder: (_, snap) {
        final docs  = snap.data?.docs ?? [];
        final pend  = docs.where((d) {
          final e = ((d.data() as Map<String, dynamic>)['estado'] as String? ?? '').toUpperCase();
          return e == 'PENDIENTE';
        }).length;
        return _previewContador(
          label:    'Reservas recientes',
          valor:    '${docs.length}',
          sublabel: '$pend pendiente${pend == 1 ? '' : 's'}',
          icon:     Icons.event_seat_rounded,
          color:    c,
        );
      },
    );
  }

  Widget _previewSeleccion(Color c) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('seleccion_nazari').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.stars_rounded, size: 32, color: c.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('Sin libros en la selección',
                style: TextStyle(fontSize: 11, color: _kTextSec.withValues(alpha: 0.6))),
          ]));
        }
        return ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _previewTitle('Selección editorial — ${docs.length} libro${docs.length == 1 ? '' : 's'}'),
            ...docs.take(4).map((d) {
              final data = d.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 28, height: 40,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Icon(Icons.menu_book_rounded, size: 14, color: c)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    data['titulo'] ?? data['nombre'] ?? '',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              );
            }),
          ]);
      });
  }

  Widget _previewPlantillasPdf(Color c) {
    const opciones = ['Pedidos web', 'Facturas', 'Albaranes', 'Catálogo PDF'];
    return ListView(padding: EdgeInsets.zero, children: [
      _previewTitle('Documentos disponibles'),
      ...opciones.map((op) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0), width: 0.5))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            Icon(Icons.picture_as_pdf_rounded, size: 14, color: c),
            const SizedBox(width: 8),
            Text(op, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
            const Spacer(),
            Icon(Icons.download_rounded, size: 13, color: const Color(0xFFCBD5E1)),
          ]),
        ),
      )),
    ]);
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
      case 'seleccion':
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId)
              .collection('seleccion_nazari').snapshots(),
          builder: (_, s) {
            final n = s.data?.docs.length ?? 0;
            return _dot('$n libro${n == 1 ? '' : 's'} en la selección', const Color(0xFF6B1E2A));
          });
      case 'plantillas_pdf':
        return _dot('Genera facturas y documentos PDF', const Color(0xFFDC2626));
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
          switch (sec.tipo) {
            case 'blog':
              return StreamBuilder<List<EntradaBlog>>(
                stream: _svc.obtenerBlogSeccion(widget.empresaId, seccionId),
                builder: (_, s) => _dot(
                  '${s.data?.length ?? 0} entrada${(s.data?.length ?? 0) == 1 ? '' : 's'}',
                  const Color(0xFF2563EB)));
            case 'noticias': {
              final cnt = _noticiasCache.length;
              return _dot('$cnt noticia${cnt == 1 ? '' : 's'} publicada${cnt == 1 ? '' : 's'}',
                  const Color(0xFF059669));
            }
            case 'entrevistas': {
              final cnt = _entrevistasCache.length;
              return _dot('$cnt entrevista${cnt == 1 ? '' : 's'}', const Color(0xFF7C3AED));
            }
            case 'agenda':
              return _dot('Gestionar presentaciones y ferias', const Color(0xFF1E4D6B));
            case 'autores':
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _svc.obtenerAutores(widget.empresaId),
                builder: (_, s) => _dot('${s.data?.length ?? 0} autores registrados',
                    const Color(0xFF0EA5E9)));
            case 'carta':
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _svc.obtenerCartaWeb(widget.empresaId),
                builder: (_, s) {
                  final total = s.data?.length ?? 0;
                  final disp  = s.data?.where((i) => i['disponible'] != false).length ?? 0;
                  return _dot('$total platos · $disp disponibles',
                      const Color(0xFFE65100));
                });
            case 'menu_semanal':
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _svc.obtenerMenuSemanal(widget.empresaId),
                builder: (_, s) {
                  final total   = s.data?.length ?? 0;
                  final activos = s.data?.where((d) => d['activo'] as bool? ?? true).length ?? 0;
                  return _dot('$total días · $activos activos esta semana',
                      const Color(0xFF0F766E));
                });
            case 'reservas':
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('empresas').doc(widget.empresaId)
                    .collection('reservas')
                    .where('estado', isEqualTo: 'PENDIENTE')
                    .snapshots(),
                builder: (_, s) {
                  final n = s.data?.docs.length ?? 0;
                  return _dot('$n reserva${n == 1 ? '' : 's'} pendiente${n == 1 ? '' : 's'}',
                      n > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
                });
            case 'seleccion':
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('empresas').doc(widget.empresaId)
                    .collection('seleccion_nazari').snapshots(),
                builder: (_, s) {
                  final n = s.data?.docs.length ?? 0;
                  return _dot('$n libro${n == 1 ? '' : 's'} en la selección',
                      const Color(0xFF6B1E2A));
                });
            case 'plantillas_pdf':
              return _dot('Genera facturas y documentos PDF', const Color(0xFFDC2626));
            default:
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
    // Para secciones dinámicas (wsc_*) pasar el nombre legible al breadcrumb
    final nombre = mod.id.startsWith('wsc_') ? mod.titulo : mod.id;
    setState(() { _moduloActivo = mod.id; _moduloActivoNombre = nombre; });
    widget.onSubModuloChanged?.call(nombre);
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

  static String _tipoAttrLabel(String tipo) {
    switch (tipo) {
      case 'blog':         return 'Blog';
      case 'catalogo':     return 'Catalogo';
      case 'agenda':       return 'Agenda';
      case 'noticias':     return 'Noticias';
      case 'entrevistas':  return 'Entrevistas';
      case 'autores':      return 'Autores';
      case 'carta':        return 'Carta';
      case 'menu_semanal': return 'MenuSemanal';
      case 'reservas':     return 'Reservas';
      default:             return tipo;
    }
  }

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
                'En tu HTML: data-fluix-${nombreCtrl.text.isNotEmpty ? nombreCtrl.text : "Nombre"}-${_tipoAttrLabel(tipo)}',
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
                DropdownMenuItem(value: 'blog',          child: Text('Blog — artículos y entradas')),
                DropdownMenuItem(value: 'catalogo',      child: Text('Catálogo — productos e ítems')),
                DropdownMenuItem(value: 'agenda',        child: Text('Agenda — eventos y citas')),
                DropdownMenuItem(value: 'noticias',      child: Text('Noticias — actualidad')),
                DropdownMenuItem(value: 'entrevistas',   child: Text('Entrevistas')),
                DropdownMenuItem(value: 'autores',       child: Text('Autores — fichas de personas')),
                DropdownMenuItem(value: 'carta',         child: Text('Carta — menú del restaurante')),
                DropdownMenuItem(value: 'reservas',      child: Text('Reservas — gestión de mesas')),
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
            leading: Icon(seccion.activa ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: const Color(0xFF64748B)),
            title: Text(seccion.activa ? 'Ocultar del hub' : 'Mostrar en hub',
                style: TextStyle(color: _kText)),
            subtitle: Text(seccion.activa ? 'La sección queda guardada pero no visible' : 'Vuelve a aparecer en el hub',
                style: TextStyle(fontSize: 12, color: _kTextSec)),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('empresas').doc(widget.empresaId)
                  .collection('web_secciones').doc(seccionId)
                  .update({'activa': !seccion.activa});
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
      appBar: const FluixAppBar(titulo: 'Contenido Web', showLeading: true),
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
  final bool activa;

  const _WebSeccionDin({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.orden,
    this.activa = true,
  });

  factory _WebSeccionDin.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return _WebSeccionDin(
      id:     doc.id,
      nombre: d['nombre'] as String? ?? 'Sección',
      tipo:   (d['tipo'] as String? ?? 'blog').toLowerCase(),
      orden:  (d['orden'] as num?)?.toInt() ?? 0,
      activa: d['activa'] as bool? ?? true,
    );
  }

  Color get color {
    switch (tipo) {
      case 'blog':         return const Color(0xFF2563EB);
      case 'catalogo':     return const Color(0xFF6B1E2A);
      case 'agenda':       return const Color(0xFF1E4D6B);
      case 'noticias':     return const Color(0xFF059669);
      case 'entrevistas':  return const Color(0xFF7C3AED);
      case 'autores':      return const Color(0xFF0EA5E9);
      case 'carta':        return const Color(0xFFE65100);
      case 'menu_semanal': return const Color(0xFF0F766E);
      case 'reservas':     return const Color(0xFF0EA5E9);
      case 'seleccion':    return const Color(0xFF6B1E2A);
      case 'plantillas_pdf': return const Color(0xFFDC2626);
      default:             return const Color(0xFF475569);
    }
  }

  IconData get icono {
    switch (tipo) {
      case 'blog':         return Icons.article_rounded;
      case 'catalogo':     return Icons.menu_book_rounded;
      case 'agenda':       return Icons.event_rounded;
      case 'noticias':     return Icons.newspaper_rounded;
      case 'entrevistas':  return Icons.record_voice_over_rounded;
      case 'autores':      return Icons.person_rounded;
      case 'carta':        return Icons.restaurant_menu_rounded;
      case 'menu_semanal': return Icons.restaurant_rounded;
      case 'reservas':     return Icons.event_seat_rounded;
      case 'seleccion':    return Icons.stars_rounded;
      case 'plantillas_pdf': return Icons.picture_as_pdf_rounded;
      default:             return Icons.web_rounded;
    }
  }

  String get _desc {
    switch (tipo) {
      case 'blog':         return 'Entradas y artículos\nde $nombre';
      case 'catalogo':     return 'Catálogo de\n$nombre';
      case 'agenda':       return 'Próximos eventos\ny presentaciones';
      case 'noticias':     return 'Crónicas y actualidad\neditoriales';
      case 'entrevistas':  return 'Entrevistas a autores\ny protagonistas';
      case 'autores':      return 'Fichas de autores\ny colaboradores';
      case 'carta':        return 'Platos y bebidas\nde la carta';
      case 'menu_semanal': return 'Menú del día por\njornada de la semana';
      case 'reservas':     return 'Gestiona las reservas\nrecibidas desde la web';
      case 'seleccion':    return 'Curaduría editorial\ny libro del mes';
      case 'plantillas_pdf': return 'Descarga facturas, pedidos\ny documentos en PDF';
      default:             return nombre;
    }
  }

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

// ─────────────────────────────────────────────────────────────────────────────
// Módulo Plantillas PDF — Nazarí
// Permite descargar PDFs de pedidos web, facturas y documentos editoriales.
// ─────────────────────────────────────────────────────────────────────────────
class _TabPlantillasPdfNazari extends StatelessWidget {
  final String empresaId;
  final Color  color;
  const _TabPlantillasPdfNazari({required this.empresaId, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 8),
        Text('Plantillas PDF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        const Text('Genera y descarga documentos en PDF para Editorial Nazarí.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 20),
        _seccion(context, 'Pedidos web',
            'Genera un PDF de los pedidos recibidos desde la tienda.',
            Icons.shopping_bag_rounded, color, () => _abrirPedidos(context)),
        _seccion(context, 'Catálogo PDF',
            'Exporta el catálogo completo de libros en formato PDF.',
            Icons.menu_book_rounded, const Color(0xFF1E4D6B), null),
        _seccion(context, 'Facturas',
            'Genera facturas para clientes y distribuidores.',
            Icons.receipt_long_rounded, const Color(0xFF059669), null),
        _seccion(context, 'Documentos editoriales',
            'Contratos, cesiones de derechos y otros documentos.',
            Icons.description_rounded, const Color(0xFF7C3AED), null),
      ]),
    );
  }

  Widget _seccion(BuildContext ctx, String titulo, String desc, IconData icono, Color c, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icono, color: c, size: 22),
        ),
        title: Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c)
            : Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey[300]),
        onTap: onTap,
      ),
    );
  }

  void _abrirPedidos(BuildContext context) {
    Navigator.of(context).pushNamed('/pedidos', arguments: empresaId);
  }
}
