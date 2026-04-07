import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/verifactu/xml_payload_verifactu_builder.dart';

void main() {
  test('builder genera payload fiscal sin SOAP Envelope', () {
    final factura = Factura(
      id: 'f1',
      empresaId: 'e1',
      numeroFactura: 'FAC-2026-0001',
      tipo: TipoFactura.venta_directa,
      estado: EstadoFactura.pagada,
      clienteNombre: 'Cliente Test',
      datosFiscales: const DatosFiscales(nif: 'B12345678'),
      lineas: const [
        LineaFactura(
          descripcion: 'Servicio',
          precioUnitario: 100,
          cantidad: 1,
          porcentajeIva: 21,
        ),
      ],
      subtotal: 100,
      totalIva: 21,
      total: 121,
      historial: const [],
      fechaEmision: DateTime(2026, 1, 15),
    );

    final xml = XmlPayloadVerifactuBuilder.construirSuministroSingleAltaLegacy(
      factura: factura,
      nifEmisor: 'B76543210',
      nombreEmisor: 'Empresa Test SL',
      tipoFactura: 'F1',
      claveRegimen: '01',
      hashRegistro: 'a' * 64,
      hashAnterior: '',
      fechaExpedicion: '2026-01-15',
      fechaHoraRegistro: '2026-01-15T10:00:00+01:00',
      nombreSoftware: 'PlaneaG',
      idSoftware: 'PG-001',
      versionSoftware: '1.0.0',
      nifFabricante: 'B00000000',
      esSoloVerifactu: true,
    );

    expect(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), isTrue);
    expect(xml.contains('<vf:SuministroLRFacturasEmitidas'), isTrue);
    expect(xml.contains('<soapenv:Envelope'), isFalse);
    expect(xml.contains('<vf:RegistroAlta>'), isTrue);
    expect(xml.contains('<vf:IDVersionSif>1.0</vf:IDVersionSif>'), isTrue);
  });
}

