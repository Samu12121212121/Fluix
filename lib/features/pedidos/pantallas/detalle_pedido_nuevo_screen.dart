import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/detalle_factura_screen.dart';

class DetallePedidoNuevoScreen extends StatefulWidget {
  final Pedido pedido;
  final String empresaId;
  const DetallePedidoNuevoScreen({super.key, required this.pedido, required this.empresaId});

  @override
  State<DetallePedidoNuevoScreen> createState() => _DetallePedidoNuevoScreenState();
}

class _DetallePedidoNuevoScreenState extends State<DetallePedidoNuevoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final PedidosService _svc = PedidosService();
  final _notasCtrl = TextEditingController();
  late Pedido _pedido;
  bool _generandoFactura = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _nombre => FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;
    _notasCtrl.text = _pedido.notasInternas ?? '';
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Pedido #${_pedido.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: _colorEstado(_pedido.estado),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<EstadoPedido>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Cambiar estado',
            onSelected: (e) => _cambiarEstado(e),
            itemBuilder: (_) => EstadoPedido.values.map((e) => PopupMenuItem(
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
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Detalle'),
            Tab(text: 'Notas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTabDetalle(),
          _buildTabNotas(),
          _buildTabHistorial(),
        ],
      ),
    );
  }

  Widget _buildTabDetalle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado y pago
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _badge(_nombreEstado(_pedido.estado), _colorEstado(_pedido.estado)),
                      _badgePago(_pedido.estadoPago),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(_iconoOrigen(_pedido.origen), size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text('Origen: ${_nombreOrigen(_pedido.origen)}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const Spacer(),
                      Icon(_iconoPago(_pedido.metodoPago), size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(_nombrePago(_pedido.metodoPago), style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(_pedido.fechaCreacion),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('${_pedido.total.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1976D2))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cliente
          _cardInfo('Cliente', [
            _fila(Icons.person, 'Nombre', _pedido.clienteNombre),
            if (_pedido.clienteTelefono != null) _fila(Icons.phone, 'Teléfono', _pedido.clienteTelefono!),
            if (_pedido.clienteCorreo != null) _fila(Icons.email, 'Correo', _pedido.clienteCorreo!),
          ]),
          const SizedBox(height: 12),

          // Productos
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Productos (${_pedido.totalItems} items)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Divider(height: 16),
                  ..._pedido.lineas.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text('${l.cantidad}x',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1976D2)))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.productoNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (l.variante != null)
                                Text(l.variante!.nombre, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if (l.notasLinea != null)
                                Text(l.notasLinea!, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        Text('${l.subtotal.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                      ],
                    ),
                  )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('${_pedido.total.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1976D2))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Notas del cliente
          if (_pedido.notasCliente != null)
            _cardInfo('Notas del cliente', [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_pedido.notasCliente!, style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5)),
              ),
            ]),
          const SizedBox(height: 12),

          // Cambiar estado de pago
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado del pago', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Divider(height: 16),
                  Row(
                    children: [
                      _badgePago(_pedido.estadoPago),
                      const Spacer(),
                      if (_pedido.estadoPago == EstadoPago.pendiente)
                        ElevatedButton.icon(
                          onPressed: () => _cambiarEstadoPago(EstadoPago.pagado),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Marcar pagado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, foregroundColor: Colors.white,
                          ),
                        )
                      else if (_pedido.estadoPago == EstadoPago.pagado)
                        OutlinedButton.icon(
                          onPressed: () => _cambiarEstadoPago(EstadoPago.reembolsado),
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Reembolsar'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── FACTURA ──────────────────────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Color(0xFF1976D2)),
                      SizedBox(width: 8),
                      Text('Notas internas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Privadas — el cliente no las ve', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Divider(height: 16),
                  TextField(
                    controller: _notasCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe notas internas del pedido...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _svc.actualizarNotasInternas(
                          widget.empresaId, _pedido.id, _notasCtrl.text.trim(), _uid, _nombre,
                        );
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Notas guardadas'), backgroundColor: Colors.green),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                      ),
                      child: const Text('Guardar notas'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNotas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.lock_outline, size: 18, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text('Notas internas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
              const SizedBox(height: 4),
              Text('Privadas — el cliente no las ve', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const Divider(height: 16),
              TextField(
                controller: _notasCtrl,
                decoration: const InputDecoration(
                  hintText: 'Escribe notas internas del pedido...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _svc.actualizarNotasInternas(
                      widget.empresaId, _pedido.id, _notasCtrl.text.trim(), _uid, _nombre,
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Notas guardadas'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar notas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabHistorial() {
    final historial = _pedido.historial.reversed.toList();
    if (historial.isEmpty) {
      return Center(child: Text('Sin historial', style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historial.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final h = historial[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: const Color(0xFF1976D2), shape: BoxShape.circle)),
                if (i < historial.length - 1)
                  Container(width: 2, height: 36, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.descripcion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${h.usuarioNombre} · ${DateFormat('dd/MM/yyyy HH:mm').format(h.fecha)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardInfo(String titulo, List<Widget> children) => Card(
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

  Widget _fila(IconData ic, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(ic, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );

  Widget _badge(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _badgePago(EstadoPago e) {
    final (color, texto) = switch (e) {
      EstadoPago.pendiente   => (Colors.orange, '⏳ Pendiente'),
      EstadoPago.pagado      => (Colors.green, '✅ Pagado'),
      EstadoPago.reembolsado => (Colors.purple, '↩️ Reembolsado'),
    };
    return _badge(texto, color);
  }

  Future<void> _generarOVerFactura() async {
    // Si ya tiene factura, abrir directamente
    if (_pedido.facturaId != null && _pedido.facturaId!.isNotEmpty) {
      _verFactura(_pedido.facturaId!);
      return;
    }

    setState(() => _generandoFactura = true);
    try {
      final facturaId = await _svc.generarFacturaDesdePedido(
        empresaId: widget.empresaId,
        pedidoId: _pedido.id,
        usuarioId: _uid,
        usuarioNombre: _nombre,
      );

      // Actualizar estado local del pedido con facturaId
      setState(() {
        _pedido = Pedido(
          id: _pedido.id, empresaId: _pedido.empresaId,
          clienteNombre: _pedido.clienteNombre, clienteTelefono: _pedido.clienteTelefono,
          clienteCorreo: _pedido.clienteCorreo, lineas: _pedido.lineas, total: _pedido.total,
          estado: _pedido.estado, origen: _pedido.origen, metodoPago: _pedido.metodoPago,
          estadoPago: _pedido.estadoPago, notasInternas: _pedido.notasInternas,
          notasCliente: _pedido.notasCliente, historial: _pedido.historial,
          fechaCreacion: _pedido.fechaCreacion, fechaActualizacion: DateTime.now(),
          tareaAsociadaId: _pedido.tareaAsociadaId, fechaEntrega: _pedido.fechaEntrega,
          facturaId: facturaId,
        );
        _generandoFactura = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('✅ Factura generada correctamente'),
          ]),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 3),
        ));
        _verFactura(facturaId);
      }
    } catch (e) {
      setState(() => _generandoFactura = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error generando factura: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _verFactura(String facturaId) async {
    try {
      final snap = await FacturacionService()
          .obtenerFacturas(widget.empresaId)
          .first;
      final factura = snap.firstWhere((f) => f.id == facturaId,
          orElse: () => throw Exception('Factura no encontrada'));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleFacturaScreen(
            factura: factura,
            empresaId: widget.empresaId,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo abrir la factura: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _cambiarEstado(EstadoPedido nuevo) async {
    await _svc.cambiarEstado(widget.empresaId, _pedido.id, nuevo, _uid, _nombre);
    setState(() {
      _pedido = Pedido(
        id: _pedido.id, empresaId: _pedido.empresaId,
        clienteNombre: _pedido.clienteNombre, clienteTelefono: _pedido.clienteTelefono,
        clienteCorreo: _pedido.clienteCorreo, lineas: _pedido.lineas, total: _pedido.total,
        estado: nuevo, origen: _pedido.origen, metodoPago: _pedido.metodoPago,
        estadoPago: _pedido.estadoPago, notasInternas: _pedido.notasInternas,
        notasCliente: _pedido.notasCliente, historial: _pedido.historial,
        fechaCreacion: _pedido.fechaCreacion, fechaActualizacion: DateTime.now(),
      );
    });
  }

  Future<void> _cambiarEstadoPago(EstadoPago nuevo) async {
    await _svc.cambiarEstadoPago(widget.empresaId, _pedido.id, nuevo, _uid, _nombre);
    setState(() {
      _pedido = Pedido(
        id: _pedido.id, empresaId: _pedido.empresaId,
        clienteNombre: _pedido.clienteNombre, clienteTelefono: _pedido.clienteTelefono,
        clienteCorreo: _pedido.clienteCorreo, lineas: _pedido.lineas, total: _pedido.total,
        estado: _pedido.estado, origen: _pedido.origen, metodoPago: _pedido.metodoPago,
        estadoPago: nuevo, notasInternas: _pedido.notasInternas,
        notasCliente: _pedido.notasCliente, historial: _pedido.historial,
        fechaCreacion: _pedido.fechaCreacion, fechaActualizacion: DateTime.now(),
      );
    });
  }

  Color _colorEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => Colors.orange,
    EstadoPedido.confirmado    => Colors.blue,
    EstadoPedido.enPreparacion => const Color(0xFF7B1FA2),
    EstadoPedido.listo         => Colors.teal,
    EstadoPedido.entregado     => Colors.green[700]!,
    EstadoPedido.cancelado     => Colors.red,
  };

  String _nombreEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => 'Pendiente',
    EstadoPedido.confirmado    => 'Confirmado',
    EstadoPedido.enPreparacion => 'En Preparación',
    EstadoPedido.listo         => 'Listo',
    EstadoPedido.entregado     => 'Entregado',
    EstadoPedido.cancelado     => 'Cancelado',
  };

  String _nombreOrigen(OrigenPedido o) => switch (o) {
    OrigenPedido.web        => 'Web',
    OrigenPedido.app        => 'App',
    OrigenPedido.whatsapp   => 'WhatsApp',
    OrigenPedido.presencial => 'Presencial',
  };

  IconData _iconoOrigen(OrigenPedido o) => switch (o) {
    OrigenPedido.web        => Icons.language,
    OrigenPedido.app        => Icons.phone_android,
    OrigenPedido.whatsapp   => Icons.chat_bubble,
    OrigenPedido.presencial => Icons.store,
  };

  String _nombrePago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.paypal   => 'PayPal',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.efectivo => 'Efectivo',
  };

  IconData _iconoPago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => Icons.credit_card,
    MetodoPago.paypal   => Icons.account_balance_wallet,
    MetodoPago.bizum    => Icons.smartphone,
    MetodoPago.efectivo => Icons.money,
  };
}

