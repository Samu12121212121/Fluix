import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/negocio_publico_model.dart';
import '../../negocio_publico/pantallas/tab_reservas_screen.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../services/canjeo_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/utils/app_settings.dart';
import '../widgets/booking_sheet.dart';
import '../../../domain/modelos/config_reservas.dart';

// Reactive dark-mode flag — updated at the start of each build.
bool _isDark = false;

class _C {
  static const accent     = Color(0xFF00BFA5);
  static const accentRosa = Color(0xFFE91E63);
  static const oro        = Color(0xFFFFB830);
  static const negro      = Color(0xFF0A0F23);

  static Color get fondo      => _isDark ? const Color(0xFF0A0F23) : const Color(0xFFF4F6FB);
  static Color get grisOscuro => _isDark ? const Color(0xFF1E2139) : const Color(0xFFEEF2F7);
  static Color get grisMedio  => _isDark ? const Color(0xFF252A45) : Colors.white;
  static Color get grisClaro  => _isDark ? const Color(0xFF2A2E45) : const Color(0xFFDDE3ED);
  static Color get texto      => _isDark ? Colors.white             : const Color(0xFF1E293B);
  static Color get textoMuted => _isDark ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
  static Color get textoHint  => _isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8);
}

// ─── Top-level helpers ───────────────────────────────────────────────────────

IconData _iconCategoria(String cat) {
  switch (cat.toLowerCase()) {
    case 'corte': case 'pelo': case 'peluqueria': return Icons.content_cut_rounded;
    case 'color': case 'tinte':                    return Icons.color_lens_rounded;
    case 'manicura': case 'pedicura':              return Icons.spa_rounded;
    case 'masaje':                                  return Icons.self_improvement_rounded;
    case 'facial':                                  return Icons.face_retouching_natural_rounded;
    case 'tatuaje':                                 return Icons.brush_rounded;
    case 'comida': case 'plato':                   return Icons.restaurant_rounded;
    default:                                        return Icons.star_rounded;
  }
}

Widget _encabezadoSeccion(String titulo, IconData icon, VoidCallback onVerTodos) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Icon(icon, size: 18, color: _C.texto),
        const SizedBox(width: 8),
        Expanded(child: Text(titulo,
            style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w700))),
        GestureDetector(
          onTap: onVerTodos,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Ver todos', style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _C.accent),
          ]),
        ),
      ]),
    );

Widget _vacio(String msg, IconData icon) => Center(
  child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: _C.textoHint.withValues(alpha: 0.4)),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: _C.textoMuted, fontSize: 14), textAlign: TextAlign.center),
    ])));

Widget _resumenRating(double rating, String label, int? numResenas, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.grisOscuro, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Text(rating.toStringAsFixed(1), style: TextStyle(
            fontSize: 42, fontWeight: FontWeight.w900, color: color, height: 1)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(5, (i) => Icon(
              i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20, color: i < rating.round() ? color : _C.grisClaro))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _C.textoMuted, fontSize: 12, fontWeight: FontWeight.w500)),
          if (numResenas != null) ...[
            const SizedBox(height: 2),
            Text('$numResenas ${numResenas == 1 ? 'reseña' : 'reseñas'}',
                style: TextStyle(color: _C.textoHint, fontSize: 11)),
          ],
        ])),
      ]));

Color _colorNombreResena(String? hex) {
  if (hex == null) return _C.texto;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _C.texto; }
}

Widget _badgeMarco(String? marco) {
  if (marco == null) return const SizedBox.shrink();
  final emoji = switch (marco) { 'platino' => '💎', 'oro' => '🥇', _ => '🟤' };
  return Padding(padding: const EdgeInsets.only(left: 4),
      child: Text(emoji, style: TextStyle(fontSize: 12)));
}

// ═══════════════════════════════════════════════════════════════════
// DETALLE NEGOCIO
// ═══════════════════════════════════════════════════════════════════
class DetalleNegocioScreen extends StatefulWidget {
  final NegocioPublico negocio;
  const DetalleNegocioScreen({super.key, required this.negocio});

  @override
  State<DetalleNegocioScreen> createState() => _DetalleNegocioScreenState();
}

// ── Definición de tab dinámica ────────────────────────────────────────────────
class _TabDef {
  final String id;
  final IconData icon;
  final String label;
  const _TabDef(this.id, this.icon, this.label);
}

