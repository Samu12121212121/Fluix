import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_347_exporter.dart';

/// Tests unitarios para Mod347Exporter — Modelo 347 AEAT
///
/// Art. 33 RD 1065/2007: Umbral = 3.005,06€ (IVA incluido)
/// Declaración anual de operaciones con terceros.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Factura _factura({
    required String id,
    required String clienteNif,
    required String clienteNombre,
    required double subtotal,
    required double iva,
    required double total,
    EstadoFactura estado = EstadoFactura.pendiente,
  }) {
    return Factura(
      id: id,
      empresaId: 'emp1',
      numeroFactura: 'FAC-2026-$id',
      tipo: TipoFactura.venta_directa,
      estado: estado,
      clienteNombre: clienteNombre,
      datosFiscales: DatosFiscales(nif: clienteNif, razonSocial: clienteNombre),
      lineas: const [
        LineaFactura(descripcion: 'Servicio', precioUnitario: 1000, cantidad: 1, porcentajeIva: 21),
      ],
      subtotal: subtotal,
      totalIva: iva,
      total: total,
      historial: const [],
      fechaEmision: DateTime(2026, 6, 15),
    );
  }

  FacturaRecibida _facRecibida({
    required String id,
    required String nifProveedor,
    required String nombreProveedor,
    required double base,
    required double iva,
    required double total,
    EstadoFacturaRecibida estado = EstadoFacturaRecibida.registrada,
  }) {
    return FacturaRecibida(
      id: id,
      empresaId: 'emp1',
      numeroFactura: 'REC-2026-$id',
      fechaEmision: DateTime(2026, 6, 15),
      fechaRecepcion: DateTime(2026, 6, 16),
      nifProveedor: nifProveedor,
      nombreProveedor: nombreProveedor,
      baseImponible: base,
      porcentajeIva: 21,
      importeIva: iva,
      ivaDeducible: true,
      totalConImpuestos: total,
      estado: estado,
      fechaCreacion: DateTime(2026, 6, 16),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UMBRAL 3.005,06€
  // ═══════════════════════════════════════════════════════════════════════════

  group('Umbral declaración MOD 347', () {
    test('Cliente con total 3.005,05€ (1 céntimo bajo umbral) → NO declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(
            id: '1', clienteNif: 'B12345678', clienteNombre: 'Cliente A',
            subtotal: 2483.51, iva: 521.54, total: 3005.05,
          ),
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta, isEmpty);
      expect(resumen.numDeclaraciones, 0);
    });

    test('Cliente con total 3.005,06€ (exacto umbral) → SÍ declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(
            id: '1', clienteNif: 'B12345678', clienteNombre: 'Cliente A',
            subtotal: 2483.52, iva: 521.54, total: 3005.06,
          ),
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta.length, 1);
      expect(resumen.operacionesVenta[0].nifTercero, 'B12345678');
    });

    test('Cliente con total 10.000€ (muy por encima) → declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(
            id: '1', clienteNif: 'A87654321', clienteNombre: 'Gran Cliente',
            subtotal: 8264.46, iva: 1735.54, total: 10000,
          ),
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta.length, 1);
      expect(resumen.totalVentas, closeTo(10000, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AGRUPACIÓN POR TERCERO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Agrupación de facturas por NIF', () {
    test('Múltiples facturas al mismo cliente se suman', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B12345678', clienteNombre: 'C1',
              subtotal: 1000, iva: 210, total: 1210),
          _factura(id: '2', clienteNif: 'B12345678', clienteNombre: 'C1',
              subtotal: 1000, iva: 210, total: 1210),
          _factura(id: '3', clienteNif: 'B12345678', clienteNombre: 'C1',
              subtotal: 1000, iva: 210, total: 1210),
        ],
        facturasRecibidas: [],
      );

      // 3 × 1.210 = 3.630 > 3.005,06 → declarable
      expect(resumen.operacionesVenta.length, 1);
      expect(resumen.operacionesVenta[0].totalAnual, closeTo(3630, 0.01));
      expect(resumen.operacionesVenta[0].numOperaciones, 3);
    });

    test('Clientes distintos se separan', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C1',
              subtotal: 3000, iva: 630, total: 3630),
          _factura(id: '2', clienteNif: 'B22222222', clienteNombre: 'C2',
              subtotal: 3000, iva: 630, total: 3630),
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta.length, 2);
      expect(resumen.numDeclaraciones, 2);
    });

    test('Un cliente bajo umbral y otro encima: solo declara el de encima', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'Pequeño',
              subtotal: 1000, iva: 210, total: 1210), // < umbral
          _factura(id: '2', clienteNif: 'B22222222', clienteNombre: 'Grande',
              subtotal: 4000, iva: 840, total: 4840), // > umbral
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta.length, 1);
      expect(resumen.operacionesVenta[0].nifTercero, 'B22222222');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPRAS (FACTURAS RECIBIDAS)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Compras — facturas recibidas', () {
    test('Proveedor sobre umbral → operación de compra', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'Proveedor X',
              base: 3000, iva: 630, total: 3630),
        ],
      );

      expect(resumen.operacionesCompra.length, 1);
      expect(resumen.operacionesCompra[0].tipo, TipoOperacion347.compra);
      expect(resumen.totalCompras, closeTo(3630, 0.01));
    });

    test('Proveedor bajo umbral → no declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'P Pequeño',
              base: 1000, iva: 210, total: 1210),
        ],
      );

      expect(resumen.operacionesCompra, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCLUSIONES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Exclusiones del cálculo', () {
    test('Factura anulada NO se incluye', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B12345678', clienteNombre: 'C1',
              subtotal: 5000, iva: 1050, total: 6050,
              estado: EstadoFactura.anulada),
        ],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta, isEmpty);
    });

    test('Factura sin NIF de cliente NO se incluye', () {
      final factura = Factura(
        id: 'sin-nif',
        empresaId: 'emp1',
        numeroFactura: 'FAC-2026-SN',
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pendiente,
        clienteNombre: 'Consumidor Final',
        datosFiscales: null, // SIN NIF
        lineas: const [
          LineaFactura(descripcion: 'Producto', precioUnitario: 5000, cantidad: 1, porcentajeIva: 21),
        ],
        subtotal: 5000,
        totalIva: 1050,
        total: 6050,
        historial: const [],
        fechaEmision: DateTime(2026, 6, 15),
      );

      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [factura],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta, isEmpty);
    });

    test('Factura recibida rechazada NO se incluye', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'Prov',
              base: 5000, iva: 1050, total: 6050,
              estado: EstadoFacturaRecibida.rechazada),
        ],
      );

      expect(resumen.operacionesCompra, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DE FICHERO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Generación fichero MOD 347', () {
    test('Fichero con 2 operaciones tiene 3 líneas (1 declarante + 2 ops)', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C1',
              subtotal: 3000, iva: 630, total: 3630),
          _factura(id: '2', clienteNif: 'B22222222', clienteNombre: 'C2',
              subtotal: 4000, iva: 840, total: 4840),
        ],
        facturasRecibidas: [],
      );

      final fichero = Mod347Exporter.generarFichero(
        nifDeclarante: 'B76543210',
        nombreDeclarante: 'FLUIXTECH SL',
        resumen: resumen,
      );

      final lineas = fichero.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lineas.length, 3); // 1 declarante + 2 operaciones

      // Tipo 1 = declarante
      expect(lineas[0].startsWith('1'), isTrue);
      expect(lineas[0].contains('347'), isTrue);

      // Tipo 2 = operaciones
      expect(lineas[1].startsWith('2'), isTrue);
      expect(lineas[2].startsWith('2'), isTrue);
    });

    test('Sin operaciones declarables → fichero solo con declarante', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B12345678', clienteNombre: 'Pequeño',
              subtotal: 500, iva: 105, total: 605),
        ],
        facturasRecibidas: [],
      );

      final fichero = Mod347Exporter.generarFichero(
        nifDeclarante: 'B76543210',
        nombreDeclarante: 'FLUIXTECH SL',
        resumen: resumen,
      );

      final lineas = fichero.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lineas.length, 1); // solo declarante
    });

    test('NIF del declarante aparece en registro tipo 1', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );

      final fichero = Mod347Exporter.generarFichero(
        nifDeclarante: 'B76543210',
        nombreDeclarante: 'EMPRESA TEST SL',
        resumen: resumen,
      );

      expect(fichero.contains('B76543210'), isTrue);
      expect(fichero.contains('EMPRESA TEST SL'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO REAL: BAR EN GUADALAJARA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso real: Bar Guadalajara — MOD 347 anual', () {
    test('Proveedor de bebidas >3.005€ y panadería <3.005€', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          // Distribuidora bebidas: 12 facturas × 400€ = 4.800€
          ...[for (int i = 1; i <= 12; i++)
            _facRecibida(id: 'beb$i', nifProveedor: 'A11111111',
                nombreProveedor: 'Distribuidora Bebidas SL',
                base: 330.58, iva: 69.42, total: 400)],
          // Panadería: 12 facturas × 150€ = 1.800€
          ...[for (int i = 1; i <= 12; i++)
            _facRecibida(id: 'pan$i', nifProveedor: 'B22222222',
                nombreProveedor: 'Panadería López',
                base: 123.97, iva: 26.03, total: 150)],
        ],
      );

      // Solo la distribuidora supera el umbral
      expect(resumen.operacionesCompra.length, 1);
      expect(resumen.operacionesCompra[0].nifTercero, 'A11111111');
      expect(resumen.operacionesCompra[0].totalAnual, closeTo(4800, 0.01));
      expect(resumen.operacionesCompra[0].numOperaciones, 12);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('Sin facturas → resumen vacío', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [],
      );

      expect(resumen.operacionesVenta, isEmpty);
      expect(resumen.operacionesCompra, isEmpty);
      expect(resumen.totalVentas, 0);
      expect(resumen.totalCompras, 0);
      expect(resumen.numDeclaraciones, 0);
    });

    test('Factura recibida con NIF vacío se ignora', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: '', nombreProveedor: 'Sin NIF',
              base: 10000, iva: 2100, total: 12100),
        ],
      );

      expect(resumen.operacionesCompra, isEmpty);
    });

    test('Ejercicio se graba correctamente', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2025,
        facturasEmitidas: [],
        facturasRecibidas: [],
      );

      expect(resumen.anio, 2025);
    });
  });
}

