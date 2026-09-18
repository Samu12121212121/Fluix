import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/modelos/producto.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/catalogo_web_sync_service.dart';
import 'detalle_pedido_nuevo_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO PEDIDOS — Catálogo · Inventario · Pedidos
// ═════════════════════════════════════════════════════════════════════════════

class ModuloPedidosNuevoScreen extends StatefulWidget {
  final String empresaId;
  const ModuloPedidosNuevoScreen({super.key, required this.empresaId});
  @override
  State<ModuloPedidosNuevoScreen> createState() => _ModuloPedidosNuevoScreenState();
}

class _ModuloPedidosNuevoScreenState extends State<ModuloPedidosNuevoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc = PedidosService();
  bool _dark = false;
  String _busCat = '';
  String _busInv = '';
  String _busPed = '';
  String _filtroCat = 'todas';

  static const _kVerde = Color(0xFF10B981);
  static const _kAzul  = Color(0xFF3B82F6);
  static const _kRojo  = Color(0xFFEF4444);
  static const _kAmbar = Color(0xFFEAB308);

  Color get _bg      => _dark ? const Color(0xFF05060A) : const Color(0xFFF4F6FB);
  Color get _panel   => _dark ? const Color(0xFF0D1117) : Colors.white;
  Color get _border  => _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  Color get _text    => _dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _soft    => _dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _inputBg => _dark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  _StockStatus _stockStatus(Producto p) {
    if (p.stock == null || p.stock! <= 0) return _StockStatus('Sin stock', _kRojo);
    final minimo = p.stockMinimo ?? 10;
    if (p.stock! <= minimo) return _StockStatus('Stock bajo', _kAmbar);
    return _StockStatus('Disponible', const Color(0xFF22C55E));
  }

  Future<void> _enviarPedidoPrueba() async {
    final nombres = ['Ana Torres', 'Carlos Ruiz', 'Lucía Pérez', 'Miguel Sanz'];
    final productos = [
      ('Producto Básico', 12.50),
      ('Pack Premium', 49.99),
      ('Servicio Extra', 25.00),
      ('Artículo Web', 8.75),
    ];
    final idx = DateTime.now().millisecond % 4;
    try {
      await _svc.crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: nombres[idx],
        clienteTelefono: '+34 6${idx}0 ${100 + idx * 111} ${200 + idx * 33}',
        clienteCorreo: '${nombres[idx].toLowerCase().replaceAll(' ', '.')}@test.com',
        lineas: [
          LineaPedido(
            productoId: 'test_${idx}',
            productoNombre: productos[idx].$1,
            precioUnitario: productos[idx].$2,
            cantidad: (idx % 3) + 1,
          ),
        ],
        origen: OrigenPedido.web,
        metodoPago: MetodoPago.tarjeta,
        usuarioNombre: 'Sistema',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📦 Pedido de ${nombres[idx]} enviado'),
            backgroundColor: _kAzul,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kRojo),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          // ── Header estilo empleados (sin back button) ─────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Pedidos y Almacén', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Catálogo · Inventario · Pedidos',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
              const Spacer(),
              if (kDebugMode)
                IconButton(
                  icon: const Icon(Icons.science_outlined, color: Color(0xFF6B7280)),
                  tooltip: 'Pedido de prueba (web)',
                  onPressed: _enviarPedidoPrueba,
                ),
            ]),
          ),
          _buildTabBar(),
          Expanded(child: TabBarView(
            controller: _tabs,
            children: [_buildTabCatalogo(), _buildTabInventario(), _buildTabPedidos()],
          )),
        ]),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: _panel.withValues(alpha: 0.8),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(children: [
      _tabBtn(0, Icons.grid_view_rounded, 'Catálogo'),
      const SizedBox(width: 6),
      _tabBtn(1, Icons.inventory_rounded, 'Inventario'),
      const SizedBox(width: 6),
      _tabBtn(2, Icons.receipt_long_rounded, 'Pedidos'),
    ]),
  );

  Widget _tabBtn(int idx, IconData icon, String label) {
    final sel = _tabs.index == idx;
    return GestureDetector(
      onTap: () { _tabs.animateTo(idx); setState(() {}); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? const LinearGradient(colors: [_kVerde, Color(0xFF059669)]) : null,
          color: sel ? null : _inputBg,
          borderRadius: BorderRadius.circular(10),
          border: sel ? null : Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : _soft),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : _soft)),
        ]),
      ),
    );
  }

  // ── Colección movimientos de stock ───────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _movCol =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('movimientos_stock');

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0 — CATÁLOGO (grid compacto + filtro por categoría)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCatalogo() => StreamBuilder<List<Producto>>(
    stream: _svc.productosStream(widget.empresaId),
    builder: (ctx, snap) {
      final prods = snap.data ?? [];
      final cats  = ['todas', ...{...prods.map((p) => p.categoria)}];
      final filtrados = prods.where((p) {
        final m = p.nombre.toLowerCase().contains(_busCat.toLowerCase()) ||
            p.categoria.toLowerCase().contains(_busCat.toLowerCase());
        final c = _filtroCat == 'todas' || p.categoria == _filtroCat;
        return m && c;
      }).toList();
      final valorTotal = prods.fold(0.0, (s, p) => s + p.precio * (p.stock ?? 0));
      final bajStock   = prods.where((p) => (p.stock ?? 0) > 0 && (p.stock ?? 0) < 10).length;
      final sinStock   = prods.where((p) => (p.stock ?? 0) <= 0).length;

      return Column(children: [
        // KPIs
        Container(color: _bg, padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            _kpi('${prods.length}', 'Productos', _kVerde),  const SizedBox(width: 8),
            _kpi('${valorTotal.toStringAsFixed(0)}€', 'Valor', _kAzul), const SizedBox(width: 8),
            _kpi('$bajStock', 'Bajo stock', _kAmbar), const SizedBox(width: 8),
            _kpi('$sinStock', 'Sin stock', _kRojo),
          ]),
        ),
        // Toolbar
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            Expanded(child: _searchBox(_busCat, 'Buscar producto...', (v) => setState(() => _busCat = v))),
            const SizedBox(width: 8),
            _addBtn('Nuevo', () => _mostrarPopupProducto()),
          ])),
        // Filtro por categoría (chips)
        if (cats.length > 1)
          SizedBox(height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final cat = cats[i];
                final sel = _filtroCat == cat;
                return GestureDetector(
                  onTap: () => setState(() => _filtroCat = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? _kVerde : _inputBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _kVerde : _border),
                    ),
                    child: Text(cat == 'todas' ? 'Todas' : cat,
                      style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        color: sel ? Colors.white : _soft)),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        // Grid de productos — foto grande + nombre/desc/precio claros
        Expanded(child: filtrados.isEmpty
          ? _empty('No hay productos')
          : LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth > 900 ? 5 : c.maxWidth > 600 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, childAspectRatio: 0.68,
                  crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: filtrados.length,
                itemBuilder: (_, i) => _productoCard(filtrados[i]),
              );
            })),
      ]);
    },
  );

  // ── Ficha compacta: foto grande (65% alto) + nombre + precio ──────────────
  Widget _productoCard(Producto p) {
    final st = _stockStatus(p);
    final bajStock = p.stockMinimo != null && p.stock != null && p.stock! <= p.stockMinimo!;
    return GestureDetector(
      onTap: () => _mostrarPopupProducto(p),
      child: Container(
        decoration: BoxDecoration(
          color: _panel, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bajStock ? _kAmbar.withValues(alpha: 0.5) : _border),
          boxShadow: _dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Foto / icono — 60% de la altura
          Expanded(flex: 60, child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: p.thumbnailUrl != null || p.imagenUrl != null
                ? CachedNetworkImage(imageUrl: (p.thumbnailUrl ?? p.imagenUrl)!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _iconoFondo(p))
                : _iconoFondo(p)),
            // Badge estado en esquina superior derecha
            Positioned(top: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (bajStock ? _kAmbar : st.color).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(bajStock ? '⚠ Bajo' : st.label,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)))),
          ])),
          // Info — 40% de la altura
          Expanded(flex: 40, child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Text(p.nombre,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text, height: 1.2),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (p.descripcion != null && p.descripcion!.isNotEmpty)
                Text(p.descripcion!,
                  style: TextStyle(fontSize: 10.5, color: _soft, height: 1.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Text('${p.precio.toStringAsFixed(2)}€',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kVerde)),
                const Spacer(),
                if (p.stock != null)
                  Text('${p.stock}u', style: TextStyle(fontSize: 9.5, color: _soft, fontFamily: 'monospace')),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _iconoFondo(Producto p) => Container(
    color: _kAzul.withValues(alpha: _dark ? 0.14 : 0.08),
    child: Center(child: Text(
      p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _kAzul.withValues(alpha: 0.5)))));


  Widget _iconoLetra(Producto p) => Center(
    child: Text(p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kAzul)));

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — INVENTARIO (lista simple de cards, sin table layout)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabInventario() => StreamBuilder<List<Producto>>(
    stream: _svc.productosStream(widget.empresaId),
    builder: (ctx, snap) {
      final prods = snap.data ?? [];
      final filtrados = prods.where((p) =>
        p.nombre.toLowerCase().contains(_busInv.toLowerCase()) ||
        (p.sku ?? '').toLowerCase().contains(_busInv.toLowerCase())).toList();
      final valorInv = prods.fold(0.0, (s, p) => s + p.precio * (p.stock ?? 0));
      final bajStock  = prods.where((p) => (p.stock ?? 0) > 0 && (p.stock ?? 0) < 10).length;
      final sinStock  = prods.where((p) => (p.stock ?? 0) <= 0).length;

      return Column(children: [
        // KPIs
        Container(color: _bg, padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            _kpi('${valorInv.toStringAsFixed(0)}€', 'Valor inv.', _kVerde),  const SizedBox(width: 8),
            _kpi('$bajStock', 'Bajo mínimo', _kAmbar),                        const SizedBox(width: 8),
            _kpi('$sinStock', 'Sin stock', _kRojo),                           const SizedBox(width: 8),
            _kpi('${prods.length}', 'Productos', _kAzul),
          ]),
        ),
        // Toolbar
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(children: [
            Expanded(child: _searchBox(_busInv, 'Buscar por nombre o SKU...', (v) => setState(() => _busInv = v))),
            const SizedBox(width: 8),
            // Recibir mercancía rápido
            GestureDetector(
              onTap: () => _mostrarPopupMovimiento(tipoInicial: 'entrada'),
              child: Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: _kVerde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: _kVerde.withValues(alpha: 0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.download_rounded, color: _kVerde, size: 15),
                  const SizedBox(width: 4),
                  Text('Recibir', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kVerde)),
                ]))),
            const SizedBox(width: 8),
            _addBtn('Nuevo', () => _mostrarPopupProducto()),
          ])),
        // Lista
        Expanded(child: filtrados.isEmpty
          ? _empty('Sin productos en inventario')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              itemCount: filtrados.length,
              itemBuilder: (_, i) => _invCard(filtrados[i]),
            )),
      ]);
    },
  );

  Widget _invCard(Producto p) {
    final st  = _stockStatus(p);
    final max = p.stock == null ? 1 : (p.stock! > 100 ? p.stock! : 100);
    final pct = p.stock == null ? 0.0 : (p.stock! / max).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _mostrarPopupProducto(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: _dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Row(children: [
          // Icono
          Container(width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
              color: _inputBg, border: Border.all(color: _border)),
            child: p.thumbnailUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(9),
                  child: CachedNetworkImage(imageUrl: p.thumbnailUrl!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _iconoLetra(p)))
              : _iconoLetra(p)),
          const SizedBox(width: 10),
          // Nombre + cat + SKU
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _text),
              overflow: TextOverflow.ellipsis),
            Row(children: [
              Text(p.categoria, style: TextStyle(fontSize: 10.5, color: _soft)),
              if (p.sku != null) ...[
                Text(' · ', style: TextStyle(color: _soft)),
                Text(p.sku!, style: TextStyle(fontSize: 10, color: _soft, fontFamily: 'monospace')),
              ],
            ]),
          ])),
          const SizedBox(width: 10),
          // Stock + barra
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.stock ?? 0} uds',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text)),
            const SizedBox(height: 4),
            SizedBox(width: 70, height: 5,
              child: ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: _border.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation(st.color)))),
          ]),
          const SizedBox(width: 10),
          // Valor
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(p.precio * (p.stock ?? 0)).toStringAsFixed(0)}€',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20), border: Border.all(color: st.color.withValues(alpha: 0.3))),
              child: Text(st.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: st.color))),
          ]),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — PEDIDOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabPedidos() => StreamBuilder<List<Pedido>>(
    stream: _svc.pedidosStream(widget.empresaId),
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final todos = snap.data ?? [];
      final q = _busPed.toLowerCase();
      final filtrados = q.isEmpty
          ? todos
          : todos.where((p) =>
              p.clienteNombre.toLowerCase().contains(q) ||
              p.lineas.any((l) => l.productoNombre.toLowerCase().contains(q))).toList();
      final now = DateTime.now();
      final hoy = todos.where((p) =>
        p.fechaCreacion.year == now.year &&
        p.fechaCreacion.month == now.month &&
        p.fechaCreacion.day == now.day).length;
      final pendientes = todos.where((p) => p.estado == EstadoPedido.pendiente).length;
      final cobrados   = todos.where((p) => p.estadoPago == EstadoPago.pagado).length;

      return Column(children: [
        Container(color: _bg, padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            _kpi('${todos.length}', 'Total', _kAzul),   const SizedBox(width: 8),
            _kpi('$pendientes',     'Pendientes', _kAmbar), const SizedBox(width: 8),
            _kpi('$cobrados',       'Cobrados', _kVerde), const SizedBox(width: 8),
            _kpi('$hoy',            'Hoy', _soft),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: _searchBox(_busPed, 'Buscar por cliente o producto…',
              (v) => setState(() => _busPed = v))),
        Expanded(child: filtrados.isEmpty
          ? _empty('Sin pedidos registrados')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              itemCount: filtrados.length,
              itemBuilder: (_, i) => _pedidoCard(filtrados[i]))),
      ]);
    },
  );

  Widget _pedidoCard(Pedido p) {
    final Color estadoColor;
    final String estadoLabel;
    switch (p.estado) {
      case EstadoPedido.pendiente:     estadoColor = _kAmbar;  estadoLabel = 'Pendiente'; break;
      case EstadoPedido.confirmado:    estadoColor = _kAzul;   estadoLabel = 'Confirmado'; break;
      case EstadoPedido.enPreparacion: estadoColor = const Color(0xFF8B5CF6); estadoLabel = 'En preparación'; break;
      case EstadoPedido.listo:         estadoColor = _kVerde;  estadoLabel = 'Listo'; break;
      case EstadoPedido.entregado:     estadoColor = const Color(0xFF6B7280); estadoLabel = 'Entregado'; break;
      case EstadoPedido.cancelado:     estadoColor = _kRojo;   estadoLabel = 'Cancelado'; break;
    }
    final cobrado = p.estadoPago == EstadoPago.pagado;
    final fecha   = DateFormat('dd/MM HH:mm').format(p.fechaCreacion);
    final resumen = p.lineas.map((l) => '${l.productoNombre} ×${l.cantidad}').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetallePedidoNuevoScreen(pedido: p, empresaId: widget.empresaId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.clienteNombre,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text),
                overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text('${p.total.toStringAsFixed(2)} €',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: cobrado ? _kVerde : _text)),
            ]),
            const SizedBox(height: 6),
            Text(resumen, style: TextStyle(fontSize: 12, color: _soft),
              overflow: TextOverflow.ellipsis, maxLines: 2),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estadoColor.withValues(alpha: 0.35))),
                child: Text(estadoLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: estadoColor))),
              const SizedBox(width: 6),
              if (cobrado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kVerde.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('✓ Cobrado',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kVerde))),
              const Spacer(),
              Text(fecha, style: TextStyle(fontSize: 10, color: _soft, fontFamily: 'monospace')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _movimientoCard(Map<String, dynamic> m) {
    final tipo    = m['tipo'] as String? ?? 'entrada';
    final color   = tipo == 'entrada' ? _kVerde : tipo == 'salida' ? _kRojo : _kAzul;
    final arrow   = tipo == 'entrada' ? '↓' : tipo == 'salida' ? '↑' : '⚙';
    final label   = tipo == 'entrada' ? 'Entrada' : tipo == 'salida' ? 'Salida' : 'Ajuste';
    final cant    = m['cantidad'] as int? ?? 0;
    final prod    = m['producto_nombre'] as String? ?? '—';
    final motivo  = m['motivo'] as String? ?? '';
    final ubic    = m['ubicacion'] as String? ?? '';
    final res     = m['stock_resultante'] as int? ?? 0;
    final ts      = m['fecha'] as Timestamp?;
    final fecha   = ts != null ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
      child: Row(children: [
        Container(width: 4, height: 42,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(prod, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _text),
              overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('$arrow ${tipo == 'ajuste' ? '' : cant} uds',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Text('$arrow $label', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
            if (motivo.isNotEmpty) ...[
              const SizedBox(width: 6),
              Expanded(child: Text(motivo, style: TextStyle(fontSize: 11, color: _soft),
                overflow: TextOverflow.ellipsis)),
            ],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text(fecha, style: TextStyle(fontSize: 10, color: _soft, fontFamily: 'monospace')),
            if (ubic.isNotEmpty) ...[
              Text(' · $ubic', style: TextStyle(fontSize: 10, color: _soft)),
            ],
            const Spacer(),
            Text('→ $res uds', style: TextStyle(fontSize: 10, color: _soft, fontFamily: 'monospace')),
          ]),
        ])),
      ]),
    );
  }

  void _mostrarPopupMovimiento({String tipoInicial = 'entrada', Producto? prodPresel}) {
    String tipoSel = tipoInicial;
    String? productoIdSel = prodPresel?.id;
    final prodCtrl  = TextEditingController(text: prodPresel?.nombre ?? '');
    final cantCtrl  = TextEditingController();
    final motivoCtrl = TextEditingController();
    final ubicCtrl  = TextEditingController(text: prodPresel?.ubicacion ?? '');
    bool guardando  = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: _panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: _border)),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Text('Registrar movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(ctx),
                child: Icon(Icons.close_rounded, color: _soft, size: 20)),
            ]),
            const SizedBox(height: 16),
            // Selector de tipo
            Row(children: ['entrada', 'salida', 'ajuste'].map((tipo) {
              final sel = tipoSel == tipo;
              final color = tipo == 'entrada' ? _kVerde : tipo == 'salida' ? _kRojo : _kAzul;
              final label = tipo == 'entrada' ? '↓ Entrada' : tipo == 'salida' ? '↑ Salida' : '⚙ Ajuste';
              return Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setS(() => tipoSel = tipo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.15) : _inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? color.withValues(alpha: 0.5) : _border)),
                    child: Center(child: Text(label, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? color : _soft)))),
                ),
              ));
            }).toList()),
            const SizedBox(height: 12),
            // Selector de producto desde catálogo
            StreamBuilder<List<Producto>>(
              stream: _svc.productosStream(widget.empresaId),
              builder: (ctx, snap) {
                final prods = snap.data ?? [];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PRODUCTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _soft, letterSpacing: 0.4, fontFamily: 'monospace')),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: productoIdSel != null ? _kVerde : _border)),
                    child: Column(children: [
                      TextField(
                        controller: prodCtrl,
                        onChanged: (v) => setS(() { productoIdSel = null; }),
                        style: TextStyle(color: _text, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Buscar o escribir producto...',
                          hintStyle: TextStyle(color: _soft.withValues(alpha: 0.5), fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: _soft, size: 16),
                          suffixIcon: productoIdSel != null
                            ? Icon(Icons.check_circle, color: _kVerde, size: 18) : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                      if (prodCtrl.text.isNotEmpty && productoIdSel == null && prods.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: ListView(shrinkWrap: true,
                            children: prods.where((p) =>
                              p.nombre.toLowerCase().contains(prodCtrl.text.toLowerCase())).take(5).map((p) =>
                              InkWell(
                                onTap: () => setS(() {
                                  productoIdSel = p.id;
                                  prodCtrl.text  = p.nombre;
                                  if (p.ubicacion != null) ubicCtrl.text = p.ubicacion!;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(children: [
                                    Text(p.nombre, style: TextStyle(fontSize: 13, color: _text)),
                                    const Spacer(),
                                    Text('${p.stock ?? 0}u', style: TextStyle(fontSize: 11, color: _soft)),
                                  ])),
                              )).toList()),
                        ),
                    ]),
                  ),
                ]);
              }),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _popupField(cantCtrl, 'CANTIDAD', '0', isNum: true)),
              const SizedBox(width: 10),
              Expanded(child: _popupField(ubicCtrl, 'UBICACIÓN', 'Almacén A...')),
            ]),
            const SizedBox(height: 10),
            _popupField(motivoCtrl, 'MOTIVO', 'Compra proveedor, venta, ajuste...'),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: guardando ? null : () async {
                final prod = prodCtrl.text.trim();
                if (prod.isEmpty) return;
                final cant = int.tryParse(cantCtrl.text) ?? 0;
                if (cant <= 0) return;
                setS(() => guardando = true);
                try {
                  // Actualizar stock del producto en Firestore (si hay ID)
                  int stockResultante = 0;
                  if (productoIdSel != null) {
                    final prodRef = FirebaseFirestore.instance
                        .collection('empresas').doc(widget.empresaId)
                        .collection('productos').doc(productoIdSel);
                    final snap = await prodRef.get();
                    final stockActual = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
                    final delta = tipoSel == 'entrada' ? cant
                        : tipoSel == 'salida' ? -cant : (cant - stockActual);
                    stockResultante = (stockActual + delta).clamp(0, 999999);
                    await prodRef.update({'stock': stockResultante});
                  }
                  await _movCol.add({
                    'tipo': tipoSel,
                    'producto_nombre': prod,
                    'producto_id': productoIdSel,
                    'cantidad': cant,
                    'motivo': motivoCtrl.text.trim(),
                    'ubicacion': ubicCtrl.text.trim(),
                    'fecha': Timestamp.now(),
                    'stock_resultante': stockResultante,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } finally {
                  if (ctx.mounted) setS(() => guardando = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kVerde, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), elevation: 0),
              child: guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar movimiento', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POPUP — Añadir / Editar producto
  // ═══════════════════════════════════════════════════════════════════════════

  void _mostrarPopupProducto([Producto? prod]) {
    final nombreCtrl   = TextEditingController(text: prod?.nombre ?? '');
    final catCtrl      = TextEditingController(text: prod?.categoria ?? '');
    final precioCtrl   = TextEditingController(text: prod?.precio != null ? prod!.precio.toStringAsFixed(2) : '');
    final costeCtrl    = TextEditingController(text: prod?.precioCoste?.toStringAsFixed(2) ?? '');
    final stockCtrl    = TextEditingController(text: prod?.stock?.toString() ?? '');
    final stockMinCtrl = TextEditingController(text: prod?.stockMinimo?.toString() ?? '');
    final skuCtrl      = TextEditingController(text: prod?.sku ?? '');
    final barrasCtrl   = TextEditingController(text: prod?.codigoBarras ?? '');
    final ubicCtrl     = TextEditingController(text: prod?.ubicacion ?? '');
    final descCtrl     = TextEditingController(text: prod?.descripcion ?? '');
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _border.withValues(alpha: 2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              // Header
              Row(children: [
                Container(width: 34, height: 34,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(colors: [_kVerde.withValues(alpha: 0.18), _kVerde.withValues(alpha: 0.04)]),
                    border: Border.all(color: _kVerde.withValues(alpha: 0.3))),
                  child: const Icon(Icons.inventory_2_rounded, color: _kVerde, size: 17)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(prod == null ? 'Nuevo producto' : 'Editar producto',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
                  Text('Completa la información básica', style: TextStyle(fontSize: 11, color: _soft)),
                ]),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(ctx),
                  child: Container(width: 28, height: 28,
                    decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border)),
                    child: Icon(Icons.close_rounded, size: 15, color: _soft))),
              ]),
              const SizedBox(height: 18),
              // Campo nombre
              _popupField(nombreCtrl, 'NOMBRE DEL PRODUCTO', 'Ej. Auriculares Bluetooth'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _popupField(catCtrl, 'CATEGORÍA', 'Ej. Electrónica')),
                const SizedBox(width: 10),
                Expanded(child: _popupField(precioCtrl, 'PRECIO VENTA (€)', '0.00', isNum: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _popupField(costeCtrl, 'PRECIO COSTE (€)', '0.00', isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _popupField(skuCtrl, 'SKU / REF.', 'Ej. PRD-001')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _popupField(stockCtrl, 'STOCK ACTUAL', '0', isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _popupField(stockMinCtrl, 'STOCK MÍNIMO', '10', isNum: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _popupField(barrasCtrl, 'CÓDIGO DE BARRAS', 'EAN-13...')),
                const SizedBox(width: 10),
                Expanded(child: _popupField(ubicCtrl, 'UBICACIÓN', 'Almacén A, Est. 3')),
              ]),
              const SizedBox(height: 10),
              _popupField(descCtrl, 'DESCRIPCIÓN', 'Breve descripción...', maxLines: 2),
              const SizedBox(height: 18),
              // Botones
              Row(children: [
                if (prod != null)
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _svc.eliminarProducto(widget.empresaId, prod.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: _kRojo)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: _soft),
                  child: const Text('Cancelar')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: guardando ? null : () async {
                    final nombre = nombreCtrl.text.trim();
                    if (nombre.isEmpty) return;
                    setS(() => guardando = true);
                    try {
                      final campos = {
                        'nombre': nombre,
                        'categoria': catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                        'precio': double.tryParse(precioCtrl.text) ?? 0.0,
                        if (costeCtrl.text.trim().isNotEmpty) 'precio_coste': double.tryParse(costeCtrl.text),
                        'stock': int.tryParse(stockCtrl.text),
                        if (stockMinCtrl.text.trim().isNotEmpty) 'stock_minimo': int.tryParse(stockMinCtrl.text),
                        if (skuCtrl.text.trim().isNotEmpty) 'sku': skuCtrl.text.trim(),
                        if (barrasCtrl.text.trim().isNotEmpty) 'codigo_barras': barrasCtrl.text.trim(),
                        if (ubicCtrl.text.trim().isNotEmpty) 'ubicacion': ubicCtrl.text.trim(),
                        if (descCtrl.text.trim().isNotEmpty) 'descripcion': descCtrl.text.trim(),
                      };
                      Producto productoGuardado;
                      if (prod == null) {
                        productoGuardado = await _svc.crearProducto(
                          empresaId: widget.empresaId,
                          nombre: nombre,
                          categoria: campos['categoria'] as String,
                          precio: campos['precio'] as double,
                          stock: campos['stock'] as int?,
                          stockMinimo: campos['stock_minimo'] as int?,
                          precioCoste: campos['precio_coste'] as double?,
                          sku: campos['sku'] as String?,
                          codigoBarras: campos['codigo_barras'] as String?,
                          ubicacion: campos['ubicacion'] as String?,
                          descripcion: campos['descripcion'] as String?,
                        );
                      } else {
                        await _svc.actualizarProducto(widget.empresaId, prod.id, campos);
                        productoGuardado = prod.copyWith(
                          nombre: nombre,
                          categoria: campos['categoria'] as String?,
                          precio: campos['precio'] as double?,
                          descripcion: campos['descripcion'] as String?,
                        );
                      }
                      // Sincronizar automáticamente con secciones web vinculadas (fire & forget)
                      CatalogoWebSyncService()
                          .sincronizarProducto(widget.empresaId, productoGuardado)
                          .ignore();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } finally {
                      if (ctx.mounted) setS(() => guardando = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kVerde, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0),
                  child: guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _popupField(TextEditingController ctrl, String label, String hint,
      {bool isNum = false, int maxLines = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
        color: _soft, letterSpacing: 0.4, fontFamily: 'monospace')),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
        style: TextStyle(color: _text, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: _soft.withValues(alpha: 0.5), fontSize: 13),
          filled: true, fillColor: _inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kVerde, width: 1.5)),
        ),
      ),
    ]);

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _kpi(String num, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border)),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -14, right: -14, child: Container(width: 50, height: 50,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.transparent,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 10)]))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(num, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: _soft), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    ),
  );

  Widget _searchBox(String value, String hint, ValueChanged<String> cb) => Container(
    height: 38,
    decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border)),
    child: TextField(
      onChanged: cb,
      style: TextStyle(color: _text, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: _soft, fontSize: 12.5),
        prefixIcon: Icon(Icons.search, color: _soft, size: 16),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 9)),
    ),
  );

  Widget _addBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kVerde, Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _kVerde.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.add_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );

  Widget _empty(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inbox_outlined, size: 40, color: _soft.withValues(alpha: 0.3)),
    const SizedBox(height: 8),
    Text(msg, style: TextStyle(fontSize: 13, color: _soft)),
  ]));
}

class _StockStatus { final String label; final Color color; const _StockStatus(this.label, this.color); }
