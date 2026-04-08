import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/validador_fiscal_integral.dart';

void main() {
  group('ValidadorFiscalIntegral', () {
    final empresaValida = const EmpresaConfig(
      nif: 'B76543214',
      razonSocial: 'Empresa Test SL',
      domicilioFiscal: 'Calle Test 123',
      codigoPostal: '28001',
      municipio: 'Madrid',
      provincia: 'Madrid',
    );

    test(
      'R4 — Rechaza factura sin NIF del destinatario en operación B2B',
      () {
        final factura = Factura(
          id: 'f1',
          empresaId: 'e1',
          numeroFactura: 'FAC-2026-0001',
          tipo: TipoFactura.venta_directa,
          estado: EstadoFactura.pendiente,
          clienteNombre: 'Cliente SL',
          datosFiscales: null, // SIN NIF
          lineas: const [
            LineaFactura(
              descripcion: 'Producto',
              precioUnitario: 1000,
              cantidad: 1,
              porcentajeIva: 21,
            ),
          ],
          subtotal: 1000,
          totalIva: 210,
          total: 1210,
          historial: const [],
          fechaEmision: DateTime(2026, 1, 15),
        );

        final resultado = ValidadorFiscalIntegral.validarFacturaCompleta(
          factura,
          empresaValida,
          [factura],
        );

        expect(resultado.esValido, isFalse);
        expect(
          resultado.errores.any((e) => e.contains('R4-NIF-DESTINATARIO')),
          isTrue,
        );
      },
    );

    test(
      'R4 — Acepta factura con NIF válido del emisor y destinatario',
      () {
        final factura = Factura(
          id: 'f1',
          empresaId: 'e1',
          numeroFactura: 'FAC-2026-0001',
          tipo: TipoFactura.venta_directa,
          estado: EstadoFactura.pendiente,
          clienteNombre: 'Cliente SL',
          datosFiscales: const DatosFiscales(
            nif: 'A12345678',
            razonSocial: 'Cliente Test SL',
          ),
          lineas: const [
            LineaFactura(
              descripcion: 'Producto',
              precioUnitario: 1000,
              cantidad: 1,
              porcentajeIva: 21,
            ),
          ],
          subtotal: 1000,
          totalIva: 210,
          total: 1210,
          historial: const [],
          fechaEmision: DateTime(2026, 1, 15),
        );

        final resultado = ValidadorFiscalIntegral.validarFacturaCompleta(
          factura,
          empresaValida,
          [factura],
        );

        expect(resultado.esValido, isTrue);
        expect(resultado.errores, isEmpty);
      },
    );

    test('R8 — Detecta desglose de IVA cuando hay múltiples tipos', () {
      final factura = Factura(
        id: 'f1',
        empresaId: 'e1',
        numeroFactura: 'FAC-2026-0001',
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pendiente,
        clienteNombre: 'Cliente SL',
        datosFiscales: const DatosFiscales(nif: 'A12345678'),
        lineas: const [
          LineaFactura(
            descripcion: 'Producto A',
            precioUnitario: 500,
            cantidad: 1,
            porcentajeIva: 21,
          ),
          LineaFactura(
            descripcion: 'Producto B',
            precioUnitario: 500,
            cantidad: 1,
            porcentajeIva: 10,
          ),
        ],
        subtotal: 1000,
        totalIva: 155,
        total: 1155,
        historial: const [],
        fechaEmision: DateTime(2026, 1, 15),
      );

      final resultado = ValidadorFiscalIntegral.validarFacturaCompleta(
        factura,
        empresaValida,
        [factura],
      );

      expect(
        resultado.advertencias.any((a) => a.contains('R8-DESGLOSE-IVA')),
        isTrue,
      );
    });

    test('R1 — Detecta hueco en correlatividad de facturas', () {
      final f1 = Factura(
        id: 'f1',
        empresaId: 'e1',
        numeroFactura: 'FAC-2026-0001',
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pagada,
        clienteNombre: 'Cliente',
        lineas: const [],
        subtotal: 0,
        totalIva: 0,
        total: 0,
        historial: const [],
        fechaEmision: DateTime(2026, 1, 1),
      );

      final f2 = Factura(
        id: 'f2',
        empresaId: 'e1',
        numeroFactura: 'FAC-2026-0003', // Falta 0002
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pagada,
        clienteNombre: 'Cliente',
        lineas: const [],
        subtotal: 0,
        totalIva: 0,
        total: 0,
        historial: const [],
        fechaEmision: DateTime(2026, 1, 2),
      );

      final errores = ValidadorFiscalIntegral.validarCorrelatividad([f1, f2]);

      expect(errores.isNotEmpty, isTrue);
      expect(
        errores.any((e) => e.contains('R1-CORRELATIVIDAD')),
        isTrue,
      );
    });

    test('R9 — Detecta series mixtas (normales + rectificativas)', () {
      final normal = Factura(
        id: 'f1',
        empresaId: 'e1',
        numeroFactura: 'FAC-2026-0001',
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pagada,
        clienteNombre: 'Cliente',
        lineas: const [],
        subtotal: 0,
        totalIva: 0,
        total: 0,
        historial: const [],
        fechaEmision: DateTime(2026, 1, 1),
      );

      final rectificativa = Factura(
        id: 'f2',
        empresaId: 'e1',
        numeroFactura: 'FAC-2026-R0001',
        tipo: TipoFactura.rectificativa,
        estado: EstadoFactura.pagada,
        clienteNombre: 'Cliente',
        lineas: const [],
        subtotal: 0,
        totalIva: 0,
        total: 0,
        historial: const [],
        fechaEmision: DateTime(2026, 1, 2),
        facturaOriginalId: 'f1',
      );

      final advertencias =
          ValidadorFiscalIntegral.validarSeriesPorTipo([normal, rectificativa]);

      expect(
        advertencias.any((a) => a.contains('R9-SERIES-RECTIFICATIVAS')),
        isTrue,
      );
    });

    test('Construye mensaje de error con formato estándar', () {
      final mensaje = ValidadorFiscalIntegral.construirMensajeError(
        regla: 'R4-NIF-VALIDO',
        descripcion: 'NIF del emisor inválido',
        articulo: 'Art. 6.1 RD 1619/2012',
        solucion: 'Verificar que el NIF sea correcto y esté bien formado',
      );

      expect(mensaje.contains('R4-NIF-VALIDO'), isTrue);
      expect(mensaje.contains('ADVERTENCIA DE INCUMPLIMIENTO FISCAL'), isTrue);
      expect(mensaje.contains('150.000 EUR'), isTrue);
    });
  });
}

