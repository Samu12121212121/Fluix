import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/enums/enums.dart';

class Usuario {
  final String id;
  final String nombre;
  final String correo;
  final String telefono;
  final String? empresaId;
  final RolUsuario rol;
  final bool activo;
  final DateTime fechaCreacion;
  final List<String> permisos;
  final String? tokenDispositivo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    this.empresaId,
    required this.rol,
    this.activo = true,
    required this.fechaCreacion,
    this.permisos = const [],
    this.tokenDispositivo,
  });

  // Factory para crear desde Firestore
  factory Usuario.fromFirestore(Map<String, dynamic> datos, String id) {
    return Usuario(
      id: id,
      nombre: datos['nombre'] ?? '',
      correo: datos['correo'] ?? '',
      telefono: datos['telefono'] ?? '',
      empresaId: datos['empresa_id'],
      rol: RolUsuario.values.firstWhere(
        (r) => r.toString().split('.').last == datos['rol'],
        orElse: () => RolUsuario.staff,
      ),
      activo: datos['activo'] ?? true,
      fechaCreacion: _parseDate(datos['fecha_creacion']),
      permisos: List<String>.from(datos['permisos'] ?? []),
      tokenDispositivo: datos['token_dispositivo'],
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'empresa_id': empresaId,
      'rol': rol.toString().split('.').last,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'permisos': permisos,
      'token_dispositivo': tokenDispositivo,
    };
  }

  // Métodos de conveniencia para verificar permisos
  bool get esPropietario => rol == RolUsuario.propietario;
  bool get esAdmin => rol == RolUsuario.admin;
  bool get esStaff => rol == RolUsuario.staff;
  bool get puedeGestionarEmpleados => esPropietario || esAdmin;
  bool get puedeVerFinanzas => esPropietario || esAdmin;
  bool get puedeModificarConfiguracion => esPropietario;

  Usuario copyWith({
    String? nombre,
    String? correo,
    String? telefono,
    String? empresaId,
    RolUsuario? rol,
    bool? activo,
    List<String>? permisos,
    String? tokenDispositivo,
  }) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      empresaId: empresaId ?? this.empresaId,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion,
      permisos: permisos ?? this.permisos,
      tokenDispositivo: tokenDispositivo ?? this.tokenDispositivo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Usuario && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}


DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
