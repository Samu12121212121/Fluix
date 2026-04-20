import 'package:cloud_firestore/cloud_firestore.dart';

/// Parsea fechas de Firestore de forma robusta.
/// Acepta Timestamp, String ISO 8601 (con o sin microsegundos) o null.
DateTime parseDate(dynamic valor, {DateTime? fallback}) {
  if (valor == null) return fallback ?? DateTime.now();
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) {
    // Truncar a milisegundos (max 3 decimales) para máxima compatibilidad
    final dotIdx = valor.indexOf('.');
    String limpio;
    if (dotIdx != -1) {
      final prefix = valor.substring(0, dotIdx);
      final rest = valor.substring(dotIdx + 1);
      final digits = RegExp(r'^\d+').firstMatch(rest)?.group(0) ?? '';
      final suffix = rest.substring(digits.length);
      final truncated = digits.length > 3 ? digits.substring(0, 3) : digits;
      limpio = '$prefix.$truncated$suffix';
    } else {
      limpio = valor;
    }
    return DateTime.tryParse(limpio) ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

/// Versión que devuelve null si el valor es null.
DateTime? parseDateOrNull(dynamic valor) {
  if (valor == null) return null;
  return parseDate(valor);
}


