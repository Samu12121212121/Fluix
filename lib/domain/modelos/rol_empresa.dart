import 'package:cloud_firestore/cloud_firestore.dart';

/// Mapa de todos los permisos disponibles: clave → etiqueta legible.
const kPermisosDisponibles = <String, String>{
  'ver_fichajes_equipo':    'Ver fichajes del equipo',
  'editar_fichajes_equipo': 'Editar fichajes del equipo',
  'aprobar_vacaciones':     'Aprobar vacaciones',
  'ver_nominas_equipo':     'Ver nóminas del equipo',
  'ver_nominas_propias':    'Ver nóminas propias',
  'gestionar_empleados':    'Gestionar empleados del departamento',
  'ver_informes':           'Ver informes de actividad',
  'exportar_datos':         'Exportar datos',
  'crear_fichajes':         'Crear/corregir fichajes',
};

/// Icono sugerido por nivel (solo orientativo para la UI).
const kIconosPorNivel = <int, String>{
  1: 'director', 2: 'manager', 3: 'senior', 4: 'junior',
};

/// Rol personalizado creado por el admin de la empresa.
/// Se almacena en empresas/{id}/roles_empresa/{roleId}.
class RolEmpresa {
  final String id;
  final String nombre;
  final String? descripcion;
  /// 1 = máxima autoridad (director), mayor = menor autoridad (junior).
  final int nivel;
  /// Color hex para la UI, e.g. '#3B82F6'.
  final String color;
  final Map<String, bool> permisos;
  final bool activo;
  final DateTime creadoAt;

  const RolEmpresa({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.nivel,
    this.color = '#3B82F6',
    this.permisos = const {},
    this.activo = true,
    required this.creadoAt,
  });

  factory RolEmpresa.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RolEmpresa(
      id:          doc.id,
      nombre:      d['nombre']      as String? ?? '',
      descripcion: d['descripcion'] as String?,
      nivel:       (d['nivel'] as num?)?.toInt() ?? 4,
      color:       d['color']       as String? ?? '#3B82F6',
      permisos:    Map<String, bool>.from(d['permisos'] as Map? ?? {}),
      activo:      d['activo']      as bool?   ?? true,
      creadoAt:    (d['creado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre':      nombre,
    'descripcion': descripcion,
    'nivel':       nivel,
    'color':       color,
    'permisos':    permisos,
    'activo':      activo,
    'creado_at':   FieldValue.serverTimestamp(),
  };

  bool tienePermiso(String permiso) => permisos[permiso] == true;

  RolEmpresa copyWith({
    String? nombre, String? descripcion, int? nivel,
    String? color, Map<String, bool>? permisos, bool? activo,
  }) => RolEmpresa(
    id: id, creadoAt: creadoAt,
    nombre:      nombre      ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    nivel:       nivel       ?? this.nivel,
    color:       color       ?? this.color,
    permisos:    permisos    ?? this.permisos,
    activo:      activo      ?? this.activo,
  );
}