class _DetalleNegocioScreenState extends State<DetalleNegocioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  late List<_TabDef> _tabDefs;

  // Categorías de tipo servicio (cita con profesional)
  static const _catsServicio = ['peluquerias','esteticas','clinicas','gimnasios'];
  // Categorías de tipo mesa/espacio
  static const _catsMesa = ['restaurantes','bares','hoteles'];

  bool get _esServicio => _catsServicio.contains(widget.negocio.categoria.name.toLowerCase());
  bool get _esMesa     => _catsMesa.contains(widget.negocio.categoria.name.toLowerCase());

  @override
  void initState() {
    super.initState();
    _tabDefs = _calcularTabs();
    _tc = TabController(length: _tabDefs.length, vsync: this);
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
  }

  List<_TabDef> _calcularTabs() {
    final vis = widget.negocio.seccionesVisibles;
    bool tabOn(String id) => vis == null || (vis[id] ?? true);

    final tabs = [const _TabDef('resumen', Icons.home_rounded, 'Resumen')];

    if (_esServicio) {
      if (tabOn('servicios'))
        tabs.add(const _TabDef('servicios', Icons.content_cut_rounded, 'Servicios'));
    } else {
      if (tabOn('servicios'))
        tabs.add(const _TabDef('reservar', Icons.calendar_today_rounded, 'Reservar'));
      if (!_esMesa && tabOn('servicios'))
        tabs.add(const _TabDef('servicios', Icons.content_cut_rounded, 'Servicios'));
    }

    if (tabOn('resenas'))   tabs.add(const _TabDef('resenas',   Icons.star_rounded,          'Reseñas'));
    if (tabOn('productos')) tabs.add(const _TabDef('productos', Icons.shopping_bag_outlined,  'Productos'));
    if (tabOn('equipo'))    tabs.add(const _TabDef('equipo',    Icons.people_outline,         'Equipo'));
    if (tabOn('galeria'))   tabs.add(const _TabDef('galeria',   Icons.photo_library_rounded,  'Galería'));
    if (tabOn('ofertas'))   tabs.add(const _TabDef('ofertas',   Icons.local_offer_outlined,   'Ofertas'));
    if (tabOn('politicas')) tabs.add(const _TabDef('politicas', Icons.shield_outlined,        'Políticas'));

    return tabs;
  }

  int _idxTab(String id) => _tabDefs.indexWhere((t) => t.id == id);

  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  void _abrirReserva() {
    if (_esServicio) {
      // Va al tab Servicios (que tiene booking integrado)
      _tc.animateTo(_idxTab('servicios'));
    } else {
      mostrarBookingSheet(context, widget.negocio);
    }
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDark);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = AppSettings.darkMode.value;
    final n = widget.negocio;
    final w = MediaQuery.sizeOf(context).width;

    // Desktop: 2 columnas
    if (w >= 900) {
      return Scaffold(
        backgroundColor: _C.fondo,
        body: Row(children: [
          SizedBox(width: 340, child: SingleChildScrollView(child: _buildHeader(n))),
          const VerticalDivider(width: 1),
          Expanded(child: Column(children: [
            _buildTabBar(),
            Expanded(child: TabBarView(controller: _tc, children: _buildTabWidgets(n))),
          ])),
        ]),
      );
    }

    // Móvil / tablet: header hace scroll, tab bar se queda sticky
    return Scaffold(
      backgroundColor: _C.fondo,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(n)),
        ],
        body: Column(children: [
          _buildTabBar(),
          Expanded(child: TabBarView(
            controller: _tc,
            children: _buildTabWidgets(n),
          )),
        ]),
      ),
    );
  }

  List<Widget> _buildTabWidgets(NegocioPublico n) => _tabDefs.map((t) => switch (t.id) {
    'resumen'   => _TabResumen(negocio: n,
        onReservar:    _abrirReserva,
        onVerServicios: () => _idxTab('servicios') >= 0 ? _tc.animateTo(_idxTab('servicios')) : null,
        onVerResenas:  () => _tc.animateTo(_idxTab('resenas')),
        onVerGaleria:  () => _tc.animateTo(_idxTab('galeria'))),
    'reservar'  => _TabReservarMesa(negocio: n),
    'servicios' => _esServicio
        ? TabReservasScreen(negocio: n)   // flow completo con cita
        : _TabServicios(negocio: n),      // solo catálogo
    'resenas'   => _TabResenas(negocio: n),
    'productos' => _TabProductos(negocio: n),
    'equipo'    => _TabProfesionales(negocio: n),
    'galeria'   => _TabGaleria(negocio: n),
    'ofertas'   => _TabPromociones(negocio: n),
    'politicas' => _TabPolitica(negocio: n),
    _           => const SizedBox.shrink(),
  }).toList();

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader(NegocioPublico n) {
    final abierto = _estaAbiertoAhora(n);
    final rating  = n.ratingGoogle ?? n.ratingFluix;
    final desc    = n.descripcionCorta ?? n.descripcion;
    final telefono = n.telefono;
    final whatsapp = n.whatsapp;
    final web = n.website ?? n.web;

    return ColoredBox(
      color: _C.grisMedio,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Hero image ─────────────────────────────────────────────
        Stack(children: [
          SizedBox(
            width: double.infinity, height: 220,
            child: n.fotoUrl != null && n.fotoUrl!.isNotEmpty
                ? Image.network(n.fotoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _heroPlaceholder())
                : _heroPlaceholder(),
          ),
          // Gradient overlay
          Positioned(bottom: 0, left: 0, right: 0, child: Container(
            height: 100,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            )),
          )),
          // Back button
          SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              _circleBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
              const Spacer(),
              _circleBtn(Icons.share_rounded, () => _compartirWhatsApp(n)),
            ]),
          )),
          // Abierto / Cerrado badge
          if (n.horarios != null || n.horario != null)
            Positioned(bottom: 12, left: 16, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: abierto ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(abierto ? 'Abierto ahora' : 'Cerrado',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            )),
        ]),

        // ── Nombre + categoría + rating ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Categoría + rating
            Row(children: [
              _badgeCategoria(n),
              const Spacer(),
              if (rating != null) Row(children: [
                const Icon(Icons.star_rounded, size: 14, color: _C.oro),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _C.texto)),
                if (n.numResenas != null)
                  Text('  (${n.numResenas})',
                      style: TextStyle(fontSize: 11, color: _C.textoMuted)),
              ]),
            ]),
            const SizedBox(height: 7),
            // Nombre
            Text(n.nombre, style: TextStyle(
                fontSize: 23, fontWeight: FontWeight.w900, color: _C.texto, height: 1.1)),
            // Descripción
            if (desc != null && desc.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(desc, style: TextStyle(fontSize: 13, color: _C.textoMuted, height: 1.45),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            // Horario hoy
            if (n.horarios != null || n.horario != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _mostrarHorario(n),
                child: Row(children: [
                  Icon(Icons.access_time_rounded, size: 13, color: _C.textoMuted),
                  const SizedBox(width: 5),
                  Text(_horarioHoy(n),
                      style: TextStyle(fontSize: 12, color: _C.textoMuted)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _C.textoHint),
                ]),
              ),
            ],
          ]),
        ),

        // ── Botones de acción ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 0, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // Reservar (principal)
              _btnAccionPrimario(
                label: n.textoBotonReserva?.isNotEmpty == true ? n.textoBotonReserva! : 'Reservar',
                icon: Icons.calendar_today_rounded,
                onTap: _abrirReserva,
              ),
              if (telefono != null) ...[
                const SizedBox(width: 8),
                _btnAccion(label: 'Llamar', icon: Icons.phone_rounded, onTap: () => _llamar(n)),
              ],
              if (whatsapp != null) ...[
                const SizedBox(width: 8),
                _btnAccion(label: 'WhatsApp', icon: Icons.chat_rounded, onTap: () => _abrirWhatsapp(n)),
              ],
              if (n.direccion != null) ...[
                const SizedBox(width: 8),
                _btnAccion(label: 'Cómo llegar', icon: Icons.directions_rounded, onTap: () => _abrirMapa(n)),
              ],
              if (web != null) ...[
                const SizedBox(width: 8),
                _btnAccion(label: 'Web', icon: Icons.language_rounded, onTap: () => _abrirWeb(web)),
              ],
              const SizedBox(width: 16),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Info Row (ahora vacío, todo va en el header) ──────────────
  Widget _buildInfoRow(NegocioPublico n) => const SizedBox.shrink();

  // ── Helpers del header ────────────────────────────────────────
  Widget _heroPlaceholder() => ColoredBox(
    color: _C.grisOscuro,
    child: Center(child: Icon(Icons.store_rounded, size: 56, color: _C.textoHint)),
  );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: 15, color: _C.texto),
    ),
  );

  Widget _btnAccionPrimario({required String label, required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(22)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );

  Widget _btnAccion({required String label, required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _C.grisMedio,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _C.grisClaro, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: _C.texto),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: _C.texto, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ),
      );

  // ── Tab Bar ──────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: _C.grisMedio,
    child: Column(children: [
      Divider(height: 1, color: _C.grisClaro),
      TabBar(
        controller: _tc,
        indicatorColor: _C.accent,
        indicatorWeight: 2.5,
        labelColor: _C.accent,
        unselectedLabelColor: _C.textoMuted,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        tabs: _tabDefs.map((t) => Tab(icon: Icon(t.icon, size: 16), text: t.label)).toList(),
      ),
    ]),
  );

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _badgeCategoria(NegocioPublico n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _C.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(n.categoria.icono, style: TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text(n.categoria.label,
          style: TextStyle(color: _C.accent, fontWeight: FontWeight.w600, fontSize: 11)),
    ]),
  );

  String _horarioHoy(NegocioPublico n) {
    final hoyIdx = DateTime.now().weekday;
    if (n.horarios != null) {
      final h = n.horarios![hoyIdx - 1];
      if (h == null) return 'Ver horario';
      if (!h.abierto) return 'Cerrado hoy';
      return h.textoHorario;
    }
    if (n.horario != null) {
      const dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
      final h = n.horario![dias[hoyIdx - 1]];
      if (h == null) return 'Ver horario';
      if (h['cerrado'] == true) return 'Cerrado hoy';
      final ap = h['apertura'] as String? ?? '';
      final ci = h['cierre'] as String? ?? '';
      return ap.isNotEmpty && ci.isNotEmpty ? '$ap – $ci' : 'Ver horario';
    }
    return 'Ver horario';
  }

  void _mostrarHorario(NegocioPublico n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModalHorario(negocio: n),
    );
  }

  Future<void> _abrirMapa(NegocioPublico n) async {
    if (n.direccion == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(n.direccion!)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _llamar(NegocioPublico n) async {
    if (n.telefono == null) return;
    final uri = Uri.parse('tel:${n.telefono}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _compartirWhatsApp(NegocioPublico n) async {
    final sb = StringBuffer();
    sb.write('*${n.nombre}*');
    final desc = n.descripcionCorta ?? n.descripcion;
    if (desc != null && desc.isNotEmpty) sb.write('\n\n$desc');
    if (n.direccion != null) sb.write('\n\n📍 ${n.direccion}');
    if (n.telefono != null)  sb.write('\n📞 ${n.telefono}');
    final w = n.website ?? n.web;
    if (w != null && w.isNotEmpty) sb.write('\n🌐 $w');
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeQueryComponent(sb.toString())}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirWhatsapp(NegocioPublico n) async {
    if (n.whatsapp == null) return;
    final num = n.whatsapp!.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$num');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirWeb(String url) async {
    final raw = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(raw);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _estaAbiertoAhora(NegocioPublico n) {
    final ahora = TimeOfDay.now();
    final hoyIdx = DateTime.now().weekday - 1; // 0=lunes
    HorarioDia? h;
    if (n.horarios != null) {
      h = n.horarios![hoyIdx];
    } else if (n.horario != null) {
      const dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
      final raw = n.horario![dias[hoyIdx]];
      if (raw != null && raw['cerrado'] != true) {
        final apStr = raw['apertura'] as String? ?? '';
        final ciStr = raw['cierre'] as String? ?? '';
        final ap = _parseHora(apStr);
        final ci = _parseHora(ciStr);
        if (ap != null && ci != null) {
          return _horaEntre(ahora, ap, ci);
        }
      }
      return false;
    }
    if (h == null || !h.abierto) return false;
    final ap = _parseHora(h.horaApertura ?? '');
    final ci = _parseHora(h.horaCierre ?? '');
    if (ap == null || ci == null) return false;
    return _horaEntre(ahora, ap, ci);
  }

  TimeOfDay? _parseHora(String s) {
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _horaEntre(TimeOfDay t, TimeOfDay desde, TimeOfDay hasta) {
    final tMin = t.hour * 60 + t.minute;
    final dMin = desde.hour * 60 + desde.minute;
    final hMin = hasta.hour * 60 + hasta.minute;
    return tMin >= dMin && tMin < hMin;
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODAL HORARIO
// ═══════════════════════════════════════════════════════════════════
class _ModalHorario extends StatelessWidget {
  final NegocioPublico negocio;
  const _ModalHorario({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _C.grisClaro, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.access_time_rounded, color: _C.accent, size: 18)),
          const SizedBox(width: 10),
          Text('Horario', style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        _buildHorariosWidget(),
      ]),
    );
  }

  Widget _buildHorariosWidget() {
    final List<({String dia, String texto, bool cerrado})> filas = [];
    final n = negocio;
    if (n.horario != null && n.horario!.isNotEmpty) {
      const orden = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
      for (final dia in orden) {
        final h = n.horario![dia]; if (h == null) continue;
        final cerrado = h['cerrado'] == true;
        final ap = h['apertura'] as String? ?? '';
        final ci = h['cierre'] as String? ?? '';
        final apt = h['apertura_tarde'] as String?;
        final cit = h['cierre_tarde'] as String?;
        String texto;
        if (cerrado) { texto = 'Cerrado'; }
        else if (ap.isNotEmpty && ci.isNotEmpty) {
          texto = apt != null && cit != null ? '$ap–$ci / $apt–$cit' : '$ap–$ci';
        } else { texto = 'Abierto'; }
        filas.add((dia: dia.substring(0, 3), texto: texto, cerrado: cerrado));
      }
    } else if (n.horarios != null) {
      const dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
      for (int i = 0; i < 7; i++) {
        final h = n.horarios![i]; if (h == null) continue;
        filas.add((dia: dias[i], texto: h.textoHorario, cerrado: !h.abierto));
      }
    }
    if (filas.isEmpty) return Text('Sin horario disponible',
        style: TextStyle(color: _C.textoMuted));
    final hoyIdx = DateTime.now().weekday;
    return Column(children: filas.asMap().entries.map((e) {
      final esHoy = (e.key + 1) == hoyIdx;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: esHoy ? _C.accent.withValues(alpha: 0.08) : _C.grisOscuro,
          borderRadius: BorderRadius.circular(8),
          border: esHoy ? Border.all(color: _C.accent.withValues(alpha: 0.35)) : null,
        ),
        child: Row(children: [
          SizedBox(width: 36, child: Text(e.value.dia, style: TextStyle(
              color: esHoy ? _C.accent : _C.textoMuted,
              fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400, fontSize: 13))),
          Expanded(child: Text(e.value.texto,
              style: TextStyle(color: e.value.cerrado ? _C.textoHint : _C.texto, fontSize: 13))),
          if (esHoy && !e.value.cerrado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(4)),
              child: Text('Hoy', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
        ]),
      );
    }).toList());
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — RESUMEN (overview con servicios + reseñas + galería + CTA)
// ═══════════════════════════════════════════════════════════════════
class _TabResumen extends StatelessWidget {
  final NegocioPublico negocio;
  final VoidCallback onReservar;
  final VoidCallback onVerServicios;
  final VoidCallback onVerResenas;
  final VoidCallback onVerGaleria;

  const _TabResumen({
    required this.negocio,
    required this.onReservar,
    required this.onVerServicios,
    required this.onVerResenas,
    required this.onVerGaleria,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 20),
        _SeccionServicios(negocio: negocio, onVerTodos: onVerServicios),
        const SizedBox(height: 24),
        _SeccionResenas(negocio: negocio, onVerTodos: onVerResenas),
        const SizedBox(height: 24),
        _SeccionGaleria(negocio: negocio, onVerTodos: onVerGaleria),
        const SizedBox(height: 24),
        _BannerReservar(onReservar: onReservar),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Sección servicios destacados ─────────────────────────────────
class _SeccionServicios extends StatelessWidget {
  final NegocioPublico negocio;
  final VoidCallback onVerTodos;
  const _SeccionServicios({required this.negocio, required this.onVerTodos});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezadoSeccion('Servicios', Icons.content_cut_rounded, onVerTodos),
      const SizedBox(height: 12),
      if (negocio.empresaIdVinculada.isNotEmpty)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(negocio.empresaIdVinculada)
              .collection('servicios')
              .orderBy('nombre')
              .limit(4)
              .snapshots(),
          builder: (_, snap) {
            final docs = (snap.data?.docs ?? [])
                .where((d) => (d.data() as Map)['activo'] != false)
                .toList();
            if (docs.isEmpty) return _fallbackServicios();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TarjetaServicio(data: d, onReservar: onVerTodos),
                );
              }).toList()),
            );
          },
        )
      else
        _fallbackServicios(),
    ]);
  }

  Widget _fallbackServicios() {
    final items = [...(negocio.serviciosDestacados ?? []), ...(negocio.especialidades ?? [])];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: items.take(3).map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TarjetaServicio(data: {'nombre': s, 'activo': true}, onReservar: onVerTodos),
      )).toList()),
    );
  }
}

