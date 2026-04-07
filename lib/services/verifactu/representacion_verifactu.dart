enum ModeloRepresentacionVerifactu {
  anexoI,
  anexoII,
  anexoIII,
}

enum TipoInterviniente {
  obligadoTributario,
  empresaSoftware,
  profesionalTributario,
}

enum TipoOtorgante {
  personaFisica,
  personaJuridica,
}

enum TipoCanalEnvio {
  propio,
  softwareDirecto,
  gestoriaDirecto,
  softwareBajoGestoria,
}

class DocumentoRepresentacionVerifactu {
  final ModeloRepresentacionVerifactu modelo;
  final String nifOtorgante;
  final String nifRepresentante;
  final TipoOtorgante tipoOtorgante;
  final DateTime fechaFirma;
  final DateTime? fechaRevocacion;

  // Reglas de validez de la Resolucion 18-dic-2024.
  final bool textoNormalizadoIntegro;
  final bool documentacionAdjunta;
  final bool permiteSubdelegacion;
  final bool softwareNotificadoAlCliente;

  const DocumentoRepresentacionVerifactu({
    required this.modelo,
    required this.nifOtorgante,
    required this.nifRepresentante,
    required this.tipoOtorgante,
    required this.fechaFirma,
    this.fechaRevocacion,
    this.textoNormalizadoIntegro = true,
    this.documentacionAdjunta = true,
    this.permiteSubdelegacion = false,
    this.softwareNotificadoAlCliente = false,
  });

  bool get estaRevocado =>
      fechaRevocacion != null && !fechaRevocacion!.isAfter(DateTime.now());
}

class ContextoEnvioVerifactu {
  final String nifObligado;
  final String nifEnviador;
  final TipoCanalEnvio canal;
  final String? nifGestoria;

  const ContextoEnvioVerifactu({
    required this.nifObligado,
    required this.nifEnviador,
    required this.canal,
    this.nifGestoria,
  });
}

class ResultadoValidacionRepresentacion {
  final bool valido;
  final List<String> errores;
  final List<String> defectosSubsanables;

  const ResultadoValidacionRepresentacion({
    required this.valido,
    required this.errores,
    required this.defectosSubsanables,
  });

  bool get requiereSubsanacion10Dias =>
      !valido && errores.isEmpty && defectosSubsanables.isNotEmpty;
}

class ValidadorRepresentacionVerifactu {
  static ResultadoValidacionRepresentacion validarAntesDeEnviar({
    required ContextoEnvioVerifactu contexto,
    required List<DocumentoRepresentacionVerifactu> documentos,
  }) {
    final errores = <String>[];
    final subsanables = <String>[];

    if (contexto.canal == TipoCanalEnvio.propio) {
      // Envio del propio obligado: no requiere representacion.
      if (contexto.nifObligado != contexto.nifEnviador) {
        errores.add(
          'Canal propio inconsistente: el NIF enviador no coincide con el obligado.',
        );
      }
      return ResultadoValidacionRepresentacion(
        valido: errores.isEmpty,
        errores: errores,
        defectosSubsanables: subsanables,
      );
    }

    for (final d in documentos) {
      if (!d.textoNormalizadoIntegro) {
        errores.add(
          'El texto del modelo normalizado ha sido modificado (${d.modelo.name}).',
        );
      }
      if (d.estaRevocado) {
        errores.add('El documento ${d.modelo.name} esta revocado.');
      }
      if (d.tipoOtorgante == TipoOtorgante.personaJuridica && !d.documentacionAdjunta) {
        subsanables.add(
          'Falta documentacion acreditativa del representante legal (${d.modelo.name}).',
        );
      }
    }

    switch (contexto.canal) {
      case TipoCanalEnvio.softwareDirecto:
        _validarSoftwareDirecto(contexto, documentos, errores, subsanables);
        break;
      case TipoCanalEnvio.gestoriaDirecto:
        _validarGestoriaDirecto(contexto, documentos, errores);
        break;
      case TipoCanalEnvio.softwareBajoGestoria:
        _validarSoftwareBajoGestoria(contexto, documentos, errores, subsanables);
        break;
      case TipoCanalEnvio.propio:
        break;
    }

    return ResultadoValidacionRepresentacion(
      valido: errores.isEmpty && subsanables.isEmpty,
      errores: errores,
      defectosSubsanables: subsanables,
    );
  }

  static void _validarSoftwareDirecto(
    ContextoEnvioVerifactu contexto,
    List<DocumentoRepresentacionVerifactu> docs,
    List<String> errores,
    List<String> subsanables,
  ) {
    final anexoI = docs.where((d) => d.modelo == ModeloRepresentacionVerifactu.anexoI).toList();
    if (anexoI.isEmpty) {
      errores.add('Falta Anexo I para envio software directo en nombre de tercero.');
      return;
    }

    final valido = anexoI.any(
      (d) => d.nifOtorgante == contexto.nifObligado && d.nifRepresentante == contexto.nifEnviador,
    );
    if (!valido) {
      errores.add('Anexo I no coincide con obligado/enviador del envio.');
    }

    if (anexoI.any((d) => !d.documentacionAdjunta)) {
      subsanables.add('Anexo I sin documentacion completa. Subsanable en 10 dias.');
    }
  }

  static void _validarGestoriaDirecto(
    ContextoEnvioVerifactu contexto,
    List<DocumentoRepresentacionVerifactu> docs,
    List<String> errores,
  ) {
    final anexoII = docs.where((d) => d.modelo == ModeloRepresentacionVerifactu.anexoII).toList();
    if (anexoII.isEmpty) {
      errores.add('Falta Anexo II para envio directo por gestoria.');
      return;
    }

    final valido = anexoII.any(
      (d) => d.nifOtorgante == contexto.nifObligado && d.nifRepresentante == contexto.nifEnviador,
    );
    if (!valido) {
      errores.add('Anexo II no coincide con obligado/gestoria enviadora.');
    }
  }

  static void _validarSoftwareBajoGestoria(
    ContextoEnvioVerifactu contexto,
    List<DocumentoRepresentacionVerifactu> docs,
    List<String> errores,
    List<String> subsanables,
  ) {
    final anexoII = docs.where((d) => d.modelo == ModeloRepresentacionVerifactu.anexoII).toList();
    final anexoIII = docs.where((d) => d.modelo == ModeloRepresentacionVerifactu.anexoIII).toList();

    if (anexoII.isEmpty || anexoIII.isEmpty) {
      errores.add('Falta cadena completa de representacion (Anexo II + Anexo III).');
      return;
    }

    if (contexto.nifGestoria == null || contexto.nifGestoria!.isEmpty) {
      errores.add('Canal softwareBajoGestoria requiere nifGestoria en el contexto.');
      return;
    }

    final iiValido = anexoII.any(
      (d) => d.nifOtorgante == contexto.nifObligado &&
          d.nifRepresentante == contexto.nifGestoria &&
          d.permiteSubdelegacion,
    );
    if (!iiValido) {
      errores.add('Anexo II invalido o sin autorizacion de subdelegacion.');
    }

    final iiiValido = anexoIII.any(
      (d) => d.nifOtorgante == contexto.nifGestoria && d.nifRepresentante == contexto.nifEnviador,
    );
    if (!iiiValido) {
      errores.add('Anexo III invalido para la subdelegacion gestoria -> software.');
    }

    if (!anexoII.any((d) => d.softwareNotificadoAlCliente)) {
      subsanables.add(
        'Falta constancia de que la gestoria informo al cliente del software subdelegado.',
      );
    }
  }
}

