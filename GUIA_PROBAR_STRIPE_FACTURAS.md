# 🧪 Guía: Probar Stripe → Factura Automática

## ¿Cómo funciona el flujo completo?

```
Cliente (empresa) compra en fluixtech.com
        ↓ (Stripe Checkout)
  Pago completado en Stripe
        ↓ (webhook HTTP → stripeWebhook)
        ├──────────────────────────────────────────────────────┐
        │  1️⃣ INGRESO para FluxTech (propietario)              │  2️⃣ GASTO para la empresa cliente
        │                                                      │
        ↓                                                      ↓
  empresas/fluixtech/pedidos/{pedidoId}          empresas/{empresa_cliente_id}/gastos/{gastoId}
        ↓ (trigger onNuevoPedidoGenerarFactura)                ↓ (directo, ya está pagado)
  empresas/fluixtech/facturas/{facturaId}        cache_contable/{YYYY-MM} actualizado
        ↓ (notificación push)
  📱 Fluixtech ve la factura de INGRESO          📱 Empresa cliente ve el GASTO de software
```

**Resumen:**
- **FluxTech** → módulo Facturas muestra la venta como **ingreso**
- **Empresa cliente** → módulo Contabilidad/Gastos muestra la suscripción como **gasto de software**

---

## PASO 1 — Configurar las claves de Stripe en Firebase

Abre una terminal y ejecuta (una sola vez).  
Usa el **nuevo sistema de secrets** (sin deprecación hasta 2027):

```powershell
cd "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

# Stripe Secret Key (empieza por sk_live_... o sk_test_...)
firebase functions:secrets:set STRIPE_SECRET_KEY
# → Te pedirá que pegues el valor: sk_test_xxxxxxxx...

# Webhook Signing Secret (empieza por whsec_...)
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# → Te pedirá que pegues el valor: whsec_xxxxxxxx...
```

> 🔑 Encuentra estas claves en **Stripe Dashboard → Developers → API Keys**  
> ⚠️ **NO uses** `firebase functions:config:set` — ese comando está deprecado y dejará de funcionar en marzo 2027.

---

## PASO 2 — Desplegar las Functions

```powershell
cd "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\functions"
npm install
npm run build
cd ..
firebase deploy --only functions
```

**URL del webhook que se creará:**
```
https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhook
```

> 💡 Durante el deploy, Firebase te preguntará si quieres conceder acceso a los secrets  
> a la función `stripeWebhook`. Di **Y** (sí).

---

## PASO 3 — Registrar el webhook en Stripe Dashboard

