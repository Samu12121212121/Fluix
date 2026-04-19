# 🔴 ESTADO CRÍTICO DEL MÓDULO DE FACTURACIÓN — Abril 2026

> **Objetivo:** Radiografía honesta del sistema. Se señalan los puntos débiles tal como están en el código, sin suavizar.

---

## 1. ARQUITECTURA GENERAL — QUÉ HAY IMPLEMENTADO

### Colecciones en Firestore (lo que realmente existe)

| Colección | Qué guarda | Quién escribe |
|---|---|---|
| `facturas` | Facturas emitidas a clientes | App (formulario / TPV) |
| `facturas_recibidas` | Facturas de proveedores | App (formulario) + **IA** |
| `gastos` | Gastos manuales simplificados | App (formulario manual) |
| `fiscal_documents` | Archivo original subido (PDF/foto) | IA pipeline |
| `fiscal_transactions` | Registro fiscal detallado extraído por IA | IA pipeline |
| `fiscal_extractions` | JSON crudo + metadatos del proceso IA | IA pipeline |
| `modelos_fiscales` | Snapshots calculados de 303/130/etc. | App (al calcular) |
| `modelos130` | Mod.130 guardados | App |
| `modelos115` | Mod.115 guardados | App |

### Flujo de la IA (cómo funciona hoy)

```
Usuario sube PDF/foto
        ↓
FiscalUploadService
  → Dedup por SHA-256
  → Sube a Firebase Storage
  → Crea doc en fiscal_documents
        ↓
Cloud Function: processInvoice (europe-west1)
  → Google Document AI (OCR)
  → Claude Sonnet 4.5 (extracción fiscal)
        ↓
  Guarda en:
    - fiscal_transactions/{id}     ← modelo fiscal nuevo
    - facturas_recibidas/{id}      ← modelo contable existente
    - fiscal_extractions/{id}      ← traza del proceso
```

### Modelos fiscales implementados

| Modelo | Estado | Base de datos |
|---|---|---|
| **Mod. 303** IVA trimestral | ✅ Cálculo + fichero AEAT DR303e26v101 | `facturas` + `facturas_recibidas` |
| **Mod. 130** IRPF pago fraccionado | ✅ Cálculo YTD + fichero | `facturas` + `facturas_recibidas` |
| **Mod. 115** Retenciones arrendamiento | ✅ Cálculo + fichero | `facturas_recibidas` (es_arrendamiento=true) |
| **Mod. 111** Retenciones IRPF | ✅ Pantalla | desconocido |
| **Mod. 190** Resumen anual retenciones | ✅ Pantalla | desconocido |
| **Mod. 202** IS pago fraccionado | ✅ Pantalla | desconocido |
| **Mod. 347** Operaciones >3.005€ | ✅ Cálculo + exportación | `facturas` + `facturas_recibidas` |
| **Mod. 349** Operaciones intracomunitarias | ✅ Pantalla | `facturas_recibidas` |
| **Mod. 390** Resumen anual IVA | ✅ Cálculo | llama a Mod303 x4 trimestres |
| **Libro Registro IVA** | ✅ Generación | `facturas` + `facturas_recibidas` |

---

## 2. 🔴 BUGS CRÍTICOS ACTIVOS (código confirmado)

### BUG #1 — `calcularResumen` no lee `facturas_recibidas` para gastos
**Impacto: ALTO. Afecta Resumen, Gráficos, y el modelo fiscal visual del tab Modelos.**

```dart
// contabilidad_service.dart - calcularResumen()
// ❌ SOLO lee colección "gastos" (entrada manual)
// NO lee "facturas_recibidas" donde la IA guarda todo
final snapGastos = await _gastos(empresaId)  // ← colección "gastos"
    .where('fecha_gasto', ...)
    .get();
```

**Resultado:** Si el usuario solo usa IA para subir facturas (la función principal del módulo), el resumen, los gráficos y el cálculo del IVA soportado mostrarán **0€ de gastos** aunque existan docenas de facturas en `facturas_recibidas`.

**Nota:** `calcularModelosFiscales` llama a `calcularResumen`, así que el tab "Modelos" también hereda este bug.

---

### BUG #2 — Mod.303 calcula IVA repercutido a 0 cuando las facturas no tienen líneas detalladas
**Impacto: ALTO. Afecta directamente al modelo oficial descargable.**

```dart
// mod_303_service.dart - _calcularTotales()
// ❌ Si f.lineas == [], la suma es 0
final baseGeneral = emitidas.fold(0.0, (sum, f) => sum + f.lineas
    .where((l) => l.porcentajeIva == 21)
    .fold(0.0, (s, l) => s + l.subtotalSinIva));
```

