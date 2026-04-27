import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Reserva extends Equatable {
  final String id;
  final DateTime fechaCreacion;
  final DateTime fechaHora;
  final DateTime? fechaModificacion;

  // Datos del formulario web
  final int comensales;
  final String clienteNombre;
  final String clienteEmail;
  final String clienteTelefono;
  final String? comentarios;
  final String servicio; // 'almuerzo', 'cena', etc.

  // Campos opcionales adicionales
  final String? estado; // 'pendiente', 'confirmada', 'cancelada'
  final String? mesa;
  final String? origen; // 'web', 'manual', 'telefono'

  // Campos de cancelación
  final String? motivoCancelacion;
  final DateTime? fechaCancelacion;

  const Reserva({
    required this.id,
    required this.fechaCreacion,
    required this.fechaHora,
    this.fechaModificacion,
    required this.comensales,
    required this.clienteNombre,
    required this.clienteEmail,
    required this.clienteTelefono,
    this.comentarios,
    this.servicio = 'almuerzo',
    this.estado = 'pendiente',
    this.mesa,
    this.origen = 'web',
    this.motivoCancelacion,
    this.fechaCancelacion,
  });

  factory Reserva.fromMap(Map<String, dynamic> datos, String id) {
    return Reserva(
      id: id,
      fechaCreacion: _parseDate(datos['fecha_creacion']),
      fechaHora: _parseDate(datos['fecha_hora']),
      fechaModificacion: datos['fecha_modificacion'] != null
          ? _parseDate(datos['fecha_modificacion'])
          : null,

      // Datos del cliente y reserva
      comensales: datos['comensales'] ?? datos['num_comensales'] ?? 1,
      clienteNombre: datos['cliente_nombre'] ?? datos['nombre'] ?? '',
      clienteEmail: datos['cliente_email'] ?? datos['email'] ?? datos['correo'] ?? '',
      clienteTelefono: datos['cliente_telefono'] ?? datos['telefono'] ?? datos['phone'] ?? '',
      comentarios: datos['comentarios'] ?? datos['notas'],
      servicio: datos['servicio'] ?? 'almuerzo',

      // Campos opcionales
      estado: datos['estado'] ?? 'pendiente',
      mesa: datos['mesa'],
      origen: datos['origen'] ?? 'web',

      // Campos de cancelación
      motivoCancelacion: datos['motivo_cancelacion'] as String?,
      fechaCancelacion: datos['fecha_cancelacion'] != null
          ? _parseDate(datos['fecha_cancelacion'])
          : null,
    );
  }

  /// Método auxiliar para parsear fechas de forma segura
  static DateTime _parseDate(dynamic fecha) {
    if (fecha == null) return DateTime.now();

    if (fecha is Timestamp) {
      return fecha.toDate();
    }

    if (fecha is String) {
      return DateTime.parse(fecha);
    }

    if (fecha is DateTime) {
      return fecha;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_hora': fechaHora.toIso8601String(),
      'fecha_modificacion': fechaModificacion?.toIso8601String(),

      // Datos del cliente
      'comensales': comensales,
      'cliente_nombre': clienteNombre,
      'cliente_email': clienteEmail,
      'cliente_telefono': clienteTelefono,
      'comentarios': comentarios,
      'servicio': servicio,

      // Campos opcionales
      'estado': estado,
      'mesa': mesa,
      'origen': origen,

      // Campos de cancelación
      if (motivoCancelacion != null) 'motivo_cancelacion': motivoCancelacion,
      if (fechaCancelacion != null)
        'fecha_cancelacion': Timestamp.fromDate(fechaCancelacion!),
    };
  }

  /// Copia con modificaciones
  Reserva copyWith({
    String? id,
    DateTime? fechaCreacion,
    DateTime? fechaHora,
    DateTime? fechaModificacion,
    int? comensales,
    String? clienteNombre,
    String? clienteEmail,
    String? clienteTelefono,
    String? comentarios,
    String? servicio,
    String? estado,
    String? mesa,
    String? origen,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
  }) {
    return Reserva(
      id: id ?? this.id,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaHora: fechaHora ?? this.fechaHora,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      comensales: comensales ?? this.comensales,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      comentarios: comentarios ?? this.comentarios,
      servicio: servicio ?? this.servicio,
      estado: estado ?? this.estado,
      mesa: mesa ?? this.mesa,
      origen: origen ?? this.origen,
      motivoCancelacion: motivoCancelacion ?? this.motivoCancelacion,
      fechaCancelacion: fechaCancelacion ?? this.fechaCancelacion,
    );
  }

  /// Obtener hora formateada
  String get horaFormateada {
    final hora = fechaHora.hour.toString().padLeft(2, '0');
    final minuto = fechaHora.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  /// Obtener fecha formateada
  String get fechaFormateada {
    final dia = fechaHora.day.toString().padLeft(2, '0');
    final mes = fechaHora.month.toString().padLeft(2, '0');
    final anio = fechaHora.year;
    return '$dia/$mes/$anio';
  }

  /// Texto de comensales
  String get comensalesTexto {
    if (comensales == 1) return '1 persona';
    if (comensales >= 7) return '7+ personas';
    return '$comensales personas';
  }

  @override
  List<Object?> get props => [
    id,
    fechaCreacion,
    fechaHora,
    fechaModificacion,
    comensales,
    clienteNombre,
    clienteEmail,
    clienteTelefono,
    comentarios,
    servicio,
    estado,
    mesa,
    origen,
    motivoCancelacion,
    fechaCancelacion,
  ];
}