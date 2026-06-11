import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/services/tpv/cierre_caja_service.dart';
import 'package:planeag_flutter/services/tpv_facturacion_service.dart';
import 'tpv_bar_cobro_helpers.dart';

export 'tpv_bar_cobro_helpers.dart'
    show mostrarPantallaCierreCaja, mostrarDialogoAperturaCaja, Cupon;

Future<void> mostrarPantallaCobro(
  BuildContext context,
  String empresaId,
  String mesaId,
  String nombreMesa,
  List<Map<String, dynamic>> lineas,
  double total,
  int comensales,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PantallaCobro(
      empresaId: empresaId,
      mesaId: mesaId,
      nombreMesa: nombreMesa,
      lineas: lineas,
      total: total,
      comensales: comensales,
    ),
  );
}

class _PantallaCobro extends StatefulWidget {
  final String empresaId;
  final String mesaId;
  final String nombreMesa;
  final List<Map<String, dynamic>> lineas;
  final double total;
  final int comensales;

  const _PantallaCobro({
    required this.empresaId,
    required this.mesaId,
    required this.nombreMesa,
    required this.lineas,
    required this.total,
    required this.comensales,
  });

  @override
  State<_PantallaCobro> createState() => _PantallaCobroState();
}

class _PantallaCobroState extends State<_PantallaCobro> {
  final _entregadoCtrl = TextEditingController();
  final _propinaCtrl = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl = TextEditingController();
  final _nombreFiadoCtrl = TextEditingController();

  String _metodoPago = 'efectivo';
  double _propina = 0.0;
  bool _procesando = false;
  Cupon? _cuponAplicado;
  double _descuentoCupon = 0.0;

  bool _mostrarPropina = true;
  List<int> _propinaSugerida = const [5, 10, 15];
  int _descuentoMaxPct = 100;

  double get _totalConDescuento => widget.total - _descuentoCupon;
  double get _totalFinal => _totalConDescuento + _propina;
  double get _cambio {
    if (_metodoPago != 'efectivo') return 0.0;
    final e = double.tryParse(_entregadoCtrl.text) ?? 0.0;
    return (e - _totalFinal).clamp(0.0, double.infinity);
  }

  double get _saldoPendienteMixto {
    final ef = double.tryParse(_efectivoMixtoCtrl.text) ?? 0.0;
    final ta = double.tryParse(_tarjetaMixtoCtrl.text) ?? 0.0;
    return (_totalFinal - ef - ta).clamp(0.0, double.infinity);
  }

