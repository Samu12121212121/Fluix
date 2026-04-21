# 🧾 AUDITORÍA PACK FISCAL — Fluix CRM
> Fecha: 21 Abril 2026 | Estado real del código fuente auditado

---

## 📐 ARQUITECTURA GENERAL DEL PACK FISCAL

```
USUARIO SUBE FACTURA (foto/PDF)
         │
         ▼
FiscalCaptureService → FiscalUploadService
         │  guarda en fiscal_documents/
         ▼
Cloud Function: processInvoice
    ├─ Document AI OCR (Google)
    ├─ pdf-parse (PDF con texto nativo)
    ├─ sharp (optimización imágenes)
    ├─ preprocesarTextoOCR (limpieza)
    ├─ Claude Sonnet (extracción JSON)
    ├─ validateInvoice (validación fiscal)
    ├─ fetchExchangeRateBCE (moneda extranjera)
    ├─ computeFileHash SHA-256 (duplicados)
    ├─ decideStatus (confianza ≥92% → posted)
    └─ Guarda en:
         ├─ fiscal_transactions/ (modelo central)
         ├─ facturas/ (ingresos)
         └─ facturas_recibidas/ (gastos)
         │
         ▼
Flutter: ReviewTransactionScreen (needs_review)
         │  o auto-aprobado si ≥92%
         ▼
Cloud Function: calculateFiscalModel
    ├─ Lee fiscal_transactions del período
    └─ Calcula modelos AEAT:
         303, 111, 115, 202, 390, 190, 180, 347
         │
         ▼
Exportación:
    ├─ PDF (pdf-lib sobre template AEAT)
    ├─ Pre-declaración posicional 303
    └─ PresentarAeatWidget → Sede AEAT (web)
```

---

## 🔬 AUDITORÍA POR MODELO AEAT

---

### MODELO 303 — IVA Trimestral ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model303.ts`): ✅
- Casillas: 01-02 (4%), 04-05 (10%), 07-08 (21%), 10-11 (intracomunitario), 12-13 (ISP), 27 (total devengado), 28-35 (soportado), 45-46 (resultado)
- Detecta tipo IVA de cada transacción (4/10/21%)
- Excluye REBU/margin_scheme del cálculo estándar
- Separa IVA soportado en bienes corrientes vs inversión
- Pre-declaración posicional AEAT 2026 (`model303PreDec.ts`)

**Flutter** (`modelo303_screen.dart`): ✅
- 4 tabs trimestrales + selector de año
- Muestra todas las casillas del modelo
- Botón "Calcular" llama a Cloud Function
- PDF exportable con `share_plus`
- `PresentarAeatWidget` con URL directa a Sede AEAT
- Guarda resultado en `modelos_fiscales/303_{año}_{trim}T`

**❌ Qué falta:**
- Casillas de rectificativas (complementarias/sustitutivas) no implementadas
- Casilla 64 (cuotas pendientes compensación trimestres anteriores) no implementada
- No detecta volumen de operaciones total para casilla 108

---

### MODELO 111 — Retenciones IRPF Trimestral ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model111.ts`): ✅
- Clave A: nóminas (rendimientos del trabajo)
- Clave G: facturas de profesionales con retención
- Casillas 01-06 + totales 28-29
- Deduplica perceptores por NIF

**Flutter** (`modelo111_screen.dart`): ✅
- Lee desde `modelo111_service.dart` (propio, no usa calculateFiscalModel)
- Muestra perceptores por tipo
- PDF exportable

**❌ Qué falta:**
- Clave B (premios) y Clave C (capital mobiliario) no implementadas
- Ingresos a cuenta por especie no implementados
- Solo llama a `modelo111_service.dart` (no unificado con `calculateFiscalModel`)

---

### MODELO 115 — Retenciones Arrendamientos Trimestral ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model115.ts`): ✅
- Filtra por tag `ALQUILER_LOCAL`
- Requiere retención > 0 para incluir
- Casillas 01 (arrendadores), 02 (base), 03 (retención)
- Desglose por arrendador

**Flutter** (`modelo115_screen.dart`): ✅
- Muestra arrendadores y bases
- PDF exportable

**❌ Qué falta:**
- Arrendamientos de bienes muebles (art. 101.7 LIRPF) no contemplados
- No valida que el % retención sea exactamente 19%

---

### MODELO 130 — Pago Fraccionado IRPF Autónomos ✅ IMPLEMENTADO

