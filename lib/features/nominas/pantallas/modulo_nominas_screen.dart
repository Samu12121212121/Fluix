import 'package:flutter/material.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/nominas_service.dart';
import 'package:planeag_flutter/features/nominas/pantallas/detalle_nomina_screen.dart';

/// Pantalla principal del módulo de nóminas.
/// Tabs: Este Mes | Historial | Costes | Resumen
class ModuloNominasScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloNominasScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloNominasScreen> createState() => _ModuloNominasScreenState();
}

class _ModuloNominasScreenState extends State<ModuloNominasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final NominasService _svc = NominasService();

  int _mesActual = DateTime.now().month;
  int _anioActual = DateTime.now().year;

  int _mesHist = DateTime.now().month;
  int _anioHist = DateTime.now().year;

  int _anioCostes = DateTime.now().year;

  bool _generando = false;
  String _busquedaEmpleado = '';

  bool get _esPropietario =>
      widget.sesion?.esPropietario ??
      (PermisosService().sesion?.esPropietario ?? false);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── Cabecera ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestión de Nóminas',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Cálculo automático · Normativa española 2026',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tabs ────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF0D47A1),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0D47A1),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Este Mes'),
                Tab(text: 'Historial'),
                Tab(text: 'Costes'),
                Tab(text: 'Resumen'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildTabMesActual(),
                _buildTabHistorial(),
                _buildTabCostes(),
                _buildTabResumen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _esPropietario
          ? FloatingActionButton.extended(
              onPressed: _generando ? null : _generarNominasMes,
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              icon: _generando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generando ? 'Generando...' : 'Generar nóminas'),
            )
          : null,
    ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: ESTE MES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabMesActual() {
    return StreamBuilder<List<Nomina>>(
      stream: _svc.obtenerNominasMes(widget.empresaId, _anioActual, _mesActual),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final nominas = snap.data ?? [];

        if (nominas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No hay nóminas para ${Nomina.nombreMes(_mesActual)} $_anioActual',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Pulsa "Generar nóminas" para crear las del mes',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _mostrarInfoConfiguracion(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('¿Cómo generar nóminas?'),
                ),
              ],
            ),
          );
        }

        final totalNeto  = nominas.fold(0.0, (s, n) => s + n.salarioNeto);
        final totalCoste = nominas.fold(0.0, (s, n) => s + n.costeTotalEmpresa);
        final tienenIrpfAjustado = nominas.any((n) => n.irpfAjustado);

        // Filtrar por búsqueda
        final filtradas = _busquedaEmpleado.isEmpty
            ? nominas
            : nominas.where((n) =>
                n.empleadoNombre.toLowerCase().contains(_busquedaEmpleado.toLowerCase())).toList();

        return Column(
          children: [
            // Chips de resumen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _chipResumen('${nominas.length}', 'Nóminas',
                      Icons.receipt_long, const Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  _chipResumen('€${totalNeto.toStringAsFixed(0)}', 'Neto total',
                      Icons.account_balance_wallet, const Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  _chipResumen('€${totalCoste.toStringAsFixed(0)}', 'Coste emp.',
                      Icons.business, const Color(0xFFF57C00)),
                ],
              ),
            ),
            // Búsqueda + botones de exportar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar empleado...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() => _busquedaEmpleado = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Exportar CSV',
                    icon: const Icon(Icons.table_chart, color: Color(0xFF0D47A1), size: 22),
                    onPressed: () => _svc.exportarCsvMes(context, widget.empresaId, _anioActual, _mesActual),
                  ),
                  IconButton(
                    tooltip: 'Compartir todos los PDFs',
                    icon: const Icon(Icons.share, color: Color(0xFF0D47A1), size: 22),
                    onPressed: () => _svc.compartirNominasMesPdf(context, widget.empresaId, _anioActual, _mesActual),
                  ),
                  if (_esPropietario)
                    IconButton(
                      tooltip: 'Eliminar borradores del mes',
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      onPressed: _eliminarBorradoresMes,
                    ),
                ],
              ),
            ),
            if (tienenIrpfAjustado)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Nóminas del mes',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Info IRPF regularizado',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                              SizedBox(width: 8),
                              Expanded(child: Text('IRPF Regularizado', style: TextStyle(fontSize: 16))),
                            ],
                          ),
                          content: const Text(
                            'Algunas nóminas tienen IRPF recalculado por regularización anual (YTD).\n\n'
                            'Esto significa que el tipo de retención se ha ajustado según los ingresos '
                            'acumulados del trabajador durante el año fiscal, conforme a la normativa vigente.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtradas.length,
                itemBuilder: (_, i) => _TarjetaNomina(
                  nomina: filtradas[i],
                  empresaId: widget.empresaId,
                  esPropietario: _esPropietario,
                  onTap: () => _abrirDetalle(filtradas[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarInfoConfiguracion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Configurar nóminas', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Para generar nóminas, cada empleado debe tener configurados '
          'sus datos salariales desde su perfil → Datos de nómina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: HISTORIAL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabHistorial() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _mesHist--;
                  if (_mesHist < 1) { _mesHist = 12; _anioHist--; }
                }),
              ),
              Expanded(
                child: Text(
                  '${Nomina.nombreMes(_mesHist)} $_anioHist',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _mesHist++;
                  if (_mesHist > 12) { _mesHist = 1; _anioHist++; }
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Nomina>>(
            stream: _svc.obtenerNominasMes(widget.empresaId, _anioHist, _mesHist),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final nominas = snap.data ?? [];
              if (nominas.isEmpty) {
                return Center(
                  child: Text(
                    'Sin nóminas en ${Nomina.nombreMes(_mesHist)} $_anioHist',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: nominas.length,
                itemBuilder: (_, i) => _TarjetaNomina(
                  nomina: nominas[i],
                  empresaId: widget.empresaId,
                  esPropietario: _esPropietario,
                  onTap: () => _abrirDetalle(nominas[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: COSTES (Dashboard por empleado)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCostes() {
    return Column(
      children: [
        // Selector de año
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _anioCostes--),
              ),
              Expanded(
                child: Text(
                  'Costes totales $_anioCostes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _anioCostes++),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _svc.costesAnualesPorEmpleado(widget.empresaId, _anioCostes),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = snap.data!;
              if (lista.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Sin datos para $_anioCostes',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              // Total anual empresa
              final totalAnual = lista.fold(0.0, (s, e) => s + (e['coste_total'] as double));
              final totalNeto  = lista.fold(0.0, (s, e) => s + (e['neto_total'] as double));
              final totalSS    = lista.fold(0.0, (s, e) => s + (e['ss_empresa_total'] as double));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI totales
                    Row(
                      children: [
                        Expanded(child: _kpiCard('Coste Total', '€${_fmt(totalAnual)}', const Color(0xFFF44336))),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Neto Pagado', '€${_fmt(totalNeto)}', const Color(0xFF2E7D32))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _kpiCard('SS Empresa', '€${_fmt(totalSS)}', const Color(0xFFF57C00))),
                        const SizedBox(width: 8),
                        Expanded(child: _kpiCard('Empleados', '${lista.length}', const Color(0xFF1976D2))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Desglose por empleado',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),

                    ...lista.map((e) => _tarjetaCosteEmpleado(e, totalAnual)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tarjetaCosteEmpleado(Map<String, dynamic> e, double totalAnual) {
    final coste = e['coste_total'] as double;
    final neto  = e['neto_total'] as double;
    final ss    = e['ss_empresa_total'] as double;
    final pct   = totalAnual > 0 ? coste / totalAnual : 0.0;
    final nombre = e['nombre'] as String? ?? '—';
    final meses  = e['num_nominas'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_iniciales(nombre),
                        style: const TextStyle(color: Color(0xFF0D47A1),
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('$meses nóminas · ${(pct * 100).toStringAsFixed(1)}% del total',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('€${_fmt(coste)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFFF44336))),
                    Text('coste total', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Barra de progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF0D47A1),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat('Neto', '€${_fmt(neto)}', const Color(0xFF2E7D32)),
                _miniStat('SS Empresa', '€${_fmt(ss)}', const Color(0xFFF57C00)),
                _miniStat('IRPF', '€${_fmt(e['irpf_total'] as double)}',
                    const Color(0xFF7B1FA2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String valor, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB: RESUMEN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabResumen() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _svc.resumenMes(widget.empresaId, _anioActual, _mesActual),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen — ${Nomina.nombreMes(_mesActual)} $_anioActual',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _kpiCard('Total Bruto', '€${(r['total_bruto'] as double).toStringAsFixed(0)}', const Color(0xFF1976D2))),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Total Neto', '€${(r['total_neto'] as double).toStringAsFixed(0)}', const Color(0xFF2E7D32))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _kpiCard('SS Empresa', '€${(r['total_ss_empresa'] as double).toStringAsFixed(0)}', const Color(0xFFF57C00))),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Coste Total', '€${(r['coste_total'] as double).toStringAsFixed(0)}', const Color(0xFFF44336))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _kpiCard('IRPF Retenido', '€${(r['total_irpf'] as double).toStringAsFixed(0)}', const Color(0xFF7B1FA2))),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('SS Trabajador', '€${(r['total_ss_trabajador'] as double).toStringAsFixed(0)}', const Color(0xFF0097A7))),
                ],
              ),
              const SizedBox(height: 20),

              // Estados
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estado de nóminas',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      _estadoRow('Borradores', r['pendientes'] ?? 0, Colors.orange),
                      _estadoRow('Aprobadas', r['aprobadas'] ?? 0, const Color(0xFF1976D2)),
                      _estadoRow('Pagadas', r['pagadas'] ?? 0, const Color(0xFF2E7D32)),
                      if ((r['irpf_ajustados'] ?? 0) > 0)
                        _estadoRow('IRPF regularizado', r['irpf_ajustados'] ?? 0,
                            const Color(0xFF7B1FA2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if ((r['pendientes'] ?? 0) > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tienes ${r['pendientes']} nóminas en borrador pendientes de aprobar.',
                          style: const TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Alertas de cumplimiento
              FutureBuilder<List<Map<String, String>>>(
                future: _svc.alertasCumplimiento(
                    widget.empresaId, _anioActual, _mesActual),
                builder: (ctx, snapA) {
                  if (!snapA.hasData || snapA.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alertas de cumplimiento',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...snapA.data!.map((a) => _alertaRow(a)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Info normativa
              Card(
                elevation: 0,
                color: const Color(0xFFF5F5F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ℹ️ Cálculos según normativa española 2026',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 6),
                      Text(
                        '• SS Trabajador: CC 4,70% + Desempleo 1,55% + FP 0,10% + MEI 0,12%\n'
                        '• SS Empresa: CC 23,60% + Desempleo 5,50% + FOGASA 0,20% + FP 0,60% + AT ~1,50% + MEI 0,58%\n'
                        '• IRPF: tramos progresivos (19% a 47%) con mínimo personal y familiar\n'
                        '• IRPF incluye reducción por rendimientos del trabajo (hasta 7.302€)\n'
                        '• IRPF se regulariza mensualmente según ingresos acumulados (YTD)\n'
                        '• Base cotización: mín. 1.260€ — máx. 4.720,50€/mes\n'
                        '• Jornada parcial: salario prorrateado según horas/40h',
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _alertaRow(Map<String, String> alerta) {
    final tipo = alerta['tipo'] ?? 'info';
    final Color color;
    final IconData icono;
    switch (tipo) {
      case 'danger':
        color = Colors.red; icono = Icons.error_outline; break;
      case 'warning':
        color = Colors.orange; icono = Icons.warning_amber; break;
      default:
        color = const Color(0xFF1976D2); icono = Icons.info_outline;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(alerta['mensaje'] ?? '',
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _generarNominasMes() async {
    setState(() => _generando = true);
    try {
      final n = await _svc.generarNominasMasivas(
          widget.empresaId, _mesActual, _anioActual);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $n nóminas generadas para ${Nomina.nombreMes(_mesActual)}'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _eliminarBorradoresMes() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar borradores'),
        content: Text(
          'Se eliminarán todas las nóminas en borrador de '
          '${Nomina.nombreMes(_mesActual)} $_anioActual.\n\n'
          'Las nóminas aprobadas o pagadas no se verán afectadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      final snap = await _svc.obtenerNominasMes(
              widget.empresaId, _anioActual, _mesActual)
          .first;
      int eliminadas = 0;
      for (final n in snap) {
        if (n.estado == EstadoNomina.borrador) {
          await _svc.eliminarNomina(widget.empresaId, n.id);
          eliminadas++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ $eliminadas borrador(es) eliminado(s)'),
            backgroundColor: const Color(0xFF0D47A1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirDetalle(Nomina nomina) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetalleNominaScreen(
        nomina: nomina,
        empresaId: widget.empresaId,
        esPropietario: _esPropietario,
      ),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _chipResumen(String valor, String label, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String titulo, String valor, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.08), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _estadoRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text('$count',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _iniciales(String nombre) {
    final p = nombre.split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';
  }

  String _fmt(double v) => v >= 10000
      ? '${(v / 1000).toStringAsFixed(1)}k'
      : v.toStringAsFixed(0);
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA NÓMINA
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaNomina extends StatelessWidget {
  final Nomina nomina;
  final String empresaId;
  final bool esPropietario;
  final VoidCallback onTap;

  const _TarjetaNomina({
    required this.nomina,
    required this.empresaId,
    required this.esPropietario,
    required this.onTap,
  });

  Color get _colorEstado {
    switch (nomina.estado) {
      case EstadoNomina.borrador: return Colors.orange;
      case EstadoNomina.aprobada: return const Color(0xFF1976D2);
      case EstadoNomina.pagada:   return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _iniciales(nomina.empleadoNombre),
                    style: TextStyle(color: _colorEstado,
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(nomina.empleadoNombre,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (nomina.irpfAjustado) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('IRPF reg.',
                                style: TextStyle(fontSize: 9, color: Color(0xFF7B1FA2),
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Neto: €${nomina.salarioNeto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500)),
                    Text('Coste empresa: €${nomina.costeTotalEmpresa.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(nomina.estado.etiqueta,
                    style: TextStyle(color: _colorEstado, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';
  }
}




