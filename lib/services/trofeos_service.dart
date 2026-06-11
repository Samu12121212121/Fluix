import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/perfil_cliente/models/trofeo_def.dart';

class TrofeosService {
  static final _db = FirebaseFirestore.instance;

  // Otorga un trofeo al usuario (si no lo tiene ya) y suma las monedas
  static Future<bool> otorgarTrofeo(String uid, String trofeoId) async {
    final def = kTrofeos.where((t) => t.id == trofeoId).firstOrNull;
    if (def == null) return false;

    final ref = _db.collection('usuarios').doc(uid).collection('trofeos').doc(trofeoId);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['completado'] as bool? ?? false)) return false;

    // Comprobar multiplicador ×2 activo
    final userSnap = await _db.collection('usuarios').doc(uid).get();
    final multiExpira = (userSnap.data()?['canje_multi_expira'] as Timestamp?)?.toDate();
    final multiplicador = (multiExpira != null && multiExpira.isAfter(DateTime.now())) ? 2 : 1;
    final monedasFinales = def.monedas * multiplicador;

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
    } else {
      await ref.set({'completado': false, 'progreso': progreso}, SetOptions(merge: true));
      return false;
    }
  }

  // Stream de todos los trofeos del usuario
  static Stream<Map<String, Map<String, dynamic>>> streamTrofeos(String uid) {
    return _db
        .collection('usuarios').doc(uid).collection('trofeos')
        .snapshots()
        .map((snap) => {
          for (final doc in snap.docs) doc.id: doc.data(),
        });
  }

  // Stream de monedas del usuario
  static Stream<int> streamMonedas(String uid) {
    return _db.collection('usuarios').doc(uid).snapshots().map(
      (snap) => (snap.data()?['monedas'] as int?) ?? 0,
    );
  }

  // Otorga el trofeo bienvenido si es la primera vez
  static Future<void> verificarBienvenido(String uid) async {
    await otorgarTrofeo(uid, 'bienvenido');
  }
}