class _TarjetaServicioCompacta extends StatelessWidget {
  final String nombre;
  final IconData icon;
  final int? duracion;
  final dynamic precio;
  final dynamic precioDesde;
  final String? imagenUrl;

  const _TarjetaServicioCompacta({
    required this.nombre,
    required this.icon,
    this.duracion,
    this.precio,
    this.precioDesde,
    this.imagenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final precioTexto = precio != null
        ? '${(precio as num).toStringAsFixed(0)} €'
        : precioDesde != null
            ? '${(precioDesde as num).toStringAsFixed(0)} €'
            : null;

    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.grisClaro),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _C.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: imagenUrl != null && imagenUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(imagenUrl!, width: 26, height: 26, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(icon, size: 22, color: _C.accent)))
              : Icon(icon, size: 22, color: _C.accent),
        ),
        const SizedBox(height: 8),
        Text(nombre,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.texto),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Row(children: [
          if (duracion != null) ...[
            Icon(Icons.access_time_rounded, size: 10, color: _C.textoHint),
            const SizedBox(width: 3),
            Text('${duracion}min', style: TextStyle(fontSize: 10, color: _C.textoHint)),
            const SizedBox(width: 6),
          ],
          if (precioTexto != null)
            Text(precioTexto,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.accent)),
        ]),
      ]),
    );
  }
}

// ── Sección últimas reseñas ──────────────────────────────────────
class _SeccionResenas extends StatelessWidget {
  final NegocioPublico negocio;
  final VoidCallback onVerTodos;
  const _SeccionResenas({required this.negocio, required this.onVerTodos});

  @override
  Widget build(BuildContext context) {
    if (negocio.empresaIdVinculada.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezadoSeccion('Últimas reseñas', Icons.star_rounded, onVerTodos),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas').doc(negocio.empresaIdVinculada)
            .collection('valoraciones')
            .orderBy('fecha', descending: true)
            .limit(6)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox.shrink();
          final toShow = docs.take(2).toList();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Row(
                children: toShow.asMap().entries.map((e) {
                  final d = e.value.data() as Map<String, dynamic>;
                  return Expanded(child: Padding(
                    padding: EdgeInsets.only(
                        right: e.key == 0 ? 6 : 0,
                        left: e.key == 1 ? 6 : 0),
                    child: _TarjetaResenaCompacta(data: d),
                  ));
                }).toList(),
              ),
              if (docs.length > 2) ...[
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 20, height: 6,
                      decoration: BoxDecoration(color: _C.accent,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: _C.grisClaro,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: _C.grisClaro,
                          borderRadius: BorderRadius.circular(3))),
                ]),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}

