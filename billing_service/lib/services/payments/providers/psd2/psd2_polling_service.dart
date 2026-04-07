// lib/services/payments/providers/psd2/psd2_polling_service.dart

import '../../../../repositories/consent_repository.dart';
import '../../interfaces/payment_event.dart';
import '../../../logger.dart';
import 'circuit_breaker.dart';
import 'psd2_event_mapper.dart';
import 'banks/bank_adapter.dart';
import 'banks/berlin_group_client.dart';

// Importado por el orquestador
typedef PaymentProcessor = Future<void> Function(PaymentEvent event);

class Psd2PollingService {
  final Map<String, BerlinGroupClient> _clients  = {};
  final Map<String, CircuitBreaker>    _breakers = {};
  final PaymentProcessor               _processor;
  final Psd2EventMapper                _mapper;
  final ConsentRepository              _consentRepo;

  Psd2PollingService({
    required PaymentProcessor    processor,
    required ConsentRepository   consentRepo,
  })  : _processor   = processor,
        _mapper      = Psd2EventMapper(),
        _consentRepo = consentRepo;

  void registerBank(BankAdapter adapter) {
    final client = BerlinGroupClient(adapter);
    _clients[adapter.bankId]  = client;
    _breakers[adapter.bankId] = CircuitBreaker(bankId: adapter.bankId);
  }

  Map<String, CircuitBreaker> get breakers => Map.unmodifiable(_breakers);

  Future<void> pollAll() async {
    for (final bankId in _clients.keys) {
      try {
        await _breakers[bankId]!.execute(() => _pollBank(bankId));
      } on CircuitOpenException catch (e) {
        logger.info(e.message);
      } catch (e, st) {
        logger.error('Error polling $bankId: $e', st);
      }
    }
  }

  Future<void> _pollBank(String bankId) async {
    final consent = await _consentRepo.getByBankId(bankId);
    if (consent == null || consent.isExpired) {
      logger.warn('[$bankId] Sin consentimiento activo — omitiendo polling');
      return;
    }

    final client   = _clients[bankId]!;
    final accounts = await client.getAccounts(
      consentId:   consent.bankId,
      accessToken: consent.accessToken,
    );

    for (final account in accounts) {
      final since = await _consentRepo.getLastProcessedDate(bankId, account.id) ??
                    DateTime.now().subtract(const Duration(days: 1));

      final transactions = await client.getTransactions(
        accountId:   account.id,
        consentId:   account.consentId,
        dateFrom:    since,
        accessToken: consent.accessToken,
      );

      final credits = transactions.where(
        (t) => t.creditDebitIndicator == 'CRDT',
      );

      for (final tx in credits) {
        final event = _mapper.map(tx, bankId);
        if (event != null) await _processor(event);
      }

      if (transactions.isNotEmpty) {
        await _consentRepo.updateLastProcessedDate(
          bankId, account.id, DateTime.now(),
        );
      }
    }
  }
}


