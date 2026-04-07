// lib/models/tenant.dart

class Tenant {
  final String   id;
  final String   nombre;
  final String   nif;
  final String   emailAdmin;
  final String   plan;      // 'basic' | 'pro' | 'enterprise'
  final bool     activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tenant({
    required this.id,
    required this.nombre,
    required this.nif,
    required this.emailAdmin,
    this.plan    = 'basic',
    this.activo  = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tenant.fromRow(Map<String, dynamic> row) => Tenant(
    id:         row['id'] as String,
    nombre:     row['nombre'] as String,
    nif:        row['nif'] as String,
    emailAdmin: row['email_admin'] as String,
    plan:       row['plan'] as String? ?? 'basic',
    activo:     row['activo'] as bool? ?? true,
    createdAt:  DateTime.parse(row['created_at'].toString()),
    updatedAt:  DateTime.parse(row['updated_at'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'nombre':      nombre,
    'nif':         nif,
    'email_admin': emailAdmin,
    'plan':        plan,
    'activo':      activo,
    'created_at':  createdAt.toIso8601String(),
    'updated_at':  updatedAt.toIso8601String(),
  };
}

