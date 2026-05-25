import 'package:flutter/material.dart';

/// Widget de rating Fluix reutilizable en tarjetas y detalle de negocio.
/// IMPORTANTE: Solo muestra rating_fluix, nunca rating de Google.
class ResumenRating extends StatelessWidget {
  final double? ratingFluix;
  final int? totalValoraciones;
  final bool compacto;        // true → una línea pequeña para cards
  final bool mostrarContador; // false → solo estrellas + número

  const ResumenRating({
    super.key,
    this.ratingFluix,
    this.totalValoraciones,
    this.compacto = false,
    this.mostrarContador = true,
  });

  static const _amarillo = Color(0xFFFFBB00);
  static const _muted    = Color(0xFFB0B3C1);
  static const _hint     = Color(0xFF6B6E82);

  @override
  Widget build(BuildContext context) {
    if (ratingFluix == null && (totalValoraciones ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return compacto ? _compacto() : _detallado();
  }

  // ── Versión compacta para cards (una línea) ──────────────────
  Widget _compacto() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 12, color: _amarillo),
      const SizedBox(width: 3),
      if (ratingFluix != null)
        Text(ratingFluix!.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      if (mostrarContador && totalValoraciones != null && totalValoraciones! > 0) ...[
        const SizedBox(width: 3),
        Text('(${_formatCount(totalValoraciones!)})',
            style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    ]);
  }

  // ── Versión detallada para pantalla de negocio ───────────────
  Widget _detallado() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic, children: [
        const Icon(Icons.star_rounded, size: 20, color: _amarillo),
        const SizedBox(width: 6),
        Text(ratingFluix?.toStringAsFixed(1) ?? '—',
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(width: 6),
        Text('/ 5', style: const TextStyle(fontSize: 14, color: _muted)),
      ]),
      const SizedBox(height: 6),
      _estrellasFila(ratingFluix ?? 0),
      if (mostrarContador && totalValoraciones != null) ...[
        const SizedBox(height: 4),
        Text('${_formatCount(totalValoraciones!)} reseñas Fluix',
            style: const TextStyle(fontSize: 12, color: _hint)),
      ],
    ]);
  }

  // ── Fila de estrellas media ──────────────────────────────────
  Widget _estrellasFila(double rating) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      final llena = i < rating.floor();
      final media = !llena && i < rating;
      return Icon(
        llena ? Icons.star_rounded
            : media ? Icons.star_half_rounded
            : Icons.star_outline_rounded,
        size: compacto ? 12 : 18,
        color: (llena || media) ? _amarillo : _hint,
      );
    }));
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA DE DISTRIBUCIÓN DE ESTRELLAS (para PantallaValoracionesNegocio)
// ─────────────────────────────────────────────────────────────────────────────
class BarraDistribucionEstrellas extends StatelessWidget {
  final Map<int, int> distribucion; // {5: 80, 4: 20, 3: 5, 2: 2, 1: 3}

  const BarraDistribucionEstrellas({super.key, required this.distribucion});

  static const _amarillo = Color(0xFFFFBB00);
  static const _borde    = Color(0xFF2A2E45);
  static const _muted    = Color(0xFFB0B3C1);

  @override
  Widget build(BuildContext context) {
    final total = distribucion.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(5, (i) {
        final estrella = 5 - i;
        final count    = distribucion[estrella] ?? 0;
        final pct      = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            SizedBox(width: 14,
                child: Text('$estrella', style: const TextStyle(
                    fontSize: 11, color: _muted))),
            const Icon(Icons.star_rounded, size: 11, color: _amarillo),
            const SizedBox(width: 6),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _borde,
                valueColor: const AlwaysStoppedAnimation(_amarillo),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 28, child: Text('$count',
                style: const TextStyle(fontSize: 10, color: _muted),
                textAlign: TextAlign.right)),
          ]),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA DISTRIBUCIÓN ESTRELLAS
// ─────────────────────────────────────────────────────────────────────────────
class BarraDistribucionEstrellas extends StatelessWidget {
  final Map<int, int> distribucion;
  const BarraDistribucionEstrellas({super.key, required this.distribucion});

  @override
  Widget build(BuildContext context) {
    final total = distribucion.values.fold(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final count = distribucion[star] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Text('$star★', style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: Color(0xFFB0B3C1))),
            const SizedBox(width: 8),
            Expanded(child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2E45),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBB00),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 32, child: Text('$count',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B6E82)))),
          ]),
        );
      }).toList(),
    );
  }
}


