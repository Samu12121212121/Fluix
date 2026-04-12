import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../services/contabilidad_service.dart';
import '../../../services/mod_303_service.dart';
import '../../../services/facturacion_service.dart';
import '../../../domain/modelos/empresa.dart';
import '../../../domain/modelos/contabilidad.dart';
import '../../fiscal/pantallas/modelo111_screen.dart';
import '../../fiscal/pantallas/modelo190_screen.dart';
import '../../fiscal/pantallas/modelo115_screen.dart';
import '../../fiscal/pantallas/modelo130_screen.dart';
import '../../fiscal/pantallas/modelo202_screen.dart';
import '../../fiscal/pantallas/modelo390_screen.dart';
import 'package:planeag_flutter/features/fiscal/pantallas/modelo303_screen.dart';
import '../../../widgets/calendario_fiscal_widget.dart';
import 'pantalla_configuracion_fiscal_empresa.dart';
import 'tab_mod_347.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MODELOS FISCALES — 303 (IVA) y 130 (IRPF)
// ═════════════════════════════════════════════════════════════════════════════

class TabModelosFiscales extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;

  const TabModelosFiscales({
    super.key,
    required this.empresaId,
    required this.anio,
    required this.svc,
  });

  @override
  State<TabModelosFiscales> createState() => _TabModelosFiscalesState();
}

