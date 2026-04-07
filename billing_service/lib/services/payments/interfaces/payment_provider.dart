// lib/services/payments/interfaces/payment_provider.dart

import 'payment_event.dart';

abstract class PaymentProvider {
  String get providerId;
  String get displayName;
  bool   get supportsWebhook;
  bool   get requiresPolling;

  Future<bool> validateSignature(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  );

  Future<PaymentEvent?> processEvent(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  );

  Future<List<PaymentEvent>> pollNewPayments({required String lastProcessedId});
}

