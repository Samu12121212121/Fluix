import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../core/utils/app_settings.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../services/contabilidad_service.dart';
import '../../../domain/modelos/contabilidad.dart';
import 'tab_modelos_fiscales.dart';
import 'formulario_factura_recibida_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL CONTABILIDAD — diseño con pill toggle
// ═════════════════════════════════════════════════════════════════════════════

class PantallaContabilidad extends StatefulWidget {
  final String empresaId;
  final int initialTab;
  const PantallaContabilidad({super.key, required this.empresaId, this.initialTab = 0});

  @override
  State<PantallaContabilidad> createState() => _PantallaContabilidadState();
}

class _PantallaContabilidadState extends State<PantallaContabilidad> {
  final ContabilidadService _svc = ContabilidadService();
  int  _anio    = DateTime.now().year;
  int  _seccion = 0; // 0 = Resumen, 1 = Modelos
  bool _isDark  = false;

  Color get _bg     => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get _surf   => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text   => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub    => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _border => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDarkChange);
    // initialTab >= 5 era "Modelos" en el TabBar antiguo
    _seccion = widget.initialTab >= 5 ? 1 : 0;
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDarkChange);
    super.dispose();
  }

  void _onDarkChange() {
    if (mounted) setState(() => _isDark = AppSettings.darkMode.value);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmpresaConfigProvider(widget.empresaId)..cargar(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: Navigator.of(context).canPop()
            ? const FluixAppBar(titulo: 'Contabilidad', showLeading: true)
            : null,
        body: Column(children: [
          _buildTopBar(),
          Divider(height: 1, thickness: 1, color: _border),
          Expanded(child: IndexedStack(
            index: _seccion,
            children: [
              ContabTabResumen(
                empresaId: widget.empresaId,
                anio: _anio, svc: _svc,
                color: const Color(0xFF3B82F6),
                isDark: _isDark,
              ),
              TabModelosFiscales(
                empresaId: widget.empresaId,
                anio: _anio, svc: _svc,
                isDark: _isDark,
              ),
            ],
          )),
        ]),
      ),
    );
  }

  // Header + toggle en una sola barra compacta (~48px)
  Widget _buildTopBar() {
    const acento = Color(0xFF3B82F6);
    return Container(
      color: _surf,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(children: [
        // ── Toggle segmentado ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _segBtn('Resumen',  Icons.dashboard_outlined,     0, acento),
            const SizedBox(width: 2),
            _segBtn('Modelos',  Icons.account_balance_outlined, 1, acento),
          ]),
        ),
        const Spacer(),
        // ── Selector de año ────────────────────────────────────────────────
        Icon(Icons.calendar_today_outlined, size: 13, color: _sub),
        const SizedBox(width: 5),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: _surf),
          child: DropdownButton<int>(
            value: _anio,
            isDense: true,
            style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 13),
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.expand_more_rounded, size: 16, color: _sub),
            items: [2024, 2025, 2026]
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _anio = v!),
          ),
        ),
      ]),
    );
  }

  Widget _segBtn(String label, IconData icon, int idx, Color acento) {
    final sel = _seccion == idx;
    return GestureDetector(
      onTap: () => setState(() => _seccion = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? acento : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: sel ? [const BoxShadow(color: Color(0x283B82F6), blurRadius: 4, offset: Offset(0, 1))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? Colors.white : _sub),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? Colors.white : _sub,
          )),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — RESUMEN FISCAL
// ═════════════════════════════════════════════════════════════════════════════

class ContabTabResumen extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;
  final Color color;
  final bool isDark;
  const ContabTabResumen({required this.empresaId, required this.anio,
      required this.svc, required this.color, this.isDark = false});

  @override
  State<ContabTabResumen> createState() => ContabTabResumenState();
}

class ContabTabResumenState extends State<ContabTabResumen> {
  ResumenContable? _resumenAnual;
  List<ResumenContable> _trimestres = [];
  bool _cargando = true;
  String? _error;
  int _trimestreSeleccionado = 0; // 0 = anual

