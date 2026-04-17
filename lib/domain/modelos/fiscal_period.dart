import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de un período fiscal — empresas/{id}/fiscal_periods/{periodId}
/// periodId = "2026-Q1" (trimestral) o "2026" (anual)
class FiscalPeriod {
  final String period;
  final String tipo;              // 'trimestral' | 'anual'
  final String estado;            // 'abierto' | 'cerrado' | 'presentado'

  // Resumen
  final int numInvoicesReceived;
  final int numInvoicesSent;
  final int totalBaseReceivedCents;
  final int totalBaseSentCents;

  // Modelos aplicables
  final List<String> modelosRequeridos;   // ['303', '111', '115']
  final List<String> modelosPresentados;

  // Fechas clave
  final DateTime? fechaLimitePresentacion;
  final DateTime? cerradoAt;
  final DateTime? presentadoAt;

  final String? notas;

  const FiscalPeriod({
    required this.period,
    required this.tipo,
    this.estado = 'abierto',
    this.numInvoicesReceived = 0,
    this.numInvoicesSent = 0,
    this.totalBaseReceivedCents = 0,
    this.totalBaseSentCents = 0,
    this.modelosRequeridos = const [],
    this.modelosPresentados = const [],
    this.fechaLimitePresentacion,
    this.cerradoAt,
    this.presentadoAt,
    this.notas,
  });

  factory FiscalPeriod.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FiscalPeriod(
      period: d['period'] as String? ?? doc.id,
      tipo: d['tipo'] as String? ?? 'trimestral',
      estado: d['estado'] as String? ?? 'abierto',
      numInvoicesReceived: d['num_invoices_received'] as int? ?? 0,
      numInvoicesSent: d['num_invoices_sent'] as int? ?? 0,
      totalBaseReceivedCents: d['total_base_received_cents'] as int? ?? 0,
      totalBaseSentCents: d['total_base_sent_cents'] as int? ?? 0,
      modelosRequeridos: List<String>.from(d['modelos_requeridos'] ?? []),
      modelosPresentados: List<String>.from(d['modelos_presentados'] ?? []),
      fechaLimitePresentacion: _ts(d['fecha_limite_presentacion']),
      cerradoAt: _ts(d['cerrado_at']),
      presentadoAt: _ts(d['presentado_at']),
      notas: d['notas'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'period': period,
    'tipo': tipo,
    'estado': estado,
    'num_invoices_received': numInvoicesReceived,
    'num_invoices_sent': numInvoicesSent,
    'total_base_received_cents': totalBaseReceivedCents,
    'total_base_sent_cents': totalBaseSentCents,
    'modelos_requeridos': modelosRequeridos,
    'modelos_presentados': modelosPresentados,
    'fecha_limite_presentacion': fechaLimitePresentacion != null
        ? Timestamp.fromDate(fechaLimitePresentacion!)
        : null,
    'cerrado_at': cerradoAt != null ? Timestamp.fromDate(cerradoAt!) : null,
    'presentado_at': presentadoAt != null ? Timestamp.fromDate(presentadoAt!) : null,
    'notas': notas,
  };

  bool get estaAbierto => estado == 'abierto';
  bool get estaCerrado => estado == 'cerrado';
  bool get estaPresentado => estado == 'presentado';
}

/// Histórico de exports fiscales — empresas/{id}/fiscal_exports/{exportId}
class FiscalExport {
  final String id;
  final String modelId;           // FK a fiscal_models
  final String modelCode;
  final String period;
  final String format;            // 'pdf_oficial', 'pre_declaracion_txt', 'csv', 'xml'
  final String filename;
  final String storagePath;
  final int fileSizeBytes;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime? downloadedAt;
  final String? downloadedBy;
  final String modelVersion;

  const FiscalExport({
    required this.id,
    required this.modelId,
    required this.modelCode,
    required this.period,
    required this.format,
    required this.filename,
    required this.storagePath,
    this.fileSizeBytes = 0,
    required this.generatedAt,
    required this.generatedBy,
    this.downloadedAt,
    this.downloadedBy,
    this.modelVersion = '',
  });

  factory FiscalExport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FiscalExport(
      id: doc.id,
      modelId: d['model_id'] as String? ?? '',
      modelCode: d['model_code'] as String? ?? '',
      period: d['period'] as String? ?? '',
      format: d['format'] as String? ?? '',
      filename: d['filename'] as String? ?? '',
      storagePath: d['storage_path'] as String? ?? '',
      fileSizeBytes: d['file_size_bytes'] as int? ?? 0,
      generatedAt: _ts(d['generated_at']) ?? DateTime.now(),
      generatedBy: d['generated_by'] as String? ?? '',
      downloadedAt: _ts(d['downloaded_at']),
      downloadedBy: d['downloaded_by'] as String?,
      modelVersion: d['model_version'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'model_id': modelId,
    'model_code': modelCode,
    'period': period,
    'format': format,
    'filename': filename,
    'storage_path': storagePath,
    'file_size_bytes': fileSizeBytes,
    'generated_at': Timestamp.fromDate(generatedAt),
    'generated_by': generatedBy,
    'downloaded_at': downloadedAt != null ? Timestamp.fromDate(downloadedAt!) : null,
    'downloaded_by': downloadedBy,
    'model_version': modelVersion,
  };
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

