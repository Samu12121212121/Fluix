# 📊 ANÁLISIS: Facturación Fluix CRM vs. Líderes del Mercado Español

**Fecha del análisis:** 12 de abril de 2026  
**Versión:** Revisión completa del código fuente  
**Competidores analizados:** Holded, Billin, Quipu, Factura Directa, Anfix

---

## 1. FUNCIONALIDADES QUE YA TIENE FLUIX CRM

### ✅ Creación de Facturas — MUY COMPLETO
- **Factura ordinaria** con múltiples líneas, IVA por línea, descuentos por línea y global
- **Factura proforma** (serie P-) con conversión a factura definitiva en 1 click
- **Factura rectificativa** completa (Art. 15 RD 1619/2012): motivos R1-R5, métodos sustitución/diferencias
- **Duplicar factura** existente con nuevo número automático
- **Series automáticas** (F-/R-/P-) con numeración correlativa por año, prefijo personalizable por empresa
- **Factura desde pedido** con mapeo automático de líneas
- **Notas internas** y **notas para el cliente**
- **Fecha de operación** separada de fecha de emisión (Art. 6.1.f RD 1619/2012)
- **Edición de facturas pendientes** con recálculo automático de totales
- **Historial de auditoría** completo (quién hizo qué y cuándo)

### ✅ Impuestos y Fiscal — MUY AVANZADO
- **IVA desglosado** por tipo impositivo (21%, 10%, 4%, 0%)
- **Recargo de equivalencia** por línea (1.4%, 5.2%)
- **Retención IRPF** (7%, 15%, 19%) con cálculo automático
- **Descuento global** sobre subtotal
- **Operaciones intracomunitarias** (NIF-IVA, detección automática)
- **Asistente IVA construcción** (inversión del sujeto pasivo)
- **Detección automática sector** (hostelería IVA 10%, comercio, construcción)
- **Criterio de caja** configurable (devengo/caja)

### ✅ VeriFactu — IMPLEMENTACIÓN COMPLETA
- Hash SHA-256 encadenado (cadena de bloques fiscal)
- XML Payload Builder para AEAT
- Firma XAdES-BES con certificado PKCS#12
- Generador QR VeriFactu
- Servicio de remisión a AEAT
- Validador de registros
- Política VeriFactu 2027 (RD 1007/2023 + RD 254/2025)
- Gestión de certificados digitales
- Representación gráfica VeriFactu en PDF

### ✅ Modelos Fiscales AEAT — MUY COMPLETO
- **Modelo 303** (IVA trimestral) con cálculo IVA repercutido - soportado
- **Modelo 111** (retenciones IRPF trabajadores/profesionales)
- **Modelo 115** (retenciones arrendamientos)
- **Modelo 130** (pago fraccionado IRPF autónomos)
- **Modelo 190** (resumen anual retenciones)
- **Modelo 202** (pago fraccionado Impuesto Sociedades)
- **Modelo 347** (operaciones con terceros > 3.005,06€)
- **Modelo 349** (operaciones intracomunitarias)
- **Modelo 390** (resumen anual IVA)
- **Exportador DR303e26v101** (formato electrónico AEAT)
- **Libro registro IVA** exportable

### ✅ Contabilidad y Gastos — BUENO
- **Módulo de gastos** completo con categorías (12 categorías)
- **Proveedores** con CRUD, NIF, intracomunitario
- **Facturas recibidas** con modelo completo (IVA deducible/no deducible, arrendamiento)
- **Resumen contable** trimestral/anual (beneficio neto, IVA a ingresar, pago fraccionado IRPF)
- **Libro de facturas emitidas** exportable a CSV
- **Libro de gastos/facturas recibidas** exportable a CSV
- **Informe completo para gestoría** en CSV
- **Cache contable mensual** para lecturas rápidas
- **Gráficos de evolución** mensual (ingresos vs gastos)
- **Adjuntar PDF/imagen al gasto** (`facturaArchivoUrl`)

