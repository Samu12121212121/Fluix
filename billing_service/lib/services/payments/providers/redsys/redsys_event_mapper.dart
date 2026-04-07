// lib/services/payments/providers/redsys/redsys_event_mapper.dart

import '../../interfaces/payment_event.dart';

class RedsysEventMapper {
  PaymentEvent? map(Map<String, dynamic> data) {
    final responseCode    = int.tryParse(data['Ds_Response'] as String? ?? '9999') ?? 9999;
    if (responseCode > 99) return null; // Pago fallido o denegado

    final transactionType = data['Ds_TransactionType'] as String? ?? '0';

    final status = switch (transactionType) {
      '0' => PaymentStatus.succeeded,
      '3' => PaymentStatus.refunded,
      _   => null,
    };
    if (status == null) return null;

    final amount = (int.tryParse(data['Ds_Amount'] as String? ?? '0') ?? 0) / 100;

    DateTime timestamp;
    try {
      final d = (data['Ds_Date'] as String).split('/');
      final t = (data['Ds_Hour'] as String).split(':');
      timestamp = DateTime(
        int.parse(d[2]), int.parse(d[1]), int.parse(d[0]),
        int.parse(t[0]), int.parse(t[1]),
      );
    } catch (_) {
      timestamp = DateTime.now();
    }

    return PaymentEvent(
      eventId:           '${data['Ds_MerchantCode']}_${data['Ds_Order']}',
      providerId:        'redsys',
      timestamp:         timestamp,
      amount:            amount,
      currency:          'EUR',
      status:            status,
      method:            PaymentMethod.card,
      rawPayload:        data,
      externalReference: data['Ds_Order'] as String?,
    );
  }
}

