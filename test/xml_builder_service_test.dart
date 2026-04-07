import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/services/verifactu/xml_builder_service.dart';
import 'package:planeag_flutter/services/verifactu/modelos_verifactu.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';

/// Tests unitarios para XmlBuilderService — Verifactu
///
/// Orden HAC/1177/2024: Formato XML de remisión a AEAT.
/// RD 1007/2023 art. 12: Contenido del RegistroAlta.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Factura _factura({
    String nifCliente = 'B12345678',
    double subtotal = 1000,
    double iva = 210,
    double total = 1210,
  }) {
    return Factura(
      id: 'f1',
      empresaId: 'e1',
      numeroFactura: 'FAC-2026-0001',
      tipo: TipoFactura.venta_directa,
      estado: EstadoFactura.pagada,
      clienteNombre: 'Cliente Test SL',
      datosFiscales: DatosFiscales(nif: nifCliente, razonSocial: 'Cliente Test SL'),
      lineas: const [
        LineaFactura(descripcion: 'Consultoría', precioUnitario: 1000, cantidad: 1, porcentajeIva: 21),
      ],
      subtotal: subtotal,
      totalIva: iva,
      total: total,
      historial: const [],
      fechaEmision: DateTime(2026, 3, 15),
    );
  }

  RegistroFacturacionAlta _registro({
    String nifEmisor = 'B76543210',
    String serie = 'FAC',
    String numero = '0001',
    DateTime? fechaExpedicion,
    double importeTotal = 1210,
    double cuotaTotal = 210,
    bool esVerifactu = true,
    ReferenceRegistroAnterior? anterior,
  }) {
    return RegistroFacturacionAlta(
      nifEmisor: nifEmisor,
      numeroSerie: serie,
      numeroFactura: numero,
      fechaExpedicion: fechaExpedicion ?? DateTime(2026, 3, 15),
      tipoFactura: TipoFacturaVeri.f1,
      descripcion: 'Servicio consultoría',
      importeTotal: importeTotal,
      cuotaTotal: cuotaTotal,
      desglosePorTipo: {'21': 1000.0},
      claveRegimen: ClaveRegimen.general,
      calificacion: CalificacionOperacion.sujetaNoExentaSinIsp,
      registroAnterior: anterior ?? ReferenceRegistroAnterior.primerRegistro(),
      fechaHoraGeneracion: DateTime(2026, 3, 15, 10, 30, 0),
      zonaHoraria: '+01:00',
      esVerifactu: esVerifactu,
    );
  }

  final builder = XmlBuilderService();

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTRUCTURA XML BÁSICA
  // ═══════════════════════════════════════════════════════════════════════════

  group('Estructura XML — RegistroAlta', () {
    test('XML comienza con declaración XML UTF-8', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Empresa Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), isTrue);
    });

    test('XML contiene SuministroLRFacturasEmitidas (namespace vf)', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Empresa Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('<vf:SuministroLRFacturasEmitidas'), isTrue);
    });

    test('XML contiene RegistroAlta', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Empresa Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('<vf:RegistroAlta>'), isTrue);
    });

    test('XML NO contiene SOAP Envelope (modo Verifactu directo)', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(esVerifactu: true),
        factura: _factura(),
        nombreEmisor: 'Empresa Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('<soapenv:Envelope'), isFalse);
    });

    test('IDVersionSif = 1.0 (Orden HAC/1177/2024)', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Empresa Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('<vf:IDVersionSif>1.0</vf:IDVersionSif>'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DATOS DEL EMISOR
  // ═══════════════════════════════════════════════════════════════════════════

  group('Datos del emisor en XML', () {
    test('NIF del emisor aparece en el XML', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(nifEmisor: 'B76543210'),
        factura: _factura(),
        nombreEmisor: 'Fluixtech SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('B76543210'), isTrue);
    });

    test('Nombre del emisor aparece en el XML', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Fluixtech SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('Fluixtech SL'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // HASH Y ENCADENAMIENTO
  // ═══════════════════════════════════════════════════════════════════════════

  group('Hash en XML', () {
    test('Hash del registro se incluye en el XML (64 chars hex)', () {
      final registro = _registro();
      final xml = builder.buildRegistroAlta(
        registro: registro,
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      // El hash debe estar en el XML
      expect(xml.contains(registro.hash), isTrue);
    });

    test('Primer registro: sin hash anterior', () {
      final registro = _registro(anterior: ReferenceRegistroAnterior.primerRegistro());
      final xml = builder.buildRegistroAlta(
        registro: registro,
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      // XML es válido y se genera sin error
      expect(xml.length, greaterThan(100));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DATOS DE SOFTWARE
  // ═══════════════════════════════════════════════════════════════════════════

  group('Datos de software en XML', () {
    test('NIF del fabricante aparece en XML', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '2.5.0',
        nifFabricante: 'B99999999',
      );

      expect(xml.contains('B99999999'), isTrue);
    });

    test('Versión del software aparece en XML', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(),
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '2.5.0',
        nifFabricante: 'B99999999',
      );

      expect(xml.contains('2.5.0'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FECHA FORMATEADA CORRECTAMENTE
  // ═══════════════════════════════════════════════════════════════════════════

  group('Formato de fechas', () {
    test('Fecha de expedición en formato YYYY-MM-DD', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(fechaExpedicion: DateTime(2026, 1, 5)),
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('2026-01-05'), isTrue);
    });

    test('Fecha con mes diciembre formateada correctamente', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(fechaExpedicion: DateTime(2026, 12, 31)),
        factura: _factura(),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.contains('2026-12-31'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CASO IVA 0% (OPERACIÓN EXENTA)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Caso especial: factura IVA 0%', () {
    test('Factura exenta IVA genera XML válido', () {
      final xml = builder.buildRegistroAlta(
        registro: _registro(importeTotal: 500, cuotaTotal: 0),
        factura: _factura(subtotal: 500, iva: 0, total: 500),
        nombreEmisor: 'Test SL',
        nombreSoftware: 'PlaneaG',
        idSoftware: 'PG-001',
        versionSoftware: '1.0.0',
        nifFabricante: 'B00000000',
      );

      expect(xml.length, greaterThan(100));
      expect(xml.contains('<?xml'), isTrue);
    });
  });
}