class _TarjetaResenaCompacta extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TarjetaResenaCompacta({required this.data});

  @override
  Widget build(BuildContext context) {
    final texto     = data['texto'] ?? data['comentario'] ?? '';
    final estrellas = (data['estrellas'] as num?)?.toDouble() ?? 5;
    final isGoogle  = data['origen'] == 'google';
    final ts        = data['fecha'] as Timestamp?;
    final fecha     = ts?.toDate();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.grisClaro),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isGoogle
                  ? const Color(0xFF4285F4).withValues(alpha: 0.10)
                  : _C.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              isGoogle ? Icons.g_mobiledata_rounded : Icons.star_rounded,
              size: 18,
              color: isGoogle ? const Color(0xFF4285F4) : _C.accent,
            ),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isGoogle ? 'Google' : 'Fluix',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.texto)),
            Row(children: List.generate(5, (i) => Icon(
                i < estrellas.round() ? Icons.star_rounded : Icons.star_border_rounded,
                size: 10, color: _C.oro))),
          ]),
        ]),
        const SizedBox(height: 8),
        Text('"$texto"',
            style: TextStyle(fontSize: 11, color: _C.textoMuted,
                height: 1.4, fontStyle: FontStyle.italic),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        if (fecha != null) ...[
          const SizedBox(height: 6),
          Text(_fmtFecha(fecha),
              style: TextStyle(fontSize: 10, color: _C.textoHint)),
        ],
      ]),
    );
  }

  String _fmtFecha(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays == 0) return 'Hoy';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    if (d.inDays < 30) return 'Hace ${(d.inDays / 7).round()} semanas';
    return 'Hace ${(d.inDays / 30).round()} meses';
  }
}

// ── Sección galería destacada ─────────────────────────────────────
class _SeccionGaleria extends StatelessWidget {
  final NegocioPublico negocio;
  final VoidCallback onVerTodos;
  const _SeccionGaleria({required this.negocio, required this.onVerTodos});

  @override
  Widget build(BuildContext context) {
    final fotos = negocio.fotosGaleria ?? [];
    if (fotos.isEmpty) return const SizedBox.shrink();
    final mostrar = fotos.take(5).toList();
    final extras  = fotos.length - 5;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezadoSeccion('Galería destacada', Icons.photo_library_rounded, onVerTodos),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: mostrar.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final isLast = i == mostrar.length - 1 && extras > 0;
            return GestureDetector(
              onTap: onVerTodos,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(children: [
                  Image.network(mostrar[i], width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(width: 100, height: 100, color: _C.grisOscuro,
                              child: Icon(Icons.broken_image_outlined,
                                  color: _C.textoHint, size: 24))),
                  if (isLast)
                    Container(
                      width: 100, height: 100,
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                        const SizedBox(height: 4),
                        Text('+$extras fotos',
                            style: TextStyle(color: Colors.white,
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Banner CTA reservar ───────────────────────────────────────────
class _BannerReservar extends StatelessWidget {
  final VoidCallback onReservar;
  const _BannerReservar({required this.onReservar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _C.accent, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Listo para tu próxima cita?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text('Reserva ahora y disfruta de una experiencia única.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReservar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Reservar',
                    style: TextStyle(color: _C.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded, color: _C.accent, size: 10),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — RESEÑAS
// ═══════════════════════════════════════════════════════════════════
class _TabResenas extends StatefulWidget {
  final NegocioPublico negocio;
  const _TabResenas({required this.negocio});

  @override
  State<_TabResenas> createState() => _TabResenasState();
}

class _TabResenasState extends State<_TabResenas>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tc,
          indicatorColor: _C.accent,
          indicatorWeight: 2,
          labelColor: _C.accent,
          unselectedLabelColor: _C.textoMuted,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            _subTab('Google', Icons.g_mobiledata_rounded, widget.negocio.ratingGoogle),
            _subTab('Fluix', Icons.star_rounded, widget.negocio.ratingFluix),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tc, children: [
        _ListaResenasGoogle(negocio: widget.negocio),
        _ListaResenasFluix(negocio: widget.negocio),
      ])),
    ]);
  }

  Tab _subTab(String label, IconData icon, double? rating) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16),
      const SizedBox(width: 4),
      Text(label),
      if (rating != null) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: _C.grisClaro, borderRadius: BorderRadius.circular(8)),
          child: Text(rating.toStringAsFixed(1),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ]),
  );
}

class _ListaResenasGoogle extends StatelessWidget {
  final NegocioPublico negocio;
  const _ListaResenasGoogle({required this.negocio});

  @override
  Widget build(BuildContext context) {
    if (negocio.empresaIdVinculada.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        if (negocio.ratingGoogle != null) ...[
          _resumenRating(negocio.ratingGoogle!, 'Google Reviews',
              negocio.numResenas, const Color(0xFF4285F4)),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            Icon(Icons.rate_review_outlined, size: 36, color: _C.textoHint),
            const SizedBox(height: 8),
            Text(negocio.ratingGoogle != null
                ? '${negocio.ratingGoogle!.toStringAsFixed(1)}★ en Google · ${negocio.numResenas ?? 0} reseñas'
                : 'Sin reseñas de Google todavía',
                style: TextStyle(color: _C.textoMuted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Las reseñas detalladas se sincronizan con Google My Business',
                style: TextStyle(color: _C.textoHint, fontSize: 11),
                textAlign: TextAlign.center),
          ]),
        ),
      ]);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(negocio.empresaIdVinculada)
          .collection('valoraciones')
          .where('origen', isEqualTo: 'google')
          .orderBy('fecha', descending: true)
          .limit(30)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = snap.data?.docs ?? [];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          if (negocio.ratingGoogle != null) ...[
            _resumenRating(negocio.ratingGoogle!, 'Google Reviews',
                negocio.numResenas, const Color(0xFF4285F4)),
            const SizedBox(height: 16),
          ],
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Icon(Icons.rate_review_outlined, size: 36, color: _C.textoHint),
                const SizedBox(height: 8),
                Text(negocio.ratingGoogle != null
                    ? '${negocio.ratingGoogle!.toStringAsFixed(1)}★ en Google'
                    : 'Sin reseñas de Google todavía',
                    style: TextStyle(color: _C.textoMuted, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Se sincronizan con Google My Business',
                    style: TextStyle(color: _C.textoHint, fontSize: 11),
                    textAlign: TextAlign.center),
              ]),
            )
          else
            ...docs.map((d) => _TarjetaResena(data: d.data() as Map<String, dynamic>)),
        ]);
      },
    );
  }
}

class _ListaResenasFluix extends StatefulWidget {
  final NegocioPublico negocio;
  const _ListaResenasFluix({required this.negocio});

  @override
  State<_ListaResenasFluix> createState() => _ListaResenasFluixState();
}

