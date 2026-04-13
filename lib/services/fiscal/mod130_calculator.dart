import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/modelos/modelo130.dart';
import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.130 CALCULATOR — Pago fraccionado IRPF autónomos
// Art. 110 LIRPF — Cálculo acumulativo YTD
// ═══════════════════════════════════════════════════════════════════════════════

class Mod130Calculator {
  static final Mod130Calculator _i = Mod130Calculator._();
  factory Mod130Calculator() => _i;
  Mod130Calculator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _modelos130(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos130');

  CollectionReference<Map<String, dynamic>> _facturas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('facturas');

  CollectionReference<Map<String, dynamic>> _facturasRecibidas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('facturas_recibidas');

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el Mod.130 para un trimestre a partir de facturas YTD.
  Future<Modelo130> calcular({
    required String empresaId,
    required int ejercicio,
    required String trimestre,
    double c13Manual = 0,
    double c15Manual = 0,
    double c16Manual = 0,
    double c18Manual = 0,
    bool esComplementaria = false,
    String? nJustificanteAnterior,
  }) async {
    final ytd = Modelo130.rangoYTD(ejercicio, trimestre);

    // [01] Ingresos computables acumulados YTD
    final emitidas = await _obtenerFacturasEmitidas(
      empresaId, ytd.inicio, ytd.fin,
    );
    final c01 = emitidas.fold(0.0, (sum, f) => sum + f.subtotal);

    // [02] Gastos fiscalmente deducibles acumulados YTD
    final recibidas = await _obtenerFacturasRecibidas(
      empresaId, ytd.inicio, ytd.fin,
    );
    final c02 = recibidas.fold(0.0, (sum, f) => sum + f.baseImponible);

    // [05] Pagos fraccionados anteriores del mismo ejercicio
    final c05 = await _sumarPagosAnteriores(empresaId, ejercicio, trimestre);

    // [06] Retenciones soportadas acumuladas YTD
    // (retenciones que los clientes aplicaron sobre las facturas del autónomo)
    final c06 = emitidas.fold(0.0, (sum, f) => sum + f.retencionIrpf);

    debugPrint('📊 130: facturas encontradas en Q$trimestre/$ejercicio: '
        '${emitidas.length} emitidas / ${recibidas.length} recibidas');
    debugPrint('📊 130: ingresos totales (YTD): ${c01.toStringAsFixed(2)} €');
    debugPrint('📊 130: gastos totales (YTD): ${c02.toStringAsFixed(2)} €');
    debugPrint('📊 130: retenciones soportadas: ${c06.toStringAsFixed(2)} €');
    debugPrint('📊 130: pagos anteriores: ${c05.toStringAsFixed(2)} €');

    // Validar c16 máximo 660.14€
    final c16Validado = c16Manual.clamp(0.0, 660.14);

    final docRef = _modelos130(empresaId).doc();

    return Modelo130(
      id: docRef.id,
      empresaId: empresaId,
      ejercicio: ejercicio,
      trimestre: trimestre,
      fechaGeneracion: DateTime.now(),
      c01: _r2(c01),
      c02: _r2(c02),
      c05: _r2(c05),
      c06: _r2(c06),
      c13: _r2(c13Manual),
      c15: _r2(c15Manual),
      c16: _r2(c16Validado),
      c18: _r2(c18Manual),
      esComplementaria: esComplementaria,
      nJustificanteAnterior: nJustificanteAnterior,
      facturasEmitidasIds: emitidas.map((f) => f.id).toList(),
      facturasRecibidasIds: recibidas.map((f) => f.id).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTAS FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Factura>> _obtenerFacturasEmitidas(
    String empresaId, DateTime inicio, DateTime fin,
  ) async {
    final snap = await _facturas(empresaId)
        .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => Factura.fromFirestore(d))
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList();
  }

  Future<List<FacturaRecibida>> _obtenerFacturasRecibidas(
    String empresaId, DateTime inicio, DateTime fin,
  ) async {
    final snap = await _facturasRecibidas(empresaId)
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .where((f) => f.estado != EstadoFacturaRecibida.rechazada)
        .toList();
  }

  /// Suma los resultados [c19] de los Mod.130 presentados en trimestres
  /// anteriores del mismo ejercicio (pagos fraccionados ya realizados).
  Future<double> _sumarPagosAnteriores(
    String empresaId, int ejercicio, String trimestre,
  ) async {
    final anteriores = Modelo130.trimestresAnteriores(trimestre);
    if (anteriores.isEmpty) return 0;

    double total = 0;
    for (final t in anteriores) {
      final snap = await _modelos130(empresaId)
          .where('ejercicio', isEqualTo: ejercicio)
          .where('trimestre', isEqualTo: t)
          .orderBy('fecha_generacion', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        // Usar c19 almacenado (resultado final de ese trimestre)
        final resultado = (d['c19'] as num?)?.toDouble() ?? 0;
        // Solo sumar si fue positivo (se ingresó)
        if (resultado > 0) total += resultado;
      }
    }
    return total;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> guardar(String empresaId, Modelo130 modelo) async {
    // Buscar si ya existe uno para este trimestre/ejercicio
    final existente = await _modelos130(empresaId)
        .where('ejercicio', isEqualTo: modelo.ejercicio)
        .where('trimestre', isEqualTo: modelo.trimestre)
        .limit(1)
        .get();

    if (existente.docs.isNotEmpty) {
      await existente.docs.first.reference.update(modelo.toFirestore());
    } else {
      await _modelos130(empresaId).doc(modelo.id).set(modelo.toFirestore());
    }
  }

  Future<void> marcarPresentado(String empresaId, String docId) async {
    await _modelos130(empresaId).doc(docId).update({'estado': 'presentado'});
  }

  Stream<List<Modelo130>> obtenerTodos(String empresaId, int ejercicio) {
    return _modelos130(empresaId)
        .where('ejercicio', isEqualTo: ejercicio)
        .orderBy('trimestre')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Modelo130.fromFirestore(d)).toList());
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}


