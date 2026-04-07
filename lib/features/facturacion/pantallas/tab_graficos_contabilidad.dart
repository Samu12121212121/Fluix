import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contabilidad_service.dart';
import '../../../domain/modelos/contabilidad.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB GRÁFICOS DE EVOLUCIÓN
// ═════════════════════════════════════════════════════════════════════════════

class TabGraficosContabilidad extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;

  const TabGraficosContabilidad({
    super.key,
    required this.empresaId,
    required this.anio,
    required this.svc,
  });

  @override
  State<TabGraficosContabilidad> createState() =>
      _TabGraficosContabilidadState();
}

class _TabGraficosContabilidadState extends State<TabGraficosContabilidad> {
  List<DatoMensual>? _datos;
  bool _cargando = true;
  int? _mesSeleccionado; // null = ninguno

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(TabGraficosContabilidad old) {
    super.didUpdateWidget(old);
    if (old.anio != widget.anio || old.empresaId != widget.empresaId) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _mesSeleccionado = null;
    });
    try {
      final datos = await widget.svc.obtenerDatosMensuales(
          widget.empresaId, widget.anio);
      if (mounted) setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final datos = _datos ?? [];
    final totalIngresos = datos.fold(0.0, (s, d) => s + d.ingresos);
    final totalGastos = datos.fold(0.0, (s, d) => s + d.gastos);
    final beneficioNeto = totalIngresos - totalGastos;

    // Mes actual para filtrar meses futuros
    final mesActual = DateTime.now().year == widget.anio
        ? DateTime.now().month
        : 12;

    final datosFiltrados = datos.take(mesActual).toList();
    final maxValor = datosFiltrados.fold(
        0.0,
        (m, d) => [m, d.ingresos, d.gastos].reduce(
            (a, b) => a > b ? a : b));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPIs anuales ──────────────────────────────────────────────────
        _buildKpisAnuales(totalIngresos, totalGastos, beneficioNeto, color),
        const SizedBox(height: 16),

        // ── Gráfico de barras ─────────────────────────────────────────────
        _buildCardChart(
          titulo: 'Ingresos vs Gastos por mes',
          icono: Icons.bar_chart,
          color: color,
          child: Column(
            children: [
              // Leyenda
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _leyenda('Ingresos', Colors.green),
                  const SizedBox(width: 20),
                  _leyenda('Gastos', Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: maxValor <= 0
                    ? Center(
                        child: Text('Sin datos en ${widget.anio}',
                            style: TextStyle(color: Colors.grey[400])))
                    : BarChart(
                        BarChartData(
                          maxY: maxValor * 1.25,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(
                              color: Color(0xFFEEEEEE),
                              strokeWidth: 0.8,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex,
                                  rod, rodIndex) {
                                final etiqueta =
                                    rodIndex == 0 ? 'Ingresos' : 'Gastos';
                                return BarTooltipItem(
                                  '$etiqueta\n${rod.toY.toStringAsFixed(0)}€',
                                  const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                );
                              },
                            ),
                            touchCallback: (event, response) {
                              if (event is FlTapUpEvent &&
                                  response?.spot != null) {
                                setState(() {
                                  final idx = response!.spot!.touchedBarGroupIndex;
                                  _mesSeleccionado =
                                      _mesSeleccionado == idx + 1
                                          ? null
                                          : idx + 1;
                                });
                              }
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (v, _) {
                                  final i = v.toInt();
                                  if (i < 0 ||
                                      i >= datosFiltrados.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    datosFiltrados[i].nombreCorto,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _mesSeleccionado == i + 1
                                          ? color
                                          : Colors.grey,
                                      fontWeight:
                                          _mesSeleccionado == i + 1
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: datosFiltrados
                              .asMap()
                              .entries
                              .map((e) {
                            final sel =
                                _mesSeleccionado == e.key + 1;
                            return BarChartGroupData(
                              x: e.key,
                              barsSpace: 3,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.ingresos,
                                  width: 7,
                                  color: Colors.green
                                      .withValues(alpha: sel ? 1 : 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                BarChartRodData(
                                  toY: e.value.gastos,
                                  width: 7,
                                  color: Colors.red
                                      .withValues(alpha: sel ? 1 : 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Detalle del mes seleccionado ──────────────────────────────────
        if (_mesSeleccionado != null) ...[
          _buildDetalleMes(
              datos[_mesSeleccionado! - 1], _mesSeleccionado!, color),
          const SizedBox(height: 14),
        ],

        // ── Gráfico P&L (línea de beneficio acumulado) ────────────────────
        _buildCardChart(
          titulo: 'Beneficio neto mensual',
          icono: Icons.show_chart,
          color: color,
          child: SizedBox(
            height: 160,
            child: datosFiltrados.every((d) => d.beneficio == 0)
                ? Center(
                    child: Text('Sin datos',
                        style: TextStyle(color: Colors.grey[400])))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFEEEEEE),
                          strokeWidth: 0.8,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= datosFiltrados.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                datosFiltrados[i].nombreCorto,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    '${s.y >= 0 ? '+' : ''}${s.y.toStringAsFixed(0)}€',
                                    TextStyle(
                                      color: s.y >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: datosFiltrados.asMap().entries.map((e) {
                            return FlSpot(
                                e.key.toDouble(), e.value.beneficio);
                          }).toList(),
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: spot.y >= 0
                                  ? Colors.green
                                  : Colors.red,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.2),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        // Línea cero
                        LineChartBarData(
                          spots: List.generate(
                              datosFiltrados.length,
                              (i) => FlSpot(i.toDouble(), 0)),
                          color: Colors.grey.withValues(alpha: 0.3),
                          barWidth: 1,
                          dotData: const FlDotData(show: false),
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Tabla resumen mensual ─────────────────────────────────────────
        _buildTablaMensual(datosFiltrados, color),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildKpisAnuales(double ingresos, double gastos,
      double beneficio, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Row(children: [
        _kpiAnual('Total ingresos', '${ingresos.toStringAsFixed(0)}€',
            Colors.green),
        _divV(),
        _kpiAnual('Total gastos', '${gastos.toStringAsFixed(0)}€',
            Colors.red),
        _divV(),
        _kpiAnual(
          beneficio >= 0 ? 'Beneficio neto' : 'Pérdida neta',
          '${beneficio >= 0 ? '+' : ''}${beneficio.toStringAsFixed(0)}€',
          beneficio >= 0 ? color : Colors.red,
        ),
      ]),
    );
  }

  Widget _kpiAnual(String label, String valor, Color c) => Expanded(
        child: Column(children: [
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: c)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _divV() =>
      Container(width: 1, height: 36, color: Colors.grey[200]);

  Widget _leyenda(String label, Color color) => Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _buildDetalleMes(DatoMensual dato, int mes, Color color) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_today, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              '${meses[mes]} ${widget.anio}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _mesSeleccionado = null),
              child: Icon(Icons.close, color: color, size: 18),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _datoMes('Ingresos', dato.ingresos, Colors.green)),
            Expanded(child: _datoMes('Gastos', dato.gastos, Colors.red)),
            Expanded(
                child: _datoMes(
              dato.hayBeneficio ? 'Beneficio' : 'Pérdida',
              dato.beneficio,
              dato.hayBeneficio ? color : Colors.red,
            )),
          ]),
        ],
      ),
    );
  }

  Widget _datoMes(String label, double valor, Color c) => Column(
        children: [
          Text(
            '${valor >= 0 ? '' : '-'}${valor.abs().toStringAsFixed(2)}€',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: c),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );

  Widget _buildTablaMensual(List<DatoMensual> datos, Color color) {
    if (datos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.table_chart_outlined, size: 16, color: Colors.grey),
            SizedBox(width: 6),
            Text('Resumen mensual',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          // Cabecera
          Row(children: [
            const SizedBox(width: 40),
            _celdaH('Ingresos'),
            _celdaH('Gastos'),
            _celdaH('Beneficio'),
          ]),
          const Divider(height: 8),
          ...datos.where((d) => d.ingresos > 0 || d.gastos > 0).map((d) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    d.nombreCorto,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ),
                _celdaV('${d.ingresos.toStringAsFixed(0)}€',
                    Colors.green),
                _celdaV('${d.gastos.toStringAsFixed(0)}€',
                    Colors.red),
                _celdaV(
                  '${d.beneficio >= 0 ? '+' : ''}${d.beneficio.toStringAsFixed(0)}€',
                  d.hayBeneficio ? color : Colors.red,
                  negrita: true,
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _celdaH(String text) => Expanded(
        child: Text(text,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
      );

  Widget _celdaV(String text, Color color, {bool negrita = false}) =>
      Expanded(
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight:
                  negrita ? FontWeight.bold : FontWeight.normal),
        ),
      );

  Widget _buildCardChart({
    required String titulo,
    required IconData icono,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, color: color, size: 16),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}


