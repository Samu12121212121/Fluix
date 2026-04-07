import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido_whatsapp.dart';
import 'package:planeag_flutter/services/pedidos_whatsapp_service.dart';

class DetallePedidoScreen extends StatefulWidget {
  final PedidoWhatsApp pedido;
  final String empresaId;
  const DetallePedidoScreen({super.key, required this.pedido, required this.empresaId});

  @override
  State<DetallePedidoScreen> createState() => _DetallePedidoScreenState();
}

class _DetallePedidoScreenState extends State<DetallePedidoScreen> {
  final PedidosWhatsAppService _svc = PedidosWhatsAppService();
  final TextEditingController _notasCtrl = TextEditingController();
  late PedidoWhatsApp _pedido;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;
    _notasCtrl.text = _pedido.notasInternas ?? '';
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorEstado = _colorEstado(_pedido.estado);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Pedido de ${_pedido.clienteNombre}'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<EstadoPedidoWA>(
            icon: const Icon(Icons.more_vert),
            onSelected: (estado) async {
              await _svc.actualizarEstado(widget.empresaId, _pedido.id, estado);
              setState(() => _pedido = PedidoWhatsApp(
                id: _pedido.id,
                empresaId: _pedido.empresaId,
                clienteNombre: _pedido.clienteNombre,
                clienteTelefono: _pedido.clienteTelefono,
                mensajeOriginal: _pedido.mensajeOriginal,
                pedidoResumen: _pedido.pedidoResumen,
                estado: estado,
                fecha: _pedido.fecha,
                fechaActualizacion: DateTime.now(),
                notasInternas: _pedido.notasInternas,
                items: _pedido.items,
                totalEstimado: _pedido.totalEstimado,
              ));
            },
            itemBuilder: (_) => EstadoPedidoWA.values.map((e) => PopupMenuItem(
              value: e,
              child: Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: _colorEstado(e)),
                  const SizedBox(width: 10),
                  Text(_nombreEstado(e)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado actual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: colorEstado),
                  const SizedBox(width: 10),
                  Text('Estado: ${_nombreEstado(_pedido.estado)}',
                      style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text(DateFormat('dd/MM HH:mm').format(_pedido.fecha),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Cliente
            _card('Cliente', [
              _fila(Icons.person, 'Nombre', _pedido.clienteNombre),
              _fila(Icons.phone_android, 'Teléfono', _pedido.clienteTelefono),
            ]),
            const SizedBox(height: 12),

            // Mensaje original
            _card('Mensaje WhatsApp', [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble, color: Color(0xFF25D366), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_pedido.mensajeOriginal,
                          style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Items del pedido
            if (_pedido.items.isNotEmpty)
              _cardItems(),
            if (_pedido.items.isNotEmpty) const SizedBox(height: 12),

            // Notas internas
            _card('Notas internas', [
              TextField(
                controller: _notasCtrl,
                decoration: const InputDecoration(
                  hintText: 'Añade notas internas del pedido...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
                onChanged: (_) {},
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    await _svc.actualizarNotasInternas(
                      widget.empresaId, _pedido.id, _notasCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Notas guardadas')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar notas'),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Acciones
            _card('Acciones rápidas', [
              _botonAccion(
                icon: Icons.phone,
                label: 'Llamar cliente',
                color: Colors.blue,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Llamando a ${_pedido.clienteTelefono}')),
                ),
              ),
              const SizedBox(height: 8),
              _botonAccion(
                icon: Icons.delete_outline,
                label: 'Eliminar pedido',
                color: Colors.red,
                onTap: () => _confirmarEliminar(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _cardItems() {
    final total = _pedido.totalEstimado;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Items del pedido', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (total != null)
                  Text('${total.toStringAsFixed(2)} €',
                      style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 16),
            ..._pedido.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${item.cantidad}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF25D366))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
                  if (item.precioUnitario != null)
                    Text('${item.subtotal!.toStringAsFixed(2)} €',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _fila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _botonAccion({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmarEliminar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Eliminar este pedido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _svc.eliminarPedido(widget.empresaId, _pedido.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoPedidoWA e) => switch (e) {
    EstadoPedidoWA.nuevo     => Colors.blue,
    EstadoPedidoWA.visto     => Colors.teal,
    EstadoPedidoWA.enProceso => Colors.orange,
    EstadoPedidoWA.listo     => const Color(0xFF25D366),
    EstadoPedidoWA.entregado => Colors.green[800]!,
    EstadoPedidoWA.cancelado => Colors.red,
  };

  String _nombreEstado(EstadoPedidoWA e) => switch (e) {
    EstadoPedidoWA.nuevo     => 'Nuevo',
    EstadoPedidoWA.visto     => 'Visto',
    EstadoPedidoWA.enProceso => 'En proceso',
    EstadoPedidoWA.listo     => 'Listo',
    EstadoPedidoWA.entregado => 'Entregado',
    EstadoPedidoWA.cancelado => 'Cancelado',
  };
}

