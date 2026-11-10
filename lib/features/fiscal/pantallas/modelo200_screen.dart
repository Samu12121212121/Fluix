import 'package:flutter/material.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../domain/modelos/modelo200.dart';
import '../../../services/fiscal/mod200_calculator.dart';
import '../../../services/fiscal/sede_aeat_urls.dart';
import '../../../widgets/presentar_aeat_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 200 — Impuesto sobre Sociedades (anual)
// Solo visible para sociedades (SL, SA, SLU, SLP, Cooperativa, etc.)
// ═════════════════════════════════════════════════════════════════════════════

const _kPurple  = Color(0xFF7C3AED);
const _kPurpleL = Color(0xFFF5F3FF);
const _kBg      = Color(0xFFF8FAFC);
const _kSurf    = Colors.white;
const _kBorder  = Color(0xFFE2E8F0);
const _kText    = Color(0xFF0F172A);
const _kSub     = Color(0xFF64748B);
const _kGreen   = Color(0xFF16A34A);
const _kRed     = Color(0xFFDC2626);
const _kAmber   = Color(0xFFD97706);

class Modelo200Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;
  final bool embebido;

  const Modelo200Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
    this.embebido = false,
  });

  @override
  State<Modelo200Screen> createState() => _Modelo200ScreenState();
}

class _Modelo200ScreenState extends State<Modelo200Screen> {
  final _svc = Mod200Calculator();
  late int _anio;
  bool _calculando = false;

