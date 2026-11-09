import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/modelo200.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.200 CALCULATOR — Impuesto sobre Sociedades (anual)
// Art. 25-29 LIS
//
// Fuentes de datos:
//   - facturas (emitidas)        → ingresos del ejercicio
//   - facturas_recibidas         → gastos con IVA deducible
//   - gastos                     → gastos internos
//   - modelos_fiscales/202_*     → pagos fraccionados ingresados
// ═══════════════════════════════════════════════════════════════════════════════

class Mod200Calculator {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String empresaId, String sub) =>
      _db.collection('empresas').doc(empresaId).collection(sub);

  /// Calcula el Modelo 200 para un ejercicio dado.
  Future<Modelo200> calcular({
    required String empresaId,
    required int ejercicio,
    TipoGravamenIS tipoGravamen = TipoGravamenIS.general,
    double c547BasesNegativas = 0,
  }) async {
    final inicio = DateTime(ejercicio, 1, 1);
    final fin    = DateTime(ejercicio + 1, 1, 1);

    // ── [01] Ingresos y gastos del ejercicio ───────────────────────────────
    final totalIngresos = await _sumarIngresos(empresaId, inicio, fin);
    final totalGastos   = await _sumarGastos(empresaId, inicio, fin);
    final resultadoContable = totalIngresos - totalGastos;

    // ── Retenciones soportadas (clientes que retuvieron al facturar) ───────
    final retenciones = await _sumarRetenciones(empresaId, inicio, fin);

    // ── [599] Pagos fraccionados ingresados vía Modelo 202 ─────────────────
    final pagosFraccionados = await _sumarPagosFraccionados202(empresaId, ejercicio);

    return Modelo200(
      id:                      Modelo200.docId(ejercicio),
      empresaId:               empresaId,
      ejercicio:               ejercicio,
      fechaGeneracion:         DateTime.now(),
      c01ResultadoContable:    _r2(resultadoContable),
      c547BasesNegativas:      _r2(c547BasesNegativas),
      tipoGravamen:            tipoGravamen,
      c598Retenciones:         _r2(retenciones),
      c599PagosFraccionados:   _r2(pagosFraccionados),
      totalIngresosEjercicio:  _r2(totalIngresos),
      totalGastosEjercicio:    _r2(totalGastos),
    );
  }

  // ── Suma base imponible de facturas emitidas del período ──────────────────
  Future<double> _sumarIngresos(String empresaId, DateTime inicio, DateTime fin) async {
    final snap = await _col(empresaId, 'facturas')
        .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs.fold<double>(0.0, (sum, d) {
      final data = d.data();
      if ((data['estado'] as String?) == 'anulada') return sum;
      return sum + ((data['base_imponible'] as num?)?.toDouble() ?? 0);
    });
  }

  // ── Suma gastos del período (facturas recibidas + gastos internos) ─────────
  Future<double> _sumarGastos(String empresaId, DateTime inicio, DateTime fin) async {
    // Facturas recibidas
    double total = 0;
    final facturasSnap = await _col(empresaId, 'facturas_recibidas')
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();
    for (final d in facturasSnap.docs) {
      final data = d.data();
      if ((data['estado'] as String?) == 'rechazada') continue;
      total += (data['base_imponible'] as num?)?.toDouble() ?? 0;
    }

    // Gastos internos
    final gastosSnap = await _col(empresaId, 'gastos')
        .where('fecha_gasto', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_gasto', isLessThan: Timestamp.fromDate(fin))
        .get();
    for (final d in gastosSnap.docs) {
      final data = d.data();
      if ((data['estado'] as String?) == 'anulado') continue;
      total += (data['base_imponible'] as num?)?.toDouble() ?? 0;
    }

    return total;
  }

  // ── Suma retenciones IRPF soportadas en facturas emitidas ─────────────────
  Future<double> _sumarRetenciones(String empresaId, DateTime inicio, DateTime fin) async {
    final snap = await _col(empresaId, 'facturas')
        .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs.fold<double>(0.0, (sum, d) {
      final data = d.data();
      if ((data['estado'] as String?) == 'anulada') return sum;
      return sum + ((data['retencion_irpf'] as num?)?.toDouble() ?? 0);
    });
  }

  // ── Suma pagos fraccionados IS del ejercicio (Modelo 202 × 3) ─────────────
  Future<double> _sumarPagosFraccionados202(String empresaId, int ejercicio) async {
    double total = 0;
    for (final periodo in ['1P', '2P', '3P']) {
      final docId = '202_${ejercicio}_$periodo';
      final snap  = await _col(empresaId, 'modelos_fiscales').doc(docId).get();
      if (snap.exists) {
        total += (snap.data()?['resultado_ingresar'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  /// Guarda el modelo calculado en Firestore.
  Future<void> guardar(String empresaId, Modelo200 modelo) async {
    await _col(empresaId, 'modelos_fiscales')
        .doc(modelo.id)
        .set({
          ...modelo.toFirestore(),
          'fecha_calculo': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Marca como presentado con justificante opcional.
  Future<void> marcarPresentado(String empresaId, int ejercicio, String? justificante) async {
    await _col(empresaId, 'modelos_fiscales').doc(Modelo200.docId(ejercicio)).update({
      'estado': 'presentado',
      'fecha_presentacion': FieldValue.serverTimestamp(),
      if (justificante != null && justificante.isNotEmpty)
        'justificante_aeat': justificante,
    });
  }

  /// Stream del Modelo 200 de un ejercicio.
  Stream<Modelo200?> obtener(String empresaId, int ejercicio) {
    return _col(empresaId, 'modelos_fiscales')
        .doc(Modelo200.docId(ejercicio))
        .snapshots()
        .map((snap) => snap.exists ? Modelo200.fromFirestore(snap) : null);
  }

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
}
