import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/verifactu/politica_verifactu_2027.dart';

void main() {
  test('plazos vigentes 2027 se exponen correctamente', () {
    expect(
      PoliticaVerifactu2027.fechaLimiteAdaptacion(
        TipoObligadoVerifactu.impuestoSociedades,
      ),
      DateTime(2027, 1, 1),
    );
    expect(
      PoliticaVerifactu2027.fechaLimiteAdaptacion(
        TipoObligadoVerifactu.restoObligados,
      ),
      DateTime(2027, 7, 1),
    );
    expect(
      PoliticaVerifactu2027.fechaLimiteAdaptacion(
        TipoObligadoVerifactu.productorSoftware,
      ),
      DateTime(2025, 7, 28),
    );
  });

  test('SII excluye totalmente del reglamento', () {
    expect(
      PoliticaVerifactu2027.estaExcluidoPorSii(llevaLibrosPorSii: true),
      isTrue,
    );
    expect(
      PoliticaVerifactu2027.estaExcluidoPorSii(llevaLibrosPorSii: false),
      isFalse,
    );
  });

  test('firma electronica solo en NO VERI*FACTU', () {
    expect(
      PoliticaVerifactu2027.requiereFirmaElectronica(esVerifactu: true),
      isFalse,
    );
    expect(
      PoliticaVerifactu2027.requiereFirmaElectronica(esVerifactu: false),
      isTrue,
    );
  });
}

