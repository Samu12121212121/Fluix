# 🛒 Módulo de Pedidos en Explorar + APIs de Delivery (Glovo, etc.)

> **Fecha:** Mayo 2026  
> **Alcance:** Carnicerías, fruterías y cualquier negocio que requiera gestión de pedidos desde la app B2C (pantalla Explorar).

---

## 📌 Visión general

```
Cliente (Explorar)
    │
    ├── Ve negocio con 🛒 "Aceptamos pedidos"
    │
    ├── Entra en el catálogo de productos del negocio
    │
    ├── Añade al carrito → elige modalidad (recoger/entrega/...)
    │
    ├── Elige método de pago (configura el negocio)
    │
    └── Confirma pedido
             │
             ├── Firestore: pedidos/{id}  ← creado
             ├── Push notification → negocio recibe alerta
             └── (Opcional) Integración con Glovo/Stuart/etc.
```

---

## 🏗️ Fase 1 — Configuración del negocio (B2B)

### 1.1 Campos nuevos en `negocios_publicos` / `empresas`

```json
{
  "acepta_pedidos": true,
  "modalidades_pedido": ["recoger_en_tienda", "entrega_domicilio", "pedido_previo"],
  "metodos_pago_pedido": ["efectivo", "tarjeta", "bizum", "transferencia"],
  "tiempo_preparacion_min": 30,
  "radio_entrega_km": 5.0,
  "coste_envio": 2.50,
  "pedido_minimo": 10.00,
  "notas_pedido": "Pedidos mínimo con 2h de antelación",
  "delivery_externo": {
    "glovo_activo": false,
    "glovo_store_id": "",
    "stuart_activo": false,
    "stuart_api_key": ""
  }
}
```

### 1.2 Pantalla de configuración de pedidos (B2B)

Añadir una sección "Pedidos" en la configuración del negocio:

```dart
// lib/features/negocio_publico/pantallas/configuracion_pedidos_negocio_screen.dart

class ConfiguracionPedidosNegocioScreen extends StatefulWidget {
  final String empresaId;
  // ...
}
```

**Controles que debe tener:**
- `Switch` → Activar/desactivar pedidos online
- `MultiSelectChip` → Modalidades (Recoger, Domicilio, Pedido Previo, Mesa, etc.)
- `MultiSelectChip` → Métodos de pago aceptados
- `TextField` → Tiempo de preparación (minutos)
- `TextField` → Pedido mínimo (€)
- `TextField` → Coste de envío (€) 
- `TextField` → Radio de entrega (km)
- `TextField` → Notas para el cliente
- Botón → **Importar catálogo CSV**

### 1.3 Importar catálogo CSV

Ya existe `ImportacionCatalogoSheet` en la app. Solo hay que enlazarlo desde aquí.

**Formato CSV esperado:**
```csv
nombre,descripcion,categoria,precio,precio_oferta,iva_pct,activo,imagen_url
Chuletón de buey,Chuletón premium 300g,Vacuno,18.50,,10,true,
Lomo de cerdo,Lomo fresco por kilo,Porcino,9.90,7.50,10,true,
Pechuga de pollo,Pack 1kg,Aves,5.50,,10,true,
```

---

## 🏗️ Fase 2 — Pantalla Explorar (B2C)

### 2.1 Badge "Pedidos" en tarjeta del negocio

En `pantalla_explorar.dart`, añadir badge si `acepta_pedidos == true`:

```dart
// En la tarjeta del negocio
if (negocio.aceptaPedidos == true)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF1976D2),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_bag_outlined, size: 9, color: Colors.white),
        SizedBox(width: 3),
        Text('Pedidos', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    ),
  ),
```

### 2.2 Dentro del negocio (detalle_negocio_screen)

Si `acepta_pedidos == true`, mostrar tab o sección "Pedir":

```dart
Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Pedir'),
```

### 2.3 Pantalla catálogo cliente

```dart
// lib/features/reservas_cliente/pantallas/catalogo_cliente_screen.dart

class CatalogoClienteScreen extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final NegocioPublico negocio;
}
```

**UI:**
- Grid de productos por categoría
- Buscador
- Carrito flotante con total
- Al pulsar producto → modal con foto, descripción, cantidad, añadir al carrito

### 2.4 Carrito y checkout

```dart
// lib/features/reservas_cliente/pantallas/carrito_screen.dart

class CarritoScreen extends StatefulWidget {
  final String negocioId;
  final List<ItemCarrito> items;
  final NegocioPublico negocio;
}
```

**Pasos del checkout:**
1. Resumen de productos
2. Seleccionar modalidad (según `modalidades_pedido` del negocio)
3. Si entrega → dirección del cliente
4. Seleccionar método de pago (según `metodos_pago_pedido`)
5. Notas adicionales
6. Confirmar → crea documento en Firestore

