# Estado Bugs Fiscales — 19 Abril 2026 (actualizado)

## ✅ FASE 1: Bugs P0 — CORREGIDOS

### BUG #1 — `calcularResumen` ignoraba `facturas_recibidas/`
**Archivo:** `lib/services/contabilidad_service.dart` — ✅ CORREGIDO  

### BUG #2 — Mod.303 fallaba con facturas sin líneas desglosadas
**Archivo:** `lib/services/mod_303_service.dart` — ✅ CORREGIDO  

### BUG #3 — Solo facturas pagadas contaban como ingreso
**Archivo:** `lib/services/contabilidad_service.dart` — ✅ CORREGIDO  

### UI — Tabs mal nombrados
**Archivo:** `pantalla_contabilidad.dart` — ✅ CORREGIDO  

---

## ✅ FASE 2: Bugs P1 — CORREGIDOS

### BUG #7 — Ingresos IA iban a `facturas_recibidas/` en vez de `facturas/`
**Archivo:** `functions/src/fiscal/processInvoice.ts` — ✅ CORREGIDO  
Bloque 14 bifurca: `ingreso` → `facturas/`, `gasto` → `facturas_recibidas/`.

### Problema D — Sin dedup por NIF+número de factura
**Archivo:** `functions/src/fiscal/processInvoice.ts` — ✅ CORREGIDO  
- Mismo NIF + número + fecha ≤1 día → **BLOQUEA** (devuelve `duplicate`)
- Mismo NIF + número + fecha 2-7 días → **WARNING** + `needs_review`
- Mismo número, distinto NIF → **PERMITE**

### Problema E — Archivo en limbo por timeout
**Archivo:** `lib/services/fiscal/fiscal_upload_service.dart` — ✅ CORREGIDO  
Si hash coincide con doc en estado `failed`/`pending`, permite resubir.

### Prompt — Detección de facturas rectificativas
**Archivo:** `invoiceExtractionV1.ts` — ✅ CORREGIDO  
Bloque 5 ampliado: detecta rectificativas, extrae `external_reference`, tag `RECTIFICATIVE_INVOICE`.

---

## ✅ NUEVAS FUNCIONALIDADES — Anulación, Borrado y Rectificativas

### `anularTransaccion()` — `fiscal_upload_service.dart`
- draft/needs_review/posted → voided
- Marca `facturas_recibidas` vinculada como `rechazada`
- Auditoría en `fiscal_transaction_history`

### `eliminarBorrador()` — `fiscal_upload_service.dart`
- Solo draft/needs_review
- Snapshot en historial antes de borrar

### `crearFacturaRectificativa()` — `fiscal_upload_service.dart`
- Solo para `posted`
- Importes negativos, tag `RECTIFICATIVE_INVOICE`
- Vínculo bidireccional original ↔ rectificativa
- Soporta anulación total o parcial

### Reglas Firestore actualizadas — `firestore.rules`
- `create` para rectificativas
- `delete` para draft/needs_review
- `update` voided desde cualquier estado activo
- `fiscal_transaction_history` permite `create` desde app

### UI completa — `invoice_result_screen.dart`
- Bottom sheet con acciones contextuales según estado
- Diálogo de confirmación para eliminar borrador
- Diálogo con motivo para anulación
- Selector total/parcial para rectificativas con input de importe
- Status card muestra `voided` (rojo), `duplicate` (rojo)
- Info de anulación (motivo) y rectificativa (ID) en la vista

### Upload screen — `upload_invoice_screen.dart`
- Maneja `status: "duplicate"` devuelto por la CF
- Muestra aviso sin navegar a la pantalla de resultado

---

## 📊 Acciones por estado

| Estado | Editar | Eliminar | Anular | Rectificativa |
|--------|--------|----------|--------|---------------|
| draft | ✅ | ✅ | ✅ | ❌ |
| needs_review | ✅ | ✅ | ✅ | ❌ |
| posted | ❌ | ❌ | ✅ | ✅ |
| voided | ❌ | ❌ | ❌ | ❌ |

## 📊 Resumen

| Categoría | Total | Resueltos | Pendientes |
|-----------|-------|-----------|------------|
| P0 | 3 | 3 ✅ | 0 |
| P1 | 4 | 4 ✅ | 0 |
| P2 | 2 | 0 | 2 ⏳ |
| UI | 1 | 1 ✅ | 0 |
| Nuevas funciones | 3 | 3 ✅ | 0 |

---

## 🟡 FASE 3: P2 — Pendiente

- Unificar `fiscal_transactions/` como fuente única de verdad
- BUG #6: borrar upload_invoice_screen duplicado
- BUG #5: Mod.130 no incluye `gastos/`

## 📋 Desplegar cambios

```bash
firebase deploy --only functions:processInvoice
firebase deploy --only firestore:rules
flutter build apk --release
```

## 🔮 Futuros pasos

1. ~~UI Flutter: menú bottom sheet para anular/eliminar/rectificar~~ ✅ HECHO
2. Serie rectificativa: numeración correlativa "R-2026-0001"
3. Migración batch gastos/ + facturas_recibidas/ → fiscal_transactions/
4. Tests unitarios para duplicados y rectificativas
5. Mod.130: leer gastos/ + facturas_recibidas/
6. Mod.347: verificar suma >3.005,06€
7. Dashboard fiscal con IVA a ingresar/compensar
8. Alertas 15 días antes de vencimiento trimestral AEAT
9. Migrar a Node.js 22 antes del 30/04/2026

