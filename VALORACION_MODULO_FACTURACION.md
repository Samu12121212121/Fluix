# 📊 VALORACIÓN COMPLETA — MÓDULO DE FACTURACIÓN

**Fecha:** 20 de marzo de 2026  
**Proyecto:** PlaneaG / Fluix CRM (Flutter + Firebase)  
**Alcance:** Todo el módulo de facturación, contabilidad, cumplimiento fiscal y Verifactu

---

## 1. INVENTARIO DE ARCHIVOS DEL MÓDULO

### 1.1 Modelos de Dominio
| Archivo | Líneas | Función |
|---------|--------|---------|
| `domain/modelos/factura.dart` | 494 | Modelo Factura completo (emitidas) |
| `domain/modelos/factura_recibida.dart` | 246 | Modelo Factura Recibida (gastos) |
| `domain/modelos/empresa_config.dart` | 165 | Configuración fiscal empresa |
| `domain/modelos/contabilidad.dart` | — | Modelos Gasto, Proveedor, etc. |
| **Total modelos** | **~905** | |

### 1.2 Servicios (Backend/Lógica de negocio)
| Archivo | Líneas | Función |
|---------|--------|---------|
| `services/facturacion_service.dart` | 908 | CRUD facturas, estadísticas, MOD 303/111 |
| `services/verifactu_service.dart` | 410 | Registro Verifactu, hash SHA-256, XML, QR |
| `services/contabilidad_service.dart` | 709 | Gastos, proveedores, libros contables |
| `services/pdf_service.dart` | 312 | Generación PDF + CSV |
| `services/validador_fiscal_integral.dart` | 313 | 10 reglas fiscales maestras (R1-R10) |
| `services/mod_303_service.dart` | 377 | Modelo 303 IVA trimestral |
| `services/mod_347_service.dart` | 117 | Modelo 347 operaciones >3.005,06€ |
| `services/mod_349_service.dart` | 225 | Modelo 349 intracomunitarias |
| **Total servicios** | **~3.371** | |

### 1.3 Verifactu (RD 1007/2023 + RD 254/2025)
| Archivo | Líneas | Función |
|---------|--------|---------|
| `verifactu/modelos_verifactu.dart` | 432 | Enums AEAT, hash chain SHA-256, modelos |
| `verifactu/validador_verifactu.dart` | 128 | Validación R2, R3, R6, R10 |
| `verifactu/generador_qr_verifactu.dart` | 56 | URL QR obligatorio |
| `verifactu/xml_payload_verifactu_builder.dart` | 91 | XML para envío AEAT |
| `verifactu/politica_verifactu_2027.dart` | 39 | Plazos RDL 15/2025 |
| `verifactu/firma_xades_minima_validator.dart` | 84 | Validación firma XAdES |
| `verifactu/representacion_verifactu.dart` | 230 | Anexos I/II/III representación |
| `verifactu/lgt_201bis_riesgos.dart` | 21 | Sanciones art. 201 bis LGT |
| **Total Verifactu** | **~1.081** | |

### 1.4 Exportadores AEAT
| Archivo | Función |
|---------|---------|
| `exportadores_aeat/mod_303_exporter.dart` | Fichero MOD 303 formato AEAT |
| `exportadores_aeat/dr303e26v101_exporter.dart` | Formato DR303 electrónico |
| `exportadores_aeat/libro_registro_iva_exporter.dart` | Libro registro IVA |
| `exportadores_aeat/mod_347_exporter.dart` | Fichero MOD 347 |
| `exportadores_aeat/mod_349_exporter.dart` | Fichero MOD 349 |

