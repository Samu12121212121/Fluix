import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/negocio_publico_model.dart';
import '../../../services/geolocalizacion_service.dart';
import '../../perfil_cliente/pantallas/pantalla_perfil_cliente.dart';
import '../../reservas_cliente/pantallas/detalle_negocio_screen.dart';
import 'pantalla_notificaciones_cliente.dart';
import '../widgets/carrusel_flash_slots.dart';

// ═══════════════════════════════════════════════════════════════════════
// PALETA GLOBAL - Cian/Magenta
// ═══════════════════════════════════════════════════════════════════════
class _C {
  static const negro      = Color(0xFF0A0F23); // Fondo azul marino RGB(10,15,35)
  static const grisOscuro = Color(0xFF151932); // Superficie
  static const grisMedio  = Color(0xFF1E2139); // Tarjeta
  static const grisClaro  = Color(0xFF2A2E45); // Outline
  static const accent     = Color(0xFF00FFC8); // Primario cian brillante
  static const accentRosa = Color(0xFFFF3296); // Magenta rojizo
  static const accentRosa2 = Color(0xFFFF4678); // Rosa alternativo
  static const accentRojo = Color(0xFFFF2850); // Rojo/rosa vibrante RGB(255,40,80)
  static const texto      = Color(0xFFFFFFFF); // Texto blanco
  static const textoMuted = Color(0xFFB0B3C1); // Texto secundario
  static const textoHint  = Color(0xFF6B6E82); // Texto sugerencia
}

// ══════════════════════════════════════════════════════════════════════
// HORARIO HELPER — Determina si el negocio está abierto ahora
// ══════════════════════════════════════════════════════════════════════
class _HorarioHelper {
  static const _nombresDia = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  /// Devuelve true si abierto, false si cerrado, null si no hay datos de horario.
  static bool? estaAbierto(NegocioPublico negocio) {
    final ahora = TimeOfDay.now();
    final diaSemana = DateTime.now().weekday; // 1=Lunes, 7=Domingo

    // Prioridad: campo 'horario' (Map<String, Map>) usado en B2C
    if (negocio.horario != null && negocio.horario!.isNotEmpty) {
      final nombreDia = _nombresDia[diaSemana];
      final h = negocio.horario![nombreDia];
      if (h == null) return null;
      if (h['cerrado'] == true) return false;
      final ap = h['apertura'] as String?;
      final ci = h['cierre'] as String?;
      if (ap == null || ci == null) return null;
      final ab = _dentroDeRango(ahora, ap, ci);
      if (ab) return true;
      // Turno tarde
      final apt = h['apertura_tarde'] as String?;
      final cit = h['cierre_tarde'] as String?;
      if (apt != null && cit != null) return _dentroDeRango(ahora, apt, cit);
      return false;
    }

    // Fallback: campo 'horarios' (Map<int, HorarioDia>) usado en B2B
    if (negocio.horarios != null && negocio.horarios!.isNotEmpty) {
      final h = negocio.horarios![diaSemana];
      if (h == null) return null;
      if (!h.abierto) return false;
      if (h.horaApertura == null || h.horaCierre == null) return null;
      final ab = _dentroDeRango(ahora, h.horaApertura!, h.horaCierre!);
      if (ab) return true;
      if (h.horaAperturaTarde != null && h.horaCierreTarde != null) {
        return _dentroDeRango(ahora, h.horaAperturaTarde!, h.horaCierreTarde!);
      }
      return false;
    }
    return null;
  }

  static bool _dentroDeRango(TimeOfDay ahora, String inicio, String fin) {
    final pi = inicio.split(':');
    final pf = fin.split(':');
    if (pi.length < 2 || pf.length < 2) return false;
    final minA = ahora.hour * 60 + ahora.minute;
    final minI = (int.tryParse(pi[0]) ?? 0) * 60 + (int.tryParse(pi[1]) ?? 0);
    final minF = (int.tryParse(pf[0]) ?? 0) * 60 + (int.tryParse(pf[1]) ?? 0);
    return minA >= minI && minA <= minF;
  }
}

