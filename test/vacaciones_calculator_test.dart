import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/vacaciones_service.dart';
import 'package:planeag_flutter/models/vacacion_model.dart';
import 'package:planeag_flutter/models/saldo_vacaciones_model.dart';

/// Tests unitarios para los cálculos de vacaciones y ausencias.
/// Cubren: devengo proporcional, descuento ausencias, días naturales/laborables,
/// saldo, y permisos retribuidos.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE DÍAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cálculo de días naturales y laborables', () {
    test('1 día (mismo día inicio y fin)', () {
      final inicio = DateTime(2026, 7, 1);
      final fin = DateTime(2026, 7, 1);
      expect(VacacionesService.calcularDiasNaturales(inicio, fin), 1);
      expect(VacacionesService.calcularDiasLaborables(inicio, fin), 1); // miércoles
    });

    test('10 días naturales incluyen fines de semana', () {
      // 1-10 julio 2026 (miércoles a viernes)
      final inicio = DateTime(2026, 7, 1);
      final fin = DateTime(2026, 7, 10);
      expect(VacacionesService.calcularDiasNaturales(inicio, fin), 10);
      expect(VacacionesService.calcularDiasLaborables(inicio, fin), 8);
    });

    test('1 semana completa = 7 naturales, 5 laborables', () {
      // Lunes 6 julio a domingo 12 julio 2026
      final inicio = DateTime(2026, 7, 6);
      final fin = DateTime(2026, 7, 12);
      expect(VacacionesService.calcularDiasNaturales(inicio, fin), 7);
      expect(VacacionesService.calcularDiasLaborables(inicio, fin), 5);
    });

    test('Fin de semana = 0 laborables', () {
      final inicio = DateTime(2026, 7, 4); // sábado
      final fin = DateTime(2026, 7, 5); // domingo
      expect(VacacionesService.calcularDiasNaturales(inicio, fin), 2);
      expect(VacacionesService.calcularDiasLaborables(inicio, fin), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DEVENGO PROPORCIONAL
  // ═══════════════════════════════════════════════════════════════════════════

  group('Devengo proporcional de vacaciones', () {
    test('Caso 1: Hostelería contrato desde 01/01/2026, cálculo a 30/06/2026', () {
      // Devengado a 30/06: (181/365) × 30 = 14,88 días
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2026, 1, 1),
        fechaCalculo: DateTime(2026, 6, 30),
        diasConvenio: 30,
        anio: 2026,
      );
      // 181 días (1 ene – 30 jun), 2026 no es bisiesto → 365 días
      // (181/365) × 30 = 14.876...
      expect(devengado, closeTo(14.88, 0.05));
    });

    test('Año completo = todos los días de convenio', () {
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2026, 1, 1),
        fechaCalculo: DateTime(2026, 12, 31),
        diasConvenio: 30,
        anio: 2026,
      );
      expect(devengado, closeTo(30.0, 0.01));
    });

    test('Industrias cárnicas 31 días, año completo', () {
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2026, 1, 1),
        fechaCalculo: DateTime(2026, 12, 31),
        diasConvenio: 31,
        anio: 2026,
      );
      expect(devengado, closeTo(31.0, 0.01));
    });

    test('Contrato desde 01/07/2026, cálculo a 31/12/2026 → ~medio año', () {
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2026, 7, 1),
        fechaCalculo: DateTime(2026, 12, 31),
        diasConvenio: 30,
        anio: 2026,
      );
      // 184 días / 365 × 30 = 15.12...
      expect(devengado, closeTo(15.12, 0.1));
    });

    test('Contrato de año anterior → devenga desde 01/01 del año', () {
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2025, 3, 15),
        fechaCalculo: DateTime(2026, 6, 30),
        diasConvenio: 30,
        anio: 2026,
      );
      // Debería contar desde 01/01/2026 (no desde 2025)
      expect(devengado, closeTo(14.88, 0.05));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: DEVENGO Y SALDO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 1: Empleado hostelería, contrato 01/01/2026', () {
    test('Devengado a 30/06: 14,88 días. Disfruta 10 → saldo 4,88', () {
      final devengado = VacacionesService.calcularDiasDevengados(
        fechaInicioContrato: DateTime(2026, 1, 1),
        fechaCalculo: DateTime(2026, 6, 30),
        diasConvenio: 30,
        anio: 2026,
      );
      expect(devengado, closeTo(14.88, 0.05));

      final disfrutados = 10.0;
      final pendientes = devengado - disfrutados;
      expect(pendientes, closeTo(4.88, 0.05));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 2: DESCUENTO AUSENCIA INJUSTIFICADA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 2: Descuento ausencia injustificada', () {
    test('2 días injustificados, salario 1.800€, mes 30 días → descuento 120€', () {
      final descuento = VacacionesService.calcularDescuentoAusencia(
        salarioBrutoMensual: 1800,
        diasMes: 30,
        diasAusencia: 2,
      );
      expect(descuento, closeTo(120.0, 0.01));
    });

    test('Nómina neta = normal - 120€', () {
      // Simulación simplificada
      const salarioBruto = 1800.0;
      final descuento = VacacionesService.calcularDescuentoAusencia(
        salarioBrutoMensual: salarioBruto,
        diasMes: 30,
        diasAusencia: 2,
      );
      expect(descuento, 120.0);
      // El neto sería salarioBruto - deducciones SS - IRPF - descuento
      // La integración real la hace Nomina.salarioNeto
    });

    test('0 días ausencia → 0 descuento', () {
      final descuento = VacacionesService.calcularDescuentoAusencia(
        salarioBrutoMensual: 1800,
        diasMes: 30,
        diasAusencia: 0,
      );
      expect(descuento, 0);
    });

    test('Mes completo ausencia → descuento = salario completo', () {
      final descuento = VacacionesService.calcularDescuentoAusencia(
        salarioBrutoMensual: 1800,
        diasMes: 30,
        diasAusencia: 30,
      );
      expect(descuento, closeTo(1800.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 3: PERMISO RETRIBUIDO — 0 DESCUENTO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 3: Permiso retribuido nacimiento hijo', () {
    test('Tipo permisoRetribuido no descuenta salario', () {
      expect(TipoAusencia.permisoRetribuido.descuentaSalario, false);
    });

    test('Subtipo nacimiento = 2 días máximo', () {
      expect(SubtipoPermiso.nacimiento.diasMaxDefecto, 2);
    });

    test('Permiso matrimonio = 15 días', () {
      expect(SubtipoPermiso.matrimonio.diasMaxDefecto, 15);
    });

    test('Fallecimiento 1er grado con desplazamiento = 4 días', () {
      expect(SubtipoPermiso.fallecimiento1erGrado.diasMaxDefecto, 4);
    });

    test('Fallecimiento 2º grado con desplazamiento = 3 días', () {
      expect(SubtipoPermiso.fallecimiento2oGrado.diasMaxDefecto, 3);
    });

    test('Mudanza = 1 día', () {
      expect(SubtipoPermiso.mudanza.diasMaxDefecto, 1);
    });

    test('Solicitud de permiso retribuido tiene descuento 0', () {
      final solicitud = SolicitudVacaciones(
        id: 'test1',
        empleadoId: 'emp1',
        empresaId: 'empresa1',
        tipo: TipoAusencia.permisoRetribuido,
        subtipo: SubtipoPermiso.nacimiento,
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 11),
        diasNaturales: 2,
        diasLaborables: 2,
        descuentoSalario: 0, // no descuenta
        fechaCreacion: DateTime(2026, 3, 1),
      );
      expect(solicitud.descuentoSalario, 0);
      expect(solicitud.tipo.descuentaSalario, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 4: MEDIA JORNADA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 4: Empleado a media jornada', () {
    test('Base diaria = (900/30) = 30€/día, 2 días ausencia = 60€', () {
      final descuento = VacacionesService.calcularDescuentoAusencia(
        salarioBrutoMensual: 900,
        diasMes: 30,
        diasAusencia: 2,
      );
      expect(descuento, closeTo(60.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DÍAS POR CONVENIO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Días de vacaciones por convenio', () {
    test('Hostelería = 30 días', () {
      expect(VacacionesService.diasVacacionesPorSector('hosteleria'), 30);
    });
    test('Comercio = 30 días', () {
      expect(VacacionesService.diasVacacionesPorSector('comercio'), 30);
    });
    test('Peluquería = 30 días', () {
      expect(VacacionesService.diasVacacionesPorSector('peluqueria'), 30);
    });
    test('Industrias cárnicas = 31 días', () {
      expect(VacacionesService.diasVacacionesPorSector('carniceria'), 31);
      expect(VacacionesService.diasVacacionesPorSector('industrias_carnicas'), 31);
    });
    test('Veterinarios = 30 días', () {
      expect(VacacionesService.diasVacacionesPorSector('veterinarios'), 30);
      expect(VacacionesService.diasVacacionesPorSector('veterinaria'), 30);
    });
    test('Sector desconocido = 30 días (mínimo ET)', () {
      expect(VacacionesService.diasVacacionesPorSector('otro'), 30);
      expect(VacacionesService.diasVacacionesPorSector(null), 30);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DÍAS EN MES DE SOLICITUD
  // ═══════════════════════════════════════════════════════════════════════════

  group('Días de solicitud en un mes concreto', () {
    test('Solicitud completa dentro del mes', () {
      final solicitud = SolicitudVacaciones(
        id: 'test', empleadoId: 'e', empresaId: 'emp',
        tipo: TipoAusencia.ausenciaInjustificada,
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 15),
        diasNaturales: 6,
        fechaCreacion: DateTime.now(),
      );
      expect(VacacionesService.diasEnMesDeSolicitud(solicitud, 2026, 3), 6);
    });

    test('Solicitud cruza fin de mes', () {
      final solicitud = SolicitudVacaciones(
        id: 'test', empleadoId: 'e', empresaId: 'emp',
        tipo: TipoAusencia.vacaciones,
        fechaInicio: DateTime(2026, 3, 28),
        fechaFin: DateTime(2026, 4, 5),
        diasNaturales: 9,
        fechaCreacion: DateTime.now(),
      );
      // Marzo: 28-31 = 4 días
      expect(VacacionesService.diasEnMesDeSolicitud(solicitud, 2026, 3), 4);
      // Abril: 1-5 = 5 días
      expect(VacacionesService.diasEnMesDeSolicitud(solicitud, 2026, 4), 5);
    });

    test('Solicitud en otro mes = 0 días', () {
      final solicitud = SolicitudVacaciones(
        id: 'test', empleadoId: 'e', empresaId: 'emp',
        tipo: TipoAusencia.vacaciones,
        fechaInicio: DateTime(2026, 5, 1),
        fechaFin: DateTime(2026, 5, 10),
        diasNaturales: 10,
        fechaCreacion: DateTime.now(),
      );
      expect(VacacionesService.diasEnMesDeSolicitud(solicitud, 2026, 3), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO SALDO VACACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo SaldoVacaciones', () {
    test('totalDisponible = devengados + arrastre - disfrutados', () {
      final saldo = SaldoVacaciones(
        empleadoId: 'e1',
        anio: 2026,
        diasDevengados: 30,
        diasDisfrutados: 10,
        diasPendientes: 20,
        diasPendientesAnoAnterior: 3,
        ultimaActualizacion: DateTime.now(),
      );
      expect(saldo.totalDisponible, 23); // 30 + 3 - 10
    });

    test('totalDisponible no es negativo', () {
      final saldo = SaldoVacaciones(
        empleadoId: 'e1',
        anio: 2026,
        diasDevengados: 10,
        diasDisfrutados: 15,
        diasPendientes: -5,
        ultimaActualizacion: DateTime.now(),
      );
      expect(saldo.totalDisponible, 0);
    });

    test('Serialización toMap/fromMap roundtrip', () {
      final original = SaldoVacaciones(
        empleadoId: 'emp123',
        anio: 2026,
        diasDevengados: 25.5,
        diasDisfrutados: 10.0,
        diasPendientes: 15.5,
        diasPendientesAnoAnterior: 2.0,
        ultimaActualizacion: DateTime(2026, 6, 15),
      );
      final map = original.toMap();
      final restored = SaldoVacaciones.fromMap(map);
      expect(restored.empleadoId, 'emp123');
      expect(restored.anio, 2026);
      expect(restored.diasDevengados, 25.5);
      expect(restored.diasDisfrutados, 10.0);
      expect(restored.diasPendientes, 15.5);
      expect(restored.diasPendientesAnoAnterior, 2.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO SOLICITUD VACACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo SolicitudVacaciones', () {
    test('Serialización toMap/fromMap roundtrip', () {
      final original = SolicitudVacaciones(
        id: 'sol1',
        empleadoId: 'emp1',
        empresaId: 'empresa1',
        tipo: TipoAusencia.ausenciaInjustificada,
        fechaInicio: DateTime(2026, 3, 10),
        fechaFin: DateTime(2026, 3, 12),
        diasNaturales: 3,
        diasLaborables: 3,
        estado: EstadoSolicitud.aprobado,
        descuentoSalario: 180.0,
        notas: 'Sin justificante',
        fechaCreacion: DateTime(2026, 3, 1),
        empleadoNombre: 'Juan Pérez',
      );
      final map = original.toMap();
      final restored = SolicitudVacaciones.fromMap(map);
      expect(restored.id, 'sol1');
      expect(restored.tipo, TipoAusencia.ausenciaInjustificada);
      expect(restored.estado, EstadoSolicitud.aprobado);
      expect(restored.descuentoSalario, 180.0);
      expect(restored.diasNaturales, 3);
      expect(restored.empleadoNombre, 'Juan Pérez');
    });

    test('TipoAusencia.descuentaSalario solo en injustificada', () {
      expect(TipoAusencia.vacaciones.descuentaSalario, false);
      expect(TipoAusencia.ausenciaJustificada.descuentaSalario, false);
      expect(TipoAusencia.ausenciaInjustificada.descuentaSalario, true);
      expect(TipoAusencia.permisoRetribuido.descuentaSalario, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DÍAS EN MES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Utilidades: días en mes', () {
    test('Febrero 2026 = 28 días', () {
      expect(VacacionesService.diasEnMes(2026, 2), 28);
    });
    test('Febrero 2024 (bisiesto) = 29 días', () {
      expect(VacacionesService.diasEnMes(2024, 2), 29);
    });
    test('Julio = 31 días', () {
      expect(VacacionesService.diasEnMes(2026, 7), 31);
    });
    test('Abril = 30 días', () {
      expect(VacacionesService.diasEnMes(2026, 4), 30);
    });
  });
}