  // Ajustes manuales opcionales
  TipoGravamenIS _tipoGravamen = TipoGravamenIS.general;
  final _basesNegCtrl    = TextEditingController(text: '0');
  final _dedDoblCtrl     = TextEditingController(text: '0');
  final _bonificCtrl     = TextEditingController(text: '0');
  final _dedEmpCtrl      = TextEditingController(text: '0');
  final _ajusteCtrl      = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? (DateTime.now().year - 1); // IS del ejercicio anterior
  }

  @override
  void dispose() {
    _basesNegCtrl.dispose();
    _dedDoblCtrl.dispose();
    _bonificCtrl.dispose();
    _dedEmpCtrl.dispose();
    _ajusteCtrl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    setState(() => _calculando = true);
    try {
      final modelo = await _svc.calcular(
        empresaId:          widget.empresaId,
        ejercicio:          _anio,
        tipoGravamen:       _tipoGravamen,
        c547BasesNegativas: _parseDouble(_basesNegCtrl.text),
      );

      // Aplicar ajustes manuales opcionales
      final modeloFinal = modelo.copyWith(
        c03OtrosAjustes:        _parseDouble(_ajusteCtrl.text),
        c582DedDobleImposicion: _parseDouble(_dedDoblCtrl.text),
        c583Bonificaciones:     _parseDouble(_bonificCtrl.text),
        c585DedCreacionEmpleo:  _parseDouble(_dedEmpCtrl.text),
      );

      await _svc.guardar(widget.empresaId, modeloFinal);
      if (mounted) FluxToast.exito(context, 'Modelo 200 $_anio calculado — ${modeloFinal.resultadoTexto}');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error calculando: $e');
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  Future<void> _marcarPresentado() async {
    await _svc.marcarPresentado(widget.empresaId, _anio, null);
    if (mounted) FluxToast.exito(context, 'Modelo 200 $_anio marcado como presentado');
  }

  static double _parseDouble(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<Modelo200?>(
      stream: _svc.obtener(widget.empresaId, _anio),
      builder: (ctx, snap) {
        final modelo = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 14),
            _buildAjustesCard(),
            const SizedBox(height: 14),
            if (modelo != null) ...[
              _buildResultadoCard(modelo),
              const SizedBox(height: 14),
              _buildCasillasCard(modelo),
              const SizedBox(height: 14),
              _buildAcciones(modelo),
            ] else ...[
              _buildBotonesCalculo(),
            ],
            const SizedBox(height: 20),
            PresentarAeatWidget(
              modelo: '200',
              urlAeat: SedeAeatUrls.mod200,
              onJustificanteGuardado: (_) {},
            ),
          ],
        );
      },
    );

    if (widget.embebido) return body;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: FluixAppBar(
        titulo: 'Modelo 200 — IS Sociedades',
        showLeading: true,
        extraActions: [
          _anioNav(),
        ],
      ),
      body: body,
    );
  }

  // ── Selector de año ───────────────────────────────────────────────────────

  Widget _anioNav() => Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(
      icon: const Icon(Icons.chevron_left),
      onPressed: () => setState(() => _anio--),
      visualDensity: VisualDensity.compact,
    ),
    Text('$_anio', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: () => setState(() => _anio++),
      visualDensity: VisualDensity.compact,
    ),
  ]);

  // ── Card superior: info del modelo ────────────────────────────────────────

  Widget _buildHeaderCard() {
    final plazo      = Modelo200.plazoLimite(_anio);
    final diasRestantes = plazo.difference(DateTime.now()).inDays;
    final colorPlazo = diasRestantes < 0 ? _kRed : diasRestantes <= 30 ? _kAmber : _kGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B21B6), _kPurple]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.business_center_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Modelo 200 — IS Anual',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              Text('Impuesto sobre Sociedades · Ejercicio $_anio',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$_anio', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.schedule_rounded, color: colorPlazo, size: 15),
            const SizedBox(width: 6),
            Text('Plazo: ${_fmtDate(Modelo200.plazoLimite(_anio))}',
                style: TextStyle(color: colorPlazo, fontWeight: FontWeight.w600, fontSize: 12)),
            const Spacer(),
            Text(
              diasRestantes < 0
                  ? 'Vencido hace ${-diasRestantes} días'
                  : '$diasRestantes días restantes',
              style: TextStyle(color: colorPlazo, fontSize: 11),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Card de ajustes manuales ──────────────────────────────────────────────

  Widget _buildAjustesCard() {
    return _card(
      title: 'Configuración del ejercicio',
      icon: Icons.tune_rounded,
      child: Column(children: [
        // Tipo de gravamen
        const Align(alignment: Alignment.centerLeft,
          child: Text('Tipo de gravamen aplicable',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub))),
        const SizedBox(height: 6),
        Row(children: TipoGravamenIS.values.map((t) {
          final sel = _tipoGravamen == t;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _tipoGravamen = t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kPurple : _kSurf,
                  border: Border.all(color: sel ? _kPurple : _kBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t.etiqueta,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: sel ? Colors.white : _kSub,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 12),
        // Campos opcionales
        Row(children: [
          Expanded(child: _campoAjuste(_basesNegCtrl, 'Bases negativas anteriores [547]', Icons.remove_circle_outline)),
          const SizedBox(width: 8),
          Expanded(child: _campoAjuste(_ajusteCtrl, 'Ajustes extracontables netos [03]', Icons.swap_vert_rounded)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _campoAjuste(_dedDoblCtrl, 'Deducción doble imposición [582]', Icons.language_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _campoAjuste(_bonificCtrl, 'Bonificaciones [583]', Icons.percent_rounded)),
        ]),
        const SizedBox(height: 8),
        _campoAjuste(_dedEmpCtrl, 'Deducción creación empleo discapacidad [585]', Icons.people_outline_rounded),
      ]),
    );
  }

  Widget _campoAjuste(TextEditingController ctrl, String label, IconData icon) =>
    TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 16, color: _kSub),
        suffixText: '€',
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: const TextStyle(fontSize: 13),
    );

  // ── Card resultado principal ───────────────────────────────────────────────

  Widget _buildResultadoCard(Modelo200 m) {
    final col = m.esAIngresar ? _kRed : m.esADevolver ? _kGreen : _kSub;
    final icono = m.esAIngresar ? Icons.arrow_upward_rounded
        : m.esADevolver ? Icons.arrow_downward_rounded
        : Icons.check_circle_outline_rounded;
    final texto = m.esAIngresar
        ? 'A ingresar en Hacienda'
        : m.esADevolver
            ? 'Hacienda te devuelve'
            : 'Cuota cero';
    final esPresent = m.estado == EstadoModelo200.presentado;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        border: Border.all(color: col.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: col.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icono, color: col, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.resultadoTexto,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: col)),
            Text(texto, style: const TextStyle(fontSize: 12, color: _kSub)),
          ])),
          if (esPresent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('PRESENTADO',
                  style: TextStyle(fontSize: 10, color: _kGreen, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 14),
        // KPIs rápidos
        Row(children: [
          _kpiCol('Ingresos', '${m.totalIngresosEjercicio.toStringAsFixed(0)} €', _kText),
          _divV(),
          _kpiCol('Gastos', '${m.totalGastosEjercicio.toStringAsFixed(0)} €', _kSub),
          _divV(),
          _kpiCol('Resultado\ncontable', '${m.c01ResultadoContable.toStringAsFixed(0)} €',
              m.c01ResultadoContable >= 0 ? _kGreen : _kRed),
          _divV(),
          _kpiCol('Base\nimponible', '${m.c552BaseImponible.toStringAsFixed(0)} €', _kPurple),
          _divV(),
          _kpiCol('Cuota\nlíquida', '${m.c592CuotaLiquida.toStringAsFixed(0)} €', col),
        ]),
      ]),
    );
  }

  Widget _kpiCol(String label, String valor, Color color) => Expanded(
    child: Column(children: [
      Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: _kSub), textAlign: TextAlign.center),
    ]),
  );

  Widget _divV() => Container(width: 1, height: 32, color: _kBorder);

  // ── Card casillas desglosadas ─────────────────────────────────────────────

  Widget _buildCasillasCard(Modelo200 m) {
    return _card(
      title: 'Desglose casillas',
      icon: Icons.format_list_numbered_rounded,
      child: Column(children: [
        _seccion('BASE IMPONIBLE'),
        _fila('[01]', 'Resultado contable', m.c01ResultadoContable, bold: true),
        if (m.c02AjusteIS != 0)
          _fila('[02]', 'IS y otros impuestos a añadir', m.c02AjusteIS),
        if (m.c03OtrosAjustes != 0)
          _fila('[03]', 'Ajustes extracontables netos', m.c03OtrosAjustes),
        _fila('[BIP]', 'Base imponible previa', m.baseImponiblePrevia,
            color: _kText),
        if (m.c547BasesNegativas > 0)
          _fila('[547]', 'Bases negativas a compensar', -m.c547BasesNegativas),
        _fila('[552]', 'Base imponible', m.c552BaseImponible,
            bold: true, color: _kPurple),
        const Divider(height: 16),
        _seccion('CUOTA ÍNTEGRA'),
        _fila('[tipo]', 'Tipo de gravamen', m.tipoGravamen.tipo * 100,
            suffix: '%', color: _kSub),
        _fila('[566]', 'Cuota íntegra', m.c566CuotaIntegra, bold: true),
        if (m.totalDeducciones > 0) ...[
          const Divider(height: 16),
          _seccion('DEDUCCIONES'),
          if (m.c582DedDobleImposicion > 0)
            _fila('[582]', 'Deducción doble imposición', -m.c582DedDobleImposicion),
          if (m.c583Bonificaciones > 0)
            _fila('[583]', 'Bonificaciones', -m.c583Bonificaciones),
          if (m.c585DedCreacionEmpleo > 0)
            _fila('[585]', 'Deducción creación empleo', -m.c585DedCreacionEmpleo),
        ],
        _fila('[592]', 'Cuota líquida', m.c592CuotaLiquida, bold: true),
        const Divider(height: 16),
        _seccion('RESULTADO'),
        if (m.c598Retenciones > 0)
          _fila('[598]', 'Retenciones soportadas', -m.c598Retenciones),
        if (m.c599PagosFraccionados > 0)
          _fila('[599]', 'Pagos fraccionados (Mod.202)', -m.c599PagosFraccionados),
        _fila('[600]', 'RESULTADO', m.c600Resultado,
            bold: true,
            color: m.esAIngresar ? _kRed : m.esADevolver ? _kGreen : _kSub),
      ]),
    );
  }

  Widget _seccion(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: _kSub, letterSpacing: 0.5)),
  );

  Widget _fila(String casilla, String label, double valor,
      {bool bold = false, Color? color, String suffix = '€'}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 46,
          child: Text(casilla, style: TextStyle(fontSize: 10, color: _kPurple.withValues(alpha: 0.7)))),
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
        Text(
          suffix == '%'
              ? '${valor.toStringAsFixed(0)} %'
              : '${valor >= 0 ? '' : '- '}${valor.abs().toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? (valor < 0 ? _kRed.withValues(alpha: 0.8) : _kText),
          ),
        ),
      ]),
    );

  // ── Botones acción ────────────────────────────────────────────────────────

  Widget _buildBotonesCalculo() => Column(children: [
    SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton.icon(
        onPressed: _calculando ? null : _calcular,
        icon: _calculando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.calculate_rounded, size: 20),
        label: Text(_calculando ? 'Calculando...' : 'CALCULAR MODELO 200',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPurple, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
  ]);

  Widget _buildAcciones(Modelo200 m) => Wrap(spacing: 8, runSpacing: 8, children: [
    _btn('Recalcular', Icons.refresh_rounded, _kPurple, _calcular),
    _btn('Sede AEAT', Icons.open_in_browser_rounded, const Color(0xFF0369A1),
        () => SedeAeatUrls.abrir(SedeAeatUrls.mod200)),
    if (m.estado == EstadoModelo200.borrador)
      _btn('Marcar presentado', Icons.check_rounded, _kGreen, _marcarPresentado),
  ]);

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) =>
    OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required String title, required IconData icon, required Widget child}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurf, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _kPurpleL, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: _kPurple),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
