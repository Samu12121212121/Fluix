import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/models/pdf_template.dart';

class PdfTemplateService {
  static const _col = 'pdf_templates';
  final _db = FirebaseFirestore.instance;

  // Sin orderBy en Firestore → sin necesidad de índice compuesto.
  // Se ordena en cliente por fecha_modificacion descendente.

  Stream<List<PdfTemplate>> watchPlantillas(String empresaId) {
    return _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => PdfTemplate.fromFirestore(d)).toList();
          list.sort((a, b) => b.fechaModificacion.compareTo(a.fechaModificacion));
          return list;
        });
  }

  /// Devuelve TODAS las plantillas (activas e inactivas) para gestión del usuario.
  Stream<List<PdfTemplate>> watchTodasPlantillas(String empresaId) {
    return _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => PdfTemplate.fromFirestore(d)).toList();
          list.sort((a, b) => b.fechaModificacion.compareTo(a.fechaModificacion));
          return list;
        });
  }

  Future<void> toggleActiva(String plantillaId, bool nuevaActiva) async {
    await _db.collection(_col).doc(plantillaId).update({
      'activa': nuevaActiva,
      'fecha_modificacion': Timestamp.now(),
    });

    // Si se desactiva una plantilla que era la default, transferir el flag
    // a la siguiente plantilla activa del mismo tipo para ese empresa.
    if (!nuevaActiva) {
      final doc = await _db.collection(_col).doc(plantillaId).get();
      final data = doc.data();
      if (data == null) return;
      final esDefault = data['es_default'] as bool? ?? false;
      if (!esDefault) return;

      final tipo = data['tipo'] as String?;
      final empresaId = data['empresa_id'] as String?;
      if (tipo == null || empresaId == null) return;

      final snap = await _db
          .collection(_col)
          .where('empresa_id', isEqualTo: empresaId)
          .get();

      final candidatos = snap.docs.where(
        (d) =>
            d.id != plantillaId &&
            d.data()['tipo'] == tipo &&
            (d.data()['activa'] as bool? ?? true),
      ).toList();

      if (candidatos.isEmpty) return; // no hay otra activa → sin transferencia

      final batch = _db.batch();
      batch.update(_db.collection(_col).doc(plantillaId), {'es_default': false});
      batch.update(candidatos.first.reference, {
        'es_default': true,
        'fecha_modificacion': Timestamp.now(),
      });
      await batch.commit();
    }
  }

  Future<List<PdfTemplate>> getPlantillas(String empresaId) async {
    final snap = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .where('activa', isEqualTo: true)
        .get();
    final list = snap.docs.map((d) => PdfTemplate.fromFirestore(d)).toList();
    list.sort((a, b) => b.fechaModificacion.compareTo(a.fechaModificacion));
    return list;
  }

  Future<PdfTemplate?> getPlantillaById(String id) async {
    final doc = await _db.collection(_col).doc(id).get();
    if (!doc.exists) return null;
    return PdfTemplate.fromFirestore(doc);
  }

  Future<PdfTemplate?> getPlantillaDefault(String empresaId, TipoDocumentoPdf tipo) async {
    // Query mínima: solo empresa_id. Filtra todo en cliente para evitar
    // cualquier problema de índices o reglas Firestore.
    final snap = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .get();

    debugPrint('🎨 [TPL] getPlantillaDefault: ${snap.docs.length} docs encontrados para $empresaId');
    for (final d in snap.docs) {
      final data = d.data();
      debugPrint('  → id=${d.id} tipo=${data['tipo']} es_default=${data['es_default']} activa=${data['activa']} nombre=${data['nombre']}');
    }

    final activas = snap.docs
        .where((d) {
          final data = d.data();
          return data['tipo'] == tipo.id
              && (data['activa'] as bool? ?? true);
        })
        .toList();

    if (activas.isEmpty) {
      debugPrint('🎨 [TPL] Sin plantilla activa para tipo=${tipo.id}');
      return null;
    }

    // Preferir la marcada como default; si ninguna lo está (o la default está
    // inactiva), usar la primera activa disponible como fallback.
    final conDefault = activas.where(
      (d) => (d.data()['es_default'] as bool? ?? false) == true,
    ).toList();

    final elegida = conDefault.isNotEmpty ? conDefault.first : activas.first;
    debugPrint('🎨 [TPL] Plantilla encontrada: ${elegida.data()['nombre']}');
    return PdfTemplate.fromFirestore(elegida);
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
    // Query con solo empresa_id para no necesitar índice compuesto.
    // Filtra tipo y es_default en cliente antes de actualizar el batch.
    final snap = await _db
        .collection(_col)
        .where('empresa_id', isEqualTo: empresaId)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      final esMismoTipo = data['tipo'] == tipo.id;
      final esActualDefault = data['es_default'] as bool? ?? false;
      if (esMismoTipo && esActualDefault && doc.id != plantillaId) {
        batch.update(doc.reference, {'es_default': false});
      }
    }
    // Marcar como default Y activar en el mismo batch para evitar
    // el estado roto (es_default=true pero activa=false).
    batch.update(_db.collection(_col).doc(plantillaId), {
      'es_default': true,
      'activa': true,
      'fecha_modificacion': Timestamp.now(),
    });
    await batch.commit();
  }

  /// Crea una plantilla por defecto para cada tipo que no tenga ninguna.
  /// Seguro para ejecutar múltiples veces (idempotente por tipo).
  Future<void> inicializarPlantillasDefault(String empresaId) async {
    final existentes = await getPlantillas(empresaId);
    final tiposExistentes = existentes.map((p) => p.tipo).toSet();

    final todas = [
      PdfTemplate.defaultFactura(empresaId),
      PdfTemplate.defaultFacturaRectificativa(empresaId),
      PdfTemplate.defaultProforma(empresaId),
      PdfTemplate.defaultPresupuesto(empresaId),
      PdfTemplate.defaultAlbaran(empresaId),
      PdfTemplate.defaultFichajes(empresaId),
      PdfTemplate.defaultHorasEmpleado(empresaId),
      PdfTemplate.defaultInformeInterno(empresaId),
    ];

    final faltantes = todas.where((t) => !tiposExistentes.contains(t.tipo)).toList();
    if (faltantes.isEmpty) return;

    final batch = _db.batch();
    for (final tpl in faltantes) {
      final ref = _db.collection(_col).doc();
      batch.set(ref, tpl.copyWith(id: ref.id).toFirestore());
    }
    await batch.commit();
  }
}
