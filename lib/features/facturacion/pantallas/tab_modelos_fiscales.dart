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
import '../../../services/fiscal/sede_aeat_urls.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../domain/modelos/empresa.dart';
import '../../../domain/modelos/contabilidad.dart';
import '../../fiscal/pantallas/modelo111_screen.dart';
import '../../fiscal/pantallas/modelo190_screen.dart';
import '../../fiscal/pantallas/modelo115_screen.dart';
import '../../fiscal/pantallas/modelo202_screen.dart';
import '../../fiscal/pantallas/modelo390_screen.dart';
import '../../../widgets/calendario_fiscal_widget.dart';
import '../../perfil/pantallas/pantalla_perfil.dart';
import 'tab_mod_347.dart';
import 'tab_mod_349.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MODELOS FISCALES — 303 (IVA) y 130 (IRPF)
// ═════════════════════════════════════════════════════════════════════════════

class TabModelosFiscales extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;
  final bool isDark;

  const TabModelosFiscales({
    super.key,
    required this.empresaId,
    required this.anio,
    required this.svc,
    this.isDark = false,
  });

  @override
  State<TabModelosFiscales> createState() => _TabModelosFiscalesState();
}

class _TabModelosFiscalesState extends State<TabModelosFiscales> {
  List<ModeloFiscalTrimestral>? _modelos;
  bool _cargando = true;
  int _tabModelo = 0; // 0 = 303 IVA, 1 = 130 IRPF
  int _periodoSel = 0; // trimestre seleccionado (0-3) en el period grid
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

  static const _kDesktopBreakpoint = 720.0;

  static const _kModels = [
    _ModeloInfo('303', 'IVA trimestral',     Icons.receipt_long_rounded,  Color(0xFF3B82F6), 0),
    _ModeloInfo('130', 'IRPF fraccionado',   Icons.percent_rounded,        Color(0xFF8B5CF6), 1),
    _ModeloInfo('111', 'Retenciones IRPF',   Icons.people_outlined,        Color(0xFF10B981), 2),
    _ModeloInfo('115', 'Alquiler',           Icons.home_work_outlined,     Color(0xFFEAB308), 4),
    _ModeloInfo('190', 'Resumen anual',      Icons.summarize_rounded,      Color(0xFF10B981), 3, periodico: false),
    _ModeloInfo('390', 'IVA anual',          Icons.receipt_long_rounded,   Color(0xFF3B82F6), 5, periodico: false),
    _ModeloInfo('347', 'Terceros',           Icons.handshake_outlined,     Color(0xFFF97316), 6, periodico: false),
    _ModeloInfo('349', 'Intracomunitario',   Icons.language_outlined,      Color(0xFF06B6D4), 7, periodico: false),
  ];

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    final empresaConfig = context.watch<EmpresaConfigProvider>().config;
    final esSociedad = empresaConfig.esSociedad;
    final modelos = _modelos ?? [];
    final alertas = modelos.where((m) => m.estadoAlerta != EstadoAlertaFiscal.ok).toList();
    final tieneNifOk = empresaConfig.tieneNifConfigurado && empresaConfig.tieneNifValido;
    final isWide = MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

