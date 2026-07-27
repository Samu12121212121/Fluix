# Integración Stripe → PlaneaG TPV — Editorial Nazari

## Qué hace esta integración

Cuando un cliente compra un libro en la web de Editorial Nazari y paga con Stripe, el pedido aparece automáticamente en el TPV de PlaneaG con un badge naranja. Desde el TPV se puede gestionar el estado (pendiente → en preparación → enviado → completado).

---

## Paso 1 — Configurar el webhook en Stripe (una sola vez)

1. Entrar en el dashboard de Stripe de Editorial Nazari: https://dashboard.stripe.com
2. Ir a **Developers → Webhooks → Add endpoint**
3. URL del endpoint:
   ```
   https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhookTienda
   ```
4. Eventos a escuchar: `checkout.session.completed`
5. Copiar el **Signing secret** que aparece y guardarlo como variable de entorno en Firebase:
   ```bash
   firebase functions:secrets:set STRIPE_TIENDA_WEBHOOK_SECRET
   # (pegar el signing secret cuando lo pida)
   ```

---

## Paso 2 — Obtener el empresa_id de Editorial Nazari en PlaneaG

Es el ID del documento de Firestore. Se puede ver en la URL del panel de admin o en Firebase Console → Firestore → empresas → (seleccionar Nazari) → copiar el ID.

```
Ejemplo: abc123xyz789
```

---

## Paso 3 — Modificar la web de Editorial Nazari

En el código donde se crea el Stripe Checkout Session, añadir dos campos en `metadata`:

### Si la web es JavaScript/Node.js:

```javascript
const session = await stripe.checkout.sessions.create({
  // ... resto de parámetros existentes ...
  
  payment_method_types: ['card'],
  mode: 'payment',
  
  // ── AÑADIR ESTO ──────────────────────────────────────────────────
  metadata: {
    empresa_id: 'EMPRESA_ID_DE_NAZARI_EN_PLANEAG',  // ← poner el ID real
    tipo: 'pedido_tienda',
  },
  // ─────────────────────────────────────────────────────────────────
  
  // Para que PlaneaG pueda descontar el stock correcto,
  // añadir el catalogo_id de PlaneaG en los metadatos de cada producto:
  line_items: [
    {
      price_data: {
        currency: 'eur',
        product_data: {
          name: 'El nombre del libro',
          metadata: {
            catalogo_id: 'ID_DEL_PRODUCTO_EN_PLANEAG',  // ← ID del catálogo
          },
        },
        unit_amount: 1500, // precio en céntimos (15,00 €)
      },
      quantity: 1,
    },
  ],
  
  success_url: 'https://editorialnazari.com/gracias?session_id={CHECKOUT_SESSION_ID}',
  cancel_url: 'https://editorialnazari.com/tienda',
});
```

### Si la web usa PHP:

```php
$session = \Stripe\Checkout\Session::create([
  // ... resto de parámetros ...
  'metadata' => [
    'empresa_id' => 'EMPRESA_ID_DE_NAZARI_EN_PLANEAG',
    'tipo'       => 'pedido_tienda',
  ],
  'line_items' => [[
    'price_data' => [
      'currency' => 'eur',
      'product_data' => [
        'name'     => 'El nombre del libro',
        'metadata' => [
          'catalogo_id' => 'ID_DEL_PRODUCTO_EN_PLANEAG',
        ],
      ],
      'unit_amount' => 1500,
    ],
    'quantity' => 1,
  ]],
]);
```

### Si la web usa WooCommerce + plugin Stripe:

Muchos plugins de WooCommerce tienen hooks para añadir metadata. Buscar el filtro `woocommerce_stripe_checkout_session_metadata` o similar según el plugin.

---

## Paso 4 — Vincular productos del catálogo (para descuento de stock)

Para que el TPV descuente el stock automáticamente al llegar un pedido web, cada producto de Stripe necesita tener en su metadata el `catalogo_id` (el ID del documento en Firestore).

**Forma 1 (recomendada):** Añadir el campo directamente en los `product_data.metadata` del checkout session (ver ejemplo arriba).

**Forma 2:** En el dashboard de Stripe, editar cada producto y añadir un metadato `catalogo_id` con el ID del producto en PlaneaG.

Si no se vincula el catalogo_id, el stock NO se descuenta automáticamente pero el pedido SÍ llega al TPV correctamente.

---

## Cómo funciona una vez configurado

```
Cliente compra en web → Stripe procesa el pago
      ↓
Stripe llama al webhook de PlaneaG (stripeWebhookTienda)
      ↓
PlaneaG crea el pedido en Firestore con estado "pendiente"
PlaneaG descuenta el stock del catálogo
PlaneaG envía email de confirmación al cliente
      ↓
En el TPV de la tienda física aparece un badge 🟠 naranja
      ↓
El empleado hace clic → ve el pedido → lo marca "en preparación"
      ↓
Prepara el envío → lo marca "enviado"
      ↓
Pedido completado ✅
```

---

## Variables de entorno necesarias en functions/.env

```bash
STRIPE_SECRET_KEY=sk_live_xxxxx         # Clave secreta de la cuenta Stripe de Nazari
STRIPE_TIENDA_WEBHOOK_SECRET=whsec_xxx  # Signing secret del webhook de tienda
```

Si `STRIPE_TIENDA_WEBHOOK_SECRET` no está configurado, el sistema usa `STRIPE_WEBHOOK_SECRET` como fallback.

---

## Notas importantes

- El webhook valida la firma de Stripe para evitar pedidos falsos.
- Los eventos duplicados se ignoran automáticamente (idempotencia).
- Si el pago se realiza pero el webhook falla, Stripe reintenta automáticamente durante 3 días.
- El catálogo de PlaneaG y la web de Nazari son independientes — no hace falta migrar nada.
