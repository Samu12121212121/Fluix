import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/pdf_template.dart';

class PdfTemplateService {
  static const _col = 'pdf_templates';
  final _db = FirebaseFirestore.instance;

  Stream<List<PdfTemplate>> watchPlantillas(String empresaId) {
    return _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('activa', isEqualTo: true)
        .orderBy('fecha_modificacion', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PdfTemplate.fromFirestore(d)).toList());
  }

  Future<List<PdfTemplate>> getPlantillas(String empresaId) async {
    final snap = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('activa', isEqualTo: true)
        .orderBy('fecha_modificacion', descending: true)
        .get();
    return snap.docs.map((d) => PdfTemplate.fromFirestore(d)).toList();
  }

  Future<PdfTemplate?> getPlantillaById(String id) async {
    final doc = await _db.collection(_col).doc(id).get();
    if (!doc.exists) return null;
    return PdfTemplate.fromFirestore(doc);
  }

  Future<PdfTemplate?> getPlantillaDefault(String empresaId, TipoDocumentoPdf tipo) async {
    final snap = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('tipo', isEqualTo: tipo.id)
        .where('es_default', isEqualTo: true)
        .where('activa', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PdfTemplate.fromFirestore(snap.docs.first);
  }

  Future<String> crearPlantilla(PdfTemplate plantilla) async {
    final ref = _db.collection(_col).doc();
    await ref.set(plantilla.copyWith(id: ref.id).toFirestore());
    return ref.id;
  }

  Future<void> actualizarPlantilla(PdfTemplate plantilla) async {
    await _db.collection(_col).doc(plantilla.id).update(
        plantilla.copyWith(fechaModificacion: DateTime.now()).toFirestore());
  }

  Future<void> eliminarPlantilla(String id) async {
    await _db.collection(_col).doc(id).update({'activa': false});
  }

  Future<String> duplicarPlantilla(PdfTemplate original, String nuevoNombre) async {
    final ref = _db.collection(_col).doc();
    final copia = original.copyWith(
      id: ref.id,
      nombre: nuevoNombre,
      esDefault: false,
      fechaCreacion: DateTime.now(),
      fechaModificacion: DateTime.now(),
    );
    await ref.set(copia.toFirestore());
    return ref.id;
  }

  Future<void> establecerComoDefault(String empresaId, String plantillaId, TipoDocumentoPdf tipo) async {
    final batch = _db.batch();
    final snaps = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('tipo', isEqualTo: tipo.id)
        .where('es_default', isEqualTo: true)
        .get();
    for (final doc in snaps.docs) {
      if (doc.id != plantillaId) batch.update(doc.reference, {'es_default': false});
    }
    batch.update(_db.collection(_col).doc(plantillaId),
        {'es_default': true, 'fecha_modificacion': Timestamp.now()});
    await batch.commit();
  }

  Future<void> inicializarPlantillasDefault(String empresaId) async {
    final existentes = await getPlantillas(empresaId);
    if (existentes.isNotEmpty) return;
    final batch = _db.batch();
    for (final tpl in [
      PdfTemplate.defaultFactura(empresaId),
      PdfTemplate.defaultFichajes(empresaId),
      PdfTemplate.defaultPresupuesto(empresaId),
    ]) {
      final ref = _db.collection(_col).doc();
      batch.set(ref, tpl.copyWith(id: ref.id).toFirestore());
    }
    await batch.commit();
  }
}

