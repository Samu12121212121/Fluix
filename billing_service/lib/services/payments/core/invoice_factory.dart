// lib/services/payments/core/invoice_factory.dart
// Construye facturas F1 (completa B2B), F2 (simplificada B2C) y R4 (rectificativa).
// Art. 6, 7 y 15 del RD 1619/2012.

import '../../../models/invoice.dart';
import '../../../repositories/business_config_repository.dart';
import '../interfaces/payment_event.dart';
import 'invoice_series_repository.dart';
import 'tax_calculator.dart';

class ProcessingException implements Exception {
  final String message;
  const ProcessingException(this.message);
  @override String toString() => 'ProcessingException: $message';
}

class InvoiceFactory {
  final InvoiceSeriesRepository  _series;
  final TaxCalculator            _tax;
  final BusinessConfigRepository _config;

  InvoiceFactory(this._series, this._tax, this._config);

  Future<Invoice> build(PaymentEvent event, CustomerInfo? customer) async {
    final cfg         = await _config.get();
    final productCode = (event.rawPayload['metadata']?['product_code'] as String?) ??
                        cfg.defaultProductCode;

    final tax = await _tax.calculate(
      grossAmount:   event.amount,
      productCode:   productCode,
      customer:      customer,
      isGrossAmount: true,
    );

    final isB2B = customer?.type == CustomerType.b2b && customer?.nif != null;
    final type  = isB2B ? InvoiceType.complete : InvoiceType.simplified;
    final serie = await _series.getNextNumber(type: type);

    return isB2B
        ? _buildF1(event, customer!, serie, tax)
        : _buildF2(event, customer, serie, tax);
  }

  // ── F1 — Factura Completa — Art. 6 RD 1619/2012 ───────────────────────────
  Invoice _buildF1(
    PaymentEvent   e,
    CustomerInfo   c,
    InvoiceSeries  s,
    TaxBreakdown   t,
  ) => Invoice(
    serie:                 s.serie,
    numero:                s.numero,
    tipo:                  InvoiceType.complete,
    tipoVerifactu:         'F1',
    emisorNif:             s.emisorNif,
    emisorNombre:          s.emisorNombre,
    destinatarioNif:       c.nif!,
    destinatarioNombre:    c.name ?? '',
    destinatarioDireccion: c.address ?? '',
    fechaExpedicion:       DateTime.now(),
    fechaOperacion:        e.timestamp,
    baseImponible:         t.baseImponible,
    tipoIva:               t.vatRate.percentage,
    cuotaIva:              t.cuotaIva,
    retencionIrpf:         t.retencionIrpf,
    recargo:               t.recargo,
    importeTotal:          t.importeTotal,
    descripcion:           _desc(e),
    claveRegimen:          '01',
    calificacionOperacion: 'S1',
    referenciaExterna:     e.externalReference,
    proveedorPago:         e.providerId,
  );

  // ── F2 — Factura Simplificada — Art. 7 RD 1619/2012 ───────────────────────
  Invoice _buildF2(
    PaymentEvent   e,
    CustomerInfo?  c,
    InvoiceSeries  s,
    TaxBreakdown   t,
  ) => Invoice(
    serie:                 s.serie,
    numero:                s.numero,
    tipo:                  InvoiceType.simplified,
    tipoVerifactu:         'F2',
    emisorNif:             s.emisorNif,
    emisorNombre:          s.emisorNombre,
    destinatarioEmail:     c?.email,
    fechaExpedicion:       DateTime.now(),
    fechaOperacion:        e.timestamp,
    baseImponible:         t.baseImponible,
    tipoIva:               t.vatRate.percentage,
    cuotaIva:              t.cuotaIva,
    retencionIrpf:         t.retencionIrpf,
    recargo:               t.recargo,
    importeTotal:          t.importeTotal,
    descripcion:           _desc(e),
    claveRegimen:          '01',
    calificacionOperacion: 'S1',
    referenciaExterna:     e.externalReference,
    proveedorPago:         e.providerId,
  );

  // ── R4 — Factura Rectificativa — Art. 15 RD 1619/2012 ─────────────────────
  Future<Invoice> buildRectificativa(
    PaymentEvent refund,
    Invoice      original,
  ) async {
    final serie = await _series.getNextNumber(type: InvoiceType.rectificativa);
    return Invoice(
      serie:                    serie.serie,
      numero:                   serie.numero,
      tipo:                     InvoiceType.rectificativa,
      tipoVerifactu:            'R4',
      tipoRectificativa:        'I',
      facturaRectificadaSerie:  original.serie,
      facturaRectificadaNumero: original.numero,
      facturaRectificadaFecha:  original.fechaExpedicion,
      emisorNif:                original.emisorNif,
      emisorNombre:             original.emisorNombre,
      destinatarioNif:          original.destinatarioNif,
      destinatarioNombre:       original.destinatarioNombre,
      fechaExpedicion:          DateTime.now(),
      fechaOperacion:           refund.timestamp,
      baseImponible:            -original.baseImponible,
      tipoIva:                  original.tipoIva,
      cuotaIva:                 -original.cuotaIva,
      retencionIrpf:            -original.retencionIrpf,
      recargo:                  -original.recargo,
      importeTotal:             -refund.amount,
      descripcion:              'Devolución — ${original.serie}-${original.numero}',
      claveRegimen:             '01',
      calificacionOperacion:    'S1',
      referenciaExterna:        refund.externalReference,
      proveedorPago:            refund.providerId,
    );
  }

  String _desc(PaymentEvent e) =>
      'Servicios — ${e.providerId} — ${e.externalReference ?? e.eventId}';
}

