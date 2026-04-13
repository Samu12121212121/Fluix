        nif: 'B12345678',
        nif: 'A28123456',
      expect(reg1.substring(10, 19).trim(), 'B19123456');
import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/modelo111.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/modelo111_service.dart';
import 'package:planeag_flutter/services/exportadores_aeat/modelo111_aeat_exporter.dart';

/// Tests del Modelo 111 — Retenciones e ingresos a cuenta IRPF.
///
/// Cubren:
/// 1. Bar con 3 empleados (T1 2026)
/// 2. Retribución en especie (comida empresa)
/// 3. Declaración negativa
/// 4. Declaración complementaria
/// 5. Formato fichero AEAT (posicional DR111e16v18)
/// 6. Modelo de datos
/// 7. Edge cases
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una nómina simulada con los campos necesarios.
  Nomina _nomina({
    required String empleadoId,
    required String nombre,
    required int mes,
    required double bruto,
    required double retencionIrpf,
    double retribucionesEspecie = 0,
  }) {
    return Nomina(
      id: '${empleadoId}_$mes',
      empresaId: 'emp001',
      empleadoId: empleadoId,
      empleadoNombre: nombre,
      mes: mes,
      anio: 2026,
      periodo: '${Nomina.nombreMes(mes)} 2026',
      salarioBrutoMensual: bruto,
      retribucionesEspecie: retribucionesEspecie,
      baseCotizacion: bruto,
      ssTrabajadorCC: 0,
      ssTrabajadorDesempleo: 0,
      ssTrabajadorFP: 0,
      baseIrpf: bruto + retribucionesEspecie,
      porcentajeIrpf: bruto > 0 ? (retencionIrpf / bruto * 100) : 0,
      retencionIrpf: retencionIrpf,
      ssEmpresaCC: 0,
      ssEmpresaDesempleo: 0,
      ssEmpresaFogasa: 0,
      ssEmpresaFP: 0,
      estado: EstadoNomina.pagada,
      fechaCreacion: DateTime(2026, mes, 28),
    );
  }

  final svc = Modelo111Service();

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: BAR CON 3 EMPLEADOS — T1 2026
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 1: Bar con 3 empleados, T1 2026', () {
    late Modelo111 modelo;

    setUp(() {
      final nominas = <Nomina>[
        // Empleado A: 1.800€/mes × 3 meses, 15% retención = 270€/mes
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'A', nombre: 'Empleado A', mes: m,
          bruto: 1800, retencionIrpf: 270)),
        // Empleado B: 1.500€/mes × 3 meses, 12% retención = 180€/mes
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'B', nombre: 'Empleado B', mes: m,
          bruto: 1500, retencionIrpf: 180)),
        // Empleado C: 1.200€/mes × 3 meses, 9% retención = 108€/mes
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'C', nombre: 'Empleado C', mes: m,
          bruto: 1200, retencionIrpf: 108)),
      ];

      modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );
    });

    test('c01 = 3 perceptores', () {
      expect(modelo.c01, 3);
    });

    test('c02 = 13.500€ (suma brutos dinerarios)', () {
      // A: 1800×3 = 5400, B: 1500×3 = 4500, C: 1200×3 = 3600
      expect(modelo.c02, 13500);
    });

    test('c03 = 1.674€ (suma retenciones)', () {
      // A: 270×3 = 810, B: 180×3 = 540, C: 108×3 = 324
      expect(modelo.c03, 1674);
    });

    test('c28 = c03 = 1.674€ (total retenciones sin especie)', () {
      expect(modelo.c28, 1674);
    });

    test('c30 = c28 = 1.674€ (resultado a ingresar)', () {
      expect(modelo.c30, 1674);
    });

    test('tipo = ingreso', () {
      expect(modelo.tipoAutomatico, TipoDeclaracion111.ingreso);
    });

    test('9 nóminas incluidas', () {
      expect(modelo.nominasIncluidas.length, 9);
    });

    test('Trimestre correcto', () {
      expect(modelo.trimestre, '1T');
      expect(modelo.ejercicio, 2026);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 2: RETRIBUCIÓN EN ESPECIE (comida empresa)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 2: Retribución en especie', () {
    late Modelo111 modelo;

    setUp(() {
      final nominas = [1, 2, 3].map((m) => _nomina(
        empleadoId: 'X', nombre: 'Empleado X', mes: m,
        bruto: 1500,
        retencionIrpf: 300, // IRPF sobre total (dinerario + especie)
        retribucionesEspecie: 100,
      )).toList();

      modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );
    });

    test('c04 = 1 perceptor con especie', () {
      expect(modelo.c04, 1);
    });

    test('c05 = 300€ (100€/mes × 3 meses)', () {
      expect(modelo.c05, 300);
    });

    test('c06 = ingresos a cuenta proporcionales', () {
      // Proporción especie: 100/1600 = 0.0625
      // IRPF especie por mes: 300 × 0.0625 = 18.75
      // Total: 18.75 × 3 = 56.25
      expect(modelo.c06, closeTo(56.25, 0.01));
    });

    test('c03 = retenciones dinerarias (excluye proporción especie)', () {
      // IRPF dinerario por mes: 300 - 18.75 = 281.25
      // Total: 281.25 × 3 = 843.75
      expect(modelo.c03, closeTo(843.75, 0.01));
    });

    test('c28 = c03 + c06', () {
      expect(modelo.c28, closeTo(modelo.c03 + modelo.c06, 0.01));
    });

    test('c01 = 1 perceptor dinerario', () {
      expect(modelo.c01, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 3: DECLARACIÓN NEGATIVA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 3: Declaración negativa (sin nóminas)', () {
    test('Tipo = negativa, c28 = 0, c30 = 0', () {
      final modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: [],
      );

      expect(modelo.tipoAutomatico, TipoDeclaracion111.negativa);
      expect(modelo.c28, 0);
      expect(modelo.c30, 0);
      expect(modelo.c01, 0);
      expect(modelo.c02, 0);
      expect(modelo.c03, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 4: DECLARACIÓN COMPLEMENTARIA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 4: Declaración complementaria', () {
    test('c30 = c28 - c29 (700 - 500 = 200)', () {
      // Declaración original T2: c28 = 500€
      // Nueva declaración con corrección: c28 = 700€, c29 = 500€
      final nominas = [4, 5, 6].map((m) => _nomina(
        empleadoId: 'A', nombre: 'A', mes: m,
        bruto: 2000, retencionIrpf: 233.33,
      )).toList();

      final modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '2T',
        nominas: nominas,
        deducirComplementaria: 500,
        tipoForzado: TipoDeclaracion111.complementaria,
      );

      // c28 ≈ 699.99 (233.33 × 3)
      expect(modelo.c28, closeTo(700, 1));
      expect(modelo.c29, 500);
      expect(modelo.c30, closeTo(200, 1));
      expect(modelo.tipo, TipoDeclaracion111.complementaria);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 5: FICHERO AEAT (formato posicional DR111e16v18)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso 5: Fichero AEAT .txt', () {
    late Modelo111 modelo;
    late EmpresaConfig empresa;
        nif: 'B19123454',
    setUp(() {
      empresa = const EmpresaConfig(
        nif: 'B19123456',
        razonSocial: 'Bar La Esquina S.L.',
      );

      final nominas = <Nomina>[
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'A', nombre: 'A', mes: m,
          bruto: 1800, retencionIrpf: 270)),
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'B', nombre: 'B', mes: m,
          bruto: 1500, retencionIrpf: 180)),
        ...[1, 2, 3].map((m) => _nomina(
          empleadoId: 'C', nombre: 'C', mes: m,
          bruto: 1200, retencionIrpf: 108)),
      ];

      modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );
    });

    test('Fichero tiene 2 registros de 500 chars', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final lineas = txt.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 2);
      expect(lineas[0].length, 500);
      expect(lineas[1].length, 500);
    });

    test('Registro 1: tipo "11", modelo "11"', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg1 = txt.split('\r\n')[0];
      expect(reg1.substring(0, 2), '11'); // tipo
      expect(reg1.substring(2, 4), '11'); // modelo
      expect(reg1.substring(4, 8), '2026'); // ejercicio
      expect(reg1.substring(8, 10), '1T'); // período
    });

    test('Registro 1: NIF declarante en pos 11-19', () {
      expect(reg1.substring(10, 19).trim(), 'B19123454');
          modelo: modelo, empresa: empresa);
      final reg1 = txt.split('\r\n')[0];
      expect(reg1.substring(10, 19).trim(), 'B19123456');
    });

    test('Registro 1: tipo declaración = "I"', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg1 = txt.split('\r\n')[0];
      expect(reg1[59], 'I'); // pos 60
    });

    test('Registro 2: c28 en céntimos en pos 335-349', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg2 = txt.split('\r\n')[1];
      // c28 = 1674.00 → 167400 céntimos
      final c28txt = reg2.substring(334, 349);
      expect(int.parse(c28txt), 167400);
    });

    test('Registro 2: c30 en céntimos en pos 365-379', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg2 = txt.split('\r\n')[1];
      final c30txt = reg2.substring(364, 379);
      expect(int.parse(c30txt), 167400);
    });

    test('Registro 2: c01 (nº perceptores) en pos 20-24', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg2 = txt.split('\r\n')[1];
      final c01txt = reg2.substring(19, 24);
      expect(int.parse(c01txt), 3);
    });

    test('Registro 2: c02 en céntimos en pos 25-39', () {
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg2 = txt.split('\r\n')[1];
      final c02txt = reg2.substring(24, 39);
      // 13500.00 → 1350000 céntimos
      expect(int.parse(c02txt), 1350000);
    });

    test('Declaración negativa: tipo = "N"', () {
      final negativa = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: [],
      );
      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: negativa, empresa: empresa);
      final reg1 = txt.split('\r\n')[0];
      expect(reg1[59], 'N');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO DE DATOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Modelo de datos Modelo111', () {
    test('Serialización ida y vuelta Firestore', () {
      final original = Modelo111(
        id: '2026_1T',
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        fechaInicio: DateTime(2026, 1, 1),
        fechaFin: DateTime(2026, 3, 31),
        plazoLimite: DateTime(2026, 4, 20),
        c01: 3, c02: 13500, c03: 1674,
        c04: 1, c05: 300, c06: 57,
        fechaCreacion: DateTime(2026, 3, 15),
        nominasIncluidas: ['n1', 'n2', 'n3'],
      );

      final map = original.toMap();
      final restaurado = Modelo111.fromMap(map);

      expect(restaurado.c01, 3);
      expect(restaurado.c02, 13500);
      expect(restaurado.c03, 1674);
      expect(restaurado.c04, 1);
      expect(restaurado.c05, 300);
      expect(restaurado.c06, 57);
      expect(restaurado.c28, 1674 + 57);
      expect(restaurado.nominasIncluidas.length, 3);
      expect(restaurado.trimestre, '1T');
    });

    test('c28 = suma de todas las retenciones', () {
      final m = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
        c03: 100, c06: 20, c09: 30, c12: 10,
        c15: 5, c18: 3, c21: 2, c24: 1, c27: 0.50,
      );
      expect(m.c28, closeTo(171.50, 0.01));
    });

    test('c30 nunca negativo', () {
      final m = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
        c03: 100, c29: 200, // deducir más de lo que hay
      );
      expect(m.c30, 0);
    });

    test('Plazos de presentación correctos', () {
      expect(Modelo111.calcularPlazoLimite(2026, '1T'), DateTime(2026, 4, 20));
      expect(Modelo111.calcularPlazoLimite(2026, '2T'), DateTime(2026, 7, 20));
      expect(Modelo111.calcularPlazoLimite(2026, '3T'), DateTime(2026, 10, 20));
      expect(Modelo111.calcularPlazoLimite(2026, '4T'), DateTime(2027, 1, 20));
    });

    test('Rangos de meses por trimestre', () {
      expect(Modelo111.rangoMeses('1T'), (mesInicio: 1, mesFin: 3));
      expect(Modelo111.rangoMeses('2T'), (mesInicio: 4, mesFin: 6));
      expect(Modelo111.rangoMeses('3T'), (mesInicio: 7, mesFin: 9));
      expect(Modelo111.rangoMeses('4T'), (mesInicio: 10, mesFin: 12));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('copyWith modifica solo campos especificados', () {
      final original = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
        c01: 3, c02: 5000, c03: 800,
      );
      final modificado = original.copyWith(c01: 5, c03: 1200);
      expect(modificado.c01, 5);
      expect(modificado.c02, 5000); // no cambia
      expect(modificado.c03, 1200);
    });

    test('TipoDeclaracion111 códigos AEAT correctos', () {
      expect(TipoDeclaracion111.ingreso.codigo, 'I');
      expect(TipoDeclaracion111.negativa.codigo, 'N');
      expect(TipoDeclaracion111.complementaria.codigo, 'C');
    });

    test('tipoAutomatico deduce del resultado', () {
      final positivo = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
        c03: 500,
      );
      expect(positivo.tipoAutomatico, TipoDeclaracion111.ingreso);

      final negativa = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
      );
      expect(negativa.tipoAutomatico, TipoDeclaracion111.negativa);

      final complementaria = Modelo111(
        id: 'x', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
        c03: 700, c29: 500,
        tipo: TipoDeclaracion111.complementaria,
      );
      expect(complementaria.tipoAutomatico, TipoDeclaracion111.complementaria);
    });

    test('Secciones II-V a cero para PYMEs', () {
      final nominas = [1, 2, 3].map((m) => _nomina(
        empleadoId: 'A', nombre: 'A', mes: m,
        bruto: 1500, retencionIrpf: 200,
      )).toList();

      final modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );

      // Secciones II-V deben ser 0
      expect(modelo.c07, 0); expect(modelo.c08, 0); expect(modelo.c09, 0);
      expect(modelo.c10, 0); expect(modelo.c11, 0); expect(modelo.c12, 0);
      expect(modelo.c13, 0); expect(modelo.c14, 0); expect(modelo.c15, 0);
      expect(modelo.c16, 0); expect(modelo.c17, 0); expect(modelo.c18, 0);
      expect(modelo.c19, 0); expect(modelo.c20, 0); expect(modelo.c21, 0);
      expect(modelo.c22, 0); expect(modelo.c23, 0); expect(modelo.c24, 0);
      expect(modelo.c25, 0); expect(modelo.c26, 0); expect(modelo.c27, 0);
    });

    test('Empleado con 0€ retención IRPF sigue contando como perceptor', () {
      final nominas = [1].map((m) => _nomina(
        empleadoId: 'A', nombre: 'A', mes: m,
        bruto: 800, retencionIrpf: 0, // Sin retención (SMI)
      )).toList();

      final modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );

      expect(modelo.c01, 1); // sigue siendo perceptor
      expect(modelo.c02, 800);
      expect(modelo.c03, 0);
      expect(modelo.c28, 0);
      expect(modelo.tipoAutomatico, TipoDeclaracion111.negativa);
    });

    test('Mismo empleado en varios meses cuenta como 1 perceptor', () {
      final nominas = [1, 2, 3].map((m) => _nomina(
        empleadoId: 'UNICO', nombre: 'Juan', mes: m,
        bruto: 2000, retencionIrpf: 300,
      )).toList();

      final modelo = svc.agregarNominas(
        empresaId: 'emp001',
        ejercicio: 2026,
        trimestre: '1T',
        nominas: nominas,
      );

      expect(modelo.c01, 1); // 1 perceptor, no 3
      expect(modelo.c02, 6000);
      expect(modelo.c03, 900);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // INTEGRIDAD FORMATO AEAT
  // ═══════════════════════════════════════════════════════════════════════════

        nif: 'A28123453',
    test('Importes en céntimos sin decimales', () {
      final empresa = const EmpresaConfig(
        nif: 'A28123456',
        razonSocial: 'Test S.L.',
      );
      final modelo = Modelo111(
        id: '2026_2T', empresaId: 'x', ejercicio: 2026, trimestre: '2T',
        fechaInicio: DateTime(2026, 4, 1), fechaFin: DateTime(2026, 6, 30),
        plazoLimite: DateTime(2026, 7, 20), fechaCreacion: DateTime(2026),
        c01: 2, c02: 12345.67, c03: 1234.56,
      );

      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg2 = txt.split('\r\n')[1];

      // c02: 12345.67€ → 1234567 céntimos
      expect(int.parse(reg2.substring(24, 39)), 1234567);
      // c03: 1234.56€ → 123456 céntimos
      expect(int.parse(reg2.substring(39, 54)), 123456);
    });
        nif: 'B12345674',
    test('Razón social con acentos se normaliza', () {
      final empresa = const EmpresaConfig(
        nif: 'B12345678',
        razonSocial: 'Peluquería María José S.L.',
      );
      final modelo = Modelo111(
        id: '2026_1T', empresaId: 'x', ejercicio: 2026, trimestre: '1T',
        fechaInicio: DateTime(2026), fechaFin: DateTime(2026),
        plazoLimite: DateTime(2026), fechaCreacion: DateTime(2026),
      );

      final txt = Modelo111AeatExporter.exportarTexto(
          modelo: modelo, empresa: empresa);
      final reg1 = txt.split('\r\n')[0];
      final razon = reg1.substring(19, 59);

      // Sin acentos, en mayúsculas
      expect(razon.contains('Í'), false);
      expect(razon.contains('É'), false);
      expect(razon.contains('á'), false);
      expect(razon, contains('PELUQUERIA'));
      expect(razon, contains('MARIA'));
    });
  });
}

