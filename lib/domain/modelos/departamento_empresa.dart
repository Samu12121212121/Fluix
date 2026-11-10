import 'package:cloud_firestore/cloud_firestore.dart';

/// Departamento o unidad organizativa de una empresa.
/// Se almacena en empresas/{id}/departamentos/{deptId}.
/// Soporta jerarquía mediante [padreId].
class DepartamentoEmpresa {
  final String id;
  final String nombre;
  final String? descripcion;
  /// UID del jefe/responsable de este departamento.
  final String? jefeUid;
  /// Nombre del jefe (copia desnormalizada para evitar lecturas extra).
  final String? jefeNombre;
  /// ID del departamento padre (null = departamento raíz).
  final String? padreId;
  final bool activo;
  final DateTime creadoAt;

  const DepartamentoEmpresa({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.jefeUid,
    this.jefeNombre,
    this.padreId,
    this.activo = true,
    required this.creadoAt,
  });

  factory DepartamentoEmpresa.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DepartamentoEmpresa(
      id:          doc.id,
      nombre:      d['nombre']       as String? ?? '',
      descripcion: d['descripcion']  as String?,
      jefeUid:     d['jefe_uid']     as String?,
      jefeNombre:  d['jefe_nombre']  as String?,
      padreId:     d['padre_id']     as String?,
      activo:      d['activo']       as bool?   ?? true,
      creadoAt:    (d['creado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre':      nombre,
    'descripcion': descripcion,
    'jefe_uid':    jefeUid,
    'jefe_nombre': jefeNombre,
    'padre_id':    padreId,
    'activo':      activo,
    'creado_at':   FieldValue.serverTimestamp(),
  };

  DepartamentoEmpresa copyWith({
    String? nombre, String? descripcion,
    String? jefeUid, String? jefeNombre,
    String? padreId, bool? activo,
  }) => DepartamentoEmpresa(
    id: id, creadoAt: creadoAt,
    nombre:      nombre      ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    jefeUid:     jefeUid     ?? this.jefeUid,
    jefeNombre:  jefeNombre  ?? this.jefeNombre,
    padreId:     padreId     ?? this.padreId,
    activo:      activo      ?? this.activo,
  );
}
