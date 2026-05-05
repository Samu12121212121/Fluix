import 'package:cloud_firestore/cloud_firestore.dart';

class MensajeContactoWeb {
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final String asunto;
  final String mensaje;
  final String origen;
  final bool leido;
  final bool respondido;
  final DateTime fechaCreacion;
  final String? respuesta;
  final DateTime? fechaRespuesta;

  MensajeContactoWeb({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    required this.asunto,
    required this.mensaje,
    required this.origen,
    required this.leido,
    required this.respondido,
    required this.fechaCreacion,
    this.respuesta,
    this.fechaRespuesta,
  });

  factory MensajeContactoWeb.fromMap(Map<String, dynamic> map) {
    return MensajeContactoWeb(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'],
      asunto: map['asunto'] ?? '',
      mensaje: map['mensaje'] ?? '',
      origen: map['origen'] ?? 'web',
      leido: map['leido'] ?? false,
      respondido: map['respondido'] ?? false,
      fechaCreacion: (map['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respuesta: map['respuesta'],
      fechaRespuesta: (map['fecha_respuesta'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      if (telefono != null) 'telefono': telefono,
      'asunto': asunto,
      'mensaje': mensaje,
      'origen': origen,
      'leido': leido,
      'respondido': respondido,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      if (respuesta != null) 'respuesta': respuesta,
      if (fechaRespuesta != null) 'fecha_respuesta': Timestamp.fromDate(fechaRespuesta!),
    };
  }
}

class ContactoWebService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtener todos los mensajes de contacto
  Stream<List<MensajeContactoWeb>> obtenerMensajes(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MensajeContactoWeb.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Marcar mensaje como leído
  Future<void> marcarComoLeido(String empresaId, String mensajeId) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .doc(mensajeId)
        .update({'leido': true});
  }

  /// Responder mensaje
  Future<void> responderMensaje(String empresaId, String mensajeId, String respuesta) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .doc(mensajeId)
        .update({
      'respondido': true,
      'respuesta': respuesta,
      'fecha_respuesta': FieldValue.serverTimestamp(),
    });
  }

  /// Eliminar mensaje
  Future<void> eliminarMensaje(String empresaId, String mensajeId) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .doc(mensajeId)
        .delete();
  }

  /// Obtener contador de mensajes sin leer
  Stream<int> contarMensajesSinLeer(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .where('leido', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}


