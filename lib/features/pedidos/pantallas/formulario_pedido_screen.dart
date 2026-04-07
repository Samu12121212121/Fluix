import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido_whatsapp.dart';
import 'package:planeag_flutter/services/pedidos_whatsapp_service.dart';

class FormularioPedidoScreen extends StatefulWidget {
  final String empresaId;
  const FormularioPedidoScreen({super.key, required this.empresaId});

  @override
  State<FormularioPedidoScreen> createState() => _FormularioPedidoScreenState();
}

class _FormularioPedidoScreenState extends State<FormularioPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _resumenCtrl = TextEditingController();
  final _itemNombreCtrl = TextEditingController();
  final _itemPrecioCtrl = TextEditingController();
  final PedidosWhatsAppService _svc = PedidosWhatsAppService();
  List<ItemPedido> _items = [];
  int _cantidadItem = 1;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _mensajeCtrl.dispose();
    _resumenCtrl.dispose();
    _itemNombreCtrl.dispose();
    _itemPrecioCtrl.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (sum, i) => sum + (i.subtotal ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nuevo pedido'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccionCard('Datos del cliente', [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del cliente *', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nombre obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono WhatsApp *', prefixIcon: Icon(Icons.phone_android)),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Teléfono obligatorio' : null,
              ),
            ]),
            const SizedBox(height: 12),
            _seccionCard('Mensaje recibido', [
              TextFormField(
                controller: _mensajeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mensaje original de WhatsApp *',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(padding: EdgeInsets.only(bottom: 48), child: Icon(Icons.chat_bubble)),
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Introduce el mensaje' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _resumenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Resumen del pedido (opcional)',
                  prefixIcon: Icon(Icons.summarize),
                  hintText: '2x Pizza Margarita, 1x Coca-Cola...',
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _seccionCard('Items del pedido', [
              // Lista de items
              if (_items.isNotEmpty) ...[
                ..._items.asMap().entries.map((e) => ListTile(
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${e.value.cantidad}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF25D366))),
                    ),
                  ),
                  title: Text(e.value.nombre, style: const TextStyle(fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (e.value.precioUnitario != null)
                        Text('${e.value.subtotal!.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () => setState(() => _items.removeAt(e.key)),
                      ),
                    ],
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
                Divider(),
                Text('Total: ${_total.toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF25D366))),
                const SizedBox(height: 12),
              ],
              // Formulario nuevo item
              const Text('Añadir item:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cantidad
                  SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        const Text('Cant.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Row(
                          children: [
                            InkWell(
                              onTap: () { if (_cantidadItem > 1) setState(() => _cantidadItem--); },
                              child: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                            ),
                            Expanded(child: Text('$_cantidadItem', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                            InkWell(
                              onTap: () => setState(() => _cantidadItem++),
                              child: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF25D366)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _itemNombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del item', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _itemPrecioCtrl,
                      decoration: const InputDecoration(labelText: 'Precio €', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _agregarItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _seccionCard(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF25D366))),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _agregarItem() {
    final nombre = _itemNombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    final precio = double.tryParse(_itemPrecioCtrl.text.replaceAll(',', '.'));
    setState(() {
      _items.add(ItemPedido(nombre: nombre, cantidad: _cantidadItem, precioUnitario: precio));
      _itemNombreCtrl.clear();
      _itemPrecioCtrl.clear();
      _cantidadItem = 1;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _svc.crearPedidoManual(
        empresaId: widget.empresaId,
        clienteNombre: _nombreCtrl.text.trim(),
        clienteTelefono: _telefonoCtrl.text.trim(),
        mensajeOriginal: _mensajeCtrl.text.trim(),
        pedidoResumen: _resumenCtrl.text.trim().isEmpty ? null : _resumenCtrl.text.trim(),
        items: _items,
        totalEstimado: _items.isNotEmpty ? _total : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}


