// lib/services/payments/providers/psd2/banks/bankinter_adapter.dart
import 'bank_adapter.dart';

class BankinterAdapter implements BankAdapter {
  @override String get bankId      => 'bankinter';
  @override String get displayName => 'Bankinter';
  @override String get baseUrl     => 'https://api.bankinter.com/psd2';
  @override String get authorizationEndpoint =>
      'https://api.bankinter.com/psd2/oauth/authorize';
  @override String get tokenEndpoint =>
      'https://api.bankinter.com/psd2/oauth/token';
  @override String get transactionsEndpoint =>
      '$baseUrl/v1/accounts/{accountId}/transactions';
}

