# ESTADO MÓDULO FISCAL — Abril 2026

> Documento generado: 2026-04-17

---

## ✅ QUÉ ESTÁ IMPLEMENTADO

### Backend — Cloud Functions (TypeScript)

| Componente | Archivo | Estado |
|---|---|---|
| Prompt IA versionado (9 bloques) | `functions/src/fiscal/prompts/invoiceExtractionV1.ts` | ✅ Implementado |
| Versión del prompt | `PROMPT_VERSION = 'invoice_es_v1_2026_04'` | ✅ |
| Soporte DocAI entities | `extractWithClaude()` con ENTIDADES_DOCAI | ✅ Implementado |
| Retry automático (JSON malformado / rate-limit) | `extractWithRetry()` | ✅ Implementado |
| Cloud Function `processInvoice` | Procesamiento completo con OCR + Claude | ✅ |
| Guardado `withholding_amount_cents`, `due_date`, `supplier_iban` | fiscal_transactions | ✅ Nuevo |
| **Calculador Modelo 303** — IVA trimestral | `models/model303.ts` | ✅ Implementado |
| **Calculador Modelo 111** — Ret. IRPF trimestral | `models/model111.ts` | ✅ Implementado |
| **Calculador Modelo 115** — Ret. alquileres trimestral | `models/model115.ts` | ✅ Implementado |
| **Calculador Modelo 202** — Pago fraccionado IS | `models/model202.ts` | ✅ Implementado (simplificado) |
| **Calculador Modelo 390** — Resumen anual IVA | `models/model390.ts` | ✅ Implementado |
| **Calculador Modelo 190** — Resumen anual IRPF | `models/model190.ts` | ✅ Implementado |
| **Calculador Modelo 180** — Resumen anual arrendamientos | `models/model180.ts` | ✅ Implementado |
| **Calculador Modelo 347** — Operaciones con terceros | `models/model347.ts` | ✅ Implementado |
| Cloud Function `calculateFiscalModel` (router 8 modelos) | `models/calculateModel.ts` | ✅ Implementado |
| Generador pre-declaración Modelo 303 (formato posicional AEAT) | `exports/model303PreDec.ts` | ✅ Implementado (casillas principales) |
| Generador PDF relleno con pdf-lib | `exports/generateModelPdf.ts` | ✅ Implementado (requiere templates en Storage) |

### Flutter — Pantallas

| Pantalla | Archivo | Estado |
|---|---|---|
| Upload de facturas IA | `upload_invoice_screen.dart` | ✅ Existía |
| Modelo 303 — IVA trimestral | `modelo303_screen.dart` | ✅ Existía |
| Modelo 111 — Retenciones IRPF | `modelo111_screen.dart` | ✅ Existía |
| Modelo 115 — Retenciones alquileres | `modelo115_screen.dart` | ✅ Existía |
| Modelo 130 — Pagos fraccionados IRPF autónomos | `modelo130_screen.dart` | ✅ Existía |
| Modelo 190 — Resumen anual IRPF | `modelo190_screen.dart` | ✅ Existía |
| Modelo 202 — Pagos fraccionados IS | `modelo202_screen.dart` | ✅ Existía |
| Modelo 390 — Resumen anual IVA | `modelo390_screen.dart` | ✅ Existía |
| **Modelo 180 — Resumen anual arrendamientos** | `modelo180_screen.dart` | ✅ **Nuevo** |
| **Modelo 347 — Operaciones con terceros** | `modelo347_screen.dart` | ✅ **Nuevo** |
| **ExportModelsScreen — wizard unificado 8 modelos** | `export_models_screen.dart` | ✅ **Nuevo** |

### Flutter — Servicios

| Servicio | Archivo | Estado |
|---|---|---|
| `Mod303Service` | `services/mod_303_service.dart` | ✅ Existía |
| `Modelo111Service` + PDF | `services/modelo111_service.dart` | ✅ Existía |
| `Mod115Calculator` + Exporter | `services/fiscal/mod115_calculator.dart` | ✅ Existía |
| `Mod130Calculator` | `services/fiscal/mod130_calculator.dart` | ✅ Existía |
| `Mod202Calculator` | `services/fiscal/mod202_calculator.dart` | ✅ Existía |
| `Mod390Calculator` | `services/fiscal/mod390_calculator.dart` | ✅ Existía |
| `Modelo190Service` | `services/modelo190_service.dart` | ✅ Existía |
| `Mod347Service` | `services/mod_347_service.dart` | ✅ Existía |
| **`Mod180Calculator`** | `services/fiscal/mod180_calculator.dart` | ✅ **Nuevo** |
| `ValidadorFiscalIntegral` | `services/validador_fiscal_integral.dart` | ✅ Existía |