class _TabModelosFiscalesState extends State<TabModelosFiscales> {
  List<ModeloFiscalTrimestral>? _modelos;
  bool _cargando = true;
  int _tabModelo = 0; // 0 = 303 IVA, 1 = 130 IRPF
  final FacturacionService _facturacionService = FacturacionService();
  CriterioIVA _criterioIva = CriterioIVA.devengo;
  bool _guardandoCriterio = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarCriterioIva();
  }

  @override
  void didUpdateWidget(TabModelosFiscales old) {
    super.didUpdateWidget(old);
    if (old.anio != widget.anio || old.empresaId != widget.empresaId) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final modelos = await widget.svc.calcularModelosFiscales(
          widget.empresaId, widget.anio);
      if (mounted) setState(() {
        _modelos = modelos;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarCriterioIva() async {
    try {
      final criterio =
          await _facturacionService.obtenerCriterioIVA(widget.empresaId);
      if (mounted) setState(() => _criterioIva = criterio);
    } catch (_) {}
  }

  Future<void> _guardarCriterioIva(CriterioIVA nuevo) async {
    setState(() => _guardandoCriterio = true);
    try {
      await _facturacionService.guardarCriterioIVA(widget.empresaId, nuevo);
      if (mounted) {
        setState(() => _criterioIva = nuevo);
        await _cargar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Criterio fiscal actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error guardando criterio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoCriterio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;

    if (_cargando) return const Center(child: CircularProgressIndicator());

    final modelos = _modelos ?? [];
    final alertas = modelos
        .where((m) => m.estadoAlerta != EstadoAlertaFiscal.ok)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Banner de alertas ─────────────────────────────────────────────
        if (alertas.isNotEmpty) ...[
          _buildBannerAlertas(alertas, color),
          const SizedBox(height: 12),
        ],

        if (!empresaConfig.tieneNifConfigurado || !empresaConfig.tieneNifValido) ...[
          _buildBannerNifFaltante(color),
          const SizedBox(height: 12),
        ],

        // ── Selector de modelo ────────────────────────────────────────────
        _buildSelectorModelo(color),
        const SizedBox(height: 12),

        // ── Si es Modelo 111, navegar a su pantalla dedicada ─────────────
        if (_tabModelo == 2) ...[
          _buildBotonModelo111(color),
        ] else if (_tabModelo == 3) ...[
          _buildBotonModelo190(color),
        ] else if (_tabModelo == 4) ...[
          _buildBotonModelo115(color),
        ] else if (_tabModelo == 5) ...[
          _buildBotonModelo390(color),
        ] else if (_tabModelo == 6) ...[
          _buildBotonModelo347(color),
        ] else if (_tabModelo == 1 && empresaConfig.esSociedad) ...[
          _buildBotonModelo202(color),
        ] else ...[

        // ── Configuración fiscal: criterio IVA ────────────────────────────
        _buildSelectorCriterioIva(color),
        const SizedBox(height: 16),

        // ── Info del modelo ───────────────────────────────────────────────
        _buildInfoModelo(color),
        const SizedBox(height: 16),

        // ── Cards por trimestre ───────────────────────────────────────────
        ...modelos.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _tabModelo == 0
              ? _buildCard303(m, color)
              : _buildCard130(m, color),
        )),

        // ── Acceso a pantalla completa del Modelo 303 ─────────────────────
        if (_tabModelo == 0) ...[
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.open_in_new, color: color),
              title: const Text('Abrir Modelo 303 completo'),
              subtitle: const Text('Exportación AEAT DR303e26v101, marcado como presentado, etc.'),
              trailing: Icon(Icons.chevron_right, color: color),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo303Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Acceso a pantalla completa del Modelo 130 ─────────────────────
        if (_tabModelo == 1 && !empresaConfig.esSociedad) ...[
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.open_in_new, color: color),
              title: const Text('Abrir Modelo 130 completo'),
              subtitle: const Text('Cálculo completo, casillas oficiales, PDF borrador, presentar AEAT'),
              trailing: Icon(Icons.chevron_right, color: color),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo130Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Calendario fiscal anual ───────────────────────────────────────
        const SizedBox(height: 4),
        _buildCalendarioFiscal(color),
        const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildBannerAlertas(
      List<ModeloFiscalTrimestral> alertas, Color color) {
    final vencidos = alertas
        .where((a) => a.estadoAlerta == EstadoAlertaFiscal.vencido)
        .length;
    final proximos = alertas
        .where((a) => a.estadoAlerta == EstadoAlertaFiscal.proximo)
        .length;

    final color2 = vencidos > 0 ? Colors.red : Colors.orange;
    final texto = vencidos > 0
        ? '⚠️ $vencidos modelo${vencidos > 1 ? 's' : ''} vencido${vencidos > 1 ? 's' : ''} sin presentar'
        : '📅 $proximos modelo${proximos > 1 ? 's' : ''} con vencimiento próximo (< 15 días)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color2.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(vencidos > 0 ? Icons.error_outline : Icons.timer_outlined,
              color: color2, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                  color: color2,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerNifFaltante(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configura el NIF de tu empresa antes de generar modelos fiscales',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _abrirConfiguracionFiscal,
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Ir a configuración fiscal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorModelo(Color color) {
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;
    final esSociedad = empresaConfig.esSociedad;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabChip('303\nIVA', 0, color),
          const SizedBox(width: 6),
          // Mostrar 130 (IRPF autónomos) o 202 (IS sociedades) según forma jurídica
          if (esSociedad)
            _tabChip('202\nIS', 1, color)
          else
            _tabChip('130\nIRPF', 1, color),
          const SizedBox(width: 6),
          _tabChip('111\nRetenc.', 2, color),
          const SizedBox(width: 6),
          _tabChip('190\nResumen', 3, color),
          const SizedBox(width: 6),
          _tabChip('115\nAlquiler', 4, color),
          const SizedBox(width: 6),
          _tabChip('390\nIVA anual', 5, color),
          const SizedBox(width: 6),
          _tabChip('347\nTerceros', 6, color),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index, Color color) {
    final sel = _tabModelo == index;
    return GestureDetector(
      onTap: () => setState(() => _tabModelo = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: sel ? color : Colors.grey.withValues(alpha: 0.3)),
          boxShadow: sel
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sel ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildBotonModelo111(Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 111 — Retenciones e ingresos a cuenta IRPF',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Art. 101 LIRPF · Declaración trimestral de retenciones IRPF '
              'practicadas a empleados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo111Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 111'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonModelo190(Color color) {
    final plazo = DateTime(widget.anio + 1, 1, 31);
    final dias = plazo.difference(DateTime.now()).inDays;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.assignment, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 190 — Resumen anual retenciones IRPF',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Declaración informativa anual complementaria del 111.\n'
              'Plazo: del 1 al 31 de enero de ${widget.anio + 1}'
              '${dias >= 0 && dias <= 30 ? ' ($dias días)' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo190Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 190'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonModelo115(Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.home_work, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 115 — Retenciones arrendamientos',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Art. 101.6 LIRPF · Retención del 19% sobre arrendamientos '
              'de locales de negocio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo115Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 115'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonModelo390(Color color) {
    final plazo = DateTime(widget.anio + 1, 1, 30);
    final dias = plazo.difference(DateTime.now()).inDays;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.summarize, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 390 — Resumen Anual IVA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Consolida los 4 Mod.303 del ejercicio.\n'
              'Plazo: del 1 al 30 de enero de ${widget.anio + 1}'
              '${dias >= 0 && dias <= 30 ? ' ($dias días)' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo390Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 390'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorCriterioIva(Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: color, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Configuración fiscal: criterio IVA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              if (_guardandoCriterio)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<CriterioIVA>(
            segments: const [
              ButtonSegment(
                value: CriterioIVA.devengo,
                label: Text('Devengo'),
                icon: Icon(Icons.calendar_today, size: 14),
              ),
              ButtonSegment(
                value: CriterioIVA.caja,
                label: Text('Caja (RECC)'),
                icon: Icon(Icons.payments_outlined, size: 14),
              ),
            ],
            selected: {_criterioIva},
            onSelectionChanged: _guardandoCriterio
                ? null
                : (sel) => _guardarCriterioIva(sel.first),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'El criterio de caja solo es aplicable si tu empresa está '
              'acogida al RECC. Consulta con tu gestor antes de activarlo.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoModelo(Color color) {
    final texto303 =
        'Declaración trimestral del IVA. La diferencia entre el IVA de las '
        'ventas (repercutido) y el de las compras (soportado) determina si '
        'debes ingresar o te devuelven.';
    final texto130 =
        'Pago fraccionado del IRPF para autónomos en estimación directa. '
        'Se calcula el 20% del beneficio neto acumulado menos los pagos anteriores.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tabModelo == 0 ? texto303 : texto130,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard303(ModeloFiscalTrimestral m, Color color) {
    final alerta = m.estadoAlerta;
    final colorAlerta = _colorAlerta(alerta);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: alerta != EstadoAlertaFiscal.ok
            ? Border.all(color: colorAlerta.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera trimestre
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.nombreTrimestre,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.periodoTexto,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 12),
                ),
              ),
              _badgeAlerta(alerta, m.fechaLimiteTexto),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // IVA repercutido
            _filaModelo(
              '+ IVA repercutido (ventas)',
              m.ivaRepercutido,
              Colors.green,
            ),
            // IVA soportado
            _filaModelo(
              '– IVA soportado (gastos deducibles)',
              m.ivaSoportado,
              Colors.red,
            ),
            const Divider(height: 16),
            // Resultado
            _filaModelo(
              m.hayDevolucionIva
                  ? '✅ Hacienda te devuelve'
                  : '⚠️ A ingresar en Hacienda',
              m.resultadoIva.abs(),
              m.hayDevolucionIva ? Colors.green : Colors.deepOrange,
              negrita: true,
              grande: true,
            ),
            const SizedBox(height: 10),

            // Pie: fecha límite + botón descarga
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorAlerta.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.calendar_today,
                              size: 13, color: colorAlerta),
                          const SizedBox(width: 6),
                          Text(
                            'Fecha límite: ${m.fechaLimiteTexto}',
                            style: TextStyle(
                                fontSize: 11,
                                color: colorAlerta,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            _textoAlerta(alerta),
                            style: TextStyle(
                                fontSize: 10,
                                color: colorAlerta,
                                fontWeight: FontWeight.bold),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                onPressed: () => _descargarMod303(m.trimestre),
                tooltip: 'Descargar MOD 303',
                  style: IconButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.1),
                    foregroundColor: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard130(ModeloFiscalTrimestral m, Color color) {
    final alerta = m.estadoAlerta;
    final colorAlerta = _colorAlerta(alerta);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: alerta != EstadoAlertaFiscal.ok
            ? Border.all(color: colorAlerta.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.nombreTrimestre,
                  style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.periodoTexto,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              _badgeAlerta(alerta, m.fechaLimiteTexto),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            if (!m.hayBeneficio) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sin beneficio este trimestre. No hay pago fraccionado.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
            ] else ...[
              _filaModelo('Rendimiento neto (beneficio)',
                  m.beneficioNeto, Colors.green),
              _filaModelo('× 20% retención estimada',
                  m.pagoFraccionadoIrpf, Colors.orange),
              const Divider(height: 16),
              _filaModelo(
                '⚠️ A ingresar (estimado)',
                m.pagoFraccionadoIrpf,
                Colors.purple,
                negrita: true,
                grande: true,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠ Dato orientativo. Tu gestor calculará el importe exacto '
                  'aplicando deducciones y retenciones previas acumuladas.',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
            ],
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorAlerta.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today,
                    size: 13, color: colorAlerta),
                const SizedBox(width: 6),
                Text(
                  'Fecha límite: ${m.fechaLimiteTexto}',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorAlerta,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _textoAlerta(alerta),
                  style: TextStyle(
                      fontSize: 10,
                      color: colorAlerta,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarioFiscal(Color color) {
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;
    return CalendarioFiscalWidget(
      empresaId: widget.empresaId,
      formaJuridica: empresaConfig.formaJuridica,
      ejercicio: widget.anio,
    );
  }

  Widget _filaModelo(String label, double valor, Color color,
      {bool negrita = false, bool grande = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: grande ? 13 : 12,
              fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '${valor.toStringAsFixed(2)}€',
          style: TextStyle(
            fontSize: grande ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ]),
    );
  }

  Widget _badgeAlerta(EstadoAlertaFiscal alerta, String fechaTexto) {
    if (alerta == EstadoAlertaFiscal.ok) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('OK',
            style: TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.bold)),
      );
    }

    final colorAlerta = _colorAlerta(alerta);
    final icono = alerta == EstadoAlertaFiscal.vencido
        ? Icons.error
        : Icons.timer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorAlerta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: colorAlerta),
          const SizedBox(width: 3),
          Text(
            alerta == EstadoAlertaFiscal.vencido ? 'VENCIDO' : '< 15 días',
            style: TextStyle(
                fontSize: 10,
                color: colorAlerta,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _colorAlerta(EstadoAlertaFiscal alerta) {
    switch (alerta) {
      case EstadoAlertaFiscal.ok:
        return Colors.green;
      case EstadoAlertaFiscal.proximo:
        return Colors.orange;
      case EstadoAlertaFiscal.vencido:
        return Colors.red;
    }
  }

  /// Descarga MOD 303 para un trimestre
  Future<void> _descargarMod303(int trimestre) async {
    try {
      final empresaConfig = context.read<EmpresaConfigProvider>().config;
      if (!empresaConfig.tieneNifValido) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configura un NIF válido antes de generar el MOD 303'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final mod303Service = Mod303Service();

      // Generar fichero MOD 303
      final contenido = await mod303Service.generarMod303Descargable(
        empresaId: widget.empresaId,
        nifEmpresa: empresaConfig.nifNormalizado,
        anio: widget.anio,
        trimestre: trimestre,
      );

      // Guardar en archivo
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se puede acceder a descargas')),
          );
        }
        return;
      }

      final archivo = File(
        '${directory.path}/MOD303_${widget.anio}_T$trimestre.txt'
      );
      await archivo.writeAsString(contenido);

      // Compartir
      if (mounted) {
        await Share.shareXFiles(
          [XFile(archivo.path)],
          subject: 'MOD 303 - Trimestre $trimestre ${widget.anio}',
          text: 'Fichero MOD 303 para importar en Sede Electrónica de la AEAT',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ MOD 303 descargado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirConfiguracionFiscal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<EmpresaConfigProvider>(),
          child: const PantallaConfiguracionFiscalEmpresa(),
        ),
      ),
    );
    await _cargarCriterioIva();
    await _cargar();
  }

  String _textoAlerta(EstadoAlertaFiscal alerta) {
    switch (alerta) {
      case EstadoAlertaFiscal.ok:
        return 'Pendiente';
      case EstadoAlertaFiscal.proximo:
        return 'Próximo vencimiento';
      case EstadoAlertaFiscal.vencido:
        return 'Plazo vencido';
    }
  }

  Widget _buildBotonModelo202(Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.account_balance, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 202 — Pago fraccionado IS (Sociedades)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Art. 40.2 LIS · Pago a cuenta del Impuesto de Sociedades.\n'
              'Períodos: abril (1P), octubre (2P), diciembre (3P)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Modelo202Screen(
                    empresaId: widget.empresaId,
                    anioInicial: widget.anio,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 202'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonModelo347(Color color) {
    final plazo = DateTime(widget.anio + 1, 2, 28);
    final dias = plazo.difference(DateTime.now()).inDays;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.people_alt, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Modelo 347 — Operaciones con terceros',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Art. 33 RD 1065/2007 · Declaración anual de operaciones >3.005,06€.\n'
              'Plazo: hasta el 28 de febrero de ${widget.anio + 1}'
              '${dias >= 0 && dias <= 60 ? ' ($dias días)' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final appConfig = context.read<AppConfigProvider>();
                final empresaConfigProvider = context.read<EmpresaConfigProvider>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider.value(value: appConfig),
                        ChangeNotifierProvider.value(value: empresaConfigProvider),
                      ],
                      child: Scaffold(
                        appBar: AppBar(
                          title: const Text('Modelo 347 — Operaciones con terceros'),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 1,
                        ),
                        body: TabMod347(
                          empresaId: widget.empresaId,
                          anio: widget.anio,
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Modelo 347'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODELO AUXILIAR PARA EVENTO FISCAL
// ═════════════════════════════════════════════════════════════════════════════

class _EventoFiscal {
  final String fecha;
  final String modelo;
  final Color color;
  final IconData icono;

  const _EventoFiscal(this.fecha, this.modelo, this.color, this.icono);
}


