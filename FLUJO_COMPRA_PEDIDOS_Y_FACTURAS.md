# 📋 Flujo Completo de Compra: Notificaciones y Facturación

## ✅ Estado Actual del Sistema

Tu aplicación **SÍ** está configurada para:

### 1. **Notificaciones de Nuevos Pedidos** ✅

**¿Cómo funciona?**
- Cuando se crea un pedido en Firestore (`empresas/{empresaId}/pedidos`), se dispara automáticamente una **Cloud Function** llamada `onNuevoPedido`
- La función envía una **notificación push** a todos los dispositivos registrados de la empresa

**Ubicación del código:**
```
functions/src/index.ts (líneas ~190-210)
```

**Notificación que recibe:**
```
🛒 Nuevo Pedido
"Cliente - €X,XX (vía app/whatsapp)"
```

**Flujo exacto:**
1. Usuario/cliente crea un pedido (vía formulario app o WhatsApp)
2. `crearPedido()` en `pedidos_service.dart` guarda el pedido en Firestore
3. **Automáticamente** se dispara `onNuevoPedido` Cloud Function
4. La notificación llega a **TODOS los dispositivos del propietario/empleados** de esa empresa
5. Se muestra con sonido, icono y datos del pedido

---

## ⚠️ Generación de Facturas - ESTADO ACTUAL

### **Problema Identificado: NO HAY GENERACIÓN AUTOMÁTICA** ❌

**Situación actual:**
- Las facturas **SE CREAN MANUALMENTE** desde la sección de Facturación
- **NO existe una función que genere factura automáticamente al crear un pedido**
- Debes crear la factura de forma manual usando los datos del pedido

**Código actual:**
- `facturacion_service.dart` → `crearFactura()` requiere ser llamada manualmente
- No hay integración entre `pedidos_service.dart` y `facturacion_service.dart`

---

## 🔧 SOLUCIÓN: Implementar Generación Automática de Facturas

### **Opción 1: Generación Automática al Crear Pedido** (Recomendado)

```typescript
// Agregar en functions/src/index.ts
export const onNuevoPedidoCrearFactura = functions
  .region("europe-west1")
  .firestore.document("empresas/{empresaId}/pedidos/{pedidoId}")
  .onCreate(async (snap, context) => {
    const empresaId = context.params.empresaId;
    const pedido = snap.data();

    try {
      // Generar factura automáticamente
      const facturaRef = await db
        .collection("empresas")
        .doc(empresaId)
        .collection("facturas")
        .add({
          numero_factura: `FAC-${new Date().getFullYear()}-${Date.now()}`,
          cliente_nombre: pedido.cliente_nombre || "Cliente",
          cliente_telefono: pedido.cliente_telefono || "",
          cliente_correo: pedido.cliente_correo || "",
          lineas: pedido.lineas || [],
          subtotal: (pedido.subtotal || pedido.total) || 0,
          total_iva: (pedido.iva || 0),
          total: pedido.total || 0,
          estado: "pendiente",
          pedido_id: snap.id,
          fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          metodo_pago: pedido.metodo_pago || "pendiente",
          historial: [{
            accion: "creada_automaticamente",
            descripcion: "Factura generada automáticamente al crear el pedido",
            fecha: admin.firestore.FieldValue.serverTimestamp()
          }]
        });

      console.log(`✅ Factura generada automáticamente para pedido ${snap.id}`);
    } catch (error) {
      console.error(`❌ Error generando factura: ${error}`);
    }
  });
```

### **Opción 2: Generar Factura Manualmente desde Pedido (Más Control)**

En `pedidos_service.dart`:
```dart
// Método para generar factura desde pedido
Future<void> generarFacturaDesdeP edido({
  required String empresaId,
  required String pedidoId,
  required String usuarioId,
  required String usuarioNombre,
}) async {
  final pedido = await _pedidos(empresaId).doc(pedidoId).get();
  if (!pedido.exists) throw Exception('Pedido no encontrado');
  
  final datos = pedido.data()!;
  
  // Llamar a facturacion_service
  final factSvc = FacturacionService();
  await factSvc.crearFactura(
    empresaId: empresaId,
    clienteNombre: datos['cliente_nombre'] ?? 'Cliente',
    clienteTelefono: datos['cliente_telefono'],
    clienteCorreo: datos['cliente_correo'],
    lineas: (datos['lineas'] as List?)?.map(...).toList() ?? [],
    metodoPago: ...
    pedidoId: pedidoId,
    usuarioId: usuarioId,
    usuarioNombre: usuarioNombre,
  );
}
```

---

## 📱 Pantalla Recomendada: Agregar Botón "Generar Factura"

En `detalle_pedido_screen.dart`, agregar:
```dart
ElevatedButton.icon(
  onPressed: () => _generarFactura(),
  icon: const Icon(Icons.receipt),
  label: const Text('Generar Factura'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF1976D2),
  ),
)
```

---

## 🧾 Notificación de Factura Creada

**También existe:**
```
functions/src/index.ts (líneas ~225-245)
onNuevaFactura → Envía notificación cuando se crea factura
```

Notificación:
```
🧾 Nueva Factura Pendiente
"FAC-2026-0001 — Cliente — €250.00"
```

---

## 📊 Resumen del Estado Actual

| Funcionalidad | Estado | Ubicación |
|---|---|---|
| **Notificación de Pedidos** | ✅ Automática | Cloud Functions `onNuevoPedido` |
| **Notificación de Facturas** | ✅ Automática | Cloud Functions `onNuevaFactura` |
| **Generación de Facturas** | ❌ Manual | Require crear manualmente |
| **Integración Pedido→Factura** | ❌ No existe | Necesita implementación |

---

## 🚀 Próximos Pasos Recomendados

1. **Implementar generación automática de facturas** (más eficiente)
2. **Agregar referencia entre Pedidos y Facturas** (relación pedido_id)
3. **Crear pantalla de reconciliación** (verificar pedidos sin factura)
4. **Agregar impresión/descarga de facturas en PDF**


