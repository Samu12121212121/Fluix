import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/finiquito.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/services/finiquito_calculator.dart';

/// Tests del calculador de finiquitos y liquidaciones.
/// Cubren: ET arts. 49-53, LIRPF art. 7.e, LGSS art. 109.
///
/// Casos:
/// 1. Dimisión voluntaria (hostelería, 2 años, julio)
/// 2. Despido improcedente (comercio, 5 años, 1.800€/mes)
/// 3. Fin contrato temporal (cárnicas, 1 año)
/// 4. Contrato anterior a 12/02/2012 (cálculo dual)
/// 5. Mutuo acuerdo (sin indemnización)
/// 6. ERE (20 días/año)
/// 7. Edge cases
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  DatosNominaEmpleado _config({
    double salarioBrutoAnual = 21600,
    int numPagas = 14,
    bool pagasProrrateadas = false,
    double complementoFijo = 0,
    DateTime? fechaInicioContrato,
    String? sectorEmpresa,
    TipoContrato tipoContrato = TipoContrato.indefinido,
  }) {
    return DatosNominaEmpleado(
      salarioBrutoAnual: salarioBrutoAnual,
      numPagas: numPagas,
      pagasProrrateadas: pagasProrrateadas,
      complementoFijo: complementoFijo,
      fechaInicioContrato: fechaInicioContrato,
      tipoContrato: tipoContrato,
      sectorEmpresa: sectorEmpresa,
      comunidadAutonoma: ComunidadAutonoma.castillaMancha,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: DIMISIÓN VOLUNTARIA — HOSTELERÍA, 2 AÑOS, JULIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 1: Dimisión voluntaria — hostelería, 2 años', () {
    late Finiquito f;

    setUp(() {
      f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 21000, // 1.500€/mes × 14 pagas
          numPagas: 15, // Hostelería GU: 15 pagas
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2024, 7, 1),
          sectorEmpresa: 'hosteleria',
        ),
        empleadoNombre: 'María García',
        empleadoId: 'emp001',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 7, 15),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 15,
        diasVacacionesDisfrutadas: 0,
        convenioId: 'hosteleria-guadalajara',
      );
    });

    test('Sin indemnización (dimisión = 0€)', () {
      expect(f.indemnizacion, 0);
    });

    test('Salario pendiente: 15 de 31 días de julio', () {
      // salarioMensual = 21000/12 = 1750€/mes
      // salarioPendiente = (1750 / 31) × 15 ≈ 846.77
      expect(f.salarioPendiente, greaterThan(0));
      expect(f.diasTrabajadosMes, 15);
      expect(f.diasMesBaja, 31); // julio tiene 31 días
    });

    test('Vacaciones pendientes correctas', () {
      // 2 años, baja en julio (196 días del año)
      // diasDevengadas = (196 / 365) × 30 ≈ 16
      expect(f.diasVacacionesPendientes, greaterThan(0));
      expect(f.importeVacaciones, greaterThan(0));
    });

    test('Tiene prorrata de pagas extra (15 pagas hostelería)', () {
      // Hostelería 15 pagas: marzo, julio, navidad
      expect(f.prorrataPagasExtra, isNotEmpty);
      expect(f.totalProrrataPagas, greaterThan(0));
    });

    test('IRPF solo sobre partes sujetas (no indemnización)', () {
      // Base IRPF = salario + vacaciones + pagas (no hay indemnización)
      final baseEsperada = f.salarioPendiente + f.importeVacaciones + f.totalProrrataPagas;
      expect(f.baseIrpf, closeTo(baseEsperada, 0.01));
    });

    test('Cuota SS sobre conceptos cotizables', () {
      // Base SS = salario + vacaciones + pagas (no indemnización)
      expect(f.baseSS, closeTo(f.salarioPendiente + f.importeVacaciones + f.totalProrrataPagas, 0.01));
      expect(f.cuotaObreraSSFiniquito, greaterThan(0));
    });

    test('Líquido = bruto - retenciones', () {
      expect(f.liquidoPercibir,
          closeTo(f.totalBruto - f.totalRetenciones, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 2: DESPIDO IMPROCEDENTE — COMERCIO, 5 AÑOS, 1.800€/MES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 2: Despido improcedente — comercio, 5 años', () {
    late Finiquito f;

    setUp(() {
      f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 25200, // 1.800 × 14 pagas
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2021, 3, 1),
          sectorEmpresa: 'comercio',
        ),
        empleadoNombre: 'Pedro López',
        empleadoId: 'emp002',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 3, 1),
        causaBaja: CausaBaja.despidoImprocedente,
        diasTrabajadosMes: 1,
        diasVacacionesDisfrutadas: 0,
        convenioId: 'comercio-guadalajara',
      );
    });

    test('Indemnización = 33 días × 5 años × salarioDiario', () {
      // salarioTotalAnual = 25200 (sin complemento)
      // salarioDiario = 25200 / 365 = 69.04€/día
      // indemnización = 33 × 5 × 69.04 = 11.391.78€
      final salarioDiario = 25200 / 365;
      final esperado = 33 * 5 * salarioDiario;
      expect(f.indemnizacion, closeTo(esperado, 5)); // tolerancia por fracciones año
      expect(f.indemnizacion, greaterThan(10000));
    });

    test('Indemnización exenta IRPF (art. 7.e LIRPF)', () {
      // Exenta hasta 33 × años × salarioDiario
      expect(f.indemnizacionExenta, greaterThan(0));
      // Para despido improcedente con 5 años exactos, exenta = total
      expect(f.indemnizacionExenta, closeTo(f.indemnizacion, 1));
      expect(f.indemnizacionSujeta, closeTo(0, 1));
    });

    test('33 días/año, máximo 24 mensualidades', () {
      expect(f.diasIndemnizacion, greaterThan(0));
      // Máximo = 24 mensualidades = 24 × (25200/12) = 50.400€
      final maxIndem = (25200 / 12) * 24;
      expect(f.indemnizacion, lessThanOrEqualTo(maxIndem));
    });

    test('Tiene prorrata pagas extra (14 pagas comercio)', () {
      // Comercio: julio + navidad
      expect(f.prorrataPagasExtra.length, 2);
    });

    test('Causa correcta', () {
      expect(f.causaBaja, CausaBaja.despidoImprocedente);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 3: FIN CONTRATO TEMPORAL — CÁRNICAS, 1 AÑO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 3: Fin contrato temporal — cárnicas, 1 año', () {
    late Finiquito f;

    setUp(() {
      f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 18000,
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2025, 4, 1),
          sectorEmpresa: 'carniceria',
          tipoContrato: TipoContrato.temporal,
        ),
        empleadoNombre: 'Ana Ruiz',
        empleadoId: 'emp003',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 4, 1),
        causaBaja: CausaBaja.finContrato,
        diasTrabajadosMes: 1,
        diasVacacionesDisfrutadas: 5,
        diasVacacionesConvenio: 31, // Cárnicas: 31 días
        convenioId: 'industrias-carnicas-guadalajara-2025',
      );
    });

    test('Indemnización = 12 días/año', () {
      // salarioTotalAnual = 18000
      // salarioDiario = 18000 / 365 ≈ 49.32
      // indemnización ≈ 12 × 1 × 49.32 ≈ 591.78
      final salarioDiario = 18000 / 365;
      final esperado = 12 * 1 * salarioDiario;
      expect(f.indemnizacion, closeTo(esperado, 2));
    });

    test('Indemnización temporal tributa íntegramente', () {
      // Fin de contrato: NO exenta
      expect(f.indemnizacionExenta, 0);
      expect(f.indemnizacionSujeta, closeTo(f.indemnizacion, 0.01));
    });

    test('31 días vacaciones convenio cárnicas', () {
      expect(f.diasVacacionesConvenio, 31);
    });

    test('Vacaciones pendientes con 5 disfrutadas', () {
      // 365 días trabajados, 31 días convenio → devengadas = 31
      // pendientes = 31 - 5 = 26
      expect(f.diasVacacionesPendientes, greaterThan(20));
      expect(f.diasVacacionesDisfrutadas, 5);
    });

    test('Base IRPF incluye indemnización sujeta', () {
      final baseEsperada = f.salarioPendiente + f.importeVacaciones +
          f.totalProrrataPagas + f.indemnizacionSujeta;
      expect(f.baseIrpf, closeTo(baseEsperada, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 4: CONTRATO ANTERIOR A 12/02/2012 (CÁLCULO DUAL)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 4: Cálculo dual pre/post Reforma Laboral 2012', () {
    late Finiquito f;

    setUp(() {
      f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 30000,
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2008, 1, 1), // Antes de 12/02/2012
          sectorEmpresa: 'comercio',
        ),
        empleadoNombre: 'Carlos Fernández',
        empleadoId: 'emp004',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.despidoImprocedente,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 10,
        convenioId: 'comercio-guadalajara',
      );
    });

    test('Tiene cálculo dual (tramo anterior + posterior)', () {
      expect(f.indemnizacionTramoAnterior, isNotNull);
      expect(f.indemnizacionTramoPosterior, isNotNull);
    });

    test('Tramo anterior: 45 días/año (pre 12/02/2012)', () {
      // Desde 01/01/2008 hasta 12/02/2012 ≈ 4.12 años
      // 45 × 4.12 × salarioDiario ≈ significativo
      expect(f.indemnizacionTramoAnterior!, greaterThan(0));
    });

    test('Tramo posterior: 33 días/año (post 12/02/2012)', () {
      // Desde 12/02/2012 hasta 30/06/2026 ≈ 14.38 años
      // 33 × 14.38 × salarioDiario
      expect(f.indemnizacionTramoPosterior!, greaterThan(0));
    });

    test('Indemnización total = tramo1 + tramo2', () {
      // Con el tope global de 720 días
      expect(f.indemnizacion, greaterThanOrEqualTo(
          f.indemnizacionTramoAnterior! + f.indemnizacionTramoPosterior! - 1));
    });

    test('Exención IRPF sobre total', () {
      // Exento hasta el límite legal de 33 días/año
      expect(f.indemnizacionExenta, greaterThan(0));
    });

    test('Más de 18 años de antigüedad', () {
      expect(f.aniosAntiguedad, greaterThan(18));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 5: MUTUO ACUERDO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 5: Mutuo acuerdo — sin indemnización', () {
    test('No hay indemnización', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 24000,
          numPagas: 12,
          pagasProrrateadas: true,
          fechaInicioContrato: DateTime(2023, 1, 1),
        ),
        empleadoNombre: 'Laura Martín',
        empleadoId: 'emp005',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 6, 15),
        causaBaja: CausaBaja.mutuoAcuerdo,
        diasTrabajadosMes: 15,
        diasVacacionesDisfrutadas: 5,
      );

      expect(f.indemnizacion, 0);
      expect(f.indemnizacionExenta, 0);
      expect(f.indemnizacionSujeta, 0);
    });

    test('Con 12 pagas prorrateadas no hay prorrata de extra', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 24000,
          numPagas: 12,
          pagasProrrateadas: true,
          fechaInicioContrato: DateTime(2023, 1, 1),
        ),
        empleadoNombre: 'Laura Martín',
        empleadoId: 'emp005',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 6, 15),
        causaBaja: CausaBaja.mutuoAcuerdo,
        diasTrabajadosMes: 15,
        diasVacacionesDisfrutadas: 5,
      );

      expect(f.prorrataPagasExtra, isEmpty);
      expect(f.totalProrrataPagas, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 6: ERE — 20 DÍAS/AÑO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 6: ERE — 20 días/año, máx 12 mensualidades', () {
    test('Indemnización = 20 días/año', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 30000,
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2020, 1, 1),
        ),
        empleadoNombre: 'Javier Sánchez',
        empleadoId: 'emp006',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 12, 31),
        causaBaja: CausaBaja.ere,
        diasTrabajadosMes: 31,
        diasVacacionesDisfrutadas: 20,
        convenioId: 'comercio-guadalajara',
      );

      // ≈7 años × 20 × salarioDiario
      final salarioDiario = 30000 / 365;
      expect(f.indemnizacion, greaterThan(20 * 6 * salarioDiario * 0.9));

      // ERE: tributa íntegramente
      expect(f.indemnizacionExenta, 0);
      expect(f.indemnizacionSujeta, closeTo(f.indemnizacion, 0.01));
    });

    test('Máximo 12 mensualidades', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 60000,
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2005, 1, 1),
        ),
        empleadoNombre: 'Alto salario',
        empleadoId: 'emp007',
        empresaId: 'empresa001',
        fechaBaja: DateTime(2026, 12, 31),
        causaBaja: CausaBaja.ere,
        diasTrabajadosMes: 31,
        diasVacacionesDisfrutadas: 30,
      );

      final maxIndem = (60000 / 12) * 12; // 60.000€
      expect(f.indemnizacion, lessThanOrEqualTo(maxIndem));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('Salario 0 → finiquito 0', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(salarioBrutoAnual: 0, fechaInicioContrato: DateTime(2025, 1, 1)),
        empleadoNombre: 'Test',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 1, 15),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 15,
        diasVacacionesDisfrutadas: 0,
      );
      expect(f.salarioPendiente, 0);
      expect(f.importeVacaciones, 0);
      expect(f.liquidoPercibir, 0);
    });

    test('Todas las vacaciones disfrutadas → 0 días pendientes', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 20000,
          fechaInicioContrato: DateTime(2025, 1, 1),
        ),
        empleadoNombre: 'Test',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 12, 31),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 31,
        diasVacacionesDisfrutadas: 30,
      );
      expect(f.diasVacacionesPendientes, 0);
      expect(f.importeVacaciones, 0);
    });

    test('Jubilación: sin indemnización', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 35000,
          fechaInicioContrato: DateTime(1990, 1, 1),
        ),
        empleadoNombre: 'Jubilado',
        empleadoId: 'jub',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.jubilacion,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 0,
      );
      expect(f.indemnizacion, 0);
      expect(f.causaBaja, CausaBaja.jubilacion);
    });

    test('SS NO cotiza sobre indemnización', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 25200,
          numPagas: 14,
          fechaInicioContrato: DateTime(2021, 1, 1),
        ),
        empleadoNombre: 'Test SS',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.despidoImprocedente,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 0,
      );
      // Base SS = salario + vacaciones + pagas (SIN indemnización)
      final baseSSEsperada = f.salarioPendiente + f.importeVacaciones + f.totalProrrataPagas;
      expect(f.baseSS, closeTo(baseSSEsperada, 0.01));
      // La indemnización NO debe estar incluida en la base SS
      expect(f.baseSS, lessThan(f.totalBruto));
    });

    test('Despido procedente: indemnización tributa íntegramente', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 24000,
          numPagas: 14,
          fechaInicioContrato: DateTime(2022, 1, 1),
        ),
        empleadoNombre: 'Test Proc',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.despidoProcedente,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 0,
      );
      expect(f.indemnizacion, greaterThan(0));
      expect(f.indemnizacionExenta, 0);
      expect(f.indemnizacionSujeta, closeTo(f.indemnizacion, 0.01));
    });

    test('Contrato empezado este año: vacaciones proporcionales', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 20000,
          fechaInicioContrato: DateTime(2026, 2, 1),
        ),
        empleadoNombre: 'Nuevo',
        empleadoId: 'nuevo',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 5, 31),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 31,
        diasVacacionesDisfrutadas: 0,
      );
      // ~120 días trabajados → ~10 días vacaciones
      expect(f.diasVacacionesPendientes, greaterThan(5));
      expect(f.diasVacacionesPendientes, lessThan(15));
    });

    test('Veterinarios: 30 días vacaciones, 14 pagas', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 22000,
          numPagas: 14,
          pagasProrrateadas: false,
          fechaInicioContrato: DateTime(2024, 1, 1),
          sectorEmpresa: 'veterinarios',
        ),
        empleadoNombre: 'Vet Test',
        empleadoId: 'vet',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 9, 30),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 10,
        convenioId: 'veterinarios-guadalajara-2026',
      );
      expect(f.diasVacacionesConvenio, 30);
      expect(f.prorrataPagasExtra.length, 2); // julio + navidad
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // INTEGRIDAD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Integridad de cálculos', () {
    test('totalBruto = salario + vacaciones + pagas + indemnización', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 25200,
          numPagas: 14,
          fechaInicioContrato: DateTime(2021, 1, 1),
        ),
        empleadoNombre: 'Integridad',
        empleadoId: 'int',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.despidoImprocedente,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 0,
      );

      final totalEsperado = f.salarioPendiente + f.importeVacaciones +
          f.totalProrrataPagas + f.indemnizacion;
      expect(f.totalBruto, closeTo(totalEsperado, 0.01));
    });

    test('liquidoPercibir = totalBruto - totalRetenciones', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 25200,
          numPagas: 14,
          fechaInicioContrato: DateTime(2021, 1, 1),
        ),
        empleadoNombre: 'Test',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.despidoProcedente,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 10,
      );

      expect(f.liquidoPercibir,
          closeTo(f.totalBruto - f.totalRetenciones, 0.01));
    });

    test('totalRetenciones = IRPF + SS', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 25200,
          numPagas: 14,
          fechaInicioContrato: DateTime(2021, 1, 1),
        ),
        empleadoNombre: 'Test',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 6, 30),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 30,
        diasVacacionesDisfrutadas: 10,
      );

      expect(f.totalRetenciones,
          closeTo(f.importeIrpf + f.cuotaObreraSSFiniquito, 0.01));
    });

    test('Valores nunca negativos', () {
      final f = FiniquitoCalculator.calcular(
        config: _config(
          salarioBrutoAnual: 20000,
          fechaInicioContrato: DateTime(2025, 1, 1),
        ),
        empleadoNombre: 'Test',
        empleadoId: 'test',
        empresaId: 'test',
        fechaBaja: DateTime(2026, 3, 15),
        causaBaja: CausaBaja.dimision,
        diasTrabajadosMes: 15,
        diasVacacionesDisfrutadas: 0,
      );

      expect(f.salarioPendiente, greaterThanOrEqualTo(0));
      expect(f.importeVacaciones, greaterThanOrEqualTo(0));
      expect(f.indemnizacion, greaterThanOrEqualTo(0));
      expect(f.importeIrpf, greaterThanOrEqualTo(0));
      expect(f.cuotaObreraSSFiniquito, greaterThanOrEqualTo(0));
      expect(f.totalBruto, greaterThanOrEqualTo(0));
    });
  });
}

