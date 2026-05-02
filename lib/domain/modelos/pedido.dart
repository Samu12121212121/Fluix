import 'package:cloud_firestore/cloud_firestore.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum EstadoPedido { pendiente, confirmado, enPreparacion, listo, entregado, cancelado }

enum OrigenPedido { web, app, whatsapp, presencial, tpvExterno }

enum MetodoPago { tarjeta, paypal, bizum, efectivo, mixto }

enum EstadoPago { pendiente, pagado, reembolsado }

// ── VARIANTE DE PRODUCTO ──────────────────────────────────────────────────────

class VarianteProducto {
  final String id;
  final String nombre;           // ej: "Grande", "Cabello corto", "1kg"
  final String tipo;             // ej: "tamaño", "sabor", "color"
  final double? precioDiferencia; // diferencia sobre precio base (legacy/compat)
  final double? precio;          // precio propio de la variante
  final int? duracionMinutos;    // duración propia si es servicio
  final String? sku;             // SKU propio (opcional)
  final bool disponible;         // toggle activar/desactivar sin eliminar
  final int? stockExtra;

  const VarianteProducto({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.precioDiferencia,
    this.precio,
    this.duracionMinutos,
    this.sku,
    this.disponible = true,
    this.stockExtra,
  });

  /// Devuelve el precio efectivo: si tiene precio propio lo usa,
  /// si no, suma precioDiferencia al precio base.
  double precioEfectivo(double precioBase) =>
      precio ?? (precioBase + (precioDiferencia ?? 0));

