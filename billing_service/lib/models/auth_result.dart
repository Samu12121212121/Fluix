// lib/models/auth_result.dart

class AuthResult {
  final bool    ok;
  final String? token;
  final String? tenantId;
  final String? errorMessage;

  const AuthResult._({
    required this.ok,
    this.token,
    this.tenantId,
    this.errorMessage,
  });

  factory AuthResult.success({
    required String token,
    required String tenantId,
  }) => AuthResult._(ok: true, token: token, tenantId: tenantId);

  factory AuthResult.error(String message) =>
      AuthResult._(ok: false, errorMessage: message);

  Map<String, dynamic> toJson() => ok
      ? {'ok': true, 'token': token, 'tenant_id': tenantId}
      : {'ok': false, 'error': errorMessage};
}

