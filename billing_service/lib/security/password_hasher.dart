// lib/security/password_hasher.dart
// Hash de contraseñas usando HMAC-SHA256 con salt aleatorio.
// Para producción real se recomienda bcrypt/argon2, pero esto es
// una implementación segura sin dependencias externas adicionales.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const _iterations = 100000;
  static const _saltLength = 32;

  /// Genera un hash seguro de la contraseña con salt aleatorio.
  /// Formato de salida: `$iterations$salt_base64$hash_base64`
  static String hash(String password) {
    final salt = _generateSalt();
    final hash = _pbkdf2(password, salt, _iterations);
    return '$_iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
  }

  /// Verifica que la contraseña coincide con el hash almacenado.
  static bool verify(String password, String storedHash) {
    final parts = storedHash.split('\$');
    if (parts.length != 3) return false;

    final iterations = int.tryParse(parts[0]) ?? _iterations;
    final salt       = base64.decode(parts[1]);
    final expected   = base64.decode(parts[2]);

    final actual = _pbkdf2(password, salt, iterations);

    // Comparación en tiempo constante
    if (actual.length != expected.length) return false;
    var result = 0;
    for (var i = 0; i < actual.length; i++) {
      result |= actual[i] ^ expected[i];
    }
    return result == 0;
  }

  /// PBKDF2 con HMAC-SHA256.
  static List<int> _pbkdf2(String password, List<int> salt, int iterations) {
    final passwordBytes = utf8.encode(password);
    var block = [...salt, 0, 0, 0, 1]; // block index = 1

    final hmacKey = Hmac(sha256, passwordBytes);
    var u = hmacKey.convert(block).bytes;
    var result = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmacKey.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result;
  }

  static List<int> _generateSalt() {
    final random = Random.secure();
    return List.generate(_saltLength, (_) => random.nextInt(256));
  }
}