Facturas creadas desde el **TPV**, la **factura rápida** o cualquier flujo simplificado pueden tener `lineas: []` con los totales guardados directamente en `subtotal` y `total_iva`. El Mod.303 ignora esas facturas → casillas vacías → el fichero AEAT enviado a Hacienda contiene datos incorrectos.

**El Mod.303 SÍ lee `facturas_recibidas` para IVA soportado (correcto), pero el IVA repercutido queda a 0.**

---

### BUG #3 — `calcularResumen` solo cuenta ingresos de facturas PAGADAS
**Impacto: MEDIO. El resumen fiscal muestra menos ingresos de los reales.**

```dart
// contabilidad_service.dart
final facturasPagadas = facturas.where((f) => f.esPagada).toList();
for (final f in facturasPagadas) {  // ← pendientes quedan a 0
```

Una empresa con 50 facturas emitidas en estado "pendiente" verá 0€ de ingresos en el resumen fiscal. El criterio de devengo fiscal no es "cobrado" sino "emitido".

---

### BUG #4 — El Tab "Resumen" no se recarga al volver al tab
**Impacto: BAJO-MEDIO. Problema de UX pero con consecuencias fiscales si el usuario no lo detecta.**

`_TabResumen` carga en `initState()` y `didUpdateWidget` (solo si cambia el año). Cuando el usuario sube una factura por IA, vuelve al tab Resumen y **ve los datos del último cálculo**, sin la factura nueva. Hay que cambiar manualmente de año y volver, o cerrar y reabrir la pantalla, para ver los datos actualizados.

---

### BUG #5 — Mod.130 no incluye gastos de la colección `gastos`
**Impacto: MEDIO. El 130 puede calcular menos gastos deducibles de los reales.**

```dart
// mod130_calculator.dart - _obtenerFacturasRecibidas()
// Solo lee facturas_recibidas, ignora colección "gastos"
final snap = await _facturasRecibidas(empresaId)
    .where('fecha_recepcion', ...)
    .get();
```

Si el usuario registra gastos manualmente en el tab "Gastos" (colección `gastos`), esos gastos **no se incluyen** en el cálculo de la casilla [02] del Mod.130. El beneficio neto calculado será más alto → más IRPF a pagar del necesario.

---

### BUG #6 — Dos `upload_invoice_screen.dart` con comportamiento distinto
**Impacto: MEDIO. Genera confusión y funcionalidades duplicadas desincronizadas.**

Existen dos versiones del mismo archivo:
- `lib/features/facturacion/pantallas/upload_invoice_screen.dart` → usa el flujo nuevo con paso de selección Gasto/Ingreso, y al completarse muestra un resultado inline y vuelve automáticamente.
- `lib/features/fiscal/pantallas/upload_invoice_screen.dart` → usa el mismo servicio pero navega a `InvoiceResultScreen` con el `transaction_id`.

La primera versión **no muestra el InvoiceResultScreen** — el usuario ve un mensaje de éxito genérico y vuelve, sin saber si la IA tuvo warnings o errores de extracción.

---

### BUG #7 — `UploadInvoiceScreen` del módulo fiscal ignora el tipo "ingreso" en el procesamiento
**Impacto: MEDIO. Las facturas de ingreso subidas por IA se procesan como gastos.**

En la Cloud Function `processInvoice`:
```typescript
type: tipoDocumento === "ingreso" ? "invoice_issued" : "invoice_received",
```
Esto distingue el tipo en `fiscal_transactions`, pero **el guardado en `facturas_recibidas`** se hace siempre, aunque sea un ingreso. Un ingreso subido por IA debería guardarse en `facturas` (emitidas), no en `facturas_recibidas`.

---

## 3. 🟡 PUNTOS DÉBILES DEL PIPELINE DE IA

### Problema A — El prompt asume siempre que el receptor es español
```typescript
// fiscal_upload_service.dart - userPrompt
País del receptor (cliente): ES  // ← hardcodeado
```
Si la empresa opera con clientes internacionales y sube una factura de venta a un cliente alemán, la IA la procesará asumiendo que el cliente es español. Impacto en la detección de `vat_scheme` (reverse_charge_eu, export).

---

### Problema B — Sin validación humana obligatoria antes de usar los datos fiscales
El flujo actual es:
1. IA extrae datos
2. Se guardan **automáticamente** en `facturas_recibidas`
3. Al calcular el 303, esos datos ya se usan directamente

