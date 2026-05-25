# 🧾 Unificación de Facturación con TPVs en PlaneaG

> **Fecha:** Mayo 2026  
> **Objetivo:** Que cada venta cerrada en el TPV genere automáticamente su factura en el módulo de facturación, sin duplicar trabajo manual.

---

## 📌 El problema actual

| Flujo actual | Problema |
|---|---|
| TPV cierra venta → guarda en `pedidos` | La venta NO genera factura automáticamente |
| Facturación → requiere crear la factura a mano | Doble trabajo, errores de transcripción |
| El cierre de caja del TPV no cuadra con facturas emitidas | Informes inconsistentes |

---

## 🏗️ Arquitectura propuesta

```
TPV (cierre de venta)
       │
       ▼
  pedidos/{id}   ← ya existe en Firestore
       │
       │  [Cloud Function: onPedidoCompletado]
       │
       ▼
  facturas/{id}  ← se crea automáticamente
       │
       ├── Módulo Facturación  → listado, PDF, AEAT
       └── Cierre de Caja TPV → totales cuadran
```

---

## 🔧 Paso 1 — Estandarizar el documento `pedidos`

Al cerrar una venta en el TPV, el documento en Firestore debe incluir estos campos:

```json
{
  "empresa_id": "abc123",
  "cliente": "Juan García",
  "cliente_nif": "12345678A",          // opcional, para factura completa
  "cliente_correo": "juan@email.com",  // para envío digital
  "lineas": [
    {
      "descripcion": "Corte de pelo",
      "cantidad": 1,
      "precio_unitario": 15.00,
      "iva_pct": 21
    }
  ],
  "subtotal": 15.00,
  "iva_total": 3.15,
  "total": 18.15,
  "metodo_pago": "tarjeta",            // efectivo | tarjeta | bizum
  "estado_pago": "pagado",
  "fecha_creacion": Timestamp,
  "generar_factura": true,             // ← flag para la Cloud Function
  "serie_factura": "A"                 // ← serie a usar (A=ventas TPV)
}
```

---

## ⚡ Paso 2 — Cloud Function `onPedidoCompletado`

```typescript
// functions/src/facturacion/onPedidoCompletado.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onPedidoCompletado = functions.firestore
  .document('empresas/{empresaId}/pedidos/{pedidoId}')
  .onWrite(async (change, context) => {
    const data = change.after.data();
    if (!data) return;

    // Solo procesar si está pagado y requiere factura
    if (data.estado_pago !== 'pagado' || !data.generar_factura) return;
    // Evitar regenerar si ya tiene factura asociada
    if (data.factura_id) return;

    const { empresaId, pedidoId } = context.params;
    const db = admin.firestore();

    // Obtener siguiente número de factura
    const empresaRef = db.collection('empresas').doc(empresaId);
    const empresa = await empresaRef.get();
    const serie = data.serie_factura ?? 'A';
    const contadorKey = `contador_factura_${serie}`;
    const contador = (empresa.data()?.[contadorKey] ?? 0) + 1;

    const numeroFactura = `${serie}${String(contador).padStart(5, '0')}`; // A00001

    // Crear factura
    const facturaRef = await empresaRef.collection('facturas').add({
      numero: numeroFactura,
      serie: serie,
      pedido_id: pedidoId,
      cliente: data.cliente ?? '',
      cliente_nif: data.cliente_nif ?? '',
      cliente_correo: data.cliente_correo ?? '',
      lineas: data.lineas ?? [],
      subtotal: data.subtotal ?? 0,
      iva_total: data.iva_total ?? 0,
      total: data.total ?? 0,
      metodo_pago: data.metodo_pago ?? '',
      estado: 'emitida',
      fecha_emision: admin.firestore.FieldValue.serverTimestamp(),
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
      empresa_id: empresaId,
      origen: 'tpv',                  // para distinguir de facturas manuales
    });

    // Actualizar pedido con referencia a la factura y el contador
    await Promise.all([
      change.after.ref.update({ factura_id: facturaRef.id, numero_factura: numeroFactura }),
      empresaRef.update({ [contadorKey]: contador }),
    ]);

    console.log(`✅ Factura ${numeroFactura} creada para pedido ${pedidoId}`);
  });
```

---

## 📱 Paso 3 — Cambios en el TPV (Flutter)

### 3.1 Al cerrar venta, marcar `generar_factura: true`

En el servicio de cierre de venta del TPV, añadir el flag:

```dart
// lib/features/tpv/services/tpv_service.dart

Future<void> cerrarVenta({
  required String empresaId,
  required Map<String, dynamic> datosPedido,
  required bool emitirFactura,
}) async {
  await FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)
    .collection('pedidos')
    .add({
      ...datosPedido,
      'estado_pago': 'pagado',
      'generar_factura': emitirFactura,
      'serie_factura': 'A',
      'fecha_creacion': FieldValue.serverTimestamp(),
    });
}
```

