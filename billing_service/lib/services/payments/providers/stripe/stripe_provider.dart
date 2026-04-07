// lib/services/payments/providers/stripe/stripe_provider.dart

import '../../interfaces/payment_event.dart';
import '../../interfaces/payment_provider.dart';
import 'stripe_webhook_validator.dart';
import 'stripe_event_mapper.dart';

class StripeProvider implements PaymentProvider {
  final String             _webhookSecret;
  final StripeEventMapper  _mapper;

  StripeProvider({required String webhookSecret})
      : _webhookSecret = webhookSecret,
        _mapper        = StripeEventMapper();

  @override String get providerId      => 'stripe';
  @override String get displayName     => 'Stripe';
  @override bool   get supportsWebhook => true;
  @override bool   get requiresPolling => false;

  @override
  Future<bool> validateSignature(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  ) async {
    final sig = headers['stripe-signature'];
    final raw = headers['_raw_body'];
    if (sig == null || raw == null) return false;
    return StripeWebhookValidator.verify(
      rawBody:   raw,
      signature: sig,
      secret:    _webhookSecret,
      tolerance: const Duration(minutes: 5),
    );
  }

  @override
  Future<PaymentEvent?> processEvent(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  ) async => _mapper.map(payload['type'] as String?, payload);

  @override
  Future<List<PaymentEvent>> pollNewPayments({
    required String lastProcessedId,
  }) => throw UnsupportedError('Stripe usa webhooks, no polling');
}

