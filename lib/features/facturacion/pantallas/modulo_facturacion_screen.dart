import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:planeag_flutter/core/providers/empresa_config_provider.dart';
import 'package:planeag_flutter/domain/modelos/contabilidad.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/pantalla_contabilidad.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_libro_ingresos.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_graficos_contabilidad.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_modelos_fiscales.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_facturas_recibidas.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_mod_347.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/tab_facturas.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/formulario_factura_screen.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';

class ModuloFacturacionScreen extends StatefulWidget {
  final String empresaId;

  const ModuloFacturacionScreen({super.key, required this.empresaId});

  @override
  State<ModuloFacturacionScreen> createState() =>
      _ModuloFacturacionScreenState();
}

class _ModuloFacturacionScreenState extends State<ModuloFacturacionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContabilidadService _svcContab = ContabilidadService();
  int _anioContab = DateTime.now().year;

  static const _kColorPrimario = Color(0xFF0D47A1);
  static const _kColorOscuro = Color(0xFF1A237E);
  static const int _anioMin = 2020;
  static const int _anioMax = 2030;
  // Tab 0 = Facturas, tabs 1-9 = Contabilidad
  static const int _kContabStart = 1;

  bool get _enFacturas => _tabController.index == 0;
  bool get _enContabilidad => _tabController.index >= _kContabStart;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cambiarAnio(int delta) {
    final nuevo = _anioContab + delta;
    if (nuevo >= _anioMin && nuevo <= _anioMax) setState(() => _anioContab = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmpresaConfigProvider(widget.empresaId)..cargar(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: _kColorPrimario,
          elevation: 0,
          title: Text(
            _enFacturas ? 'Facturas' : 'Contabilidad',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
          ),
          actions: [
            if (_enContabilidad) _buildSelectorAnio(),
          ],
        ),
        body: Column(
          children: [
            if (_enContabilidad) _buildKpiHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Facturación ──────────────────────────────────────────
                  TabFacturas(empresaId: widget.empresaId),
                  // ── Contabilidad (tabs 1-9) ──────────────────────────────
                  ContabTabResumen(empresaId: widget.empresaId, anio: _anioContab, svc: _svcContab, color: _kColorPrimario),
                  TabLibroIngresos(empresaId: widget.empresaId, anio: _anioContab, svc: _svcContab),
                  TabFacturasRecibidas(empresaId: widget.empresaId, svc: _svcContab),
                  ContabTabGastos(empresaId: widget.empresaId, svc: _svcContab, color: _kColorPrimario),
                  TabGraficosContabilidad(empresaId: widget.empresaId, anio: _anioContab, svc: _svcContab),
                  TabModelosFiscales(empresaId: widget.empresaId, anio: _anioContab, svc: _svcContab),
                  TabMod347(empresaId: widget.empresaId, anio: _anioContab),
                  ContabTabProveedores(empresaId: widget.empresaId, svc: _svcContab, color: _kColorPrimario),
                  ContabTabExportar(empresaId: widget.empresaId, anio: _anioContab, svc: _svcContab, color: _kColorPrimario),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _enFacturas ? _buildFab() : null,
      ),
    );
  }

  // ── FAB NUEVA FACTURA ─────────────────────────────────────────────────────

  Widget _buildFab() => FloatingActionButton.extended(
    heroTag: 'nueva_factura',
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioFacturaScreen(empresaId: widget.empresaId)),
    ),
    backgroundColor: _kColorPrimario,
    icon: const Icon(Icons.receipt_long, color: Colors.white),
    label: const Text('Nueva Factura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
  );

  // ── SELECTOR DE AÑO ───────────────────────────────────────────────────────

  Widget _buildSelectorAnio() => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _arrowBtn(Icons.chevron_left, () => _cambiarAnio(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('$_anioContab', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          _arrowBtn(Icons.chevron_right, () => _cambiarAnio(1)),
        ],
      ),
    ),
  );

  Widget _arrowBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: Colors.white, size: 20)),
  );

  // ── BARRA KPI ─────────────────────────────────────────────────────────────

  Widget _buildKpiHeader() => FutureBuilder<ResumenContable>(
    key: ValueKey(_anioContab),
    future: _svcContab.calcularResumen(empresaId: widget.empresaId, anio: _anioContab),
    builder: (context, snap) {
      final r = snap.data;
      final loading = snap.connectionState == ConnectionState.waiting;
      return Container(
        color: _kColorOscuro,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: loading
            ? const SizedBox(height: 30, child: LinearProgressIndicator(backgroundColor: Colors.white24, color: Colors.white54))
            : IntrinsicHeight(
                child: Row(children: [
                  _kpiBox('Ingresos', r?.totalFacturado ?? 0, Colors.greenAccent.shade200, Icons.trending_up),
                  const VerticalDivider(color: Colors.white24, width: 1, thickness: 1),
                  _kpiBox('Gastos', r?.totalGastado ?? 0, Colors.redAccent.shade100, Icons.trending_down),
                  const VerticalDivider(color: Colors.white24, width: 1, thickness: 1),
                  _kpiBox('Resultado', r?.beneficioNeto ?? 0,
                      (r?.hayBeneficio ?? true) ? Colors.greenAccent.shade200 : Colors.orangeAccent,
                      (r?.hayBeneficio ?? true) ? Icons.arrow_upward : Icons.arrow_downward),
                ]),
              ),
      );
    },
  );

  Widget _kpiBox(String label, double valor, Color color, IconData icono) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Icon(icono, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w500)),
            Text('${valor.toStringAsFixed(0)}€', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    ),
  );

  // ── TAB BAR ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: TabBar(
      controller: _tabController,
      labelColor: _kColorPrimario,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.transparent,
      indicatorWeight: 0.1,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
      indicator: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      tabs: const [
        _StyledTab(icon: Icons.receipt_long,          label: 'Facturas',     highlight: true),
        _StyledTab(icon: Icons.calculate_outlined,    label: 'Resumen'),
        _StyledTab(icon: Icons.trending_up,           label: 'Ingresos'),
        _StyledTab(icon: Icons.shopping_cart_outlined,label: 'Recibidas'),
        _StyledTab(icon: Icons.receipt_long,          label: 'Gastos'),
        _StyledTab(icon: Icons.bar_chart,             label: 'Gráficos'),
        _StyledTab(icon: Icons.account_balance,       label: 'Modelos'),
        _StyledTab(icon: Icons.assignment_outlined,   label: 'MOD 347'),
        _StyledTab(icon: Icons.people_outline,        label: 'Proveedores'),
        _StyledTab(icon: Icons.file_download_outlined,label: 'Exportar'),
      ],
    ),
  );
}

class _StyledTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _StyledTab({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 3),
            Text(label),
          ],
        ),
      ),
    );
  }
}
