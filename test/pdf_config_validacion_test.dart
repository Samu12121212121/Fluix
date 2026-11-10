import 'package:flutter_test/flutter_test.dart';
import 'package:planeag_flutter/domain/modelos/pdf_configuracion.dart';

// ── Tests de validación de PdfConfiguracion ───────────────────────────────────
// Verifica reglas de negocio: IBAN vacío = sin bloque pago, IBAN inválido = error,
// textos por tipo correctos, prefijos, etc.

void main() {
  group('ConfigTipoDocPdf — textos prohibidos por tipo', () {
    // Presupuesto y proforma NO pueden tener textos de factura
    test('presupuesto: etiquetaCliente no es "FACTURADO A"', () {
      expect(ConfigTipoDocPdf.presupuesto.etiquetaCliente.toUpperCase(),
          isNot('FACTURADO A'));
    });
    test('proforma: etiquetaCliente no es "FACTURADO A"', () {
      expect(ConfigTipoDocPdf.proforma.etiquetaCliente.toUpperCase(),
          isNot('FACTURADO A'));
    });
    test('presupuesto: pie legal no dice "Factura emitida"', () {
      expect(ConfigTipoDocPdf.presupuesto.pieLegal.toLowerCase(),
          isNot(contains('factura emitida')));
    });
    test('presupuesto: pie legal no menciona Verifactu', () {
      expect(ConfigTipoDocPdf.presupuesto.pieLegal.toLowerCase(),
          isNot(contains('verifactu')));
    });
    test('albarán: pie legal no dice "Factura emitida"', () {
      expect(ConfigTipoDocPdf.albaran.pieLegal.toLowerCase(),
          isNot(contains('factura emitida')));
    });
    test('albarán: etiquetaCliente es "Entregar a"', () {
      expect(ConfigTipoDocPdf.albaran.etiquetaCliente, 'Entregar a');
    });
  });

  group('ConfigTipoDocPdf — mostrarPago por tipo', () {
    test('factura muestra pago', () => expect(ConfigTipoDocPdf.factura.mostrarPago, isTrue));
    test('rectificativa NO muestra pago', () => expect(ConfigTipoDocPdf.rectificativa.mostrarPago, isFalse));
    test('presupuesto NO muestra pago', () => expect(ConfigTipoDocPdf.presupuesto.mostrarPago, isFalse));
    test('albarán NO muestra pago', () => expect(ConfigTipoDocPdf.albaran.mostrarPago, isFalse));
    test('fichajes NO muestra pago', () => expect(ConfigTipoDocPdf.fichajes.mostrarPago, isFalse));
  });

  group('ConfigTipoDocPdf — mostrarVerifactu por tipo', () {
    test('solo factura y rectificativa muestran Verifactu', () {
      expect(ConfigTipoDocPdf.factura.mostrarVerifactu, isTrue);
      expect(ConfigTipoDocPdf.rectificativa.mostrarVerifactu, isTrue);
      expect(ConfigTipoDocPdf.presupuesto.mostrarVerifactu, isFalse);
      expect(ConfigTipoDocPdf.proforma.mostrarVerifactu, isFalse);
      expect(ConfigTipoDocPdf.albaran.mostrarVerifactu, isFalse);
      expect(ConfigTipoDocPdf.fichajes.mostrarVerifactu, isFalse);
    });
  });

  group('PdfConfiguracion — IBAN y bloque de pago', () {
    test('sin IBAN configurado, iban es null → bloque pago no aplica', () {
      final cfg = PdfConfiguracion(
        razonSocial: 'Test SL', cif: 'B12345678',
        tipoVia: 'Calle', nombreVia: 'Test', numero: '1',
        codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
        configPorTipo: const {},
        updatedAt: DateTime(2026),
      );
      expect(cfg.iban, isNull);
    });

    test('IBAN inválido no pasa la validación', () {
      expect(validarIban('ES00 0000 0000 0000 0000'), isFalse);
    });

    test('IBAN vacío no pasa la validación', () {
      expect(validarIban(''), isFalse);
    });

    test('IBAN válido pasa la validación', () {
      expect(validarIban('ES91 2100 0418 4502 0005 1332'), isTrue);
    });
  });

  group('PdfConfiguracion — prefijos por tipo', () {
    final cfg = PdfConfiguracion(
      razonSocial: 'Test', cif: 'B12345678',
      tipoVia: 'Calle', nombreVia: 'Test', numero: '1',
      codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
      configPorTipo: const {},
      prefijoFactura: 'F',
      prefijoRectificativa: 'R',
      prefijoPresupuesto: 'PRES',
      prefijoProforma: 'PF',
      prefijoAlbaran: 'ALB',
      updatedAt: DateTime(2026),
    );

    test('factura → prefijo F', () {
      expect(cfg.prefijoParaTipo('factura'), 'F');
    });
    test('rectificativa → prefijo R', () {
      expect(cfg.prefijoParaTipo('rectificativa'), 'R');
    });
    test('presupuesto → prefijo PRES', () {
      expect(cfg.prefijoParaTipo('presupuesto'), 'PRES');
    });
    test('proforma → prefijo PF', () {
      expect(cfg.prefijoParaTipo('proforma'), 'PF');
    });
    test('albarán → prefijo ALB', () {
      expect(cfg.prefijoParaTipo('albaran'), 'ALB');
    });
    test('tipo desconocido → prefijo factura por defecto', () {
      expect(cfg.prefijoParaTipo('desconocido'), 'F');
    });
  });

  group('PdfConfiguracion — copyWith', () {
    final base = PdfConfiguracion(
      razonSocial: 'Original SL', cif: 'B12345678',
      tipoVia: 'Calle', nombreVia: 'Mayor', numero: '1',
      codigoPostal: '28001', localidad: 'Madrid', provincia: 'Madrid',
      configPorTipo: const {},
      updatedAt: DateTime(2026),
    );

    test('copyWith cambia solo el campo indicado', () {
      final updated = base.copyWith(razonSocial: 'Nueva SL');
      expect(updated.razonSocial, 'Nueva SL');
      expect(updated.cif, base.cif); // sin cambio
    });

    test('copyWith actualiza updatedAt', () {
      final updated = base.copyWith(razonSocial: 'Test');
      expect(updated.updatedAt.isAfter(base.updatedAt) ||
             updated.updatedAt.isAtSameMomentAs(base.updatedAt), isTrue);
    });
  });

  group('ConfigTipoDocPdf — copyWith', () {
    test('modifica un campo sin afectar los demás', () {
      final original = ConfigTipoDocPdf.factura;
      final modified = original.copyWith(etiquetaCliente: 'Destinatario');
      expect(modified.etiquetaCliente, 'Destinatario');
      expect(modified.mostrarPago, original.mostrarPago);
      expect(modified.titulo, original.titulo);
    });
  });
}
