import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/modelos/adjunto_tarea.dart';

/// Servicio para gestionar adjuntos de tareas.
///
/// Storage path: empresas/{empresaId}/tareas/{tareaId}/adjuntos/{filename}
/// Firestore:    empresas/{empresaId}/tareas/{tareaId}/adjuntos/{adjuntoId}
class AdjuntosTareaService {
  static final AdjuntosTareaService _i = AdjuntosTareaService._();
  factory AdjuntosTareaService() => _i;
  AdjuntosTareaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  static const int kMaxAdjuntos = 10;
  static const int kMaxBytesArchivo = 10 * 1024 * 1024; // 10 MB
  static const int kMaxPxImagen = 1200;
  static const int kCalidadImagen = 80;

  CollectionReference<Map<String, dynamic>> _col(
    String empresaId,
    String tareaId,
  ) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('tareas')
          .doc(tareaId)
          .collection('adjuntos');

  // ── LISTAR ───────────────────────────────────────────────────────────────

  Stream<List<AdjuntoTarea>> listarStream(String empresaId, String tareaId) =>
      _col(empresaId, tareaId)
          .orderBy('fecha_subida', descending: true)
          .snapshots()
          .map((s) => s.docs.map(AdjuntoTarea.fromFirestore).toList());

  Future<List<AdjuntoTarea>> listar(String empresaId, String tareaId) async {
    final snap = await _col(empresaId, tareaId)
        .orderBy('fecha_subida', descending: true)
        .get();
    return snap.docs.map(AdjuntoTarea.fromFirestore).toList();
  }

  // ── SUBIR ────────────────────────────────────────────────────────────────

  /// Sube un archivo y devuelve el [AdjuntoTarea] guardado.
  ///
  /// [onProgress] recibe valores de 0.0 a 1.0 con el progreso de subida.
  Future<AdjuntoTarea> subir({
    required String empresaId,
    required String tareaId,
    required File archivo,
    required String subidoPorId,
    void Function(double progreso)? onProgress,
  }) async {
    // Validar límites
    final existentes = await listar(empresaId, tareaId);
    if (existentes.length >= kMaxAdjuntos) {
      throw Exception('Máximo $kMaxAdjuntos adjuntos por tarea.');
    }

    final tamanio = await archivo.length();
    if (tamanio > kMaxBytesArchivo) {
      throw Exception(
          'El archivo supera el tamaño máximo de ${kMaxBytesArchivo ~/ (1024 * 1024)}MB.');
    }

    final extension = _extension(archivo.path);
    final tipo = _detectarTipo(extension);
    final id = _uuid.v4();
    final nombre = archivo.path.split('/').last.split('\\').last;

    // Comprimir si es imagen
    File archivoASubir = archivo;
    if (tipo == TipoAdjunto.imagen) {
      archivoASubir = await _comprimirImagen(archivo, id);
    }

    // Subir a Storage
    final storageRef = _storage
        .ref('empresas/$empresaId/tareas/$tareaId/adjuntos/$id$extension');    final uploadTask = storageRef.putFile(archivoASubir);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await uploadTask;
    final url = await storageRef.getDownloadURL();
    final tamanioFinal = await archivoASubir.length();

    final adjunto = AdjuntoTarea(
      id: id,
      nombre: nombre,
      url: url,
      thumbnailUrl: null, // Generado por Cloud Function
      tipo: tipo,
      tamanioBytes: tamanioFinal,
      subidoPorId: subidoPorId,
      fechaSubida: DateTime.now(),
    );

    await _col(empresaId, tareaId).doc(id).set(adjunto.toFirestore());

    // Limpiar archivo temporal de compresión
    if (tipo == TipoAdjunto.imagen && archivoASubir.path != archivo.path) {
      try {
        await archivoASubir.delete();
      } catch (_) {}
    }

    return adjunto;
  }

  // ── ELIMINAR ─────────────────────────────────────────────────────────────

  Future<void> eliminar({
    required String empresaId,
    required String tareaId,
    required AdjuntoTarea adjunto,
  }) async {
    // Eliminar de Storage
    try {
      final ref = _storage.refFromURL(adjunto.url);
      await ref.delete();
    } catch (_) {}

    // Eliminar thumbnail si existe
    if (adjunto.thumbnailUrl != null) {
      try {
        final ref = _storage.refFromURL(adjunto.thumbnailUrl!);
        await ref.delete();
      } catch (_) {}
    }

    // Eliminar de Firestore
    await _col(empresaId, tareaId).doc(adjunto.id).delete();
  }

  // ── PRIVADOS ─────────────────────────────────────────────────────────────

  String _extension(String path) {
    final name = path.split('/').last.split('\\').last;
    final idx = name.lastIndexOf('.');
    return idx >= 0 ? name.substring(idx).toLowerCase() : '';
  }

  TipoAdjunto _detectarTipo(String extension) {
    const imagenes = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
    const pdfs = ['.pdf'];
    if (imagenes.contains(extension)) return TipoAdjunto.imagen;
    if (pdfs.contains(extension)) return TipoAdjunto.pdf;
    return TipoAdjunto.documento;
  }

  Future<File> _comprimirImagen(File archivo, String id) async {
    final dir = await getTemporaryDirectory();
    final destino = '${dir.path}/${id}_compressed.jpg';
    try {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        archivo.path,
        destino,
        quality: kCalidadImagen,
        minWidth: kMaxPxImagen,
        minHeight: kMaxPxImagen,
      );
      if (xFile != null) return File(xFile.path);
    } catch (_) {}
    return archivo;
  }
}






