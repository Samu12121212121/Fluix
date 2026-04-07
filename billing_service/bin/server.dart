// bin/server.dart
// Punto de entrada del microservicio de facturación automática.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'package:billing_service/database/postgres_database.dart';
import 'package:billing_service/repositories/business_config_repository.dart';
import 'package:billing_service/repositories/consent_repository.dart';
import 'package:billing_service/repositories/invoice_repository.dart';
import 'package:billing_service/services/logger.dart';
import 'package:billing_service/services/notification_service.dart';
import 'package:billing_service/services/payments/core/client_resolver.dart';
import 'package:billing_service/services/payments/core/health_monitor.dart';
import 'package:billing_service/services/payments/core/idempotency_repository.dart';
import 'package:billing_service/services/payments/core/invoice_emitter.dart';
import 'package:billing_service/services/payments/core/invoice_factory.dart';
import 'package:billing_service/services/payments/core/invoice_series_repository.dart';
import 'package:billing_service/services/payments/core/payment_processor.dart';
import 'package:billing_service/services/payments/core/retry_queue.dart';
import 'package:billing_service/services/payments/core/tax_calculator.dart';
import 'package:billing_service/services/payments/providers/psd2/banks/bbva_adapter.dart';
import 'package:billing_service/services/payments/providers/psd2/banks/caixabank_adapter.dart';
import 'package:billing_service/services/payments/providers/psd2/banks/santander_adapter.dart';
import 'package:billing_service/services/payments/providers/psd2/circuit_breaker.dart';
import 'package:billing_service/services/payments/providers/psd2/psd2_auth_service.dart';
import 'package:billing_service/services/payments/providers/psd2/psd2_consent_manager.dart';
import 'package:billing_service/services/payments/providers/psd2/psd2_polling_service.dart' as psd2;
import 'package:billing_service/services/payments/providers/redsys/redsys_provider.dart';
import 'package:billing_service/services/payments/providers/stripe/stripe_provider.dart';
import 'package:billing_service/services/payments/registry/provider_registry.dart';
import 'package:billing_service/services/verifactu_service.dart';

// ────────────────────────────────────────────────────────────────────────────
// BOOTSTRAP
// ────────────────────────────────────────────────────────────────────────────

late PostgresDatabase        db;
late ProviderRegistry        providerRegistry;
late PaymentProcessor        paymentProcessor;
late RetryQueue              retryQueue;
late HealthMonitor           healthMonitor;
late psd2.Psd2PollingService      psd2PollingService;
late Psd2ConsentManager      psd2ConsentManager;
late NotificationService     notifications;

