import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BLOG POST — modelo completo multi-tenant
// ═══════════════════════════════════════════════════════════════════════════

enum EstadoBlog { borrador, publicado, programado }

extension EstadoBlogExt on EstadoBlog {
  String get valor => name; // 'borrador' | 'publicado' | 'programado'
  String get etiqueta => switch (this) {
    EstadoBlog.borrador    => 'Borrador',
    EstadoBlog.publicado   => 'Publicado',
    EstadoBlog.programado  => 'Programado',
  };
}

class BlogSeo {
  final String metaTitle;
  final String metaDescription;
  final List<String> keywords;
  final String? imagenOg;

  const BlogSeo({
    this.metaTitle = '',
    this.metaDescription = '',
    this.keywords = const [],
    this.imagenOg,
  });

  factory BlogSeo.fromMap(Map<String, dynamic> m) => BlogSeo(
    metaTitle:       m['meta_title'] as String? ?? '',
    metaDescription: m['meta_description'] as String? ?? '',
    keywords:        (m['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
    imagenOg:        m['imagen_og'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'meta_title':       metaTitle,
    'meta_description': metaDescription,
    'keywords':         keywords,
    if (imagenOg != null) 'imagen_og': imagenOg,
  };

  BlogSeo copyWith({String? metaTitle, String? metaDescription,
      List<String>? keywords, String? imagenOg}) =>
      BlogSeo(
        metaTitle: metaTitle ?? this.metaTitle,
        metaDescription: metaDescription ?? this.metaDescription,
        keywords: keywords ?? this.keywords,
        imagenOg: imagenOg ?? this.imagenOg,
      );
}

class BlogPost {
  final String id;
  final String empresaId;
  final String titulo;
  final String slug;           // único por empresaId
  final String resumen;
  final String contenido;      // Markdown (seguro: no HTML crudo)
  final String? imagenUrl;
  final String? thumbnailUrl;
  final String? categoriaId;
  final List<String> etiquetas;
  final String autor;
  final DateTime fechaPublicacion;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final EstadoBlog estado;
  final BlogSeo seo;
  final bool eliminado;
  final DateTime? fechaEliminacion;
  final int visitas;

  const BlogPost({
    required this.id,
    required this.empresaId,
    required this.titulo,
    required this.slug,
    this.resumen = '',
    this.contenido = '',
    this.imagenUrl,
    this.thumbnailUrl,
    this.categoriaId,
    this.etiquetas = const [],
    this.autor = '',
    required this.fechaPublicacion,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estado = EstadoBlog.borrador,
    this.seo = const BlogSeo(),
    this.eliminado = false,
    this.fechaEliminacion,
    this.visitas = 0,
  });

  factory BlogPost.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return BlogPost(
      id:                 doc.id,
      empresaId:          m['empresa_id'] as String? ?? '',
      titulo:             m['titulo'] as String? ?? '',
      slug:               m['slug'] as String? ?? doc.id,
      resumen:            m['resumen'] as String? ?? '',
      contenido:          m['contenido'] as String? ?? '',
      imagenUrl:          _nonEmpty(m['imagen_url'] as String?),
      thumbnailUrl:       _nonEmpty(m['thumbnail_url'] as String?),
      categoriaId:        _nonEmpty(m['categoria_id'] as String?),
      etiquetas:          (m['etiquetas'] as List<dynamic>?)?.cast<String>() ?? [],
      autor:              m['autor'] as String? ?? '',
      fechaPublicacion:   _parseTs(m['fecha_publicacion']),
      fechaCreacion:      _parseTs(m['fecha_creacion']),
      fechaActualizacion: m['fecha_actualizacion'] != null ? _parseTs(m['fecha_actualizacion']) : null,
      estado:             _parseEstado(m['estado'] as String?),
      seo:                m['seo'] != null ? BlogSeo.fromMap(m['seo'] as Map<String, dynamic>) : const BlogSeo(),
      eliminado:          m['eliminado'] as bool? ?? false,
      fechaEliminacion:   m['fecha_eliminacion'] != null ? _parseTs(m['fecha_eliminacion']) : null,
      visitas:            (m['visitas'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id':          empresaId,
    'titulo':              titulo,
    'slug':                slug,
    'resumen':             resumen,
    'contenido':           contenido,
    if (imagenUrl != null)    'imagen_url': imagenUrl,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (categoriaId != null)  'categoria_id': categoriaId,
    'etiquetas':           etiquetas,
    'autor':               autor,
    'fecha_publicacion':   Timestamp.fromDate(fechaPublicacion),
    'fecha_creacion':      Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': FieldValue.serverTimestamp(),
    'estado':              estado.valor,
    'seo':                 seo.toMap(),
    'eliminado':           eliminado,
    if (fechaEliminacion != null) 'fecha_eliminacion': Timestamp.fromDate(fechaEliminacion!),
    'visitas':             visitas,
  };

  BlogPost copyWith({
    String? titulo, String? slug, String? resumen, String? contenido,
    String? imagenUrl, String? thumbnailUrl, String? categoriaId,
    List<String>? etiquetas, String? autor, DateTime? fechaPublicacion,
    EstadoBlog? estado, BlogSeo? seo, bool? eliminado, DateTime? fechaEliminacion,
    bool clearImagen = false, bool clearCategoria = false,
  }) => BlogPost(
    id: id, empresaId: empresaId,
    titulo:            titulo ?? this.titulo,
    slug:              slug ?? this.slug,
    resumen:           resumen ?? this.resumen,
    contenido:         contenido ?? this.contenido,
    imagenUrl:         clearImagen ? null : (imagenUrl ?? this.imagenUrl),
    thumbnailUrl:      clearImagen ? null : (thumbnailUrl ?? this.thumbnailUrl),
    categoriaId:       clearCategoria ? null : (categoriaId ?? this.categoriaId),
    etiquetas:         etiquetas ?? this.etiquetas,
    autor:             autor ?? this.autor,
    fechaPublicacion:  fechaPublicacion ?? this.fechaPublicacion,
    fechaCreacion:     fechaCreacion,
    estado:            estado ?? this.estado,
    seo:               seo ?? this.seo,
    eliminado:         eliminado ?? this.eliminado,
    fechaEliminacion:  fechaEliminacion ?? this.fechaEliminacion,
    visitas:           visitas,
  );

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get fechaFormateada {
    final d = fechaPublicacion;
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  int get tiempoLecturaMin {
    final palabras = contenido.split(RegExp(r'\s+')).length;
    return (palabras / 200).ceil().clamp(1, 99);
  }

  /// Genera un slug URL-safe desde el título.
  static String slugDesde(String titulo) {
    final s = titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return s.isEmpty ? 'sin-titulo' : s;
  }

  static String? _nonEmpty(String? s) => (s != null && s.isNotEmpty) ? s : null;

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static EstadoBlog _parseEstado(String? v) => switch (v) {
    'publicado'  => EstadoBlog.publicado,
    'programado' => EstadoBlog.programado,
    _            => EstadoBlog.borrador,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORÍA DE BLOG
// ═══════════════════════════════════════════════════════════════════════════

class BlogCategoria {
  final String id;
  final String empresaId;
  final String nombre;
  final String slug;
  final int orden;
  final bool eliminado;

  const BlogCategoria({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.slug,
    this.orden = 0,
    this.eliminado = false,
  });

  factory BlogCategoria.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return BlogCategoria(
      id:         doc.id,
      empresaId:  m['empresa_id'] as String? ?? '',
      nombre:     m['nombre'] as String? ?? '',
      slug:       m['slug'] as String? ?? doc.id,
      orden:      (m['orden'] as num?)?.toInt() ?? 0,
      eliminado:  m['eliminado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'nombre':     nombre,
    'slug':       slug,
    'orden':      orden,
    'eliminado':  eliminado,
  };
}
