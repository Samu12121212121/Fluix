import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pedido de tienda online (Stripe)
class PedidoTienda extends Equatable {
  final String id;
  final String empresaId;
  final String stripePaymentId;
  final String stripeCustomerId;
  final double monto;
  final String moneda;
  final String estado; // 'pendiente', 'pagado', 'enviado', 'completado', 'cancelado'
  final String? clienteNombre;
  final String? clienteEmail;
  final String? clienteTelefono;
  final String? direccionEnvio;
  final List<ItemPedido> items;
  final DateTime fechaCreacion;
  final DateTime? fechaPago;
  final String origen; // 'tienda_online'
  final String? facturaId; // ID de la factura generada
  final String? notasCliente;
  final Map<String, dynamic>? metadataStripe;

  const PedidoTienda({
    required this.id,
    required this.empresaId,
    required this.stripePaymentId,
    required this.stripeCustomerId,
    required this.monto,
    this.moneda = 'EUR',
    required this.estado,
    this.clienteNombre,
    this.clienteEmail,
    this.clienteTelefono,
    this.direccionEnvio,
    required this.items,
    required this.fechaCreacion,
    this.fechaPago,
    this.origen = 'tienda_online',
    this.facturaId,
    this.notasCliente,
    this.metadataStripe,
  });

  factory PedidoTienda.fromFirestore(Map<String, dynamic> data, String id) {
    return PedidoTienda(
      id: id,
      empresaId: data['empresa_id'] ?? '',
      stripePaymentId: data['stripe_payment_id'] ?? '',
      stripeCustomerId: data['stripe_customer_id'] ?? '',
      monto: (data['monto'] ?? 0.0).toDouble(),
      moneda: data['moneda'] ?? 'EUR',
      estado: data['estado'] ?? 'pendiente',
      clienteNombre: data['cliente_nombre'],
      clienteEmail: data['cliente_email'],
      clienteTelefono: data['cliente_telefono'],
      direccionEnvio: data['direccion_envio'],
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => ItemPedido.fromMap(item))
              .toList() ??
          [],
      fechaCreacion: _parseDate(data['fecha_creacion']),
      fechaPago: data['fecha_pago'] != null ? _parseDate(data['fecha_pago']) : null,
      origen: data['origen'] ?? 'tienda_online',
      facturaId: data['factura_id'],
      notasCliente: data['notas_cliente'],
      metadataStripe: data['metadata_stripe'] != null 
          ? Map<String, dynamic>.from(data['metadata_stripe'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'empresa_id': empresaId,
      'stripe_payment_id': stripePaymentId,
      'stripe_customer_id': stripeCustomerId,
      'monto': monto,
      'moneda': moneda,
      'estado': estado,
      'cliente_nombre': clienteNombre,
      'cliente_email': clienteEmail,
      'cliente_telefono': clienteTelefono,
      'direccion_envio': direccionEnvio,
      'items': items.map((item) => item.toMap()).toList(),
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_pago': fechaPago != null ? Timestamp.fromDate(fechaPago) : null,
      'origen': origen,
      'factura_id': facturaId,
      'notas_cliente': notasCliente,
      'metadata_stripe': metadataStripe,
    };
  }

  static DateTime _parseDate(dynamic fecha) {
    if (fecha is Timestamp) return fecha.toDate();
    if (fecha is String) return DateTime.tryParse(fecha) ?? DateTime.now();
    if (fecha is DateTime) return fecha;
    return DateTime.now();
  }

  PedidoTienda copyWith({
    String? estado,
    String? facturaId,
    DateTime? fechaPago,
  }) {
    return PedidoTienda(
      id: id,
      empresaId: empresaId,
      stripePaymentId: stripePaymentId,
      stripeCustomerId: stripeCustomerId,
      monto: monto,
      moneda: moneda,
      estado: estado ?? this.estado,
      clienteNombre: clienteNombre,
      clienteEmail: clienteEmail,
      clienteTelefono: clienteTelefono,
      direccionEnvio: direccionEnvio,
      items: items,
      fechaCreacion: fechaCreacion,
      fechaPago: fechaPago ?? this.fechaPago,
      origen: origen,
      facturaId: facturaId ?? this.facturaId,
      notasCliente: notasCliente,
      metadataStripe: metadataStripe,
    );
  }

  @override
  List<Object?> get props => [
        id,
        empresaId,
        stripePaymentId,
        monto,
        estado,
        items,
        fechaCreacion,
      ];
}

/// Item individual de un pedido
class ItemPedido extends Equatable {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double? descuento;
  final String? imagenUrl;

  const ItemPedido({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento,
    this.imagenUrl,
  });

  double get subtotal => cantidad * precioUnitario;
  double get total => subtotal - (descuento ?? 0);

  factory ItemPedido.fromMap(Map<String, dynamic> data) {
    return ItemPedido(
      productoId: data['producto_id'] ?? '',
      nombre: data['nombre'] ?? '',
      cantidad: data['cantidad'] ?? 1,
      precioUnitario: (data['precio_unitario'] ?? 0.0).toDouble(),
      descuento: data['descuento'] != null ? (data['descuento'] as num).toDouble() : null,
      imagenUrl: data['imagen_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'producto_id': productoId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'descuento': descuento,
      'imagen_url': imagenUrl,
    };
  }

  @override
  List<Object?> get props => [productoId, nombre, cantidad, precioUnitario];
}

