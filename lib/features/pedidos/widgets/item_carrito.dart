// lib/features/pedidos/domain/modelos/item_carrito.dart

class ItemCarrito {
  final String productoId;
  final String nombre;
  final String? descripcion;
  final double precioUnitario;
  final double ivaPct; // 10% alimentación, 21% otros
  int cantidad;
  final String? imagenUrl;
  final String? categoria;

  ItemCarrito({
    required this.productoId,
    required this.nombre,
    this.descripcion,
    required this.precioUnitario,
    this.ivaPct = 10,
    this.cantidad = 1,
    this.imagenUrl,
    this.categoria,
  });

  double get subtotal => precioUnitario * cantidad;
  double get ivaTotal => subtotal * (ivaPct / 100);
  double get totalConIva => subtotal + ivaTotal;

  ItemCarrito copyWith({int? cantidad}) => ItemCarrito(
    productoId:     productoId,
    nombre:         nombre,
    descripcion:    descripcion,
    precioUnitario: precioUnitario,
    ivaPct:         ivaPct,
    cantidad:       cantidad ?? this.cantidad,
    imagenUrl:      imagenUrl,
    categoria:      categoria,
  );

  Map<String, dynamic> toJson() => {
    'producto_id':     productoId,
    'nombre':          nombre,
    if (descripcion != null) 'descripcion': descripcion,
    'precio_unitario': precioUnitario,
    'iva_pct':         ivaPct,
    'cantidad':        cantidad,
    'subtotal':        subtotal,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    if (categoria != null) 'categoria':  categoria,
  };

  factory ItemCarrito.fromJson(Map<String, dynamic> j) => ItemCarrito(
    productoId:     j['producto_id']     as String? ?? '',
    nombre:         j['nombre']          as String? ?? '',
    descripcion:    j['descripcion']     as String?,
    precioUnitario: (j['precio_unitario'] as num?)?.toDouble() ?? 0,
    ivaPct:         (j['iva_pct']         as num?)?.toDouble() ?? 10,
    cantidad:       (j['cantidad']        as num?)?.toInt()    ?? 1,
    imagenUrl:      j['imagen_url']      as String?,
    categoria:      j['categoria']       as String?,
  );
}