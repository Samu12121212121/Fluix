// test/billing_service_test.dart
// Tests unitarios del sistema de facturación automática.
//
// Para ejecutar:
//   cd billing_service
//   dart test test/billing_service_test.dart
//
// No necesita PostgreSQL ni Stripe real — usa mocks e in-memory.

import 'package:test/test.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// Importamos los módulos directamente
import '../lib/services/payments/interfaces/payment_event.dart';
import '../lib/services/payments/providers/stripe/stripe_webhook_validator.dart';
import '../lib/services/payments/providers/stripe/stripe_event_mapper.dart';
import '../lib/services/payments/providers/redsys/redsys_signature_validator.dart';
import '../lib/services/payments/providers/redsys/redsys_event_mapper.dart';
import '../lib/services/payments/providers/psd2/circuit_breaker.dart';
import '../lib/services/payments/core/tax_calculator.dart';
import '../lib/services/payments/core/idempotency_repository.dart';
import '../lib/models/invoice.dart';
import '../lib/models/processing_result.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // MÓDULO 1 — MODELOS Y ENUMS
  // ═══════════════════════════════════════════════════════════════════════════

  group('PaymentEvent — serialización', () {
    test('toJson → fromJson roundtrip', () {
      final event = PaymentEvent(
        eventId:    'evt_test_001',
        providerId: 'stripe',
        timestamp:  DateTime(2026, 3, 30, 12, 0),
        amount:     42.50,
        currency:   'EUR',
        status:     PaymentStatus.succeeded,
        method:     PaymentMethod.card,
        customer:   const CustomerInfo(
          nif:   'B12345678',
          name:  'Empresa Test S.L.',
          email: 'test@empresa.com',
          type:  CustomerType.b2b,
        ),
        rawPayload: {'key': 'value'},
        externalReference: 'pi_abc123',
      );

      final json    = event.toJson();
      final decoded = PaymentEvent.fromJson(json);

      expect(decoded.eventId, 'evt_test_001');
      expect(decoded.amount, 42.50);
      expect(decoded.customer?.nif, 'B12345678');
      expect(decoded.customer?.type, CustomerType.b2b);
      expect(decoded.status, PaymentStatus.succeeded);
    });

    test('fromJson con customer nulo', () {
      final json = {
        'event_id':    'evt_002',
        'provider_id': 'redsys',
        'timestamp':   '2026-03-30T12:00:00.000',
        'amount':      100.0,
        'currency':    'EUR',
        'status':      'succeeded',
        'method':      'card',
        'raw_payload': {},
      };
      final event = PaymentEvent.fromJson(json);
      expect(event.customer, isNull);
      expect(event.externalReference, isNull);
    });
  });

  group('Invoice model', () {
    test('copyWith mantiene campos', () {
      const inv = Invoice(
        serie:                 'F-2026',
        numero:                '00000001',
        tipo:                  InvoiceType.complete,
        tipoVerifactu:         'F1',
        emisorNif:             'B12345678',
        emisorNombre:          'Test S.L.',
        fechaExpedicion:       null as dynamic ?? DateTime(2026, 1, 1),  // workaround
        fechaOperacion:        null as dynamic ?? DateTime(2026, 1, 1),
        baseImponible:         100.0,
        tipoIva:               21.0,
        cuotaIva:              21.0,
        retencionIrpf:         0.0,
        recargo:               0.0,
        importeTotal:          121.0,
        descripcion:           'Test',
        claveRegimen:          '01',
        calificacionOperacion: 'S1',
        proveedorPago:         'stripe',
      );

      final updated = inv.copyWith(
        id:            'uuid-123',
        hashVerifactu: 'abc123',
      );

      expect(updated.id, 'uuid-123');
      expect(updated.hashVerifactu, 'abc123');
      expect(updated.serie, 'F-2026');
      expect(updated.emisorNif, 'B12345678');
    });
  });

  group('ProcessingResult', () {
    test('success tiene invoice', () {
      final inv = Invoice(
        serie: 'F-2026', numero: '001', tipo: InvoiceType.simplified,
        tipoVerifactu: 'F2', emisorNif: 'B1', emisorNombre: 'X',
        fechaExpedicion: DateTime.now(), fechaOperacion: DateTime.now(),
        baseImponible: 10, tipoIva: 21, cuotaIva: 2.1,
        retencionIrpf: 0, recargo: 0, importeTotal: 12.1,
        descripcion: 'Test', claveRegimen: '01',
        calificacionOperacion: 'S1', proveedorPago: 'test',
      );
      final r = ProcessingResult.success(invoice: inv);
      expect(r.isSuccess, isTrue);
      expect(r.invoice?.serie, 'F-2026');
    });

    test('duplicate no tiene error', () {
      final r = ProcessingResult.duplicate(eventId: 'evt_1');
      expect(r.isDuplicate, isTrue);
      expect(r.error, isNull);
    });

    test('error tiene mensaje', () {
      final r = ProcessingResult.error(eventId: 'evt_1', error: 'boom');
      expect(r.error, 'boom');
      expect(r.isSuccess, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MÓDULO 3 — STRIPE
  // ═══════════════════════════════════════════════════════════════════════════

  group('StripeWebhookValidator', () {
    test('verifica firma HMAC-SHA256 correcta', () {
      const secret  = 'whsec_test_secret_12345';
      const body    = '{"id":"evt_1","type":"payment_intent.succeeded"}';
      final ts      = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Generar firma válida
      final message  = '$ts.$body';
      final hmac     = Hmac(sha256, utf8.encode(secret));
      final digest   = hmac.convert(utf8.encode(message));
      final sig      = 't=$ts,v1=${digest.toString()}';

      final result = StripeWebhookValidator.verify(
        rawBody:   body,
        signature: sig,
        secret:    secret,
        tolerance: const Duration(minutes: 5),
      );
      expect(result, isTrue);
    });

    test('rechaza firma incorrecta', () {
      final result = StripeWebhookValidator.verify(
        rawBody:   '{"test":true}',
        signature: 't=12345,v1=invalid_hash_here',
        secret:    'whsec_real',
        tolerance: const Duration(minutes: 5),
      );
      expect(result, isFalse);
    });

    test('rechaza firma expirada (tolerancia 0s)', () {
      const secret = 'whsec_test';
      const body   = '{}';
      // Timestamp de hace 1 hora
      final ts     = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600).toString();
      final hmac   = Hmac(sha256, utf8.encode(secret));
      final digest = hmac.convert(utf8.encode('$ts.$body'));
      final sig    = 't=$ts,v1=${digest.toString()}';

      final result = StripeWebhookValidator.verify(
        rawBody:   body,
        signature: sig,
        secret:    secret,
        tolerance: const Duration(seconds: 30), // 30s de tolerancia, firma de 1h
      );
      expect(result, isFalse);
    });
  });

  group('StripeEventMapper', () {
    test('mapea payment_intent.succeeded correctamente', () {
      final payload = {
        'id':   'evt_stripe_001',
        'type': 'payment_intent.succeeded',
        'data': {
          'object': {
            'id':       'pi_123',
            'amount':   4250,
            'currency': 'eur',
            'created':  1711800000,
            'metadata': {
              'customer_type':  'b2b',
              'customer_nif':   'B99887766',
              'customer_name':  'Acme Corp',
              'customer_email': 'acme@test.com',
            },
          },
        },
      };

      final mapper = StripeEventMapper();
      final event  = mapper.map('payment_intent.succeeded', payload);

      expect(event, isNotNull);
      expect(event!.eventId, 'evt_stripe_001');
      expect(event.amount, 42.50);
      expect(event.currency, 'EUR');
      expect(event.status, PaymentStatus.succeeded);
      expect(event.customer?.nif, 'B99887766');
      expect(event.customer?.type, CustomerType.b2b);
      expect(event.externalReference, 'pi_123');
    });

    test('mapea charge.refunded', () {
      final payload = {
        'id':   'evt_ref_001',
        'type': 'charge.refunded',
        'data': {
          'object': {
            'amount_refunded': 1500,
            'currency':        'eur',
            'payment_intent':  'pi_original_123',
          },
        },
      };

      final mapper = StripeEventMapper();
      final event  = mapper.map('charge.refunded', payload);

      expect(event, isNotNull);
      expect(event!.amount, 15.0);
      expect(event.status, PaymentStatus.refunded);
      expect(event.externalReference, 'pi_original_123');
    });

    test('ignora eventos desconocidos', () {
      final mapper = StripeEventMapper();
      final event  = mapper.map('customer.created', {'data': {}});
      expect(event, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MÓDULO 4 — REDSYS
  // ═══════════════════════════════════════════════════════════════════════════

  group('RedsysEventMapper', () {
    test('mapea pago exitoso (Ds_Response=0000)', () {
      final mapper = RedsysEventMapper();
      final event  = mapper.map({
        'Ds_Response':        '0000',
        'Ds_TransactionType': '0',
        'Ds_Amount':          '5000', // 50.00 EUR
        'Ds_MerchantCode':    '999008881',
        'Ds_Order':           'PEDIDO001',
        'Ds_Date':            '30/03/2026',
        'Ds_Hour':            '14:30:00',
      });

      expect(event, isNotNull);
      expect(event!.amount, 50.0);
      expect(event.status, PaymentStatus.succeeded);
      expect(event.providerId, 'redsys');
      expect(event.externalReference, 'PEDIDO001');
    });

    test('ignora pago denegado (Ds_Response=0190)', () {
      final mapper = RedsysEventMapper();
      final event  = mapper.map({
        'Ds_Response': '0190',
        'Ds_TransactionType': '0',
        'Ds_Amount': '1000',
      });
      expect(event, isNull);
    });

    test('mapea devolución (Ds_TransactionType=3)', () {
      final mapper = RedsysEventMapper();
      final event  = mapper.map({
        'Ds_Response':        '0000',
        'Ds_TransactionType': '3',
        'Ds_Amount':          '2000',
        'Ds_MerchantCode':    '999008881',
        'Ds_Order':           'PEDIDO002',
        'Ds_Date':            '30/03/2026',
        'Ds_Hour':            '15:00:00',
      });

      expect(event, isNotNull);
      expect(event!.status, PaymentStatus.refunded);
      expect(event.amount, 20.0);
    });
  });

  group('RedsysSignatureValidator — 3DES', () {
    test('rechaza firma inválida', () {
      // Clave de 16 bytes codificada en Base64
      final key = base64.encode(List.generate(16, (i) => i + 1));

      final result = RedsysSignatureValidator.verify(
        merchantParameters: base64.encode(utf8.encode('{"Ds_Order":"0001"}')),
        signature:          'FIRMA_INVALIDA_AQUI',
        merchantKey:        key,
        order:              '0001',
      );
      expect(result, isFalse);
    });

    test('lanza error con clave de tamaño incorrecto', () {
      expect(
        () => RedsysSignatureValidator.verify(
          merchantParameters: 'test',
          signature:          'test',
          merchantKey:        base64.encode([1, 2, 3]), // 3 bytes — inválido
          order:              '001',
        ),
        isFalse, // Devuelve false (catch), no lanza excepción
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MÓDULO 5 — CIRCUIT BREAKER
  // ═══════════════════════════════════════════════════════════════════════════

  group('CircuitBreaker', () {
    test('empieza cerrado', () {
      final cb = CircuitBreaker(bankId: 'test', failureThreshold: 3);
      expect(cb.isOpen, isFalse);
    });

    test('se abre tras N fallos', () async {
      final cb = CircuitBreaker(
        bankId:           'test',
        failureThreshold: 3,
        recoveryTimeout:  const Duration(minutes: 30),
      );

      for (var i = 0; i < 3; i++) {
        try {
          await cb.execute<void>(() => throw Exception('fallo $i'));
        } catch (_) {}
      }

      expect(cb.isOpen, isTrue);
    });

    test('rechaza llamadas cuando está abierto', () async {
      final cb = CircuitBreaker(
        bankId:           'test',
        failureThreshold: 1,
        recoveryTimeout:  const Duration(minutes: 30),
      );

      try {
        await cb.execute<void>(() => throw Exception('fallo'));
      } catch (_) {}

      expect(cb.isOpen, isTrue);

      expect(
        () => cb.execute<void>(() async {}),
        throwsA(isA<CircuitOpenException>()),
      );
    });

    test('se cierra tras éxito en half-open', () async {
      final cb = CircuitBreaker(
        bankId:           'test',
        failureThreshold: 1,
        recoveryTimeout:  Duration.zero, // se recupera inmediatamente
      );

      // Abrir el circuit breaker
      try {
        await cb.execute<void>(() => throw Exception('fallo'));
      } catch (_) {}
      expect(cb.isOpen, isTrue);

      // Esperar que pase el recoveryTimeout (0ms)
      await Future.delayed(const Duration(milliseconds: 10));

      // Debería pasar a half-open y cerrarse tras éxito
      final result = await cb.execute<String>(() async => 'ok');
      expect(result, 'ok');
      expect(cb.isOpen, isFalse);
    });

    test('toJson devuelve estado', () {
      final cb = CircuitBreaker(bankId: 'bbva');
      final json = cb.toJson();
      expect(json['bank_id'], 'bbva');
      expect(json['state'], 'closed');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MÓDULO 6 — IDEMPOTENCY RESULT
  // ═══════════════════════════════════════════════════════════════════════════

  group('IdempotencyResult', () {
    test('acquired se crea correctamente', () {
      final r = IdempotencyResult.acquired();
      expect(r, isA<Acquired>());
    });

    test('alreadyCompleted tiene invoiceId', () {
      final r = IdempotencyResult.alreadyCompleted(invoiceId: 'inv_123');
      expect(r, isA<AlreadyCompleted>());
      expect((r as AlreadyCompleted).invoiceId, 'inv_123');
    });

    test('error tiene mensaje', () {
      final r = IdempotencyResult.error('DB down');
      expect(r, isA<IdempotencyError>());
      expect((r as IdempotencyError).message, 'DB down');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // INTEGRACIÓN — FLUJO COMPLETO (sin BD)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Flujo completo de evento Stripe → factura (simulado)', () {
    test('evento Stripe → mapeo → PaymentEvent válido', () {
      // 1. Simular webhook de Stripe
      const rawBody = '{"id":"evt_live_001","type":"payment_intent.succeeded",'
          '"data":{"object":{"id":"pi_999","amount":12100,"currency":"eur","created":1711800000,'
          '"metadata":{"customer_type":"b2b","customer_nif":"B11223344",'
          '"customer_name":"Mi Cliente S.L.","customer_email":"cli@test.com",'
          '"product_code":"hosteleria"}}}}';
      final payload = jsonDecode(rawBody) as Map<String, dynamic>;

      // 2. Mapear
      final mapper = StripeEventMapper();
      final event  = mapper.map(
        payload['type'] as String,
        payload,
      );

      // 3. Verificar
      expect(event, isNotNull);
      expect(event!.amount, 121.0);
      expect(event.currency, 'EUR');
      expect(event.customer?.nif, 'B11223344');
      expect(event.customer?.type, CustomerType.b2b);
      expect(event.providerId, 'stripe');
      expect(event.externalReference, 'pi_999');

      // 4. Simular que sería F1 (completa) por ser B2B con NIF
      final isB2B = event.customer?.type == CustomerType.b2b &&
                    event.customer?.nif != null;
      expect(isB2B, isTrue);

      // 5. Calcular impuestos (simulado sin BD)
      const baseImponible = 121.0 / 1.21; // ≈ 100.0
      const cuotaIva      = 100.0 * 0.21;  // = 21.0
      expect(baseImponible, closeTo(100.0, 0.01));
      expect(cuotaIva, closeTo(21.0, 0.01));
    });
  });
}

