import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET CANVAS DE FIRMA TÁCTIL
// Permite al empleado firmar con el dedo en la pantalla.
// ═══════════════════════════════════════════════════════════════════════════════

class FirmaFiniquitoCanvas extends StatefulWidget {
  final void Function(List<List<Offset>> trazos)? onChanged;
  final Color colorTrazo;
  final double grosorTrazo;
  final double height;

  const FirmaFiniquitoCanvas({
    super.key,
    this.onChanged,
    this.colorTrazo = Colors.black,
    this.grosorTrazo = 2.5,
    this.height = 180,
  });

  @override
  State<FirmaFiniquitoCanvas> createState() => FirmaCanvasState();
}

class FirmaCanvasState extends State<FirmaFiniquitoCanvas> {
  final List<List<Offset>> _trazos = [];
  List<Offset>? _trazoActual;

  bool get estaVacio => _trazos.isEmpty && _trazoActual == null;

  /// Lista de trazos completados para exportar a PNG.
  List<List<Offset>> get trazos => List.unmodifiable(_trazos);

  /// Borra toda la firma.
  void limpiar() {
    setState(() {
      _trazos.clear();
      _trazoActual = null;
    });
    widget.onChanged?.call([]);
  }

  void _comenzarTrazo(Offset pos) {
    setState(() => _trazoActual = [pos]);
  }

  void _continuarTrazo(Offset pos) {
    if (_trazoActual == null) return;
    setState(() => _trazoActual!.add(pos));
  }

  void _terminarTrazo() {
    if (_trazoActual != null && _trazoActual!.isNotEmpty) {
      _trazos.add(List.from(_trazoActual!));
      _trazoActual = null;
      widget.onChanged?.call(List.from(_trazos));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Área de firma ──────────────────────────────────────────────────
        GestureDetector(
          onPanStart: (d) => _comenzarTrazo(d.localPosition),
          onPanUpdate: (d) => _continuarTrazo(d.localPosition),
          onPanEnd: (_) => _terminarTrazo(),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: estaVacio ? Colors.grey.shade400 : Colors.black87,
                width: estaVacio ? 1.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _FirmaPainter(
                  trazos: _trazos,
                  trazoActual: _trazoActual,
                  color: widget.colorTrazo,
                  grosor: widget.grosorTrazo,
                ),
                child: estaVacio
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gesture, size: 32,
                                color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text(
                              'Firme aquí con el dedo',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),

        // ── Botones ────────────────────────────────────────────────────────
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: limpiar,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('Borrar y repetir'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _FirmaPainter extends CustomPainter {
  final List<List<Offset>> trazos;
  final List<Offset>? trazoActual;
  final Color color;
  final double grosor;

  const _FirmaPainter({
    required this.trazos,
    required this.trazoActual,
    required this.color,
    required this.grosor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void dibujarTrazo(List<Offset> puntos) {
      if (puntos.length < 2) {
        // Punto suelto (tap)
        if (puntos.length == 1) {
          canvas.drawCircle(puntos.first, grosor / 2, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        return;
      }
      final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (int i = 1; i < puntos.length; i++) {
        path.lineTo(puntos[i].dx, puntos[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final trazo in trazos) {
      dibujarTrazo(trazo);
    }
    if (trazoActual != null) {
      dibujarTrazo(trazoActual!);
    }
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter old) => true;
}

