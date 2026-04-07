// lib/services/payments/providers/stripe/stripe_event_mapper.dart

import '../../interfaces/payment_event.dart';

class StripeEventMapper {
  PaymentEvent? map(String? eventType, Map<String, dynamic> payload) {
    return switch (eventType) {
      'payment_intent.succeeded' => _mapSucceeded(payload),
      'charge.refunded'          => _mapRefunded(payload),
      _                          => null,
    };
  }

  PaymentEvent _mapSucceeded(Map<String, dynamic> payload) {
    final pi       = payload['data']['object'] as Map<String, dynamic>;
    final metadata = (pi['metadata'] as Map<String, dynamic>?) ?? {};

    CustomerInfo? customer;
    if (metadata['customer_type'] == 'b2b' &&
        metadata['customer_nif'] != null) {
      customer = CustomerInfo(
        nif:     metadata['customer_nif'] as String,
        name:    metadata['customer_name'] as String?,
        email:   metadata['customer_email'] as String?,
        address: metadata['customer_address'] as String?,
        type:    CustomerType.b2b,
      );
    } else if (metadata['customer_email'] != null) {
      customer = CustomerInfo(
        email: metadata['customer_email'] as String,
        type:  CustomerType.b2c,
      );
    }

    return PaymentEvent(
      eventId:           payload['id'] as String,
      providerId:        'stripe',
      timestamp:         DateTime.fromMillisecondsSinceEpoch(
                           (pi['created'] as int) * 1000),
      amount:            (pi['amount'] as int) / 100,
      currency:          (pi['currency'] as String).toUpperCase(),
      status:            PaymentStatus.succeeded,
      method:            PaymentMethod.card,
      customer:          customer,
      rawPayload:        payload,
      externalReference: pi['id'] as String?,
    );
  }

  PaymentEvent _mapRefunded(Map<String, dynamic> payload) {
    final charge = payload['data']['object'] as Map<String, dynamic>;
    return PaymentEvent(
      eventId:           payload['id'] as String,
      providerId:        'stripe',
      timestamp:         DateTime.now(),
      amount:            (charge['amount_refunded'] as int) / 100,
      currency:          (charge['currency'] as String).toUpperCase(),
      status:            PaymentStatus.refunded,
      method:            PaymentMethod.card,
      rawPayload:        payload,
      externalReference: charge['payment_intent'] as String?,
    );
  }
}