class _ListaResenasFluixState extends State<_ListaResenasFluix> {
  final _scrollCtrl = ScrollController();
  String get _colRef => 'empresas/${widget.negocio.empresaIdVinculada}/valoraciones';

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _mostrarFormulario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { FluxToast.aviso(context, 'Inicia sesión para dejar una reseña'); return; }
    final empresaId = widget.negocio.empresaIdVinculada;
    if (empresaId.isEmpty) {
      FluxToast.aviso(context, 'Este negocio no tiene perfil verificado para reseñas'); return;
    }
    final ref = FirebaseFirestore.instance
        .collection('empresas').doc(empresaId).collection('reservas');
    final snap1 = await ref.where('usuario_uid', isEqualTo: uid).limit(1).get();
    final snap  = snap1.docs.isNotEmpty
        ? snap1 : await ref.where('cliente_uid', isEqualTo: uid).limit(1).get();
    if (!mounted) return;
    if (snap.docs.isEmpty) {
      FluxToast.aviso(context, 'Solo puedes reseñar negocios donde has reservado',
          title: 'Reserva primero'); return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _FormularioResena(negocio: widget.negocio, uid: uid, colRef: _colRef),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.negocio.empresaIdVinculada.isEmpty) {
      return _vacio('Sin reseñas Fluix todavía', Icons.star_border_rounded);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(_colRef)
          .where('origen', isEqualTo: 'fluix').limit(50).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = <QueryDocumentSnapshot>[...(snap.data?.docs ?? [])]
          ..sort((a, b) {
            final ta = (a.data() as Map)['fecha'] as Timestamp?;
            final tb = (b.data() as Map)['fecha'] as Timestamp?;
            if (ta == null) return 1; if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        return Stack(children: [
          ListView(controller: _scrollCtrl, primary: false,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            if (docs.isNotEmpty) ...[
              _resumenFluix(docs),
              const SizedBox(height: 16),
              _CarruselResenas(docs: docs),
              const SizedBox(height: 20),
              Divider(color: _C.grisClaro),
              const SizedBox(height: 16),
              Text('Todas las reseñas',
                  style: TextStyle(color: _C.texto, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...docs.map((d) => _TarjetaResena(data: d.data() as Map<String, dynamic>)),
            ] else _vacio('Sé el primero en valorar este negocio', Icons.star_border_rounded),
          ]),
          Positioned(bottom: 16, right: 16,
            child: FloatingActionButton.extended(
              onPressed: _mostrarFormulario,
              backgroundColor: _C.accentRosa, foregroundColor: Colors.white,
              icon: Icon(Icons.rate_review_rounded, size: 18),
              label: Text('Añadir reseña',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ]);
      },
    );
  }

  Widget _resumenFluix(List<QueryDocumentSnapshot> docs) {
    final total = docs.length;
    final media = docs.fold<double>(0,
        (s, d) => s + ((d.data() as Map)['estrellas'] as num? ?? 0).toDouble()) / total;
    return _resumenRating(media, 'Fluix Rating', total, _C.accent);
  }
}

class _CarruselResenas extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  const _CarruselResenas({required this.docs});
  @override
  State<_CarruselResenas> createState() => _CarruselResenasState();
}

class _CarruselResenasState extends State<_CarruselResenas> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _pagina = 0;
  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 240,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.docs.length,
          onPageChanged: (i) => setState(() => _pagina = i),
          itemBuilder: (_, i) => _TarjetaCarruselResena(
              data: widget.docs[i].data() as Map<String, dynamic>,
              activa: i == _pagina),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.docs.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _pagina ? 20 : 6, height: 6,
            decoration: BoxDecoration(
              color: i == _pagina ? _C.accent : _C.grisClaro,
              borderRadius: BorderRadius.circular(3)),
          ))),
    ]);
  }
}

class _TarjetaCarruselResena extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool activa;
  const _TarjetaCarruselResena({required this.data, required this.activa});

  @override
  Widget build(BuildContext context) {
    final autor     = data['autor'] ?? data['autorNombre'] ?? data['clienteNombre'] ?? 'Anónimo';
    final texto     = data['texto'] ?? data['comentario'] ?? '';
    final estrellas = (data['estrellas'] as num?)?.toDouble() ?? 0;
    final avatarUrl = data['avatarUrl'] ?? data['autorAvatarUrl'] as String?;
    final servicio  = data['servicio'] ?? data['servicioUsado'] as String?;
    final verificado = data['verificado'] as bool? ?? false;
    final respuesta = data['respuesta'] as String?;
    final ts        = data['fecha'] as Timestamp?;
    final fecha     = ts?.toDate();

    return AnimatedScale(
      scale: activa ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.grisMedio, borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: activa ? _C.accent.withValues(alpha: 0.35) : _C.grisClaro,
              width: activa ? 1.5 : 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(nombre: autor, avatarUrl: avatarUrl, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (data['destacada'] == true)
                  Padding(padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFFFB830))),
                Expanded(child: Text(autor,
                    style: TextStyle(
                        color: _colorNombreResena(data['autor_color'] as String?),
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
                _badgeMarco(data['autor_marco'] as String?),
                if (verificado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _C.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, color: _C.accent, size: 10),
                      SizedBox(width: 3),
                      Text('Verificado', style: TextStyle(
                          color: _C.accent, fontSize: 9, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 3),
              Row(children: List.generate(5, (i) => Icon(
                  i < estrellas.round() ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 14, color: _C.oro))),
            ])),
          ]),
          const SizedBox(height: 12),
          Expanded(child: Text('"$texto"',
              style: TextStyle(color: _C.textoMuted, fontSize: 13,
                  fontStyle: FontStyle.italic, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 8),
          Row(children: [
            if (servicio != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _C.accentRosa.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(servicio, style: TextStyle(
                    color: _C.accentRosa, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (fecha != null)
              Text(_fmtFecha(fecha), style: TextStyle(color: _C.textoHint, fontSize: 11)),
          ]),
          if (respuesta != null && respuesta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _C.grisOscuro, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.accent.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.storefront_rounded, size: 12, color: _C.accent),
                  SizedBox(width: 5),
                  Text('Respuesta del negocio',
                      style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(respuesta, style: TextStyle(
                    color: _C.textoMuted, fontSize: 12, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  String _fmtFecha(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays == 0) return 'Hoy';
    if (d.inDays == 1) return 'Ayer';
    if (d.inDays < 30) return 'Hace ${d.inDays} días';
    if (d.inDays < 365) return 'Hace ${(d.inDays / 30).round()} meses';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _FormularioResena extends StatefulWidget {
  final NegocioPublico negocio;
  final String uid;
  final String colRef;
  const _FormularioResena({required this.negocio, required this.uid, required this.colRef});
  @override
  State<_FormularioResena> createState() => _FormularioResenaState();
}

class _FormularioResenaState extends State<_FormularioResena> {
  final _nombreCtrl   = TextEditingController();
  final _comentCtrl   = TextEditingController();
  final _servicioCtrl = TextEditingController();
  double _estrellas   = 5;
  bool _guardando     = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) _nombreCtrl.text = user!.displayName!;
  }

  @override
  void dispose() { _nombreCtrl.dispose(); _comentCtrl.dispose(); _servicioCtrl.dispose(); super.dispose(); }

  bool get _puedeGuardar =>
      _nombreCtrl.text.trim().isNotEmpty && _comentCtrl.text.trim().isNotEmpty;

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() => _guardando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userSnap = await FirebaseFirestore.instance
          .collection('usuarios').doc(widget.uid).get();
      final ud = userSnap.data() ?? {};
      final anonimo  = (ud['canje_anonimo_usos'] as int? ?? 0) > 0;
      final firma    = ud['canje_firma'] as String?;
      final colorH   = ud['canje_color_nombre'] as String?;
      final destacada = ud['canje_resena_destacada'] as bool? ?? false;
      final marco    = ud['canje_marco'] as String?;
      final nombreFinal = anonimo ? 'Anónimo' : _nombreCtrl.text.trim();
      final textoFinal  = firma != null && firma.isNotEmpty
          ? '${_comentCtrl.text.trim()} $firma' : _comentCtrl.text.trim();

      await FirebaseFirestore.instance.collection(widget.colRef).add({
        'origen': 'fluix', 'uid': widget.uid, 'autor': nombreFinal,
        'texto': textoFinal, 'estrellas': _estrellas,
        'servicio': _servicioCtrl.text.trim().isEmpty ? null : _servicioCtrl.text.trim(),
        if (user?.photoURL != null && !anonimo) 'avatarUrl': user!.photoURL,
        'verificado': false, 'fecha': FieldValue.serverTimestamp(),
        'negocioId': widget.negocio.id, 'negocioNombre': widget.negocio.nombre,
        if (destacada) 'destacada': true,
        if (colorH != null) 'autor_color': colorH,
        if (marco != null) 'autor_marco': marco,
        if (anonimo) 'es_anonimo': true,
      });

      if (anonimo) await CanjeoService.consumirUso(widget.uid, 'modo_anonimo');
      if (destacada) await CanjeoService.consumirUso(widget.uid, 'resena_destacada');
      if (mounted) { Navigator.pop(context); FluxToast.exito(context, 'Reseña publicada. ¡Gracias!'); }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _C.grisClaro, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.star_rounded, color: _C.oro, size: 20),
          const SizedBox(width: 8),
          Text('Reseña para ${widget.negocio.nombre}',
              style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ...List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _estrellas = i + 1.0),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(i < _estrellas ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _C.oro, size: 36)),
          )),
          const SizedBox(width: 10),
          Text('${_estrellas.toInt()}/5',
              style: TextStyle(color: _C.oro, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        _campo(_nombreCtrl, 'Tu nombre *', 'Ej: María García'),
        const SizedBox(height: 10),
        TextField(
          controller: _comentCtrl, maxLines: 3, maxLength: 3000,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: _C.texto, fontSize: 13),
          decoration: _inputDec('Cuéntanos tu experiencia...'),
        ),
        const SizedBox(height: 10),
        _campo(_servicioCtrl, 'Servicio usado (opcional)', 'Ej: Corte y color'),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_puedeGuardar && !_guardando) ? _guardar : null,
            icon: _guardando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.negro))
                : Icon(Icons.send_rounded, size: 18),
            label: Text(_guardando ? 'Publicando...' : 'Publicar reseña',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: _C.accentRosa, foregroundColor: Colors.white,
              disabledBackgroundColor: _C.accentRosa.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, String hint) => TextField(
    controller: ctrl, onChanged: (_) => setState(() {}),
    style: TextStyle(color: _C.texto, fontSize: 13),
    decoration: _inputDec(hint).copyWith(
        labelText: label, labelStyle: TextStyle(color: _C.textoMuted, fontSize: 12)));

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: _C.textoHint, fontSize: 13),
    filled: true, fillColor: _C.fondo,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _C.grisClaro, width: 0.5)),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _C.accent, width: 1)),
    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide.none),
  );
}

