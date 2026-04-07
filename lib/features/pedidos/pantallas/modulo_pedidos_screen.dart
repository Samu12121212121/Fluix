import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';

class ModuloPedidosScreen extends StatefulWidget {
  final String empresaId;
  const ModuloPedidosScreen({super.key, required this.empresaId});

  @override
  State<ModuloPedidosScreen> createState() => _ModuloPedidosScreenState();
}

class _ModuloPedidosScreenState extends State<ModuloPedidosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final PedidosService _svc = PedidosService();
  bool _creandoPrueba = false;

  // Estados que se muestran en las pestañas
  static const _tabEstados = [
    null,                        // Todos
    EstadoPedido.pendiente,
    EstadoPedido.confirmado,
    EstadoPedido.enPreparacion,
    EstadoPedido.listo,
    EstadoPedido.entregado,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabEstados.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _creandoPrueba
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.science_outlined),
            tooltip: 'Crear datos de prueba',
            onPressed: _creandoPrueba ? null : _crearDatosPrueba,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo pedido',
            onPressed: () => _mostrarFormularioNuevoPedido(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: '🕐 Pendiente'),
            Tab(text: '✅ Confirmado'),
            Tab(text: '⚙️ En prep.'),
            Tab(text: '🟢 Listo'),
            Tab(text: '📦 Entregado'),
          ],
        ),
      ),
      body: StreamBuilder<List<Pedido>>(
        stream: _svc.pedidosStream(widget.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final todos = snapshot.data ?? [];

          return Column(
            children: [
              _buildResumen(todos),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: _tabEstados.map((estado) {
                    final filtrados = estado == null
                        ? todos
                        : todos.where((p) => p.estado == estado).toList();
                    return _buildLista(filtrados);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioNuevoPedido(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── RESUMEN ───────────────────────────────────────────────────────────────

  Widget _buildResumen(List<Pedido> pedidos) {
    final pendientes   = pedidos.where((p) => p.estado == EstadoPedido.pendiente).length;
    final enPrep       = pedidos.where((p) => p.estado == EstadoPedido.enPreparacion).length;
    final listos       = pedidos.where((p) => p.estado == EstadoPedido.listo).length;
    final ahora        = DateTime.now();
    final hoy          = pedidos.where((p) =>
        p.fechaCreacion.day == ahora.day &&
        p.fechaCreacion.month == ahora.month &&
        p.fechaCreacion.year == ahora.year).length;

    return Container(
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _chipResumen('$pendientes', 'Pendientes', Colors.yellow[200]!),
          const SizedBox(width: 8),
          _chipResumen('$enPrep', 'En prep.', Colors.orange[200]!),
          const SizedBox(width: 8),
          _chipResumen('$listos', 'Listos', Colors.lightGreen[200]!),
          const SizedBox(width: 8),
          _chipResumen('$hoy', 'Hoy', Colors.white),
        ],
      ),
    );
  }

  Widget _chipResumen(String valor, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(
              color: Colors.white70, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );

  // ── LISTA ─────────────────────────────────────────────────────────────────

  Widget _buildLista(List<Pedido> pedidos) {
    if (pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Sin pedidos en este estado',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pedidos.length,
      itemBuilder: (_, i) => _tarjetaPedido(pedidos[i]),
    );
  }

  // ── TARJETA PEDIDO ────────────────────────────────────────────────────────

  Widget _tarjetaPedido(Pedido pedido) {
    final colorEstado = _colorEstado(pedido.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorEstado.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => _abrirDetalle(pedido),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.12),
                    child: Text(
                      pedido.clienteNombre.isNotEmpty
                          ? pedido.clienteNombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido.clienteNombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        if (pedido.clienteTelefono != null)
                          Text(pedido.clienteTelefono!,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _badgeEstado(pedido.estado),
                ],
              ),
              const Divider(height: 16),

              // Productos
              if (pedido.lineas.isNotEmpty)
                ...pedido.lineas.take(3).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${l.cantidad}x ${l.productoNombre}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${l.subtotal.toStringAsFixed(2)}€',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )),
              if (pedido.lineas.length > 3)
                Text('+${pedido.lineas.length - 3} más...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),

              const SizedBox(height: 8),

              // Footer
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(DateFormat('dd/MM HH:mm').format(pedido.fechaCreacion),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 10),
                  _badgeOrigen(pedido.origen),
                  const Spacer(),
                  Text(
                    '${pedido.total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1976D2)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _accionesRapidas(pedido),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACCIONES RÁPIDAS DE ESTADO ─────────────────────────────────────────────

  Widget _accionesRapidas(Pedido pedido) {
    final siguientes = _estadosSiguientes(pedido.estado);
    if (siguientes.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: siguientes.map((e) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: OutlinedButton(
          onPressed: () => _cambiarEstado(pedido, e),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _colorEstado(e)),
            foregroundColor: _colorEstado(e),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 30),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: Text(_nombreEstado(e)),
        ),
      )).toList(),
    );
  }

  Future<void> _cambiarEstado(Pedido pedido, EstadoPedido nuevo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await _svc.cambiarEstado(
          widget.empresaId, pedido.id, nuevo, uid, 'Agente');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Estado actualizado → ${_nombreEstado(nuevo)}'),
          backgroundColor: _colorEstado(nuevo),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── DETALLE ───────────────────────────────────────────────────────────────

  void _abrirDetalle(Pedido pedido) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DetallePedidoNuevo(
          pedidoId: pedido.id,
          empresaId: widget.empresaId,
          svc: _svc,
        ),
      ),
    );
  }

  // ── NUEVO PEDIDO ──────────────────────────────────────────────────────────

  Future<void> _mostrarFormularioNuevoPedido() async {
    final clienteCtrl = TextEditingController();
    final telCtrl     = TextEditingController();
    OrigenPedido _origen = OrigenPedido.presencial;
    MetodoPago   _metodo = MetodoPago.efectivo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo pedido',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: clienteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<OrigenPedido>(
                      initialValue: _origen,
                      decoration: const InputDecoration(
                          labelText: 'Origen',
                          border: OutlineInputBorder()),
                      items: OrigenPedido.values.map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(_nombreOrigen(o)),
                      )).toList(),
                      onChanged: (v) => setModal(() => _origen = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<MetodoPago>(
                      initialValue: _metodo,
                      decoration: const InputDecoration(
                          labelText: 'Pago',
                          border: OutlineInputBorder()),
                      items: MetodoPago.values.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(_nombreMetodoPago(m)),
                      )).toList(),
                      onChanged: (v) => setModal(() => _metodo = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (clienteCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    await _svc.crearPedido(
                      empresaId: widget.empresaId,
                      clienteNombre: clienteCtrl.text.trim(),
                      clienteTelefono: telCtrl.text.trim().isEmpty
                          ? null : telCtrl.text.trim(),
                      lineas: [],
                      origen: _origen,
                      metodoPago: _metodo,
                      usuarioId: uid,
                      usuarioNombre: 'Agente',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Pedido creado'),
                          backgroundColor: Color(0xFF1976D2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Crear pedido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  List<EstadoPedido> _estadosSiguientes(EstadoPedido actual) => switch (actual) {
    EstadoPedido.pendiente     => [EstadoPedido.confirmado, EstadoPedido.cancelado],
    EstadoPedido.confirmado    => [EstadoPedido.enPreparacion, EstadoPedido.cancelado],
    EstadoPedido.enPreparacion => [EstadoPedido.listo],
    EstadoPedido.listo         => [EstadoPedido.entregado],
    EstadoPedido.entregado     => [],
    EstadoPedido.cancelado     => [],
  };

  Color _colorEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => Colors.orange,
    EstadoPedido.confirmado    => Colors.blue,
    EstadoPedido.enPreparacion => Colors.purple,
    EstadoPedido.listo         => const Color(0xFF25D366),
    EstadoPedido.entregado     => Colors.green[800]!,
    EstadoPedido.cancelado     => Colors.red,
  };

  String _nombreEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => 'Pendiente',
    EstadoPedido.confirmado    => 'Confirmado',
    EstadoPedido.enPreparacion => 'En preparación',
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

  String _nombreMetodoPago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.paypal   => 'PayPal',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.efectivo => 'Efectivo',
  };

  Widget _badgeEstado(EstadoPedido e) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _colorEstado(e).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(_nombreEstado(e),
        style: TextStyle(
            color: _colorEstado(e),
            fontWeight: FontWeight.w600,
            fontSize: 11)),
  );

  Widget _badgeOrigen(OrigenPedido o) {
    final colores = {
      OrigenPedido.web: Colors.blue,
      OrigenPedido.app: Colors.purple,
      OrigenPedido.whatsapp: const Color(0xFF25D366),
      OrigenPedido.presencial: Colors.grey,
    };
    final c = colores[o] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(_nombreOrigen(o),
          style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _crearDatosPrueba() async {
    setState(() => _creandoPrueba = true);
    try {
      await _svc.crearDatosPrueba(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos de prueba creados'),
            backgroundColor: Color(0xFF1976D2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creandoPrueba = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETALLE DE PEDIDO — muestra info completa y permite cambiar estado
// ═══════════════════════════════════════════════════════════════════════════

class _DetallePedidoNuevo extends StatelessWidget {
  final String pedidoId;
  final String empresaId;
  final PedidosService svc;

  const _DetallePedidoNuevo({
    required this.pedidoId,
    required this.empresaId,
    required this.svc,
  });

  Color _colorEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => Colors.orange,
    EstadoPedido.confirmado    => Colors.blue,
    EstadoPedido.enPreparacion => Colors.purple,
    EstadoPedido.listo         => const Color(0xFF25D366),
    EstadoPedido.entregado     => Colors.green[800]!,
    EstadoPedido.cancelado     => Colors.red,
  };

  String _nombreEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente     => 'Pendiente',
    EstadoPedido.confirmado    => 'Confirmado',
    EstadoPedido.enPreparacion => 'En preparación',
    EstadoPedido.listo         => 'Listo',
    EstadoPedido.entregado     => 'Entregado',
    EstadoPedido.cancelado     => 'Cancelado',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pedido>>(
      stream: svc.pedidosStream(empresaId),
      builder: (context, snap) {
        final todos = snap.data ?? [];
        final pedido = todos.isEmpty
            ? null
            : todos.firstWhere(
                (p) => p.id == pedidoId,
                orElse: () => _pedidoVacio(),
              );

        if (pedido == null || snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final colorEstado = _colorEstado(pedido.estado);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Text('Pedido — ${pedido.clienteNombre}'),
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<EstadoPedido>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Cambiar estado',
                onSelected: (nuevo) async {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  await svc.cambiarEstado(empresaId, pedido.id, nuevo, uid, 'Agente');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Estado → ${_nombreEstado(nuevo)}'),
                      backgroundColor: _colorEstado(nuevo),
                    ));
                  }
                },
                itemBuilder: (_) => EstadoPedido.values
                    .where((e) => e != pedido.estado)
                    .map((e) => PopupMenuItem(
                          value: e,
                          child: Row(
                            children: [
                              CircleAvatar(
                                  radius: 6,
                                  backgroundColor: _colorEstado(e)),
                              const SizedBox(width: 10),
                              Text(_nombreEstado(e)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colorEstado.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                          radius: 6, backgroundColor: colorEstado),
                      const SizedBox(width: 10),
                      Text(_nombreEstado(pedido.estado),
                          style: TextStyle(
                              color: colorEstado,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const Spacer(),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(pedido.fechaCreacion),
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cliente
                _seccion(context, 'Cliente', [
                  _fila(Icons.person_outline, 'Nombre',
                      pedido.clienteNombre),
                  if (pedido.clienteTelefono != null)
                    _fila(Icons.phone_outlined, 'Teléfono',
                        pedido.clienteTelefono!),
                  if (pedido.clienteCorreo != null)
                    _fila(Icons.email_outlined, 'Correo',
                        pedido.clienteCorreo!),
                ]),
                const SizedBox(height: 12),

                // Productos
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Productos',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const Divider(),
                        if (pedido.lineas.isEmpty)
                          Text('Sin productos',
                              style: TextStyle(color: Colors.grey[500]))
                        else
                          ...pedido.lineas.map((l) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text('${l.cantidad}x',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1976D2))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(l.productoNombre)),
                                Text(
                                    '${l.subtotal.toStringAsFixed(2)}€',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('TOTAL: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text(
                                '${pedido.total.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF1976D2))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Pago y origen
                _seccion(context, 'Pago y origen', [
                  _fila(Icons.payment_outlined, 'Método de pago',
                      _nombreMetodoPago(pedido.metodoPago)),
                  _fila(Icons.circle_outlined, 'Estado pago',
                      _nombreEstadoPago(pedido.estadoPago)),
                  _fila(Icons.web_outlined, 'Origen',
                      _nombreOrigen(pedido.origen)),
                ]),

                if (pedido.notasCliente != null) ...[
                  const SizedBox(height: 12),
                  _seccion(context, 'Notas del cliente', [
                    Text(pedido.notasCliente!,
                        style: TextStyle(color: Colors.grey[700])),
                  ]),
                ],

                if (pedido.historial.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _seccion(context, 'Historial', [
                    ...pedido.historial.reversed.take(5).map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM HH:mm').format(h.fecha),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(h.descripcion,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _seccion(BuildContext context, String titulo, List<Widget> hijos) =>
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Divider(),
              ...hijos,
            ],
          ),
        ),
      );

  Widget _fila(IconData icono, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icono, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Text('$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Expanded(
          child: Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ],
    ),
  );

  String _nombreMetodoPago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.paypal   => 'PayPal',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.efectivo => 'Efectivo',
  };

  String _nombreEstadoPago(EstadoPago e) => switch (e) {
    EstadoPago.pendiente   => 'Pendiente',
    EstadoPago.pagado      => 'Pagado',
    EstadoPago.reembolsado => 'Reembolsado',
  };

  String _nombreOrigen(OrigenPedido o) => switch (o) {
    OrigenPedido.web        => 'Web',
    OrigenPedido.app        => 'App',
    OrigenPedido.whatsapp   => 'WhatsApp',
    OrigenPedido.presencial => 'Presencial',
  };

  Pedido _pedidoVacio() => Pedido(
    id: '', empresaId: '', clienteNombre: 'Cargando...',
    lineas: [], total: 0,
    estado: EstadoPedido.pendiente,
    origen: OrigenPedido.presencial,
    metodoPago: MetodoPago.efectivo,
    estadoPago: EstadoPago.pendiente,
    historial: [],
    fechaCreacion: DateTime.now(),
  );
}
