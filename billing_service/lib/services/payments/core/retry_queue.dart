// lib/services/payments/core/retry_queue.dart

import 'dart:convert';
import 'dart:math';

import '../../logger.dart';
import '../../../database/database.dart';
import '../../notification_service.dart';
import '../interfaces/payment_event.dart';
import 'payment_processor.dart';

class RetryQueue {
  final Database            _db;
  final PaymentProcessor    _processor;
  final NotificationService _notifications;

  static const _maxAttempts = 8;
  // Delays exponenciales: 1, 2, 4, 8, 16, 32, 64, 128 min (~4.25h total)

  RetryQueue({
    required Database            db,
    required PaymentProcessor    processor,
    required NotificationService notifications,
  })  : _db            = db,
        _processor     = processor,
        _notifications = notifications;

  Future<void> enqueue(PaymentEvent event, {String? tenantId}) async {
    await _db.execute('''
      INSERT INTO retry_queue
        (event_id, provider_id, payload, status, attempt_count, next_attempt_at,
         tenant_id, created_at, updated_at)
      VALUES
        (@id, @provider, @payload::jsonb, 'pending', 0, NOW(), @tenantId, NOW(), NOW())
      ON CONFLICT (event_id) DO NOTHING
    ''', {
      'id':       event.eventId,
      'provider': event.providerId,
      'payload':  jsonEncode(event.toJson()),
      'tenantId': tenantId,
    });
    final prefix = tenantId != null ? '[$tenantId] ' : '';
    logger.info('${prefix}[RetryQueue] Encolado: ${event.eventId} (${event.providerId})');
  }

  Future<void> processQueue() async {
    final rows = await _db.queryMany('''
      SELECT * FROM retry_queue
      WHERE  status IN ('pending','retrying')
        AND  next_attempt_at <= NOW()
      ORDER BY next_attempt_at ASC
      LIMIT  50
      FOR UPDATE SKIP LOCKED
    ''');

    for (final row in rows) {
      await _processRow(row);
    }
  }

  Future<void> _processRow(Map<String, dynamic> row) async {
    final eventId  = row['event_id'] as String;
    final tenantId = row['tenant_id'] as String?;
    final attempts = (row['attempt_count'] as int) + 1;

    try {
      final event = PaymentEvent.fromJson(
        jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      );
      final result = await _processor.process(event, tenantId);

      if (result.isSuccess || result.isDuplicate) {
        await _db.execute(
          "UPDATE retry_queue SET status='completed', updated_at=NOW() "
          'WHERE event_id=@id',
          {'id': eventId},
        );
        logger.info('[RetryQueue] Completado: $eventId');
      } else {
        await _scheduleRetry(eventId, attempts, result.error);
      }
    } catch (e) {
      await _scheduleRetry(eventId, attempts, e.toString());
    }
  }

  Future<void> _scheduleRetry(
    String  id,
    int     attempts,
    String? error,
  ) async {
    if (attempts >= _maxAttempts) {
      await _db.execute(
        "UPDATE retry_queue SET status='dead_letter', last_error=@err, "
        'updated_at=NOW() WHERE event_id=@id',
        {'id': id, 'err': error},
      );
      logger.error('[RetryQueue] DEAD LETTER: $id — $error');
      await _notifications.sendUrgent(
        title: '🚨 Pago sin facturar tras $_maxAttempts intentos',
        body:  'Evento $id requiere revisión manual. Error: $error',
      );
      return;
    }

    final delayMin = pow(2, attempts - 1).toInt();
    final next     = DateTime.now().add(Duration(minutes: delayMin));

    await _db.execute('''
      UPDATE retry_queue
      SET    status = 'retrying',
             attempt_count  = @n,
             next_attempt_at = @next,
             last_error      = @err,
             updated_at      = NOW()
      WHERE  event_id = @id
    ''', {
      'n':    attempts,
      'next': next.toIso8601String(),
      'err':  error,
      'id':   id,
    });

    logger.info('[RetryQueue] Reintento $attempts/$_maxAttempts programado '
        'para $id en ${delayMin}min');
  }

  /// Mueve un evento de dead_letter a pending para reintentar manualmente.
  Future<void> manualRetry(String eventId) async {
    await _db.execute('''
      UPDATE retry_queue
      SET    status = 'pending', attempt_count = 0,
             next_attempt_at = NOW(), updated_at = NOW()
      WHERE  event_id = @id AND status = 'dead_letter'
    ''', {'id': eventId});
    logger.info('[RetryQueue] Reintento manual: $eventId');
  }

  Future<List<Map<String, dynamic>>> getDeadLetter({String? tenantId}) async {
    if (tenantId != null) {
      return _db.queryMany(
        "SELECT * FROM retry_queue WHERE status = 'dead_letter' "
        'AND tenant_id = @tid ORDER BY updated_at DESC LIMIT 100',
        {'tid': tenantId},
      );
    }
    return _db.queryMany(
      "SELECT * FROM retry_queue WHERE status = 'dead_letter' "
      'ORDER BY updated_at DESC LIMIT 100',
    );
  }
}


