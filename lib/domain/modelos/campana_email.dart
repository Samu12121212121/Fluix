import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MODELO — Campaña de Email Marketing
// Firestore: empresas/{id}/campanas_email/{campanaId}
// El envío real lo ejecuta una Cloud Function al pasar estado → 'enviando'
// ═════════════════════════════════════════════════════════════════════════════

enum EstadoCampana { borrador, programada, enviando, enviada, fallida }

extension EstadoCampanaExt on EstadoCampana {
  String get id {
    switch (this) {
      case EstadoCampana.borrador:   return 'borrador';
      case EstadoCampana.programada: return 'programada';
      case EstadoCampana.enviando:   return 'enviando';
      case EstadoCampana.enviada:    return 'enviada';
      case EstadoCampana.fallida:    return 'fallida';
    }
  }

  String get label {
    switch (this) {
      case EstadoCampana.borrador:   return 'Borrador';
      case EstadoCampana.programada: return 'Programada';
      case EstadoCampana.enviando:   return 'Enviando…';
      case EstadoCampana.enviada:    return 'Enviada';
      case EstadoCampana.fallida:    return 'Fallida';
    }
  }

  static EstadoCampana fromId(String? id) {
    switch (id) {
      case 'programada': return EstadoCampana.programada;
      case 'enviando':   return EstadoCampana.enviando;
      case 'enviada':    return EstadoCampana.enviada;
      case 'fallida':    return EstadoCampana.fallida;
      default:           return EstadoCampana.borrador;
    }
  }
}

// Segmento de destinatarios
enum SegmentoCampana { todos, clientesActivos, manual }

extension SegmentoCampanaExt on SegmentoCampana {
  String get id {
    switch (this) {
      case SegmentoCampana.todos:           return 'todos';
      case SegmentoCampana.clientesActivos: return 'clientes_activos';
      case SegmentoCampana.manual:          return 'manual';
    }
  }

  String get label {
    switch (this) {
      case SegmentoCampana.todos:           return 'Todos los clientes';
      case SegmentoCampana.clientesActivos: return 'Clientes activos (últimos 90 días)';
      case SegmentoCampana.manual:          return 'Lista manual de emails';
    }
  }

  static SegmentoCampana fromId(String? id) {
    switch (id) {
      case 'clientes_activos': return SegmentoCampana.clientesActivos;
      case 'manual':           return SegmentoCampana.manual;
      default:                 return SegmentoCampana.todos;
    }
  }
}

class CampanaEmail {
  final String id;
  final String nombre;
  final String asunto;
  final String contenidoHtml;
  final EstadoCampana estado;
  final DateTime? fechaEnvio;
  final SegmentoCampana segmento;
  final List<String> destinatariosManual;
  final int totalEnviados;
  final int totalAbiertos;
  final int totalClicks;
  final String? errorMensaje;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  const CampanaEmail({
    required this.id,
    required this.nombre,
    required this.asunto,
    required this.contenidoHtml,
    this.estado = EstadoCampana.borrador,
    this.fechaEnvio,
    this.segmento = SegmentoCampana.todos,
    this.destinatariosManual = const [],
    this.totalEnviados = 0,
    this.totalAbiertos = 0,
    this.totalClicks = 0,
    this.errorMensaje,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory CampanaEmail.fromMap(Map<String, dynamic> m) => CampanaEmail(
    id:                   m['id'] as String? ?? '',
    nombre:               m['nombre'] as String? ?? '',
    asunto:               m['asunto'] as String? ?? '',
    contenidoHtml:        m['contenido_html'] as String? ?? '',
    estado:               EstadoCampanaExt.fromId(m['estado'] as String?),
    fechaEnvio:           _parseDate(m['fecha_envio']),
    segmento:             SegmentoCampanaExt.fromId(m['segmento'] as String?),
    destinatariosManual:  (m['destinatarios_manual'] as List<dynamic>? ?? []).cast<String>(),
    totalEnviados:        (m['total_enviados'] as num?)?.toInt() ?? 0,
    totalAbiertos:        (m['total_abiertos'] as num?)?.toInt() ?? 0,
    totalClicks:          (m['total_clicks'] as num?)?.toInt() ?? 0,
    errorMensaje:         m['error_mensaje'] as String?,
    fechaCreacion:        _parseDate(m['fecha_creacion']) ?? DateTime.now(),
    fechaActualizacion:   _parseDate(m['fecha_actualizacion']),
  );

  Map<String, dynamic> toMap() => {
    'nombre':                nombre,
    'asunto':                asunto,
    'contenido_html':        contenidoHtml,
    'estado':                estado.id,
    if (fechaEnvio != null) 'fecha_envio': Timestamp.fromDate(fechaEnvio!),
    'segmento':              segmento.id,
    'destinatarios_manual':  destinatariosManual,
    'total_enviados':        totalEnviados,
    'total_abiertos':        totalAbiertos,
    'total_clicks':          totalClicks,
    if (errorMensaje != null) 'error_mensaje': errorMensaje,
  };

  CampanaEmail copyWith({
    String? nombre, String? asunto, String? contenidoHtml,
    EstadoCampana? estado, DateTime? fechaEnvio, SegmentoCampana? segmento,
    List<String>? destinatariosManual,
  }) => CampanaEmail(
    id:                  id,
    nombre:              nombre ?? this.nombre,
    asunto:              asunto ?? this.asunto,
    contenidoHtml:       contenidoHtml ?? this.contenidoHtml,
    estado:              estado ?? this.estado,
    fechaEnvio:          fechaEnvio ?? this.fechaEnvio,
    segmento:            segmento ?? this.segmento,
    destinatariosManual: destinatariosManual ?? this.destinatariosManual,
    totalEnviados:       totalEnviados,
    totalAbiertos:       totalAbiertos,
    totalClicks:         totalClicks,
    fechaCreacion:       fechaCreacion,
    fechaActualizacion:  fechaActualizacion,
  );

  double get tasaApertura =>
      totalEnviados > 0 ? totalAbiertos / totalEnviados : 0;
  double get tasaClick =>
      totalEnviados > 0 ? totalClicks / totalEnviados : 0;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