// ══════════════════════════════════════════════════════════════════════
// BADGE "ABIERTO / CERRADO"
// ══════════════════════════════════════════════════════════════════════
class _BadgeHorario extends StatelessWidget {
  final NegocioPublico negocio;
  const _BadgeHorario({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final abierto = _HorarioHelper.estaAbierto(negocio);
    if (abierto == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: abierto ? const Color(0xFF2E7D32) : Colors.black54,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        abierto ? 'Abierto' : 'Cerrado',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: abierto ? Colors.white : Colors.white60,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// FILTROS
// ══════════════════════════════════════════════════════════════════════
class FiltrosExplorar {
  final RangeValues precio;
  final int ratingMin;     // 0 = sin filtro
  final int radioKm;       // 0 = sin filtro
  final bool soloAbiertos;

  const FiltrosExplorar({
    this.precio = const RangeValues(0, 200),
    this.ratingMin = 0,
    this.radioKm = 0,
    this.soloAbiertos = false,
  });

  bool get tieneAlgunFiltro => ratingMin > 0 || soloAbiertos || radioKm > 0 || precio.start > 0 || precio.end < 200;

  bool pasaFiltro(NegocioPublico n) {
    if (ratingMin > 0 && (n.ratingGoogle == null || n.ratingGoogle! < ratingMin)) return false;
    if (soloAbiertos && _HorarioHelper.estaAbierto(n) != true) return false;
    return true;
  }
}

// ══════════════════════════════════════════════════════════════════════
// SKELETON — tarjeta compacta 140×175
// ══════════════════════════════════════════════════════════════════════
class _SkeletonCarrusel extends StatelessWidget {
  final int count;
  final double width;
  final double height;
  const _SkeletonCarrusel({this.count = 3, this.width = 140, this.height = 175});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: _C.grisMedio,
          highlightColor: _C.grisClaro,
          child: Container(
            width: width,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _C.grisMedio,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SERVICIO FAVORITOS
// ══════════════════════════════════════════════════════════════════════
class _FavService {
  static Future<bool> esFavorito(String negocioId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('usuarios').doc(uid)
          .collection('favoritos').doc(negocioId).get();
      return doc.exists;
    } catch (e) {
      // Silenciar errores de permisos
      return false;
    }
  }

  static Future<void> toggle(NegocioPublico negocio, bool agregar) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseFirestore.instance
          .collection('usuarios').doc(uid)
          .collection('favoritos').doc(negocio.id);
      if (agregar) {
        await ref.set({
          'negocio_id': negocio.id,
          'nombre': negocio.nombre,
          'foto_url': negocio.fotoUrl ?? '',
          'categoria': negocio.categoria.name,
          'rating': negocio.ratingGoogle,
          'guardado_en': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (e) {
      // Silenciar errores de permisos
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RAÍZ CON TAB BAR INFERIOR
// ═══════════════════════════════════════════════════════════════════════
class PantallaExplorar extends StatefulWidget {
  final bool soloContenido;
  const PantallaExplorar({super.key, this.soloContenido = false});

  @override
  State<PantallaExplorar> createState() => _PantallaExplorarState();
}

class _PantallaExplorarState extends State<PantallaExplorar> {
  int _tab = 0;

  static const _tabs = [
    _TabExplorar(),
    _TabBuscar(),
    _TabFavoritos(),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final body = Scaffold(
      backgroundColor: _C.negro,
      body: IndexedStack(
        index: _tab,
        children: [
          ..._tabs,
          const PantallaPerfilCliente(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        indice: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );

    return body;
  }
}

// ── Bottom bar ──────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.indice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.grisOscuro,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            _item(0, Icons.grid_view_rounded,     'Explorar'),
            _item(1, Icons.search_rounded,         'Buscar'),
            _item(2, Icons.favorite_border_rounded,'Favoritos'),
            _item(3, Icons.person_outline_rounded, 'Perfil'),
          ]),
        ),
      ),
    );
  }

  Widget _item(int idx, IconData icon, String label) {
    final sel = indice == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(idx),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22,
              color: sel ? _C.accent : _C.textoMuted),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            color: sel ? _C.accent : _C.textoMuted,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 0 — EXPLORAR
// ═══════════════════════════════════════════════════════════════════════
class _TabExplorar extends StatefulWidget {
  const _TabExplorar();

  @override
  State<_TabExplorar> createState() => _TabExplorarState();
}

class _TabExplorarState extends State<_TabExplorar> {
  CategoriaNegocio? _cat;
  bool _modTendencias = false;
  FiltrosExplorar _filtros = const FiltrosExplorar();
  Position? _posicion;

  String get _subtituloCercaDeTi =>
      _posicion != null ? 'Negocios cerca de ti' : 'Activa la ubicación para ver cercanos';

  @override
  void initState() {
    super.initState();
    _cargarPosicion();
  }

  Future<void> _cargarPosicion() async {
    final resultado = await GeolocalizacionService.obtenerPosicion();
    if (resultado.ok && mounted) {
      setState(() => _posicion = resultado.posicion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _appBar(),
        SliverToBoxAdapter(child: _greeting()),
        SliverToBoxAdapter(child: _chips()),
        // ── FLASH SLOTS ──────────────────────────────────────────
        const SliverToBoxAdapter(child: CarruselFlashSlots()),
        // ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _seccion(
          emoji: '🔥', titulo: 'Ofertas especiales', sub: 'Solo por tiempo limitado',
          filtro: 'ofertas',
          child: _CarruselOfertas(cat: _cat, modTendencias: _modTendencias, filtros: _filtros),
        )),
        SliverToBoxAdapter(child: _seccion(
          emoji: '⭐', titulo: 'Recomendados', sub: 'Mejor valorados',
          filtro: 'recomendados',
          child: _CarruselCompacto(cat: _cat, filtroRating: 4.0, modTendencias: _modTendencias, filtros: _filtros),
        )),
        SliverToBoxAdapter(child: _seccion(
          emoji: '📍', titulo: 'Cerca de ti', sub: _subtituloCercaDeTi,
          filtro: 'cercanos',
          child: _CarruselCompacto(cat: _cat, modTendencias: _modTendencias, filtros: _filtros, posicion: _posicion),
        )),
        SliverToBoxAdapter(child: _tituloSeccion(
          emoji: '✨', titulo: 'Encuentra tu nuevo favorito', sub: 'Todos los negocios',
        )),
        _gridNegocios(),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  SliverAppBar _appBar() {
    return SliverAppBar(
      backgroundColor: _C.negro,
      floating: true, snap: true,
      elevation: 0, toolbarHeight: 54,
      title: Text('Fluix', style: TextStyle(
        color: _C.accent, fontSize: 28,
        fontWeight: FontWeight.w800, letterSpacing: -1,
      )),
      actions: [
        // Botón filtros
        GestureDetector(
          onTap: () async {
            final resultado = await showModalBottomSheet<FiltrosExplorar>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => FiltrosBottomSheet(filtrosActuales: _filtros),
            );
            if (resultado != null) setState(() => _filtros = resultado);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _filtros.tieneAlgunFiltro ? _C.accent.withValues(alpha: 0.2) : _C.grisMedio,
              shape: BoxShape.circle,
              border: _filtros.tieneAlgunFiltro
                  ? Border.all(color: _C.accent, width: 1.5)
                  : null,
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: _filtros.tieneAlgunFiltro ? _C.accent : _C.textoMuted,
            ),
          ),
        ),
        // Notificaciones
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('notificaciones')
                    .where('leida', isEqualTo: false)
                    .snapshots(),
            builder: (context, snap) {
              final noLeidas = snap.data?.docs.length ?? 0;
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaNotificacionesCliente())),
                child: Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(
                    radius: 17, backgroundColor: _C.grisMedio,
                    child: Icon(Icons.notifications_none_rounded,
                        size: 19, color: _C.texto.withValues(alpha: 0.8)),
                  ),
                  if (noLeidas > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: _C.accentRosa, shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            noLeidas > 9 ? '9+' : '$noLeidas',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _greeting() {
    final h = DateTime.now().hour;
    final s = h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s, style: TextStyle(fontSize: 12, color: _C.textoMuted)),
        const SizedBox(height: 2),
        Text('Encuentra tu lugar', style: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w700, color: _C.texto, height: 1.1,
        )),
      ]),
    );
  }

  Widget _chips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Chip(label: 'Todo', sel: _cat == null && !_modTendencias, 
                onTap: () => setState(() { _cat = null; _modTendencias = false; })),
          _ChipTendencias(
            sel: _modTendencias,
            onTap: () => setState(() { _modTendencias = !_modTendencias; _cat = null; }),
          ),
          ...CategoriaNegocio.values.map((c) => _Chip(
            label: c.label,
            sel: _cat == c && !_modTendencias,
            onTap: () => setState(() { _cat = c; _modTendencias = false; }),
          )),
        ],
      ),
    );
  }

