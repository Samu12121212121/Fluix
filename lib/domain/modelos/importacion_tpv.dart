import 'package:cloud_firestore/cloud_firestore.dart';

// ── IMPORTACIÓN TPV ───────────────────────────────────────────────────────────

class ImportacionTpv {
  final String id;
  final String empresaId;
  final String nombreFichero;
  final DateTime fechaImportacion;
  final int totalFilas;
  final int filasImportadas;
  final int filasError;
  final String origen; // 'csv_manual', 'glop', 'agora', etc.
  final List<String> pedidosCreados;

  const ImportacionTpv({
    required this.id,
    required this.empresaId,
    required this.nombreFichero,
    required this.fechaImportacion,
    required this.totalFilas,
    required this.filasImportadas,
    required this.filasError,
    required this.origen,
    required this.pedidosCreados,
  });

  factory ImportacionTpv.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ImportacionTpv(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      nombreFichero: d['nombre_fichero'] ?? '',
      fechaImportacion: _parseTs(d['fecha_importacion']),
      totalFilas: (d['total_filas'] as num?)?.toInt() ?? 0,
      filasImportadas: (d['filas_importadas'] as num?)?.toInt() ?? 0,
      filasError: (d['filas_error'] as num?)?.toInt() ?? 0,
      origen: d['origen'] ?? 'csv_manual',
      pedidosCreados: List<String>.from(d['pedidos_creados'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'nombre_fichero': nombreFichero,
    'fecha_importacion': Timestamp.fromDate(fechaImportacion),
    'total_filas': totalFilas,
    'filas_importadas': filasImportadas,
    'filas_error': filasError,
    'origen': origen,
    'pedidos_creados': pedidosCreados,
  };
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

