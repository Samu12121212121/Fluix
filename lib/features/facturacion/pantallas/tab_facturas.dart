import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'package:planeag_flutter/core/utils/app_settings.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'detalle_factura_screen.dart';
import 'formulario_factura_screen.dart';
import 'pantalla_contabilidad.dart';
import 'tab_albaranes_recibidos.dart';
import 'tab_facturas_recurrentes.dart';

const _kTabProveedores = 7;
const _kTabModelos     = 5;

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
  final bool showTitle; // false cuando el AppBar exterior ya muestra el título
  const TabFacturas({super.key, required this.empresaId, this.onNavigateToTab, this.showTitle = true});

  @override
  State<TabFacturas> createState() => _TabFacturasState();
}

enum _VistaDocumentos { facturas, presupuestos, albaranes, albaranesRecibidos, recurrentes }

class _TabFacturasState extends State<TabFacturas> {
  final _service    = FacturacionService();
  final _contabSvc  = ContabilidadService();
  int _anio = DateTime.now().year;

  _Filtro _filtro            = _Filtro.todas;
  _VistaDocumentos _vistaDoc = _VistaDocumentos.facturas;
  String  _busqueda    = '';
  String  _filtroFlujo = 'todas';
  bool    _darkMode    = false;
  int     _paginaActual = 0;
  static const _porPagina = 10;

  // Índices de carruseles inferiores
  int _idxBotIzq = 0;
  int _idxBotDer = 0;

  // Filtro período flujo de caja
  String _periodoCaja = 'año'; // 'año' | 'mes' | 'semana'

