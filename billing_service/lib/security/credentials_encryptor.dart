// lib/security/credentials_encryptor.dart
// Cifrado AES-256-GCM para credenciales de pago de tenants.
// La MASTER_KEY vive únicamente en variable de entorno del servidor.

import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class CredentialsEncryptor {
  final Uint8List _masterKey; // 32 bytes desde variable de entorno MASTER_KEY

  CredentialsEncryptor({required String masterKeyBase64})
      : _masterKey = base64.decode(masterKeyBase64) {
    if (_masterKey.length != 32) {
      throw ArgumentError(
        'MASTER_KEY debe ser exactamente 32 bytes (256 bits) en Base64. '
        'Recibido: ${_masterKey.length} bytes. '
        'Genera una con: openssl rand -base64 32',
      );
    }
  }

  /// Cifra un mapa de credenciales → string Base64 listo para guardar en BD.
  String encrypt(Map<String, String> credentials) {
    final plaintext = utf8.encode(jsonEncode(credentials));

    // Generar IV aleatorio de 12 bytes (recomendado para AES-GCM)
    final iv = _generateRandomBytes(12);

    // AES-256-GCM con tag de 128 bits
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true, // encrypt
      AEADParameters(KeyParameter(_masterKey), 128, iv, Uint8List(0)),
    );

    final ciphertext = Uint8List(cipher.getOutputSize(plaintext.length));
    var offset = 0;
    offset += cipher.processBytes(
      plaintext, 0, plaintext.length, ciphertext, offset,
    );
    cipher.doFinal(ciphertext, offset);

    // Formato: IV (12 bytes) + ciphertext+tag
    final result = Uint8List(12 + ciphertext.length);
    result.setRange(0, 12, iv);
    result.setRange(12, result.length, ciphertext);

    return base64.encode(result);
  }

  /// Descifra → devuelve el mapa de credenciales original.
  /// Lanza si la clave es incorrecta o los datos están corruptos.
  Map<String, String> decrypt(String encryptedBase64) {
    final data       = base64.decode(encryptedBase64);
    if (data.length < 13) {
      throw StateError('Datos cifrados demasiado cortos — posible corrupción');
    }

    final iv         = Uint8List.fromList(data.sublist(0, 12));
    final ciphertext = Uint8List.fromList(data.sublist(12));

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false, // decrypt
      AEADParameters(KeyParameter(_masterKey), 128, iv, Uint8List(0)),
    );

    final plaintext = Uint8List(cipher.getOutputSize(ciphertext.length));
    var offset = 0;
    offset += cipher.processBytes(
      ciphertext, 0, ciphertext.length, plaintext, offset,
    );
    cipher.doFinal(plaintext, offset);

    // Eliminar padding nulo al final
    var end = plaintext.length;
    while (end > 0 && plaintext[end - 1] == 0) {
      end--;
    }

    return Map<String, String>.from(
      jsonDecode(utf8.decode(plaintext.sublist(0, end))) as Map,
    );
  }

  Uint8List _generateRandomBytes(int length) {
    final random = FortunaRandom();
    // Sembrar con microsegundos del sistema (suficiente para IVs, no para claves)
    final seedSource = Uint8List(32);
    final now = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < 32; i++) {
      seedSource[i] = ((now >> (i % 8 * 8)) ^ (now >> (i * 3))) & 0xFF;
    }
    random.seed(KeyParameter(seedSource));
    return random.nextBytes(length);
  }
}

