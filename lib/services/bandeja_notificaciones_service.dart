import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Bandeja de notificaciones in-app
//
// Estructura Firestore:
//   notificaciones/{empresaId}/items/{autoId}
//     titulo:          string
//     cuerpo:          string
//     tipo:            string   (tarea_asignada | factura_vencida | reserva_nueva | alerta_fiscal | nomina_pendiente)
//     timestamp:       Timestamp
//     leida:           bool
//     modulo_destino:  string   (tareas | facturacion | reservas | fiscal | nominas)
//     entidad_id:      string?  (ID del documento destino)
// ─────────────────────────────────────────────────────────────────────────────

enum TipoNotificacion {
  tareaAsignada,
  facturaVencida,
  reservaNueva,
  alertaFiscal,
  nominaPendiente,
}

extension TipoNotificacionX on TipoNotificacion {
  String get id => name;

  String get modulo {
    switch (this) {
      case TipoNotificacion.tareaAsignada:   return 'tareas';
      case TipoNotificacion.facturaVencida:  return 'facturacion';
      case TipoNotificacion.reservaNueva:    return 'reservas';
      case TipoNotificacion.alertaFiscal:    return 'fiscal';
      case TipoNotificacion.nominaPendiente: return 'nominas';
    }
  }

  String get emoji {
    switch (this) {
      case TipoNotificacion.tareaAsignada:   return '📌';
      case TipoNotificacion.facturaVencida:  return '💰';
      case TipoNotificacion.reservaNueva:    return '📅';
      case TipoNotificacion.alertaFiscal:    return '📋';
      case TipoNotificacion.nominaPendiente: return '💼';
    }
  }
}

class NotificacionInApp {
  final String id;
  final String titulo;
  final String cuerpo;
  final TipoNotificacion tipo;
  final DateTime timestamp;
  final bool leida;
  final String moduloDestino;
  final String? entidadId;
  // Datos del remitente (cuando aplica)
  final String? remitenteNombre;
  final String? remitenteTelefono;
  final String? remitenteEmail;
  // Campos extra de reserva (web form + genéricos)
  final String? ubicacion;
  final String? personas;
  final bool? alergenos;
  final String? alergenosDetalle;

  const NotificacionInApp({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    required this.timestamp,
    required this.leida,
    required this.moduloDestino,
    this.entidadId,
    this.remitenteNombre,
    this.remitenteTelefono,
    this.remitenteEmail,
    this.ubicacion,
    this.personas,
    this.alergenos,
    this.alergenosDetalle,
  });

  factory NotificacionInApp.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificacionInApp(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      cuerpo: data['cuerpo'] as String? ?? '',
      tipo: _parseTipo(data['tipo'] as String? ?? ''),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leida: data['leida'] as bool? ?? false,
      moduloDestino: data['modulo_destino'] as String? ?? '',
      entidadId: data['entidad_id'] as String?,
      remitenteNombre: data['remitente_nombre'] as String?,
      remitenteTelefono: data['remitente_telefono'] as String?,
      remitenteEmail: data['remitente_email'] as String?,
      ubicacion: data['ubicacion'] as String?,
      personas: data['personas'] as String?,
      alergenos: data['alergenos'] as bool?,
      alergenosDetalle: data['alergenos_detalle'] as String?,
    );
  }

  static TipoNotificacion _parseTipo(String raw) {
    // Soporta camelCase (Cloud Function v1) y snake_case (posibles variantes)
    switch (raw) {
      case 'reservaNueva':
      case 'reserva_nueva':
      case 'nueva_reserva':
        return TipoNotificacion.reservaNueva;
      case 'tareaAsignada':
      case 'tarea_asignada':
        return TipoNotificacion.tareaAsignada;
      case 'facturaVencida':
      case 'factura_vencida':
        return TipoNotificacion.facturaVencida;
      case 'alertaFiscal':
      case 'alerta_fiscal':
        return TipoNotificacion.alertaFiscal;
      case 'nominaPendiente':
      case 'nomina_pendiente':
        return TipoNotificacion.nominaPendiente;
      default:
        return TipoNotificacion.tareaAsignada; // fallback
    }
  }
}

class BandejaNotificacionesService {
  static final BandejaNotificacionesService _i = BandejaNotificacionesService._();
  factory BandejaNotificacionesService() => _i;
  BandejaNotificacionesService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('notificaciones').doc(empresaId).collection('items');

  // ── STREAMS ─────────────────────────────────────────────────────────────

  Stream<List<NotificacionInApp>> notificacionesStream(String empresaId) =>
      _col(empresaId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map(NotificacionInApp.fromFirestore).toList());

  Stream<int> noLeidasCount(String empresaId) =>
      _col(empresaId)
          .where('leida', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.length);

  // ── ACCIONES ────────────────────────────────────────────────────────────

  Future<void> marcarLeida(String empresaId, String notifId) =>
      _col(empresaId).doc(notifId).update({'leida': true});

  Future<void> marcarTodasLeidas(String empresaId) async {
    final snap = await _col(empresaId).where('leida', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }

  Future<void> eliminar(String empresaId, String notifId) =>
      _col(empresaId).doc(notifId).delete();

  Future<void> eliminarAntiguas(String empresaId, {int diasLimite = 30}) async {
    final limite = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: diasLimite)));
    final snap = await _col(empresaId)
        .where('timestamp', isLessThan: limite)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── CREAR (usado por Cloud Functions internamente, o manualmente) ───────

  Future<void> crear({
    required String empresaId,
    required String titulo,
    required String cuerpo,
    required TipoNotificacion tipo,
    String? entidadId,
    String? remitenteNombre,
    String? remitenteTelefono,
    String? remitenteEmail,
  }) async {
    await _col(empresaId).add({
      'titulo':          titulo,
      'cuerpo':          cuerpo,
      'tipo':            tipo.id,
      'timestamp':       FieldValue.serverTimestamp(),
      'leida':           false,
      'modulo_destino':  tipo.modulo,
      'entidad_id':      entidadId,
      if (remitenteNombre != null) 'remitente_nombre': remitenteNombre,
      if (remitenteTelefono != null) 'remitente_telefono': remitenteTelefono,
      if (remitenteEmail != null) 'remitente_email': remitenteEmail,
    });
  }
}

