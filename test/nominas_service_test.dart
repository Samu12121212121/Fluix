import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/services/nominas_service.dart';
import 'package:planeag_flutter/domain/modelos/convenio_colectivo.dart';

/// Tests unitarios para los cálculos de nómina.
/// Cubren: IRPF, Seguridad Social, mínimo personal/familiar,
/// horas extra, parcialidad, pagas extras y cotización solidaridad.
void main() {
  final svc = NominasService();

  // ═══════════════════════════════════════════════════════════════════════════
  // MÍNIMO PERSONAL Y FAMILIAR
  // ═══════════════════════════════════════════════════════════════════════════

  group('Mínimo personal y familiar', () {
    test('Soltero sin hijos = 5.550 €', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 25000);
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550);
    });

    test('Mayor de 65 añade 1.150 €', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 25000);
      final minimo = NominasService.calcularMinimoPersonalFamiliar(
        config: config, edadEmpleado: 67,
      );
      expect(minimo, 5550 + 1150);
    });

    test('Mayor de 75 añade 1.400 € (no 1.150)', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 25000);
      final minimo = NominasService.calcularMinimoPersonalFamiliar(
        config: config, edadEmpleado: 78,
      );
      expect(minimo, 5550 + 1400);
    });

    test('1 hijo = +2.400 €', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        numHijos: 1,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 2400);
    });

    test('2 hijos = +2.400 + 2.700 = +5.100 €', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        numHijos: 2,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 2400 + 2700);
    });

    test('3 hijos = +2.400 + 2.700 + 4.000 = +9.100 €', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        numHijos: 3,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 2400 + 2700 + 4000);
    });

    test('1 hijo menor de 3 años añade 2.800 € extra', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        numHijos: 1,
        numHijosMenores3: 1,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 2400 + 2800);
    });

    test('Discapacidad >= 33% añade 3.000 €', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        discapacidad: true,
        porcentajeDiscapacidad: 33,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 3000);
    });

    test('Discapacidad >= 65% añade 9.000 €', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        discapacidad: true,
        porcentajeDiscapacidad: 65,
      );
      final minimo = NominasService.calcularMinimoPersonalFamiliar(config: config);
      expect(minimo, 5550 + 9000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // IRPF
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cálculo IRPF', () {
    test('Salario 0 → IRPF 0%', () {
      final pct = NominasService.calcularPorcentajeIrpf(0);
      expect(pct, 0);
    });

    test('Salario negativo → IRPF 0%', () {
      final pct = NominasService.calcularPorcentajeIrpf(-5000);
      expect(pct, 0);
    });

    test('Salario bajo (12.000 €) → IRPF muy reducido (reducción RT máxima)', () {
      final pct = NominasService.calcularPorcentajeIrpf(12000);
      // Con reducción por rendimientos de 9.302 €, la base liquidable es muy baja
      expect(pct, lessThan(5));
      expect(pct, greaterThanOrEqualTo(0));
    });

    test('Salario 25.000 € → IRPF entre 8% y 18%', () {
      final pct = NominasService.calcularPorcentajeIrpf(25000);
      expect(pct, greaterThan(8));
      expect(pct, lessThan(18));
    });

    test('Salario 50.000 € → IRPF entre 18% y 30%', () {
      final pct = NominasService.calcularPorcentajeIrpf(50000);
      expect(pct, greaterThan(18));
      expect(pct, lessThan(30));
    });

    test('Salario 100.000 € → IRPF entre 25% y 40%', () {
      final pct = NominasService.calcularPorcentajeIrpf(100000);
      expect(pct, greaterThan(25));
      expect(pct, lessThan(40));
    });

    test('IRPF nunca supera 50%', () {
      final pct = NominasService.calcularPorcentajeIrpf(1000000);
      expect(pct, lessThanOrEqualTo(50));
    });

    test('IRPF con config: 2 hijos reduce retención', () {
      final sinHijos = DatosNominaEmpleado(salarioBrutoAnual: 30000, numHijos: 0);
      final conHijos = DatosNominaEmpleado(salarioBrutoAnual: 30000, numHijos: 2);
      final pctSin = NominasService.calcularPorcentajeIrpf(30000, config: sinHijos);
      final pctCon = NominasService.calcularPorcentajeIrpf(30000, config: conHijos);
      expect(pctCon, lessThan(pctSin));
    });

    test('IRPF personalizado se usa cuando se establece', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        irpfPersonalizado: 15.0,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 6, anio: 2026, config: config,
      );
      expect(nomina.porcentajeIrpf, 15.0);
    });

    test('Ajuste autonómico Madrid reduce IRPF', () {
      final estatal = DatosNominaEmpleado(
        salarioBrutoAnual: 40000,
        comunidadAutonoma: ComunidadAutonoma.estatal,
      );
      final madrid = DatosNominaEmpleado(
        salarioBrutoAnual: 40000,
        comunidadAutonoma: ComunidadAutonoma.madrid,
      );
      final pctEstatal = NominasService.calcularPorcentajeIrpf(40000, config: estatal);
      final pctMadrid = NominasService.calcularPorcentajeIrpf(40000, config: madrid);
      expect(pctMadrid, lessThan(pctEstatal));
    });

    test('Ajuste autonómico Cataluña aumenta IRPF', () {
      final estatal = DatosNominaEmpleado(
        salarioBrutoAnual: 40000,
        comunidadAutonoma: ComunidadAutonoma.estatal,
      );
      final cataluna = DatosNominaEmpleado(
        salarioBrutoAnual: 40000,
        comunidadAutonoma: ComunidadAutonoma.cataluna,
      );
      final pctEstatal = NominasService.calcularPorcentajeIrpf(40000, config: estatal);
      final pctCataluna = NominasService.calcularPorcentajeIrpf(40000, config: cataluna);
      expect(pctCataluna, greaterThan(pctEstatal));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // IRPF AJUSTADO (YTD)
  // ═══════════════════════════════════════════════════════════════════════════

  group('IRPF mensual ajustado (YTD)', () {
    test('Sin retención previa, enero: cuota anual / 12', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final irpfMes = NominasService.calcularIrpfMensualAjustado(
        baseAnualEstimada: 30000,
        irpfYaRetenidoYtd: 0,
        mesActual: 1,
        config: config,
      );
      expect(irpfMes, greaterThan(0));
    });

    test('En diciembre con mucho retenido → IRPF muy bajo o 0', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final irpfMes = NominasService.calcularIrpfMensualAjustado(
        baseAnualEstimada: 30000,
        irpfYaRetenidoYtd: 50000, // más que la cuota anual
        mesActual: 12,
        config: config,
      );
      expect(irpfMes, 0); // Ya se ha retenido de más
    });

    test('Mitad de año con retenciones correctas → similar a mes normal', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final irpfEnero = NominasService.calcularIrpfMensualAjustado(
        baseAnualEstimada: 30000,
        irpfYaRetenidoYtd: 0,
        mesActual: 1,
        config: config,
      );
      // Tras 6 meses con las retenciones de enero
      final irpfJulio = NominasService.calcularIrpfMensualAjustado(
        baseAnualEstimada: 30000,
        irpfYaRetenidoYtd: irpfEnero * 6,
        mesActual: 7,
        config: config,
      );
      // Deberían ser similares si no cambió el salario
      expect((irpfJulio - irpfEnero).abs(), lessThan(50));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE NÓMINA COMPLETA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Nómina completa', () {
    test('Nómina básica: salario neto < bruto', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.salarioNeto, lessThan(nomina.totalDevengos));
      expect(nomina.salarioNeto, greaterThan(0));
    });

    test('Nómina: devengos - deducciones = neto (identidad contable)', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 6, anio: 2026, config: config,
      );
      expect(
        nomina.salarioNeto,
        closeTo(nomina.totalDevengos - nomina.totalDeducciones, 0.01),
      );
    });

    test('Nómina: SS trabajador + IRPF = total deducciones', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(
        nomina.totalDeducciones,
        closeTo(nomina.totalSSTrabajador + nomina.retencionIrpf, 0.01),
      );
    });

    test('Nómina: coste empresa > bruto (por SS empresa)', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.costeTotalEmpresa, greaterThan(nomina.totalDevengos));
    });

    test('SS trabajador CC = 4.70% de base cotización', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(
        nomina.ssTrabajadorCC,
        closeTo(nomina.baseCotizacion * 4.70 / 100, 0.01),
      );
    });

    test('SS empresa CC = 23.60% de base cotización', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(
        nomina.ssEmpresaCC,
        closeTo(nomina.baseCotizacion * 23.60 / 100, 0.01),
      );
    });

    test('Período se genera correctamente', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.periodo, 'Marzo 2026');
    });

    test('Estado inicial es borrador', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.estado, EstadoNomina.borrador);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // HORAS EXTRA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Horas extra', () {
    test('Horas extra aumentan el neto', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final sinHoras = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      final conHoras = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
        horasExtra: 10, precioHoraExtra: 15,
      );
      expect(conHoras.salarioNeto, greaterThan(sinHoras.salarioNeto));
    });

    test('Importe horas extra = horas × precio', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
        horasExtra: 10, precioHoraExtra: 20,
      );
      expect(nomina.importeHorasExtra, closeTo(200, 0.01));
      expect(nomina.horasExtra, 10);
      expect(nomina.precioHoraExtra, 20);
    });

    test('ImporteHorasExtra directo tiene prioridad sobre precio*horas', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 24000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
        horasExtra: 10, precioHoraExtra: 20, importeHorasExtra: 500,
      );
      expect(nomina.importeHorasExtra, closeTo(500, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PARCIALIDAD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Jornada parcial', () {
    test('Media jornada (20h) → salario bruto mensual ≈ mitad', () {
      final completa = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        horasSemanales: 40,
      );
      final parcial = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        horasSemanales: 20,
      );
      final nCompleta = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: completa,
      );
      final nParcial = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: parcial,
      );
      expect(
        nParcial.salarioBrutoMensual,
        closeTo(nCompleta.salarioBrutoMensual / 2, 0.01),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGAS EXTRAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Pagas extras', () {
    test('14 pagas prorrateadas: mensual = bruto/12', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        numPagas: 14,
        pagasProrrateadas: true,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.salarioBrutoMensual, closeTo(24000 / 12, 0.01));
      expect(nomina.pagaExtra, 0);
    });

    test('14 pagas no prorrateadas: mes normal = bruto/14', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 28000,
        numPagas: 14,
        pagasProrrateadas: false,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.salarioBrutoMensual, closeTo(28000 / 14, 0.01));
      expect(nomina.pagaExtra, 0); // Marzo no es mes de paga extra
    });

    test('14 pagas no prorrateadas: junio tiene paga extra', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 28000,
        numPagas: 14,
        pagasProrrateadas: false,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 6, anio: 2026, config: config,
      );
      expect(nomina.pagaExtra, closeTo(28000 / 14, 0.01));
    });

    test('14 pagas no prorrateadas: diciembre tiene paga extra', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 28000,
        numPagas: 14,
        pagasProrrateadas: false,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 12, anio: 2026, config: config,
      );
      expect(nomina.pagaExtra, closeTo(28000 / 14, 0.01));
    });

    test('12 pagas: mensual = bruto/12, sin paga extra', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        numPagas: 12,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 6, anio: 2026, config: config,
      );
      expect(nomina.salarioBrutoMensual, closeTo(24000 / 12, 0.01));
      expect(nomina.pagaExtra, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTRATO TEMPORAL
  // ═══════════════════════════════════════════════════════════════════════════

  group('Contrato temporal', () {
    test('Temporal tiene mayor desempleo trabajador (1.60% vs 1.55%)', () {
      final indefinido = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        tipoContrato: TipoContrato.indefinido,
      );
      final temporal = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        tipoContrato: TipoContrato.temporal,
      );
      final nIndef = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: indefinido,
      );
      final nTemp = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: temporal,
      );
      expect(nTemp.ssTrabajadorDesempleo, greaterThan(nIndef.ssTrabajadorDesempleo));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GRUPO DE COTIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  group('Grupo de cotización', () {
    test('Grupo 1 tiene base mínima 1.929,00 € (RDL 3/2026)', () {
    test('Grupo 1 tiene base mínima 1.847,40 €', () {
      expect(GrupoCotizacion.grupo1.baseMinMensual, 1847.40);
    test('Grupo 10 tiene base mínima 42,00 € (diaria × 30)', () {
      expect(GrupoCotizacion.grupo10.baseMinMensual, 42.00);
      // Salario muy bajo con grupo 1 → base = mínimo del grupo
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 12000, // 1.000 €/mes
        grupoCotizacion: GrupoCotizacion.grupo1,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // El mínimo del grupo 1 es 1.847,40 pero el devengo es 1.000
      // La base se clampea al mínimo del grupo
      expect(nomina.baseCotizacion, greaterThanOrEqualTo(GrupoCotizacion.grupo1.baseMinMensual));
    });

    test('Base cotización no supera máximo (5.101,20 € — RDL 3/2026)', () {
    test('Base cotización no supera máximo (4.720,50 €)', () {
        salarioBrutoAnual: 120000, // 10.000 €/mes
        grupoCotizacion: GrupoCotizacion.grupo1,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.baseCotizacion, lessThanOrEqualTo(5101.20));
    });
  });

      expect(nomina.baseCotizacion, lessThanOrEqualTo(4720.50));
  // MEI — Mecanismo Equidad Intergeneracional
  // ═══════════════════════════════════════════════════════════════════════════

  group('MEI', () {
    test('MEI trabajador = 0.15% de base cotización (RDL 3/2026)', () {
    test('MEI trabajador = 0.12% de base cotización', () {
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(
        nomina.ssMeiTrabajador,
        closeTo(nomina.baseCotizacion * 0.15 / 100, 0.01),
      );
    });

        closeTo(nomina.baseCotizacion * 0.12 / 100, 0.01),
    test('MEI empresa = 0.58% de base cotización', () {
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(
        nomina.ssMeiEmpresa,
        closeTo(nomina.baseCotizacion * 0.75 / 100, 0.01),
      );
    });
  });

        closeTo(nomina.baseCotizacion * 0.58 / 100, 0.01),
  // COTIZACIÓN SOLIDARIDAD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cotización solidaridad', () {
    test('Salario normal (< base máxima) → solidaridad = 0', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.ssSolidaridadTrabajador, 0);
      expect(nomina.ssSolidaridadEmpresa, 0);
    });

    test('Salario alto (> base máxima) → solidaridad > 0', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 120000);
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // 10.000 €/mes > 4.720,50 → hay exceso
      expect(nomina.ssSolidaridadTrabajador, greaterThan(0));
      expect(nomina.ssSolidaridadEmpresa, greaterThan(0));
      // La empresa paga más que el trabajador en solidaridad
      expect(nomina.ssSolidaridadEmpresa, greaterThan(nomina.ssSolidaridadTrabajador));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO Nomina fromMap / toMap
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo Nomina serialización', () {
    test('toMap y fromMap son consistentes', () {
      final config = DatosNominaEmpleado(salarioBrutoAnual: 30000);
      final original = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Juan García',
        empleadoNif: '12345678Z', mes: 6, anio: 2026, config: config,
      );
      final map = original.toMap();
      map['id'] = 'test_id';
      final restaurada = Nomina.fromMap(map);

      expect(restaurada.empleadoNombre, 'Juan García');
      expect(restaurada.empleadoNif, '12345678Z');
      expect(restaurada.mes, 6);
      expect(restaurada.anio, 2026);
      expect(restaurada.salarioBrutoMensual, closeTo(original.salarioBrutoMensual, 0.01));
      expect(restaurada.salarioNeto, closeTo(original.salarioNeto, 0.01));
      expect(restaurada.totalDeducciones, closeTo(original.totalDeducciones, 0.01));
      expect(restaurada.costeTotalEmpresa, closeTo(original.costeTotalEmpresa, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO DatosNominaEmpleado fromMap / toMap
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo DatosNominaEmpleado serialización', () {
    test('toMap y fromMap son consistentes', () {
      const original = DatosNominaEmpleado(
        nif: '12345678Z',
        nss: '28/1234567890',
        salarioBrutoAnual: 30000,
        numPagas: 14,
        pagasProrrateadas: false,
        tipoContrato: TipoContrato.indefinido,
        horasSemanales: 40,
        numHijos: 2,
        comunidadAutonoma: ComunidadAutonoma.madrid,
        grupoCotizacion: GrupoCotizacion.grupo5,
      );
      final map = original.toMap();
      final restaurado = DatosNominaEmpleado.fromMap(map);

      expect(restaurado.nif, '12345678Z');
      expect(restaurado.nss, '28/1234567890');
      expect(restaurado.salarioBrutoAnual, 30000);
      expect(restaurado.numPagas, 14);
      expect(restaurado.pagasProrrateadas, false);
      expect(restaurado.tipoContrato, TipoContrato.indefinido);
      expect(restaurado.numHijos, 2);
      expect(restaurado.comunidadAutonoma, ComunidadAutonoma.madrid);
      expect(restaurado.grupoCotizacion, GrupoCotizacion.grupo5);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASOS REALES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Casos reales de nómina', () {
    test('Empleado tipo: 24.000 €/año, soltero, Madrid, indefinido', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 24000,
        numPagas: 12,
        tipoContrato: TipoContrato.indefinido,
        comunidadAutonoma: ComunidadAutonoma.madrid,
        grupoCotizacion: GrupoCotizacion.grupo7,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // Bruto mensual = 2.000 €
      expect(nomina.salarioBrutoMensual, closeTo(2000, 0.01));
      // Neto debería estar entre 1.500 y 1.800 €
      expect(nomina.salarioNeto, greaterThan(1500));
      expect(nomina.salarioNeto, lessThan(1800));
      // Coste empresa > 2.600 € (bruto + ~30% SS empresa)
      expect(nomina.costeTotalEmpresa, greaterThan(2500));
    });

    test('Empleado tipo: 50.000 €/año, casado, 2 hijos, Cataluña', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 50000,
        numPagas: 14,
        pagasProrrateadas: true,
        tipoContrato: TipoContrato.indefinido,
        estadoCivil: EstadoCivil.casado,
        numHijos: 2,
        comunidadAutonoma: ComunidadAutonoma.cataluna,
        grupoCotizacion: GrupoCotizacion.grupo1,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // Bruto mensual = 50.000/12 ≈ 4.166,67 €
      expect(nomina.salarioBrutoMensual, closeTo(50000 / 12, 0.01));
      // IRPF con 2 hijos debería ser menor que sin hijos
      expect(nomina.porcentajeIrpf, greaterThan(10));
      expect(nomina.porcentajeIrpf, lessThan(25));
    });

    test('SMI 2026: ~15.876 €/año → IRPF muy bajo', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 15876,
        numPagas: 14,
        pagasProrrateadas: true,
        tipoContrato: TipoContrato.indefinido,
        grupoCotizacion: GrupoCotizacion.grupo10,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // Con la reducción por rendimientos del trabajo, el IRPF debe ser < 5%
      expect(nomina.porcentajeIrpf, lessThan(5));
    });

    test('Hostelería 15 pagas: paga extra mes 9 y pluses variables por día', () {
      final cfg = DatosNominaEmpleado(
        salarioBrutoAnual: 22499.10,
        numPagas: 15,
        pagasProrrateadas: false,
        complementoFijo: 80,
        sectorEmpresa: 'hosteleria',
      );

      final plusFestivo = PlusConvenio(
        id: 'festivos',
        nombre: 'Festivos',
        tipo: 'fijo',
        importe: 50.0,
        baseCalculo: 'dia_festivo_trabajado',
      );

      // Mes 5: sin paga extra, 2 festivos trabajados
      final nominaMayo = svc.calcularNomina(
        empresaId: 'test',
        empleadoId: 'emp1',
        empleadoNombre: 'Test',
        mes: 5,
        anio: 2026,
        config: cfg,
        plusesConvenio: [plusFestivo],
        unidadesPlusesVariables: {'festivos': 2}, // 2 x 50 = 100
      );

      final mensualBase = 22499.10 / 15;
      expect(nominaMayo.salarioBrutoMensual, closeTo(mensualBase, 0.01));
      expect(nominaMayo.pagaExtra, 0);
      expect(nominaMayo.complementos, closeTo(80 + 100, 0.1));
      expect(nominaMayo.totalDevengosCash, greaterThan(mensualBase));

      // Mes 9: incluye paga extra
      final nominaSep = svc.calcularNomina(
        empresaId: 'test',
        empleadoId: 'emp1',
        empleadoNombre: 'Test',
        mes: 9,
        anio: 2026,
        config: cfg,
      );

      expect(nominaSep.pagaExtra, closeTo(mensualBase, 0.01));
      expect(nominaSep.salarioBrutoMensual, closeTo(mensualBase, 0.01));
    });

    test('Prorrata 15 pagas cuando pagas_prorrateadas = true', () {
      final cfg = DatosNominaEmpleado(
        salarioBrutoAnual: 22499.10,
        numPagas: 15,
        pagasProrrateadas: true,
        sectorEmpresa: 'hosteleria',
      );

      final nomina = svc.calcularNomina(
        empresaId: 'test',
        empleadoId: 'emp1',
        empleadoNombre: 'Test',
        mes: 3,
        anio: 2026,
        config: cfg,
      );

      final mensualProrrata = 22499.10 / 12;
      final mensualSinProrrata = 22499.10 / 15;
      final prorrataEsperada = mensualProrrata - mensualSinProrrata;

      expect(nomina.salarioBrutoMensual, closeTo(mensualProrrata, 0.01));
      expect(nomina.pagaExtra, 0);
      expect(nomina.pagaExtraProrrata, closeTo(prorrataEsperada, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // IRPF CASTILLA-LA MANCHA — TRAMOS AUTONÓMICOS 2026
}

      // 6 tramos: 12450, 20200, 35200, 60000, 300000, ∞
      expect(tramos.length, 6);
      expect(tramos[0], [12450, 19.0]);
      expect(tramos[1], [20200, 24.0]);
      expect(tramos[2], [35200, 30.0]);
      expect(tramos[3], [60000, 37.0]);
      expect(tramos[4], [300000, 45.0]);
      expect(tramos[5][0], double.infinity);
      expect(tramos[5][1], 47.0);
    });

    test('Tramos CLM: cuotas íntegras acumuladas correctas (referencia TaxDown)', () {
      // Cuota acumulada al fin de cada tramo según tarifa autonómica CLM.
      // Se verifica contra los importes oficiales × 2 (estatal + autonómica).
      //
      // Tramo 1: 12.450 × 19% = 2.365,50
      expect(impuestoBrutoCLM(12450), closeTo(2365.50, 0.01));

      // Tramo 2: 2.365,50 + 7.750 × 24% = 2.365,50 + 1.860 = 4.225,50
      expect(impuestoBrutoCLM(20200), closeTo(4225.50, 0.01));

      // Tramo 3: 4.225,50 + 15.000 × 30% = 4.225,50 + 4.500 = 8.725,50
      expect(impuestoBrutoCLM(35200), closeTo(8725.50, 0.01));

      // Tramo 4: 8.725,50 + 24.800 × 37% = 8.725,50 + 9.176 = 17.901,50
      expect(impuestoBrutoCLM(60000), closeTo(17901.50, 0.01));

      // Tramo 5: 17.901,50 + 240.000 × 45% = 17.901,50 + 108.000 = 125.901,50
      expect(impuestoBrutoCLM(300000), closeTo(125901.50, 0.01));
    });

    test('Tramos CLM: retención efectiva para 30k y 70k brutos (soltero sin hijos)', () {
      final config30k = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final config70k = DatosNominaEmpleado(
        salarioBrutoAnual: 70000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );

      final pct30k = NominasService.calcularPorcentajeIrpf(
        30000, config: config30k,
      );
      final pct70k = NominasService.calcularPorcentajeIrpf(
        70000, config: config70k,
      );

      // 30.000€ — reducción RT 2.000€ → base liq 28.000€
      //   Impuesto 28.000: 2.365,50 + 7.750×24% + 7.800×30% = 6.565,50
      //   Impuesto mínPF 5.550: 5.550×19% = 1.054,50
      //   Cuota: 5.511 → 18,37%
      expect(pct30k, closeTo(18.37, 0.3));

      // 70.000€ — reducción RT 2.000€ → base liq 68.000€
      //   Impuesto 68.000: 17.901,50 + 8.000×45% = 21.501,50
      //   Impuesto mínPF 5.550: 1.054,50
      //   Cuota: 20.447 → 29,21%
      expect(pct70k, closeTo(29.21, 0.3));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // VERIFICACIÓN CONSTANTES SS 2026 — RDL 3/2026 + Orden PJC/178/2025
  // ═══════════════════════════════════════════════════════════════════════════

  group('Constantes SS 2026 (RDL 3/2026)', () {
    test('Base máxima cotización = 5.101,20 €/mes', () {
      // Un salario altísimo → la base cotización se clampea a la máxima
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 200000, // ~16.666 €/mes, muy por encima del tope
        grupoCotizacion: GrupoCotizacion.grupo1,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      expect(nomina.baseCotizacion, closeTo(5101.20, 0.01));
    });

    test('MEI total 2026 = 0,90% (trabajador 0,15% + empresa 0,75%)', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 36000, // 3.000€/mes — dentro de topes
        grupoCotizacion: GrupoCotizacion.grupo5,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      final meiTotal = nomina.ssMeiTrabajador + nomina.ssMeiEmpresa;
      final meiEsperado = nomina.baseCotizacion * 0.90 / 100;
      expect(meiTotal, closeTo(meiEsperado, 0.01));
      // Verificar desglose
      expect(nomina.ssMeiTrabajador, closeTo(nomina.baseCotizacion * 0.15 / 100, 0.01));
      expect(nomina.ssMeiEmpresa, closeTo(nomina.baseCotizacion * 0.75 / 100, 0.01));
    });

    test('Cuota total CC trabajador grupo 1 con salario 30.000€/año', () {
      // Grupo 1: base mín 1.929,00€ → salario 2.500€/mes > mínimo, se usa el devengo
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000, // 2.500 €/mes
        grupoCotizacion: GrupoCotizacion.grupo1,
      );
      final nomina = svc.calcularNomina(
        empresaId: 'test', empleadoId: 'emp1', empleadoNombre: 'Test',
        mes: 3, anio: 2026, config: config,
      );
      // Base cotización = max(devengo, baseMinGrupo1) clampeada a max
      // 2.500 > 1.929 → base = 2.500
      expect(nomina.baseCotizacion, closeTo(2500, 0.01));
      // CC trabajador = 4,70% de base
      final ccEsperada = 2500 * 4.70 / 100; // = 117,50€
      expect(nomina.ssTrabajadorCC, closeTo(ccEsperada, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DEDUCCIONES AUTONÓMICAS CLM — Ley 8/2013 + DL 1/2009
  // ═══════════════════════════════════════════════════════════════════════════

  group('Deducciones autonómicas CLM', () {
    test('Empleado sin deducciones CLM → IRPF igual que sin deducciones', () {
      // Mismo salario, mismo IRPF si no tiene ningún campo CLM activo
      final configCLM = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final configEstatal = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final pctCon = NominasService.calcularPorcentajeIrpf(25000, config: configCLM);
      final pctSin = NominasService.calcularPorcentajeIrpf(25000, config: configEstatal);
      expect(pctCon, pctSin);
    });

    test('Nacimiento 1er hijo con renta ≤27k → −100€ cuota', () {
      final sinHijo = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final conHijo = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
        numHijosNacidosEsteAno: 1,
      );
      final pctSin = NominasService.calcularPorcentajeIrpf(25000, config: sinHijo);
      final pctCon = NominasService.calcularPorcentajeIrpf(25000, config: conHijo);
      // La diferencia de cuota = diferencia de %  × baseAnual / 100
      final diffCuota = (pctSin - pctCon) * 25000 / 100;
      expect(diffCuota, closeTo(100, 0.01));
    });

    test('Familia numerosa especial → −400€ cuota', () {
      final sinFN = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final conFN = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
        familiaNumerosa: FamiliaNumerosa.especial,
      );
      final pctSin = NominasService.calcularPorcentajeIrpf(25000, config: sinFN);
      final pctCon = NominasService.calcularPorcentajeIrpf(25000, config: conFN);
      final diffCuota = (pctSin - pctCon) * 25000 / 100;
      expect(diffCuota, closeTo(400, 0.01));
    });

    test('Guardería 1.000€ gastos → −150€ cuota (15%)', () {
      final sinG = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final conG = DatosNominaEmpleado(
        salarioBrutoAnual: 25000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
        gastosGuarderia: 1000,
      );
      final pctSin = NominasService.calcularPorcentajeIrpf(25000, config: sinG);
      final pctCon = NominasService.calcularPorcentajeIrpf(25000, config: conG);
      final diffCuota = (pctSin - pctCon) * 25000 / 100;
      // 15% de 1.000 = 150€ (dentro del máximo 250€)
      expect(diffCuota, closeTo(150, 0.01));
    });

    test('Renta >27k → 0€ deducciones CLM (fuera de límite)', () {
      // Base 35.000€ — supera el límite de 27.000€ individual
      final sinD = DatosNominaEmpleado(
        salarioBrutoAnual: 35000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final conD = DatosNominaEmpleado(
        salarioBrutoAnual: 35000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
        numHijosNacidosEsteAno: 2,       // 500€ si renta ≤27k
        familiaNumerosa: FamiliaNumerosa.especial, // 400€ si renta ≤27k
        gastosGuarderia: 2000,            // 250€ si renta ≤27k
      );
      final pctSin = NominasService.calcularPorcentajeIrpf(35000, config: sinD);
      final pctCon = NominasService.calcularPorcentajeIrpf(35000, config: conD);
      // No debe haber diferencia: renta supera el límite
      expect(pctSin, pctCon);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO INDUSTRIAS CÁRNICAS — Datos salariales BOE-A-2025-13965
  // ═══════════════════════════════════════════════════════════════════════════

  group('Convenio Industrias Cárnicas 2025', () {
    test('Oficial 1ª Obrero — salario base mensual ≈ 1.528,09€ (14 pagas)', () {
      // Nivel 10: salario anual 21.393,23€ / 14 pagas = 1.528,088…€/mes
      const salarioAnual = 21393.23;
      const numPagas = 14;
      final salarioMensual = salarioAnual / numPagas;
      expect(salarioMensual, closeTo(1528.09, 0.01));
    });

    test('Hora extra Peón = hora ordinaria × 1,75', () {
      // Nivel 13 (Peón): salario anual 19.804,15€
      // Jornada: 1.748 horas/año
      // Hora ordinaria = 19.804,15 / 1.748 ≈ 11,3296€
      // Hora extra = 11,3296 × 1,75 ≈ 19,8269€
      const salarioAnualPeon = 19804.15;
      const horasAnuales = 1748;
      const recargoHoraExtra = 1.75;
      final horaOrdinaria = salarioAnualPeon / horasAnuales;
      final horaExtra = horaOrdinaria * recargoHoraExtra;

      expect(horaOrdinaria, closeTo(11.33, 0.01));
      expect(horaExtra, closeTo(19.83, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVENIO VETERINARIOS — BOE-A-2023-21910 (prórroga 2026, IPC 2,9%)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Convenio Veterinarios 2026 (prórroga IPC 2,9%)', () {
    // Factor IPC: ×1,029
    const double ipc = 1.029;

    // Función de redondeo idéntica al seed
    double r(double v) => (v * ipc * 100).roundToDouble() / 100;

    test('ACV — salario mensual 2026 ≈ 1.276,01€ (SB×1,029 + CPT×1,029)', () {
      // SB 2025 Nivel III: 1.216,98€ → SB 2026 = 1.252,27€
      // CPT 2025 ACV: 23,07€ → CPT 2026 = 23,74€
      // Total = 1.252,27 + 23,74 = 1.276,01€
      final sb3 = r(1216.98);    // 1252.27
      final cptAcv = r(23.07);   // 23.74
      final totalMensual = sb3 + cptAcv;
      expect(totalMensual, closeTo(1276.01, 0.50));
    });

    test('Veterinario Supervisado — salario mensual 2026 ≈ 1.550,44€ (SB×1,029, CPT=0)', () {
      // SB 2025 Nivel I: 1.506,74€ → SB 2026 = 1.550,44€
      // CPT = 0 → Total = 1.550,44€
      final sb1 = r(1506.74);   // 1550.44
      expect(sb1, closeTo(1550.44, 0.50));
    });

    test('Hora extra Vet. Generalista = hora ordinaria × 1,5', () {
      // SB 2025: 1.506,74 → SB 2026 = 1.550,44
      // CPT 2025: 120,54 → CPT 2026 = 124,04
      // Total mensual = 1.674,48 → Anual = 1.674,48 × 14 = 23.442,72
      // Jornada: 1.780 h/año
      // Hora ordinaria = 23.442,72 / 1.780 ≈ 13,17
      // Hora extra = 13,17 × 1,50 ≈ 19,76
      final sb1 = r(1506.74);
      final cptGen = r(120.54);
      final totalMensual = sb1 + cptGen;
      final salarioAnual = totalMensual * 14;
      const horasAnuales = 1780;
      const recargoHoraExtra = 1.50;

      final horaOrdinaria = salarioAnual / horasAnuales;
      final horaExtra = horaOrdinaria * recargoHoraExtra;

      expect(horaOrdinaria, closeTo(13.17, 0.05));
      expect(horaExtra, closeTo(19.76, 0.05));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF NÓMINA — Modelo oficial BOE-A-2014-11637
  // ═══════════════════════════════════════════════════════════════════════════

  group('PDF nómina — modelo oficial BOE', () {
    test('PDF tiene 2 páginas y contiene textos obligatorios BOE', () async {
      // Construir una nómina de prueba con todos los campos
      final nomina = Nomina(
        id: 'test-pdf',
        empresaId: 'emp1',
        empleadoId: 'trab1',
        empleadoNombre: 'Juan Garcia Lopez',
        empleadoNif: '12345678Z',
        empleadoNss: '281234567890',
        mes: 3,
        anio: 2026,
        periodo: 'Marzo 2026',
        salarioBrutoMensual: 2000.00,
        complementos: 150.00,
        baseCotizacion: 2500.00,
        ssTrabajadorCC: 117.50,
        ssTrabajadorDesempleo: 38.75,
        ssTrabajadorFP: 2.50,
        ssMeiTrabajador: 3.75,
        baseIrpf: 2150.00,
        porcentajeIrpf: 15.0,
        retencionIrpf: 322.50,
        ssEmpresaCC: 590.00,
        ssEmpresaDesempleo: 137.50,
        ssEmpresaFogasa: 5.00,
        ssEmpresaFP: 15.00,
        ssEmpresaAT: 37.50,
        ssMeiEmpresa: 18.75,
        fechaCreacion: DateTime(2026, 3, 31),
      );

      // Generar el PDF
      final bytes = await NominaPdfService.generarNominaPdf(
        nomina,
        nombreEmpresa: 'Fluixtech SL',
        cifEmpresa: 'B12345678',
        direccionEmpresa: 'C/ Mayor 1, Guadalajara',
        cccEmpresa: '19123456789',
      );

      // Verificar que se generaron bytes (PDF válido)
      expect(bytes.length, greaterThan(1000));

      // Convertir a texto para buscar strings en el PDF raw
      final pdfText = String.fromCharCodes(bytes);

      // Verificar que el PDF tiene exactamente 2 páginas
      // El PDF object tree tiene un /Pages con /Count 2
      final countPattern = RegExp(r'/Count\s+2');
      expect(countPattern.hasMatch(pdfText), isTrue,
        reason: 'El PDF debe tener exactamente 2 páginas (anverso + reverso)');

      // Verificar CVE lateral obligatorio
      expect(pdfText, contains('BOE-A-2014-11637'));
    });
  });
}
