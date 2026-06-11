import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/negocio_publico_model.dart';
import '../../negocio_publico/pantallas/tab_reservas_screen.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../services/canjeo_service.dart';

class _C {
  static const negro      = Color(0xFF0A0F23);
  static const grisOscuro = Color(0xFF151932);
  static const grisMedio  = Color(0xFF1E2139);
  static const grisClaro  = Color(0xFF2A2E45);
  static const accent     = Color(0xFF00FFC8);
  static const accentRosa = Color(0xFFFF3296);
  static const oro        = Color(0xFFFFB830);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);
}

// ═══════════════════════════════════════════════════════════════════
// DETALLE NEGOCIO — 6 pestañas (Reservar primera)
// ═══════════════════════════════════════════════════════════════════
class DetalleNegocioScreen extends StatefulWidget {
  final NegocioPublico negocio;
  const DetalleNegocioScreen({super.key, required this.negocio});

  @override
  State<DetalleNegocioScreen> createState() => _DetalleNegocioScreenState();
}

class _DetalleNegocioScreenState extends State<DetalleNegocioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 6, vsync: this); // ← 6 tabs
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.negocio;
    return Scaffold(
      backgroundColor: _C.negro,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar(n)],
        body: Column(children: [
          Container(
            color: _C.grisOscuro,
            child: TabBar(
              controller: _tc,
              indicatorColor: _C.accent,
              indicatorWeight: 2.5,
              labelColor: _C.accent,
              unselectedLabelColor: _C.textoMuted,
              isScrollable: false,                    // ← FIXED: No scrollable para ocupar todo el ancho
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: '⚡ Reservar'),
                Tab(text: 'Info'),
                Tab(text: 'Reseñas'),
                Tab(text: 'Servicios'),
                Tab(text: 'Galería'),
                Tab(text: 'Política'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                TabReservasScreen(negocio: n),  // ← NUEVA primera tab
                _TabInformacion(negocio: n),
                _TabResenas(negocio: n),
                _TabServicios(negocio: n),
                _TabGaleria(negocio: n),
                _TabPolitica(negocio: n),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(NegocioPublico n) {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: _C.grisOscuro,
      foregroundColor: _C.texto,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          n.fotoUrl != null && n.fotoUrl!.isNotEmpty
              ? Image.network(n.fotoUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fotoPlaceholder())
              : _fotoPlaceholder(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, _C.negro.withValues(alpha: 0.90)],
                stops: const [0.35, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 14, left: 16, right: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.nombre, style: const TextStyle(
                color: _C.texto, fontSize: 20, fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
              )),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF3296), Color(0xFFFF4678)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(n.categoria.label,
                      style: const TextStyle(fontSize: 11, color: _C.texto, fontWeight: FontWeight.w600)),
                ),
                if (n.ratingGoogle != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.star_rounded, size: 14, color: _C.accent),
                  const SizedBox(width: 3),
                  Text(n.ratingGoogle!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, color: _C.texto, fontWeight: FontWeight.bold)),
                  if (n.numResenas != null) ...[
                    const SizedBox(width: 3),
                    Text('(${n.numResenas})',
                        style: const TextStyle(fontSize: 11, color: _C.textoMuted)),
                  ],
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _fotoPlaceholder() => Container(
    color: _C.grisMedio,
    child: const Center(child: Icon(Icons.store_rounded, size: 64, color: _C.textoHint)),
  );
}

// ═══════════════════════════════════════════════════════════════════
// TAB — INFORMACIÓN
// ═══════════════════════════════════════════════════════════════════
class _TabInformacion extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabInformacion({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        if (_tieneDesc()) ...[
          _secTitle('Sobre nosotros'),
          const SizedBox(height: 8),
          Text(negocio.descripcionDetallada ?? negocio.descripcion ?? '',
              style: const TextStyle(fontSize: 14, color: _C.textoMuted, height: 1.6)),
          const SizedBox(height: 24),
        ],
        if (negocio.caracteristicas?.isNotEmpty ?? false) ...[
          _secTitle('Características'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
              children: negocio.caracteristicas!.map((c) => _chip(c)).toList()),
          const SizedBox(height: 24),
        ],
        if (_tieneAmenidades()) ...[
          _secTitle('Comodidades'),
          const SizedBox(height: 12),
          _amenidades(),
          const SizedBox(height: 24),
        ],
        if (negocio.horarios != null || negocio.horario != null) ...[
          _secTitle('Horarios'),
          const SizedBox(height: 12),
          _buildHorarios(),
          const SizedBox(height: 24),
        ],
        _secTitle('Contacto'),
        const SizedBox(height: 12),
        _buildContacto(),
        if (_tieneRedes()) ...[
          const SizedBox(height: 8),
          _buildRedes(context),
        ],
      ],
    );
  }

  bool _tieneDesc() =>
      (negocio.descripcionDetallada?.isNotEmpty ?? false) ||
          (negocio.descripcion?.isNotEmpty ?? false);

  bool _tieneAmenidades() =>
      negocio.aceptaTarjeta == true || negocio.tieneParking == true ||
          negocio.tieneWifi == true || negocio.admiteMascotas == true ||
          negocio.tieneTerraza == true || negocio.accesibleSillaRuedas == true ||
          negocio.reservasOnline == true;

  bool _tieneRedes() =>
      (negocio.instagram?.isNotEmpty ?? false) ||
          (negocio.facebook?.isNotEmpty ?? false) ||
          (negocio.whatsapp?.isNotEmpty ?? false) ||
          ((negocio.website ?? negocio.web)?.isNotEmpty ?? false);

  Widget _secTitle(String t) => Text(t,
      style: const TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700));

  Widget _chip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _C.grisMedio, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: _C.textoMuted, fontSize: 12)));

  Widget _amenidades() {
    final items = <({IconData icon, String label})>[
      if (negocio.aceptaTarjeta == true)        (icon: Icons.credit_card_rounded,    label: 'Acepta tarjeta'),
      if (negocio.tieneParking == true)          (icon: Icons.local_parking_rounded,  label: 'Parking'),
      if (negocio.tieneWifi == true)             (icon: Icons.wifi_rounded,            label: 'WiFi gratis'),
      if (negocio.admiteMascotas == true)        (icon: Icons.pets_rounded,            label: 'Mascotas'),
      if (negocio.tieneTerraza == true)          (icon: Icons.deck_rounded,            label: 'Terraza'),
      if (negocio.accesibleSillaRuedas == true)  (icon: Icons.accessible_rounded,     label: 'Accesible'),
      if (negocio.reservasOnline == true)        (icon: Icons.event_available_rounded, label: 'Reservas online'),
    ];
    return Wrap(spacing: 16, runSpacing: 10,
        children: items.map((a) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(a.icon, size: 16, color: _C.accent),
          const SizedBox(width: 5),
          Text(a.label, style: const TextStyle(fontSize: 13, color: _C.textoMuted)),
        ])).toList());
  }

  Widget _buildHorarios() {
    final List<({String dia, String texto, bool cerrado})> filas = [];
    if (negocio.horario != null && negocio.horario!.isNotEmpty) {
      const orden = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
      for (final dia in orden) {
        final h = negocio.horario![dia]; if (h == null) continue;
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
    } else if (negocio.horarios != null) {
      const dias = ['','Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
      for (int i = 1; i <= 7; i++) {
        final h = negocio.horarios![i]; if (h == null) continue;
        filas.add((dia: dias[i], texto: h.textoHorario, cerrado: !h.abierto));
      }
    }
    if (filas.isEmpty) return const SizedBox.shrink();
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
              child: const Text('Hoy', style: TextStyle(color: _C.negro, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
        ]),
      );
    }).toList());
  }

  Widget _buildContacto() => Column(children: [
    if (negocio.direccion != null)      _cItem(Icons.location_on_rounded,  negocio.direccion!),
    if (negocio.telefono != null)       _cItem(Icons.phone_rounded,         negocio.telefono!),
    if ((negocio.email ?? negocio.emailPublico) != null)
      _cItem(Icons.email_rounded, negocio.email ?? negocio.emailPublico!),
    if ((negocio.web ?? negocio.website) != null)
      _cItem(Icons.language_rounded, negocio.web ?? negocio.website!),
    if (negocio.precioMedio?.isNotEmpty ?? false)
      _cItem(Icons.euro_rounded, 'Precio medio: ${negocio.precioMedio}'),
  ]);

  Widget _cItem(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 17, color: _C.accentRosa),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: _C.textoMuted))),
      ]));

  Widget _buildRedes(BuildContext ctx) => Wrap(spacing: 8, runSpacing: 8, children: [
    if (negocio.instagram?.isNotEmpty ?? false)
      _btnRed(ctx, Icons.camera_alt_outlined, 'Instagram', negocio.instagram!),
    if (negocio.facebook?.isNotEmpty ?? false)
      _btnRed(ctx, Icons.facebook, 'Facebook', negocio.facebook!),
    if (negocio.whatsapp?.isNotEmpty ?? false)
      _btnRed(ctx, Icons.phone_rounded, 'WhatsApp', 'https://wa.me/${negocio.whatsapp}'),
    if ((negocio.website ?? negocio.web)?.isNotEmpty ?? false)
      _btnRed(ctx, Icons.language, 'Web', negocio.website ?? negocio.web!),
  ]);

  Widget _btnRed(BuildContext ctx, IconData icon, String label, String url) =>
      OutlinedButton.icon(
        onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Abrir: $url'),
                behavior: SnackBarBehavior.floating, backgroundColor: _C.grisOscuro)),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.accent,
          side: const BorderSide(color: _C.accent, width: 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          visualDensity: VisualDensity.compact,
        ),
      );
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
        color: _C.negro,
        child: TabBar(
          controller: _tc,
          indicatorColor: _C.accentRosa,
          indicatorWeight: 2,
          labelColor: _C.texto,
          unselectedLabelColor: _C.textoMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
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
      return _vacio('Sin reseñas de Google', Icons.g_mobiledata_rounded);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(negocio.empresaIdVinculada)
          .collection('valoraciones')
          .where('origen', isEqualTo: 'google')
          .orderBy('fecha', descending: true)
          .limit(30)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
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
                const Icon(Icons.rate_review_outlined, size: 36, color: _C.textoHint),
                const SizedBox(height: 8),
                Text(
                    negocio.ratingGoogle != null
                        ? '${negocio.ratingGoogle!.toStringAsFixed(1)}★ en Google'
                        : 'Sin reseñas de Google todavía',
                    style: const TextStyle(color: _C.textoMuted, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                const Text('Se sincronizan con Google My Business',
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
  String get _colRef =>
      'empresas/${widget.negocio.empresaIdVinculada}/valoraciones';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _mostrarFormulario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      FluxToast.aviso(context, 'Inicia sesión para dejar una reseña');
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('negocios_publicos')
        .doc(widget.negocio.id)
        .collection('reservas')
        .where('usuarioUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (!mounted) return;

    if (snap.docs.isEmpty) {
      FluxToast.aviso(
        context,
        'Solo puedes reseñar negocios donde has reservado',
        title: 'Reserva primero',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioResena(
        negocio: widget.negocio,
        uid: uid,
        colRef: _colRef,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.negocio.empresaIdVinculada.isEmpty) {
      return _vacio('Sin reseñas Fluix todavía', Icons.star_border_rounded);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_colRef)
          .where('origen', isEqualTo: 'fluix')
          .limit(50)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = <QueryDocumentSnapshot>[...(snap.data?.docs ?? [])]
          ..sort((a, b) {
            final ta = (a.data() as Map)['fecha'] as Timestamp?;
            final tb = (b.data() as Map)['fecha'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        return Stack(children: [
          ListView(controller: _scrollCtrl, primary: false, padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            if (docs.isNotEmpty) ...[
              _resumenFluix(docs),
              const SizedBox(height: 16),
              _CarruselResenas(docs: docs),
              const SizedBox(height: 20),
              const Divider(color: _C.grisClaro),
              const SizedBox(height: 16),
              const Text('Todas las reseñas',
                  style: TextStyle(color: _C.texto, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...docs.map((d) => _TarjetaResena(data: d.data() as Map<String, dynamic>)),
            ] else ...[
              _vacio('Sé el primero en valorar este negocio', Icons.star_border_rounded),
            ],
          ]),
          Positioned(
            bottom: 16, right: 16,
            child: FloatingActionButton.extended(
              onPressed: _mostrarFormulario,
              backgroundColor: _C.accentRosa,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.rate_review_rounded, size: 18),
              label: const Text('Añadir reseña',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ]);
      },
    );
  }

  Widget _resumenFluix(List<QueryDocumentSnapshot> docs) {
    final total = docs.length;
    final media = docs.fold<double>(
        0, (s, d) => s + ((d.data() as Map)['estrellas'] as num? ?? 0).toDouble()) / total;
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
            activa: i == _pagina,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.docs.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _pagina ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _pagina ? _C.accent : _C.grisClaro,
            borderRadius: BorderRadius.circular(3),
          ),
        )),
      ),
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
          color: _C.grisMedio,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: activa ? _C.accent.withValues(alpha: 0.35) : _C.grisClaro,
            width: activa ? 1.5 : 0.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(nombre: autor, avatarUrl: avatarUrl, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (data['destacada'] == true)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFFFB830)),
                  ),
                Expanded(child: Text(autor,
                    style: TextStyle(
                      color: _colorNombreResena(data['autor_color'] as String?),
                      fontWeight: FontWeight.bold, fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis)),
                _badgeMarco(data['autor_marco'] as String?),
                if (verificado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, color: _C.accent, size: 10),
                      SizedBox(width: 3),
                      Text('Verificado',
                          style: TextStyle(color: _C.accent, fontSize: 9, fontWeight: FontWeight.w600)),
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
              style: const TextStyle(color: Color(0xFFD0D3E0), fontSize: 13,
                  fontStyle: FontStyle.italic, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 8),
          Row(children: [
            if (servicio != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.accentRosa.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(servicio,
                    style: const TextStyle(color: _C.accentRosa, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (fecha != null)
              Text(_fmtFecha(fecha), style: const TextStyle(color: _C.textoHint, fontSize: 11)),
          ]),
          // Respuesta del negocio
          if (respuesta != null && respuesta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.grisOscuro,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.accent.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.storefront_rounded, size: 12, color: _C.accent),
                  SizedBox(width: 5),
                  Text('Respuesta del negocio',
                      style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(respuesta,
                    style: const TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4),
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
  void dispose() {
    _nombreCtrl.dispose();
    _comentCtrl.dispose();
    _servicioCtrl.dispose();
    super.dispose();
  }

  bool get _puedeGuardar =>
      _nombreCtrl.text.trim().isNotEmpty && _comentCtrl.text.trim().isNotEmpty;

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() => _guardando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Leer canjes activos del usuario
      final userSnap = await FirebaseFirestore.instance
          .collection('usuarios').doc(widget.uid).get();
      final ud = userSnap.data() ?? {};

      final anonimo = (ud['canje_anonimo_usos'] as int? ?? 0) > 0;
      final firma   = ud['canje_firma'] as String?;
      final colorH  = ud['canje_color_nombre'] as String?;
      final destacada = ud['canje_resena_destacada'] as bool? ?? false;
      final marco   = ud['canje_marco'] as String?;

      final nombreFinal = anonimo ? 'Anónimo' : _nombreCtrl.text.trim();
      final textoFinal  = firma != null && firma.isNotEmpty
          ? '${_comentCtrl.text.trim()} $firma'
          : _comentCtrl.text.trim();

      await FirebaseFirestore.instance.collection(widget.colRef).add({
        'origen':      'fluix',
        'uid':         widget.uid,
        'autor':       nombreFinal,
        'texto':       textoFinal,
        'estrellas':   _estrellas,
        'servicio':    _servicioCtrl.text.trim().isEmpty ? null : _servicioCtrl.text.trim(),
        if (user?.photoURL != null && !anonimo) 'avatarUrl': user!.photoURL,
        'verificado':  false,
        'fecha':       FieldValue.serverTimestamp(),
        'negocioId':   widget.negocio.id,
        'negocioNombre': widget.negocio.nombre,
        if (destacada)           'destacada': true,
        if (colorH != null)      'autor_color': colorH,
        if (marco != null)       'autor_marco': marco,
        if (anonimo)             'es_anonimo': true,
      });

      // Consumir usos de canjes de un solo uso
      if (anonimo) await CanjeoService.consumirUso(widget.uid, 'modo_anonimo');
      if (destacada) await CanjeoService.consumirUso(widget.uid, 'resena_destacada');

      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, 'Reseña publicada. ¡Gracias!');
      }
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
      decoration: const BoxDecoration(
        color: Color(0xFF151932),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _C.grisClaro, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.star_rounded, color: _C.oro, size: 20),
          const SizedBox(width: 8),
          Text('Reseña para ${widget.negocio.nombre}',
              style: const TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.bold)),
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
              style: const TextStyle(color: _C.oro, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        _campo(_nombreCtrl, 'Tu nombre *', 'Ej: María García'),
        const SizedBox(height: 10),
        TextField(
          controller: _comentCtrl, maxLines: 3, maxLength: 3000,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: _C.texto, fontSize: 13),
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
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_guardando ? 'Publicando...' : 'Publicar reseña',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
    style: const TextStyle(color: _C.texto, fontSize: 13),
    decoration: _inputDec(hint).copyWith(
      labelText: label, labelStyle: const TextStyle(color: _C.textoMuted, fontSize: 12),
    ),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _C.textoHint, fontSize: 13),
    filled: true, fillColor: _C.negro,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: _C.grisClaro, width: 0.5),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: _C.accent, width: 1),
    ),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide.none,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS COMPARTIDOS
// ═══════════════════════════════════════════════════════════════════
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
          Text(label, style: const TextStyle(color: _C.textoMuted, fontSize: 12, fontWeight: FontWeight.w500)),
          if (numResenas != null) ...[
            const SizedBox(height: 2),
            Text('$numResenas ${numResenas == 1 ? 'reseña' : 'reseñas'}',
                style: const TextStyle(color: _C.textoHint, fontSize: 11)),
          ],
        ])),
      ]),
    );

