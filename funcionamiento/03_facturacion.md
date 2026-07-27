# Módulo: Facturación

## Qué hace

Gestión completa de facturas emitidas: crear, editar, anular, rectificar y enviar facturas. Soporta múltiples series (FAC, RECT, PRO, TPV), distintos métodos de pago, y se integra con VeriFactu para cumplimiento fiscal.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/facturacion/pantallas/modulo_facturacion_screen.dart` | Pantalla principal del módulo |
| `features/facturacion/pantallas/tab_facturas.dart` | Listado de facturas con filtros |
| `features/facturacion/pantallas/formulario_factura_screen.dart` | Crear/editar factura |
| `features/facturacion/pantallas/formulario_linea_factura_sheet.dart` | Añadir/editar línea de factura |
| `features/facturacion/pantallas/formulario_rectificativa_screen.dart` | Crear factura rectificativa |
| `features/facturacion/pantallas/formulario_factura_recibida_screen.dart` | Registrar factura de proveedor |
| `features/facturacion/pantallas/tab_facturas_recibidas.dart` | Listado de facturas recibidas |
| `features/facturacion/pantallas/resumen_fiscal_screen.dart` | Vista consolidada fiscal |
| `features/facturacion/pantallas/tab_graficos_contabilidad.dart` | Gráficos de ingresos/gastos |
| `features/facturacion/pantallas/pantalla_contabilidad.dart` | Vista de contabilidad |
| `features/facturacion/widgets/panel_validacion_fiscal.dart` | Validación VeriFactu |
| `features/facturacion/widgets/asistente_iva_construccion.dart` | Asistente IVA para construcción |
| `domain/modelos/factura.dart` | Modelo principal de factura |
| `domain/modelos/contabilidad.dart` | Modelo de contabilidad |
| `services/email_service.dart` | Envío de facturas por email |

---

## Modelo de datos: Factura

```dart
Factura {
  id: String
  numeroFactura: String          // FAC-2026-0001
  serie: String                  // FAC, RECT, PRO, TPV
  estado: EstadoFactura          // pendiente, pagada, anulada, vencida, rectificada
  
  // Datos del cliente
  clienteId: String?
  clienteNombre: String
  clienteNif: String
  clienteDireccion: String
  
  // Fechas
  fechaEmision: DateTime
  fechaVencimiento: DateTime?
  fechaPago: DateTime?
  
  // Líneas
  lineas: List<LineaFactura>
  
  // Totales
  subtotal: double
  totalIva: double
  total: double
  
  // Pago
  metodoPago: MetodoPagoFactura  // tarjeta, PayPal, Bizum, efectivo, transferencia
  
  // VeriFactu
  verifactuRegistrado: bool
  verifactuHash: String?
  verifactuQr: String?
}

LineaFactura {
  descripcion: String
  cantidad: double
  precioUnitario: double
  tipoIva: double               // 0, 4, 10, 21
  subtotal: double
  totalIva: double
  total: double
}
```

---

## Cómo funciona internamente

### Crear una factura
1. El usuario abre `formulario_factura_screen.dart`
2. Selecciona el cliente (autocompletado desde Firestore)
3. Añade líneas con `formulario_linea_factura_sheet.dart`
4. El sistema calcula subtotal + IVA automáticamente
5. Asigna número de factura consultando el contador en `configuracion/facturacion`
6. Al guardar, crea el documento en `empresas/{empresaId}/facturas`
7. Si VeriFactu está activo, llama a `verifactu_service.dart` para generar el hash y el QR

### Numeración automática
- Los contadores de serie se guardan en `empresas/{empresaId}/configuracion/facturacion`
- Campos: `contador_fac`, `contador_rect`, `contador_pro`, `contador_tpv`
- Se incrementan con transacción Firestore para evitar duplicados

### Rectificativas
- Se crea a partir de una factura existente con estado `rectificada`
- La rectificativa hereda los datos de la original pero con importes en negativo
- Serie propia: RECT-2026-0001

### Facturas de proveedor (recibidas)
- Se registran en `empresas/{empresaId}/facturas_recibidas`
- Pueden subirse como PDF y pasar por OCR automático (ver módulo Fiscal)
- Alimentan los cálculos de IVA soportado para los modelos trimestrales

### Contabilidad
- `tab_graficos_contabilidad.dart` cruza facturas emitidas + recibidas
- Muestra evolución de ingresos/gastos por mes
- Calcula margen bruto y beneficio estimado

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/facturas` | Facturas emitidas |
| `empresas/{empresaId}/facturas_recibidas` | Compras a proveedores |
| `empresas/{empresaId}/configuracion/facturacion` | Contadores de series |
| `empresas/{empresaId}/clientes` | Datos del cliente para autocompletar |

---

## Cloud Functions relacionadas

| Función | Cuándo se ejecuta |
|---------|------------------|
| `processInvoice` | Al subir un PDF de factura recibida — OCR con Document AI + Claude |
| `generarFacturasResumenTpv` | Scheduled a las 23:30 — crea factura resumen del día para el TPV |
| `enviarEmailConPdf` | Callable — envía factura por email al cliente |

---

## Estados de una factura

```
pendiente → pagada
pendiente → anulada
pagada    → rectificada (genera RECT-)
```

---

## Conexión con otros módulos

- **Clientes** — autocompletado del destinatario y actualización del historial
- **Fiscal / VeriFactu** — cada factura emitida puede requerir registro en AEAT
- **TPV** — genera facturas automáticas desde ventas del TPV
- **Pedidos** — conversión automática de pedido pagado a factura
- **Contabilidad** — las facturas son la fuente de datos de ingresos/gastos

---

## Integración VeriFactu

Cuando la empresa tiene activado VeriFactu:
1. Al emitir una factura, `verifactu_service.dart` genera el hash encadenado (Art. 6 RD 1007/2023)
2. Se genera el QR con los datos de la factura
3. El XML se firma con el certificado PKCS12 de la empresa (`firmarXMLVerifactu` Cloud Function)
4. Se envía a la AEAT (`remitirVerifactu` Cloud Function)
5. El resultado queda registrado en la factura (`verifactuRegistrado: true`)
