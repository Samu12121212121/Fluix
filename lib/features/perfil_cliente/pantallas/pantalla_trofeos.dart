import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trofeo_def.dart';
import '../../../services/trofeos_service.dart';
import '../../tienda_monedas/pantalla_tienda_monedas.dart';
import 'pantalla_monedero.dart';
import '../widgets/trofeo_desbloqueado_overlay.dart';

const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kCard2  = Color(0xFF252A45);
const _kBorde  = Color(0xFF2A2E45);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kOro    = Color(0xFFFFB830);

class PantallaTrofeos extends StatefulWidget {
  const PantallaTrofeos({super.key});
  @override
  State<PantallaTrofeos> createState() => _PantallaTrofeosState();
}

class _PantallaTrofeosState extends State<PantallaTrofeos> {
  TrofeoCategoria? _catFiltro;
  String? _ultimoTrofeoMostrado;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: TrofeosService.streamUltimoTrofeoDesbloqueado(uid),
      builder: (_, snapOverlay) {
        final ultimo = snapOverlay.data;
        final mostrarOverlay = ultimo != null && ultimo != _ultimoTrofeoMostrado;
        return Stack(children: [
          Scaffold(
            backgroundColor: _kBg,
            appBar: AppBar(
              backgroundColor: const Color(0xFF151932),
              foregroundColor: _kTexto,
              title: const Text('Mis Trofeos', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                StreamBuilder<int>(
                  stream: TrofeosService.streamMonedas(uid),
                  builder: (_, snap) => GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaMonedero())),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ChipMonedas(monedas: snap.data ?? 0),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaTiendaMonedas())),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kOro.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kOro.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Tienda', style: TextStyle(color: _kOro, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            body: StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: TrofeosService.streamTrofeos(uid),
              builder: (_, snap) {
                final datos = snap.data ?? {};
                final visibles = kTrofeos.where((t) => !t.oculto).toList();
                final completados = visibles.where((t) => datos[t.id]?['completado'] == true).length;
                final progCat = TrofeosService.progresoCategoria(datos);
                final lista = _catFiltro == null ? visibles : visibles.where((t) => t.categoria == _catFiltro).toList();
                return CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _HeaderProgreso(completados: completados, total: visibles.length, datos: datos, progCat: progCat)),
                  SliverToBoxAdapter(child: _FiltrosCategorias(seleccionada: _catFiltro, onTap: (c) => setState(() => _catFiltro = _catFiltro == c ? null : c), progCat: progCat)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final def = lista[i];
                          final d = datos[def.id];
                          final completado = d?['completado'] as bool? ?? false;
                          final progreso = d?['progreso'] as int? ?? (completado ? (def.meta ?? 1) : 0);
                          return _TarjetaTrofeo(def: def, completado: completado, progreso: progreso);
                        },
                        childCount: lista.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10, childAspectRatio: 1.0,
                        crossAxisSpacing: 6, mainAxisSpacing: 6,
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
          if (mostrarOverlay)
            TrofeoDesbloqueadoOverlay(
              trofeoId: ultimo,
              onDismiss: () => setState(() => _ultimoTrofeoMostrado = ultimo),
            ),
        ]);
      },
    );
  }
}

// ── Header de progreso ────────────────────────────────────────────────────────

class _HeaderProgreso extends StatelessWidget {
  final int completados, total;
  final Map<String, Map<String, dynamic>> datos;
  final Map<TrofeoCategoria, ({int completados, int total})> progCat;
  const _HeaderProgreso({required this.completados, required this.total, required this.datos, required this.progCat});

  int get _monedasGanadas => datos.values.where((d) => d['completado'] == true).fold(0, (s, d) => s + ((d['monedas_otorgadas'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completados / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E2139), Color(0xFF252A45)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOro.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$completados de $total trofeos', style: const TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${(pct * 100).toInt()}% completado', style: const TextStyle(color: _kMuted, fontSize: 11)),
          ])),
          Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text('$_monedasGanadas', style: const TextStyle(color: _kOro, fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: pct, minHeight: 6, backgroundColor: _kBorde,
          valueColor: const AlwaysStoppedAnimation<Color>(_kOro),
        )),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: progCat.entries.map((e) {
          final p = e.value;
          final done = p.completados == p.total && p.total > 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: done ? e.key.color.withValues(alpha: 0.2) : _kCard2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: done ? e.key.color.withValues(alpha: 0.5) : _kBorde, width: 0.8),
            ),
            child: Text('${p.completados}/${p.total}', style: TextStyle(color: done ? e.key.color : _kMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          );
        }).toList()),
      ]),
    );
  }
}

// ── Filtros de categoría ──────────────────────────────────────────────────────

