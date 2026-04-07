// lib/services/payments/providers/psd2/banks/caixabank_adapter.dart
import 'bank_adapter.dart';

class CaixaBankAdapter implements BankAdapter {
  @override String get bankId      => 'caixabank';
  @override String get displayName => 'CaixaBank';
  @override String get baseUrl     => 'https://api.caixabank.es/psd2/openbanking';
  @override String get authorizationEndpoint =>
      'https://api.caixabank.es/psd2/openbanking/oauth/authorize';
  @override String get tokenEndpoint =>
      'https://api.caixabank.es/psd2/openbanking/oauth/token';
  @override String get transactionsEndpoint =>
      '$baseUrl/v1/accounts/{accountId}/transactions';
}