  Widget _seccion({
    required String emoji, required String titulo,
    required String sub, required Widget child, required String filtro,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tituloSeccion(emoji: emoji, titulo: titulo, sub: sub, filtro: filtro),
      child,
    ]);
  }

  Widget _tituloSeccion({required String emoji, required String titulo, required String sub, String filtro = ''}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$emoji $titulo', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _C.texto)),
          const SizedBox(height: 1),
          Text(sub, style: const TextStyle(fontSize: 11, color: _C.textoMuted)),
        ])),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PantallaListadoCompleto(titulo: '$emoji $titulo', filtro: filtro, cat: _cat),
          )),
          child: Text('Ver todo →', style: TextStyle(fontSize: 12, color: _C.accent,
              fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  SliverPadding _gridNegocios() {
    Query q = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true);
    if (_cat != null) q = q.where('categoria', isEqualTo: _cat!.name);
    if (_modTendencias) q = q.where('ratingFluix', isGreaterThanOrEqualTo: 4.3).orderBy('ratingFluix', descending: true);
    if (_filtros.ratingMin > 0) q = q.where('ratingGoogle', isGreaterThanOrEqualTo: _filtros.ratingMin.toDouble());

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          // Skeleton mientras carga
          if (snap.connectionState == ConnectionState.waiting) {
            return SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, __) => Shimmer.fromColors(
                  baseColor: _C.grisMedio,
                  highlightColor: _C.grisClaro,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.grisMedio,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                childCount: 6,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.75,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          var negocios = docs.map((d) =>
              NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>)).toList();
          // Aplicar filtros cliente
          if (_filtros.tieneAlgunFiltro) {
            negocios = negocios.where(_filtros.pasaFiltro).toList();
          }
          if (negocios.isEmpty) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Sin resultados con los filtros aplicados',
                    style: TextStyle(color: _C.textoMuted, fontSize: 13))),
              ),
            );
          }
          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TarjetaGrid(negocio: negocios[i]),
              childCount: negocios.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          );
        },
      ),
    );
  }
}

