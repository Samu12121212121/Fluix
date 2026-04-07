import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_303_exporter.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_347_exporter.dart';

void main() {
  test('MOD303 usa el NIF configurado y nunca el placeholder A12345678', () async {
    final emitida = Factura(
      id: '1',
      empresaId: 'e1',
      numeroFactura: 'FAC-1',
      tipo: TipoFactura.venta_directa,
      estado: EstadoFactura.pendiente,
      clienteNombre: 'Cliente',
      lineas: const [
        LineaFactura(descripcion: 'Servicio', precioUnitario: 100, cantidad: 1, porcentajeIva: 21),
      ],
      subtotal: 100,
      totalIva: 21,
      total: 121,
      historial: const [],
      fechaEmision: DateTime(2026, 1, 10),
    );

    final recibida = FacturaRecibida(
      id: '2',
      empresaId: 'e1',
      numeroFactura: 'R-1',
      fechaEmision: DateTime(2026, 1, 11),
      fechaRecepcion: DateTime(2026, 1, 11),
      nifProveedor: 'B11111111',
      nombreProveedor: 'Proveedor',
      baseImponible: 50,
      porcentajeIva: 21,
      importeIva: 10.5,
      ivaDeducible: true,
      totalConImpuestos: 60.5,
      fechaCreacion: DateTime(2026, 1, 11),
    );

    final txt = await Mod303Exporter().exportar(
      const DatosMod303(
        facturasEmitidas: [],
        facturasRecibidas: [],
        nifEmpresa: 'B76543210',
        ejercicio: '2026',
        periodo: '01',
      ).copyWithForTest([emitida], [recibida]),
    );

    expect(txt.contains('A12345678'), isFalse);
    expect(txt.contains('B76543210'), isTrue);
  });

  test('MOD347 usa el NIF configurado y nunca el placeholder A12345678', () {
    final resumen = const Resumen347(
      anio: 2026,
      operacionesVenta: [
        Operacion347(
          nifTercero: 'B22222222',
          nombreTercero: 'Cliente 347',
          tipo: TipoOperacion347.venta,
          baseImponibleAnual: 3000,
          ivaAnual: 630,
          totalAnual: 3630,
          numOperaciones: 2,
          superaUmbral: true,
        ),
      ],
      operacionesCompra: [],
      totalVentas: 3630,
      totalCompras: 0,
      numDeclaraciones: 1,
    );

    final txt = Mod347Exporter.generarFichero(
      nifDeclarante: 'B76543210',
      nombreDeclarante: 'Empresa Real SL',
      resumen: resumen,
    );

    expect(txt.contains('A12345678'), isFalse);
    expect(txt.contains('B76543210'), isTrue);
  });
}

extension on DatosMod303 {
  DatosMod303 copyWithForTest(
    List<Factura> emitidas,
    List<FacturaRecibida> recibidas,
  ) {
    return DatosMod303(
      facturasEmitidas: emitidas,
      facturasRecibidas: recibidas,
      nifEmpresa: nifEmpresa,
      ejercicio: ejercicio,
      periodo: periodo,
    );
  }
}