**Backend**: ⚠️ No hay `model130.ts` en Cloud Functions — tiene su propio servicio Flutter
- `mod130_calculator.dart` + `mod130_exporter.dart` (solo en cliente)
- `Modelo130` model en `domain/modelos/modelo130.dart`
- `sede_aeat_urls.dart` con URL Sede AEAT

**Flutter** (`modelo130_screen.dart`): ✅
- Cálculo trimestral de rendimientos netos
- Acumulado del ejercicio para la fórmula del 130
- PDF exportable
- `PresentarAeatWidget` con URL AEAT

**❌ Qué falta:**
- El cálculo es **solo en cliente** (Dart), no en Cloud Function — inconsistente con el resto
- No integrado en `calculateFiscalModel` → sin histórico centralizado
- No aparece en `ExportModelsScreen` (el hub de modelos) — **está huérfano**

---

### MODELO 202 — Pagos Fraccionados Impuesto de Sociedades ✅ IMPLEMENTADO (simplificado)

**Backend** (`functions/src/fiscal/models/model202.ts`): ⚠️ Simplificado
- Usa ingresos - gastos de fiscal_transactions como proxy del resultado contable
- Tipo IS 15% (empresa nueva) / 25% (general) configurable con `is_new_company`
- Pago fraccionado = 18% de la cuota anual estimada
- Descuenta retenciones soportadas

**Flutter** (`modelo202_screen.dart`): ✅
- Muestra el cálculo simplificado
- PDF exportable
- Aviso claro de que es estimación

**❌ Qué falta:**
- No usa el resultado contable real (requeriría integración contable completa)
- No implementa la modalidad del artículo 40.3 (% de la cuota del IS del año anterior)
- Aviso de "simplificado" debería ser más visible

---

### MODELO 390 — Resumen Anual IVA ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model390.ts`): ✅
- Delega en `calculate303` sobre el año completo
- Desglose por trimestre
- Verifica coherencia entre los 4 trimestres

**Flutter** (`modelo390_screen.dart`): ✅
- Muestra casillas del 303 a nivel anual
- Desglose trimestral visual

**❌ Qué falta:**
- Casillas exclusivas del 390 no en el 303: sector diferenciado, prorrata, bienes de inversión (casillas 100+)
- No contempla régimen simplificado ni agricultura

---

### MODELO 190 — Resumen Anual Retenciones IRPF ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model190.ts`): ✅
- Claves A (trabajo) y G (actividades económicas)
- Agrupa por perceptor/NIF con totales anuales
- Par anual del Modelo 111

**Flutter** (`modelo190_screen.dart`): ✅
- Lista de perceptores con retenciones anuales
- PDF exportable

**❌ Qué falta:**
- Claves B, C, D, E (capital mobiliario, arrendamientos, premios, otros) no implementadas

---

### MODELO 180 — Resumen Anual Retenciones Arrendamientos ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model180.ts`): ✅
- Par anual del Modelo 115
- Agrega por arrendador con dirección del inmueble
- Incluye base y retención anual

**Flutter** (`modelo180_screen.dart`): ✅
- Lista de arrendadores con datos anuales
- PDF exportable

**❌ Qué falta:**
- Referencia catastral del inmueble no guardada (obligatoria en la declaración real)

---

### MODELO 347 — Operaciones con Terceros ✅ IMPLEMENTADO

**Backend** (`functions/src/fiscal/models/model347.ts`): ✅
- Umbral correcto: 3.005,06 €/año
- Excluye intracomunitarias, arrendamientos con retención, nóminas
- Desglose por trimestre
- Separa clientes vs proveedores

**Flutter** (`modelo347_screen.dart`): ✅
- Muestra operadores declarables y sus totales
- PDF exportable

**❌ Qué falta:**
- Operaciones en efectivo > 6.000 € no marcadas (obligatorio desde 2021)
- No genera el fichero en formato BOE/txt para presentación telemática masiva

---

## 🚫 MODELOS NO IMPLEMENTADOS

| Modelo | Nombre | Obligado cuando | Estado |
|--------|--------|-----------------|--------|
| **349** | Operaciones intracomunitarias | Compras/ventas en UE | ❌ Sin implementar |
| **340** | Libros de registro | Solo bajo requerimiento | ❌ Sin implementar |
| **036/037** | Alta/modificación censal | Cambios en empresa | ❌ Sin implementar (manual) |

