import 'package:cloud_firestore/cloud_firestore.dart';

// ── TIPO DE INTERACCIÓN ───────────────────────────────────────────────────────

enum TipoInteraccion { llamada, email, whatsapp, nota, reunion, reserva }

extension TipoInteraccionExt on TipoInteraccion {
  String get label {
    switch (this) {
      case TipoInteraccion.llamada:  return 'Llamada';
      case TipoInteraccion.email:    return 'Email';
      case TipoInteraccion.whatsapp: return 'WhatsApp';
      case TipoInteraccion.nota:     return 'Nota';
      case TipoInteraccion.reunion:  return 'Reunión';
      case TipoInteraccion.reserva:  return 'Reserva';
    }
  }

  String get value => name;

  static TipoInteraccion fromString(String v) {
    return TipoInteraccion.values.firstWhere(
      (e) => e.name == v,
      orElse: () => TipoInteraccion.nota,
    );
  }
}

// ── MODELO ────────────────────────────────────────────────────────────────────

class InteraccionCliente {
  final String id;
  final TipoInteraccion tipo;
  final DateTime fecha;
  final String descripcion;
  final String usuarioNombre;

  const InteraccionCliente({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.descripcion,
    required this.usuarioNombre,
  });

  factory InteraccionCliente.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InteraccionCliente(
      id: doc.id,
      tipo: TipoInteraccionExt.fromString(d['tipo'] ?? 'nota'),
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descripcion: d['descripcion'] ?? '',
      usuarioNombre: d['usuario_nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'tipo': tipo.value,
    'fecha': Timestamp.fromDate(fecha),
    'descripcion': descripcion,
    'usuario_nombre': usuarioNombre,
  };
}

