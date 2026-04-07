import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de triggers para actualizar estadísticas en tiempo real
/// cuando ocurren eventos dentro de la app.
///
/// Llama a estos métodos desde los servicios de reservas, pedidos, clientes, etc.
/// Actualiza el documento empresas/{id}/estadisticas/resumen con FieldValue.increment
/// para que tanto la app como la web lo lean en tiempo real.
class EstadisticasTriggerService {
  static final EstadisticasTriggerService _i = EstadisticasTriggerService._();
  factory EstadisticasTriggerService() => _i;
  EstadisticasTriggerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _resumen(String empresaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('estadisticas')
      .doc('resumen');

  // ── Reservas ──────────────────────────────────────────────────────────────

  Future<void> reservaCreada(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'reservas_total': FieldValue.increment(1),
        'reservas_mes': FieldValue.increment(1),
        'reservas_pendientes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> reservaConfirmada(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'reservas_pendientes': FieldValue.increment(-1),
        'reservas_confirmadas': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> reservaCancelada(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'reservas_pendientes': FieldValue.increment(-1),
        'reservas_canceladas': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> reservaCompletada(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'reservas_confirmadas': FieldValue.increment(-1),
        'reservas_completadas': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Pedidos ───────────────────────────────────────────────────────────────

  Future<void> pedidoCreado(String empresaId, double total) async {
    try {
      await _resumen(empresaId).set({
        'pedidos_total': FieldValue.increment(1),
        'pedidos_mes': FieldValue.increment(1),
        'pedidos_pendientes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> pedidoPagado(String empresaId, double total) async {
    try {
      await _resumen(empresaId).set({
        'pedidos_pendientes': FieldValue.increment(-1),
        'ingresos_pedidos_mes': FieldValue.increment(total),
        'ingresos_totales_mes': FieldValue.increment(total),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Clientes ──────────────────────────────────────────────────────────────

  Future<void> clienteCreado(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'total_clientes': FieldValue.increment(1),
        'nuevos_clientes_mes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ─��� Facturas ──────────────────────────────────────────────────────────────

  Future<void> facturaCreada(String empresaId) async {
    try {
      await _resumen(empresaId).set({
        'facturas_mes': FieldValue.increment(1),
        'facturas_pendientes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> facturaPagada(String empresaId, double total) async {
    try {
      await _resumen(empresaId).set({
        'facturas_pendientes': FieldValue.increment(-1),
        'facturas_pagadas_mes': FieldValue.increment(1),
        'ingresos_facturas_mes': FieldValue.increment(total),
        'ingresos_totales_mes': FieldValue.increment(total),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Valoraciones ─────────────────────────────────────────────────────────

  Future<void> valoracionCreada(String empresaId, int estrellas) async {
    try {
      // Leemos el doc para recalcular el promedio correcto
      final doc = await _resumen(empresaId).get();
      final data = doc.exists ? doc.data() as Map<String, dynamic> : {};
      final total = (data['total_valoraciones'] as num?)?.toInt() ?? 0;
      final suma = (data['suma_calificaciones'] as num?)?.toDouble() ?? 0;
      final nuevoTotal = total + 1;
      final nuevaSuma = suma + estrellas;

      await _resumen(empresaId).set({
        'total_valoraciones': nuevoTotal,
        'suma_calificaciones': nuevaSuma,
        'valoracion_promedio': nuevaSuma / nuevoTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

