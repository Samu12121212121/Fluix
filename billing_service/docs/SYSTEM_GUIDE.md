# GUÍA DEL SISTEMA — Facturación Automática
Generado: 2026-03-30

---

## Qué hace este sistema

Detecta automáticamente cualquier cobro y genera la factura fiscal correspondiente
sin intervención humana. Funciona con tres fuentes de pago:

1. **Stripe** — Pagos con tarjeta en la app Flutter
2. **Redsys** — TPV físico de cualquier banco español (CaixaBank, Santander, BBVA, etc.)
3. **PSD2 Open Banking** — Transferencias y cobros detectados directamente en la cuenta bancaria

Cada factura cumple con el RD 1619/2012 (factura válida) y el RD 1007/2023 (registro Verifactu en AEAT).

---

## Estructura del proyecto

```
billing_service/
  bin/
    server.dart                     ← Punto de entrada + scheduler
  lib/
    database/
      database.dart                 ← Interfaz abstracta BD
      postgres_database.dart        ← Implementación PostgreSQL
    models/
      business_config.dart          ← Config del negocio (NIF, IVA, IRPF)
      invoice.dart                  ← Modelo de factura F1/F2/R4
      processing_result.dart        ← Resultado del procesamiento
      psd2_consent.dart             ← Modelos PSD2
    repositories/
      business_config_repository.dart
      consent_repository.dart
      invoice_repository.dart
    services/
      logger.dart
      notification_service.dart
      verifactu_service.dart
      payments/
        interfaces/
          payment_event.dart        ← Modelo normalizado de evento
          payment_provider.dart     ← Interfaz de proveedor
        providers/
          stripe/                   ← Webhook HMAC-SHA256
          redsys/                   ← 3DES + HMAC-SHA256
          psd2/                     ← Berlin Group + Circuit Breaker
            banks/                  ← Adaptadores por banco
        core/
          payment_processor.dart    ← Orquestador central
          idempotency_repository.dart
          invoice_factory.dart      ← Construye F1/F2/R4
          invoice_series_repository.dart
          invoice_emitter.dart
          tax_calculator.dart       ← IVA/IRPF/recargo
          retry_queue.dart          ← Backoff exponencial
          health_monitor.dart       ← Alertas automáticas
        registry/
          provider_registry.dart
  migrations/
    001_create_payment_processing_log.sql
    002_create_invoices.sql
    003_create_retry_queue.sql
    004_create_psd2_tables.sql
```

---

## Cómo arrancar el sistema

### 1. Requisitos previos
- **Dart SDK** ≥ 3.0
- **PostgreSQL** ≥ 9.5 (para `FOR UPDATE SKIP LOCKED`)

### 2. Instalar dependencias
```bash
cd billing_service
dart pub get
```

### 3. Crear la base de datos
```bash
createdb facturacion_auto
psql facturacion_auto < migrations/001_create_payment_processing_log.sql
psql facturacion_auto < migrations/002_create_invoices.sql
psql facturacion_auto < migrations/003_create_retry_queue.sql
psql facturacion_auto < migrations/004_create_psd2_tables.sql
```

### 4. Configurar variables de entorno
```bash
export DATABASE_URL=postgresql://user:pass@localhost:5432/facturacion_auto
export PORT=8080

# Emisor (tu negocio)
export EMISOR_NIF=B12345678
export EMISOR_NOMBRE="Mi Empresa S.L."

# Stripe
export STRIPE_WEBHOOK_SECRET=whsec_xxxxx

# Redsys
export REDSYS_MERCHANT_KEY=base64key==

# PSD2 (por banco)
export PSD2_CAIXABANK_CLIENT_ID=xxxx
export PSD2_CAIXABANK_CLIENT_SECRET=xxxx

# Verifactu (URL de tu Cloud Function)
export VERIFACTU_CLOUD_FUNCTION_URL=https://europe-west1-tu-proyecto.cloudfunctions.net/firmarXMLVerifactu

# Notificaciones
export NOTIFICATION_EMAIL=admin@tu-negocio.com
```

