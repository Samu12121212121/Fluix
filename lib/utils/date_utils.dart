import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UTILIDADES DE FECHA — Parseo seguro de valores procedentes de Firestore
//
// Firestore puede devolver fechas como:
//   1. Timestamp  (tipo nativo)
//   2. String ISO 8601: "2026-03-30T17:23:22.524041"
//   3. String ISO con Z: "2026-03-30T17:23:22.524041Z"
//   4. String solo fecha: "2026-03-30"
//   5. String formato español: "30/03/2026"
//   6. int (microsegundos desde epoch)
//   7. DateTime (ya parseado)
//
// Estas funciones manejan TODOS los formatos sin lanzar excepción.
// ─────────────────────────────────────────────────────────────────────────────

/// Formatos de fecha españoles que intentamos parsear (en orden de más a menos común).
final List<DateFormat> _formatosEspanol = [
  DateFormat('dd/MM/yyyy HH:mm:ss'),
  DateFormat('dd/MM/yyyy HH:mm'),
  DateFormat('dd/MM/yyyy'),
  DateFormat('d/M/yyyy'),
  DateFormat('dd-MM-yyyy'),
];

/// Parsea un valor dinámico procedente de Firestore a [DateTime].
///
/// Devuelve `null` si no se puede parsear (nunca lanza excepción).
///
/// Formatos soportados:
/// - [Timestamp] de Firestore
/// - [DateTime] (passthrough)
/// - [String] en ISO 8601, solo fecha, o formato español dd/MM/yyyy
/// - [int] interpretado como microsegundos desde epoch
DateTime? parsearFecha(dynamic valor) {
  if (valor == null) return null;

  // 1. Timestamp de Firestore
  if (valor is Timestamp) {
    return valor.toDate();
  }

  // 2. Ya es DateTime
  if (valor is DateTime) {
    return valor;
  }

  // 3. String → intentar múltiples formatos
  if (valor is String) {
    final trimmed = valor.trim();
    if (trimmed.isEmpty) return null;

    // 3a. ISO 8601 / solo fecha (DateTime.tryParse cubre ambos)
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    // 3b. Formatos españoles (dd/MM/yyyy, etc.)
    for (final fmt in _formatosEspanol) {
      try {
        return fmt.parseStrict(trimmed);
      } catch (_) {
        // Intentar siguiente formato
      }
    }

    return null;
  }

  // 4. int → microsegundos desde epoch
  if (valor is int) {
    try {
      return DateTime.fromMicrosecondsSinceEpoch(valor);
    } catch (_) {
      return null;
    }
  }

  // 5. num (double) → convertir a int y tratar como microsegundos
  if (valor is num) {
    try {
      return DateTime.fromMicrosecondsSinceEpoch(valor.toInt());
    } catch (_) {
      return null;
    }
  }

  return null;
}

/// Formato por defecto para mostrar en la UI.
final DateFormat _fmtUI = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');
final DateFormat _fmtUISoloFecha = DateFormat('dd/MM/yyyy', 'es_ES');

/// Formatea un valor dinámico para mostrar en la UI.
///
/// Si [soloFecha] es true, omite la hora.
/// Devuelve [fallback] si no se puede parsear.
String formatearFechaSegura(
  dynamic valor, {
  String fallback = '-',
  bool soloFecha = false,
}) {
  final dt = parsearFecha(valor);
  if (dt == null) return fallback;
  try {
    return soloFecha ? _fmtUISoloFecha.format(dt) : _fmtUI.format(dt);
  } catch (_) {
    return fallback;
  }
}

