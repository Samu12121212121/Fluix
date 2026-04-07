// lib/services/payments/providers/redsys/redsys_signature_validator.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class RedsysSignatureValidator {
  /// Verifica la firma HMAC_SHA256_V1 de Redsys.
  ///
  /// Algoritmo oficial:
  ///   1. Decodificar merchantKey desde Base64
  ///   2. Diversificar la clave con el número de pedido vía 3DES-ECB
  ///   3. HMAC-SHA256 sobre Ds_MerchantParameters (string Base64, sin decodificar)
  ///   4. Codificar resultado en Base64URL sin padding
  ///   5. Comparar en tiempo constante
  static bool verify({
    required String merchantParameters,
    required String signature,
    required String merchantKey,
    required String order,
  }) {
    try {
      final keyBytes       = base64.decode(merchantKey);
      final diversifiedKey = _diversifyKey(Uint8List.fromList(keyBytes), order);

      final hmac     = Hmac(sha256, diversifiedKey);
      final digest   = hmac.convert(utf8.encode(merchantParameters));
      final computed = base64Url.encode(digest.bytes).replaceAll('=', '');
      final received = signature.replaceAll('=', '');

      return _constantTimeEquals(computed, received);
    } catch (_) {
      return false;
    }
  }

  /// Diversificación 3DES-ECB: clave derivada específica para cada pedido.
  static Uint8List _diversifyKey(Uint8List key, String order) {
    // Número de pedido: 8 bytes, alineado a la derecha con ceros a la izquierda
    final orderBytes = Uint8List(8);
    final orderUtf8  = utf8.encode(order);
    final copyLen    = orderUtf8.length < 8 ? orderUtf8.length : 8;
    for (var i = 0; i < copyLen; i++) {
      orderBytes[8 - copyLen + i] = orderUtf8[i];
    }

    // Expandir clave a 24 bytes para 3DES (2-key: K1|K2|K1)
    final tripleDesKey = _expandTo24Bytes(key);

    // 3DES-ECB sin padding sobre los 8 bytes del pedido
    final cipher = ECBBlockCipher(DESedeEngine());
    cipher.init(true, KeyParameter(tripleDesKey));

    final output = Uint8List(8);
    cipher.processBlock(orderBytes, 0, output, 0);
    return output;
  }

  static Uint8List _expandTo24Bytes(Uint8List key) {
    if (key.length == 24) return key;
    if (key.length == 16) {
      final expanded = Uint8List(24);
      expanded.setRange(0, 16, key);
      expanded.setRange(16, 24, key.sublist(0, 8));
      return expanded;
    }
    throw ArgumentError(
      'Clave Redsys inválida: ${key.length} bytes. '
      'Debe ser 16 o 24 bytes. '
      'Verifica REDSYS_MERCHANT_KEY en las variables de entorno.',
    );
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

