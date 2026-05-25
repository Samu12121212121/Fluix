import 'package:cloud_firestore/cloud_firestore.dart';

/// QR de canje generado por el cliente para validar recompensa
class QrCanjeModel {
  final String id;
  final String negocioId;
  final String clienteId;
  final String clienteNombre;
  final String? clienteFoto;
  final String recompensaId;
  final String recompensaTitulo;
  final String recompensaDescripcion;
  final String recompensaTipo;
  final dynamic recompensaValor;
  final String estado; // 'pendiente' | 'canjeado' | 'expirado'
  final DateTime generadoAt;
  final DateTime expiraAt;
  final DateTime? canjeadoAt;
  final String? canjeadoPorUid; // UID del empleado que escaneó

  const QrCanjeModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteFoto,
    required this.recompensaId,
    required this.recompensaTitulo,
    required this.recompensaDescripcion,
    required this.recompensaTipo,
    required this.recompensaValor,
    required this.estado,
    required this.generadoAt,
    required this.expiraAt,
    this.canjeadoAt,
    this.canjeadoPorUid,
  });

  factory QrCanjeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QrCanjeModel(
      id: doc.id,
      negocioId: d['negocio_id'] as String? ?? '',
      clienteId: d['cliente_id'] as String? ?? '',
      clienteNombre: d['cliente_nombre'] as String? ?? '',
      clienteFoto: d['cliente_foto'] as String?,
      recompensaId: d['recompensa_id'] as String? ?? '',
      recompensaTitulo: d['recompensa_titulo'] as String? ?? '',
      recompensaDescripcion: d['recompensa_descripcion'] as String? ?? '',
      recompensaTipo: d['recompensa_tipo'] as String? ?? '',
      recompensaValor: d['recompensa_valor'],
      estado: d['estado'] as String? ?? 'pendiente',
      generadoAt: (d['generado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiraAt: (d['expira_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      canjeadoAt: (d['canjeado_at'] as Timestamp?)?.toDate(),
      canjeadoPorUid: d['canjeado_por_uid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id': negocioId,
    'cliente_id': clienteId,
    'cliente_nombre': clienteNombre,
    if (clienteFoto != null) 'cliente_foto': clienteFoto,
    'recompensa_id': recompensaId,
    'recompensa_titulo': recompensaTitulo,
    'recompensa_descripcion': recompensaDescripcion,
    'recompensa_tipo': recompensaTipo,
    'recompensa_valor': recompensaValor,
    'estado': estado,
    'generado_at': Timestamp.fromDate(generadoAt),
    'expira_at': Timestamp.fromDate(expiraAt),
    if (canjeadoAt != null) 'canjeado_at': Timestamp.fromDate(canjeadoAt!),
    if (canjeadoPorUid != null) 'canjeado_por_uid': canjeadoPorUid,
  };

  QrCanjeModel copyWith({
    String? id,
    String? negocioId,
    String? clienteId,
    String? clienteNombre,
    String? clienteFoto,
    String? recompensaId,
    String? recompensaTitulo,
    String? recompensaDescripcion,
    String? recompensaTipo,
    dynamic recompensaValor,
    String? estado,
    DateTime? generadoAt,
    DateTime? expiraAt,
    DateTime? canjeadoAt,
    String? canjeadoPorUid,
  }) {
    return QrCanjeModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteFoto: clienteFoto ?? this.clienteFoto,
      recompensaId: recompensaId ?? this.recompensaId,
      recompensaTitulo: recompensaTitulo ?? this.recompensaTitulo,
      recompensaDescripcion: recompensaDescripcion ?? this.recompensaDescripcion,
      recompensaTipo: recompensaTipo ?? this.recompensaTipo,
      recompensaValor: recompensaValor ?? this.recompensaValor,
      estado: estado ?? this.estado,
      generadoAt: generadoAt ?? this.generadoAt,
      expiraAt: expiraAt ?? this.expiraAt,
      canjeadoAt: canjeadoAt ?? this.canjeadoAt,
      canjeadoPorUid: canjeadoPorUid ?? this.canjeadoPorUid,
    );
  }

  bool get estaPendiente => estado == 'pendiente';
  bool get estaCanjeado => estado == 'canjeado';
  bool get estaExpirado => estado == 'expirado' || DateTime.now().isAfter(expiraAt);

  /// Tiempo restante en segundos hasta expirar
  int get segundosRestantes {
    if (estaExpirado || estaCanjeado) return 0;
    final diferencia = expiraAt.difference(DateTime.now());
    return diferencia.inSeconds > 0 ? diferencia.inSeconds : 0;
  }

  /// Formato del valor de la recompensa
  String get textoValor {
    if (recompensaTipo == 'descuento_porcentaje') return '$recompensaValor%';
    if (recompensaTipo == 'visita_gratis') return 'Gratis';
    if (recompensaTipo == 'producto') return recompensaValor.toString();
    return recompensaValor.toString();
  }
}

/// Modelo de checkin registrado
class CheckinModel {
  final String id;
  final String negocioId;
  final String clienteId;
  final String clienteNombre;
  final String? clienteFoto;
  final int sellosAntes;
  final int sellosDespues;
  final bool recompensaDesbloqueada;
  final String? recompensaId;
  final String? recompensaTitulo;
  final DateTime creadoAt;

  const CheckinModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteFoto,
    required this.sellosAntes,
    required this.sellosDespues,
    required this.recompensaDesbloqueada,
    this.recompensaId,
    this.recompensaTitulo,
    required this.creadoAt,
  });

  factory CheckinModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CheckinModel(
      id: doc.id,
      negocioId: d['negocio_id'] as String? ?? '',
      clienteId: d['cliente_id'] as String? ?? '',
      clienteNombre: d['cliente_nombre'] as String? ?? '',
      clienteFoto: d['cliente_foto'] as String?,
      sellosAntes: d['sellos_antes'] as int? ?? 0,
      sellosDespues: d['sellos_despues'] as int? ?? 0,
      recompensaDesbloqueada: d['recompensa_desbloqueada'] as bool? ?? false,
      recompensaId: d['recompensa_id'] as String?,
      recompensaTitulo: d['recompensa_titulo'] as String?,
      creadoAt: (d['creado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id': negocioId,
    'cliente_id': clienteId,
    'cliente_nombre': clienteNombre,
    if (clienteFoto != null) 'cliente_foto': clienteFoto,
    'sellos_antes': sellosAntes,
    'sellos_despues': sellosDespues,
    'recompensa_desbloqueada': recompensaDesbloqueada,
    if (recompensaId != null) 'recompensa_id': recompensaId,
    if (recompensaTitulo != null) 'recompensa_titulo': recompensaTitulo,
    'creado_at': FieldValue.serverTimestamp(),
  };
}

