import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/modelos/pedido.dart';

/// Gestiona el stock del catálogo de productos.
/// Todas las operaciones son atómicas vía batch de Firestore.
class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _catalogo(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('catalogo');

  // ─────────────────────────────────────────────────────────────────────
  // Decremento al vender
  // ─────────────────────────────────────────────────────────────────────

  /// Decrementa el stock de los productos vendidos.
  /// Si un producto no tiene campo `stock` o este es null, no hace nada
  /// para ese producto (stock no gestionado).
  /// Si el stock es insuficiente, lanza [StockInsuficienteException].
  Future<void> decrementarStockPorVenta({
    required String empresaId,
    required List<LineaPedido> lineas,
  }) async {
    // 1. Leer stock actual de todos los productos en paralelo
    final futures = lineas.map((l) =>
        _catalogo(empresaId).doc(l.productoId).get());
    final snaps = await Future.wait(futures);

    // 2. Verificar stock suficiente
    for (int i = 0; i < lineas.length; i++) {
      final data = snaps[i].data();
      if (data == null) continue; // producto no encontrado, ignorar
      final stockActual = (data['stock'] as num?)?.toInt();
      if (stockActual == null) continue; // stock no gestionado
      if (stockActual < lineas[i].cantidad) {
        throw StockInsuficienteException(
          productoNombre: lineas[i].productoNombre,
          stockDisponible: stockActual,
          cantidadSolicitada: lineas[i].cantidad,
        );
      }
    }

    // 3. Decrementar en batch atómico
    final batch = _db.batch();
    for (int i = 0; i < lineas.length; i++) {
      final data = snaps[i].data();
      if (data == null) continue;
      final stockActual = (data['stock'] as num?)?.toInt();
      if (stockActual == null) continue; // stock no gestionado
      batch.update(
        _catalogo(empresaId).doc(lineas[i].productoId),
        {
          'stock': FieldValue.increment(-lineas[i].cantidad),
          'ultima_actualizacion_stock': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Incremento al recibir mercancía
  // ─────────────────────────────────────────────────────────────────────

  /// Incrementa el stock al registrar una entrada de mercancía.
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

  // ─────────────────────────────────────────────────────────────────────
  // Alertas de stock bajo
  // ─────────────────────────────────────────────────────────────────────

  /// Devuelve productos con stock por debajo del mínimo configurado.
  /// Si el producto no tiene `stock_minimo`, usa 5 como valor por defecto.
  Future<List<Map<String, dynamic>>> productosConStockBajo(
    String empresaId,
  ) async {
    final snap = await _catalogo(empresaId)
        .where('activo', isEqualTo: true)
        .get();

    final bajos = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final stock = (data['stock'] as num?)?.toInt();
      if (stock == null) continue; // stock no gestionado, ignorar
      final minimo = (data['stock_minimo'] as num?)?.toInt() ?? 5;
      if (stock <= minimo) {
        bajos.add({
          'id': doc.id,
          'nombre': data['nombre'] ?? '',
          'stock': stock,
          'stock_minimo': minimo,
        });
      }
    }
    return bajos;
  }
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

