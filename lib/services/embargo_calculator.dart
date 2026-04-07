// ═════════════════════════════════════════════════════════════════════════════
// CALCULADORA DE EMBARGOS JUDICIALES — Art. 607 LEC (2026)
// ═════════════════════════════════════════════════════════════════════════════
//
// Tabla de inembargabilidad vigente (SMI mensual 2026 = 1.381,20 €/mes):
//
//  Tramo 1:  ≤ 1 SMI (0 – 1.381,20 €)      → inembargable (0%)
//  Tramo 2:  1 – 2 SMI (1.381,21 – 2.762,40 €) → embargable al 30%
//  Tramo 3:  2 – 3 SMI (2.762,41 – 4.143,60 €) → embargable al 50%
//  Tramo 4:  3 – 4 SMI (4.143,61 – 5.524,80 €) → embargable al 60%
//  Tramo 5:  4 – 5 SMI (5.524,81 – 6.906,00 €) → embargable al 75%
//  Tramo 6:  > 5 SMI (> 6.906,00 €)            → embargable al 90%
//
// Referencia: BOE-A-2000-323 (LEC), actualizado RD 145/2024 (SMI provisional 2026).
// ═════════════════════════════════════════════════════════════════════════════

class EmbargoCalculator {
  /// SMI mensual de referencia 2026 (provisional hasta publicación oficial).
  /// Igual al base mínimo de cotización SS → 1.381,20 €/mes.
  static const double smi2026 = 1381.20;

  /// Tabla de tramos art. 607 LEC:
  /// Cada entrada: (porcentaje_embargable, tamaño_tramo_en_SMIs)
  static const List<_Tramo> _tabla = [
    _Tramo(pct: 0.30, tramos: 1), // entre 1 y 2 SMI
    _Tramo(pct: 0.50, tramos: 1), // entre 2 y 3 SMI
    _Tramo(pct: 0.60, tramos: 1), // entre 3 y 4 SMI
    _Tramo(pct: 0.75, tramos: 1), // entre 4 y 5 SMI
    _Tramo(pct: 0.90, tramos: double.infinity), // más de 5 SMI
  ];

  /// Calcula el importe máximo embargable del salario neto según art. 607 LEC.
  ///
  /// [salarioNeto] es el neto MENSUAL después de SS e IRPF (no el bruto).
  /// Devuelve 0 si el neto ≤ 1 SMI (totalmente inembargable).
  static double calcularMaximoEmbargable(double salarioNeto) {
    if (salarioNeto <= smi2026) return 0.0;

    double embargable = 0.0;
    double exceso = salarioNeto - smi2026; // exceso por encima del primer SMI

    for (final tramo in _tabla) {
      if (exceso <= 0) break;
      final tamanoTramo = tramo.tramos == double.infinity
          ? exceso
          : (smi2026 * tramo.tramos);
      final baseTramo = exceso.clamp(0.0, tamanoTramo);
      embargable += baseTramo * tramo.pct;
      exceso -= tamanoTramo;
    }

    return double.parse(embargable.toStringAsFixed(2));
  }

  /// Calcula el embargo efectivo para el mes.
  ///
  /// Aplica la tabla 607 LEC y respeta el tope judicial si existe.
  /// [importeMensualMaximo] = tope fijado por el juzgado (null = sin tope).
  static double calcularEmbargoMes(
    double salarioNeto, {
    double? importeMensualMaximo,
  }) {
    final maxLec = calcularMaximoEmbargable(salarioNeto);
    if (importeMensualMaximo != null && importeMensualMaximo > 0) {
      return maxLec.clamp(0.0, importeMensualMaximo);
    }
    return maxLec;
  }

  /// Devuelve un desglose detallado de la aplicación de la tabla LEC.
  /// Útil para mostrar al administrador cómo se calcula el embargo.
  static DesgloseLec desglosarCalculo(double salarioNeto) {
    if (salarioNeto <= smi2026) {
      return DesgloseLec(
        salarioNeto: salarioNeto,
        tramos: [],
        totalEmbargable: 0,
        porcentajeEfectivo: 0,
      );
    }

    final tramosResult = <TramoResultado>[];
    double exceso = salarioNeto - smi2026;
    double totalEmbargable = 0;

    for (int i = 0; i < _tabla.length; i++) {
      if (exceso <= 0) break;
      final tramo = _tabla[i];
      final tamano = tramo.tramos == double.infinity
          ? exceso
          : (smi2026 * tramo.tramos);
      final base = exceso.clamp(0.0, tamano);
      final importeTramo = base * tramo.pct;
      tramosResult.add(TramoResultado(
        numero: i + 2, // tramo 2 es el primero embargable
        desde: smi2026 * (i + 1),
        hasta: tramo.tramos == double.infinity ? null : smi2026 * (i + 2),
        porcentaje: tramo.pct * 100,
        baseAplicada: base,
        importe: double.parse(importeTramo.toStringAsFixed(2)),
      ));
      totalEmbargable += importeTramo;
      exceso -= tamano;
    }

    return DesgloseLec(
      salarioNeto: salarioNeto,
      tramos: tramosResult,
      totalEmbargable: double.parse(totalEmbargable.toStringAsFixed(2)),
      porcentajeEfectivo: salarioNeto > 0
          ? (totalEmbargable / salarioNeto * 100)
          : 0,
    );
  }
}

// ── Clases auxiliares ─────────────────────────────────────────────────────────

class _Tramo {
  final double pct;
  final double tramos; // en múltiplos de SMI (double.infinity = ilimitado)
  const _Tramo({required this.pct, required this.tramos});
}

class TramoResultado {
  final int numero;
  final double desde;
  final double? hasta; // null = sin límite superior
  final double porcentaje;
  final double baseAplicada;
  final double importe;

  const TramoResultado({
    required this.numero,
    required this.desde,
    this.hasta,
    required this.porcentaje,
    required this.baseAplicada,
    required this.importe,
  });
}

class DesgloseLec {
  final double salarioNeto;
  final List<TramoResultado> tramos;
  final double totalEmbargable;
  final double porcentajeEfectivo;

  const DesgloseLec({
    required this.salarioNeto,
    required this.tramos,
    required this.totalEmbargable,
    required this.porcentajeEfectivo,
  });
}