1. Ve a [https://dashboard.stripe.com/webhooks](https://dashboard.stripe.com/webhooks)
2. Haz clic en **"Add endpoint"**
3. Pega la URL:
   ```
   https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhook
   ```
4. En **"Select events"**, selecciona:
   - ✅ `checkout.session.completed`
   - ✅ `payment_intent.succeeded` (opcional)
5. Guarda y **copia el Webhook Signing Secret** (`whsec_...`)
6. Ejecuta el comando del Paso 1 con ese `whsec_`

---

## PASO 4 — Configurar el metadata en tu Checkout de Stripe

En el código de tu web (fluixtech.com), al crear la Stripe Checkout Session, **añade metadata**:

```javascript
// Ejemplo con Stripe.js / Node.js backend
const session = await stripe.checkout.sessions.create({
  payment_method_types: ['card'],
  line_items: [{
    price: 'price_xxxxx',  // ID del precio en Stripe
    quantity: 1,
  }],
  mode: 'payment',
  success_url: 'https://fluixtech.com/gracias',
  cancel_url: 'https://fluixtech.com/planes',
  metadata: {
    empresa_id: 'ID_DE_LA_EMPRESA_CLIENTE', // ← ID de la empresa que compra (en Firestore)
    paquete: 'Plan Pro Mensual',             // ← Nombre que aparece en factura y en el gasto
  },
  customer_email: 'cliente@email.com',
});
```

> ⚠️ **`empresa_id` = el ID de la empresa CLIENTE (quien paga), NO fluixtech.**  
> Con ese ID, el webhook sabrá:  
> — Crear el INGRESO en `empresas/fluixtech`  
> — Crear el GASTO en `empresas/{empresa_id}`

> 📌 **Si usas WordPress + WooCommerce:**  
> Añade el campo `empresa_id` como campo de checkout personalizado,  
> o pásalo como metadata via `woocommerce_checkout_order_processed`.

---

## ¿Qué se crea exactamente en Firestore?

### En la cuenta de FluxTech (propietario):
```
empresas/fluixtech/pedidos/{id}   → estado: confirmado, estado_pago: pagado
empresas/fluixtech/facturas/{id}  → tipo: pedido, estado: pendiente (auto-generada)
```

### En la cuenta de la empresa cliente:
```
empresas/{empresa_id}/gastos/{id}            → categoria: software, estado: pagado
empresas/{empresa_id}/cache_contable/{YYYY-MM} → gastos_total incrementado
```

---

## PASO 5 — Probar con Stripe CLI (recomendado)

### Instalar Stripe CLI (si no lo tienes):
Descarga desde [https://stripe.com/docs/stripe-cli](https://stripe.com/docs/stripe-cli)

### Escuchar eventos en local y reenviarlos a Firebase:
```bash
stripe listen --forward-to https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhook
```

### Simular un pago completado:
```bash
stripe trigger checkout.session.completed
```

> Esto enviará un evento de prueba real a tu webhook.  
> Verás en Firebase Console → Functions → Logs si fue exitoso.

---

## PASO 6 — Probar con un pago real de prueba

1. En Stripe Dashboard, activa el **modo test** (switch en la esquina superior derecha)
2. Haz una compra en tu web usando la tarjeta de prueba:
   ```
   Número: 4242 4242 4242 4242
   Fecha:  12/34
   CVC:    123
   ```
3. Espera ~5 segundos
4. Abre la app → **Módulo Facturas**
5. Deberías ver la nueva factura automáticamente generada

---

## Verificar en Firebase Console

1. Ve a [https://console.firebase.google.com/project/planeaapp-4bea4/firestore](https://console.firebase.google.com/project/planeaapp-4bea4/firestore)
2. Navega a: `empresas` → `fluixtech` → `pedidos`
   - Deberías ver el pedido creado por el webhook
3. Navega a: `empresas` → `fluixtech` → `facturas`
   - Deberías ver la factura generada automáticamente

---

## Verificar logs de Firebase Functions

```powershell
firebase functions:log --only stripeWebhook,onNuevoPedidoGenerarFactura
```

Deberías ver algo como:
```
✅ Pedido abc123 creado desde Stripe para empresa "fluixtech" — Juan García — €99.00
   ➡️  La factura se generará automáticamente via onNuevoPedidoGenerarFactura
✅ Factura FAC-2026-0001 generada automáticamente para pedido abc123
```

---

## Solución de problemas

| Error | Solución |
|-------|---------|
| `Stripe no configurado en el servidor` | Ejecuta el comando de config del Paso 1 y vuelve a desplegar |
| `Webhook signature verification failed` | Copia bien el `whsec_` del Stripe Dashboard y actualiza config |
| Se crea el pedido pero no la factura | Revisa los logs de `onNuevoPedidoGenerarFactura` en Firebase |
| No aparece en la app | Asegúrate de estar logueado con la empresa `fluixtech` |

---

## Estructura de los documentos creados automáticamente

### 1️⃣ Pedido de INGRESO (en `empresas/fluixtech/pedidos`)
```json
{
  "empresa_id": "fluixtech",
  "cliente_nombre": "Juan García",
  "cliente_correo": "juan@email.com",
  "empresa_cliente_id": "id_empresa_cliente",
  "origen": "web",
  "estado": "confirmado",
  "estado_pago": "pagado",
  "metodo_pago": "tarjeta",
  "lineas": [{ "producto_nombre": "Plan Pro Mensual", "precio_unitario": 81.82, "porcentaje_iva": 21 }],
  "subtotal": 81.82,
  "total": 99.00,
  "stripe_session_id": "cs_test_..."
}
```

### 1️⃣ Factura de INGRESO (en `empresas/fluixtech/facturas`) — auto-generada
```json
{
  "numero_factura": "FAC-2026-0001",
  "tipo": "pedido",
  "estado": "pendiente",
  "cliente_nombre": "Juan García",
  "total": 99.00,
  "subtotal": 81.82,
  "total_iva": 17.18
}
```

### 2️⃣ GASTO (en `empresas/{empresa_cliente_id}/gastos`) — creado directamente
```json
{
  "concepto": "Suscripción PlaneaG — Plan Pro Mensual",
  "categoria": "software",
  "proveedor_nombre": "FluxTech",
  "base_imponible": 81.82,
  "porcentaje_iva": 21,
  "importe_iva": 17.18,
  "total": 99.00,
  "iva_deducible": true,
  "estado": "pagado",
  "metodo_pago": "tarjeta",
  "numero_factura_proveedor": "FAC-2026-0001"
}
```






