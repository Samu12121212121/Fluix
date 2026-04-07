/// Generador de código QR según RD 1007/2023 art. 6.5 + RD 1619/2012
/// 
/// Requisitos:
/// - Tamaño: 30-40 mm (1181-1575 pixels a 300 DPI)
/// - Norma: ISO/IEC 18004
/// - Corrección de errores: M (15%)
/// - Contenido: URL AEAT + NIF + serie/nº + fecha + importe total

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GeneradorCodigoQrVerifactu {
  /// URL base del servicio de cotejo AEAT (será proporcionado en documentación oficial)
  static const String urlBaseAeat = 'https://cotejoadministrativo.aeat.es/verifactu';

  /// Genera un Widget QR listo para incrustar en la UI o PDF.
  ///
  /// Tamaño por defecto: 200px (ajustar según impresión).
  /// Corrección de errores: Nivel M (15%) según requisitos AEAT.
  static Widget generarWidgetQr({
    required String nifEmisor,
    required String numeroSerie,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double importeTotal,
    double size = 200.0,
  }) {
    final url = obtenerUrlQr(
      nifEmisor,
      numeroSerie,
      numeroFactura,
      fechaExpedicion,
      importeTotal,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: url,
          version: QrVersions.auto,
          size: size,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          gapless: true,
          embeddedImageStyle: null,
        ),
        const SizedBox(height: 6),
        Text(
          obtenerTextoLegalVerifactu(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 8, color: Colors.black54),
        ),
      ],
    );
  }

  /// Convierte los parámetros a la URL que codifica el QR.
  static String obtenerUrlQr(
    String nifEmisor,
    String numeroSerie,
    String numeroFactura,
    DateTime fechaExpedicion,
    double importeTotal,
  ) {
    final numeroCompleto = numeroSerie + numeroFactura;
    final fechaStr =
        '${fechaExpedicion.year}${fechaExpedicion.month.toString().padLeft(2, '0')}${fechaExpedicion.day.toString().padLeft(2, '0')}';
    final importeStr = (importeTotal * 100).toInt().toString();

    return '$urlBaseAeat'
        '?nif=${Uri.encodeComponent(nifEmisor)}'
        '&numero=${Uri.encodeComponent(numeroCompleto)}'
        '&fecha=$fechaStr'
        '&importe=$importeStr';
  }

  /// Texto legal obligatorio para facturas VERI*FACTU
  static String obtenerTextoLegalVerifactu() {
    return 'Factura verificable en la sede electrónica de la AEAT (VERI*FACTU)';
  }
}



