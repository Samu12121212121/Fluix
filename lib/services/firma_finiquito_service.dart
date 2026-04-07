import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/finiquito.dart';
import 'finiquito_pdf_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE FIRMA TÁCTIL DEL FINIQUITO
// ═══════════════════════════════════════════════════════════════════════════════

class FirmaFiniquitoService {
  static final FirmaFiniquitoService _i = FirmaFiniquitoService._();
  factory FirmaFiniquitoService() => _i;
  FirmaFiniquitoService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── REF ────────────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _ref(
          String empresaId, String finiquitoId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('finiquitos')
          .doc(finiquitoId);

  // ═══════════════════════════════════════════════════════════════════════════
  // GUARDAR FIRMA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sube la firma PNG a Firebase Storage.
  /// Devuelve la URL pública del archivo.
  Future<String> guardarFirma({
    required String empresaId,
    required String finiquitoId,
    required Uint8List firmaBytes,
    required String empleadoNombre,
  }) async {
    final path = 'empresas/$empresaId/finiquitos/firmas/'
        'firma_${finiquitoId}_${DateTime.now().millisecondsSinceEpoch}.png';

    final ref = _storage.ref().child(path);
    await ref.putData(firmaBytes, SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGENERAR PDF CON FIRMA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Regenera el PDF del finiquito incluyendo la firma y lo sube a Storage.
  Future<String> regenerarPDFConFirma({
    required Finiquito finiquito,
    required String firmaUrl,
    required Uint8List firmaBytes,
    required String ciudad,
  }) async {
    final pdfBytes = await FiniquitoPdfService.generarConFirma(
      finiquito,
      firmaBytes: firmaBytes,
      ciudad: ciudad,
    );

    final path = 'empresas/${finiquito.empresaId}/finiquitos/pdfs/'
        'finiquito_firmado_${finiquito.id}.pdf';
    final ref = _storage.ref().child(path);
    await ref.putData(pdfBytes,
        SettableMetadata(contentType: 'application/pdf'));
    return await ref.getDownloadURL();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARCAR COMO FIRMADO (INMUTABLE)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Marca el finiquito como firmado y registra todos los metadatos.
  /// Una vez firmado, el documento es inmutable.
  Future<void> marcarComoFirmado({
    required String empresaId,
    required String finiquitoId,
    required String firmaUrl,
    required String pdfFirmadoUrl,
    required String firmaUid,
    String? geolocalizacion,
  }) async {
    final doc = await _ref(empresaId, finiquitoId).get();
    if (!doc.exists) throw Exception('Finiquito no encontrado');

    // Verificar que no esté ya firmado
    if (doc.data()?['firmado'] == true) {
      throw Exception('El finiquito ya está firmado y no puede modificarse');
    }

    await _ref(empresaId, finiquitoId).update({
      'estado': EstadoFiniquito.firmado.name,
      'firmado': true,
      'firma_url': firmaUrl,
      'pdf_firmado_url': pdfFirmadoUrl,
      'fecha_firma': FieldValue.serverTimestamp(),
      'firma_uid': firmaUid,
      if (geolocalizacion != null) 'firma_geo': geolocalizacion,
    });

    // Notificar al propietario
    try {
      final data = doc.data()!;
      final nombreEmpleado =
          data['empleado_nombre'] as String? ?? 'Empleado';

      // Notificación in-app
      await _db
          .collection('notificaciones')
          .doc(empresaId)
          .collection('items')
          .add({
        'titulo': '✍️ Finiquito firmado',
        'cuerpo':
            'El finiquito de $nombreEmpleado ha sido firmado',
        'tipo': 'finiquito_firmado',
        'timestamp': FieldValue.serverTimestamp(),
        'leida': false,
        'modulo_destino': 'finiquitos',
        'entidad_id': finiquitoId,
      });
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERTIR TRAZOS A PNG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte una lista de trazos de firma a bytes PNG.
  static Future<Uint8List?> trazosAPng({
    required List<List<Offset>> trazos,
    double ancho = 400,
    double alto = 200,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, ancho, alto));

    // Fondo blanco
    canvas.drawRect(
      Rect.fromLTWH(0, 0, ancho, alto),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Dibujar trazos
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length < 2) continue;
      final path = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (int i = 1; i < trazo.length; i++) {
        path.lineTo(trazo[i].dx, trazo[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(ancho.toInt(), alto.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}


