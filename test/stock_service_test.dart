import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/stock_service.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';

// Helper para crear productos en el catálogo falso
Future<void> _crearProducto(
  FakeFirebaseFirestore db,
  String empresaId,
  String productoId, {
  required String nombre,
  required int stock,
  int stockMinimo = 5,
  bool controlStock = true,
}) async {
  await db
      .collection('empresas')
      .doc(empresaId)
      .collection('catalogo')
      .doc(productoId)
      .set({
    'nombre': nombre,
    'stock': stock,
    'stock_minimo': stockMinimo,
    'control_stock': controlStock,
    'activo': true,
    'precio': 10.0,
  });
}

// Helper para crear un pedido con stock_descontado opcional
Future<void> _crearPedido(
  FakeFirebaseFirestore db,
  String empresaId,
  String pedidoId, {
  bool stockDescontado = false,
}) async {
  await db
      .collection('empresas')
      .doc(empresaId)
      .collection('pedidos')
      .doc(pedidoId)
      .set({
    'total': 20.0,
    'estado': 'pendiente',
    if (stockDescontado) 'stock_descontado': true,
  });
}

// Leer stock actual de un producto
Future<int?> _leerStock(
    FakeFirebaseFirestore db, String empresaId, String productoId) async {
  final snap = await db
      .collection('empresas')
      .doc(empresaId)
      .collection('catalogo')
      .doc(productoId)
      .get();
  return (snap.data()?['stock'] as num?)?.toInt();
}

// Leer flag stock_descontado del pedido
Future<bool> _leerStockDescontado(
    FakeFirebaseFirestore db, String empresaId, String pedidoId) async {
  final snap = await db
      .collection('empresas')
      .doc(empresaId)
      .collection('pedidos')
      .doc(pedidoId)
      .get();
  return snap.data()?['stock_descontado'] == true;
}

