// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO GENERADOR DE QR VERIFACTU - Fluix CRM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Genera códigos QR para facturas según la Orden HAC/1177/2024
// 
// URL de verificación AEAT:
// https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR
//
// Parámetros obligatorios:
// - nif: NIF del emisor
// - num: Número de factura
// - fec: Fecha de expedición (DD-MM-YYYY)
// - imp: Importe total con 2 decimales
// - id: ID de instalación del software
//
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class QrVerifactuService {
  
  /// URL base de verificación de la AEAT
  static const String URL_VALIDACION_AEAT = 'https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR';
  
  /// Genera la URL del QR según especificación AEAT
  /// 
  /// Formato: https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR?
  ///          nif={NIF_EMISOR}&num={NUMERO}&fec={FECHA}&imp={IMPORTE}&id={ID_INSTALACION}
  String generarUrlQr({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
  }) {
    // Formato fecha: DD-MM-YYYY
    final fechaStr = DateFormat('dd-MM-yyyy').format(fechaExpedicion);
    
    // Formato importe: con 2 decimales y punto como separador
    final importeStr = totalFactura.toStringAsFixed(2);
    
    // Codificar parámetros para URL
    final nifEncoded = Uri.encodeComponent(nifEmisor);
    final numEncoded = Uri.encodeComponent(numeroFactura);
    final idEncoded = Uri.encodeComponent(idInstalacion);
    
    // Construir URL completa
    final url = '$URL_VALIDACION_AEAT'
        '?nif=$nifEncoded'
        '&num=$numEncoded'
        '&fec=$fechaStr'
        '&imp=$importeStr'
        '&id=$idEncoded';
    
    return url;
  }
  
  /// Genera el widget QR para mostrar en pantalla
  /// 
  /// Uso:
  /// ```dart
  /// QrVerifactuService().generarQrWidget(
  ///   nifEmisor: 'B26997528',
  ///   numeroFactura: '2026/00001',
  ///   fechaExpedicion: DateTime.now(),
  ///   totalFactura: 121.00,
  ///   idInstalacion: 'INST-001',
  /// )
  /// ```
  Widget generarQrWidget({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
    double size = 150.0,
    bool mostrarLeyenda = true,
  }) {
    final url = generarUrlQr(
      nifEmisor: nifEmisor,
      numeroFactura: numeroFactura,
      fechaExpedicion: fechaExpedicion,
      totalFactura: totalFactura,
      idInstalacion: idInstalacion,
    );
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Encabezado "VERI*FACTU" (obligatorio)
        if (mostrarLeyenda) ...[
          const Text(
            'VERI*FACTU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Código QR
        QrImageView(
          data: url,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          padding: const EdgeInsets.all(8),
        ),
        
        // Leyenda explicativa (obligatoria)
        if (mostrarLeyenda) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sistema de verificación de facturas',
              style: TextStyle(
                fontSize: 9,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Escanea para verificar autenticidad',
              style: TextStyle(
                fontSize: 8,
                color: Colors.black38,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
  
  /// Genera el QR como imagen para incluir en PDF
  /// 
  /// Retorna un Uint8List con la imagen PNG del QR
  /// Útil para la librería `pdf` de Flutter
  Future<Uint8List?> generarQrBytes({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
    int size = 150,
  }) async {
    final url = generarUrlQr(
      nifEmisor: nifEmisor,
      numeroFactura: numeroFactura,
      fechaExpedicion: fechaExpedicion,
      totalFactura: totalFactura,
      idInstalacion: idInstalacion,
    );
    
    try {
      // Generar QR Code
      final qrCode = QrCode.fromData(
        data: url,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      
      // Renderizar como imagen
      final qrPainter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );
      
      // NOTA: Para convertir realmente a bytes, necesitas usar:
      // - package:image para convertir el painter a PNG
      // - o renderizar el widget a una imagen con ui.PictureRecorder
      //
      // Ejemplo con PictureRecorder (avanzado):
      // final recorder = ui.PictureRecorder();
      // final canvas = Canvas(recorder);
      // qrPainter.paint(canvas, Size(size.toDouble(), size.toDouble()));
      // final picture = recorder.endRecording();
      // final img = await picture.toImage(size, size);
      // final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      // return byteData?.buffer.asUint8List();
      
      // Por ahora, retornamos null (implementar según necesidad)
      return null;
      
    } catch (e) {
      debugPrint('⚠️ [QR] Error generando QR bytes: $e');
      return null;
    }
  }
  
  /// Widget completo de factura con QR (para mostrar en pantalla)
  Widget buildSeccionQrFactura({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
    required String nombreFabricante,
    required String nombreSoftware,
    required String versionSoftware,
    required String nifFabricante,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // QR Code con leyenda
          generarQrWidget(
            nifEmisor: nifEmisor,
            numeroFactura: numeroFactura,
            fechaExpedicion: fechaExpedicion,
            totalFactura: totalFactura,
            idInstalacion: idInstalacion,
            size: 140,
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          // Texto legal obligatorio
          Text(
            'Esta factura ha sido expedida mediante un sistema informático de facturación '
            'que cumple con el Reglamento por el que se regulan las obligaciones de facturación '
            '(RD 1007/2023 modificado por RD 254/2025).',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.justify,
          ),
          
          const SizedBox(height: 12),
          
          // Información del software
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.computer, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Software de Facturación',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Software:', '$nombreSoftware v$versionSoftware'),
                _buildInfoRow('Fabricante:', nombreFabricante),
                _buildInfoRow('NIF Fabricante:', nifFabricante),
                _buildInfoRow('ID Instalación:', idInstalacion),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Helper para construir filas de información
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Valida que los datos del QR sean correctos
  bool validarDatosQr({
    required String nifEmisor,
    required String numeroFactura,
    required double totalFactura,
  }) {
    // NIF debe tener formato válido (simplificado)
    if (nifEmisor.isEmpty || nifEmisor.length < 9) {
      return false;
    }
    
    // Número de factura no puede estar vacío
    if (numeroFactura.isEmpty) {
      return false;
    }
    
    // Total debe ser positivo
    if (totalFactura < 0) {
      return false;
    }
    
    return true;
  }
  
  /// Genera un resumen de verificación para logging
  String generarResumenVerificacion({
    required String nifEmisor,
    required String numeroFactura,
    required DateTime fechaExpedicion,
    required double totalFactura,
    required String idInstalacion,
  }) {
    final url = generarUrlQr(
      nifEmisor: nifEmisor,
      numeroFactura: numeroFactura,
      fechaExpedicion: fechaExpedicion,
      totalFactura: totalFactura,
      idInstalacion: idInstalacion,
    );
    
    return '''
═══════════════════════════════════════════════════════════
QR VERIFACTU GENERADO
═══════════════════════════════════════════════════════════
NIF Emisor:     $nifEmisor
Nº Factura:     $numeroFactura
Fecha:          ${DateFormat('dd/MM/yyyy').format(fechaExpedicion)}
Importe Total:  ${totalFactura.toStringAsFixed(2)}€
ID Instalación: $idInstalacion
───────────────────────────────────────────────────────────
URL Verificación:
$url
═══════════════════════════════════════════════════════════
''';
  }
}

