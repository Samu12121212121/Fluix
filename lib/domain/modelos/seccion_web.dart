import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Tipos de sección disponibles ─────────────────────────────────────────────
enum TipoSeccion {
  texto,    // Título + texto libre + imagen opcional
  carta,    // Lista de platos/productos con nombre, descripción y precio
  galeria,  // Colección de imágenes
  ofertas,  // Ofertas con precio original y precio rebajado
  horarios, // Días/horas de apertura
}

extension TipoSeccionExt on TipoSeccion {
  String get nombre {
    switch (this) {
      case TipoSeccion.texto:    return 'Texto / Anuncio';
      case TipoSeccion.carta:    return 'Carta / Menú';
      case TipoSeccion.galeria:  return 'Galería de fotos';
      case TipoSeccion.ofertas:  return 'Ofertas';
      case TipoSeccion.horarios: return 'Horarios';
    }
  }

  String get id {
    switch (this) {
      case TipoSeccion.texto:    return 'texto';
      case TipoSeccion.carta:    return 'carta';
      case TipoSeccion.galeria:  return 'galeria';
      case TipoSeccion.ofertas:  return 'ofertas';
      case TipoSeccion.horarios: return 'horarios';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoSeccion.texto:    return Icons.article;
      case TipoSeccion.carta:    return Icons.restaurant_menu;
      case TipoSeccion.galeria:  return Icons.photo_library;
      case TipoSeccion.ofertas:  return Icons.local_offer;
      case TipoSeccion.horarios: return Icons.schedule;
    }
  }

  Color get color {
    switch (this) {
      case TipoSeccion.texto:    return const Color(0xFF1976D2);
      case TipoSeccion.carta:    return const Color(0xFFE65100);
      case TipoSeccion.galeria:  return const Color(0xFF7B1FA2);
      case TipoSeccion.ofertas:  return const Color(0xFF2E7D32);
      case TipoSeccion.horarios: return const Color(0xFF00796B);
    }
  }

  static TipoSeccion fromId(String id) {
    switch (id) {
      case 'carta':    return TipoSeccion.carta;
      case 'galeria':  return TipoSeccion.galeria;
      case 'ofertas':  return TipoSeccion.ofertas;
      case 'horarios': return TipoSeccion.horarios;
      default:         return TipoSeccion.texto;
    }
  }
}