### 5. Arrancar
```bash
dart run bin/server.dart
```

Verás:
```
[INFO] Conectando a PostgreSQL...
[INFO] ✅ BD conectada
[INFO] ✅ Proveedor Stripe registrado
[INFO] ✅ Proveedor Redsys registrado
[INFO] ⏱ Scheduler iniciado (retry:1min, psd2:20min, health:1h, consents:24h)
[INFO] 🚀 Servidor Facturación Automática en http://localhost:8080
```

---

## Cómo fluye un pago de principio a fin

### Stripe (webhook)
```
Cliente paga en app Flutter
        ↓
Stripe envía POST a /webhooks/stripe
        ↓
StripeWebhookValidator verifica firma HMAC-SHA256
        ↓
StripeEventMapper → PaymentEvent normalizado
        ↓
RetryQueue.enqueue() — guardado en BD
        ↓  (cada minuto, el scheduler procesa la cola)
PaymentProcessor.process()
        ↓
IdempotencyRepository.tryAcquire() — INSERT atómico
        ↓
ClientResolver — ¿B2B (con NIF) o B2C?
        ↓
TaxCalculator — IVA + IRPF + recargo equivalencia
        ↓
InvoiceFactory — F1 (completa B2B) o F2 (simplificada B2C)
        ↓
VerifactuService — hash SHA-256 + XML registro
        ↓
InvoiceEmitter — PDF + email al cliente
        ↓
IdempotencyRepository.markCompleted()
```

### Redsys (notificación URL del TPV)
```
Cliente paga en TPV físico
        ↓
Banco envía POST a /webhooks/redsys (form-urlencoded)
        ↓
RedsysSignatureValidator verifica 3DES-ECB + HMAC-SHA256
        ↓
RedsysEventMapper → PaymentEvent normalizado
        ↓
RetryQueue.enqueue() → mismo flujo que Stripe
```

### PSD2 Open Banking (polling)
```
Cada 20 minutos, el scheduler ejecuta:
Psd2PollingService.pollAll()
        ↓
Por cada banco registrado (con circuit breaker):
  BerlinGroupClient.getTransactions()
        ↓
  Filtrar solo CRDT (cobros) no procesados
        ↓
  Psd2EventMapper → PaymentEvent
        ↓
  RetryQueue.enqueue() → mismo flujo
```

---

