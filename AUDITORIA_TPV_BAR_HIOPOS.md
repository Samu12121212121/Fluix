# 🧾 Auditoría Técnica TPV — PlaneaGuada / FluixCRM
### Análisis de viabilidad: TPV para bares similar a HIOPOS

> **Versión analizada:** `1.0.15` · Dart SDK `^3.11.1` · Firebase (Firestore, Functions v2, Storage)
> **Fecha de análisis:** Mayo 2026

---

## 1. 🏗️ Arquitectura Actual del Módulo TPV

```
features/tpv/pantallas/
  ├── modulo_tpv_screen.dart               ← Hub principal
  ├── caja_rapida_screen.dart              ← TPV activo (venta directa)
  ├── pantalla_cierre_caja.dart            ← Cierre diario + historial
  ├── facturar_pedidos_screen.dart         ← Facturación manual batch
  ├── configuracion_facturacion_tpv_screen.dart
  ├── importar_ventas_csv_screen.dart      ← Importación CSV (Glop, etc.)
  └── historial_importaciones_screen.dart

services/tpv/
  ├── cierre_caja_service.dart
  └── impresora_bluetooth_service.dart

services/
  ├── pedidos_service.dart                 ← CRUD productos + pedidos
  └── tpv_facturacion_service.dart         ← 3 modos de facturación

domain/modelos/
  ├── pedido.dart                          ← Producto, LineaPedido, Pedido, enums
  ├── cierre_caja.dart
  ├── importacion_tpv.dart
  └── configuracion_facturacion_tpv.dart
```

---

## 2. ✅ LO QUE YA ESTÁ IMPLEMENTADO

### 2.1 Caja Rápida (`CajaRapidaScreen`)

| Feature | Estado | Notas |
|---|---|---|
| Catálogo visual en grid | ✅ | `StreamBuilder`, grid con `maxCrossAxisExtent: 160` |
| Filtro por categoría | ✅ | `Stream<List<String>>` via `categoriasStream()` |
| Búsqueda por nombre | ✅ | Filtro local sobre el stream |
| Imágenes en tarjetas | ✅ | `thumbnailUrl` (Cloud Function) o `imagenUrl` fallback |
| Ticket lateral / tabs | ✅ | Layout adaptativo: `≥600px` split; `<600px` tabs |
| Añadir / quitar unidades | ✅ | +/- iconos, badge de cantidad en tarjeta |
| Método de pago (Efectivo / Tarjeta / Mixto) | ✅ | Chips de pago con validación |
| Cálculo de cambio | ✅ | Campo "Entrega cliente" — cambio en tiempo real |
| Creación de pedido en Firestore | ✅ | `PedidosService.crearPedido()` con origen `presencial` |
| Marca automática como pagado/entregado | ✅ | `cambiarEstado` + `cambiarEstadoPago` |
| Generación de ticket de texto | ✅ | `_generarTicketTexto()` con formato tabular |
| Compartir ticket por `share_plus` | ✅ | Share por WhatsApp/Email |
| Confirmar cobro con diálogo | ✅ | Muestra total, método y cambio |
| Limpiar ticket con confirmación | ✅ | |

### 2.2 Cierre de Caja

| Feature | Estado |
|---|---|
| Cálculo automático del día | ✅ Query Firestore: `estado_pago == 'pagado'` en rango día |
| Desglose efectivo / tarjeta / transferencia | ✅ |
| Guarda en `cierres_caja/{yyyy-MM-dd}` | ✅ ID único por fecha, impide duplicados |
| Impide doble cierre el mismo día | ✅ |
| Historial últimos 30 cierres | ✅ |
| Impresión BT del cierre | ✅ `ImpressoraBluetooth.imprimirCierreCaja()` integrado |

### 2.3 Impresora Bluetooth Térmica