// ── Chip ─────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _C.accent : _C.grisMedio,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          color: sel ? _C.negro : _C.textoMuted,
        )),
      ),
    );
  }
}

class _ChipTendencias extends StatelessWidget {
  final bool sel;
  final VoidCallback onTap;
  const _ChipTendencias({required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: sel ? const LinearGradient(
            colors: [Color(0xFFFF3296), Color(0xFFFFBB00)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ) : null,
          color: sel ? null : _C.grisMedio,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('Tendencias', style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            color: sel ? Colors.white : _C.textoMuted,
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// BOTÓN CORAZÓN (compartido por todas las tarjetas)
// ══════════════════════════════════════════════════════════════════════
class _HeartButton extends StatefulWidget {
  final NegocioPublico negocio;
  const _HeartButton({required this.negocio});

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton>
    with SingleTickerProviderStateMixin {
  bool _favorito = false;
  bool _cargando = true;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnim = Tween<double>(begin: 1, end: 1.4).chain(
        CurveTween(curve: Curves.elasticOut)).animate(_animCtrl);
    _checkFavorito();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _checkFavorito() async {
    final ok = await _FavService.esFavorito(widget.negocio.id);
    if (mounted) setState(() { _favorito = ok; _cargando = false; });
  }

  Future<void> _toggle() async {
    final nuevoEstado = !_favorito;
    setState(() => _favorito = nuevoEstado);
    _animCtrl.forward(from: 0);
    await _FavService.toggle(widget.negocio, nuevoEstado);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox(width: 30, height: 30);
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _C.negro.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Icon(
              _favorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: _favorito ? _C.accentRosa : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CARRUSEL OFERTAS (horizontal ancho)
// ═══════════════════════════════════════════════════════════════════════
class _CarruselOfertas extends StatelessWidget {
  final CategoriaNegocio? cat;
  final bool modTendencias;
  final FiltrosExplorar filtros;
  const _CarruselOfertas({this.cat, this.modTendencias = false, this.filtros = const FiltrosExplorar()});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true)
        .limit(30);
    if (cat != null) q = q.where('categoria', isEqualTo: cat!.name);
    if (modTendencias) q = q.where('ratingFluix', isGreaterThanOrEqualTo: 4.3).orderBy('ratingFluix', descending: true);

    return SizedBox(
      height: 120,
      child: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _SkeletonCarrusel(count: 3, width: 240, height: 120);
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox.shrink();
          var items = docs.map((d) =>
              NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>)).toList();
          if (filtros.tieneAlgunFiltro) items = items.where(filtros.pasaFiltro).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _TarjetaOferta(negocio: items[i]),
          );
        },
      ),
    );
  }
}

class _TarjetaOferta extends StatelessWidget {
  final NegocioPublico negocio;
  const _TarjetaOferta({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleNegocioScreen(negocio: negocio))),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _C.grisMedio,
        ),
        child: Stack(children: [
          // Foto
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.expand(
              child: negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty
                  ? Image.network(negocio.fotoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _FotoPlaceholder())
                  : const _FotoPlaceholder(),
            ),
          ),
          // Gradiente
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, _C.negro.withValues(alpha: 0.88)],
              ),
            ),
          ),
          // Badge OFERTA
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _C.accent, borderRadius: BorderRadius.circular(5)),
              child: Text('OFERTA', style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: _C.negro)),
            ),
          ),
          // Badge ABIERTO/CERRADO
          Positioned(bottom: 32, left: 10,
            child: _BadgeHorario(negocio: negocio)),
          // Corazón
          Positioned(top: 8, right: 8,
            child: _HeartButton(negocio: negocio)),
          // Info
          Positioned(bottom: 10, left: 12, right: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(negocio.nombre, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                if (negocio.ratingGoogle != null) ...[
                  Icon(Icons.star_rounded, size: 11, color: _C.accent),
                  const SizedBox(width: 3),
                  Text(negocio.ratingGoogle!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  const SizedBox(width: 6),
                ],
                Text(negocio.categoria.label,
                    style: const TextStyle(fontSize: 10, color: Colors.white54)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CARRUSEL COMPACTO
// ═══════════════════════════════════════════════════════════════════════
class _CarruselCompacto extends StatelessWidget {
  final CategoriaNegocio? cat;
  final double? filtroRating;
  final bool modTendencias;
  final FiltrosExplorar filtros;
  final Position? posicion;
  const _CarruselCompacto({this.cat, this.filtroRating, this.modTendencias = false, this.filtros = const FiltrosExplorar(), this.posicion});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true)
        .limit(50);
    if (cat != null) q = q.where('categoria', isEqualTo: cat!.name);
    if (modTendencias) q = q.where('ratingFluix', isGreaterThanOrEqualTo: 4.3).orderBy('ratingFluix', descending: true);

    return SizedBox(
      height: 175,
      child: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _SkeletonCarrusel(count: 3, width: 140, height: 175);
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox.shrink();
          var items = docs.map((d) =>
              NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>)).toList();
          if (!modTendencias && filtroRating != null) {
            final filtrados = items.where((n) =>
            n.ratingGoogle != null && n.ratingGoogle! >= filtroRating!).toList();
            if (filtrados.isNotEmpty) items = filtrados;
          }
          if (filtros.tieneAlgunFiltro) items = items.where(filtros.pasaFiltro).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _TarjetaCompacta(negocio: items[i], posicion: posicion),
          );
        },
      ),
    );
  }
}

