import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import 'fichajes_colors.dart';

// ── FichajeEstadoActualCard ────────────────────────────────────────────────────

class FichajeEstadoActualCard extends StatelessWidget {
  final Fichaje? misFichaje;
  final DateTime ahora;
  final String nombreUsuario;

  const FichajeEstadoActualCard({
    super.key,
    required this.misFichaje,
    required this.ahora,
    required this.nombreUsuario,
  });

  @override
  Widget build(BuildContext context) {
    final entrada = misFichaje?.entrada?.toDate().toLocal();
    final trabajando = misFichaje != null && misFichaje!.salida == null;
    final finalizado = misFichaje?.salida != null;
    final horasMin = misFichaje?.tiempoNeto?.inMinutes ?? 0;
    final horasTxt =
        '${horasMin ~/ 60}h ${(horasMin % 60).toString().padLeft(2, '0')}m';
    final entradaTxt =
        entrada != null ? DateFormat('HH:mm').format(entrada) : '—';
    final salidaPrevTxt = entrada != null
        ? DateFormat('HH:mm')
            .format(entrada.add(const Duration(hours: 8)))
        : '—';

    return fichajeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mi estado actual',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFText)),
        const SizedBox(height: 14),
        Row(children: [
          Stack(children: [
            const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(Icons.person, size: 24, color: kFSub)),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: trabajando ? kFGreen : kFGray,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  )),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombreUsuario,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kFText),
                      overflow: TextOverflow.ellipsis),
                  const Text('Administrador',
                      style: TextStyle(fontSize: 11, color: kFSub)),
                ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trabajando
                  ? kFGreen.withValues(alpha: 0.1)
                  : finalizado
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trabajando
                  ? 'Trabajando'
                  : finalizado
                      ? 'Finalizada'
                      : 'Sin fichar',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: trabajando
                    ? kFGreen
                    : finalizado
                        ? const Color(0xFF3B82F6)
                        : kFGray,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: kFBorder),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _infoRow(
                  Icons.access_time_outlined, 'Entrada hoy', entradaTxt)),
          Expanded(
              child: _infoRow(
                  Icons.timer_outlined, 'Salida prev.', salidaPrevTxt)),
        ]),
        const SizedBox(height: 10),
        _infoRow(
            Icons.schedule_outlined, 'Horas trabajadas', horasTxt),
      ]),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: kFSub),
        const SizedBox(width: 6),
        Flexible(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: kFSub),
                overflow: TextOverflow.ellipsis),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kFText),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);
}

// ── FichajeAsistenciaHoyCard ──────────────────────────────────────────────────

class FichajeAsistenciaHoyCard extends StatelessWidget {
  final List<Fichaje> fichajes;

  const FichajeAsistenciaHoyCard({super.key, required this.fichajes});

  @override
  Widget build(BuildContext context) {
    final total = fichajes.length;
    final trabajando = fichajes
        .where((f) =>
            f.salida == null &&
            !f.pausas.any((p) => p.fin == null))
        .length;
    final enPausa =
        fichajes.where((f) => f.pausas.any((p) => p.fin == null)).length;
    final finalizados =
        fichajes.where((f) => f.salida != null).length;
    final pW = total > 0 ? trabajando / total : 0.0;
    final pP = total > 0 ? enPausa / total : 0.0;

    return fichajeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Asistencia hoy',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFText)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
                painter: _DonutPainter(trabajando: pW, enPausa: pP)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              _legend(kFGreen, 'Trabajando', trabajando,
                  total > 0 ? (trabajando * 100 ~/ total) : 0),
              const SizedBox(height: 8),
              _legend(kFOrange, 'En pausa', enPausa,
                  total > 0 ? (enPausa * 100 ~/ total) : 0),
              const SizedBox(height: 8),
              _legend(kFGray, 'Finalizados', finalizados,
                  total > 0 ? (finalizados * 100 ~/ total) : 0),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: kFBorder),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Total empleados',
              style: TextStyle(fontSize: 11, color: kFSub)),
          const Spacer(),
          Text('$total',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kFText)),
        ]),
      ]),
    );
  }

  static Widget _legend(Color color, String label, int count, int pct) =>
      Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: kFSub))),
        Text('$count ($pct%)',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kFText)),
      ]);
}