### Exportadores AEAT (Flutter)

| Modelo | Archivo | Estado |
|---|---|---|
| 303 posicional (DR303E26V101) | `exportadores_aeat/dr303e26v101_exporter.dart` | ✅ Existía |
| 303 genérico | `exportadores_aeat/mod_303_exporter.dart` | ✅ Existía |
| 111 AEAT | `exportadores_aeat/modelo111_aeat_exporter.dart` | ✅ Existía |
| 115 | `services/fiscal/mod115_exporter.dart` | ✅ Existía |
| 130 | `services/fiscal/mod130_exporter.dart` | ✅ Existía |
| 202 | `services/fiscal/mod202_exporter.dart` | ✅ Existía |
| 390 posicional | `services/fiscal/mod390_posicional_service.dart` | ✅ Existía |
| 347 | `exportadores_aeat/mod_347_exporter.dart` | ✅ Existía |
| 349 | `exportadores_aeat/mod_349_exporter.dart` | ✅ Existía |
| Libro registro IVA | `exportadores_aeat/libro_registro_iva_exporter.dart` | ✅ Existía |

---

## ⚠️ QUÉ FALTA PARA PRODUCCIÓN REAL

### Prioridad CRÍTICA (sin esto no se puede presentar)

#### 1. Templates PDF oficiales en Firebase Storage
- **Qué falta**: Subir a `gs://TU_BUCKET/templates/fiscal/modelo{code}_{year}.pdf` los PDFs
  oficiales rellenables de la AEAT para cada año.
- **Cómo**: Descarga los PDFs de https://sede.agenciatributaria.gob.es/Sede/modelos-formularios
  y sube a Storage con la nomenclatura esperada.
- **Riesgo si no se hace**: `generateModelPdf.ts` lanza error al intentar generar PDF.

#### 2. Mapeo exacto de campos PDF para cada modelo
- El archivo `generateModelPdf.ts` intenta nombres de campo genéricos (`Casilla_XX`, `CXX`).
- La AEAT usa nombres de campo específicos en cada PDF (ej: `C[28]`, `Base21`...).
- **Acción**: Inspeccionar cada PDF con pdf-lib o Adobe Acrobat y mapear los nombres exactos.
- **Referencia**: Archivo `exports/generateModelPdf.ts` — función `generarModeloPdf()`.

#### 3. Diseño de registros completo del Modelo 303
- El archivo `exports/model303PreDec.ts` implementa las casillas principales pero NO el
  diseño completo del registro (que tiene ~2000 caracteres en el formato oficial 2026).
- **Acción**: Descargar "Diseño de registros Modelo 303 — 2026" de AEAT y completar
  la función `generarPreDec303()`.
- **Nota**: El diseño cambia cada año. Crear versión por año.

#### 4. Diseños de registros para 111, 115, 190, 180, 347
- Solo está el pre-declaración para 303. Los demás necesitan su propio generador posicional.
- **Referencia**: Ya existen exportadores en Flutter para 111, 115, 347. Portar la lógica
  al backend TypeScript o implementar la descarga desde la Cloud Function.

#### 5. `calculateFiscalModel` no tiene `pdf-lib` en `package.json`
- **Acción**: `cd functions && npm install pdf-lib`
- Sin esto el build de functions fallará al compilar `generateModelPdf.ts`.

---

### Prioridad ALTA (calidad y fiabilidad)

#### 6. Modelo 202 simplificado
- El calculador usa las `fiscal_transactions` como proxy del resultado contable.
- Para empresas reales, el resultado contable viene del módulo de contabilidad, no de facturas.
- **Acción**: Integrar con `contabilidad_service.dart` cuando esté disponible.
- **Workaround actual**: El modelo marca `warnings` alertando al usuario.

#### 7. `calculateFiscalModel` no genera fichero pre-declaración
- La CF devuelve el JSON calculado pero no el fichero TXT posicional.
- **Acción**: Añadir endpoint `generatePreDec` que llame a `generarPreDec303()` y devuelva
  el fichero como base64 o lo suba a Storage.

