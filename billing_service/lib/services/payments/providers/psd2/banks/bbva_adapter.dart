// lib/services/payments/providers/psd2/banks/bbva_adapter.dart
import 'bank_adapter.dart';

class BBVAAdapter implements BankAdapter {
  @override String get bankId      => 'bbva';
  @override String get displayName => 'BBVA';
  @override String get baseUrl     => 'https://connect.bbva.com/psd2';
  @override String get authorizationEndpoint =>
      'https://connect.bbva.com/psd2/oauth2/authorize';
  @override String get tokenEndpoint =>
      'https://connect.bbva.com/psd2/oauth2/token';
  @override String get transactionsEndpoint =>
      '$baseUrl/v3/accounts/{accountId}/transactions';
}

