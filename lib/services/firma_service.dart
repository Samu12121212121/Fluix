import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE FIRMA DIGITAL DE NÓMINAS
// ═══════════════════════════════════════════════════════════════════════════════

class FirmaService {
  static final FirmaService _i = FirmaService._();
  factory FirmaService() => _i;
  FirmaService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Sube la firma PNG a Firebase Storage y devuelve la URL de descarga.
  Future<String> guardarFirma({
    required String empresaId,
    required String nominaId,
    required Uint8List pngBytes,
  }) async {
    final ref = _storage.ref('firmas/$empresaId/$nominaId.png');
    await ref.putData(pngBytes, SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }

  /// Marca la nómina como firmada en Firestore.
  Future<void> marcarComoFirmada({
    required String empresaId,
    required String nominaId,
    required String firmaUrl,
    required String empleadoId,
  }) async {
    await _db
        .collection('empresas').doc(empresaId)
        .collection('nominas').doc(nominaId)
        .update({
      'firma_url': firmaUrl,
      'firma_fecha': Timestamp.fromDate(DateTime.now()),
      'firma_empleado_id': empleadoId,
      'estado_firma': 'firmada',
    });
  }

  /// Marca la nómina como lista para firmar.
  Future<void> marcarListaParaFirmar({
    required String empresaId,
    required String nominaId,
  }) async {
    await _db
        .collection('empresas').doc(empresaId)
        .collection('nominas').doc(nominaId)
        .update({
      'estado_firma': 'pendiente',
    });
  }

  /// Obtiene la URL de la firma de una nómina (null si no está firmada).
  Future<String?> obtenerFirmaUrl(String empresaId, String nominaId) async {
    final doc = await _db
        .collection('empresas').doc(empresaId)
        .collection('nominas').doc(nominaId)
        .get();
    return doc.data()?['firma_url'] as String?;
  }

  /// Flujo completo: guardar firma + marcar como firmada.
  Future<String> firmarNomina({
    required String empresaId,
    required String nominaId,
    required String empleadoId,
    required Uint8List pngBytes,
  }) async {
    final url = await guardarFirma(
      empresaId: empresaId, nominaId: nominaId, pngBytes: pngBytes,
    );
    await marcarComoFirmada(
      empresaId: empresaId, nominaId: nominaId,
      firmaUrl: url, empleadoId: empleadoId,
    );
    return url;
  }

  /// Descarga los bytes PNG de la firma desde Storage.
  Future<Uint8List?> descargarFirmaPng(String empresaId, String nominaId) async {
    try {
      final ref = _storage.ref('firmas/$empresaId/$nominaId.png');
      return await ref.getData(1024 * 1024); // max 1MB
    } catch (_) {
      return null;
    }
  }
}