class _TarjetaResena extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TarjetaResena({required this.data});

  @override
  Widget build(BuildContext context) {
    final autor      = data['autor'] ?? data['autorNombre'] ?? data['clienteNombre'] ?? 'Anónimo';
    final texto      = data['texto'] ?? data['comentario'] ?? data['resena'] ?? '';
    final estrellas  = (data['estrellas'] as num?)?.toDouble() ?? 0;
    final avatarUrl  = data['avatarUrl'] ?? data['autorAvatarUrl'] as String?;
    final servicio   = data['servicio'] ?? data['servicioUsado'] as String?;
    final verificado = data['verificado'] as bool? ?? false;
    final respuesta  = data['respuesta'] as String?;
    final ts         = data['fecha'] as Timestamp?;
    final fecha      = ts?.toDate();
    final tsResp     = data['fechaRespuesta'] as Timestamp?;
    final fechaResp  = tsResp?.toDate();
    final accentColor = estrellas >= 4 ? _C.accent : estrellas >= 3 ? _C.oro : _C.accentRosa;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(14)),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, decoration: BoxDecoration(color: accentColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Avatar(nombre: autor, avatarUrl: avatarUrl, size: 38),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(autor,
                          style: TextStyle(color: _C.texto, fontSize: 13, fontWeight: FontWeight.w700))),
                      if (verificado)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.verified_rounded, color: _C.accent, size: 10),
                            SizedBox(width: 3),
                            Text('Verificado', style: TextStyle(
                                color: _C.accent, fontSize: 9, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      ...List.generate(5, (i) => Icon(
                          i < estrellas.round() ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 13, color: i < estrellas.round() ? _C.oro : _C.grisClaro)),
                      const SizedBox(width: 6),
                      if (fecha != null)
                        Text(_fmtFecha(fecha), style: TextStyle(color: _C.textoHint, fontSize: 10)),
                    ]),
                  ])),
                ]),
                if ((texto as String).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(texto, style: TextStyle(color: _C.textoMuted, fontSize: 13, height: 1.5)),
                ],
                if (servicio != null && servicio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _C.accentRosa.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.accentRosa.withValues(alpha: 0.25))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.content_cut_rounded, size: 10, color: _C.accentRosa),
                      const SizedBox(width: 4),
                      Text(servicio, style: TextStyle(
                          color: _C.accentRosa, fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ),
            if (respuesta != null && respuesta.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _C.grisMedio, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.accent.withValues(alpha: 0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.storefront_rounded, size: 12, color: _C.accent),
                    const SizedBox(width: 5),
                    Text('Respuesta del negocio',
                        style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (fechaResp != null)
                      Text(_fmtFecha(fechaResp), style: TextStyle(color: _C.textoHint, fontSize: 10)),
                  ]),
                  const SizedBox(height: 6),
                  Text(respuesta, style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4)),
                ]),
              ),
          ])),
        ]),
      ),
    );
  }

  String _fmtFecha(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays == 0) return 'Hoy';
    if (d.inDays == 1) return 'Ayer';
    if (d.inDays < 30) return 'Hace ${d.inDays} días';
    if (d.inDays < 365) return 'Hace ${(d.inDays / 30).round()} meses';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Avatar extends StatelessWidget {
  final String nombre;
  final String? avatarUrl;
  final double size;
  const _Avatar({required this.nombre, required this.avatarUrl, required this.size});

  Color get _color {
    const colors = [Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055),
      Color(0xFF0984E3), Color(0xFFD63031), Color(0xFFFDAB3D)];
    return colors[nombre.isEmpty ? 0 : nombre.codeUnitAt(0) % colors.length];
  }

  String get _iniciales {
    final p = nombre.trim().split(' ');
    if (p.isEmpty || p[0].isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _color,
        border: Border.all(color: _C.grisClaro, width: 1.5),
        image: avatarUrl != null
            ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover,
                onError: (_, __) {})
            : null),
    child: avatarUrl == null
        ? Center(child: Text(_iniciales, style: TextStyle(
            color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.bold)))
        : null,
  );
}

// ═══════════════════════════════════════════════════════════════════
// TAB — SERVICIOS  (con filtros de categoría + diseño de la imagen)
// ═══════════════════════════════════════════════════════════════════
class _TabServicios extends StatefulWidget {
  final NegocioPublico negocio;
  const _TabServicios({required this.negocio});
  @override
  State<_TabServicios> createState() => _TabServiciosState();
}

class _TabServiciosState extends State<_TabServicios> {
  String? _catActiva; // null = Todos

  @override
  Widget build(BuildContext context) {
    if (widget.negocio.empresaIdVinculada.isEmpty) {
      return _vacio('Sin servicios disponibles aún', Icons.spa_outlined);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.negocio.empresaIdVinculada)
          .collection('servicios')
          .orderBy('nombre')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final todos = (snap.data?.docs ?? [])
            .map((d) => d.data() as Map<String, dynamic>)
            .where((d) => d['activo'] != false)
            .toList();

        if (todos.isEmpty) return _vacio('Sin servicios disponibles aún', Icons.spa_outlined);

        // Categorías únicas
        final cats = <String>[];
        for (final s in todos) {
          final c = (s['categoria'] as String? ?? '').trim();
          if (c.isNotEmpty && !cats.contains(c)) cats.add(c);
        }

        final filtrados = _catActiva == null
            ? todos
            : todos.where((s) => s['categoria'] == _catActiva).toList();

        return Column(children: [
          // ── Chips de categoría ──────────────────────────────────
          if (cats.isNotEmpty)
            Container(
              color: _C.grisMedio,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _catChip('Todos', _catActiva == null, () => setState(() => _catActiva = null)),
                    ...cats.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _catChip(c, _catActiva == c, () => setState(() => _catActiva = _catActiva == c ? null : c)),
                    )),
                  ],
                ),
              ),
            ),
          // ── Contador ────────────────────────────────────────────
          Container(
            color: _C.grisMedio,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Text('${filtrados.length} servicio${filtrados.length == 1 ? '' : 's'} disponible${filtrados.length == 1 ? '' : 's'}',
                  style: TextStyle(color: _C.textoMuted, fontSize: 12)),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFEEF2F7)),
          // ── Lista de servicios ───────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _TarjetaServicio(
                data: filtrados[i],
                onReservar: () {
                  final state = context.findAncestorStateOfType<_DetalleNegocioScreenState>();
                  if (state != null) state._abrirReserva();
                },
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _catChip(String label, bool activo, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: activo ? _C.accent : _C.grisMedio,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activo ? _C.accent : _C.grisClaro, width: activo ? 0 : 1),
      ),
      child: Text(label, style: TextStyle(
        color: activo ? Colors.white : _C.textoMuted,
        fontSize: 13, fontWeight: activo ? FontWeight.w700 : FontWeight.w500)),
    ),
  );
}

