import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'detalle_factura_screen.dart';
import 'formulario_factura_screen.dart';
import 'pantalla_contabilidad.dart';

const _kTabProveedores = 8;
const _kTabModelos     = 6;

enum _Filtro { todas, pendientes, pagadas, vencidas, tpv }

extension _FiltroLabel on _Filtro {
  String get label {
    switch (this) {
      case _Filtro.todas:      return 'Todas';
      case _Filtro.pendientes: return 'Pendientes';
      case _Filtro.pagadas:    return 'Pagadas';
      case _Filtro.vencidas:   return 'Vencidas';
      case _Filtro.tpv:        return 'TPV';
    }
  }
}

class TabFacturas extends StatefulWidget {
  final String empresaId;
  final void Function(int tabIndex)? onNavigateToTab;
  const TabFacturas({super.key, required this.empresaId, this.onNavigateToTab});

  @override
  State<TabFacturas> createState() => _TabFacturasState();
}

class _TabFacturasState extends State<TabFacturas> {
  final _service = FacturacionService();
  final int _anio = DateTime.now().year;

  _Filtro _filtro      = _Filtro.todas;
  String  _busqueda    = '';
  String  _filtroFlujo = 'todas';
  bool    _darkMode    = false;
  int     _paginaActual = 0;
  static const _porPagina = 10;

  @override
  void initState() {
    super.initState();
    _service.detectarYMarcarVencidas(widget.empresaId);
  }

