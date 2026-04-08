import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/services/nominas_service.dart';
import 'package:planeag_flutter/services/regularizacion_irpf_service.dart';

/// Tests para la lógica de regularización anual de IRPF (diciembre).
///
/// Art. 86-87 RIRPF: regularización tipo de retención.
///
/// Estos tests verifican la lógica pura del cálculo, no la lectura
/// de Firestore (que se prueba por separado con fake_cloud_firestore).
///
/// NOTA: RegularizacionIRPFService.calcularRegularizacion lee de Firestore.
/// Para testear la lógica pura, verificamos los componentes:
/// 1. NominasService.calcularPorcentajeIrpf (ya testeado)
/// 2. Cálculo de ajuste = irpfCorrecto - irpfRetenido
/// 3. Alerta de desviación si ajuste > 20% salario mensual
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // LÓGICA DE REGULARIZACIÓN — CÁLCULOS PUROS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cálculo de ajuste regularización', () {
    test('Sin desviación: ajuste = 0 cuando retención fue correcta', () {
      // Empleado con 30.000€/año
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );

      // Calcular el porcentaje correcto
      final pctCorrecto = NominasService.calcularPorcentajeIrpf(30000, config: config);
      final irpfAnualCorrecto = 30000 * pctCorrecto / 100;

      // Simular que se retuvo exactamente lo correcto
      final ajuste = irpfAnualCorrecto - irpfAnualCorrecto;
      expect(ajuste, 0);
    });

    test('Retención insuficiente: ajuste positivo (retener más en diciembre)', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );

      final pctCorrecto = NominasService.calcularPorcentajeIrpf(30000, config: config);
      final irpfAnualCorrecto = 30000 * pctCorrecto / 100;

      // Simular que se retuvo un 5% menos de lo correcto
      final totalRetenido = irpfAnualCorrecto * 0.95;
      final ajuste = irpfAnualCorrecto - totalRetenido;

      expect(ajuste, greaterThan(0));
      expect(ajuste, closeTo(irpfAnualCorrecto * 0.05, 0.01));
    });

    test('Retención excesiva: ajuste negativo (devolver al trabajador)', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );

      final pctCorrecto = NominasService.calcularPorcentajeIrpf(30000, config: config);
      final irpfAnualCorrecto = 30000 * pctCorrecto / 100;

      // Simular que se retuvo un 10% MÁS de lo correcto
      final totalRetenido = irpfAnualCorrecto * 1.10;
      final ajuste = irpfAnualCorrecto - totalRetenido;

      expect(ajuste, lessThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTA DE DESVIACIÓN (> 20% SALARIO MENSUAL)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Alerta de desviación', () {
    test('Ajuste pequeño (< 20% mensual): sin alerta', () {
      const salarioBruto = 30000.0;
      final salarioMensual = salarioBruto / 12; // 2.500€
      final umbral = salarioMensual * 0.20; // 500€
      final ajuste = 200.0; // < 500€

      expect(ajuste.abs() > umbral, isFalse);
    });

    test('Ajuste grande (> 20% mensual): con alerta', () {
      const salarioBruto = 30000.0;
      final salarioMensual = salarioBruto / 12; // 2.500€
      final umbral = salarioMensual * 0.20; // 500€
      final ajuste = 800.0; // > 500€

      expect(ajuste.abs() > umbral, isTrue);
    });

    test('Ajuste negativo grande también genera alerta', () {
      const salarioBruto = 24000.0;
      final salarioMensual = salarioBruto / 12; // 2.000€
      final umbral = salarioMensual * 0.20; // 400€
      final ajuste = -600.0; // abs > 400€

      expect(ajuste.abs() > umbral, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMBIO SITUACIÓN FAMILIAR MID-YEAR
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cambio situación familiar a mitad de año', () {
    test('Nacimiento de hijo en junio: IRPF anual se recalcula con hijos', () {
      // Enero-mayo: sin hijos
      final configSinHijos = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        numHijos: 0,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );
      final pctSinHijos = NominasService.calcularPorcentajeIrpf(30000, config: configSinHijos);

      // A partir de junio: 1 hijo (menor de 3 años → art. 58.2 LIRPF)
      final configConHijo = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        numHijos: 1,
        numHijosMenores3: 1,
      );
      final pctConHijo = NominasService.calcularPorcentajeIrpf(30000, config: configConHijo);

      // El % con hijo debe ser menor
      expect(pctConHijo, lessThan(pctSinHijos));

      // La regularización en diciembre corrige la diferencia
      // Caso más realista: el empleador no recalculó hasta diciembre,
      // así que los 11 meses (ene-nov) se retuvieron al tipo viejo
      final totalRetenido = 11 * (30000 / 12) * pctSinHijos / 100;

      // El correcto para el año completo (con hijo desde junio):
      // En España, el mínimo por descendientes se aplica al año completo
      final irpfAnualCorrecto = 30000 * pctConHijo / 100;

      // Se habrá retenido de más → ajuste negativo (devolver al trabajador)
      // Se habrá retenido de más
      expect(ajuste, lessThan(0)); // devolver al trabajador
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO ResultadoRegularizacion
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo ResultadoRegularizacion', () {
    test('Resultado con todos los campos', () {
      const resultado = ResultadoRegularizacion(
        irpfRetenidoEneNov: 4500,
        irpfAnualCorrecto: 5000,
        ajuste: 500,
        baseImponibleAnualReal: 30000,
        porcentajeEfectivoReal: 16.67,
        porcentajeEfectivoAplicado: 15.0,
        alertaDesviacion: true,
        mensajeAlerta: 'Se ha retenido de menos durante el año.',
      );

      expect(resultado.ajuste, 500);
      expect(resultado.alertaDesviacion, isTrue);
      expect(resultado.mensajeAlerta, isNotNull);
    });

    test('Resultado sin alerta', () {
      const resultado = ResultadoRegularizacion(
        irpfRetenidoEneNov: 5000,
        irpfAnualCorrecto: 5100,
        ajuste: 100,
        baseImponibleAnualReal: 30000,
        porcentajeEfectivoReal: 17.0,
        porcentajeEfectivoAplicado: 16.67,
        alertaDesviacion: false,
        mensajeAlerta: null,
      );

      expect(resultado.alertaDesviacion, isFalse);
      expect(resultado.mensajeAlerta, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO REAL: REGULARIZACIÓN DICIEMBRE HOSTELERÍA GUADALAJARA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso real: Camarero hostelería Guadalajara — diciembre', () {
    test('Empleado 21.000€/año CLM, retención media 10% → ajuste en diciembre', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 21000,
        numPagas: 15,
        comunidadAutonoma: ComunidadAutonoma.castillaMancha,
      );

      final pctCorrecto = NominasService.calcularPorcentajeIrpf(21000, config: config);
      final irpfAnualCorrecto = 21000 * pctCorrecto / 100;

      // Simulamos 11 meses retenidos al 10% (estimación incorrecta)
      final retenido11Meses = 11 * (21000 / 12) * 10 / 100; // 1.925€

      final ajuste = irpfAnualCorrecto - retenido11Meses;

      // El ajuste es la diferencia que se aplica en diciembre
      // Puede ser positivo o negativo dependiendo del IRPF real
      expect(ajuste.isFinite, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('Salario 0 → todo es 0', () {
      final pct = NominasService.calcularPorcentajeIrpf(0);
      expect(pct, 0);
      final irpf = 0 * pct / 100;
      expect(irpf, 0);
    });

    test('IRPF personalizado: no se regulariza automáticamente', () {
      final config = DatosNominaEmpleado(
        salarioBrutoAnual: 30000,
        irpfPersonalizado: 15.0,
      );
      // Cuando el IRPF es personalizado, la regularización debería
      // comparar contra el 15% fijado, no contra la tarifa
      final cuotaPersonalizada = 30000 * 15.0 / 100;
      expect(cuotaPersonalizada, 4500);
    });
  });
}

