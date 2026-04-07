// lib/services/payments/providers/psd2/banks/sabadell_adapter.dart
import 'bank_adapter.dart';

class SabadellAdapter implements BankAdapter {
  @override String get bankId      => 'sabadell';
  @override String get displayName => 'Banco Sabadell';
  @override String get baseUrl     => 'https://openapi.bancsabadell.com/psd2';
  @override String get authorizationEndpoint =>
      'https://openapi.bancsabadell.com/psd2/oauth/authorize';
  @override String get tokenEndpoint =>
      'https://openapi.bancsabadell.com/psd2/oauth/token';
  @override String get transactionsEndpoint =>
      '$baseUrl/v1/accounts/{accountId}/transactions';
}

