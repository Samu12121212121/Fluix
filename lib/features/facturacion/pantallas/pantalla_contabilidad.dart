import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../services/contabilidad_service.dart';
import '../../../domain/modelos/contabilidad.dart';
import 'tab_libro_ingresos.dart';
import 'tab_graficos_contabilidad.dart';
import 'tab_modelos_fiscales.dart';
import 'tab_facturas_recibidas.dart';
import 'tab_mod_347.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL CONTABILIDAD
// ═════════════════════════════════════════════════════════════════════════════

class PantallaContabilidad extends StatefulWidget {
  final String empresaId;
  const PantallaContabilidad({super.key, required this.empresaId});

  @override
  State<PantallaContabilidad> createState() => _PantallaContabilidadState();
}

class _PantallaContabilidadState extends State<PantallaContabilidad>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final ContabilidadService _svc = ContabilidadService();
  int _anio = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return ChangeNotifierProvider(
      create: (_) => EmpresaConfigProvider(widget.empresaId)..cargar(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Contabilidad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _anio,
                  dropdownColor: color,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  items: [2024, 2025, 2026]
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y', style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _anio = v);
                  },
                ),
              ),
            ),
          ],
        ),
        body: Column(children: [
          TabBar(
            controller: _tab,
            labelColor: color,
            unselectedLabelColor: Colors.grey,
            indicatorColor: color,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Resumen'),
              Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Ingresos'),
              Tab(icon: Icon(Icons.shopping_cart_outlined, size: 18), text: 'F. Recibidas'),
              Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Gastos manuales'),
              Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Gráficos'),
              Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Modelos'),
              Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'MOD 347'),
              Tab(icon: Icon(Icons.people, size: 18), text: 'Proveedores'),
              Tab(icon: Icon(Icons.file_download, size: 18), text: 'Exportar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TabResumen(empresaId: widget.empresaId, anio: _anio, svc: _svc, color: color),
                TabLibroIngresos(empresaId: widget.empresaId, anio: _anio, svc: _svc),
                TabFacturasRecibidas(empresaId: widget.empresaId, svc: _svc),
                _TabGastos(empresaId: widget.empresaId, svc: _svc, color: color),
                TabGraficosContabilidad(empresaId: widget.empresaId, anio: _anio, svc: _svc),
                TabModelosFiscales(empresaId: widget.empresaId, anio: _anio, svc: _svc),
                TabMod347(
                  empresaId: widget.empresaId,
                  anio: _anio,
                ),
                _TabProveedores(empresaId: widget.empresaId, svc: _svc, color: color),
                _TabExportar(empresaId: widget.empresaId, anio: _anio, svc: _svc, color: color),
              ],
            ),
          ),
        ]),
      ),
    );
  }

}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — RESUMEN FISCAL
// ═════════════════════════════════════════════════════════════════════════════

class _TabResumen extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;
  final Color color;
  const _TabResumen({required this.empresaId, required this.anio,
      required this.svc, required this.color});

  @override
  State<_TabResumen> createState() => _TabResumenState();
}