---

## 🏗️ Fase 3 — Notificaciones al negocio

### 3.1 Cloud Function: `onNuevoPedidoCliente`

```typescript
// functions/src/pedidos/onNuevoPedidoCliente.ts

export const onNuevoPedidoCliente = functions.firestore
  .document('empresas/{empresaId}/pedidos/{pedidoId}')
  .onCreate(async (snap, context) => {
    const pedido = snap.data();
    const { empresaId } = context.params;

    // Obtener tokens FCM de los empleados/admin del negocio
    const usuarios = await admin.firestore()
      .collection('usuarios')
      .where('empresa_id', '==', empresaId)
      .where('activo', '==', true)
      .get();

    const tokens: string[] = [];
    for (const u of usuarios.docs) {
      const fcm = u.data().fcm_token;
      if (fcm) tokens.push(fcm);
    }

    if (tokens.length === 0) return;

    const total = (pedido.total ?? 0).toFixed(2);
    const modalidad = pedido.modalidad ?? 'recogida';
    const cliente = pedido.nombre_cliente ?? 'Cliente';

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: '🛒 Nuevo pedido recibido',
        body: `${cliente} • ${total}€ • ${modalidad}`,
      },
      data: {
        tipo: 'nuevo_pedido',
        pedido_id: snap.id,
        empresa_id: empresaId,
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  });
```

### 3.2 Token FCM en Flutter

Al hacer login, guardar/actualizar el token:

```dart
// lib/services/notificaciones_service.dart

Future<void> guardarTokenFCM(String uid) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;
  await FirebaseFirestore.instance
    .collection('usuarios')
    .doc(uid)
    .update({'fcm_token': token});
}
```

---

## 🏗️ Fase 4 — Pagos

### Opción A: Pago en negocio (efectivo/bizum/tarjeta física) — Sin integración

El pedido se crea con `estado_pago: 'pendiente'` y el negocio lo cobra al entregar.  
✅ Sin complejidad técnica. Válido para el 90% de los negocios locales.

### Opción B: Pago online con Stripe

```dart
// Requiere: stripe_payment flutter package + Cloud Functions

// 1. Cliente pulsa "Pagar ahora"
// 2. Cloud Function crea PaymentIntent en Stripe
// 3. Flutter abre Stripe Sheet
// 4. Al completar → actualiza pedido a estado_pago: 'pagado'
// 5. Cloud Function onPedidoCompletado genera factura (ya implementado)
```

**Recomendación:** Empezar con Opción A y añadir Stripe en v2.

---

## 🚚 Fase 5 — Integración APIs de Delivery

### 5.1 Glovo for Business (Glovo Partners API)

**¿Qué permite?**
- Publicar el catálogo del negocio en Glovo
- Recibir pedidos de Glovo en tu sistema
- Actualizar estado del pedido desde PlaneaG

**¿Cómo de difícil?** → **Medio-alto** ⚠️

| Aspecto | Detalle |
|---|---|
| Acceso | Requiere ser partner oficial de Glovo (contracto comercial) |
| API | REST + Webhooks. Documentación en `partners.glovoapp.com` |
| Autenticación | OAuth2 con `client_credentials` |
| Integración | ~2-3 semanas de desarrollo |
| Limitación | Solo disponible para restaurantes y ciertos sectores |

**Flujo con Glovo:**
```
Glovo recibe pedido del cliente
         │
         │ Webhook POST → Cloud Function nuestra
         │
         ▼
empresas/{id}/pedidos/{id}   ← se crea con origen: 'glovo'
         │
         │ Negocio acepta/rechaza desde PlaneaG
         │
         ▼
PUT /orders/{orderId}/status → API Glovo   ← actualizamos estado
```

**Cloud Function webhook Glovo:**
```typescript
export const webhookGlovo = functions.https.onRequest(async (req, res) => {
  // Verificar firma HMAC-SHA256 del header X-Glovo-Signature
  const firma = req.headers['x-glovo-signature'];
  const cuerpo = JSON.stringify(req.body);
  const firmaEsperada = crypto
    .createHmac('sha256', process.env.GLOVO_WEBHOOK_SECRET!)
    .update(cuerpo)
    .digest('hex');
  
  if (firma !== firmaEsperada) {
    res.status(401).send('Firma inválida');
    return;
  }

  const evento = req.body;
  if (evento.type === 'ORDER_CREATED') {
    const order = evento.data;
    // Mapear pedido Glovo → estructura PlaneaG
    const empresaId = await obtenerEmpresaPorGlovoStoreId(order.store_id);
    await admin.firestore()
      .collection('empresas').doc(empresaId)
      .collection('pedidos').add({
        origen: 'glovo',
        glovo_order_id: order.order_id,
        nombre_cliente: order.customer.name,
        lineas: order.products.map(p => ({
          nombre: p.name,
          cantidad: p.quantity,
          precio_unitario: p.price / 100,
        })),
        total: order.total_price / 100,
        modalidad: 'entrega_domicilio',
        estado: 'pendiente',
        fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
  res.status(200).send('OK');
});
```

