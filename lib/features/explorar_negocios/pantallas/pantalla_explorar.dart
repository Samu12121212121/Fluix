import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/negocio_publico_model.dart';
import '../../../services/geolocalizacion_service.dart';
import '../../perfil_cliente/pantallas/pantalla_perfil_cliente.dart';
import '../../reservas_cliente/pantallas/detalle_negocio_screen.dart';
import 'pantalla_notificaciones_cliente.dart';
import '../widgets/carrusel_flash_slots.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';

// ═══════════════════════════════════════════════════════════════════════
// PALETA GLOBAL - Light theme (alineada con empresas modo claro)
// ═══════════════════════════════════════════════════════════════════════
class _C {
  // Fondos y superficies (light)
  static const fondo      = Color(0xFFF4F6FB); // Fondo principal claro
  static const grisOscuro = Color(0xFFEEF2F7); // Superficie secundaria
  static const grisMedio  = Color(0xFFFFFFFF); // Tarjeta blanca
  static const grisClaro  = Color(0xFFDDE3ED); // Borde sutil
  // negro se conserva SOLO para overlays sobre imágenes
  static const negro      = Color(0xFF0A0F23);
  // Colores de acento — igual que dashboard empresas
  static const accent     = Color(0xFF00BFA5); // Teal Fluix
  static const accentAlt  = Color(0xFF009688); // Teal oscuro
  static const accentGreen= Color(0xFF10B981); // Esmeralda
  static const accentRosa = Color(0xFFE91E63); // Rosa (corazones)
  // Texto sobre fondo claro
  static const texto      = Color(0xFF1E293B); // slate-800
  static const textoMuted = Color(0xFF64748B); // slate-500
  static const textoHint  = Color(0xFF94A3B8); // slate-400
}