  factory VarianteProducto.fromMap(Map<String, dynamic> d) => VarianteProducto(
    id: d['id'] ?? '',
    nombre: d['nombre'] ?? '',
    tipo: d['tipo'] ?? '',
    precioDiferencia: (d['precio_diferencia'] as num?)?.toDouble(),
    precio: (d['precio'] as num?)?.toDouble(),
    duracionMinutos: (d['duracion_minutos'] as num?)?.toInt(),
    sku: d['sku'] as String?,
    disponible: d['disponible'] as bool? ?? true,
    stockExtra: d['stock_extra'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'precio_diferencia': precioDiferencia,
    'precio': precio,
    'duracion_minutos': duracionMinutos,
    'sku': sku,
    'disponible': disponible,
    'stock_extra': stockExtra,
  };

  VarianteProducto copyWith({
    String? nombre,
    String? tipo,
    double? precioDiferencia,
    double? precio,
    int? duracionMinutos,
    String? sku,
    bool? disponible,
    int? stockExtra,
  }) => VarianteProducto(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    precioDiferencia: precioDiferencia ?? this.precioDiferencia,
    precio: precio ?? this.precio,
    duracionMinutos: duracionMinutos ?? this.duracionMinutos,
    sku: sku ?? this.sku,
    disponible: disponible ?? this.disponible,
    stockExtra: stockExtra ?? this.stockExtra,
  );
}

// ── PRODUCTO ──────────────────────────────────────────────────────────────────

class Producto {
  final String id;
  final String empresaId;
  final String nombre;
  final String? descripcion;
  final String categoria;
  final double precio;
  final String? imagenUrl;
  final String? thumbnailUrl;    // miniatura 400x400 generada por Cloud Function
  final int? stock;
  final bool activo;
  final bool destacado;
  final bool tieneVariantes;     // toggle: true → oculta precio base, muestra variantes
  final int? duracionMinutos;    // duración del servicio (null si es producto físico)
  final double ivaPorcentaje;    // % IVA (21, 10, 4, 0)
  final String? sku;
  final String? codigoBarras;
  final List<VarianteProducto> variantes;
  final List<String> etiquetas;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  const Producto({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    required this.precio,
    this.imagenUrl,
    this.thumbnailUrl,
    this.stock,
    this.activo = true,
    this.destacado = false,
    this.tieneVariantes = false,
    this.duracionMinutos,
    this.ivaPorcentaje = 21,
    this.sku,
    this.codigoBarras,
    required this.variantes,
    required this.etiquetas,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  /// Variantes que están disponibles (no desactivadas).
  List<VarianteProducto> get variantesDisponibles =>
      variantes.where((v) => v.disponible).toList();

  /// Precio mínimo entre variantes disponibles, o el precio base.
  double get precioDesde {
    if (!tieneVariantes || variantesDisponibles.isEmpty) return precio;
    return variantesDisponibles
        .map((v) => v.precioEfectivo(precio))
        .reduce((a, b) => a < b ? a : b);
  }

  /// Precio máximo entre variantes disponibles.
  double get precioHasta {
    if (!tieneVariantes || variantesDisponibles.isEmpty) return precio;
    return variantesDisponibles
        .map((v) => v.precioEfectivo(precio))
        .reduce((a, b) => a > b ? a : b);
  }

  /// Texto de precio para mostrar en el catálogo.
  String get textoRangoPrecio {
    if (!tieneVariantes || variantesDisponibles.isEmpty) {
      return '${precio.toStringAsFixed(2)} €';
    }
    final min = precioDesde;
    final max = precioHasta;
    if (min == max) return '${min.toStringAsFixed(2)} €';
    return 'desde ${min.toStringAsFixed(2)} €';
  }

  /// true si es un servicio (tiene duración configurada).
  bool get esServicio => duracionMinutos != null && duracionMinutos! > 0;

  factory Producto.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Producto(
        id: doc.id, empresaId: '', nombre: 'Sin nombre', categoria: 'General',
        precio: 0, variantes: [], etiquetas: [], fechaCreacion: DateTime.now(),
      );
    }
    final d = raw as Map<String, dynamic>;
    return Producto(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      nombre: d['nombre'] ?? '',
      descripcion: d['descripcion'],
      categoria: d['categoria'] ?? 'General',
      precio: (d['precio'] as num?)?.toDouble() ?? 0,
      imagenUrl: d['imagen_url'],
      thumbnailUrl: d['thumbnail_url'],
      stock: d['stock'],
      activo: d['activo'] ?? true,
      destacado: d['destacado'] ?? false,
      tieneVariantes: d['tiene_variantes'] ?? false,
      duracionMinutos: (d['duracion_minutos'] as num?)?.toInt(),
      ivaPorcentaje: (d['iva_porcentaje'] as num?)?.toDouble() ?? 21,
      sku: d['sku'],
      codigoBarras: d['codigo_barras'],
      variantes: (d['variantes'] as List<dynamic>? ?? [])
          .map((v) => VarianteProducto.fromMap(v as Map<String, dynamic>))
          .toList(),
      etiquetas: List<String>.from(d['etiquetas'] ?? []),
      fechaCreacion: _parseTs(d['fecha_creacion']),
      fechaActualizacion: d['fecha_actualizacion'] != null ? _parseTs(d['fecha_actualizacion']) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'nombre': nombre,
    'descripcion': descripcion,
    'categoria': categoria,
    'precio': precio,
    'imagen_url': imagenUrl,
    'thumbnail_url': thumbnailUrl,
    'stock': stock,
    'activo': activo,
    'destacado': destacado,
    'tiene_variantes': tieneVariantes,
    'duracion_minutos': duracionMinutos,
    'iva_porcentaje': ivaPorcentaje,
    'sku': sku,
    'codigo_barras': codigoBarras,
    'variantes': variantes.map((v) => v.toMap()).toList(),
    'etiquetas': etiquetas,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': fechaActualizacion != null ? Timestamp.fromDate(fechaActualizacion!) : null,
  };

  Producto copyWith({
    String? nombre,
    String? descripcion,
    String? categoria,
    double? precio,
    String? imagenUrl,
    String? thumbnailUrl,
    int? stock,
    bool? activo,
    bool? destacado,
    bool? tieneVariantes,
    int? duracionMinutos,
    double? ivaPorcentaje,
    String? sku,
    String? codigoBarras,
    List<VarianteProducto>? variantes,
    List<String>? etiquetas,
  }) => Producto(
    id: id,
    empresaId: empresaId,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    categoria: categoria ?? this.categoria,
    precio: precio ?? this.precio,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    stock: stock ?? this.stock,
    activo: activo ?? this.activo,
    destacado: destacado ?? this.destacado,
    tieneVariantes: tieneVariantes ?? this.tieneVariantes,
    duracionMinutos: duracionMinutos ?? this.duracionMinutos,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    sku: sku ?? this.sku,
    codigoBarras: codigoBarras ?? this.codigoBarras,
    variantes: variantes ?? this.variantes,
    etiquetas: etiquetas ?? this.etiquetas,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: this.fechaActualizacion,
  );
}

// ── LÍNEA DE PEDIDO ───────────────────────────────────────────────────────────

class LineaPedido {
  final String productoId;
  final String productoNombre;
  final double precioUnitario;
  final double? costeUnitario;
  final int cantidad;
  final double ivaPorcentaje;      // % IVA del producto (21, 10, 4, 0)
  final VarianteProducto? variante;
  final String? notasLinea;