Widget _vacio(String msg, IconData icon) => Center(
  child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: _C.textoHint.withValues(alpha: 0.4)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: _C.textoMuted, fontSize: 14), textAlign: TextAlign.center),
    ]),
  ),
);

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
      decoration: BoxDecoration(
        color: _C.grisOscuro,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Barra de color izquierda
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Cabecera: avatar + nombre + estrellas
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Avatar(nombre: autor, avatarUrl: avatarUrl, size: 38),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(autor,
                      style: const TextStyle(color: _C.texto, fontSize: 13, fontWeight: FontWeight.w700))),
                  if (verificado)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_rounded, color: _C.accent, size: 10),
                        SizedBox(width: 3),
                        Text('Verificado', style: TextStyle(color: _C.accent, fontSize: 9, fontWeight: FontWeight.w600)),
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
                    Text(_fmtFecha(fecha), style: const TextStyle(color: _C.textoHint, fontSize: 10)),
                ]),
              ])),
            ]),
            // Comentario
            if ((texto as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(texto, style: const TextStyle(color: _C.textoMuted, fontSize: 13, height: 1.5)),
            ],
            // Servicio
            if (servicio != null && servicio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.accentRosa.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.accentRosa.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.content_cut_rounded, size: 10, color: _C.accentRosa),
                  const SizedBox(width: 4),
                  Text(servicio, style: const TextStyle(color: _C.accentRosa, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
        // Respuesta del negocio
        if (respuesta != null && respuesta.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.grisMedio,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.accent.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.storefront_rounded, size: 12, color: _C.accent),
                const SizedBox(width: 5),
                const Text('Respuesta del negocio',
                    style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (fechaResp != null)
                  Text(_fmtFecha(fechaResp), style: const TextStyle(color: _C.textoHint, fontSize: 10)),
              ]),
              const SizedBox(height: 6),
              Text(respuesta, style: const TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4)),
            ]),
          ),
          ])),  // cierra Expanded > Column
        ]),     // cierra Row
      ),        // cierra IntrinsicHeight
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

