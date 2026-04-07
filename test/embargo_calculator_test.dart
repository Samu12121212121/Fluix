import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/embargo_calculator.dart';

/// Tests unitarios para EmbargoCalculator — Art. 607 LEC (2026).
///
/// Tabla de tramos (SMI 2026 = 1.381,20 €/mes):
///  Tramo 1: ≤ 1 SMI (0 – 1.381,20 €) → inembargable (0%)
///  Tramo 2: 1–2 SMI (1.381,21 – 2.762,40 €) → 30%
///  Tramo 3: 2–3 SMI (2.762,41 – 4.143,60 €) → 50%
///  Tramo 4: 3–4 SMI (4.143,61 – 5.524,80 €) → 60%
///  Tramo 5: 4–5 SMI (5.524,81 – 6.906,00 €) → 75%
///  Tramo 6: > 5 SMI (> 6.906,00 €) → 90%
void main() {
  const smi = 1381.20;

  // ═══════════════════════════════════════════════════════════════════════════
  // INEMBARGABILIDAD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 1 — Salario ≤ 1 SMI: totalmente inembargable', () {
    test('Salario 0 → embargo 0', () {
      expect(EmbargoCalculator.calcularMaximoEmbargable(0), 0);
    });

    test('Salario negativo → embargo 0', () {
      expect(EmbargoCalculator.calcularMaximoEmbargable(-500), 0);
    });

    test('Salario exacto = 1 SMI (${smi}€) → embargo 0', () {
      expect(EmbargoCalculator.calcularMaximoEmbargable(smi), 0);
    });

    test('Salario 1.000€ < SMI → embargo 0', () {
      expect(EmbargoCalculator.calcularMaximoEmbargable(1000), 0);
    });

    test('Salario 1.381,19€ (1 céntimo bajo SMI) → embargo 0', () {
      expect(EmbargoCalculator.calcularMaximoEmbargable(smi - 0.01), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMO 2: 1–2 SMI → 30%
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 2 — Entre 1 y 2 SMI: 30% del exceso', () {
    test('Salario 1.381,21€ (1 céntimo sobre SMI) → embargo ≈ 0,003€', () {
      final resultado = EmbargoCalculator.calcularMaximoEmbargable(smi + 0.01);
      expect(resultado, closeTo(0.01 * 0.30, 0.01));
    });

    test('Salario 2.000€ → exceso 618,80 × 30% = 185,64€', () {
      final exceso = 2000 - smi;
      final esperado = exceso * 0.30;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(2000),
        closeTo(esperado, 0.01),
      );
    });

    test('Salario 2.762,40€ (exacto 2 SMI) → exceso = 1 SMI × 30% = 414,36€', () {
      final exceso = smi;
      final esperado = exceso * 0.30;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(smi * 2),
        closeTo(esperado, 0.01),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMO 3: 2–3 SMI → 50%
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 3 — Entre 2 y 3 SMI: +50% del exceso', () {
    test('Salario 3.000€ → tramo2(414,36) + (3000−2762,40)×50%', () {
      final tramo2 = smi * 0.30; // 414,36
      final excesoTramo3 = 3000 - (smi * 2);
      final esperado = tramo2 + excesoTramo3 * 0.50;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(3000),
        closeTo(esperado, 0.01),
      );
    });

    test('Salario 4.143,60€ (exacto 3 SMI)', () {
      final tramo2 = smi * 0.30;
      final tramo3 = smi * 0.50;
      final esperado = tramo2 + tramo3;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(smi * 3),
        closeTo(esperado, 0.01),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMO 4: 3–4 SMI → 60%
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 4 — Entre 3 y 4 SMI: +60% del exceso', () {
    test('Salario 5.524,80€ (exacto 4 SMI)', () {
      final tramo2 = smi * 0.30;
      final tramo3 = smi * 0.50;
      final tramo4 = smi * 0.60;
      final esperado = tramo2 + tramo3 + tramo4;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(smi * 4),
        closeTo(esperado, 0.01),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMO 5: 4–5 SMI → 75%
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 5 — Entre 4 y 5 SMI: +75% del exceso', () {
    test('Salario 6.906,00€ (exacto 5 SMI)', () {
      final tramo2 = smi * 0.30;
      final tramo3 = smi * 0.50;
      final tramo4 = smi * 0.60;
      final tramo5 = smi * 0.75;
      final esperado = tramo2 + tramo3 + tramo4 + tramo5;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(smi * 5),
        closeTo(esperado, 0.01),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMO 6: > 5 SMI → 90%
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramo 6 — Más de 5 SMI: +90% del exceso', () {
    test('Salario 8.000€ → todos los tramos + (8000−6906)×90%', () {
      final tramo2 = smi * 0.30;
      final tramo3 = smi * 0.50;
      final tramo4 = smi * 0.60;
      final tramo5 = smi * 0.75;
      final exceso6 = 8000 - (smi * 5);
      final tramo6 = exceso6 * 0.90;
      final esperado = tramo2 + tramo3 + tramo4 + tramo5 + tramo6;
      expect(
        EmbargoCalculator.calcularMaximoEmbargable(8000),
        closeTo(esperado, 0.01),
      );
    });

    test('Salario alto: 15.000€ → embargo significativo', () {
      final resultado = EmbargoCalculator.calcularMaximoEmbargable(15000);
      // Siempre < salario neto
      expect(resultado, greaterThan(0));
      expect(resultado, lessThan(15000));
      // El primer SMI siempre queda protegido
      final netoTrasEmbargo = 15000 - resultado;
      expect(netoTrasEmbargo, greaterThanOrEqualTo(smi));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EMBARGO CON TOPE JUDICIAL
  // ═══════════════════════════════════════════════════════════════════════════

  group('calcularEmbargoMes — con tope judicial', () {
    test('Sin tope: usa el máximo de la tabla', () {
      final maximo = EmbargoCalculator.calcularMaximoEmbargable(3000);
      final embargo = EmbargoCalculator.calcularEmbargoMes(3000);
      expect(embargo, maximo);
    });

    test('Tope judicial de 200€ respeta el tope', () {
      final embargo = EmbargoCalculator.calcularEmbargoMes(
        3000,
        importeMensualMaximo: 200,
      );
      expect(embargo, lessThanOrEqualTo(200));
    });

    test('Tope judicial mayor que máximo legal: usa el máximo legal', () {
      final maximo = EmbargoCalculator.calcularMaximoEmbargable(2000);
      final embargo = EmbargoCalculator.calcularEmbargoMes(
        2000,
        importeMensualMaximo: 50000,
      );
      expect(embargo, maximo);
    });

    test('Tope judicial 0: embargo 0', () {
      // Un tope de importeMensualMaximo > 0 se requiere
      // Aquí el clamp(0, 0) = 0 pero verificamos el comportamiento
      final embargo = EmbargoCalculator.calcularEmbargoMes(
        3000,
        importeMensualMaximo: 0,
      );
      expect(embargo, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DESGLOSE DETALLADO
  // ═══════════════════════════════════════════════════════════════════════════

  group('desglosarCalculo — detalle por tramos', () {
    test('Salario bajo SMI: lista de tramos vacía', () {
      final d = EmbargoCalculator.desglosarCalculo(1000);
      expect(d.tramos, isEmpty);
      expect(d.totalEmbargable, 0);
      expect(d.porcentajeEfectivo, 0);
    });

    test('Salario 3.500€: desglose con 2 tramos', () {
      final d = EmbargoCalculator.desglosarCalculo(3500);
      expect(d.tramos.length, 2); // tramo 2 y tramo 3
      expect(d.tramos[0].porcentaje, 30);
      expect(d.tramos[1].porcentaje, 50);
      expect(d.totalEmbargable, greaterThan(0));
      expect(d.porcentajeEfectivo, greaterThan(0));
      expect(d.porcentajeEfectivo, lessThan(50)); // media ponderada < 50%
    });

    test('Salario 10.000€: desglose con 5 tramos', () {
      final d = EmbargoCalculator.desglosarCalculo(10000);
      expect(d.tramos.length, 5);
      expect(d.tramos[0].porcentaje, 30);
      expect(d.tramos[1].porcentaje, 50);
      expect(d.tramos[2].porcentaje, 60);
      expect(d.tramos[3].porcentaje, 75);
      expect(d.tramos[4].porcentaje, 90);
    });

    test('totalEmbargable del desglose coincide con calcularMaximoEmbargable', () {
      for (final salario in [2000.0, 3000.0, 5000.0, 8000.0, 15000.0]) {
        final desglose = EmbargoCalculator.desglosarCalculo(salario);
        final directo = EmbargoCalculator.calcularMaximoEmbargable(salario);
        expect(desglose.totalEmbargable, closeTo(directo, 0.01),
            reason: 'Falla para salario $salario');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO REAL: CAMARERO BAR GUADALAJARA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso real: Camarero bar Guadalajara con embargo judicial', () {
    test('Neto 1.350€ (bajo SMI) → inembargable', () {
      // Salario neto mensual típico de un camarero a jornada parcial
      expect(EmbargoCalculator.calcularMaximoEmbargable(1350), 0);
    });

    test('Neto 1.650€ → embargo tramo 2', () {
      // Camarero a jornada completa con propinas declaradas
      final exceso = 1650 - smi; // 268,80€
      final esperado = exceso * 0.30; // 80,64€
      final embargo = EmbargoCalculator.calcularMaximoEmbargable(1650);
      expect(embargo, closeTo(esperado, 0.01));
      // Al camarero le quedan al menos 1.381,20€ + 188,16€
      expect(1650 - embargo, greaterThanOrEqualTo(smi));
    });

    test('Juzgado fija tope 150€/mes pero tabla permite 80,64€ → aplica tabla', () {
      final embargo = EmbargoCalculator.calcularEmbargoMes(
        1650,
        importeMensualMaximo: 150,
      );
      final maxTabla = EmbargoCalculator.calcularMaximoEmbargable(1650);
      expect(embargo, maxTabla); // porque maxTabla (80,64) < 150
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Constantes SMI 2026', () {
    test('SMI 2026 = 1.381,20€', () {
      expect(EmbargoCalculator.smi2026, 1381.20);
    });
  });
}

