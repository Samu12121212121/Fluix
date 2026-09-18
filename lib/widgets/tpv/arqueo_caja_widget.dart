import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kBg      = Color(0xFF0A0F23);
const _kCard    = Color(0xFF1E2139);
const _kVerde   = Color(0xFF00FFC8);
const _kRosa    = Color(0xFFFF3296);
const _kSec     = Color(0xFFB0B3C1);
const _kDivider = Color(0xFF2E3355);

class ArqueoCajaWidget extends StatefulWidget {
  final double totalSistema;
  final Function(Map<String, int> denominaciones, double totalContado) onConfirmar;

  const ArqueoCajaWidget({
    super.key,
    required this.totalSistema,
    required this.onConfirmar,
  });

  /// Devuelve `(dens, total)` al confirmar, o null si se cancela.
  static Future<({Map<String, int> dens, double total})?> mostrar(
    BuildContext context, {
    required double totalSistema,
  }) async {
    ({Map<String, int> dens, double total})? resultado;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ArqueoCajaWidget(
        totalSistema: totalSistema,
        onConfirmar: (dens, total) =>
            resultado = (dens: dens, total: total),
      ),
    );
    return resultado;
  }

  @override
  State<ArqueoCajaWidget> createState() => _ArqueoCajaWidgetState();
}

class _ArqueoCajaWidgetState extends State<ArqueoCajaWidget> {
  static const _billetes = [200.0, 100.0, 50.0, 20.0, 10.0, 5.0];
  static const _monedas  = [2.0, 1.0, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01];

  // Persistencia en memoria: clave = fecha de hoy.
  // Se restaura automáticamente si el usuario cierra y vuelve a abrir el arqueo.
  static final Map<String, Map<String, int>> _cache = {};
  static String get _claveHoy =>
      DateTime.now().toLocal().toString().substring(0, 10);

  final Map<String, int> _qty = {};
  final _fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
  final _fmtShort = NumberFormat('#,##0.00', 'es_ES');

  @override
  void initState() {
    super.initState();
    // Inicializar con ceros
    for (final d in [..._billetes, ..._monedas]) {
      _qty[_k(d)] = 0;
    }
    // Restaurar último estado del día si existe
    final guardado = _cache[_claveHoy];
    if (guardado != null) {
      _qty.addAll(guardado);
    }
  }

  String _k(double d) => d.toStringAsFixed(2);
  int    _get(double d) => _qty[_k(d)] ?? 0;
  double _sub(double d) => d * _get(d);

  void _guardarCache() => _cache[_claveHoy] = Map.from(_qty);

  void _inc(double d) => setState(() {
    _qty[_k(d)] = _get(d) + 1;
    _guardarCache();
  });

  void _dec(double d) {
    final v = _get(d);
    if (v > 0) {
      setState(() {
        _qty[_k(d)] = v - 1;
        _guardarCache();
      });
    }
  }

  double get _totalContado =>
      [..._billetes, ..._monedas].fold(0.0, (s, d) => s + _sub(d));
  double get _diferencia => _totalContado - widget.totalSistema;

  Map<String, int> _build() => {
    for (final d in [..._billetes, ..._monedas]) _k(d): _get(d),
  };

  String _labelBillete(double d) => '${d.toInt()} €';
  String _labelMoneda(double d) =>
      d >= 1 ? '${d.toInt()} €' : '${(d * 100).round()} ct';

  @override
  Widget build(BuildContext context) {
    final diferencia = _diferencia;
    final colorDif = diferencia.abs() < 0.01
        ? _kVerde
        : (diferencia < 0 ? _kRosa : Colors.amber);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, sc) => Column(children: [
        // ── Handle + título ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: _kSec.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.calculate_outlined, color: _kVerde, size: 18),
              const SizedBox(width: 8),
              const Text('Arqueo de caja',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kSec.withValues(alpha: 0.3)),
                ),
                child: Text('Sistema: ${_fmt.format(widget.totalSistema)}',
                    style: const TextStyle(color: _kSec, fontSize: 12)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        // ── Contenido scrollable ────────────────────────────────────────
        Expanded(child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Billetes en grid 2 columnas
            _sectionLabel('BILLETES'),
            const SizedBox(height: 6),
            _billetesGrid(),
            const SizedBox(height: 12),
            // Monedas en grid 4 columnas
            _sectionLabel('MONEDAS'),
            const SizedBox(height: 6),
            _monedasGrid(),
            const SizedBox(height: 14),
            // Resumen
            _resumen(colorDif, diferencia),
            const SizedBox(height: 16),
          ],
        )),
        // ── Botón confirmar ─────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kVerde,
                  foregroundColor: _kBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Confirmar  ${_fmt.format(_totalContado)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  widget.onConfirmar(_build(), _totalContado);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
        color: _kSec, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
  );