void main() {
  const empresaId = 'emp_test';
  late FakeFirebaseFirestore db;
  late StockService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = StockService(db);
  });

  group('decrementarStockPorVenta', () {
    test('descuenta stock correctamente en venta normal', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Café', stock: 10, controlStock: true);
      await _crearPedido(db, empresaId, 'ped1');

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Café',
            precioUnitario: 2.0,
            cantidad: 3),
      ];

      await svc.decrementarStockPorVenta(
          empresaId: empresaId, pedidoId: 'ped1', lineas: lineas);

      expect(await _leerStock(db, empresaId, 'p1'), 7);
      expect(await _leerStockDescontado(db, empresaId, 'ped1'), isTrue);
    });

    test('es idempotente — segundo llamado es no-op', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Agua', stock: 10, controlStock: true);
      await _crearPedido(db, empresaId, 'ped2');

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Agua',
            precioUnitario: 1.0,
            cantidad: 2),
      ];

      // Primera llamada — descuenta
      await svc.decrementarStockPorVenta(
          empresaId: empresaId, pedidoId: 'ped2', lineas: lineas);
      expect(await _leerStock(db, empresaId, 'p1'), 8);

      // Segunda llamada (reintento) — NO descuenta más
      await svc.decrementarStockPorVenta(
          empresaId: empresaId, pedidoId: 'ped2', lineas: lineas);
      expect(await _leerStock(db, empresaId, 'p1'), 8,
          reason: 'El stock no debe descuentarse dos veces');
    });

    test('lanza StockInsuficienteException cuando no hay stock', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Cerveza', stock: 1, controlStock: true);
      await _crearPedido(db, empresaId, 'ped3');

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Cerveza',
            precioUnitario: 3.0,
            cantidad: 5),
      ];

      expect(
        () => svc.decrementarStockPorVenta(
            empresaId: empresaId, pedidoId: 'ped3', lineas: lineas),
        throwsA(isA<StockInsuficienteException>()),
      );
      // El stock no debe haber cambiado
      expect(await _leerStock(db, empresaId, 'p1'), 1);
    });

    test('ignora productos con controlStock=false', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Café', stock: 10, controlStock: false);
      await _crearPedido(db, empresaId, 'ped4');

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Café',
            precioUnitario: 2.0,
            cantidad: 3),
      ];

      await svc.decrementarStockPorVenta(
          empresaId: empresaId, pedidoId: 'ped4', lineas: lineas);

      // Stock sin cambios porque controlStock=false
      expect(await _leerStock(db, empresaId, 'p1'), 10);
      // Aun así, el pedido queda marcado
      expect(await _leerStockDescontado(db, empresaId, 'ped4'), isTrue);
    });

    test('mezcla de productos con y sin control de stock', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Con control', stock: 20, controlStock: true);
      await _crearProducto(db, empresaId, 'p2',
          nombre: 'Sin control', stock: 20, controlStock: false);
      await _crearPedido(db, empresaId, 'ped5');

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Con control',
            precioUnitario: 5.0,
            cantidad: 4),
        LineaPedido(
            productoId: 'p2',
            productoNombre: 'Sin control',
            precioUnitario: 5.0,
            cantidad: 4),
      ];

      await svc.decrementarStockPorVenta(
          empresaId: empresaId, pedidoId: 'ped5', lineas: lineas);

      expect(await _leerStock(db, empresaId, 'p1'), 16);
      expect(await _leerStock(db, empresaId, 'p2'), 20,
          reason: 'p2 sin control no debe cambiar');
    });
  });

  group('restaurarStockPorCancelacion', () {
    test('restaura stock cuando el pedido tiene stock_descontado=true', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Zumo', stock: 7, controlStock: true);
      // Simular pedido ya con stock descontado
      await _crearPedido(db, empresaId, 'ped6', stockDescontado: true);

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Zumo',
            precioUnitario: 2.5,
            cantidad: 3),
      ];

      await svc.restaurarStockPorCancelacion(
          empresaId: empresaId, pedidoId: 'ped6', lineas: lineas);

      expect(await _leerStock(db, empresaId, 'p1'), 10);
      expect(await _leerStockDescontado(db, empresaId, 'ped6'), isFalse,
          reason: 'flag debe quedar en false tras restaurar');
    });

    test('no restaura si stock_descontado=false (pedido sin cobro)', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Refresco', stock: 5, controlStock: true);
      await _crearPedido(db, empresaId, 'ped7', stockDescontado: false);

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Refresco',
            precioUnitario: 2.0,
            cantidad: 2),
      ];

      await svc.restaurarStockPorCancelacion(
          empresaId: empresaId, pedidoId: 'ped7', lineas: lineas);

      // Sin cambios porque nunca se descontó
      expect(await _leerStock(db, empresaId, 'p1'), 5);
    });

    test('no restaura doble en anulación repetida', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Botella', stock: 7, controlStock: true);
      await _crearPedido(db, empresaId, 'ped8', stockDescontado: true);

      final lineas = [
        LineaPedido(
            productoId: 'p1',
            productoNombre: 'Botella',
            precioUnitario: 3.0,
            cantidad: 3),
      ];

      // Primera restauración
      await svc.restaurarStockPorCancelacion(
          empresaId: empresaId, pedidoId: 'ped8', lineas: lineas);
      expect(await _leerStock(db, empresaId, 'p1'), 10);

      // Segunda restauración — no-op (stock_descontado ya es false)
      await svc.restaurarStockPorCancelacion(
          empresaId: empresaId, pedidoId: 'ped8', lineas: lineas);
      expect(await _leerStock(db, empresaId, 'p1'), 10,
          reason: 'No debe restaurar dos veces');
    });
  });

  group('alertasStockStream', () {
    test('emite productos agotados y con stock bajo', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Agotado', stock: 0, stockMinimo: 5, controlStock: true);
      await _crearProducto(db, empresaId, 'p2',
          nombre: 'Bajo', stock: 3, stockMinimo: 5, controlStock: true);
      await _crearProducto(db, empresaId, 'p3',
          nombre: 'OK', stock: 50, stockMinimo: 5, controlStock: true);
      await _crearProducto(db, empresaId, 'p4',
          nombre: 'Sin control', stock: 0, stockMinimo: 5, controlStock: false);

      final alertas = await svc.productosConStockBajo(empresaId);

      expect(alertas.length, 2,
          reason: 'Solo p1 (agotado) y p2 (bajo), p3 OK, p4 sin control');
      expect(alertas.any((a) => a.productoId == 'p1' && a.agotado), isTrue);
      expect(alertas.any((a) => a.productoId == 'p2' && !a.agotado), isTrue);
      expect(alertas.any((a) => a.productoId == 'p3'), isFalse);
      expect(alertas.any((a) => a.productoId == 'p4'), isFalse);
    });

    test('los agotados aparecen antes que los bajos', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Bajo', stock: 3, stockMinimo: 5, controlStock: true);
      await _crearProducto(db, empresaId, 'p2',
          nombre: 'Agotado', stock: 0, stockMinimo: 5, controlStock: true);

      final alertas = await svc.productosConStockBajo(empresaId);
      expect(alertas.length, 2);
      expect(alertas.first.agotado, isTrue,
          reason: 'El agotado debe ir primero');
    });
  });

  group('ajustarStock', () {
    test('establece el stock al valor indicado', () async {
      await _crearProducto(db, empresaId, 'p1',
          nombre: 'Gin', stock: 5, controlStock: true);

      await svc.ajustarStock(
          empresaId: empresaId, productoId: 'p1', nuevoStock: 100);

      expect(await _leerStock(db, empresaId, 'p1'), 100);
    });
  });
}