// ══════════════════════════════════════════════════════════════════════
// VALIDACIÓN DE URL DE IMAGEN
// ══════════════════════════════════════════════════════════════════════
bool _esUrlImagenValida(String? url) {
  if (url == null || url.isEmpty) return false;
  final u = url.toLowerCase();
  // Dominios de almacenamiento conocidos
  if (u.contains('firebasestorage.googleapis.com')) return true;
  if (u.contains('storage.googleapis.com')) return true;
  if (u.contains('googleusercontent.com')) return true;
  if (u.contains('cloudinary.com')) return true;
  if (u.contains('imgix.net')) return true;
  if (u.contains('unsplash.com')) return true;
  if (u.contains('wikimedia.org')) return true;
  // Extensiones de imagen habituales en la ruta (antes del ?)
  final path = u.split('?').first;
  for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.heic']) {
    if (path.endsWith(ext)) return true;
  }
  return false;
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
    final color = abierto ? const Color(0xFF10B981) : const Color(0xFF64748B);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              abierto ? 'Abierto' : 'Cerrado',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ]),
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
  final Position? posicion; // contexto para el filtro de distancia

  const FiltrosExplorar({
    this.precio = const RangeValues(0, 200),
    this.ratingMin = 0,
    this.radioKm = 0,
    this.soloAbiertos = false,
    this.posicion,
  });

  bool get tieneAlgunFiltro => ratingMin > 0 || soloAbiertos || radioKm > 0;

  FiltrosExplorar conPosicion(Position? p) => FiltrosExplorar(
    precio: precio,
    ratingMin: ratingMin,
    radioKm: radioKm,
    soloAbiertos: soloAbiertos,
    posicion: p,
  );

  bool pasaFiltro(NegocioPublico n) {
    if (ratingMin > 0 && (n.ratingGoogle == null || n.ratingGoogle! < ratingMin)) return false;
    if (soloAbiertos && _HorarioHelper.estaAbierto(n) != true) return false;
    if (radioKm > 0 && posicion != null) {
      if (n.latitud == null || n.longitud == null) return false;
      final km = GeolocalizacionService.distanciaKm(
        posicion!.latitude, posicion!.longitude,
        n.latitud!, n.longitud!,
      );
      if (km > radioKm) return false;
    }
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
          baseColor: const Color(0xFFE8EEF4),
          highlightColor: const Color(0xFFF5F8FC),
          child: Container(
            width: width,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SKELETON — tarjeta individual (para grid)
// ══════════════════════════════════════════════════════════════════════
class _SkeletonCard extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8EEF4),
    highlightColor: const Color(0xFFF5F8FC),
    child: Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF4),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
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

  static Future<bool> toggle(NegocioPublico negocio, bool agregar) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
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
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ── Color por categoría (para chips circulares) ───────────────────────────
extension CategoriaNegocioColor on CategoriaNegocio {
  Color get chipColor {
    switch (this) {
      case CategoriaNegocio.restaurantes: return const Color(0xFFF97316);
      case CategoriaNegocio.cafeterias:   return const Color(0xFFD97706);
      case CategoriaNegocio.esteticas:    return const Color(0xFFEC4899);
      case CategoriaNegocio.peluquerias:  return const Color(0xFFA855F7);
      case CategoriaNegocio.barberias:    return const Color(0xFF64748B);
      case CategoriaNegocio.carnicerias:  return const Color(0xFFEF4444);
      case CategoriaNegocio.fruterias:    return const Color(0xFF22C55E);
      case CategoriaNegocio.tatuajes:     return const Color(0xFF6366F1);
      case CategoriaNegocio.clinicas:     return const Color(0xFF3B82F6);
      case CategoriaNegocio.gimnasios:    return const Color(0xFFF59E0B);
      case CategoriaNegocio.hoteles:      return const Color(0xFF14B8A6);
      case CategoriaNegocio.tiendas:      return const Color(0xFF8B5CF6);
      default:                            return const Color(0xFF64748B);
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

  void _irABuscar() => setState(() => _tab = 1);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    if (widget.soloContenido) {
      return _TabExplorar(onBuscar: _irABuscar);
    }

    return Scaffold(
      backgroundColor: _C.fondo,
      body: IndexedStack(
        index: _tab,
        children: [
          _TabExplorar(onBuscar: _irABuscar),
          const _TabBuscar(),
          const _TabFavoritos(),
          const PantallaPerfilCliente(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        indice: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Bottom bar ──────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.indice, required this.onTap});

  static const _kItems = [
    (Icons.grid_view_rounded,     Icons.grid_view_outlined,     'Explorar'),
    (Icons.search_rounded,        Icons.search_outlined,        'Buscar'),
    (Icons.favorite_rounded,      Icons.favorite_border_rounded,'Favoritos'),
    (Icons.person_rounded,        Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20, offset: const Offset(0, -4),
        )],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_kItems.length, (i) {
              final sel = indice == i;
              final (iconSel, icon, label) = _kItems[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF0D47A1).withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sel ? iconSel : icon, size: 22,
                          color: sel ? _C.accent : _C.textoMuted),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? _C.accent : _C.textoMuted,
                        ),
                        child: Text(label),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 0 — EXPLORAR
// ═══════════════════════════════════════════════════════════════════════
class _TabExplorar extends StatefulWidget {
  final VoidCallback? onBuscar;
  const _TabExplorar({this.onBuscar});

  @override
  State<_TabExplorar> createState() => _TabExplorarState();
}

class _TabExplorarState extends State<_TabExplorar> {
  CategoriaNegocio? _cat;
  bool _modTendencias = false;
  FiltrosExplorar _filtros = const FiltrosExplorar();
  Position? _posicion;

  // Stream único — un solo listener para toda la pantalla
  List<NegocioPublico> _negocios = [];
  bool _cargandoNegocios = true;
  StreamSubscription<QuerySnapshot>? _negociosSub;

  @override
  void initState() {
    super.initState();
    _cargarPosicion();
    _negociosSub = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _negocios = snap.docs
            .map((d) => NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>))
            .where((n) => n.tieneDatosMinimos)
            .toList();
        _cargandoNegocios = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _cargandoNegocios = false);
    });
  }

  @override
  void dispose() {
    _negociosSub?.cancel();
    super.dispose();
  }

  // Filtrado por categoría y modo tendencias, sin consulta extra
  List<NegocioPublico> get _filtrados {
    var items = _negocios;
    if (_cat != null) items = items.where((n) => n.categoria == _cat).toList();
    if (_modTendencias) items = items.where((n) => (n.ratingFluix ?? 0) >= 4.3).toList();
    return items;
  }

