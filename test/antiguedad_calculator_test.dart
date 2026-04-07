import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/antiguedad_calculator.dart';

/// Tests unitarios para el cálculo de antigüedad por convenio colectivo.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AÑOS COMPLETOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cálculo de años completos', () {
    test('Mismo día = 0 años', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2023, 3, 15), DateTime(2023, 3, 15)),
        0,
      );
    });

    test('1 día antes del aniversario = 0 años', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2023, 3, 15), DateTime(2024, 3, 14)),
        0,
      );
    });

    test('Justo el aniversario = 1 año', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2023, 3, 15), DateTime(2024, 3, 15)),
        1,
      );
    });

    test('7 años exactos', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2019, 6, 1), DateTime(2026, 6, 1)),
        7,
      );
    });

    test('15 años y medio', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2011, 1, 1), DateTime(2026, 7, 15)),
        15,
      );
    });

    test('Fecha futura devuelve 0', () {
      expect(
        AntiguedadCalculator.aniosCompletos(
            DateTime(2026, 3, 15), DateTime(2023, 1, 1)),
        0,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: HOSTELERÍA — 7 AÑOS, SALARIO 1.200€
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 1: Hostelería, 7 años, salario base 1.200€', () {
    test('2 trienios → 10% × 1.200 = 120€/mes', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2019, 1, 1),
        fechaCalculo: DateTime(2026, 3, 15),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.aniosCompletos, 7);
      expect(r.tramosCumplidos, 2);
      expect(r.tipoTramo, 'trienio');
      expect(r.importe, closeTo(120.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 2: HOSTELERÍA — 15+ AÑOS (MÁXIMO)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 2: Hostelería, 15+ años, salario base 1.200€', () {
    test('5 trienios (máximo) → 25% × 1.200 = 300€/mes', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2005, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.aniosCompletos, 21);
      expect(r.tramosCumplidos, 5); // máximo 5 trienios
      expect(r.importe, closeTo(300.0, 0.01));
    });

    test('18 años → sigue siendo 5 trienios (tope)', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2008, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1000,
      );
      expect(r.tramosCumplidos, 5);
      expect(r.importe, closeTo(250.0, 0.01)); // 25% × 1000
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 3: COMERCIO — 5 AÑOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 3: Comercio, 5 años, salario base 1.100€', () {
    test('2 bienios → 10% × 1.100 = 110€/mes', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2021, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1100,
      );
      expect(r.aniosCompletos, 5);
      expect(r.tramosCumplidos, 2);
      expect(r.tipoTramo, 'bienio');
      expect(r.importe, closeTo(110.0, 0.01));
    });

    test('Comercio 6 años → 3 bienios → 15% × 1.100 = 165€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2020, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1100,
      );
      expect(r.tramosCumplidos, 3);
      expect(r.importe, closeTo(165.0, 0.01));
    });

    test('Comercio sin límite → 10 bienios (20 años)', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2006, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1000,
      );
      expect(r.tramosCumplidos, 10);
      expect(r.importe, closeTo(500.0, 0.01)); // 50% × 1000
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 4: CONTRATO 15/03/2023, NÓMINA MARZO 2026 (CUMPLE 3 AÑOS)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 4: Cumple trienio justo en el mes de la nómina', () {
    test('Nómina 15/03/2026: ya cumple 3 años → aplica trienio', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2023, 3, 15),
        fechaCalculo: DateTime(2026, 3, 15), // justo el aniversario
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.aniosCompletos, 3);
      expect(r.tramosCumplidos, 1);
      expect(r.importe, closeTo(60.0, 0.01)); // 5% × 1200
    });

    test('Nómina 14/03/2026: NO cumple aún → 0 trienios', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2023, 3, 15),
        fechaCalculo: DateTime(2026, 3, 14), // un día antes
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.aniosCompletos, 2);
      expect(r.tramosCumplidos, 0);
      expect(r.importe, 0);
    });

    test('Nómina 31/03/2026: también aplica trienio', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2023, 3, 15),
        fechaCalculo: DateTime(2026, 3, 31), // fin de mes
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.tramosCumplidos, 1);
      expect(r.importe, closeTo(60.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 5: ANTIGÜEDAD MANUAL
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 5: Empleado con antiguedadManual = true', () {
    test('El calculador devuelve el importe automático — la lógica manual '
        'se aplica fuera (en nominas_service)', () {
      // Cuando antiguedadManual = true, nominas_service usa antiguedadManualImporte
      // en vez de llamar al calculador. El calculador siempre calcula automático.
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2020, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.importe, closeTo(120.0, 0.01)); // 2 trienios
      // En nominas_service: si antiguedadManual → usa 150€ (o lo que ponga el admin)
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PELUQUERÍA / VETERINARIOS: SIN ANTIGÜEDAD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Convenios sin antigüedad automática', () {
    test('Peluquería → 0€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2015, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convPeluqueria,
        salarioBase: 1200,
      );
      expect(r.importe, 0);
      expect(r.tramosCumplidos, 0);
    });

    test('Veterinarios → 0€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2015, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convVeterinarios,
        salarioBase: 1500,
      );
      expect(r.importe, 0);
    });

    test('Convenio desconocido → 0€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2015, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: 'otro_sector',
        salarioBase: 1200,
      );
      expect(r.importe, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // INDUSTRIAS CÁRNICAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Industrias Cárnicas — trienios por nivel', () {
    test('Nivel 5, 7 años → 2 trienios × 34€ = 68€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2019, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convCarnicas,
        salarioBase: 1200, // no se usa para cárnicas (importe fijo)
        nivelCategoriaCarnicas: 5,
      );
      expect(r.tramosCumplidos, 2);
      expect(r.importe, closeTo(68.0, 0.01));
    });

    test('Nivel 1, 9 años → 3 trienios × 45€ = 135€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2017, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convCarnicas,
        salarioBase: 0,
        nivelCategoriaCarnicas: 1,
      );
      expect(r.tramosCumplidos, 3);
      expect(r.importe, closeTo(135.0, 0.01));
    });

    test('Nivel 6, 6 años → 2 trienios × 32€ = 64€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2020, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convCarnicas,
        salarioBase: 0,
        nivelCategoriaCarnicas: 6,
      );
      expect(r.tramosCumplidos, 2);
      expect(r.importe, closeTo(64.0, 0.01));
    });

    test('Menos de 3 años → 0€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2024, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convCarnicas,
        salarioBase: 0,
        nivelCategoriaCarnicas: 3,
      );
      expect(r.importe, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // HOSTELERÍA — MENOS DE 3 AÑOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Hostelería — empleados nuevos', () {
    test('1 año → 0 trienios → 0€', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2025, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.importe, 0);
      expect(r.tramosCumplidos, 0);
    });

    test('2 años y 11 meses → 0 trienios', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2023, 4, 1),
        fechaCalculo: DateTime(2026, 3, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.importe, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PRÓXIMO CAMBIO DE TRAMO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Próximo cambio de tramo', () {
    test('Hostelería: contrato 01/05/2023 → próximo trienio 01/05/2026', () {
      final fecha = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: DateTime(2023, 5, 1),
        convenio: AntiguedadCalculator.convHosteleria,
      );
      expect(fecha, DateTime(2026, 5, 1));
    });

    test('Comercio: contrato 15/03/2025 → próximo bienio 15/03/2027', () {
      final fecha = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: DateTime(2025, 3, 15),
        convenio: AntiguedadCalculator.convComercio,
      );
      expect(fecha, DateTime(2027, 3, 15));
    });

    test('Peluquería → null (sin antigüedad)', () {
      final fecha = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: DateTime(2020, 1, 1),
        convenio: AntiguedadCalculator.convPeluqueria,
      );
      expect(fecha, isNull);
    });

    test('Hostelería 15+ años (máximo alcanzado) → null', () {
      final fecha = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: DateTime(2005, 1, 1),
        convenio: AntiguedadCalculator.convHosteleria,
      );
      // Ya tiene 7 trienios (21 años), pero máximo es 5 → null
      expect(fecha, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 6: ALERTA — BIENIO 20/05/2026
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 6: Alerta de cambio de tramo', () {
    test('Próximo cambio en el rango de 30 días genera alerta', () {
      // Este test solo verifica la lógica de cálculo de fecha.
      // La generación de alertas requiere Firestore (integración).
      final fechaCambio = AntiguedadCalculator.calcularProximoCambio(
        fechaInicioContrato: DateTime(2024, 5, 20),
        convenio: AntiguedadCalculator.convComercio,
      );
      expect(fechaCambio, DateTime(2026, 5, 20));

      // Verificar importes antes y después
      final antes = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2024, 5, 20),
        fechaCalculo: DateTime(2026, 5, 19), // justo antes
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1100,
      );
      expect(antes.tramosCumplidos, 0);
      expect(antes.importe, 0);

      final despues = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2024, 5, 20),
        fechaCalculo: DateTime(2026, 5, 20), // justo el día
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1100,
      );
      expect(despues.tramosCumplidos, 1);
      expect(despues.importe, closeTo(55.0, 0.01)); // 5% × 1100
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMALIZACIÓN DE CONVENIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Normalización de convenio por sector', () {
    test('hosteleria → hosteleria_guadalajara', () {
      expect(AntiguedadCalculator.normalizarConvenio('hosteleria'),
          AntiguedadCalculator.convHosteleria);
    });
    test('comercio → comercio_guadalajara', () {
      expect(AntiguedadCalculator.normalizarConvenio('comercio'),
          AntiguedadCalculator.convComercio);
    });
    test('carniceria → industrias_carnicas', () {
      expect(AntiguedadCalculator.normalizarConvenio('carniceria'),
          AntiguedadCalculator.convCarnicas);
    });
    test('veterinaria → veterinarios', () {
      expect(AntiguedadCalculator.normalizarConvenio('veterinaria'),
          AntiguedadCalculator.convVeterinarios);
    });
    test('null → vacío', () {
      expect(AntiguedadCalculator.normalizarConvenio(null), '');
    });
    test('Sector desconocido → vacío', () {
      expect(AntiguedadCalculator.normalizarConvenio('textil'), '');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DESCRIPCIÓN EN NÓMINA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Descripción de concepto en nómina', () {
    test('Hostelería incluye años y trienios', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2019, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convHosteleria,
        salarioBase: 1200,
      );
      expect(r.descripcion, contains('7 años'));
      expect(r.descripcion, contains('2 trienios'));
    });

    test('Comercio incluye años y bienios', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2020, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convComercio,
        salarioBase: 1100,
      );
      expect(r.descripcion, contains('6 años'));
      expect(r.descripcion, contains('3 bienios'));
    });

    test('Cárnicas incluye nivel', () {
      final r = AntiguedadCalculator.calcular(
        fechaInicio: DateTime(2019, 1, 1),
        fechaCalculo: DateTime(2026, 6, 1),
        convenio: AntiguedadCalculator.convCarnicas,
        salarioBase: 0,
        nivelCategoriaCarnicas: 3,
      );
      expect(r.descripcion, contains('nivel 3'));
    });
  });
}

