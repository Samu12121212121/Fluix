// lib/models/psd2_consent.dart

class Psd2Consent {
  final String  bankId;
  final String  accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String  status; // 'active' | 'expired' | 'revoked'

  const Psd2Consent({
    required this.bankId,
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.status = 'active',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get daysUntilExpiry =>
      expiresAt.difference(DateTime.now()).inDays;
}

class Psd2Token {
  final String  accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const Psd2Token({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });
}

class Psd2Account {
  final String id;
  final String consentId;
  final String iban;
  final String? currency;

  const Psd2Account({
    required this.id,
    required this.consentId,
    required this.iban,
    this.currency,
  });
}

class Psd2Transaction {
  final String  transactionId;
  final double  amount;
  final String  currency;
  final DateTime bookingDate;
  final String  creditDebitIndicator; // 'CRDT' | 'DBIT'
  final String? remittanceInfo;
  final String? debtorName;
  final String? debtorIban;

  const Psd2Transaction({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.bookingDate,
    required this.creditDebitIndicator,
    this.remittanceInfo,
    this.debtorName,
    this.debtorIban,
  });
}