  Future<void> _cargarPosicion() async {
    final resultado = await GeolocalizacionService.obtenerPosicion();
    if (resultado.ok && mounted) {
      setState(() {
        _posicion = resultado.posicion;
        _filtros  = _filtros.conPosicion(_posicion);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocios = _filtrados;
    return Scaffold(
      backgroundColor: _C.fondo,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _heroSection(context)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _chips(),
          )),
          const SliverToBoxAdapter(child: CarruselFlashSlots()),
          SliverToBoxAdapter(child: _seccion(
            titulo: 'Ofertas especiales', sub: 'Solo por tiempo limitado',
            filtro: 'ofertas',
            child: _CarruselOfertas(negocios: negocios, cargando: _cargandoNegocios, filtros: _filtros),
          )),
          SliverToBoxAdapter(child: _seccion(
            titulo: 'Recomendados', sub: 'Los mejor valorados',
            filtro: 'recomendados',
            child: _CarruselCompacto(negocios: negocios, cargando: _cargandoNegocios, filtroRating: 4.0, filtros: _filtros),
          )),
          if (_posicion != null)
            SliverToBoxAdapter(child: _seccion(
              titulo: 'Cerca de ti', sub: 'Negocios en tu zona',
              filtro: 'cercanos',
              child: _CarruselCompacto(negocios: negocios, cargando: _cargandoNegocios, filtros: _filtros, posicion: _posicion),
            ))
          else
            SliverToBoxAdapter(child: _invitacionUbicacion()),
          SliverToBoxAdapter(child: _tituloSeccion(
            titulo: 'Todos los negocios', sub: 'Encuentra tu favorito',
          )),
          _gridNegocios(negocios),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Botón filtros (AppBar action) ────────────────────────────────────────────
  Widget _filtrosBtn() {
    return GestureDetector(
      onTap: () async {
        final resultado = await showModalBottomSheet<FiltrosExplorar>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => FiltrosBottomSheet(filtrosActuales: _filtros),
        );
        if (resultado != null) setState(() => _filtros = resultado.conPosicion(_posicion));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _filtros.tieneAlgunFiltro
              ? _C.accent.withValues(alpha: 0.12)
              : _C.grisOscuro,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.tune_rounded, size: 18,
            color: _filtros.tieneAlgunFiltro ? _C.accent : _C.textoMuted),
      ),
    );
  }

  // ── Botón notificaciones (AppBar action) ──────────────────────────────────────
  Widget _notificacionesBtn() {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PantallaNotificacionesCliente())),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _C.grisOscuro, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none_rounded, size: 19, color: _C.textoMuted),
              ),
              if (noLeidas > 0)
                Positioned(
                  top: -1, right: -1,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: _C.accentRosa, shape: BoxShape.circle),
                    child: Center(child: Text(
                      noLeidas > 9 ? '9+' : '$noLeidas',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    )),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  // ── Hero: nube orgánica asimétrica en la zona superior-derecha ──
  Widget _heroSection(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final h = DateTime.now().hour;
    final saludo = h < 12 ? 'Buenos días,' : h < 19 ? 'Buenas tardes,' : 'Buenas noches,';
    final heroH = topPad + 248.0;

    return LayoutBuilder(builder: (_, bc) {
      final w = bc.maxWidth;
      final textRight = w * 0.50;

      return SizedBox(
        height: heroH,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Fondo base claro
            const Positioned.fill(child: ColoredBox(color: _C.fondo)),
            // ── Nube recortada: imagen (o fallback azul) + overlay degradado ──
            Positioned.fill(
              child: ClipPath(
                clipper: _CloudClipper(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/palacio_infantado.webp',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF1565C0)),
                    ),
                    // Overlay de gradiente para mantener el tono azul Fluix
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            const Color(0xFF1565C0).withValues(alpha: 0.35),
                            const Color(0xFF0D47A1).withValues(alpha: 0.60),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Nube rosa: forma real extraída de la foto (cloud_rosa.png)
            // Valores elegidos en el preview HTML:
            //   ancho=59%, alto=38%, X=179/390·w, Y=211/310·heroH, op=83%
            Positioned(
              left:  w * (179.0 / 390.0),
              top:   heroH * (211.0 / 310.0),
              width: w * 0.59,
              height: heroH * 0.38,
              child: Image.asset(
                'assets/cloud_rosa.png',
                fit: BoxFit.fill,
                opacity: const AlwaysStoppedAnimation(0.83),
              ),
            ),
            // ── Círculo verde (semiluna, abajo-izquierda, detrás del texto)
            Positioned(
              left: -(w * 0.09),
              bottom: -(w * 0.07),
              child: Container(
                width: w * 0.26,
                height: w * 0.26,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // ── Texto izquierda
            Positioned(
              left: 20, top: topPad + 10, bottom: 14,
              right: textRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fluix',
                      style: TextStyle(color: _C.accent, fontSize: 28,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const Spacer(),
                  Text(saludo,
                      style: TextStyle(fontSize: 13, color: _C.texto,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.white.withValues(alpha: 0.9),
                              blurRadius: 6)])),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Encuentra tu lugar',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                            color: _C.texto, height: 1.05, letterSpacing: -0.3,
                            shadows: [Shadow(color: Colors.white.withValues(alpha: 0.9),
                                blurRadius: 8)])),
                  ),
                  const SizedBox(height: 6),
                  Text('Experiencias y negocios a un clic.',
                      style: TextStyle(fontSize: 11, color: _C.texto,
                          height: 1.4,
                          shadows: [Shadow(color: Colors.white.withValues(alpha: 0.9),
                              blurRadius: 6)])),
                ],
              ),
            ),
            // ── Botones filtro + notificaciones
            Positioned(
              top: topPad + 10,
              right: 14,
              child: Row(children: [
                _filtrosBtn(),
                const SizedBox(width: 10),
                _notificacionesBtn(),
              ]),
            ),
          ],
        ),
      );
    });
  }

  Widget _chips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _PillChip(
            emoji: '✨', label: 'Todo',
            color: _C.accent,
            sel: _cat == null && !_modTendencias,
            onTap: () => setState(() { _cat = null; _modTendencias = false; }),
          ),
          _PillChip(
            emoji: '🔥', label: 'Tendencias',
            color: const Color(0xFFF97316),
            sel: _modTendencias,
            onTap: () => setState(() { _modTendencias = !_modTendencias; _cat = null; }),
          ),
          ...CategoriaNegocio.values.map((c) => _PillChip(
            emoji: c.icono,
            label: c.label,
            color: c.chipColor,
            sel: _cat == c && !_modTendencias,
            onTap: () => setState(() { _cat = c; _modTendencias = false; }),
          )),
        ],
      ),
    );
  }

  Widget _invitacionUbicacion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _C.accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.accent.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _C.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location_rounded, color: _C.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Negocios cerca de ti',
                  style: TextStyle(color: _C.texto, fontSize: 13,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Activa la ubicación para ver qué hay alrededor',
                  style: TextStyle(color: _C.textoMuted, fontSize: 11, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: _C.accent, size: 20),
        ]),
      ),
    );
  }

  Widget _seccion({
    required String titulo, required String sub,
    required Widget child, required String filtro,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tituloSeccion(titulo: titulo, sub: sub, filtro: filtro),
      child,
    ]);
  }

  Widget _tituloSeccion({required String titulo, required String sub, String filtro = ''}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700, color: _C.texto, letterSpacing: -0.2)),
          Text(sub, style: GoogleFonts.poppins(
              fontSize: 11, color: _C.textoMuted, fontWeight: FontWeight.w400)),
        ])),
        if (filtro.isNotEmpty)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PantallaListadoCompleto(titulo: titulo, filtro: filtro, cat: _cat),
            )),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Ver todo', style: TextStyle(fontSize: 12, color: _C.accent,
                  fontWeight: FontWeight.w600)),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_rounded, size: 14, color: _C.accent),
            ]),
          ),
      ]),
    );
  }

  Widget _gridNegocios(List<NegocioPublico> negocios) {
    if (_cargandoNegocios) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 0.95,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => Shimmer.fromColors(
              baseColor: const Color(0xFFE8EEF4),
              highlightColor: const Color(0xFFF5F8FC),
              child: Container(decoration: BoxDecoration(
                color: const Color(0xFFE8EEF4),
                borderRadius: BorderRadius.circular(16),
              )),
            ),
            childCount: 6,
          ),
        ),
      );
    }
    var items = [...negocios];
    if (_filtros.tieneAlgunFiltro) items = items.where(_filtros.pasaFiltro).toList();
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Sin resultados con los filtros aplicados',
            style: TextStyle(color: _C.textoMuted, fontSize: 13))),
      ));
    }
    items.sort((a, b) => a.id.compareTo(b.id));
    final seed = DateTime.now().day * 31 + DateTime.now().month;
    for (int i = items.length - 1; i > 0; i--) {
      final j = (seed * (i + 7)) % (i + 1);
      final tmp = items[i]; items[i] = items[j]; items[j] = tmp;
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _TarjetaGrid(negocio: items[i]),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ── Clipper de nube orgánica: misma forma bezier, recorta imagen al contorno ──
class _CloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.24, 0)
      ..lineTo(w + 4, 0)
      ..lineTo(w + 4, h * 0.84)
      ..cubicTo(w * 0.79, h * 1.03, w * 0.52, h * 0.96, w * 0.33, h * 0.88)
      ..cubicTo(w * 0.18, h * 0.83, w * 0.10, h * 0.69, w * 0.17, h * 0.56)
      ..cubicTo(w * 0.04, h * 0.48, w * 0.00, h * 0.29, w * 0.27, h * 0.23)
      ..cubicTo(w * 0.44, h * 0.18, w * 0.27, h * 0.06, w * 0.24, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

// ── Nube cúmulo: ancha y baja, bumps redondeados de distinto tamaño ────
class _SmallCloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    // bY = línea de base de los bumps (~60 % de la altura)
    final bY = h * 0.62;

    return Path()
      ..moveTo(0, h)
      ..lineTo(w + 8, h)
      ..lineTo(w + 8, bY)

      // Bump 1: pequeño, extremo derecho
      ..cubicTo(w + 8, h * 0.22,  w * 0.85, h * 0.10,  w * 0.82, bY)
      // Valle 1-2
      ..cubicTo(w * 0.80, h * 0.74, w * 0.76, h * 0.74, w * 0.73, bY)
      // Bump 2: mediano
      ..cubicTo(w * 0.71, h * 0.08,  w * 0.56, h * 0.02,  w * 0.53, bY)
      // Valle 2-3
      ..cubicTo(w * 0.51, h * 0.76, w * 0.46, h * 0.76, w * 0.44, bY)
      // Bump 3: el más grande y alto (centro visual)
      ..cubicTo(w * 0.42, -h * 0.06, w * 0.22, -h * 0.06, w * 0.20, bY)
      // Valle 3-4
      ..cubicTo(w * 0.18, h * 0.74, w * 0.13, h * 0.74, w * 0.11, bY)
      // Bump 4: pequeño-mediano, extremo izquierdo
      ..cubicTo(w * 0.09, h * 0.18,  w * 0.00, h * 0.16,  0, bY)

      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

// ── Pill chip moderna (reemplaza los círculos) ────────────────────────────
class _PillChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool sel;
  final VoidCallback onTap;
  const _PillChip({required this.emoji, required this.label, required this.color,
      required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: sel ? color : _C.grisClaro,
            width: sel ? 0 : 1,
          ),
          boxShadow: sel ? [BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )] : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1),
          )],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 11,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? Colors.white : _C.texto,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ── Chip de texto compacto (para filtros en tab Buscar) ───────────────────