El **Modelo 349** es el más crítico — `processInvoice.ts` ya detecta transacciones intracomunitarias (tag `CROSS_BORDER_EU`, `esIntracomunitario`) pero no hay modelo 349.

---

## 🔗 ESTADO DE LA UI — QUÉ ESTÁ CONECTADO Y QUÉ NO

| Pantalla | Existe | Accesible desde la app | Estado |
|----------|:------:|:----------------------:|--------|
| `ExportModelsScreen` | ✅ | ✅ FAB "🏛️ Modelos AEAT" en `ModuloFacturacionScreen` | ✅ Conectado hoy |
| `Modelo303Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo111Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo115Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo130Screen` | ✅ | ✅ Via `ExportModelsScreen` (añadida hoy) | ✅ Conectado hoy |
| `Modelo202Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo390Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo190Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo180Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `Modelo347Screen` | ✅ | ✅ Via `ExportModelsScreen` | ✅ |
| `ReviewTransactionScreen` | ✅ | ✅ Tab "🔍 Revisión IA" en Facturación | ✅ Conectado hoy |
| `UploadInvoiceScreen` | ✅ | ✅ FAB en `ModuloFacturacionScreen` | ✅ |
| `InvoiceResultScreen` | ✅ | ✅ Tras procesar factura | ✅ |
| `SubirCertificadoVerifactuScreen` | ✅ | ✅ Icono en AppBar de `ExportModelsScreen` | ✅ Conectado hoy |

**Badge de estado** (`calculado` / `presentado`) en cada modelo de `ExportModelsScreen`: ✅ Implementado hoy

---

## ❌ LO QUE FALTA PARA TERMINAR EL PACK FISCAL

### 🔴 CRÍTICO — Sin esto el pack no es vendible

1. **`ExportModelsScreen` no está en la navegación principal**
   - El hub de todos los modelos AEAT existe pero no hay ningún botón/ruta que llegue a él
   - **Fix**: Añadir acceso desde `ModuloFacturacionScreen` (un FAB o tab) y/o desde el menú lateral

2. **`Modelo130Screen` no está en `ExportModelsScreen`**
   - La pantalla existe y funciona pero el hub de modelos no la incluye
   - **Fix**: Añadirla en `ExportModelsScreen._modelosTrimestrales`

3. **`SubirCertificadoVerifactuScreen` completamente huérfana**
   - Sin acceso desde ningún sitio de la app
   - **Fix**: Añadir en configuración fiscal de la empresa

4. **Templates PDF de la AEAT no subidos a Storage**
   - `generateModelPdf.ts` requiere `templates/fiscal/modelo{code}_{year}.pdf` en Storage
   - Sin los PDFs oficiales descargados de la AEAT y subidos, los PDFs no se pueden generar
   - **Fix**: Descargar de `sede.agenciatributaria.gob.es` y subir a Firebase Storage

5. **XML AEAT — solo existe pre-declaración 303**
   - `model303PreDec.ts` genera formato posicional para el 303
   - El resto de modelos (111, 115, 347, 390) no tienen generación de fichero AEAT
   - **Fix**: Implementar generadores de fichero para cada modelo (diseño de registros publicado por la AEAT)

6. **Modelo 349 (intracomunitarias) no implementado**
   - Las transacciones ya están etiquetadas con `CROSS_BORDER_EU` / `esIntracomunitario`
   - Pero no hay Cloud Function ni pantalla Flutter para el 349
   - **Fix**: Añadir `model349.ts` + `Modelo349Screen`

### 🟡 IMPORTANTE — Para calidad del pack

7. **Calendario fiscal con alertas push**
   - No hay ningún recordatorio de vencimientos (día 20 de cada mes/trimestre)
   - **Fix**: Cloud Function scheduled que mire qué modelos vencen en los próximos 5 días y envíe push

8. **Historial de presentaciones**
   - `modelos_fiscales/{modelo}_{periodo}` se guarda pero no hay pantalla que muestre el historial
   - El usuario no sabe qué modelos ya presentó y cuáles están pendientes

9. **Estado del modelo** (`calculado` / `presentado` / `pendiente`)
   - Se guarda en Firestore el campo `estado` pero la UI no lo refleja visualmente
   - **Fix**: Badge de estado en cada modelo en `ExportModelsScreen`

10. **`mod130_calculator.dart` no unificado con `calculateFiscalModel`**
    - El 130 tiene cálculo en cliente, el resto en Cloud Function — inconsistente
    - **Fix**: Crear `model130.ts` en Cloud Functions y migrar la lógica

### 🟢 MEJORAS DE CALIDAD

11. **Pre-declaraciones de otros modelos** (111, 115, 347)
    - Solo el 303 tiene generación de fichero posicional
    - **Fix**: Implementar generadores de pre-declaración para el resto

12. **Casillas de 390 específicas** (prorrata, bienes inversión, sector diferenciado)
    - El 390 actual es solo el 303 anual — faltan las casillas exclusivas del resumen anual

13. **Validación de NIF del declarante**
    - El CIF/NIF de la empresa no se valida antes de generar el modelo
    - Si está en blanco, genera un PDF con campo vacío (error en Sede AEAT)

---

## 📊 TABLA RESUMEN POR MODELO

| Modelo | Backend | Flutter UI | Exportación | Accesible | Nota |
|--------|:-------:|:----------:|:-----------:|:---------:|------|
| **303** | ✅ | ✅ | PDF + PreDec | ⚠️ Via ExportModels | 8.5/10 |
| **111** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7.5/10 |
| **115** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7.5/10 |
| **130** | ⚠️ Solo cliente | ✅ | PDF | ❌ Huérfana | 6/10 |
| **202** | ✅ Simplificado | ✅ | PDF | ⚠️ Via ExportModels | 6.5/10 |
| **390** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7/10 |
| **190** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7/10 |
| **180** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7/10 |
| **347** | ✅ | ✅ | PDF | ⚠️ Via ExportModels | 7.5/10 |
| **349** | ❌ | ❌ | ❌ | ❌ | 0/10 |

**Nota global Pack Fiscal: 7.0/10**
*(sube a 8.5/10 si se resuelven los 6 puntos críticos)*

---

## 🛠️ QUÉ NECESITO DE TI PARA TERMINAR

Para completar el Pack Fiscal al 100% necesito que me pases:

### 📥 Archivos PDF oficiales AEAT
Los PDFs de formulario rellenables se descargan de la Sede AEAT y se suben a Firebase Storage en:
```
storage://planeaapp-4bea4.firebasestorage.app/templates/fiscal/
  ├─ modelo303_2026.pdf
  ├─ modelo111_2026.pdf
  ├─ modelo115_2026.pdf
  ├─ modelo130_2026.pdf
  ├─ modelo202_2026.pdf
  ├─ modelo390_2026.pdf
  ├─ modelo190_2026.pdf
  ├─ modelo180_2026.pdf
  └─ modelo347_2026.pdf
