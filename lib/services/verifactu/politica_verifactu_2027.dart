enum TipoObligadoVerifactu {
  impuestoSociedades,
  restoObligados,
  productorSoftware,
}

enum ModoVerifactu {
  /// Remisión automática a la AEAT — VERI*FACTU (art. 14 RD 1007/2023)
  veriFActu,
  /// Sin remisión automática — firma electrónica obligatoria (art. 12)
  noVeriFActu,
}

class PoliticaVerifactu2027 {
  // Plazos vigentes tras RDL 15/2025 (diciembre 2025).
  static final DateTime fechaLimiteImpuestoSociedades = DateTime(2027, 1, 1);
  static final DateTime fechaLimiteRestoObligados = DateTime(2027, 7, 1);
  static final DateTime fechaLimiteProductorSoftware = DateTime(2025, 7, 28);

  /// Modo actual — configurable por empresa en Firestore.
  /// Por defecto VERI*FACTU (remisión automática).
  static ModoVerifactu _modoActual = ModoVerifactu.veriFActu;

  static ModoVerifactu get modoActual => _modoActual;

  /// Permite cambiar el modo (llamar al arrancar la app según config).
  static void setModo(ModoVerifactu modo) => _modoActual = modo;

  /// Devuelve la fecha límite de adaptación para el tipo de obligado.
  static DateTime fechaLimiteAdaptacion(TipoObligadoVerifactu tipo) {
    switch (tipo) {
      case TipoObligadoVerifactu.impuestoSociedades:
        return fechaLimiteImpuestoSociedades;
      case TipoObligadoVerifactu.restoObligados:
        return fechaLimiteRestoObligados;
      case TipoObligadoVerifactu.productorSoftware:
        return fechaLimiteProductorSoftware;
    }
  }

  /// Art. 4.1 RD 1007/2023: empresas en SII quedan excluidas del reglamento.
  static bool estaExcluidoPorSii({required bool llevaLibrosPorSii}) {
    return llevaLibrosPorSii;
  }

  /// Art. 12 + art. 16.3: firma obligatoria solo en NO VERI*FACTU.
  static bool requiereFirmaElectronica({required bool esVerifactu}) {
    return !esVerifactu;
  }

  static bool requiereRemisionAutomaticaAeat({required bool esVerifactu}) {
    return esVerifactu;
  }
}
