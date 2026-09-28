import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/detalle_factura_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE PEDIDO — modal bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class DetallePedidoNuevoScreen extends StatefulWidget {
  final Pedido pedido;
  final String empresaId;

  const DetallePedidoNuevoScreen({
    super.key,
    required this.pedido,
    required this.empresaId,
  });

  /// Abre el detalle como popup de la app.
  static Future<void> showPopup(
    BuildContext context,
    Pedido pedido,
    String empresaId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (ctx, scroll) => _PedidoPopupContent(
          pedido: pedido,
          empresaId: empresaId,
          scrollCtrl: scroll,
        ),
      ),
    );
  }

  @override
  State<DetallePedidoNuevoScreen> createState() => _DetallePedidoNuevoScreenState();
}

class _DetallePedidoNuevoScreenState extends State<DetallePedidoNuevoScreen> {
  @override
  Widget build(BuildContext context) {
    // Fallback: pantalla completa (acceso directo via Navigator.push legacy)
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Pedido #${widget.pedido.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: _colorEstado(widget.pedido.estado),
        foregroundColor: Colors.white,
      ),
      body: _PedidoPopupContent(
        pedido: widget.pedido,
        empresaId: widget.empresaId,
        scrollCtrl: ScrollController(),
        insideScaffold: true,
      ),
    );
  }
}

// ── Contenido compartido entre popup y pantalla completa ─────────────────────

class _PedidoPopupContent extends StatefulWidget {
  final Pedido pedido;
  final String empresaId;
  final ScrollController scrollCtrl;
  final bool insideScaffold;

  const _PedidoPopupContent({
    required this.pedido,
    required this.empresaId,
    required this.scrollCtrl,
    this.insideScaffold = false,
  });

  @override
  State<_PedidoPopupContent> createState() => _PedidoPopupContentState();
}

