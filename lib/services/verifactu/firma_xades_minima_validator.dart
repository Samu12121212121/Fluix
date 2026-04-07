/// Resultado de la validación mínima de firma XAdES.
class ResultadoValidacionFirma {
  final bool valida;
  final List<String> errores;

  const ResultadoValidacionFirma({
    required this.valida,
    required this.errores,
  });
}

/// Representación mínima del certificado necesaria para validar la firma.
class CertificadoFirmaMinimo {
  final String subject;
  final String issuer;
  final String serialNumber;
  final DateTime notBefore;
  final DateTime notAfter;

  const CertificadoFirmaMinimo({
    required this.subject,
    required this.issuer,
    required this.serialNumber,
    required this.notBefore,
    required this.notAfter,
  });

  /// Comprueba si el certificado está vigente en la fecha dada.
  bool esVigenteEn(DateTime fecha) {
    return !fecha.isBefore(notBefore) && !fecha.isAfter(notAfter);
  }
}

class FirmaXadesMinimaValidator {
  /// Validacion minima previa a envio AEAT para NO VERI*FACTU.
  ///
  /// Comprueba formato XAdES basico y certificado minimo:
  /// - Bloque Signature presente y no vacio.
  /// - SignedInfo y SignatureValue presentes.
  /// - Certificado informado y vigente.
  static ResultadoValidacionFirma validar({
    required String signatureXml,
    required CertificadoFirmaMinimo? certificado,
    DateTime? fechaValidacion,
  }) {
    final errores = <String>[];
    final ahora = fechaValidacion ?? DateTime.now();

    final firma = signatureXml.trim();
    if (firma.isEmpty) {
      errores.add('HAC1177-FIRMA-001: Signature vacia.');
      return ResultadoValidacionFirma(valida: false, errores: errores);
    }

    if (!firma.contains('<Signature') || !firma.contains('</Signature>')) {
      errores.add('HAC1177-FIRMA-002: Bloque Signature malformado.');
    }

    if (!firma.contains('<SignedInfo') || !firma.contains('</SignedInfo>')) {
      errores.add('HAC1177-FIRMA-003: Falta bloque SignedInfo.');
    }

    if (!firma.contains('<SignatureValue') || !firma.contains('</SignatureValue>')) {
      errores.add('HAC1177-FIRMA-004: Falta bloque SignatureValue.');
    }

    if (certificado == null) {
      errores.add('HAC1177-FIRMA-005: Falta certificado para NO VERI*FACTU.');
    } else {
      if (certificado.subject.trim().isEmpty ||
          certificado.issuer.trim().isEmpty ||
          certificado.serialNumber.trim().isEmpty) {
        errores.add('HAC1177-FIRMA-006: Certificado minimo incompleto.');
      }
      if (!certificado.esVigenteEn(ahora)) {
        errores.add('HAC1177-FIRMA-007: Certificado no vigente en fecha de firma.');
      }
    }

    return ResultadoValidacionFirma(
      valida: errores.isEmpty,
      errores: errores,
    );
  }
}
