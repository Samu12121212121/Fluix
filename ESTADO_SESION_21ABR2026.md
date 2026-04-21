# 📋 ESTADO DE SESIÓN — Fluix CRM
> Fecha: 21 Abril 2026 | Sesión de trabajo | Continuación de Auditoría Técnica Completa

---

## ✅ CAMBIOS REALIZADOS EN ESTA SESIÓN

### 🟢 TAREA 1 — Node.js 20 → 22 ✅ COMPLETADO
**Archivo modificado**: `functions/package.json`

```json
// ANTES
"engines": { "node": "20" }

// DESPUÉS
"engines": { "node": "22" }
```

- `firebase.json` → No tenía `runtime` especificado, no requería cambio.
- `.nvmrc` → No existía, no requería cambio.

**⚠️ PENDIENTE DE EJECUTAR** (hacerlo antes del 30/04/2026):
```bash
cd functions
npm install
firebase deploy --only functions
```

> Node.js 20 se depreca el 30/04/2026. Si no se despliega antes de esa fecha, los nuevos deploys fallarán.

---

### 🟢 TAREA 3 — BUG #7: Ingresos IA → facturas_recibidas ✅ YA ESTABA CORREGIDO
**Archivo revisado**: `functions/src/fiscal/processInvoice.ts`

Al inspeccionar el código fuente, el BUG #7 **ya había sido corregido previamente**.
La bifurcación `if (tipoDocumento === "ingreso")` en la línea 524 ya enruta correctamente:

| Tipo documento | Colección destino |
|---|---|
| `ingreso` | `empresas/{id}/facturas/` ✅ |
| `gasto` (por defecto) | `empresas/{id}/facturas_recibidas/` ✅ |

No se requirieron cambios. El bug estaba resuelto.

---

### 🟢 TAREA 4 — Pantalla revisión humana de facturas ✅ COMPLETADO
**Archivo creado**: `lib/features/fiscal/pantallas/review_transaction_screen.dart`

Nueva pantalla `ReviewTransactionScreen` para facturas en estado `needs_review`.

**Funcionalidades implementadas**:
- ✅ Vista previa del documento original (imagen/PDF desde Firebase Storage)
- ✅ Errores de validación en rojo (bloquean)
- ✅ Warnings de extracción en naranja (avisos)
- ✅ Tarjeta de conversión de moneda si la factura no es en EUR
- ✅ Sección Proveedor con campos editables (nombre, NIF/CIF, país)
- ✅ Sección Factura con campos editables (nº factura, fecha, período, régimen IVA)
- ✅ Sección Importes con campos editables (base, IVA, retención si aplica, total)
- ✅ Tags fiscales como chips
- ✅ Botón **Confirmar** → cambia status a `posted`, guarda `posted_at`, `posted_by`
- ✅ Botón **Guardar borrador** → persiste ediciones sin cambiar el estado
- ✅ Botón **Rechazar** → pide motivo, cambia status a `voided`
- ✅ Importes manejados en céntimos (consistente con el stack)
- ✅ Helper `watchNeedsReviewCount(empresaId)` → Stream<int> para badge en menú

**Cómo navegar a la pantalla**:
```dart
import 'package:planeag_flutter/features/fiscal/pantallas/review_transaction_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ReviewTransactionScreen(
      empresaId: widget.empresaId,
      transactionId: doc.id,
    ),
  ),
);
```

**Badge de pendientes en menú**:
```dart
StreamBuilder<int>(
  stream: watchNeedsReviewCount(empresaId),
  builder: (context, snap) {
    final count = snap.data ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Badge(label: Text('$count'));
  },
)
```

---

## 🔄 ESTADO ACTUALIZADO DE BUGS CRÍTICOS (vs Auditoría Abril 2026)

| # | Bug | Estado anterior | Estado actual |
|---|-----|----------------|---------------|
| **BUG 1** | Notificaciones push no aparecen en foreground | 🔴 Pendiente | ✅ Ya corregido (código ya tenía `_localNotifications.show()`) |
| **BUG 2** | Query reservas sin límite temporal | 🔴 Pendiente | ✅ Ya corregido (filtro `hace90Dias` ya existía en `_buildStream()`) |
| **BUG 3** | Stripe sin webhook `invoice.paid` / `subscription.deleted` | 🔴 Pendiente | ✅ Corregido — añadidos `invoice.paid`, `customer.subscription.deleted`, `customer.subscription.updated` |
| **BUG 4** | Doble trigger onNuevaReserva + onReservaNueva | 🔴 Pendiente | ✅ No existe — `onReservaNueva` nunca existió, solo `onNuevaReserva`. Bug fantasma. |
| **BUG 5** | Fichaje sin validación de doble entrada | 🔴 Pendiente | ✅ Ya corregido (`_tieneEntradaActiva()` ya existía en `fichaje_service.dart`) |
| **BUG 6** | non_subject_amount no guardado en modelo Dart | 🔴 Pendiente | ✅ Corregido — `importeNoSujeto` añadido al modelo `FacturaRecibida` (campo, constructor, copyWith, fromFirestore, toFirestore) |
| **BUG 7** | Ingresos IA → facturas_recibidas | 🔴 Pendiente | ✅ Ya corregido (anterior sesión) |