Future<void> main() async {
  // ── Configuración desde variables de entorno ──────────────────────────────
  final dbUrl     = Platform.environment['DATABASE_URL'] ?? '';
  final port      = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  if (dbUrl.isEmpty) {
    stderr.writeln('❌ DATABASE_URL no configurado. Abortando.');
    exit(1);
  }

  // ── Base de datos ─────────────────────────────────────────────────────────
  logger.info('Conectando a PostgreSQL...');
  db = await PostgresDatabase.fromUrl(dbUrl);
  logger.info('✅ BD conectada');

  // ── Servicios de soporte ──────────────────────────────────────────────────
  notifications       = NotificationService.fromEnv();
  final verifactu     = VerifactuService.fromEnv();
  final configRepo    = BusinessConfigRepository(db);
  final invoiceRepo   = InvoiceRepository(db);
  final consentRepo   = ConsentRepository(db);
  final idempotency   = IdempotencyRepository(db);
  final taxCalc       = TaxCalculator(configRepo);
  final seriesRepo    = InvoiceSeriesRepository(db, configRepo);
  final clientRes     = ClientResolver(db);
  final factory       = InvoiceFactory(seriesRepo, taxCalc, configRepo);
  final emitter       = InvoiceEmitter(notifications: notifications);

  // ── Payment Processor ─────────────────────────────────────────────────────
  paymentProcessor = PaymentProcessor(
    idempotency:    idempotency,
    clientResolver: clientRes,
    invoiceFactory: factory,
    verifactu:      verifactu,
    emitter:        emitter,
    invoiceRepo:    invoiceRepo,
  );

  // ── Cola de reintentos ─────────────────────────────────────────────────────
  retryQueue = RetryQueue(
    db:            db,
    processor:     paymentProcessor,
    notifications: notifications,
  );

  // ── Proveedores de pago ───────────────────────────────────────────────────
  providerRegistry = ProviderRegistry();

  final stripeSecret  = Platform.environment['STRIPE_WEBHOOK_SECRET'] ?? '';
  final redsysKey     = Platform.environment['REDSYS_MERCHANT_KEY'] ?? '';

  if (stripeSecret.isNotEmpty) {
    providerRegistry.register(StripeProvider(webhookSecret: stripeSecret));
    logger.info('✅ Proveedor Stripe registrado');
  }
  if (redsysKey.isNotEmpty) {
    providerRegistry.register(RedsysProvider(merchantKey: redsysKey));
    logger.info('✅ Proveedor Redsys registrado');
  }

  // ── PSD2 ──────────────────────────────────────────────────────────────────
  final psd2Auth = Psd2AuthService();
  final banks    = [CaixaBankAdapter(), SantanderAdapter(), BBVAAdapter()];
  for (final bank in banks) psd2Auth.registerBank(bank);

  psd2ConsentManager = Psd2ConsentManager(
    repo:          consentRepo,
    auth:          psd2Auth,
    notifications: notifications,
  );

  psd2PollingService = psd2.Psd2PollingService(
    processor:   (event) async { await retryQueue.enqueue(event); },
    consentRepo: consentRepo,
  );
  for (final bank in banks) {
    if (Platform.environment['PSD2_${bank.bankId.toUpperCase()}_CLIENT_ID'] != null) {
      psd2PollingService.registerBank(bank);
      logger.info('✅ Banco PSD2 registrado: ${bank.displayName}');
    }
  }

  // ── Health Monitor ────────────────────────────────────────────────────────
  healthMonitor = HealthMonitor(
    db:            db,
    notifications: notifications,
    breakers:      psd2PollingService.breakers,
  );

  // ── Scheduler ────────────────────────────────────────────────────────────
  _startScheduler();

  // ── HTTP Server ───────────────────────────────────────────────────────────
  final app = _buildRouter();
  final pipeline = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  final server = await io.serve(pipeline, InternetAddress.anyIPv4, port);
  logger.info('🚀 Servidor Facturación Automática en http://localhost:$port');
}

// ────────────────────────────────────────────────────────────────────────────
// ROUTER
// ────────────────────────────────────────────────────────────────────────────

Router _buildRouter() {
  final router = Router();

  // ── Webhooks (validación por firma del proveedor) ─────────────────────────
  router.post('/webhooks/stripe',  _handleStripeWebhook);
  router.post('/webhooks/redsys',  _handleRedsysNotification);

  // ── PSD2 OAuth2 callback ──────────────────────────────────────────────────
  router.get('/psd2/callback', _handlePsd2Callback);

  // ── Pagos ─────────────────────────────────────────────────────────────────
  router.get('/payments/recent',     _getRecentPayments);
  router.post('/payments/<id>/retry', _retryPayment);

  // ── Administración ────────────────────────────────────────────────────────
  router.get('/admin/dead-letter', _getDeadLetter);
  router.get('/admin/health',      _getHealth);

  // ── Sistema ───────────────────────────────────────────────────────────────
  router.get('/health',    _getHealth);
  router.get('/status',    _getStatus);
  router.get('/providers', _getProviders);

  return router;
}

// ────────────────────────────────────────────────────────────────────────────
// HANDLERS
// ────────────────────────────────────────────────────────────────────────────

Future<Response> _handleStripeWebhook(Request req) async {
  final rawBody = await req.readAsString();
  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(rawBody) as Map<String, dynamic>;
  } catch (_) {
    return Response(400, body: 'Invalid JSON');
  }

  final headers = {
    ...req.headers.map((k, v) => MapEntry(k, v)),
    '_raw_body': rawBody,
  };

  final provider = providerRegistry.getById('stripe');
  if (provider == null) {
    return Response(503, body: 'Stripe provider not configured');
  }

  final isValid = await provider.validateSignature(payload, headers);
  if (!isValid) {
    logger.warn('[Stripe] Firma inválida — rechazado');
    return Response(400, body: 'Invalid signature');
  }

  final event = await provider.processEvent(payload, headers);
  if (event != null) {
    await retryQueue.enqueue(event);
    logger.info('[Stripe] Evento encolado: ${event.eventId}');
  }

  // Responder a Stripe en < 30s
  return Response.ok('OK');
}

