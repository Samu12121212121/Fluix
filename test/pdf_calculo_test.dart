import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/pdf_configuracion.dart';

// ── Tests del módulo PDF ────────────────────────────────────────────────────
// Cubre: Factura.calcularTotales, validaciones NIF/IBAN, ConfigTipoDocPdf defaults
// No requiere Firebase: son tests unitarios puros.

void main() {
  group('Factura.calcularTotales — caso base', () {
    test('sin descuento: 1 línea 21%', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Test', precioUnitario: 100, cantidad: 1)],
      );
      expect(r['subtotal'],               closeTo(100.0, 0.01));
      expect(r['importe_descuento_global'],closeTo(0.0,   0.01));
      expect(r['total_iva'],              closeTo(21.0,  0.01));
      expect(r['total'],                  closeTo(121.0, 0.01));
    });

    test('P-2026-0008 — 300 € −10 % → base 270, IVA 56,70, total 326,70', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Servicio', precioUnitario: 300, cantidad: 1)],
        descuentoGlobal: 10,
      );
      expect(r['subtotal'],               closeTo(300.0, 0.01));
      expect(r['importe_descuento_global'],closeTo(30.0,  0.01));
      expect(r['total_iva'],              closeTo(56.70, 0.01)); // 270 * 21%
      expect(r['total'],                  closeTo(326.70,0.01)); // 270 + 56,70
    });

    test('descuento 100 % → todo cero', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Gratis', precioUnitario: 500, cantidad: 1)],
        descuentoGlobal: 100,
      );
      expect(r['total_iva'], closeTo(0.0, 0.001));
      expect(r['total'],     closeTo(0.0, 0.001));
    });

    test('precio cero → no genera IVA', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Gratuito', precioUnitario: 0, cantidad: 5)],
      );
      expect(r['total'], closeTo(0.0, 0.001));
    });

    test('múltiples tipos de IVA en el mismo documento', () {
      final r = Factura.calcularTotales(
        lineas: [
          LineaFactura(descripcion: 'Servicio 21%',  precioUnitario: 100, cantidad: 1, porcentajeIva: 21),
          LineaFactura(descripcion: 'Hostelería 10%', precioUnitario: 200, cantidad: 1, porcentajeIva: 10),
        ],
      );
      // IVA = 100*0.21 + 200*0.10 = 21 + 20 = 41
      expect(r['total_iva'], closeTo(41.0, 0.01));
      expect(r['total'],     closeTo(341.0, 0.01)); // 300 + 41
    });

    test('multi-IVA con descuento global 10 %', () {
      final r = Factura.calcularTotales(
        lineas: [
          LineaFactura(descripcion: '21%', precioUnitario: 100, cantidad: 1, porcentajeIva: 21),
          LineaFactura(descripcion: '10%', precioUnitario: 100, cantidad: 1, porcentajeIva: 10),
        ],
        descuentoGlobal: 10,
      );
      // subtotal=200, descuento=20, base=180
      // IVA = 90*0.21 + 90*0.10 = 18.90 + 9.00 = 27.90
      expect(r['subtotal'],               closeTo(200.0, 0.01));
      expect(r['importe_descuento_global'],closeTo(20.0,  0.01));
      expect(r['total_iva'],              closeTo(27.9,  0.02));
      expect(r['total'],                  closeTo(207.9, 0.02));
    });

    test('IRPF 15 % se resta del total', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Freelance', precioUnitario: 1000, cantidad: 1)],
        porcentajeIrpf: 15,
      );
      // base=1000, IVA=210, IRPF=150, total=1000+210-150=1060
      expect(r['retencion_irpf'], closeTo(150.0, 0.01));
      expect(r['total'],          closeTo(1060.0, 0.01));
    });

    test('rectificativa: importes negativos no cambian la lógica', () {
      final r = Factura.calcularTotales(
        lineas: [LineaFactura(descripcion: 'Devolución', precioUnitario: -100, cantidad: 1)],
      );
      expect(r['subtotal'], closeTo(-100.0, 0.01));
      expect(r['total_iva'],closeTo(-21.0,  0.01));
      expect(r['total'],    closeTo(-121.0, 0.01));
    });

    test('descuento por línea se aplica antes del global', () {
      final r = Factura.calcularTotales(
        lineas: [
          // Precio bruto 200, descuento línea 50% → subtotalSinIva = 100
          LineaFactura(descripcion: 'Test', precioUnitario: 200, cantidad: 1,
              porcentajeIva: 21, descuento: 50),
        ],
        descuentoGlobal: 10,  // sobre el subtotal neto (100)
      );
      // subtotal = 100, descuento global = 10, base = 90, IVA = 90*0.21 = 18.90
      expect(r['subtotal'],               closeTo(100.0, 0.01));
      expect(r['importe_descuento_global'],closeTo(10.0,  0.01));
      expect(r['total_iva'],              closeTo(18.9,  0.02));
    });
  });

  group('validarNifEs', () {
    test('CIF válido', () {
      expect(validarNifEs('B12345679'), isTrue);
      expect(validarNifEs('A28207289'), isTrue);
    });
    test('DNI válido', () {
      expect(validarNifEs('12345678Z'), isTrue);
    });
    test('NIE válido', () {
      expect(validarNifEs('X1234567L'), isTrue);
    });
    test('NIF vacío → false', () {
      expect(validarNifEs(''), isFalse);
    });
    test('NIF con formato incorrecto → false', () {
      expect(validarNifEs('12345'), isFalse);
      expect(validarNifEs('ABCDEFGH'), isFalse);
    });
  });

  group('validarIban', () {
    test('IBAN español válido', () {
      expect(validarIban('ES9121000418450200051332'), isTrue);
      expect(validarIban('ES91 2100 0418 4502 0005 1332'), isTrue); // con espacios
    });
    test('IBAN inválido (dígito de control erróneo)', () {
      expect(validarIban('ES0021000418450200051332'), isFalse);
    });
    test('IBAN vacío → false', () {
      expect(validarIban(''), isFalse);
    });
  });

  group('formatearIban', () {
    test('formatea en grupos de 4', () {
      expect(formatearIban('ES9121000418450200051332'), 'ES91 2100 0418 4502 0005 1332');
    });
    test('limpia espacios existentes antes de formatear', () {
      expect(formatearIban('ES91  210004184502'), 'ES91 2100 0418 4502');
    });
  });

  group('PdfConfiguracion.domicilioCompleto', () {
    test('compone la dirección correctamente', () {
      final cfg = PdfConfiguracion(
        razonSocial: 'Test SL', cif: 'B12345678',
        tipoVia: 'Avenida', nombreVia: 'Beleña', numero: '14', pisoPorta: '2.º B',
        codigoPostal: '19005', localidad: 'Guadalajara', provincia: 'Guadalajara',
        configPorTipo: {}, updatedAt: DateTime(2026),
      );
      expect(cfg.domicilioLinea1, 'Avenida, Beleña, 14, 2.º B');
      expect(cfg.domicilioLinea2, '19005 Guadalajara');
    });

    test('sin piso/porta no añade coma extra', () {
      final cfg = PdfConfiguracion(
        razonSocial: 'Test SL', cif: 'B12345678',
        tipoVia: 'Calle', nombreVia: 'Mayor', numero: '5',
        codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
        configPorTipo: {}, updatedAt: DateTime(2026),
      );
      expect(cfg.domicilioLinea1, 'Calle, Mayor, 5');
    });
  });

  group('PdfConfiguracion.datosEmisorCompletos', () {
    test('detecta campos faltantes', () {
      final cfg = PdfConfiguracion(
        razonSocial: '', cif: '',
        tipoVia: 'Calle', nombreVia: '', numero: '',
        codigoPostal: '', localidad: '', provincia: '',
        configPorTipo: {}, updatedAt: DateTime(2026),
      );
      expect(cfg.datosEmisorCompletos, isFalse);
      expect(cfg.camposFaltantes, containsAll(['Razón social', 'CIF/NIF']));
    });

    test('datos completos', () {
      final cfg = PdfConfiguracion(
        razonSocial: 'Fluix Tech SL', cif: 'B12345678',
        tipoVia: 'Calle', nombreVia: 'Mayor', numero: '1',
        codigoPostal: '19001', localidad: 'Guadalajara', provincia: 'Guadalajara',
        configPorTipo: {}, updatedAt: DateTime(2026),
      );
      expect(cfg.datosEmisorCompletos, isTrue);
      expect(cfg.camposFaltantes, isEmpty);
    });
  });

  group('ConfigTipoDocPdf defaults', () {
    test('factura: mostrarPago = true, mostrarVerifactu = true', () {
      expect(ConfigTipoDocPdf.factura.mostrarPago, isTrue);
      expect(ConfigTipoDocPdf.factura.mostrarVerifactu, isTrue);
      expect(ConfigTipoDocPdf.factura.mostrarFirma, isFalse);
    });

    test('albarán: sin pago, sin Verifactu, con firma', () {
      expect(ConfigTipoDocPdf.albaran.mostrarPago, isFalse);
      expect(ConfigTipoDocPdf.albaran.mostrarVerifactu, isFalse);
      expect(ConfigTipoDocPdf.albaran.mostrarFirma, isTrue);
      expect(ConfigTipoDocPdf.albaran.etiquetaCliente, 'Entregar a');
    });

    test('presupuesto: sin pago, sin Verifactu, "Válido hasta" implícito', () {
      expect(ConfigTipoDocPdf.presupuesto.mostrarPago, isFalse);
      expect(ConfigTipoDocPdf.presupuesto.mostrarVerifactu, isFalse);
      expect(ConfigTipoDocPdf.presupuesto.diasVencimiento, greaterThan(0));
    });

    test('presupuesto: pie legal NO contiene "RD 1619/2012" como texto de factura', () {
      final pie = ConfigTipoDocPdf.presupuesto.pieLegal.toLowerCase();
      expect(pie, contains('no constituye factura'));
    });

    test('albarán: pie legal NO contiene "RD 1619/2012" como texto de factura', () {
      final pie = ConfigTipoDocPdf.albaran.pieLegal.toLowerCase();
      expect(pie, isNot(contains('factura emitida')));
      expect(pie, isNot(contains('rd 1619')));
    });
  });

  group('PdfConfiguracion.cfgTipo — fallback a defaults', () {
    final cfg = PdfConfiguracion(
      razonSocial: 'Test', cif: 'B12345678',
      tipoVia: 'Calle', nombreVia: 'Test', numero: '1',
      codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
      configPorTipo: {},  // vacío → usa defaults
      updatedAt: DateTime(2026),
    );

    test('sin config guardada usa defaults de albaran', () {
      final alb = cfg.cfgTipo('albaran');
      expect(alb.etiquetaCliente, 'Entregar a');
      expect(alb.mostrarFirma, isTrue);
    });

    test('config guardada sobreescribe el default', () {
      const personalizada = ConfigTipoDocPdf(
        titulo: 'Albarán Personalizado',
        etiquetaCliente: 'Destinatario',
        diasVencimiento: 0,
        pieLegal: 'Firme aquí',
        mostrarPago: false, mostrarColumnaIva: false,
        mostrarImportes: true, mostrarFirma: true,
        mostrarVerifactu: false, tipoIvaDefecto: 21.0,
      );
      final cfgConPersonalizada = PdfConfiguracion(
        razonSocial: 'Test', cif: 'B12345678',
        tipoVia: 'Calle', nombreVia: 'Test', numero: '1',
        codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
        configPorTipo: {'albaran': personalizada},
        updatedAt: DateTime(2026),
      );
      expect(cfgConPersonalizada.cfgTipo('albaran').etiquetaCliente, 'Destinatario');
    });
  });
}
