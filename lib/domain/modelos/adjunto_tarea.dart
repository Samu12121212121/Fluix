import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de archivo adjunto soportados.
enum TipoAdjunto { imagen, pdf, documento }

extension TipoAdjuntoX on TipoAdjunto {
  String get etiqueta => switch (this) {
        TipoAdjunto.imagen    => 'Imagen',
        TipoAdjunto.pdf       => 'PDF',
        TipoAdjunto.documento => 'Documento',
      };
}

/// Representa un archivo adjunto de una tarea.
///
/// Estructura Firestore:
///   empresas/{empresaId}/tareas/{tareaId}/adjuntos/{adjuntoId}
class AdjuntoTarea {
  final String id;
  final String nombre;
  final String url;

  /// URL de la miniatura (200×200) generada por Cloud Function. Null para PDFs.
  final String? thumbnailUrl;
  final TipoAdjunto tipo;
  final int tamanioBytes;
  final String subidoPorId;
  final DateTime fechaSubida;

  const AdjuntoTarea({
    required this.id,
    required this.nombre,
    required this.url,
    this.thumbnailUrl,
    required this.tipo,
    required this.tamanioBytes,
    required this.subidoPorId,
    required this.fechaSubida,
  });

  factory AdjuntoTarea.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AdjuntoTarea(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      url: data['url'] as String? ?? '',
      thumbnailUrl: data['thumbnail_url'] as String?,
      tipo: TipoAdjunto.values.firstWhere(
        (e) => e.name == (data['tipo'] as String? ?? ''),
        orElse: () => TipoAdjunto.documento,
      ),
      tamanioBytes: data['tamanio_bytes'] as int? ?? 0,
      subidoPorId: data['subido_por_id'] as String? ?? '',
      fechaSubida: _parseTs(data['fecha_subida']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'tipo': tipo.name,
        'tamanio_bytes': tamanioBytes,
        'subido_por_id': subidoPorId,
        'fecha_subida': Timestamp.fromDate(fechaSubida),
      };

  String get tamanioFormateado {
    if (tamanioBytes < 1024) return '${tamanioBytes}B';
    if (tamanioBytes < 1024 * 1024) return '${(tamanioBytes / 1024).toStringAsFixed(1)}KB';
    return '${(tamanioBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