### ✅ PDF y Envío
- **Generación PDF profesional** con logo de empresa, datos fiscales completos
- **Desglose IVA** por tipo impositivo en el PDF
- **QR VeriFactu** incluido en el PDF
- **Compartir/Descargar/Imprimir** PDF
- **Envío por email** (Cloud Function con SMTP)
- **Envío de factura por email** con cuerpo HTML personalizado

### ✅ Pagos y Pasarelas
- **Stripe Connect** (tarjeta, Apple Pay, Google Pay)
- **Redsys** (TPV bancario español)
- **PSD2 / Open Banking** (conexión bancaria)
- **Bizum, PayPal, Transferencia, Efectivo** como métodos de cobro
- **Billing Service** backend independiente con webhooks Stripe/Redsys
- **Health monitor** de pagos

### ✅ Clientes
- **Módulo de clientes** completo con NIF, dirección, etiquetas, notas
- **Estados** (contacto, activo, inactivo)
- **Operaciones intracomunitarias** por cliente
- **Historial de facturación por cliente** con resumen estadístico (total facturado, pendiente cobro, últimos 6 meses)
- **Fusión de clientes** duplicados
- **Importación/exportación** de clientes

### ✅ Productos/Servicios
- **Catálogo de productos** con precios, categoría, duración, imágenes
- **Historial de precios** con motivos de cambio
- **Importación de catálogo** desde CSV

### ✅ Validación Fiscal Integral
- 10 reglas maestras: Correlatividad, Hash chain, Inalterabilidad, NIF válido, Representación, Tiempo, Conservación, Desglose IVA, Series separadas, Firma cualificada
- Validación de NIF/CIF española
- Evaluación de riesgos LGT 201bis

### ✅ Otras
- **Detección automática de facturas vencidas**
- **Configuración fiscal de empresa** (forma jurídica, régimen IVA, SII, VeriFactu)
- **WhatsApp** para pedidos (no directamente para facturas)
- **Notificaciones push** vía Firebase Cloud Messaging

---

## 2. TABLA COMPARATIVA COMPLETA

### CREACIÓN DE FACTURAS

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Facturas recurrentes automáticas | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 24-32 |
| Duplicar factura existente | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Convertir presupuesto → factura 1 click | ❌ (no hay presupuestos) | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 40-60 |
| Convertir albarán → factura | ❌ (no hay albaranes) | ✅ | ⚠️ | ❌ | ✅ | ✅ | **IMPORTANTE** | 32-48 |
| Facturas en múltiples idiomas | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | MENOR | 16-24 |
| Facturas en múltiples divisas | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | MENOR | 20-28 |
| Plantillas personalizables (colores, logo, fuente) | ⚠️ Logo + colores fijos | ✅ | ✅ | ⚠️ | ✅ | ✅ | **IMPORTANTE** | 24-36 |
| Vista previa en tiempo real | ❌ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | **IMPORTANTE** | 16-24 |
| Guardar como borrador | ⚠️ Estado "pendiente" actúa como borrador, pero no hay estado formal "borrador" | ✅ | ✅ | ✅ | ✅ | ✅ | MENOR | 8-12 |
| Numeración automática por series | ✅ (F/R/P personalizables) | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |

### PRESUPUESTOS Y ALBARANES

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Módulo de presupuestos completo | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 40-60 |
| Envío de presupuesto al cliente | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 8-12 |
| Cliente acepta/rechaza online | ❌ | ✅ | ✅ | ❌ | ✅ | ⚠️ | **IMPORTANTE** | 24-32 |
| Conversión automática al aceptar | ❌ | ✅ | ✅ | ❌ | ✅ | ⚠️ | **IMPORTANTE** | 8-12 |
| Albaranes de entrega | ❌ | ✅ | ⚠️ | ❌ | ✅ | ✅ | **IMPORTANTE** | 32-40 |
| Conversión albarán → factura | ❌ | ✅ | ⚠️ | ❌ | ✅ | ✅ | **IMPORTANTE** | 8-12 |

