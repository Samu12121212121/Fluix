# 📊 Análisis Explorar + Integración TPV
> PlaneaG / Fluix CRM — Versión 2026-05-18

---

## PARTE 1 — Pantalla Explorar: Completitud y Mejoras

### Puntuación global: **7.5 / 10**

| Bloque | Estado | Nota | Puntos de mejora |
|---|---|---|---|
| AppBar (logo Fluix + notificaciones) | ✅ Completo | 10/10 | — |
| Saludo dinámico (buenos días/tardes/noches) | ✅ Completo | 10/10 | — |
| Chips de categorías + chip Tendencias🔥 | ✅ Completo | 10/10 | — |
| Flash Slots (carrusel + countdown + reserva) | ✅ Completo | 9/10 | Añadir notif push cuando quedan <10 min |
| Ofertas especiales (carrusel horizontal) | ✅ Completo | 9/10 | Diferenciar tipos de oferta (% vs precio fijo) |
| Recomendados (filtro rating ≥ 4.0) | ⚠️ Parcial | 6/10 | **Orden hardcoded**, sin ponderación real |
| Cerca de ti | ⚠️ Falso | 4/10 | **Geolocalización falsa** ("Guadalajara · centro") |
| Grid de negocios (2 columnas) | ✅ Completo | 9/10 | — |
| Botón corazón animado (favoritos) | ✅ Completo | 10/10 | — |
| Tab Buscar | ⚠️ Parcial | 7/10 | **Búsqueda client-side**, sin índice |
| Tab Favoritos | ✅ Completo | 9/10 | — |
| Tab Perfil cliente | ✅ Completo | 8/10 | — |
| Switch empresa ↔ usuario | ✅ Completo | 10/10 | — |
| Ver todo (PantallaListadoCompleto) | ✅ Completo | 8/10 | Sin infinite scroll |
| Skeleton loaders | ❌ Ausente | 0/10 | Paquete `shimmer` ya instalado |
| Geolocalización real | ❌ Ausente | 0/10 | Paquete `geolocator` ya instalado |
| Filtros avanzados (precio, horario, radio) | ❌ Ausente | 0/10 | Requiere nuevo Widget |
| Estado "Abierto ahora" | ❌ Ausente | 0/10 | Simple comparativa de horario |

---

### 🚀 Mejoras priorizadas

#### 🔴 Alta prioridad (diferencial de producto)

**1. Geolocalización real — "Cerca de ti"**
```dart
// Usar geolocator (ya en pubspec) para obtener la posición actual
// Guardar GeoPoint en Firestore por cada negocio
// Calcular distancia con la fórmula de Haversine o índice geohash
final position = await Geolocator.getCurrentPosition();
// Luego filtrar negocios por radio (ej. 5 km)
```
Impacto: ⭐⭐⭐⭐⭐ — Diferenciador clave frente a competidores.

**2. Skeleton Loaders mientras carga**
```dart
// El paquete shimmer YA está instalado
import 'package:shimmer/shimmer.dart';

// Reemplazar los SizedBox.shrink() por:
Shimmer.fromColors(
  baseColor: Color(0xFF1E2139),
  highlightColor: Color(0xFF2A2E45),
  child: Container(width: 140, height: 175, decoration: BoxDecoration(...)),
);
```
Impacto: ⭐⭐⭐⭐ — Percepción de velocidad de carga mucho mejor.

**3. Estado "Abierto ahora"**
```dart
// Añadir campo horario al modelo NegocioPublico
// { "lunes": {"apertura": "09:00", "cierre": "20:00"}, ... }
bool _estaAbiertoAhora(Map<String, dynamic> horario) {
  final ahora = TimeOfDay.now();
  final diaActual = DateFormat('EEEE', 'es').format(DateTime.now());
  final rango = horario[diaActual.toLowerCase()];
  if (rango == null) return false;
  // Comparar ahora entre apertura y cierre
}
// Mostrar badge verde "Abierto" / rojo "Cerrado" en las tarjetas
```
Impacto: ⭐⭐⭐⭐ — Los usuarios buscan negocios abiertos ahora mismo.

#### 🟡 Media prioridad

**4. Búsqueda con índice (Algolia / Typesense)**
- Actualmente la búsqueda descarga TODOS los negocios y filtra en cliente.
- Con 100+ negocios esto es ineficiente.
- **Solución rápida**: usar `where('nombre_lower', isGreaterThanOrEqualTo: query)` en Firestore (requiere campo `nombre_lower` normalizado).

**5. Filtros avanzados (panel deslizante)**
```
Panel inferior con:
├── Rango de precio: slider €
├── Valoración mínima: 1★ a 5★  
├── Radio de distancia: 1km / 5km / 10km
└── Horario: "Abierto ahora" toggle
```

**6. Reserva rápida desde tarjeta**
- Botón "Reservar" visible en la tarjeta grid.
- Abre bottom sheet con selección de fecha/hora directa.
- Sin necesidad de entrar a la pantalla de detalle.

