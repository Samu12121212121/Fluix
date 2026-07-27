import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/contabilidad_service.dart';
import '../../../services/facturacion_service.dart';
import '../../../domain/modelos/contabilidad.dart';
import '../../../domain/modelos/factura.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB GRÁFICOS — 10 charts de análisis financiero
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
  State<TabGraficosContabilidad> createState() => _TabGraficosContabilidadState();
}

class _TabGraficosContabilidadState extends State<TabGraficosContabilidad> {
  static const _verde   = Color(0xFF10B981);
  static const _azul    = Color(0xFF3B82F6);
  static const _rojo    = Color(0xFFEF4444);
  static const _ambar   = Color(0xFFF59E0B);
  static const _morado  = Color(0xFF8B5CF6);
  static const _naranja = Color(0xFFF97316);
  static const _cian    = Color(0xFF06B6D4);
  static const _meses   = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
  static const _dias    = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];

  @override
  void didUpdateWidget(TabGraficosContabilidad old) {
    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Factura>>(
      stream: FacturacionService().obtenerFacturas(widget.empresaId),
      builder: (ctx, facSnap) {
        return FutureBuilder<List<DatoMensual>>(
          key: ValueKey('${widget.empresaId}-${widget.anio}'),
          future: widget.svc.obtenerDatosMensuales(widget.empresaId, widget.anio),
          builder: (ctx, mesSnap) {
            if (mesSnap.connectionState == ConnectionState.waiting && facSnap.data == null) {
              return const Center(child: CircularProgressIndicator(color: _verde));
            }

            final datos   = mesSnap.data ?? [];
            final allFact = (facSnap.data ?? []).where((f) => f.fechaEmision.year == widget.anio).toList();
            final ingr    = allFact.where((f) => f.flujo == 'ingreso').toList();
            final gast    = allFact.where((f) => f.flujo == 'gasto').toList();

            final charts = [
              _chart1IngresosGastos(datos),
              _chart2BeneficioNeto(datos),
              _chart3EstadoFacturas(allFact),
              _chart4TipoFacturacion(allFact),
              _chart5TopClientes(ingr),
              _chart6MetodosPago(allFact),
              _chart7DiasSemana(allFact),
              _chart8MensualColumnas(datos),
              _chart9IVA(ingr, gast),
              _chart10FacturasEmitidas(ingr),
            ];

            return LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 700;
              if (wide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (int i = 0; i < charts.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(child: charts[i]),
                              const SizedBox(width: 14),
                              Expanded(child: i + 1 < charts.length ? charts[i + 1] : const SizedBox()),
                            ]),
                          ),
                        ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: charts.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                itemBuilder: (_, i) => charts[i],
              );
            });
          },
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card(String title, String subtitle, IconData icon, Color color, Widget body) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            ])),
          ]),
          const SizedBox(height: 16),
          body,
        ]),
      );

  Widget _sinDatos() => const SizedBox(height: 160,
      child: Center(child: Text('Sin datos para este período', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))));

  FlGridData get _gridH => FlGridData(show: true, drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1));

  FlBorderData get _noBorder => FlBorderData(show: false);

  AxisTitles get _noTitle => const AxisTitles(sideTitles: SideTitles(showTitles: false));

  LineChartBarData _lineBar(List<FlSpot> spots, Color color, {bool fill = true}) =>
      LineChartBarData(
        spots: spots, color: color, barWidth: 2.5, isCurved: true,
        dotData: const FlDotData(show: false),
        belowBarData: fill ? BarAreaData(show: true, color: color.withValues(alpha: 0.10)) : BarAreaData(show: false),
      );

  PieChartSectionData _pie(double val, Color color, String label) => PieChartSectionData(
    value: val, color: color, title: val >= 5 ? label : '',
    radius: 44, titleStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
  );

  Widget _leyenda(Color color, String label, {String? valor}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
      if (valor != null) Text(valor, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
    ]),
  );

  AxisTitles _bottomMeses(List<String> labels) => AxisTitles(sideTitles: SideTitles(
    showTitles: true, reservedSize: 20,
    getTitlesWidget: (v, _) {
      final i = v.toInt();
      return i >= 0 && i < labels.length
          ? Text(labels[i], style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)))
          : const SizedBox.shrink();
    },
  ));

  // ── 1. Ingresos vs Gastos — línea/área ────────────────────────────────────

  Widget _chart1IngresosGastos(List<DatoMensual> datos) {
    final mesMax = DateTime.now().year == widget.anio ? DateTime.now().month : 12;
    final d = datos.take(mesMax).toList();
    if (d.isEmpty) return _card('Ingresos vs Gastos', 'Evolución mensual', Icons.show_chart, _verde, _sinDatos());
    final maxY = d.fold(0.0, (m, e) => [m, e.ingresos, e.gastos].reduce((a, b) => a > b ? a : b)) * 1.25;
    final labels = d.map((e) => e.nombreCorto).toList();
    return _card('Ingresos vs Gastos', 'Evolución mensual', Icons.show_chart, _verde,
      Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _leyenda(_verde, 'Ingresos'), const SizedBox(width: 16), _leyenda(_rojo, 'Gastos'),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 180, child: LineChart(LineChartData(
          maxY: maxY, gridData: _gridH, borderData: _noBorder,
          titlesData: FlTitlesData(leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle, bottomTitles: _bottomMeses(labels)),
          lineBarsData: [
            _lineBar(d.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ingresos)).toList(), _verde),
            _lineBar(d.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.gastos)).toList(), _rojo),
          ],
        ))),
      ]),
    );
  }

  // ── 2. Beneficio neto — línea ──────────────────────────────────────────────

  Widget _chart2BeneficioNeto(List<DatoMensual> datos) {
    final mesMax = DateTime.now().year == widget.anio ? DateTime.now().month : 12;
    final d = datos.take(mesMax).toList();
    if (d.every((e) => e.beneficio == 0)) return _card('Beneficio neto', 'Resultado por mes', Icons.trending_up, _azul, _sinDatos());
    final spots = d.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.beneficio)).toList();
    final maxY  = spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.3;
    final minY  = spots.fold(0.0, (m, s) => s.y < m ? s.y : m) * 1.3;
    final labels = d.map((e) => e.nombreCorto).toList();
    return _card('Beneficio neto', 'Resultado por mes', Icons.trending_up, _azul,
      SizedBox(height: 210, child: LineChart(LineChartData(
        maxY: maxY.isFinite && maxY != 0 ? maxY : 100,
        minY: minY.isFinite && minY < 0 ? minY : null,
        gridData: _gridH, borderData: _noBorder,
        titlesData: FlTitlesData(leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle, bottomTitles: _bottomMeses(labels)),
        lineBarsData: [_lineBar(spots, _azul)],
      ))),
    );
  }

  // ── 3. Facturas por estado — donut ─────────────────────────────────────────

  Widget _chart3EstadoFacturas(List<Factura> facts) {
    final pag = facts.where((f) => f.estado == EstadoFactura.pagada).length;
    final pen = facts.where((f) => f.estado == EstadoFactura.pendiente).length;
    final vec = facts.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).length;
    final anu = facts.where((f) => f.estado == EstadoFactura.anulada).length;
    final tot = (pag + pen + vec + anu).toDouble();
    if (tot == 0) return _card('Facturas por estado', 'Distribución actual', Icons.donut_large, _azul, _sinDatos());
    return _card('Facturas por estado', 'Distribución actual', Icons.donut_large, _azul,
      SizedBox(height: 180, child: Row(children: [
        Expanded(child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 38, sections: [
          if (pag > 0) _pie(pag / tot * 100, _verde, '${(pag/tot*100).round()}%'),
          if (pen > 0) _pie(pen / tot * 100, _ambar, '${(pen/tot*100).round()}%'),
          if (vec > 0) _pie(vec / tot * 100, _rojo,  '${(vec/tot*100).round()}%'),
          if (anu > 0) _pie(anu / tot * 100, const Color(0xFF94A3B8), '${(anu/tot*100).round()}%'),
        ]))),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _leyenda(_verde, 'Pagadas', valor: '$pag'),
          _leyenda(_ambar, 'Pendientes', valor: '$pen'),
          _leyenda(_rojo,  'Vencidas', valor: '$vec'),
          if (anu > 0) _leyenda(const Color(0xFF94A3B8), 'Anuladas', valor: '$anu'),
        ]),
      ])),
    );
  }

  // ── 4. Facturación por tipo — barras ───────────────────────────────────────

  Widget _chart4TipoFacturacion(List<Factura> facts) {
    final tpv   = facts.where((f) => f.pedidoId != null || (f.ticketIds?.isNotEmpty == true)).fold(0.0, (s, f) => s + f.total);
    final ingr  = facts.where((f) => f.flujo == 'ingreso' && f.pedidoId == null && (f.ticketIds?.isEmpty != false)).fold(0.0, (s, f) => s + f.total);
    final gast  = facts.where((f) => f.flujo == 'gasto').fold(0.0, (s, f) => s + f.total);
    final rect  = facts.where((f) => f.tipo == TipoFactura.rectificativa).fold(0.0, (s, f) => s + f.total.abs());
    if (tpv + ingr + gast + rect == 0) return _card('Facturación por tipo', 'TPV, ingresos, gastos...', Icons.bar_chart, _naranja, _sinDatos());
    final grupos = [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: tpv,  color: _naranja, width: 22, borderRadius: BorderRadius.circular(4))]),
      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: ingr, color: _verde,   width: 22, borderRadius: BorderRadius.circular(4))]),
      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: gast, color: _rojo,    width: 22, borderRadius: BorderRadius.circular(4))]),
      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: rect, color: _morado,  width: 22, borderRadius: BorderRadius.circular(4))]),
    ];
    final labels = ['TPV', 'Ingresos', 'Gastos', 'Rect.'];
    return _card('Facturación por tipo', 'Importe por categoría', Icons.bar_chart, _naranja,
      SizedBox(height: 210, child: BarChart(BarChartData(
        maxY: [tpv, ingr, gast, rect].reduce((a, b) => a > b ? a : b) * 1.3,
        gridData: _gridH, borderData: _noBorder,
        titlesData: FlTitlesData(
          leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
              getTitlesWidget: (v, _) => Text(labels[v.toInt()], style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))))),
        ),
        barGroups: grupos,
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toStringAsFixed(0)}€', const TextStyle(color: Colors.white, fontSize: 11)),
        )),
      ))),
    );
  }

  // ── 5. Top 10 clientes — barras horizontales ───────────────────────────────

  Widget _chart5TopClientes(List<Factura> ingr) {
    final map = <String, double>{};
    for (final f in ingr) {
      final n = f.clienteNombre.isEmpty ? 'General' : f.clienteNombre;
      map[n] = (map[n] ?? 0) + f.total;
    }
    if (map.isEmpty) return _card('Top 10 clientes', 'Mayor facturación', Icons.people_alt_rounded, _cian, _sinDatos());
    final top = (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10).toList();
    final maxVal = top.first.value;
    return _card('Top 10 clientes', 'Mayor facturación', Icons.people_alt_rounded, _cian,
      Column(
        children: top.asMap().entries.map((e) {
          final pct = e.value.value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 90, child: Text(e.value.key, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Expanded(child: Stack(children: [
                Container(height: 14, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(widthFactor: pct, child: Container(height: 14,
                    decoration: BoxDecoration(color: _cian.withValues(alpha: 0.6 + 0.4 * pct), borderRadius: BorderRadius.circular(4)))),
              ])),
              const SizedBox(width: 6),
              SizedBox(width: 56, child: Text('${e.value.value.toStringAsFixed(0)}€', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), textAlign: TextAlign.right)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── 6. Métodos de pago — donut ─────────────────────────────────────────────

  Widget _chart6MetodosPago(List<Factura> facts) {
    final pagadas = facts.where((f) => f.estado == EstadoFactura.pagada).toList();
    final map = <String, double>{};
    for (final f in pagadas) {
      if (f.desgloseMetodoPago != null && f.desgloseMetodoPago!.isNotEmpty) {
        for (final e in f.desgloseMetodoPago!.entries) { map[e.key] = (map[e.key] ?? 0) + e.value; }
      } else if (f.metodoPago != null) {
        final k = f.metodoPago!.etiqueta;
        map[k] = (map[k] ?? 0) + f.total;
      }
    }
    if (map.isEmpty) return _card('Métodos de pago', 'Efectivo, tarjeta, Bizum...', Icons.payment_rounded, _morado, _sinDatos());
    final cols = [_azul, _verde, _ambar, _morado, _naranja, _cian, _rojo];
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tot = entries.fold(0.0, (s, e) => s + e.value);
    return _card('Métodos de pago', 'Efectivo, tarjeta, Bizum...', Icons.payment_rounded, _morado,
      SizedBox(height: 180, child: Row(children: [
        Expanded(child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 38,
          sections: entries.asMap().entries.map((e) => _pie(e.value.value / tot * 100, cols[e.key % cols.length], '${(e.value.value/tot*100).round()}%')).toList(),
        ))),
        const SizedBox(width: 8),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) => _leyenda(cols[e.key % cols.length], e.value.key, valor: '${e.value.value.toStringAsFixed(0)}€')).toList(),
        ),
      ])),
    );
  }

  // ── 7. Cobros por día de la semana — barras ────────────────────────────────

  Widget _chart7DiasSemana(List<Factura> facts) {
    final sums = List.filled(7, 0.0);
    for (final f in facts.where((f) => f.fechaPago != null)) {
      final wd = f.fechaPago!.weekday - 1; // 0=Lun
      sums[wd] += f.total;
    }
    if (sums.every((s) => s == 0)) return _card('Cobros por día semana', 'Detectar patrones', Icons.calendar_view_week_rounded, _ambar, _sinDatos());
    final maxY = sums.reduce((a, b) => a > b ? a : b) * 1.3;
    return _card('Cobros por día semana', 'Detectar patrones', Icons.calendar_view_week_rounded, _ambar,
      SizedBox(height: 210, child: BarChart(BarChartData(
        maxY: maxY,
        gridData: _gridH, borderData: _noBorder,
        titlesData: FlTitlesData(
          leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
              getTitlesWidget: (v, _) => Text(_dias[v.toInt()], style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))))),
        ),
        barGroups: sums.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(toY: e.value, color: _ambar.withValues(alpha: 0.6 + 0.4 * (e.value / (maxY == 0 ? 1 : maxY))),
              width: 22, borderRadius: BorderRadius.circular(4)),
        ])).toList(),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toStringAsFixed(0)}€', const TextStyle(color: Colors.white, fontSize: 11)),
        )),
      ))),
    );
  }

  // ── 8. Facturación por meses — columnas ───────────────────────────────────

  Widget _chart8MensualColumnas(List<DatoMensual> datos) {
    final mesMax = DateTime.now().year == widget.anio ? DateTime.now().month : 12;
    final d = datos.take(mesMax).toList();
    if (d.isEmpty || d.every((e) => e.ingresos == 0)) return _card('Facturación por meses', 'Comparación anual', Icons.bar_chart_rounded, _verde, _sinDatos());
    final maxY = d.fold(0.0, (m, e) => e.ingresos > m ? e.ingresos : m) * 1.3;
    return _card('Facturación por meses', 'Comparación anual', Icons.bar_chart_rounded, _verde,
      SizedBox(height: 210, child: BarChart(BarChartData(
        maxY: maxY,
        gridData: _gridH, borderData: _noBorder,
        titlesData: FlTitlesData(
          leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                return i >= 0 && i < d.length ? Text(d[i].nombreCorto, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))) : const SizedBox.shrink();
              })),
        ),
        barGroups: d.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(toY: e.value.ingresos, color: _verde, width: 14, borderRadius: BorderRadius.circular(4)),
        ])).toList(),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${rod.toY.toStringAsFixed(0)}€', const TextStyle(color: Colors.white, fontSize: 11)),
        )),
      ))),
    );
  }

  // ── 9. IVA repercutido vs soportado — líneas ──────────────────────────────

  Widget _chart9IVA(List<Factura> ingr, List<Factura> gast) {
    final ivaRep  = List.filled(12, 0.0);
    final ivaSop  = List.filled(12, 0.0);
    for (final f in ingr) { ivaRep[f.fechaEmision.month - 1] += f.totalIva; }
    for (final f in gast) { ivaSop[f.fechaEmision.month - 1] += f.totalIva; }
    final mesMax  = DateTime.now().year == widget.anio ? DateTime.now().month : 12;
    final repSpots = List.generate(mesMax, (i) => FlSpot(i.toDouble(), ivaRep[i]));
    final sopSpots = List.generate(mesMax, (i) => FlSpot(i.toDouble(), ivaSop[i]));
    if (ivaRep.every((v) => v == 0) && ivaSop.every((v) => v == 0)) {
      return _card('IVA repercutido vs soportado', 'Seguimiento fiscal', Icons.receipt_rounded, _azul, _sinDatos());
    }
    final maxY = [...repSpots, ...sopSpots].fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.3;
    return _card('IVA repercutido vs soportado', 'Seguimiento fiscal', Icons.receipt_rounded, _azul,
      Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _leyenda(_azul, 'IVA repercutido'), const SizedBox(width: 16), _leyenda(_rojo, 'IVA soportado'),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 170, child: LineChart(LineChartData(
          maxY: maxY == 0 ? 100 : maxY,
          gridData: _gridH, borderData: _noBorder,
          titlesData: FlTitlesData(
            leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle,
            bottomTitles: _bottomMeses(_meses.take(mesMax).toList()),
          ),
          lineBarsData: [
            _lineBar(repSpots, _azul, fill: false),
            _lineBar(sopSpots, _rojo, fill: false),
          ],
        ))),
      ]),
    );
  }

  // ── 10. Facturas emitidas — línea ──────────────────────────────────────────

  Widget _chart10FacturasEmitidas(List<Factura> ingr) {
    final counts = List.filled(12, 0.0);
    for (final f in ingr) { counts[f.fechaEmision.month - 1] += 1; }
    final mesMax  = DateTime.now().year == widget.anio ? DateTime.now().month : 12;
    final spots   = List.generate(mesMax, (i) => FlSpot(i.toDouble(), counts[i]));
    if (spots.every((s) => s.y == 0)) return _card('Facturas emitidas', 'Número por mes', Icons.receipt_long_rounded, _morado, _sinDatos());
    final maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m) * 1.3;
    return _card('Facturas emitidas', 'Número de facturas por mes', Icons.receipt_long_rounded, _morado,
      SizedBox(height: 210, child: LineChart(LineChartData(
        maxY: maxY == 0 ? 10 : maxY,
        gridData: _gridH, borderData: _noBorder,
        titlesData: FlTitlesData(
          leftTitles: _noTitle, rightTitles: _noTitle, topTitles: _noTitle,
          bottomTitles: _bottomMeses(_meses.take(mesMax).toList()),
        ),
        lineBarsData: [_lineBar(spots, _morado)],
      ))),
    );
  }
}
