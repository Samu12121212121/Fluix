import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum EstadoFlashSlot { activo, expirado, completo, cancelado }

extension EstadoFlashSlotX on EstadoFlashSlot {
  String get nombre {
    switch (this) {
      case EstadoFlashSlot.activo:    return 'activo';
      case EstadoFlashSlot.expirado:  return 'expirado';
      case EstadoFlashSlot.completo:  return 'completo';
      case EstadoFlashSlot.cancelado: return 'cancelado';
    }
  }

  static EstadoFlashSlot fromString(String? s) {
    switch (s) {
      case 'expirado':  return EstadoFlashSlot.expirado;
      case 'completo':  return EstadoFlashSlot.completo;
      case 'cancelado': return EstadoFlashSlot.cancelado;
      default:          return EstadoFlashSlot.activo;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class FlashSlotModel {
  final String id;
  final String negocioId;
  final String negocioNombre;
  final String? negocioFotoUrl;
  final String empresaId;

  final String servicioNombre;
  final String? servicioId;

  final double precioOriginal;
  final String tipoDescuento;   // 'porcentaje' | 'precio_fijo'
  final double valorDescuento;
  final double precioFinal;

  final DateTime fechaHoraInicio;
  final DateTime fechaHoraExpiracion;

  final int huecosTotal;
  final int huecosReservados;

  final EstadoFlashSlot estado;
  final String? profesionalId;
  final String? profesionalNombre;

  final DateTime creadoAt;
  final List<String> reservasIds;

  const FlashSlotModel({
    required this.id,
    required this.negocioId,
    required this.negocioNombre,
    this.negocioFotoUrl,
    required this.empresaId,
    required this.servicioNombre,
    this.servicioId,
    required this.precioOriginal,
    required this.tipoDescuento,
    required this.valorDescuento,
    required this.precioFinal,
    required this.fechaHoraInicio,
    required this.fechaHoraExpiracion,
    required this.huecosTotal,
    required this.huecosReservados,
    required this.estado,
    this.profesionalId,
    this.profesionalNombre,
    required this.creadoAt,
    required this.reservasIds,
  });

  // ── Campos calculados ──────────────────────────────────────────
  int get huecosDisponibles => (huecosTotal - huecosReservados).clamp(0, huecosTotal);
  bool get estaLleno        => huecosReservados >= huecosTotal;
  bool get haExpirado       => DateTime.now().isAfter(fechaHoraExpiracion);
  bool get estaActivo       => estado == EstadoFlashSlot.activo && !haExpirado && !estaLleno;
  Duration get tiempoRestante => fechaHoraExpiracion.difference(DateTime.now());
  double get porcentajeOcupacion =>
      huecosTotal > 0 ? (huecosReservados / huecosTotal).clamp(0.0, 1.0) : 0.0;
  double get ahorro => precioOriginal - precioFinal;
  String get descuentoTexto => tipoDescuento == 'porcentaje'
      ? '${valorDescuento.toInt()}% dto.'
      : '-€${valorDescuento.toStringAsFixed(2)}';

  // ── Serialización ──────────────────────────────────────────────
  factory FlashSlotModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FlashSlotModel(
      id:                   doc.id,
      negocioId:            d['negocio_id']         as String? ?? '',
      negocioNombre:        d['negocio_nombre']      as String? ?? '',
      negocioFotoUrl:       d['negocio_foto_url']    as String?,
      empresaId:            d['empresa_id']          as String? ?? '',
      servicioNombre:       d['servicio_nombre']     as String? ?? '',
      servicioId:           d['servicio_id']         as String?,
      precioOriginal:       (d['precio_original']    as num?)?.toDouble() ?? 0,
      tipoDescuento:        d['tipo_descuento']      as String? ?? 'porcentaje',
      valorDescuento:       (d['valor_descuento']    as num?)?.toDouble() ?? 0,
      precioFinal:          (d['precio_final']       as num?)?.toDouble() ?? 0,
      fechaHoraInicio:      (d['fecha_hora_inicio']  as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaHoraExpiracion:  (d['fecha_hora_expiracion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      huecosTotal:          d['huecos_totales']      as int? ?? 1,
      huecosReservados:     d['huecos_reservados']   as int? ?? 0,
      estado:               EstadoFlashSlotX.fromString(d['estado'] as String?),
      profesionalId:        d['profesional_id']      as String?,
      profesionalNombre:    d['profesional_nombre']  as String?,
      creadoAt:             (d['creado_at']          as Timestamp?)?.toDate() ?? DateTime.now(),
      reservasIds:          (d['reservas_ids']       as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id':            negocioId,
    'negocio_nombre':        negocioNombre,
    if (negocioFotoUrl != null) 'negocio_foto_url': negocioFotoUrl,
    'empresa_id':            empresaId,
    'servicio_nombre':       servicioNombre,
    if (servicioId != null) 'servicio_id': servicioId,
    'precio_original':       precioOriginal,
    'tipo_descuento':        tipoDescuento,
    'valor_descuento':       valorDescuento,
    'precio_final':          precioFinal,
    'fecha_hora_inicio':     Timestamp.fromDate(fechaHoraInicio),
    'fecha_hora_expiracion': Timestamp.fromDate(fechaHoraExpiracion),
    'huecos_totales':        huecosTotal,
    'huecos_reservados':     huecosReservados,
    'estado':                estado.nombre,
    if (profesionalId != null)   'profesional_id':     profesionalId,
    if (profesionalNombre != null) 'profesional_nombre': profesionalNombre,
    'creado_at':             FieldValue.serverTimestamp(),
    'reservas_ids':          reservasIds,
  };

  FlashSlotModel copyWith({
    String? id,
    int? huecosReservados,
    EstadoFlashSlot? estado,
    List<String>? reservasIds,
  }) {
    return FlashSlotModel(
      id:                  id ?? this.id,
      negocioId:           negocioId,
      negocioNombre:       negocioNombre,
      negocioFotoUrl:      negocioFotoUrl,
      empresaId:           empresaId,
      servicioNombre:      servicioNombre,
      servicioId:          servicioId,
      precioOriginal:      precioOriginal,
      tipoDescuento:       tipoDescuento,
      valorDescuento:      valorDescuento,
      precioFinal:         precioFinal,
      fechaHoraInicio:     fechaHoraInicio,
      fechaHoraExpiracion: fechaHoraExpiracion,
      huecosTotal:         huecosTotal,
      huecosReservados:    huecosReservados ?? this.huecosReservados,
      estado:              estado ?? this.estado,
      profesionalId:       profesionalId,
      profesionalNombre:   profesionalNombre,
      creadoAt:            creadoAt,
      reservasIds:         reservasIds ?? this.reservasIds,
    );
  }
}

