import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/it_service.dart';
import 'package:planeag_flutter/domain/modelos/baja_laboral.dart';

/// Tests unitarios para ITService.calcularImpactoEnNomina
///
/// Normativa: art. 169-176 LGSS · RD 625/2014 · Orden TAS/399/2004
///
/// Contingencias comunes:
///   Días 1-3:  sin prestación (salvo mejora convenio)
///   Días 4-15: 60% BR — a cargo de la empresa
///   Días 16-20: 60% BR — a cargo del INSS (empresa anticipa)
///   Día 21+:    75% BR — a cargo del INSS
///
/// Contingencias profesionales (AT/EP):
///   75% BR desde día 1 — a cargo de la Mutua
///
/// Maternidad/Paternidad:
///   100% BR desde día 1 — a cargo del INSS
void main() {
  final svc = ITService();

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  BajaLaboral _baja({
    TipoContingencia tipo = TipoContingencia.enfermedadComun,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    double baseReguladoraDiaria = 80.0, // 2.400€/mes ÷ 30
    bool mejoraConvenioDias1a3 = false,
    double porcentajeMejoraDias1a3 = 0,
  }) {
    return BajaLaboral(
      id: 'baja-test',
      empleadoId: 'emp-test',
      tipo: tipo,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      baseReguladoraDiaria: baseReguladoraDiaria,
      mejoraConvenioDias1a3: mejoraConvenioDias1a3,
      porcentajeMejoraDias1a3: porcentajeMejoraDias1a3,
      fechaCreacion: DateTime(2026, 1, 1),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENFERMEDAD COMÚN — DÍAS 1-3: SIN PRESTACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  group('EC — Días 1-3: sin prestación (a cargo del trabajador)', () {
    test('Baja de 2 días → prestación IT = 0€', () {
      // Baja empieza el 10 de marzo, dura 2 días
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 11),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 2);
      expect(res.diasTrabajados, 29);
      expect(res.importeIT, 0); // días 1-3 sin prestación
      expect(res.importeCargoEmpresa, 0);
      expect(res.importeCargoINSS, 0);
    });

    test('Baja de 3 días exactos → IT = 0€', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 12),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 3);
      expect(res.importeIT, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EC — DÍAS 1-3 CON MEJORA DE CONVENIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('EC — Días 1-3 con mejora de convenio', () {
    test('Convenio hostelería: mejora 60% BR días 1-3', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 12), // 3 días
        baseReguladoraDiaria: 80,
        mejoraConvenioDias1a3: true,
        porcentajeMejoraDias1a3: 60,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 3);
      // 3 días × 80 × 60% = 144€ a cargo de la empresa
      expect(res.importeIT, closeTo(144, 0.01));
      expect(res.importeCargoEmpresa, closeTo(144, 0.01));
      expect(res.importeCargoINSS, 0);
    });

    test('Convenio con mejora 100% BR días 1-3', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 4, 1),
        fechaFin: DateTime(2026, 4, 3), // 3 días
        baseReguladoraDiaria: 100,
        mejoraConvenioDias1a3: true,
        porcentajeMejoraDias1a3: 100,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 4, anio: 2026,
        diasMes: 30, salarioMensual: 3000,
      );

      expect(res.importeIT, closeTo(300, 0.01)); // 3 × 100
      expect(res.importeCargoEmpresa, closeTo(300, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EC — DÍAS 4-15: 60% BR A CARGO DE LA EMPRESA
  // ═══════════════════════════════════════════════════════════════════════════

  group('EC — Días 4-15: 60% BR (cargo empresa)', () {
    test('Baja de 10 días: 3 sin + 7 al 60%', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 5),
        fechaFin: DateTime(2026, 3, 14), // 10 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 10);
      // Días 1-3: 0€, Días 4-10: 7 × 80 × 0.60 = 336€
      expect(res.importeIT, closeTo(336, 0.01));
      expect(res.importeCargoEmpresa, closeTo(336, 0.01));
      expect(res.importeCargoINSS, 0);
    });

    test('Baja de 15 días exactos: 3 sin + 12 al 60%', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 15), // 15 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 15);
      // Días 1-3: 0€, Días 4-15: 12 × 80 × 0.60 = 576€
      expect(res.importeIT, closeTo(576, 0.01));
      expect(res.importeCargoEmpresa, closeTo(576, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EC — DÍAS 16-20: 60% BR A CARGO DEL INSS
  // ═══════════════════════════════════════════════════════════════════════════

  group('EC — Días 16-20: 60% BR (cargo INSS)', () {
    test('Baja de 20 días: 3 sin + 12 empresa + 5 INSS', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 20), // 20 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 20);
      // Días 1-3: 0€
      // Días 4-15: 12 × 80 × 0.60 = 576€ (empresa)
      // Días 16-20: 5 × 80 × 0.60 = 240€ (INSS)
      final totalEsperado = 576.0 + 240.0;
      expect(res.importeIT, closeTo(totalEsperado, 0.01));
      expect(res.importeCargoEmpresa, closeTo(576, 0.01));
      expect(res.importeCargoINSS, closeTo(240, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EC — DÍA 21+: 75% BR A CARGO DEL INSS
  // ═══════════════════════════════════════════════════════════════════════════

  group('EC — Día 21+: 75% BR (cargo INSS)', () {
    test('Baja de 30 días: 3 sin + 12 empresa@60% + 5 INSS@60% + 10 INSS@75%', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 30), // 30 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 30);
      final empresa = 12 * 80 * 0.60; // 576
      final inss60 = 5 * 80 * 0.60;   // 240
      final inss75 = 10 * 80 * 0.75;  // 600
      expect(res.importeIT, closeTo(empresa + inss60 + inss75, 0.01));
      expect(res.importeCargoEmpresa, closeTo(empresa, 0.01));
      expect(res.importeCargoINSS, closeTo(inss60 + inss75, 0.01));
    });

    test('Baja larga (60 días) — IT segundo mes completo al 75%', () {
      // Baja empezó el 1 de febrero, calculamos impacto en marzo
      final baja = _baja(
        fechaInicio: DateTime(2026, 2, 1),
        fechaFin: DateTime(2026, 4, 1), // 59 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      // En marzo: días relativos de baja = 29 a 59 → todos > 21 → 75% INSS
      expect(res.diasBaja, 31); // todo el mes de marzo
      expect(res.importeCargoINSS, closeTo(31 * 80 * 0.75, 0.01));
      expect(res.importeCargoEmpresa, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTINGENCIA PROFESIONAL (AT / EP) — 75% desde día 1
  // ═══════════════════════════════════════════════════════════════════════════

  group('Contingencia profesional (AT) — 75% BR desde día 1', () {
    test('Accidente laboral 10 días → 10 × BR × 75% (cargo mutua)', () {
      final baja = _baja(
        tipo: TipoContingencia.accidenteLaboral,
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 19), // 10 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 10);
      expect(res.importeIT, closeTo(10 * 80 * 0.75, 0.01));
      expect(res.importeCargoMutua, closeTo(10 * 80 * 0.75, 0.01));
      expect(res.importeCargoEmpresa, 0);
      expect(res.importeCargoINSS, 0);
    });

    test('Enfermedad profesional — mismo tratamiento que AT', () {
      final baja = _baja(
        tipo: TipoContingencia.enfermedadProfesional,
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 5), // 5 días
        baseReguladoraDiaria: 100,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 3000,
      );

      expect(res.importeIT, closeTo(5 * 100 * 0.75, 0.01));
      expect(res.importeCargoMutua, closeTo(5 * 100 * 0.75, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MATERNIDAD / PATERNIDAD — 100% BR desde día 1 (INSS)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Maternidad/Paternidad — 100% BR (cargo INSS)', () {
    test('Maternidad 31 días en marzo → 31 × BR × 100%', () {
      final baja = _baja(
        tipo: TipoContingencia.maternidad,
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 31),
        baseReguladoraDiaria: 90,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2700,
      );

      expect(res.diasBaja, 31);
      expect(res.importeIT, closeTo(31 * 90, 0.01));
      expect(res.importeCargoINSS, closeTo(31 * 90, 0.01));
      expect(res.importeCargoEmpresa, 0);
      expect(res.importeCargoMutua, 0);
    });

    test('Paternidad 16 días en abril', () {
      final baja = _baja(
        tipo: TipoContingencia.paternidad,
        fechaInicio: DateTime(2026, 4, 1),
        fechaFin: DateTime(2026, 4, 16),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 4, anio: 2026,
        diasMes: 30, salarioMensual: 2400,
      );

      expect(res.diasBaja, 16);
      expect(res.importeIT, closeTo(16 * 80, 0.01));
      expect(res.importeCargoINSS, closeTo(16 * 80, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DESCUENTO PROPORCIONAL DE SALARIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Descuento proporcional del salario', () {
    test('10 días baja en mes de 31 → descuento = 10/31 × salario', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 19), // 10 días
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.descuentoSalario, closeTo(2400 * 10 / 31, 0.01));
    });

    test('Mes completo de baja → descuento = salario total', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 31),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.descuentoSalario, closeTo(2400, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BAJA QUE NO AFECTA AL MES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Baja fuera del mes calculado', () {
    test('Baja en enero → impacto en marzo = 0', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 1, 10),
        fechaFin: DateTime(2026, 1, 20),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      expect(res.diasBaja, 0);
      expect(res.importeIT, 0);
      expect(res.descuentoSalario, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAMOS AGRUPADOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tramos agrupados correctamente', () {
    test('Baja 25 días EC: genera al menos 3 grupos de tramos', () {
      final baja = _baja(
        fechaInicio: DateTime(2026, 3, 1),
        fechaFin: DateTime(2026, 3, 25),
        baseReguladoraDiaria: 80,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 3, anio: 2026,
        diasMes: 31, salarioMensual: 2400,
      );

      // Tramos: días 1-3 (sin), días 4-15 (60% empresa), días 16-20 (60% INSS), días 21-25 (75% INSS)
      expect(res.tramos.length, greaterThanOrEqualTo(3));
      
      // Verificar que los tramos cubren todos los días
      final totalDiasTramos = res.tramos.fold(0, (sum, t) => sum + t.dias);
      expect(totalDiasTramos, 25);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO REAL: HOSTELERÍA GUADALAJARA CON MEJORA CONVENIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso real: Camarero con gripe, convenio hostelería Guadalajara', () {
    test('12 días baja EC, mejora convenio 60% días 1-3', () {
      // Base cotización mes anterior: 2.400€ → BR diaria = 80€
      final baja = _baja(
        fechaInicio: DateTime(2026, 2, 10),
        fechaFin: DateTime(2026, 2, 21), // 12 días
        baseReguladoraDiaria: 80,
        mejoraConvenioDias1a3: true,
        porcentajeMejoraDias1a3: 60,
      );

      final res = svc.calcularImpactoEnNomina(
        baja: baja,
        mes: 2, anio: 2026,
        diasMes: 28, salarioMensual: 2400,
      );

      expect(res.diasBaja, 12);
      // Días 1-3: 3 × 80 × 0.60 = 144€ (empresa, mejora convenio)
      // Días 4-12: 9 × 80 × 0.60 = 432€ (empresa)
      final cargoEmpresaEsperado = 144.0 + 432.0;
      expect(res.importeCargoEmpresa, closeTo(cargoEmpresaEsperado, 0.01));
      expect(res.importeCargoINSS, 0); // no llega a día 16
      expect(res.descuentoSalario, closeTo(2400 * 12 / 28, 0.01));
    });
  });
}

