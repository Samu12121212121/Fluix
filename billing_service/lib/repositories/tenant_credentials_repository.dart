// lib/repositories/tenant_credentials_repository.dart
// Gestiona credenciales cifradas de pago por tenant.

import '../database/database.dart';
import '../security/credentials_encryptor.dart';

class TenantCredentialsRepository {
  final Database             _db;
  final CredentialsEncryptor _encryptor;

  TenantCredentialsRepository(this._db, this._encryptor);

  /// Guardar credenciales cifradas para un tenant y proveedor.
  /// Usa UPSERT: si ya existen, las actualiza.
  Future<void> save({
    required String tenantId,
    required String provider,
    required Map<String, String> credentials,
  }) async {
    final encrypted = _encryptor.encrypt(credentials);
    await _db.execute('''
      INSERT INTO tenant_payment_credentials
        (tenant_id, provider, credentials, activo, created_at, updated_at)
      VALUES
        (@tenantId, @provider, @creds, TRUE, NOW(), NOW())
      ON CONFLICT (tenant_id, provider)
      DO UPDATE SET credentials = @creds, activo = TRUE, updated_at = NOW()
    ''', {
      'tenantId': tenantId,
      'provider': provider,
      'creds':    encrypted,
    });
  }

  /// Obtener credenciales descifradas (solo en memoria, nunca loguear).
  Future<Map<String, String>?> get({
    required String tenantId,
    required String provider,
  }) async {
    final row = await _db.queryOne('''
      SELECT credentials FROM tenant_payment_credentials
      WHERE  tenant_id = @tenantId
        AND  provider  = @provider
        AND  activo    = TRUE
    ''', {'tenantId': tenantId, 'provider': provider});

    if (row == null) return null;
    return _encryptor.decrypt(row['credentials'] as String);
  }

  /// Listar proveedores configurados para un tenant (sin credenciales).
  Future<List<Map<String, dynamic>>> listProviders(String tenantId) async {
    return _db.queryMany('''
      SELECT provider, activo, created_at, updated_at
      FROM   tenant_payment_credentials
      WHERE  tenant_id = @tenantId
      ORDER BY provider
    ''', {'tenantId': tenantId});
  }

  /// Desactivar credenciales de un proveedor para un tenant.
  Future<void> deactivate({
    required String tenantId,
    required String provider,
  }) async {
    await _db.execute('''
      UPDATE tenant_payment_credentials
      SET    activo = FALSE, updated_at = NOW()
      WHERE  tenant_id = @tenantId AND provider = @provider
    ''', {'tenantId': tenantId, 'provider': provider});
  }
}

