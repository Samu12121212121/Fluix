import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';

/// Selector de variante reutilizable para pedidos y citas.
/// Muestra un bottom sheet con las variantes disponibles del producto.
/// Devuelve la variante seleccionada o null si se cancela.
class VarianteSelectorWidget extends StatelessWidget {
  final Producto producto;
  final VarianteProducto? varianteSeleccionada;
  final ValueChanged<VarianteProducto> onSeleccionada;

  const VarianteSelectorWidget({
    super.key,
    required this.producto,
    this.varianteSeleccionada,
    required this.onSeleccionada,
  });

  /// Abre el bottom sheet de selección.
  static Future<VarianteProducto?> mostrar(
    BuildContext context, {
    required Producto producto,
    VarianteProducto? varianteActual,
  }) {
    return showModalBottomSheet<VarianteProducto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VarianteSelectorSheet(
        producto: producto,
        varianteActual: varianteActual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = producto.variantesDisponibles;

    if (!producto.tieneVariantes || disponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        final v = await mostrar(context,
            producto: producto, varianteActual: varianteSeleccionada);
        if (v != null) onSeleccionada(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1976D2).withValues(alpha: 0.04),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                varianteSeleccionada != null
                    ? varianteSeleccionada!.nombre
                    : 'Seleccionar variante',
                style: TextStyle(
                  color: varianteSeleccionada != null
                      ? Colors.black87
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            if (varianteSeleccionada != null)
              Text(
                '${varianteSeleccionada!.precioEfectivo(producto.precio).toStringAsFixed(2)} €',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                    fontSize: 14),
              ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── BOTTOM SHEET INTERNO ──────────────────────────────────────────────────────

class _VarianteSelectorSheet extends StatelessWidget {
  final Producto producto;
  final VarianteProducto? varianteActual;

  const _VarianteSelectorSheet({
    required this.producto,
    this.varianteActual,
  });

  String _duracion(int? mins) {
    if (mins == null) return '';
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? ' · ${h}h ${m}min' : ' · ${h}h';
    }
    return ' · ${mins}min';
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = producto.variantesDisponibles;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona una opción',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: disponibles.length,
              itemBuilder: (_, i) {
                final v = disponibles[i];
                final seleccionada = v.id == varianteActual?.id;
                final precio = v.precioEfectivo(producto.precio);

                return ListTile(
                  selected: seleccionada,
                  selectedTileColor:
                      const Color(0xFF1976D2).withValues(alpha: 0.06),
                  leading: seleccionada
                      ? const CircleAvatar(
                          backgroundColor: Color(0xFF1976D2),
                          radius: 16,
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        )
                      : CircleAvatar(
                          backgroundColor:
                              Colors.grey[100],
                          radius: 16,
                          child: Text(
                            v.nombre[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                  title: Text(
                    v.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: v.sku != null
                      ? Text('SKU: ${v.sku}',
                          style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${precio.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1976D2)),
                      ),
                      if (v.duracionMinutos != null)
                        Text(
                          _duracion(v.duracionMinutos),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, v),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

