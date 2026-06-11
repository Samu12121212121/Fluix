import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/modelos/mesa.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Dato que viaja dentro del Draggable del canvas
// ═══════════════════════════════════════════════════════════════════════════

class PlanoCanvasDrag {
  /// null → mesa nueva desde el panel lateral
  final String? mesaId;

  /// 'rect' | 'circle' | 'bar'  (usado solo cuando mesaId == null)
  final String forma;

  const PlanoCanvasDrag({this.mesaId, required this.forma});
}

// ═══════════════════════════════════════════════════════════════════════════
// MesaCanvasItem — Widget que representa una mesa en el plano visual
// ═══════════════════════════════════════════════════════════════════════════

class MesaCanvasItem extends StatelessWidget {
  final Mesa mesa;
  final bool seleccionada;
  final bool modoEdicion;
  final VoidCallback onTap;

  /// [x, y] en fracción 0-1 relativa al canvas. Se invoca al soltar el drag.
  final void Function(double x, double y)? onDropped;

  /// Importe de la comanda activa (opcional, se muestra si > 0)
  final double? importeComanda;

  const MesaCanvasItem({
    super.key,
    required this.mesa,
    required this.seleccionada,
    required this.modoEdicion,
    required this.onTap,
    this.onDropped,
    this.importeComanda,
  });

  // ── Colores por estado ────────────────────────────────────────────────────
  static const _colorLibre     = Color(0xFF1D9E75);
  static const _colorOcupada   = Color(0xFFE24B4A);
  static const _colorReservada = Color(0xFFEF9F27);

  Color get _colorBase {
    return switch (mesa.estado) {
      'ocupada'   => _colorOcupada,
      'reservada' => _colorReservada,
      _           => _colorLibre,
    };
  }

  // ── Forma del borde ───────────────────────────────────────────────────────
  BorderRadius _borderRadius() {
    return switch (mesa.forma) {
      'circle' => BorderRadius.circular(9999),
      'bar'    => BorderRadius.circular(6),
      _        => BorderRadius.circular(10),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorBase;
    final contenido = _Contenido(
      mesa: mesa,
      color: color,
      seleccionada: seleccionada,
      borderRadius: _borderRadius(),
      importeComanda: importeComanda,
    );

    if (!modoEdicion) {
      return GestureDetector(onTap: onTap, child: contenido);
    }

    return GestureDetector(
      onTap: onTap,
      child: Draggable<PlanoCanvasDrag>(
        data: PlanoCanvasDrag(mesaId: mesa.id, forma: mesa.forma),
        feedback: Opacity(opacity: 0.8, child: contenido),
        childWhenDragging: Opacity(opacity: 0.25, child: contenido),
        child: contenido,
      ),
    );
  }
}

// ── Contenido visual de la tarjeta ───────────────────────────────────────────

class _Contenido extends StatelessWidget {
  final Mesa mesa;
  final Color color;
  final bool seleccionada;
  final BorderRadius borderRadius;
  final double? importeComanda;

  const _Contenido({
    required this.mesa,
    required this.color,
    required this.seleccionada,
    required this.borderRadius,
    this.importeComanda,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}';
    final importe = importeComanda ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: borderRadius,
        border: Border.all(
          color: seleccionada ? Colors.white : color,
          width: seleccionada ? 2.5 : 1.5,
        ),
        boxShadow: seleccionada
            ? [BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 8)]
            : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (mesa.zona.isNotEmpty)
            Text(
              mesa.zona,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                height: 1.2,
              ),
            ),
          const SizedBox(height: 2),
          if (importe > 0)
            Text(
              NumberFormat.currency(symbol: '€', decimalDigits: 2).format(importe),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 9, color: Colors.white.withValues(alpha: 0.55)),
                const SizedBox(width: 2),
                Text(
                  '${mesa.capacidad}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Widget arrastrable del panel lateral (nueva mesa) ───────────────────────

class NuevaMesaDraggable extends StatelessWidget {
  final String forma;
  final IconData icono;
  final String etiqueta;

  const NuevaMesaDraggable({
    super.key,
    required this.forma,
    required this.icono,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3D50)),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(etiqueta,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );

    return Draggable<PlanoCanvasDrag>(
      data: PlanoCanvasDrag(forma: forma),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

