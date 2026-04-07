import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/verifactu/representacion_verifactu.dart';

void main() {
  test('canal propio no requiere anexos si el enviador es el obligado', () {
    final r = ValidadorRepresentacionVerifactu.validarAntesDeEnviar(
      contexto: const ContextoEnvioVerifactu(
        nifObligado: 'B11111111',
        nifEnviador: 'B11111111',
        canal: TipoCanalEnvio.propio,
      ),
      documentos: const [],
    );

    expect(r.valido, isTrue);
    expect(r.errores, isEmpty);
  });

  test('software directo requiere anexo I valido', () {
    final r = ValidadorRepresentacionVerifactu.validarAntesDeEnviar(
      contexto: const ContextoEnvioVerifactu(
        nifObligado: 'B11111111',
        nifEnviador: 'B22222222',
        canal: TipoCanalEnvio.softwareDirecto,
      ),
      documentos: [
        DocumentoRepresentacionVerifactu(
          modelo: ModeloRepresentacionVerifactu.anexoI,
          nifOtorgante: 'B11111111',
          nifRepresentante: 'B22222222',
          tipoOtorgante: TipoOtorgante.personaJuridica,
          fechaFirma: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(r.valido, isTrue);
  });

  test('gestoria + software requiere anexo II y III', () {
    final r = ValidadorRepresentacionVerifactu.validarAntesDeEnviar(
      contexto: const ContextoEnvioVerifactu(
        nifObligado: 'B11111111',
        nifEnviador: 'B33333333',
        nifGestoria: 'B22222222',
        canal: TipoCanalEnvio.softwareBajoGestoria,
      ),
      documentos: [
        DocumentoRepresentacionVerifactu(
          modelo: ModeloRepresentacionVerifactu.anexoII,
          nifOtorgante: 'B11111111',
          nifRepresentante: 'B22222222',
          tipoOtorgante: TipoOtorgante.personaJuridica,
          fechaFirma: DateTime(2026, 1, 1),
          permiteSubdelegacion: true,
          softwareNotificadoAlCliente: true,
        ),
        DocumentoRepresentacionVerifactu(
          modelo: ModeloRepresentacionVerifactu.anexoIII,
          nifOtorgante: 'B22222222',
          nifRepresentante: 'B33333333',
          tipoOtorgante: TipoOtorgante.personaJuridica,
          fechaFirma: DateTime(2026, 1, 2),
        ),
      ],
    );

    expect(r.valido, isTrue);
  });

  test('si falta cadena II+III debe fallar', () {
    final r = ValidadorRepresentacionVerifactu.validarAntesDeEnviar(
      contexto: const ContextoEnvioVerifactu(
        nifObligado: 'B11111111',
        nifEnviador: 'B33333333',
        nifGestoria: 'B22222222',
        canal: TipoCanalEnvio.softwareBajoGestoria,
      ),
      documentos: [
        DocumentoRepresentacionVerifactu(
          modelo: ModeloRepresentacionVerifactu.anexoII,
          nifOtorgante: 'B11111111',
          nifRepresentante: 'B22222222',
          tipoOtorgante: TipoOtorgante.personaJuridica,
          fechaFirma: DateTime(2026, 1, 1),
          permiteSubdelegacion: true,
        ),
      ],
    );

    expect(r.valido, isFalse);
    expect(r.errores.join(' '), contains('Anexo II + Anexo III'));
  });
}


