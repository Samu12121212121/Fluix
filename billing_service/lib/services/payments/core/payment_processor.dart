// lib/services/payments/core/payment_processor.dart
// Orquestador central: idempotencia → cliente → factura → verifactu → emitir.
// ACTUALIZADO PARA MULTI-TENANT (Prompt 8).

import '../../../models/invoice.dart';
import '../../../models/processing_result.dart';
import '../../../models/tenant_business_config.dart';
import '../../../repositories/invoice_repository.dart';
import '../../../repositories/tenant_business_config_repository.dart';
import '../../../services/logger.dart';
import '../../../services/verifactu_service.dart';
import '../interfaces/payment_event.dart';
import 'client_resolver.dart';
import 'idempotency_repository.dart';
import 'invoice_emitter.dart';
import 'invoice_factory.dart';

class PaymentProcessor {
  final IdempotencyRepository            _idempotency;
  final ClientResolver                   _clientResolver;
  final InvoiceFactory                   _invoiceFactory;
  final VerifactuService                 _verifactu;
  final InvoiceEmitter                   _emitter;
  final InvoiceRepository                _invoiceRepo;
  final TenantBusinessConfigRepository?  _configRepo;  // NUEVO: multi-tenant

  PaymentProcessor({
    required IdempotencyRepository idempotency,
    required ClientResolver        clientResolver,
    required InvoiceFactory        invoiceFactory,
    required VerifactuService      verifactu,
    required InvoiceEmitter        emitter,
    required InvoiceRepository     invoiceRepo,
    TenantBusinessConfigRepository? configRepo,
  })  : _idempotency    = idempotency,
        _clientResolver = clientResolver,
        _invoiceFactory = invoiceFactory,
        _verifactu      = verifactu,
        _emitter        = emitter,
        _invoiceRepo    = invoiceRepo,
        _configRepo     = configRepo;

  /// Procesa un evento de pago para un tenant específico.
  /// [tenantId] identifica la empresa propietaria del pago.
  Future<ProcessingResult> process(PaymentEvent? event, [String? tenantId]) async {
    if (event == null) return ProcessingResult.skipped('Evento nulo');

    // Verificar configuración del tenant si se proporciona
    TenantBusinessConfig? tenantConfig;
    if (tenantId != null && _configRepo != null) {
      tenantConfig = await _configRepo!.get(tenantId);
      if (tenantConfig == null) {
        return ProcessingResult.error(
          eventId: event.eventId,
          error:   'Configuración fiscal no encontrada para tenant $tenantId',
        );
      }
    }

    // Idempotencia incluye tenantId para evitar colisiones entre tenants
    // (dos tenants podrían recibir el mismo eventId de Stripe)
    final lockKey = tenantId != null
        ? '$tenantId:${event.eventId}'
        : event.eventId;

    final lock = await _idempotency.tryAcquire(lockKey, event.providerId);

    return switch (lock) {
      Acquired()         => await _execute(event, tenantId, tenantConfig),
      AlreadyCompleted() => ProcessingResult.duplicate(eventId: event.eventId),
      BeingProcessed()   => ProcessingResult.deferred(
                               reason: 'Otro worker está procesando este evento'),
      PreviouslyFailed() => ProcessingResult.error(
                               eventId: event.eventId,
                               error:   'Fallido previamente — usar POST /payments/${event.eventId}/retry'),
      Duplicate()        => ProcessingResult.duplicate(eventId: event.eventId),
      IdempotencyError(:final message) => ProcessingResult.error(
                               eventId: event.eventId,
                               error:   message),
    };
  }

  Future<ProcessingResult> _execute(
    PaymentEvent event,
    String? tenantId,
    TenantBusinessConfig? tenantConfig,
  ) async {
    final lockKey = tenantId != null
        ? '$tenantId:${event.eventId}'
        : event.eventId;

    try {
      // 2. Resolver cliente B2B / B2C
      final customer = await _clientResolver.resolve(event);

      // 3. Construir factura
      Invoice invoice;
      if (event.status == PaymentStatus.refunded) {
        final original = await _invoiceRepo.findByExternalReference(
          event.externalReference,
          tenantId: tenantId,
        );
        if (original == null) {
          throw ProcessingException(
            'Factura original no encontrada para reembolso ${event.externalReference}',
          );
        }
        invoice = await _invoiceFactory.buildRectificativa(event, original);
      } else {
        invoice = await _invoiceFactory.build(event, customer);
      }

      // 4. Registro Verifactu (usa datos del tenant si están disponibles)
      final registro = await _verifactu.createRegistroAlta(
        nifEmisor:               tenantConfig?.emisorNif ?? invoice.emisorNif,
        numSerie:                invoice.serie,
        numFactura:              invoice.numero,
        fechaExpedicion:         invoice.fechaExpedicion,
        tipoFactura:             invoice.tipoVerifactu,
        importeTotal:            invoice.importeTotal,
        cuotaTotal:              invoice.cuotaIva,
        descripcion:             invoice.descripcion,
        destinatarioNif:         invoice.destinatarioNif,
        claveRegimen:            invoice.claveRegimen,
        calificacionOperacion:   invoice.calificacionOperacion,
        tipoRectificativa:       invoice.tipoRectificativa,
        facturaRectificadaSerie: invoice.facturaRectificadaSerie,
        facturaRectificadaNumero: invoice.facturaRectificadaNumero,
      );

      // 5. Guardar factura con hash Verifactu y tenantId
      final saved = invoice.copyWith(
        tenantId:          tenantId,
        registroVerifactu: registro.xmlContent,
        hashVerifactu:     registro.hash,
      );
      final persisted = await _invoiceRepo.save(saved);

      // 6. Emitir (PDF + email)
      await _emitter.emit(persisted, registro, customer);

      // 7. Marcar como completado
      await _idempotency.markCompleted(lockKey, persisted.id);

      final prefix = tenantId != null ? '[$tenantId] ' : '';
      logger.info('${prefix}Factura generada: ${persisted.serie}-${persisted.numero}');

      return ProcessingResult.success(invoice: persisted);

    } catch (e, st) {
      await _idempotency.markFailed(lockKey, e.toString());
      final prefix = tenantId != null ? '[$tenantId] ' : '';
      logger.error('${prefix}Error procesando ${event.eventId}: $e', st);
      return ProcessingResult.error(
        eventId: event.eventId,
        error:   e.toString(),
      );
    }
  }
}



