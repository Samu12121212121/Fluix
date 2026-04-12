import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/modelo202.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CALCULADOR MODELO 202 — Pago fraccionado IS
// ═══════════════════════════════════════════════════════════════════════════════

class Mod202Calculator {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calcula el Modelo 202 para un período dado.
  /// La base (c01) viene de la cuota íntegra del IS del último ejercicio.
  Future<Modelo202> calcular({
    required String empresaId,
    required int ejercicio,
    required PeriodoModelo202 periodo,
  }) async {
    // Buscar último IS declarado (del ejercicio anterior)
    final docIS = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .doc('200_${ejercicio - 1}_anual')
        .get();

    double baseIS = 0;
    if (docIS.exists) {
      final data = docIS.data()!;
      baseIS = (data['cuota_integra'] as num?)?.toDouble() ?? 0;
    }

    // Buscar pagos fraccionados anteriores del mismo ejercicio
    double pagosAnteriores = 0;
    final periodoAnterior = <PeriodoModelo202>[];
    if (periodo == PeriodoModelo202.p2) {
      periodoAnterior.add(PeriodoModelo202.p1);
    } else if (periodo == PeriodoModelo202.p3) {
      periodoAnterior.addAll([PeriodoModelo202.p1, PeriodoModelo202.p2]);
    }

    for (final p in periodoAnterior) {
      final prevDoc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('modelos_fiscales')
          .doc('202_${ejercicio}_${p.codigo}')
          .get();
      if (prevDoc.exists) {
        pagosAnteriores +=
            (prevDoc.data()?['resultado_ingresar'] as num?)?.toDouble() ?? 0;
      }
    }

    final docId = '202_${ejercicio}_${periodo.codigo}';

    return Modelo202(
      id: docId,
      empresaId: empresaId,
      ejercicio: ejercicio,
      periodo: periodo,
      fechaGeneracion: DateTime.now(),
      c01: baseIS,
      c06: pagosAnteriores,
    );
  }

  /// Guarda el modelo calculado en Firestore.
  Future<void> guardar(String empresaId, Modelo202 modelo) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .doc(modelo.id)
        .set({
      ...modelo.toFirestore(),
      'fecha_calculo': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marca como presentado.
  Future<void> marcarPresentado(
      String empresaId, String docId, String? justificante) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .doc(docId)
        .update({
      'estado': 'presentado',
      'fecha_presentacion': FieldValue.serverTimestamp(),
      if (justificante != null) 'justificante_aeat': justificante,
    });
  }

  /// Stream de un modelo 202 específico.
  Stream<Modelo202?> obtener(String empresaId, int ejercicio, PeriodoModelo202 periodo) {
    final docId = '202_${ejercicio}_${periodo.codigo}';
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .doc(docId)
        .snapshots()
        .map((snap) => snap.exists ? Modelo202.fromFirestore(snap) : null);
  }

  /// Stream de todos los 202 del ejercicio.
  Stream<List<Modelo202>> obtenerTodos(String empresaId, int ejercicio) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos_fiscales')
        .where('modelo', isEqualTo: '202')
        .where('ejercicio', isEqualTo: ejercicio)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Modelo202.fromFirestore(d)).toList()
              ..sort((a, b) => a.periodo.index.compareTo(b.periodo.index)));
  }
}

