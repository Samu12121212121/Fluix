import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de cierre de caja diario
class CierreCaja {
  final String? id;
  final DateTime fecha;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;
  final double totalVentas;
  final int numTickets;
  final String cerradoPor;
  final DateTime timestamp;
  final String? observaciones;

  const CierreCaja({
    this.id,
    required this.fecha,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalTransferencia,
    required this.totalVentas,
    required this.numTickets,
    required this.cerradoPor,
    required this.timestamp,
    this.observaciones,
  });

  double get totalGeneral =>
      totalEfectivo + totalTarjeta + totalTransferencia;

  factory CierreCaja.fromMap(Map<String, dynamic> map, String id) {
    DateTime _toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return CierreCaja(
      id: id,
      fecha: _toDate(map['fecha']),
      totalEfectivo: (map['total_efectivo'] as num?)?.toDouble() ?? 0.0,
      totalTarjeta: (map['total_tarjeta'] as num?)?.toDouble() ?? 0.0,
      totalTransferencia:
          (map['total_transferencia'] as num?)?.toDouble() ?? 0.0,
      totalVentas: (map['total_ventas'] as num?)?.toDouble() ?? 0.0,
      numTickets: (map['num_tickets'] as num?)?.toInt() ?? 0,
      cerradoPor: map['cerrado_por'] as String? ?? '',
      timestamp: _toDate(map['timestamp']),
      observaciones: map['observaciones'] as String?,
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
        'timestamp': Timestamp.fromDate(timestamp),
        'observaciones': observaciones,
      };

  /// Clave de documento Firestore: "yyyy-MM-dd"
  static String claveDocumento(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

