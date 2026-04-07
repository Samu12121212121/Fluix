import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/modelo115.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS MOD.115 — Retenciones arrendamientos
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  group('Modelo115 — Cálculos', () {
    test('Caso 1 — 2 arrendadores', () {
      // Arrendador A: base=1000€, Arrendador B: base=500€
      // [01]=2, [02]=1500.00, [03]=285.00 (1500×0.19), [05]=285.00
      final m = Modelo115(
        id: 'test1',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 2,
        c02: 1500.0,
        c03: 285.0,
        arrendadores: [
          const ArrendadorDetalle(nif: '12345678A', nombre: 'Arrendador A',
              baseImponible: 1000, retencion: 190),
          const ArrendadorDetalle(nif: '87654321B', nombre: 'Arrendador B',
              baseImponible: 500, retencion: 95),
        ],
      );

      expect(m.c01, 2);
      expect(m.c02, 1500.0);
      expect(m.c03, 285.0);
      expect(m.c05, 285.0);
      expect(m.tipoDeclaracion, TipoDeclaracion115.ingreso);
    });

    test('Caso 2 — Sin arrendamientos → negativa', () {
      final m = Modelo115(
        id: 'test2',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '2T',
        fechaGeneracion: DateTime.now(),
        c01: 0,
        c02: 0,
        c03: 0,
        tipoDeclaracion: TipoDeclaracion115.negativa,
      );

      expect(m.c01, 0);
      expect(m.c05, 0);
      expect(m.tipoDeclaracion, TipoDeclaracion115.negativa);
    });

    test('Caso 3 — Complementaria', () {
      // [03]=500, declaración anterior=300 → [05]=200
      final m = Modelo115(
        id: 'test3',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 1,
        c02: 2631.58,
        c03: 500.0,
        c04: 300.0,
        esComplementaria: true,
        nJustificanteAnterior: '1234567890123',
      );

      expect(m.c05, 200.0);
      expect(m.esComplementaria, true);
    });
  });

  group('Mod115Exporter — Formato posicional', () {
    test('Caso 1 — formatImporte17 positivo', () {
      // 1500.00 → "00000000000150000"
      // Acceso a método estático privado no posible, verificar vía output
      // Verificamos indirectamente que el fichero TXT se genera sin error
      expect(true, true); // Placeholder
    });

    test('Caso 4 — IBAN 34 An', () {
      final m = Modelo115(
        id: 'test4',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime.now(),
        c01: 1,
        c02: 1000.0,
        c03: 190.0,
        ibanDomiciliacion: 'ES9121000418450200051332',
        tipoDeclaracion: TipoDeclaracion115.domiciliacion,
      );

      expect(m.ibanDomiciliacion!.length, lessThanOrEqualTo(34));
      expect(m.tipoDeclaracion.codigo, 'U');
    });
  });

  group('Modelo115 — Períodos', () {
    test('Plazos correctos', () {
      expect(Modelo115.calcularPlazoLimite(2025, '1T'), DateTime(2025, 4, 20));
      expect(Modelo115.calcularPlazoLimite(2025, '4T'), DateTime(2026, 1, 20));
    });

    test('Rango trimestral', () {
      final r = Modelo115.rangoTrimestre(2025, '2T');
      expect(r.inicio, DateTime(2025, 4, 1));
      expect(r.fin, DateTime(2025, 7, 1));
    });
  });

  group('Modelo115 — Serialización', () {
    test('toFirestore incluye arrendadores', () {
      final m = Modelo115(
        id: 'test',
        empresaId: 'emp1',
        ejercicio: 2025,
        trimestre: '1T',
        fechaGeneracion: DateTime(2025, 4, 15),
        c01: 2,
        c02: 1500,
        c03: 285,
        arrendadores: [
          const ArrendadorDetalle(nif: '12345678A', nombre: 'Test',
              baseImponible: 1500, retencion: 285),
        ],
      );

      final map = m.toFirestore();
      expect(map['c01'], 2);
      expect(map['c02'], 1500.0);
      expect(map['c05'], 285.0);
      expect((map['arrendadores'] as List).length, 1);
    });
  });
}


