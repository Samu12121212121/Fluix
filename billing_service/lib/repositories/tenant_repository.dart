// lib/repositories/tenant_repository.dart

import '../database/database.dart';
import '../models/tenant.dart';

class TenantRepository {
  final Database _db;

  TenantRepository(this._db);

  Future<Tenant?> get(String tenantId) async {
    final row = await _db.queryOne(
      'SELECT * FROM tenants WHERE id = @id',
      {'id': tenantId},
    );
    return row != null ? Tenant.fromRow(row) : null;
  }

  Future<Tenant?> findByNif(String nif) async {
    final row = await _db.queryOne(
      'SELECT * FROM tenants WHERE nif = @nif',
      {'nif': nif},
    );
    return row != null ? Tenant.fromRow(row) : null;
  }

  Future<Tenant?> findByEmail(String email) async {
    final row = await _db.queryOne(
      'SELECT * FROM tenants WHERE email_admin = @email',
      {'email': email},
    );
    return row != null ? Tenant.fromRow(row) : null;
  }

  Future<List<Tenant>> listAll({bool? activo}) async {
    final where = activo != null ? 'WHERE activo = @activo' : '';
    final rows = await _db.queryMany(
      'SELECT * FROM tenants $where ORDER BY created_at DESC',
      activo != null ? {'activo': activo} : null,
    );
    return rows.map(Tenant.fromRow).toList();
  }

  Future<Tenant> create({
    required String nombre,
    required String nif,
    required String emailAdmin,
    String plan = 'basic',
  }) async {
    final row = await _db.queryOne('''
      INSERT INTO tenants (nombre, nif, email_admin, plan)
      VALUES (@nombre, @nif, @email, @plan)
      RETURNING *
    ''', {
      'nombre': nombre,
      'nif':    nif,
      'email':  emailAdmin,
      'plan':   plan,
    });
    return Tenant.fromRow(row!);
  }

  Future<void> suspend(String tenantId) async {
    await _db.execute(
      'UPDATE tenants SET activo = FALSE, updated_at = NOW() WHERE id = @id',
      {'id': tenantId},
    );
  }

  Future<void> activate(String tenantId) async {
    await _db.execute(
      'UPDATE tenants SET activo = TRUE, updated_at = NOW() WHERE id = @id',
      {'id': tenantId},
    );
  }
}