| Feature | Estado |
|---|---|
| Escanear + conectar dispositivos vinculados | ✅ |
| Reconexión automática al último dispositivo | ✅ Guardado en `SharedPreferences` |
| `imprimirTicket(TicketData)` | ✅ Modelo normalizado con lineas, total, método |
| `imprimirCierreCaja(CierreCaja)` | ✅ Desglose por método + paperCut |
| `BotonImprimirWidget` | ✅ Botón inteligente: sin conexión → selector BT |

### 2.4 Modelo de Dominio — Catálogo

El modelo `Producto` ya tiene campos hosteleros:
```dart
final double ivaPorcentaje;        // 10% para F&B (campo existe, no se usa en caja)
final bool tieneVariantes;         // ej: Caña / Jarra / Litro
final List<VarianteProducto> variantes; // precio propio por variante
final String? codigoBarras;        // sin UI de escaneo aún
final List<String> etiquetas;      // para agrupar ("popular", "sin gluten")
```

### 2.5 Facturación TPV (`TpvFacturacionService`)

| Modo | Implementación |
|---|---|
| `porVenta` | Factura por pedido individual |
| `resumenDiario` | Agrupa el día; Cloud Function cron nocturna |
| `manual` | `FacturarPedidosScreen` batch |

La Cloud Function `generarFacturasResumenTpv` (cron `30 23 * * * Europe/Madrid`) genera facturas batch automáticas. VeriFactu habilitables por toggle.

### 2.6 Importación CSV

- Wizard 4 pasos: instrucciones → selección → mapeo → preview → importar
- Auto-detección separador y encoding (UTF-8 / Latin-1)
- Formatos: Glop, Agora, ICG, Excel export, extracto bancario
- Historial con opción de deshacer

### 2.7 Paquetes ya disponibles para TPV de bar

| Package | Versión | Uso |
|---|---|---|
| `blue_thermal_printer` | ^1.0.9 | Impresora BT térmica ✅ |
| `fl_chart` | ^0.69.0 | Gráficas de ventas en cierre |
| `file_picker` + `csv` | | Importación CSV ✅ |
| `share_plus` | ^10.1.4 | Compartir ticket ✅ |
| `qr_flutter` | ^4.1.0 | QR en tickets (pendiente en TPV) |
| `sqflite` | ^2.4.0 | **En pubspec, SIN USAR en TPV** |
| `connectivity_plus` | ^6.0.5 | **En pubspec, SIN USAR en TPV** |
| `pdf` + `printing` | | Z-Report PDF exportable |

---

## 3. ❌ GAPS CRÍTICOS vs. HIOPOS

### 3.1 🚨 Bloqueantes — Sin estos no es un TPV de bar real

#### A) NO existe Gestión de Mesas
No hay ningún concepto de `mesa`, `zona`, `sala` en el código ni en Firestore. HIOPOS centra toda la operativa en esto: sin mesas no hay comandas abiertas, ni transferencia, ni cobro al final de la noche.

**Solución:** Nueva subcolección:
```json
"empresas/{id}/mesas/{mesaId}": {
  "numero": 1,
  "nombre": "Mesa 5",
  "zona": "Terraza",
  "estado": "libre | ocupada | reservada",
  "comanda_id": null,
  "num_comensales": 0,
  "camarero_uid": null
}
```

#### B) NO existe "Comanda Abierta" (Tab)
`CajaRapidaScreen._cobrar()` crea un pedido y lo marca `entregado + pagado` en el mismo acto. No hay forma de abrir una cuenta, añadir rondas y cerrar al final.

**Solución:** Separar `comanda` (abierta, mutable) de `pedido` (cerrado, fiscal):
```
Comanda (viva)          →   Pedido (fiscal)
─────────────────           ──────────────
Estado: abierta             Estado: entregado
En: comandas/               En: pedidos/
Referencia a mesa_id        Referencia a factura_id
Editable: sí                Editable: no
```

#### C) BT ticket NO conectado a Caja Rápida
`imprimirTicket()` existe y está completo, pero `CajaRapidaScreen` solo llama a `Share.share()`. Un bar no puede dar ticket físico al cliente al cobrar.

