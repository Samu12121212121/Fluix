// lib/services/payments/providers/psd2/banks/berlin_group_client.dart
// Implementación del protocolo NextGenPSD2 Berlin Group v1.3

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../../models/psd2_consent.dart';
import 'bank_adapter.dart';

class BerlinGroupClient {
  final BankAdapter _adapter;

  BerlinGroupClient(this._adapter);

  String get bankId => _adapter.bankId;

  /// Obtiene la lista de cuentas disponibles bajo el consentimiento.
  Future<List<Psd2Account>> getAccounts({
    required String consentId,
    required String accessToken,
  }) async {
    final url = '${_adapter.baseUrl}/v1/accounts';
    final response = await http.get(
      Uri.parse(url),
      headers: _headers(consentId: consentId, accessToken: accessToken),
    );

    _checkResponse(response, 'getAccounts');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = (data['accounts'] as List<dynamic>? ?? []);

    return accounts.map((a) {
      final acc = a as Map<String, dynamic>;
      return Psd2Account(
        id:        acc['resourceId'] as String? ?? acc['id'] as String,
        consentId: consentId,
        iban:      acc['iban'] as String? ?? '',
        currency:  acc['currency'] as String?,
      );
    }).toList();
  }

  /// Obtiene las transacciones de una cuenta desde una fecha.
  Future<List<Psd2Transaction>> getTransactions({
    required String accountId,
    required String consentId,
    required DateTime dateFrom,
    String accessToken = '',
  }) async {
    final dateTo  = DateTime.now();
    final fromStr = _formatDate(dateFrom);
    final toStr   = _formatDate(dateTo);

    final url = _adapter.transactionsEndpoint
        .replaceAll('{accountId}', accountId);

    final response = await http.get(
      Uri.parse('$url?dateFrom=$fromStr&dateTo=$toStr&bookingStatus=booked'),
      headers: _headers(consentId: consentId, accessToken: accessToken),
    );

    _checkResponse(response, 'getTransactions[$accountId]');

    final data         = jsonDecode(response.body) as Map<String, dynamic>;
    final transactions = data['transactions'] as Map<String, dynamic>? ?? {};
    final booked       = (transactions['booked'] as List<dynamic>?) ?? [];

    return booked.map((t) => _parseTransaction(t as Map<String, dynamic>)).toList();
  }

  Psd2Transaction _parseTransaction(Map<String, dynamic> t) {
    final amount   = t['transactionAmount'] as Map<String, dynamic>? ?? {};
    final rawAmt   = double.tryParse(amount['amount'] as String? ?? '0') ?? 0;
    final currency = amount['currency'] as String? ?? 'EUR';
    final crDt     = t['creditDebitIndicator'] as String? ??
        (rawAmt >= 0 ? 'CRDT' : 'DBIT');

    DateTime bookingDate;
    try {
      bookingDate = DateTime.parse(t['bookingDate'] as String);
    } catch (_) {
      bookingDate = DateTime.now();
    }

    final debtor    = t['debtorAccount'] as Map<String, dynamic>? ?? {};
    final remit     = t['remittanceInformationUnstructured'] as String? ??
                      t['remittanceInformationStructured'] as String?;

    return Psd2Transaction(
      transactionId:          t['transactionId'] as String? ??
                               t['entryReference'] as String? ??
                               '${bookingDate.millisecondsSinceEpoch}',
      amount:                 rawAmt.abs(),
      currency:               currency,
      bookingDate:            bookingDate,
      creditDebitIndicator:   crDt,
      remittanceInfo:         remit,
      debtorName:             t['debtorName'] as String?,
      debtorIban:             debtor['iban'] as String?,
    );
  }

  Map<String, String> _headers({
    required String consentId,
    required String accessToken,
  }) => {
    'Accept':        'application/json',
    'Content-Type':  'application/json',
    'Consent-ID':    consentId,
    if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
    'X-Request-ID':  DateTime.now().millisecondsSinceEpoch.toString(),
  };

  void _checkResponse(http.Response r, String operation) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(
        'PSD2 $operation error — ${_adapter.bankId}: '
        '${r.statusCode} ${r.body}',
      );
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