---

### 5.2 Stuart (delivery on-demand — repartidores)

**¿Qué es?** API para contratar repartidores bajo demanda (como un Glovo interno para el negocio).

**¿Cómo de difícil?** → **Medio** ✅

| Aspecto | Detalle |
|---|---|
| Acceso | Registro en `stuart.com/api` — sin contrato comercial obligatorio |
| API | REST bien documentada |
| Precio | El negocio paga por entrega (~3-8€ según distancia) |
| Uso ideal | Carnicerías/fruterías que hacen reparto propio pero quieren externalizarlo |

```typescript
// Crear job de entrega en Stuart cuando negocio acepta pedido
async function crearEnvioStuart(pedido: Pedido) {
  const response = await fetch('https://api.stuart.com/v2/jobs', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.STUART_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      job: {
        pickups: [{
          address: pedido.direccion_negocio,
          comment: `Pedido PlaneaG #${pedido.id}`,
        }],
        dropoffs: [{
          address: pedido.direccion_cliente,
          contact: {
            firstname: pedido.nombre_cliente,
            phone: pedido.telefono_cliente,
          },
          package_type: 'small',
        }],
      }
    })
  });
  return response.json();
}
```

---

### 5.3 Comparativa APIs de Delivery

| API | Dificultad | Coste | Sectores | Recomendación |
|---|---|---|---|---|
| **Glovo Partners** | Alta | Comisión % | Restaurantes principalmente | V2 si hay volumen |
| **Stuart** | Media | Por entrega | Cualquiera | ✅ Empezar aquí |
| **Uber Eats API** | Alta | Comisión % | Restaurantes | No prioritario |
| **Deliveroo** | Alta | Comisión % | Restaurantes | No disponible en todos los países |
| **Propio repartidor** | Baja | 0 | Cualquiera | ✅ Para empezar (Modalidad A) |

**Recomendación para PlaneaG:**
1. **Fase 1:** Solo modalidades propias (el negocio hace el reparto o el cliente recoge)
2. **Fase 2:** Stuart para reparto bajo demanda  
3. **Fase 3:** Glovo si los negocios lo solicitan y tienen volumen

---

## 📊 Estructura Firestore del Pedido Cliente

```json
{
  "origen": "planeag_b2c",
  "negocio_id": "abc123",
  "empresa_id": "abc123",
  "usuario_uid": "usr456",
  "nombre_cliente": "Ana López",
  "telefono_cliente": "+34612345678",
  "modalidad": "recoger_en_tienda",
  "direccion_entrega": null,
  "metodo_pago": "efectivo",
  "lineas": [
    {
      "producto_id": "prod1",
      "nombre": "Chuletón de buey",
      "cantidad": 2,
      "precio_unitario": 18.50,
      "iva_pct": 10,
      "subtotal": 37.00
    }
  ],
  "subtotal": 37.00,
  "coste_envio": 0,
  "total": 37.00,
  "notas": "Sin sal por favor",
  "estado": "pendiente",
  "estado_pago": "pendiente_en_negocio",
  "fecha_creacion": "Timestamp",
  "fecha_estimada_lista": "Timestamp"
}
```

---

## ✅ Checklist de implementación

### Sprint 1 — Configuración B2B
- [ ] Añadir campos `acepta_pedidos`, `modalidades_pedido`, `metodos_pago_pedido` al modelo `NegocioPublico`
- [ ] Crear `ConfiguracionPedidosNegocioScreen`  
- [ ] Enlazar importación CSV desde configuración de pedidos

### Sprint 2 — Explorar B2C  
- [ ] Badge "Pedidos" en tarjeta de negocio en Explorar
- [ ] Tab "Pedir" en detalle del negocio
- [ ] `CatalogoClienteScreen` — grid de productos con carrito
- [ ] `CarritoScreen` — checkout, modalidad, pago

### Sprint 3 — Notificaciones
- [ ] Cloud Function `onNuevoPedidoCliente`
- [ ] Guardar token FCM al login
- [ ] Pantalla de gestión de pedidos en B2B con estados

### Sprint 4 — Delivery (opcional)
- [ ] Integrar Stuart API
- [ ] Webhook Glovo (si hay demanda)
- [ ] Estado del pedido en tiempo real para el cliente

