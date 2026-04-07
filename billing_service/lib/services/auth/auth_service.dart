// lib/services/auth/auth_service.dart
// Autenticación y autorización multi-tenant.

import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../database/database.dart';
import '../../models/auth_result.dart';
import '../../models/tenant_business_config.dart';
import '../../repositories/tenant_business_config_repository.dart';
import '../../security/jwt_service.dart';
import '../../security/password_hasher.dart';
import '../logger.dart';

class AuthService {
  final Database                       _db;
  final JwtService                     _jwt;
  final TenantBusinessConfigRepository _configRepo;

  AuthService({
    required Database                       db,
    required JwtService                     jwt,
    required TenantBusinessConfigRepository configRepo,
  })  : _db         = db,
        _jwt        = jwt,
        _configRepo = configRepo;

  // ── REGISTRO: crea tenant + usuario admin + config básica ──────────────

  Future<AuthResult> register({
    required String nombre,
    required String nif,
    required String email,
    required String password,
  }) async {
    // Validaciones básicas
    if (nombre.trim().isEmpty) return AuthResult.error('Nombre de empresa vacío');
    if (nif.trim().isEmpty)    return AuthResult.error('NIF/CIF vacío');
    if (email.trim().isEmpty)  return AuthResult.error('Email vacío');
    if (password.length < 8)   return AuthResult.error('La contraseña debe tener al menos 8 caracteres');

    // Verificar que el NIF y email no están ya registrados
    final existsNif = await _db.queryOne(
      'SELECT id FROM tenants WHERE nif = @nif',
      {'nif': nif},
    );
    if (existsNif != null) {
      return AuthResult.error('Ya existe una empresa con este NIF');
    }

    final existsEmail = await _db.queryOne(
      'SELECT id FROM tenants WHERE email_admin = @email',
      {'email': email},
    );
    if (existsEmail != null) {
      return AuthResult.error('Ya existe una cuenta con este email');
    }

    return _db.transaction((tx) async {
      // 1. Crear tenant
      final tenantRow = await tx.queryOne('''
        INSERT INTO tenants (nombre, nif, email_admin)
        VALUES (@nombre, @nif, @email)
        RETURNING id
      ''', {'nombre': nombre, 'nif': nif, 'email': email});

      final tenantId = tenantRow!['id'] as String;

      // 2. Crear usuario admin
      final passwordHash = PasswordHasher.hash(password);
      await tx.execute('''
        INSERT INTO tenant_users (tenant_id, email, password_hash, role)
        VALUES (@tenantId, @email, @hash, 'admin')
      ''', {'tenantId': tenantId, 'email': email, 'hash': passwordHash});

      // 3. Crear config fiscal básica (se completará en onboarding)
      await _configRepo.upsert(TenantBusinessConfig(
        tenantId:        tenantId,
        emisorNif:       nif,
        emisorNombre:    nombre,
        emisorDireccion: '',
      ));

      // 4. Crear series de facturación por defecto
      final year = DateTime.now().year;
      for (final serie in ['F-$year', 'FS-$year', 'R-$year']) {
        await tx.execute('''
          INSERT INTO invoice_series_counters (tenant_id, serie, last_number)
          VALUES (@tid, @serie, 0)
          ON CONFLICT DO NOTHING
        ''', {'tid': tenantId, 'serie': serie});
      }

      // 5. Generar JWT
      final token = _jwt.generate(
        tenantId: tenantId,
        email:    email,
        role:     'admin',
      );

      logger.info('[Auth] Nueva empresa registrada: $nombre ($nif) — tenant=$tenantId');
      return AuthResult.success(token: token, tenantId: tenantId);
    });
  }

  // ── LOGIN: devuelve JWT con tenantId embebido ──────────────────────────

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final row = await _db.queryOne('''
      SELECT u.id, u.tenant_id, u.password_hash, u.role, u.activo,
             t.activo as tenant_activo
      FROM   tenant_users u
      JOIN   tenants t ON t.id = u.tenant_id
      WHERE  u.email = @email
    ''', {'email': email});

    if (row == null) {
      return AuthResult.error('Credenciales incorrectas');
    }
    if (!(row['activo'] as bool)) {
      return AuthResult.error('Usuario desactivado');
    }
    if (!(row['tenant_activo'] as bool)) {
      return AuthResult.error('Cuenta de empresa suspendida');
    }
    if (!PasswordHasher.verify(password, row['password_hash'] as String)) {
      return AuthResult.error('Credenciales incorrectas');
    }

    final token = _jwt.generate(
      tenantId: row['tenant_id'] as String,
      email:    email,
      role:     row['role'] as String,
    );

    logger.info('[Auth] Login exitoso: $email — tenant=${row['tenant_id']}');
    return AuthResult.success(
      token:    token,
      tenantId: row['tenant_id'] as String,
    );
  }

  // ── Middleware: extraer tenantId del JWT ────────────────────────────────

  /// Extrae el tenant_id del header Authorization: Bearer <token>.
  /// Lanza [UnauthorizedException] si el token es inválido o expirado.
  String extractTenantId(Request req) {
    final auth = req.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) {
      throw const UnauthorizedException('Token de autenticación requerido');
    }
    final token  = auth.substring(7);
    final claims = _jwt.verify(token);
    return claims.tenantId;
  }

  /// Extrae el payload completo del JWT.
  JwtPayload extractClaims(Request req) {
    final auth = req.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) {
      throw const UnauthorizedException('Token de autenticación requerido');
    }
    return _jwt.verify(auth.substring(7));
  }

  /// Verifica que el request tiene el SUPERADMIN_KEY correcto.
  bool isSuperAdmin(Request req, String superadminKey) {
    final key = req.headers['x-superadmin-key'] ?? '';
    return key == superadminKey && superadminKey.isNotEmpty;
  }
}

