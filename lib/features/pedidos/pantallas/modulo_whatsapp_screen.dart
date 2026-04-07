// Módulo de gestión de pedidos recibidos por WhatsApp
// Este archivo reexporta el módulo con el nombre correcto para el dashboard

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido_whatsapp.dart';
import 'package:planeag_flutter/services/pedidos_whatsapp_service.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/detalle_pedido_screen.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/formulario_pedido_screen.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/pantalla_chats_bot.dart';

/// Módulo de pedidos recibidos por WhatsApp.
/// Permite gestionar los pedidos que llegan por WhatsApp,
/// cambiar su estado y crear datos de prueba.
class ModuloWhatsAppScreen extends StatefulWidget {
  final String empresaId;
  const ModuloWhatsAppScreen({super.key, required this.empresaId});

  @override
  State<ModuloWhatsAppScreen> createState() => _ModuloWhatsAppScreenState();
}

class _ModuloWhatsAppScreenState extends State<ModuloWhatsAppScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final PedidosWhatsAppService _svc = PedidosWhatsAppService();
  bool _creandoPrueba = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
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
        title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _creandoPrueba
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.science_outlined),
            tooltip: 'Crear datos de prueba',
            onPressed: _creandoPrueba ? null : _crearDatosPrueba,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: '🆕 Nuevos'),
            Tab(text: '⚙️ Proceso'),
            Tab(text: '✅ Listos'),
            Tab(text: '📦 Entregados'),
            Tab(text: '🤖 Bot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildPedidosTab(),
          _buildPedidosTabFiltro(EstadoPedidoWA.nuevo),
          _buildPedidosTabFiltro(EstadoPedidoWA.enProceso),
          _buildPedidosTabFiltro(EstadoPedidoWA.listo),
          _buildPedidosTabFiltro(EstadoPedidoWA.entregado),
          _buildBotTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FormularioPedidoScreen(empresaId: widget.empresaId),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido WA'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildResumen(List<PedidoWhatsApp> pedidos) {
    final nuevos = pedidos.where((p) => p.estado == EstadoPedidoWA.nuevo).length;
    final proceso = pedidos.where((p) => p.estado == EstadoPedidoWA.enProceso).length;
    final listos = pedidos.where((p) => p.estado == EstadoPedidoWA.listo).length;
    final ahora = DateTime.now();
    final hoy = pedidos.where((p) =>
        p.fecha.day == ahora.day &&
        p.fecha.month == ahora.month &&
        p.fecha.year == ahora.year).length;

    return Container(
      color: const Color(0xFF25D366),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _chipResumen('$nuevos', 'Nuevos', Colors.yellow[200]!),
          const SizedBox(width: 8),
          _chipResumen('$proceso', 'En proceso', Colors.orange[200]!),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _buildLista(List<PedidoWhatsApp> pedidos) {
    if (pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Sin pedidos de WhatsApp', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
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

  Widget _tarjetaPedido(PedidoWhatsApp pedido) {
    final colorEstado = _colorEstado(pedido.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorEstado.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetallePedidoScreen(pedido: pedido, empresaId: widget.empresaId),
        )),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                    child: Text(
                      pedido.clienteNombre.isNotEmpty ? pedido.clienteNombre[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido.clienteNombre,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(pedido.clienteTelefono,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _badgeEstado(pedido.estado),
                ],
              ),
              const Divider(height: 16),
              if (pedido.pedidoResumen != null)
                Text(pedido.pedidoResumen!,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))
              else
                Text(
                  pedido.mensajeOriginal,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13, fontStyle: FontStyle.italic),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(DateFormat('dd/MM HH:mm').format(pedido.fecha),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (pedido.items.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_cart, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${pedido.items.length} items',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                  const Spacer(),
                  if (pedido.totalEstimado != null)
                    Text(
                      '${pedido.totalEstimado!.toStringAsFixed(2)} €',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF25D366)),
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

  Widget _accionesRapidas(PedidoWhatsApp pedido) {
    final siguientes = _estadosSiguientes(pedido.estado);
    if (siguientes.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: siguientes.map((e) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: OutlinedButton(
          onPressed: () => _svc.actualizarEstado(widget.empresaId, pedido.id, e),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _colorEstado(e)),
            foregroundColor: _colorEstado(e),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 30),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: Text(_nombreEstado(e)),
        ),
      )).toList(),
    );
  }

  List<EstadoPedidoWA> _estadosSiguientes(EstadoPedidoWA actual) => switch (actual) {
    EstadoPedidoWA.nuevo      => [EstadoPedidoWA.visto, EstadoPedidoWA.enProceso],
    EstadoPedidoWA.visto      => [EstadoPedidoWA.enProceso],
    EstadoPedidoWA.enProceso  => [EstadoPedidoWA.listo],
    EstadoPedidoWA.listo      => [EstadoPedidoWA.entregado],
    EstadoPedidoWA.entregado  => [],
    EstadoPedidoWA.cancelado  => [],
  };

  Widget _badgeEstado(EstadoPedidoWA e) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _colorEstado(e).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(_nombreEstado(e),
        style: TextStyle(color: _colorEstado(e), fontWeight: FontWeight.w600, fontSize: 12)),
  );

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

  Future<void> _crearDatosPrueba() async {
    setState(() => _creandoPrueba = true);
    try {
      await _svc.crearPedidosDePrueba(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pedidos de prueba de WhatsApp creados'),
            backgroundColor: Color(0xFF25D366),
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

  Widget _buildBotTab() {
    return StreamBuilder<List<dynamic>>(
      // Stream simulado — usamos el svc de chats directamente
      stream: Stream.value([]),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header bot
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.smart_toy_outlined,
                        size: 56, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text('Bot WhatsApp',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Responde automáticamente a tus clientes\nlas 24 horas del día',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Funcionalidades
              _featureCard(
                Icons.record_voice_over_outlined,
                'Respuestas automáticas',
                'Detecta palabras clave y responde al instante sin intervención humana.',
                const Color(0xFF25D366),
              ),
              _featureCard(
                Icons.psychology_outlined,
                'Detección de intenciones',
                'Entiende qué quiere el cliente: reservar, pedir, consultar horario...',
                const Color(0xFF1976D2),
              ),
              _featureCard(
                Icons.list_alt_outlined,
                'Catálogo automático',
                'Muestra tus servicios y productos directamente desde la base de datos.',
                const Color(0xFF7B1FA2),
              ),
              _featureCard(
                Icons.support_agent_outlined,
                'Modo agente',
                'Toma el control de la conversación cuando el bot no sea suficiente.',
                const Color(0xFFE65100),
              ),
              const SizedBox(height: 8),

              // Botones de acción
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PantallaChatsBot(empresaId: widget.empresaId),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Ver conversaciones del bot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PantallaChatsBot(
                          empresaId: widget.empresaId),
                    ),
                  ),
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('Configurar respuestas automáticas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _featureCard(
      IconData icono, String titulo, String desc, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: color, size: 22),
        ),
        title: Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(desc,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
    );
  }

  Widget _buildPedidosTab() {
    return StreamBuilder<List<PedidoWhatsApp>>(
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
              child: _buildLista(todos),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPedidosTabFiltro(EstadoPedidoWA estado) {
    return StreamBuilder<List<PedidoWhatsApp>>(
      stream: _svc.pedidosStream(widget.empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final todos = snapshot.data ?? [];
        final pedidosFiltrados = todos.where((p) => p.estado == estado).toList();

        return Column(
          children: [
            _buildResumen(todos),
            Expanded(
              child: _buildLista(pedidosFiltrados),
            ),
          ],
        );
      },
    );
  }
}
