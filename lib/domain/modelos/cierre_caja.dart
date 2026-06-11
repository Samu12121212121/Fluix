import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de cierre de caja diario (Z-Report)
class CierreCaja {
  final String? id;
  final DateTime fecha;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;
  final double totalVentas;
  final int numTickets;
  // UID del empleado que cerró (legacy) + nombre real (nuevo)
  final String cerradoPor;
  final String cerradoPorNombre;
  final DateTime timestamp;
  final String? observaciones;
  // ── Control de efectivo ────────────────────────────────────────────────
  final double fondoInicial;
  final double efectivoTeorico;
  final double efectivoReal;
  final double diferencia;
  // ── Z-Report fiscal ────────────────────────────────────────────────────
  /// Número Z correlativo, sin huecos. Null en cierres generados antes del CF.
  final int? numeroZ;
  /// ID del terminal TPV que cerró la caja.
  final String dispositivoId;
  /// Desglose de IVA: key = tipo (4/10/21), value = {base, cuota}.
  final Map<String, Map<String, double>> desgloseIva;

  const CierreCaja({
    this.id,
    required this.fecha,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalTransferencia,
    required this.totalVentas,
    required this.numTickets,
    required this.cerradoPor,
    this.cerradoPorNombre = '',
    required this.timestamp,
    this.observaciones,
    this.fondoInicial = 0,
    this.efectivoTeorico = 0,
    this.efectivoReal = 0,
    this.diferencia = 0,
    this.numeroZ,
    this.dispositivoId = '',
    this.desgloseIva = const {},
  });

  double get totalGeneral =>
      totalEfectivo + totalTarjeta + totalTransferencia;

  factory CierreCaja.fromMap(Map<String, dynamic> map, String id) {
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    Map<String, Map<String, double>> parseDesglose(dynamic raw) {
      if (raw == null) return {};
      final m = raw as Map<String, dynamic>;
      return m.map((k, v) {
        final entry = v as Map<String, dynamic>;
        return MapEntry(k, {
          'base': (entry['base'] as num?)?.toDouble() ?? 0.0,
          'cuota': (entry['cuota'] as num?)?.toDouble() ?? 0.0,
        });
      });
    }

    return CierreCaja(
      id: id,
      fecha: toDate(map['fecha']),
      totalEfectivo: (map['total_efectivo'] as num?)?.toDouble() ?? 0.0,
      totalTarjeta: (map['total_tarjeta'] as num?)?.toDouble() ?? 0.0,
      totalTransferencia:
          (map['total_transferencia'] as num?)?.toDouble() ?? 0.0,
      totalVentas: (map['total_ventas'] as num?)?.toDouble() ?? 0.0,
      numTickets: (map['num_tickets'] as num?)?.toInt() ?? 0,
      cerradoPor: map['cerrado_por'] as String? ?? '',
      cerradoPorNombre: map['cerrado_por_nombre'] as String? ?? '',
      timestamp: toDate(map['timestamp'] ?? map['timestamp_cierre']),
      observaciones: map['observaciones'] as String?,
      fondoInicial: (map['fondo_inicial'] as num?)?.toDouble() ?? 0.0,
      efectivoTeorico: (map['efectivo_teorico'] as num?)?.toDouble() ?? 0.0,
      efectivoReal: (map['efectivo_real'] as num?)?.toDouble() ?? 0.0,
      diferencia: (map['diferencia'] as num?)?.toDouble() ?? 0.0,
      numeroZ: (map['numero_z'] as num?)?.toInt(),
      dispositivoId: map['dispositivo_id'] as String? ?? '',
      desgloseIva: parseDesglose(map['desglose_iva']),
    );
  }

  Map<String, dynamic> toMap() => {
        'fecha': Timestamp.fromDate(fecha),
        'total_efectivo': totalEfectivo,
        'total_tarjeta': totalTarjeta,
        'total_transferencia': totalTransferencia,
        'total_ventas': totalVentas,
        'num_tickets': numTickets,
        'cerrado_por': cerradoPor,
        'cerrado_por_nombre': cerradoPorNombre,
        'timestamp': Timestamp.fromDate(timestamp),
        'observaciones': observaciones,
        'fondo_inicial': fondoInicial,
        'efectivo_teorico': efectivoTeorico,
        'efectivo_real': efectivoReal,
        'diferencia': diferencia,
        if (numeroZ != null) 'numero_z': numeroZ,
        'dispositivo_id': dispositivoId,
        'desglose_iva': desgloseIva,
      };

  /// Clave de documento Firestore: "yyyy-MM-dd"
  static String claveDocumento(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

