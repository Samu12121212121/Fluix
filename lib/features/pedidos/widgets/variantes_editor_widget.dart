import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:uuid/uuid.dart';

/// Editor completo de variantes en el formulario de producto.
/// Permite añadir, editar y eliminar variantes con precio propio,
/// duración, SKU y toggle de disponibilidad.
class VariantesEditorWidget extends StatefulWidget {
  final List<VarianteProducto> variantes;
  final bool esServicio; // si true, muestra campo duración
  final ValueChanged<List<VarianteProducto>> onCambiadas;

  const VariantesEditorWidget({
    super.key,
    required this.variantes,
    required this.esServicio,
    required this.onCambiadas,
  });

  @override
  State<VariantesEditorWidget> createState() => _VariantesEditorWidgetState();
}

class _VariantesEditorWidgetState extends State<VariantesEditorWidget> {
  List<VarianteProducto> _lista = [];

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.variantes);
  }

  @override
  void didUpdateWidget(VariantesEditorWidget old) {
    super.didUpdateWidget(old);
    if (old.variantes != widget.variantes) {
      setState(() => _lista = List.from(widget.variantes));
    }
  }

  void _notificar() => widget.onCambiadas(List.from(_lista));

  Future<void> _abrirDialog({VarianteProducto? variante, int? indice}) async {
    final result = await showDialog<VarianteProducto>(
      context: context,
      builder: (_) => _DialogVariante(
        variante: variante,
        esServicio: widget.esServicio,
      ),
    );
    if (result == null) return;
    setState(() {
      if (indice != null) {
        _lista[indice] = result;
      } else {
        _lista.add(result);
      }
    });
    _notificar();
  }

  Future<void> _eliminar(int indice) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar variante'),
        content: Text('¿Eliminar "${_lista[indice].nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _lista.removeAt(indice));
    _notificar();
  }

  void _toggleDisponible(int indice) {
    setState(() {
      _lista[indice] = _lista[indice].copyWith(
          disponible: !_lista[indice].disponible);
    });
    _notificar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lista.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Añade al menos una variante con precio',
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ),
            ]),
          ),
        ..._lista.asMap().entries.map((e) => _TarjetaVariante(
              variante: e.value,
              esServicio: widget.esServicio,
              onEditar: () => _abrirDialog(variante: e.value, indice: e.key),
              onEliminar: () => _eliminar(e.key),
              onToggleDisponible: () => _toggleDisponible(e.key),
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _abrirDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir variante'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF1976D2)),
          ),
        ),
      ],
    );
  }
}

// ── TARJETA VARIANTE ──────────────────────────────────────────────────────────

class _TarjetaVariante extends StatelessWidget {
  final VarianteProducto variante;
  final bool esServicio;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onToggleDisponible;

  const _TarjetaVariante({
    required this.variante,
    required this.esServicio,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleDisponible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: variante.disponible
              ? const Color(0xFF1976D2).withValues(alpha: 0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Disponible toggle
              Switch(
              value: variante.disponible,
              onChanged: (_) => onToggleDisponible(),
              activeThumbColor: const Color(0xFF1976D2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variante.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: variante.disponible ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  Row(children: [
                    if (variante.precio != null)
                      _badge('${variante.precio!.toStringAsFixed(2)} €',
                          const Color(0xFF1976D2)),
                    if (esServicio && variante.duracionMinutos != null) ...[
                      const SizedBox(width: 4),
                      _badge('${variante.duracionMinutos} min', Colors.teal),
                    ],
                    if (variante.sku != null) ...[
                      const SizedBox(width: 4),
                      _badge('SKU: ${variante.sku}', Colors.grey),
                    ],
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1976D2)),
              onPressed: onEditar,
              tooltip: 'Editar',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onEliminar,
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(texto,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      );
}

// ── DIÁLOGO AÑADIR/EDITAR VARIANTE ────────────────────────────────────────────

class _DialogVariante extends StatefulWidget {
  final VarianteProducto? variante;
  final bool esServicio;

  const _DialogVariante({this.variante, required this.esServicio});

  @override
  State<_DialogVariante> createState() => _DialogVarianteState();
}

class _DialogVarianteState extends State<_DialogVariante> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _tipoCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _duracionCtrl;
  late TextEditingController _skuCtrl;
  bool _disponible = true;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    final v = widget.variante;
    _nombreCtrl = TextEditingController(text: v?.nombre ?? '');
    _tipoCtrl = TextEditingController(text: v?.tipo ?? '');
    _precioCtrl = TextEditingController(
        text: v?.precio != null ? v!.precio!.toStringAsFixed(2) : '');
    _duracionCtrl = TextEditingController(
        text: v?.duracionMinutos?.toString() ?? '');
    _skuCtrl = TextEditingController(text: v?.sku ?? '');
    _disponible = v?.disponible ?? true;
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _tipoCtrl, _precioCtrl, _duracionCtrl, _skuCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
    if (precio == null || precio < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Introduce un precio válido')));
      return;
    }
    final v = VarianteProducto(
      id: widget.variante?.id ?? _uuid.v4(),
      nombre: _nombreCtrl.text.trim(),
      tipo: _tipoCtrl.text.trim().isEmpty ? 'variante' : _tipoCtrl.text.trim(),
      precio: precio,
      duracionMinutos: int.tryParse(_duracionCtrl.text.trim()),
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      disponible: _disponible,
    );
    Navigator.pop(context, v);
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.variante == null ? 'Nueva variante' : 'Editar variante'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _nombreCtrl,
              decoration: _deco('Nombre de la variante *', Icons.label),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nombre obligatorio' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tipoCtrl,
              decoration: _deco('Tipo (tamaño, sabor...)', Icons.category),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _precioCtrl,
              decoration: _deco('Precio propio (€) *', Icons.euro),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Precio obligatorio';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Precio inválido';
                }
                return null;
              },
            ),
            if (widget.esServicio) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _duracionCtrl,
                decoration: _deco('Duración (minutos)', Icons.timer),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _skuCtrl,
              decoration: _deco('SKU (opcional)', Icons.qr_code),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
              title: const Text('Disponible', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Desactiva para ocultar sin eliminar',
                  style: TextStyle(fontSize: 12)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFF1976D2),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}