  // ── Grid billetes: 2 columnas, tarjetas grandes ─────────────────────
  Widget _billetesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _billetes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 90,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => _cardBillete(_billetes[i]),
    );
  }

  // ── Grid monedas: 4 columnas, tarjetas compactas ────────────────────
  Widget _monedasGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monedas.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 80,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (_, i) => _cardMoneda(_monedas[i]),
    );
  }

  // ── Tarjeta de billete ───────────────────────────────────────────────
  Widget _cardBillete(double d) {
    final qty = _get(d);
    final sub = _sub(d);
    final activo = qty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? _kVerde.withValues(alpha: 0.5) : _kDivider,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        // Denominación
        Text(_labelBillete(d),
            style: TextStyle(
              color: activo ? _kVerde : Colors.white,
              fontSize: 15, fontWeight: FontWeight.w800,
            )),
        // Controles +/-
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _btnCounter(() => _dec(d), Icons.remove_rounded, compact: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 28,
              child: Text('$qty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: activo ? Colors.white : _kSec,
                    fontSize: 16, fontWeight: FontWeight.bold,
                  )),
            ),
          ),
          _btnCounter(() => _inc(d), Icons.add_rounded, compact: false),
        ]),
        // Subtotal
        Text(
          sub > 0 ? '${_fmtShort.format(sub)} €' : '—',
          style: TextStyle(color: activo ? _kVerde : _kDivider, fontSize: 10.5),
        ),
      ]),
    );
  }

  // ── Tarjeta de moneda ────────────────────────────────────────────────
  Widget _cardMoneda(double d) {
    final qty = _get(d);
    final sub = _sub(d);
    final activo = qty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activo ? _kVerde.withValues(alpha: 0.4) : _kDivider,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        // Denominación
        Text(_labelMoneda(d),
            style: TextStyle(
              color: activo ? _kVerde : Colors.white,
              fontSize: 11.5, fontWeight: FontWeight.w700,
            )),
        // Controles +/-
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _btnCounter(() => _dec(d), Icons.remove_rounded, compact: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('$qty',
                style: TextStyle(
                  color: activo ? Colors.white : _kSec,
                  fontSize: 14, fontWeight: FontWeight.bold,
                )),
          ),
          _btnCounter(() => _inc(d), Icons.add_rounded, compact: true),
        ]),
        // Subtotal
        Text(
          sub > 0 ? '${_fmtShort.format(sub)} €' : '',
          style: const TextStyle(color: _kVerde, fontSize: 9),
        ),
      ]),
    );
  }

  // ── Botón +/- ────────────────────────────────────────────────────────
  Widget _btnCounter(VoidCallback onTap, IconData icon, {required bool compact}) {
    final size = compact ? 24.0 : 28.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(color: _kSec.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: compact ? 13 : 16, color: _kSec),
      ),
    );
  }

  // ── Resumen: total contado / sistema / diferencia ───────────────────
  Widget _resumen(Color colorDif, double diferencia) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorDif.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        _filaResumen('Total contado', _fmt.format(_totalContado), _kVerde),
        const SizedBox(height: 6),
        _filaResumen('Total sistema', _fmt.format(widget.totalSistema), _kSec),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: _kDivider, height: 1),
        ),
        _filaResumen(
          'Diferencia',
          '${diferencia >= 0 ? '+' : ''}${_fmt.format(diferencia)}',
          colorDif,
          bold: true,
        ),
      ]),
    );
  }

  Widget _filaResumen(String label, String valor, Color c, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: _kSec, fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(valor,
            style: TextStyle(color: c, fontSize: bold ? 16 : 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
