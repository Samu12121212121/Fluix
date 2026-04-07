// lib/services/payments/core/idempotency_repository.dart

import '../../../database/database.dart';

class IdempotencyRepository {
  final Database _db;
  IdempotencyRepository(this._db);

  /// Intenta adquirir el lock atómicamente.
  Future<IdempotencyResult> tryAcquire(
    String eventId,
    String providerId,
  ) async {
    try {
      final rowsAffected = await _db.execute('''
        INSERT INTO payment_processing_log
          (event_id, provider_id, status, locked_at, created_at, updated_at)
        VALUES
          (@eventId, @providerId, 'processing', NOW(), NOW(), NOW())
        ON CONFLICT (event_id) DO NOTHING
      ''', {'eventId': eventId, 'providerId': providerId});

      if (rowsAffected == 1) return IdempotencyResult.acquired();

      final row = await _db.queryOne(
        'SELECT status, invoice_id, locked_at FROM payment_processing_log '
        'WHERE event_id = @id',
        {'id': eventId},
      );
      if (row == null) return IdempotencyResult.error('Estado inconsistente');

      return switch (row['status'] as String) {
        'completed'  => IdempotencyResult.alreadyCompleted(
                          invoiceId: row['invoice_id'] as String?),
        'failed'     => IdempotencyResult.previouslyFailed(),
        'processing' => await _checkStaleLock(eventId, row),
        _            => IdempotencyResult.duplicate(),
      };
    } catch (e) {
      return IdempotencyResult.error(e.toString());
    }
  }

  /// Reclama locks huérfanos (worker murió hace más de 10 minutos).
  Future<IdempotencyResult> _checkStaleLock(
    String eventId,
    Map<String, dynamic> row,
  ) async {
    final lockedAt = row['locked_at'] as DateTime?;
    final isStale  = lockedAt == null ||
        DateTime.now().difference(lockedAt) > const Duration(minutes: 10);

    if (!isStale) return IdempotencyResult.beingProcessed();

    final updated = await _db.execute('''
      UPDATE payment_processing_log
      SET    status = 'processing', locked_at = NOW(), updated_at = NOW()
      WHERE  event_id  = @eventId
        AND  status    = 'processing'
        AND  locked_at < NOW() - INTERVAL '10 minutes'
    ''', {'eventId': eventId});

    return updated == 1
        ? IdempotencyResult.acquired()
        : IdempotencyResult.beingProcessed();
  }

  Future<void> markCompleted(String eventId, String invoiceId) async {
    await _db.execute('''
      UPDATE payment_processing_log
      SET    status = 'completed', invoice_id = @invoiceId,
             completed_at = NOW(), updated_at = NOW()
      WHERE  event_id = @eventId
    ''', {'eventId': eventId, 'invoiceId': invoiceId});
  }

  Future<void> markFailed(String eventId, String errorMessage) async {
    await _db.execute('''
      UPDATE payment_processing_log
      SET    status = 'failed', error_message = @error, updated_at = NOW()
      WHERE  event_id = @eventId
    ''', {'eventId': eventId, 'error': errorMessage});
  }
}

// ── Tipos de resultado ─────────────────────────────────────────────────────

sealed class IdempotencyResult {
  const IdempotencyResult();
  factory IdempotencyResult.acquired()                             => const Acquired();
  factory IdempotencyResult.alreadyCompleted({String? invoiceId}) => AlreadyCompleted(invoiceId);
  factory IdempotencyResult.beingProcessed()                      => const BeingProcessed();
  factory IdempotencyResult.previouslyFailed()                    => const PreviouslyFailed();
  factory IdempotencyResult.duplicate()                           => const Duplicate();
  factory IdempotencyResult.error(String msg)                     => IdempotencyError(msg);
}

class Acquired         extends IdempotencyResult { const Acquired(); }
class AlreadyCompleted extends IdempotencyResult {
  final String? invoiceId;
  const AlreadyCompleted(this.invoiceId);
}
class BeingProcessed   extends IdempotencyResult { const BeingProcessed(); }
class PreviouslyFailed extends IdempotencyResult { const PreviouslyFailed(); }
class Duplicate        extends IdempotencyResult { const Duplicate(); }
class IdempotencyError extends IdempotencyResult {
  final String message;
  const IdempotencyError(this.message);
}