No hay un paso de "revisión y aprobación". Una factura con `status: needs_review` (tiene errores de validación) entra igualmente en el cálculo del Mod.303. La única distinción es el campo `estado: "pendiente"` vs `"recibida"`, pero `Mod303Service._obtenerFacturasRecibidas` incluye **ambos estados**.

---

### Problema C — Confianza en Document AI para NIF/importes sin verificación
El prompt permite que DocAI con score ≥ 0.90 se use directamente sin verificar con el OCR:
```
Si DocAI score ≥ 0.90 → úsalo directamente
```
Un NIF extraído con score 0.91 que esté mal (número confundido) se usará en el Mod.347 y puede generar discrepancias con Hacienda.

---

### Problema D — Dedup solo por hash SHA-256 del archivo
Si el usuario sube el mismo PDF dos veces → bloqueado ✅. Pero si recibe la misma factura en dos formatos (PDF y foto escaneada), ambas pasan el dedup y se contabilizan dos veces. No hay dedup por `(nif_proveedor + numero_factura)` a nivel de `facturas_recibidas` — solo en `fiscal_transactions`, y solo como **warning**, no como bloqueo.

---

### Problema E — Timeout de 180 segundos sin retry desde el cliente
Si la Cloud Function tarda más de 180s (PDFs grandes, Document AI lento), lanza error y **el archivo ya está en Storage pero no procesado**. No hay mecanismo de reintento. El usuario ve un error y si vuelve a subir el mismo archivo, el dedup por hash lo bloquea con "archivo ya subido". **El archivo queda en un limbo permanente**: en Storage, con un doc en `fiscal_documents`, pero sin `fiscal_transaction` ni `factura_recibida`.

---

### Problema F — El modelo `claude-sonnet-4-5` tiene coste por llamada no controlado
No hay límite de llamadas por empresa/mes implementado en el código. Una empresa con muchos documentos puede generar costes descontrolados. El pack `fiscal_ai` solo verifica que esté activo, no controla el volumen de uso.

---

## 4. 🟡 PUNTOS DÉBILES DE LOS MODELOS FISCALES

### Mod.303 — Casillas no cubiertas

| Casilla | Descripción | Estado |
|---|---|---|
| 01/03 | IVA reducido 10% | ✅ (si hay líneas) |
| 04/06 | IVA general 21% | ✅ (si hay líneas) |
| 07/09 | IVA superreducido 4% | ✅ (si hay líneas) |
| 10-19 | Adquisiciones intracomunitarias | ❌ No implementado |
| 26-39 | Modificación bases/cuotas | ❌ No implementado |
| 40-46 | Operaciones asimiladas importaciones | ❌ No implementado |
| 59 | IVA diferido importaciones | ❌ No implementado |
| 64 | Compensaciones régimen especial agricultura | ❌ No implementado |
| 80-84 | Información adicional adquisiciones | ❌ No implementado |

El fichero generado **solo rellena casillas básicas** (01, 03, 04, 06, 20, 46-71). Para muchas empresas que operan solo en mercado nacional con IVA estándar, es suficiente. Para empresas con proveedores UE, importaciones o sector agrícola, el fichero está incompleto.

---

### Mod.303 — `_construirPorcentajes` siempre devuelve 100% en casilla 65
```dart
Map<String, double> _construirPorcentajes(Map<String, dynamic> datos) {
  return <String, double>{'65': 100.0};  // ← hardcodeado
}
```
La casilla 65 es el porcentaje de deducción aplicable (prorrata). Para empresas con operaciones mixtas (sujetas y exentas), el 100% es incorrecto y puede resultar en deducciones de IVA indebidas.

---

### Mod.130 — Los trimestres anteriores se buscan por `fecha_generacion desc limit(1)`
Si el usuario genera el mismo trimestre varias veces (recálculos), se coge el más reciente. Correcto. Pero si se genera uno con datos erróneos, se guarda y se usa en el siguiente trimestre sin aviso. No hay "versión oficial" vs "borrador".

---

### Mod.115 — Solo funciona si las facturas tienen `es_arrendamiento: true`
Este campo lo debe marcar el usuario manualmente al registrar la factura, o la IA lo detecta con el tag `ALQUILER_LOCAL`. Si la IA falla en la detección (factura de alquiler sin la palabra "arrendamiento" explícita), el Mod.115 queda vacío y el usuario tiene una obligación fiscal no cubierta sin saberlo.

---

## 5. 🟡 PUNTOS DÉBILES DE LA UI

### UI 1 — Pestañas de Contabilidad con nombres incorrectos (pendiente de arreglar)

