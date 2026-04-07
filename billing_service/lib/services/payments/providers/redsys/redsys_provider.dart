// lib/services/payments/providers/redsys/redsys_provider.dart

import 'dart:convert';

import '../../interfaces/payment_event.dart';
import '../../interfaces/payment_provider.dart';
import 'redsys_event_mapper.dart';
import 'redsys_signature_validator.dart';

class RedsysProvider implements PaymentProvider {
  final String             _merchantKey;
  final RedsysEventMapper  _mapper;

  RedsysProvider({required String merchantKey})
      : _merchantKey = merchantKey,
        _mapper      = RedsysEventMapper();

  @override String get providerId      => 'redsys';
  @override String get displayName     => 'Redsys (TPV bancario)';
  @override bool   get supportsWebhook => true;
  @override bool   get requiresPolling => false;

  @override
  Future<bool> validateSignature(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  ) async {
    final merchantParams = payload['Ds_MerchantParameters'] as String?;
    final signature      = payload['Ds_Signature'] as String?;
    if (merchantParams == null || signature == null) return false;

    final order = _extractOrder(merchantParams);
    return RedsysSignatureValidator.verify(
      merchantParameters: merchantParams,
      signature:          signature,
      merchantKey:        _merchantKey,
      order:              order,
    );
  }

  @override
  Future<PaymentEvent?> processEvent(
    Map<String, dynamic> payload,
    Map<String, String> headers,
  ) async {
    final merchantParams = payload['Ds_MerchantParameters'] as String;
    final decoded = jsonDecode(
      utf8.decode(base64.decode(merchantParams)),
    ) as Map<String, dynamic>;
    return _mapper.map(decoded);
  }

  String _extractOrder(String merchantParams) {
    try {
      final decoded = jsonDecode(
        utf8.decode(base64.decode(merchantParams)),
      ) as Map<String, dynamic>;
      return (decoded['Ds_Order'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<PaymentEvent>> pollNewPayments({
    required String lastProcessedId,
  }) => throw UnsupportedError('Redsys usa notificación URL, no polling');
}