**Fix puntual (1 día):** En `_mostrarDialogoExito()`, añadir `BotonImprimirWidget` que llame a `ImpressoraBluetooth().imprimirTicket(TicketData(...))`.

#### D) Ticket sin datos legales de empresa
`_generarTicketTexto()` escribe `'FLUIX CRM — TICKET'` hardcoded. Un ticket fiscal español debe incluir nombre comercial, NIF/CIF y dirección.

**Fix:** Pasar `EmpresaConfig` (ya existe) a `CajaRapidaScreen` y usarlo en el ticket.

### 3.2 ⚠️ Deficiencias Importantes

#### E) IVA no se transfiere en Caja Rápida
```dart
// CajaRapidaScreen._cobrar() — bug:
LineaPedido(
  precioUnitario: l.precioUnitario,
  // ❌ ivaPorcentaje no se pasa → default 21%
  // correcto para bar: 10% bebidas
)
```
`_LineaTicket` local no almacena `ivaPorcentaje`. Genera facturas fiscalmente incorrectas.

#### F) Sin selector de variante en Caja Rápida
Si un producto tiene variantes (Caña/Jarra), al tocar la tarjeta añade el precio base directamente sin preguntar. `VarianteSelectorWidget` ya existe en `lib/features/pedidos/widgets/` pero no se usa desde Caja Rápida.

#### G) Sin número de ticket secuencial
`TicketData.numeroTicket` recibe un `int`, pero nada lo genera. Se usa `pedidoId.substring(0,8)`.

**Fix:** Contador atómico `empresas/{id}/contadores/tickets` con `FieldValue.increment(1)` en transacción.

#### H) Sin descuentos
No existe campo `descuento` en `_LineaTicket`, `LineaPedido`, ni `Pedido`. Cero lógica de descuento.

#### I) Cierre mixto incorrecto
```dart
// CierreCajaService — bug:
case 'mixto':
  totalEfectivo += total / 2;  // ❌ Hardcoded 50/50
  totalTarjeta  += total / 2;
```
`Pedido` no almacena `importeEfectivo`/`importeTarjeta` para pagos mixtos.

#### J) Sin decremento de stock al vender
`PedidosService.crearPedido()` no decrementa stock. Para un bar con productos de cocina o almacén de botellas esto es un gap.

#### K) Cierre de caja sin análisis
Solo muestra totales por método de pago. Faltan:
- Ventas por categoría
- Top productos del día
- Comparativa vs. ayer / promedio semana
- Exportar Z-Report a PDF (`pdf` package ya disponible)
- Gráfico de ventas por hora (`fl_chart` ya disponible)

#### L) Sin notas por línea en Caja Rápida
`LineaPedido.notasLinea` existe en el modelo pero no hay campo de entrada en la UI. Crítico para un bar: "sin hielo", "al punto", "alérgico a frutos secos".

#### M) Sin modo Offline
`sqflite` y `connectivity_plus` están en `pubspec.yaml` pero no se usan. En hostelería la conexión cae y la caja debe seguir operativa.

---

## 4. 📊 Comparativa Completa vs. HIOPOS

