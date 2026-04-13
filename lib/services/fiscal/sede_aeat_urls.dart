import 'package:url_launcher/url_launcher.dart';

/// URLs oficiales de la Sede Electrónica de la AEAT para presentación de modelos.
class SedeAeatUrls {
  SedeAeatUrls._();

  static const _base =
      'https://sede.agenciatributaria.gob.es/Sede/procedimientos-servicios/modelos-formularios/declaraciones';

  // ── Modelos trimestrales ──────────────────────────────────────────────────

  /// Modelo 303 — Autoliquidación IVA
  static const mod303 = '$_base/modelo-303.html';

  /// Modelo 130 — Pago fraccionado IRPF autónomos
  static const mod130 = '$_base/modelo-130.html';

  /// Modelo 111 — Retenciones IRPF (admite fichero TXT DR111e16v18)
  static const mod111 = '$_base/modelo-111.html';

  /// Modelo 115 — Retenciones arrendamientos (admite fichero TXT DR115e15v13)
  static const mod115 = '$_base/modelo-115.html';

  /// Modelo 202 — Pago fraccionado IS sociedades
  static const mod202 = '$_base/modelo-202.html';

  // ── Modelos anuales ───────────────────────────────────────────────────────

  /// Modelo 390 — Resumen anual IVA
  static const mod390 = '$_base/modelo-390.html';

  /// Modelo 347 — Operaciones con terceros >3.005,06€ (admite fichero TXT)
  static const mod347 = '$_base/modelo-347.html';

  /// Modelo 190 — Resumen anual retenciones IRPF (admite fichero TXT)
  static const mod190 = '$_base/modelo-190.html';

  /// Modelo 349 — Operaciones intracomunitarias (admite fichero TXT)
  static const mod349 = '$_base/modelo-349.html';

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
