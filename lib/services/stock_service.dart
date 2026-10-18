import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/pedido.dart';

/// Gestiona el stock del catálogo de productos.
///
/// Contrato de idempotencia:
///   Cuando el descuento tiene éxito, escribe `stock_descontado: true` en el
///   documento del pedido. Antes de decrementar comprueba ese flag — si ya
///   está activo, la operación es un no-op (seguro ante reintentos).
///
/// Contrato de controlStock:
///   Solo se descuenta/restaura stock en productos con `control_stock == true`.
///   Los productos sin ese campo, o con `control_stock: false`, no se tocan.
class StockService {
  final FirebaseFirestore _db;
  StockService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _catalogo(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('catalogo');

  DocumentReference<Map<String, dynamic>> _pedidoRef(
          String empresaId, String pedidoId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .doc(pedidoId);

  // ─────────────────────────────────────────────────────────────────────
  // Decremento al vender (idempotente, transaccional por producto)
  // ─────────────────────────────────────────────────────────────────────

  /// Decrementa el stock de los productos vendidos.
  ///
  /// - Solo actúa sobre productos con `control_stock == true`.
  /// - Es idempotente: si el pedido ya tiene `stock_descontado: true`, no
  ///   hace nada (protege ante reintentos del caller).
  /// - Usa una transacción Firestore por producto para evitar stock negativo
  ///   en ventas concurrentes.
  /// - Si un producto tiene stock insuficiente lanza [StockInsuficienteException].
  ///   En ese caso el caller debe decidir si bloquear o continuar; el pedido
  ///   NO queda marcado como `stock_descontado`.
  Future<void> decrementarStockPorVenta({
    required String empresaId,
    required String pedidoId,
    required List<LineaPedido> lineas,
  }) async {
    // 1. Idempotencia: comprobar si ya se descontó
    final pedidoSnap = await _pedidoRef(empresaId, pedidoId).get();
    if (pedidoSnap.data()?['stock_descontado'] == true) return;

    // 2. Filtrar sólo las líneas con productos que tienen control_stock
    //    Leer todos en paralelo para minimizar latencia.
    final futures = lineas.map((l) => _catalogo(empresaId).doc(l.productoId).get());
    final snaps = await Future.wait(futures);

    final lineasGestionadas = <({LineaPedido linea, int stockActual})>[];
    for (int i = 0; i < lineas.length; i++) {
      final data = snaps[i].data();
      if (data == null) continue;
      if (data['control_stock'] != true) continue;
      final stockActual = (data['stock'] as num?)?.toInt() ?? 0;
      if (stockActual < lineas[i].cantidad) {
        throw StockInsuficienteException(
          productoNombre: lineas[i].productoNombre,
          stockDisponible: stockActual,
          cantidadSolicitada: lineas[i].cantidad,
        );
      }
      lineasGestionadas.add((linea: lineas[i], stockActual: stockActual));
    }

    if (lineasGestionadas.isEmpty) {
      // Ningún producto gestionado — marcar igualmente para no repetir
      await _pedidoRef(empresaId, pedidoId)
          .update({'stock_descontado': true});
      return;
    }

    // 3. Transacción atómica: decrementar cada producto y marcar pedido
    //    Firestore permite hasta 500 docs por transacción, suficiente para un TPV.
    await _db.runTransaction((txn) async {
      // Re-leer dentro de la transacción para lectura consistente
      final reReads = await Future.wait(
        lineasGestionadas.map((e) =>
            txn.get(_catalogo(empresaId).doc(e.linea.productoId))),
      );

      for (int i = 0; i < lineasGestionadas.length; i++) {
        final snap = reReads[i];
        final data = snap.data();
        if (data == null || data['control_stock'] != true) continue;
        final stock = (data['stock'] as num?)?.toInt() ?? 0;
        if (stock < lineasGestionadas[i].linea.cantidad) {
          throw StockInsuficienteException(
            productoNombre: lineasGestionadas[i].linea.productoNombre,
            stockDisponible: stock,
            cantidadSolicitada: lineasGestionadas[i].linea.cantidad,
          );
        }
        txn.update(snap.reference, {
          'stock': FieldValue.increment(-lineasGestionadas[i].linea.cantidad),
          'ultima_actualizacion_stock': FieldValue.serverTimestamp(),
        });
      }

      // Marcar el pedido como stock descontado dentro de la misma transacción
      txn.update(_pedidoRef(empresaId, pedidoId), {'stock_descontado': true});
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // Restauración al cancelar / devolver
  // ─────────────────────────────────────────────────────────────────────

  /// Restaura el stock cuando un pedido se cancela o se devuelve.
  ///
  /// Solo actúa si el pedido tiene `stock_descontado: true` para evitar
  /// restaurar stock que nunca se descontó.
  Future<void> restaurarStockPorCancelacion({
    required String empresaId,
    required String pedidoId,
    required List<LineaPedido> lineas,
  }) async {
    final pedidoSnap = await _pedidoRef(empresaId, pedidoId).get();
    if (pedidoSnap.data()?['stock_descontado'] != true) return;

    await _db.runTransaction((txn) async {
      final refs = lineas
          .where((l) => l.productoId.isNotEmpty)
          .map((l) => _catalogo(empresaId).doc(l.productoId))
          .toList();

      final prodSnaps = await Future.wait(refs.map((r) => txn.get(r)));

      for (int i = 0; i < refs.length; i++) {
        final data = prodSnaps[i].data();
        if (data == null || data['control_stock'] != true) continue;
        txn.update(refs[i], {
          'stock': FieldValue.increment(lineas[i].cantidad),
          'ultima_actualizacion_stock': FieldValue.serverTimestamp(),
        });
      }

      // Marcar que ya no está descontado para evitar doble restauración
      txn.update(_pedidoRef(empresaId, pedidoId), {'stock_descontado': false});
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // Incremento manual (entrada de mercancía)
  // ─────────────────────────────────────────────────────────────────────

  Future<void> incrementarStock({
    required String empresaId,
    required String productoId,
    required int cantidad,
  }) async {
    await _catalogo(empresaId).doc(productoId).update({
      'stock': FieldValue.increment(cantidad),
      'ultima_actualizacion_stock': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ajustarStock({
    required String empresaId,
    required String productoId,
    required int nuevoStock,
  }) async {
    await _catalogo(empresaId).doc(productoId).update({
      'stock': nuevoStock,
      'ultima_actualizacion_stock': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // Consultas
  // ─────────────────────────────────────────────────────────────────────

  /// Devuelve stream de productos con control de stock activo, ordenados
  /// por nivel de alerta (agotado primero, luego stock bajo).
  Stream<List<AlertaStock>> alertasStockStream(String empresaId) {
    return _catalogo(empresaId)
        .where('activo', isEqualTo: true)
        .where('control_stock', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final alertas = <AlertaStock>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final stock = (data['stock'] as num?)?.toInt();
        if (stock == null) continue;
        final minimo = (data['stock_minimo'] as num?)?.toInt() ?? 5;
        if (stock <= minimo) {
          alertas.add(AlertaStock(
            productoId: doc.id,
            nombre: data['nombre'] as String? ?? '—',
            stock: stock,
            stockMinimo: minimo,
            agotado: stock <= 0,
          ));
        }
      }
      alertas.sort((a, b) {
        if (a.agotado && !b.agotado) return -1;
        if (!a.agotado && b.agotado) return 1;
        return a.stock.compareTo(b.stock);
      });
      return alertas;
    });
  }

  /// Versión one-shot para el dashboard widget.
  Future<List<AlertaStock>> productosConStockBajo(String empresaId) =>
      alertasStockStream(empresaId).first;
}

// ─────────────────────────────────────────────────────────────────────────
// Modelos de alerta
// ─────────────────────────────────────────────────────────────────────────

class AlertaStock {
  final String productoId;
  final String nombre;
  final int stock;
  final int stockMinimo;
  final bool agotado;

  const AlertaStock({
    required this.productoId,
    required this.nombre,
    required this.stock,
    required this.stockMinimo,
    required this.agotado,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Excepción tipada
// ─────────────────────────────────────────────────────────────────────────

class StockInsuficienteException implements Exception {
  final String productoNombre;
  final int stockDisponible;
  final int cantidadSolicitada;

  const StockInsuficienteException({
    required this.productoNombre,
    required this.stockDisponible,
    required this.cantidadSolicitada,
  });

  @override
  String toString() =>
      'Stock insuficiente para "$productoNombre": '
      'disponible $stockDisponible, solicitado $cantidadSolicitada';
}
