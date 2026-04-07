import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Gestiona imágenes del catálogo en Firebase Storage.
/// Path: empresas/{empresaId}/catalogo/{productoId}/imagen.jpg
/// Thumbnail generado por Cloud Function: thumb_imagen.jpg
class ProductoImagenService {
  static final ProductoImagenService _i = ProductoImagenService._();
  factory ProductoImagenService() => _i;
  ProductoImagenService._();

  final _storage = FirebaseStorage.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  static const int _maxSize = 800;
  static const int _jpegQuality = 85;

  // ── RUTAS ─────────────────────────────────────────────────────────────────

  String _pathImagen(String empresaId, String productoId) =>
      'empresas/$empresaId/catalogo/$productoId/imagen.jpg';
  String _pathThumb(String empresaId, String productoId) =>
      'empresas/$empresaId/catalogo/$productoId/thumb_imagen.jpg';

  // ── SELECCIONAR Y SUBIR ───────────────────────────────────────────────────

  /// Abre el picker, procesa (crop 1:1 + 800×800 + calidad 85%)
  /// y sube a Storage. Devuelve la URL pública o null si se cancela.
  Future<String?> seleccionarYSubir({
    required String empresaId,
    required String productoId,
    required ImageSource source,
    String? urlAnterior,
  }) async {
    // Pick
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 95,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final processed = await _procesarImagen(bytes);

    // Eliminar imagen anterior de Storage antes de subir
    if (urlAnterior != null) {
      await _eliminarArchivosStorage(empresaId, productoId);
    }

    // Subir
    final ref = _storage.ref(_pathImagen(empresaId, productoId));
    await ref.putData(
      processed,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'empresaId': empresaId,
          'productoId': productoId,
          'subidoEn': DateTime.now().toIso8601String(),
        },
      ),
    );

    final url = await ref.getDownloadURL();

    // Guardar URL en Firestore
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .doc(productoId)
        .update({'imagen_url': url});

    return url;
  }

  /// Mismo que [seleccionarYSubir] pero con hasta 3 reintentos.
  Future<String?> seleccionarYSubirConRetry({
    required String empresaId,
    required String productoId,
    required ImageSource source,
    String? urlAnterior,
  }) async {
    Exception? lastErr;
    for (int i = 0; i < 3; i++) {
      try {
        return await seleccionarYSubir(
          empresaId: empresaId,
          productoId: productoId,
          source: source,
          urlAnterior: urlAnterior,
        );
      } catch (e) {
        lastErr = Exception(e.toString());
        if (i < 2) await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw lastErr!;
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  Future<void> eliminarImagen({
    required String empresaId,
    required String productoId,
  }) async {
    await _eliminarArchivosStorage(empresaId, productoId);
    try {
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo')
          .doc(productoId)
          .update({
        'imagen_url': FieldValue.delete(),
        'thumbnail_url': FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> _eliminarArchivosStorage(
      String empresaId, String productoId) async {
    for (final path in [
      _pathImagen(empresaId, productoId),
      _pathThumb(empresaId, productoId),
    ]) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
  }

  // ── PROCESAR IMAGEN ───────────────────────────────────────────────────────

  /// Recorte cuadrado central + redimensión 800×800 + compresión JPEG 85%.
  Future<Uint8List> _procesarImagen(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Imagen corrupta o formato no soportado');

    // Crop al cuadrado central (1:1 forzado)
    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final x = (decoded.width - side) ~/ 2;
    final y = (decoded.height - side) ~/ 2;
    final cropped = img.copyCrop(decoded, x: x, y: y, width: side, height: side);
    final resized = img.copyResize(cropped, width: _maxSize, height: _maxSize,
        interpolation: img.Interpolation.linear);
    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }
}



