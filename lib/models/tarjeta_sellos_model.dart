import 'package:cloud_firestore/cloud_firestore.dart';

/// Recompensa desbloqueada por el cliente
class RecompensaDesbloqueada {
  final String recompensaId;
  final String titulo;
  final String estado; // 'disponible' | 'canjeada' | 'expirada'
  final DateTime desbloqueadaAt;
  final DateTime? canjeadaAt;
  final String? qrCanjeId;

  const RecompensaDesbloqueada({
    required this.recompensaId,
    required this.titulo,
    required this.estado,
    required this.desbloqueadaAt,
    this.canjeadaAt,
    this.qrCanjeId,
  });

  factory RecompensaDesbloqueada.fromMap(Map<String, dynamic> map) {
    return RecompensaDesbloqueada(
      recompensaId: map['recompensa_id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      estado: map['estado'] as String? ?? 'disponible',
      desbloqueadaAt: (map['desbloqueada_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      canjeadaAt: (map['canjeada_at'] as Timestamp?)?.toDate(),
      qrCanjeId: map['qr_canje_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'recompensa_id': recompensaId,
    'titulo': titulo,
    'estado': estado,
    'desbloqueada_at': Timestamp.fromDate(desbloqueadaAt),
    if (canjeadaAt != null) 'canjeada_at': Timestamp.fromDate(canjeadaAt!),
    if (qrCanjeId != null) 'qr_canje_id': qrCanjeId,
  };

  RecompensaDesbloqueada copyWith({
    String? recompensaId,
    String? titulo,
    String? estado,
    DateTime? desbloqueadaAt,
    DateTime? canjeadaAt,
    String? qrCanjeId,
  }) {
    return RecompensaDesbloqueada(
      recompensaId: recompensaId ?? this.recompensaId,
      titulo: titulo ?? this.titulo,
      estado: estado ?? this.estado,
      desbloqueadaAt: desbloqueadaAt ?? this.desbloqueadaAt,
      canjeadaAt: canjeadaAt ?? this.canjeadaAt,
      qrCanjeId: qrCanjeId ?? this.qrCanjeId,
    );
  }

  bool get estaDisponible => estado == 'disponible';
  bool get estaCanjeada => estado == 'canjeada';
  bool get estaExpirada => estado == 'expirada';
}

/// Tarjeta de sellos del cliente para un negocio específico
class TarjetaSelloModel {
  final String id;
  final String negocioId;
  final String negocioNombre;
  final String? negocioFoto;
  final String programaId;
  final int sellosActuales;
  final int sellosTotalesHistorico;
  final List<RecompensaDesbloqueada> recompensasDesbloqueadas;
  final DateTime? ultimoCheckin;
  final DateTime creadoAt;
  final DateTime? actualizadoAt;

  const TarjetaSelloModel({
    required this.id,
    required this.negocioId,
    required this.negocioNombre,
    this.negocioFoto,
    required this.programaId,
    required this.sellosActuales,
    required this.sellosTotalesHistorico,
    required this.recompensasDesbloqueadas,
    this.ultimoCheckin,
    required this.creadoAt,
    this.actualizadoAt,
  });

  factory TarjetaSelloModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final recompensasList = (d['recompensas_desbloqueadas'] as List<dynamic>?)
        ?.map((r) => RecompensaDesbloqueada.fromMap(r as Map<String, dynamic>))
        .toList() ?? [];

    return TarjetaSelloModel(
      id: doc.id,
      negocioId: d['negocio_id'] as String? ?? '',
      negocioNombre: d['negocio_nombre'] as String? ?? '',
      negocioFoto: d['negocio_foto'] as String?,
      programaId: d['programa_id'] as String? ?? '',
      sellosActuales: d['sellos_actuales'] as int? ?? 0,
      sellosTotalesHistorico: d['sellos_totales_historico'] as int? ?? 0,
      recompensasDesbloqueadas: recompensasList,
      ultimoCheckin: (d['ultimo_checkin'] as Timestamp?)?.toDate(),
      creadoAt: (d['creado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualizadoAt: (d['actualizado_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id': negocioId,
    'negocio_nombre': negocioNombre,
    if (negocioFoto != null) 'negocio_foto': negocioFoto,
    'programa_id': programaId,
    'sellos_actuales': sellosActuales,
    'sellos_totales_historico': sellosTotalesHistorico,
    'recompensas_desbloqueadas': recompensasDesbloqueadas.map((r) => r.toMap()).toList(),
    if (ultimoCheckin != null) 'ultimo_checkin': Timestamp.fromDate(ultimoCheckin!),
    'creado_at': Timestamp.fromDate(creadoAt),
    if (actualizadoAt != null) 'actualizado_at': Timestamp.fromDate(actualizadoAt!),
  };

  TarjetaSelloModel copyWith({
    String? id,
    String? negocioId,
    String? negocioNombre,
    String? negocioFoto,
    String? programaId,
    int? sellosActuales,
    int? sellosTotalesHistorico,
    List<RecompensaDesbloqueada>? recompensasDesbloqueadas,
    DateTime? ultimoCheckin,
    DateTime? creadoAt,
    DateTime? actualizadoAt,
  }) {
    return TarjetaSelloModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      negocioNombre: negocioNombre ?? this.negocioNombre,
      negocioFoto: negocioFoto ?? this.negocioFoto,
      programaId: programaId ?? this.programaId,
      sellosActuales: sellosActuales ?? this.sellosActuales,
      sellosTotalesHistorico: sellosTotalesHistorico ?? this.sellosTotalesHistorico,
      recompensasDesbloqueadas: recompensasDesbloqueadas ?? this.recompensasDesbloqueadas,
      ultimoCheckin: ultimoCheckin ?? this.ultimoCheckin,
      creadoAt: creadoAt ?? this.creadoAt,
      actualizadoAt: actualizadoAt ?? this.actualizadoAt,
    );
  }

  /// Obtiene las recompensas disponibles para canjear
  List<RecompensaDesbloqueada> get recompensasDisponibles =>
      recompensasDesbloqueadas.where((r) => r.estaDisponible).toList();

  /// Obtiene las recompensas ya canjeadas
  List<RecompensaDesbloqueada> get recompensasCanjeadas =>
      recompensasDesbloqueadas.where((r) => r.estaCanjeada).toList();

  /// Verifica si puede hacer check-in (no ha visitado en las últimas 2 horas)
  bool get puedeHacerCheckin {
    if (ultimoCheckin == null) return true;
    final diferencia = DateTime.now().difference(ultimoCheckin!);
    return diferencia.inHours >= 2;
  }

  /// Tiempo restante hasta poder hacer check-in de nuevo
  Duration? get tiempoHastaProximoCheckin {
    if (puedeHacerCheckin) return null;
    final diferencia = DateTime.now().difference(ultimoCheckin!);
    return const Duration(hours: 2) - diferencia;
  }
}

