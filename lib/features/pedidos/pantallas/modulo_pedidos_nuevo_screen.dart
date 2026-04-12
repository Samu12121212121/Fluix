import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/detalle_pedido_nuevo_screen.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/formulario_nuevo_pedido_screen.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/catalogo_productos_screen.dart';

class ModuloPedidosNuevoScreen extends StatefulWidget {
  final String empresaId;
  const ModuloPedidosNuevoScreen({super.key, required this.empresaId});

  @override
  State<ModuloPedidosNuevoScreen> createState() => _ModuloPedidosNuevoScreenState();
}

class _ModuloPedidosNuevoScreenState extends State<ModuloPedidosNuevoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final PedidosService _svc = PedidosService();
  String _busqueda = '';
  OrigenPedido? _filtroOrigen;
  final TextEditingController _busCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _busCtrl.dispose();
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
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Catálogo de productos',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CatalogoProductosScreen(empresaId: widget.empresaId),
            )),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(text: 'Hoy'),
              Tab(text: 'Esta semana'),
              Tab(text: 'Pendientes'),
              Tab(text: 'En Preparación'),
              Tab(text: 'Listos'),
              Tab(text: 'Todos'),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Pedido>>(
        stream: _svc.pedidosStream(widget.empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = snap.data ?? [];
          final ahora = DateTime.now();
          final hoyNorm = DateTime(ahora.year, ahora.month, ahora.day);
          final finSemana = hoyNorm.add(const Duration(days: 7));

          // "Hoy": pedidos cuya fecha_entrega es hoy, o creados hoy sin fecha_entrega
          final hoy = todos.where((p) {
            final fechaRef = p.fechaEntrega ?? p.fechaCreacion;
            final norm = DateTime(fechaRef.year, fechaRef.month, fechaRef.day);
            return norm == hoyNorm;
          }).toList();

          // "Esta semana": pedidos con fecha_entrega dentro de los próximos 7 días
          // (excluye los de hoy para no duplicar)
          final estaSemana = todos.where((p) {
            final fe = p.fechaEntrega;
            if (fe == null) return false;
            final norm = DateTime(fe.year, fe.month, fe.day);
            return norm.isAfter(hoyNorm) && norm.isBefore(finSemana);
          }).toList()
            ..sort((a, b) => (a.fechaEntrega ?? a.fechaCreacion)
                .compareTo(b.fechaEntrega ?? b.fechaCreacion));

          return Column(
            children: [
              _buildResumenDia(hoy, todos),
              const SizedBox(height: 8),
              _buildBuscador(),
              const SizedBox(height: 4),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildLista(_filtrar(hoy)),
                    _buildListaSemana(_filtrar(estaSemana)),
                    _buildLista(_filtrar(todos.where((p) => p.estado == EstadoPedido.pendiente).toList())),
                    _buildLista(_filtrar(todos.where((p) => p.estado == EstadoPedido.enPreparacion).toList())),
                    _buildLista(_filtrar(todos.where((p) => p.estado == EstadoPedido.listo).toList())),
                    _buildLista(_filtrar(todos)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FormularioNuevoPedidoScreen(empresaId: widget.empresaId),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    ),
    );
  }

  List<Pedido> _filtrar(List<Pedido> pedidos) {
    var resultado = pedidos;
      resultado = resultado.where((p) =>
        p.clienteNombre.toLowerCase().contains(_busqueda) ||
        (p.clienteTelefono?.contains(_busqueda) ?? false) ||
        p.lineas.any((l) => l.productoNombre.toLowerCase().contains(_busqueda))
      ).toList();
    }
    if (_filtroOrigen != null) {
      resultado = resultado.where((p) => p.origen == _filtroOrigen).toList();
    }
    return resultado;
  }

  Widget _buildResumenDia(List<Pedido> hoy, List<Pedido> todos) {
    final ventasHoy = hoy
        .where((p) => p.estado != EstadoPedido.cancelado && p.estadoPago == EstadoPago.pagado)
        .fold<double>(0, (s, p) => s + p.total);
    final pendientesTotales = todos.where((p) => p.estado == EstadoPedido.pendiente).length;
    final enPrep = todos.where((p) => p.estado == EstadoPedido.enPreparacion).length;

    return Container(
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _chipResumen('${hoy.length}', 'Hoy', Colors.white),
          const SizedBox(width: 8),
          _chipResumen('$pendientesTotales', 'Pendientes', Colors.orange[200]!),
          const SizedBox(width: 8),
          _chipResumen('$enPrep', 'En prep.', Colors.purple[200]!),
          const SizedBox(width: 8),
          _chipResumen('${ventasHoy.toStringAsFixed(0)}€', 'Cobrado', Colors.green[200]!),
        ],
      ),
    );
  }

  // Lista agrupada por día para "Esta semana"
  Widget _buildListaSemana(List<Pedido> pedidos) {
    if (pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Sin pedidos programados esta semana',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Los pedidos con fecha de entrega aparecerán aquí',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Agrupar por día
    final Map<String, List<Pedido>> grupos = {};
    for (final p in pedidos) {
      final fe = p.fechaEntrega!;
      final clave = '${fe.year}-${fe.month.toString().padLeft(2,'0')}-${fe.day.toString().padLeft(2,'0')}';
      grupos.putIfAbsent(clave, () => []).add(p);
    }

    final claves = grupos.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: claves.length,
      itemBuilder: (_, i) {
        final clave = claves[i];
        final partes = clave.split('-');
        final fecha = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
        final pedidosDia = grupos[clave]!;
        final ahora = DateTime.now();
        final hoyNorm = DateTime(ahora.year, ahora.month, ahora.day);
        final diff = fecha.difference(hoyNorm).inDays;
        final nombreDia = diff == 1
            ? 'Mañana'
            : diff == 2
                ? 'Pasado mañana'
                : DateFormat('EEEE d \'de\' MMMM', 'es').format(fecha);
        final totalDia = pedidosDia
            .where((p) => p.estado != EstadoPedido.cancelado)
            .fold<double>(0, (s, p) => s + p.total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del día
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombreDia[0].toUpperCase() + nombreDia.substring(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1976D2)),
                    ),
                  ),
                  Text('${pedidosDia.length} pedido${pedidosDia.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text('${totalDia.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1976D2))),
                ],
              ),
            ),
            // Pedidos del día
            ...pedidosDia.map((p) => _tarjetaPedido(p)),
          ],
        );
      },
    );
  }

  Widget _chipResumen(String valor, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _busCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar cliente o producto...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                        _busCtrl.clear(); setState(() => _busqueda = '');
                      })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<OrigenPedido?>(
            icon: Icon(
              Icons.filter_list,
              color: _filtroOrigen != null ? const Color(0xFF1976D2) : Colors.grey,
            ),
            tooltip: 'Filtrar por origen',
            onSelected: (v) => setState(() => _filtroOrigen = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos los orígenes')),
              ...OrigenPedido.values.map((o) => PopupMenuItem(
                value: o,
                child: Row(
                  children: [
                    Icon(_iconoOrigen(o), size: 16),
                    const SizedBox(width: 8),
                    Text(_nombreOrigen(o)),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLista(List<Pedido> pedidos) {
    if (pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Sin pedidos', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      itemCount: pedidos.length,
      itemBuilder: (_, i) => _tarjetaPedido(pedidos[i]),
    );
  }

  Widget _tarjetaPedido(Pedido p) {
    final colorEstado = _colorEstado(p.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: p.estaAtrasado ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetallePedidoNuevoScreen(pedido: p, empresaId: widget.empresaId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorEstado.withValues(alpha: 0.15),
                    child: Text(p.clienteNombre.isNotEmpty ? p.clienteNombre[0].toUpperCase() : '?',
                        style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.clienteNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (p.clienteTelefono != null)
                          Text(p.clienteTelefono!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badgeEstado(p.estado),
                      const SizedBox(height: 4),
                      Text('${p.total.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                    ],
                  ),
                ],
              ),
              const Divider(height: 12),
              // Líneas resumidas
              Text(
                p.lineas.map((l) => '${l.cantidad}x ${l.productoNombre}').join(', '),
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Footer
              Row(
                children: [
                  Icon(_iconoOrigen(p.origen), size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_nombreOrigen(p.origen), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(_iconoPago(p.metodoPago), size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_nombrePago(p.metodoPago), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const Spacer(),
                  if (p.estadoPago == EstadoPago.pagado)
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  if (p.estadoPago == EstadoPago.pagado)
                    Text(' Pagado', style: TextStyle(fontSize: 11, color: Colors.green[700])),
                  const SizedBox(width: 8),
                  if (p.fechaEntrega != null) ...[
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF1976D2)),
                    const SizedBox(width: 3),
                    Text(
                      'Entrega ${DateFormat('HH:mm').format(p.fechaEntrega!)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1976D2), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(DateFormat('HH:mm').format(p.fechaCreacion),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              // Acciones rápidas de estado
              if (_estadosSiguientes(p.estado).isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _estadosSiguientes(p.estado).map((e) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: OutlinedButton(
                      onPressed: () => _svc.cambiarEstado(widget.empresaId, p.id, e, '', 'Admin'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _colorEstado(e)),
                        foregroundColor: _colorEstado(e),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      child: Text(_nombreEstado(e)),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<EstadoPedido> _estadosSiguientes(EstadoPedido actual) => switch (actual) {
    EstadoPedido.pendiente     => [EstadoPedido.confirmado, EstadoPedido.cancelado],
    EstadoPedido.confirmado    => [EstadoPedido.enPreparacion],
    EstadoPedido.enPreparacion => [EstadoPedido.listo],
    EstadoPedido.listo         => [EstadoPedido.entregado],
    EstadoPedido.entregado     => [],
    EstadoPedido.cancelado     => [],
  };

  Widget _badgeEstado(EstadoPedido e) {
    final color = _colorEstado(e);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(_nombreEstado(e), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
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
    EstadoPedido.enPreparacion => 'En prep.',
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

