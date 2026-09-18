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
  pedidoNuevo,
  clienteNuevo,
  contactoWeb,
  sugerencia,
  generica,
  vacacionesSolicitadas,
}

extension TipoNotificacionX on TipoNotificacion {
  String get id => name;

  String get modulo {
    switch (this) {
      case TipoNotificacion.tareaAsignada:         return 'tareas';
      case TipoNotificacion.facturaVencida:        return 'facturacion';
      case TipoNotificacion.reservaNueva:          return 'reservas';
      case TipoNotificacion.alertaFiscal:          return 'fiscal';
      case TipoNotificacion.nominaPendiente:       return 'nominas';
      case TipoNotificacion.pedidoNuevo:           return 'pedidos';
      case TipoNotificacion.clienteNuevo:          return 'clientes';
      case TipoNotificacion.contactoWeb:           return 'web';
      case TipoNotificacion.sugerencia:            return '';
      case TipoNotificacion.generica:              return '';
      case TipoNotificacion.vacacionesSolicitadas: return 'vacaciones';
    }
  }

  String get emoji {
    switch (this) {
      case TipoNotificacion.tareaAsignada:         return '📌';
      case TipoNotificacion.facturaVencida:        return '💰';
      case TipoNotificacion.reservaNueva:          return '📅';
      case TipoNotificacion.alertaFiscal:          return '📋';
      case TipoNotificacion.nominaPendiente:       return '💼';
      case TipoNotificacion.pedidoNuevo:           return '📦';
      case TipoNotificacion.clienteNuevo:          return '👤';
      case TipoNotificacion.contactoWeb:           return '💬';
      case TipoNotificacion.sugerencia:            return '💡';
      case TipoNotificacion.generica:              return '🔔';
      case TipoNotificacion.vacacionesSolicitadas: return '🏖️';
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
    switch (raw) {
      case 'reservaNueva':
      case 'reserva_nueva':
      case 'nueva_reserva':
      case 'cita_nueva':
      case 'citaNueva':
        return TipoNotificacion.reservaNueva;
      case 'tareaAsignada':
      case 'tarea_asignada':
      case 'tarea_nueva':
      case 'tareaNueva':
        return TipoNotificacion.tareaAsignada;
      case 'facturaVencida':
      case 'factura_vencida':
      case 'factura_nueva':
      case 'facturaNueva':
        return TipoNotificacion.facturaVencida;
      case 'alertaFiscal':
      case 'alerta_fiscal':
        return TipoNotificacion.alertaFiscal;
      case 'nominaPendiente':
      case 'nomina_pendiente':
        return TipoNotificacion.nominaPendiente;
      case 'pedidoNuevo':
      case 'pedido_nuevo':
      case 'nuevo_pedido':
        return TipoNotificacion.pedidoNuevo;
      case 'clienteNuevo':
      case 'cliente_nuevo':
        return TipoNotificacion.clienteNuevo;
      case 'contactoWeb':
      case 'contacto_web':
      case 'contacto_nuevo':
      case 'mensaje_contacto':
      case 'mensaje_web':
        return TipoNotificacion.contactoWeb;
      case 'sugerencia':
        return TipoNotificacion.sugerencia;
      case 'vacacionesSolicitadas':
      case 'vacaciones_solicitadas':
        return TipoNotificacion.vacacionesSolicitadas;
      default:
        return TipoNotificacion.generica;
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

  // ── SEMBRAR EJEMPLOS (uno por cada tipo) ────────────────────────────────

  Future<void> sembrarEjemplos(String empresaId) async {
    final now = DateTime.now();
    final ejemplos = <Map<String, dynamic>>[
      {
        'titulo': 'Tarea asignada: Revisión de contratos Q3',
        'cuerpo': 'Se te ha asignado la tarea "Revisión de contratos Q3". Vence el viernes.',
        'tipo': TipoNotificacion.tareaAsignada.id,
        'modulo_destino': TipoNotificacion.tareaAsignada.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 2))),
      },
      {
        'titulo': 'Factura vencida — F-2026-0142',
        'cuerpo': 'La factura F-2026-0142 de Restaurante El Olivo vence hoy (1.450 €). Pendiente de cobro.',
        'tipo': TipoNotificacion.facturaVencida.id,
        'modulo_destino': TipoNotificacion.facturaVencida.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
      },
      {
        'titulo': 'Nueva reserva — Sábado 22/08 21:00 h',
        'cuerpo': 'Reserva para 4 personas el sábado 22/08 a las 21:00 h. Sin alergias declaradas.',
        'tipo': TipoNotificacion.reservaNueva.id,
        'modulo_destino': TipoNotificacion.reservaNueva.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
        'remitente_nombre': 'Carlos Martínez',
        'remitente_telefono': '+34 612 345 678',
        'personas': '4',
        'alergenos': false,
      },
      {
        'titulo': 'Alerta fiscal — Modelo 303',
        'cuerpo': 'El modelo 303 del 2T vence el 20 de julio. Revisa y presenta tus declaraciones a tiempo.',
        'tipo': TipoNotificacion.alertaFiscal.id,
        'modulo_destino': TipoNotificacion.alertaFiscal.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
      },
      {
        'titulo': 'Nóminas pendientes de cierre',
        'cuerpo': '5 nóminas de agosto están pendientes de generar y firmar antes del día 28.',
        'tipo': TipoNotificacion.nominaPendiente.id,
        'modulo_destino': TipoNotificacion.nominaPendiente.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 20))),
      },
      {
        'titulo': 'Nuevo pedido #PED-0089',
        'cuerpo': 'Pedido de Clínica Dental Sonríe — 3 artículos por 320 €. Estado: pendiente de preparar.',
        'tipo': TipoNotificacion.pedidoNuevo.id,
        'modulo_destino': TipoNotificacion.pedidoNuevo.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 25))),
      },
      {
        'titulo': 'Nuevo cliente registrado',
        'cuerpo': 'Ana Gómez se ha registrado como cliente desde el portal web.',
        'tipo': TipoNotificacion.clienteNuevo.id,
        'modulo_destino': TipoNotificacion.clienteNuevo.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
        'remitente_nombre': 'Ana Gómez',
        'remitente_email': 'ana.gomez@correo.com',
      },
      {
        'titulo': 'Mensaje de contacto web',
        'cuerpo': '«Hola, me interesa el servicio Premium. ¿Podéis llamarme esta tarde?»',
        'tipo': TipoNotificacion.contactoWeb.id,
        'modulo_destino': TipoNotificacion.contactoWeb.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 40))),
        'remitente_nombre': 'Luis Fernández',
        'remitente_telefono': '+34 699 001 122',
      },
      {
        'titulo': 'Sugerencia de mejora del sistema',
        'cuerpo': 'Los tiempos de carga del panel de clientes pueden optimizarse activando la caché local.',
        'tipo': TipoNotificacion.sugerencia.id,
        'modulo_destino': TipoNotificacion.sugerencia.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 50))),
      },
      {
        'titulo': 'Solicitud de vacaciones',
        'cuerpo': 'María López ha solicitado vacaciones del 25/08 al 08/09. Pendiente de aprobar.',
        'tipo': TipoNotificacion.vacacionesSolicitadas.id,
        'modulo_destino': TipoNotificacion.vacacionesSolicitadas.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'remitente_nombre': 'María López',
      },
      {
        'titulo': 'Copia de seguridad completada',
        'cuerpo': 'La copia de seguridad automática de las 03:00 h finalizó correctamente.',
        'tipo': TipoNotificacion.generica.id,
        'modulo_destino': TipoNotificacion.generica.modulo,
        'leida': false,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
      },
    ];

    final batch = _db.batch();
    for (final e in ejemplos) {
      batch.set(_col(empresaId).doc(), e);
    }
    await batch.commit();
  }
}