| Feature HIOPOS | Estado FluixCRM | Prioridad |
|---|---|---|
| Plano de mesas interactivo | ❌ No existe | 🔴 Alta |
| Comandas abiertas por mesa | ❌ No existe | 🔴 Alta |
| Transferencia de mesa | ❌ No existe | 🔴 Alta |
| Impresión de comanda a cocina | ❌ No existe | 🔴 Alta |
| Routing multi-impresora (bar/cocina) | ❌ No existe | 🔴 Alta |
| BT ticket desde cobro en Caja Rápida | ⚠️ Servicio OK, sin conectar | 🔴 Alta |
| Datos empresa en ticket | ⚠️ Hardcoded "FLUIX CRM" | 🔴 Alta |
| IVA correcto (10%) en caja | ⚠️ Default 21% | 🔴 Alta |
| Variantes en Caja Rápida | ⚠️ Modelo OK, UI ausente | 🔴 Alta |
| Número de ticket secuencial | ⚠️ Campo en BT modelo, sin contador | 🟠 Media-Alta |
| Descuentos por línea/ticket | ❌ No existe | 🟠 Media |
| Notas por línea en Caja Rápida | ⚠️ Modelo OK, UI ausente | 🟠 Media |
| Reparto mixto real en cierre | ⚠️ Hardcoded 50/50 | 🟠 Media |
| Decremento de stock | ❌ No existe | 🟠 Media |
| Z-Report PDF exportable | ❌ No existe | 🟡 Baja-Media |
| División de cuenta | ❌ No existe | 🟡 Baja |
| Propina / tip | ❌ No existe | 🟡 Baja |
| Cuenta en espera / parked sale | ❌ No existe | 🟡 Baja |
| Escáner código de barras | ⚠️ Campo modelo OK, sin UI | 🟡 Baja |
| WiFi / IP printer support | ❌ Solo BT | 🟡 Baja |
| KDS (Kitchen Display System) | ❌ No existe | 🟡 Baja |
| Modo offline + sync | ❌ sqflite sin usar | 🟡 Baja |

---

## 5. 🔧 Arquitectura Firestore Ampliada para Bar

```
empresas/{id}/
  ├── catalogo/{productoId}        ← ya existe
  ├── pedidos/{pedidoId}           ← ya existe
  │     + importe_efectivo: double?  ← AÑADIR para mixto real
  │     + importe_tarjeta: double?
  │     + numero_ticket: int          ← AÑADIR
  │     + descuento_total: double?    ← AÑADIR
  │
  ├── mesas/{mesaId}               ← NUEVO
  │     numero, nombre, zona
  │     estado: libre|ocupada|reservada
  │     comanda_id, camarero_uid
  │
  ├── comandas/{comandaId}         ← NUEVO (tab abierto)
  │     mesa_id, camarero_uid
  │     lineas: [{ productoId, nombre, cantidad, precio, notas }]
  │     estado: abierta|cobrada
  │     apertura: Timestamp
  │
  ├── contadores/tickets           ← NUEVO (autoincrement)
  │     ultimo_numero: 0
  │
  ├── cierres_caja/{yyyy-MM-dd}   ← ya existe
  │     + desglose_categorias: map  ← AÑADIR
  │
  └── impresoras/{impresoraId}    ← NUEVO (routing multi-impresora)
        alias, tipo: bt|wifi|ip
        mac_address | ip_address: string
        destinos: [cocina, barra, sala]
```

**Reglas Firestore a añadir:**
```javascript
match /empresas/{id}/mesas/{mesaId} {
  allow read, write: if esStaffOSuperior(id);
}
match /empresas/{id}/comandas/{comandaId} {
  allow read, write: if esStaffOSuperior(id);
}
match /empresas/{id}/contadores/{doc} {
  allow read, write: if esStaffOSuperior(id);
}
```

---

## 6. 🗺️ Roadmap de Implementación

### FASE 0 — Correcciones Críticas (≈ 3-4 días)
*Hacen el TPV actual correcto para venta directa de barra:*

| # | Tarea | Tiempo |
|---|---|---|
| 1 | Conectar BT ticket al cobro en `_mostrarDialogoExito()` | 1 día |
| 2 | `_LineaTicket` hereda `ivaPorcentaje` desde `Producto.ivaPorcentaje` | ½ día |
| 3 | Datos empresa (`nombre`, `nif`, `dirección`) en `_generarTicketTexto()` | ½ día |
| 4 | Selector de variante en `_agregarProducto()` via `VarianteSelectorWidget` | 1 día |
| 5 | Notas por línea (`notasLinea`) en `_filaTicket()` | ½ día |

