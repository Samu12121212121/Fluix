import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/sepa_xml_generator.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';

void main() {
  test('Generar XML -> validar contra estructura básica pain.001.001.03', () {
    final nominas = [
      Nomina(
        id: '1', empresaId: 'e1', empleadoId: 'u1', empleadoNombre: 'Juan',
        mes: 1, anio: 2026, periodo: 'Ene 2026', salarioBrutoMensual: 1000,
        baseCotizacion: 1000, ssTrabajadorCC: 40, ssTrabajadorDesempleo: 10, ssTrabajadorFP: 1,
        baseIrpf: 1000, porcentajeIrpf: 10, retencionIrpf: 100,
        ssEmpresaCC: 200, ssEmpresaDesempleo: 50, ssEmpresaFogasa: 2, ssEmpresaFP: 6,
        estado: EstadoNomina.aprobada, fechaCreacion: DateTime.now()
      )
    ];
    
    final ordenante = DatosOrdenante(
      nif: 'B12345678', razonSocial: 'Empresa', direccion: 'Calle 1', ibanEmpresa: 'ES9121000418450200051332'
    );
    
    final datosEmp = {'u1': DatosNominaEmpleado(salarioBrutoAnual: 12000, cuentaBancaria: 'ES9121000418450200051332')};

    final xml = SepaXmlGenerator.generarXML(
      nominas: nominas, 
      ordenante: ordenante, 
      datosEmpleados: datosEmp, 
      fechaEjecucion: DateTime.now()
    );

    expect(xml, contains('pain.001.001.03'));
    expect(xml, contains('<IBAN>ES9121000418450200051332</IBAN>'));
  });

  test('Verificar IBAN con módulo 97', () {
    expect(SepaXmlGenerator.validarIBAN('ES9121000418450200051332'), isNull);
    expect(SepaXmlGenerator.validarIBAN('ES9121000418450200051333'), isNotNull);
  });
}

