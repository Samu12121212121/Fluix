import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_349_exporter.dart';
import 'package:planeag_flutter/services/mod_349_service.dart';

void main() {
  group('MOD349 Exporter', () {
    final empresa = EmpresaConfig(
      nif: 'A58818501',
      razonSocial: 'Empresa Test SL',
      domicilioFiscal: 'Calle Falsa 123',
      codigoPostal: '28001',
      municipio: 'Madrid',
      provincia: 'Madrid',
    );

    test('registro tipo 1 y tipo 2 tienen longitud 500 y cabeceras correctas', () async {
      final exporter = Mod349Exporter();
      final bytes = await exporter.exportar(
        DatosMod349(
          empresa: empresa,
          ejercicio: 2026,
          periodo: '1T',
          operadores: const [
            Operador349(
              codigoPaisNif: 'DE',
              numeroNif: '123456789',
              razonSocial: 'KUNDE GMBH',
              claveOperacion: ClaveOperacion349.entregasExentas,
              baseImponible: 1234.56,
            ),
          ],
        ),
      );

      final txt = String.fromCharCodes(bytes);
      final lineas = txt.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 2);

      final tipo1 = lineas[0];
      final tipo2 = lineas[1];

      expect(tipo1.length, 500);
      expect(tipo2.length, 500);
      expect(tipo1.substring(0, 1), '1');
      expect(tipo2.substring(0, 1), '2');
      expect(tipo1.substring(1, 4), '349');
      expect(tipo2.substring(1, 4), '349');
      expect(tipo2.substring(75, 77), 'DE');
      expect(tipo2.substring(132, 133), 'E');
      expect(tipo2.substring(178, 235), ' ' * 57);
    });

    test('suma de bases de operadores coincide con pos 147-161 del tipo 1', () async {
      final exporter = Mod349Exporter();
      final bytes = await exporter.exportar(
        DatosMod349(
          empresa: empresa,
          ejercicio: 2026,
          periodo: '1T',
          operadores: const [
            Operador349(
              codigoPaisNif: 'DE',
              numeroNif: '123456789',
              razonSocial: 'KUNDE 1',
              claveOperacion: ClaveOperacion349.entregasExentas,
              baseImponible: 100.10,
            ),
            Operador349(
              codigoPaisNif: 'FR',
              numeroNif: 'AB123456789',
              razonSocial: 'KUNDE 2',
              claveOperacion: ClaveOperacion349.prestacionServicios,
              baseImponible: 200.25,
            ),
          ],
        ),
      );

      final tipo1 = String.fromCharCodes(bytes).split('\r\n').first;
      expect(tipo1.substring(146, 159), '0000000000300');
      expect(tipo1.substring(159, 161), '35');
      expect(tipo1.substring(8, 17), isNot('A12345678'));
    });

    test('registro rectificacion tiene longitud 500', () async {
      final exporter = Mod349Exporter();
      final bytes = await exporter.exportar(
        DatosMod349(
          empresa: empresa,
          ejercicio: 2026,
          periodo: '1T',
          operadores: const [],
          rectificaciones: const [
            Rectificacion349(
              codigoPaisNif: 'IT',
              numeroNif: '12345678901',
              razonSocial: 'OPERADOR IT',
              claveOperacion: ClaveOperacion349.entregasExentas,
              ejercicioRectificado: 2025,
              periodoRectificado: '4T',
              baseImponibleRectificada: 900.50,
              baseImponibleAnterior: 1000.50,
            ),
          ],
        ),
      );

      final lineas = String.fromCharCodes(bytes)
          .split('\r\n')
          .where((l) => l.isNotEmpty)
          .toList();
      expect(lineas.length, 2);
      expect(lineas[1].length, 500);
      expect(lineas[1].substring(0, 1), '2');
      expect(lineas[1].substring(1, 4), '349');
    });
  });

  test('acumula 3 facturas mismo operador + clave en 1 registro tipo 2', () {
    final service = Mod349Service();

    Factura factura(String id, double subtotal) => Factura(
          id: id,
          empresaId: 'e1',
          numeroFactura: id,
          tipo: TipoFactura.venta_directa,
          estado: EstadoFactura.pagada,
          clienteNombre: 'Cliente UE',
          datosFiscales: const DatosFiscales(
            nifIvaComunitario: 'DE123456789',
            esIntracomunitario: true,
            razonSocial: 'Cliente UE GmbH',
            pais: 'Alemania',
          ),
          lineas: const [
            LineaFactura(
              descripcion: 'Producto',
              precioUnitario: 1,
              cantidad: 1,
              porcentajeIva: 0,
            ),
          ],
          subtotal: subtotal,
          totalIva: 0,
          total: subtotal,
          historial: const [],
          fechaEmision: DateTime(2026, 2, 10),
        );

    final ops = service.calcularOperadoresPeriodo(
      [factura('F1', 100), factura('F2', 200), factura('F3', 300)],
      const [],
      '1T',
      2026,
    );

    expect(ops.length, 1);
    expect(ops.first.codigoPaisNif, 'DE');
    expect(ops.first.numeroNif, '123456789');
    expect(ops.first.claveOperacion.codigo, 'E');
    expect(ops.first.baseImponible, 600);
  });
}