class _TarjetaCompacta extends StatelessWidget {
  final NegocioPublico negocio;
  final Position? posicion;
  const _TarjetaCompacta({required this.negocio, this.posicion});

  @override
  Widget build(BuildContext context) {
    // Calcular distancia si tenemos ubicación y el negocio tiene coordenadas
    String? distanciaTexto;
    if (posicion != null && negocio.latitud != null && negocio.longitud != null) {
      final km = GeolocalizacionService.distanciaKm(
        posicion!.latitude, posicion!.longitude,
        negocio.latitud!, negocio.longitud!,
      );
      distanciaTexto = GeolocalizacionService.formatearDistancia(km);
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleNegocioScreen(negocio: negocio))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _C.grisOscuro,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Foto + corazón
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 100, width: double.infinity,
                child: negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty
                    ? Image.network(negocio.fotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _FotoPlaceholder())
                    : const _FotoPlaceholder(),
              ),
            ),
            Positioned(top: 6, right: 6,
              child: _HeartButton(negocio: negocio)),
            Positioned(top: 6, left: 6,
              child: _BadgeHorario(negocio: negocio)),
          ]),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(negocio.nombre,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _C.texto, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                if (negocio.ratingGoogle != null) ...[
                  Icon(Icons.star_rounded, size: 11, color: _C.accent),
                  const SizedBox(width: 3),
                  Text(negocio.ratingGoogle!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10, color: _C.textoMuted,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 5),
                ],
                Flexible(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: _C.grisMedio, borderRadius: BorderRadius.circular(4)),
                  child: Text(negocio.categoria.label,
                      style: const TextStyle(fontSize: 9, color: _C.textoMuted),
                      overflow: TextOverflow.ellipsis),
                )),
              ]),
              // Distancia
              if (distanciaTexto != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.place_rounded, size: 9, color: _C.accent),
                  const SizedBox(width: 2),
                  Text(distanciaTexto,
                      style: const TextStyle(fontSize: 9, color: _C.accent,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TARJETA GRID (cuadrada 2 columnas)
// ═══════════════════════════════════════════════════════════════════════
class _TarjetaGrid extends StatelessWidget {
  final NegocioPublico negocio;
  const _TarjetaGrid({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleNegocioScreen(negocio: negocio))),
      child: Container(
        decoration: BoxDecoration(
          color: _C.grisOscuro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Foto cuadrada
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.05,
                child: negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty
                    ? Image.network(negocio.fotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _FotoPlaceholder())
                    : const _FotoPlaceholder(),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(negocio.nombre,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: _C.texto, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (negocio.tagline != null && negocio.tagline!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(negocio.tagline!,
                          style: const TextStyle(fontSize: 9, color: _C.textoMuted,
                              fontStyle: FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 3),
                    if (negocio.ratingGoogle != null)
                      Row(children: [
                        ...List.generate(5, (i) {
                          final llena = i < negocio.ratingGoogle!.round();
                          return Icon(
                            llena ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 12,
                            color: llena ? _C.accent : _C.grisClaro,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(negocio.ratingGoogle!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10, color: _C.textoMuted)),
                      ]),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _C.negro, borderRadius: BorderRadius.circular(5)),
                      child: Text(negocio.categoria.label,
                          style: const TextStyle(fontSize: 9, color: _C.textoMuted)),
                    ),
                    if (negocio.precioMedio != null && negocio.precioMedio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: _C.negro, borderRadius: BorderRadius.circular(4)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.euro, size: 9, color: _C.textoMuted),
                          const SizedBox(width: 2),
                          Text(negocio.precioMedio!,
                              style: const TextStyle(fontSize: 9, color: _C.textoMuted)),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]),
          // Corazón en esquina superior derecha
          Positioned(top: 8, right: 8,
            child: _HeartButton(negocio: negocio)),
          // Badge abierto/cerrado esquina superior izquierda
          Positioned(top: 8, left: 8,
            child: _BadgeHorario(negocio: negocio)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 1 — BUSCAR
// ═══════════════════════════════════════════════════════════════════════
class _TabBuscar extends StatefulWidget {
  const _TabBuscar();

  @override
  State<_TabBuscar> createState() => _TabBuscarState();
}

class _TabBuscarState extends State<_TabBuscar> {
  final _ctrl = TextEditingController();
  String _q = '';
  CategoriaNegocio? _catFiltro;
  // Stream persistente: se carga UNA VEZ y se filtra en cliente
  late final Stream<QuerySnapshot> _stream;
  List<NegocioPublico> _todos = [];
  bool _cargando = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true)
        .limit(200)
        .snapshots();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.negro,
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            _errorMsg = snap.error.toString();
          } else if (snap.hasData) {
            _cargando = false;
            _todos = snap.data!.docs
                .map((d) => NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>))
                .toList();
          }
          return SafeArea(child: Column(children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _C.grisOscuro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: false,
                  onChanged: (v) => setState(() { _q = v.toLowerCase().trim(); _catFiltro = null; }),
                  style: const TextStyle(color: _C.texto, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Busca negocios o servicios...',
                    hintStyle: const TextStyle(color: _C.textoMuted, fontSize: 14),
                    prefixIcon: _cargando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2)))
                        : const Icon(Icons.search_rounded, color: _C.textoMuted, size: 20),
                    suffixIcon: _q.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 17, color: _C.textoMuted),
                            onPressed: () { _ctrl.clear(); setState(() { _q = ''; _catFiltro = null; }); })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            // Chips de categorías (solo cuando no hay texto)
            if (_q.isEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: CategoriaNegocio.values.map((c) => _Chip(
                    label: '${c.icono} ${c.label}',
                    sel: _catFiltro == c,
                    onTap: () => setState(() {
                      _catFiltro = _catFiltro == c ? null : c;
                    }),
                  )).toList(),
                ),
              ),
            // Contenido
            Expanded(child: _q.isEmpty && _catFiltro == null
                ? _sugerencias()
                : _resultados()),
          ]));
        },
      ),
    );
  }

  Widget _sugerencias() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      children: [
        const Text('Categorías populares',
            style: TextStyle(fontSize: 12, color: _C.textoMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        ...CategoriaNegocio.values.map((c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: _C.grisOscuro, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _C.grisMedio, borderRadius: BorderRadius.circular(9)),
              child: Center(child: Text(c.icono, style: const TextStyle(fontSize: 18))),
            ),
            title: Text(c.label,
                style: const TextStyle(color: _C.texto, fontSize: 14,
                    fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: _C.textoMuted, size: 18),
            onTap: () => setState(() => _catFiltro = c),
          ),
        )),
      ],
    );
  }

  Widget _resultados() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }
    if (_errorMsg != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: _C.textoMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Error al cargar los negocios', style: TextStyle(color: _C.texto, fontSize: 14)),
          const SizedBox(height: 4),
          Text(_errorMsg!, style: const TextStyle(color: _C.textoMuted, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ));
    }

    var items = List<NegocioPublico>.from(_todos);

    // Filtro por categoría
    if (_catFiltro != null) {
      items = items.where((n) => n.categoria == _catFiltro).toList();
    }

    // Filtro client-side por texto de búsqueda
    if (_q.isNotEmpty) {
      items = items.where((n) =>
          n.nombre.toLowerCase().contains(_q) ||
          (n.descripcion?.toLowerCase().contains(_q) ?? false) ||
          n.categoria.label.toLowerCase().contains(_q) ||
          (n.direccion?.toLowerCase().contains(_q) ?? false) ||
          (n.tagline?.toLowerCase().contains(_q) ?? false)).toList();
    }

    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: 52, color: _C.textoMuted.withValues(alpha: 0.3)),
        const SizedBox(height: 14),
        Text(
          _catFiltro != null
              ? 'Sin resultados en ${_catFiltro!.label}'
              : 'Sin resultados para "$_q"',
          style: const TextStyle(color: _C.textoMuted, fontSize: 14)),
        const SizedBox(height: 8),
        Text('${_todos.length} negocios cargados',
            style: const TextStyle(color: _C.textoHint, fontSize: 11)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final n = items[i];
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => DetalleNegocioScreen(negocio: n))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.grisOscuro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56, height: 56,
                  child: n.fotoUrl != null && n.fotoUrl!.isNotEmpty
                      ? Image.network(n.fotoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: _C.grisMedio))
                      : const ColoredBox(color: _C.grisMedio),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.nombre, style: const TextStyle(
                    color: _C.texto, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _C.grisMedio, borderRadius: BorderRadius.circular(5)),
                    child: Text(n.categoria.label,
                        style: const TextStyle(color: _C.textoMuted, fontSize: 10)),
                  ),
                  if (n.ratingGoogle != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star_rounded, size: 11, color: _C.accent),
                    const SizedBox(width: 2),
                    Text(n.ratingGoogle!.toStringAsFixed(1),
                        style: const TextStyle(color: _C.textoMuted, fontSize: 11)),
                  ],
                ]),
                if (n.descripcion != null) ...[
                  const SizedBox(height: 3),
                  Text(n.descripcion!,
                      style: const TextStyle(color: _C.textoHint, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ])),
              const SizedBox(width: 8),
              _HeartButton(negocio: n),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 2 — FAVORITOS (funcional con Firestore)