| Tab actual | Nombre correcto | Widget |
|---|---|---|
| "Ingresos" | Ingresos (libro) | TabLibroIngresos |
| "Compras" | **Gastos** | TabFacturasRecibidas |
| "Gastos" | **Ingresos (registro)** | _TabGastos (obsoleto) |

El tab "Gastos" actual (_TabGastos) gestiona la colección `gastos` (entrada manual), que es una **colección secundaria** que los modelos fiscales mayoritariamente ignoran. El usuario que registra gastos ahí cree que está haciéndolo bien, pero el Mod.303 no los incluye.

---

### UI 2 — Al subir una factura por IA desde el tab "Gastos" (TabFacturasRecibidas), el resultado muestra solo "éxito/error" sin detalles

La versión de `upload_invoice_screen.dart` del módulo de facturación no navega a `InvoiceResultScreen`. El usuario no sabe:
- Qué NIF extrajo la IA
- Si hay warnings de validación matemática
- Si hubo un posible duplicado detectado

---

### UI 3 — El botón "Calcular" del Mod.303 no recalcula automáticamente
Después de subir 10 facturas por IA, el usuario tiene que ir a Contabilidad → Modelos → Mod.303 → y pulsar "Calcular" en cada trimestre. No hay ningún aviso de "hay facturas nuevas desde el último cálculo".

---

### UI 4 — El InvoiceResultScreen del módulo fiscal lee `fiscal_transactions` pero el tab "Gastos" no tiene enlace a ese resultado
Los datos ricos de la extracción IA (confianza, warnings, tags fiscales, líneas) están en `fiscal_transactions`, pero la pantalla principal de facturas recibidas solo muestra los campos básicos de `facturas_recibidas`. Un usuario que quiera ver "¿cómo interpretó la IA esta factura?" no tiene forma de acceder a esa información desde la UI principal.

---

## 6. RESUMEN DE RIESGOS POR PRIORIDAD

| Prioridad | Problema | Consecuencia real |
|---|---|---|
| 🔴 P0 | BUG #1 — Resumen no lee `facturas_recibidas` | Resumen y modelos muestran 0€ gastos |
| 🔴 P0 | BUG #2 — Mod.303 ignora facturas sin líneas | Fichero AEAT incorrecto → problema con Hacienda |
| 🔴 P0 | BUG #7 — Ingresos IA van a `facturas_recibidas` | Contabilidad mezclada ingresos/gastos |
| 🟠 P1 | BUG #3 — Solo facturas pagadas cuentan como ingreso | Ingresos del resumen son menores a los reales |
| 🟠 P1 | BUG #5 — Mod.130 no incluye colección `gastos` | IRPF calculado mayor al real |
| 🟠 P1 | Problema E — Archivo en limbo si timeout | Dedup bloquea reintento permanentemente |
| 🟠 P1 | Problema D — Sin dedup por NIF+NumFactura | Facturas duplicadas en distintos formatos |
| 🟡 P2 | BUG #4 — Resumen no se recarga | UX confusa, usuario no ve cambios |
| 🟡 P2 | BUG #6 — Dos upload screens distintos | Comportamiento inconsistente |
| 🟡 P2 | Casilla 65 hardcodeada al 100% | Error para empresas con prorrata |
| 🟡 P2 | No hay validación humana antes de usar datos IA | Datos erróneos entran en modelos fiscales |
| 🟢 P3 | Coste IA no controlado por empresa | Riesgo económico a escala |
| 🟢 P3 | Casillas intracomunitarias no implementadas | Limitación para empresas con proveedores UE |

---

## 7. LO QUE SÍ FUNCIONA BIEN

- ✅ **Pipeline IA completo**: upload → OCR → Claude → Firestore funciona de extremo a extremo
- ✅ **Prompt muy robusto**: 9 bloques, enum cerrado de regímenes IVA, validación matemática interna, casos especiales (margen, ISP, retenciones)
- ✅ **Dedup por hash**: evita subir el mismo archivo dos veces
- ✅ **Mod.115**: único modelo que funciona correctamente de extremo a extremo (lee solo `facturas_recibidas`, campo `es_arrendamiento`)
- ✅ **Mod.130 YTD**: la lógica acumulativa es correcta y está bien implementada para `facturas_recibidas`
- ✅ **Fichero DR303e26v101**: formato posicional AEAT correcto para el 303
- ✅ **`TabLibroIngresos`**: StreamBuilder en tiempo real, funciona correctamente para facturas emitidas
- ✅ **Criterio devengo/caja**: implementado y configurable por empresa

---

*Generado: 19/04/2026 — Basado en revisión directa del código fuente*

