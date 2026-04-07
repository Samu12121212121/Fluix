import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/features/pedidos/pantallas/formulario_producto_screen.dart';

class DetalleProductoScreen extends StatelessWidget {
  final Producto producto;
  final String empresaId;
  const DetalleProductoScreen({super.key, required this.producto, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = PedidosService();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(producto.nombre),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FormularioProductoScreen(empresaId: empresaId, productoEditar: producto),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmarEliminar(context, svc),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen / placeholder
            if (producto.imagenUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(producto.imagenUrl!, height: 200, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImagen(),
                ),
              )
            else
              _placeholderImagen(),
            const SizedBox(height: 16),

            // Info principal
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20))),
                        if (producto.destacado) const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: producto.activo ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(producto.activo ? 'Activo' : 'Inactivo',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${producto.precio.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                    if (producto.descripcion != null) ...[
                      const SizedBox(height: 8),
                      Text(producto.descripcion!, style: TextStyle(color: Colors.grey[700], height: 1.5)),
                    ],
                    const Divider(height: 20),
                    _fila(Icons.category, 'Categoría', producto.categoria),
                    if (producto.stock != null) _fila(Icons.inventory, 'Stock', '${producto.stock} unidades'),
                    _fila(Icons.calendar_today, 'Creado', _formatFecha(producto.fechaCreacion)),
                  ],
                ),
              ),
            ),

            // Variantes
            if (producto.variantes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Variantes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Divider(height: 16),
                      ...producto.variantes.map((v) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune, color: Color(0xFF1976D2), size: 18),
                        title: Text('${v.nombre} — ${v.tipo}'),
                        trailing: v.precioDiferencia != null
                            ? Text('+${v.precioDiferencia!.toStringAsFixed(2)} €',
                                style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold))
                            : null,
                      )),
                    ],
                  ),
                ),
              ),
            ],

            // Etiquetas
            if (producto.etiquetas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Etiquetas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: producto.etiquetas.map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                          backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                          labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Toggle activo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => svc.toggleActivoProducto(empresaId, producto.id, !producto.activo),
                icon: Icon(producto.activo ? Icons.visibility_off : Icons.visibility),
                label: Text(producto.activo ? 'Desactivar producto' : 'Activar producto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: producto.activo ? Colors.orange : Colors.green,
                  side: BorderSide(color: producto.activo ? Colors.orange : Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImagen() => Container(
    height: 140,
    decoration: BoxDecoration(
      color: const Color(0xFF1976D2).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400])),
  );

  Widget _fila(IconData icono, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icono, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _confirmarEliminar(BuildContext context, PedidosService svc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto.nombre}"? No podrá recuperarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await svc.eliminarProducto(empresaId, producto.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

