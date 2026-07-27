# Módulo: Pedidos y TPV

---

## PEDIDOS

### Qué hace

Gestión de pedidos de productos de cualquier origen: web, app, WhatsApp, presencial o TPV externo. Incluye catálogo de productos con variantes, historial de precios, importación de catálogo por CSV y bot de WhatsApp para recibir pedidos automáticamente.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/pedidos/pantallas/detalle_pedido_screen.dart` | Detalle del pedido con acciones |
| `features/pedidos/pantallas/formulario_pedido_screen.dart` | Crear pedido manual |
| `features/pedidos/pantallas/catalogo_productos_screen.dart` | Búsqueda en catálogo |
| `features/pedidos/pantallas/formulario_producto_screen.dart` | Alta/edición de producto |
| `features/pedidos/pantallas/detalle_producto_screen.dart` | Ficha del producto |
| `features/pedidos/widgets/variante_selector_widget.dart` | Selector de variantes |
| `features/pedidos/widgets/variantes_editor_widget.dart` | Editor de variantes del producto |
| `features/pedidos/widgets/historial_precios_widget.dart` | Historial de cambios de precio |
| `features/pedidos/widgets/importacion_catalogo_sheet.dart` | Importar catálogo CSV |
| `services/pedidos_whatsapp_service.dart` | Integración con WhatsApp Business |
| `domain/modelos/pedido_whatsapp.dart` | Modelo de pedido por WhatsApp |

### Modelo de datos

```dart
Pedido {
  id: String
  clienteId: String?
  clienteNombre: String
  clienteEmail: String?
  clienteTelefono: String?
  
  fecha: DateTime
  origen: OrigenPedido        // web, app, whatsapp, presencial, tpvExterno
  
  lineas: List<LineaPedido>
  subtotal: double
  totalIva: double
  total: double
  
  estado: EstadoPedido        // pendiente, confirmado, enPreparacion, listo, entregado, cancelado
  estadoPago: EstadoPago      // pendiente, pagado, devuelto
  metodoPago: String?
  
  notasInternas: String?
  notasCliente: String?
  
  facturaId: String?          // Si se ha generado factura
}

LineaPedido {
  productoId: String
  productoNombre: String
  variante: String?           // Ej: "Talla M - Azul"
  cantidad: double
  precioUnitario: double
  tipoIva: double
  total: double
}

Producto {
  id: String
  nombre: String
  descripcion: String?
  precio: double
  costo: double?
  categoriaId: String?
  stock: int?
  controlStock: bool
  imagenUrl: String?
  activo: bool
  variantes: List<VarianteProducto>
}

VarianteProducto {
  nombre: String              // Ej: "Talla M"
  valor: String               // Ej: "Azul"
  precioExtra: double
  stock: int?
}
```

### Cómo funciona

#### Flujo de pedido online/WhatsApp
1. El cliente hace el pedido (web, app o WhatsApp)
2. Trigger `onNuevoPedido` → notificación push al negocio
3. Si el pedido viene de WhatsApp, `whatsappWebhook` procesa el mensaje y crea el pedido
4. El negocio confirma/rechaza desde la app
5. Al cambiar a estado `confirmado`, el cliente recibe notificación
6. Si el pago se registra como cobrado, trigger `onNuevoPedidoGenerarFactura` crea automáticamente la factura

#### Importación de catálogo
- `importacion_catalogo_sheet.dart` acepta CSV con columnas: nombre, precio, costo, categoría, stock
- Se mapean las columnas y se importan masivamente en Firestore

---

## TPV (Terminal Punto de Venta)

### Qué hace

Terminal de venta presencial adaptable a distintos tipos de negocio: tienda, restaurante con mesas, o peluquería con servicios. Incluye impresión de tickets, scanner de código de barras, cierre de caja (Z/X) y facturación automática del día.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/tpv/pantallas/tpv_tienda_screen.dart` | TPV modo tienda (productos) |
| `features/tpv/pantallas/tpv_peluqueria_screen.dart` | TPV modo servicios/peluquería |
| `features/tpv/pantallas/facturar_pedidos_screen.dart` | Emisión de facturas desde TPV |
| `features/tpv/pantallas/importar_ventas_csv_screen.dart` | Importar ventas desde CSV externo |
| `features/tpv/pantallas/historial_importaciones_screen.dart` | Historial de importaciones |

### Modos de TPV

| Modo | Uso |
|------|-----|
| **Tienda** | Venta de productos con scanner, variantes y stock |
| **Peluquería** | Selección de servicios, asignación a profesional, cobro |
| **Restaurante** | Gestión de mesas por zonas, comandas a cocina, cuenta |

### Flujo de venta en TPV
1. Se seleccionan productos/servicios
2. El sistema calcula totales con IVA
3. Se elige método de pago (efectivo, tarjeta, Bizum, etc.)
4. Al cobrar, se crea un `Pedido` en Firestore con `origen: presencial`
5. Se imprime ticket en impresora térmica Bluetooth
6. El stock se actualiza automáticamente
7. A las 23:30, `generarFacturasResumenTpv` agrupa todas las ventas del día en una única factura resumen

### Hardware soportado
- **Impresora térmica** — Bluetooth vía `blue_thermal_printer`
- **Scanner** — cámara del dispositivo vía `mobile_scanner` (código de barras/QR)

### Cierre de caja
- **Cierre X** — arqueo parcial sin resetear contadores
- **Cierre Z** — cierre del día con reseteo de contadores
- Se registra en `empresas/{empresaId}/cierres_caja` con:
  - Efectivo inicial y final
  - Ventas por método de pago
  - Diferencia (descuadre)
- `debug_tpv.bat` / `debug_tpv.ps1` — scripts de depuración para TPV en Windows

---

## Colecciones Firestore usadas (Pedidos + TPV)

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/pedidos` | Todos los pedidos (web, app, TPV) |
| `empresas/{empresaId}/catalogo` | Catálogo de productos |
| `empresas/{empresaId}/categorias_catalogo` | Categorías del catálogo |
| `empresas/{empresaId}/mesas` | Mesas del restaurante |
| `empresas/{empresaId}/zonas_tpv` | Zonas (sala, terraza, barra) |
| `empresas/{empresaId}/cierres_caja` | Histórico de cierres |

---

## Cloud Functions relacionadas

| Función | Cuándo |
|---------|--------|
| `onNuevoPedido` | Trigger — notificación al negocio |
| `onNuevoPedidoGenerarFactura` | Trigger — auto-factura si pago registrado |
| `onNuevoPedidoWhatsApp` | Trigger — envía confirmación por WhatsApp |
| `whatsappWebhook` | HTTP — recibe/responde mensajes de WhatsApp Business |
| `generarFacturasResumenTpv` | Scheduled 23:30 — factura diaria del TPV |
| `cerrarCaja` | Callable — proceso de cierre Z/X |

---

## Conexión con otros módulos

- **Clientes** — los pedidos se vinculan a clientes del CRM
- **Facturación** — los pedidos generan facturas automáticamente
- **Catálogo** — el TPV usa el mismo catálogo de productos que la tienda online
- **Fiscal** — las facturas generadas del TPV alimentan los modelos AEAT
