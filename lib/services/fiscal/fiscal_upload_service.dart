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
      final existingData = existing.docs.first.data();
      final processingStatus = existingData['processing_status'] as String?;

      // Si el procesamiento anterior falló o se quedó pendiente, permitir reintento
      if (processingStatus == 'failed' || processingStatus == 'pending') {
        // Reutilizar el document ID existente
        final existingDocId = existing.docs.first.id;
        // Eliminar el doc viejo para poder recrearlo
        await _db
            .collection('empresas')
            .doc(empresaId)
            .collection('fiscal_documents')
            .doc(existingDocId)
            .delete();
      } else {
        throw DuplicateDocumentException(
            'Este archivo ya fue subido anteriormente');
      }
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

  // ═══════════════════════════════════════════════════════════════
  // ANULACIÓN, BORRADO Y RECTIFICATIVAS
  // ═══════════════════════════════════════════════════════════════

  /// Anula una transacción (marca como 'voided').
  /// draft/needs_review → se puede anular sin más.
  /// posted → se anula y se recomienda crear rectificativa.
  Future<void> anularTransaccion({
    required String empresaId,
    required String transactionId,
    required String motivo,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    if (motivo.trim().isEmpty) throw Exception('Debes indicar un motivo');

    final txRef = _db
        .collection('empresas').doc(empresaId)
        .collection('fiscal_transactions').doc(transactionId);

    final txDoc = await txRef.get();
    if (!txDoc.exists) throw Exception('Transacción no encontrada');

    final data = txDoc.data()!;
    final currentStatus = data['status'] as String?;

    if (!['draft', 'needs_review', 'posted'].contains(currentStatus)) {
      throw Exception('No se puede anular en estado $currentStatus');
    }

    await txRef.update({
      'status': 'voided',
      'voided_at': FieldValue.serverTimestamp(),
      'voided_by': uid,
      'void_reason': motivo,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Marcar factura_recibida vinculada si existe
    final facturaRecibidaId = data['_ai_factura_recibida_id'] as String?;
    if (facturaRecibidaId != null) {
      await _db.collection('empresas').doc(empresaId)
          .collection('facturas_recibidas').doc(facturaRecibidaId)
          .update({
        'estado': 'rechazada',
        'notas': 'Anulada: $motivo',
      });
    }

    // Auditoría
    await _db.collection('empresas').doc(empresaId)
        .collection('fiscal_transaction_history').add({
      'transaction_id': transactionId,
      'change_type': 'voided',
      'reason': motivo,
      'old_status': currentStatus,
      'new_status': 'voided',
      'changed_at': FieldValue.serverTimestamp(),
      'changed_by': uid,
    });
  }

  /// Elimina un borrador (draft/needs_review). Nunca posted.
  Future<void> eliminarBorrador({
    required String empresaId,
    required String transactionId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final txRef = _db
        .collection('empresas').doc(empresaId)
        .collection('fiscal_transactions').doc(transactionId);

    final txDoc = await txRef.get();
    if (!txDoc.exists) throw Exception('Transacción no encontrada');

    final status = txDoc.data()!['status'] as String?;
    if (status != 'draft' && status != 'needs_review') {
      throw Exception(
        'No se puede eliminar una factura contabilizada. Usa "Anular".',
      );
    }

    // Guardar en historial antes de borrar
    await _db.collection('empresas').doc(empresaId)
        .collection('fiscal_transaction_history').add({
      'transaction_id': transactionId,
      'change_type': 'deleted_draft',
      'deleted_data': txDoc.data(),
      'changed_at': FieldValue.serverTimestamp(),
      'changed_by': uid,
    });

    await txRef.delete();

    // Borrar factura_recibida vinculada
    final frId = txDoc.data()?['_ai_factura_recibida_id'] as String?;
    if (frId != null) {
      await _db.collection('empresas').doc(empresaId)
          .collection('facturas_recibidas').doc(frId).delete();
    }
  }

  /// Crea factura rectificativa con importes negativos.
  /// Solo para transacciones en estado 'posted'.
  Future<String> crearFacturaRectificativa({
    required String empresaId,
    required String transactionIdOriginal,
    required String motivo,
    double? importeRectificado, // null = anulación total
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final origRef = _db
        .collection('empresas').doc(empresaId)
        .collection('fiscal_transactions').doc(transactionIdOriginal);

    final origDoc = await origRef.get();
    if (!origDoc.exists) throw Exception('Factura original no encontrada');

    final orig = origDoc.data()!;
    if (orig['status'] != 'posted') {
      throw Exception('Solo se pueden rectificar facturas contabilizadas');
    }

    final totalCents = (orig['total_amount_cents'] as num?) ?? 0;
    final factor = importeRectificado != null && totalCents != 0
        ? -(importeRectificado / (totalCents / 100))
        : -1.0;

    final baseRect = ((orig['base_amount_cents'] ?? 0) as num).toDouble() * factor;
    final vatRect = ((orig['vat_amount_cents'] ?? 0) as num).toDouble() * factor;
    final totalRect = ((orig['total_amount_cents'] ?? 0) as num).toDouble() * factor;

    final invoiceDate = DateTime.now();
    final quarter = ((invoiceDate.month - 1) ~/ 3) + 1;
    final period = '${invoiceDate.year}-Q$quarter';

    final rectRef = await _db
        .collection('empresas').doc(empresaId)
        .collection('fiscal_transactions').add({
      'type': orig['type'],
      'status': 'posted',
      'document_id': orig['document_id'],
      'extraction_id': orig['extraction_id'],
      'invoice_number': 'RECT-${orig['invoice_number']}',
      'external_reference': orig['invoice_number'],
      'invoice_date': Timestamp.fromDate(invoiceDate),
      'period': period,
      'counterparty': orig['counterparty'],
      'base_amount_cents': baseRect.round(),
      'vat_amount_cents': vatRect.round(),
      'total_amount_cents': totalRect.round(),
      'vat_rate': orig['vat_rate'],
      'currency': orig['currency'] ?? 'EUR',
      'vat_scheme': orig['vat_scheme'],
      'tax_tags': [
        ...(orig['tax_tags'] as List? ?? []).map((e) => e.toString()),
        'RECTIFICATIVE_INVOICE',
      ],
      'rectifies_transaction_id': transactionIdOriginal,
      'rectification_reason': motivo,
      'rectification_type': importeRectificado != null ? 'partial' : 'full',
      'validation_errors': <String>[],
      'validation_warnings': <String>[],
      'extraction_warnings': <String>[],
      'created_at': FieldValue.serverTimestamp(),
      'created_by': uid,
      'posted_at': FieldValue.serverTimestamp(),
      'posted_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await origRef.update({
      'rectified_by_transaction_id': rectRef.id,
      'rectification_date': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _db.collection('empresas').doc(empresaId)
        .collection('fiscal_transaction_history').add({
      'transaction_id': transactionIdOriginal,
      'change_type': 'rectified',
      'new_transaction_id': rectRef.id,
      'reason': motivo,
      'changed_at': FieldValue.serverTimestamp(),
      'changed_by': uid,
    });

    return rectRef.id;
  }
}

class DuplicateDocumentException implements Exception {
  final String message;
  DuplicateDocumentException(this.message);
  @override
  String toString() => message;
}