class _ChipTexto extends StatelessWidget {
  final String label;
  final bool sel;
  final Color color;
  final VoidCallback onTap;
  const _ChipTexto({required this.label, required this.sel,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : _C.grisOscuro,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _C.grisClaro),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? Colors.white : _C.textoMuted,
        )),
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
    final ok = await _FavService.toggle(widget.negocio, nuevoEstado);
    if (!ok && mounted) {
      setState(() => _favorito = !nuevoEstado);
      FluxToast.error(context, nuevoEstado ? 'Error al guardar favorito' : 'Error al eliminar favorito');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox(width: 32, height: 32);
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Icon(
              _favorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: _favorito ? _C.accentRosa : _C.textoMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CARRUSEL OFERTAS — cuadrícula 2 columnas, tarjetas retrato
// ═══════════════════════════════════════════════════════════════════════
class _CarruselOfertas extends StatelessWidget {
  final List<NegocioPublico> negocios;
  final bool cargando;
  final FiltrosExplorar filtros;
  const _CarruselOfertas({required this.negocios, required this.cargando, this.filtros = const FiltrosExplorar()});

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return LayoutBuilder(builder: (_, bc) {
        const hPad = 16.0; const gap = 12.0;
        final cardW = (bc.maxWidth - hPad * 2 - gap) / 2;
        return _SkeletonCarrusel(count: 2, width: cardW, height: cardW * 1.30);
      });
    }
    var items = [...negocios];
    if (filtros.tieneAlgunFiltro) items = items.where(filtros.pasaFiltro).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    items.sort((a, b) =>
        (b.ratingGoogle ?? b.ratingFluix ?? 0).compareTo(a.ratingGoogle ?? a.ratingFluix ?? 0));
    items = items.take(6).toList();

    return LayoutBuilder(builder: (_, bc) {
      const hPad = 16.0; const gap = 12.0;
      final cardW = (bc.maxWidth - hPad * 2 - gap) / 2;
      final cardH = cardW * 1.30;

      return SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: hPad),
          itemCount: items.length,
          itemBuilder: (ctx, i) => Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? gap : 0),
            child: SizedBox(width: cardW, child: _TarjetaOferta(negocio: items[i])),
          ),
        ),
      );
    });
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _C.grisMedio,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: Stack(children: [
          // Foto
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.expand(
              child: _esUrlImagenValida(negocio.fotoUrl)
                  ? CachedNetworkImage(imageUrl: negocio.fotoUrl!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _FotoPlaceholder(),
                      placeholder: (_, __) => const _FotoPlaceholder())
                  : const _FotoPlaceholder(),
            ),
          ),
          // Gradiente (más suave, empieza desde el centro)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: const [0.35, 1.0],
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                ),
              ),
            ),
          ),
          // Badge OFERTA
          Positioned(top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _C.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('OFERTA', style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
            ),
          ),
          // Badge abierto + corazón en fila
          Positioned(top: 12, right: 12,
            child: _HeartButton(negocio: negocio)),
          // Info en la parte baja
          Positioned(bottom: 12, left: 14, right: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BadgeHorario(negocio: negocio),
              const SizedBox(height: 5),
              Text(negocio.nombre, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (negocio.ratingGoogle != null) ...[
                  _ChipRating(rating: negocio.ratingGoogle!),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(negocio.categoria.label,
                      style: const TextStyle(fontSize: 10, color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CARRUSEL COMPACTO — usa lista compartida
// ═══════════════════════════════════════════════════════════════════════
class _CarruselCompacto extends StatelessWidget {
  final List<NegocioPublico> negocios;
  final bool cargando;
  final double? filtroRating;
  final FiltrosExplorar filtros;
  final Position? posicion;
  const _CarruselCompacto({required this.negocios, required this.cargando, this.filtroRating, this.filtros = const FiltrosExplorar(), this.posicion});

  @override
  Widget build(BuildContext context) {
    if (cargando) return const _SkeletonCarrusel(count: 3, width: 155, height: 210);
    var items = [...negocios];
    if (filtroRating != null) {
      final filtrados = items.where((n) => n.ratingGoogle != null && n.ratingGoogle! >= filtroRating!).toList();
      if (filtrados.isNotEmpty) items = filtrados;
    }
    if (filtros.tieneAlgunFiltro) items = items.where(filtros.pasaFiltro).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    if (posicion != null) {
      items.sort((a, b) {
        if (a.latitud == null || a.longitud == null) return 1;
        if (b.latitud == null || b.longitud == null) return -1;
        final da = GeolocalizacionService.distanciaKm(
            posicion!.latitude, posicion!.longitude, a.latitud!, a.longitud!);
        final db = GeolocalizacionService.distanciaKm(
            posicion!.latitude, posicion!.longitude, b.latitud!, b.longitud!);
        return da.compareTo(db);
      });
    } else if (filtroRating != null) {
      items.sort((a, b) => (b.ratingGoogle ?? 0).compareTo(a.ratingGoogle ?? 0));
    }
    items = items.take(15).toList();
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _TarjetaCompacta(negocio: items[i], posicion: posicion),
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
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            // Imagen full-card
            SizedBox.expand(
              child: _esUrlImagenValida(negocio.fotoUrl)
                  ? CachedNetworkImage(
                      imageUrl: negocio.fotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _FotoPlaceholder(),
                      errorWidget: (_, __, ___) => const _FotoPlaceholder())
                  : const _FotoPlaceholder(),
            ),
            // Gradiente inferior
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: const [0.35, 1.0],
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.80)],
              ),
            ))),
            // Corazón top-right
            Positioned(top: 7, right: 7, child: _HeartButton(negocio: negocio)),
            // Info overlay bottom
            Positioned(bottom: 10, left: 10, right: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(negocio.nombre,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: Colors.white, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  if (negocio.ratingGoogle != null) ...[
                    _ChipRating(rating: negocio.ratingGoogle!),
                    const SizedBox(width: 5),
                  ],
                  if (distanciaTexto != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.near_me_rounded, size: 10, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(distanciaTexto,
                          style: const TextStyle(fontSize: 10, color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ])
                  else
                    Flexible(child: Text(negocio.categoria.label,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                        overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Chip de rating reutilizable ──────────────────────────────────────────────
class _ChipRating extends StatelessWidget {
  final double rating;
  const _ChipRating({required this.rating});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.50)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 9, color: Color(0xFFD97706)),
      const SizedBox(width: 2),
      Text(rating.toStringAsFixed(1),
          style: const TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );
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
          color: _C.grisMedio,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.grisClaro),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Foto cuadrada
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 2.0,
                child: _esUrlImagenValida(negocio.fotoUrl)
                    ? CachedNetworkImage(
                        imageUrl: negocio.fotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _FotoPlaceholder(),
                        errorWidget: (_, __, ___) => const _FotoPlaceholder())
                    : const _FotoPlaceholder(),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  Text(negocio.nombre,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _C.texto, height: 1.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  // Rating + reseñas
                  if (negocio.ratingGoogle != null)
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 10, color: Color(0xFFD97706)),
                      const SizedBox(width: 2),
                      Text(negocio.ratingGoogle!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706))),
                      if (negocio.numResenas != null) ...[
                        const SizedBox(width: 3),
                        Text('(${negocio.numResenas})',
                            style: const TextStyle(fontSize: 9, color: _C.textoHint)),
                      ],
                    ]),
                  const SizedBox(height: 2),
                  // Tipo de negocio
                  Text(negocio.categoria.label,
                      style: const TextStyle(fontSize: 9.5, color: _C.textoMuted)),
                  // Servicios destacados
                  if (negocio.serviciosDestacados != null &&
                      negocio.serviciosDestacados!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(negocio.serviciosDestacados!.take(2).join(' · '),
                        style: const TextStyle(fontSize: 9, color: _C.textoHint),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  // Precio medio
                  if (negocio.precioMedio != null && negocio.precioMedio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('~ ${negocio.precioMedio}',
                        style: const TextStyle(fontSize: 9.5, color: _C.textoMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
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
  late Stream<QuerySnapshot> _stream;
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

  void _reintentar() {
    setState(() {
      _cargando = true;
      _errorMsg = null;
      _stream = FirebaseFirestore.instance
          .collection('negocios_publicos')
          .where('activo', isEqualTo: true)
          .limit(200)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.fondo,
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            _cargando = false;
            _errorMsg = snap.error.toString();
          } else if (snap.hasData) {
            _cargando = false;
            _errorMsg = null;
            _todos = snap.data!.docs
                .map((d) => NegocioPublico.fromJson(d.id, d.data() as Map<String, dynamic>))
                .toList();
          }
          return SafeArea(child: Column(children: [
            // Header Fluix
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Fluix',
                    style: TextStyle(color: _C.accent, fontSize: 24,
                        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
            ),
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.grisClaro),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )],
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
                  children: CategoriaNegocio.values.map<Widget>((c) => _ChipTexto(
                    label: '${c.icono} ${c.label}',
                    sel: _catFiltro == c,
                    color: c.chipColor,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.grisClaro),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4, offset: const Offset(0, 1),
              )]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _C.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9)),
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
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(foregroundColor: _C.accent),
          ),
        ]),
      ));
    }

    var items = _todos.where((n) => n.tieneDatosMinimos).toList();

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.grisClaro),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2),
              )],
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56, height: 56,
                  child: n.fotoUrl != null && n.fotoUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: n.fotoUrl!, fit: BoxFit.cover,
                          placeholder: (_, __) => const _FotoPlaceholder(),
                          errorWidget: (_, __, ___) =>
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
// TAB 2 — FAVORITOS
// ═══════════════════════════════════════════════════════════════════════
enum _SortFav { reciente, nombre, rating }

