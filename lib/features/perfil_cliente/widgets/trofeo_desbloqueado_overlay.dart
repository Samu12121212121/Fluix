import 'package:flutter/material.dart';
import '../models/trofeo_def.dart';

class TrofeoDesbloqueadoOverlay extends StatefulWidget {
  final String trofeoId;
  final VoidCallback onDismiss;
  const TrofeoDesbloqueadoOverlay({super.key, required this.trofeoId, required this.onDismiss});

  @override
  State<TrofeoDesbloqueadoOverlay> createState() => _TrofeoDesbloqueadoOverlayState();
}

class _TrofeoDesbloqueadoOverlayState extends State<TrofeoDesbloqueadoOverlay>
    with TickerProviderStateMixin {
  late AnimationController _enter, _pulse;
  late Animation<double> _scale, _opacity, _pulseSz;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..forward();
    _pulse = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _scale   = CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(parent: _enter, curve: Curves.easeIn);
    _pulseSz = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    // Auto-dismiss tras 3.5 segundos
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _enter.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = kTrofeos.where((t) => t.id == widget.trofeoId).firstOrNull;
    if (def == null) return const SizedBox.shrink();

    final catColor  = def.categoria.color;
    final tierColor = def.tier.color;

    return GestureDetector(
      onTap: _dismiss,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _pulse]),
        builder: (ctx, _) => Opacity(
          opacity: _opacity.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.75 * _opacity.value),
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: _TarjetaCelebracion(
                  def: def,
                  catColor: catColor,
                  tierColor: tierColor,
                  pulseScale: _pulseSz.value,
                  onDismiss: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaCelebracion extends StatelessWidget {
  final TrofeoDef def;
  final Color catColor, tierColor;
  final double pulseScale;
  final VoidCallback onDismiss;
  const _TarjetaCelebracion({
    required this.def, required this.catColor, required this.tierColor,
    required this.pulseScale, required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: catColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(color: catColor.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Etiqueta
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: catColor.withValues(alpha: 0.4)),
          ),
          child: Text('¡Trofeo desbloqueado!', style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 20),
        // Emoji pulsante
        Transform.scale(
          scale: pulseScale,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: catColor.withValues(alpha: 0.12),
              border: Border.all(color: catColor.withValues(alpha: 0.5), width: 2),
              boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Text(def.emoji, style: const TextStyle(fontSize: 52)),
          ),
        ),
        const SizedBox(height: 18),
        Text(def.titulo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        // Tier badge
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(def.tier.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(def.tier.label, style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        Text(def.descripcion, style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        if (def.monedas > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB830).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB830).withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('+${def.monedas} monedas', style: const TextStyle(color: Color(0xFFFFB830), fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Text('Toca para continuar', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
      ]),
    );
  }
}
