import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Producto de tienda online con precio dinámico
class ProductoTienda extends Equatable {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String? stripePriceId; // ID del precio en Stripe
  final String? stripeProductId; // ID del producto en Stripe
  final String? imagenUrl;
  final String? categoria;
  final bool activo;
  final int? stock;
  final bool gestionarStock;
  final DateTime fechaCreacion;
  final DateTime? fechaModificacion;

  const ProductoTienda({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    this.stripePriceId,
    this.stripeProductId,
    this.imagenUrl,
    this.categoria,
    this.activo = true,
    this.stock,
    this.gestionarStock = false,
    required this.fechaCreacion,
    this.fechaModificacion,
  });

  factory ProductoTienda.fromFirestore(Map<String, dynamic> data, String id) {
    return ProductoTienda(
      id: id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      precio: (data['precio'] ?? 0.0).toDouble(),
      stripePriceId: data['stripe_price_id'],
      stripeProductId: data['stripe_product_id'],
      imagenUrl: data['imagen_url'],
      categoria: data['categoria'],
      activo: data['activo'] ?? true,
      stock: data['stock'],
      gestionarStock: data['gestionar_stock'] ?? false,
      fechaCreacion: _parseDate(data['fecha_creacion']),
      fechaModificacion: data['fecha_modificacion'] != null
          ? _parseDate(data['fecha_modificacion'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stripe_price_id': stripePriceId,
      'stripe_product_id': stripeProductId,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'activo': activo,
      'stock': stock,
      'gestionar_stock': gestionarStock,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_modificacion': fechaModificacion != null
          ? Timestamp.fromDate(fechaModificacion)
          : null,
    };
  }

  static DateTime _parseDate(dynamic fecha) {
    if (fecha is Timestamp) return fecha.toDate();
    if (fecha is String) return DateTime.tryParse(fecha) ?? DateTime.now();
    if (fecha is DateTime) return fecha;
    return DateTime.now();
  }

  ProductoTienda copyWith({
    String? nombre,
    String? descripcion,
    double? precio,
    String? stripePriceId,
    String? stripeProductId,
    String? imagenUrl,
    String? categoria,
    bool? activo,
    int? stock,
    bool? gestionarStock,
  }) {
    return ProductoTienda(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      stripeProductId: stripeProductId ?? this.stripeProductId,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      categoria: categoria ?? this.categoria,
      activo: activo ?? this.activo,
      stock: stock ?? this.stock,
      gestionarStock: gestionarStock ?? this.gestionarStock,
      fechaCreacion: fechaCreacion,
      fechaModificacion: DateTime.now(),
    );
  }

  bool get disponible {
    if (!activo) return false;
    if (!gestionarStock) return true;
    return stock != null && stock! > 0;
  }

  @override
  List<Object?> get props => [
        id,
        nombre,
        precio,
        stripePriceId,
        activo,
        stock,
      ];
}

