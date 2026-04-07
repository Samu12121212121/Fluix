import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoPedidoWA { nuevo, visto, enProceso, listo, entregado, cancelado }

class PedidoWhatsApp {
  final String id;
  final String empresaId;
  final String clienteNombre;
  final String clienteTelefono;
  final String mensajeOriginal;
  final String? pedidoResumen;
  final EstadoPedidoWA estado;
  final DateTime fecha;
  final DateTime? fechaActualizacion;
  final String? notasInternas;
  final List<ItemPedido> items;
  final double? totalEstimado;
  final String? tareaAsociadaId;

  PedidoWhatsApp({
    required this.id,
    required this.empresaId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.mensajeOriginal,
    this.pedidoResumen,
    required this.estado,
    required this.fecha,
    this.fechaActualizacion,
    this.notasInternas,
    required this.items,
    this.totalEstimado,
    this.tareaAsociadaId,
  });

  factory PedidoWhatsApp.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return PedidoWhatsApp(
        id: doc.id, empresaId: '', clienteNombre: '', clienteTelefono: '',
        mensajeOriginal: '', estado: EstadoPedidoWA.nuevo, fecha: DateTime.now(), items: [],
      );
    }
    final data = raw as Map<String, dynamic>;
    return PedidoWhatsApp(
      id: doc.id,
      empresaId: data['empresa_id'] ?? '',
      clienteNombre: data['cliente_nombre'] ?? 'Cliente',
      clienteTelefono: data['cliente_telefono'] ?? '',
      mensajeOriginal: data['mensaje_original'] ?? '',
      pedidoResumen: data['pedido_resumen'],
      estado: EstadoPedidoWA.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoPedidoWA.nuevo,
      ),
      fecha: _parseTimestamp(data['fecha']),
      fechaActualizacion: data['fecha_actualizacion'] != null
          ? _parseTimestamp(data['fecha_actualizacion'])
          : null,
      notasInternas: data['notas_internas'],
      items: (data['items'] as List<dynamic>? ?? [])
          .map((i) => ItemPedido.fromMap(i as Map<String, dynamic>))
          .toList(),
      totalEstimado: (data['total_estimado'] as num?)?.toDouble(),
      tareaAsociadaId: data['tarea_asociada_id'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'cliente_nombre': clienteNombre,
    'cliente_telefono': clienteTelefono,
    'mensaje_original': mensajeOriginal,
    'pedido_resumen': pedidoResumen,
    'estado': estado.name,
    'fecha': Timestamp.fromDate(fecha),
    'fecha_actualizacion': fechaActualizacion != null
        ? Timestamp.fromDate(fechaActualizacion!)
        : null,
    'notas_internas': notasInternas,
    'items': items.map((i) => i.toMap()).toList(),
    'total_estimado': totalEstimado,
    'tarea_asociada_id': tareaAsociadaId,
  };
}

class ItemPedido {
  final String nombre;
  final int cantidad;
  final double? precioUnitario;
  final String? notas;

  ItemPedido({
    required this.nombre,
    required this.cantidad,
    this.precioUnitario,
    this.notas,
  });

  factory ItemPedido.fromMap(Map<String, dynamic> data) => ItemPedido(
    nombre: data['nombre'] ?? '',
    cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
    precioUnitario: (data['precio_unitario'] as num?)?.toDouble(),
    notas: data['notas'],
  );

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'notas': notas,
  };

  double? get subtotal =>
      precioUnitario != null ? precioUnitario! * cantidad : null;
}

DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

