import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';

// ── MODELO LOCAL ───────────────────────────────────────────────────────────────

class _LineaTicket {
  final String productoId;
  final String nombre;
  final double precioUnitario;
  int cantidad = 1;

  _LineaTicket({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
  });

  double get subtotal => precioUnitario * cantidad;
}

// ── PANTALLA ───────────────────────────────────────────────────────────────────

class CajaRapidaScreen extends StatefulWidget {
  final String empresaId;
  const CajaRapidaScreen({super.key, required this.empresaId});

  @override
  State<CajaRapidaScreen> createState() => _CajaRapidaScreenState();
}

class _CajaRapidaScreenState extends State<CajaRapidaScreen>
    with SingleTickerProviderStateMixin {
  final PedidosService _svc = PedidosService();

  // Ticket
  final List<_LineaTicket> _lineas = [];
  MetodoPago _metodoPago = MetodoPago.efectivo;
  final _entregaCtrl       = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl  = TextEditingController();
  bool _cobrando = false;

  // Catálogo
  String _busqueda = '';
  String? _categoriaFiltro;
  final _busCtrl = TextEditingController();

  // Tab (móvil)
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _busCtrl.dispose();
    _entregaCtrl.dispose();
    _efectivoMixtoCtrl.dispose();
    _tarjetaMixtoCtrl.dispose();
    super.dispose();
  }

  double get _total => _lineas.fold(0.0, (s, l) => s + l.subtotal);

  // ── AGREGAR PRODUCTO ────────────────────────────────────────────────────────

  void _agregarProducto(Producto p) {
    setState(() {
      final idx = _lineas.indexWhere((l) => l.productoId == p.id);
      if (idx >= 0) {
        _lineas[idx].cantidad++;
      } else {
        _lineas.add(_LineaTicket(
          productoId: p.id,
          nombre: p.nombre,
          precioUnitario: p.precio,
        ));
      }
    });
  }

  // ── COBRAR ─────────────────────────────────────────────────────────────────

  Future<void> _cobrar() async {
    if (_lineas.isEmpty) return;

    // Validar mixto
    if (_metodoPago == MetodoPago.mixto) {
      final ef = double.tryParse(_efectivoMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
      final ta = double.tryParse(_tarjetaMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
      if ((ef + ta - _total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El importe mixto (${_fmt(ef + ta)}) no coincide con el total (${_fmt(_total)})'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cobro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${_fmt(_total)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Método: ${_nombrePago(_metodoPago)}'),
            if (_metodoPago == MetodoPago.efectivo && _entregaCtrl.text.isNotEmpty)
              Text('Cambio: ${_fmt(_cambio)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),  child: const Text('COBRAR')),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _cobrando = true);
    try {
      final lineas = _lineas.map((l) => LineaPedido(
        productoId: l.productoId,
        productoNombre: l.nombre,
        precioUnitario: l.precioUnitario,
        cantidad: l.cantidad,
      )).toList();

      final pedido = await _svc.crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: 'Cliente TPV',
        lineas: lineas,
        origen: OrigenPedido.presencial,
        metodoPago: _metodoPago,
        notasInternas: 'Venta TPV caja rápida',
        usuarioNombre: 'TPV',
      );

      // Marcar como entregado y pagado
      await _svc.cambiarEstado(
          widget.empresaId, pedido.id, EstadoPedido.entregado, '', 'TPV');
      await _svc.cambiarEstadoPago(
          widget.empresaId, pedido.id, EstadoPago.pagado, '', 'TPV');

      if (!mounted) return;

      final ticket = _generarTicketTexto(pedido.id);
      _mostrarDialogoExito(ticket);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cobrar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  double get _cambio {
    final entrega = double.tryParse(_entregaCtrl.text.replaceAll(',', '.')) ?? 0;
    return (entrega - _total).clamp(0, double.infinity);
  }

  void _mostrarDialogoExito(String ticket) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('¡Cobro realizado!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total cobrado: ${_fmt(_total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_metodoPago == MetodoPago.efectivo && _cambio > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Cambio: ${_fmt(_cambio)}',
                    style: const TextStyle(fontSize: 16, color: Colors.green)),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Compartir ticket'),
            onPressed: () => Share.share(ticket, subject: 'Ticket de compra'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _limpiarTicket();
            },
            child: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }

  void _limpiarTicket() {
    setState(() {
      _lineas.clear();
      _metodoPago = MetodoPago.efectivo;
      _entregaCtrl.clear();
      _efectivoMixtoCtrl.clear();
      _tarjetaMixtoCtrl.clear();
    });
  }

  String _generarTicketTexto(String pedidoId) {
    final fmt  = DateFormat('dd/MM/yyyy HH:mm');
    final buf  = StringBuffer();
    buf.writeln('================================');
    buf.writeln('     FLUIX CRM — TICKET');
    buf.writeln('================================');
    buf.writeln('Fecha: ${fmt.format(DateTime.now())}');
    buf.writeln('Ref: ${pedidoId.substring(0, 8).toUpperCase()}');
    buf.writeln('--------------------------------');
    for (final l in _lineas) {
      final nombre = l.nombre.length > 18 ? '${l.nombre.substring(0, 18)}…' : l.nombre.padRight(20);
      buf.writeln('$nombre x${l.cantidad}  ${_fmt(l.subtotal).padLeft(8)}');
    }
    buf.writeln('--------------------------------');
    buf.writeln('TOTAL:${_fmt(_total).padLeft(26)}');
    buf.writeln('Método de pago: ${_nombrePago(_metodoPago)}');
    if (_metodoPago == MetodoPago.efectivo && _cambio > 0) {
      buf.writeln('Cambio:${_fmt(_cambio).padLeft(25)}');
    }
    buf.writeln('================================');
    buf.writeln('        ¡Gracias!');
    buf.writeln('================================');
    return buf.toString();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.point_of_sale, size: 22),
            SizedBox(width: 8),
            Text('Caja Rápida', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_lineas.isNotEmpty)
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Limpiar ticket'),
                    content: const Text('¿Descartar todas las líneas del ticket?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      TextButton(onPressed: () { Navigator.pop(context); _limpiarTicket(); }, child: const Text('Limpiar')),
                    ],
                  ),
                ),
                icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                label: const Text('Limpiar', style: TextStyle(color: Colors.white70)),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: LayoutBuilder(builder: (_, c) {
              if (c.maxWidth >= 600) return const SizedBox.shrink();
              return TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Catálogo'),
                  Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Ticket'),
                      if (_lineas.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_lineas.length}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                  ),
                ],
              );
            }),
          ),
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return Row(
              children: [
                Expanded(flex: 3, child: _buildCatalogo()),
                const VerticalDivider(width: 1),
                SizedBox(width: 340, child: _buildTicket()),
              ],
            );
          }
          return TabBarView(
            controller: _tabCtrl,
            children: [_buildCatalogo(), _buildTicket()],
          );
        }),
      ),
    );
  }

  // ── CATÁLOGO ───────────────────────────────────────────────────────────────

  Widget _buildCatalogo() {
    return StreamBuilder<List<String>>(
      stream: _svc.categoriasStream(widget.empresaId),
      builder: (context, catSnap) {
        final cats = catSnap.data ?? [];
        return StreamBuilder<List<Producto>>(
          stream: _svc.productosStream(widget.empresaId, soloActivos: true),
          builder: (context, snap) {
            final todos = snap.data ?? [];
            final filtrados = todos.where((p) {
              final catOk = _categoriaFiltro == null || p.categoria == _categoriaFiltro;
              final busOk = _busqueda.isEmpty ||
                  p.nombre.toLowerCase().contains(_busqueda.toLowerCase());
              return catOk && busOk;
            }).toList();

            return Column(
              children: [
                // Buscador
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    controller: _busCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              setState(() { _busqueda = ''; _busCtrl.clear(); });
                            })
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                  ),
                ),
                // Categorías
                if (cats.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _chipCategoria('Todas', null),
                        ...cats.map((c) => _chipCategoria(c, c)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                // Grid de productos
                Expanded(
                  child: snap.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : filtrados.isEmpty
                          ? Center(
                              child: Text(
                                _busqueda.isNotEmpty ? 'Sin resultados para "$_busqueda"' : 'No hay productos activos',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: filtrados.length,
                              itemBuilder: (_, i) => _tarjetaProducto(filtrados[i]),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _chipCategoria(String label, String? valor) {
    final sel = _categoriaFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
        selected: sel,
        selectedColor: const Color(0xFF1565C0),
        onSelected: (_) => setState(() => _categoriaFiltro = valor),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _tarjetaProducto(Producto p) {
    final enTicket = _lineas.indexWhere((l) => l.productoId == p.id);
    final cantidad  = enTicket >= 0 ? _lineas[enTicket].cantidad : 0;

    return GestureDetector(
      onTap: () => _agregarProducto(p),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Imagen o ícono
                if (p.thumbnailUrl != null || p.imagenUrl != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        p.thumbnailUrl ?? p.imagenUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Center(child: Icon(Icons.inventory_2, size: 40, color: Color(0xFF1565C0))),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  child: Column(
                    children: [
                      Text(p.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_fmt(p.precio),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            // Badge de cantidad
            if (cantidad > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: Text('$cantidad',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── TICKET ─────────────────────────────────────────────────────────────────

  Widget _buildTicket() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Cabecera ticket
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: Color(0xFF1565C0)),
                SizedBox(width: 6),
                Text('TICKET ACTUAL',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          // Líneas
          Expanded(
            child: _lineas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Toca un producto para añadirlo',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _lineas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _filaTicket(i),
                  ),
          ),
          // Separador + total
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_fmt(_total),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
              ],
            ),
          ),
          const Divider(height: 1),
          // Método de pago
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MÉTODO DE PAGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chipPago(MetodoPago.efectivo, '💵 Efectivo'),
                    const SizedBox(width: 6),
                    _chipPago(MetodoPago.tarjeta, '💳 Tarjeta'),
                    const SizedBox(width: 6),
                    _chipPago(MetodoPago.mixto, '🔀 Mixto'),
                  ],
                ),
                const SizedBox(height: 10),
                // Campos adicionales según método
                if (_metodoPago == MetodoPago.efectivo) ...[
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _entregaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Entrega cliente (€)',
                          prefixIcon: Icon(Icons.money),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () => FocusScope.of(context).unfocus(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_cambio > 0) ...[
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('CAMBIO', style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1)),
                        Text(_fmt(_cambio),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ],
                  ]),
                ] else if (_metodoPago == MetodoPago.mixto) ...[
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _efectivoMixtoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Efectivo (€)',
                          prefixIcon: Icon(Icons.money),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _tarjetaMixtoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tarjeta (€)',
                          prefixIcon: Icon(Icons.credit_card),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () => FocusScope.of(context).unfocus(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Botón cobrar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: (_lineas.isEmpty || _cobrando) ? null : _cobrar,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _cobrando
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.payments_outlined),
                label: Text(
                  _cobrando ? 'Procesando…' : 'COBRAR ${_lineas.isEmpty ? '' : _fmt(_total)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaTicket(int i) {
    final l = _lineas[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${_fmt(l.precioUnitario)} × ${l.cantidad} = ${_fmt(l.subtotal)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          // Controles cantidad
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => setState(() {
              if (l.cantidad > 1) {
                l.cantidad--;
              } else {
                _lineas.removeAt(i);
              }
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.red[400],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('${l.cantidad}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => setState(() => l.cantidad++),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.green[700],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => setState(() => _lineas.removeAt(i)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.grey[500],
          ),
        ],
      ),
    );
  }

  Widget _chipPago(MetodoPago metodo, String label) {
    final sel = _metodoPago == metodo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _metodoPago = metodo;
          _entregaCtrl.clear();
          _efectivoMixtoCtrl.clear();
          _tarjetaMixtoCtrl.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF1565C0) : const Color(0xFFF5F7FA),
            border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.grey[700])),
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  String _fmt(double v) => NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(v);

  String _nombrePago(MetodoPago m) => switch (m) {
    MetodoPago.efectivo => 'Efectivo',
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.mixto    => 'Mixto',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.paypal   => 'PayPal',
  };
}


