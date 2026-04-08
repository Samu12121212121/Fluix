import 'modelos_verifactu.dart';
import 'politica_verifactu_2027.dart';
import 'firma_xades_minima_validator.dart';

class ValidadorVerifactu {
  static ValidacionVerifactuResultado validarRegistroAlta(
    RegistroFacturacionAlta registro,
    RegistroFacturacionAlta? registroAnterior,
    {CertificadoFirmaMinimo? certificadoFirma}
  ) {
    final errores = <String>[];
    final advertencias = <String>[];

    if (RegistroFacturacionAlta.idVersion != '1.0') {
      errores.add('HAC1177-ALTA-001: IDVersion debe ser 1.0.');
    }

    if (registroAnterior != null) {
      if (registro.registroAnterior.hash64Caracteres != registroAnterior.hash64) {
        errores.add('VERIFACTU-001: Encadenamiento roto en RegistroAlta.');
      }
    } else if (!registro.registroAnterior.esPrimerRegistro) {
      errores.add('VERIFACTU-002: Primer registro debe marcar PrimerRegistro.');
    }

    if (!_esHashValido(registro.hash)) {
      errores.add('VERIFACTU-003: Hash SHA-256 inválido en RegistroAlta.');
    }

    final requiereFirma =
        PoliticaVerifactu2027.requiereFirmaElectronica(esVerifactu: registro.esVerifactu);
    if (requiereFirma && (registro.firmaXAdES == null || registro.firmaXAdES!.trim().isEmpty)) {
      errores.add('HAC1177-ALTA-002: Signature obligatoria en NO VERI*FACTU.');
    } else if (requiereFirma) {
      final rFirma = FirmaXadesMinimaValidator.validar(
        signatureXml: registro.firmaXAdES ?? '',
        certificado: certificadoFirma,
        fechaValidacion: registro.fechaHoraGeneracion,
      );
      errores.addAll(rFirma.errores);
    }

    if (!requiereFirma && (registro.firmaXAdES ?? '').trim().isNotEmpty) {
      advertencias.add('HAC1177-ALTA-W001: Firma presente en VERI*FACTU (no obligatoria).');
    }

    if (registro.importeTotal < 0 || registro.cuotaTotal < 0) {
      errores.add('HAC1177-ALTA-003: Importe/Cuota no pueden ser negativos.');
    }

    // R6 — Precisión temporal (art. 29.2.j LGT)
    final diferenciaSegundos =
        DateTime.now().difference(registro.fechaHoraGeneracion).inSeconds.abs();
    if (diferenciaSegundos > 60) {
      errores.add(
        'VERIFACTU-005: La hora de generación difiere '
        '${(diferenciaSegundos / 60).toStringAsFixed(1)} min del reloj del sistema '
        '(máximo 1 min, art. 29.2.j LGT).',
      );
    }


    if (RegistroFacturacionAnulacion.idVersion != '1.0') {
      errores.add('HAC1177-ANU-001: IDVersion debe ser 1.0.');
    }

    if (registroAnterior != null &&
        registro.registroAnterior.hash64Caracteres != registroAnterior.hash64) {
      errores.add('VERIFACTU-A-001: Encadenamiento roto en RegistroAnulacion.');
    }

    if (!const {'E', 'D', 'T'}.contains(registro.solicitanteCodigo)) {
      errores.add('HAC1177-ANU-002: GeneradoPor inválido (usar E/D/T).');
    }

    if (!_esHashValido(registro.hash)) {
      errores.add('VERIFACTU-A-003: Hash SHA-256 inválido en RegistroAnulacion.');
    }

    return ValidacionVerifactuResultado(
      esValido: errores.isEmpty,
      errores: errores,
      advertencias: const [],
      hashCalculado: registro.hash,
      hashPrimeros64: registro.hash64,
    );
  }

  static ValidacionVerifactuResultado validarLote(int totalRegistros) {
    if (totalRegistros < 1 || totalRegistros > 1000) {
      return const ValidacionVerifactuResultado(
        esValido: false,
        errores: ['HAC1177-LOTE-001: El lote debe contener entre 1 y 1000 registros.'],
        advertencias: [],
      );
    }
    return const ValidacionVerifactuResultado(
      esValido: true,
      errores: [],
      advertencias: [],
    );
  }

  static bool _esHashValido(String hash) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(hash.toLowerCase());
  }
}

class ValidacionVerifactuResultado {
  final bool esValido;
  final List<String> errores;
  final List<String> advertencias;
  final String? hashCalculado;
  final String? hashPrimeros64;

  const ValidacionVerifactuResultado({
    required this.esValido,
    required this.errores,
    required this.advertencias,
    this.hashCalculado,
    this.hashPrimeros64,
  });
}

