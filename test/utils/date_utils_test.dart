import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planeag_flutter/utils/date_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('parsearFecha', () {
    test('1. Timestamp de Firestore → DateTime', () {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 30, 17, 23, 22));
      final result = parsearFecha(ts);
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
      expect(result.hour, 17);
    });

    test('2. String ISO 8601 sin zona → DateTime', () {
      final result = parsearFecha('2026-03-30T17:23:22.524041');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
    });

    test('3. String ISO 8601 con Z → DateTime', () {
      final result = parsearFecha('2026-03-30T17:23:22.524041Z');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
    });

    test('4. String solo fecha → DateTime', () {
      final result = parsearFecha('2026-03-30');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
      expect(result.hour, 0);
    });

    test('5. String formato español dd/MM/yyyy → DateTime', () {
      final result = parsearFecha('30/03/2026');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
    });

    test('6. int microsegundos desde epoch → DateTime', () {
      final dt = DateTime(2026, 3, 30, 17, 23, 22);
      final micros = dt.microsecondsSinceEpoch;
      final result = parsearFecha(micros);
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 3);
      expect(result.day, 30);
    });

    test('7. null → null (sin excepción)', () {
      expect(parsearFecha(null), isNull);
    });

    test('8. String vacío → null (sin excepción)', () {
      expect(parsearFecha(''), isNull);
    });

    test('9. String no parseable → null (sin excepción)', () {
      expect(parsearFecha('esto no es una fecha'), isNull);
    });

    test('10. DateTime passthrough', () {
      final dt = DateTime(2026, 3, 30);
      expect(parsearFecha(dt), dt);
    });
  });

  group('formatearFechaSegura', () {
    test('devuelve fecha formateada para Timestamp válido', () {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 30, 17, 23));
      final result = formatearFechaSegura(ts);
      expect(result, contains('30/03/2026'));
      expect(result, contains('17:23'));
    });

    test('devuelve solo fecha cuando soloFecha=true', () {
      final result = formatearFechaSegura('2026-03-30T17:23:22', soloFecha: true);
      expect(result, '30/03/2026');
    });

    test('devuelve fallback para null', () {
      expect(formatearFechaSegura(null), '-');
    });

    test('devuelve fallback personalizado', () {
      expect(formatearFechaSegura(null, fallback: 'N/A'), 'N/A');
    });

    test('devuelve fallback para string no parseable', () {
      expect(formatearFechaSegura('basura'), '-');
    });
  });
}