  bool get _d => widget.isDark;
  Color get _bg   => _d ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get _surf => _d ? const Color(0xFF1E293B) : Colors.white;
  Color get _txt  => _d ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub  => _d ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _bdr  => _d ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(ContabTabResumen old) {
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

    return ColoredBox(
      color: _bg,
      child: ListView(
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
    ));
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
              color: sel ? widget.color : _surf,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? widget.color : _bdr),
              boxShadow: sel ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 6)] : null,
            ),
            child: Text(e.value,
                style: TextStyle(
                    color: sel ? Colors.white : _sub,
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
        color: _surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr),
        boxShadow: _d ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(titulo, style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        Text('${valor.toStringAsFixed(2)}€', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(subtitulo, style: TextStyle(color: _sub, fontSize: 10)),
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
        color: _surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr),
        boxShadow: _d ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _txt)),
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

class ContabTabGastos extends StatelessWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Color color;
  const ContabTabGastos({required this.empresaId, required this.svc,
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

class ContabTabProveedores extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Color color;
  const ContabTabProveedores({required this.empresaId, required this.svc,
      required this.color, super.key});

  @override
  State<ContabTabProveedores> createState() => _ContabTabProveedoresState();
}

class _ContabTabProveedoresState extends State<ContabTabProveedores> {
  String _busqueda = '';
  String _categoriaFiltro = 'Todos';
  bool _isDark = false;

  // Colores adaptativos
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _surf    => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _bdr     => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _txt     => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub     => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _input   => _isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC);
  Color get _chipBg  => _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get _chipBdr => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  static const _categorias = [
    'Todos', 'suministros', 'servicios', 'software', 'alquiler',
    'transporte', 'marketing', 'seguros', 'otros',
  ];

  static const _catColors = {
    'suministros':  Color(0xFF10B981),
    'servicios':    Color(0xFF3B82F6),
    'software':     Color(0xFF8B5CF6),
    'alquiler':     Color(0xFFEAB308),
    'transporte':   Color(0xFF06B6D4),
    'marketing':    Color(0xFFF97316),
    'seguros':      Color(0xFFEC4899),
    'otros':        Color(0xFF6B7280),
  };

  Color _colorCat(String cat) => _catColors[cat.toLowerCase()] ?? const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDark);
    super.dispose();
  }

  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Proveedor>>(
      stream: widget.svc.obtenerProveedores(widget.empresaId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var proveedores = snap.data ?? [];

        // Filtros
        if (_busqueda.isNotEmpty) {
          final q = _busqueda.toLowerCase();
          proveedores = proveedores.where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            (p.nif?.toLowerCase().contains(q) ?? false) ||
            p.categoria.toLowerCase().contains(q)).toList();
        }
        if (_categoriaFiltro != 'Todos') {
          proveedores = proveedores.where((p) => p.categoria == _categoriaFiltro).toList();
        }

        return ColoredBox(
          color: _bg,
          child: Column(children: [
          // ── Barra búsqueda + botón nuevo ───────────────────────────────
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _busqueda = v),
                  style: TextStyle(fontSize: 13, color: _txt),
                  decoration: InputDecoration(
                    hintText: 'Buscar proveedor…',
                    hintStyle: TextStyle(fontSize: 12, color: _sub),
                    prefixIcon: Icon(Icons.search, size: 18, color: _sub),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(icon: Icon(Icons.clear, size: 16, color: _sub), onPressed: () => setState(() => _busqueda = ''))
                        : null,
                    filled: true,
                    fillColor: _input,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _bdr)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _bdr)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.color, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _abrirFormProveedor(context, null),
                icon: const Icon(Icons.add, size: 15, color: Colors.white),
                label: const Text('Nuevo', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
              ),
            ]),
          ),
          // ── Chips de categoría ─────────────────────────────────────────
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categorias.map((cat) {
                  final sel = _categoriaFiltro == cat;
                  final c = cat == 'Todos' ? widget.color : _colorCat(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _categoriaFiltro = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? c : _chipBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? c : _chipBdr),
                        ),
                        child: Text(cat.substring(0, 1).toUpperCase() + cat.substring(1),
                            style: TextStyle(fontSize: 11,
                                color: sel ? Colors.white : _sub,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: _bdr),
          // ── Lista ──────────────────────────────────────────────────────
          Expanded(
            child: proveedores.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.storefront_outlined, size: 64, color: _sub.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Sin proveedores', style: TextStyle(color: _sub, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(_busqueda.isNotEmpty || _categoriaFiltro != 'Todos'
                        ? 'No hay resultados para este filtro'
                        : 'Añade tu primer proveedor',
                        style: TextStyle(color: _sub, fontSize: 12)),
                    if (_busqueda.isEmpty && _categoriaFiltro == 'Todos') ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _abrirFormProveedor(context, null),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Añadir proveedor'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color, foregroundColor: Colors.white),
                      ),
                    ],
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: proveedores.length,
                    itemBuilder: (ctx, i) => _buildCard(context, proveedores[i]),
                  ),
          ),
        ]));
      },
    );
  }

  Widget _buildCard(BuildContext context, Proveedor p) {
    final catColor = _colorCat(p.categoria);
    return GestureDetector(
      onTap: () => _abrirFormProveedor(context, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bdr),
          boxShadow: _isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header con avatar + nombre + acción
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(children: [
              // Avatar con inicial
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withValues(alpha: 0.8), catColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _txt),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.categoria, style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w600)),
                  ),
                  if (p.esIntracomunitario) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('UE', style: TextStyle(fontSize: 9, color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ])),
              IconButton(
                icon: Icon(Icons.receipt_long_outlined, size: 17, color: widget.color),
                tooltip: 'Registrar factura recibida',
                onPressed: () => _registrarFacturaProveedor(context, p),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF94A3B8)),
                onPressed: () => _abrirFormProveedor(context, p),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          // Info row
          if (p.nif != null || p.email != null || p.telefono != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _bdr)),
              ),
              child: Wrap(spacing: 16, runSpacing: 4, children: [
                if (p.nif != null) _infoChip(Icons.badge_outlined, p.nif!),
                if (p.email != null) _infoChip(Icons.email_outlined, p.email!),
                if (p.telefono != null) _infoChip(Icons.phone_outlined, p.telefono!),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: _sub),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 11, color: _sub)),
  ]);

  void _registrarFacturaProveedor(BuildContext context, Proveedor p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FormularioFacturaRecibidaScreen(
            empresaId: widget.empresaId,
            nombreProveedorInicial: p.nombre,
            nifProveedorInicial: p.nif,
          ),
        ),
      ),
    );
  }

  void _abrirFormProveedor(BuildContext context, Proveedor? p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            // Handle + header
            Container(
              color: _surf,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: _isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(p == null ? Icons.add_business_outlined : Icons.edit_outlined, color: widget.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      p == null ? 'Nuevo proveedor' : 'Editar proveedor',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    )),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ]),
            ),
            Expanded(child: _FormProveedorInline(
              empresaId: widget.empresaId,
              svc: widget.svc,
              proveedor: p,
              color: widget.color,
              scrollController: scrollCtrl,
              onGuardado: () => Navigator.pop(ctx),
            )),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — EXPORTAR