// ── Helpers de canjes para tarjetas de reseña ─────────────────────
Color _colorNombreResena(String? hex) {
  if (hex == null) return _C.texto;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _C.texto; }
}

Widget _badgeMarco(String? marco) {
  if (marco == null) return const SizedBox.shrink();
  final emoji = switch (marco) { 'platino' => '💎', 'oro' => '🥇', _ => '🟤' };
  return Padding(padding: const EdgeInsets.only(left: 4),
      child: Text(emoji, style: const TextStyle(fontSize: 12)));
}

class _Avatar extends StatelessWidget {
  final String nombre;
  final String? avatarUrl;
  final double size;
  const _Avatar({required this.nombre, required this.avatarUrl, required this.size});

  Color get _color {
    const colors = [
      Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055),
      Color(0xFF0984E3), Color(0xFFD63031), Color(0xFFFDAB3D),
    ];
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
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: _color,
      border: Border.all(color: _C.grisClaro, width: 1.5),
      image: avatarUrl != null
          ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover, onError: (_, __) {})
          : null,
    ),
    child: avatarUrl == null
        ? Center(child: Text(_iniciales,
        style: TextStyle(color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.bold)))
        : null,
  );
}

// ═══════════════════════════════════════════════════════════════════
// TAB — SERVICIOS (solo lista, sin flow — el flow está en Reservar)
// ═══════════════════════════════════════════════════════════════════
class _TabServicios extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabServicios({required this.negocio});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(negocio.empresaIdVinculada)
          .collection('servicios').orderBy('nombre').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _C.accent));
        }
        final docs = snap.data?.docs ?? [];
        final estaticos = [...(negocio.serviciosDestacados ?? []), ...(negocio.especialidades ?? [])];
        if (docs.isEmpty && estaticos.isEmpty) {
          return _vacio('Sin servicios disponibles aún', Icons.spa_outlined);
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          if (docs.isNotEmpty)
            ...docs.map((d) => _TarjetaServicio(data: d.data() as Map<String, dynamic>))
          else ...[
            const Padding(padding: EdgeInsets.only(bottom: 12),
                child: Text('Servicios disponibles',
                    style: TextStyle(color: _C.texto, fontSize: 15, fontWeight: FontWeight.w700))),
            ...estaticos.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _C.grisOscuro, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.accent.withValues(alpha: 0.15))),
              child: Row(children: [
                const Icon(Icons.star_rounded, size: 14, color: _C.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: const TextStyle(color: _C.texto, fontSize: 14))),
              ]),
            )),
          ],
        ]);
      },
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TarjetaServicio({required this.data});

  @override
  Widget build(BuildContext context) {
    final nombre      = data['nombre'] as String? ?? '';
    final desc        = data['descripcion'] as String? ?? '';
    final precio      = data['precio'];
    final precioDesde = data['precio_desde'];
    final duracion    = data['duracion'] as int?;
    final categoria   = data['categoria'] as String? ?? '';
    final imagenUrl   = data['imagen_url'] as String?; // ← NUEVO: soporte para imagen
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
        // Imagen o icono de categoría
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: _C.grisMedio, 
            borderRadius: BorderRadius.circular(10),
            image: imagenUrl != null && imagenUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imagenUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imagenUrl == null || imagenUrl.isEmpty
              ? Center(child: Icon(_iconCat(categoria), size: 24, color: _C.accent))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(color: _C.texto, fontSize: 14, fontWeight: FontWeight.w600)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4)),
          ],
          if (duracion != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 11, color: _C.textoHint),
              const SizedBox(width: 3),
              Text(duracion >= 60
                  ? '${duracion ~/ 60}h${duracion % 60 > 0 ? ' ${duracion % 60}min' : ''}'
                  : '${duracion}min',
                  style: const TextStyle(color: _C.textoHint, fontSize: 11)),
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
                style: const TextStyle(color: _C.accent, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  IconData _iconCat(String cat) {
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
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => _VisorFotos(fotos: fotos, indiceInicial: i, negocioId: negocio.id))),
        child: Hero(
          tag: 'galeria_${negocio.id}_$i',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.network(fotos[i], fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null ? child
                    : Container(color: _C.grisMedio,
                    child: const Center(child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(color: _C.grisMedio,
                    child: const Icon(Icons.broken_image_outlined, color: _C.textoHint, size: 24))),
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
  void initState() {
    super.initState();
    _idx = widget.indiceInicial;
    _pc = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87, foregroundColor: Colors.white,
        title: Text('${_idx + 1} / ${widget.fotos.length}', style: const TextStyle(fontSize: 14)),
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
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48))),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB — POLÍTICA (T&C)
// ═══════════════════════════════════════════════════════════════════
class _TabPolitica extends StatelessWidget {
  final NegocioPublico negocio;
  const _TabPolitica({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final tyc = negocio.terminosYCondiciones?.trim() ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.gavel_rounded, color: _C.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Términos y Condiciones',
                style: TextStyle(color: _C.texto, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(negocio.nombre, style: const TextStyle(color: _C.textoMuted, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 20),
        if (tyc.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(Icons.description_outlined, size: 52, color: _C.textoHint.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Este negocio no ha publicado\ntérminos y condiciones todavía.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _C.textoMuted, fontSize: 14, height: 1.5)),
            ]),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _C.grisOscuro, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.grisClaro, width: 0.5),
            ),
            child: Text(tyc, style: const TextStyle(color: Color(0xFFD0D3E0), fontSize: 13, height: 1.7)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.accent.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: _C.accent, size: 16),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Al confirmar una reserva aceptas estos términos y condiciones.',
                style: TextStyle(color: _C.textoMuted, fontSize: 12, height: 1.4),
              )),
            ]),
          ),
        ],
      ],
    );
  }
}