// ── Modelo principal ─────────────────────────────────────────────────────────
class SeccionWeb {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activa;
  final TipoSeccion tipo;
  final ContenidoSeccion contenido;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  SeccionWeb({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activa,
    required this.tipo,
    required this.contenido,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory SeccionWeb.fromMap(Map<String, dynamic> map) {
    final tipoStr = map['tipo'] as String? ?? 'texto';
    final tipo = TipoSeccionExt.fromId(tipoStr);
    final contenidoRaw = map['contenido'] as Map<String, dynamic>? ?? {};

    return SeccionWeb(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      activa: map['activa'] ?? true,
      tipo: tipo,
      contenido: ContenidoSeccion.fromMap(contenidoRaw, tipo),
      fechaCreacion: _parseDate(map['fecha_creacion']),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? _parseDate(map['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'activa': activa,
    'tipo': tipo.id,
    'contenido': contenido.toMap(),
    'fecha_creacion': fechaCreacion.toIso8601String(),
    if (fechaActualizacion != null)
      'fecha_actualizacion': fechaActualizacion!.toIso8601String(),
  };

  SeccionWeb copyWith({
    String? nombre,
    String? descripcion,
    bool? activa,
    ContenidoSeccion? contenido,
    DateTime? fechaActualizacion,
  }) => SeccionWeb(
    id: id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    activa: activa ?? this.activa,
    tipo: tipo,
    contenido: contenido ?? this.contenido,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
  );

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ── Contenido por tipo ────────────────────────────────────────────────────────
class ContenidoSeccion {
  // Tipo TEXTO
  final String titulo;
  final String texto;
  final String? imagenUrl;

  // Tipo CARTA / MENU — lista de platos
  final List<ItemCarta> itemsCarta;

  // Tipo GALERIA — lista de URLs
  final List<ItemGaleria> imagenesGaleria;

  // Tipo OFERTAS
  final List<ItemOferta> ofertas;

  // Tipo HORARIOS
  final List<ItemHorario> horarios;

  const ContenidoSeccion({
    this.titulo = '',
    this.texto = '',
    this.imagenUrl,
    this.itemsCarta = const [],
    this.imagenesGaleria = const [],
    this.ofertas = const [],
    this.horarios = const [],
  });

  factory ContenidoSeccion.fromMap(Map<String, dynamic> map, TipoSeccion tipo) {
    return ContenidoSeccion(
      titulo:   map['titulo'] as String? ?? '',
      texto:    map['texto'] as String? ?? '',
      imagenUrl: map['imagen_url'] as String?,
      itemsCarta: (map['items_carta'] as List<dynamic>? ?? [])
          .map((e) => ItemCarta.fromMap(e as Map<String, dynamic>))
          .toList(),
      imagenesGaleria: (map['imagenes_galeria'] as List<dynamic>? ?? [])
          .map((e) => ItemGaleria.fromMap(e as Map<String, dynamic>))
          .toList(),
      ofertas: (map['ofertas'] as List<dynamic>? ?? [])
          .map((e) => ItemOferta.fromMap(e as Map<String, dynamic>))
          .toList(),
      horarios: (map['horarios'] as List<dynamic>? ?? [])
          .map((e) => ItemHorario.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'texto': texto,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'items_carta': itemsCarta.map((e) => e.toMap()).toList(),
    'imagenes_galeria': imagenesGaleria.map((e) => e.toMap()).toList(),
    'ofertas': ofertas.map((e) => e.toMap()).toList(),
    'horarios': horarios.map((e) => e.toMap()).toList(),
  };

  ContenidoSeccion copyWith({
    String? titulo,
    String? texto,
    String? imagenUrl,
    List<ItemCarta>? itemsCarta,
    List<ItemGaleria>? imagenesGaleria,
    List<ItemOferta>? ofertas,
    List<ItemHorario>? horarios,
  }) => ContenidoSeccion(
    titulo: titulo ?? this.titulo,
    texto: texto ?? this.texto,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    itemsCarta: itemsCarta ?? this.itemsCarta,
    imagenesGaleria: imagenesGaleria ?? this.imagenesGaleria,
    ofertas: ofertas ?? this.ofertas,
    horarios: horarios ?? this.horarios,
  );
}

// ── Item de Carta / Menú ──────────────────────────────────────────────────────
class ItemCarta {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String? imagenUrl;
  final String categoria;
  final bool disponible;

  ItemCarta({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    this.imagenUrl,
    this.categoria = 'General',
    this.disponible = true,
  });

  factory ItemCarta.fromMap(Map<String, dynamic> m) => ItemCarta(
    id:          m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    nombre:      m['nombre'] as String? ?? '',
    descripcion: m['descripcion'] as String? ?? '',
    precio:      (m['precio'] as num?)?.toDouble() ?? 0.0,
    imagenUrl:   m['imagen_url'] as String?,
    categoria:   m['categoria'] as String? ?? 'General',
    disponible:  m['disponible'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'precio': precio,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'categoria': categoria,
    'disponible': disponible,
  };

  ItemCarta copyWith({
    String? nombre, String? descripcion, double? precio,
    String? imagenUrl, String? categoria, bool? disponible,
  }) => ItemCarta(
    id: id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    precio: precio ?? this.precio,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    categoria: categoria ?? this.categoria,
    disponible: disponible ?? this.disponible,
  );
}

// ── Item de Galería ───────────────────────────────────────────────────────────
class ItemGaleria {
  final String id;
  final String url;
  final String? descripcion;

  ItemGaleria({required this.id, required this.url, this.descripcion});

  factory ItemGaleria.fromMap(Map<String, dynamic> m) => ItemGaleria(
    id:          m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    url:         m['url'] as String? ?? '',
    descripcion: m['descripcion'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    if (descripcion != null) 'descripcion': descripcion,
  };
}

// ── Item de Oferta ────────────────────────────────────────────────────────────
class ItemOferta {
  final String id;
  final String titulo;
  final String descripcion;
  final double? precioOriginal;
  final double? precioOferta;
  final String? imagenUrl;
  final String? fechaFin; // ISO string
  final bool activa;

  ItemOferta({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.precioOriginal,
    this.precioOferta,
    this.imagenUrl,
    this.fechaFin,
    this.activa = true,
  });

  factory ItemOferta.fromMap(Map<String, dynamic> m) => ItemOferta(
    id:             m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    titulo:         m['titulo'] as String? ?? '',
    descripcion:    m['descripcion'] as String? ?? '',
    precioOriginal: (m['precio_original'] as num?)?.toDouble(),
    precioOferta:   (m['precio_oferta'] as num?)?.toDouble(),
    imagenUrl:      m['imagen_url'] as String?,
    fechaFin:       m['fecha_fin'] as String?,
    activa:         m['activa'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    if (precioOriginal != null) 'precio_original': precioOriginal,
    if (precioOferta != null) 'precio_oferta': precioOferta,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    if (fechaFin != null) 'fecha_fin': fechaFin,
    'activa': activa,
  };

  ItemOferta copyWith({
    String? titulo, String? descripcion, double? precioOriginal,
    double? precioOferta, String? imagenUrl, String? fechaFin, bool? activa,
  }) => ItemOferta(
    id: id,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    precioOriginal: precioOriginal ?? this.precioOriginal,
    precioOferta: precioOferta ?? this.precioOferta,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    fechaFin: fechaFin ?? this.fechaFin,
    activa: activa ?? this.activa,
  );
}

// ── Item de Horario ───────────────────────────────────────────────────────────
class ItemHorario {
  final String dia;
  final String apertura;
  final String cierre;
  final bool cerrado;

  ItemHorario({
    required this.dia,
    required this.apertura,
    required this.cierre,
    this.cerrado = false,
  });

  factory ItemHorario.fromMap(Map<String, dynamic> m) => ItemHorario(
    dia:      m['dia'] as String? ?? '',
    apertura: m['apertura'] as String? ?? '09:00',
    cierre:   m['cierre'] as String? ?? '21:00',
    cerrado:  m['cerrado'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'dia': dia,
    'apertura': apertura,
    'cierre': cierre,
    'cerrado': cerrado,
  };

  ItemHorario copyWith({String? apertura, String? cierre, bool? cerrado}) =>
      ItemHorario(
        dia: dia,
        apertura: apertura ?? this.apertura,
        cierre: cierre ?? this.cierre,
        cerrado: cerrado ?? this.cerrado,
      );

  static List<ItemHorario> porDefecto() => [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ].map((d) => ItemHorario(
    dia: d,
    apertura: '09:00',
    cierre: '21:00',
    cerrado: d == 'Domingo',
  )).toList();
}

// Iconos legacy (compatibilidad)
class IconosSeccion {
  static IconData obtenerIcono(String tipo) =>
      TipoSeccionExt.fromId(tipo).icono;
}

// ── SEO Configuration ─────────────────────────────────────────────────────────
class SeoConfig {
  final String tituloSeo;
  final String descripcionSeo;
  final String palabrasClave;
  final String? imagenOg;
  final String? googleAnalyticsId;
  final String? pixelFacebook;
  final String robotsContent; // 'index,follow' etc.

  const SeoConfig({
    this.tituloSeo = '',
    this.descripcionSeo = '',
    this.palabrasClave = '',
    this.imagenOg,
    this.googleAnalyticsId,
    this.pixelFacebook,
    this.robotsContent = 'index,follow',
  });

  factory SeoConfig.fromMap(Map<String, dynamic> m) => SeoConfig(
    tituloSeo:          m['titulo_seo'] as String? ?? '',
    descripcionSeo:     m['descripcion_seo'] as String? ?? '',
    palabrasClave:      m['palabras_clave'] as String? ?? '',
    imagenOg:           m['imagen_og'] as String?,
    googleAnalyticsId:  m['google_analytics_id'] as String?,
    pixelFacebook:      m['pixel_facebook'] as String?,
    robotsContent:      m['robots_content'] as String? ?? 'index,follow',
  );

  Map<String, dynamic> toMap() => {
    'titulo_seo':         tituloSeo,
    'descripcion_seo':    descripcionSeo,
    'palabras_clave':     palabrasClave,
    if (imagenOg != null) 'imagen_og': imagenOg,
    if (googleAnalyticsId != null) 'google_analytics_id': googleAnalyticsId,
    if (pixelFacebook != null) 'pixel_facebook': pixelFacebook,
    'robots_content':     robotsContent,
  };

  SeoConfig copyWith({
    String? tituloSeo, String? descripcionSeo, String? palabrasClave,
    String? imagenOg, String? googleAnalyticsId, String? pixelFacebook,
    String? robotsContent,
  }) => SeoConfig(
    tituloSeo:         tituloSeo ?? this.tituloSeo,
    descripcionSeo:    descripcionSeo ?? this.descripcionSeo,
    palabrasClave:     palabrasClave ?? this.palabrasClave,
    imagenOg:          imagenOg ?? this.imagenOg,
    googleAnalyticsId: googleAnalyticsId ?? this.googleAnalyticsId,
    pixelFacebook:     pixelFacebook ?? this.pixelFacebook,
    robotsContent:     robotsContent ?? this.robotsContent,
  );

  int get caracteresDescripcion => descripcionSeo.length;
  bool get descripcionOk => caracteresDescripcion >= 120 && caracteresDescripcion <= 160;
  int get caracteresTitulo => tituloSeo.length;
  bool get tituloOk => caracteresTitulo >= 30 && caracteresTitulo <= 60;
}

// ── Entrada de Blog ───────────────────────────────────────────────────────────
class EntradaBlog {
  final String id;
  final String titulo;
  final String resumen;
  final String contenido; // Markdown
  final String? imagenUrl;
  final bool publicada;
  final DateTime fechaPublicacion;
  final List<String> etiquetas;
  final String autor;
  final int visitas;

  const EntradaBlog({
    required this.id,
    required this.titulo,
    this.resumen = '',
    this.contenido = '',
    this.imagenUrl,
    this.publicada = false,
    required this.fechaPublicacion,
    this.etiquetas = const [],
    this.autor = '',
    this.visitas = 0,
  });

  factory EntradaBlog.fromMap(Map<String, dynamic> m) => EntradaBlog(
    id:                m['id'] as String? ?? '',
    titulo:            m['titulo'] as String? ?? '',
    resumen:           m['resumen'] as String? ?? '',
    contenido:         m['contenido'] as String? ?? '',
    imagenUrl:         m['imagen_url'] as String?,
    publicada:         m['publicada'] as bool? ?? false,
    fechaPublicacion:  _parseFecha(m['fecha_publicacion']),
    etiquetas:         (m['etiquetas'] as List<dynamic>?)?.cast<String>() ?? [],
    autor:             m['autor'] as String? ?? '',
    visitas:           (m['visitas'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id':                 id,
    'titulo':             titulo,
    'resumen':            resumen,
    'contenido':          contenido,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'publicada':          publicada,
    'fecha_publicacion':  fechaPublicacion.toIso8601String(),
    'etiquetas':          etiquetas,
    'autor':              autor,
    'visitas':            visitas,
  };

  EntradaBlog copyWith({
    String? titulo, String? resumen, String? contenido, String? imagenUrl,
    bool? publicada, DateTime? fechaPublicacion, List<String>? etiquetas,
    String? autor,
  }) => EntradaBlog(
    id: id,
    titulo: titulo ?? this.titulo,
    resumen: resumen ?? this.resumen,
    contenido: contenido ?? this.contenido,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    publicada: publicada ?? this.publicada,
    fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
    etiquetas: etiquetas ?? this.etiquetas,
    autor: autor ?? this.autor,
    visitas: visitas,
  );

  static DateTime _parseFecha(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  String get fechaFormateada {
    final d = fechaPublicacion;
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  int get tiempoLecturaMin {
    final palabras = contenido.split(' ').length;
    return (palabras / 200).ceil().clamp(1, 99);
  }
}

// ── Configuración Avanzada Web ────────────────────────────────────────────────
class ConfigWebAvanzada {
  final String? dominioPropioUrl;
  // Formulario de contacto
  final bool contactoActivo;
  final String? contactoEmail;
  final String? contactoWhatsapp;
  final String? contactoTitulo;
  // Popup
  final bool popupActivo;
  final String? popupTitulo;
  final String? popupTexto;
  final String? popupBotonTexto;
  final String? popupBotonUrl;
  final int popupRetrasoSeg;
  // Banner superior
  final bool bannerActivo;
  final String? bannerTexto;
  final String? bannerColor;   // hex: '#e53935'
  final String? bannerUrlDestino;

  const ConfigWebAvanzada({
    this.dominioPropioUrl,
    this.contactoActivo = false,
    this.contactoEmail,
    this.contactoWhatsapp,
    this.contactoTitulo,
    this.popupActivo = false,
    this.popupTitulo,
    this.popupTexto,
    this.popupBotonTexto,
    this.popupBotonUrl,
    this.popupRetrasoSeg = 5,
    this.bannerActivo = false,
    this.bannerTexto,
    this.bannerColor,
    this.bannerUrlDestino,
  });

  factory ConfigWebAvanzada.fromMap(Map<String, dynamic> m) => ConfigWebAvanzada(
    dominioPropioUrl:   m['dominio_propio_url'] as String?,
    contactoActivo:     m['contacto_activo'] as bool? ?? false,
    contactoEmail:      m['contacto_email'] as String?,
    contactoWhatsapp:   m['contacto_whatsapp'] as String?,
    contactoTitulo:     m['contacto_titulo'] as String?,
    popupActivo:        m['popup_activo'] as bool? ?? false,
    popupTitulo:        m['popup_titulo'] as String?,
    popupTexto:         m['popup_texto'] as String?,
    popupBotonTexto:    m['popup_boton_texto'] as String?,
    popupBotonUrl:      m['popup_boton_url'] as String?,
    popupRetrasoSeg:    (m['popup_retraso_seg'] as num?)?.toInt() ?? 5,
    bannerActivo:       m['banner_activo'] as bool? ?? false,
    bannerTexto:        m['banner_texto'] as String?,
    bannerColor:        m['banner_color'] as String?,
    bannerUrlDestino:   m['banner_url_destino'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (dominioPropioUrl != null) 'dominio_propio_url': dominioPropioUrl,
    'contacto_activo':    contactoActivo,
    if (contactoEmail != null) 'contacto_email': contactoEmail,
    if (contactoWhatsapp != null) 'contacto_whatsapp': contactoWhatsapp,
    if (contactoTitulo != null) 'contacto_titulo': contactoTitulo,
    'popup_activo':       popupActivo,
    if (popupTitulo != null) 'popup_titulo': popupTitulo,
    if (popupTexto != null) 'popup_texto': popupTexto,
    if (popupBotonTexto != null) 'popup_boton_texto': popupBotonTexto,
    if (popupBotonUrl != null) 'popup_boton_url': popupBotonUrl,
    'popup_retraso_seg':  popupRetrasoSeg,
    'banner_activo':      bannerActivo,
    if (bannerTexto != null) 'banner_texto': bannerTexto,
    if (bannerColor != null) 'banner_color': bannerColor,
    if (bannerUrlDestino != null) 'banner_url_destino': bannerUrlDestino,
  };

  ConfigWebAvanzada copyWith({
    String? dominioPropioUrl, bool? contactoActivo, String? contactoEmail,
    String? contactoWhatsapp, String? contactoTitulo,
    bool? popupActivo, String? popupTitulo, String? popupTexto,
    String? popupBotonTexto, String? popupBotonUrl, int? popupRetrasoSeg,
    bool? bannerActivo, String? bannerTexto, String? bannerColor,
    String? bannerUrlDestino,
  }) => ConfigWebAvanzada(
    dominioPropioUrl:  dominioPropioUrl ?? this.dominioPropioUrl,
    contactoActivo:    contactoActivo ?? this.contactoActivo,
    contactoEmail:     contactoEmail ?? this.contactoEmail,
    contactoWhatsapp:  contactoWhatsapp ?? this.contactoWhatsapp,
    contactoTitulo:    contactoTitulo ?? this.contactoTitulo,
    popupActivo:       popupActivo ?? this.popupActivo,
    popupTitulo:       popupTitulo ?? this.popupTitulo,
    popupTexto:        popupTexto ?? this.popupTexto,
    popupBotonTexto:   popupBotonTexto ?? this.popupBotonTexto,
    popupBotonUrl:     popupBotonUrl ?? this.popupBotonUrl,
    popupRetrasoSeg:   popupRetrasoSeg ?? this.popupRetrasoSeg,
    bannerActivo:      bannerActivo ?? this.bannerActivo,
    bannerTexto:       bannerTexto ?? this.bannerTexto,
    bannerColor:       bannerColor ?? this.bannerColor,
    bannerUrlDestino:  bannerUrlDestino ?? this.bannerUrlDestino,
  );
}