class _PedidoPopupContentState extends State<_PedidoPopupContent> {
  final _svc = PedidosService();
  final _notasCtrl = TextEditingController();
  late Pedido _pedido;
  bool _generandoFactura = false;
  bool _cambiandoEstado = false;
  bool _mostrarNotas = false;
  bool _mostrarHistorial = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _nombre => FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';

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
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.insideScaffold
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        if (!widget.insideScaffold) _handle(),
        _header(),
        Expanded(
          child: ListView(
            controller: widget.scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _estadoRow(),
              const SizedBox(height: 14),
              _productosCard(),
              const SizedBox(height: 12),
              _clienteCard(),
              if (_pedido.notasCliente != null && _pedido.notasCliente!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _notasClienteCard(),
              ],
              const SizedBox(height: 12),
              _facturaCard(),
              const SizedBox(height: 12),
              _notasInternasTile(),
              const SizedBox(height: 8),
              _historialTile(),
            ],
          ),
        ),
      ]),
    );
    return widget.insideScaffold ? content : SafeArea(child: content);
  }

  // ── Handle ────────────────────────────────────────────────────────────────
  Widget _handle() => Container(
    width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
  );

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() {
    final color = _colorEstado(_pedido.estado);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icono estado
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(_iconoEstado(_pedido.estado), color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pedido #${_pedido.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(_pedido.clienteNombre,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Text(DateFormat('dd MMM yyyy · HH:mm', 'es').format(_pedido.fechaCreacion),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_pedido.total.toStringAsFixed(2)} €',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          _badgePago(_pedido.estadoPago),
        ]),
      ]),
    );
  }

  // ── Estado — chips para cambiar ───────────────────────────────────────────
  Widget _estadoRow() {
    final estados = [
      EstadoPedido.pendiente,
      EstadoPedido.confirmado,
      EstadoPedido.enPreparacion,
      EstadoPedido.enviado,
      EstadoPedido.entregado,
      EstadoPedido.cancelado,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Estado del pedido',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF64748B), letterSpacing: .3)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: estados.map((e) {
        final sel = _pedido.estado == e;
        final color = _colorEstado(e);
        return GestureDetector(
          onTap: _cambiandoEstado || sel ? null : () => _cambiarEstado(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? color : color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (sel && _cambiandoEstado)
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: sel ? Colors.white : color))
              else
                Icon(_iconoEstado(e), size: 13,
                    color: sel ? Colors.white : color),
              const SizedBox(width: 5),
              Text(_nombreEstado(e),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : color)),
            ]),
          ),
        );
      }).toList()),
    ]);
  }

  // ── Productos ─────────────────────────────────────────────────────────────
  Widget _productosCard() => _card(
    icon: Icons.inventory_2_rounded,
    color: const Color(0xFF3B82F6),
    titulo: 'Productos (${_pedido.totalItems} items)',
    child: Column(children: [
      ..._pedido.lineas.map((l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('${l.cantidad}x',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6))))),
          const SizedBox(width: 10),
          Expanded(child: Text(l.productoNombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${l.subtotal.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6))),
        ]),
      )),
      const Divider(height: 16),
      // Desglose envío (pedidos web con gastos_envio)
      if (_pedido.gastosEnvio != null && _pedido.gastosEnvio! > 0) ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal productos',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text('${(_pedido.totalProductos ?? _pedido.total - _pedido.gastosEnvio!).toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_shipping_outlined,
                size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              'Envío${_pedido.opcionEnvio != null ? " (${_pedido.opcionEnvio})" : ""}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ]),
          Text('${_pedido.gastosEnvio!.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
        const SizedBox(height: 8),
      ],
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        Text('${_pedido.total.toStringAsFixed(2)} €',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                color: Color(0xFF3B82F6))),
      ]),
    ]),
  );

  // ── Cliente ───────────────────────────────────────────────────────────────
  Widget _clienteCard() => _card(
    icon: Icons.person_rounded,
    color: const Color(0xFF8B5CF6),
    titulo: 'Cliente',
    child: Column(children: [
      _fila('Nombre', _pedido.clienteNombre, Icons.person_outline),
      if (_pedido.clienteTelefono != null && _pedido.clienteTelefono!.isNotEmpty)
        _fila('Teléfono', _pedido.clienteTelefono!, Icons.phone_outlined),
      if (_pedido.clienteCorreo != null && _pedido.clienteCorreo!.isNotEmpty)
        _fila('Correo', _pedido.clienteCorreo!, Icons.email_outlined),
      if (_pedido.direccionEnvio != null && _pedido.direccionEnvio!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.local_shipping_outlined,
              size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          const Text('Envío', style: TextStyle(
              fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _pedido.direccionEnvio!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A)),
            textAlign: TextAlign.right,
          )),
        ]),
      ],
    ]),
  );

  // ── Notas del cliente ─────────────────────────────────────────────────────
  Widget _notasClienteCard() => _card(
    icon: Icons.sticky_note_2_outlined,
    color: const Color(0xFFF59E0B),
    titulo: 'Notas del cliente',
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
      child: Text(_pedido.notasCliente ?? '',
          style: const TextStyle(fontSize: 13, height: 1.5,
              fontStyle: FontStyle.italic)),
    ),
  );

  // ── Factura ───────────────────────────────────────────────────────────────
  Widget _facturaCard() => _card(
    icon: Icons.receipt_long_rounded,
    color: const Color(0xFF10B981),
    titulo: 'Factura',
    child: _pedido.facturaId != null && _pedido.facturaId!.isNotEmpty
        ? Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Factura generada',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981)))),
            TextButton.icon(
              onPressed: () => _abrirFacturaPorId(_pedido.facturaId!),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Ver', style: TextStyle(fontSize: 13)),
            ),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Genera la factura de este pedido automáticamente.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _generandoFactura ? null : _generarOVerFactura,
              icon: _generandoFactura
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt_long, size: 16),
              label: Text(_generandoFactura ? 'Generando...' : 'Generar factura'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
  );

  // ── Notas internas (colapsable) ───────────────────────────────────────────
  Widget _notasInternasTile() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(children: [
      InkWell(
        onTap: () => setState(() => _mostrarNotas = !_mostrarNotas),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Notas internas',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            Icon(_mostrarNotas ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF64748B)),
          ]),
        ),
      ),
      if (_mostrarNotas)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(children: [
            TextField(
              controller: _notasCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Notas privadas del pedido…',
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _svc.actualizarNotasInternas(
                    widget.empresaId, _pedido.id,
                    _notasCtrl.text.trim(), _uid, _nombre,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Notas guardadas'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Guardar notas'),
              ),
            ),
          ]),
        ),
    ]),
  );

  // ── Historial (colapsable) ────────────────────────────────────────────────
  Widget _historialTile() {
    final hist = _pedido.historial.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _mostrarHistorial = !_mostrarHistorial),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(child: Text('Historial (${hist.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Icon(_mostrarHistorial ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF64748B)),
            ]),
          ),
        ),
        if (_mostrarHistorial && hist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: hist.asMap().entries.map((e) {
              final h = e.value;
              final last = e.key == hist.length - 1;
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(width: 9, height: 9,
                      decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                  if (!last) Container(width: 2, height: 32, color: const Color(0xFFE2E8F0)),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.descripcion,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('${h.usuarioNombre} · ${DateFormat('dd/MM/yy HH:mm').format(h.fecha)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ]),
                )),
              ]);
            }).toList()),
          ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _card({required IconData icon, required Color color,
      required String titulo, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _fila(String label, String valor, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      const Spacer(),
      Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A))),
    ]),
  );

  Widget _badgePago(EstadoPago e) {
    final (color, label) = switch (e) {
      EstadoPago.pendiente   => (const Color(0xFFF59E0B), 'Pendiente pago'),
      EstadoPago.pagado      => (const Color(0xFF10B981), 'Pagado'),
      EstadoPago.reembolsado => (const Color(0xFF8B5CF6), 'Reembolsado'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Cambiar estado con email si es "enviado" ──────────────────────────────
  Future<void> _cambiarEstado(EstadoPedido nuevo) async {
    setState(() => _cambiandoEstado = true);
    try {
      await _svc.cambiarEstado(widget.empresaId, _pedido.id, nuevo, _uid, _nombre);
      // El trigger onPedidoEstadoCambiado en Cloud Functions envía el email
      if (mounted) setState(() {
        _pedido = _pedido.copyWith(estado: nuevo);
        _cambiandoEstado = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cambiandoEstado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _generarOVerFactura() async {
    if (_pedido.facturaId != null && _pedido.facturaId!.isNotEmpty) {
      await _abrirFacturaPorId(_pedido.facturaId!);
      return;
    }
    setState(() => _generandoFactura = true);
    try {
      final factura = await _svc.generarFacturaDesdePedido(
        empresaId: widget.empresaId,
        pedidoId: _pedido.id,
        usuarioId: _uid,
        usuarioNombre: _nombre,
      );
      if (!mounted) return;
      setState(() {
        _pedido = _pedido.copyWith(facturaId: factura.id);
        _generandoFactura = false;
      });
      _abrirFactura(factura);
    } catch (e) {
      if (!mounted) return;
      setState(() => _generandoFactura = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
    }
  }

  void _abrirFactura(Factura factura) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetalleFacturaScreen(factura: factura, empresaId: widget.empresaId),
    ));
  }

  Future<void> _abrirFacturaPorId(String facturaId) async {
    try {
      final doc = await FacturacionService().obtenerFacturaDoc(widget.empresaId, facturaId);
      if (!mounted) return;
      _abrirFactura(doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ── Helpers de estado ─────────────────────────────────────────────────────────

Color _colorEstado(EstadoPedido e) => switch (e) {
  EstadoPedido.pendiente     => const Color(0xFFF59E0B),
  EstadoPedido.confirmado    => const Color(0xFF3B82F6),
  EstadoPedido.enPreparacion => const Color(0xFF8B5CF6),
  EstadoPedido.enviado       => const Color(0xFF0EA5E9),
  EstadoPedido.listo         => const Color(0xFF14B8A6),
  EstadoPedido.entregado     => const Color(0xFF10B981),
  EstadoPedido.cancelado     => const Color(0xFFEF4444),
};

IconData _iconoEstado(EstadoPedido e) => switch (e) {
  EstadoPedido.pendiente     => Icons.schedule_rounded,
  EstadoPedido.confirmado    => Icons.check_circle_outline_rounded,
  EstadoPedido.enPreparacion => Icons.build_circle_outlined,
  EstadoPedido.enviado       => Icons.local_shipping_rounded,
  EstadoPedido.listo         => Icons.inventory_rounded,
  EstadoPedido.entregado     => Icons.done_all_rounded,
  EstadoPedido.cancelado     => Icons.cancel_outlined,
};

String _nombreEstado(EstadoPedido e) => switch (e) {
  EstadoPedido.pendiente     => 'Pendiente',
  EstadoPedido.confirmado    => 'Confirmado',
  EstadoPedido.enPreparacion => 'En preparación',
  EstadoPedido.enviado       => 'Enviado',
  EstadoPedido.listo         => 'Listo',
  EstadoPedido.entregado     => 'Entregado',
  EstadoPedido.cancelado     => 'Cancelado',
};