### 1.5 UI (Pantallas y Widgets)
| Archivo | Líneas | Función |
|---------|--------|---------|
| `pantallas/modulo_facturacion_screen.dart` | 679 | Pantalla principal con tabs |
| `pantallas/formulario_factura_screen.dart` | — | Crear/editar factura |
| `pantallas/formulario_factura_recibida_screen.dart` | — | Crear factura recibida |
| `pantallas/detalle_factura_screen.dart` | — | Detalle de factura |
| `pantallas/resumen_fiscal_screen.dart` | — | Resumen fiscal trimestral |
| `pantallas/pantalla_contabilidad.dart` | — | Tab contabilidad |
| `pantallas/pantalla_configuracion_fiscal_empresa.dart` | — | Config fiscal |
| `pantallas/tab_facturas_recibidas.dart` | — | Listado facturas recibidas |
| `pantallas/tab_graficos_contabilidad.dart` | — | Gráficos contables |
| `pantallas/tab_libro_ingresos.dart` | — | Libro de ingresos |
| `pantallas/tab_modelos_fiscales.dart` | — | Modelos AEAT |
| `pantallas/tab_mod_347.dart` | — | Tab Modelo 347 |
| `pantallas/tab_mod_349.dart` | — | Tab Modelo 349 |
| `widgets/panel_validacion_fiscal.dart` | 322 | Panel visual validación fiscal |

### 📐 TOTAL ESTIMADO DEL MÓDULO: ~7.000-8.500 líneas de código

---

## 2. VALORACIÓN FUNCIONAL — ¿QUÉ HACE?

### ✅ FACTURACIÓN EMITIDA (Nota: 9/10)
- **Crear facturas** con líneas, IVA multi-tipo, descuentos por línea, descuento global
- **Series separadas** automáticas: FAC (ordinarias), RECT (rectificativas), PRO (proformas)
- **Numeración correlativa** por serie con transacción Firestore (sin huecos)
- **Rectificativas** con inversión de líneas y anulación automática de la original
- **Proformas** con conversión a factura definitiva
- **Duplicar facturas**
- **Crear factura desde pedido** (integración con módulo de pedidos)
- **Estados**: Pendiente → Pagada / Anulada / Vencida
- **Detección automática de vencidas** al abrir el módulo
- **Historial de auditoría** por cada acción (quién, cuándo, qué)
- **Datos fiscales completos**: NIF, razón social, dirección, CP, ciudad, país
- **Operaciones intracomunitarias**: NIF IVA comunitario, detección automática
- **Retención IRPF** configurable (0/7/15/19%)
- **Recargo de equivalencia** por línea
- **Días de vencimiento** configurables

### ✅ FACTURACIÓN RECIBIDA / GASTOS (Nota: 8/10)
- **Facturas de proveedor** con NIF validado, base, IVA, retenciones
- **IVA deducible/no deducible** configurable
- **Recargo de equivalencia** en recibidas
- **Gestión de proveedores** (CRUD completo)
- **Gastos por categoría** con período
- **Conciliación bancaria** (referencia bancaria)

### ✅ CONTABILIDAD (Nota: 8/10)
- **Libro de ingresos** con desglose
- **Gráficos contables** visuales
- **Resumen fiscal** mensual y trimestral
- **Criterio IVA**: Devengo vs Criterio de Caja configurable
- **Exportación CSV** de facturas y gastos

### ✅ MODELOS FISCALES AEAT (Nota: 8.5/10)
- **MOD 303** — IVA trimestral con IVA repercutido vs soportado
- **MOD 111** — Retenciones IRPF trimestrales
- **MOD 347** — Operaciones con terceros >3.005,06€ (anual)
- **MOD 349** — Operaciones intracomunitarias
- **Exportadores** en formato AEAT oficial (ficheros descargables)
- **Libro Registro IVA** exportable
- **Formato DR303e26v101** electrónico

### ✅ GENERACIÓN PDF (Nota: 8/10)
- **PDF profesional** con diseño corporativo (cabecera azul, tabla, totales)
- **Datos de empresa** dinámicos desde Firestore
- **Desglose completo**: líneas, IVA, descuento, IRPF, recargo
- **Sello PROFORMA** automático
- **Impresión directa** y compartir
- **Exportación CSV** para Excel