// ═════════════════════════════════════════════════════════════════════════════

class ContabTabExportar extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;
  final Color color;
  const ContabTabExportar({required this.empresaId, required this.anio,
      required this.svc, required this.color});

  @override
  State<ContabTabExportar> createState() => ContabTabExportarState();
}

class ContabTabExportarState extends State<ContabTabExportar> {
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
      appBar: FluixAppBar(
        titulo: widget.gasto == null ? 'Nuevo gasto' : 'Editar gasto',
        showLeading: true,
        extraActions: [
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
// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO INLINE DE PROVEEDOR (para usar dentro del popup)
// ─────────────────────────────────────────────────────────────────────────────

class _FormProveedorInline extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;
  final Proveedor? proveedor;
  final Color color;
  final ScrollController scrollController;
  final VoidCallback onGuardado;

  const _FormProveedorInline({
    required this.empresaId, required this.svc, this.proveedor,
    required this.color, required this.scrollController, required this.onGuardado,
  });

  @override
  State<_FormProveedorInline> createState() => _FormProveedorInlineState();
}

class _FormProveedorInlineState extends State<_FormProveedorInline> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _nifCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _telCtrl    = TextEditingController();
  final _dirCtrl    = TextEditingController();
  final _webCtrl    = TextEditingController();
  final _notasCtrl  = TextEditingController();
  String _categoria = 'servicios';
  bool _guardando   = false;

  static const _categorias = [
    ('suministros', Icons.inventory_2_outlined, Color(0xFF10B981)),
    ('servicios',   Icons.build_outlined,       Color(0xFF3B82F6)),
    ('software',    Icons.computer_outlined,    Color(0xFF8B5CF6)),
    ('alquiler',    Icons.home_work_outlined,   Color(0xFFEAB308)),
    ('transporte',  Icons.local_shipping_outlined, Color(0xFF06B6D4)),
    ('marketing',   Icons.campaign_outlined,    Color(0xFFF97316)),
    ('seguros',     Icons.shield_outlined,      Color(0xFFEC4899)),
    ('gestor',      Icons.account_balance_outlined, Color(0xFF6366F1)),
    ('otros',       Icons.more_horiz,           Color(0xFF6B7280)),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.proveedor != null) {
      final p = widget.proveedor!;
      _nombreCtrl.text = p.nombre;
      _nifCtrl.text    = p.nif ?? '';
      _emailCtrl.text  = p.email ?? '';
      _telCtrl.text    = p.telefono ?? '';
      _dirCtrl.text    = p.direccion ?? '';
      _notasCtrl.text  = p.notas ?? '';
      _categoria       = p.categoria;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl,_nifCtrl,_emailCtrl,_telCtrl,_dirCtrl,_webCtrl,_notasCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
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
        activo: true,
        fechaAlta: widget.proveedor?.fechaAlta ?? DateTime.now(),
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );
      await widget.svc.guardarProveedor(widget.empresaId, p);
      if (mounted) {
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.proveedor == null ? '✅ Proveedor creado' : '✅ Proveedor actualizado'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categorias.firstWhere((c) => c.$1 == _categoria, orElse: () => _categorias.last).$3;
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sección datos principales ──────────────────────────────────
          _seccion('Datos del proveedor', child: Column(children: [
            _campo(_nombreCtrl, 'Nombre / Razón social *', Icons.storefront_outlined, obligatorio: true),
            _divider(),
            _campo(_nifCtrl,   'NIF / CIF',  Icons.badge_outlined),
            _divider(),
            _campo(_emailCtrl, 'Email',       Icons.email_outlined, tipo: TextInputType.emailAddress),
            _divider(),
            _campo(_telCtrl,   'Teléfono',    Icons.phone_outlined,  tipo: TextInputType.phone),
            _divider(),
            _campo(_dirCtrl,   'Dirección',   Icons.location_on_outlined),
          ])),
          const SizedBox(height: 14),
          // ── Categoría ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.category_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text('Categoría', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _categorias.map((cat) {
                final sel = _categoria == cat.$1;
                return GestureDetector(
                  onTap: () => setState(() => _categoria = cat.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? cat.$3 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? cat.$3 : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.$2, size: 14, color: sel ? Colors.white : Colors.grey[600]),
                      const SizedBox(width: 5),
                      Text(cat.$1[0].toUpperCase() + cat.$1.substring(1),
                          style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList()),
            ]),
          ),
          const SizedBox(height: 14),
          // ── Notas ──────────────────────────────────────────────────────
          _seccion('Notas', child: TextFormField(
            controller: _notasCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Observaciones, condiciones de pago…',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              border: InputBorder.none,
            ),
          )),
          const SizedBox(height: 20),
          // ── Botón guardar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.proveedor == null ? 'Crear proveedor' : 'Guardar cambios',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          if (widget.proveedor != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await widget.svc.eliminarProveedor(widget.empresaId, widget.proveedor!.id);
                  if (mounted) widget.onGuardado();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Eliminar proveedor'),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, {required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.grey[500], letterSpacing: 1.1)),
      ),
      const Divider(height: 1, color: Color(0xFFE2E8F0)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: child),
    ]),
  );

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {TextInputType tipo = TextInputType.text, bool obligatorio = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      validator: obligatorio ? (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null : null,
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 46);
}

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
      appBar: FluixAppBar(
        titulo: widget.proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor',
        showLeading: true,
        extraActions: [
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











