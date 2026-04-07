// lib/services/payments/providers/psd2/banks/santander_adapter.dart
import 'bank_adapter.dart';

class SantanderAdapter implements BankAdapter {
  @override String get bankId      => 'santander';
  @override String get displayName => 'Banco Santander';
  @override String get baseUrl     => 'https://apis.santander.com/psd2';
  @override String get authorizationEndpoint =>
      'https://apis.santander.com/psd2/oauth/authorize';
  @override String get tokenEndpoint =>
      'https://apis.santander.com/psd2/oauth/token';
  @override String get transactionsEndpoint =>
      '$baseUrl/v1/accounts/{accountId}/transactions';
}

