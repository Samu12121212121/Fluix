import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/costes_nominas_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET RESUMEN DE COSTES — KPIs + Gráficos + Tabla desglose
// ═══════════════════════════════════════════════════════════════════════════════

class ResumenCostesWidget extends StatefulWidget {
  final String empresaId;
  final int anio;
  final int mes;

  const ResumenCostesWidget({
    super.key,
    required this.empresaId,
    required this.anio,
    required this.mes,
  });

  @override
  State<ResumenCostesWidget> createState() => _ResumenCostesWidgetState();
}

class _ResumenCostesWidgetState extends State<ResumenCostesWidget> {
  final _svc = CostesNominasService();
  ResumenCostesMes? _resumen;
  double _variacion = 0;
  List<CostesMensual> _evolucion = [];
  bool _cargando = true;
  int _sortColumn = 6; // costeTotalEmpresa
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant ResumenCostesWidget old) {
    super.didUpdateWidget(old);
    if (old.mes != widget.mes || old.anio != widget.anio) _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final resumen = await _svc.obtenerResumenMes(widget.empresaId, widget.anio, widget.mes);
      final variacion = await _svc.variacionMesAnterior(widget.empresaId, widget.anio, widget.mes);
      final evolucion = await _svc.evolucion12Meses(widget.empresaId, widget.anio, widget.mes);
      setState(() {
        _resumen = resumen;
        _variacion = variacion;
        _evolucion = evolucion;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_resumen == null) return const Center(child: Text('Sin datos'));

    final r = _resumen!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs ────────────────────────────────────────────────────
          _buildKpis(r),
          const SizedBox(height: 20),

          // ── Donut Chart ─────────────────────────────────────────────
          _tituloSeccion('Distribución del coste'),
          const SizedBox(height: 8),
          SizedBox(height: 200, child: _buildDonut(r)),
          const SizedBox(height: 20),

          // ── Barras mensuales ─────────────────────────────────────────
          _tituloSeccion('Evolución últimos 12 meses'),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _buildBarras()),
          const SizedBox(height: 20),

          // ── Tabla desglose ──────────────────────────────────────────
          _tituloSeccion('Desglose por empleado'),
          const SizedBox(height: 8),
          _buildTabla(r),
          const SizedBox(height: 16),

          // ── Botón exportar CSV ──────────────────────────────────────
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Exportar CSV'),
              onPressed: () => _svc.exportarResumenCsv(
                context, widget.empresaId, widget.anio, widget.mes),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPIs ──────────────────────────────────────────────────────────────────

  Widget _buildKpis(ResumenCostesMes r) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpiCard('Total netos', r.totalNetos, Icons.account_balance_wallet, const Color(0xFF2E7D32)),
        _kpiCard('IRPF retenido', r.totalIRPF, Icons.receipt_long, const Color(0xFFE65100)),
        _kpiCard('SS Trabajador', r.totalSSTrabajador, Icons.security, const Color(0xFF1565C0)),
        _kpiCard('SS Empresa', r.totalSSEmpresa, Icons.business, const Color(0xFF7B1FA2)),
        _kpiCard('Coste total', r.costeTotalEmpresa, Icons.euro, const Color(0xFF0D47A1), grande: true),
        _kpiVariacion(),
      ],
    );
  }

  Widget _kpiCard(String label, double valor, IconData icon, Color color, {bool grande = false}) {
    return Container(
      width: grande ? 180 : 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 6)],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text('${valor.toStringAsFixed(2)} €',
            style: TextStyle(fontSize: grande ? 17 : 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _kpiVariacion() {
    final positiva = _variacion > 0;
    final color = positiva ? Colors.red : Colors.green;
    final icon = positiva ? Icons.trending_up : Icons.trending_down;
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text('vs. mes anterior', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text('${_variacion >= 0 ? '+' : ''}${_variacion.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ── Donut ─────────────────────────────────────────────────────────────────

  Widget _buildDonut(ResumenCostesMes r) {
    if (r.costeTotalEmpresa == 0) return const Center(child: Text('Sin datos'));

    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(
                value: r.totalNetos,
                color: const Color(0xFF4CAF50),
                title: '${(r.totalNetos / r.costeTotalEmpresa * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                radius: 50,
              ),
              PieChartSectionData(
                value: r.totalSSEmpresa,
                color: const Color(0xFF7B1FA2),
                title: '${(r.totalSSEmpresa / r.costeTotalEmpresa * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                radius: 50,
              ),
              PieChartSectionData(
                value: r.totalIRPF + r.totalSSTrabajador,
                color: const Color(0xFFE65100),
                title: '${((r.totalIRPF + r.totalSSTrabajador) / r.costeTotalEmpresa * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                radius: 50,
              ),
            ],
          )),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _leyenda(const Color(0xFF4CAF50), 'Neto empleados'),
            _leyenda(const Color(0xFF7B1FA2), 'SS Empresa'),
            _leyenda(const Color(0xFFE65100), 'IRPF + SS Trab.'),
          ],
        ),
      ],
    );
  }

  Widget _leyenda(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ── Barras ────────────────────────────────────────────────────────────────

  Widget _buildBarras() {
    if (_evolucion.isEmpty) return const Center(child: Text('Sin datos'));

    final maxVal = _evolucion.fold(0.0, (m, e) => e.costeTotalEmpresa > m ? e.costeTotalEmpresa : m);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      barGroups: _evolucion.asMap().entries.map((e) => BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.costeTotalEmpresa,
            width: 16,
            color: e.key == _evolucion.length - 1
                ? const Color(0xFF0D47A1)
                : const Color(0xFF90CAF9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      )).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= _evolucion.length) return const SizedBox();
              return Text(_evolucion[idx].etiqueta,
                style: const TextStyle(fontSize: 8), textAlign: TextAlign.center);
            },
          ),
        ),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ));
  }

  // ── Tabla ─────────────────────────────────────────────────────────────────

  Widget _buildTabla(ResumenCostesMes r) {
    final desglose = List<DesgloseCostesEmpleado>.from(r.desglose);
    _ordenarDesglose(desglose);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        sortColumnIndex: _sortColumn,
        sortAscending: _sortAsc,
        columns: [
          DataColumn(label: const Text('Empleado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            onSort: (i, a) => setState(() { _sortColumn = i; _sortAsc = a; })),
          ..._numColumns(['Bruto', 'SS Trab.', 'IRPF', 'Neto', 'SS Emp.', 'Coste Total']),
        ],
        rows: [
          ...desglose.map((d) => DataRow(cells: [
            DataCell(Text(d.nombre, style: const TextStyle(fontSize: 11))),
            _numCell(d.salarioBruto),
            _numCell(d.ssTrabajador),
            _numCell(d.irpfRetenido),
            _numCell(d.neto),
            _numCell(d.ssEmpresa),
            _numCell(d.costeTotalEmpresa, bold: true),
          ])),
          // Fila de totales
          DataRow(
            color: WidgetStateProperty.all(const Color(0xFFE3F2FD)),
            cells: [
              const DataCell(Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              _numCell(r.totalBruto, bold: true),
              _numCell(r.totalSSTrabajador, bold: true),
              _numCell(r.totalIRPF, bold: true),
              _numCell(r.totalNetos, bold: true),
              _numCell(r.totalSSEmpresa, bold: true),
              _numCell(r.costeTotalEmpresa, bold: true),
            ],
          ),
        ],
      ),
    );
  }

  List<DataColumn> _numColumns(List<String> names) {
    return names.asMap().entries.map((e) => DataColumn(
      numeric: true,
      label: Text(e.value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      onSort: (i, a) => setState(() { _sortColumn = i; _sortAsc = a; }),
    )).toList();
  }

  DataCell _numCell(double v, {bool bold = false}) {
    return DataCell(Text(
      v.toStringAsFixed(2),
      style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
    ));
  }

  void _ordenarDesglose(List<DesgloseCostesEmpleado> list) {
    list.sort((a, b) {
      double va, vb;
      switch (_sortColumn) {
        case 0: return _sortAsc ? a.nombre.compareTo(b.nombre) : b.nombre.compareTo(a.nombre);
        case 1: va = a.salarioBruto; vb = b.salarioBruto; break;
        case 2: va = a.ssTrabajador; vb = b.ssTrabajador; break;
        case 3: va = a.irpfRetenido; vb = b.irpfRetenido; break;
        case 4: va = a.neto; vb = b.neto; break;
        case 5: va = a.ssEmpresa; vb = b.ssEmpresa; break;
        default: va = a.costeTotalEmpresa; vb = b.costeTotalEmpresa;
      }
      return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
    });
  }

  Widget _tituloSeccion(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }
}