  const LineaPedido({
    required this.productoId,
    required this.productoNombre,
    required this.precioUnitario,
    this.costeUnitario,
    required this.cantidad,
    this.ivaPorcentaje = 21.0,
    this.variante,
    this.notasLinea,
  });

  double get subtotal => precioUnitario * cantidad;

  factory LineaPedido.fromMap(Map<String, dynamic> d) => LineaPedido(
    productoId: d['producto_id'] ?? '',
    productoNombre: d['producto_nombre'] ?? '',
    precioUnitario: (d['precio_unitario'] as num?)?.toDouble() ?? 0,
    costeUnitario: (d['coste_unitario'] as num?)?.toDouble(),
    cantidad: (d['cantidad'] as num?)?.toInt() ?? 1,
    ivaPorcentaje: (d['iva_porcentaje'] as num?)?.toDouble() ?? 21.0,
    variante: d['variante'] != null
        ? VarianteProducto.fromMap(d['variante'] as Map<String, dynamic>)
        : null,
    notasLinea: d['notas_linea'],
  );

  Map<String, dynamic> toMap() => {
    'producto_id': productoId,
    'producto_nombre': productoNombre,
    'precio_unitario': precioUnitario,
    'coste_unitario': costeUnitario,
    'cantidad': cantidad,
    'iva_porcentaje': ivaPorcentaje,
    'variante': variante?.toMap(),
    'notas_linea': notasLinea,
  };
}

// ── HISTORIAL DE PEDIDO ───────────────────────────────────────────────────────

class EntradaHistorialPedido {
  final String usuarioId;
  final String usuarioNombre;
  final String accion;
  final String descripcion;
  final DateTime fecha;

  const EntradaHistorialPedido({
    required this.usuarioId,
    required this.usuarioNombre,
    required this.accion,
    required this.descripcion,
    required this.fecha,
  });

  factory EntradaHistorialPedido.fromMap(Map<String, dynamic> d) =>
      EntradaHistorialPedido(
        usuarioId: d['usuario_id'] ?? '',
        usuarioNombre: d['usuario_nombre'] ?? '',
        accion: d['accion'] ?? '',
        descripcion: d['descripcion'] ?? '',
        fecha: _parseTs(d['fecha']),
      );

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'usuario_nombre': usuarioNombre,
    'accion': accion,
    'descripcion': descripcion,
    'fecha': Timestamp.fromDate(fecha),
  };
}

// ── PEDIDO ────────────────────────────────────────────────────────────────────

class Pedido {
  final String id;
  final String empresaId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteCorreo;
  final List<LineaPedido> lineas;
  final double total;
  final EstadoPedido estado;
  final OrigenPedido origen;
  final MetodoPago metodoPago;
  final EstadoPago estadoPago;
  final String? notasInternas;
  final String? notasCliente;
  final List<EntradaHistorialPedido> historial;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final String? tareaAsociadaId;
  final DateTime? fechaEntrega; // fecha/hora para la que es el pedido
  final String? facturaId;