class _TabResumenState extends State<_TabResumen> {
  ResumenContable? _resumenAnual;
  List<ResumenContable> _trimestres = [];
  bool _cargando = true;
  String? _error;
  int _trimestreSeleccionado = 0; // 0 = anual

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(_TabResumen old) {
    super.didUpdateWidget(old);
    if (old.anio != widget.anio) _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final anual = await widget.svc.calcularResumen(
          empresaId: widget.empresaId, anio: widget.anio);
      final trimestres = await widget.svc.calcularTrimestres(
          widget.empresaId, widget.anio);
      if (mounted) {
        setState(() {
          _resumenAnual = anual;
          _trimestres = trimestres;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  ResumenContable? get _resumenActual => _trimestreSeleccionado == 0
      ? _resumenAnual
      : (_trimestres.isNotEmpty
          ? _trimestres[_trimestreSeleccionado - 1]
          : null);

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Error al cargar resumen:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      ));
    }
    final r = _resumenActual;
    if (r == null) return const Center(child: Text('Sin datos'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Selector trimestre ──────────────────────────────────────────
        _buildSelectorPeriodo(),
        const SizedBox(height: 16),

        // ── Tarjetas principales ────────────────────────────────────────
        Row(children: [
          Expanded(child: _buildKpiCard(
            'Ingresos\nnetos', r.baseImponibleEmitida,
            Icons.trending_up, Colors.green, '${r.numFacturasEmitidas} facturas',
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildKpiCard(
            'Gastos\nnetos', r.baseImponibleRecibida,
            Icons.trending_down, Colors.red, '${r.numGastos} gastos',
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildKpiCard(
            'Beneficio\nneto', r.beneficioNeto,
            r.hayBeneficio ? Icons.star : Icons.warning,
            r.hayBeneficio ? widget.color : Colors.orange,
            r.hayBeneficio ? 'Positivo ✓' : 'Negativo ⚠',
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildKpiCard(
            r.hayDevolucion ? 'IVA a\ndevolver' : 'IVA a\ningresar',
            r.ivaAIngresar.abs(),
            Icons.account_balance,
            r.hayDevolucion ? Colors.green : Colors.deepOrange,
            'Modelo 303',
          )),
        ]),
        const SizedBox(height: 20),

        // ── Detalle IVA ─────────────────────────────────────────────────
        _buildCard(
          titulo: 'Desglose IVA — Modelo 303',
          icono: Icons.receipt,
          color: Colors.deepOrange,
          child: Column(children: [
            _buildFilaDetalle('IVA repercutido (ventas)',
                r.ivaRepercutido, Colors.green),
            _buildFilaDetalle('IVA soportado (gastos)',
                -r.ivaSoportado, Colors.red),
            const Divider(),
            _buildFilaDetalle(
              r.hayDevolucion ? '✓ Hacienda te devuelve' : '⚠ A ingresar',
              r.ivaAIngresar.abs(),
              r.hayDevolucion ? Colors.green : Colors.deepOrange,
              negrita: true,
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── IRPF ────────────────────────────────────────────────────────
        if (r.hayBeneficio)
          _buildCard(
            titulo: 'Pago Fraccionado IRPF — Modelo 130',
            icono: Icons.percent,
            color: Colors.purple,
            child: Column(children: [
              _buildFilaDetalle('Base (beneficio neto)', r.beneficioNeto, Colors.black87),
              _buildFilaDetalle('Retención estimada (20%)',
                  r.pagoFraccionadoIRPF, Colors.purple, negrita: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠ Dato orientativo. Tu gestor calculará el importe exacto según deducciones y retenciones previas.',
                  style: TextStyle(fontSize: 11, color: Colors.purple),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 12),

        // ── Trimestres ──────────────────────────────────────────────────
        if (_trimestres.isNotEmpty && _trimestreSeleccionado == 0)
          _buildCard(
            titulo: 'Desglose trimestral',
            icono: Icons.bar_chart,
            color: widget.color,
            child: Column(
              children: _trimestres.asMap().entries.map((e) {
                final t = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('T${e.key + 1}',
                          style: TextStyle(color: widget.color,
                              fontWeight: FontWeight.bold, fontSize: 12))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Base: ${t.baseImponibleEmitida.toStringAsFixed(2)}€',
                            style: const TextStyle(fontSize: 12)),
                        Text('IVA neto: ${t.ivaAIngresar.toStringAsFixed(2)}€',
                            style: TextStyle(
                                fontSize: 11,
                                color: t.hayDevolucion ? Colors.green : Colors.deepOrange)),
                      ],
                    )),
                    Text(t.hayBeneficio
                        ? '+${t.beneficioNeto.toStringAsFixed(0)}€'
                        : '${t.beneficioNeto.toStringAsFixed(0)}€',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: t.hayBeneficio ? Colors.green : Colors.red)),
                  ]),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 12),

        // ── Cuenta de Resultados (P&L) ──────────────────────────────────
        if (_resumenAnual != null)
          _buildCard(
            titulo: 'Cuenta de Resultados (P&L) ${widget.anio}',
            icono: Icons.analytics_outlined,
            color: Colors.teal,
            child: _buildPyL(_resumenAnual!),
          ),
      ],
    );
  }

  Widget _buildPyL(ResumenContable r) {
    final margen = r.totalFacturado > 0
        ? (r.beneficioNeto / r.baseImponibleEmitida * 100)
        : 0.0;
    return Column(
      children: [
        _filaPlantilla('INGRESOS', null, null, seccion: true),
        _filaPlantilla('  (+) Ventas / Servicios', r.baseImponibleEmitida, Colors.green),
        const Divider(height: 16),
        _filaPlantilla('GASTOS', null, null, seccion: true),
        _filaPlantilla('  (–) Gastos operacionales', r.baseImponibleRecibida, Colors.red),
        const Divider(height: 16),
        _filaPlantilla('RESULTADO BRUTO (EBITDA)',
            r.beneficioNeto, r.hayBeneficio ? Colors.teal : Colors.red,
            negrita: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (r.hayBeneficio ? Colors.teal : Colors.red)
                .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                Text(
                  '${margen.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: r.hayBeneficio ? Colors.teal : Colors.red),
                ),
                Text('Margen neto',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
              Container(width: 1, height: 36, color: Colors.grey[200]),
              Column(children: [
                Text(
                  '${r.numFacturasEmitidas}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo),
                ),
                Text('Facturas emitidas',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
              Container(width: 1, height: 36, color: Colors.grey[200]),
              Column(children: [
                Text(
                  '${r.numGastos}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepOrange),
                ),
                Text('Gastos registrados',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
            ],
          ),
        ),
        if (r.numFacturasPendientes > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.pending, color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              Text(
                '${r.numFacturasPendientes} factura${r.numFacturasPendientes > 1 ? 's' : ''} pendiente${r.numFacturasPendientes > 1 ? 's' : ''} de cobro',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _filaPlantilla(String label, double? valor, Color? color,
      {bool negrita = false, bool seccion = false}) {
    if (seccion) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        negrita ? FontWeight.bold : FontWeight.normal))),
        Text(
          '${valor!.toStringAsFixed(2)}€',
          style: TextStyle(
              fontSize: negrita ? 14 : 13,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87),
        ),
      ]),
    );
  }

  // ignore: unused_element — keep for reference
  Widget _buildSelectorPeriodoUnused() => const SizedBox.shrink();

  Widget _buildSelectorPeriodo() {
    final opciones = ['Anual', 'T1', 'T2', 'T3', 'T4'];
    return Row(
      children: opciones.asMap().entries.map((e) {
        final sel = e.key == _trimestreSeleccionado;
        return GestureDetector(
          onTap: () => setState(() => _trimestreSeleccionado = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? widget.color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? widget.color : Colors.grey.withValues(alpha: 0.3)),
              boxShadow: sel
                  ? [BoxShadow(color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 6)]
                  : null,
            ),
            child: Text(e.value,
                style: TextStyle(
                    color: sel ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKpiCard(String titulo, double valor, IconData icono,
      Color color, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(titulo,
              style: TextStyle(color: Colors.grey[600],
                  fontSize: 11, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        Text('${valor.toStringAsFixed(2)}€',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(subtitulo,
            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]),
    );
  }

  Widget _buildFilaDetalle(String label, double valor, Color color,
      {bool negrita = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: negrita ? FontWeight.bold : FontWeight.normal))),
        Text('${valor >= 0 ? '' : '-'}${valor.abs().toStringAsFixed(2)}€',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildCard({required String titulo, required IconData icono,
      required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — GASTOS
// ═════════════════════════════════════════════════════════════════════════════

class _TabGastos extends StatelessWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Color color;
  const _TabGastos({required this.empresaId, required this.svc,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gasto>>(
      stream: svc.obtenerGastos(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final gastos = snap.data ?? [];

        return Stack(children: [
          // ── Lista scrollable ──────────────────────────────────────────
          gastos.isEmpty
              ? _buildVacio(context)
              : () {
                  // Agrupar por mes ordenado desc
                  final grupos = <String, List<Gasto>>{};
                  for (final g in gastos) {
                    final key =
                        '${g.fechaGasto.year}-${g.fechaGasto.month.toString().padLeft(2, '0')}';
                    grupos.putIfAbsent(key, () => []).add(g);
                  }
                  final claves = grupos.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [
                      _buildResumenGastos(gastos),
                      const SizedBox(height: 16),
                      ...claves.map(
                          (k) => _buildGrupoMes(context, k, grupos[k]!)),
                    ],
                  );
                }(),

          // ── FAB posicionado sin Scaffold ──────────────────────────────
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_nuevo_gasto',
              onPressed: () => _abrirFormGasto(context, null),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo gasto'),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Sin gastos registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Registra tus gastos para calcular el IVA soportado',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirFormGasto(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Registrar primer gasto'),
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _buildResumenGastos(List<Gasto> gastos) {
    final total = gastos.fold(0.0, (s, g) => s + g.total);
    final iva = gastos
        .where((g) => g.ivaDeducible)
        .fold(0.0, (s, g) => s + g.importeIva);
    final pendientes = gastos.where((g) => g.estado == EstadoGasto.pendiente).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Row(children: [
        _miniKpi('Total gastos', '${total.toStringAsFixed(0)}€', Colors.red),
        _sep(),
        _miniKpi('IVA deducible', '${iva.toStringAsFixed(0)}€', Colors.orange),
        _sep(),
        _miniKpi('Pendientes', '$pendientes', Colors.blue),
      ]),
    );
  }

  Widget _miniKpi(String label, String valor, Color c) => Expanded(
    child: Column(children: [
      Text(valor,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _sep() => Container(width: 1, height: 36, color: Colors.grey[200]);

  Widget _buildGrupoMes(BuildContext context, String key, List<Gasto> gastos) {
    final parts = key.split('-');
    final anio = int.parse(parts[0]);
    final mes = int.parse(parts[1]);
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
      'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre',
      'Noviembre', 'Diciembre'];
    final totalMes = gastos.fold(0.0, (s, g) => s + g.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Text('${meses[mes]} $anio',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Text('${totalMes.toStringAsFixed(2)}€',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
          ]),
        ),
        ...gastos.map((g) => _TarjetaGasto(
            gasto: g,
            svc: svc,
            empresaId: empresaId,
            color: color,
            onEditar: () => _abrirFormGasto(context, g))),
        const SizedBox(height: 8),
      ],
    );
  }

  void _abrirFormGasto(BuildContext context, Gasto? gasto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaFormGasto(
          empresaId: empresaId,
          svc: svc,
          gasto: gasto,
        ),
      ),
    );
  }
}

class _TarjetaGasto extends StatelessWidget {
  final Gasto gasto;
  final ContabilidadService svc;
  final String empresaId;
  final Color color;
  final VoidCallback onEditar;

  const _TarjetaGasto({required this.gasto, required this.svc,
      required this.empresaId, required this.color, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final catColor = _colorCategoria(gasto.categoria);
    final pagado = gasto.estado == EstadoGasto.pagado;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt, color: catColor, size: 20),
        ),
        title: Text(gasto.concepto,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gasto.categoria.nombre,
                style: TextStyle(color: catColor, fontSize: 11)),
            if (gasto.proveedorNombre != null)
              Text(gasto.proveedorNombre!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${gasto.total.toStringAsFixed(2)}€',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pagado ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(pagado ? 'Pagado' : 'Pendiente',
                  style: TextStyle(
                      fontSize: 10,
                      color: pagado ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        onTap: onEditar,
      ),
    );
  }

  Color _colorCategoria(CategoriaGasto c) {
    switch (c) {
      case CategoriaGasto.suministros:  return Colors.blue;
      case CategoriaGasto.alquiler:     return Colors.purple;
      case CategoriaGasto.software:     return Colors.teal;
      case CategoriaGasto.marketing:    return Colors.orange;
      case CategoriaGasto.personal:     return Colors.green;
      case CategoriaGasto.transporte:   return Colors.indigo;
      case CategoriaGasto.equipamiento: return Colors.brown;
      case CategoriaGasto.gestor:       return Colors.deepPurple;
      default:                          return Colors.grey;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — PROVEEDORES
// ═════════════════════════════════════════════════════════════════════════════

class _TabProveedores extends StatelessWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Color color;
  const _TabProveedores({required this.empresaId, required this.svc,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Proveedor>>(
      stream: svc.obtenerProveedores(empresaId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final proveedores = snap.data ?? [];

        return Stack(children: [
          // ── Lista ─────────────────────────────────────────────────────
          proveedores.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('Sin proveedores',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Genera datos de prueba o añade uno manualmente',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _abrirFormProveedor(context, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir proveedor'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color, foregroundColor: Colors.white),
                    ),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: proveedores.length,
                  itemBuilder: (ctx, i) {
                    final p = proveedores[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6)],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Text(
                              p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                              style: TextStyle(color: color,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.nif != null)
                              Text('NIF: ${p.nif}',
                                  style: const TextStyle(fontSize: 11)),
                            Text(p.categoria,
                                style: TextStyle(color: color, fontSize: 11)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _abrirFormProveedor(context, p),
                        ),
                        onTap: () => _abrirFormProveedor(context, p),
                      ),
                    );
                  },
                ),

          // ── FAB ───────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_nuevo_proveedor',
              onPressed: () => _abrirFormProveedor(context, null),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo proveedor'),
            ),
          ),
        ]);
      },
    );
  }

  void _abrirFormProveedor(BuildContext context, Proveedor? p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaFormProveedor(
          empresaId: empresaId,
          svc: svc,
          proveedor: p,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — EXPORTAR
// ═════════════════════════════════════════════════════════════════════════════

class _TabExportar extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;
  final Color color;
  const _TabExportar({required this.empresaId, required this.anio,
      required this.svc, required this.color});

  @override
  State<_TabExportar> createState() => _TabExportarState();
}

class _TabExportarState extends State<_TabExportar> {
  bool _exportando = false;

  Future<void> _exportar(String tipo) async {
    setState(() => _exportando = true);
    try {
      String csv;
      String nombre;
      switch (tipo) {
        case 'emitidas':
          csv = await widget.svc.exportarLibroEmitidasCsv(
              widget.empresaId, widget.anio);
          nombre = 'facturas_emitidas_${widget.anio}.csv';
          break;
        case 'recibidas':
          csv = await widget.svc.exportarLibroRecibidasCsv(
              widget.empresaId, widget.anio);
          nombre = 'facturas_recibidas_${widget.anio}.csv';
          break;
        default:
          csv = await widget.svc.exportarInformeGestoriaCsv(
              widget.empresaId, widget.anio);
          nombre = 'informe_gestoria_${widget.anio}.csv';
      }
      if (mounted) {
        setState(() => _exportando = false);
        _mostrarExportado(csv, nombre);
      }
    } catch (e) {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _mostrarExportado(String csv, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csv));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('✅ CSV copiado al portapapeles')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar'),
              ),
            ]),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(csv,
                      style: const TextStyle(color: Color(0xFF9CDCFE),
                          fontSize: 10, fontFamily: 'monospace')),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csv));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 CSV copiado — pégalo en Google Sheets o Excel'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copiar y cerrar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/$nombre');
                    await file.writeAsString(csv, flush: true);
                    await Share.shareXFiles(
                      [XFile(file.path, mimeType: 'text/csv')],
                      subject: nombre,
                    );
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartir como archivo .csv'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: widget.color,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.file_download, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Exportar para Gestoría',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              SizedBox(height: 6),
              Text('Genera archivos CSV listos para importar en tu gestoría o '
                  'en Google Sheets / Excel.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Opciones de exportación
        _buildOpcion(
          context,
          icono: Icons.trending_up,
          color: Colors.green,
          titulo: 'Libro Facturas Emitidas',
          descripcion: 'Todas las facturas que has emitido en ${widget.anio}',
          tipo: 'emitidas',
        ),
        const SizedBox(height: 10),
        _buildOpcion(
          context,
          icono: Icons.trending_down,
          color: Colors.red,
          titulo: 'Libro Facturas Recibidas / Gastos',
          descripcion: 'Todos los gastos y compras de ${widget.anio}',
          tipo: 'recibidas',
        ),
        const SizedBox(height: 10),
        _buildOpcion(
          context,
          icono: Icons.summarize,
          color: Colors.deepOrange,
          titulo: 'Informe Completo Gestoría',
          descripcion: 'Resumen fiscal + libros emitidas y recibidas en un solo archivo',
          tipo: 'gestoria',
          destacado: true,
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOpcion(BuildContext context, {
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
    required String tipo,
    bool destacado = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: destacado
            ? Border.all(color: color.withValues(alpha: 0.4), width: 2)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color, size: 22),
        ),
        title: Row(children: [
          Expanded(child: Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (destacado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Recomendado',
                  style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Text(descripcion,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: _exportando
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.download, color: color),
        onTap: _exportando ? null : () => _exportar(tipo),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORMULARIO DE GASTO
// ═════════════════════════════════════════════════════════════════════════════

class PantallaFormGasto extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Gasto? gasto;

  const PantallaFormGasto({super.key, required this.empresaId,
      required this.svc, this.gasto});

  @override
  State<PantallaFormGasto> createState() => _PantallaFormGastoState();
}

class _PantallaFormGastoState extends State<PantallaFormGasto> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _factNumCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  CategoriaGasto _categoria = CategoriaGasto.otros;
  double _porcIva = 21.0;
  bool _ivaDeducible = true;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.gasto != null) {
      final g = widget.gasto!;
      _conceptoCtrl.text = g.concepto;
      _baseCtrl.text = g.baseImponible.toStringAsFixed(2);
      _factNumCtrl.text = g.numeroFacturaProveedor ?? '';
      _proveedorCtrl.text = g.proveedorNombre ?? '';
      _notasCtrl.text = g.notas ?? '';
      _categoria = g.categoria;
      _porcIva = g.porcentajeIva;
      _ivaDeducible = g.ivaDeducible;
      _fecha = g.fechaGasto;
    }
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose(); _baseCtrl.dispose(); _factNumCtrl.dispose();
    _proveedorCtrl.dispose(); _notasCtrl.dispose();
    super.dispose();
  }

  double get _base => double.tryParse(_baseCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _iva => _ivaDeducible ? _base * (_porcIva / 100) : 0;
  double get _total => _base + _iva;

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.gasto == null ? 'Nuevo gasto' : 'Editar gasto'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(_guardando ? 'Guardando...' : 'Guardar',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(child: Column(children: [
              TextFormField(
                controller: _conceptoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Concepto del gasto *',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.description_outlined)),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _proveedorCtrl,
                decoration: const InputDecoration(
                    labelText: 'Proveedor (opcional)',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.storefront_outlined)),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _factNumCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nº factura proveedor (opcional)',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.tag)),
              ),
            ])),
            const SizedBox(height: 12),

            // Categoría
            _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Categoría',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: CategoriaGasto.values.map((c) {
                    final sel = c == _categoria;
                    return GestureDetector(
                      onTap: () => setState(() => _categoria = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? color : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(c.nombre,
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )),
            const SizedBox(height: 12),

            // Importes
            _card(child: Column(children: [
              TextFormField(
                controller: _baseCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Base imponible (€) *',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.euro)),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obligatorio';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Número inválido';
                  }
                  return null;
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _ivaDeducible,
                onChanged: (v) => setState(() => _ivaDeducible = v),
                activeThumbColor: color,
                title: const Text('IVA deducible',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(_ivaDeducible
                    ? 'Se restará del IVA a ingresar'
                    : 'No deducible (ticket sin factura, etc.)',
                    style: const TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              ),
              if (_ivaDeducible) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    const Text('% IVA: ', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    ...[0.0, 4.0, 10.0, 21.0].map((p) => GestureDetector(
                      onTap: () => setState(() => _porcIva = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _porcIva == p
                              ? color : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${p.toInt()}%',
                            style: TextStyle(
                                color: _porcIva == p
                                    ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    )),
                  ]),
                ),
              ],
              const Divider(height: 1),
              // Preview total
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Base: ${_base.toStringAsFixed(2)}€',
                          style: const TextStyle(fontSize: 12)),
                      if (_ivaDeducible)
                        Text('IVA (${_porcIva.toInt()}%): ${_iva.toStringAsFixed(2)}€',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  )),
                  Text('Total: ${_total.toStringAsFixed(2)}€',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 16, color: color)),
                ]),
              ),
            ])),
            const SizedBox(height: 12),

            // Fecha
            _card(child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha del gasto'),
              subtitle: Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _fecha = picked);
              },
              trailing: const Icon(Icons.chevron_right),
            )),
            const SizedBox(height: 12),

            // Notas
            _card(child: TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: InputBorder.none,
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.svc.guardarGasto(
        widget.empresaId,
        concepto: _conceptoCtrl.text.trim(),
        categoria: _categoria,
        proveedorNombre: _proveedorCtrl.text.trim().isEmpty
            ? null : _proveedorCtrl.text.trim(),
        numeroFacturaProveedor: _factNumCtrl.text.trim().isEmpty
            ? null : _factNumCtrl.text.trim(),
        baseImponible: _base,
        porcentajeIva: _porcIva,
        ivaDeducible: _ivaDeducible,
        fechaGasto: _fecha,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        gastoIdEditar: widget.gasto?.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Gasto guardado correctamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORMULARIO DE PROVEEDOR
// ═════════════════════════════════════════════════════════════════════════════

class PantallaFormProveedor extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Proveedor? proveedor;

  const PantallaFormProveedor({super.key, required this.empresaId,
      required this.svc, this.proveedor});

  @override
  State<PantallaFormProveedor> createState() => _PantallaFormProveedorState();
}

class _PantallaFormProveedorState extends State<PantallaFormProveedor> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _nifCtrl     = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _dirCtrl     = TextEditingController();
  String _categoria  = 'servicios';
  bool _guardando    = false;

  @override
  void initState() {
    super.initState();
    if (widget.proveedor != null) {
      final p = widget.proveedor!;
      _nombreCtrl.text = p.nombre;
      _nifCtrl.text = p.nif ?? '';
      _emailCtrl.text = p.email ?? '';
      _telCtrl.text = p.telefono ?? '';
      _dirCtrl.text = p.direccion ?? '';
      _categoria = p.categoria;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _nifCtrl.dispose(); _emailCtrl.dispose();
    _telCtrl.dispose(); _dirCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(_guardando ? 'Guardando...' : 'Guardar',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(child: Column(children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre / Razón social *',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.storefront_outlined)),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _nifCtrl,
                decoration: const InputDecoration(
                    labelText: 'NIF / CIF',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.email_outlined)),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _telCtrl,
                decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _dirCtrl,
                decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),
            ])),
            const SizedBox(height: 12),
            _card(child: DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: InputBorder.none,
                  prefixIcon: Icon(Icons.category_outlined)),
              items: ['suministros', 'servicios', 'software', 'alquiler',
                'marketing', 'transporte', 'seguros', 'gestor', 'otros']
                  .map((c) => DropdownMenuItem(value: c,
                  child: Text(c[0].toUpperCase() + c.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v!),
            )),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final p = Proveedor(
        id: widget.proveedor?.id ?? '',
        nombre: _nombreCtrl.text.trim(),
        nif: _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        direccion: _dirCtrl.text.trim().isEmpty ? null : _dirCtrl.text.trim(),
        categoria: _categoria,
        fechaAlta: widget.proveedor?.fechaAlta ?? DateTime.now(),
      );
      await widget.svc.guardarProveedor(widget.empresaId, p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Proveedor guardado'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}











