import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/estadisticas_trigger_service.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';

class PedidosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── COLECCIONES ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _productos(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('catalogo');

  CollectionReference<Map<String, dynamic>> _pedidos(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('pedidos');

  // ── PRODUCTOS ────────────────────────────────────────────────────────────────

  Stream<List<Producto>> productosStream(String empresaId, {bool soloActivos = false}) {
    Query<Map<String, dynamic>> q = _productos(empresaId).orderBy('nombre');
    if (soloActivos) q = q.where('activo', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Producto.fromFirestore).toList());
  }

  Stream<List<Producto>> productosPorCategoriaStream(String empresaId, String categoria) =>
      _productos(empresaId)
          .where('categoria', isEqualTo: categoria)
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .snapshots()
          .map((s) => s.docs.map(Producto.fromFirestore).toList());

  Stream<List<String>> categoriasStream(String empresaId) =>
      _productos(empresaId).snapshots().map((s) {
        final cats = s.docs
            .map((d) => (d.data()['categoria'] as String?) ?? 'General')
            .toSet()
            .toList()
          ..sort();
        return cats;
      });

  Future<Producto> crearProducto({
    required String empresaId,
    required String nombre,
    required String categoria,
    required double precio,
    String? descripcion,
    String? imagenUrl,
    int? stock,
    bool destacado = false,
    bool tieneVariantes = false,
    int? duracionMinutos,
    double ivaPorcentaje = 21,
    String? sku,
    String? codigoBarras,
    List<VarianteProducto> variantes = const [],
    List<String> etiquetas = const [],
  }) async {
    final ref = _productos(empresaId).doc();
    final producto = Producto(
      id: ref.id,
      empresaId: empresaId,
      nombre: nombre,
      descripcion: descripcion,
      categoria: categoria,
      precio: precio,
      imagenUrl: imagenUrl,
      stock: stock,
      activo: true,
      destacado: destacado,
      tieneVariantes: tieneVariantes,
      duracionMinutos: duracionMinutos,
      ivaPorcentaje: ivaPorcentaje,
      sku: sku,
      codigoBarras: codigoBarras,
      variantes: variantes,
      etiquetas: etiquetas,
      fechaCreacion: DateTime.now(),
    );
    await ref.set(producto.toFirestore());
    return producto;
  }

  /// Crea un producto usando un ID pre-generado (necesario para subir
  /// la imagen antes de guardar el documento).
  Future<void> crearProductoConId({
    required String empresaId,
    required String id,
    required Map<String, dynamic> datos,
  }) async {
    final ref = _productos(empresaId).doc(id);
    await ref.set({
      ...datos,
      'empresa_id': empresaId,
      'activo': datos['activo'] ?? true,
      'fecha_creacion': Timestamp.fromDate(DateTime.now()),
      'variantes': datos['variantes'] ?? [],
      'etiquetas': datos['etiquetas'] ?? [],
    });
  }

  Future<void> actualizarProducto(String empresaId, String productoId, Map<String, dynamic> datos) =>
      _productos(empresaId).doc(productoId).update({
        ...datos,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });

  Future<void> toggleActivoProducto(String empresaId, String productoId, bool activo) =>
      actualizarProducto(empresaId, productoId, {'activo': activo});

  Future<void> eliminarProducto(String empresaId, String productoId) =>
      _productos(empresaId).doc(productoId).delete();

  // ── PEDIDOS ──────────────────────────────────────────────────────────────────

  Stream<List<Pedido>> pedidosStream(String empresaId) =>
      _pedidos(empresaId)
          .orderBy('fecha_creacion', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Pedido.fromFirestore).toList());

  Stream<List<Pedido>> pedidosHoyStream(String empresaId) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return _pedidos(empresaId)
        .where('fecha_creacion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .snapshots()
        .map((s) {
          final lista = s.docs.map(Pedido.fromFirestore).toList()
            ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
          return lista;
        });
  }

  Stream<List<Pedido>> pedidosPorEstadoStream(
      String empresaId, EstadoPedido estado) =>
      _pedidos(empresaId)
          .orderBy('fecha_creacion', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map(Pedido.fromFirestore)
              .where((p) => p.estado == estado)
              .toList());

  Future<Pedido> crearPedido({
    required String empresaId,
    required String clienteNombre,
    required List<LineaPedido> lineas,
    required OrigenPedido origen,
    required MetodoPago metodoPago,
    String? clienteTelefono,
    String? clienteCorreo,
    String? notasCliente,
    String? notasInternas,
    String usuarioId = '',
    String usuarioNombre = 'Sistema',
    DateTime? fechaEntrega,
  }) async {
    final ref = _pedidos(empresaId).doc();
    final total = lineas.fold<double>(0, (sum, l) => sum + l.subtotal);
    final ahora = DateTime.now();
    final entrada = EntradaHistorialPedido(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'creacion',
      descripcion: 'Pedido creado desde ${_nombreOrigen(origen)}',
      fecha: ahora,
    );
    final pedido = Pedido(
      id: ref.id,
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteCorreo: clienteCorreo,
      lineas: lineas,
      total: total,
      estado: EstadoPedido.pendiente,
      origen: origen,
      metodoPago: metodoPago,
      estadoPago: EstadoPago.pendiente,
      notasCliente: notasCliente,
      notasInternas: notasInternas,
      historial: [entrada],
      fechaCreacion: ahora,
      fechaEntrega: fechaEntrega,
    );
    await ref.set(pedido.toFirestore());
    // Actualizar estadísticas en tiempo real
    EstadisticasTriggerService().pedidoCreado(empresaId, total);
    return pedido;
  }

  Future<void> cambiarEstado(
    String empresaId,
    String pedidoId,
    EstadoPedido nuevoEstado,
    String usuarioId,
    String usuarioNombre,
  ) async {
    final entrada = EntradaHistorialPedido(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'cambio_estado',
      descripcion: 'Estado → ${_nombreEstado(nuevoEstado)}',
      fecha: DateTime.now(),
    );
    await _pedidos(empresaId).doc(pedidoId).update({
      'estado': nuevoEstado.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
  }

  Future<void> cambiarEstadoPago(
    String empresaId,
    String pedidoId,
    EstadoPago nuevoEstadoPago,
    String usuarioId,
    String usuarioNombre,
  ) async {
    final entrada = EntradaHistorialPedido(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'cambio_pago',
      descripcion: 'Pago → ${_nombreEstadoPago(nuevoEstadoPago)}',
      fecha: DateTime.now(),
    );
    await _pedidos(empresaId).doc(pedidoId).update({
      'estado_pago': nuevoEstadoPago.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
    // Trigger estadísticas si se marca como pagado
    if (nuevoEstadoPago == EstadoPago.pagado) {
      final doc = await _pedidos(empresaId).doc(pedidoId).get();
      final total = ((doc.data()?['total'] as num?) ?? 0).toDouble();
      EstadisticasTriggerService().pedidoPagado(empresaId, total);
    }
  }

  Future<void> actualizarNotasInternas(String empresaId, String pedidoId, String notas,
      String usuarioId, String usuarioNombre) async {
    final entrada = EntradaHistorialPedido(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'nota',
      descripcion: 'Nota interna actualizada',
      fecha: DateTime.now(),
    );
    await _pedidos(empresaId).doc(pedidoId).update({
      'notas_internas': notas,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
  }

  Future<void> eliminarPedido(String empresaId, String pedidoId) =>
      _pedidos(empresaId).doc(pedidoId).delete();

  /// Genera una factura a partir de un pedido y actualiza el pedido con el facturaId.
  Future<String> generarFacturaDesdePedido({
    required String empresaId,
    required String pedidoId,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final doc = await _pedidos(empresaId).doc(pedidoId).get();
    final pedido = Pedido.fromFirestore(doc);

    final lineas = pedido.lineas
        .map((l) => LineaFactura(
              descripcion: l.productoNombre,
              precioUnitario: l.precioUnitario,
              cantidad: l.cantidad,
            ))
        .toList();

    final facturaSvc = FacturacionService();
    final resultado = await facturaSvc.crearFactura(
      empresaId: empresaId,
      clienteNombre: pedido.clienteNombre,
      clienteTelefono: pedido.clienteTelefono,
      clienteCorreo: pedido.clienteCorreo,
      lineas: lineas,
      metodoPago: _pedidoMetodoToFactura(pedido.metodoPago),
      pedidoId: pedidoId,
      tipo: TipoFactura.pedido,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );
    final factura = resultado.factura;

    final entrada = EntradaHistorialPedido(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'factura_generada',
      descripcion: 'Factura ${factura.numeroFactura} generada',
      fecha: DateTime.now(),
    );

    await _pedidos(empresaId).doc(pedidoId).update({
      'factura_id': factura.id,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });

    return factura.id;
  }

  MetodoPagoFactura? _pedidoMetodoToFactura(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => MetodoPagoFactura.tarjeta,
    MetodoPago.paypal   => MetodoPagoFactura.paypal,
    MetodoPago.bizum    => MetodoPagoFactura.bizum,
    MetodoPago.efectivo => MetodoPagoFactura.efectivo,
    MetodoPago.mixto    => null, // El mixto no mapea directo a un único método de factura
  };

  // ── ESTADÍSTICAS ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> obtenerResumenHoy(String empresaId) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final snap = await _pedidos(empresaId)
        .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .get();
    final pedidos = snap.docs.map(Pedido.fromFirestore).toList();
    final ventasTotal = pedidos
        .where((p) => p.estado != EstadoPedido.cancelado)
        .fold<double>(0, (sum, p) => sum + p.total);
    final pendientes = pedidos.where((p) => p.estado == EstadoPedido.pendiente).length;

    // Productos más vendidos
    final conteoProductos = <String, int>{};
    for (final p in pedidos) {
      for (final l in p.lineas) {
        conteoProductos[l.productoNombre] =
            (conteoProductos[l.productoNombre] ?? 0) + l.cantidad;
      }
    }
    final topProductos = conteoProductos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_pedidos': pedidos.length,
      'pendientes': pendientes,
      'confirmados': pedidos.where((p) => p.estado == EstadoPedido.confirmado).length,
      'en_preparacion': pedidos.where((p) => p.estado == EstadoPedido.enPreparacion).length,
      'entregados': pedidos.where((p) => p.estado == EstadoPedido.entregado).length,
      'cancelados': pedidos.where((p) => p.estado == EstadoPedido.cancelado).length,
      'ventas_total': ventasTotal,
      'pagados': pedidos.where((p) => p.estadoPago == EstadoPago.pagado).length,
      'top_productos': topProductos.take(5).map((e) => {'nombre': e.key, 'cantidad': e.value}).toList(),
    };
  }

  // ── DATOS DE PRUEBA ───────────────────────────────────────────────────────────

  Future<void> crearDatosPrueba(String empresaId) async {
    // Categorías y productos de ejemplo
    final productos = [
      {'nombre': 'Café Americano', 'categoria': 'Bebidas', 'precio': 1.80, 'descripcion': 'Café suave con agua'},
      {'nombre': 'Cappuccino', 'categoria': 'Bebidas', 'precio': 2.50, 'descripcion': 'Espresso con leche espumada'},
      {'nombre': 'Tostada con Tomate', 'categoria': 'Desayunos', 'precio': 2.20, 'descripcion': 'Pan artesano con tomate rallado'},
      {'nombre': 'Croissant', 'categoria': 'Desayunos', 'precio': 1.90, 'descripcion': 'Hojaldre mantequilla'},
      {'nombre': 'Bocadillo Jamón', 'categoria': 'Comida', 'precio': 4.50, 'descripcion': 'Jamón ibérico en barra'},
      {'nombre': 'Menú del Día', 'categoria': 'Comida', 'precio': 9.90, 'descripcion': 'Primero, segundo y postre'},
    ];

    final batch = _db.batch();
    for (final p in productos) {
      final ref = _productos(empresaId).doc();
      batch.set(ref, {
        'empresa_id': empresaId,
        'nombre': p['nombre'],
        'descripcion': p['descripcion'],
        'categoria': p['categoria'],
        'precio': p['precio'],
        'imagen_url': null,
        'stock': null,
        'activo': true,
        'destacado': false,
        'variantes': [],
        'etiquetas': [],
        'fecha_creacion': Timestamp.fromDate(DateTime.now()),
        'fecha_actualizacion': null,
      });
    }
    await batch.commit();

    // Pedidos de ejemplo
    await crearPedido(
      empresaId: empresaId,
      clienteNombre: 'María García',
      clienteTelefono: '+34 612 345 678',
      lineas: [
        LineaPedido(productoId: 'demo', productoNombre: 'Cappuccino', precioUnitario: 2.50, cantidad: 2),
        LineaPedido(productoId: 'demo', productoNombre: 'Croissant', precioUnitario: 1.90, cantidad: 1),
      ],
      origen: OrigenPedido.whatsapp,
      metodoPago: MetodoPago.efectivo,
      usuarioNombre: 'Sistema',
    );
    await crearPedido(
      empresaId: empresaId,
      clienteNombre: 'Carlos López',
      clienteTelefono: '+34 698 765 432',
      lineas: [
        LineaPedido(productoId: 'demo', productoNombre: 'Menú del Día', precioUnitario: 9.90, cantidad: 2),
      ],
      origen: OrigenPedido.web,
      metodoPago: MetodoPago.tarjeta,
      usuarioNombre: 'Sistema',
    );
    print('✅ Datos de prueba del catálogo creados');
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  String _nombreOrigen(OrigenPedido o) => switch (o) {
    OrigenPedido.web        => 'Web',
    OrigenPedido.app        => 'App',
    OrigenPedido.whatsapp   => 'WhatsApp',
    OrigenPedido.presencial => 'Presencial',
    OrigenPedido.tpvExterno => 'TPV Externo',
  };

  String _nombreEstado(EstadoPedido e) => switch (e) {
    EstadoPedido.pendiente      => 'Pendiente',
    EstadoPedido.confirmado     => 'Confirmado',
    EstadoPedido.enPreparacion  => 'En Preparación',
    EstadoPedido.listo          => 'Listo',
    EstadoPedido.entregado      => 'Entregado',
    EstadoPedido.cancelado      => 'Cancelado',
  };

  String _nombreEstadoPago(EstadoPago e) => switch (e) {
    EstadoPago.pendiente   => 'Pendiente',
    EstadoPago.pagado      => 'Pagado',
    EstadoPago.reembolsado => 'Reembolsado',
  };
}

