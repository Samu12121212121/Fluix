import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trofeo_def.dart';
import '../../../services/trofeos_service.dart';
import 'pantalla_monedero.dart';
import '../widgets/trofeo_desbloqueado_overlay.dart';
import '../../../core/widgets/fluix_app_bar.dart';

const _kBg     = Color(0xFFF4F6FB);
const _kCard   = Color(0xFFFFFFFF);
const _kCard2  = Color(0xFFEEF2F7);
const _kBorde  = Color(0xFFDDE3ED);
const _kTexto  = Color(0xFF1E293B);
const _kMuted  = Color(0xFF64748B);
const _kOro    = Color(0xFFE59B00);

class PantallaTrofeos extends StatefulWidget {
  const PantallaTrofeos({super.key});
  @override
  State<PantallaTrofeos> createState() => _PantallaTrofeosState();
}

class _PantallaTrofeosState extends State<PantallaTrofeos> {
  TrofeoCategoria? _catFiltro;
  String? _ultimoTrofeoMostrado;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _mostrarProximamente(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏪', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('¡Próximamente!', style: TextStyle(
              color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'La tienda está en camino.\n¡Mejor que ahorres tus monedas!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('¡Entendido!',
                style: TextStyle(color: _kOro, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

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
            bottomNavigationBar: const _BottomNavTrofeos(),
            appBar: FluixAppBar(
        titulo: 'Mis Trofeos',
        showLeading: true,
        extraActions: [
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
                  onTap: () => _mostrarProximamente(context),
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
                    sliver: SliverList(
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
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF0F7FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                Text(c.label, style: TextStyle(color: sel ? Colors.white : _kMuted, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                if (p != null) ...[
                  const SizedBox(width: 5),
                  Text('${p.completados}', style: TextStyle(color: sel ? Colors.white70 : _kMuted.withValues(alpha: 0.7), fontSize: 10)),
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
    final catColor = def.categoria.color;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context, backgroundColor: Colors.transparent,
          builder: (_) => _DetalleSheet(def: def, completado: widget.completado, progreso: widget.progreso),
        ),
        child: Transform.scale(
          scale: widget.completado ? _scale.value : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.completado ? catColor.withValues(alpha: 0.5) : _kBorde,
                width: widget.completado ? 1.2 : 0.6,
              ),
              boxShadow: widget.completado ? [BoxShadow(
                color: catColor.withValues(alpha: 0.18 * _glow.value),
                blurRadius: 10,
              )] : null,
            ),
            child: Row(children: [
              _HexBadge(
                emoji: def.emoji,
                color: catColor,
                completado: widget.completado,
                glowValue: _glow.value,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(def.titulo, style: const TextStyle(
                    color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(def.descripcion, style: const TextStyle(
                    color: _kMuted, fontSize: 11, height: 1.35),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 10),
              _EstadoTrofeo(completado: widget.completado, color: catColor),
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
        color: const Color(0xFFF8FAFC),
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

// ── Hex badge ─────────────────────────────────────────────────────────────────

class _HexBadge extends StatelessWidget {
  final String emoji;
  final Color color;
  final bool completado;
  final double glowValue;
  const _HexBadge({required this.emoji, required this.color,
    required this.completado, this.glowValue = 0.0});

  @override
  Widget build(BuildContext context) {
    final fill   = completado ? color.withValues(alpha: 0.22) : _kCard2;
    final border = completado ? color.withValues(alpha: 0.65) : _kBorde;
    Widget badge = SizedBox(
      width: 54, height: 60,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(54, 60),
          painter: _HexPainter(fill: fill, border: border,
            shimmerColor: completado ? color : Colors.transparent,
            shimmerProgress: glowValue),
        ),
        Text(emoji, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
      ]),
    );
    if (!completado) {
      badge = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: badge,
      );
    }
    return badge;
  }
}

// ── Estado de trofeo ───────────────────────────────────────────────────────────

class _EstadoTrofeo extends StatelessWidget {
  final bool completado;
  final Color color;
  const _EstadoTrofeo({required this.completado, required this.color});

  @override
  Widget build(BuildContext context) {
    if (completado) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text('Obtenido', style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]);
    }
    return const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_rounded, size: 28, color: _kMuted),
      SizedBox(height: 2),
      Text('Bloqueado', style: TextStyle(
        color: _kMuted, fontSize: 10, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Hex painter ────────────────────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  final Color fill;
  final Color border;
  final Color shimmerColor;
  final double shimmerProgress;
  const _HexPainter({required this.fill, required this.border,
    this.shimmerColor = Colors.transparent, this.shimmerProgress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    if (shimmerProgress > 0 && shimmerColor != Colors.transparent) {
      canvas.drawPath(path, Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent,
            shimmerColor.withValues(alpha: 0.14 * shimmerProgress),
            Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
    canvas.drawPath(path, Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round);
  }

  static Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(size.width, size.height) / 2 * 0.9;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
    old.fill != fill || old.border != border || old.shimmerProgress != shimmerProgress;
}

// Alias de compatibilidad
class TrofeoService {
  static Stream<Map<String, Map<String, dynamic>>> streamTrofeos(String uid) => TrofeosService.streamTrofeos(uid);
  static Stream<int> streamMonedas(String uid) => TrofeosService.streamMonedas(uid);
}

// ── Bottom nav (replica del explorar, Perfil seleccionado) ────────────────────

class _BottomNavTrofeos extends StatelessWidget {
  const _BottomNavTrofeos();

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
          child: Row(children: [
            _BotNavItem(icon: Icons.grid_view_rounded, label: 'Explorar', selected: false,
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst)),
            _BotNavItem(icon: Icons.favorite_rounded, label: 'Favoritos', selected: false,
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst)),
            _BotNavItem(icon: Icons.person_rounded, label: 'Perfil', selected: true,
              onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

class _BotNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BotNavItem({required this.icon, required this.label,
    required this.selected, required this.onTap});

  static const _accent = Color(0xFF00BFA5);
  static const _muted  = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D47A1).withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: selected ? _accent : _muted),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? _accent : _muted,
          )),
        ]),
      ),
    ),
  );
}