// ═══════════════════════════════════════════════════════════════════════
class _TabFavoritos extends StatelessWidget {
  const _TabFavoritos();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _C.negro,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              const Text('Mis Favoritos', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: _C.texto,
              )),
              const Spacer(),
              Icon(Icons.favorite_rounded, color: _C.accentRosa, size: 22),
            ]),
          ),

          if (uid == null)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border_rounded, size: 56,
                    color: _C.textoMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('Inicia sesión para guardar favoritos',
                    style: TextStyle(color: _C.texto, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            )))
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('usuarios').doc(uid)
                    .collection('favoritos')
                    .snapshots(),  // sin orderBy → evita necesitar índice compuesto
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _C.accent));
                  }

                  if (snap.hasError) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 48,
                            color: _C.textoMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('No se pudieron cargar los favoritos',
                            style: TextStyle(color: _C.texto, fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('${snap.error}',
                            style: const TextStyle(color: _C.textoMuted, fontSize: 11),
                            textAlign: TextAlign.center),
                      ],
                    ));
                  }

                  // Ordenar cliente-side por fecha (más reciente primero)
                  final docs = [...(snap.data?.docs ?? [])];
                  docs.sort((a, b) {
                    final ta = (a.data() as Map<String, dynamic>)['guardado_en'];
                    final tb = (b.data() as Map<String, dynamic>)['guardado_en'];
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return (tb as dynamic).compareTo(ta);
                  });

                  if (docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border_rounded, size: 56,
                            color: _C.textoMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('Sin favoritos aún',
                            style: TextStyle(color: _C.texto, fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Pulsa el ❤️ en cualquier negocio\npara guardarlo aquí',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _C.textoMuted, fontSize: 13)),
                      ],
                    ));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return _TarjetaFavorito(data: data, uid: uid, docId: docs[i].id);
                    },
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class _TarjetaFavorito extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  final String docId;
  const _TarjetaFavorito({required this.data, required this.uid, required this.docId});

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] as String? ?? '';
    final fotoUrl = data['foto_url'] as String? ?? '';
    final catName = data['categoria'] as String? ?? '';
    final rating = (data['rating'] as num?)?.toDouble();

    CategoriaNegocio? cat;
    try {
      cat = CategoriaNegocio.values.firstWhere((c) => c.name == catName);
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        // Cargar negocio completo y navegar
        final negocioId = data['negocio_id'] as String? ?? docId;
        final docSnap = await FirebaseFirestore.instance
            .collection('negocios_publicos').doc(negocioId).get();
        if (!context.mounted) return;
        if (docSnap.exists) {
          final negocio = NegocioPublico.fromJson(
              docSnap.id, docSnap.data() as Map<String, dynamic>);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => DetalleNegocioScreen(negocio: negocio)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _C.grisOscuro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Foto
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: fotoUrl.isNotEmpty
                    ? Image.network(fotoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _FotoPlaceholder())
                    : const _FotoPlaceholder(),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _C.texto, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (rating != null)
                    Row(children: [
                      Icon(Icons.star_rounded, size: 11, color: _C.accent),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: _C.textoMuted)),
                    ]),
                  if (cat != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _C.negro, borderRadius: BorderRadius.circular(4)),
                      child: Text(cat.label,
                          style: const TextStyle(fontSize: 9, color: _C.textoMuted)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
          // Botón eliminar favorito (corazón lleno)
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('usuarios').doc(uid)
                    .collection('favoritos').doc(docId)
                    .delete();
              },
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _C.negro.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.favorite_rounded, size: 16, color: _C.accentRosa),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PLACEHOLDER FOTO
// ═══════════════════════════════════════════════════════════════════════
class _FotoPlaceholder extends StatelessWidget {
  const _FotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.grisMedio,
      child: Center(
        child: Icon(Icons.image_outlined, size: 28,
            color: _C.textoMuted.withValues(alpha: 0.3)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FILTROS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════
class FiltrosBottomSheet extends StatefulWidget {
  final FiltrosExplorar filtrosActuales;
  const FiltrosBottomSheet({super.key, required this.filtrosActuales});

  @override
  State<FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<FiltrosBottomSheet> {
  late RangeValues _precio;
  late int _ratingMin;
  late int _radioKm;
  late bool _soloAbiertos;

  @override
  void initState() {
    super.initState();
    _precio      = widget.filtrosActuales.precio;
    _ratingMin   = widget.filtrosActuales.ratingMin;
    _radioKm     = widget.filtrosActuales.radioKm;
    _soloAbiertos = widget.filtrosActuales.soloAbiertos;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF151932),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2E45),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          // Título
          const Text('Filtros', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 20),

          // Precio
          Row(children: [
            const Icon(Icons.euro, size: 14, color: _C.textoMuted),
            const SizedBox(width: 6),
            const Text('Rango de precio',
                style: TextStyle(fontSize: 13, color: _C.textoMuted, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              '${_precio.start.toInt()}€ – ${_precio.end.toInt()}€',
              style: const TextStyle(fontSize: 12, color: _C.accent),
            ),
          ]),
          RangeSlider(
            values: _precio,
            min: 0, max: 200,
            divisions: 20,
            activeColor: _C.accent,
            inactiveColor: const Color(0xFF2A2E45),
            onChanged: (v) => setState(() => _precio = v),
          ),
          const SizedBox(height: 8),

          // Rating mínimo
          const Text('Valoración mínima',
              style: TextStyle(fontSize: 13, color: _C.textoMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final sel = i < _ratingMin;
              return GestureDetector(
                onTap: () => setState(() => _ratingMin = _ratingMin == i + 1 ? 0 : i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    sel ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 28,
                    color: sel ? _C.accent : const Color(0xFF2A2E45),
                  ),
                ),
              );
            }),
            // Texto
          ),
          const SizedBox(height: 16),

          // Abierto ahora
          Row(children: [
            const Icon(Icons.access_time_rounded, size: 14, color: _C.textoMuted),
            const SizedBox(width: 6),
            const Text('Solo negocios abiertos ahora',
                style: TextStyle(fontSize: 13, color: _C.textoMuted, fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(
              value: _soloAbiertos,
              onChanged: (v) => setState(() => _soloAbiertos = v),
              activeColor: _C.accent,
              inactiveTrackColor: const Color(0xFF2A2E45),
            ),
          ]),
          const SizedBox(height: 16),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _precio = const RangeValues(0, 200);
                    _ratingMin = 0;
                    _radioKm = 0;
                    _soloAbiertos = false;
                  });
                  Navigator.pop(context, const FiltrosExplorar());
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2A2E45)),
                  foregroundColor: _C.textoMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Limpiar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, FiltrosExplorar(
                  precio: _precio,
                  ratingMin: _ratingMin,
                  radioKm: _radioKm,
                  soloAbiertos: _soloAbiertos,
                )),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: _C.negro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA LISTADO COMPLETO (Ver todo)
