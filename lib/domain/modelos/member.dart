import 'package:cloud_firestore/cloud_firestore.dart';

/// Miembro de una empresa — subcolección empresas/{id}/members/{userId}
///
/// Facilita listado directo de empleados de una empresa,
/// revocación de acceso sin borrar usuario, y auditoría de invitaciones.
class Member {
  final String userId;            // = document ID = UID
  final String rol;               // 'propietario', 'admin', 'staff', 'empleado'
  final List<String> modulosPermitidos;
  final bool activo;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final String? invitedBy;        // UID de quién invitó

  const Member({
    required this.userId,
    required this.rol,
    this.modulosPermitidos = const [],
    this.activo = true,
    this.invitedAt,
    this.joinedAt,
    this.invitedBy,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Member(
      userId: doc.id,
      rol: d['rol'] as String? ?? 'empleado',
      modulosPermitidos: List<String>.from(d['modulos_permitidos'] ?? []),
      activo: d['activo'] as bool? ?? true,
      invitedAt: _parseTs(d['invited_at']),
      joinedAt: _parseTs(d['joined_at']),
      invitedBy: d['invited_by'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'rol': rol,
    'modulos_permitidos': modulosPermitidos,
    'activo': activo,
    'invited_at': invitedAt != null ? Timestamp.fromDate(invitedAt!) : null,
    'joined_at': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
    'invited_by': invitedBy,
  };

  Member copyWith({
    String? rol,
    List<String>? modulosPermitidos,
    bool? activo,
  }) {
    return Member(
      userId: userId,
      rol: rol ?? this.rol,
      modulosPermitidos: modulosPermitidos ?? this.modulosPermitidos,
      activo: activo ?? this.activo,
      invitedAt: invitedAt,
      joinedAt: joinedAt,
      invitedBy: invitedBy,
    );
  }
}

DateTime? _parseTs(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