> ✅ Con Fase 0 el TPV de barra directa ya es operativo y fiscalmente correcto.

### FASE 1 — TPV de Barra Completo (≈ 2 semanas)

| # | Tarea | Tiempo |
|---|---|---|
| 6 | Contador secuencial de tickets (`contadores/tickets`) | 1 día |
| 7 | Descuentos por línea y por total | 1 día |
| 8 | Reparto mixto real (`importeEfectivo`/`importeTarjeta` en `Pedido`) | 1.5 días |
| 9 | Decremento de stock en transacción al crear pedido | 1 día |
| 10 | Cierre de caja: desglose por categoría + PDF + gráfico horas | 3 días |
| 11 | Escáner de código de barras (`mobile_scanner` package) | 2 días |

### FASE 2 — Módulo de Mesas (≈ 3-4 semanas)

| # | Tarea | Tiempo |
|---|---|---|
| 12 | Colecciones `mesas` + `comandas` Firestore con reglas e índices | 2 días |
| 13 | Plano de Mesas UI — `GridView` con tarjetas con badge de importe | 4 días |
| 14 | Pantalla Comanda por Mesa — catálogo + guardar en `comandas/` | 3 días |
| 15 | Botón "Cobrar" convierte comanda → pedido → opcional factura | 2 días |
| 16 | Transferencia de mesa | 1 día |
| 17 | Ticket de cocina/barra — solo productos nuevos desde última impresión | 2 días |

### FASE 3 — Profesional / Multi-Impresora (≈ 4 semanas)

| # | Tarea | Tiempo |
|---|---|---|
| 18 | `PrintRouterService` — routing por categoría de producto | 3 días |
| 19 | Impresoras WiFi/IP (socket TCP raw ESC/POS) | 5 días |
| 20 | División de cuenta | 3 días |
| 21 | Cuentas en espera (`parked sales` via `sqflite`) | 2 días |
| 22 | Modo offline + sync on reconnect via `connectivity_plus` | 5 días |
| 23 | KDS — pantalla de cocina (tablet) en tiempo real via Firestore stream | 3 días |

---

## 7. 📦 Dependencias Adicionales Necesarias

| Package | Uso | Estado |
|---|---|---|
| `mobile_scanner` | Escáner QR/barcode | ❌ Añadir |
| `flutter_riverpod` | State management reactivo para mesas multi-device | ❌ Opcional pero recomendado |
| Socket TCP raw | Impresora WiFi ESC/POS | ❌ Implementación manual con `dart:io` |
| `sqflite` | Cola offline de pedidos | ✅ Ya en pubspec, **sin usar** |
| `connectivity_plus` | Detección online/offline | ✅ Ya en pubspec, **sin usar** |
| `pdf` + `printing` | Z-Report PDF | ✅ Ya en pubspec |
| `fl_chart` | Gráficos en cierre | ✅ Ya en pubspec |

---

## 8. 💡 Resumen Ejecutivo

**El módulo TPV tiene una base técnica sólida:** catálogo con imágenes + variantes + IVA, flujo de cobro multi-método, integración fiscal completa (VeriFactu, series), cierre de caja con historial, importación CSV de TPVs externos, impresora Bluetooth térmica funcional.

**Para un bar tipo HIOPOS, los bloqueos principales son:**
1. 🚨 Sin mesas ni comandas abiertas
2. 🚨 BT ticket no conectado al cobro (servicio existe, falta llamarlo)
3. 🚨 IVA por defecto 21% (correcto es 10% bebidas)
4. 🚨 Ticket sin datos legales empresa

**Las 5 correcciones de Fase 0 (≈3-4 días) hacen el TPV de barra directa operativo y fiscalmente correcto.** El módulo de Mesas completo requiere ≈6-8 semanas adicionales para ser comparable a HIOPOS.

---

*Auditoría técnica basada en análisis estático de código fuente — Mayo 2026*

