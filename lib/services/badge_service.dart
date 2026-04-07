import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Badges numéricos en iconos del menú
//
// Proporciona streams en tiempo real para cada tipo de badge.
// ─────────────────────────────────────────────────────────────────────────────

class BadgeCounts {
  final int tareasUrgentes;
  final int pedidosPendientes;
  final int notificacionesSinLeer;
  final int reservasHoyPendientes;

  const BadgeCounts({
    this.tareasUrgentes = 0,
    this.pedidosPendientes = 0,
    this.notificacionesSinLeer = 0,
    this.reservasHoyPendientes = 0,
  });

  int get total =>
      tareasUrgentes + pedidosPendientes +
      notificacionesSinLeer + reservasHoyPendientes;
}

class BadgeService {
  static final BadgeService _i = BadgeService._();
  factory BadgeService() => _i;
  BadgeService._();

  final _db = FirebaseFirestore.instance;

  /// Stream combinado de todos los badges, actualizado en tiempo real.
  Stream<BadgeCounts> badgesStream({
    required String empresaId,
    required String userId,
  }) {
    final controller = StreamController<BadgeCounts>.broadcast();
    int tareas = 0, pedidos = 0, notif = 0, reservas = 0;

    void emit() {
      if (!controller.isClosed) {
        controller.add(BadgeCounts(
          tareasUrgentes: tareas,
          pedidosPendientes: pedidos,
          notificacionesSinLeer: notif,
          reservasHoyPendientes: reservas,
        ));
      }
    }

    // Tareas urgentes/vencidas asignadas al usuario
    final sub1 = _db
        .collection('empresas').doc(empresaId)
        .collection('tareas')
        .where('usuario_asignado_id', isEqualTo: userId)
        .where('estado', whereIn: ['pendiente', 'enProgreso'])
        .snapshots()
        .listen((snap) {
      final ahora = DateTime.now();
      tareas = snap.docs.where((d) {
        final data = d.data();
        final fl = (data['fecha_limite'] as Timestamp?)?.toDate();
        final urgente = data['prioridad'] == 'urgente';
        final vencida = fl != null && fl.isBefore(ahora);
        return urgente || vencida;
      }).length;
      emit();
    });

    // Pedidos pendientes o listos
    final sub2 = _db
        .collection('empresas').doc(empresaId)
        .collection('pedidos')
        .where('estado', whereIn: ['pendiente', 'listo'])
        .snapshots()
        .listen((snap) {
      pedidos = snap.docs.length;
      emit();
    });

    // Notificaciones no leídas
    final sub3 = _db
        .collection('notificaciones').doc(empresaId)
        .collection('items')
        .where('leida', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      notif = snap.docs.length;
      emit();
    });

    // Reservas hoy sin confirmar
    final hoyInicio = DateTime.now();
    final inicio = DateTime(hoyInicio.year, hoyInicio.month, hoyInicio.day);
    final fin = inicio.add(const Duration(days: 1));
    final sub4 = _db
        .collection('empresas').doc(empresaId)
        .collection('reservas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snap) {
      reservas = snap.docs.length;
      emit();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
      sub4.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Marcar notificaciones como vistas al entrar al módulo
  Future<void> marcarModuloVisto(String empresaId, String modulo) async {
    // Para notificaciones: marcar como leídas las del tipo de módulo
    final snap = await _db
        .collection('notificaciones').doc(empresaId)
        .collection('items')
        .where('modulo_destino', isEqualTo: modulo)
        .where('leida', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }
}