  @override
  void initState() {
    super.initState();
    _darkMode = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDarkChange);
    _service.detectarYMarcarVencidas(widget.empresaId);
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDarkChange);
    super.dispose();
  }

  void _onDarkChange() {
    if (mounted) setState(() => _darkMode = AppSettings.darkMode.value);
  }

  Color get _bg          => _darkMode ? const Color(0xFF0F172A) : const Color(0xFFF4F6FB);
  Color get _panelBg     => _darkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _panelBorder => _darkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
  Color get _textMain    => _darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _textSoft    => _darkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  List<Factura> _aplicarFiltros(List<Factura> lista) {
    // Primero filtrar por tipo de documento (vista activa)
    switch (_vistaDoc) {
      case _VistaDocumentos.facturas:
        lista = lista.where((f) => f.esDocumentoFiscal).toList();
      case _VistaDocumentos.presupuestos:
        lista = lista.where((f) => f.esProforma).toList();
      case _VistaDocumentos.albaranes:
        lista = lista.where((f) => f.esAlbaran).toList();
      case _VistaDocumentos.albaranesRecibidos:
        lista = [];
      case _VistaDocumentos.recurrentes:
        lista = [];
    }
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

        // Facturas con error en VeriFactu
        final vfErrores = todas.where((f) {
          final estado = f.verifactu?['estado'] as String?;
          return estado == 'error' || estado == 'rechazada';
        }).length;

        return Container(
          color: _bg,
          child: Stack(children: [
            _glow(const Color(0xFF10B981), top: -120, left: -80),
            _glow(const Color(0xFF3B82F6), top: 160, right: -100),
            LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth > 700;
              final todasAnio = todas.where((f) => f.fechaEmision.year == _anio).toList();
              return CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildHeader(lista)),
                if (_vistaDoc == _VistaDocumentos.albaranesRecibidos)
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: TabAlbaranesRecibidos(
                      empresaId: widget.empresaId,
                      svc: _contabSvc,
                    ),
                  )
                else if (_vistaDoc == _VistaDocumentos.recurrentes)
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: TabFacturasRecurrentes(empresaId: widget.empresaId),
                  )
                else ...[
                  // Banner VeriFactu si hay errores
                  if (vfErrores > 0)
                    SliverToBoxAdapter(child: _buildBannerVeriFactu(vfErrores)),
                  SliverToBoxAdapter(child: _buildKpis(todasAnio)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                ],
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

  // ── Banner VeriFactu ───────────────────────────────────────────────────────

  Widget _buildBannerVeriFactu(int n) => Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
      const SizedBox(width: 10),
      Expanded(child: Text(
        '$n factura${n > 1 ? 's' : ''} con error en VeriFactu. '
        'Accede al detalle de cada factura para reintentar el envío a la AEAT.',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
      )),
    ]),
  );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(List<Factura> listaFiltrada) => Container(
    color: _panelBg,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
      if (widget.showTitle)
        Text('Facturación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textMain)),
      const Spacer(),
      OutlinedButton.icon(
        onPressed: () => _exportarCsv(listaFiltrada),
        icon: const Icon(Icons.table_rows_rounded, size: 15),
        label: const Text('CSV', style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _textMain,
          side: BorderSide(color: _panelBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      const SizedBox(width: 8),
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
      const SizedBox(width: 8),
      PopupMenuButton<TipoFactura>(
        onSelected: (tipo) => _mostrarNuevaFactura(tipoInicial: tipo),
        tooltip: 'Nuevo documento',
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: TipoFactura.venta_directa,
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF0D47A1)),
              const SizedBox(width: 10),
              const Text('Factura'),
            ]),
          ),
          PopupMenuItem(
            value: TipoFactura.proforma,
            child: Row(children: [
              const Icon(Icons.description_outlined, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              const Text('Presupuesto'),
            ]),
          ),
          PopupMenuItem(
            value: TipoFactura.albaran,
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              const Text('Albarán'),
            ]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 15, color: Colors.white),
            SizedBox(width: 6),
            Text('Nuevo', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
          ]),
        ),
      ),
    ]),
    // ── Toggle Facturas / Presupuestos / Albaranes ──────────────────────
    const SizedBox(height: 10),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _vistaChip(_VistaDocumentos.facturas,     'Facturas',      Icons.receipt_long_rounded,     const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        _vistaChip(_VistaDocumentos.presupuestos, 'Presupuestos',  Icons.description_outlined,     const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        _vistaChip(_VistaDocumentos.albaranes,    'Albaranes',     Icons.local_shipping_outlined,  const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _vistaChip(_VistaDocumentos.albaranesRecibidos, 'Alb. recibidos', Icons.move_to_inbox_rounded, const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        _vistaChip(_VistaDocumentos.recurrentes, 'Recurrentes', Icons.repeat_rounded, const Color(0xFF6366F1)),
      ]),
    ),
    const SizedBox(height: 10),
  ]));

  Widget _vistaChip(_VistaDocumentos v, String label, IconData icon, Color color) {
    final sel = _vistaDoc == v;
    return GestureDetector(
      onTap: () => setState(() { _vistaDoc = v; _paginaActual = 0; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _panelBorder, width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? color : _textSoft),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? color : _textSoft)),
        ]),
      ),
    );
  }

  // ── KPI cards ──────────────────────────────────────────────────────────────

  Widget _buildKpis(List<Factura> todas) {
    // KPIs solo sobre facturas reales (excluir presupuestos y albaranes)
    final soloFacturas = todas.where((f) => f.esDocumentoFiscal).toList();
    final ingTotal   = soloFacturas.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final pendiente  = soloFacturas.where((f) => f.estado == EstadoFactura.pendiente).fold(0.0, (s, f) => s + f.total);
    final nPend      = soloFacturas.where((f) => f.estado == EstadoFactura.pendiente).length;
    final nPag       = soloFacturas.where((f) => f.estado == EstadoFactura.pagada).length;
    final nVen       = soloFacturas.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).length;
    final pctPag     = soloFacturas.isEmpty ? 0 : (nPag / soloFacturas.length * 100).round();
    final bg = _bg;
    return LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 600;
      final row1 = [
        _kpiStat('Total facturado', '${ingTotal.toStringAsFixed(0)} €', '$_anio', const Color(0xFF10B981), Icons.monetization_on_rounded),
        const SizedBox(width: 7),
        _kpiStat('Pendiente', '${pendiente.toStringAsFixed(0)} €', '$nPend fact.', const Color(0xFFEAB308), Icons.schedule_rounded),
        const SizedBox(width: 7),
        _kpiStat('Pagadas', '$nPag', '$pctPag%', const Color(0xFF3B82F6), Icons.task_alt_rounded),
      ];
      final row2 = [
        _kpiStat('Vencidas', '$nVen', nVen == 0 ? 'Al día' : 'Atención', const Color(0xFF8B5CF6), Icons.warning_amber_rounded),
        const SizedBox(width: 7),
        _kpiBtn('Modelos', Icons.account_balance_rounded, const Color(0xFF8B5CF6), () => widget.onNavigateToTab?.call(_kTabModelos)),
        const SizedBox(width: 7),
        _kpiBtn('Proveedores', Icons.business_rounded, const Color(0xFFF97316), _mostrarProveedores),
      ];
      if (narrow) {
        return Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Column(children: [
            Row(children: row1),
            const SizedBox(height: 7),
            Row(children: row2),
          ]),
        );
      }
      return Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Row(children: [...row1, const SizedBox(width: 7), ...row2]),
      );
    });
  }

  Widget _kpiStat(String label, String valor, String sub, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _panelBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(width: 30, height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 10, color: _textSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 1),
        Flexible(child: Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textMain), overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 1),
        Text(sub, style: TextStyle(fontSize: 9.5, color: _textSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _kpiBtn(String label, IconData icon, Color color, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _panelBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Container(width: 30, height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Row(children: [
            Flexible(child: Text('Ver ${label.toLowerCase()}', style: TextStyle(fontSize: 9.5, color: color), overflow: TextOverflow.ellipsis)),
            Icon(Icons.chevron_right, color: color, size: 10),
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
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
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
                  fillColor: _darkMode ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
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
              color: _darkMode ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
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
    return LayoutBuilder(builder: (_, cons) {
      final narrow = cons.maxWidth < 460;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          SizedBox(width: narrow ? 68 : 80, child: Text('Nº FACTURA', style: s, overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('CLIENTE', style: s, overflow: TextOverflow.ellipsis)),
          if (!narrow) SizedBox(width: 70, child: Text('FECHA',   style: s)),
          SizedBox(width: narrow ? 52 : 64, child: Text('IMPORTE', style: s, textAlign: TextAlign.right)),
          SizedBox(width: narrow ? 56 : 68, child: Text('ESTADO',  style: s, textAlign: TextAlign.center)),
          const SizedBox(width: 26),
        ]),
      );
    });
  }

  Widget _tableRow(Factura f) {
    final colorEstado = _colorEstado(f.estado);
    final esTpv   = f.pedidoId != null || (f.ticketIds?.isNotEmpty == true);
    final dt      = f.fechaEmision;
    final fecha   = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    final esGasto = f.flujo == 'gasto';
    return InkWell(
      onTap: () {
        final wide = MediaQuery.of(context).size.width >= 640;
        if (wide) {
          // Desktop/tablet: popup modal sin navegar a nueva pantalla
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.55),
            builder: (_) => ValueListenableBuilder<bool>(
              valueListenable: AppSettings.darkMode,
              builder: (_, dark, __) => Theme(
                data: dark
                    ? ThemeData.dark().copyWith(
                        cardColor: const Color(0xFF1E293B),
                        scaffoldBackgroundColor: const Color(0xFF0F172A),
                        colorScheme: const ColorScheme.dark(surface: Color(0xFF1E293B)),
                      )
                    : ThemeData.light().copyWith(cardColor: Colors.white),
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 660,
                      height: MediaQuery.of(context).size.height * 0.88,
                      child: DetalleFacturaScreen(
                        factura: f,
                        empresaId: widget.empresaId,
                        asSheet: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.92,
              maxChildSize: 0.97,
              minChildSize: 0.5,
              expand: false,
              builder: (_, __) => ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: DetalleFacturaScreen(factura: f, empresaId: widget.empresaId, asSheet: true),
              ),
            ),
          );
        }
      },
      hoverColor: _panelBorder.withValues(alpha: 0.5),
      child: LayoutBuilder(builder: (_, cons) {
        final narrow = cons.maxWidth < 460;
        return Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _panelBorder.withValues(alpha: 0.5)))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            SizedBox(width: narrow ? 68 : 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            if (!narrow) SizedBox(width: 70, child: Text(fecha, style: TextStyle(color: _textSoft, fontSize: 11))),
            SizedBox(width: narrow ? 52 : 64, child: Text('${f.total.toStringAsFixed(2)}€',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _textMain), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
            SizedBox(width: narrow ? 56 : 68, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorEstado.withValues(alpha: 0.3))),
              child: Text(f.estado.etiqueta, style: TextStyle(color: colorEstado, fontSize: 9, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            ))),
            SizedBox(width: 28, child: _badgeVf(f.verifactu)),
            SizedBox(width: 26, child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 14, color: _textSoft),
              padding: EdgeInsets.zero,
              tooltip: 'Acciones',
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pdf', child: Row(children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 15, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8), const Text('Ver PDF', style: TextStyle(fontSize: 13)),
                ])),
                if (f.estado == EstadoFactura.pendiente || f.estado == EstadoFactura.vencida)
                  PopupMenuItem(value: 'pagada', child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 8), const Text('Marcar como pagada', style: TextStyle(fontSize: 13, color: Color(0xFF10B981))),
                  ])),
              ],
              onSelected: (v) async {
                if (v == 'pdf') _mostrarPdfPopup(context, f);
                if (v == 'pagada') {
                  await _service.actualizarEstado(
                    empresaId: widget.empresaId,
                    facturaId: f.id,
                    nuevoEstado: EstadoFactura.pagada,
                  );
                  if (context.mounted) FluxToast.exito(context, '✅ ${f.numeroFactura} marcada como pagada');
                }
              },
            )),
          ]),
        );
      }),
    );
  }

  Widget _badgeVf(Map<String, dynamic>? vf) {
    if (vf == null) return const SizedBox.shrink();
    final estado = vf['estado'] as String? ?? 'pendiente';
    final color = switch (estado) {
      'aceptada'              => const Color(0xFF10B981),
      'rechazada' || 'error'  => const Color(0xFFEF4444),
      'enviada'               => const Color(0xFF3B82F6),
      _                       => const Color(0xFFF59E0B),
    };
    return Tooltip(
      message: 'Verifactu: $estado',
      child: Container(
        width: 22, height: 16,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text('VF',
            style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w800))),
      ),
    );
  }

  // ── Panel derecho — gráficos ───────────────────────────────────────────────

  Widget _buildGraficosPanel(List<Factura> todas) {
    final todasAnio = todas.where((f) => f.fechaEmision.year == _anio).toList();
    final ingTotal = todasAnio.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final gasTotal = todasAnio.where((f) => f.flujo == 'gasto').fold(0.0, (s, f) => s + f.total);
    final benNeto  = ingTotal - gasTotal;
    return Column(children: [
      // ── Evolución de facturación ────────────────────────────────────────
      _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.show_chart_rounded, size: 15, color: _textSoft),
          const SizedBox(width: 6),
          Text('Evolución de facturación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final years = [DateTime.now().year - 2, DateTime.now().year - 1, DateTime.now().year];
              final picked = await showDialog<int>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: _panelBg,
                  title: Text('Seleccionar año', style: TextStyle(fontSize: 14, color: _textMain)),
                  children: years.map((y) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, y),
                    child: Text('$y', style: TextStyle(
                      fontSize: 14, color: y == _anio ? const Color(0xFF3B82F6) : _textMain,
                      fontWeight: y == _anio ? FontWeight.w700 : FontWeight.normal,
                    )),
                  )).toList(),
                ),
              );
              if (picked != null) setState(() => _anio = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$_anio', style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                const Icon(Icons.expand_more_rounded, size: 13, color: Color(0xFF3B82F6)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _resumenFila(Icons.trending_up_rounded,   'Total ingresos', ingTotal, const Color(0xFF10B981)),
        const SizedBox(height: 5),
        _resumenFila(Icons.trending_down_rounded, 'Total gastos',   gasTotal, const Color(0xFFEF4444)),
        const SizedBox(height: 5),
        _resumenFila(Icons.bolt_rounded, 'Beneficio neto', benNeto, benNeto >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), bold: true),
        const SizedBox(height: 14),
        SizedBox(height: 130, child: () {
          final sI = _spotsIngresos(todasAnio);
          final sG = _spotsGastos(todasAnio);
          final allY = [...sI.map((s) => s.y), ...sG.map((s) => s.y)];
          final maxY = allY.isEmpty ? 100.0 : allY.reduce((a, b) => a > b ? a : b) * 1.15;
          final minY = allY.isEmpty ? -10.0 : (allY.reduce((a, b) => a < b ? a : b) - maxY * 0.08);
          return LineChart(LineChartData(
            minY: minY < 0 ? minY : -maxY * 0.05,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: sI, isCurved: true,
                color: const Color(0xFF10B981), barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFF10B981).withValues(alpha: 0.1)),
              ),
              LineChartBarData(
                spots: sG, isCurved: true,
                color: const Color(0xFFEF4444), barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFFEF4444).withValues(alpha: 0.06)),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} €',
                  TextStyle(color: s.bar.color ?? Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                )).toList(),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
          ));
        }()),
      ])),
      const SizedBox(height: 14),
      // ── Flujo de caja (Ingresos vs. Gastos) con filtros ────────────────
      _buildFlujoCaja(todasAnio),
    ]);
  }

  Widget _buildFlujoCaja(List<Factura> todas) {
    final now = DateTime.now();
    List<Factura> filtradas;
    String etiqueta;

    switch (_periodoCaja) {
      case 'mes':
        filtradas = todas.where((f) =>
          f.fechaEmision.year == now.year && f.fechaEmision.month == now.month).toList();
        etiqueta = 'Este mes';
      case 'semana':
        final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
        final finSemana    = inicioSemana.add(const Duration(days: 6));
        filtradas = todas.where((f) =>
          !f.fechaEmision.isBefore(DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day)) &&
          !f.fechaEmision.isAfter(DateTime(finSemana.year, finSemana.month, finSemana.day, 23, 59))).toList();
        etiqueta = 'Esta semana';
      default: // año
        filtradas = todas.where((f) => f.fechaEmision.year == now.year).toList();
        etiqueta = 'Este año';
    }

    final ingF   = filtradas.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final gasF   = filtradas.where((f) => f.flujo == 'gasto').fold(0.0, (s, f) => s + f.total);
    final netoF  = ingF - gasF;

    return _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.donut_large_rounded, size: 15, color: _textSoft),
        const SizedBox(width: 6),
        Text('Flujo de caja', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
        const Spacer(),
        // Filtros período
        Container(
          height: 26,
          decoration: BoxDecoration(color: _darkMode ? const Color(0x10FFFFFF) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (key, lbl) in [('año','Año'), ('mes','Mes'), ('semana','Semana')])
              GestureDetector(
                onTap: () => setState(() => _periodoCaja = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _periodoCaja == key ? const Color(0xFF3B82F6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(lbl, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: _periodoCaja == key ? Colors.white : _textSoft,
                  )),
                ),
              ),
          ]),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 10),
        child: Text(etiqueta, style: TextStyle(fontSize: 10, color: _textSoft)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 120, height: 120, child: PieChart(PieChartData(
          sections: _seccionesDonut(ingF, gasF),
          centerSpaceRadius: 32, sectionsSpace: 3,
        ))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _leyendaItem(const Color(0xFF10B981), 'Ingresos', '${ingF.toStringAsFixed(0)} €'),
          const SizedBox(height: 10),
          _leyendaItem(const Color(0xFFEF4444), 'Gastos',   '${gasF.toStringAsFixed(0)} €'),
          const SizedBox(height: 10),
          _leyendaItem(
            netoF >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            'Neto', '${netoF.toStringAsFixed(0)} €',
          ),
        ])),
      ]),
    ]));
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

  // ── Sección inferior — 3 cards con carrusel ──────────────────────────────────

  Widget _buildBottomSection(List<Factura> todas) => LayoutBuilder(builder: (_, c) {
    final wide = c.maxWidth > 700;
    final todasAnio = todas.where((f) => f.fechaEmision.year == _anio).toList();
    final cardIzq = _buildCarruselBotIzq(todasAnio);
    final cardMed = _buildIngresosDelMes(todasAnio);
    final cardDer = _buildCarruselBotDer(todasAnio);
    if (wide) return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: cardIzq), const SizedBox(width: 14),
      Expanded(child: cardMed), const SizedBox(width: 14),
      Expanded(child: cardDer),
    ]));
    // Móvil: las 3 visibles individualmente (solo)
    return Column(children: [cardIzq, const SizedBox(height: 14), cardMed, const SizedBox(height: 14), cardDer]);
  });

  // ── Carrusel inferior izquierda: Facturas por estado / Métodos pago / Ventas tipo
  Widget _buildCarruselBotIzq(List<Factura> todas) {
    final slides = [
      _buildFacturaPorEstado(todas),
      _buildMetodosPago(todas),
      _buildVentasPorTipo(todas),
    ];
    final titles = ['Facturas por estado', 'Métodos de pago', 'Ventas por tipo'];
    return _buildCarrusel(slides, titles, _idxBotIzq, (i) => setState(() => _idxBotIzq = i));
  }

  // ── Carrusel inferior derecha: Top clientes / IVA por tipo / Facturación por categorías
  Widget _buildCarruselBotDer(List<Factura> todas) {
    final slides = [
      _buildTopClientes(todas),
      _buildIvaPorTipo(todas),
      _buildPorCategorias(todas),
    ];
    final titles = ['Top clientes', '🏛 IVA por tipo', '📦 Por categorías'];
    return _buildCarrusel(slides, titles, _idxBotDer, (i) => setState(() => _idxBotDer = i));
  }

  Widget _buildCarrusel(List<Widget> slides, List<String> titles, int idx, ValueChanged<int> onPage) {
    return Container(
      decoration: BoxDecoration(
        color: _panelBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _darkMode ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header con título + dots + flechas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
          child: Row(children: [
            Expanded(child: Text(titles[idx],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain),
                overflow: TextOverflow.ellipsis)),
            // Flechas
            _carruselBtn(Icons.chevron_left, idx > 0, () => onPage(idx - 1)),
            const SizedBox(width: 2),
            // Dots
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(slides.length, (i) => Container(
              width: i == idx ? 14 : 6, height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == idx ? const Color(0xFF10B981) : _panelBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ))),
            const SizedBox(width: 2),
            _carruselBtn(Icons.chevron_right, idx < slides.length - 1, () => onPage(idx + 1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 160,
            child: Center(child: slides[idx]),
          ),
        ),
      ]),
    );
  }

  Widget _carruselBtn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 24, height: 24,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: _panelBorder)),
      child: Icon(icon, size: 14, color: enabled ? _textSoft : _panelBorder),
    ),
  );

  // ── Slide 1 izq: Facturas por estado (donut) ─────────────────────────────
  Widget _buildFacturaPorEstado(List<Factura> todas) {
    final pag  = todas.where((f) => f.estado == EstadoFactura.pagada).length;
    final pend = todas.where((f) => f.estado == EstadoFactura.pendiente).length;
    final ven  = todas.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).length;
    final tot  = pag + pend + ven;
    return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 100, height: 100, child: PieChart(PieChartData(
          sections: [
            if (pag > 0)  PieChartSectionData(value: pag.toDouble(),  color: const Color(0xFF22C55E), radius: 30, title: ''),
            if (pend > 0) PieChartSectionData(value: pend.toDouble(), color: const Color(0xFFEAB308), radius: 30, title: ''),
            if (ven > 0)  PieChartSectionData(value: ven.toDouble(),  color: const Color(0xFFEF4444), radius: 30, title: ''),
            if (tot == 0) PieChartSectionData(value: 1, color: _panelBorder, radius: 30, title: ''),
          ],
          centerSpaceRadius: 24, sectionsSpace: 2,
        ))),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        _estadoItem(const Color(0xFF22C55E), 'Pagadas',    pag,  tot),
        const SizedBox(height: 8),
        _estadoItem(const Color(0xFFEAB308), 'Pendientes', pend, tot),
        const SizedBox(height: 8),
        _estadoItem(const Color(0xFFEF4444), 'Vencidas',   ven,  tot),
      ]),
    ]);
  }

  Widget _estadoItem(Color c, String label, int n, int tot) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: _textSoft)),
    const SizedBox(width: 6),
    Text('$n (${tot > 0 ? (n / tot * 100).round() : 0}%)',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
  ]);

  // ── Slide 2 izq: Métodos de pago (donut) ─────────────────────────────────
  Widget _buildMetodosPago(List<Factura> todas) {
    final map = <String, double>{};
    for (final f in todas.where((f) => f.flujo != 'gasto')) {
      final m = f.metodoPago?.name ?? 'efectivo';
      map[m] = (map[m] ?? 0) + f.total;
    }
    final tot = map.values.fold(0.0, (a, b) => a + b);
    final colors = [const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFFEAB308), const Color(0xFF8B5CF6)];
    final entries = map.entries.toList();
    return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 100, height: 100, child: PieChart(PieChartData(
          sections: entries.isEmpty
              ? [PieChartSectionData(value: 1, color: _panelBorder, radius: 30, title: '')]
              : entries.asMap().entries.map((e) => PieChartSectionData(
                  value: e.value.value,
                  color: colors[e.key % colors.length],
                  radius: 30, title: '',
                )).toList(),
          centerSpaceRadius: 24, sectionsSpace: 2,
        ))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (entries.isEmpty) Text('Sin datos', style: TextStyle(fontSize: 11, color: _textSoft))
        else ...entries.asMap().entries.take(4).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Expanded(child: Text(_labelMetodo(e.value.key), style: TextStyle(fontSize: 10, color: _textSoft), overflow: TextOverflow.ellipsis)),
            Text('${tot > 0 ? (e.value.value / tot * 100).round() : 0}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMain)),
          ]),
        )),
      ])),
    ]);
  }

  String _labelMetodo(String m) {
    switch (m) {
      case 'tarjeta':   return 'Tarjeta';
      case 'transferencia': return 'Transferencia';
      case 'efectivo':  return 'Efectivo';
      case 'bizum':     return 'Bizum';
      default:          return m.substring(0, 1).toUpperCase() + m.substring(1);
    }
  }

  // ── Slide 3 izq: Ventas por tipo (donut ingreso/gasto) ───────────────────
  Widget _buildVentasPorTipo(List<Factura> todas) {
    final ing  = todas.where((f) => f.flujo != 'gasto').fold(0.0, (s, f) => s + f.total);
    final gas  = todas.where((f) => f.flujo == 'gasto').fold(0.0, (s, f) => s + f.total);
    final tpv  = todas.where((f) => f.pedidoId != null || (f.ticketIds?.isNotEmpty == true)).fold(0.0, (s, f) => s + f.total);
    final tot  = ing + gas;
    return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 100, height: 100, child: PieChart(PieChartData(
          sections: tot == 0
              ? [PieChartSectionData(value: 1, color: _panelBorder, radius: 30, title: '')]
              : [
                  if (ing > 0) PieChartSectionData(value: ing, color: const Color(0xFF10B981), radius: 30, title: ''),
                  if (gas > 0) PieChartSectionData(value: gas, color: const Color(0xFFEF4444), radius: 30, title: ''),
                ],
          centerSpaceRadius: 24, sectionsSpace: 2,
        ))),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        _estadoDoble(const Color(0xFF10B981), 'Ingresos', ing, tot),
        const SizedBox(height: 8),
        _estadoDoble(const Color(0xFFEF4444), 'Gastos',   gas, tot),
        if (tpv > 0) ...[
          const SizedBox(height: 8),
          _estadoDoble(Colors.deepOrange, 'TPV', tpv, tot),
        ],
      ]),
    ]);
  }

  Widget _estadoDoble(Color c, String label, double v, double tot) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: _textSoft)),
    const SizedBox(width: 6),
    Text('${tot > 0 ? (v / tot * 100).round() : 0}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
  ]);

  // ── Centro abajo: Ingresos del mes (bar chart) ────────────────────────────
  Widget _buildIngresosDelMes(List<Factura> todas) {
    final m    = _mensualIngresos(todas);
    final mg   = _mensualGastos(todas);
    final maxV = [...m.values, ...mg.values].fold(0.0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _darkMode ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ingresos del mes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 8, height: 3, color: const Color(0xFF10B981)),
          const SizedBox(width: 4),
          Text('Ingresos', style: TextStyle(fontSize: 9, color: _textSoft)),
          const SizedBox(width: 10),
          Container(width: 8, height: 3, color: const Color(0xFFEF4444)),
          const SizedBox(width: 4),
          Text('Gastos', style: TextStyle(fontSize: 9, color: _textSoft)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: BarChart(BarChartData(
          barGroups: List.generate(12, (i) => BarChartGroupData(
            x: i, barsSpace: 2,
            barRods: [
              BarChartRodData(toY: m[i + 1] ?? 0, color: const Color(0xFF10B981), width: 8, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: mg[i + 1] ?? 0, color: const Color(0xFFEF4444), width: 8, borderRadius: BorderRadius.circular(3)),
            ],
          )),
          maxY: maxV > 0 ? maxV * 1.2 : 100,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: _panelBorder, strokeWidth: 0.5)),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(2)} €',
                TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)]),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 18,
              getTitlesWidget: (v, _) {
                const months = ['E','F','M','A','M','J','J','A','S','O','N','D'];
                final i = v.toInt();
                if (i < 0 || i >= 12) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 3),
                    child: Text(months[i], style: TextStyle(fontSize: 8, color: _textSoft)));
              },
            )),
          ),
        ))),
      ]),
    );
  }

  // ── Slide 1 der: Top clientes ─────────────────────────────────────────────
  Widget _buildTopClientes(List<Factura> todas) {
    final map = <String, double>{};
    for (final f in todas) {
      if (f.flujo != 'gasto') {
        final c = f.clienteNombre.isEmpty ? 'Caja directa' : f.clienteNombre;
        map[c] = (map[c] ?? 0) + f.total;
      }
    }
    final top    = (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final totSum = map.values.fold(0.0, (a, b) => a + b);
    if (top.isEmpty) return Center(child: Text('Sin datos', style: TextStyle(fontSize: 12, color: _textSoft)));
    return Column(children: top.asMap().entries.map((e) {
      final pct = totSum > 0 ? e.value.value / totSum : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Container(width: 20, height: 20,
              decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.value.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _textMain), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
            )),
          ])),
          const SizedBox(width: 8),
          Text('${e.value.value.toStringAsFixed(0)} €',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMain)),
        ]),
      );
    }).toList());
  }

  // ── Slide 2 der: IVA por tipo ─────────────────────────────────────────────
  Widget _buildIvaPorTipo(List<Factura> todas) {
    final map = <String, double>{};
    for (final f in todas.where((f) => f.flujo != 'gasto')) {
      for (final l in f.lineas) {
        final key = '${l.porcentajeIva.toStringAsFixed(0)}%';
        map[key] = (map[key] ?? 0) + l.importeIva;
      }
    }
    final colors = [const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFFEAB308), const Color(0xFF8B5CF6)];
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tot = entries.fold(0.0, (s, e) => s + e.value);
    if (entries.isEmpty) return Center(child: Text('Sin datos IVA', style: TextStyle(fontSize: 12, color: _textSoft)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...entries.asMap().entries.take(4).map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('IVA ${e.value.key}', style: TextStyle(fontSize: 11, color: _textSoft)),
            const Spacer(),
            Text('${e.value.value.toStringAsFixed(0)} €',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
            value: tot > 0 ? e.value.value / tot : 0,
            minHeight: 4,
            backgroundColor: colors[e.key % colors.length].withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(colors[e.key % colors.length]),
          )),
        ]),
      )),
    ]);
  }

  // ── Slide 3 der: Facturación por categorías ───────────────────────────────
  Widget _buildPorCategorias(List<Factura> todas) {
    final map = <String, double>{};
    for (final f in todas.where((f) => f.flujo != 'gasto')) {
      for (final l in f.lineas) {
        final cat = l.descripcion.isNotEmpty ? l.descripcion.split(' ').first : 'General';
        map[cat] = (map[cat] ?? 0) + l.subtotalSinIva;
      }
    }
    final entries = (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final tot = entries.fold(0.0, (s, e) => s + e.value);
    final colors = [const Color(0xFF10B981), const Color(0xFF3B82F6), const Color(0xFFEAB308), const Color(0xFF8B5CF6), const Color(0xFFF97316)];
    if (entries.isEmpty) return Center(child: Text('Sin datos', style: TextStyle(fontSize: 12, color: _textSoft)));
    return Column(children: entries.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(e.value.key, style: TextStyle(fontSize: 11, color: _textSoft), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text('${e.value.value.toStringAsFixed(0)} €',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMain)),
        const SizedBox(width: 4),
        Text('${tot > 0 ? (e.value.value / tot * 100).round() : 0}%',
            style: TextStyle(fontSize: 9, color: colors[e.key % colors.length])),
      ]),
    )).toList());
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

  Map<int, double> _mensualGastos(List<Factura> todas) {
    final m = <int, double>{};
    for (final f in todas) {
      if (f.flujo == 'gasto' && f.fechaEmision.year == _anio) {
        m[f.fechaEmision.month] = (m[f.fechaEmision.month] ?? 0) + f.total;
      }
    }
    return m;
  }

  List<FlSpot> _spotsIngresos(List<Factura> todas) {
    final m = _mensualIngresos(todas);
    return List.generate(12, (i) => FlSpot(i.toDouble(), m[i + 1] ?? 0));
  }

  List<FlSpot> _spotsGastos(List<Factura> todas) {
    final m = _mensualGastos(todas);
    return List.generate(12, (i) => FlSpot(i.toDouble(), m[i + 1] ?? 0));
  }

  // ── PDF Popup ──────────────────────────────────────────────────────────────

  void _mostrarPdfPopup(BuildContext context, Factura f) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
    );
    PdfService.generarFacturaPdfConDatos(f, widget.empresaId).then((bytes) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra spinner
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(ctx).size.width > 700 ? 40 : 12,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Barra de acciones ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
              ),
              child: Row(children: [
                const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(f.numeroFactura,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
                // Descargar
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.white, size: 20),
                  tooltip: 'Descargar PDF',
                  onPressed: () => Printing.sharePdf(bytes: bytes, filename: '${f.numeroFactura}.pdf'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Compartir
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                  tooltip: 'Compartir',
                  onPressed: () => Printing.sharePdf(bytes: bytes, filename: '${f.numeroFactura}.pdf'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Imprimir
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: Colors.white, size: 20),
                  tooltip: 'Imprimir',
                  onPressed: () => Printing.layoutPdf(onLayout: (_) async => bytes, name: '${f.numeroFactura}.pdf'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Cerrar
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ]),
            ),
            // ── Vista previa PDF (A4 completo) ─────────────────────────────
            SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: PdfPreview(
                build: (_) async => bytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: '${f.numeroFactura}.pdf',
                maxPageWidth: 800,
                actions: const [],
              ),
            ),
          ]),
        ),
      );
    }).catchError((e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        FluxToast.error(context, 'Error generando PDF: $e');
      }
    });
  }

  // ── Popups ─────────────────────────────────────────────────────────────────

  void _mostrarNuevaFactura({TipoFactura? tipoInicial}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FormularioFacturaScreen(
          empresaId: widget.empresaId,
          tipoInicial: tipoInicial,
        ),
      ),
    );
  }

  Future<void> _exportarCsv(List<Factura> facturas) async {
    if (facturas.isEmpty) {
      FluxToast.aviso(context, 'No hay facturas para exportar');
      return;
    }
    final buf = StringBuffer();
    buf.writeln('Nº Factura;Fecha;Cliente;NIF;Base Imponible;IVA;Total;Estado;Método Pago');
    for (final f in facturas) {
      final fecha = '${f.fechaEmision.day.toString().padLeft(2,'0')}/${f.fechaEmision.month.toString().padLeft(2,'0')}/${f.fechaEmision.year}';
      final nif   = f.datosFiscales?.nif ?? '';
      final metodo = f.metodoPago?.name ?? '';
      buf.writeln([
        f.numeroFactura, fecha,
        '"${f.clienteNombre.replaceAll('"', '""')}"',
        nif,
        f.subtotal.toStringAsFixed(2).replaceAll('.', ','),
        f.totalIva.toStringAsFixed(2).replaceAll('.', ','),
        f.total.toStringAsFixed(2).replaceAll('.', ','),
        f.estado.etiqueta, metodo,
      ].join(';'));
    }
    try {
      final dir  = await getTemporaryDirectory();
      final anio = facturas.first.fechaEmision.year;
      final file = File('${dir.path}/facturas_$anio.csv');
      await file.writeAsString(buf.toString(), encoding: const SystemEncoding());
      await Share.shareXFiles([XFile(file.path)],
          text: 'Facturas ${facturas.first.fechaEmision.year} — ${facturas.length} registros');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al exportar: $e');
    }
  }

  void _mostrarExportar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _darkMode ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                )),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.business_rounded, size: 20, color: Color(0xFFF97316)),
              const SizedBox(width: 8),
              Text('Proveedores', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: _darkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
              )),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
          Divider(height: 1, color: _darkMode ? Colors.white12 : Colors.grey.shade200),
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
