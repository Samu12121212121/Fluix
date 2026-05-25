import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/valoracion_model.dart';
import '../../../services/valoracion_service.dart';
import '../widgets/resumen_rating.dart';
import 'package:timeago/timeago.dart' as timeago;

class _C {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const amarillo   = Color(0xFFFFBB00);
  static const accent     = Color(0xFF00FFC8);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA VALORACIONES NEGOCIO (vista CLIENTE)
// ─────────────────────────────────────────────────────────────────────────────
class PantallaValoracionesNegocio extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final double? ratingFluix;
  final int? totalValoraciones;

  const PantallaValoracionesNegocio({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    this.ratingFluix,
    this.totalValoraciones,
  });

  @override
  State<PantallaValoracionesNegocio> createState() => _PantallaValoracionesNegocioState();
}

class _PantallaValoracionesNegocioState extends State<PantallaValoracionesNegocio> {
  final _scrollCtrl = ScrollController();
  final List<ValoracionModel> _items = [];
  DocumentSnapshot? _ultimoDoc;
  bool _cargando = false;
  bool _hayMas = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _scrollCtrl.addListener(_onScroll);
    _cargarPrimera();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _cargarMas();
    }
  }

  Future<void> _cargarPrimera() async {
    setState(() => _cargando = true);
    final r = await ValoracionService.cargarPagina(widget.negocioId, limite: 20);
    if (mounted) {
      setState(() {
        _items.addAll(r.items);
        _ultimoDoc = r.last;
        _hayMas = r.items.length >= 20;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_cargando || !_hayMas || _ultimoDoc == null) return;
    setState(() => _cargando = true);
    final r = await ValoracionService.cargarPagina(
        widget.negocioId, desde: _ultimoDoc, limite: 20);
    if (mounted) {
      setState(() {
        _items.addAll(r.items);
        _ultimoDoc = r.last;
        _hayMas = r.items.length >= 20;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.fondo,
      appBar: AppBar(
        backgroundColor: _C.superficie,
        foregroundColor: _C.texto,
        elevation: 0,
        title: Text('Reseñas · ${widget.negocioNombre}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: _items.isEmpty && _cargando
          ? _shimmer()
          : _items.isEmpty
              ? _vacio()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 2, // header + items + footer
                  itemBuilder: (ctx, i) {
                    if (i == 0) return _header();
                    if (i == _items.length + 1) {
                      return _cargando
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator(
                                  color: _C.amarillo, strokeWidth: 2)))
                          : const SizedBox(height: 20);
                    }
                    return _CardValoracion(val: _items[i - 1]);
                  },
                ),
    );
  }

  Widget _header() {
    return Column(children: [
      // Rating summary
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.tarjeta,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.borde),
        ),
        child: Column(children: [
          ResumenRating(
            ratingFluix:      widget.ratingFluix,
            totalValoraciones: widget.totalValoraciones,
            compacto:          false,
            mostrarContador:   true,
          ),
          if (widget.totalValoraciones != null && widget.totalValoraciones! > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: _C.borde, height: 1),
            const SizedBox(height: 16),
            BarraDistribucionEstrellas(
              distribucion: _calcularDistribucion(),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Todas las reseñas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: _C.texto)),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Map<int, int> _calcularDistribucion() {
    final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final v in _items) {
      dist[v.estrellas] = (dist[v.estrellas] ?? 0) + 1;
    }
    return dist;
  }

  Widget _vacio() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⭐', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('Aún no hay reseñas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: _C.texto)),
      const SizedBox(height: 8),
      const Text('Sé el primero en valorar este negocio',
          style: TextStyle(fontSize: 13, color: _C.textoMuted)),
    ]),
  ));

  Widget _shimmer() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, __) => Container(
      height: 120,
      decoration: BoxDecoration(
        color: _C.tarjeta,
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD VALORACIÓN
// ─────────────────────────────────────────────────────────────────────────────
class _CardValoracion extends StatelessWidget {
  final ValoracionModel val;
  const _CardValoracion({required this.val});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: avatar + nombre + estrellas + fecha
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val.clienteNombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _C.texto)),
              const SizedBox(height: 4),
              Row(children: [
                ...List.generate(5, (i) => Icon(
                  i < val.estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: i < val.estrellas ? _C.amarillo : _C.textoHint,
                )),
                const Spacer(),
                Text(_formatFecha(val.creadoAt),
                    style: const TextStyle(fontSize: 11, color: _C.textoMuted)),
              ]),
            ],
          )),
        ]),
        const SizedBox(height: 12),

        // Comentario
        Text(val.comentario,
            style: const TextStyle(fontSize: 13, color: _C.texto, height: 1.5)),

        // Respuesta del negocio
        if (val.tieneRespuesta) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.superficie,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.borde.withValues(alpha: 0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _C.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Icon(Icons.store_rounded,
                      size: 12, color: _C.accent)),
                ),
                const SizedBox(width: 8),
                const Text('Respuesta del negocio',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _C.accent)),
                if (val.respuestaAt != null) ...[
                  const Spacer(),
                  Text(_formatFecha(val.respuestaAt!),
                      style: const TextStyle(fontSize: 10, color: _C.textoMuted)),
                ],
              ]),
              const SizedBox(height: 8),
              Text(val.respuestaNegocio!,
                  style: const TextStyle(fontSize: 12, color: _C.texto, height: 1.4)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _avatar() {
    if (val.clienteFotoUrl != null && val.clienteFotoUrl!.isNotEmpty) {
      return ClipOval(child: SizedBox(
        width: 40, height: 40,
        child: Image.network(val.clienteFotoUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarPlaceholder()),
      ));
    }
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [Color(0xFF00FFC8), Color(0xFF0D47A1)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Text(
      val.clienteNombre.isNotEmpty ? val.clienteNombre[0].toUpperCase() : '?',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: Colors.white),
    )),
  );

  String _formatFecha(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 7) {
      return timeago.format(dt, locale: 'es');
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