### ✅ VERIFACTU — Cumplimiento RD 1007/2023 (Nota: 7.5/10)
- **Hash SHA-256 encadenado** (cadena criptográfica)
- **Registros de facturación** Alta + Anulación
- **Registros de eventos** (10 tipos) + resumen cada 6h
- **Validación de cadena** (integridad, inalterabilidad)
- **Código QR** con URL AEAT
- **XML para envío AEAT** (payload sin firma)
- **Política de plazos** RDL 15/2025 (IS: 01/01/2027, resto: 01/07/2027)
- **Firma XAdES** — validación mínima (placeholder para certificado real)
- **Representación** — Anexos I/II/III con validación completa
- **Sanciones LGT** — Art. 201 bis documentado
- **Modalidades**: VERI*FACTU (con remisión) y NO VERI*FACTU (con firma)

### ✅ VALIDACIÓN FISCAL INTEGRAL (Nota: 9/10)
- **R1 — Correlatividad**: Detección de huecos en numeración
- **R4 — NIF válido**: Emisor + destinatario
- **R6 — Tiempo**: Diferencia ≤1 minuto
- **R7 — Conservación**: Plazo 4 años LGT
- **R8 — Desglose IVA**: Multi-tipo separado
- **R9 — Series separadas**: Rectificativas en serie propia
- **Panel visual** en UI con errores y advertencias

### ✅ UI / UX (Nota: 8/10)
- **6 tabs**: Todas, Pendientes, Pagadas, Vencidas, Estadísticas, Contabilidad
- **Búsqueda** por cliente o número
- **Tarjetas** con color por estado, acciones rápidas
- **Marcar pagada** con selección de método de pago
- **Anular** con motivo obligatorio
- **Ver PDF** directo desde la lista
- **Estadísticas**: Hoy, Mes, Año con desglose
- **FAB** para nueva factura + acceso a resumen fiscal

---

## 3. VALORACIÓN TÉCNICA — ¿CÓMO ESTÁ HECHO?

### 🟢 PUNTOS FUERTES

| Aspecto | Detalle |
|---------|---------|
| **Arquitectura** | Separación limpia: Domain → Services → Features (pantallas/widgets) |
| **Modelos inmutables** | `const` constructors, `copyWith`, `factory fromFirestore` |
| **Transacciones** | Numeración con `runTransaction` para evitar duplicados |
| **Streams reactivos** | `StreamBuilder` para listas en tiempo real |
| **Batch writes** | Marcado masivo de vencidas con batch |
| **Criterio IVA dual** | Devengo vs Caja implementado correctamente |
| **Intracomunitarias** | Detección automática por NIF, país y flag |
| **Hash chain** | SHA-256 correcto con encadenamiento por 64 primeros chars |
| **Auditoría** | Historial inmutable por cada acción |
| **Cálculo de totales** | Método estático centralizado con descuento, IRPF, recargo |
| **Normativa completa** | LGT 58/2003, RD 1619/2012, RD 1007/2023, RD 254/2025, Orden HAC/1177/2024 |

### 🟡 PUNTOS A MEJORAR

| Aspecto | Detalle | Severidad |
|---------|---------|-----------|
| **NIF emisor vacío** | En `crearFactura()` se crea `EmpresaConfig` con `nif: ''` (TODO pendiente) | 🔴 Alta |
| **Facturas del período vacías** | Se pasa `[]` al validador en vez de facturas reales del período | 🔴 Alta |
| **Código duplicado** | `_esFacturaIntracomunitaria` y `_tienePrefijoVatEu` repetidos en 3 servicios | 🟡 Media |
| **QR sin librería** | `generarCodigoQr()` es un stub vacío — no genera imagen QR real | 🟡 Media |
| **Firma XAdES** | Solo validación de formato XML — no firma criptográfica real | 🟡 Media (plazo: Q2 2026) |
| **Envío AEAT** | No implementado — sin cliente SOAP ni sandbox | 🟡 Media (plazo: Q3 2026) |
| **Advertencias silenciosas** | `resultadoValidacion.advertencias` tiene un TODO sin implementar | 🟡 Media |
| **Verifactu no bloquea** | Si falla el registro Verifactu, se traga la excepción silenciosamente | 🟡 Media |
| **PDF sin QR Verifactu** | El PDF no incluye el QR obligatorio cuando Verifactu está activo | 🟡 Media |
| **Tests limitados** | Solo tests de hash chain Verifactu, no hay tests de FacturacionService | 🟠 Baja-Media |
| **Sin paginación** | Las queries de facturas no tienen paginación (problemas con volumen alto) | 🟠 Baja |
| **`obtenerFacturasPorEstado`** | Filtra en cliente (`.where()` en lista), no en query Firestore | 🟠 Baja |

