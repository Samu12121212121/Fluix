// lib/services/payments/providers/psd2/circuit_breaker.dart

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  CircuitState _state        = CircuitState.closed;
  int          _failureCount = 0;
  DateTime?    _openedAt;

  final String   bankId;
  final int      failureThreshold;
  final Duration recoveryTimeout;

  CircuitBreaker({
    required this.bankId,
    this.failureThreshold = 5,
    this.recoveryTimeout  = const Duration(minutes: 30),
  });

  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      final elapsed = DateTime.now().difference(_openedAt!);
      if (elapsed < recoveryTimeout) {
        throw CircuitOpenException(
          'Circuit breaker abierto para $bankId. '
          'Próximo intento en ${(recoveryTimeout - elapsed).inMinutes}min.',
        );
      }
      _state = CircuitState.halfOpen;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      if (e is CircuitOpenException) rethrow;
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _state        = CircuitState.closed;
  }

  void _onFailure() {
    _failureCount++;
    if (_failureCount >= failureThreshold) {
      _state    = CircuitState.open;
      _openedAt = DateTime.now();
    }
  }

  bool get isOpen => _state == CircuitState.open;

  Map<String, dynamic> toJson() => {
    'bank_id':       bankId,
    'state':         _state.name,
    'failure_count': _failureCount,
    'opened_at':     _openedAt?.toIso8601String(),
  };
}

class CircuitOpenException implements Exception {
  final String message;
  const CircuitOpenException(this.message);
  @override String toString() => 'CircuitOpenException: $message';
}