// ═══════════════════════════════════════════════════════════════════════
class PantallaListadoCompleto extends StatefulWidget {
  final String titulo;
  final String filtro; // 'ofertas', 'recomendados', 'cercanos'
  final CategoriaNegocio? cat;

  const PantallaListadoCompleto({
    super.key,
    required this.titulo,
    required this.filtro,
    this.cat,
  });

  @override
  State<PantallaListadoCompleto> createState() => _PantallaListadoCompletoState();
}

class _PantallaListadoCompletoState extends State<PantallaListadoCompleto> {
  CategoriaNegocio? _cat;

  @override
  void initState() {
    super.initState();
    _cat = widget.cat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.negro,
      appBar: AppBar(
        backgroundColor: _C.grisOscuro,
        foregroundColor: _C.texto,
        title: Text(widget.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _Chip(label: 'Todo', sel: _cat == null, onTap: () => setState(() => _cat = null)),
                ...CategoriaNegocio.values.map((c) => _Chip(
                  label: c.label, sel: _cat == c,
                  onTap: () => setState(() => _cat = c),
                )),
              ],
            ),
          ),
        ),
      ),
      body: _buildListado(),
    );
  }

  Widget _buildListado() {
    Query q = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true);
    if (_cat != null) q = q.where('categoria', isEqualTo: _cat!.name);
    if (widget.filtro == 'recomendados') {
      q = q.orderBy('ratingGoogle', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off, size: 60, color: _C.textoMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Sin resultados', style: TextStyle(color: _C.textoMuted, fontSize: 16)),
          ]));
        }

        var negocios = docs.map((d) =>
            NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>)).toList();

        if (widget.filtro == 'recomendados') {
          final filtrados = negocios.where((n) => n.ratingGoogle != null && n.ratingGoogle! >= 4.0).toList();
          if (filtrados.isNotEmpty) negocios = filtrados;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.72,
            crossAxisSpacing: 12, mainAxisSpacing: 12,
          ),
          itemCount: negocios.length,
          itemBuilder: (_, i) => _TarjetaGrid(negocio: negocios[i]),
        );
      },
    );
  }
}
