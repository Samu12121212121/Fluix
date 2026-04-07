import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../services/rating_historial_service.dart';

/// Gráfico de línea con la evolución del rating mes a mes.
/// Muestra mensaje de espera si hay menos de 2 meses de datos.
class GraficoEvolucionRatingWidget extends StatefulWidget {
  final String empresaId;

  const GraficoEvolucionRatingWidget({super.key, required this.empresaId});

  @override
  State<GraficoEvolucionRatingWidget> createState() =>
      _GraficoEvolucionRatingWidgetState();
}

class _GraficoEvolucionRatingWidgetState
    extends State<GraficoEvolucionRatingWidget> {
  final _svc = RatingHistorialService();
  List<RatingSnapshot> _historial = [];
  bool _cargando = true;
  int? _indexTocado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final h = await _svc.obtenerHistorial(widget.empresaId);
    if (mounted) {
      setState(() {
        _historial = h;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Menos de 2 meses → estado vacío informativo
    if (_historial.length < 2) {
      return _EstadoVacioGrafico(
        mesesRecopilados: _historial.length,
      );
    }

    final tendencia = _svc.calcularTendencia(_historial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + tendencia
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Text(
                'Evolución del rating',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87),
              ),
              const Spacer(),
              if (tendencia != null) _BadgeTendencia(tendencia: tendencia),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tooltip al tocar un punto
        if (_indexTocado != null && _indexTocado! < _historial.length)
          _TooltipMes(snapshot: _historial[_indexTocado!]),

        const SizedBox(height: 8),

        // Gráfico
        SizedBox(
          height: 160,
          child: LineChart(
            _construirGrafico(),
            duration: const Duration(milliseconds: 300),
          ),
        ),

        // Nota informativa
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Rating calculado sobre las últimas ${_historial.isNotEmpty ? _historial.last.totalResenasEnFirestore : 0} reseñas almacenadas',
            style: TextStyle(
                fontSize: 10, color: Colors.grey[400], fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  LineChartData _construirGrafico() {
    final puntos = _historial.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.ratingMedio);
    }).toList();

    return LineChartData(
      minY: 1.0,
      maxY: 5.2,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (y) => FlLine(
          color: Colors.grey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 1,
            getTitlesWidget: (value, _) {
              if (value == value.toInt().toDouble()) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 10),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, _) {
              final i = value.toInt();
              if (i < 0 || i >= _historial.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _historial[i].etiquetaMes,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      // Línea de referencia en 4.0
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 4.0,
            color: const Color(0xFF43A047).withValues(alpha: 0.4),
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: TextStyle(
                  color: const Color(0xFF43A047),
                  fontSize: 9,
                  fontWeight: FontWeight.w600),
              labelResolver: (_) => '4.0 ⭐',
            ),
          ),
        ],
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (_, response) {
          final spot =
              response?.lineBarSpots?.firstOrNull?.spotIndex;
          if (mounted) setState(() => _indexTocado = spot);
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
          tooltipRoundedRadius: 8,
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} ⭐',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: puntos,
          isCurved: true,
          curveSmoothness: 0.3,
          color: const Color(0xFFF57C00),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: _indexTocado != null &&
                      _indexTocado == spot.x.toInt()
                  ? 6
                  : 4,
              color: const Color(0xFFF57C00),
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF57C00).withValues(alpha: 0.2),
                const Color(0xFFF57C00).withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _EstadoVacioGrafico extends StatelessWidget {
  final int mesesRecopilados;

  const _EstadoVacioGrafico({required this.mesesRecopilados});

  @override
  Widget build(BuildContext context) {
    final diasTranscurridos = mesesRecopilados * 30;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.show_chart, size: 36, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            'El gráfico de evolución estará disponible\ntras 2 meses de uso',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            mesesRecopilados == 0
                ? 'Llevamos 0 días recopilando datos. Conecta Google Business para empezar.'
                : 'Llevamos aproximadamente $diasTranscurridos días recopilando datos.',
            style: TextStyle(
                color: Colors.grey[500], fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BadgeTendencia extends StatelessWidget {
  final double tendencia;

  const _BadgeTendencia({required this.tendencia});

  @override
  Widget build(BuildContext context) {
    final sube = tendencia > 0;
    final estable = tendencia == 0;
    final color = estable
        ? Colors.grey
        : sube
            ? const Color(0xFF43A047)
            : const Color(0xFFD32F2F);
    final icono = estable
        ? Icons.remove
        : sube
            ? Icons.trending_up
            : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          '${sube ? '+' : ''}${tendencia.toStringAsFixed(2)}',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }
}

class _TooltipMes extends StatelessWidget {
  final RatingSnapshot snapshot;

  const _TooltipMes({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF57C00).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 13, color: Color(0xFFF57C00)),
          const SizedBox(width: 6),
          Text(
            '${snapshot.etiquetaMes}: ${snapshot.ratingMedio.toStringAsFixed(2)} ⭐ '
            '(${snapshot.totalResenasEnFirestore} reseñas)',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

