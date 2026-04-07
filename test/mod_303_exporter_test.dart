import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/exportadores_aeat/mod_303_exporter.dart';

void main() {
  test('MOD303: cada registro tiene exactamente 500 caracteres', () async {
    final emitida = Factura(
      id: 'f1',
      empresaId: 'e1',
      numeroFactura: 'FAC-2026-0001',
      tipo: TipoFactura.venta_directa,
      estado: EstadoFactura.pendiente,
      clienteNombre: 'Cliente Test',
      lineas: const [
        LineaFactura(
          descripcion: 'Servicio',
          precioUnitario: 1000,
          cantidad: 1,
          porcentajeIva: 21,
        ),
      ],
      subtotal: 1000,
      totalIva: 210,
      total: 1210,
      historial: const [],
      fechaEmision: DateTime(2026, 3, 15),
    );

    final recibida = FacturaRecibida(
      id: 'r1',
      empresaId: 'e1',
      numeroFactura: 'INV-2026-001',
      fechaEmision: DateTime(2026, 3, 2),
      fechaRecepcion: DateTime(2026, 3, 4),
      nifProveedor: 'B12345678',
      nombreProveedor: 'Proveedor Test',
      baseImponible: 500,
      porcentajeIva: 21,
      importeIva: 105,
      ivaDeducible: true,
      totalConImpuestos: 605,
      fechaCreacion: DateTime(2026, 3, 4),
    );

    final datos = DatosMod303(
      facturasEmitidas: [emitida],
      facturasRecibidas: [recibida],
      nifEmpresa: 'B76543210',
      ejercicio: '2026',
      periodo: '01',
    );

    final txt = await Mod303Exporter().exportar(datos);

    // Debe terminar en CRLF y contener 2 registros (tipo 1 y tipo 2)
    expect(txt.endsWith('\r\n'), isTrue);

    final lineas = txt.split('\r\n').where((l) => l.isNotEmpty).toList();
    expect(lineas.length, 2);

    final tipo1 = lineas[0];
    final tipo2 = lineas[1];

    expect(tipo1.length, 500);
    expect(tipo2.length, 500);

    // Posiciones obligatorias cabecera (1-based)
    expect(tipo1.substring(0, 1), '1'); // pos 1
    expect(tipo1.substring(1, 4), '303'); // pos 2-4
    expect(tipo1.substring(7, 16), 'B76543210'); // pos 8-16 (NIF efectivo)
    expect(tipo1.substring(24, 28), '2026'); // pos 25-28
    expect(tipo1.substring(28, 30), '01'); // pos 29-30

    // Posiciones obligatorias detalle (1-based)
    expect(tipo2.substring(0, 1), '2'); // pos 1
    expect(tipo2.substring(1, 4), '303'); // pos 2-4
    expect(tipo2.substring(7, 16), 'B76543210'); // pos 8-16 (NIF efectivo)
    expect(tipo2.substring(24, 28), '2026'); // pos 25-28
    expect(tipo2.substring(28, 30), '01'); // pos 29-30

    // Importes en céntimos y con ceros a la izquierda
    // Base general: 1000.00€ -> 100000 céntimos, campo 31-45 (15)
    expect(tipo2.substring(30, 45), '000000000100000');

    // Cuota repercutida total: 210.00€ -> 21000 céntimos, campo 46-60 (15)
    expect(tipo2.substring(45, 60), '000000000021000');

    // Base soportada deducible: 500.00€ -> 50000 céntimos, campo 61-75 (15)
    expect(tipo2.substring(60, 75), '000000000050000');

    // Cuota soportada deducible: 105.00€ -> 10500 céntimos, campo 76-90 (15)
    expect(tipo2.substring(75, 90), '000000000010500');

    // Resultado: 210 - 105 = +105€; signo en pos 91, valor en 92-106
    expect(tipo2.substring(90, 91), '+');
    expect(tipo2.substring(91, 106), '000000000010500');
  });
}

