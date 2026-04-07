// lib/services/payments/providers/stripe/stripe_webhook_validator.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class StripeWebhookValidator {
  static bool verify({
    required String rawBody,
    required String signature,
    required String secret,
    required Duration tolerance,
  }) {
    try {
      final parts     = signature.split(',');
      String? timestamp;
      String? v1Hash;
      for (final p in parts) {
        if (p.startsWith('t='))  timestamp = p.substring(2);
        if (p.startsWith('v1=')) v1Hash    = p.substring(3);
      }
      if (timestamp == null || v1Hash == null) return false;

      final eventTime = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp) * 1000,
      );
      if (DateTime.now().difference(eventTime).abs() > tolerance) return false;

      final message  = '$timestamp.$rawBody';
      final hmac     = Hmac(sha256, utf8.encode(secret));
      final computed = hmac.convert(utf8.encode(message)).toString();

      return _constantTimeEquals(computed, v1Hash);
    } catch (_) {
      return false;
    }
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