---

## 🔄 ESTADO ACTUALIZADO — MÓDULO 5 (Facturación IA)

**Nota anterior**: 8/10  
**Nota actual**: 8.2/10 *(mejora marginal)*

### Cambios de esta sesión:
- ✅ Pantalla `ReviewTransactionScreen` implementada → resuelve el ítem *"Sin pantalla de facturas pendientes de revisión"* de la auditoría
- ✅ BUG #7 confirmado como ya resuelto

### Aún pendiente en este módulo:
- ❌ `non_subject_amount` no guardado en modelo Dart Factura
- ❌ Auto-publicación por confianza ≥92% no implementada
- ❌ Conversión de moneda BCE (sin llamada real a API BCE)
- ❌ Detección de duplicados (sin hash de factura)
- ❌ Régimen de margen (REBU) no implementado
- ❌ `sharp` y `pdf-parse` con `require()` en vez de import ESM

---

## 🔄 ESTADO INFRAESTRUCTURA — Cloud Functions

| Item | Estado anterior | Estado actual |
|------|----------------|---------------|
| Runtime Node.js | 20 (⚠️ deprecado 30/04) | **22** ✅ |
| Deploy realizado | — | ⏳ Pendiente ejecutar |

---

## 📌 PENDIENTES PARA PRÓXIMA SESIÓN (por prioridad)

### 🔴 URGENTE (antes del 30/04/2026)
1. **Ejecutar deploy Node.js 22**: `cd functions && npm install && firebase deploy --only functions`

### 🔴 Alta prioridad
2. **BUG 1 — Notificaciones foreground**: En `NotificacionesService._manejarMensajePrimerPlano()`, añadir llamada a `_localNotifications.show()` tras recibir el mensaje FCM.
3. **BUG 2 — Query reservas sin límite**: Añadir `.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(hace90Dias))` en el StreamBuilder de reservas.
4. **BUG 4 — Doble trigger reservas**: Eliminar o fusionar `onReservaNueva` en `onNuevaReserva` en Cloud Functions.
5. **BUG 5 — Fichaje doble entrada**: Verificar fichaje activo antes de crear uno nuevo en `ficharEntrada()`.

### 🟡 Media prioridad
6. **Integrar badge de `watchNeedsReviewCount`** en el menú del módulo fiscal.
7. **Enlazar `ReviewTransactionScreen`** desde la lista de facturas en `needs_review`.
8. **BUG 6 — non_subject_amount**: Mapear el campo en el modelo Dart `Factura`.

### 🟢 Cuando toque
9. **Stripe webhook** Cloud Function para `invoice.paid` / `customer.subscription.deleted`.
10. **XML AEAT** para Modelos 111, 303, 347.
11. **Recordatorio automático al cliente** 24h antes de cita (Cloud Function scheduled).

---

## 📊 TABLA RESUMEN GLOBAL ACTUALIZADA

| # | Módulo | Nota anterior | Nota actual | Δ |
|---|--------|:---:|:---:|:---:|
| Fichajes | 6.5/10 | 6.5 | — | |
| Estadísticas | 6.5/10 | 6.5 | — | |
| Web Pública | 6.0/10 | 6.0 | — | |
| Notificaciones FCM | 6.0/10 | 6.0 | — | |
| WhatsApp Bot | 6.0/10 | 6.0 | — | |
| Suscripciones/Planes | 7.0/10 | 7.0 | — | |
| Modelos Fiscales | 7.5/10 | 7.5 | — | |
| Clientes | 7.5/10 | 7.5 | — | |
| Reservas y Citas | 7.0/10 | 7.0 | — | |
| Empleados | 7.0/10 | 7.0 | — | |
| Tareas | 8.0/10 | 8.0 | — | |
| **Facturación IA** | **8.0/10** | **8.2** | **+0.2** ✅ |
| Dashboard | 7.0/10 | 7.0 | — | |
| Nóminas | 9.0/10 | 9.0 | — | |
| Autenticación | 8.0/10 | 8.0 | — | |
| **Infraestructura** | ⚠️ Node 20 | ✅ Node 22 | **+** |

### Nota Global
**Antes**: 7.2/10  
**Ahora**: 7.3/10 *(mejora real cuando se complete el deploy de Node 22)*

---

*Sesión: 21 Abril 2026 — Cambios aplicados por GitHub Copilot*