Future<Response> _handleRedsysNotification(Request req) async {
  final body   = await req.readAsString();
  final params = Uri.splitQueryString(body);

  final payload = <String, dynamic>{
    'Ds_SignatureVersion':   params['Ds_SignatureVersion'],
    'Ds_MerchantParameters': params['Ds_MerchantParameters'],
    'Ds_Signature':          params['Ds_Signature'],
  };

  final provider = providerRegistry.getById('redsys');
  if (provider == null) return Response(503, body: 'KO');

  final isValid = await provider.validateSignature(payload, {});
  if (!isValid) {
    logger.warn('[Redsys] Firma inválida — rechazado');
    return Response(400, body: 'KO');
  }

  final event = await provider.processEvent(payload, {});
  if (event != null) await retryQueue.enqueue(event);

  return Response.ok('OK');
}

Future<Response> _handlePsd2Callback(Request req) async {
  final params = req.requestedUri.queryParameters;
  final code   = params['code'];
  final bankId = params['state']; // bankId se pasa como state

  if (code == null || bankId == null) {
    return Response(400, body: 'Parámetros inválidos');
  }

  await psd2ConsentManager.renewConsent(
    bankId:            bankId,
    authorizationCode: code,
  );
  return Response.ok(
    '<html><body>✅ Conexión bancaria renovada. Puedes cerrar esta ventana.</body></html>',
    headers: {'Content-Type': 'text/html'},
  );
}

Future<Response> _getRecentPayments(Request req) async {
  final invoices = await db.queryMany(
    'SELECT id, serie, numero, tipo_verifactu, importe_total, '
    'proveedor_pago, fecha_expedicion FROM invoices '
    'ORDER BY fecha_expedicion DESC LIMIT 50',
  );
  return _json({'invoices': invoices});
}

Future<Response> _retryPayment(Request req, String id) async {
  await retryQueue.manualRetry(id);
  return _json({'ok': true, 'event_id': id});
}

Future<Response> _getDeadLetter(Request req) async {
  final rows = await retryQueue.getDeadLetter();
  return _json({'dead_letter': rows, 'count': rows.length});
}

Future<Response> _getHealth(Request req) async {
  final checks = await healthMonitor.runChecks();
  final hasCritical = checks.any((c) => c.severity == Severity.critical);
  return Response(
    hasCritical ? 503 : 200,
    body: jsonEncode({'checks': checks.map((c) => c.toJson()).toList()}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _getStatus(Request req) async => _json({
  'status':  'running',
  'version': '1.0.0',
  'time':    DateTime.now().toIso8601String(),
});

Future<Response> _getProviders(Request req) async =>
    _json(providerRegistry.toJson());

// ────────────────────────────────────────────────────────────────────────────
// SCHEDULER
// ────────────────────────────────────────────────────────────────────────────

void _startScheduler() {
  // Cola de reintentos — cada minuto
  Timer.periodic(const Duration(minutes: 1), (_) async {
    try { await retryQueue.processQueue(); } catch (e) {
      logger.error('[Scheduler] Error procesando cola: $e');
    }
  });

  // Polling PSD2 — cada 20 minutos
  Timer.periodic(const Duration(minutes: 20), (_) async {
    try { await psd2PollingService.pollAll(); } catch (e) {
      logger.error('[Scheduler] Error polling PSD2: $e');
    }
  });

  // Health monitor — cada hora
  Timer.periodic(const Duration(hours: 1), (_) async {
    try { await healthMonitor.runChecks(); } catch (e) {
      logger.error('[Scheduler] Error health check: $e');
    }
  });

  // Verificar consentimientos PSD2 — diariamente
  Timer.periodic(const Duration(hours: 24), (_) async {
    try { await psd2ConsentManager.checkAllConsents(); } catch (e) {
      logger.error('[Scheduler] Error verificando consentimientos: $e');
    }
  });

  // Limpiar locks huérfanos — cada hora
  Timer.periodic(const Duration(hours: 1), (_) async {
    try {
      final n = await db.execute('''
        UPDATE payment_processing_log
        SET    status = 'failed',
               error_message = 'Lock huérfano — timeout 10min',
               updated_at    = NOW()
        WHERE  status    = 'processing'
          AND  locked_at < NOW() - INTERVAL '10 minutes'
      ''');
      if (n > 0) logger.warn('[Scheduler] Limpiados $n locks huérfanos');
    } catch (e) {
      logger.error('[Scheduler] Error limpiando locks: $e');
    }
  });

  logger.info('⏱ Scheduler iniciado (retry:1min, psd2:20min, health:1h, consents:24h)');
}

// ────────────────────────────────────────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────────────────────────────────────────

Response _json(Map<String, dynamic> data, {int statusCode = 200}) => Response(
  statusCode,
  body:    jsonEncode(data),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

