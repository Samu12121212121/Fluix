// lib/security/jwt_service.dart
// Servicio JWT para autenticación de usuarios multi-tenant.
// Implementación manual con HMAC-SHA256 (sin dependencias externas).

import 'dart:convert';
import 'package:crypto/crypto.dart';

class JwtPayload {
  final String tenantId;
  final String email;
  final String role;
  final DateTime expiresAt;

  const JwtPayload({
    required this.tenantId,
    required this.email,
    required this.role,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class JwtService {
  final String _secret;

  JwtService({required String secret}) : _secret = secret {
    if (secret.length < 32) {
      throw ArgumentError(
        'JWT_SECRET debe tener al menos 32 caracteres. Recibido: ${secret.length}',
      );
    }
  }

  /// Genera un JWT con tenant_id, email y role embebidos.
  /// Expira en [expiry] (por defecto 7 días).
  String generate({
    required String tenantId,
    required String email,
    required String role,
    Duration expiry = const Duration(days: 7),
  }) {
    final header = _base64UrlEncode(jsonEncode({
      'alg': 'HS256',
      'typ': 'JWT',
    }));

    final now = DateTime.now();
    final exp = now.add(expiry);

    final payload = _base64UrlEncode(jsonEncode({
      'tenant_id': tenantId,
      'email':     email,
      'role':      role,
      'iat':       now.millisecondsSinceEpoch ~/ 1000,
      'exp':       exp.millisecondsSinceEpoch ~/ 1000,
    }));

    final signature = _sign('$header.$payload');

    return '$header.$payload.$signature';
  }

  /// Verifica y decodifica un JWT. Lanza [JwtException] si es inválido.
  JwtPayload verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const JwtException('Token JWT malformado');
    }

    final header    = parts[0];
    final payload   = parts[1];
    final signature = parts[2];

    // Verificar firma
    final expectedSig = _sign('$header.$payload');
    if (!_constantTimeEquals(signature, expectedSig)) {
      throw const JwtException('Firma JWT inválida');
    }

    // Decodificar payload
    final payloadJson = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    ) as Map<String, dynamic>;

    // Verificar expiración
    final exp = payloadJson['exp'] as int?;
    if (exp == null) throw const JwtException('JWT sin fecha de expiración');

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (DateTime.now().isAfter(expiresAt)) {
      throw const JwtException('JWT expirado');
    }

    return JwtPayload(
      tenantId:  payloadJson['tenant_id'] as String? ?? '',
      email:     payloadJson['email'] as String? ?? '',
      role:      payloadJson['role'] as String? ?? 'employee',
      expiresAt: expiresAt,
    );
  }

  String _sign(String input) {
    final hmac   = Hmac(sha256, utf8.encode(_secret));
    final digest = hmac.convert(utf8.encode(input));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _base64UrlEncode(String input) =>
      base64Url.encode(utf8.encode(input)).replaceAll('=', '');

  /// Comparación en tiempo constante para evitar timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

class JwtException implements Exception {
  final String message;
  const JwtException(this.message);
  @override
  String toString() => 'JwtException: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'No autorizado']);
  @override
  String toString() => 'UnauthorizedException: $message';
}