// ── FichajeProductividadSemanalCard ───────────────────────────────────────────

class FichajeProductividadSemanalCard extends StatelessWidget {
  final List<double> semanaData;
  final List<String> semanaLabels;
  final bool cargando;
  final VoidCallback? onVerInformes;

  const FichajeProductividadSemanalCard({
    super.key,
    required this.semanaData,
    required this.semanaLabels,
    required this.cargando,
    this.onVerInformes,
  });

  @override
  Widget build(BuildContext context) {
    final values = semanaData.isEmpty
        ? List<double>.filled(7, 0.0)
        : semanaData;
    final labels = semanaLabels.isEmpty
        ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
        : semanaLabels;
    final avg = values.where((v) => v > 0).isEmpty
        ? 0.0
        : values.where((v) => v > 0).fold(0.0, (s, v) => s + v) /
            values.where((v) => v > 0).length;

    return fichajeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Productividad semanal',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kFText))),
          if (cargando)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kFGreen))
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kFGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${avg.toStringAsFixed(0)}% prom',
                  style: const TextStyle(
                      fontSize: 10,
                      color: kFGreen,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 4),
        const Text('% horas trabajadas vs objetivo (8h/empleado)',
            style: TextStyle(fontSize: 10, color: kFSub)),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: CustomPaint(
            painter: _LinePainter(values: values, color: kFGreen),
            size: const Size(double.infinity, 110),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((d) => Text(d,
                  style: const TextStyle(fontSize: 9.5, color: kFSub)))
              .toList(),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onVerInformes,
          child: const Row(children: [
            Text('Ver informes detallados',
                style: TextStyle(
                    fontSize: 12,
                    color: kFGreen,
                    fontWeight: FontWeight.w500)),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 14, color: kFGreen),
          ]),
        ),
      ]),
    );
  }
}

// ── Painters (privados) ────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final double trabajando;
  final double enPausa;

  const _DonutPainter({required this.trabajando, required this.enPausa});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 4;
    final stroke = r * 0.38;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const start = -math.pi / 2;

    void arc(double s, double sweep, Color color) {
      canvas.drawArc(
          rect,
          s,
          sweep,
          false,
          Paint()
            ..color = color
            ..strokeWidth = stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt);
    }

    final fin = 1.0 - trabajando - enPausa;
    arc(start, 2 * math.pi * (fin > 0 ? fin : 0), kFGray);
    arc(start + 2 * math.pi * (fin > 0 ? fin : 0),
        2 * math.pi * enPausa, kFOrange);
    arc(
        start +
            2 * math.pi * ((fin > 0 ? fin : 0) + enPausa),
        2 * math.pi * trabajando,
        kFGreen);

    canvas.drawCircle(Offset(cx, cy), r - stroke / 2,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.trabajando != trabajando || old.enPausa != enPausa;
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _LinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final rng = maxV - minV == 0 ? 1.0 : maxV - minV;

    const yPcts = [100, 75, 50, 25, 0];
    for (int i = 0; i < yPcts.length; i++) {
      final pBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 8))
            ..pushStyle(
                ui.TextStyle(color: const Color(0xFF9CA3AF)))
            ..addText('${yPcts[i]}%');
      final para = pBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: 28));
      canvas.drawParagraph(para, Offset(0, (size.height / 4) * i - 5));
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
          Offset(30, y), Offset(size.width, y), gridPaint);
    }

    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = 30 + (size.width - 30) / (values.length - 1) * i;
      final y = size.height -
          (values[i] - minV) / rng * size.height * 0.9 -
          size.height * 0.05;
      pts.add(Offset(x, y));
    }

    final areaPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(pts.last.dx, size.height);
    areaPath.close();
    canvas.drawPath(
        areaPath,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    for (final p in pts) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }

    final maxIdx = values.indexOf(values.reduce(math.max));
    final maxPt = pts[maxIdx];
    final pBuilder2 =
        ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 9))
          ..pushStyle(ui.TextStyle(
              color: color, fontWeight: ui.FontWeight.bold))
          ..addText('${values[maxIdx].toStringAsFixed(0)}%');
    final para2 = pBuilder2.build()
      ..layout(const ui.ParagraphConstraints(width: 40));
    canvas.drawParagraph(para2, Offset(maxPt.dx - 20, maxPt.dy - 16));
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