## Endpoints HTTP

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/webhooks/stripe` | Webhook de Stripe |
| POST | `/webhooks/redsys` | Notificación URL de Redsys |
| GET | `/psd2/callback` | Callback OAuth2 para renovar consentimiento PSD2 |
| GET | `/payments/recent` | Últimas 50 facturas |
| POST | `/payments/<id>/retry` | Reintentar un pago fallido |
| GET | `/admin/dead-letter` | Pagos que fallaron 8 veces |
| GET | `/health` | Health check (200=OK, 503=problemas) |
| GET | `/status` | Estado del servicio |
| GET | `/providers` | Proveedores registrados |

---

## Cómo añadir un banco nuevo

### Caso 1: Banco con Redsys (mayoría de bancos españoles)
No hay que hacer nada. Un solo adaptador Redsys cubre todos los bancos
con protocolo Redsys. Solo cambian las credenciales (`REDSYS_MERCHANT_KEY`).

### Caso 2: Banco con API PSD2 propia
1. Crear `lib/.../psd2/banks/nuevo_banco_adapter.dart`:
```dart
class NuevoBancoAdapter implements BankAdapter {
  @override String get bankId      => 'nuevo_banco';
  @override String get displayName => 'Nombre del Banco';
  @override String get baseUrl     => 'https://api.nuevobanco.es/psd2';
  @override String get authorizationEndpoint => '$baseUrl/oauth/authorize';
  @override String get tokenEndpoint         => '$baseUrl/oauth/token';
  @override String get transactionsEndpoint  => '$baseUrl/v1/accounts/{accountId}/transactions';
}
```
2. Registrar en `bin/server.dart`:
```dart
psd2PollingService.registerBank(NuevoBancoAdapter());
```
3. Añadir variables de entorno:
```
PSD2_NUEVO_BANCO_CLIENT_ID=xxxx
PSD2_NUEVO_BANCO_CLIENT_SECRET=xxxx
```
4. Completar onboarding OAuth2 una vez desde la app.

---

## Cómo interpretar los logs

| Mensaje | Significa | Acción |
|---------|-----------|--------|
| `Factura F-2026-00000042 generada` | Todo correcto | Ninguna |
| `Evento evt_xyz ya procesado. Ignorando.` | Webhook duplicado (normal) | Ninguna |
| `Circuit breaker ABIERTO para caixabank` | API del banco falló 5 veces | Verificar estado en 30min |
| `DEAD LETTER: evt_xyz` | 8 intentos fallidos | Revisar GET /admin/dead-letter |
| `Sin pagos procesados en 5h` | Posible fallo en webhooks | Verificar URLs webhook |
| `Consentimiento PSD2 expira en 3 días` | Renovación pendiente | App → Bancos → Renovar |

---

## Cómo renovar una conexión bancaria PSD2

Los consentimientos PSD2 expiran cada **90 días**. El sistema avisa 7 días antes.

1. El administrador recibe notificación push/email.
2. Abre el enlace de renovación (genera URL OAuth2 del banco).
3. Se autentica en la web del banco (SCA — doble factor).
4. El banco redirige a `/psd2/callback?code=xxx&state=bankId`.
5. El sistema guarda el nuevo token → conexión renovada 90 días más.

---

## Cómo procesar manualmente un pago fallido

Si un pago llega a dead letter (8 fallos):

1. `GET /admin/dead-letter` → ver detalles y error.
2. Si es transitorio (timeout, BD caída):
   - `POST /payments/<eventId>/retry` → se reencola con reintentos.
3. Si es de datos (factura original no encontrada, NIF inválido):
   - Corregir datos en BD → `POST /payments/<eventId>/retry`.
4. Si es irrecuperable:
   - Generar factura manualmente desde la app Flutter.

---

## Tipos de factura generados

| Tipo Verifactu | Cuándo | Normativa |
|----------------|--------|-----------|
| **F1** — Completa | Cliente B2B con NIF | Art. 6 RD 1619/2012 |
| **F2** — Simplificada | Cliente B2C o sin NIF | Art. 7 RD 1619/2012 |
| **R4** — Rectificativa | Reembolso/devolución | Art. 15 RD 1619/2012 |

---

## Tipos de IVA configurables

| Tipo | % | Cuándo aplica |
|------|---|---------------|
| General | 21% | Servicios por defecto |
| Reducido | 10% | Hostelería, transporte |
| Superreducido | 4% | Medicamentos, libros |
| Exento | 0% | Seguros, educación (Art. 20 LIVA) |

Configurar en la tabla `vat_mappings`:
```sql
INSERT INTO vat_mappings VALUES ('hosteleria','reduced','Hostelería 10%',NOW());
INSERT INTO vat_mappings VALUES ('educacion','exempt','Formación exenta',NOW());
```

---

## Mantenimiento periódico

| Tarea | Frecuencia | Cómo |
|-------|-----------|------|
| Revisar dead letter | Diaria | `GET /admin/dead-letter` |
| Verificar health | Automático (cada hora) | Alertas por email/push |
| Renovar PSD2 | Cada 90 días | App → Bancos → Renovar |
| Revisar huecos en facturas | Mensual | Consultar `invoice_series_counters` |
| Actualizar tipos de IVA | Cuando cambie la ley | Tabla `vat_mappings` |
| Limpiar retry_queue completadas | Mensual | `DELETE FROM retry_queue WHERE status='completed' AND created_at < NOW() - INTERVAL '90 days'` |
| Backup de BD | Diaria | `pg_dump facturacion_auto > backup_$(date +%Y%m%d).sql` |