```
Sin estos archivos, la generación de PDF con datos de la AEAT no funciona.

### ⚙️ Configuración fiscal de la empresa
Para calcular correctamente necesito saber si la empresa de prueba (`37KyODVYpXYD04VwG3Vf`) tiene:
- [ ] NIF/CIF de la empresa en Firestore (`datos_fiscales.nif`)
- [ ] Razón social legal (`datos_fiscales.razon_social`)
- [ ] ¿Es autónomo (130) o sociedad (202)?
- [ ] ¿Tiene actividades en régimen simplificado de IVA?
- [ ] ¿Tiene arrendamientos (local de negocio)?

### 🔑 Decisión de implementación
- ¿Implemento el **Modelo 349** (intracomunitarias)? Requiere 1-2 días.
- ¿El **calendario fiscal con alertas push** es prioridad ahora?
- ¿Quieres el **fichero XML/txt** para el 111, 115 y 347 además del 303?

---

## ✅ LO QUE HAGO YO (sin necesitar nada de ti)

Puedo implementar ahora mismo:

1. **Añadir `ExportModelsScreen` a la navegación** — en `ModuloFacturacionScreen`
2. **Añadir `Modelo130Screen` a `ExportModelsScreen`**
3. **Añadir `SubirCertificadoVerifactuScreen` a configuración fiscal**
4. **Calendario fiscal** — Cloud Function scheduled + pantalla de vencimientos
5. **Historial de presentaciones** — pantalla que muestra el estado de cada modelo por trimestre
6. **Modelo 349** — backend + pantalla Flutter completa
7. **Badge de estado** en `ExportModelsScreen` (calculado/presentado/pendiente)

¿Quieres que empiece por alguno de estos?

---

*Auditoría Pack Fiscal: 21 Abril 2026*


