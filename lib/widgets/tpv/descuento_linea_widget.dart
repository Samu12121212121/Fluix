import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kRosa = Color(0xFFFF3296);
const _kSecondary = Color(0xFFB0B3C1);

class DescuentoLineaWidget extends StatefulWidget {
  final String nombreProducto;
  final double precioOriginal;
  final int cantidad;
  final int maxPct;
  final Function(double descuentoPct, double descuentoImporte) onAplicar;

  const DescuentoLineaWidget({
    super.key,
    required this.nombreProducto,
    required this.precioOriginal,
    required this.cantidad,
    this.maxPct = 100,
    required this.onAplicar,
  });

  static Future<({double pct, double importe})?> mostrar(
    BuildContext context, {
    required String nombreProducto,
    required double precioOriginal,
    required int cantidad,
    int maxPct = 100,
  }) async {
    ({double pct, double importe})? resultado;
    await showDialog(
      context: context,
      builder: (_) => DescuentoLineaWidget(
        nombreProducto: nombreProducto,
        precioOriginal: precioOriginal,
        cantidad: cantidad,
        maxPct: maxPct,
        onAplicar: (pct, importe) => resultado = (pct: pct, importe: importe),
      ),
    );
    return resultado;
  }

  @override
  State<DescuentoLineaWidget> createState() => _DescuentoLineaWidgetState();
}

class _DescuentoLineaWidgetState extends State<DescuentoLineaWidget> {
  bool _modoPorc = true; // true = porcentaje, false = importe €
  final _ctrl = TextEditingController(text: '0');
  final _fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_validar);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _totalLinea => widget.precioOriginal * widget.cantidad;

  double get _valorInput =>
      double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0.0;

  double get _descuentoImporte {
    if (_modoPorc) {
      final pct = _valorInput.clamp(0.0, 100.0);
      return _totalLinea * pct / 100;
    }
    return _valorInput.clamp(0.0, _totalLinea);
  }

  double get _descuentoPct {
    if (_modoPorc) return _valorInput.clamp(0.0, 100.0);
    if (_totalLinea == 0) return 0;
    return (_valorInput / _totalLinea * 100).clamp(0.0, 100.0);
  }

  double get _precioFinal => _totalLinea - _descuentoImporte;

  void _validar() {
    final v = _valorInput;
    final limite = widget.maxPct;
    setState(() {
      if (_modoPorc && v > limite) {
        _error = limite < 100
            ? 'Descuento máximo permitido: $limite%'
            : 'El porcentaje no puede superar el 100%';
      } else if (!_modoPorc && v > _totalLinea) {
        _error =
            'El descuento no puede superar el total (${_fmt.format(_totalLinea)})';
      } else {
        _error = null;
      }
    });
  }

  void _aplicar() {
    if (_error != null) return;
    widget.onAplicar(_descuentoPct, _descuentoImporte);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    color: _kVerde, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Aplicar descuento',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _kSecondary, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.nombreProducto,
              style: const TextStyle(color: _kSecondary, fontSize: 13),
            ),
            Text(
              '${widget.cantidad} × ${_fmt.format(widget.precioOriginal)}  =  ${_fmt.format(_totalLinea)}',
              style: const TextStyle(color: _kSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            // Toggle modo
            Container(
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: _tabBtn('% Porcentaje', true)),
                  Expanded(child: _tabBtn('€ Importe', false)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Input
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kBg,
                hintText: _modoPorc ? '0' : '0.00',
                hintStyle: const TextStyle(color: _kSecondary),
                suffix: Text(
                  _modoPorc ? '%' : '€',
                  style: const TextStyle(
                      color: _kVerde,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kVerde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _kVerde.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kVerde),
                ),
                errorText: _error,
                errorStyle: const TextStyle(color: _kRosa),
              ),
            ),
            const SizedBox(height: 12),
            // Resumen
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Descuento',
                          style:
                              TextStyle(color: _kSecondary, fontSize: 11)),
                      Text(
                        '${_descuentoPct.toStringAsFixed(1)}%  ·  ${_fmt.format(_descuentoImporte)}',
                        style: const TextStyle(
                            color: _kRosa,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Precio final',
                          style:
                              TextStyle(color: _kSecondary, fontSize: 11)),
                      Text(
                        _fmt.format(_precioFinal),
                        style: const TextStyle(
                            color: _kVerde,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSecondary,
                      side: BorderSide(color: _kSecondary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _error == null && _valorInput > 0
                        ? _aplicar
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kVerde,
                      foregroundColor: _kBg,
                      disabledBackgroundColor: _kVerde.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Aplicar descuento',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool esPorc) {
    final activo = _modoPorc == esPorc;
    return GestureDetector(
      onTap: () => setState(() {
        _modoPorc = esPorc;
        _ctrl.text = '0';
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: activo ? _kVerde.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: activo ? Border.all(color: _kVerde) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: activo ? _kVerde : _kSecondary,
              fontSize: 13,
              fontWeight:
                  activo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
