       ];
import '../../core/enums/enums.dart';

// ignore_for_file: avoid_print

class Reserva {
  final String id;
  final String empresaId;
  final String? clienteId;
  final String nombreCliente;
  final String? telefonoCliente;
  final String? correoCliente;
  final String? servicioId;
  final String? servicioNombre;
  final double? precio;
  final int? duracionMinutos;
  final DateTime fecha;
  final String fechaHora;
  final EstadoReserva estado;
  final String origen; // 'manual' | 'web' | 'web_widget'
  final String? notas;
  final String? profesionalId;
  final String? nombreProfesional;
  final DateTime? fechaCreacion;
  final DateTime? fechaModificacion;

  const Reserva({
    required this.id,
    required this.empresaId,
    this.clienteId,
    required this.nombreCliente,
    this.telefonoCliente,
    this.correoCliente,
    this.servicioId,
    this.servicioNombre,
    this.precio,
    this.duracionMinutos,
    required this.fecha,
    required this.fechaHora,
    required this.estado,
    this.origen = 'manual',
    this.notas,
    this.profesionalId,
    this.nombreProfesional,
    this.fechaCreacion,
    this.fechaModificacion,
  });

  /// Parsea desde un Map de Firestore.
  /// Normaliza el estado a minúsculas para soportar tanto 'PENDIENTE' como 'pendiente'.
  factory Reserva.fromMap(Map<String, dynamic> data, {String id = '', String empresaId = ''}) {
    // Normalizar estado
    final estadoRaw = (data['estado'] ?? 'pendiente').toString().toLowerCase();
    final estado = EstadoReserva.values.firstWhere(
      (e) => e.name == estadoRaw,
      orElse: () => EstadoReserva.pendiente,
    );

    // Nombre del cliente: soporta campos de la app y del widget web
    final nombreCliente = _strFallback([
      data['nombre_cliente'],
      data['nombre_cliente_web'],
      data['cliente'],
    ], 'Sin nombre');

    // Teléfono: soporta campos de la app y del widget web
    final telefonoCliente = _strFallback([
      data['telefono_cliente'],
      data['telefono_cliente_web'],
    ], null);

    // Correo: soporta campos de la app y del widget web
    final correoCliente = _strFallback([
      data['correo_cliente'],
      data['correo_cliente_web'],
    ], null);
import 'package:equatable/equatable.dart';
    // Nombre del servicio: puede venir como 'servicio' o 'servicio_nombre'
    final servicioNombre = _strFallback([
      data['servicio_nombre'],
      data['servicio'],
    ], null);

    // Origen: 'creado_por' como fallback para reservas antiguas del widget web
    final creadoPor = data['creado_por']?.toString() ?? '';
    final origenRaw = data['origen']?.toString() ??
        (creadoPor == 'web_widget' ? 'web' : 'manual');

    return Reserva(
      id: id,
      empresaId: empresaId,
      clienteId: data['cliente_id']?.toString(),
      nombreCliente: nombreCliente,
      telefonoCliente: telefonoCliente,
      correoCliente: correoCliente,
      servicioId: data['servicio_id']?.toString(),
      servicioNombre: servicioNombre,
      precio: (data['precio'] as num?)?.toDouble(),
      duracionMinutos: (data['duracion_minutos'] as num?)?.toInt(),
      fecha: _parseDate(data['fecha']),
      fechaHora: data['fecha_hora']?.toString() ?? '',
      estado: estado,
      origen: origenRaw,
      notas: data['notas']?.toString(),
      profesionalId: data['profesional_id']?.toString(),
      nombreProfesional: data['nombre_profesional']?.toString(),
      fechaCreacion: _parseDateNullable(data['fecha_creacion']),
      fechaModificacion: _parseDateNullable(data['fecha_modificacion']),
    );
  }

  Map<String, dynamic> toMap() => {
    'cliente_id': clienteId,
    'nombre_cliente': nombreCliente,
    if (telefonoCliente != null) 'telefono_cliente': telefonoCliente,
    if (correoCliente != null) 'correo_cliente': correoCliente,
    if (servicioId != null) 'servicio_id': servicioId,
    if (servicioNombre != null) 'servicio': servicioNombre,
    if (precio != null) 'precio': precio,
    if (duracionMinutos != null) 'duracion_minutos': duracionMinutos,
    'fecha': Timestamp.fromDate(fecha),
    'fecha_hora': fechaHora,
    'estado': estado.name.toUpperCase(),
    'origen': origen,
    if (notas != null) 'notas': notas,
    if (profesionalId != null) 'profesional_id': profesionalId,
    if (nombreProfesional != null) 'nombre_profesional': nombreProfesional,
    'fecha_creacion': FieldValue.serverTimestamp(),
  };

  Reserva copyWith({
    String? id,
    String? nombreCliente,
    String? telefonoCliente,
    String? correoCliente,
    EstadoReserva? estado,
    String? notas,
    double? precio,
    DateTime? fecha,
  }) =>
      Reserva(
        id: id ?? this.id,
        empresaId: empresaId,
        clienteId: clienteId,
        nombreCliente: nombreCliente ?? this.nombreCliente,
        telefonoCliente: telefonoCliente ?? this.telefonoCliente,
        correoCliente: correoCliente ?? this.correoCliente,
        servicioId: servicioId,
        servicioNombre: servicioNombre,
        precio: precio ?? this.precio,
        duracionMinutos: duracionMinutos,
        fecha: fecha ?? this.fecha,
        fechaHora: fechaHora,
        estado: estado ?? this.estado,
        origen: origen,
        notas: notas ?? this.notas,
        profesionalId: profesionalId,
        nombreProfesional: nombreProfesional,
        fechaCreacion: fechaCreacion,
        fechaModificacion: fechaModificacion,
      );

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get esDeWeb => origen == 'web' || origen == 'web_widget';

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Devuelve el primer valor no nulo y no vacío de la lista, o el fallback.
  static String _strFallback(List<dynamic> values, String? fallback) {
    for (final v in values) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return fallback ?? '';
  }
}
      fechaHora: DateTime.parse(datos['fecha_hora']),
      fechaHora: _parseDate(datos['fecha_hora']),
import 'package:cloud_firestore/cloud_firestore.dart';

      ];
      ];
          ? DateTime.parse(datos['fecha_modificacion'])
      fechaCreacion: DateTime.parse(datos['fecha_creacion']),
      fechaHora: DateTime.parse(datos['fecha_hora']),