### 3.2 Mostrar enlace a la factura desde el TPV

Tras cerrar la venta, el TPV puede mostrar el número de factura:

```dart
// Escuchar el pedido y mostrar factura cuando esté lista
StreamBuilder<DocumentSnapshot>(
  stream: pedidoRef.snapshots(),
  builder: (context, snap) {
    final data = snap.data?.data() as Map<String, dynamic>?;
    final numFactura = data?['numero_factura'];
    if (numFactura != null) {
      return Text('Factura: $numFactura', style: TextStyle(color: Colors.green));
    }
    return const CircularProgressIndicator();
  },
)
```

---

## 📊 Paso 4 — Cierre de Caja unificado

El cierre de caja del TPV debe cuadrar con las facturas emitidas ese día:

```dart
// Consulta para el cierre de caja
Future<Map<String, dynamic>> calcularCierreCaja({
  required String empresaId,
  required DateTime fecha,
}) async {
  final inicio = Timestamp.fromDate(DateTime(fecha.year, fecha.month, fecha.day));
  final fin    = Timestamp.fromDate(DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59));

  // Pedidos del día (fuente de verdad del TPV)
  final pedidos = await FirebaseFirestore.instance
    .collection('empresas').doc(empresaId).collection('pedidos')
    .where('fecha_creacion', isGreaterThanOrEqualTo: inicio)
    .where('fecha_creacion', isLessThanOrEqualTo: fin)
    .where('estado_pago', isEqualTo: 'pagado')
    .get();

  // Facturas emitidas ese día desde el TPV
  final facturas = await FirebaseFirestore.instance
    .collection('empresas').doc(empresaId).collection('facturas')
    .where('fecha_emision', isGreaterThanOrEqualTo: inicio)
    .where('fecha_emision', isLessThanOrEqualTo: fin)
    .where('origen', isEqualTo: 'tpv')
    .get();

  double totalEfectivo = 0, totalTarjeta = 0, totalBizum = 0;
  for (final p in pedidos.docs) {
    final d = p.data();
    final t = (d['total'] as num?)?.toDouble() ?? 0;
    switch (d['metodo_pago']) {
      case 'efectivo': totalEfectivo += t; break;
      case 'tarjeta':  totalTarjeta  += t; break;
      case 'bizum':    totalBizum    += t; break;
    }
  }

  return {
    'num_pedidos':   pedidos.size,
    'num_facturas':  facturas.size,
    'total_efectivo': totalEfectivo,
    'total_tarjeta':  totalTarjeta,
    'total_bizum':    totalBizum,
    'total_dia':      totalEfectivo + totalTarjeta + totalBizum,
    'cuadre_ok':      pedidos.size == facturas.size, // ✅ deben coincidir
  };
}
```

---

## 🔍 Paso 5 — Índice Firestore necesario

Añadir a `firestore.indexes.json`:

```json
{
  "collectionGroup": "facturas",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "origen", "order": "ASCENDING" },
    { "fieldPath": "fecha_emision", "order": "DESCENDING" }
  ]
}
```

---

## ✅ Checklist de implementación

- [ ] Actualizar estructura del documento `pedidos` en el TPV (añadir `lineas`, `subtotal`, `iva_total`, `generar_factura`, `serie_factura`)
- [ ] Crear Cloud Function `onPedidoCompletado` en `functions/src/`
- [ ] Desplegar función: `firebase deploy --only functions:onPedidoCompletado`
- [ ] Añadir índice `facturas(origen + fecha_emision)` a Firestore
- [ ] Desplegar índices: `firebase deploy --only firestore:indexes`
- [ ] Actualizar pantalla de cierre de caja del TPV para mostrar cuadre con facturas
- [ ] (Opcional) Añadir botón "Ver factura" en el ticket de cierre del TPV
- [ ] (Opcional) Envío automático de factura por email si `cliente_correo` está presente

---

## 🚨 Reglas de negocio importantes

| Regla | Detalle |
|---|---|
| **Solo una factura por pedido** | La Cloud Function comprueba `data.factura_id` antes de crear |
| **Numeración correlativa** | El contador se guarda en el doc de empresa, no en un campo de colección |
| **Series separadas** | TPV usa serie `A`, facturas manuales usan serie `B` (o la que configure el negocio) |
| **IVA correcto** | Cada línea lleva su `iva_pct`; la función no asume un IVA fijo |
| **Ticket ≠ Factura** | El ticket simplificado del TPV no sustituye a la factura Firestore para AEAT |

---

## 📁 Archivos a crear/modificar

```
functions/src/facturacion/
  └── onPedidoCompletado.ts     ← NUEVO

lib/features/tpv/
  ├── services/tpv_service.dart  ← modificar cerrarVenta()
  └── pantallas/cierre_caja_screen.dart ← añadir comparativa facturas

firestore.indexes.json           ← añadir índice origen+fecha_emision
```

