import 'package:cloud_firestore/cloud_firestore.dart';
      ];
          ? DateTime.parse(datos['fecha_modificacion'])
      fechaCreacion: DateTime.parse(datos['fecha_creacion']),
      fechaHora: DateTime.parse(datos['fecha_hora']),
import '../../core/enums/enums.dart';

class Reserva extends Equatable {
  final String id;
  final String clienteId;
  final String servicioId;
  final String? empleadoId;
  final EstadoReserva estado;
  final DateTime fechaHora;
  final Duration duracion;
  final double precio;
  final String? notas;
  final String? notasInternas;
  final DateTime fechaCreacion;
  final DateTime? fechaModificacion;
  final String? creadoPor;

  const Reserva({
    required this.id,
    required this.clienteId,
    required this.servicioId,
    this.empleadoId,
    this.estado = EstadoReserva.pendiente,
    required this.fechaHora,
    required this.duracion,
    required this.precio,
    this.notas,
    this.notasInternas,
    required this.fechaCreacion,
    this.fechaModificacion,
    this.creadoPor,
  });

  factory Reserva.fromFirestore(Map<String, dynamic> datos, String id) {
    return Reserva(
      id: id,
      clienteId: datos['cliente_id'] ?? '',
      servicioId: datos['servicio_id'] ?? '',
      empleadoId: datos['empleado_id'],
      estado: EstadoReserva.values.firstWhere(
      fechaHora: _parseDate(datos['fecha_hora']),
        orElse: () => EstadoReserva.pendiente,
      ),
      fechaHora: DateTime.parse(datos['fecha_hora']),
      duracion: Duration(minutes: datos['duracion_minutos'] ?? 60),
      fechaCreacion: _parseDate(datos['fecha_creacion']),
      notas: datos['notas'],
          ? _parseDate(datos['fecha_modificacion'])
      fechaCreacion: DateTime.parse(datos['fecha_creacion']),
      fechaModificacion: datos['fecha_modificacion'] != null
          ? DateTime.parse(datos['fecha_modificacion'])
          : null,
      creadoPor: datos['creado_por'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cliente_id': clienteId,
      'servicio_id': servicioId,
      'empleado_id': empleadoId,
      'estado': estado.toString().split('.').last,
      'fecha_hora': fechaHora.toIso8601String(),
      'duracion_minutos': duracion.inMinutes,
      'precio': precio,
      'notas': notas,
      'notas_internas': notasInternas,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_modificacion': fechaModificacion?.toIso8601String(),
      'creado_por': creadoPor,
    };
  }

  DateTime get fechaFin => fechaHora.add(duracion);

  bool get estaPendiente => estado == EstadoReserva.pendiente;
  bool get estaConfirmada => estado == EstadoReserva.confirmada;
  bool get estaCompletada => estado == EstadoReserva.completada;
  bool get estaCancelada => estado == EstadoReserva.cancelada;

  bool get esHoy {
    final ahora = DateTime.now();
    final fecha = fechaHora;
    return ahora.year == fecha.year &&
        ahora.month == fecha.month &&
        ahora.day == fecha.day;
  }

  bool get esPasada => fechaHora.isBefore(DateTime.now());
  bool get esFutura => fechaHora.isAfter(DateTime.now());

  String get horaFormateada {
    return '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}';
  }

  bool puedeSerCancelada() {
    return (estado == EstadoReserva.pendiente || estado == EstadoReserva.confirmada) &&
        fechaHora.isAfter(DateTime.now());
  }

  bool puedeSerConfirmada() {
    return estado == EstadoReserva.pendiente &&
        fechaHora.isAfter(DateTime.now());
  }

  bool puedeSerCompletada() {
    return estado == EstadoReserva.confirmada &&
        fechaHora.isBefore(DateTime.now().add(const Duration(hours: 1)));
  }

  Reserva copyWith({
    String? clienteId,
    String? servicioId,
    String? empleadoId,
    EstadoReserva? estado,
    DateTime? fechaHora,
    Duration? duracion,
    double? precio,
    String? notas,
    String? notasInternas,
    DateTime? fechaModificacion,
  }) {
    return Reserva(
      id: id,
      clienteId: clienteId ?? this.clienteId,
      servicioId: servicioId ?? this.servicioId,
      empleadoId: empleadoId ?? this.empleadoId,
      estado: estado ?? this.estado,
      fechaHora: fechaHora ?? this.fechaHora,
      duracion: duracion ?? this.duracion,
      precio: precio ?? this.precio,
      notas: notas ?? this.notas,
      notasInternas: notasInternas ?? this.notasInternas,
      fechaCreacion: fechaCreacion,
      fechaModificacion: fechaModificacion ?? DateTime.now(),
      creadoPor: creadoPor,
    );
  }

  @override
  List<Object?> get props => [
        id,
        clienteId,
        servicioId,
        empleadoId,
        estado,
        fechaHora,
        duracion,
        precio,
        notas,
        notasInternas,
       ];
        fechaModificacion,
        creadoPor,
DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}

      ];
