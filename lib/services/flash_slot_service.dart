import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flash_slot_model.dart';

class FlashSlotService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _ref(String negocioId) =>
      _db.collection('negocios_publicos').doc(negocioId).collection('flash_slots');

  static Future<String> crearSlot(FlashSlotModel slot) async {
    final ref = await _ref(slot.negocioId).add(slot.toFirestore());
    await _db.collection('flash_slots_notificaciones').add({
      'slot_id': ref.id,
      'negocio_id': slot.negocioId,
      'negocio_nombre': slot.negocioNombre,
      'servicio_nombre': slot.servicioNombre,
      'precio_final': slot.precioFinal,
      'huecos_totales': slot.huecosTotal,
      'procesado': false,
      'creado_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> cancelarSlot(String negocioId, String slotId) =>
      _ref(negocioId).doc(slotId).update({'estado': 'cancelado'});

  static Stream<List<FlashSlotModel>> escucharActivos(String negocioId) =>
      _ref(negocioId)
          .where('estado', isEqualTo: 'activo')
          .orderBy('creado_at', descending: true)
          .snapshots()
          .map((s) => s.docs.map(FlashSlotModel.fromFirestore).toList());

  static Stream<List<FlashSlotModel>> escucharHistorial(String negocioId) =>
      _ref(negocioId)
          .orderBy('creado_at', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map(FlashSlotModel.fromFirestore).toList());

  static Stream<List<FlashSlotModel>> escucharTodosActivos() {
    final ahora = Timestamp.fromDate(DateTime.now());
    return _db
        .collectionGroup('flash_slots')
        .where('estado', isEqualTo: 'activo')
        .where('fecha_hora_expiracion', isGreaterThan: ahora)
        .orderBy('fecha_hora_expiracion')
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(FlashSlotModel.fromFirestore).toList());
  }

  static Future<String> reservarSlot({
    required String negocioId,
    required String slotId,
    required FlashSlotModel slot,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No autenticado');
    final slotRef = _ref(negocioId).doc(slotId);
    String reservaId = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(slotRef);
      if (!snap.exists) throw Exception('Slot no encontrado');
      final d = snap.data()!;
      if ((d['estado'] as String?) != 'activo') throw Exception('Slot no disponible');
      final exp = (d['fecha_hora_expiracion'] as Timestamp?)?.toDate();
      if (exp != null && DateTime.now().isAfter(exp)) throw Exception('Expirado');
      final res = d['huecos_reservados'] as int? ?? 0;
      final tot = d['huecos_totales'] as int? ?? 1;
      if (res >= tot) throw Exception('Sin huecos');
      final nuevos = res + 1;
      final rRef = _db.collection('empresas').doc(slot.empresaId).collection('reservas').doc();
      reservaId = rRef.id;
      tx.set(rRef, {
        'usuario_uid': uid, 'estado': 'pendiente', 'origen': 'flash_slot',
        'flash_slot_id': slotId, 'negocio_id': negocioId,
        'negocio_nombre': slot.negocioNombre, 'servicio_nombre': slot.servicioNombre,
        'precio': slot.precioFinal, 'fecha_hora': Timestamp.fromDate(slot.fechaHoraInicio),
        'creado_en': FieldValue.serverTimestamp(),
      });
      tx.update(slotRef, {
        'huecos_reservados': nuevos,
        'estado': nuevos >= tot ? 'completo' : 'activo',
        'reservas_ids': FieldValue.arrayUnion([rRef.id]),
      });
    });
    return reservaId;
  }
}