class _TabFavoritos extends StatefulWidget {
  const _TabFavoritos();
  @override
  State<_TabFavoritos> createState() => _TabFavoritosState();
}

class _TabFavoritosState extends State<_TabFavoritos> {
  _SortFav _sort = _SortFav.reciente;

  List<QueryDocumentSnapshot> _sorted(List<QueryDocumentSnapshot> docs) {
    final list = [...docs];
    switch (_sort) {
      case _SortFav.nombre:
        list.sort((a, b) {
          final na = (a.data() as Map)['nombre'] as String? ?? '';
          final nb = (b.data() as Map)['nombre'] as String? ?? '';
          return na.compareTo(nb);
        });
      case _SortFav.rating:
        list.sort((a, b) {
          final ra = ((a.data() as Map)['rating'] as num?) ?? 0;
          final rb = ((b.data() as Map)['rating'] as num?) ?? 0;
          return rb.compareTo(ra);
        });
      case _SortFav.reciente:
        list.sort((a, b) {
          final ta = (a.data() as Map)['guardado_en'];
          final tb = (b.data() as Map)['guardado_en'];
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1; if (tb == null) return -1;
          return (tb as dynamic).compareTo(ta);
        });
    }
    return list;
  }

  String get _sortLabel => switch (_sort) {
    _SortFav.reciente => 'Recientes',
    _SortFav.nombre   => 'A-Z',
    _SortFav.rating   => 'Rating',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final uid = authSnap.data?.uid;
        if (uid == null) {
          return Scaffold(backgroundColor: _C.negro, body: SafeArea(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💫', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              const Text('Inicia sesión para guardar favoritos', style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ))));
        }
        return Scaffold(
          backgroundColor: _C.fondo,
          body: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).collection('favoritos').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _C.accent));
                }
                if (snap.hasError) {
                  return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.wifi_off_rounded, size: 40, color: _C.textoMuted),
                    SizedBox(height: 12),
                    Text('Error al cargar favoritos', style: TextStyle(color: _C.textoMuted, fontSize: 13)),
                  ]));
                }
                final docs = _sorted(snap.data?.docs ?? []);
            return Column(children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fluix', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w900, color: _C.accent, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    const Text('Favoritos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.texto)),
                    Text('${docs.length} guardado${docs.length != 1 ? 's' : ''}', style: const TextStyle(color: _C.textoMuted, fontSize: 12)),
                  ]),
                  const Spacer(),
                  PopupMenuButton<_SortFav>(
                    onSelected: (v) => setState(() => _sort = v),
                    color: _C.grisMedio,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: _C.grisMedio, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.grisClaro)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.sort_rounded, size: 13, color: _C.textoMuted),
                        const SizedBox(width: 5),
                        Text(_sortLabel, style: const TextStyle(color: _C.textoMuted, fontSize: 11)),
                      ]),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _SortFav.reciente, child: Text('Más recientes', style: TextStyle(color: Colors.white, fontSize: 13))),
                      PopupMenuItem(value: _SortFav.nombre,   child: Text('Nombre A-Z',    style: TextStyle(color: Colors.white, fontSize: 13))),
                      PopupMenuItem(value: _SortFav.rating,   child: Text('Mejor valorados', style: TextStyle(color: Colors.white, fontSize: 13))),
                    ],
                  ),
                ]),
              ),
              // ── Grid o empty state ──────────────────────────────────
              if (docs.isEmpty)
                const Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❤️', style: TextStyle(fontSize: 52)),
                  SizedBox(height: 16),
                  Text('Sin favoritos aún', style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Toca el ❤️ en cualquier negocio\npara guardarlo aquí',
                    textAlign: TextAlign.center, style: TextStyle(color: _C.textoMuted, fontSize: 13, height: 1.5)),
                ])))
              else
                Expanded(child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.72,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _TarjetaFavorito(
                    data: docs[i].data() as Map<String, dynamic>,
                    uid: uid, docId: docs[i].id,
                  ),
                )),
            ]);
          },
        ),
      ),
    );
      },
    );
  }
}