class _TarjetaServicio extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onReservar;
  const _TarjetaServicio({required this.data, this.onReservar});

  @override
  Widget build(BuildContext context) {
    final nombre      = data['nombre'] as String? ?? '';
    final desc        = data['descripcion'] as String? ?? '';
    final precio      = data['precio'];
    final precioDesde = data['precio_desde'];
    final duracion    = data['duracion'] as int?;
    final categoria   = data['categoria'] as String? ?? '';
    final imagenUrl   = data['imagen_url'] as String?;
    final activo      = data['activo'] as bool? ?? true;
    if (!activo) return const SizedBox.shrink();

    final precioTexto = precio != null
        ? '${(precio as num) % 1 == 0 ? (precio as num).toInt() : (precio as num).toStringAsFixed(2)} €'
        : precioDesde != null
            ? '${(precioDesde as num) % 1 == 0 ? (precioDesde as num).toInt() : (precioDesde as num).toStringAsFixed(2)} €'
            : null;

    return Container(
      decoration: BoxDecoration(
        color: _C.grisMedio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.grisClaro),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Imagen / icono ──────────────────────────────────────
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _C.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagenUrl != null && imagenUrl.isNotEmpty
                ? Image.network(imagenUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconPlaceholder(categoria))
                : _iconPlaceholder(categoria),
          ),
          const SizedBox(width: 14),
          // ── Contenido ───────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(nombre,
                  style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2))),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (duracion != null) ...[
                Icon(Icons.access_time_rounded, size: 13, color: _C.textoMuted),
                const SizedBox(width: 4),
                Text(_fmtDuracion(duracion), style: TextStyle(color: _C.textoMuted, fontSize: 12)),
                if (precioTexto != null)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('|', style: TextStyle(color: _C.grisClaro, fontSize: 12))),
              ],
              if (precioTexto != null)
                Text(precioTexto,
                    style: TextStyle(color: _C.accent, fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              // ── Botón Reservar ──────────────────────────────────
              GestureDetector(
                onTap: onReservar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Reservar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                  ]),
                ),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _iconPlaceholder(String categoria) => Center(
    child: Icon(_iconCat(categoria), size: 30, color: _C.accent),
  );

  String _fmtDuracion(int min) {
    if (min >= 60) { final h = min ~/ 60; final m = min % 60; return m > 0 ? '${h}h ${m}min' : '${h}h'; }
    return '${min}min';
  }

  IconData _iconCat(String cat) {
    switch (cat.toLowerCase()) {
      case 'corte': case 'pelo': case 'cortes': return Icons.content_cut_rounded;
      case 'color': case 'tinte':              return Icons.color_lens_rounded;
      case 'manicura': case 'pedicura':        return Icons.spa_rounded;
      case 'masaje': case 'masajes':           return Icons.self_improvement_rounded;
      case 'facial': case 'estetica':          return Icons.face_retouching_natural_rounded;
      case 'barba': case 'barberia':           return Icons.face_rounded;
      case 'cejas': case 'depilacion':         return Icons.auto_fix_high_rounded;
      default:                                  return Icons.star_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// (clase _TarjetaServicio anterior sustituida — bloque vacío guardado)
// ═══════════════════════════════════════════════════════════════════
class _TarjetaServicioOld extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TarjetaServicioOld({required this.data});

  @override
  Widget build(BuildContext context) {
    final nombre      = data['nombre'] as String? ?? '';
    final desc        = data['descripcion'] as String? ?? '';
    final precio      = data['precio'];
    final precioDesde = data['precio_desde'];
    final duracion    = data['duracion'] as int?;
    final categoria   = data['categoria'] as String? ?? '';
    final imagenUrl   = data['imagen_url'] as String?;
    final activo      = data['activo'] as bool? ?? true;
    if (!activo) return const SizedBox.shrink();

    final precioTexto = precio != null
        ? '€${(precio as num).toStringAsFixed(2)}'
        : precioDesde != null
            ? 'Desde €${(precioDesde as num).toStringAsFixed(2)}'
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.grisClaro)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: _C.grisMedio, borderRadius: BorderRadius.circular(10),
              image: imagenUrl != null && imagenUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(imagenUrl), fit: BoxFit.cover)
                  : null),
          child: imagenUrl == null || imagenUrl.isEmpty
              ? Center(child: Icon(_iconCategoria(categoria), size: 24, color: _C.accent))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: TextStyle(color: _C.texto, fontSize: 14, fontWeight: FontWeight.w600)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(desc, style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4)),
          ],
          if (duracion != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11, color: _C.textoHint),
              const SizedBox(width: 3),
              Text(duracion >= 60
                  ? '${duracion ~/ 60}h${duracion % 60 > 0 ? ' ${duracion % 60}min' : ''}'
                  : '${duracion}min',
                  style: TextStyle(color: _C.textoHint, fontSize: 11)),
            ]),
          ],
        ])),
        if (precioTexto != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.accent.withValues(alpha: 0.3))),
            child: Text(precioTexto,
                style: TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — GALERÍA
// ═══════════════════════════════════════════════════════════════════
class _TabGaleria extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabGaleria({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final fotos = negocio.fotosGaleria ?? [];
    if (fotos.isEmpty) return _vacio('Sin fotos en la galería aún', Icons.photo_library_outlined);
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3, childAspectRatio: 1),
      itemCount: fotos.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => showGeneralDialog(
          context: ctx,
          pageBuilder: (ctx2, _, __) => _VisorFotos(fotos: fotos, indiceInicial: i, negocioId: negocio.id),
        ),
        child: Hero(
          tag: 'galeria_${negocio.id}_$i',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.network(fotos[i], fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null ? child
                    : Container(color: _C.grisMedio,
                        child: Center(child: CircularProgressIndicator(
                            color: _C.accent, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(color: _C.grisMedio,
                    child: Icon(Icons.broken_image_outlined,
                        color: _C.textoHint, size: 24))),
          ),
        ),
      ),
    );
  }
}

class _VisorFotos extends StatefulWidget {
  final List<String> fotos;
  final int indiceInicial;
  final String negocioId;
  const _VisorFotos({required this.fotos, required this.indiceInicial, required this.negocioId});
  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
  late PageController _pc;
  late int _idx;
  @override
  void initState() { super.initState(); _idx = widget.indiceInicial; _pc = PageController(initialPage: widget.indiceInicial); }
  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_idx + 1} / ${widget.fotos.length}', style: TextStyle(color: Colors.white, fontSize: 14)),
        leading: IconButton(icon: Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.fotos.length,
        onPageChanged: (i) => setState(() => _idx = i),
        itemBuilder: (_, i) => Hero(
          tag: 'galeria_${widget.negocioId}_$i',
          child: InteractiveViewer(
            child: Center(child: Image.network(widget.fotos[i], fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48))),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — POLÍTICA
// ═══════════════════════════════════════════════════════════════════
class _TabPolitica extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabPolitica({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final tyc = negocio.terminosYCondiciones?.trim() ?? '';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 40), children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.gavel_rounded, color: _C.accent, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Términos y Condiciones',
              style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(negocio.nombre, style: TextStyle(color: _C.textoMuted, fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 20),
      if (tyc.isEmpty)
        Column(children: [
          Icon(Icons.description_outlined, size: 52, color: _C.textoHint.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Este negocio no ha publicado\ntérminos y condiciones todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textoMuted, fontSize: 14, height: 1.5)),
        ])
      else ...[
        Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.grisClaro, width: 0.5)),
          child: Text(tyc, style: TextStyle(color: _C.textoMuted, fontSize: 13, height: 1.7))),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.accent.withValues(alpha: 0.2))),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: _C.accent, size: 16),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Al confirmar una reserva aceptas estos términos y condiciones.',
              style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4))),
          ])),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — RESERVAR MESA (para bares, restaurantes, hoteles)
