import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoEvento { presentacion, feria, taller, lectura, otro }

extension TipoEventoExt on TipoEvento {
  String get id {
    switch (this) {
      case TipoEvento.presentacion: return 'presentacion';
      case TipoEvento.feria:        return 'feria';
      case TipoEvento.taller:       return 'taller';
      case TipoEvento.lectura:      return 'lectura';
      case TipoEvento.otro:         return 'otro';
    }
  }
  String get label {
    switch (this) {
      case TipoEvento.presentacion: return 'Presentación';
      case TipoEvento.feria:        return 'Feria';
      case TipoEvento.taller:       return 'Taller';
      case TipoEvento.lectura:      return 'Lectura';
      case TipoEvento.otro:         return 'Evento';
    }
  }
  static TipoEvento fromId(String? id) {
    switch (id) {
      case 'feria':        return TipoEvento.feria;
      case 'taller':       return TipoEvento.taller;
      case 'lectura':      return TipoEvento.lectura;
      case 'presentacion': return TipoEvento.presentacion;
      default:             return TipoEvento.otro;
    }
  }
}

class EventoWeb {
  final String id;
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final String lugar;
  final String? imagenUrl;
  final TipoEvento tipo;
  final String? precio;       // '10€', 'Entrada libre', etc.
  final String? urlInscripcion;
  final bool activo;
  final bool eliminado;

  const EventoWeb({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.fecha,
    this.lugar = '',
    this.imagenUrl,
    this.tipo = TipoEvento.presentacion,
    this.precio,
    this.urlInscripcion,
    this.activo = true,
    this.eliminado = false,
  });

  bool get esFuturo => fecha.isAfter(DateTime.now());

  factory EventoWeb.fromMap(Map<String, dynamic> m) => EventoWeb(
    id:              m['id'] as String? ?? '',
    titulo:          m['titulo'] as String? ?? '',
    descripcion:     m['descripcion'] as String? ?? '',
    fecha:           _parseTs(m['fecha']),
    lugar:           m['lugar'] as String? ?? '',
    imagenUrl:       m['imagen_url'] as String?,
    tipo:            TipoEventoExt.fromId(m['tipo'] as String?),
    precio:          m['precio'] as String?,
    urlInscripcion:  m['url_inscripcion'] as String?,
    activo:          m['activo'] as bool? ?? true,
    eliminado:       m['eliminado'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'titulo':           titulo,
    'descripcion':      descripcion,
    'fecha':            Timestamp.fromDate(fecha),
    'lugar':            lugar,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'tipo':             tipo.id,
    if (precio != null) 'precio': precio,
    if (urlInscripcion != null) 'url_inscripcion': urlInscripcion,
    'activo':           activo,
    'eliminado':        eliminado,
  };

  EventoWeb copyWith({
    String? titulo, String? descripcion, DateTime? fecha, String? lugar,
    String? imagenUrl, TipoEvento? tipo, String? precio,
    String? urlInscripcion, bool? activo,
  }) => EventoWeb(
    id: id, titulo: titulo ?? this.titulo, descripcion: descripcion ?? this.descripcion,
    fecha: fecha ?? this.fecha, lugar: lugar ?? this.lugar,
    imagenUrl: imagenUrl ?? this.imagenUrl, tipo: tipo ?? this.tipo,
    precio: precio ?? this.precio, urlInscripcion: urlInscripcion ?? this.urlInscripcion,
    activo: activo ?? this.activo, eliminado: eliminado,
  );

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  String get fechaCorta {
    const meses = ['ene','feb','mar','abr','may','jun',
                   'jul','ago','sep','oct','nov','dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }
}