  const Pedido({
    required this.id,
    required this.empresaId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteCorreo,
    required this.lineas,
    required this.total,
    required this.estado,
    required this.origen,
    required this.metodoPago,
    required this.estadoPago,
    this.notasInternas,
    this.notasCliente,
    required this.historial,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.tareaAsociadaId,
    this.fechaEntrega,
    this.facturaId,
  });


  bool get estaAtrasado =>
      estado == EstadoPedido.pendiente &&
      DateTime.now().difference(fechaCreacion).inMinutes > 30;

  int get totalItems => lineas.fold(0, (sum, l) => sum + l.cantidad);

  factory Pedido.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Pedido(
        id: doc.id, empresaId: '', clienteNombre: '', lineas: [], total: 0,
        estado: EstadoPedido.cancelado, origen: OrigenPedido.app,
        metodoPago: MetodoPago.efectivo, estadoPago: EstadoPago.pendiente,
        historial: [], fechaCreacion: DateTime.now(),
      );
    }
    final d = raw as Map<String, dynamic>;
    return Pedido(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      clienteNombre: d['cliente_nombre'] ?? '',
      clienteTelefono: d['cliente_telefono'],
      clienteCorreo: d['cliente_correo'],
      lineas: (d['lineas'] as List<dynamic>? ?? [])
          .map((l) => LineaPedido.fromMap(l as Map<String, dynamic>))
          .toList(),
      total: (d['total'] as num?)?.toDouble() ?? 0,
      estado: EstadoPedido.values.firstWhere(
        (e) => e.name == d['estado'], orElse: () => EstadoPedido.pendiente),
      origen: OrigenPedido.values.firstWhere(
        (e) => e.name == d['origen'], orElse: () => OrigenPedido.app),
      metodoPago: MetodoPago.values.firstWhere(
        (e) => e.name == d['metodo_pago'], orElse: () => MetodoPago.efectivo),
      estadoPago: EstadoPago.values.firstWhere(
        (e) => e.name == d['estado_pago'], orElse: () => EstadoPago.pendiente),
      notasInternas: d['notas_internas'],
      notasCliente: d['notas_cliente'],
      historial: (d['historial'] as List<dynamic>? ?? [])
          .map((h) => EntradaHistorialPedido.fromMap(h as Map<String, dynamic>))
          .toList(),
      fechaCreacion: _parseTs(d['fecha_creacion']),
      fechaActualizacion: d['fecha_actualizacion'] != null ? _parseTs(d['fecha_actualizacion']) : null,
      tareaAsociadaId: d['tarea_asociada_id'],
      fechaEntrega: d['fecha_entrega'] != null ? _parseTs(d['fecha_entrega']) : null,
      facturaId: d['factura_id'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'cliente_nombre': clienteNombre,
    'cliente_telefono': clienteTelefono,
    'cliente_correo': clienteCorreo,
    'lineas': lineas.map((l) => l.toMap()).toList(),
    'total': total,
    'estado': estado.name,
    'origen': origen.name,
    'metodo_pago': metodoPago.name,
    'estado_pago': estadoPago.name,
    'notas_internas': notasInternas,
    'notas_cliente': notasCliente,
    'historial': historial.map((h) => h.toMap()).toList(),
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': fechaActualizacion != null ? Timestamp.fromDate(fechaActualizacion!) : null,
    'tarea_asociada_id': tareaAsociadaId,
    'fecha_entrega': fechaEntrega != null ? Timestamp.fromDate(fechaEntrega!) : null,
    'factura_id': facturaId,
  };
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}