// ═══════════════════════════════════════════════════════════════════
class _TabReservarMesa extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabReservarMesa({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_rounded, color: _C.accent, size: 36)),
          const SizedBox(height: 20),
          Text(negocio.nombre,
              style: TextStyle(color: _C.texto, fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Reserva tu mesa en unos segundos',
              style: TextStyle(color: _C.textoMuted, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => mostrarBookingSheet(context, negocio),
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: const Text('Reservar mesa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: _C.accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          if (negocio.telefono != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('tel:${negocio.telefono}');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: Text('Llamar: ${negocio.telefono}', style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.accent,
                side: const BorderSide(color: _C.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — PRODUCTOS
// ═══════════════════════════════════════════════════════════════════
class _TabProductos extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabProductos({required this.negocio});

  @override
  Widget build(BuildContext context) {
    if (negocio.empresaIdVinculada.isEmpty) {
      return _vacio('Sin productos disponibles', Icons.shopping_bag_outlined);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(negocio.empresaIdVinculada)
          .collection('productos')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _vacio('Sin productos disponibles aún', Icons.shopping_bag_outlined);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final nombre      = d['nombre'] as String? ?? '';
            final precio      = d['precio'] as num?;
            final precioPromo = d['precio_promo'] as num?;
            final imagenUrl   = d['imagen_url'] as String?;
            final destacado   = d['destacado'] as bool? ?? false;

            return Container(
              decoration: BoxDecoration(
                color: _C.grisMedio, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: destacado ? _C.accent.withValues(alpha: 0.4) : _C.grisClaro),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  child: imagenUrl != null && imagenUrl.isNotEmpty
                      ? Image.network(imagenUrl, height: 110, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImg())
                      : _placeholderImg(),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (destacado)
                      Container(margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text('Destacado', style: TextStyle(color: _C.accent, fontSize: 9, fontWeight: FontWeight.w700))),
                    Text(nombre, style: TextStyle(color: _C.texto, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (precioPromo != null) ...[
                        Text('€${precioPromo.toStringAsFixed(2)}',
                            style: TextStyle(color: _C.accent, fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 5),
                        if (precio != null)
                          Text('€${precio.toStringAsFixed(2)}',
                              style: TextStyle(color: _C.textoHint, fontSize: 11,
                                  decoration: TextDecoration.lineThrough, decorationColor: _C.textoHint)),
                      ] else if (precio != null)
                        Text('€${precio.toStringAsFixed(2)}',
                            style: TextStyle(color: _C.accent, fontSize: 14, fontWeight: FontWeight.w800))
                      else
                        Text('Consultar', style: TextStyle(color: _C.textoMuted, fontSize: 12)),
                    ]),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _placeholderImg() => Container(height: 110, color: _C.grisOscuro,
      child: Center(child: Icon(Icons.shopping_bag_outlined, color: _C.textoHint, size: 32)));
}

// ═══════════════════════════════════════════════════════════════════
// TAB — PROFESIONALES / EQUIPO
// ═══════════════════════════════════════════════════════════════════
class _TabProfesionales extends StatefulWidget {
  final NegocioPublico negocio;
  const _TabProfesionales({required this.negocio});

  @override
  State<_TabProfesionales> createState() => _TabProfesionalesState();
}

class _TabProfesionalesState extends State<_TabProfesionales> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    // Query calculada una sola vez — evita re-suscripción al cambiar de tab
    final col = widget.negocio.empresaIdVinculada.isNotEmpty
        ? FirebaseFirestore.instance
            .collection('empresas').doc(widget.negocio.empresaIdVinculada)
            .collection('empleados')
            .where('visible_publico', isEqualTo: true)
        : FirebaseFirestore.instance
            .collection('negocios_publicos').doc(widget.negocio.id)
            .collection('equipo')
            .where('visible_publico', isEqualTo: true);
    _stream = col.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _vacio('Sin perfiles públicos del equipo aún', Icons.people_outline);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final nombre       = d['nombre'] as String? ?? d['nombre_completo'] as String? ?? '';
            final cargo        = d['cargo'] as String? ?? d['puesto'] as String? ?? '';
            final bio          = d['bio_publica'] as String? ?? d['descripcion'] as String? ?? '';
            final avatarUrl    = d['avatar_url'] as String? ?? d['foto_url'] as String?;
            final especialidades = (d['especialidades'] as List?)?.cast<String>() ?? [];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.grisMedio, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.grisClaro),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _C.grisOscuro,
                    border: Border.all(color: _C.grisClaro, width: 1.5),
                    image: avatarUrl != null && avatarUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Center(child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: TextStyle(color: _C.accent, fontSize: 22, fontWeight: FontWeight.bold)))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre, style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w700)),
                  if (cargo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(cargo, style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(bio, style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  if (especialidades.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: especialidades.take(4).map((e) =>
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _C.grisClaro)),
                        child: Text(e, style: TextStyle(color: _C.textoMuted, fontSize: 10))),
                    ).toList()),
                  ],
                ])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — PROMOCIONES / OFERTAS FLASH
// ═══════════════════════════════════════════════════════════════════
class _TabPromociones extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabPromociones({required this.negocio});

  @override
  Widget build(BuildContext context) {
    if (negocio.id.isEmpty) return _vacio('Sin ofertas activas', Icons.local_offer_outlined);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('negocios_publicos').doc(negocio.id)
          .collection('flash_slots')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = (snap.data?.docs ?? []).where((d) {
          final data = d.data() as Map<String, dynamic>;
          final hasta = (data['hasta'] as Timestamp?)?.toDate();
          return hasta == null || hasta.isAfter(DateTime.now());
        }).toList();

        if (docs.isEmpty) return _vacio('Sin ofertas activas en este momento', Icons.local_offer_outlined);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final nombre        = d['servicio_nombre'] as String? ?? d['nombre'] as String? ?? 'Oferta';
            final precioFinal   = (d['precio_final'] as num?)?.toDouble() ?? 0;
            final precioOriginal = (d['precio_original'] as num?)?.toDouble();
            final descuento     = d['descuento_texto'] as String?;
            final hasta         = (d['hasta'] as Timestamp?)?.toDate();
            final desc          = d['descripcion'] as String?;

            Duration? restante = hasta != null ? hasta.difference(DateTime.now()) : null;
            final urgente = restante != null && restante.inMinutes < 60;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.grisMedio, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: urgente
                    ? const Color(0xFFFF4444).withValues(alpha: 0.5)
                    : const Color(0xFFFFBB00).withValues(alpha: 0.4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFFFFBB00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.flash_on_rounded, color: Color(0xFFFFBB00), size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(nombre,
                      style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w700))),
                  if (descuento != null)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _C.accentRosa.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(descuento, style: TextStyle(color: _C.accentRosa, fontSize: 12, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('€${precioFinal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFFFBB00), fontSize: 22, fontWeight: FontWeight.w900)),
                  if (precioOriginal != null) ...[
                    const SizedBox(width: 8),
                    Text('€${precioOriginal.toStringAsFixed(2)}',
                        style: TextStyle(color: _C.textoHint, fontSize: 14,
                            decoration: TextDecoration.lineThrough, decorationColor: _C.textoHint)),
                  ],
                ]),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4)),
                ],
                if (hasta != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.timer_outlined, size: 12,
                        color: urgente ? const Color(0xFFFF4444) : _C.textoHint),
                    const SizedBox(width: 4),
                    Text(_fmtRestante(restante!),
                        style: TextStyle(fontSize: 11,
                            color: urgente ? const Color(0xFFFF4444) : _C.textoHint,
                            fontWeight: urgente ? FontWeight.w700 : FontWeight.normal)),
                  ]),
                ],
              ]),
            );
          },
        );
      },
    );
  }

  String _fmtRestante(Duration d) {
    if (d.isNegative) return 'Expirado';
    if (d.inHours > 0) return 'Termina en ${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return 'Termina en ${d.inMinutes}m';
  }
}
