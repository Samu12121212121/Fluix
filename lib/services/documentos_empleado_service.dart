import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/modelos/documento_empleado.dart';

/// Servicio para gestionar documentos de empleados (subcolección + Storage)
class DocumentosEmpleadoService {
  static final DocumentosEmpleadoService _i = DocumentosEmpleadoService._();
  factory DocumentosEmpleadoService() => _i;
  DocumentosEmpleadoService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _docs(String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('documentos');

  // ── LISTAR ────────────────────────────────────────────────────────────────

  Stream<List<DocumentoEmpleado>> listarPorEmpleado(String empleadoId) {
    return _docs(empleadoId)
        .orderBy('fecha_subida', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentoEmpleado.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<DocumentoEmpleado>> listarPorCategoria(
      String empleadoId, CategoriaDocumento categoria) {
    return _docs(empleadoId)
        .where('categoria', isEqualTo: categoria.name)
        .orderBy('fecha_subida', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentoEmpleado.fromMap(d.data(), d.id))
            .toList());
  }

  // ── SUBIR ─────────────────────────────────────────────────────────────────

  Future<DocumentoEmpleado> subir({
    required String empresaId,
    required String empleadoId,
    required String nombre,
    required CategoriaDocumento categoria,
    required Uint8List bytes,
    required String mimeType,
    required String extension_,
    required String subidoPor,
    DateTime? fechaEmision,
    DateTime? fechaCaducidad,
  }) async {
    // 1. Crear doc en Firestore para obtener ID
    final docRef = _docs(empleadoId).doc();
    final docId = docRef.id;

    // 2. Subir archivo a Storage
    final storagePath =
        'empresas/$empresaId/empleados/$empleadoId/documentos/$docId.$extension_';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'empresaId': empresaId,
          'empleadoId': empleadoId,
          'docId': docId,
          'categoria': categoria.name,
        },
      ),
    );
    final url = await ref.getDownloadURL();

    // 3. Guardar metadatos en Firestore
    final doc = DocumentoEmpleado(
      id: docId,
      empleadoId: empleadoId,
      empresaId: empresaId,
      categoria: categoria,
      nombre: nombre,
      url: url,
      storagePath: storagePath,
      mimeType: mimeType,
      tamanoBytes: bytes.length,
      fechaSubida: DateTime.now(),
      fechaEmision: fechaEmision,
      fechaCaducidad: fechaCaducidad,
      subidoPor: subidoPor,
    );

    await docRef.set(doc.toMap());
    return doc;
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  Future<void> eliminar(String empleadoId, DocumentoEmpleado doc) async {
    // Eliminar de Storage
    try {
      await _storage.ref(doc.storagePath).delete();
    } catch (e) {
      // Si no existe en Storage, continuar igualmente
      print('⚠️ Error eliminando archivo de Storage: $e');
    }
    // Eliminar metadatos de Firestore
    await _docs(empleadoId).doc(doc.id).delete();
  }

  // ── DOCUMENTOS CON CADUCIDAD PRÓXIMA ──────────────────────────────────────

  /// Obtiene documentos que caducan en los próximos [dias] días
  Future<List<DocumentoEmpleado>> documentosCaducanPronto(
      String empresaId, {int dias = 30}) async {
    final ahora = DateTime.now();
    final limite = ahora.add(Duration(days: dias));

    // Necesitamos buscar en todos los empleados de la empresa
    final empleadosSnap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .get();

    final List<DocumentoEmpleado> resultado = [];
    for (final emp in empleadosSnap.docs) {
      final docsSnap = await _docs(emp.id)
          .where('fecha_caducidad', isLessThanOrEqualTo: Timestamp.fromDate(limite))
          .where('fecha_caducidad', isGreaterThan: Timestamp.fromDate(
              ahora.subtract(const Duration(days: 90)))) // No mostrar muy vencidos
          .get();
      for (final d in docsSnap.docs) {
        resultado.add(DocumentoEmpleado.fromMap(d.data(), d.id));
      }
    }
    resultado.sort((a, b) =>
        (a.fechaCaducidad ?? ahora).compareTo(b.fechaCaducidad ?? ahora));
    return resultado;
  }
}

