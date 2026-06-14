import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoTransaccion { ganancia, canje }

class TransaccionModel {
  final String id;
  final TipoTransaccion tipo;
  final int cantidad;
  final String concepto;
  final String? trofeoId;
  final DateTime fecha;

  const TransaccionModel({
    required this.id,
    required this.tipo,
    required this.cantidad,
    required this.concepto,
    this.trofeoId,
    required this.fecha,
  });

  factory TransaccionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TransaccionModel(
      id: doc.id,
      tipo: (data['tipo'] as String?) == 'canje' ? TipoTransaccion.canje : TipoTransaccion.ganancia,
      cantidad: (data['cantidad'] as int?) ?? 0,
      concepto: (data['concepto'] as String?) ?? '',
      trofeoId: data['trofeo_id'] as String?,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tipo': tipo == TipoTransaccion.canje ? 'canje' : 'ganancia',
    'cantidad': cantidad,
    'concepto': concepto,
    if (trofeoId != null) 'trofeo_id': trofeoId,
    'fecha': FieldValue.serverTimestamp(),
  };
}

class MonederoModel {
  final int saldo;
  final int totalGanado;
  final int totalCanjeado;
  final DateTime? ultimaActualizacion;

  const MonederoModel({
    required this.saldo,
    required this.totalGanado,
    required this.totalCanjeado,
    this.ultimaActualizacion,
  });

  factory MonederoModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MonederoModel(
      saldo: (data['saldo'] as int?) ?? 0,
      totalGanado: (data['total_ganado'] as int?) ?? 0,
      totalCanjeado: (data['total_canjeado'] as int?) ?? 0,
      ultimaActualizacion: (data['ultima_actualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'saldo': saldo,
    'total_ganado': totalGanado,
    'total_canjeado': totalCanjeado,
    'ultima_actualizacion': FieldValue.serverTimestamp(),
  };

  MonederoModel copyWith({int? saldo, int? totalGanado, int? totalCanjeado}) => MonederoModel(
    saldo: saldo ?? this.saldo,
    totalGanado: totalGanado ?? this.totalGanado,
    totalCanjeado: totalCanjeado ?? this.totalCanjeado,
    ultimaActualizacion: ultimaActualizacion,
  );
}
