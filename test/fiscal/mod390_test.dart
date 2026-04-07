import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/modelo390.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS MOD.390 — Resumen Anual IVA
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  group('Modelo390 — Cálculos de casillas', () {
    test('Caso 1 — Empresa con ventas al 21%', () {
      // 4 trimestres: c05=[10000,15000,12000,13000], c06=[2100,3150,2520,2730]
      // 390: c05=50000, c06=10500, c47=10500
      // c49=3300, c64=3300, c65=10500-3300=7200
      final m = Modelo390(
        id: 'test1',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
        c05: 50000,
        c06: 10500,
        c49: 3300,
        c99: 50000,
      );

      expect(m.c47, 10500.0);          // Solo cuota 21%
      expect(m.c64, 3300.0);           // Solo c49
      expect(m.c65, 7200.0);           // 10500 - 3300
      expect(m.c84, 7200.0);           // = c65 para PYMEs CLM
      expect(m.c86, 7200.0);           // c84 - c85(0)
    });

    test('Caso 2 — Empresa mixta 10% y 21%', () {
      // c03=8000, c04=800, c05=20000, c06=4200
      final m = Modelo390(
        id: 'test2',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
        c03: 8000,
        c04: 800,
        c05: 20000,
        c06: 4200,
        c49: 2000,
      );

      expect(m.c47, 5000.0);           // 800 + 4200
      expect(m.c64, 2000.0);
      expect(m.c65, 3000.0);           // 5000 - 2000
    });

    test('Caso 3 — Con compensación año anterior', () {
      final m = Modelo390(
        id: 'test3',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
        c05: 20000,
        c06: 4200,
        c49: 3000,
        c85: 500,   // compensación
      );

      expect(m.c47, 4200.0);
      expect(m.c65, 1200.0);           // 4200 - 3000
      expect(m.c84, 1200.0);
      expect(m.c86, 700.0);            // 1200 - 500
    });

    test('Caso 4 — Resultado negativo', () {
      final m = Modelo390(
        id: 'test4',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
        c05: 10000,
        c06: 2100,
        c49: 3000,
      );

      expect(m.c47, 2100.0);
      expect(m.c65, -900.0);           // 2100 - 3000
      expect(m.c86, -900.0);           // A devolver/compensar
    });

    test('Incluye tipos 4%, 10%, 21%', () {
      final m = Modelo390(
        id: 'test5',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
        c01: 5000, c02: 200,    // 4%
        c03: 10000, c04: 1000,  // 10%
        c05: 20000, c06: 4200,  // 21%
        c49: 2000,
      );

      expect(m.c47, 5400.0);           // 200 + 1000 + 4200
      expect(m.c65, 3400.0);           // 5400 - 2000
    });
  });

  group('Modelo390 — Plazo', () {
    test('Plazo es 30 enero del año siguiente', () {
      final m = Modelo390(
        id: 'test',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime.now(),
      );

      expect(m.plazoLimite, DateTime(2026, 1, 30));
    });
  });

  group('Modelo390 — Serialización', () {
    test('toFirestore incluye todas las casillas calculadas', () {
      final m = Modelo390(
        id: 'test',
        empresaId: 'emp1',
        ejercicio: 2025,
        fechaGeneracion: DateTime(2026, 1, 15),
        c05: 50000,
        c06: 10500,
        c49: 3300,
        c99: 50000,
        actividadPrincipal: 'Hostelería',
        epigrafIAE: '671',
      );

      final map = m.toFirestore();
      expect(map['c47'], 10500.0);
      expect(map['c64'], 3300.0);
      expect(map['c65'], 7200.0);
      expect(map['c84'], 7200.0);
      expect(map['c86'], 7200.0);
      expect(map['c99'], 50000.0);
      expect(map['epigraf_iae'], '671');
    });
  });
}

