import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/fiscal/mod390_posicional_service.dart';
import 'package:planeag_flutter/domain/modelos/modelo390.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TEST UNITARIO — MOD 390 POSICIONAL
// Verifica la longitud correcta de cada página generada y el formato numérico.
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late Mod390Builder builder;
  late Modelo390 modeloBase;

  setUp(() {
    builder = Mod390Builder();
    modeloBase = const Modelo390(
      id: 'test-001',
      empresaId: 'empresa-test',
      ejercicio: 2025,
      fechaGeneracion: DateTime(2026, 1, 15),
      c01: 10000.00,
      c02: 400.00,
      c03: 25000.00,
      c04: 2500.00,
      c05: 150000.00,
      c06: 31500.00,
      c48: 0,
      c49: 18000.00,
      c85: 0,
      c99: 185000.00,
    );
  });

  // ─── Longitudes de página ──────────────────────────────────────────────────

  group('Longitudes de página posicional', () {
    test('Página 1 debe tener 1187 posiciones', () {
      final pag = builder.construirPagina1(
        nif: 'B12345678',
        razonSocial: 'EMPRESA TEST SL',
        ejercicio: 2025,
      );
      expect(pag.length, equals(1187),
          reason: 'Página 1 debe ser de exactamente 1187 caracteres');
    });

    test('Página 2 debe tener 1806 posiciones', () {
      final pag = builder.construirPagina2(modeloBase);
      expect(pag.length, equals(1806),
          reason: 'Página 2 debe ser de exactamente 1806 caracteres');
    });

    test('Página 2B debe tener 531 posiciones', () {
      final pag = builder.construirPagina2B(modeloBase);
      expect(pag.length, equals(531),
          reason: 'Página 2B debe ser de exactamente 531 caracteres');
    });

    test('Página 3 debe tener 1840 posiciones', () {
      final pag = builder.construirPagina3(modeloBase);
      expect(pag.length, equals(1840),
          reason: 'Página 3 debe ser de exactamente 1840 caracteres');
    });

    test('Página 4 debe tener 854 posiciones', () {
      final pag = builder.construirPagina4(modeloBase);
      expect(pag.length, equals(854),
          reason: 'Página 4 debe ser de exactamente 854 caracteres');
    });

    test('Página 6 debe tener 828 posiciones', () {
      final pag = builder.construirPagina6(modeloBase);
      expect(pag.length, equals(828),
          reason: 'Página 6 debe ser de exactamente 828 caracteres');
    });
  });

  // ─── Cabeceras y cierres ───────────────────────────────────────────────────

  group('Cabeceras y cierres de página', () {
    test('Página 1 comienza con <T39001000> y termina con </T39001000>', () {
      final pag = builder.construirPagina1(
        nif: 'B12345678',
        razonSocial: 'TEST SL',
        ejercicio: 2025,
      );
      expect(pag.startsWith('<T39001000>'), isTrue);
      expect(pag.endsWith('</T39001000>'), isTrue);
    });

    test('Página 2 comienza con <T39002000> y termina con </T39002000>', () {
      final pag = builder.construirPagina2(modeloBase);
      expect(pag.startsWith('<T39002000>'), isTrue);
      expect(pag.endsWith('</T39002000>'), isTrue);
    });

    test('Página 2B comienza con <T39002B00> y termina con </T39002B00>', () {
      final pag = builder.construirPagina2B(modeloBase);
      expect(pag.startsWith('<T39002B00>'), isTrue);
      expect(pag.endsWith('</T39002B00>'), isTrue);
    });

    test('Página 3 comienza con <T39003000> y termina con </T39003000>', () {
      final pag = builder.construirPagina3(modeloBase);
      expect(pag.startsWith('<T39003000>'), isTrue);
      expect(pag.endsWith('</T39003000>'), isTrue);
    });

    test('Página 4 comienza con <T39004000> y termina con </T39004000>', () {
      final pag = builder.construirPagina4(modeloBase);
      expect(pag.startsWith('<T39004000>'), isTrue);
      expect(pag.endsWith('</T39004000>'), isTrue);
    });

    test('Página 6 comienza con <T39006000> y termina con </T39006000>', () {
      final pag = builder.construirPagina6(modeloBase);
      expect(pag.startsWith('<T39006000>'), isTrue);
      expect(pag.endsWith('</T39006000>'), isTrue);
    });
  });

  // ─── Formato numérico ──────────────────────────────────────────────────────

  group('formatearN — campo numérico con signo', () {
    test('Positivo: 1234.56 → 00000000000123456 (17 chars)', () {
      final result = builder.formatearN(1234.56);
      expect(result, equals('00000000000123456'));
      expect(result.length, equals(17));
    });

    test('Negativo: -1234.56 → N0000000000123456 (17 chars)', () {
      final result = builder.formatearN(-1234.56);
      expect(result, equals('N0000000000123456'));
      expect(result.length, equals(17));
    });

    test('Cero: 0.00 → 00000000000000000', () {
      final result = builder.formatearN(0);
      expect(result, equals('00000000000000000'));
    });

    test('Importe grande: 150000.00 → 00000000015000000', () {
      final result = builder.formatearN(150000.00);
      expect(result, equals('00000000015000000'));
    });

    test('Cuota exacta: 31500.00 → 00000000003150000', () {
      final result = builder.formatearN(31500.00);
      expect(result, equals('00000000003150000'));
    });
  });

  group('formatearAn — campo alfanumérico', () {
    test('Texto corto: se rellena con blancos a la derecha', () {
      final result = builder.formatearAn('TEST', 10);
      expect(result, equals('TEST      '));
      expect(result.length, equals(10));
    });

    test('Texto largo: se trunca', () {
      final result = builder.formatearAn('ABCDEFGHIJ', 5);
      expect(result, equals('ABCDE'));
    });

    test('NIF en 9 chars', () {
      final result = builder.formatearAn('B12345678', 9);
      expect(result, equals('B12345678'));
      expect(result.length, equals(9));
    });
  });

  // ─── Cabecera Página 0 ────────────────────────────────────────────────────

  group('Página 0 — cabecera envolvente', () {
    test('Contiene <AUX> y </AUX>', () {
      final pag0 = builder.construirPagina0(
        anio: 2025,
        contenidoPaginas: 'CONTENIDO',
      );
      expect(pag0.contains('<AUX>'), isTrue);
      expect(pag0.contains('</AUX>'), isTrue);
    });

    test('Contiene el año en la posición correcta', () {
      final pag0 = builder.construirPagina0(
        anio: 2025,
        contenidoPaginas: '',
      );
      // Pos 7-10 (idx 6-9) debe ser "2025"
      expect(pag0.substring(6, 10), equals('2025'));
    });

    test('Termina con cierre correcto para 2025', () {
      final pag0 = builder.construirPagina0(
        anio: 2025,
        contenidoPaginas: '',
      );
      expect(pag0.endsWith('</T390020250A0000>'), isTrue);
    });

    test('Contiene versión 1.02 en posición 95-98 (idx 94-97)', () {
      final pag0 = builder.construirPagina0(
        anio: 2025,
        contenidoPaginas: '',
      );
      // Pos 95-98 = idx 94-97
      expect(pag0.substring(94, 98), equals('1.02'));
    });
  });

  // ─── Datos de la Página 2 ─────────────────────────────────────────────────

  group('Página 2 — datos numéricos', () {
    test('Campo [01] en posición 81-97 contiene base 4%', () {
      final pag = builder.construirPagina2(modeloBase);
      // Pos 81-97 = idx 80-96 (17 chars)
      final campo = pag.substring(80, 97);
      // c01 = 10000.00 → "00000000001000000"
      expect(campo, equals(builder.formatearN(10000.00)));
    });

    test('Campo [05] en posición 217-233 contiene base 21%', () {
      final pag = builder.construirPagina2(modeloBase);
      final campo = pag.substring(216, 233);
      expect(campo, equals(builder.formatearN(150000.00)));
    });

    test('Campo [34] total cuotas IVA en posición 1628-1644', () {
      final pag = builder.construirPagina2(modeloBase);
      final campo = pag.substring(1627, 1644);
      // c47 = c02 + c04 + c06 = 400 + 2500 + 31500 = 34400
      expect(campo, equals(builder.formatearN(34400.00)));
    });
  });

  // ─── Codificación ISO-8859-1 ──────────────────────────────────────────────

  group('codificarISO88591', () {
    test('Caracteres ASCII normales se codifican correctamente', () {
      final bytes = builder.codificarISO88591('ABC123');
      expect(bytes, equals([65, 66, 67, 49, 50, 51]));
    });

    test('Longitud de bytes = longitud de cadena para ASCII', () {
      const texto = 'EMPRESA TEST SL';
      final bytes = builder.codificarISO88591(texto);
      expect(bytes.length, equals(texto.length));
    });
  });

  // ─── Datos en Página 1 ────────────────────────────────────────────────────

  group('Página 1 — datos del sujeto pasivo', () {
    test('NIF en posiciones 14-22 (idx 13-21)', () {
      final pag = builder.construirPagina1(
        nif: 'B12345678',
        razonSocial: 'TEST SL',
        ejercicio: 2025,
      );
      final nifExtraido = pag.substring(13, 22);
      expect(nifExtraido, equals('B12345678'));
    });

    test('Razón social en posiciones 23-82 (idx 22-81), 60 chars', () {
      final pag = builder.construirPagina1(
        nif: 'B12345678',
        razonSocial: 'EMPRESA EJEMPLO',
        ejercicio: 2025,
      );
      final razonSocial = pag.substring(22, 82);
      expect(razonSocial.length, equals(60));
      expect(razonSocial.startsWith('EMPRESA EJEMPLO'), isTrue);
      expect(razonSocial.trimRight(), equals('EMPRESA EJEMPLO'));
    });

    test('Ejercicio en posiciones 103-106 (idx 102-105)', () {
      final pag = builder.construirPagina1(
        nif: 'B12345678',
        razonSocial: 'TEST',
        ejercicio: 2025,
      );
      expect(pag.substring(102, 106), equals('2025'));
    });
  });

  // ─── Página 6 — liquidación ────────────────────────────────────────────────

  group('Página 6 — resultado liquidación', () {
    test('Campo [86] resultado liquidación en posición 81-97 (idx 80-96)', () {
      final pag = builder.construirPagina6(modeloBase);
      // c86 = c84 - c85 = c65 - 0 = c47 - c64 = 34400 - 18000 = 16400
      final campo = pag.substring(80, 97);
      final c86 = modeloBase.c86;
      expect(campo, equals(builder.formatearN(c86)));
    });

    test('Volumen operaciones [99] en posición 361-377 (idx 360-376)', () {
      final pag = builder.construirPagina6(modeloBase);
      final campo = pag.substring(360, 377);
      expect(campo, equals(builder.formatearN(185000.00)));
    });
  });
}