  Color get _bg          => _darkMode ? const Color(0xFF05060A) : const Color(0xFFF4F6FB);
  Color get _panelBg     => _darkMode ? const Color(0x08FFFFFF) : Colors.white;
  Color get _panelBorder => _darkMode ? const Color(0x14FFFFFF) : const Color(0x14000000);
  Color get _textMain    => _darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _textSoft    => _darkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  List<Factura> _aplicarFiltros(List<Factura> lista) {
    switch (_filtro) {
      case _Filtro.pendientes:
        lista = lista.where((f) => f.estado == EstadoFactura.pendiente).toList();
      case _Filtro.pagadas:
        lista = lista.where((f) => f.estado == EstadoFactura.pagada).toList();
      case _Filtro.vencidas:
        lista = lista.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).toList();
      case _Filtro.tpv:
        lista = lista.where((f) => f.pedidoId != null || (f.ticketIds?.isNotEmpty == true)).toList();
      case _Filtro.todas:
        break;
    }
    if (_filtroFlujo != 'todas') lista = lista.where((f) => f.flujo == _filtroFlujo).toList();
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista.where((f) =>
          f.clienteNombre.toLowerCase().contains(q) ||
          f.numeroFactura.toLowerCase().contains(q)).toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Factura>>(
      stream: _service.obtenerFacturas(widget.empresaId),
      builder: (context, snap) {
        final todas   = snap.data ?? [];
        final lista   = _aplicarFiltros(List.from(todas));
        final loading = snap.connectionState == ConnectionState.waiting && todas.isEmpty;
        if (loading) return Center(child: CircularProgressIndicator(color: const Color(0xFF10B981)));
        final totalPags   = (lista.length / _porPagina).ceil().clamp(1, 9999);
        final pagSegura   = _paginaActual.clamp(0, totalPags - 1);
        final paginada    = lista.skip(pagSegura * _porPagina).take(_porPagina).toList();

        return Container(
          color: _bg,
          child: Stack(children: [
            _glow(const Color(0xFF10B981), top: -120, left: -80),
            _glow(const Color(0xFF3B82F6), top: 160, right: -100),
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth > 700;
              return CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildKpis(todas)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: wide
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Flexible(flex: 5, child: _buildTabla(lista, paginada, totalPags, pagSegura)),
                            const SizedBox(width: 14),
                            Flexible(flex: 3, child: _buildGraficosPanel(todas)),
                          ])
                        : Column(children: [
                            _buildTabla(lista, paginada, totalPags, pagSegura),
                            const SizedBox(height: 14),
                            _buildGraficosPanel(todas),
                          ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 28, 14, 40),
                  sliver: SliverToBoxAdapter(child: _buildBottomSection(todas)),
                ),
              ]);
            }),
          ]),
        );
      },
    );
  }

  Widget _glow(Color c, {double? top, double? left, double? right}) => Positioned(
    top: top, left: left, right: right,
    child: IgnorePointer(child: Container(width: 300, height: 300,
      decoration: BoxDecoration(shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.withValues(alpha: _darkMode ? 0.22 : 0.07), blurRadius: 100, spreadRadius: 40)]))),
  );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    color: _panelBg,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Row(children: [
      Text('Facturación', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textMain)),
      const Spacer(),
      OutlinedButton.icon(
        onPressed: _mostrarExportar,
        icon: const Icon(Icons.upload_rounded, size: 15),
        label: const Text('Exportar', style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _textMain,
          side: BorderSide(color: _panelBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      const SizedBox(width: 10),
      ElevatedButton.icon(
        onPressed: _mostrarNuevaFactura,
        icon: const Icon(Icons.add, size: 15, color: Colors.white),
        label: const Text('Nueva factura', style: TextStyle(fontSize: 13, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), elevation: 0,
        ),
      ),
    ]),
  );

  // ── KPI cards ──────────────────────────────────────────────────────────────

  Widget _buildKpis(List<Factura> todas) {
    final ingTotal   = todas.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final pendiente  = todas.where((f) => f.estado == EstadoFactura.pendiente).fold(0.0, (s, f) => s + f.total);
    final nPend      = todas.where((f) => f.estado == EstadoFactura.pendiente).length;
    final nPag       = todas.where((f) => f.estado == EstadoFactura.pagada).length;
    final nVen       = todas.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).length;
    final pctPag     = todas.isEmpty ? 0 : (nPag / todas.length * 100).round();
    return Container(
      color: _panelBg.withValues(alpha: _darkMode ? 0.3 : 1.0),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(children: [
        _kpiStat('Total facturado', '${ingTotal.toStringAsFixed(0)} €', '$_anio', const Color(0xFF10B981), Icons.monetization_on_rounded),
        const SizedBox(width: 7),
        _kpiStat('Pendiente', '${pendiente.toStringAsFixed(0)} €', '$nPend facturas', const Color(0xFFEAB308), Icons.schedule_rounded),
        const SizedBox(width: 7),
        _kpiStat('Pagadas', '$nPag', '$pctPag% del total', const Color(0xFF3B82F6), Icons.task_alt_rounded),
        const SizedBox(width: 7),
        _kpiStat('Vencidas', '$nVen', nVen == 0 ? 'Sin vencimientos' : 'Requieren atención', const Color(0xFF8B5CF6), Icons.warning_amber_rounded),
        const SizedBox(width: 7),
        _kpiBtn('Modelos',     Icons.account_balance_rounded, const Color(0xFF8B5CF6), () => widget.onNavigateToTab?.call(_kTabModelos)),
        const SizedBox(width: 7),
        _kpiBtn('Proveedores', Icons.business_rounded,        const Color(0xFFF97316), _mostrarProveedores),
      ]),
    );
  }

  Widget _kpiStat(String label, String valor, String sub, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _panelBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 10.5, color: _textSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10, color: _textSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _kpiBtn(String label, IconData icon, Color color, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _panelBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMain), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Text('Ver ${label.toLowerCase()}', style: TextStyle(fontSize: 10, color: color)),
            Icon(Icons.chevron_right, color: color, size: 11),
          ]),
        ]),
      ),
    ),
  );

  // ── Tabla con paginación ───────────────────────────────────────────────────

  Widget _buildTabla(List<Factura> lista, List<Factura> paginada, int totalPags, int paginaActual) =>
      Container(
        decoration: BoxDecoration(
          color: _panelBg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _panelBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _darkMode ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Búsqueda + limpiar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(children: [
              Expanded(child: TextField(
                onChanged: (v) => setState(() { _busqueda = v; _paginaActual = 0; }),
                style: TextStyle(color: _textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o número de factura...',
                  hintStyle: TextStyle(fontSize: 12.5, color: _textSoft),
                  prefixIcon: Icon(Icons.search, color: _textSoft, size: 17),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(icon: Icon(Icons.clear, size: 15, color: _textSoft), onPressed: () => setState(() { _busqueda = ''; _paginaActual = 0; }))
                      : null,
                  filled: true,
                  fillColor: _darkMode ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _panelBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _panelBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                ),
              )),
              if (_busqueda.isNotEmpty || _filtro != _Filtro.todas || _filtroFlujo != 'todas') ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() { _busqueda = ''; _filtro = _Filtro.todas; _filtroFlujo = 'todas'; _paginaActual = 0; }),
                  icon: const Icon(Icons.refresh, size: 13),
                  label: const Text('Limpiar filtros', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
                ),
              ],
            ]),
          ),
          // Filtros + botón nueva
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              Expanded(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ..._Filtro.values.map((f) => _chip(f.label, _filtro == f,
                      () => setState(() { _filtro = f; _paginaActual = 0; }), const Color(0xFF10B981))),
                  Container(width: 1, height: 16, color: _panelBorder, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  _chip('Ingresos', _filtroFlujo == 'ingreso',
                      () => setState(() { _filtroFlujo = _filtroFlujo == 'ingreso' ? 'todas' : 'ingreso'; _paginaActual = 0; }),
                      const Color(0xFF10B981)),
                  _chip('Gastos', _filtroFlujo == 'gasto',
                      () => setState(() { _filtroFlujo = _filtroFlujo == 'gasto' ? 'todas' : 'gasto'; _paginaActual = 0; }),
                      const Color(0xFFEF4444)),
                ]),
              )),
            ]),
          ),
          // Cabecera
          Container(
            decoration: BoxDecoration(
              color: _darkMode ? const Color(0x06FFFFFF) : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: _panelBorder), bottom: BorderSide(color: _panelBorder)),
            ),
            child: _tableHeader(),
          ),
          // Filas
          paginada.isEmpty
              ? _buildVacia()
              : ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginada.length,
                  itemBuilder: (_, i) => _tableRow(paginada[i]),
                ),
          // Paginación
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Text(
                lista.isEmpty ? 'Sin resultados'
                    : 'Mostrando ${paginaActual * _porPagina + 1} a ${(paginaActual * _porPagina + paginada.length).clamp(0, lista.length)} de ${lista.length} facturas',
                style: TextStyle(fontSize: 11, color: _textSoft),
              ),
              const Spacer(),
              _paginBtn(Icons.chevron_left, paginaActual > 0, () => setState(() => _paginaActual = paginaActual - 1)),
              const SizedBox(width: 4),
              ...List.generate(totalPags.clamp(0, 5), (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => setState(() => _paginaActual = i),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: i == paginaActual ? const Color(0xFF0D47A1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: i == paginaActual ? const Color(0xFF0D47A1) : _panelBorder),
                    ),
                    child: Center(child: Text('${i + 1}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: i == paginaActual ? Colors.white : _textSoft))),
                  ),
                ),
              )),
              const SizedBox(width: 4),
              _paginBtn(Icons.chevron_right, paginaActual < totalPags - 1, () => setState(() => _paginaActual = paginaActual + 1)),
            ]),
          ),
        ]),
      );

  Widget _paginBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _panelBorder),
        color: enabled ? Colors.transparent : _panelBorder.withValues(alpha: 0.3),
      ),
      child: Icon(icon, size: 14, color: enabled ? _textSoft : _panelBorder),
    ),
  );

  Widget _tableHeader() {
    final s = TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _textSoft, letterSpacing: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        SizedBox(width: 80,  child: Text('Nº FACTURA', style: s)),
        Expanded(             child: Text('CLIENTE',    style: s)),
        SizedBox(width: 70,  child: Text('FECHA',      style: s)),
        SizedBox(width: 46,  child: Text('TIPO',       style: s)),
        SizedBox(width: 64,  child: Text('IMPORTE',    style: s, textAlign: TextAlign.right)),
        SizedBox(width: 68,  child: Text('ESTADO',     style: s, textAlign: TextAlign.center)),
        const SizedBox(width: 26),
      ]),
    );
  }

  Widget _tableRow(Factura f) {
    final colorEstado = _colorEstado(f.estado);
    final esTpv   = f.pedidoId != null || (f.ticketIds?.isNotEmpty == true);
    final dt      = f.fechaEmision;
    final fecha   = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    final esGasto = f.flujo == 'gasto';
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleFacturaScreen(factura: f, empresaId: widget.empresaId))),
      hoverColor: _panelBorder.withValues(alpha: 0.5),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _panelBorder.withValues(alpha: 0.5)))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          SizedBox(width: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.numeroFactura, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: _textSoft, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            if (esTpv) Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.deepOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
              child: const Text('TPV', style: TextStyle(color: Colors.deepOrange, fontSize: 8.5, fontWeight: FontWeight.w700)),
            ),
          ])),
          Expanded(child: Text(f.clienteNombre.isEmpty ? 'General' : f.clienteNombre,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _textMain), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 70, child: Text(fecha, style: TextStyle(color: _textSoft, fontSize: 11))),
          SizedBox(width: 46, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: esGasto ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(esGasto ? 'Gasto' : 'Ingreso',
                style: TextStyle(color: esGasto ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          )),
          SizedBox(width: 64, child: Text('${f.total.toStringAsFixed(2)}€',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _textMain), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 68, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorEstado.withValues(alpha: 0.3))),
            child: Text(f.estado.etiqueta, style: TextStyle(color: colorEstado, fontSize: 9, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ))),
          SizedBox(width: 26, child: IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, size: 14, color: _textSoft),
            onPressed: () => PdfService.verFacturaPdf(context, f, widget.empresaId),
            visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
          )),
        ]),
      ),
    );
  }

  // ── Panel derecho — gráficos ───────────────────────────────────────────────

  Widget _buildGraficosPanel(List<Factura> todas) {
    final ingTotal = todas.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final gasTotal = todas.where((f) => f.flujo == 'gasto').fold(0.0, (s, f) => s + f.total);
    final benNeto  = ingTotal - gasTotal;
    return Column(children: [
      // ── Resumen anual ───────────────────────────────────────────────────
      _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 15, color: _textSoft),
          const SizedBox(width: 6),
          Text('Resumen anual', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: _panelBorder), borderRadius: BorderRadius.circular(6)),
            child: Text('$_anio', style: TextStyle(fontSize: 11, color: _textSoft)),
          ),
        ]),
        const SizedBox(height: 14),
        _resumenFila(Icons.trending_up_rounded,   'Total ingresos', ingTotal, const Color(0xFF10B981)),
        const SizedBox(height: 5),
        _resumenFila(Icons.trending_down_rounded, 'Total gastos',   gasTotal, const Color(0xFFEF4444)),
        const SizedBox(height: 5),
        _resumenFila(Icons.bolt_rounded, 'Beneficio neto', benNeto, benNeto >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), bold: true),
        const SizedBox(height: 14),
        SizedBox(height: 130, child: LineChart(LineChartData(
          lineBarsData: [LineChartBarData(
            spots: _spotsIngresos(todas), isCurved: true,
            color: const Color(0xFF10B981), barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF10B981).withValues(alpha: 0.1)),
          )],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
        ))),
      ])),
      const SizedBox(height: 14),
      // ── Ingresos vs. Gastos ─────────────────────────────────────────────
      _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.donut_large_rounded, size: 15, color: _textSoft),
          const SizedBox(width: 6),
          Text('Ingresos vs. Gastos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
          const Spacer(),
          Text('Este año', style: TextStyle(fontSize: 11, color: _textSoft)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(width: 110, height: 110, child: PieChart(PieChartData(
            sections: _seccionesDonut(ingTotal, gasTotal),
            centerSpaceRadius: 28, sectionsSpace: 2,
          ))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _leyendaItem(const Color(0xFF10B981), 'Ingresos', '${ingTotal.toStringAsFixed(0)} €'),
            const SizedBox(height: 12),
            _leyendaItem(const Color(0xFFEF4444), 'Gastos',   '${gasTotal.toStringAsFixed(0)} €'),
          ])),
        ]),
      ])),
    ]);
  }

  Widget _resumenFila(IconData icon, String label, double valor, Color color, {bool bold = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, color: _textSoft)),
        ]),
        Text('${valor.toStringAsFixed(0)} €',
            style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
      ]);

  Widget _leyendaItem(Color color, String label, String valor) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: _textSoft)),
      Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
    ]),
  ]);

  List<PieChartSectionData> _seccionesDonut(double ing, double gas) {
    if (ing == 0 && gas == 0) return [PieChartSectionData(value: 1, color: _panelBorder, radius: 32, title: '')];
    final t = ing + gas;
    return [
      if (ing > 0) PieChartSectionData(value: ing, color: const Color(0xFF10B981), radius: 32,
          title: gas == 0 ? '100%' : '${(ing / t * 100).round()}%',
          titleStyle: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      if (gas > 0) PieChartSectionData(value: gas, color: const Color(0xFFEF4444), radius: 32,
          title: '${(gas / t * 100).round()}%',
          titleStyle: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
    ];
  }

  // ── Sección inferior — 3 cards ──────────────────────────────────────────────

  Widget _buildBottomSection(List<Factura> todas) => LayoutBuilder(builder: (_, c) {
    final wide = c.maxWidth > 700;
    final cards = [
      _buildFacturaPorEstado(todas),
      _buildEvolucion(todas),
      _buildTopClientes(todas),
    ];
    if (wide) return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: cards[0]), const SizedBox(width: 14),
      Expanded(child: cards[1]), const SizedBox(width: 14),
      Expanded(child: cards[2]),
    ]));
    return Column(children: [cards[0], const SizedBox(height: 14), cards[1], const SizedBox(height: 14), cards[2]]);
  });

  Widget _buildFacturaPorEstado(List<Factura> todas) {
    final pag  = todas.where((f) => f.estado == EstadoFactura.pagada).length;
    final pend = todas.where((f) => f.estado == EstadoFactura.pendiente).length;
    final ven  = todas.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).length;
    final tot  = pag + pend + ven;
    return _panelCard(titulo: 'Facturas por estado', child: Row(children: [
      SizedBox(width: 120, height: 120, child: PieChart(PieChartData(
        sections: [
          if (pag > 0) PieChartSectionData(value: pag.toDouble(),  color: const Color(0xFF22C55E), radius: 36, title: ''),
          if (pend > 0) PieChartSectionData(value: pend.toDouble(), color: const Color(0xFFEAB308), radius: 36, title: ''),
          if (ven > 0) PieChartSectionData(value: ven.toDouble(),  color: const Color(0xFFEF4444), radius: 36, title: ''),
          if (tot == 0) PieChartSectionData(value: 1, color: _panelBorder, radius: 36, title: ''),
        ],
        centerSpaceRadius: 28, sectionsSpace: 2,
      ))),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _estadoItem(const Color(0xFF22C55E), 'Pagadas',    pag,  tot),
        const SizedBox(height: 8),
        _estadoItem(const Color(0xFFEAB308), 'Pendientes', pend, tot),
        const SizedBox(height: 8),
        _estadoItem(const Color(0xFFEF4444), 'Vencidas',   ven,  tot),
      ]),
    ]));
  }

  Widget _estadoItem(Color c, String label, int n, int tot) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: _textSoft)),
    const SizedBox(width: 6),
    Text('$n (${tot > 0 ? (n / tot * 100).round() : 0}%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
  ]);

  Widget _buildEvolucion(List<Factura> todas) {
    final m    = _mensualIngresos(todas);
    final maxV = m.values.fold(0.0, (a, b) => a > b ? a : b);
    return _panelCard(titulo: 'Evolución de ingresos', child: SizedBox(
      height: 150,
      child: BarChart(BarChartData(
        barGroups: List.generate(12, (i) => BarChartGroupData(
          x: i, barRods: [BarChartRodData(toY: m[i + 1] ?? 0, color: const Color(0xFF10B981), width: 12, borderRadius: BorderRadius.circular(4))],
        )),
        maxY: maxV > 0 ? maxV * 1.2 : 100,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 18,
            getTitlesWidget: (v, _) {
              const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
              final i = v.toInt();
              if (i < 0 || i >= 12) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text(months[i], style: TextStyle(fontSize: 8, color: _textSoft)));
            },
          )),
        ),
      )),
    ));
  }

  Widget _buildTopClientes(List<Factura> todas) {
    final map = <String, double>{};
    for (final f in todas) {
      if (f.flujo != 'gasto') {
        final c = f.clienteNombre.isEmpty ? 'Caja directa' : f.clienteNombre;
        map[c] = (map[c] ?? 0) + f.total;
      }
    }
    final top    = (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(4).toList();
    final totSum = map.values.fold(0.0, (a, b) => a + b);
    return _panelCard(titulo: 'Top clientes', child: Column(children: [
      if (top.isEmpty) Text('Sin datos', style: TextStyle(fontSize: 12, color: _textSoft))
      else ...top.asMap().entries.map((e) {
        final pct = totSum > 0 ? e.value.value / totSum : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 20, height: 20,
                decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.value.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textMain), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                value: pct, minHeight: 4,
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              )),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${e.value.value.toStringAsFixed(0)} €', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
              Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
            ]),
          ]),
        );
      }),
    ]));
  }

  Widget _panelCard({String? titulo, required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panelBg, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _panelBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _darkMode ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (titulo != null) ...[
        Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
        const SizedBox(height: 16),
      ],
      child,
    ]),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildVacia() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Icon(Icons.receipt_long_outlined, size: 44, color: _textSoft.withValues(alpha: 0.4)),
      const SizedBox(height: 10),
      Text('Sin facturas', style: TextStyle(fontSize: 13, color: _textSoft)),
    ]),
  );

  Widget _chip(String label, bool sel, VoidCallback onTap, Color color) => Padding(
    padding: const EdgeInsets.only(right: 5),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? color : (_darkMode ? const Color(0x10FFFFFF) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? color : _panelBorder),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : _textSoft,
            fontWeight: sel ? FontWeight.w700 : FontWeight.normal, fontSize: 11)),
      ),
    ),
  );

  Color _colorEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pendiente:   return const Color(0xFFEAB308);
      case EstadoFactura.pagada:      return const Color(0xFF22C55E);
      case EstadoFactura.anulada:     return Colors.grey;
      case EstadoFactura.vencida:     return const Color(0xFFEF4444);
      case EstadoFactura.rectificada: return Colors.orange;
    }
  }

  Map<int, double> _mensualIngresos(List<Factura> todas) {
    final m = <int, double>{};
    for (final f in todas) {
      if (f.flujo != 'gasto' && f.fechaEmision.year == _anio) {
        m[f.fechaEmision.month] = (m[f.fechaEmision.month] ?? 0) + f.total;
      }
    }
    return m;
  }

  List<FlSpot> _spotsIngresos(List<Factura> todas) {
    final m = _mensualIngresos(todas);
    return List.generate(12, (i) => FlSpot(i.toDouble(), m[i + 1] ?? 0));
  }

  // ── Popups ─────────────────────────────────────────────────────────────────

  void _mostrarNuevaFactura() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FormularioFacturaScreen(empresaId: widget.empresaId),
      ),
    );
  }

  void _mostrarExportar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.upload_rounded, size: 20, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              const Text('Exportar datos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ContabTabExportar(
            empresaId: widget.empresaId,
            anio: _anio,
            svc: ContabilidadService(),
            color: const Color(0xFF0D47A1),
          )),
        ]),
      ),
    );
  }

  void _mostrarProveedores() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.business_rounded, size: 20, color: Color(0xFFF97316)),
              const SizedBox(width: 8),
              const Text('Proveedores', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ContabTabProveedores(
            empresaId: widget.empresaId,
            svc: ContabilidadService(),
            color: const Color(0xFFF97316),
          )),
        ]),
      ),
    );
  }
}
