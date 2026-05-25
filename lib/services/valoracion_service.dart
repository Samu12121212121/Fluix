import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/valoracion_model.dart';

class ValoracionService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _valRef(String negocioId) =>
      _db.collection('negocios_publicos').doc(negocioId).collection('valoraciones');

  // ── Publicar valoración ────────────────────────────────────────
  static Future<void> publicar({
    required String negocioId,
    required String reservaId,
    required int estrellas,
    required String comentario,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No autenticado');

    // Verificar que no haya valorado ya esta reserva
    final dup = await _valRef(negocioId)
        .where('cliente_id', isEqualTo: user.uid)
        .where('reserva_id', isEqualTo: reservaId)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) throw Exception('Ya has valorado esta reserva');

    // Obtener datos del usuario
    final userDoc = await _db.collection('usuarios').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final clienteNombre = userData['nombre'] as String? ?? user.displayName ?? 'Cliente';
    final clienteFoto   = userData['foto_url'] as String? ?? user.photoURL;

    // Batch: crear valoración + eliminar pendiente
    final batch = _db.batch();
    final valRef = _valRef(negocioId).doc();
    batch.set(valRef, {
      'negocio_id':      negocioId,
      'cliente_id':      user.uid,
      'cliente_nombre':  clienteNombre,
      if (clienteFoto != null) 'cliente_foto_url': clienteFoto,
      'reserva_id':      reservaId,
      'estrellas':       estrellas,
      'comentario':      comentario,
      'visible':         true,
      'creado_at':       FieldValue.serverTimestamp(),
    });

    // Eliminar pendiente de valorar
    final pendRef = _db
        .collection('usuarios').doc(user.uid)
        .collection('pendientes_valorar').doc(reservaId);
    batch.delete(pendRef);

    await batch.commit();
  }

  // ── Responder valoración (negocio) ────────────────────────────
  static Future<void> responder({
    required String negocioId,
    required String valoracionId,
    required String respuesta,
  }) async {
    await _valRef(negocioId).doc(valoracionId).update({
      'respuesta_negocio': respuesta,
      'respuesta_at':      FieldValue.serverTimestamp(),
    });
  }

  // ── Escuchar valoraciones de un negocio (paginado) ─────────────
  static Stream<List<ValoracionModel>> escucharPorNegocio(
    String negocioId, {
    DocumentSnapshot? ultimoDoc,
    int limite = 20,
  }) {
    var q = _valRef(negocioId)
        .where('visible', isEqualTo: true)
        .orderBy('creado_at', descending: true)
        .limit(limite);
    if (ultimoDoc != null) q = q.startAfterDocument(ultimoDoc);
    return q.snapshots().map(
        (snap) => snap.docs.map(ValoracionModel.fromFirestore).toList());
  }

  // ── Obtener todas las valoraciones sin paginación (panel negocio) ─
  static Stream<List<ValoracionModel>> escucharTodasDelNegocio(String negocioId) =>
      _valRef(negocioId)
          .orderBy('creado_at', descending: true)
          .limit(200)
          .snapshots()
          .map((s) => s.docs.map(ValoracionModel.fromFirestore).toList());

  // ── Pendientes de valorar del cliente ─────────────────────────
  static Stream<List<PendienteValorar>> escucharPendientes(String uid) =>
      _db
          .collection('usuarios').doc(uid)
          .collection('pendientes_valorar')
          .where('expira_at', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .snapshots()
          .map((s) => s.docs.map(PendienteValorar.fromFirestore).toList());

  // ── Verificar si ya valoró ─────────────────────────────────────
  static Future<bool> yaValoroReserva(String negocioId, String reservaId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _valRef(negocioId)
        .where('cliente_id', isEqualTo: uid)
        .where('reserva_id', isEqualTo: reservaId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Cargar primera página (para paginación manual) ─────────────
  static Future<({List<ValoracionModel> items, DocumentSnapshot? last})>
      cargarPagina(String negocioId, {DocumentSnapshot? desde, int limite = 20}) async {
    var q = _valRef(negocioId)
        .where('visible', isEqualTo: true)
        .orderBy('creado_at', descending: true)
        .limit(limite);
    if (desde != null) q = q.startAfterDocument(desde);
    final snap = await q.get();
    final items = snap.docs.map(ValoracionModel.fromFirestore).toList();
    final last  = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (items: items, last: last);
  }

  // ── Negocios con mejores ratings (para Tendencias) ────────────
  static Stream<QuerySnapshot> escucharTendencias({int minValoraciones = 5}) =>
      _db
          .collection('negocios_publicos')
          .where('activo', isEqualTo: true)
          .where('total_valoraciones', isGreaterThanOrEqualTo: minValoraciones)
          .orderBy('total_valoraciones', descending: true)
          .orderBy('rating_fluix', descending: true)
          .limit(30)
          .snapshots();
}

