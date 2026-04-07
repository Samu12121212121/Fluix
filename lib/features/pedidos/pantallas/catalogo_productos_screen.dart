import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/widgets/producto_imagen_widgets.dart';
import 'package:planeag_flutter/features/pedidos/widgets/importacion_catalogo_sheet.dart';
import 'formulario_producto_screen.dart';

class CatalogoProductosScreen extends StatefulWidget {
  final String empresaId;
  final String? usuarioId;
  const CatalogoProductosScreen(
      {super.key, required this.empresaId, this.usuarioId});

  @override
  State<CatalogoProductosScreen> createState() =>
      _CatalogoProductosScreenState();
}

class _CatalogoProductosScreenState extends State<CatalogoProductosScreen> {
  final PedidosService _svc = PedidosService();
  String _categoriaSeleccionada = 'Todos';
  String _busqueda = '';
  bool _soloActivos = false;
  final TextEditingController _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Catálogo de Productos',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Importar CSV
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar CSV',
            onPressed: () async {
              final ok = await ImportacionCatalogoSheet.mostrar(context,
                  empresaId: widget.empresaId);
              if (ok == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ Importación completada'),
                  backgroundColor: Colors.green,
                ));
              }
            },
          ),
          IconButton(
            icon: Icon(_soloActivos
                ? Icons.visibility
                : Icons.visibility_off),
            tooltip: _soloActivos ? 'Ver todos' : 'Solo activos',
            onPressed: () =>
                setState(() => _soloActivos = !_soloActivos),
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() => _busqueda = '');
                        })
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) =>
                  setState(() => _busqueda = v.toLowerCase()),
            ),
          ),

          // Filtro categorías
          StreamBuilder<List<String>>(
            stream: _svc.categoriasStream(widget.empresaId),
            builder: (context, snap) {
              final cats = ['Todos', ...snap.data ?? []];
              return SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cats.length,
                  itemBuilder: (_, i) {
                    final cat = cats[i];
                    final sel = cat == _categoriaSeleccionada;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: sel,
                        onSelected: (_) => setState(
                            () => _categoriaSeleccionada = cat),
                        selectedColor: const Color(0xFF1976D2),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: _svc.productosStream(widget.empresaId,
                  soloActivos: _soloActivos),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                var productos = snap.data ?? [];
                if (_categoriaSeleccionada != 'Todos') {
                  productos = productos
                      .where((p) =>
                          p.categoria == _categoriaSeleccionada)
                      .toList();
                }
                if (_busqueda.isNotEmpty) {
                  productos = productos
                      .where((p) =>
                          p.nombre
                              .toLowerCase()
                              .contains(_busqueda) ||
                          (p.descripcion
                                  ?.toLowerCase()
                                  .contains(_busqueda) ??
                              false))
                      .toList();
                }
                if (productos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Sin productos',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 16)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ImportacionCatalogoSheet.mostrar(
                                context,
                                empresaId: widget.empresaId);
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Importar CSV'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: productos.length,
                  itemBuilder: (_, i) =>
                      _tarjetaProducto(productos[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_producto',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioProductoScreen(
              empresaId: widget.empresaId,
              usuarioId: widget.usuarioId,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Añadir producto'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _tarjetaProducto(Producto p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            // ── Imagen con iniciales fallback ──────────────────────────
            ProductoImagenDisplay(
              imagenUrl: p.imagenUrl,
              thumbnailUrl: p.thumbnailUrl,
              nombre: p.nombre,
              size: 56,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(p.nombre,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: p.activo
                                  ? Colors.black87
                                  : Colors.grey)),
                    ),
                    if (!p.activo) _badge('Inactivo', Colors.grey),
                    if (p.destacado)
                      const Icon(Icons.star,
                          size: 16, color: Colors.amber),
                  ]),
                  if (p.descripcion != null)
                    Text(p.descripcion!,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    _chip(p.categoria, const Color(0xFF1976D2)),
                    // Badge variantes
                    if (p.tieneVariantes)
                      _chip(
                          '${p.variantesDisponibles.length} variantes',
                          Colors.purple),
                    // Stock
                    if (p.stock != null)
                      _chip('Stock: ${p.stock}',
                          p.stock! > 5 ? Colors.green : Colors.orange),
                    // Duración
                    if (p.duracionMinutos != null)
                      _chip(
                          _formatDuracion(p.duracionMinutos!),
                          Colors.teal),
                  ]),
                ],
              ),
            ),
            // ── Precio ────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(p.textoRangoPrecio,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1976D2))),
                Text('IVA ${p.ivaPorcentaje.toInt()}%',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(children: [
            Switch(
              value: p.activo,
              onChanged: (v) => _svc.toggleActivoProducto(
                  widget.empresaId, p.id, v),
              activeThumbColor: const Color(0xFF4CAF50),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(p.activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                    fontSize: 12,
                    color: p.activo ? Colors.green : Colors.grey)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioProductoScreen(
                      empresaId: widget.empresaId,
                      usuarioId: widget.usuarioId,
                      productoEditar: p,
                    ),
                  )),
              icon: const Icon(Icons.edit, size: 15),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: Size.zero,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmarBorrar(p),
              icon: const Icon(Icons.delete_outline, size: 15),
              label: const Text('Borrar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: Size.zero,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String texto, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500)),
      );

  Widget _badge(String texto, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(texto,
            style: TextStyle(fontSize: 10, color: color)),
      );

  String _formatDuracion(int mins) {
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${mins}min';
  }

  Future<void> _confirmarBorrar(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Borrar producto'),
        content: Text(
            '¿Seguro que quieres borrar "${p.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await _svc.eliminarProducto(widget.empresaId, p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Producto borrado'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }
}

