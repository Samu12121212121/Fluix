import 'package:cloud_firestore/cloud_firestore.dart';

class ValoracionModel {
  final String id;
  final String negocioId;
  final String clienteId;
  final String clienteNombre;
  final String? clienteFotoUrl;
  final String reservaId;
  final int estrellas;          // 1-5
  final String comentario;
  final String? respuestaNegocio;
  final DateTime? respuestaAt;
  final DateTime creadoAt;
  final bool visible;

  const ValoracionModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteFotoUrl,
    required this.reservaId,
    required this.estrellas,
    required this.comentario,
    this.respuestaNegocio,
    this.respuestaAt,
    required this.creadoAt,
    this.visible = true,
  });

  bool get tieneRespuesta => respuestaNegocio != null && respuestaNegocio!.isNotEmpty;

  factory ValoracionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ValoracionModel(
      id:                 doc.id,
      negocioId:          d['negocio_id']         as String? ?? '',
      clienteId:          d['cliente_id']          as String? ?? '',
      clienteNombre:      d['cliente_nombre']      as String? ?? 'Cliente',
      clienteFotoUrl:     d['cliente_foto_url']    as String?,
      reservaId:          d['reserva_id']          as String? ?? '',
      estrellas:          d['estrellas']           as int? ?? 5,
      comentario:         d['comentario']          as String? ?? '',
      respuestaNegocio:   d['respuesta_negocio']   as String?,
      respuestaAt:        (d['respuesta_at']       as Timestamp?)?.toDate(),
      creadoAt:           (d['creado_at']          as Timestamp?)?.toDate() ?? DateTime.now(),
      visible:            d['visible']             as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id':       negocioId,
    'cliente_id':       clienteId,
    'cliente_nombre':   clienteNombre,
    if (clienteFotoUrl != null) 'cliente_foto_url': clienteFotoUrl,
    'reserva_id':       reservaId,
    'estrellas':        estrellas,
    'comentario':       comentario,
    if (respuestaNegocio != null) 'respuesta_negocio': respuestaNegocio,
    if (respuestaAt != null) 'respuesta_at': Timestamp.fromDate(respuestaAt!),
    'creado_at':        FieldValue.serverTimestamp(),
    'visible':          visible,
  };

  ValoracionModel copyWith({String? respuestaNegocio, DateTime? respuestaAt}) => ValoracionModel(
    id:               id,
    negocioId:        negocioId,
    clienteId:        clienteId,
    clienteNombre:    clienteNombre,
    clienteFotoUrl:   clienteFotoUrl,
    reservaId:        reservaId,
    estrellas:        estrellas,
    comentario:       comentario,
    respuestaNegocio: respuestaNegocio ?? this.respuestaNegocio,
    respuestaAt:      respuestaAt ?? this.respuestaAt,
    creadoAt:         creadoAt,
    visible:          visible,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDIENTE VALORAR
// ─────────────────────────────────────────────────────────────────────────────
class PendienteValorar {
  final String reservaId;
  final String negocioId;
  final String negocioNombre;
  final String? negocioFoto;
  final DateTime fechaCita;
  final DateTime expiraAt;
  final bool notificacionEnviada;

  const PendienteValorar({
    required this.reservaId,
    required this.negocioId,
    required this.negocioNombre,
    this.negocioFoto,
    required this.fechaCita,
    required this.expiraAt,
    required this.notificacionEnviada,
  });

  factory PendienteValorar.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PendienteValorar(
      reservaId:            doc.id,
      negocioId:            d['negocio_id']            as String? ?? '',
      negocioNombre:        d['negocio_nombre']         as String? ?? '',
      negocioFoto:          d['negocio_foto']           as String?,
      fechaCita:            (d['fecha_cita']            as Timestamp?)?.toDate() ?? DateTime.now(),
      expiraAt:             (d['expira_at']             as Timestamp?)?.toDate() ?? DateTime.now(),
      notificacionEnviada:  d['notificacion_enviada']   as bool? ?? false,
    );
  }
}

