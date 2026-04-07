import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/modelo390.dart';
import '../../domain/modelos/factura.dart';
import '../mod_303_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.390 CALCULATOR — Declaración-Resumen Anual IVA
// Consolida los 4 Mod.303 del ejercicio + volumen de operaciones
// ═══════════════════════════════════════════════════════════════════════════════

class Mod390Calculator {
  static final Mod390Calculator _i = Mod390Calculator._();
  factory Mod390Calculator() => _i;
  Mod390Calculator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Mod303Service _mod303Svc = Mod303Service();

  CollectionReference<Map<String, dynamic>> _modelos390(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos390');

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Modelo390> calcular({
    required String empresaId,
    required int ejercicio,
    double c63Manual = 0,
    double c522Manual = 0,
    double c85Manual = 0,
    String actividadPrincipal = '',
    String claveActividad = 'A03',
    String epigrafIAE = '',
  }) async {
    // 1. Obtener datos de los 4 trimestres del Mod.303
    final alertas = <String>[];
    final trimestresData = <int, Map<String, dynamic>>{};

    for (int t = 1; t <= 4; t++) {
      try {
        final datos = await _mod303Svc.calcularMod303(
          empresaId: empresaId,
          anio: ejercicio,
          trimestre: t,
        );
        trimestresData[t] = datos;
      } catch (e) {
        alertas.add('⚠️ ADVERTENCIA: No se pudieron obtener datos del ${t}T. '
            'El Mod.390 puede estar incompleto.');
      }
    }

    if (trimestresData.length < 4) {
      final faltantes = [1, 2, 3, 4]
          .where((t) => !trimestresData.containsKey(t))
          .map((t) => '${t}T')
          .join(', ');
      alertas.add('⚠️ Faltan trimestres: $faltantes');
    }

    // 2. Sumar casillas IVA devengado de los 4 trimestres
    double sumBaseSR = 0, sumCuotaSR = 0;     // 4% super-reducido
    double sumBaseR = 0, sumCuotaR = 0;       // 10% reducido
    double sumBaseG = 0, sumCuotaG = 0;       // 21% general
    double sumIvaSoportado = 0;
    double sumTotalRepercutido = 0;

    for (final datos in trimestresData.values) {
      sumBaseSR += (datos['base_super_reducida'] as num?)?.toDouble() ?? 0;
      sumCuotaSR += (datos['cuota_super_reducida'] as num?)?.toDouble() ?? 0;
      sumBaseR += (datos['base_reducida'] as num?)?.toDouble() ?? 0;
      sumCuotaR += (datos['cuota_reducida'] as num?)?.toDouble() ?? 0;
      sumBaseG += (datos['base_general'] as num?)?.toDouble() ?? 0;
      sumCuotaG += (datos['cuota_general'] as num?)?.toDouble() ?? 0;
      sumIvaSoportado += (datos['iva_soportado'] as num?)?.toDouble() ?? 0;
      sumTotalRepercutido += (datos['total_repercutido'] as num?)?.toDouble() ?? 0;
    }

    // 3. Calcular volumen de operaciones
    final c99 = await _calcularVolumenOperaciones(empresaId, ejercicio);

    // 4. Verificar coherencia
    final c47Calculado = _r2(sumCuotaSR + sumCuotaR + sumCuotaG);
    final diffDevengado = (c47Calculado - sumTotalRepercutido).abs();
    if (diffDevengado > 1.0) {
      alertas.add('⚠️ La cuota devengada total no cuadra con los trimestres. '
          'Diferencia: ${diffDevengado.toStringAsFixed(2)} €. '
          'Revisa si hay modificaciones de bases/cuotas.');
    }

    final docRef = _modelos390(empresaId).doc();

    return Modelo390(
      id: docRef.id,
      empresaId: empresaId,
      ejercicio: ejercicio,
      fechaGeneracion: DateTime.now(),
      // Devengado
      c01: _r2(sumBaseSR), c02: _r2(sumCuotaSR),
      c03: _r2(sumBaseR), c04: _r2(sumCuotaR),
      c05: _r2(sumBaseG), c06: _r2(sumCuotaG),
      // Deducible — para PYMEs CLM todo va a interiores corrientes
      c48: 0, c49: _r2(sumIvaSoportado),
      // Campos manuales
      c63: _r2(c63Manual),
      c522: _r2(c522Manual),
      c85: _r2(c85Manual),
      // Volumen operaciones
      c99: _r2(c99),
      // Datos estadísticos
      actividadPrincipal: actividadPrincipal,
      claveActividad: claveActividad,
      epigrafIAE: epigrafIAE,
      alertas: alertas,
    );
  }

  /// Volumen de operaciones = suma de baseImponible de facturas emitidas del año
  Future<double> _calcularVolumenOperaciones(
    String empresaId, int ejercicio,
  ) async {
    final inicio = DateTime(ejercicio, 1, 1);
    final fin = DateTime(ejercicio + 1, 1, 1);

    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => Factura.fromFirestore(d))
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList()
        .fold<double>(0.0, (sum, f) => sum + f.subtotal);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> guardar(String empresaId, Modelo390 modelo) async {
    final existente = await _modelos390(empresaId)
        .where('ejercicio', isEqualTo: modelo.ejercicio)
        .limit(1)
        .get();

    if (existente.docs.isNotEmpty) {
      await existente.docs.first.reference.update(modelo.toFirestore());
    } else {
      await _modelos390(empresaId).doc(modelo.id).set(modelo.toFirestore());
    }
  }

  Future<void> marcarPresentado(String empresaId, String docId) async {
    await _modelos390(empresaId).doc(docId).update({'estado': 'presentado'});
  }

  Stream<Modelo390?> obtener(String empresaId, int ejercicio) {
    return _modelos390(empresaId)
        .where('ejercicio', isEqualTo: ejercicio)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isNotEmpty ? Modelo390.fromFirestore(snap.docs.first) : null);
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}


