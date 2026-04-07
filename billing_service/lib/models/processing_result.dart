// lib/models/processing_result.dart

import 'invoice.dart';

sealed class ProcessingResult {
  const ProcessingResult();

  bool get isSuccess   => this is _Success;
  bool get isDuplicate => this is _Duplicate;

  String? get error => switch (this) {
    _Error(:final error) => error,
    _                    => null,
  };

  Invoice? get invoice => switch (this) {
    _Success(:final invoice) => invoice,
    _                        => null,
  };

  factory ProcessingResult.success({required Invoice invoice}) =>
      _Success(invoice);

  factory ProcessingResult.skipped(String reason) => _Skipped(reason);

  factory ProcessingResult.duplicate({String? eventId}) =>
      _Duplicate(eventId);

  factory ProcessingResult.deferred({String? reason}) => _Deferred(reason);

  factory ProcessingResult.error({
    required String eventId,
    required String error,
  }) => _Error(eventId, error);

  Map<String, dynamic> toJson() => switch (this) {
    _Success(:final invoice)   => {'status': 'success', 'invoice_id': invoice.id},
    _Skipped(:final reason)    => {'status': 'skipped',   'reason': reason},
    _Duplicate(:final eventId) => {'status': 'duplicate', 'event_id': eventId},
    _Deferred(:final reason)   => {'status': 'deferred',  'reason': reason},
    _Error(:final eventId, :final error) =>
        {'status': 'error', 'event_id': eventId, 'error': error},
  };
}

class _Success  extends ProcessingResult { final Invoice invoice; const _Success(this.invoice); }
class _Skipped  extends ProcessingResult { final String reason;   const _Skipped(this.reason); }
class _Duplicate extends ProcessingResult { final String? eventId; const _Duplicate(this.eventId); }
class _Deferred extends ProcessingResult { final String? reason;  const _Deferred(this.reason); }
class _Error    extends ProcessingResult {
  final String eventId;
  final String error;
  const _Error(this.eventId, this.error);
}

