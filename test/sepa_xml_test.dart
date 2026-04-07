import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/sepa_xml_generator.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/domain/modelos/remesa_sepa.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIÓN IBAN
  // ═══════════════════════════════════════════════════════════════════════════
  group('Validación IBAN español', () {
    test('IBAN válido ES9121000418450200051332', () {
      expect(SepaXmlGenerator.validarIBAN('ES9121000418450200051332'), isNull);
    });

    test('IBAN válido con espacios ES91 2100 0418 4502 0005 1332', () {
      expect(SepaXmlGenerator.validarIBAN('ES91 2100 0418 4502 0005 1332'), isNull);
    });

    test('IBAN válido en minúsculas es9121000418450200051332', () {
      expect(SepaXmlGenerator.validarIBAN('es9121000418450200051332'), isNull);
    });

    test('IBAN nulo devuelve error', () {
      expect(SepaXmlGenerator.validarIBAN(null), isNotNull);
    });

    test('IBAN vacío devuelve error', () {
      expect(SepaXmlGenerator.validarIBAN(''), isNotNull);
    });

    test('IBAN demasiado corto devuelve error', () {
      expect(SepaXmlGenerator.validarIBAN('ES91210004'), isNotNull);
    });

    test('IBAN no español (DE) devuelve error', () {
      expect(SepaXmlGenerator.validarIBAN('DE89370400440532013000'), isNotNull);
    });

    test('IBAN con dígitos de control erróneos', () {
      // Cambiamos el dígito de control de 91 a 00
      expect(SepaXmlGenerator.validarIBAN('ES0021000418450200051332'), isNotNull);
    });

    test('IBAN con letras en posiciones numéricas', () {
      expect(SepaXmlGenerator.validarIBAN('ES91ABCD0418450200051332'), isNotNull);
    });
  });

  group('Formateo y limpieza IBAN', () {
    test('limpiarIBAN quita espacios y guiones, mayúsculas', () {
      expect(
        SepaXmlGenerator.limpiarIBAN('es91 2100-0418 4502 0005 1332'),
        'ES9121000418450200051332',
      );
    });

    test('formatearIBAN produce grupos de 4', () {
      expect(
        SepaXmlGenerator.formatearIBAN('ES9121000418450200051332'),
        'ES91 2100 0418 4502 0005 1332',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDACIÓN DE LOTE
  // ═══════════════════════════════════════════════════════════════════════════
  group('Validación lote SEPA', () {
    final ordenanteOk = DatosOrdenante(
      nif: 'B76543210',
      razonSocial: 'Bar Ejemplo S.L.',
      direccion: 'Calle Mayor 1, Guadalajara',
      ibanEmpresa: 'ES9121000418450200051332',
    );

    Nomina _crearNomina({
      required String id,
      required String empleadoId,
      required String nombre,
      double salarioBrutoMensual = 1800,
      double ssTrabajadorCC = 85,
      double ssTrabajadorDesempleo = 28,
      double ssTrabajadorFP = 1.8,
      double retencionIrpf = 162,
      EstadoNomina estado = EstadoNomina.aprobada,
    }) => Nomina(
      id: id,
      empresaId: 'emp1',
      empleadoId: empleadoId,
      empleadoNombre: nombre,
      empleadoNif: '12345678A',
      mes: 3,
      anio: 2026,
      periodo: 'Marzo 2026',
      salarioBrutoMensual: salarioBrutoMensual,
      baseCotizacion: salarioBrutoMensual,
      ssTrabajadorCC: ssTrabajadorCC,
      ssTrabajadorDesempleo: ssTrabajadorDesempleo,
      ssTrabajadorFP: ssTrabajadorFP,
      baseIrpf: salarioBrutoMensual,
      porcentajeIrpf: 9.0,
      retencionIrpf: retencionIrpf,
      ssEmpresaCC: 400,
      ssEmpresaDesempleo: 100,
      ssEmpresaFogasa: 3.6,
      ssEmpresaFP: 10,
      estado: estado,
      fechaCreacion: DateTime(2026, 3, 1),
    );

    final datosEmpleados = {
      'emp_a': DatosNominaEmpleado(
        salarioBrutoAnual: 21600,
        cuentaBancaria: 'ES9121000418450200051332',
        nif: '12345678A',
      ),
      'emp_b': DatosNominaEmpleado(
        salarioBrutoAnual: 14400,
        cuentaBancaria: 'ES6000491500051234567892',
        nif: '87654321B',
      ),
      'emp_c': DatosNominaEmpleado(
        salarioBrutoAnual: 11760,
        cuentaBancaria: 'ES7100302053091234567895',
        nif: '11223344C',
      ),
    };

    test('lote válido no genera errores', () {
      final nominas = [
        _crearNomina(id: 'n1', empleadoId: 'emp_a', nombre: 'Juan García'),
        _crearNomina(id: 'n2', empleadoId: 'emp_b', nombre: 'Ana López'),
        _crearNomina(id: 'n3', empleadoId: 'emp_c', nombre: 'Pedro Ruiz'),
      ];
      final errores = SepaXmlGenerator.validarLote(
        nominas: nominas,
        ordenante: ordenanteOk,
        datosEmpleados: datosEmpleados,
        fechaEjecucion: DateTime(2026, 3, 23), // lunes
      );
      expect(errores, isEmpty);
    });

    test('empleado sin IBAN genera error', () {
      final datosConFallo = {
        'emp_a': DatosNominaEmpleado(
          salarioBrutoAnual: 21600,
          cuentaBancaria: null, // sin IBAN
        ),
      };
      final nominas = [
        _crearNomina(id: 'n1', empleadoId: 'emp_a', nombre: 'Juan García'),
      ];
      final errores = SepaXmlGenerator.validarLote(
        nominas: nominas,
        ordenante: ordenanteOk,
        datosEmpleados: datosConFallo,
        fechaEjecucion: DateTime(2026, 3, 23),
      );
      expect(errores, contains(contains('sin IBAN')));
    });

    test('IBAN inválido genera error', () {
      final datosConFallo = {
        'emp_a': DatosNominaEmpleado(
          salarioBrutoAnual: 21600,
          cuentaBancaria: 'ES0000000000000000000000', // inválido
        ),
      };
      final nominas = [
        _crearNomina(id: 'n1', empleadoId: 'emp_a', nombre: 'Juan García'),
      ];
      final errores = SepaXmlGenerator.validarLote(
        nominas: nominas,
        ordenante: ordenanteOk,
        datosEmpleados: datosConFallo,
        fechaEjecucion: DateTime(2026, 3, 23),
      );
      expect(errores, isNotEmpty);
      expect(errores.any((e) => e.contains('Juan García')), isTrue);
    });

    test('nómina en borrador genera error', () {
      final nominas = [
        _crearNomina(
          id: 'n1', empleadoId: 'emp_a', nombre: 'Juan García',
          estado: EstadoNomina.borrador,
        ),
      ];
      final errores = SepaXmlGenerator.validarLote(
        nominas: nominas,
        ordenante: ordenanteOk,
        datosEmpleados: datosEmpleados,
        fechaEjecucion: DateTime(2026, 3, 23),
      );
      expect(errores, contains(contains('no está aprobada')));
    });

    test('fecha en fin de semana genera error', () {
      final nominas = [
        _crearNomina(id: 'n1', empleadoId: 'emp_a', nombre: 'Juan García'),
      ];
      final errores = SepaXmlGenerator.validarLote(
        nominas: nominas,
        ordenante: ordenanteOk,
        datosEmpleados: datosEmpleados,
        fechaEjecucion: DateTime(2026, 3, 28), // sábado
      );
      expect(errores, contains(contains('fin de semana')));
    });

    test('sugerirDiaHabil salta fines de semana', () {
      // 28 marzo 2026 es sábado
      final sugerido = SepaXmlGenerator.sugerirDiaHabil(DateTime(2026, 3, 28));
      expect(sugerido.weekday, lessThanOrEqualTo(5)); // lun-vie
      expect(sugerido.day, 30); // lunes 30
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN XML
  // ═══════════════════════════════════════════════════════════════════════════
  group('Generación XML SEPA pain.001.001.03', () {
    final ordenante = DatosOrdenante(
      nif: 'B76543210',
      razonSocial: 'Bar La Esquina S.L.',
      direccion: 'Calle Mayor 1, 19001 Guadalajara',
      ibanEmpresa: 'ES9121000418450200051332',
      bicEmpresa: 'CAIXESBBXXX',
    );

    Nomina _nom(String id, String empId, String nombre, String nif, double bruto,
        double ssCC, double ssDes, double ssFP, double irpf) => Nomina(
      id: id, empresaId: 'emp1', empleadoId: empId, empleadoNombre: nombre,
      empleadoNif: nif, mes: 3, anio: 2026, periodo: 'Marzo 2026',
      salarioBrutoMensual: bruto, baseCotizacion: bruto,
      ssTrabajadorCC: ssCC, ssTrabajadorDesempleo: ssDes, ssTrabajadorFP: ssFP,
      baseIrpf: bruto, porcentajeIrpf: 9.0, retencionIrpf: irpf,
      ssEmpresaCC: 400, ssEmpresaDesempleo: 100, ssEmpresaFogasa: 3.6,
      ssEmpresaFP: 10, estado: EstadoNomina.aprobada,
      fechaCreacion: DateTime(2026, 3, 1),
    );

    final nominas = [
      _nom('n1', 'e1', 'Juan García López', '12345678A', 1800, 85.14, 28.8, 1.8, 162),
      _nom('n2', 'e2', 'Ana Martínez Ruiz', '87654321B', 1500, 71.0, 24.0, 1.5, 135),
      _nom('n3', 'e3', 'Pedro Sánchez Villa', '11223344C', 1200, 56.8, 19.2, 1.2, 108),
    ];

    final datosEmpleados = {
      'e1': DatosNominaEmpleado(salarioBrutoAnual: 21600,
          cuentaBancaria: 'ES9121000418450200051332', nif: '12345678A'),
      'e2': DatosNominaEmpleado(salarioBrutoAnual: 18000,
          cuentaBancaria: 'ES6000491500051234567892', nif: '87654321B'),
      'e3': DatosNominaEmpleado(salarioBrutoAnual: 14400,
          cuentaBancaria: 'ES7100302053091234567895', nif: '11223344C'),
    };

    late String xml;

    setUp(() {
      xml = SepaXmlGenerator.generarXML(
        nominas: nominas,
        ordenante: ordenante,
        datosEmpleados: datosEmpleados,
        fechaEjecucion: DateTime(2026, 3, 25),
        msgId: 'B7654321020260323103000',
      );
    });

    test('XML contiene declaración y namespace pain.001.001.03', () {
      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('urn:iso:std:iso:20022:tech:xsd:pain.001.001.03'));
    });

    test('XML contiene CstmrCdtTrfInitn', () {
      expect(xml, contains('<CstmrCdtTrfInitn>'));
      expect(xml, contains('</CstmrCdtTrfInitn>'));
    });

    test('NbOfTxs = 3 (GrpHdr y PmtInf)', () {
      expect(xml, contains('<NbOfTxs>3</NbOfTxs>'));
    });

    test('CtrlSum coincide con suma salarioNeto', () {
      final totalNeto = nominas.fold(0.0, (s, n) => s + n.salarioNeto);
      expect(xml, contains('<CtrlSum>${totalNeto.toStringAsFixed(2)}</CtrlSum>'));
    });

    test('MsgId aparece en GrpHdr', () {
      expect(xml, contains('<MsgId>B7654321020260323103000</MsgId>'));
    });

    test('PmtMtd es TRF', () {
      expect(xml, contains('<PmtMtd>TRF</PmtMtd>'));
    });

    test('CtgyPurp es SALA (nómina)', () {
      expect(xml, contains('<Cd>SALA</Cd>'));
    });

    test('SvcLvl es SEPA', () {
      expect(xml, contains('<Cd>SEPA</Cd>'));
    });

    test('ChrgBr es SLEV', () {
      expect(xml, contains('<ChrgBr>SLEV</ChrgBr>'));
    });

    test('BtchBookg es true', () {
      expect(xml, contains('<BtchBookg>true</BtchBookg>'));
    });

    test('ReqdExctnDt es 2026-03-25', () {
      expect(xml, contains('<ReqdExctnDt>2026-03-25</ReqdExctnDt>'));
    });

    test('IBAN empresa aparece en DbtrAcct', () {
      expect(xml, contains('<IBAN>ES9121000418450200051332</IBAN>'));
    });

    test('BIC empresa aparece en DbtrAgt', () {
      expect(xml, contains('<BIC>CAIXESBBXXX</BIC>'));
    });

    test('NIF empresa aparece en Dbtr/Id', () {
      expect(xml, contains('<Id>B76543210</Id>'));
    });

    test('Razón social empresa aparece en Dbtr/Nm', () {
      expect(xml, contains('<Nm>Bar La Esquina S.L.</Nm>'));
    });

    test('País ES en PstlAdr', () {
      expect(xml, contains('<Ctry>ES</Ctry>'));
    });

    test('3 CdtTrfTxInf presentes', () {
      final count = '<CdtTrfTxInf>'.allMatches(xml).length;
      expect(count, 3);
    });

    test('cada CdtTrfTxInf tiene EndToEndId único', () {
      expect(xml, contains('NOMINA-2026-03-12345678A'));
      expect(xml, contains('NOMINA-2026-03-87654321B'));
      expect(xml, contains('NOMINA-2026-03-11223344C'));
    });

    test('cada CdtTrfTxInf tiene InstdAmt con Ccy EUR', () {
      final matches = RegExp(r'<InstdAmt Ccy="EUR">[\d.]+</InstdAmt>')
          .allMatches(xml);
      expect(matches.length, 3);
    });

    test('importes netos individuales correctos', () {
      for (final n in nominas) {
        expect(xml, contains(n.salarioNeto.toStringAsFixed(2)));
      }
    });

    test('concepto contiene NOMINA y razón social', () {
      expect(xml, contains('<Ustrd>NOMINA 03/2026'));
    });

    test('Cdtr/Nm contiene nombres empleados', () {
      expect(xml, contains('Juan Garc'));
      expect(xml, contains('Ana Mart'));
      expect(xml, contains('Pedro S'));
    });

    test('IBAN empleados en CdtrAcct', () {
      expect(xml, contains('ES6000491500051234567892'));
      expect(xml, contains('ES7100302053091234567895'));
    });

    test('XML es well-formed (tiene cierre Document)', () {
      expect(xml, contains('</Document>'));
      expect(xml.indexOf('<Document'), lessThan(xml.indexOf('</Document>')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO 1: Bar 3 empleados marzo 2026
  // ═══════════════════════════════════════════════════════════════════════════
  group('Caso 1: Bar hostelería 3 empleados', () {
    // Empleado 1: bruto 1800, ss(85.14+28.8+1.8)=115.74, irpf 162 → neto 1522.26
    // Empleado 2: bruto 1500, ss(71+24+1.5)=96.5, irpf 135 → neto 1268.50
    // Empleado 3: bruto 1200, ss(56.8+19.2+1.2)=77.2, irpf 108 → neto 1014.80
    // Total = 3805.56

    Nomina _nom(String id, String empId, String nombre, String nif,
        double bruto, double ssCC, double ssDes, double ssFP, double irpf) =>
      Nomina(
        id: id, empresaId: 'emp1', empleadoId: empId, empleadoNombre: nombre,
        empleadoNif: nif, mes: 3, anio: 2026, periodo: 'Marzo 2026',
        salarioBrutoMensual: bruto, baseCotizacion: bruto,
        ssTrabajadorCC: ssCC, ssTrabajadorDesempleo: ssDes, ssTrabajadorFP: ssFP,
        baseIrpf: bruto, porcentajeIrpf: 9.0, retencionIrpf: irpf,
        ssEmpresaCC: 400, ssEmpresaDesempleo: 100, ssEmpresaFogasa: 3.6,
        ssEmpresaFP: 10, estado: EstadoNomina.aprobada,
        fechaCreacion: DateTime(2026, 3, 1),
      );

    final nominas = [
      _nom('n1', 'e1', 'Juan García', '12345678A', 1800, 85.14, 28.8, 1.8, 162),
      _nom('n2', 'e2', 'Ana López', '87654321B', 1500, 71.0, 24.0, 1.5, 135),
      _nom('n3', 'e3', 'Pedro Ruiz', '11223344C', 1200, 56.8, 19.2, 1.2, 108),
    ];

    test('NbOfTxs = 3 y CtrlSum correcto', () {
      final total = nominas.fold(0.0, (s, n) => s + n.salarioNeto);
      final xml = SepaXmlGenerator.generarXML(
        nominas: nominas,
        ordenante: DatosOrdenante(
          nif: 'B76543210', razonSocial: 'Bar Ejemplo S.L.',
          direccion: 'C/ Mayor 1', ibanEmpresa: 'ES9121000418450200051332',
        ),
        datosEmpleados: {
          'e1': DatosNominaEmpleado(salarioBrutoAnual: 21600,
              cuentaBancaria: 'ES9121000418450200051332'),
          'e2': DatosNominaEmpleado(salarioBrutoAnual: 18000,
              cuentaBancaria: 'ES6000491500051234567892'),
          'e3': DatosNominaEmpleado(salarioBrutoAnual: 14400,
              cuentaBancaria: 'ES7100302053091234567895'),
        },
        fechaEjecucion: DateTime(2026, 3, 25),
      );

      expect(xml, contains('<NbOfTxs>3</NbOfTxs>'));
      expect(xml, contains('<CtrlSum>${total.toStringAsFixed(2)}</CtrlSum>'));
      expect(xml, contains('<Cd>SALA</Cd>'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODELO DE DATOS REMESA SEPA
  // ═══════════════════════════════════════════════════════════════════════════
  group('Modelo RemesaSepa', () {
    test('fromMap / toMap ida y vuelta', () {
      final remesa = RemesaSepa(
        id: 'r1',
        empresaId: 'emp1',
        mes: 3,
        anio: 2026,
        fechaEjecucion: DateTime(2026, 3, 25),
        nominasIds: ['n1', 'n2', 'n3'],
        nTransferencias: 3,
        importeTotal: 3805.56,
        estado: EstadoRemesa.generada,
        msgId: 'B7654321020260323103000',
        xmlGenerado: '<xml/>',
        fechaCreacion: DateTime(2026, 3, 23),
      );

      final map = remesa.toMap();
      expect(map['mes'], 3);
      expect(map['anio'], 2026);
      expect(map['n_transferencias'], 3);
      expect(map['importe_total'], 3805.56);
      expect(map['estado'], 'generada');
      expect(map['msg_id'], 'B7654321020260323103000');
      expect(map['nominas_ids'], ['n1', 'n2', 'n3']);
    });

    test('periodoTexto formatea correctamente', () {
      final remesa = RemesaSepa(
        id: 'r1', empresaId: 'emp1', mes: 3, anio: 2026,
        fechaEjecucion: DateTime(2026, 3, 25),
        nominasIds: [], nTransferencias: 0, importeTotal: 0,
        msgId: 'test', fechaCreacion: DateTime.now(),
      );
      expect(remesa.periodoTexto, 'Marzo 2026');
    });

    test('copyWith actualiza estado', () {
      final remesa = RemesaSepa(
        id: 'r1', empresaId: 'emp1', mes: 3, anio: 2026,
        fechaEjecucion: DateTime(2026, 3, 25),
        nominasIds: [], nTransferencias: 0, importeTotal: 0,
        msgId: 'test', fechaCreacion: DateTime.now(),
      );
      final enviada = remesa.copyWith(
        estado: EstadoRemesa.enviada,
        fechaEnvio: DateTime(2026, 3, 24),
      );
      expect(enviada.estado, EstadoRemesa.enviada);
      expect(enviada.fechaEnvio, isNotNull);
      expect(enviada.id, remesa.id); // no cambia
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FESTIVOS Y DÍAS HÁBILES
  // ═══════════════════════════════════════════════════════════════════════════
  group('Festivos y días hábiles', () {
    test('1 de enero es festivo', () {
      final errores = SepaXmlGenerator.validarLote(
        nominas: [
          Nomina(
            id: 'n1', empresaId: 'e1', empleadoId: 'emp1',
            empleadoNombre: 'Test', mes: 1, anio: 2026, periodo: 'Enero 2026',
            salarioBrutoMensual: 1800, baseCotizacion: 1800,
            ssTrabajadorCC: 85, ssTrabajadorDesempleo: 28, ssTrabajadorFP: 1.8,
            baseIrpf: 1800, porcentajeIrpf: 9, retencionIrpf: 162,
            ssEmpresaCC: 400, ssEmpresaDesempleo: 100, ssEmpresaFogasa: 3.6,
            ssEmpresaFP: 10, estado: EstadoNomina.aprobada,
            fechaCreacion: DateTime(2026, 1, 1),
          ),
        ],
        ordenante: DatosOrdenante(
          nif: 'B76543210', razonSocial: 'Test S.L.',
          direccion: 'Test', ibanEmpresa: 'ES9121000418450200051332',
        ),
        datosEmpleados: {
          'emp1': DatosNominaEmpleado(
            salarioBrutoAnual: 21600,
            cuentaBancaria: 'ES9121000418450200051332',
          ),
        },
        fechaEjecucion: DateTime(2026, 1, 1), // jueves festivo
      );
      expect(errores, contains(contains('festivo')));
    });

    test('sugerirDiaHabil salta festivo de Navidad', () {
      final sugerido = SepaXmlGenerator.sugerirDiaHabil(DateTime(2026, 12, 25));
      expect(sugerido.day, greaterThan(25));
      expect(sugerido.weekday, lessThanOrEqualTo(5));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('razón social con caracteres especiales se escapa en XML', () {
      final xml = SepaXmlGenerator.generarXML(
        nominas: [
          Nomina(
            id: 'n1', empresaId: 'e1', empleadoId: 'emp1',
            empleadoNombre: 'José María O\'Brien & Cía',
            empleadoNif: '12345678A', mes: 3, anio: 2026, periodo: 'Marzo 2026',
            salarioBrutoMensual: 1800, baseCotizacion: 1800,
            ssTrabajadorCC: 85, ssTrabajadorDesempleo: 28, ssTrabajadorFP: 1.8,
            baseIrpf: 1800, porcentajeIrpf: 9, retencionIrpf: 162,
            ssEmpresaCC: 400, ssEmpresaDesempleo: 100, ssEmpresaFogasa: 3.6,
            ssEmpresaFP: 10, estado: EstadoNomina.aprobada,
            fechaCreacion: DateTime(2026, 3, 1),
          ),
        ],
        ordenante: DatosOrdenante(
          nif: 'B76543210', razonSocial: 'Bar "El Rincón" & Tapas S.L.',
          direccion: 'C/ Mayor <1>', ibanEmpresa: 'ES9121000418450200051332',
        ),
        datosEmpleados: {
          'emp1': DatosNominaEmpleado(
            salarioBrutoAnual: 21600,
            cuentaBancaria: 'ES9121000418450200051332',
          ),
        },
        fechaEjecucion: DateTime(2026, 3, 25),
      );
      // No debe contener & o < sin escapar
      expect(xml, contains('&amp;'));
      expect(xml, contains('&lt;'));
      expect(xml, contains('&gt;'));
      expect(xml, contains('&quot;'));
      expect(xml, contains('&apos;'));
    });

    test('MsgId se trunca a 35 caracteres', () {
      final xml = SepaXmlGenerator.generarXML(
        nominas: [
          Nomina(
            id: 'n1', empresaId: 'e1', empleadoId: 'emp1',
            empleadoNombre: 'Test', empleadoNif: '12345678A',
            mes: 3, anio: 2026, periodo: 'Marzo 2026',
            salarioBrutoMensual: 1800, baseCotizacion: 1800,
            ssTrabajadorCC: 85, ssTrabajadorDesempleo: 28, ssTrabajadorFP: 1.8,
            baseIrpf: 1800, porcentajeIrpf: 9, retencionIrpf: 162,
            ssEmpresaCC: 400, ssEmpresaDesempleo: 100, ssEmpresaFogasa: 3.6,
            ssEmpresaFP: 10, estado: EstadoNomina.aprobada,
            fechaCreacion: DateTime(2026, 3, 1),
          ),
        ],
        ordenante: DatosOrdenante(
          nif: 'B76543210', razonSocial: 'Test S.L.',
          direccion: 'Test', ibanEmpresa: 'ES9121000418450200051332',
        ),
        datosEmpleados: {
          'emp1': DatosNominaEmpleado(
            salarioBrutoAnual: 21600,
            cuentaBancaria: 'ES9121000418450200051332',
          ),
        },
        fechaEjecucion: DateTime(2026, 3, 25),
        msgId: 'ESTE_ES_UN_ID_MUY_LARGO_QUE_EXCEDE_35_CHARS_SEPA',
      );
      // Extraer MsgId del XML
      final match = RegExp(r'<MsgId>(.+?)</MsgId>').firstMatch(xml);
      expect(match, isNotNull);
      expect(match!.group(1)!.length, lessThanOrEqualTo(35));
    });

    test('1 sola nómina genera XML válido', () {
      final xml = SepaXmlGenerator.generarXML(
        nominas: [
          Nomina(
            id: 'n1', empresaId: 'e1', empleadoId: 'emp1',
            empleadoNombre: 'Único Empleado', empleadoNif: '12345678A',
            mes: 6, anio: 2026, periodo: 'Junio 2026',
            salarioBrutoMensual: 2000, baseCotizacion: 2000,
            ssTrabajadorCC: 94, ssTrabajadorDesempleo: 32, ssTrabajadorFP: 2,
            baseIrpf: 2000, porcentajeIrpf: 10, retencionIrpf: 200,
            ssEmpresaCC: 450, ssEmpresaDesempleo: 120, ssEmpresaFogasa: 4,
            ssEmpresaFP: 12, estado: EstadoNomina.aprobada,
            fechaCreacion: DateTime(2026, 6, 1),
          ),
        ],
        ordenante: DatosOrdenante(
          nif: 'B76543210', razonSocial: 'Test S.L.',
          direccion: 'Test', ibanEmpresa: 'ES9121000418450200051332',
        ),
        datosEmpleados: {
          'emp1': DatosNominaEmpleado(
            salarioBrutoAnual: 24000,
            cuentaBancaria: 'ES9121000418450200051332',
          ),
        },
        fechaEjecucion: DateTime(2026, 6, 25),
      );
      expect(xml, contains('<NbOfTxs>1</NbOfTxs>'));
      expect('<CdtTrfTxInf>'.allMatches(xml).length, 1);
    });
  });
}

