// lib/services/payments/providers/psd2/psd2_event_mapper.dart

import '../../interfaces/payment_event.dart';
import '../../../../models/psd2_consent.dart';

class Psd2EventMapper {
  PaymentEvent? map(Psd2Transaction tx, String bankId) {
    if (tx.creditDebitIndicator != 'CRDT') return null;
    if (tx.amount <= 0) return null;

    return PaymentEvent(
      eventId:           '${bankId}_${tx.transactionId}',
      providerId:        'psd2_$bankId',
      timestamp:         tx.bookingDate,
      amount:            tx.amount,
      currency:          tx.currency,
      status:            PaymentStatus.succeeded,
      method:            PaymentMethod.transfer,
      customer:          _resolveCustomer(tx),
      rawPayload:        {
        'transaction_id': tx.transactionId,
        'bank_id':        bankId,
        'remittance_info': tx.remittanceInfo,
        'debtor_name':    tx.debtorName,
        'debtor_iban':    tx.debtorIban,
      },
      externalReference: tx.transactionId,
    );
  }

  CustomerInfo? _resolveCustomer(Psd2Transaction tx) {
    if (tx.debtorName == null && tx.debtorIban == null) return null;
    return CustomerInfo(
      name:  tx.debtorName,
      type:  CustomerType.unknown,
    );
  }
}