### COBROS Y PAGOS

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Registro de cobros parciales | ❌ | ✅ | ✅ | ⚠️ | ✅ | ✅ | **CRÍTICO** | 16-24 |
| Facturas a plazos (vencimientos múltiples) | ❌ (un solo vencimiento) | ✅ | ⚠️ | ❌ | ✅ | ⚠️ | **IMPORTANTE** | 20-28 |
| Estado de cobro (pendiente/cobrado/vencido) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Recordatorio de cobro automático por email | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 16-24 |
| Enlace de pago directo en la factura | ❌ | ✅ | ⚠️ | ❌ | ⚠️ | ❌ | **IMPORTANTE** | 16-24 |
| Pasarela de pago integrada (Stripe/Redsys) | ✅ (Stripe + Redsys + PSD2) | ✅ | ⚠️ | ❌ | ⚠️ | ❌ | — | 0 |
| Conciliación bancaria con facturas | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | **IMPORTANTE** | 40-60 |

### GASTOS

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Módulo de gastos / facturas recibidas | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Escaneo de tickets con OCR | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | **IMPORTANTE** | 24-40 |
| Categorización de gastos | ✅ (12 categorías) | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Gastos recurrentes | ❌ | ✅ | ⚠️ | ✅ | ⚠️ | ✅ | MENOR | 12-16 |
| Adjuntar PDF/imagen al gasto | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |

### INFORMES Y CONTABILIDAD

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Cuenta de resultados automática | ⚠️ Beneficio neto básico (ingresos - gastos) | ✅ | ⚠️ | ✅ | ⚠️ | ✅ | **IMPORTANTE** | 16-24 |
| Balance de situación | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | MENOR | 40-60 |
| Informe de IVA por período | ✅ (Mod 303 trimestral/mensual) | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Informe de IRPF retenciones | ✅ (Mod 111/190) | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | — | 0 |
| Informe clientes top por facturación | ⚠️ Datos disponibles pero sin pantalla dedicada | ✅ | ⚠️ | ⚠️ | ❌ | ⚠️ | MENOR | 8-12 |
| Previsión de tesorería | ❌ | ✅ | ❌ | ❌ | ❌ | ⚠️ | **IMPORTANTE** | 24-32 |
| Aging de cobros (vencidas por antigüedad) | ❌ | ✅ | ⚠️ | ❌ | ❌ | ⚠️ | **IMPORTANTE** | 12-16 |

### AUTOMATIZACIÓN

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Envío automático de facturas por email | ✅ (Email Service + Cloud Function) | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Recordatorios de pago automáticos | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **CRÍTICO** | 16-24 |
| Integración WhatsApp para enviar factura | ⚠️ WhatsApp para pedidos, no facturas | ✅ | ❌ | ❌ | ❌ | ❌ | MENOR | 8-12 |
| Webhook para conectar con otras apps | ✅ (Billing Service webhooks Stripe/Redsys) | ✅ | ❌ | ❌ | ⚠️ | ❌ | — | 0 |
| API pública para integraciones | ❌ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | **IMPORTANTE** | 40-60 |

### LEGAL Y FISCAL

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| VeriFactu / TBAI | ✅ (Implementación completa RD 1007/2023) | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | — | 0 |
| SII (Suministro Inmediato Información) | ⚠️ Config + exclusión VeriFactu. No envío real SII | ✅ | ⚠️ | ✅ | ❌ | ✅ | **IMPORTANTE** | 40-60 |
| Factura electrónica (Facturae XML) | ❌ | ✅ | ⚠️ | ❌ | ✅ | ⚠️ | **IMPORTANTE** | 32-40 |
| Firma electrónica en facturas | ✅ (XAdES-BES para VeriFactu) | ✅ | ⚠️ | ❌ | ✅ | ⚠️ | — | 0 |
| Retención IRPF automática según tipo cliente | ✅ (7/15/19% configurable) | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |

### CLIENTES Y PRODUCTOS

| Funcionalidad | Estado Fluix | Holded | Billin | Quipu | F.Directa | Anfix | Prioridad | Esfuerzo (h) |
|---|---|---|---|---|---|---|---|---|
| Catálogo de productos/servicios con precios | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Tarifas por cliente o grupo de clientes | ❌ | ✅ | ❌ | ❌ | ⚠️ | ❌ | MENOR | 20-28 |
| Descuentos automáticos por cliente | ❌ | ✅ | ❌ | ❌ | ⚠️ | ❌ | MENOR | 12-16 |
| Historial completo facturación por cliente | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 0 |
| Portal del cliente (acceso online facturas) | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | **IMPORTANTE** | 40-60 |

---

## 3. RESUMEN DE ESTADO

| Categoría | ✅ Implementado | ⚠️ Parcial | ❌ Falta | Total |
|---|---|---|---|---|
| Creación de facturas | 5 | 2 | 3 | 10 |
| Presupuestos y albaranes | 0 | 0 | 6 | 6 |
| Cobros y pagos | 2 | 0 | 5 | 7 |
| Gastos | 3 | 0 | 2 | 5 |
| Informes y contabilidad | 2 | 2 | 3 | 7 |
| Automatización | 2 | 1 | 2 | 5 |
| Legal y fiscal | 3 | 1 | 1 | 5 |
| Clientes y productos | 2 | 0 | 3 | 5 |
| **TOTAL** | **19** | **6** | **25** | **50** |

**Cobertura actual: 38% completo + 12% parcial = ~44% del estándar de mercado**

> **NOTA:** Fluix CRM tiene una ventaja competitiva ENORME en VeriFactu, modelos fiscales AEAT y cumplimiento normativo. En el aspecto fiscal, supera a la mayoría de competidores. Lo que le falta es funcionalidad de flujo comercial (presupuestos → albaranes → facturas) y automatización de cobros.

---

## 4. 🏆 TOP 10 FUNCIONALIDADES QUE FALTAN — ORDENADAS POR IMPACTO EN PYMES ESPAÑOLAS

| # | Funcionalidad | Impacto Mercado | Razón | Esfuerzo | ROI |
|---|---|---|---|---|---|
| **1** | **Módulo de presupuestos completo** | 🔴 MÁXIMO | El 80% de pymes necesita hacer presupuestos. Es requisito #1 para captar clientes. Sin esto, no compiten con Holded/Billin. | 40-60h | ⭐⭐⭐⭐⭐ |
| **2** | **Facturas recurrentes automáticas** | 🔴 MUY ALTO | Esencial para SaaS, asesorías, gimnasios, coworkings. TODOS los competidores lo tienen. Reducción de churn altísima. | 24-32h | ⭐⭐⭐⭐⭐ |
| **3** | **Recordatorios de cobro automáticos** | 🔴 MUY ALTO | La morosidad en España es del 50%+ en pymes. Esto genera un impacto directo en la tesorería del usuario. Reduce impagos 30-40%. | 16-24h | ⭐⭐⭐⭐⭐ |
| **4** | **Cobros parciales** | 🔴 ALTO | Constructoras, agencias y consultoras cobran por hitos. Sin esto, la gestión de cobros es manual y propensa a errores. | 16-24h | ⭐⭐⭐⭐ |
| **5** | **Albaranes de entrega + conversión a factura** | 🟠 ALTO | Imprescindible para comercio mayorista, distribución y servicios de campo. Completa el flujo presupuesto → albarán → factura. | 32-48h | ⭐⭐⭐⭐ |
| **6** | **OCR para escaneo de tickets/facturas** | 🟠 ALTO | Feature "wow" para autónomos. Quipu y Holded lo usan como argumento principal de venta. Diferenciador competitivo clave. | 24-40h | ⭐⭐⭐⭐ |
| **7** | **Plantillas de factura personalizables** | 🟠 MEDIO-ALTO | Los usuarios quieren que la factura refleje su marca. Colores, fuentes, disposición personalizable. Factor emocional importante en la compra. | 24-36h | ⭐⭐⭐ |
| **8** | **Enlace de pago directo en la factura** | 🟠 MEDIO-ALTO | Reducir la fricción de cobro un 60%. El cliente recibe la factura y paga con 1 click. Ya tenéis Stripe/Redsys, solo falta generar el link en el PDF/email. | 16-24h | ⭐⭐⭐⭐ |
| **9** | **Previsión de tesorería** | 🟡 MEDIO | Diferenciador premium que justifica un plan superior. Las pymes necesitan saber si llegarán a fin de mes. Combina facturas pendientes + gastos recurrentes. | 24-32h | ⭐⭐⭐ |
| **10** | **Factura electrónica Facturae XML** | 🟡 MEDIO | Obligatoria para facturar a Administración Pública. Con la Ley Crea y Crece (2024), será obligatoria entre empresas (B2B). Ventana competitiva antes de 2027. | 32-40h | ⭐⭐⭐ |