class _FiltrosCategorias extends StatelessWidget {
  final TrofeoCategoria? seleccionada;
  final ValueChanged<TrofeoCategoria> onTap;
  final Map<TrofeoCategoria, ({int completados, int total})> progCat;
  const _FiltrosCategorias({required this.seleccionada, required this.onTap, required this.progCat});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: TrofeoCategoria.values.map((c) {
          final sel = seleccionada == c;
          final p = progCat[c];
          return GestureDetector(
            onTap: () => onTap(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? c.color : _kCard2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? c.color : _kBorde),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c.label, style: TextStyle(color: sel ? _kBg : _kMuted, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                if (p != null) ...[
                  const SizedBox(width: 5),
                  Text('${p.completados}', style: TextStyle(color: sel ? _kBg.withValues(alpha: 0.7) : _kMuted.withValues(alpha: 0.7), fontSize: 10)),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tarjeta de trofeo ─────────────────────────────────────────────────────────

class _TarjetaTrofeo extends StatefulWidget {
  final TrofeoDef def;
  final bool completado;
  final int progreso;
  const _TarjetaTrofeo({required this.def, required this.completado, required this.progreso});
  @override
  State<_TarjetaTrofeo> createState() => _TarjetaTrofeoState();
}

class _TarjetaTrofeoState extends State<_TarjetaTrofeo> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _glow  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.completado) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_TarjetaTrofeo old) {
    super.didUpdateWidget(old);
    if (!old.completado && widget.completado) _ctrl.forward(from: 0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final tierColor = def.tier.color;
    final catColor  = def.categoria.color;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Transform.scale(
        scale: widget.completado ? _scale.value : 1.0,
        child: GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, backgroundColor: Colors.transparent,
            builder: (_) => _DetalleSheet(def: def, completado: widget.completado, progreso: widget.progreso),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.completado ? catColor.withValues(alpha: 0.6) : _kBorde,
                width: widget.completado ? 1.5 : 0.5,
              ),
              boxShadow: widget.completado ? [BoxShadow(color: catColor.withValues(alpha: 0.2 * _glow.value), blurRadius: 12, spreadRadius: 1)] : null,
            ),
            child: Stack(children: [
              if (widget.completado)
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(13),
                  child: CustomPaint(painter: _ShimmerPainter(color: catColor, progress: _glow.value)))),
              // Tier dot (top-left)
              Positioned(top: 5, left: 5,
                child: Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: tierColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: tierColor.withValues(alpha: 0.6), blurRadius: 4)]),
                ),
              ),
              // Lock icon (top-right) if not completed
              if (!widget.completado)
                Positioned(top: 5, right: 5,
                  child: Icon(Icons.lock_outline_rounded, size: 10, color: _kMuted.withValues(alpha: 0.5)),
                ),
              Center(child: Text(def.emoji, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center)),
              if (!widget.completado)
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(13),
                  child: Container(color: const Color(0xFF0A0F23).withValues(alpha: 0.45)))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet detalle ──────────────────────────────────────────────────────

class _DetalleSheet extends StatelessWidget {
  final TrofeoDef def;
  final bool completado;
  final int progreso;
  const _DetalleSheet({required this.def, required this.completado, required this.progreso});

  @override
  Widget build(BuildContext context) {
    final catColor  = def.categoria.color;
    final tierColor = def.tier.color;
    final pct = def.meta != null ? (progreso / def.meta!).clamp(0.0, 1.0) : (completado ? 1.0 : 0.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: const Color(0xFF151932),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: catColor.withValues(alpha: 0.4), width: 1.5)),
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: _kBorde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(def.emoji, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 10),
        Text(def.titulo, style: const TextStyle(color: _kTexto, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(def.categoria.label, style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600))),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tierColor.withValues(alpha: 0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(def.tier.emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(def.tier.label, style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
        ]),
        const SizedBox(height: 14),
        Text(def.descripcion, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        if (def.meta != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progreso: $progreso / ${def.meta}', style: const TextStyle(color: _kMuted, fontSize: 12)),
            Text('${(pct * 100).toInt()}%', style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: _kBorde,
              valueColor: AlwaysStoppedAnimation<Color>(catColor))),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kOro.withValues(alpha: completado ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kOro.withValues(alpha: completado ? 0.4 : 0.15)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🪙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(completado ? '+${def.monedas} monedas ganadas' : '${def.monedas} monedas al completar',
              style: TextStyle(color: completado ? _kOro : _kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (completado) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, color: catColor, size: 16),
            const SizedBox(width: 6),
            Text('¡Trofeo desbloqueado!', style: TextStyle(color: catColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ],
      ])),
    );
  }
}

// ── Chip de monedas ───────────────────────────────────────────────────────────

class TrofeoMonedasChip extends StatelessWidget {
  final int monedas;
  const TrofeoMonedasChip({super.key, required this.monedas});
  @override
  Widget build(BuildContext context) => _ChipMonedas(monedas: monedas);
}

class _ChipMonedas extends StatelessWidget {
  final int monedas;
  const _ChipMonedas({required this.monedas});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _kOro.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kOro.withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🪙', style: TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text('$monedas', style: const TextStyle(color: _kOro, fontSize: 13, fontWeight: FontWeight.w800)),
    ]),
  );
}

// ── Shimmer painter ───────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final Color color;
  final double progress;
  const _ShimmerPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, color.withValues(alpha: 0.06 * progress), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        transform: GradientRotation(progress * pi / 2),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(13)), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// Alias de compatibilidad
class TrofeoService {
  static Stream<Map<String, Map<String, dynamic>>> streamTrofeos(String uid) => TrofeosService.streamTrofeos(uid);
  static Stream<int> streamMonedas(String uid) => TrofeosService.streamMonedas(uid);
}
