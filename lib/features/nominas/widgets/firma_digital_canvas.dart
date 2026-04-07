import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FIRMA DIGITAL — Canvas táctil con CustomPainter
// ═══════════════════════════════════════════════════════════════════════════════

class FirmaDigitalCanvas extends StatefulWidget {
  final double width;
  final double height;
  final ValueChanged<Uint8List>? onFirmaConfirmada;

  const FirmaDigitalCanvas({
    super.key,
    this.width = 350,
    this.height = 200,
    this.onFirmaConfirmada,
  });

  @override
  State<FirmaDigitalCanvas> createState() => _FirmaDigitalCanvasState();
}

class _FirmaDigitalCanvasState extends State<FirmaDigitalCanvas> {
  final List<List<Offset>> _trazos = [];
  List<Offset> _trazoActual = [];
  bool _haFirmado = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Canvas ─────────────────────────────────────────────────────
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onPanStart: (det) {
                setState(() {
                  _trazoActual = [det.localPosition];
                  _haFirmado = true;
                });
              },
              onPanUpdate: (det) {
                setState(() {
                  _trazoActual = [..._trazoActual, det.localPosition];
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _trazos.add(List.from(_trazoActual));
                  _trazoActual = [];
                });
              },
              child: CustomPaint(
                painter: _FirmaPainter(_trazos, _trazoActual),
                size: Size(widget.width, widget.height),
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),
        Text(
          _haFirmado ? '' : 'Firme con el dedo en el recuadro',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 12),

        // ── Botones ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Borrar'),
              onPressed: () {
                setState(() {
                  _trazos.clear();
                  _trazoActual.clear();
                  _haFirmado = false;
                });
              },
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmar firma'),
              onPressed: _haFirmado ? _confirmar : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmar() async {
    final png = await _exportarPng();
    if (png != null) {
      widget.onFirmaConfirmada?.call(png);
    }
  }

  Future<Uint8List?> _exportarPng() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, widget.width, widget.height),
      );

      // Fondo blanco
      canvas.drawRect(
        Rect.fromLTWH(0, 0, widget.width, widget.height),
        Paint()..color = Colors.white,
      );

      // Dibujar trazos
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (final trazo in _trazos) {
        if (trazo.length < 2) continue;
        final path = Path()..moveTo(trazo.first.dx, trazo.first.dy);
        for (int i = 1; i < trazo.length; i++) {
          path.lineTo(trazo[i].dx, trazo[i].dy);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        widget.width.toInt(),
        widget.height.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

class _FirmaPainter extends CustomPainter {
  final List<List<Offset>> trazos;
  final List<Offset> trazoActual;

  _FirmaPainter(this.trazos, this.trazoActual);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Línea de firma punteada
    final lineaPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(20, size.height * 0.75),
      Offset(size.width - 20, size.height * 0.75),
      lineaPaint,
    );

    // Trazos completados
    for (final trazo in trazos) {
      _dibujarTrazo(canvas, trazo, paint);
    }

    // Trazo actual
    _dibujarTrazo(canvas, trazoActual, paint);
  }

  void _dibujarTrazo(Canvas canvas, List<Offset> puntos, Paint paint) {
    if (puntos.length < 2) return;
    final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (int i = 1; i < puntos.length; i++) {
      path.lineTo(puntos[i].dx, puntos[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter old) => true;
}

