import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/modelo130.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS MOD.130 — Pago fraccionado IRPF autónomos
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  group('Modelo130 — Cálculos de casillas', () {
    test('Caso 1 — T1 normal', () {
      // ingresos=30000, gastos=12000, retenciones=1500, pagosAnt=0
      final m = Modelo130(
        id: 'test1',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 30000,
        c02: 12000,
        c05: 0,
        c06: 1500,
      );

      expect(m.c03, 18000.0);          // [03] = 30000 - 12000
      expect(m.c04, 3600.0);           // [04] = 18000 * 0.20
      expect(m.c07, 2100.0);           // [07] = 3600 - 0 - 1500
      expect(m.c12, 2100.0);           // [12] = [07]
      expect(m.c19, 2100.0);           // [19] = 2100
      expect(m.esAIngresar, true);
    });

    test('Caso 2 — T2 acumulado', () {
      // ingresos_YTD=55000, gastos_YTD=22000, retenciones_YTD=2800, pagosAnt=2100
      final m = Modelo130(
        id: 'test2',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '2T',
        fechaGeneracion: DateTime.now(),
        c01: 55000,
        c02: 22000,
        c05: 2100,
        c06: 2800,
      );

      expect(m.c03, 33000.0);          // [03] = 55000 - 22000
      expect(m.c04, 6600.0);           // [04] = 33000 * 0.20
      expect(m.c07, 1700.0);           // [07] = 6600 - 2100 - 2800
      expect(m.c12, 1700.0);
      expect(m.c19, 1700.0);
      expect(m.esAIngresar, true);
    });

    test('Caso 3 — Resultado negativo (a deducir)', () {
      // ingresos=8000, gastos=5000, retenciones=900, pagosAnt=400
      final m = Modelo130(
        id: 'test3',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 8000,
        c02: 5000,
        c05: 400,
        c06: 900,
      );

      expect(m.c03, 3000.0);           // [03] = 8000 - 5000
      expect(m.c04, 600.0);            // [04] = 3000 * 0.20
      expect(m.c07, -700.0);           // [07] = 600 - 400 - 900
      expect(m.c12, -700.0);
      expect(m.c14, -700.0);
      expect(m.c19, -700.0);
      expect(m.esADeducir, true);
      expect(m.esAIngresar, false);
    });

    test('Caso 4 — Complementaria', () {
      final m = Modelo130(
        id: 'test4',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 30000,
        c02: 12000,
        c05: 0,
        c06: 1500,
        c18: 500,
        esComplementaria: true,
      );

      expect(m.c07, 2100.0);
      expect(m.c17, 2100.0);
      expect(m.c19, 1600.0);           // [19] = 2100 - 500
    });

    test('Caso 5 — Rendimiento neto negativo → [04] = 0', () {
      final m = Modelo130(
        id: 'test5',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 5000,
        c02: 8000,
        c05: 0,
        c06: 0,
      );

      expect(m.c03, -3000.0);          // Negativo
      expect(m.c04, 0.0);              // 20% de negativo = 0
      expect(m.c07, 0.0);
      expect(m.c19, 0.0);
    });

    test('Deducción vivienda máx 660.14€', () {
      final m = Modelo130(
        id: 'test6',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 30000,
        c02: 12000,
        c05: 0,
        c06: 0,
        c16: 660.14,
      );

      expect(m.c04, 3600.0);
      expect(m.c17, closeTo(3600 - 660.14, 0.01));
    });
  });

  group('Modelo130 — Períodos y plazos', () {
    test('Plazos correctos', () {
      expect(Modelo130.calcularPlazoLimite(2025, '1T'), DateTime(2025, 4, 20));
      expect(Modelo130.calcularPlazoLimite(2025, '2T'), DateTime(2025, 7, 20));
      expect(Modelo130.calcularPlazoLimite(2025, '3T'), DateTime(2025, 10, 20));
      expect(Modelo130.calcularPlazoLimite(2025, '4T'), DateTime(2026, 1, 30));
    });

    test('Rango YTD correcto', () {
      final ytd1 = Modelo130.rangoYTD(2025, '1T');
      expect(ytd1.inicio, DateTime(2025, 1, 1));
      expect(ytd1.fin, DateTime(2025, 4, 1));

      final ytd3 = Modelo130.rangoYTD(2025, '3T');
      expect(ytd3.inicio, DateTime(2025, 1, 1));
      expect(ytd3.fin, DateTime(2025, 10, 1));

      final ytd4 = Modelo130.rangoYTD(2025, '4T');
      expect(ytd4.inicio, DateTime(2025, 1, 1));
      expect(ytd4.fin, DateTime(2026, 1, 1));
    });

    test('Trimestres anteriores correctos', () {
      expect(Modelo130.trimestresAnteriores('1T'), isEmpty);
      expect(Modelo130.trimestresAnteriores('2T'), ['1T']);
      expect(Modelo130.trimestresAnteriores('3T'), ['1T', '2T']);
      expect(Modelo130.trimestresAnteriores('4T'), ['1T', '2T', '3T']);
    });
  });

  group('Modelo130 — Serialización', () {
    test('toFirestore incluye todas las casillas', () {
      final m = Modelo130(
        id: 'test',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime(2025, 4, 15),
        c01: 30000,
        c02: 12000,
        c05: 0,
        c06: 1500,
      );

      final map = m.toFirestore();
      expect(map['c01'], 30000.0);
      expect(map['c02'], 12000.0);
      expect(map['c03'], 18000.0);
      expect(map['c04'], 3600.0);
      expect(map['c07'], 2100.0);
      expect(map['c19'], 2100.0);
      expect(map['trimestre'], '1T');
      expect(map['ejercicio'], 2025);
    });
  });
}

