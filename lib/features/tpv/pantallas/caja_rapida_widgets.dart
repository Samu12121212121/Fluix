import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../core/utils/firestore_stream_helpers.dart';
import '../../../services/pedidos_service.dart';
import '../../../widgets/tpv/descuento_linea_widget.dart';
import '../../../widgets/tpv/cupon_input_widget.dart';
import 'caja_rapida_helpers.dart';

// ── WIDGET: Catálogo de productos ─────────────────────────────────────────────

class CatalogoCajaWidget extends StatelessWidget {
  final PedidosService svc;
  final String empresaId;
  final String busqueda;
  final String? categoriaFiltro;
  final TextEditingController busCtrl;
  final List<LineaTicket> lineas;
  final void Function(String v) onBusqueda;
  final void Function(String? v) onCategoria;
  final void Function(Producto p) onAgregarProducto;

  const CatalogoCajaWidget({
    super.key,
    required this.svc,
    required this.empresaId,
    required this.busqueda,
    required this.categoriaFiltro,
    required this.busCtrl,
    required this.lineas,
    required this.onBusqueda,
    required this.onCategoria,
    required this.onAgregarProducto,
  });

  String _fmt(double v) =>
      NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(v);

  @override
  Widget build(BuildContext context) {
    return SafeStreamBuilder<List<String>>(
      stream: svc.categoriasStream(empresaId),
      contexto: 'Categorías TPV',
      builder: (context, catSnap) {
        final cats = catSnap.data ?? [];
        return SafeStreamBuilder<List<Producto>>(
          stream: svc.productosStream(empresaId, soloActivos: true),
          contexto: 'Productos TPV',
          builder: (context, snap) {
            final todos = snap.data ?? [];
            final filtrados = todos.where((p) {
              final catOk = categoriaFiltro == null || p.categoria == categoriaFiltro;
              final busOk = busqueda.isEmpty ||
                  p.nombre.toLowerCase().contains(busqueda.toLowerCase());
              return catOk && busOk;
            }).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: busCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: busqueda.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear),
                            onPressed: () { onBusqueda(''); busCtrl.clear(); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: onBusqueda,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                ),
              ),
              if (cats.isNotEmpty)
                SizedBox(height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chipCat('Todas', null),
                      ...cats.map((c) => _chipCat(c, c)),
                    ],
                  )),
              const SizedBox(height: 4),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : filtrados.isEmpty
                        ? Center(child: Text(
                            busqueda.isNotEmpty
                                ? 'Sin resultados para "$busqueda"'
                                : 'No hay productos activos',
                            style: const TextStyle(color: Colors.grey)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(10),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 160, mainAxisSpacing: 8,
                              crossAxisSpacing: 8, childAspectRatio: 0.85,
                            ),
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => _tarjetaProducto(filtrados[i]),
                          ),
              ),
            ]);
          },
        );
      },
    );
  }

  Widget _chipCat(String label, String? valor) {
    final sel = categoriaFiltro == valor;
    return Padding(padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
        selected: sel, selectedColor: const Color(0xFF1565C0),
        onSelected: (_) => onCategoria(valor),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ));
  }

  Widget _tarjetaProducto(Producto p) {
    final idx = lineas.indexWhere((l) => l.productoId == p.id);
    final qty = idx >= 0 ? lineas[idx].cantidad : 0;
    return GestureDetector(
      onTap: () => onAgregarProducto(p),
      child: Card(elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (p.thumbnailUrl != null || p.imagenUrl != null)
              Expanded(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(p.thumbnailUrl ?? p.imagenUrl!,
                  fit: BoxFit.cover, width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
              ))
            else
              const Expanded(child: Center(
                  child: Icon(Icons.inventory_2, size: 40, color: Color(0xFF1565C0)))),
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(children: [
                Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_fmt(p.precio), style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
              ])),
          ]),
          if (qty > 0) Positioned(top: 6, right: 6,
            child: Container(padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: Text('$qty', style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }
}

// ── WIDGET: Panel ticket ──────────────────────────────────────────────────────

class TicketPanelWidget extends StatelessWidget {
  final List<LineaTicket> lineas;
  final MetodoPago metodoPago;
  final double total;
  final double totalBruto;
  final double cambio;
  final double descuentoCupon;
  final bool cobrando;
  final String empresaId;
  final TextEditingController entregaCtrl;
  final TextEditingController efectivoMixtoCtrl;
  final TextEditingController tarjetaMixtoCtrl;
  final VoidCallback onCobrar;
  final void Function(MetodoPago m) onMetodoPago;
  final void Function(int i, bool bajar) onCantidad;
  final void Function(int i) onEliminar;
  final void Function(int i, double importe) onDescuentoLinea;
  final void Function(double desc) onCuponAplicado;
  final VoidCallback onCuponRetirado;
  final String Function(double) fmt;

  const TicketPanelWidget({
    super.key,
    required this.lineas,
    required this.metodoPago,
    required this.total,
    required this.totalBruto,
    required this.cambio,
    required this.descuentoCupon,
    required this.cobrando,
    required this.empresaId,
    required this.entregaCtrl,
    required this.efectivoMixtoCtrl,
    required this.tarjetaMixtoCtrl,
    required this.onCobrar,
    required this.onMetodoPago,
    required this.onCantidad,
    required this.onEliminar,
    required this.onDescuentoLinea,
    required this.onCuponAplicado,
    required this.onCuponRetirado,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: const Row(children: [
            Icon(Icons.receipt_long, size: 18, color: Color(0xFF1565C0)),
            SizedBox(width: 6),
            Text('TICKET ACTUAL',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
        Expanded(
          child: lineas.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Toca un producto para añadirlo',
                      style: TextStyle(color: Colors.grey[400])),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: lineas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) => _filaTicket(context, i),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(fmt(total), style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            ]),
            if (descuentoCupon > 0)
              Text('Descuento cupón: -${fmt(descuentoCupon)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                  textAlign: TextAlign.right),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MÉTODO DE PAGO', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: [
              _chipPago(MetodoPago.efectivo, '💵 Efectivo'),
              const SizedBox(width: 6),
              _chipPago(MetodoPago.tarjeta, '💳 Tarjeta'),
              const SizedBox(width: 6),
              _chipPago(MetodoPago.mixto, '🔀 Mixto'),
            ]),
            const SizedBox(height: 10),
            if (metodoPago == MetodoPago.efectivo) ...[
              Row(children: [
                Expanded(child: TextField(
                  controller: entregaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Entrega cliente (€)', prefixIcon: Icon(Icons.money),
                    border: OutlineInputBorder(), isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                )),
                if (cambio > 0) ...[
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('CAMBIO', style: TextStyle(
                        fontSize: 11, color: Colors.grey, letterSpacing: 1)),
                    Text(fmt(cambio), style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
                ],
              ]),
            ] else if (metodoPago == MetodoPago.mixto) ...[
              Row(children: [
                Expanded(child: TextField(
                  controller: efectivoMixtoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Efectivo (€)', prefixIcon: Icon(Icons.money),
                    border: OutlineInputBorder(), isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: tarjetaMixtoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tarjeta (€)', prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(), isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                )),
              ]),
            ],
            const SizedBox(height: 12),
          ]),
        ),
        if (lineas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CuponInputWidget(
              empresaId: empresaId, totalBase: totalBruto,
              onAplicado: (_, desc) => onCuponAplicado(desc),
              onRetirar: onCuponRetirado,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: (lineas.isEmpty || cobrando) ? null : onCobrar,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: cobrando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.payments_outlined),
              label: Text(
                cobrando ? 'Procesando…' : 'COBRAR ${lineas.isEmpty ? '' : fmt(total)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _filaTicket(BuildContext context, int i) {
    final l = lineas[i];
    final tieneDesc = l.descuentoImporte > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            tieneDesc
                ? '${fmt(l.precioUnitario - l.descuentoImporte)} × ${l.cantidad} = ${fmt(l.subtotal)}'
                : '${fmt(l.precioUnitario)} × ${l.cantidad} = ${fmt(l.subtotal)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (tieneDesc)
            Text('-${fmt(l.descuentoImporte)} dto.',
                style: const TextStyle(fontSize: 11, color: Colors.green)),
        ])),
        IconButton(
          icon: Icon(Icons.discount, size: 18,
              color: tieneDesc ? Colors.green[700] : Colors.grey[400]),
          tooltip: 'Descuento línea',
          onPressed: () async {
            final r = await DescuentoLineaWidget.mostrar(context,
                nombreProducto: l.nombre, precioOriginal: l.precioUnitario, cantidad: l.cantidad);
            if (r != null) onDescuentoLinea(i, r.importe);
          },
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => onCantidad(i, true),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(), color: Colors.red[400],
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('${l.cantidad}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => onCantidad(i, false),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(), color: Colors.green[700],
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => onEliminar(i),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(), color: Colors.grey[500],
        ),
      ]),
    );
  }

  Widget _chipPago(MetodoPago metodo, String label) {
    final sel = metodoPago == metodo;
    return Expanded(child: GestureDetector(
      onTap: () => onMetodoPago(metodo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1565C0) : const Color(0xFFF5F7FA),
          border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey[700])),
      ),
    ));
  }
}