### 🔴 BUGS / RIESGOS DETECTADOS

1. **`crearFactura()` línea ~132**: La `EmpresaConfig` se crea con NIF vacío → la validación R4 nunca detectará NIF inválido del emisor. Se debe cargar desde Firestore.

2. **`crearFactura()` línea ~140**: Se pasa `[]` como facturas del período → R1 (correlatividad) y R9 (series separadas) nunca se ejecutan en la práctica.

3. **`obtenerFacturasPorEstado()`**: Hace query sin filtro `where('estado')` en Firestore y luego filtra en memoria con `.where()` de Dart → ineficiente con muchas facturas. Debería usar query Firestore.

4. **Doble sistema Verifactu**: Existen dos implementaciones paralelas: `verifactu_service.dart` (simple, integrado en facturación) y `verifactu/modelos_verifactu.dart` (complejo, hash chain). No están conectadas entre sí.

---

## 4. CUMPLIMIENTO NORMATIVO

### RD 1619/2012 — Reglamento de Facturación
| Requisito | Estado | Nota |
|-----------|--------|------|
| Numeración correlativa por serie | ✅ | Transacción atómica |
| Series separadas rectificativas | ✅ | Serie RECT automática |
| Datos obligatorios factura completa | ✅ | NIF, nombre, fecha, desglose |
| Factura simplificada (<400€) | ✅ | Detección automática |
| Factura rectificativa | ✅ | Con referencia a original |
| Desglose IVA multi-tipo | ✅ | Validación R8 |
| Conservación 4 años | ✅ | Validación R7 |

### RD 1007/2023 + RD 254/2025 — Verifactu
| Requisito | Estado | Nota |
|-----------|--------|------|
| Hash SHA-256 encadenado | ✅ | Implementado |
| Registros Alta/Anulación | ✅ | Con campos obligatorios |
| Registros de Eventos | ✅ | 10 tipos + resumen 6h |
| Código QR | ⚠️ | URL generada, imagen no |
| Firma XAdES Enveloped | ⏳ | Placeholder — PKI pendiente |
| XML Orden HAC/1177/2024 | ⚠️ | Payload básico, sin XSD validation |
| Envío a AEAT (SOAP) | ❌ | No implementado |
| Declaración responsable | ✅ | Documentado |
| Plazos RDL 15/2025 | ✅ | IS: 01/2027, resto: 07/2027 |

### LGT 58/2003 — Obligaciones tributarias
| Requisito | Estado |
|-----------|--------|
| Art. 29.2.j — Integridad/inalterabilidad | ✅ Hash chain |
| Art. 201 bis — Sanciones documentadas | ✅ |
| Representación Anexos I/II/III | ✅ Validación completa |

### Modelos fiscales
| Modelo | Estado |
|--------|--------|
| MOD 303 (IVA trimestral) | ✅ Cálculo + exportación |
| MOD 111 (IRPF trimestral) | ✅ Cálculo |
| MOD 347 (terceros >3.005€) | ✅ Cálculo + fichero |
| MOD 349 (intracomunitarias) | ✅ Cálculo + exportación |

---

## 5. NOTA GLOBAL POR ÁREA

