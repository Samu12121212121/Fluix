import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorías predefinidas de documentos de empleado
enum CategoriaDocumento {
  contrato,
  dniNie,
  tc2Rlc,
  nominas,
  certificadoDiscapacidad,
  tituloCertificacion,
  otros,
}

extension CategoriaDocumentoExt on CategoriaDocumento {
  String get nombre {
    switch (this) {
      case CategoriaDocumento.contrato:                return 'Contrato de trabajo';
      case CategoriaDocumento.dniNie:                  return 'DNI / NIE';
      case CategoriaDocumento.tc2Rlc:                  return 'TC2 / RLC (cotizaciones SS)';
      case CategoriaDocumento.nominas:                 return 'Nóminas';
      case CategoriaDocumento.certificadoDiscapacidad: return 'Certificado de discapacidad';
      case CategoriaDocumento.tituloCertificacion:     return 'Título o certificación profesional';
      case CategoriaDocumento.otros:                   return 'Otros';
    }
  }

  String get icono {
    switch (this) {
      case CategoriaDocumento.contrato:                return '📄';
      case CategoriaDocumento.dniNie:                  return '🪪';
      case CategoriaDocumento.tc2Rlc:                  return '🏛️';
      case CategoriaDocumento.nominas:                 return '💰';
      case CategoriaDocumento.certificadoDiscapacidad: return '♿';
      case CategoriaDocumento.tituloCertificacion:     return '🎓';
      case CategoriaDocumento.otros:                   return '📎';
    }
  }
}

/// Modelo de documento de empleado almacenado en Firestore
class DocumentoEmpleado {
  final String id;
  final String empleadoId;
  final String empresaId;
  final CategoriaDocumento categoria;
  final String nombre;
  final String url;
  final String storagePath;
  final String mimeType;
  final int tamanoBytes;
  final DateTime fechaSubida;
  final DateTime? fechaEmision;
  final DateTime? fechaCaducidad;
  final String subidoPor;

  const DocumentoEmpleado({
    required this.id,
    required this.empleadoId,
    required this.empresaId,
    required this.categoria,
    required this.nombre,
    required this.url,
    required this.storagePath,
    required this.mimeType,
    this.tamanoBytes = 0,
    required this.fechaSubida,
    this.fechaEmision,
    this.fechaCaducidad,
    required this.subidoPor,
  });

  bool get esPdf => mimeType == 'application/pdf';
  bool get esImagen => mimeType.startsWith('image/');

  bool get estaCaducado =>
      fechaCaducidad != null && fechaCaducidad!.isBefore(DateTime.now());

  bool get caducaProximamente {
    if (fechaCaducidad == null) return false;
    final diasRestantes = fechaCaducidad!.difference(DateTime.now()).inDays;
    return diasRestantes >= 0 && diasRestantes <= 30;
  }

  int? get diasParaCaducidad =>
      fechaCaducidad?.difference(DateTime.now()).inDays;

  factory DocumentoEmpleado.fromMap(Map<String, dynamic> map, String id) {
    return DocumentoEmpleado(
      id: id,
      empleadoId: map['empleado_id'] ?? '',
      empresaId: map['empresa_id'] ?? '',
      categoria: CategoriaDocumento.values.firstWhere(
        (c) => c.name == (map['categoria'] as String?),
        orElse: () => CategoriaDocumento.otros,
      ),
      nombre: map['nombre'] ?? '',
      url: map['url'] ?? '',
      storagePath: map['storage_path'] ?? '',
      mimeType: map['mime_type'] ?? '',
      tamanoBytes: (map['tamano_bytes'] as num?)?.toInt() ?? 0,
      fechaSubida: _parseDate(map['fecha_subida']) ?? DateTime.now(),
      fechaEmision: _parseDate(map['fecha_emision']),
      fechaCaducidad: _parseDate(map['fecha_caducidad']),
      subidoPor: map['subido_por'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'empleado_id': empleadoId,
    'empresa_id': empresaId,
    'categoria': categoria.name,
    'nombre': nombre,
    'url': url,
    'storage_path': storagePath,
    'mime_type': mimeType,
    'tamano_bytes': tamanoBytes,
    'fecha_subida': Timestamp.fromDate(fechaSubida),
    if (fechaEmision != null) 'fecha_emision': Timestamp.fromDate(fechaEmision!),
    if (fechaCaducidad != null) 'fecha_caducidad': Timestamp.fromDate(fechaCaducidad!),
    'subido_por': subidoPor,
  };

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    return null;
  }
}