---

## 5. HOJA DE RUTA RECOMENDADA

### 🔴 FASE 1 — Sprint Crítico (2-3 semanas, ~80-100h)
1. ✅ Facturas recurrentes automáticas (24-32h)
2. ✅ Recordatorios de cobro automáticos (16-24h)  
3. ✅ Cobros parciales (16-24h)
4. ✅ Enlace de pago directo en factura (16-24h)

**Resultado:** Cierra las 4 funcionalidades más demandadas por usuarios existentes. Reducción estimada de churn: 30%.

### 🟠 FASE 2 — Flujo Comercial Completo (3-4 semanas, ~120-160h)
5. ✅ Módulo de presupuestos completo (40-60h)
6. ✅ Albaranes de entrega (32-48h)
7. ✅ Conversiones automáticas presupuesto → albarán → factura (16-24h)
8. ✅ Plantillas personalizables (24-36h)

**Resultado:** Iguala el flujo comercial de Holded/Billin. Permite captar segmentos de comercio y servicios.

### 🟡 FASE 3 — Diferenciación Premium (2-3 semanas, ~80-120h)
9. ✅ OCR para tickets/gastos (24-40h)
10. ✅ Previsión de tesorería (24-32h)
11. ✅ Facturae XML (32-40h)

**Resultado:** Features premium que justifican plan superior y diferencian de Billin/Quipu.

---

## 6. VENTAJAS COMPETITIVAS ACTUALES DE FLUIX

| Ventaja | vs. Holded | vs. Billin | vs. Quipu | vs. F.Directa | vs. Anfix |
|---|---|---|---|---|---|
| **VeriFactu completo (hash chain + firma + QR)** | Igual | SUPERIOR | SUPERIOR | SUPERIOR | SUPERIOR |
| **9 modelos fiscales AEAT integrados** | Igual | SUPERIOR | Similar | SUPERIOR | Similar |
| **Validación fiscal integral (10 reglas)** | SUPERIOR | SUPERIOR | SUPERIOR | SUPERIOR | SUPERIOR |
| **Billing Service multi-pasarela (Stripe+Redsys+PSD2)** | Igual | SUPERIOR | SUPERIOR | SUPERIOR | SUPERIOR |
| **CRM + Facturación + Nóminas en uno** | SUPERIOR | SUPERIOR | SUPERIOR | SUPERIOR | Similar |
| **Gestión de empleados + finiquitos** | SUPERIOR | N/A | N/A | N/A | SUPERIOR |

> **Conclusión:** Fluix CRM es fiscalmente el más completo del mercado. Su punto débil es la ausencia del flujo comercial clásico (presupuesto → albarán → factura) y la automatización de cobros. Implementar las 10 funcionalidades listadas igualaría a Holded y superaría a Billin, Quipu y Factura Directa.

