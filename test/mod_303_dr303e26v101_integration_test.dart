import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/exportadores_aeat/dr303e26v101_exporter.dart';

void main() {
  test('dr303e26v101_exporter genera envolvente y paginas correctamente', () {
    final exporter = Dr303e26v101Exporter();
    final txt = exporter.exportar(
      const DatosDr303e26v101(
        nifDeclarante: 'B76543210',
        nombreRazonSocial: 'EMPRESA TEST',
        ejercicio: 2026,
        periodo: '1T',
        casillas: {
          '04': 1000,
          '06': 210,
          '46': 210,
          '47': 50,
          '71': 160,
        },
      ),
    );

    expect(txt.contains('<T30302026'), isTrue);
    expect(txt.contains('<AUX>'), isTrue);
    expect(txt.contains('</T303020261T0000>'), isTrue);
  });
}


