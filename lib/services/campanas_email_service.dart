import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/campana_email.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SERVICIO — Campañas de Email Marketing
// El envío real lo gestiona una Cloud Function (Resend) que escucha
// cuando estado cambia a 'enviando'.
// ═════════════════════════════════════════════════════════════════════════════

class CampanasEmailService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('campanas_email');

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Stream<List<CampanaEmail>> obtenerCampanas(String empresaId) {
    return _col(empresaId)
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CampanaEmail.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<String> guardarCampana(String empresaId, CampanaEmail campana) async {
    final data = campana.toMap();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    if (campana.id.isEmpty) {
      data['fecha_creacion'] = FieldValue.serverTimestamp();
      final ref = await _col(empresaId).add(data);
      return ref.id;
    } else {
      await _col(empresaId).doc(campana.id).set(data, SetOptions(merge: true));
      return campana.id;
    }
  }

  Future<void> eliminarCampana(String empresaId, String campanaId) async {
    await _col(empresaId).doc(campanaId).delete();
  }

  Future<void> duplicarCampana(String empresaId, CampanaEmail original) async {
    final data = original.toMap();
    data['nombre']           = '${original.nombre} (copia)';
    data['estado']           = EstadoCampana.borrador.id;
    data['total_enviados']   = 0;
    data['total_abiertos']   = 0;
    data['total_clicks']     = 0;
    data['fecha_creacion']   = FieldValue.serverTimestamp();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    data.remove('fecha_envio');
    await _col(empresaId).add(data);
  }

  // ── ENVÍO / PROGRAMACIÓN ──────────────────────────────────────────────────

  /// Marca la campaña como 'enviando'. Una Cloud Function (Resend) recoge
  /// el documento y ejecuta el envío real, actualizando total_enviados,
  /// total_abiertos y estado final.
  Future<void> enviarAhora(String empresaId, String campanaId) async {
    await _col(empresaId).doc(campanaId).update({
      'estado':              EstadoCampana.enviando.id,
      'fecha_envio':         FieldValue.serverTimestamp(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> programar(String empresaId, String campanaId, DateTime fecha) async {
    await _col(empresaId).doc(campanaId).update({
      'estado':              EstadoCampana.programada.id,
      'fecha_envio':         Timestamp.fromDate(fecha),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelarProgramacion(String empresaId, String campanaId) async {
    await _col(empresaId).doc(campanaId).update({
      'estado':              EstadoCampana.borrador.id,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // ── ESTADÍSTICAS DE DESTINATARIOS ─────────────────────────────────────────

  Future<int> contarDestinatarios(
      String empresaId, SegmentoCampana segmento, List<String> manual) async {
    switch (segmento) {
      case SegmentoCampana.manual:
        return manual.where((e) => e.contains('@')).length;
      case SegmentoCampana.clientesActivos:
        final limite = DateTime.now().subtract(const Duration(days: 90));
        final snap = await _db
            .collection('empresas')
            .doc(empresaId)
            .collection('clientes')
            .where('ultima_visita',
                isGreaterThanOrEqualTo: Timestamp.fromDate(limite))
            .where('email', isNull: false)
            .count()
            .get();
        return snap.count ?? 0;
      case SegmentoCampana.todos:
        final snap = await _db
            .collection('empresas')
            .doc(empresaId)
            .collection('clientes')
            .where('email', isNull: false)
            .count()
            .get();
        return snap.count ?? 0;
    }
  }
}
