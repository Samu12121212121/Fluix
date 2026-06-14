import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../features/perfil_cliente/models/trofeo_def.dart';
import '../features/perfil_cliente/widgets/trofeo_desbloqueado_overlay.dart';
import '../domain/modelos/monedero.dart';

class TrofeosService {
  static final _db = FirebaseFirestore.instance;

  // Otorga un trofeo al usuario (si no lo tiene ya) y suma las monedas
  static Future<bool> otorgarTrofeo(String uid, String trofeoId) async {
    final def = kTrofeos.where((t) => t.id == trofeoId).firstOrNull;
    if (def == null) return false;

    final ref = _db.collection('usuarios').doc(uid).collection('trofeos').doc(trofeoId);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['completado'] as bool? ?? false)) return false;

    final userSnap = await _db.collection('usuarios').doc(uid).get();
    final multiExpira = (userSnap.data()?['canje_multi_expira'] as Timestamp?)?.toDate();
    final multiplicador = (multiExpira != null && multiExpira.isAfter(DateTime.now())) ? 2 : 1;
    final monedasFinales = def.monedas * multiplicador;

    final monederoRef = _db.collection('usuarios').doc(uid).collection('monedero').doc('main');
    final batch = _db.batch();
    batch.set(ref, {
      'completado': true,
      'fecha': FieldValue.serverTimestamp(),
      'monedas_otorgadas': monedasFinales,
      if (multiplicador == 2) 'con_multiplicador': true,
    });
    batch.update(_db.collection('usuarios').doc(uid), {
      'monedas': FieldValue.increment(monedasFinales),
    });
    batch.set(monederoRef, {
      'saldo': FieldValue.increment(monedasFinales),
      'total_ganado': FieldValue.increment(monedasFinales),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final txRef = monederoRef.collection('transacciones').doc();
    batch.set(txRef, {
      'tipo': 'ganancia',
      'cantidad': monedasFinales,
      'concepto': '🏆 ${def.titulo}',
      'trofeo_id': trofeoId,
      'fecha': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return true;
  }

  // Actualiza el progreso de un trofeo progresivo; lo completa si alcanza la meta
  static Future<bool> actualizarProgreso(String uid, String trofeoId, int progreso) async {
    final def = kTrofeos.where((t) => t.id == trofeoId).firstOrNull;
    if (def == null || def.meta == null) return false;

    final ref = _db.collection('usuarios').doc(uid).collection('trofeos').doc(trofeoId);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['completado'] as bool? ?? false)) return false;

    if (progreso >= def.meta!) {
      return otorgarTrofeo(uid, trofeoId);
    }
    await ref.set({'completado': false, 'progreso': progreso}, SetOptions(merge: true));
    return false;
  }

  // Stream de todos los trofeos del usuario
  static Stream<Map<String, Map<String, dynamic>>> streamTrofeos(String uid) {
    return _db
        .collection('usuarios').doc(uid).collection('trofeos')
        .snapshots()
        .map((snap) => {for (final doc in snap.docs) doc.id: doc.data()});
  }

  // Stream de monedas del usuario (campo raíz, para compatibilidad)
  static Stream<int> streamMonedas(String uid) {
    return _db.collection('usuarios').doc(uid).snapshots().map(
      (snap) => (snap.data()?['monedas'] as int?) ?? 0,
    );
  }

  // Stream del doc monedero completo
  static Stream<MonederoModel> streamMonedero(String uid) {
    return _db.collection('usuarios').doc(uid).collection('monedero').doc('main')
        .snapshots()
        .map((snap) => snap.exists ? MonederoModel.fromFirestore(snap) : const MonederoModel(saldo: 0, totalGanado: 0, totalCanjeado: 0));
  }

  // Historial de transacciones (últimas 50)
  static Stream<List<TransaccionModel>> streamTransacciones(String uid) {
    return _db
        .collection('usuarios').doc(uid).collection('monedero').doc('main')
        .collection('transacciones')
        .orderBy('fecha', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(TransaccionModel.fromFirestore).toList());
  }

  // Stream de nuevo trofeo desbloqueado (para mostrar overlay)
  static Stream<String?> streamUltimoTrofeoDesbloqueado(String uid) {
    return _db
        .collection('usuarios').doc(uid).collection('trofeos')
        .where('completado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first.id : null);
  }

  // Progreso por categoría: {categoria: {completados, total}}
  static Map<TrofeoCategoria, ({int completados, int total})> progresoCategoria(
    Map<String, Map<String, dynamic>> datos,
  ) {
    final result = <TrofeoCategoria, ({int completados, int total})>{};
    for (final cat in TrofeoCategoria.values) {
      final defs = kTrofeos.where((t) => t.categoria == cat && !t.oculto).toList();
      final completados = defs.where((t) => datos[t.id]?['completado'] == true).length;
      result[cat] = (completados: completados, total: defs.length);
    }
    return result;
  }

  // Otorga el trofeo bienvenido si es la primera vez
  static Future<void> verificarBienvenido(String uid) async {
    await otorgarTrofeo(uid, 'bienvenido');
  }

  // Muestra el overlay de trofeo desbloqueado desde cualquier pantalla
  static Future<void> mostrarOverlayTrofeo(BuildContext context, String trofeoId) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => TrofeoDesbloqueadoOverlay(
        trofeoId: trofeoId,
        onDismiss: () => Navigator.of(ctx, rootNavigator: true).pop(),
      ),
    );
  }

  // Evalúa y otorga trofeos de reserva desde el cliente (no requiere Cloud Functions)
  // Llamar justo después de crear/confirmar una reserva B2C
  static Future<void> evaluarTrofeosReservaCliente(
      String uid, BuildContext context) async {
    final List<String> otorgados = [];

    // Siempre intenta bienvenido
    if (await otorgarTrofeo(uid, 'bienvenido')) otorgados.add('bienvenido');

    // Contar reservas del usuario para trofeos progresivos
    final snap = await _db.collectionGroup('reservas')
        .where('cliente_uid', isEqualTo: uid)
        .get();
    final total = snap.size;

    for (final check in [
      (1, 'primera_reserva'), (3, 'tres_reservas'), (5, 'cinco_reservas'),
      (10, 'diez_reservas'), (25, 'veinticinco_reservas'), (50, 'cincuenta_reservas'),
    ]) {
      if (total >= check.$1) {
        if (await otorgarTrofeo(uid, check.$2)) otorgados.add(check.$2);
      }
    }

    // Mostrar overlay del trofeo más reciente (el más relevante)
    if (otorgados.isNotEmpty && context.mounted) {
      await mostrarOverlayTrofeo(context, otorgados.last);
    }
  }
}

// Alias de compatibilidad para pantalla_trofeos.dart existente
class TrofeoService {
  static Stream<Map<String, Map<String, dynamic>>> streamTrofeos(String uid) =>
      TrofeosService.streamTrofeos(uid);
  static Stream<int> streamMonedas(String uid) => TrofeosService.streamMonedas(uid);
}
