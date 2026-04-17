import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'fiscal_capture_service.dart';

class UploadProgress {
  final String step;
  final double percent;
  UploadProgress({required this.step, required this.percent});
}

class FiscalUploadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Sube archivo y lanza procesamiento backend. Devuelve el resultado completo.
  Future<Map<String, dynamic>> uploadAndProcess({
    required String empresaId,
    required CapturedFile captured,
    required String tipoDocumento, // 'gasto' o 'ingreso'
    void Function(UploadProgress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No autenticado');

    // 1. Hash para dedup
    onProgress?.call(
        UploadProgress(step: 'Verificando archivo...', percent: 0.05));

    final bytes = await captured.file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    // 2. Comprobar duplicado
    final existing = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('fiscal_documents')
        .where('sha256_hash', isEqualTo: hash)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw DuplicateDocumentException(
          'Este archivo ya fue subido anteriormente');
    }

    // 3. Subir a Storage
    onProgress?.call(
        UploadProgress(step: 'Subiendo archivo...', percent: 0.10));

    final documentId = const Uuid().v4();
    final extension = _getExtension(captured.mimeType);
    final storagePath =
        'empresas/$empresaId/private/fiscal/documents/$documentId.$extension';

    final uploadTask = _storage.ref(storagePath).putFile(
          captured.file,
          SettableMetadata(
            contentType: captured.mimeType,
            customMetadata: {
              'empresa_id': empresaId,
              'uploaded_by': user.uid,
              'original_filename': captured.originalFilename,
            },
          ),
        );

    uploadTask.snapshotEvents.listen((snap) {
      final uploadPercent = snap.bytesTransferred / snap.totalBytes;
      onProgress?.call(UploadProgress(
        step: 'Subiendo archivo...',
        percent: 0.10 + (uploadPercent * 0.40),
      ));
    });

    await uploadTask;

    // 4. Crear doc en Firestore
    onProgress?.call(
        UploadProgress(step: 'Registrando...', percent: 0.55));

    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('fiscal_documents')
        .doc(documentId)
        .set({
      'filename': captured.originalFilename,
      'mime_type': captured.mimeType,
      'file_size_bytes': captured.sizeBytes,
      'sha256_hash': hash,
      'storage_path': storagePath,
      'uploaded_at': FieldValue.serverTimestamp(),
      'uploaded_by': user.uid,
    });

    // 5. Invocar Cloud Function
    onProgress?.call(UploadProgress(
        step: 'La IA está leyendo la factura...', percent: 0.60));

    final callable = _functions.httpsCallable(
      'processInvoice',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
    );

    final result = await callable.call({
      'empresaId': empresaId,
      'documentId': documentId,
      'tipoDocumento': tipoDocumento,
    });

    onProgress?.call(UploadProgress(step: '¡Listo!', percent: 1.0));

    return Map<String, dynamic>.from(result.data as Map);
  }

  String _getExtension(String mimeType) {
    switch (mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  /// Escucha el estado de una transacción fiscal en tiempo real.
  Stream<DocumentSnapshot> watchTransaction({
    required String empresaId,
    required String transactionId,
  }) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('fiscal_transactions')
        .doc(transactionId)
        .snapshots();
  }
}

class DuplicateDocumentException implements Exception {
  final String message;
  DuplicateDocumentException(this.message);
  @override
  String toString() => message;
}






