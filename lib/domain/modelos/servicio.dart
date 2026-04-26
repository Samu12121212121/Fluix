import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Servicio extends Equatable {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final Duration duracion;
  final String? empleadoAsignado;
  final String? categoria;
  final bool activo;
  final List<String> imagenes;
  final Map<String, dynamic> configuracionAdicional;
  final DateTime fechaCreacion;
  final DateTime? fechaModificacion;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    required this.duracion,
    this.empleadoAsignado,
    this.categoria,
    this.activo = true,
    this.imagenes = const [],
    this.configuracionAdicional = const {},
    required this.fechaCreacion,
    this.fechaModificacion,
  });

  factory Servicio.fromFirestore(Map<String, dynamic> datos, String id) {
    return Servicio(
      id: id,
      nombre: datos['nombre'] ?? '',
      descripcion: datos['descripcion'] ?? '',
      precio: (datos['precio'] ?? 0.0).toDouble(),
      duracion: Duration(minutes: datos['duracion_minutos'] ?? 60),
      empleadoAsignado: datos['empleado_asignado'],
      categoria: datos['categoria'],
      activo: datos['activo'] ?? true,
      imagenes: List<String>.from(datos['imagenes'] ?? []),
      configuracionAdicional: Map<String, dynamic>.from(
        datos['configuracion_adicional'] ?? {},
      ),
      fechaCreacion: _parseDate(datos['fecha_creacion']),
      fechaModificacion: datos['fecha_modificacion'] != null
          ? _parseDate(datos['fecha_modificacion'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'duracion_minutos': duracion.inMinutes,
      'empleado_asignado': empleadoAsignado,
      'categoria': categoria,
      'activo': activo,
      'imagenes': imagenes,
      'configuracion_adicional': configuracionAdicional,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_modificacion': fechaModificacion?.toIso8601String(),
    };
  }

  String get duracionFormateada {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;

    if (horas > 0) {
      return minutos > 0 ? '${horas}h ${minutos}min' : '${horas}h';
    }
    return '${minutos}min';
  }

  String get precioFormateado {
    return '\$${precio.toStringAsFixed(precio.truncateToDouble() == precio ? 0 : 2)}';
  }

  bool get tieneImagenes => imagenes.isNotEmpty;
  String? get imagenPrincipal => imagenes.isNotEmpty ? imagenes.first : null;

  Servicio copyWith({
    String? nombre,
    String? descripcion,
    double? precio,
    Duration? duracion,
    String? empleadoAsignado,
    String? categoria,
    bool? activo,
    List<String>? imagenes,
    Map<String, dynamic>? configuracionAdicional,
    DateTime? fechaModificacion,
  }) {
    return Servicio(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      duracion: duracion ?? this.duracion,
      empleadoAsignado: empleadoAsignado ?? this.empleadoAsignado,
      categoria: categoria ?? this.categoria,
      activo: activo ?? this.activo,
      imagenes: imagenes ?? this.imagenes,
      configuracionAdicional: configuracionAdicional ?? this.configuracionAdicional,
      fechaCreacion: fechaCreacion,
      fechaModificacion: fechaModificacion ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    nombre,
    descripcion,
    precio,
    duracion,
    empleadoAsignado,
    categoria,
    activo,
    imagenes,
    configuracionAdicional,
    fechaCreacion,
    fechaModificacion,
  ];

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}