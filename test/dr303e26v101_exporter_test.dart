import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/exportadores_aeat/dr303e26v101_exporter.dart';

void main() {
  test('genera envolvente, pagina 01 y pagina 03 con cabeceras correctas', () {
    final exporter = Dr303e26v101Exporter();
    final txt = exporter.exportar(
      const DatosDr303e26v101(
        nifDeclarante: 'B76543210',
        nombreRazonSocial: 'EMPRESA TEST SL',
        ejercicio: 2026,
        periodo: '1T',
        casillas: {
          '04': 1000,
          '06': 210,
          '20': 50,
          '46': 210,
          '47': 50,
          '71': 160,
        },
      ),
    );

    expect(txt.contains('<T30302026'), isTrue);
    expect(txt.contains('<AUX>'), isTrue);
    expect(txt.contains('<T30301000>'), isTrue);
    expect(txt.contains('<T30303000>'), isTrue);
    expect(txt.contains('</T303020261T0000>'), isTrue);
  });

  test('formatea campos N negativos con prefijo N', () {
    final exporter = Dr303e26v101Exporter();
    final txt = exporter.exportar(
      const DatosDr303e26v101(
        nifDeclarante: 'B76543210',
        nombreRazonSocial: 'EMPRESA TEST SL',
        ejercicio: 2026,
        periodo: '03',
        casillas: {
          '108': -123.45,
        },
      ),
    );

    expect(txt.contains('N0000000000012345'), isTrue);
  });

  test('valida periodo no permitido', () {
    final exporter = Dr303e26v101Exporter();

    expect(
      () => exporter.exportar(
        const DatosDr303e26v101(
          nifDeclarante: 'B76543210',
          nombreRazonSocial: 'EMPRESA TEST SL',
          ejercicio: 2026,
          periodo: '13',
        ),
      ),
      throwsFormatException,
    );
  });
}

