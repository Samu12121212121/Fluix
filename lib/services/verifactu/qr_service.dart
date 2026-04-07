import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Genera URLs e imágenes QR para Verifactu.
///
/// Normativa: art. 6.5 RD 1619/2012 + Orden HAC/1177/2024
/// - Tamaño: entre 30 mm y 40 mm (128 px ≈ 34 mm a 96 DPI)
/// - Nivel de corrección: M (15 %)
class QrService {
  static const String _urlBaseAeat =
      'https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR';

  /// Nivel de corrección M obligatorio según HAC/1177/2024
  static const int _nivelCorreccion = QrErrorCorrectLevel.M;

  /// Tamaño en px: ~128 px ≈ 34 mm a 96 DPI
  static const double _tamanoQrPx = 128.0;

  // ── URL ──────────────────────────────────────────────────────────────────

  /// Genera la URL del QR con los 4 campos obligatorios.
  ///
  /// Formato fecha: dd-MM-yyyy (Orden HAC/1177/2024 Bloque 11)
  String generarUrl({
    required String nifEmisor,
    required String serie,
    required String numero,
    required DateTime fecha,
    required double importeTotal,
  }) {
    final params = {
      'nif': nifEmisor,
      'numserie': '$serie$numero',
      'fecha': _formatearFecha(fecha),
      'importe': importeTotal.toStringAsFixed(2),
    };
    return Uri.parse(_urlBaseAeat)
        .replace(queryParameters: params)
        .toString();
  }

  // ── IMAGEN ────────────────────────────────────────────────────────────────

  /// Genera la imagen QR como bytes PNG.
  ///
  /// En web devuelve [Uint8List] vacío — usar el widget [QrImageView] directamente.
  Future<Uint8List> generarImagenQr(String url) async {
    if (kIsWeb) {
      // En web QrPainter.toImageData no está disponible;
      // la UI usa el widget QrImageView.
      return Uint8List(0);
    }

    final qrPainter = QrPainter(
      data: url,
      version: QrVersions.auto,
      errorCorrectionLevel: _nivelCorreccion,
      gapless: true,
    );

    final byteData = await qrPainter.toImageData(_tamanoQrPx);
    if (byteData == null) {
      throw Exception('QrService: error generando imagen PNG del QR');
    }
    return byteData.buffer.asUint8List();
  }

  // ── TEXTO LEGAL ───────────────────────────────────────────────────────────

  /// Texto obligatorio en facturas VERI*FACTU (art. 9 RD 1007/2023).
  static String get textoLegalVerifactu =>
      'Factura verificable en la sede electrónica de la AEAT (VERI*FACTU)';

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.year}';
  }
}

