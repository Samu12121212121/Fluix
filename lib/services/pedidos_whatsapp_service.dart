import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/pedido_whatsapp.dart';

class PedidosWhatsAppService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── STREAMS ──────────────────────────────────────────────────

  Stream<List<PedidoWhatsApp>> pedidosStream(String empresaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('pedidos_whatsapp')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PedidoWhatsApp.fromFirestore).toList());

  Stream<List<PedidoWhatsApp>> pedidosPorEstadoStream(
      String empresaId, EstadoPedidoWA estado) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos_whatsapp')
          .orderBy('fecha', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map(PedidoWhatsApp.fromFirestore)
              .where((p) => p.estado == estado)
              .toList());

  // ── CRUD ──────────────────────────────────────────────────────

  Future<PedidoWhatsApp> crearPedidoManual({
    required String empresaId,
    required String clienteNombre,
    required String clienteTelefono,
    required String mensajeOriginal,
    String? pedidoResumen,
    List<ItemPedido> items = const [],
    double? totalEstimado,
  }) async {
    final ref = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos_whatsapp')
        .doc();
    final pedido = PedidoWhatsApp(
      id: ref.id,
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      mensajeOriginal: mensajeOriginal,
      pedidoResumen: pedidoResumen,
      estado: EstadoPedidoWA.nuevo,
      fecha: DateTime.now(),
      items: items,
      totalEstimado: totalEstimado,
    );
    await ref.set(pedido.toFirestore());
    return pedido;
  }

  Future<void> actualizarEstado(
    String empresaId,
    String pedidoId,
    EstadoPedidoWA nuevoEstado,
  ) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos_whatsapp')
        .doc(pedidoId)
        .update({
      'estado': nuevoEstado.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> actualizarNotasInternas(
    String empresaId,
    String pedidoId,
    String notas,
  ) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos_whatsapp')
        .doc(pedidoId)
        .update({
      'notas_internas': notas,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> actualizarItems(
    String empresaId,
    String pedidoId,
    List<ItemPedido> items,
    double? total,
  ) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos_whatsapp')
        .doc(pedidoId)
        .update({
      'items': items.map((i) => i.toMap()).toList(),
      'total_estimado': total,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> eliminarPedido(String empresaId, String pedidoId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos_whatsapp')
          .doc(pedidoId)
          .delete();

  // ── ESTADÍSTICAS ──────────────────────────────────────────────

  Future<Map<String, dynamic>> obtenerResumen(String empresaId) async {
    final snapshot = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos_whatsapp')
        .get();

    final pedidos = snapshot.docs.map(PedidoWhatsApp.fromFirestore).toList();
    final ahora = DateTime.now();
    final hoy = pedidos.where((p) =>
        p.fecha.day == ahora.day &&
        p.fecha.month == ahora.month &&
        p.fecha.year == ahora.year);

    final ingresoTotal = pedidos
        .where((p) => p.estado == EstadoPedidoWA.entregado && p.totalEstimado != null)
        .fold<double>(0, (sum, p) => sum + (p.totalEstimado ?? 0));

    return {
      'total': pedidos.length,
      'nuevos': pedidos.where((p) => p.estado == EstadoPedidoWA.nuevo).length,
      'en_proceso': pedidos.where((p) => p.estado == EstadoPedidoWA.enProceso).length,
      'listos': pedidos.where((p) => p.estado == EstadoPedidoWA.listo).length,
      'entregados': pedidos.where((p) => p.estado == EstadoPedidoWA.entregado).length,
      'cancelados': pedidos.where((p) => p.estado == EstadoPedidoWA.cancelado).length,
      'hoy': hoy.length,
      'ingreso_total': ingresoTotal,
    };
  }

  // ── SIMULADOR (para pruebas) ──────────────────────────────────

  Future<void> crearPedidosDePrueba(String empresaId) async {
    final pedidosDePrueba = [
      {
        'cliente_nombre': 'María García',
        'cliente_telefono': '+34 612 345 678',
        'mensaje_original': 'Hola! Quería pedir 2 pizzas margarita y una de 4 quesos para recoger a las 20h',
        'pedido_resumen': '2x Pizza Margarita, 1x Pizza 4 Quesos',
        'estado': EstadoPedidoWA.nuevo.name,
        'items': [
          {'nombre': 'Pizza Margarita', 'cantidad': 2, 'precio_unitario': 12.5},
          {'nombre': 'Pizza 4 Quesos', 'cantidad': 1, 'precio_unitario': 14.0},
        ],
        'total_estimado': 39.0,
      },
      {
        'cliente_nombre': 'Juan López',
        'cliente_telefono': '+34 698 765 432',
        'mensaje_original': 'Buenos días, necesito una hamburguesa doble sin cebolla y una Coca-Cola grande',
        'pedido_resumen': '1x Hamburguesa Doble (sin cebolla), 1x Coca-Cola Grande',
        'estado': EstadoPedidoWA.enProceso.name,
        'items': [
          {'nombre': 'Hamburguesa Doble', 'cantidad': 1, 'precio_unitario': 9.5},
          {'nombre': 'Coca-Cola Grande', 'cantidad': 1, 'precio_unitario': 2.5},
        ],
        'total_estimado': 12.0,
      },
      {
        'cliente_nombre': 'Ana Martínez',
        'cliente_telefono': '+34 655 111 222',
        'mensaje_original': 'Me podéis preparar el menú del día para 3 personas? El de 9.90',
        'pedido_resumen': '3x Menú del día',
        'estado': EstadoPedidoWA.listo.name,
        'items': [
          {'nombre': 'Menú del día', 'cantidad': 3, 'precio_unitario': 9.9},
        ],
        'total_estimado': 29.7,
      },
    ];

    final batch = _db.batch();
    for (final p in pedidosDePrueba) {
      final ref = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos_whatsapp')
          .doc();
      batch.set(ref, {
        ...p,
        'empresa_id': empresaId,
        'fecha': Timestamp.fromDate(DateTime.now().subtract(
            Duration(minutes: (pedidosDePrueba.indexOf(p) * 15)))),
        'fecha_actualizacion': null,
        'notas_internas': null,
        'tarea_asociada_id': null,
      });
    }
    await batch.commit();
    print('✅ Pedidos de prueba de WhatsApp creados');
  }
}