**7. Imágenes múltiples por negocio**
- Añadir campo `fotosUrls: List<String>` al modelo.
- Galería deslizable dentro de la tarjeta de detalle.

#### 🟢 Baja prioridad (diferenciadores premium)

**8. Mapa integrado**
- `google_maps_flutter` o `flutter_map` (OSM, gratuito).
- Pines de negocios en el mapa, tappables.
- Tab adicional "Mapa" en la barra inferior.

**9. Recomendaciones personalizadas**
- Cloud Function que analiza el historial de reservas del usuario.
- Devuelve IDs de negocios recomendados.
- Sección "Para ti" en la pantalla de explorar.

**10. Infinite scroll / paginación**
```dart
// Usar startAfterDocument para cargar más
Query q = FirebaseFirestore.instance
    .collection('negocios_publicos')
    .orderBy('ratingGoogle', descending: true)
    .limit(20);
// Al scroll to bottom: q.startAfterDocument(ultimoDoc).get()
```

**11. Pull to refresh**
```dart
RefreshIndicator(
  color: Color(0xFF00FFC8),
  onRefresh: () async => setState(() {}),
  child: CustomScrollView(...)
)
```

---

## PARTE 2 — Integración TPV: Datáfono, Impresora y Ticket

---

### 2A. 🖨️ Impresora Bluetooth — YA INTEGRADA

El servicio real `ImpressoraBluetooth` está en:
```
lib/services/tpv/impresora_bluetooth_service.dart
```

**Paquete**: `blue_thermal_printer: ^1.0.9` (ya en pubspec.yaml)

#### Cómo vincular la impresora (paso a paso en el móvil)

```
1. En el móvil Android: Ajustes → Bluetooth → activar
2. Emparejar la impresora térmica (aparece como "POS-58" o similar)
3. Abrir el TPV Peluquería
4. Tocar el icono 🖨️ en la barra superior derecha (ahora es tappable)
5. Se abre el diálogo "Impresora Bluetooth"
6. Selecciona tu impresora de la lista → pulsar "Conectar"
7. El icono se vuelve cian ✅
8. Al cobrar cualquier ticket → se imprime automáticamente
9. Botón "Test" para imprimir una hoja de prueba
```

#### Impresoras térmicas 58mm compatibles (España)

| Modelo | Precio aprox | BT | Corte auto |
|---|---|---|---|
| Xprinter XP-P300B | ~40€ | ✅ | ✅ |
| GOOJPRT PT-210 | ~35€ | ✅ | ❌ |
| Sewoo LK-P41 | ~120€ | ✅ | ✅ |
| EPSON TM-m30 | ~250€ | ✅ | ✅ |
| Star TSP143IIIU | ~220€ | ✅ | ✅ |

#### Permisos Android necesarios (ya deben estar en AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
```

Si no están, añadir en `android/app/src/main/AndroidManifest.xml` antes de `<application>`.

---

### 2B. 🧾 Formato del Ticket (ya implementado)

El ticket que imprime `imprimirTicket()` tiene el siguiente formato ESC/POS:

```
================================
        NOMBRE EMPRESA
================================

Ticket nº 000042
dd/MM/yyyy HH:mm
--------------------------------
Corte degradé
  1 x 25,00 € = 25,00 €
Tinte raíces
  1 x 35,00 € = 35,00 €
--------------------------------
        TOTAL: 60,00 €
        Pago: tarjeta

¡Gracias por su compra!


[corte de papel]
```

#### Para personalizar el ticket — editar el método en el servicio:

```
lib/services/tpv/impresora_bluetooth_service.dart
→ método imprimirTicket(TicketData ticket)
```

##### Personalización posible:
- Añadir logo en texto ASCII al inicio
- Añadir dirección del negocio (cargar desde Firestore en `empresas/{id}`)
- QR de valoración (url de Google Reviews)
- NIF/CIF de la empresa para tickets fiscales
- Pie de página personalizado ("Síguenos en Instagram: @...")

#### Estructura del TicketData (qué campos puedes pasar)

```dart
TicketData(
  nombreEmpresa: 'Mi Peluquería',   // Cargado de Firestore auto
  numeroTicket: 42,                  // Auto-incrementado en Firestore
  fecha: DateTime.now(),             // Automático
  lineas: [                          // Las líneas del ticket actual
    LineaTicket(nombre: 'Corte', cantidad: 1, precioUnitario: 25.0),
  ],
  total: 25.0,                       // Calculado automáticamente
  metodoPago: 'efectivo',            // Del diálogo de cobro
)
```

---

### 2C. 💳 Datáfono (cobro con tarjeta física)

#### Opción recomendada para España: **SumUp**

**¿Por qué SumUp?**
- El más usado en peluquerías y pequeño comercio en España
- Comisión: 1,69% por transacción (sin cuota mensual)
- SDK oficial para Android/iOS
- Datáfono SumUp Air desde ~39€ (compra única)
- Se conecta por Bluetooth al móvil

#### Integración Flutter con SumUp

```yaml
# pubspec.yaml — AÑADIR:
dependencies:
  sumup_sdk_flutter: ^1.0.0  # O usar Platform Channel manual