#### 8. DocAI entities en `processInvoice`
- El campo `doc.docai_entities` se leerá de Firestore pero actualmente el pipeline OCR
  no guarda las entidades de Document AI en el documento fiscal.
- **Acción**: En el paso Document AI (`callDocumentAI()`), extraer también las entidades
  estructuradas y guardarlas en `fiscal_documents/{id}.docai_entities`.

#### 9. Test unitarios de los 8 calculadores de modelos
- Ningún calculador tiene tests automáticos.
- **Acción**: Crear `functions/src/fiscal/models/__tests__/` con casos de prueba reales
  (factura normal, margen, intracomunitaria, retención).

---

### Prioridad MEDIA (mejoras operativas)

#### 10. Exportador 180 en Flutter no existe
- `Mod180Calculator` está listo pero no hay exportador AEAT posicional (`.txt`).
- **Acción**: Crear `lib/services/fiscal/mod180_exporter.dart` basándose en `mod115_exporter.dart`.

#### 11. Modelo 349 pendiente de implementar
- Para clientes con operaciones intracomunitarias.
- El exportador Flutter `mod_349_exporter.dart` ya existe.
- **Acción**: Crear calculador backend `model349.ts` + pantalla Flutter cuando haya demanda.

#### 12. Modelo 130 (autónomos IRPF)
- La pantalla `modelo130_screen.dart` y `mod130_calculator.dart` ya existen.
- Falta integrar con el calculador backend `calculateFiscalModel`.

#### 13. `ExportModelsScreen` no tiene pantalla `Modelo115Screen`
- La pantalla 115 existe pero la importación en `export_models_screen.dart` asume
  que tiene constructor `(empresaId, anioInicial)`. Verificar firma real.

#### 14. Calendario fiscal no se actualiza automáticamente
- Los plazos en `ExportModelsScreen._generarPlazos()` son fechas fijas.
- **Acción**: Cargar plazos desde Firestore o `CalendarioFiscalService`.

---

### Infraestructura y despliegue

#### 15. Variables de entorno / secretos
```
ANTHROPIC_API_KEY   → Firebase Secret Manager
DOCAI_PROCESSOR_ID  → Firebase Secret Manager
```
Verificar que ambos secretos están configurados antes de desplegar:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set DOCAI_PROCESSOR_ID
```

#### 16. Índices Firestore para `calculateFiscalModel`
La CF hace una query compuesta sobre `fiscal_transactions`:
```
WHERE status == 'posted' AND period >= '2026-Q1' AND period <= '2026-Q4'
```
**Acción**: Añadir a `firestore.indexes.json`:
```json
{
  "collectionGroup": "fiscal_transactions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "period", "order": "ASCENDING" }
  ]
}
```

#### 17. Reglas Firestore para `fiscal_models`
La colección `empresas/{id}/fiscal_models` no tiene reglas explícitas.
Actualmente cae en el catch-all `deny all`.
**Acción**: Añadir a `firestore.rules`:
```
match /fiscal_models/{modelId} {
  allow read: if perteneceAEmpresa(empresaId);
  allow write: if false; // Solo Cloud Functions pueden escribir
}
```

---

## 📋 RESUMEN EJECUTIVO

| Área | Completado | Pendiente crítico |
|---|---|---|
| Extracción IA (prompt) | ✅ 100% | — |
| 8 calculadores backend | ✅ 100% | Modelo 202 simplificado |
| Cloud Function router | ✅ 100% | pdf-lib en package.json |
| Pre-declaración posicional | ⚠️ 30% | Solo 303, diseño incompleto |
| Generación PDF | ⚠️ 60% | Faltan templates y mapeo campos |
| Pantallas Flutter | ✅ 100% (9 modelos) | Verificar pantalla 115 |
| Servicios Flutter | ✅ 100% (todos) | Exportador 180 |
| Reglas Firestore | ⚠️ 80% | `fiscal_models` sin regla |
| Índices Firestore | ⚠️ 70% | Índice compuesto para CF |

**Estimación para producción real: 3-5 días de trabajo adicional**, principalmente en:
1. Subir templates PDF AEAT + mapear campos (1-2 días)
2. Completar diseño posicional completo del 303 (1 día)
3. Índices Firestore + reglas + instalar pdf-lib (medio día)
4. Tests unitarios de calculadores (1 día opcional pero recomendado)

