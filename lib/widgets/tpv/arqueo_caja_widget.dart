import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kRosa = Color(0xFFFF3296);
const _kSecondary = Color(0xFFB0B3C1);

class ArqueoCajaWidget extends StatefulWidget {
  final double totalSistema;
  final Function(Map<String, int> denominaciones, double totalContado) onConfirmar;

  const ArqueoCajaWidget({
    super.key,
    required this.totalSistema,
    required this.onConfirmar,
  });

  static Future<Map<String, int>?> mostrar(
    BuildContext context, {
    required double totalSistema,
  }) async {
    Map<String, int>? resultado;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ArqueoCajaWidget(
        totalSistema: totalSistema,
        onConfirmar: (dens, _) => resultado = dens,
      ),
    );
    return resultado;
  }

  @override
  State<ArqueoCajaWidget> createState() => _ArqueoCajaWidgetState();
}

class _ArqueoCajaWidgetState extends State<ArqueoCajaWidget> {
  static const _billetes = [500.0, 200.0, 100.0, 50.0, 20.0, 10.0, 5.0];
  static const _monedas = [2.0, 1.0, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01];

  late final Map<String, TextEditingController> _controllers;
  final _fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

  @override
  void initState() {
    super.initState();
    final todas = [..._billetes, ..._monedas];
    _controllers = {
      for (final d in todas) _key(d): TextEditingController(text: '0'),
    };
    for (final ctrl in _controllers.values) {
      ctrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _key(double d) => d.toStringAsFixed(2);

  double _subtotal(double denominacion) {
    final qty = int.tryParse(_controllers[_key(denominacion)]?.text ?? '0') ?? 0;
    return denominacion * qty;
  }

  double get _totalContado {
    final todas = [..._billetes, ..._monedas];
    return todas.fold(0.0, (sum, d) => sum + _subtotal(d));
  }

  double get _diferencia => _totalContado - widget.totalSistema;

  Map<String, int> _buildDenominaciones() {
    final todas = [..._billetes, ..._monedas];
    return {
      for (final d in todas)
        _key(d): int.tryParse(_controllers[_key(d)]?.text ?? '0') ?? 0,
    };
  }

  Widget _filaDenomin(double denominacion, String etiqueta) {
    final ctrl = _controllers[_key(denominacion)]!;
    final sub = _subtotal(denominacion);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              etiqueta,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kSecondary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: _kSecondary.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kVerde),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _fmt.format(sub),
            style: TextStyle(
              color: sub > 0 ? _kVerde : _kSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diferencia = _diferencia;
    final colorDif = diferencia.abs() < 0.01
        ? _kVerde
        : (diferencia < 0 ? _kRosa : _kVerde);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Arqueo de caja',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Sistema: ${_fmt.format(widget.totalSistema)}',
            style: const TextStyle(color: _kSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _seccion('Billetes', _billetes),
                const SizedBox(height: 8),
                _seccion('Monedas', _monedas),
                const SizedBox(height: 16),
                _resumenTotales(colorDif, diferencia),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kVerde,
                  foregroundColor: _kBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  widget.onConfirmar(_buildDenominaciones(), _totalContado);
                  Navigator.pop(context);
                },
                child: const Text('Confirmar arqueo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<double> denominaciones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                color: _kSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: denominaciones.map((d) {
              final label = d >= 1
                  ? '${d.toInt()} €'
                  : '${(d * 100).toInt()} ct';
              return _filaDenomin(d, label);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _resumenTotales(Color colorDif, double diferencia) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorDif.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          _filaTotales('Total contado', _fmt.format(_totalContado),
              _kVerde),
          const SizedBox(height: 8),
          _filaTotales('Total sistema',
              _fmt.format(widget.totalSistema), _kSecondary),
          const Divider(color: Color(0xFF2E3355), height: 20),
          _filaTotales(
            'Diferencia',
            '${diferencia >= 0 ? '+' : ''}${_fmt.format(diferencia)}',
            colorDif,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _filaTotales(String label, String valor, Color colorValor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: _kSecondary,
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(valor,
            style: TextStyle(
                color: colorValor,
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