  @override
  void initState() {
    super.initState();
    TpvFacturacionService().obtenerConfig(widget.empresaId).then((cfg) {
      if (mounted) {
        setState(() {
          _mostrarPropina = cfg.mostrarPropina;
          _descuentoMaxPct = cfg.descuentoMaximoPct;
          _propinaSugerida = cfg.porcentajesPropina
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .where((n) => n > 0)
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _entregadoCtrl, _propinaCtrl, _efectivoMixtoCtrl,
      _tarjetaMixtoCtrl, _nombreFiadoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final esFiado = _metodoPago == 'fiado';

    return Dialog(
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F23),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              _desglose(fmt),
              if (_mostrarPropina) ...[
                const SizedBox(height: 20),
                _propinaPicker(fmt),
              ],
              const SizedBox(height: 20),
              _metodosPago(),
              const SizedBox(height: 16),
              _uiMetodo(fmt),
              if (widget.comensales > 1) _splitBill(fmt),
              const SizedBox(height: 16),
              CuponWidget(
                empresaId: widget.empresaId,
                subtotal: widget.total,
                onCuponChange: (c, d) => setState(() {
                  _cuponAplicado = c;
                  _descuentoCupon = d;
                }),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _procesando ? null : _confirmarCobro,
                style: FilledButton.styleFrom(
                  backgroundColor: esFiado
                      ? const Color(0xFFFFCC00)
                      : const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _procesando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        esFiado
                            ? 'Cobrar después — ${fmt.format(_totalFinal)}'
                            : 'Confirmar pago ${fmt.format(_totalFinal)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFC8).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.point_of_sale, color: Color(0xFF00FFC8)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cobrar',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('${widget.nombreMesa} • ${widget.comensales} personas',
              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13)),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _procesando ? null : () => Navigator.pop(context),
      ),
    ],
  );

  Widget _desglose(NumberFormat fmt) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2139), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      _fila('Subtotal', fmt.format(widget.total)),
      if (_descuentoCupon > 0) ...[
        const SizedBox(height: 8),
        _fila('Descuento cupón', '-${fmt.format(_descuentoCupon)}',
            vc: const Color(0xFFFFCC00)),
      ],
      if (_propina > 0) ...[
        const SizedBox(height: 8),
        _fila('Propina', fmt.format(_propina), vc: const Color(0xFF00FFC8)),
      ],
      const Divider(height: 24, color: Color(0xFF2A2E45)),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('TOTAL',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(fmt.format(_totalFinal),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Color(0xFF00FFC8))),
        ],
      ),
    ]),
  );

  Widget _fila(String l, String v, {Color? vc}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: const TextStyle(color: Color(0xFFB0B3C1))),
      Text(v, style: TextStyle(color: vc ?? Colors.white, fontSize: 16)),
    ],
  );

  Widget _propinaPicker(NumberFormat fmt) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _propinaCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => setState(() => _propina = double.tryParse(v) ?? 0.0),
        style: const TextStyle(color: Colors.white),
        decoration: _deco('Propina (opcional)', '0.00',
            Icons.volunteer_activism, const Color(0xFFFF3296), suf: '€'),
      ),
      const SizedBox(height: 8),
      // Botones rápidos: % configurados + importes fijos
      Wrap(spacing: 8, runSpacing: 4, children: [
        // Porcentajes sugeridos desde config
        ..._propinaSugerida.map((pct) {
          final importe = widget.total * pct / 100;
          return ActionChip(
            label: Text('$pct% (${fmt.format(importe)})'),
            onPressed: () => setState(() {
              _propina = double.parse(importe.toStringAsFixed(2));
              _propinaCtrl.text = _propina.toString();
            }),
            backgroundColor: const Color(0xFF1E2139),
            labelStyle: const TextStyle(color: Color(0xFFFF3296), fontSize: 12),
          );
        }),
        // Importes fijos clásicos
        ...[1.0, 2.0, 5.0].map((v) => ActionChip(
          label: Text('${v.toStringAsFixed(0)} €'),
          onPressed: () => setState(() { _propina = v; _propinaCtrl.text = v.toString(); }),
          backgroundColor: const Color(0xFF1E2139),
          labelStyle: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 12),
        )),
      ]),
    ],
  );

  static const _metodos = [
    ('efectivo', Icons.payments, 'Efectivo', Color(0xFF00FFC8)),
    ('tarjeta', Icons.credit_card, 'Tarjeta', Color(0xFFFF3296)),
    ('bizum', Icons.qr_code, 'QR/Bizum', Color(0xFFFF4678)),
    ('mixto', Icons.call_split, 'Mixto', Color(0xFF00D9FF)),
    ('fiado', Icons.schedule, 'Fiado', Color(0xFFFFCC00)),
  ];

  Widget _metodosPago() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Método de pago',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: _metodos.asMap().entries.expand((e) {
        final (key, icon, label, color) = e.value;
        return [
          Expanded(child: MetodoPagoChip(icono: icon, label: label,
              color: color, seleccionado: _metodoPago == key,
              onTap: () => setState(() => _metodoPago = key))),
          if (e.key < _metodos.length - 1) const SizedBox(width: 6),
        ];
      }).toList()),
    ],
  );

  Widget _uiMetodo(NumberFormat fmt) {
    if (_metodoPago == 'efectivo') return _uiEfectivo(fmt);
    if (_metodoPago == 'mixto') return _uiMixto(fmt);
    if (_metodoPago == 'fiado') return _uiFiado();
    return const SizedBox.shrink();
  }

  Widget _uiEfectivo(NumberFormat fmt) => Column(children: [
    TextField(
      controller: _entregadoCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autofocus: true,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: _deco('Entregado por el cliente', '0.00',
          Icons.euro, const Color(0xFF00FFC8), suf: '€'),
    ),
    const SizedBox(height: 8),
    Wrap(spacing: 8, children: [10.0, 20.0, 50.0, 100.0].map((v) =>
        ActionChip(label: Text('$v €'),
          onPressed: () => setState(() => _entregadoCtrl.text = v.toString()),
          backgroundColor: const Color(0xFF1E2139),
          labelStyle: const TextStyle(color: Color(0xFF00FFC8)))).toList()),
    if (_cambio > 0) ...[
      const SizedBox(height: 12),
      _bannerCambio(fmt),
    ],
  ]);

  Widget _uiMixto(NumberFormat fmt) => Column(children: [
    TextField(
      controller: _efectivoMixtoCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: _deco('Importe en efectivo', '0.00',
          Icons.payments, const Color(0xFF00FFC8), suf: '€'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _tarjetaMixtoCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: _deco('Importe en tarjeta', '0.00',
          Icons.credit_card, const Color(0xFFFF3296), suf: '€'),
    ),
    const SizedBox(height: 10),
    if (_saldoPendienteMixto > 0)
      _banner('Pendiente', fmt.format(_saldoPendienteMixto),
          const Color(0xFFFF4678))
    else
      const Row(children: [
        Icon(Icons.check_circle, color: Color(0xFF00FFC8), size: 16),
        SizedBox(width: 6),
        Text('Cubierto', style: TextStyle(color: Color(0xFF00FFC8), fontSize: 13)),
      ]),
  ]);

  Widget _uiFiado() => Column(children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.5)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: Color(0xFFFFCC00), size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text('El cobro quedará registrado como pendiente.',
              style: TextStyle(color: Color(0xFFFFCC00), fontSize: 13)),
        ),
      ]),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nombreFiadoCtrl,
      style: const TextStyle(color: Colors.white),
      decoration: _deco('Nombre del cliente (opcional)', 'Ej: Juan García',
          Icons.person_outline, const Color(0xFFFFCC00)),
    ),
  ]);

  Widget _splitBill(NumberFormat fmt) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.group, color: Color(0xFFB0B3C1), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Dividir en ${widget.comensales} personas',
              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13)),
        ),
        Text(fmt.format(_totalFinal / widget.comensales),
            style: const TextStyle(
                color: Color(0xFF00FFC8),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const Text(' /persona',
            style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 12)),
      ]),
    ),
  );

  Widget _bannerCambio(NumberFormat fmt) => _banner(
      'Cambio a devolver', fmt.format(_cambio), const Color(0xFF00FFC8));

  Widget _banner(String label, String valor, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(valor,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    ),
  );

  InputDecoration _deco(
      String label, String hint, IconData icon, Color ic,
      {String? suf}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFB0B3C1)),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6B6E82)),
      prefixIcon: Icon(icon, color: ic),
      suffixText: suf,
      suffixStyle: const TextStyle(color: Color(0xFFB0B3C1)),
      filled: true,
      fillColor: const Color(0xFF1E2139),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _snack(String msg, {Color bg = Colors.red}) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: bg));

  Future<void> _confirmarCobro() async {
    if (_metodoPago == 'efectivo') {
      final e = double.tryParse(_entregadoCtrl.text) ?? 0.0;
      if (e < _totalFinal) {
        _snack('El efectivo entregado es insuficiente');
        return;
      }
    }
    if (_metodoPago == 'mixto' && _saldoPendienteMixto > 0.009) {
      _snack('Efectivo + tarjeta no cubre el total');
      return;
    }

    final cajaOk =
        await CierreCajaService().hayCajaAbiertaHoy(widget.empresaId);
    if (!mounted) return;
    if (!cajaOk) {
      _snack('No hay caja abierta. Abre la caja antes de cobrar.',
          bg: Colors.red);
      return;
    }

    setState(() => _procesando = true);
    try {
      final efMixto = double.tryParse(_efectivoMixtoCtrl.text) ?? 0.0;
      final tjMixto = double.tryParse(_tarjetaMixtoCtrl.text) ?? 0.0;
      final importesPorMetodo = <String, double>{
        if (_metodoPago == 'mixto') ...{
          if (efMixto > 0) 'efectivo': efMixto,
          if (tjMixto > 0) 'tarjeta': tjMixto,
        } else
          _metodoPago: _totalFinal,
      };
      final params = CobroParams(
        empresaId: widget.empresaId, mesaId: widget.mesaId,
        nombreMesa: widget.nombreMesa, lineas: widget.lineas,
        subtotal: widget.total, totalFinal: _totalFinal,
        propina: _propina, descuentoCupon: _descuentoCupon,
        metodoPago: _metodoPago,
        entregadoEfectivo: double.tryParse(_entregadoCtrl.text) ?? 0.0,
        cambio: _cambio,
        efectivoMixto: efMixto,
        tarjetaMixto: tjMixto,
        nombreFiado: _nombreFiadoCtrl.text.trim(),
        cupon: _cuponAplicado, comensales: widget.comensales,
        importesPorMetodo: importesPorMetodo,
      );

      final result = await guardarCobro(params);
      if (!mounted) return;

      if (!params.esFiado) {
        await imprimirTicket(
          nombreMesa: widget.nombreMesa, lineas: widget.lineas,
          totalFinal: _totalFinal, descuentoCupon: _descuentoCupon,
          propina: _propina, metodoPago: _metodoPago, cambio: _cambio,
        );
        if (!mounted) return;
        await mostrarFacturaTpvSiProcede(context: context,
          empresaId: widget.empresaId, mesaId: widget.mesaId,
          pedido: result.pedido);
      }

      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      m.showSnackBar(SnackBar(
        content: Text(params.esFiado
            ? 'Cobro registrado como fiado'
            : 'Cobro realizado con éxito'),
        backgroundColor: params.esFiado
            ? const Color(0xFFFFCC00)
            : const Color(0xFF00FFC8),
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
}
