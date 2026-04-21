import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_347_exporter.dart';

/// Tests unitarios para Mod347Exporter — Modelo 347 AEAT
/// Art. 33 RD 1065/2007: Umbral = 3.005,06€ (IVA incluido)
void main() {
  // ── HELPERS ─────────────────────────────────────────────────────────────────

  Factura _factura({
    required String id,
    required String clienteNif,
    required String clienteNombre,
    required double subtotal,
    required double iva,
    required double total,
    EstadoFactura estado = EstadoFactura.pendiente,
    DateTime? fechaEmision,
    bool esIntracomunitario = false,
  }) {
    return Factura(
      id: id,
      empresaId: 'emp1',
      numeroFactura: 'FAC-2026-$id',
      tipo: TipoFactura.venta_directa,
      estado: estado,
      clienteNombre: clienteNombre,
      datosFiscales: DatosFiscales(
        nif: clienteNif,
        razonSocial: clienteNombre,
        esIntracomunitario: esIntracomunitario,
      ),
      lineas: const [
        LineaFactura(descripcion: 'Servicio', precioUnitario: 1000, cantidad: 1, porcentajeIva: 21),
      ],
      subtotal: subtotal,
      totalIva: iva,
      total: total,
      historial: const [],
      fechaEmision: fechaEmision ?? DateTime(2026, 6, 15),
    );
  }

  FacturaRecibida _facRecibida({
    required String id,
    required String nifProveedor,
    required String nombreProveedor,
    required double base,
    required double iva,
    required double total,
    EstadoFacturaRecibida estado = EstadoFacturaRecibida.recibida,
    DateTime? fechaRecepcion,
    bool esArrendamiento = false,
    bool esIntracomunitario = false,
  }) {
    return FacturaRecibida(
      id: id,
      empresaId: 'emp1',
      numeroFactura: 'REC-2026-$id',
      fechaEmision: DateTime(2026, 6, 15),
      fechaRecepcion: fechaRecepcion ?? DateTime(2026, 6, 16),
      nifProveedor: nifProveedor,
      nombreProveedor: nombreProveedor,
      baseImponible: base,
      porcentajeIva: 21,
      importeIva: iva,
      ivaDeducible: true,
      totalConImpuestos: total,
      estado: estado,
      fechaCreacion: DateTime(2026, 6, 16),
      esArrendamiento: esArrendamiento,
      esIntracomunitario: esIntracomunitario,
    );
  }

  String _ficheroTexto({
    required Resumen347 resumen,
    String nif = 'B76543210',
    String nombre = 'FLUIXTECH SL',
  }) =>
      Mod347Exporter.generarFicheroTexto(
        nifDeclarante: nif,
        nombreDeclarante: nombre,
        resumen: resumen,
      );

  // ── LONGITUD DE REGISTROS ────────────────────────────────────────────────

  group('Longitud registros == 500 chars (AEAT)', () {
    test('Registro declarante tiene exactamente 500 chars', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 1);
      expect(lineas[0].length, 500, reason: 'Registro tipo 1 debe tener 500 chars');
    });

    test('Registro declarado tiene exactamente 500 chars', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [
          Operacion347(
            nifTercero: 'B12345678',
            nombreTercero: 'CLIENTE TEST SL',
            clave: ClaveOperacion347.entregas,
            totalAnual: 5000.00,
            trimestres: const ImportesTrimestral(t2: 5000.00),
            superaUmbral: true,
          ),
        ],
        operacionesCompra: [],
        totalVentas: 5000.00,
        totalCompras: 0,
        numDeclaraciones: 1,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 2);
      expect(lineas[1].length, 500, reason: 'Registro tipo 2 declarado debe tener 500 chars');
    });

    test('Registro inmueble tiene exactamente 500 chars', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        inmuebles: [
          const InmuebleArrendado(
            nifArrendatario: 'B12345678',
            nombreArrendatario: 'ARRENDATARIO SL',
            importeAnual: 12000.00,
            situacion: SituacionInmueble.conRefCatastral,
            refCatastral: '1234567AB12345A0001LT',
            municipio: 'Guadalajara',
            codigoProvinciaINE: '19',
          ),
        ],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // 1 declarante + 1 inmueble = 2 líneas
      expect(lineas.length, 2);
      expect(lineas[1].length, 500, reason: 'Registro tipo 2 inmueble (hoja I) debe tener 500 chars');
      expect(lineas[1][75], 'I', reason: 'Pos 76 debe ser I para inmueble');
    });
  });

  // ── CLAVES DE OPERACIÓN ───────────────────────────────────────────────────

  group('Claves de operación correctas (A/B/C según BOE)', () {
    test('Ventas usan clave B (entregas)', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'Cliente',
              subtotal: 4000, iva: 840, total: 4840),
        ],
        facturasRecibidas: [],
      );
      expect(resumen.operacionesVenta.first.clave, ClaveOperacion347.entregas);
      expect(resumen.operacionesVenta.first.clave.codigo, 'B');
    });

    test('Compras usan clave A (adquisiciones)', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'Proveedor',
              base: 3000, iva: 630, total: 3630),
        ],
      );
      expect(resumen.operacionesCompra.first.clave, ClaveOperacion347.adquisiciones);
      expect(resumen.operacionesCompra.first.clave.codigo, 'A');
    });

    test('Clave en fichero pos 82 es A para compras', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'Prov',
              base: 3000, iva: 630, total: 3630),
        ],
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // pos 82 = índice 81 (0-based)
      expect(lineas[1][81], 'A', reason: 'Clave compra debe ser A en pos 82');
    });

    test('Clave en fichero pos 82 es B para ventas', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C',
              subtotal: 4000, iva: 840, total: 4840),
        ],
        facturasRecibidas: [],
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas[1][81], 'B', reason: 'Clave venta debe ser B en pos 82');
    });
  });

  // ── IMPORTES EN EUROS CON DECIMAL (no céntimos) ───────────────────────────

  group('Importes en EUROS con decimal explícito (no céntimos)', () {
    test('Importe 4.840,00€ → enteros 0000000004840 + decimales 00', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C',
              subtotal: 4000, iva: 840, total: 4840),
        ],
        facturasRecibidas: [],
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // pos 84-96: entera (13d), pos 97-98: decimal (2d) → índices 83-95 y 96-97
      final entera = lineas[1].substring(83, 96);
      final decimal = lineas[1].substring(96, 98);
      expect(entera, '0000000004840');
      expect(decimal, '00');
    });

    test('Importe 3.005,06€ → enteros 0000000003005 + decimales 06', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [
          Operacion347(
            nifTercero: 'B12345678',
            nombreTercero: 'CLIENTE',
            clave: ClaveOperacion347.entregas,
            totalAnual: 3005.06,
            trimestres: const ImportesTrimestral(t1: 3005.06),
            superaUmbral: true,
          ),
        ],
        operacionesCompra: [],
        totalVentas: 3005.06,
        totalCompras: 0,
        numDeclaraciones: 1,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      final entera = lineas[1].substring(83, 96);
      final decimal = lineas[1].substring(96, 98);
      expect(entera, '0000000003005');
      expect(decimal, '06');
    });
  });

  // ── DESGLOSE TRIMESTRAL ───────────────────────────────────────────────────

  group('Desglose trimestral (pos 136-263)', () {
    test('Factura de febrero va al trimestre 1T', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C',
              subtotal: 4000, iva: 840, total: 4840,
              fechaEmision: DateTime(2026, 2, 15)),
        ],
        facturasRecibidas: [],
      );
      final op = resumen.operacionesVenta.first;
      expect(op.trimestres.t1, closeTo(4840, 0.01));
      expect(op.trimestres.t2, 0);
      expect(op.trimestres.t3, 0);
      expect(op.trimestres.t4, 0);
    });

    test('Factura de octubre va al trimestre 4T', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B11111111', clienteNombre: 'C',
              subtotal: 4000, iva: 840, total: 4840,
              fechaEmision: DateTime(2026, 10, 1)),
        ],
        facturasRecibidas: [],
      );
      final op = resumen.operacionesVenta.first;
      expect(op.trimestres.t4, closeTo(4840, 0.01));
      expect(op.trimestres.t1, 0);
    });

    test('Importe 1T en fichero (pos 136-151, índice 135-150)', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [
          Operacion347(
            nifTercero: 'B12345678',
            nombreTercero: 'CLIENTE',
            clave: ClaveOperacion347.entregas,
            totalAnual: 5000.00,
            trimestres: const ImportesTrimestral(t1: 5000.00),
            superaUmbral: true,
          ),
        ],
        operacionesCompra: [],
        totalVentas: 5000.00,
        totalCompras: 0,
        numDeclaraciones: 1,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // pos 136-151 = índice 135-150
      // signo(1) + entera(13) + decimal(2) = 16 chars
      final signo1T = lineas[1][135];
      final entera1T = lineas[1].substring(136, 149);
      final decimal1T = lineas[1].substring(149, 151);
      expect(signo1T, ' ');
      expect(entera1T, '0000000005000');
      expect(decimal1T, '00');
    });
  });

  // ── NIF COMUNITARIO ───────────────────────────────────────────────────────

  group('NIF comunitario (pos 264-280)', () {
    test('Operación con NIF comunitario DE registra código país y número', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [
          Operacion347(
            nifTercero: 'DE123456789',
            nombreTercero: 'GERMAN GMBH',
            clave: ClaveOperacion347.entregas,
            totalAnual: 8000.00,
            trimestres: const ImportesTrimestral(t1: 8000.00),
            superaUmbral: true,
            codigoPaisNifComunitario: 'DE',
            numeroNifComunitario: '123456789',
          ),
        ],
        operacionesCompra: [],
        totalVentas: 8000.00,
        totalCompras: 0,
        numDeclaraciones: 1,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // pos 264-265 = índice 263-264
      final codigoPais = lineas[1].substring(263, 265);
      // pos 266-280 = índice 265-280
      final nifComunitario = lineas[1].substring(265, 280).trimRight();
      expect(codigoPais, 'DE');
      expect(nifComunitario, '123456789');
    });
  });

  // ── REGISTRO INMUEBLE ─────────────────────────────────────────────────────

  group('Registro de inmueble (hoja I)', () {
    test('Inmueble genera registro con hoja I en pos 76', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        inmuebles: [
          const InmuebleArrendado(
            nifArrendatario: 'B12345678',
            nombreArrendatario: 'ARRENDATARIO SL',
            importeAnual: 24000.00,
            situacion: SituacionInmueble.conRefCatastral,
            refCatastral: '1234567AB12345A0001LT',
            municipio: 'Guadalajara',
            codigoProvinciaINE: '19',
          ),
        ],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lineas.length, 2);
      expect(lineas[1][75], 'I');
    });

    test('Importe inmueble 24.000€ → entera 0000000024000, decimal 00', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        inmuebles: [
          const InmuebleArrendado(
            nifArrendatario: 'B12345678',
            nombreArrendatario: 'ARRENDATARIO SL',
            importeAnual: 24000.00,
          ),
        ],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(resumen: resumen);
      final lineas = fichero.split('\r\n').where((l) => l.isNotEmpty).toList();
      // pos 100-114: entera(13d)+decimal(2d) = índice 99-113 y 113-115
      final entera = lineas[1].substring(99, 112);
      final decimal = lineas[1].substring(112, 114);
      expect(entera, '0000000024000');
      expect(decimal, '00');
    });
  });

  // ── UMBRAL ────────────────────────────────────────────────────────────────

  group('Umbral declaración MOD 347', () {
    test('Total 3.005,05€ (1 céntimo bajo umbral) → NO declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B12345678', clienteNombre: 'Cliente A',
              subtotal: 2483.51, iva: 521.54, total: 3005.05),
        ],
        facturasRecibidas: [],
      );
      expect(resumen.operacionesVenta, isEmpty);
    });

    test('Total 3.005,06€ (exacto umbral) → SÍ declarable', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'B12345678', clienteNombre: 'Cliente A',
              subtotal: 2483.52, iva: 521.54, total: 3005.06),
        ],
        facturasRecibidas: [],
      );
      expect(resumen.operacionesVenta.length, 1);
    });
  });

  // ── EXCLUSIONES ───────────────────────────────────────────────────────────

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

    test('Factura intracomunitaria NO se incluye (va al 349)', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [
          _factura(id: '1', clienteNif: 'DE123456789', clienteNombre: 'German GmbH',
              subtotal: 10000, iva: 0, total: 10000,
              esIntracomunitario: true),
        ],
        facturasRecibidas: [],
      );
      expect(resumen.operacionesVenta, isEmpty);
    });

    test('Factura recibida rechazada NO se incluye', () {
      final resumen = Mod347Exporter.calcular(
        anio: 2026,
        facturasEmitidas: [],
        facturasRecibidas: [
          _facRecibida(id: '1', nifProveedor: 'A99999999', nombreProveedor: 'P',
              base: 5000, iva: 1050, total: 6050,
              estado: EstadoFacturaRecibida.rechazada),
        ],
      );
      expect(resumen.operacionesCompra, isEmpty);
    });

    test('NIF declarante nunca igual a placeholder A12345678', () {
      expect('A12345678', isNot('B76543210'));
    });
  });

  // ── ENCODING ISO-8859-1 ───────────────────────────────────────────────────

  group('Encoding ISO-8859-1', () {
    test('Ñ se convierte a N en nombre declarante', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(
        resumen: resumen,
        nombre: 'Compañía Test SL',
      );
      // La Ñ se normaliza a N y se convierte a mayúsculas
      expect(fichero.contains('COMPANIA'), isTrue);
    });

    test('Acentos se eliminan en texto', () {
      final resumen = Resumen347(
        anio: 2026,
        operacionesVenta: [],
        operacionesCompra: [],
        totalVentas: 0,
        totalCompras: 0,
        numDeclaraciones: 0,
      );
      final fichero = _ficheroTexto(
        resumen: resumen,
        nombre: 'Café Técnico SL',
      );
      expect(fichero.contains('CAFE TECNICO SL'), isTrue);
    });
  });

  // ── AGRUPACIÓN POR NIF ────────────────────────────────────────────────────

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
    });
  });
}

