# Módulo: Suscripción y Planes

## Qué hace

Gestiona los planes de suscripción de cada empresa en la plataforma Fluix. Controla qué módulos tiene habilitados, el estado del pago, y muestra pantallas de upgrade cuando el usuario intenta acceder a módulos no contratados. Integrado con Stripe para pagos.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/suscripcion/pantallas/pantalla_suscripcion_vencida.dart` | Pantalla de renovación |
| `features/suscripcion/pantallas/pantalla_upgrade_modulo.dart` | Upgrade de un módulo concreto |
| `functions/src/planesConfigV2.ts` | Configuración de planes y precios |

---

## Estructura de datos: Suscripción

La suscripción de cada empresa vive en `empresas/{empresaId}/suscripcion/actual`:

```
{
  estado: 'ACTIVA' | 'VENCIDA' | 'SUSPENDIDA'
  plan: 'starter' | 'profesional' | 'enterprise'
  
  packs_activos: ['facturacion', 'nominas', 'tpv', ...]
  addons_activos: ['verifactu', 'whatsapp', 'gmb', ...]
  
  fechaInicio: Timestamp
  fechaFin: Timestamp
  
  stripeCustomerId: String?
  stripeSubscriptionId: String?
  
  es_demo: bool              // Las cuentas demo acceden a todo
  
  periodoEssai: bool         // Período de prueba gratuito
  diasEssaiRestantes: int?
}
```

---

## Planes disponibles (planesConfigV2.ts)

| Pack | Módulos incluidos |
|------|------------------|
| `facturacion` | Facturación, contabilidad, modelos AEAT |
| `nominas` | Nóminas, finiquitos, remesas SEPA |
| `rrhh` | Empleados, vacaciones, fichajes |
| `tpv` | TPV (tienda, restaurante, peluquería) |
| `reservas` | Reservas, servicios, calendario |
| `clientes_crm` | Clientes, tareas, campañas |
| `web` | Web pública, blog, SEO |

### Add-ons independientes
- `verifactu` — facturación electrónica AEAT
- `whatsapp` — bot y notificaciones WhatsApp Business
- `gmb` — integración Google My Business
- `pdf_dinamico` — templates personalizados de PDF

---

## Cómo funciona

### Control de acceso a módulos

Las Firestore Rules validan el acceso en tiempo real:

```javascript
// En firestore.rules
function tienePackActivo(empresaId, packId) {
  return get(/empresas/$(empresaId)/suscripcion/actual).data.packs_activos.hasAny([packId])
    || get(/empresas/$(empresaId)/suscripcion/actual).data.es_demo == true;
}
```

En la app, el Grid de módulos del Dashboard filtra visualmente los módulos según los packs activos:
- Si está activo → acceso normal
- Si no está activo → icono de candado, click lleva a `pantalla_upgrade_modulo.dart`
- Si está vencido → `pantalla_suscripcion_vencida.dart` bloquea toda la app

### Stripe
- Al contratar un plan, se crea un `Customer` en Stripe y se inicia una suscripción
- `stripeWebhook` recibe los eventos de Stripe (pago exitoso, fallido, renovación)
- Al recibir `invoice.payment_succeeded`, se actualiza `estado: ACTIVA` y se extiende `fechaFin`
- Al recibir `customer.subscription.deleted`, se pone `estado: VENCIDA`

### Período de demo
- Al registrarse, la empresa tiene `es_demo: true` durante N días
- Las cuentas demo tienen acceso a todos los módulos sin restricción
- `verificarSuscripciones` (Scheduled) comprueba cada noche si el período de demo ha terminado

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/suscripcion/actual` | Estado actual de la suscripción |

---

## Cloud Functions relacionadas

| Función | Cuándo |
|---------|--------|
| `stripeWebhook` | HTTP — recibe eventos de pago de Stripe |
| `verificarSuscripciones` | Scheduled noche — comprueba vencimientos y demos |
| `crearSuscripcionDemo` | Callable — al crear empresa, inicia período de prueba |

---

## Conexión con otros módulos

- **Todos los módulos** — cada módulo comprueba si tiene el pack activo antes de mostrar contenido
- **Dashboard** — el grid de módulos usa la suscripción para mostrar/ocultar accesos
- **Registro/Onboarding** — al crear una empresa nueva se inicializa la suscripción demo
- **Firestore Rules** — la suscripción es la fuente de verdad para el control de acceso a nivel de base de datos