    return isWide
        ? _buildDesktopLayout(color, modelos, esSociedad, tieneNifOk, alertas)
        : _buildMobileLayout(color, modelos, esSociedad, tieneNifOk, alertas);
  }

  // ── DESKTOP: sidebar izquierda + contenido derecha ────────────────────────
  Widget _buildDesktopLayout(Color color, List<ModeloFiscalTrimestral> modelos,
      bool esSociedad, bool tieneNifOk, List<ModeloFiscalTrimestral> alertas) {
    final bg    = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final surf  = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final divClr = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(children: [
      _buildCompactHeader(color, tieneNifOk, alertas, surf, divClr),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Sidebar ───────────────────────────────────────────────────────
        Container(
          width: 172,
          color: surf,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _sidebarGroup('Periódicos', _kModels.where((m) => m.periodico).toList(), modelos, divClr),
              const SizedBox(height: 4),
              _sidebarGroup('Anuales', _kModels.where((m) => !m.periodico).toList(), modelos, divClr),
            ],
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: divClr),
        // ── Contenido ────────────────────────────────────────────────────
        Expanded(child: ColoredBox(
          color: bg,
          child: _buildContenidoModelo(color, modelos, esSociedad),
        )),
      ])),
    ]);
  }

  // ── MÓVIL: header compacto + chips pill + contenido ───────────────────────
  Widget _buildMobileLayout(Color color, List<ModeloFiscalTrimestral> modelos,
      bool esSociedad, bool tieneNifOk, List<ModeloFiscalTrimestral> alertas) {
    final surf   = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final divClr = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg     = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Column(children: [
      _buildCompactHeader(color, tieneNifOk, alertas, surf, divClr),
      _buildSelectorTabs(color, surf, divClr),
      Expanded(child: ColoredBox(
        color: bg,
        child: _buildContenidoModelo(color, modelos, esSociedad),
      )),
    ]);
  }

  // ── Sidebar: grupo con cabecera + items con status dot ───────────────────
  Widget _sidebarGroup(String title, List<_ModeloInfo> items,
      List<ModeloFiscalTrimestral> modelos, Color divClr) {
    final isDark = widget.isDark;
    final subClr = isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: subClr, letterSpacing: 0.6)),
      ),
      ...items.map((m) {
        final sel = _tabModelo == m.idx;
        // Status dot basado en alertas del modelo
        final alertaModel = modelos
            .where((mod) => mod.trimestre >= 1)
            .fold<EstadoAlertaFiscal>(EstadoAlertaFiscal.ok, (prev, mod) {
          if (mod.estadoAlerta == EstadoAlertaFiscal.vencido) return EstadoAlertaFiscal.vencido;
          if (prev == EstadoAlertaFiscal.vencido) return prev;
          return mod.estadoAlerta;
        });
        final dotColor = (m.idx == 0 || m.idx == 1 || m.idx == 2 || m.idx == 4)
            ? _dotColor(alertaModel)
            : const Color(0xFFF59E0B); // anuales: siempre amber (pendiente)
        return InkWell(
          onTap: () => setState(() { _tabModelo = m.idx; _periodoSel = 0; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? m.color.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent,
              border: Border(left: BorderSide(
                  color: sel ? m.color : Colors.transparent, width: 2.5)),
            ),
            child: Row(children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Icon(m.icon, size: 15,
                  color: sel ? m.color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MOD. ${m.num}', style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2,
                  color: sel ? m.color : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A)),
                )),
                Text(m.label, style: TextStyle(
                  fontSize: 9, color: sel ? m.color.withValues(alpha: 0.75)
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
                )),
              ])),
            ]),
          ),
        );
      }),
    ]);
  }

  Color _dotColor(EstadoAlertaFiscal a) => switch (a) {
    EstadoAlertaFiscal.ok      => const Color(0xFF22C55E),
    EstadoAlertaFiscal.proximo => const Color(0xFFF59E0B),
    EstadoAlertaFiscal.vencido => const Color(0xFFEF4444),
  };

  // ── Header compacto (una sola fila, ~52px) ────────────────────────────────
  Widget _buildCompactHeader(Color color, bool tieneNifOk,
      List<ModeloFiscalTrimestral> alertas, Color surf, Color divClr) {
    final txtClr = widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subClr = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      color: surf,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.account_balance_rounded, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Modelos fiscales', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: txtClr)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${widget.anio}', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
            const Spacer(),
            IconButton(
              onPressed: _cargar,
              icon: Icon(Icons.refresh_rounded, size: 17, color: subClr),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'Actualizar',
            ),
            const SizedBox(width: 2),
            OutlinedButton.icon(
              onPressed: _abrirConfiguracionFiscal,
              icon: const Icon(Icons.settings_outlined, size: 12),
              label: const Text('Fiscal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        if (alertas.isNotEmpty || !tieneNifOk) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(children: [
              if (alertas.isNotEmpty) _buildBannerAlertas(alertas, color),
              if (!tieneNifOk) ...[
                if (alertas.isNotEmpty) const SizedBox(height: 6),
                _buildBannerNifFaltante(color),
              ],
            ]),
          ),
        ],
        Divider(height: 1, thickness: 1, color: divClr),
      ]),
    );
  }

  // ── Tabs compactos para móvil (40px, pills) ───────────────────────────────
  Widget _buildSelectorTabs(Color color, Color surf, Color divClr) {
    final isDark = widget.isDark;
    final inactiveBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final inactiveTxt = isDark ? const Color(0xFF94A3B8) : const Color(0xFF374151);

    return Container(
      color: surf,
      child: Column(children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _kModels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final m = _kModels[i];
              final sel = _tabModelo == m.idx;
              return GestureDetector(
                onTap: () => setState(() => _tabModelo = m.idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? m.color : inactiveBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? m.color : divClr,
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel ? [BoxShadow(
                      color: m.color.withValues(alpha: 0.3),
                      blurRadius: 6, offset: const Offset(0, 2),
                    )] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(m.icon, size: 12, color: sel ? Colors.white : m.color),
                    const SizedBox(width: 5),
                    Text(m.num, style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : inactiveTxt,
                    )),
                  ]),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: divClr),
      ]),
    );
  }

  Widget _buildContenidoModelo(Color color, List<ModeloFiscalTrimestral> modelos, bool esSociedad) {
    if (_tabModelo == 2) {
      return Modelo111Screen(key: ValueKey('111_${widget.anio}'), empresaId: widget.empresaId, anioInicial: widget.anio, embebido: true);
    } else if (_tabModelo == 3) {
      return Modelo190Screen(key: ValueKey('190_${widget.anio}'), empresaId: widget.empresaId, anioInicial: widget.anio, embebido: true);
    } else if (_tabModelo == 4) {
      return Modelo115Screen(key: ValueKey('115_${widget.anio}'), empresaId: widget.empresaId, anioInicial: widget.anio, embebido: true);
    } else if (_tabModelo == 5) {
      return Modelo390Screen(key: ValueKey('390_${widget.anio}'), empresaId: widget.empresaId, anioInicial: widget.anio, embebido: true);
    } else if (_tabModelo == 6) {
      return TabMod347(empresaId: widget.empresaId, anio: widget.anio);
    } else if (_tabModelo == 7) {
      return TabMod349Wrapper(empresaId: widget.empresaId, anio: widget.anio);
    } else if (_tabModelo == 1 && esSociedad) {
      return Modelo202Screen(key: ValueKey('202_${widget.anio}'), empresaId: widget.empresaId, anioInicial: widget.anio, embebido: true);
    }
    if (_cargando) return Center(child: CircularProgressIndicator(color: color));
    return _build303o130(color, modelos);
  }

  Widget _build303o130(Color color, List<ModeloFiscalTrimestral> modelos) {
    final isDark = widget.isDark;
    final surf  = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg    = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final bdr   = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txt   = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub   = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final is303 = _tabModelo == 0;

    // Datos agregados para stats strip
    final totalRes  = is303
        ? modelos.fold(0.0, (s, m) => s + m.resultadoIva)
        : modelos.fold(0.0, (s, m) => s + m.pagoFraccionadoIrpf);
    final isNegativo = totalRes < 0;

    final periodoActual = _periodoSel < modelos.length ? modelos[_periodoSel] : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: [
        // ── Cabecera con criterio IVA (solo 303) ────────────────────────
        if (is303) ...[_buildSelectorCriterioIva(color), const SizedBox(height: 12)],

        // ── Stats strip ─────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bdr),
          ),
          child: IntrinsicHeight(child: Row(children: [
            _statPill(Icons.euro_rounded,
                is303 ? 'Resultado del año' : 'Total pagos fraccionados',
                '${totalRes.abs().toStringAsFixed(2)} €',
                isNegativo ? const Color(0xFF10B981) : const Color(0xFFEF4444), isDark),
            _vDivider(bdr),
            _statPill(Icons.check_circle_outline_rounded, 'Presentados',
                '0 / ${modelos.length}', const Color(0xFF6B7280), isDark),
            _vDivider(bdr),
            if (is303)
              _statPill(Icons.tune_rounded, 'Criterio IVA',
                  _criterioIva == CriterioIVA.devengo ? 'Devengo' : 'Caja (RECC)',
                  color, isDark)
            else
              _statPill(Icons.percent_rounded, '% aplicado', '20%', color, isDark),
          ])),
        ),

        // ── Period selector grid 2×2 ─────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth > 500 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: cols == 4 ? 1.5 : 1.6,
            ),
            itemCount: modelos.length,
            itemBuilder: (_, i) {
              final m = modelos[i];
              final sel = _periodoSel == i;
              final alerta = m.estadoAlerta;
              final dotColor = _dotColor(alerta);
              final mainVal = is303 ? m.resultadoIva : m.pagoFraccionadoIrpf;
              final mainIsNeg = mainVal < 0;
              final mainColor = is303
                  ? (mainIsNeg ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                  : color;
              final statusLabel = switch (alerta) {
                EstadoAlertaFiscal.ok      => 'Borrador',
                EstadoAlertaFiscal.proximo => 'Próximo',
                EstadoAlertaFiscal.vencido => 'Vencido',
              };
              return GestureDetector(
                onTap: () => setState(() => _periodoSel = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? color : bdr,
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel ? [BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8, offset: const Offset(0, 2))] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(m.nombreTrimestre,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: txt)),
                      const Spacer(),
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    ]),
                    Text(m.periodoTexto,
                        style: TextStyle(fontSize: 9.5, color: sub)),
                    const Spacer(),
                    Text(
                      '${mainVal.abs().toStringAsFixed(2)} €',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: mainColor),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dotColor)),
                      const Spacer(),
                      Text(m.fechaLimiteTexto,
                          style: TextStyle(fontSize: 9.5, color: sub)),
                    ]),
                  ]),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 12),

        // ── Detail panel: 2/3 campos + 1/3 acciones ─────────────────
        if (periodoActual != null)
          LayoutBuilder(builder: (_, c) {
            final wide = c.maxWidth > 500;
            final content = _detailFields(periodoActual, is303, txt, sub, bdr);
            final side = _detailSide(periodoActual, is303, color, surf, isDark);
            return Container(
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bdr),
              ),
              child: wide
                  ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(16), child: content)),
                      Container(width: 1, color: bdr),
                      Expanded(flex: 1, child: Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        child: Padding(padding: const EdgeInsets.all(16), child: side),
                      )),
                    ]))
                  : Column(children: [
                      Padding(padding: const EdgeInsets.all(16), child: content),
                      Divider(height: 1, color: bdr),
                      Padding(padding: const EdgeInsets.all(16), child: side),
                    ]),
            );
          }),

        const SizedBox(height: 16),
        _buildCalendarioFiscal(color),
      ],
    );
  }

  // ── Stat pill para el stats strip ────────────────────────────────────────
  Widget _statPill(IconData icon, String label, String value, Color acento, bool isDark) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final sub = isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: acento)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: acento),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: sub),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ));
  }

  Widget _vDivider(Color bdr) => Container(width: 1, color: bdr);

  // ── Filas de campos del detail panel (izquierda) ─────────────────────────
  Widget _detailFields(ModeloFiscalTrimestral m, bool is303,
      Color txt, Color sub, Color bdr) {
    final rows = is303
        ? [
          ('[01]', 'IVA repercutido', '${m.ivaRepercutido.toStringAsFixed(2)} €', false),
          ('[02]', 'IVA soportado', '${m.ivaSoportado.toStringAsFixed(2)} €', false),
          ('[27]', 'Resultado liquidación', '${m.resultadoIva.toStringAsFixed(2)} €', true),
        ]
        : [
          ('[01]', 'Ingresos íntegros', '${m.resumen.baseImponibleEmitida.toStringAsFixed(2)} €', false),
          ('[02]', 'Gastos deducibles', '${m.resumen.baseImponibleRecibida.toStringAsFixed(2)} €', false),
          ('[03]', 'Rendimiento neto', '${m.beneficioNeto.toStringAsFixed(2)} €', false),
          ('[13]', 'Pago fraccionado (20%)', '${m.pagoFraccionadoIrpf.toStringAsFixed(2)} €', true),
        ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${m.nombreTrimestre} · ${m.periodoTexto}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
        const Spacer(),
        Text('Plazo: ${m.fechaLimiteTexto}',
            style: TextStyle(fontSize: 11, color: sub)),
      ]),
      const SizedBox(height: 12),
      ...rows.map((r) => _fieldRow(r.$1, r.$2, r.$3, r.$4, txt, sub, bdr)),
    ]);
  }

  Widget _fieldRow(String num, String label, String value, bool bold,
      Color txt, Color sub, Color bdr) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Text(num, style: TextStyle(fontSize: 10, color: bdr, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? txt : sub))),
          Text(value,
              style: TextStyle(fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: bold ? txt : sub)),
        ]),
      ),
      Divider(height: 1, color: bdr),
    ]);
  }

  // ── Panel derecho: resultado + acciones ───────────────────────────────────
  Widget _detailSide(ModeloFiscalTrimestral m, bool is303, Color color,
      Color surf, bool isDark) {
    final mainVal = is303 ? m.resultadoIva : m.pagoFraccionadoIrpf;
    final mainIsNeg = mainVal < 0;
    final mainColor = is303
        ? (mainIsNeg ? const Color(0xFF10B981) : const Color(0xFFEF4444))
        : color;
    final sub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      // Resultado key figure
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(is303 ? (mainIsNeg ? 'A devolver' : 'A ingresar') : 'A ingresar',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: sub, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text('${mainVal.abs().toStringAsFixed(2)} €',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: mainColor)),
      ]),
      const SizedBox(height: 16),
      // Acciones
      _actionBtn(Icons.refresh_rounded, 'Recalcular',
          const Color(0xFF6B7280), false, () => _recalcularMod303(m.trimestre)),
      const SizedBox(height: 6),
      if (is303) ...[
        _actionBtn(Icons.download_rounded, 'Descargar AEAT .txt',
            const Color(0xFFF97316), false, () => _descargarMod303(m.trimestre)),
        const SizedBox(height: 6),
      ],
      _actionBtn(Icons.check_circle_outline_rounded, 'Marcar presentado',
          color, true, () => _marcarPresentado303(m.trimestre)),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, Color color, bool filled, VoidCallback onTap) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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


  Widget _iconoAccion(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  Widget _kpiCompacto(String label, double valor, Color color) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 2),
      Text('${valor.toStringAsFixed(0)} €',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  Widget _kpiResultado(String label, double valor, Color color) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9.5, color: color.withValues(alpha: 0.75))),
      const SizedBox(height: 2),
      Text('${valor.toStringAsFixed(2)} €',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ]),
  );

  static Widget _dividerV() => Container(
    width: 1, margin: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0xFFE5E7EB),
  );

  Widget _buildSelectorCriterioIva(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(Icons.tune_rounded, color: color, size: 14),
        const SizedBox(width: 7),
        Text('Criterio IVA:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 10),
        _criterioChip('Devengo', CriterioIVA.devengo, color),
        const SizedBox(width: 6),
        _criterioChip('Caja (RECC)', CriterioIVA.caja, color),
        if (_guardandoCriterio) ...[
          const SizedBox(width: 8),
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
        ],
        const Spacer(),
        Tooltip(
          message: 'El criterio de caja solo aplica si tu empresa está en RECC',
          child: Icon(Icons.info_outline_rounded, size: 14, color: const Color(0xFF9CA3AF)),
        ),
      ]),
    );
  }

  Widget _criterioChip(String label, CriterioIVA valor, Color color) {
    final sel = _criterioIva == valor;
    return GestureDetector(
      onTap: _guardandoCriterio ? null : () => _guardarCriterioIva(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? color : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : const Color(0xFF6B7280),
        )),
      ),
    );
  }

  Widget _buildCard303(ModeloFiscalTrimestral m, Color color) {
    final alerta = m.estadoAlerta;
    final colorAlerta = _colorAlerta(alerta);
    final esDevolucion = m.hayDevolucionIva;
    final resultColor = esDevolucion ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alerta != EstadoAlertaFiscal.ok
              ? colorAlerta.withValues(alpha: 0.5)
              : const Color(0xFFE5E7EB),
          width: alerta != EstadoAlertaFiscal.ok ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila 1: chip + periodo + badge alerta
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(m.nombreTrimestre, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(m.periodoTexto, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11))),
          _badgeAlerta(alerta, m.fechaLimiteTexto),
        ]),
        const SizedBox(height: 8),
        // Fila 2: 3 KPIs en columnas
        IntrinsicHeight(child: Row(children: [
          _kpiCompacto('Repercutido', m.ivaRepercutido, const Color(0xFF10B981)),
          _dividerV(),
          _kpiCompacto('Soportado', m.ivaSoportado, const Color(0xFF6B7280)),
          _dividerV(),
          _kpiResultado(esDevolucion ? 'Devuelven' : 'A pagar', m.resultadoIva.abs(), resultColor),
        ])),
        const SizedBox(height: 8),
        // Fila 3: fecha + acciones
        Row(children: [
          Icon(Icons.event_rounded, size: 12, color: colorAlerta),
          const SizedBox(width: 4),
          Text(m.fechaLimiteTexto, style: TextStyle(fontSize: 11, color: colorAlerta, fontWeight: FontWeight.w600)),
          const Spacer(),
          _iconoAccion(Icons.refresh_rounded, color, 'Recalcular', () => _recalcularMod303(m.trimestre)),
          _iconoAccion(Icons.download_rounded, Colors.deepOrange, 'Descargar AEAT', () => _descargarMod303(m.trimestre)),
          _iconoAccion(Icons.open_in_browser_rounded, Colors.teal, 'Sede AEAT', () => SedeAeatUrls.abrir(SedeAeatUrls.mod303)),
          _iconoAccion(Icons.check_circle_outline_rounded, Colors.green, 'Presentado', () => _marcarPresentado303(m.trimestre)),
        ]),
      ]),
    );
  }

  Widget _buildCard130(ModeloFiscalTrimestral m, Color color) {
    final alerta = m.estadoAlerta;
    final colorAlerta = _colorAlerta(alerta);
    const acento = Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alerta != EstadoAlertaFiscal.ok
              ? colorAlerta.withValues(alpha: 0.5)
              : const Color(0xFFE5E7EB),
          width: alerta != EstadoAlertaFiscal.ok ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila 1: chip + periodo + badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: acento.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(m.nombreTrimestre, style: const TextStyle(color: acento, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(m.periodoTexto, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11))),
          _badgeAlerta(alerta, m.fechaLimiteTexto),
        ]),
        const SizedBox(height: 8),
        // Fila 2: KPIs o "sin beneficio"
        if (!m.hayBeneficio)
          const Row(children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 13),
            SizedBox(width: 6),
            Text('Sin beneficio — sin pago fraccionado',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
          ])
        else
          IntrinsicHeight(child: Row(children: [
            _kpiCompacto('Beneficio neto', m.beneficioNeto, const Color(0xFF10B981)),
            _dividerV(),
            _kpiCompacto('Retención 20%', m.pagoFraccionadoIrpf, const Color(0xFFF59E0B)),
            _dividerV(),
            _kpiResultado('A ingresar', m.pagoFraccionadoIrpf, acento),
          ])),
        const SizedBox(height: 8),
        // Fila 3: fecha + nota orientativa
        Row(children: [
          Icon(Icons.event_rounded, size: 12, color: colorAlerta),
          const SizedBox(width: 4),
          Text(m.fechaLimiteTexto, style: TextStyle(fontSize: 11, color: colorAlerta, fontWeight: FontWeight.w600)),
          if (m.hayBeneficio) ...[
            const SizedBox(width: 6),
            const Text('· orientativo', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ]),
      ]),
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

  Future<void> _recalcularMod303(int trimestre) async {
    try {
      final datos = await Mod303Service().calcularMod303(
        empresaId: widget.empresaId,
        anio: widget.anio,
        trimestre: trimestre,
      );
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('modelos_fiscales')
          .doc('303_${widget.anio}_${trimestre}T')
          .set({
        ...datos..remove('facturas_emitidas')..remove('facturas_recibidas'),
        'modelo': '303', 'ejercicio': widget.anio,
        'trimestre': '${trimestre}T',
        'fecha_calculo': FieldValue.serverTimestamp(),
        'estado': 'calculado',
      }, SetOptions(merge: true));
      if (mounted) FluxToast.exito(context, 'Mod.303 ${trimestre}T recalculado');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _marcarPresentado303(int trimestre) async {
    await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('modelos_fiscales')
        .doc('303_${widget.anio}_${trimestre}T')
        .set({'estado': 'presentado', 'fecha_presentacion': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
    if (mounted) FluxToast.exito(context, 'Mod.303 ${trimestre}T marcado como presentado');
  }

  Future<void> _abrirConfiguracionFiscal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PantallaPerfil(),
      ),
    );
  }


}

class _ModeloInfo {
  final String num, label;
  final IconData icon;
  final Color color;
  final int idx;
  final bool periodico; // true = trimestral/mensual, false = anual
  const _ModeloInfo(this.num, this.label, this.icon, this.color, this.idx, {this.periodico = true});
}
