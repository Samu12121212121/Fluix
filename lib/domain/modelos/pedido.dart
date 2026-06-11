import 'package:cloud_firestore/cloud_firestore.dart';
import 'producto.dart';

export 'producto.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum EstadoPedido { pendiente, confirmado, enPreparacion, listo, entregado, cancelado }

enum OrigenPedido { web, app, whatsapp, presencial, tpvExterno }

enum MetodoPago { tarjeta, paypal, bizum, efectivo, mixto }

enum EstadoPago { pendiente, pagado, reembolsado }

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
  final double? descuentoLinea;    // importe € descontado de esta línea
  final double? descuentoLineaPct; // % descuento de esta línea

  const LineaPedido({
    required this.productoId,
    required this.productoNombre,
    required this.precioUnitario,
    this.costeUnitario,
    required this.cantidad,
    this.ivaPorcentaje = 21.0,
    this.variante,
    this.notasLinea,
    this.descuentoLinea,
    this.descuentoLineaPct,
  });

  double get subtotal => (precioUnitario - (descuentoLinea ?? 0)) * cantidad;

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
    descuentoLinea: (d['descuento_linea'] as num?)?.toDouble(),
    descuentoLineaPct: (d['descuento_linea_pct'] as num?)?.toDouble(),
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
    'descuento_linea': descuentoLinea,
    'descuento_linea_pct': descuentoLineaPct,
  };

  LineaPedido copyWith({
    String? productoId,
    String? productoNombre,
    double? precioUnitario,
    double? costeUnitario,
    int? cantidad,
    double? ivaPorcentaje,
    VarianteProducto? variante,
    String? notasLinea,
    double? descuentoLinea,
    double? descuentoLineaPct,
  }) => LineaPedido(
    productoId: productoId ?? this.productoId,
    productoNombre: productoNombre ?? this.productoNombre,
    precioUnitario: precioUnitario ?? this.precioUnitario,
    costeUnitario: costeUnitario ?? this.costeUnitario,
    cantidad: cantidad ?? this.cantidad,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    variante: variante ?? this.variante,
    notasLinea: notasLinea ?? this.notasLinea,
    descuentoLinea: descuentoLinea ?? this.descuentoLinea,
    descuentoLineaPct: descuentoLineaPct ?? this.descuentoLineaPct,
  );
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
        fecha: parseTimestamp(d['fecha']),
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
  final DateTime? fechaEntrega;
  final String? facturaId;
  final int numeroTicket;

  // Pago mixto desglose
  final double? efectivoImporte;
  final double? tarjetaImporte;

  // Descuentos
  final double? descuentoGlobal;
  final double? descuentoPct;
  final String? cuponId;
  final double? cuponDescuento;

  // Propina
  final double? propina;

  // Fiado / pago posterior
  final bool esFiado;

  // En espera (hold)
  final bool enEspera;
  final String? etiquetaEspera;

  // Comisiones / cajero
  final String? cajeroUid;
  final String? cajeroNombre;

  // Bonos
  final String? bonoId;
  final double? bonoImporte;

  // Split bill
  final int? numPagadores;

  const Pedido({
    required this.numeroTicket,
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
    this.efectivoImporte,
    this.tarjetaImporte,
    this.descuentoGlobal,
    this.descuentoPct,
    this.cuponId,
    this.cuponDescuento,
    this.propina,
    this.esFiado = false,
    this.enEspera = false,
    this.etiquetaEspera,
    this.cajeroUid,
    this.cajeroNombre,
    this.bonoId,
    this.bonoImporte,
    this.numPagadores,
  });

  bool get estaAtrasado =>
      estado == EstadoPedido.pendiente &&
      DateTime.now().difference(fechaCreacion).inMinutes > 30;

  int get totalItems => lineas.fold(0, (sum, l) => sum + l.cantidad);

  factory Pedido.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Pedido(
        id: doc.id,
        empresaId: '',
        clienteNombre: '',
        lineas: [],
        total: 0,
        estado: EstadoPedido.cancelado,
        origen: OrigenPedido.app,
        metodoPago: MetodoPago.efectivo,
        estadoPago: EstadoPago.pendiente,
        historial: [],
        fechaCreacion: DateTime.now(),
        numeroTicket: doc['numeroTicket'] ?? 0,
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
      fechaCreacion: parseTimestamp(d['fecha_creacion']),
      fechaActualizacion: d['fecha_actualizacion'] != null
          ? parseTimestamp(d['fecha_actualizacion'])
          : null,
      tareaAsociadaId: d['tarea_asociada_id'],
      fechaEntrega: d['fecha_entrega'] != null
          ? parseTimestamp(d['fecha_entrega'])
          : null,
      facturaId: d['factura_id'],
      numeroTicket: d['numero_ticket'] ?? 0,
      efectivoImporte: (d['efectivo_importe'] as num?)?.toDouble(),
      tarjetaImporte: (d['tarjeta_importe'] as num?)?.toDouble(),
      descuentoGlobal: (d['descuento_global'] as num?)?.toDouble(),
      descuentoPct: (d['descuento_pct'] as num?)?.toDouble(),
      cuponId: d['cupon_id'] as String?,
      cuponDescuento: (d['cupon_descuento'] as num?)?.toDouble(),
      propina: (d['propina'] as num?)?.toDouble(),
      esFiado: d['es_fiado'] as bool? ?? false,
      enEspera: d['en_espera'] as bool? ?? false,
      etiquetaEspera: d['etiqueta_espera'] as String?,
      cajeroUid: d['cajero_uid'] as String?,
      cajeroNombre: d['cajero_nombre'] as String?,
      bonoId: d['bono_id'] as String?,
      bonoImporte: (d['bono_importe'] as num?)?.toDouble(),
      numPagadores: (d['num_pagadores'] as num?)?.toInt(),
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
    'fecha_actualizacion': fechaActualizacion != null
        ? Timestamp.fromDate(fechaActualizacion!)
        : null,
    'tarea_asociada_id': tareaAsociadaId,
    'fecha_entrega': fechaEntrega != null ? Timestamp.fromDate(fechaEntrega!) : null,
    'factura_id': facturaId,
    'efectivo_importe': efectivoImporte,
    'tarjeta_importe': tarjetaImporte,
    'descuento_global': descuentoGlobal,
    'descuento_pct': descuentoPct,
    'cupon_id': cuponId,
    'cupon_descuento': cuponDescuento,
    'propina': propina,
    'es_fiado': esFiado,
    'en_espera': enEspera,
    'etiqueta_espera': etiquetaEspera,
    'cajero_uid': cajeroUid,
    'cajero_nombre': cajeroNombre,
    'bono_id': bonoId,
    'bono_importe': bonoImporte,
    'num_pagadores': numPagadores,
  };

  Pedido copyWith({
    String? id,
    String? empresaId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    List<LineaPedido>? lineas,
    double? total,
    EstadoPedido? estado,
    OrigenPedido? origen,
    MetodoPago? metodoPago,
    EstadoPago? estadoPago,
    String? notasInternas,
    String? notasCliente,
    List<EntradaHistorialPedido>? historial,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? tareaAsociadaId,
    DateTime? fechaEntrega,
    String? facturaId,
    int? numeroTicket,
    double? efectivoImporte,
    double? tarjetaImporte,
    double? descuentoGlobal,
    double? descuentoPct,
    String? cuponId,
    double? cuponDescuento,
    double? propina,
    bool? esFiado,
    bool? enEspera,
    String? etiquetaEspera,
    String? cajeroUid,
    String? cajeroNombre,
    String? bonoId,
    double? bonoImporte,
    int? numPagadores,
  }) => Pedido(
    id: id ?? this.id,
    empresaId: empresaId ?? this.empresaId,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    clienteTelefono: clienteTelefono ?? this.clienteTelefono,
    clienteCorreo: clienteCorreo ?? this.clienteCorreo,
    lineas: lineas ?? this.lineas,
    total: total ?? this.total,
    estado: estado ?? this.estado,
    origen: origen ?? this.origen,
    metodoPago: metodoPago ?? this.metodoPago,
    estadoPago: estadoPago ?? this.estadoPago,
    notasInternas: notasInternas ?? this.notasInternas,
    notasCliente: notasCliente ?? this.notasCliente,
    historial: historial ?? this.historial,
    fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    tareaAsociadaId: tareaAsociadaId ?? this.tareaAsociadaId,
    fechaEntrega: fechaEntrega ?? this.fechaEntrega,
    facturaId: facturaId ?? this.facturaId,
    numeroTicket: numeroTicket ?? this.numeroTicket,
    efectivoImporte: efectivoImporte ?? this.efectivoImporte,
    tarjetaImporte: tarjetaImporte ?? this.tarjetaImporte,
    descuentoGlobal: descuentoGlobal ?? this.descuentoGlobal,
    descuentoPct: descuentoPct ?? this.descuentoPct,
    cuponId: cuponId ?? this.cuponId,
    cuponDescuento: cuponDescuento ?? this.cuponDescuento,
    propina: propina ?? this.propina,
    esFiado: esFiado ?? this.esFiado,
    enEspera: enEspera ?? this.enEspera,
    etiquetaEspera: etiquetaEspera ?? this.etiquetaEspera,
    cajeroUid: cajeroUid ?? this.cajeroUid,
    cajeroNombre: cajeroNombre ?? this.cajeroNombre,
    bonoId: bonoId ?? this.bonoId,
    bonoImporte: bonoImporte ?? this.bonoImporte,
    numPagadores: numPagadores ?? this.numPagadores,
  );
}
