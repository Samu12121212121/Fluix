# BUILD STATUS — Sistema de Facturación Automática
Generado: 2026-03-30T00:00:00  
Versión del prompt: 7 (definitiva)

---

## Resumen ejecutivo

| Indicador              | Estado |
|------------------------|--------|
| Módulos completados    | 8 / 8  |
| Tests pasando          | 0 / 0 (pendiente escribir) |
| Errores críticos       | 0      |
| Advertencias           | 3      |
| Listo para producción  | ⚠️ (falta validar credenciales reales) |

---

## Estado por módulo

### ✅ MÓDULO 1 — Interfaces y modelos compartidos
- **Ficheros**: `lib/services/payments/interfaces/payment_event.dart`, `payment_provider.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: Todos los enums y modelos implementados. `CustomerInfo` soporta B2B/B2C/unknown.

### ✅ MÓDULO 2 — Idempotencia atómica
- **Ficheros**: `lib/services/payments/core/idempotency_repository.dart`, migración 001
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: INSERT atómico con `ON CONFLICT DO NOTHING` elimina la race condition.
  Detección de locks huérfanos (>10min) con re-adquisición atómica.
  ⚠️ No probado con concurrencia real — requiere test con `pgbench` o equivalente.

### ✅ MÓDULO 3 — Proveedor Stripe
- **Ficheros**: `stripe_provider.dart`, `stripe_webhook_validator.dart`, `stripe_event_mapper.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: HMAC-SHA256 con tolerancia de 5min. Soporta `payment_intent.succeeded`
  y `charge.refunded`. Metadata de B2B: `customer_nif`, `customer_name`, `customer_email`.
  ⚠️ Pendiente validar con payload real del dashboard de Stripe (modo test).

### ✅ MÓDULO 4 — Proveedor Redsys (3DES)
- **Ficheros**: `redsys_provider.dart`, `redsys_signature_validator.dart`, `redsys_event_mapper.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **CRÍTICO**: ⚠️ El algoritmo 3DES-ECB + HMAC-SHA256 está implementado según la documentación
  oficial de Redsys (HMAC_SHA256_V1). **Pendiente validar contra vector de prueba oficial**
  antes de usar en producción. La clave debe ser Base64 de 16 o 24 bytes.
  Clave inválida lanza `ArgumentError` con mensaje descriptivo.

### ✅ MÓDULO 5 — Proveedor PSD2 + Circuit Breaker
- **Ficheros**: `psd2_provider/`, `circuit_breaker.dart`, `psd2_consent_manager.dart`,
  `psd2_polling_service.dart`, `banks/` (CaixaBank, Santander, BBVA, Sabadell, Bankinter)
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: 5 bancos implementados. Circuit breaker con threshold=5, recovery=30min.
  Consentimientos con aviso a los 7 días y revocación a los 0 días.
  ⚠️ Los endpoints de los bancos son aproximados — verificar en la documentación
  oficial de cada banco antes de producción. Requiere onboarding OAuth2 real.
  ⚠️ Renovación de consentimiento no probada con flujo OAuth2 real.

### ✅ MÓDULO 6 — Motor fiscal (TaxCalculator)
- **Ficheros**: `tax_calculator.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: IVA 21%/10%/4%/0%, IRPF 15%/7%/0%, recargo de equivalencia 5.2%/1.4%/0.5%.
  Configuración via `business_config` en BD o variables de entorno.
  ⚠️ Los tipos de IVA deben ser confirmados con asesoría fiscal antes de producción.
  ⚠️ IRPF solo aplica para facturas B2B cuando `sujetaRetencionIRPF=true`.

### ✅ MÓDULO 7 — Motor central (InvoiceFactory + PaymentProcessor)
- **Ficheros**: `invoice_factory.dart`, `payment_processor.dart`, `client_resolver.dart`,
  `invoice_series_repository.dart`, `invoice_emitter.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: Flujo completo F1→F2→R4 implementado. Numeración sin huecos con
  `SELECT FOR UPDATE`. Integración Verifactu via Cloud Function o implementación local.
  ⚠️ PDF es un stub de texto plano — en producción integrar con el módulo `pdf_service.dart`
  del proyecto Flutter o con el paquete `pdf` de Dart.
  ⚠️ `ClientResolver` busca en tabla `clients` — requiere que el CRM esté conectado
  o que el proveedor (Stripe) envíe los metadatos del cliente en el webhook.

### ✅ MÓDULO 8 — Cola de reintentos + Health Monitor
- **Ficheros**: `retry_queue.dart`, `health_monitor.dart`
- **Estado**: Completado
- **Tests**: Pendiente
- **Notas**: Backoff exponencial: 1, 2, 4, 8, 16, 32, 64, 128 min. Dead letter tras 8 intentos.
  Health monitor cubre: silencio >4h, dead letter 24h, circuit breakers, consentimientos
  PSD2 y latencia de BD.
  ⚠️ `FOR UPDATE SKIP LOCKED` en la cola de reintentos requiere PostgreSQL 9.5+.

---

## Errores conocidos

Sin errores conocidos en esta versión.

---

## Advertencias

| # | Área | Descripción | Acción recomendada |
|---|------|-------------|-------------------|
| 1 | Redsys 3DES | No validado con credenciales reales de banco | Ejecutar vector de prueba oficial de Redsys antes de go-live |
| 2 | PDF generado | Stub de texto plano, no PDF real | Integrar con `pdf` package o referenciar `pdf_service.dart` del proyecto Flutter |
| 3 | PSD2 endpoints | URLs de bancos pueden haber cambiado | Verificar en documentación oficial de CaixaBank/Santander/BBVA antes de producción |

---

## Pendiente para producción

- [ ] Validar 3DES Redsys con vector de prueba oficial del banco
- [ ] Test de integración Stripe con payload real en modo test
- [ ] Ejecutar las 4 migraciones SQL en el servidor de producción
- [ ] Configurar todas las variables de entorno (ver `bin/server.dart` y `.env.example`)
- [ ] Implementar PDF real (integrar con `pdf` package de Dart)
- [ ] Registrar URL del webhook en el dashboard de Stripe: `/webhooks/stripe`
- [ ] Registrar URL de notificación en panel Redsys: `/webhooks/redsys`
- [ ] Completar onboarding OAuth2 PSD2 con cada banco (CaixaBank/Santander/BBVA)
- [ ] Configurar SSL/TLS (nginx reverse proxy recomendado)
- [ ] Configurar `business_config` en BD con NIF/nombre del emisor real
- [ ] Insertar mapeos de IVA en `vat_mappings` según los servicios del negocio
- [ ] Confirmar tipos de IVA con asesoría fiscal
- [ ] Escribir tests unitarios para todos los módulos (target: >80% cobertura)
- [ ] Configurar monitoreo externo (UptimeRobot o similar) apuntando a `/health`

---

## Métricas de calidad del código

- Cobertura de tests: 0% (pendiente escribir tests)
- Ficheros sin tests: todos (35 ficheros)
- TODO/FIXME pendientes: 0
- Líneas de código: ~2.100

