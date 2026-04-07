// lib/services/payments/providers/psd2/banks/bank_adapter.dart

/// Interfaz que cada banco PSD2 debe implementar.
abstract class BankAdapter {
  String get bankId;
  String get displayName;
  String get baseUrl;
  String get authorizationEndpoint;
  String get tokenEndpoint;
  String get transactionsEndpoint; // puede contener {accountId}
}