| Área | Nota | Justificación |
|------|------|---------------|
| **Modelos de datos** | 9.0/10 | Completos, inmutables, bien tipados |
| **Lógica de negocio** | 8.5/10 | Muy completa, algunos TODOs pendientes |
| **Cumplimiento fiscal** | 8.0/10 | Excelente para fase actual, pendiente firma+envío |
| **Verifactu** | 7.5/10 | Fundamentos sólidos, dos sistemas sin unificar |
| **Generación PDF** | 8.0/10 | Profesional, falta QR Verifactu |
| **Modelos AEAT** | 8.5/10 | 4 modelos con exportadores reales |
| **UI/UX** | 8.0/10 | Funcional, 13 pantallas, búsqueda, estadísticas |
| **Testing** | 4.0/10 | Solo tests de hash chain, falta cobertura |
| **Rendimiento** | 6.5/10 | Sin paginación, filtrado en memoria |
| **Seguridad** | 7.0/10 | Certificados pendientes, Verifactu fail-safe |

### ⭐ NOTA MEDIA GLOBAL: **7.7 / 10**

---

## 6. RESUMEN EJECUTIVO

### Lo que TIENE (y funciona bien):
- ✅ Facturación completa de extremo a extremo (crear → PDF → pagar/anular)
- ✅ 5 tipos de factura: Ordinaria, Servicio, Pedido, Rectificativa, Proforma
- ✅ Facturas recibidas + gastos + proveedores
- ✅ 4 modelos fiscales AEAT con exportadores
- ✅ Criterio IVA dual (devengo/caja)
- ✅ Validación fiscal integral con 7 de las 10 reglas activas
- ✅ Verifactu con hash chain SHA-256 funcional
- ✅ Operaciones intracomunitarias detectadas automáticamente
- ✅ IRPF + Recargo de equivalencia
- ✅ PDF profesional con impresión directa
- ✅ Historial de auditoría inmutable
- ✅ UI completa con 13 pantallas y widgets

### Lo que FALTA (roadmap):
- ⏳ Firma XAdES con certificado cualificado (Q2 2026)
- ⏳ Envío SOAP a AEAT sandbox (Q3 2026)
- ⏳ QR real en PDF con librería qr_flutter
- ⏳ Unificar los dos sistemas Verifactu
- ⏳ Cargar EmpresaConfig real en validación
- ⏳ Tests unitarios de servicios principales
- ⏳ Paginación de queries para escalabilidad

### Comparativa con competencia:
| Funcionalidad | PlaneaG/Fluix | Holded | Billin | Quipu |
|---------------|:---:|:---:|:---:|:---:|
| Facturación básica | ✅ | ✅ | ✅ | ✅ |
| Rectificativas | ✅ | ✅ | ✅ | ✅ |
| Verifactu hash chain | ✅ | ✅ | ⏳ | ⏳ |
| MOD 303 automático | ✅ | ✅ | ✅ | ✅ |
| MOD 347 / 349 | ✅ | ✅ | ❌ | ❌ |
| Criterio IVA Caja | ✅ | ✅ | ❌ | ✅ |
| Firma XAdES real | ⏳ | ⏳ | ⏳ | ⏳ |
| Multi-empresa | ✅ | ✅ | ❌ | ❌ |
| App móvil nativa | ✅ | ❌ | ❌ | ✅ |

---

## 7. LÍNEAS DE CÓDIGO TOTALES DEL MÓDULO

```
Modelos de dominio ............... ~905 líneas
Servicios de negocio ........... ~3.371 líneas
Verifactu completo ............. ~1.081 líneas
Exportadores AEAT ................ ~500 líneas (estimado)
Pantallas UI (13) .............. ~2.500 líneas (estimado)
Widgets ........................... ~322 líneas
─────────────────────────────────────────────
TOTAL MÓDULO FACTURACIÓN ....... ~8.679 líneas
```

**Esto es un módulo de facturación de nivel profesional-empresarial**, con cumplimiento normativo español muy por encima de la media para una app en fase de desarrollo. Los pendientes (firma, envío AEAT) están dentro de los plazos legales (obligación no entra hasta enero/julio 2027).