class _TarjetaFavorito extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid, docId;
  const _TarjetaFavorito({required this.data, required this.uid, required this.docId});

  @override
  Widget build(BuildContext context) {
    final nombre  = data['nombre'] as String? ?? '';
    final fotoUrl = data['foto_url'] as String? ?? '';
    final catName = data['categoria'] as String? ?? '';
    final rating  = (data['rating'] as num?)?.toDouble();
    CategoriaNegocio? cat;
    try { cat = CategoriaNegocio.values.firstWhere((c) => c.name == catName); } catch (_) {}

    return GestureDetector(
      onTap: () async {
        final negocioId = data['negocio_id'] as String? ?? docId;
        try {
          final docSnap = await FirebaseFirestore.instance.collection('negocios_publicos').doc(negocioId).get();
          if (!context.mounted) return;
          if (docSnap.exists) {
            final negocio = NegocioPublico.fromJson(docSnap.id, docSnap.data() as Map<String, dynamic>);
            Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleNegocioScreen(negocio: negocio)));
          } else {
            FluxToast.aviso(context, 'Este negocio ya no está disponible');
          }
        } catch (e) {
          if (context.mounted) FluxToast.error(context, 'Error al cargar el negocio');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.grisClaro),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Foto con overlay ──────────────────────────────────────
          Expanded(flex: 6, child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: fotoUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: fotoUrl, fit: BoxFit.cover,
                      placeholder: (_, __) => const _FotoPlaceholder(),
                      errorWidget: (_, __, ___) => const _FotoPlaceholder())
                  : const _FotoPlaceholder(),
            ),
            // Gradiente nombre
            Positioned.fill(child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                  stops: const [0.45, 1.0],
                ),
              )),
            )),
            // Nombre sobre la foto
            Positioned(left: 10, right: 44, bottom: 10,
              child: Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, height: 1.2,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            // Botón quitar favorito
            Positioned(top: 8, right: 8,
              child: GestureDetector(
                onTap: () => FirebaseFirestore.instance.collection('usuarios').doc(uid).collection('favoritos').doc(docId).delete(),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _C.accentRosa.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.accentRosa.withValues(alpha: 0.5)),
                  ),
                  child: const Center(child: Icon(Icons.favorite_rounded, size: 15, color: _C.accentRosa)),
                ),
              ),
            ),
          ])),
          // ── Info ─────────────────────────────────────────────────
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB830)),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              if (cat != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(6)),
                  child: Text(cat.label, style: const TextStyle(color: _C.textoMuted, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
            ]),
          )),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2F7), Color(0xFFE2E8F2)],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront_outlined, size: 32,
            color: _C.textoHint),
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
        color: Colors.white,
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
              color: _C.grisClaro,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          // Título
          Text('Filtros', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: _C.texto)),
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
            inactiveColor: _C.grisClaro,
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
                    color: sel ? _C.accent : _C.grisClaro,
                  ),
                ),
              );
            }),
            // Texto
          ),
          const SizedBox(height: 16),

          // Radio de distancia
          Row(children: [
            const Icon(Icons.social_distance_rounded, size: 14, color: _C.textoMuted),
            const SizedBox(width: 6),
            const Text('Radio de distancia',
                style: TextStyle(fontSize: 13, color: _C.textoMuted, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              _radioKm == 0 ? 'Sin límite' : '$_radioKm km',
              style: const TextStyle(fontSize: 12, color: _C.accent),
            ),
          ]),
          Slider(
            value: _radioKm.toDouble(),
            min: 0, max: 50,
            divisions: 10,
            activeColor: _C.accent,
            inactiveColor: _C.grisClaro,
            onChanged: (v) => setState(() => _radioKm = v.toInt()),
          ),
          const SizedBox(height: 8),

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
              inactiveTrackColor: _C.grisClaro,
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
                  side: BorderSide(color: _C.grisClaro),
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
                  foregroundColor: Colors.white,
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
      backgroundColor: _C.fondo,
      appBar: FluixAppBar(titulo: widget.titulo, showLeading: true),
      body: _buildListado(),
    );
  }

  Widget _buildListado() {
    Query q = FirebaseFirestore.instance
        .collection('negocios_publicos')
        .where('activo', isEqualTo: true)
        .limit(100);
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
        if (snap.hasError) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: _C.textoMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Error al cargar los negocios', style: TextStyle(color: _C.textoMuted, fontSize: 14)),
          ]));
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
        negocios = negocios.where((n) => n.tieneDatosMinimos).toList();

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
