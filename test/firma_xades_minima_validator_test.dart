import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/verifactu/firma_xades_minima_validator.dart';

void main() {
  test('firma NO VERI*FACTU valida formato y certificado vigente', () {
    const firma = '<Signature><SignedInfo></SignedInfo><SignatureValue>abc</SignatureValue></Signature>';
    final cert = CertificadoFirmaMinimo(
      subject: 'CN=Empresa',
      issuer: 'CN=CA',
      serialNumber: '123',
      notBefore: DateTime(2025, 1, 1),
      notAfter: DateTime(2027, 12, 31),
    );

    final r = FirmaXadesMinimaValidator.validar(
      signatureXml: firma,
      certificado: cert,
      fechaValidacion: DateTime(2026, 3, 20),
    );

    expect(r.valida, isTrue);
    expect(r.errores, isEmpty);
  });

  test('falla si certificado esta caducado', () {
    const firma = '<Signature><SignedInfo></SignedInfo><SignatureValue>abc</SignatureValue></Signature>';
    final cert = CertificadoFirmaMinimo(
      subject: 'CN=Empresa',
      issuer: 'CN=CA',
      serialNumber: '123',
      notBefore: DateTime(2020, 1, 1),
      notAfter: DateTime(2021, 1, 1),
    );

    final r = FirmaXadesMinimaValidator.validar(
      signatureXml: firma,
      certificado: cert,
      fechaValidacion: DateTime(2026, 3, 20),
    );

    expect(r.valida, isFalse);
    expect(r.errores.join(' '), contains('no vigente'));
  });
}

