import 'package:url_launcher/url_launcher.dart';

/// URLs oficiales de la Sede Electrónica de la AEAT para presentación de modelos.
class SedeAeatUrls {
  SedeAeatUrls._();

  // ── Modelos trimestrales ──────────────────────────────────────────────────

  /// Modelo 303 — Autoliquidación IVA (Pre303 online, NO admite fichero desde 2023)
  static const mod303 =
      'https://www1.agenciatributaria.gob.es/wlpl/BUGC-JDIT/VentanaCensalIva?forigen=pre303';

  /// Modelo 130 — Pago fraccionado IRPF autónomos (Pre130 online)
  static const mod130 =
      'https://www1.agenciatributaria.gob.es/wlpl/BUGC-JDIT/VentanaCensalIrpf?forigen=pre130';

  /// Modelo 111 — Retenciones IRPF (admite fichero TXT DR111e16v18)
  static const mod111 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/GI00.shtml';

  /// Modelo 115 — Retenciones arrendamientos (admite fichero TXT DR115e15v13)
  static const mod115 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/GI05.shtml';

  /// Modelo 202 — Pago fraccionado IS sociedades (presentación online)
  static const mod202 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/G621.shtml';

  // ── Modelos anuales ───────────────────────────────────────────────────────

  /// Modelo 390 — Resumen anual IVA (presentación online)
  static const mod390 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/G414.shtml';

  /// Modelo 347 — Operaciones con terceros >3.005,06€ (admite fichero TXT)
  static const mod347 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/G401.shtml';

  /// Modelo 190 — Resumen anual retenciones IRPF (admite fichero TXT)
  static const mod190 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/GI01.shtml';

  /// Modelo 349 — Operaciones intracomunitarias (admite fichero TXT)
  static const mod349 =
      'https://sede.agenciatributaria.gob.es/Sede/tramitacion/G403.shtml';

  // ── Helper ────────────────────────────────────────────────────────────────

  /// Abre la URL de la Sede AEAT en el navegador del sistema.
  static Future<bool> abrir(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

