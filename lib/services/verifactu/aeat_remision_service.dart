import 'package:cloud_firestore/cloud_firestore.dart';

/// Encola registros Verifactu para envío a la AEAT.
///
/// ⏳ PLACEHOLDER — Envío SOAP real previsto para Q3 2026 (W7 del roadmap).
/// Por ahora almacena el XML en Firestore para procesarlo en background.
///
/// Normativa: RD 1007/2023 art. 9 (máx. 1000 registros/envío, parámetro "t").
class AeatRemisionService {
  final String empresaId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AeatRemisionService(this.empresaId);

  CollectionReference<Map<String, dynamic>> get _cola =>
      _db.collection('empresas').doc(empresaId).collection('cola_verifactu');

  /// Encola un XML para envío a la AEAT.
  ///
  /// El XML se almacena en Firestore con estado [pendiente].
  /// Una Cloud Function (futuro) procesará la cola y enviará vía SOAP.
  Future<void> encolarParaEnvio({
    required String xmlPayload,
    required String facturaId,
    required String nifEmisor,
    required String numeroFactura,
  }) async {
    await _cola.add({
      'factura_id': facturaId,
      'nif_emisor': nifEmisor,
      'numero_factura': numeroFactura,
      'xml_payload': xmlPayload,
      'estado': 'pendiente', // pendiente | enviado | aceptado | rechazado
      'intentos': 0,
      'fecha_encolado': Timestamp.fromDate(DateTime.now()),
      'fecha_envio': null,
      'respuesta_aeat': null,
    });
  }

  /// Obtiene el número de registros pendientes de envío.
  Future<int> contarPendientes() async {
    final snap = await _cola
        .where('estado', isEqualTo: 'pendiente')
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Stream de registros pendientes para monitoreo.
  Stream<int> pendientesStream() {
    return _cola
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}

