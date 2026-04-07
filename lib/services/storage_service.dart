import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STORAGE SERVICE — Firebase Storage + image_picker + resize
// ═════════════════════════════════════════════════════════════════════════════

class StorageService {
  static final StorageService _i = StorageService._();
  factory StorageService() => _i;
  StorageService._();

  final _storage   = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker    = ImagePicker();

  // ── Constantes ─────────────────────────────────────────────────────────────
  static const int _fotoSize    = 400;   // px — lado del cuadrado final
  static const int _jpegQuality = 85;    // 0-100

  // ═══════════════════════════════════════════════════════════════════════════
  // PICKER — seleccionar foto de galería o cámara
  // ═══════════════════════════════════════════════════════════════════════════

  /// Muestra un diálogo para elegir galería o cámara y devuelve el [XFile].
  /// Devuelve null si el usuario cancela.
  Future<XFile?> seleccionarFoto({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1024,   // pre-reduce antes de decodificar
      maxHeight: 1024,
      imageQuality: 95, // primera pasada en el picker
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPLEADOS — subir foto de perfil
  // Path: empleados/{empresaId}/{empleadoId}/foto.jpg
  // ═══════════════════════════════════════════════════════════════════════════

  /// Redimensiona a 400×400, sube a Storage y guarda la URL en Firestore.
  /// Devuelve la URL pública de descarga.
  Future<String> subirFotoEmpleado({
    required String empresaId,
    required String empleadoId,
    required XFile fotoFile,
  }) async {
    // 1. Leer bytes originales
    final bytes = await fotoFile.readAsBytes();

    // 2. Decodificar imagen con el paquete 'image'
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('No se pudo decodificar la imagen');

    // 3. Recortar al cuadrado central y redimensionar a 400×400
    final resized = img.copyResizeCropSquare(original, size: _fotoSize);

    // 4. Codificar como JPEG
    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: _jpegQuality),
    );

    // 5. Subir a Firebase Storage
    final ref = _storage.ref('empleados/$empresaId/$empleadoId/foto.jpg');
    await ref.putData(
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'empleadoId': empleadoId,
          'empresaId': empresaId,
          'subidoEn': DateTime.now().toIso8601String(),
        },
      ),
    );

    // 6. Obtener URL pública
    final url = await ref.getDownloadURL();

    // 7. Guardar URL en Firestore (campo foto_url)
    await _firestore
        .collection('usuarios')
        .doc(empleadoId)
        .update({'foto_url': url});

    return url;
  }

  /// Elimina la foto de perfil de Storage y borra el campo en Firestore.
  Future<void> eliminarFotoEmpleado({
    required String empresaId,
    required String empleadoId,
  }) async {
    try {
      await _storage
          .ref('empleados/$empresaId/$empleadoId/foto.jpg')
          .delete();
    } catch (_) {
      // Puede que el archivo no exista — ignorar
    }
    await _firestore
        .collection('usuarios')
        .doc(empleadoId)
        .update({'foto_url': FieldValue.delete()});
  }
}

