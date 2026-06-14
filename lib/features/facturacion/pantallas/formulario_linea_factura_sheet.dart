import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';

const _kPrimario = Color(0xFF0D47A1);
const _kFondo = Color(0xFFF5F7FA);

Future<LineaFactura?> mostrarLineaSheet(
  BuildContext context, {
  required double ivaDefault,
  required bool esComercio,
  LineaFactura? editar,
}) {
  return showModalBottomSheet<LineaFactura>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LineaSheet(
      ivaDefault: ivaDefault,
      esComercio: esComercio,
      editar: editar,
    ),
  );
}

class _LineaSheet extends StatefulWidget {
  final double ivaDefault;
  final bool esComercio;
  final LineaFactura? editar;

  const _LineaSheet({
    required this.ivaDefault,
    required this.esComercio,
    this.editar,
  });

  @override
  State<_LineaSheet> createState() => _LineaSheetState();
}

class _LineaSheetState extends State<_LineaSheet> {
  late final TextEditingController _desc;
  late final TextEditingController _precio;
  late final TextEditingController _cantidad;
  late final TextEditingController _descuento;
  late final TextEditingController _referencia;
  late double? _iva;
  late String _unidad;
  late double _recargo;
  bool _mostrarErrorIva = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    _desc = TextEditingController(text: e?.descripcion ?? '');
    _precio = TextEditingController(text: e != null ? e.precioUnitario.toStringAsFixed(2) : '');
    _cantidad = TextEditingController(text: e?.cantidad.toString() ?? '1');
    _descuento = TextEditingController(text: e != null && e.descuento > 0 ? e.descuento.toStringAsFixed(0) : '0');
    _referencia = TextEditingController(text: e?.referencia ?? '');
    _iva = e?.porcentajeIva ?? (widget.esComercio ? null : widget.ivaDefault);
    _unidad = e?.unidad.isNotEmpty == true ? e!.unidad : 'ud';
    _recargo = e?.recargoEquivalencia ?? 0;
  }

  @override
  void dispose() {
    _desc.dispose();
    _precio.dispose();
    _cantidad.dispose();
    _descuento.dispose();
    _referencia.dispose();
    super.dispose();
  }

  double get _subtotalPreview {
    final p = double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0;
    final c = int.tryParse(_cantidad.text) ?? 1;
    final d = double.tryParse(_descuento.text.replaceAll(',', '.')) ?? 0;
    final base = p * c * (1 - d / 100);
    return base * (1 + (_iva ?? 0) / 100 + _recargo / 100);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Text(
                  widget.editar == null ? 'Añadir línea' : 'Editar línea',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: Listenable.merge([_precio, _cantidad, _descuento]),
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kPrimario.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_subtotalPreview.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kPrimario, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _input('Descripción *', _desc, hint: 'Producto o servicio prestado'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 3, child: _inputNum('Precio unitario (€) *', _precio)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildUnidadPicker()),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _inputNum('Cantidad', _cantidad, decimal: false)),
              const SizedBox(width: 10),
              Expanded(child: _inputNum('Descuento línea (%)', _descuento)),
            ]),
            const SizedBox(height: 16),
            _buildIvaPicker(),
            if (_mostrarErrorIva)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Selecciona el tipo de IVA', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            _buildRecargoPicker(),
            const SizedBox(height: 12),
            _input('Referencia / SKU (opcional)', _referencia),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  widget.editar == null ? 'Añadir línea' : 'Actualizar línea',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnidadPicker() {
    return DropdownButtonFormField<String>(
      value: _unidad,
      decoration: _deco('Unidad'),
      items: const [
        DropdownMenuItem(value: 'ud', child: Text('ud')),
        DropdownMenuItem(value: 'h', child: Text('h — hora')),
        DropdownMenuItem(value: 'día', child: Text('día')),
        DropdownMenuItem(value: 'mes', child: Text('mes')),
        DropdownMenuItem(value: 'año', child: Text('año')),
        DropdownMenuItem(value: 'kg', child: Text('kg')),
        DropdownMenuItem(value: 'm', child: Text('m')),
        DropdownMenuItem(value: 'm²', child: Text('m²')),
        DropdownMenuItem(value: 'm³', child: Text('m³')),
        DropdownMenuItem(value: 'l', child: Text('l — litro')),
        DropdownMenuItem(value: 'servicio', child: Text('servicio')),
        DropdownMenuItem(value: '', child: Text('— ninguna')),
      ],
      onChanged: (v) => setState(() => _unidad = v ?? 'ud'),
    );
  }

  Widget _buildIvaPicker() {
    final opciones = widget.esComercio
        ? <(String, double, String)>[
            ('4%', 4.0, 'Alimentación básica, medicamentos'),
            ('10%', 10.0, 'Alimentación general'),
            ('21%', 21.0, 'Ropa, electrónica, resto'),
          ]
        : <(String, double, String)>[
            ('0% — Exento', 0.0, ''),
            ('4%', 4.0, ''),
            ('10%', 10.0, ''),
            ('21%', 21.0, ''),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IVA aplicable${widget.esComercio ? ' *' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: opciones.map((item) {
            final selected = _iva == item.$2;
            return Tooltip(
              message: item.$3,
              child: GestureDetector(
                onTap: () => setState(() { _iva = item.$2; _mostrarErrorIva = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? _kPrimario : Colors.grey[100],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selected ? _kPrimario : Colors.grey[300]!),
                  ),
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[700],
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecargoPicker() {
    return DropdownButtonFormField<double>(
      value: _recargo,
      decoration: _deco('Recargo equivalencia'),
      items: const [
        DropdownMenuItem(value: 0.0, child: Text('Sin recargo')),
        DropdownMenuItem(value: 0.5, child: Text('0.5% (IVA 4%)')),
        DropdownMenuItem(value: 1.4, child: Text('1.4% (IVA 10%)')),
        DropdownMenuItem(value: 5.2, child: Text('5.2% (IVA 21%)')),
      ],
      onChanged: (v) => setState(() => _recargo = v ?? 0),
    );
  }

  Widget _input(String label, TextEditingController ctrl, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: TextFormField(
          controller: ctrl,
          decoration: _deco(label, hint: hint),
        ),
      );

  Widget _inputNum(String label, TextEditingController ctrl, {bool decimal = true}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: _deco(label),
      );

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: _kFondo,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kPrimario)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  void _confirmar() {
    if (_desc.text.trim().isEmpty) return;
    final precio = double.tryParse(_precio.text.replaceAll(',', '.'));
    if (precio == null || precio <= 0) return;
    if (_iva == null) { setState(() => _mostrarErrorIva = true); return; }
    Navigator.pop(context, LineaFactura(
      descripcion: _desc.text.trim(),
      precioUnitario: precio,
      cantidad: int.tryParse(_cantidad.text) ?? 1,
      porcentajeIva: _iva!,
      descuento: double.tryParse(_descuento.text.replaceAll(',', '.')) ?? 0,
      recargoEquivalencia: _recargo,
      referencia: _referencia.text.trim().isEmpty ? null : _referencia.text.trim(),
      unidad: _unidad,
    ));
  }
}
