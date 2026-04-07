// lib/services/payments/core/health_monitor.dart

import '../../logger.dart';
import '../../../database/database.dart';
import '../../notification_service.dart';
import '../providers/psd2/circuit_breaker.dart';

enum Severity { ok, warning, critical }

class HealthCheck {
  final Severity severity;
  final String   message;

  const HealthCheck.ok(this.message)       : severity = Severity.ok;
  const HealthCheck.warning(this.message)  : severity = Severity.warning;
  const HealthCheck.critical(this.message) : severity = Severity.critical;

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'message':  message,
  };
}

class HealthMonitor {
  final Database                     _db;
  final NotificationService          _notifications;
  final Map<String, CircuitBreaker>  _breakers;

  HealthMonitor({
    required Database                    db,
    required NotificationService         notifications,
    required Map<String, CircuitBreaker> breakers,
  })  : _db            = db,
        _notifications = notifications,
        _breakers      = breakers;

  Future<List<HealthCheck>> runChecks() async {
    final results = await Future.wait([
      _checkSilence(),
      _checkDeadLetter(),
      _checkBreakers(),
      _checkConsents(),
      _checkDbLatency(),
    ]);

    final criticals = results.where((c) => c.severity == Severity.critical).toList();
    if (criticals.isNotEmpty) {
      await _notifications.sendUrgent(
        title: '🚨 ${criticals.length} problema(s) en facturación automática',
        body:  criticals.map((c) => '• ${c.message}').join('\n'),
      );
    }

    for (final check in results) {
      final emoji = switch (check.severity) {
        Severity.ok       => '✅',
        Severity.warning  => '⚠️',
        Severity.critical => '🚨',
      };
      logger.info('[Health] $emoji ${check.message}');
    }

    return results;
  }

  Future<HealthCheck> _checkSilence() async {
    try {
      final row = await _db.queryOne(
        "SELECT MAX(completed_at) as last FROM payment_processing_log "
        "WHERE status='completed'",
      );
      final last = row?['last'] as DateTime?;
      if (last == null) return const HealthCheck.warning('Sin pagos procesados aún');
      final h = DateTime.now().difference(last).inHours;
      return h > 4
          ? HealthCheck.critical('Sin pagos procesados en ${h}h — verificar webhooks')
          : HealthCheck.ok(
              'Último pago hace ${DateTime.now().difference(last).inMinutes}min',
            );
    } catch (e) {
      return HealthCheck.critical('Error consultando log de pagos: $e');
    }
  }

  Future<HealthCheck> _checkDeadLetter() async {
    try {
      final row = await _db.queryOne(
        "SELECT COUNT(*) as n FROM retry_queue WHERE status='dead_letter' "
        "AND updated_at > NOW() - INTERVAL '24 hours'",
      );
      final n = (row?['n'] as int?) ?? 0;
      return n == 0
          ? const HealthCheck.ok('Sin pagos en dead letter (24h)')
          : HealthCheck.critical(
              '$n pago(s) sin facturar — revisar GET /admin/dead-letter',
            );
    } catch (e) {
      return HealthCheck.warning('Error consultando dead letter: $e');
    }
  }

  Future<HealthCheck> _checkBreakers() async {
    final open = _breakers.entries
        .where((e) => e.value.isOpen)
        .map((e) => e.key)
        .toList();
    return open.isEmpty
        ? const HealthCheck.ok('Todos los bancos PSD2 operativos')
        : HealthCheck.warning('Circuit breaker abierto: ${open.join(', ')}');
  }

  Future<HealthCheck> _checkConsents() async {
    try {
      final rows = await _db.queryMany(
        "SELECT bank_id, expires_at FROM psd2_consents "
        "WHERE expires_at < NOW() + INTERVAL '10 days' AND status='active'",
      );
      return rows.isEmpty
          ? const HealthCheck.ok('Consentimientos PSD2 vigentes (>10 días)')
          : HealthCheck.warning(
              'Consentimientos próximos a expirar: '
              '${rows.map((r) => r['bank_id']).join(', ')}',
            );
    } catch (_) {
      // No hay bancos PSD2 configurados — no es un error
      return const HealthCheck.ok('Sin bancos PSD2 configurados');
    }
  }

  Future<HealthCheck> _checkDbLatency() async {
    final t0  = DateTime.now();
    await _db.queryOne('SELECT 1');
    final ms  = DateTime.now().difference(t0).inMilliseconds;
    return ms > 500
        ? HealthCheck.critical('Latencia BD crítica: ${ms}ms')
        : ms > 200
            ? HealthCheck.warning('Latencia BD elevada: ${ms}ms')
            : HealthCheck.ok('BD OK (${ms}ms)');
  }
}


