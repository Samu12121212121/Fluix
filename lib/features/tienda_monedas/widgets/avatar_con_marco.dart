import 'package:flutter/material.dart';

/// Renderiza un avatar circular con el marco correspondiente al canje activo.
/// [marco] puede ser 'bronce', 'oro', 'platino' o null.
/// [pulsante] activa el halo de luz animado.
class AvatarConMarco extends StatefulWidget {
  final Widget child;
  final double size;
  final String? marco; // 'bronce' | 'oro' | 'platino' | null
  final bool pulsante;
  final bool temaMidnight;

  const AvatarConMarco({
    super.key,
    required this.child,
    required this.size,
    this.marco,
    this.pulsante = false,
    this.temaMidnight = false,
  });

  @override
  State<AvatarConMarco> createState() => _AvatarConMarcoState();
}

class _AvatarConMarcoState extends State<AvatarConMarco>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;
  late Animation<double> _pulso;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shimmer = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _pulso = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMarco = widget.marco != null;
    final animaNecesaria = hasMarco && widget.marco != 'bronce' || widget.pulsante;

    if (!animaNecesaria && !hasMarco) return _buildBase();

    if (!animaNecesaria) {
      // Bronce: borde estático
      return _wrapConBorde(_buildBase(), _colorBorde, 3.0, null);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        Widget base = _buildBase();
        if (widget.pulsante) {
          base = Transform.scale(scale: _pulso.value, child: base);
          base = _wrapConHalo(base);
        }
        if (hasMarco) {
          base = _wrapConBorde(base, _colorBorde, 3.0,
              widget.marco == 'platino' ? _shimmer.value : null);
        }
        return base;
      },
    );
  }

  Widget _buildBase() => SizedBox(width: widget.size, height: widget.size, child: widget.child);

  Widget _wrapConHalo(Widget child) {
    final haloColor = widget.temaMidnight
        ? const Color(0xFF3F8EFC)
        : const Color(0xFF00FFC8);
    return Container(
      width: widget.size + 10,
      height: widget.size + 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: haloColor.withValues(alpha: 0.4 * _pulso.value),
            blurRadius: 14 * _pulso.value,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _wrapConBorde(Widget child, Color color, double width, double? shimmerVal) {
    final gradient = shimmerVal != null
        ? _gradientPlatino(shimmerVal)
        : null;

    return Container(
      width: widget.size + width * 2 + 4,
      height: widget.size + width * 2 + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        color: gradient == null ? color : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width + 2),
        child: ClipOval(child: child),
      ),
    );
  }

  LinearGradient _gradientPlatino(double t) => LinearGradient(
    begin: Alignment(-1 + t * 2, -1),
    end: Alignment(1, 1 - t),
    colors: const [
      Color(0xFFE8E8E8),
      Color(0xFFFFFFFF),
      Color(0xFFC0C0C0),
      Color(0xFFF0F0F0),
      Color(0xFFE0E0E0),
    ],
  );

  Color get _colorBorde => switch (widget.marco) {
    'bronce'  => const Color(0xFFCD7F32),
    'oro'     => const Color(0xFFFFB830),
    'platino' => const Color(0xFFE0E0E0),
    _         => Colors.transparent,
  };
}