```

```dart
// En _TpvPeluqueriaState._cobrar()
// Cuando el método de pago es 'tarjeta':

import 'package:sumup_sdk_flutter/sumup_sdk_flutter.dart';

// 1. Inicializar (una sola vez, en initState)
await SumupSdkFlutter.init('TU_AFFILIATE_KEY');  // Del portal SumUp
await SumupSdkFlutter.login();  // Primera vez pide credenciales SumUp

// 2. Al cobrar con tarjeta:
final result = await SumupSdkFlutter.checkout(
  total: _total,          // Importe en EUR
  currency: 'EUR',
  title: 'Ticket #$numTicket',
  receiptEmail: '',       // Opcional: enviar recibo por email
  receiptSMS: '',         // Opcional: enviar recibo por SMS
);

if (result.success) {
  // Pago OK → guardar en Firestore + imprimir ticket
  final transactionCode = result.transactionCode;
  // Guardar transactionCode en el pedido de Firestore para trazabilidad
}
```

#### Cómo obtener tu Affiliate Key SumUp

```
1. Crear cuenta en sumup.com como negocio
2. Portal → Developers → Affiliate Keys
3. Crear nueva key → copiar el valor
4. Esa key va en SumupSdkFlutter.init('TU_KEY')
```

#### Alternativa: **Stripe Terminal** (más control, más complejo)

```yaml
dependencies:
  stripe_terminal: ^3.0.0
```

Ventajas: más flexible, control total de la UI de pago, soporta terminales físicos Stripe (BBPOS, Verifone).

Desventajas: más caro de configurar, requiere backend para `connection_token`.

#### Alternativa económica: **iZettle / Zettle by PayPal**

Funciona igual que SumUp pero es de PayPal. Bien integrado con PayPal Business.

---

### 2D. 📋 Flujo completo de cobro en el TPV (estado actual)

```
Usuario pulsa "Cobrar"
        │
        ▼
Diálogo _DialogoPago
  ├── Método: Efectivo → calcular cambio
  ├── Método: Tarjeta → [PRÓXIMO: llamar SumUp SDK]
  └── Método: Mixto   → split efectivo + tarjeta
        │
        ▼
Transacción Firestore (atómica)
  ├── Incrementar contador de tickets
  ├── Crear pedido en empresas/{id}/pedidos
  └── Si facturación automática → crear factura
        │
        ▼
ImpressoraBluetooth.imprimirTicket()
  ├── Si conectada → imprime ticket ESC/POS
  └── Si no conectada → muestra aviso (sin bloquear)
        │
        ▼
SnackBar confirmación + limpiar ticket
```

---

### 2E. 🔧 Qué necesitas hacer en el dispositivo propietario

```
CONFIGURACIÓN INICIAL (una sola vez):

1. IMPRESORA:
   Android Ajustes → Bluetooth → Activar
   → Buscar dispositivos → Seleccionar tu impresora
   → Emparejar (PIN suele ser 0000 o 1234)
   → Abrir TPV → icono 🖨️ → seleccionar → "Conectar"
   → La app recuerda la última impresora automáticamente

2. DATÁFONO SUMUP (cuando se implemente):
   → Descargar app SumUp del propietario para crear cuenta
   → Comprar datáfono SumUp Air (~39€)
   → Emparejar datáfono por Bluetooth igual que la impresora
   → Primera vez: SumupSdkFlutter.login() abre webview con login SumUp

3. PERMISOS en Android (primera vez que se abre el TPV):
   → La app pedirá permiso de Bluetooth → Aceptar
   → La app pedirá acceso a ubicación (necesario para BT en Android 12+) → Aceptar
```

---

### 2F. 🏗️ Archivos relevantes del TPV

| Archivo | Propósito |
|---|---|
| `lib/features/tpv/pantallas/tpv_peluqueria_screen.dart` | Pantalla principal del TPV peluquería |
| `lib/services/tpv/impresora_bluetooth_service.dart` | Servicio real de impresora BT (ya implementado) |
| `lib/services/tpv/cierre_caja_service.dart` | Cierre de caja diario |
| `lib/services/pedidos_service.dart` | Creación y gestión de pedidos |
| `lib/services/tpv_facturacion_service.dart` | Facturación automática al cobrar |
| `lib/domain/modelos/pedido.dart` | Modelo de pedido con líneas |

---

### 2G. 🔜 Próximos pasos TPV

- [ ] **Instalar SumUp SDK** y conectar al botón "Tarjeta" del diálogo de pago
- [ ] **Añadir logo/dirección** al ticket (leer de Firestore al imprimir)
- [ ] **Añadir QR** en el ticket — URL de Google Reviews para solicitar valoración
- [ ] **Añadir NIF/CIF** al ticket para uso como justificante fiscal simple
- [ ] **Envío de ticket por WhatsApp/Email** — alternativa digital al papel
- [ ] **Test de impresión** desde la pantalla de configuración de la empresa

---

*Documento generado automáticamente por GitHub Copilot — PlaneaG/FluixCRM 2026*

