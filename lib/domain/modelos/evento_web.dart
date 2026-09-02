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
  final String? precio;
  final String? urlInscripcion;
  final bool activo;
  final bool eliminado;
  // Campos adicionales para la web
  final String? subtitulo; // "José Prados firma ejemplares"
  final String? hora;      // "18:30 – 20:00 h"
  final String? ciudad;    // "Granada" (separado de lugar para filtrar)
  // Vínculos al catálogo
  final String? libroId;
  final String? libroTitulo;
  final String? autorId;
  final String? autorNombre;

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
    this.subtitulo,
    this.hora,
    this.ciudad,
    this.libroId,
    this.libroTitulo,
    this.autorId,
    this.autorNombre,
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
    subtitulo:       m['subtitulo'] as String?,
    hora:            m['hora'] as String?,
    ciudad:          m['ciudad'] as String?,
    libroId:         m['libro_id'] as String?,
    libroTitulo:     m['libro_titulo'] as String?,
    autorId:         m['autor_id'] as String?,
    autorNombre:     m['autor_nombre'] as String?,
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
    if (subtitulo != null && subtitulo!.isNotEmpty) 'subtitulo': subtitulo,
    if (hora != null && hora!.isNotEmpty)            'hora': hora,
    if (ciudad != null && ciudad!.isNotEmpty)        'ciudad': ciudad,
    if (libroId != null) 'libro_id': libroId,
    if (libroTitulo != null) 'libro_titulo': libroTitulo,
    if (autorId != null) 'autor_id': autorId,
    if (autorNombre != null) 'autor_nombre': autorNombre,
  };

  EventoWeb copyWith({
    String? titulo, String? descripcion, DateTime? fecha, String? lugar,
    String? imagenUrl, TipoEvento? tipo, String? precio, String? urlInscripcion,
    bool? activo, String? libroId, String? libroTitulo, String? autorId, String? autorNombre,
  }) => EventoWeb(
    id: id, titulo: titulo ?? this.titulo, descripcion: descripcion ?? this.descripcion,
    fecha: fecha ?? this.fecha, lugar: lugar ?? this.lugar,
    imagenUrl: imagenUrl ?? this.imagenUrl, tipo: tipo ?? this.tipo,
    precio: precio ?? this.precio, urlInscripcion: urlInscripcion ?? this.urlInscripcion,
    activo: activo ?? this.activo, eliminado: eliminado,
    subtitulo: subtitulo ?? this.subtitulo, hora: hora ?? this.hora,
    ciudad: ciudad ?? this.ciudad,
    libroId: libroId ?? this.libroId, libroTitulo: libroTitulo ?? this.libroTitulo,
    autorId: autorId ?? this.autorId, autorNombre: autorNombre ?? this.autorNombre,
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
