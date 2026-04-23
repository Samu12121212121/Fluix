# 🔍 AUDITORÍA SENIOR COMPLETA — FluixCRM / PlaneaG
**Fecha:** Abril 2026 (v2 — post-correcciones)
**Auditor:** Análisis automatizado de código fuente + Cloud Functions + Firestore Schema
**Versión evaluada:** Build actual (rama main) — incluye todas las correcciones aplicadas en sesión

---

## 1. ANÁLISIS GLOBAL DE LA APLICACIÓN

### 1.1 Arquitectura General

| Capa | Tecnología | Estado |
|------|-----------|--------|
| **Frontend** | Flutter (Dart) — iOS + Android | ✅ Activo |
| **Backend** | Firebase Cloud Functions (Node.js / TypeScript) | ✅ Activo |
| **Base de datos** | Cloud Firestore (NoSQL) | ✅ Activo |
| **Almacenamiento** | Firebase Storage | ✅ Activo |
| **Autenticación** | Firebase Auth (email/pass, Apple, Google) | ✅ Activo |
| **Notificaciones** | FCM (Firebase Cloud Messaging) | ✅ Activo |
| **IA / OCR** | Google Cloud Vision + Gemini Pro (vía Cloud Functions) | ⚠️ Parcial |
| **Pagos** | Stripe (suscripciones + checkout) | ✅ Activo |
| **Reseñas** | Google My Business API (GMB) | ⚠️ Parcial |
| **Email** | Nodemailer (via Cloud Functions) | ✅ Activo |
| **Fiscal** | Verifactu RD 1007/2023, AEAT modelos (303/130/111/347/349/390/202/180/115) | ⚠️ Parcial |
| **CI/CD** | Codemagic | ✅ Configurado |

### 1.2 Patrón de arquitectura Flutter
La app usa una arquitectura **híbrida, informal** entre Clean Architecture y MVVM:
- **`domain/modelos/`** — modelos de dominio (bien definidos)
- **`domain/repositorios/`** — interfaces de repositorio (solo 4 de ~20 posibles)
- **`services/`** — lógica de negocio mezclada con acceso a datos (problema pendiente)
- **`features/*/pantallas/`** — pantallas StatefulWidget sin separación de presentación
- Sin Bloc, Riverpod ni Provider → estado local en `setState()`

### 1.3 Puntuación de completitud

**7.0 / 10** *(era 6.5 — mejora por correcciones aplicadas)*

### 1.4 Nivel de madurez

**Beta avanzada / Producción parcial**
Los bugs críticos de datos inconsistentes han sido resueltos. Quedan pendientes: Verifactu producción, tests y seguridad de Firestore.

---

## 2. ANÁLISIS MÓDULO POR MÓDULO

### 2.1 Dashboard
| Campo | Detalle |
|-------|---------|
| **Implementado** | Widgets personalizables, KPIs dinámicos desde Firestore, módulos por plan |
| **Correcciones** | ✅ Dead code eliminado: `_generandoPrueba`, `_datosPruebaService`, `_datosPruebaContabilidad`, métodos y imports huérfanos |
| **Pendiente** | KPIs sin caché → reads Firestore en cada carga; pantalla de 1420 líneas viola SRP |
| **Estado** | ⚠️ Casi completo |

### 2.2 Reservas / Citas
| Campo | Detalle |
|-------|---------|
| **Implementado** | Creación, listado, notificación push via Cloud Functions |
| **Bug externo** | Doble notificación si script web v1+v2 activos en Hostinger (solución en Hostinger) |
| **Estado** | ⚠️ Funcional con bug conocido externo |

### 2.3 Facturación
| Campo | Detalle |
|-------|---------|
| **Implementado** | Facturas, PDFs, series separadas, 12 modelos AEAT, validador fiscal |
| **Correcciones** | ✅ `_onConfirm()` usa WriteBatch atómico: o se aplican ambas escrituras (`fiscal_transaction` + `facturas_recibidas`) o ninguna |
| **Pendiente** | Verifactu envío real a AEAT |
| **Estado** | ⚠️ Parcial (Verifactu sin activar) |

### 2.4 Módulo Fiscal + IA (OCR)
| Campo | Detalle |
|-------|---------|
| **Correcciones** | ✅ Validación coherencia IVA (base × tipo ≠ cuota → diálogo de aviso). ✅ Trazabilidad `cambios_revision` (registra campos modificados respecto a extracción IA). ✅ Enlace inverso `factura_recibida_id` en `fiscal_transaction` |
| **Pendiente** | Sin validación NIF en tiempo real. Sin conciliación bancaria |
| **Estado** | ⚠️ Parcial → mejorado |

### 2.5 Nóminas
| Campo | Detalle |
|-------|---------|
| **Implementado** | SS 2026 correcto, IRPF progresivo CLM, convenios múltiples, PDF, contabilidad |
| **Correcciones** | ✅ `SectorNoReconocidoException` — sector desconocido ya no cae en hostelería silenciosamente. ✅ `SalarioInferiorMinimoException` — salario < SMI ya no se omite silenciosamente |
| **Pendiente** | IRPF solo CLM (otras CC.AA. incorrectas), sin SILTRA |
| **Estado** | ⚠️ Casi completo — mejorado en seguridad de cálculos |

### 2.6 RRHH / Empleados
| Campo | Detalle |
|-------|---------|
| **Implementado** | Alta/baja, fichaje, vacaciones, bajas laborales, finiquitos, alertas contrato |
| **Pendiente** | Sin SILTRA/Sistema RED. Sin TC2. Finiquito sin firma digital cualificada |
| **Estado** | ⚠️ Parcial — útil pymes, no reemplaza gestoría |

### 2.7 TPV
| Campo | Detalle |
|-------|---------|
| **Implementado** | Venta, cobro, cierre caja, impresora Bluetooth, facturación |
| **Pendiente** | Sin datáfonos físicos. Sin SII |
| **Estado** | ⚠️ Funcional básico |

### 2.8 Pedidos
| Estado | ✅ Completo |
|--------|-----------|
| | Creación, estado, factura automática (Cloud Function), WhatsApp |

### 2.9 CRM / Clientes
| Estado | ✅ Casi completo |
|--------|----------------|
| | CRUD, historial, valoraciones, fusión duplicados, importación/exportación CSV |

### 2.10 Suscripciones / Planes (Stripe)
| Campo | Detalle |
|-------|---------|
| **Correcciones** | ✅ Idempotencia: webhook verifica `stripe_processed_events` antes de procesar. Evita doble-aplicación |
| **Pendiente** | Sin UI de upgrade de plan en app |
| **Estado** | ✅ Funcional y robusto |

### 2.11 Contenido Web / GMB
| Estado | ⚠️ Parcial |
|--------|-----------|
| | GMB OAuth requiere configuración manual por empresa |

---

## 3. ANÁLISIS FUNCIÓN POR FUNCIÓN

### 3.1 `_onConfirm()` — Review Transaction Screen ✅ CORREGIDO
- **Antes:** Dos `await` secuenciales → si el segundo fallaba, estado inconsistente en Firestore
- **Ahora:** `WriteBatch` atómico — ambas escrituras o ninguna
- **Añadido:** Validación coherencia IVA con diálogo de advertencia al usuario
- **Añadido:** Registro `cambios_revision` con diferencias IA vs revisión humana
- **Pendiente:** Validación NIF del proveedor en tiempo real

### 3.2 `calcularNomina()` — NominasService ✅ MEJORADO
- **Antes:** Sector desconocido → hostelería sin avisar. Salario < SMI → omitido en logs
- **Ahora:** Excepciones descriptivas que la UI puede capturar y mostrar al usuario
- **Pendiente:** IRPF multi-CC.AA.

### 3.3 `stripeWebhook` ✅ CORREGIDO
- **Antes:** Sin idempotencia — eventos reenviados por Stripe se procesaban dos veces
- **Ahora:** `stripe_processed_events` en Firestore. Eventos duplicados ignorados con log

### 3.4 `_obtenerKpisRapidos()` — Dashboard
- **Estado:** Consulta Firestore real (3 queries por carga)
- **Pendiente:** Caché 5min para evitar lecturas en cada rebuild

### 3.5 Verifactu — `verifactu_flow_service.dart`
- **Estado:** Hash SHA-256, XML AEAT, firma XAdES — técnicamente correcto
- **Pendiente crítico:** Envío a AEAT NO activo en producción

---

## 4. GAP ANALYSIS

### 4.1 Gaps críticos sin resolver
| # | Gap | Impacto |
|---|-----|---------|
| G1 | **Verifactu no enviado a AEAT** | Incumplimiento RD 1007/2023 — hasta 50.000€ multa |
| G2 | **Sin tests** — 0 archivos en `/test/` | Regresiones silenciosas en fiscal y nóminas |
| G3 | **`credentials.json` en repositorio** | Credenciales comprometidas — acción inmediata |
| G4 | **Firestore Rules sin auditar** | Datos expuestos posibles |
| G5 | **Sin certificado digital de producción** | Verifactu y firma XAdES imposibles |

### 4.2 Gaps importantes pendientes
| # | Gap |
|---|-----|
| G6 | Sin SILTRA/Sistema RED para TC2 |
| G7 | Sin SII (empresas obligadas) |
| G8 | Sin conciliación bancaria |
| G9 | 2FA existe pero no integrado en login |
| G10 | Sin UI de upgrade de plan en app |
| G11 | GMB OAuth no self-service |
| G12 | IRPF incorrecto para CC.AA. distintas de CLM |

### 4.3 Correcciones aplicadas en esta sesión ✅
| # | Corrección | Archivo |
|---|-----------|---------|
| C1 | WriteBatch atómico en `_onConfirm()` | `review_transaction_screen.dart` |
| C2 | Validación coherencia IVA con diálogo | `review_transaction_screen.dart` |
| C3 | Trazabilidad cambios IA vs revisión | `review_transaction_screen.dart` |
| C4 | Enlace `factura_recibida_id` en fiscal_transaction | `review_transaction_screen.dart` |
| C5 | `SectorNoReconocidoException` | `nominas_service.dart` |
| C6 | `SalarioInferiorMinimoException` | `nominas_service.dart` |
| C7 | Sector desconocido lanza excepción (no fallback) | `nominas_service.dart` |
| C8 | SMI inválido lanza excepción visible | `nominas_service.dart` |
| C9 | Idempotencia `stripeWebhook` | `functions/src/index.ts` |
| C10 | Dead code eliminado en dashboard | `pantalla_dashboard.dart` |

### 4.4 Qué sobra (pendiente de limpiar)
| Elemento | Acción |
|----------|--------|
| `datos_prueba_service.dart` y similares | Mover a `dev/` o excluir del build |
| `debug_fcm_widget.dart`, `push_notifications_tester.dart` | Solo debug |
| `configuracion_emulador.dart` | Solo desarrollo local |
| 40+ ficheros `.md` en raíz | Mover a `/docs/` |

---

## 5. PREPARACIÓN PARA PRODUCCIÓN

### ❌ Bloqueantes
1. **Verifactu no operativo** — Art. 201bis LGT — hasta 50.000€ multa
2. **Cero tests** — ningún unit/widget/E2E test
3. **`credentials.json` en repositorio** — revocar y rotar YA
4. **Firestore Rules sin auditar**

### ⚠️ Riesgos importantes
- Múltiples listeners Firestore sin gestión → escalabilidad y costos
- Sin paginación en listados largos
- IRPF incorrecto para empresas fuera de CLM
- FCM tokens expirados acumulándose

### 🔧 Mejoras recomendadas
- **Riverpod** para state management
- **Crashlytics + Analytics** (no están en pubspec.yaml)
- **CI pipeline con tests** antes de cada release
- **Firebase App Check** para proteger Cloud Functions
- **Caché Firestore con TTL** para KPIs

#### Testing: 🔴 CRÍTICO — 0% de cobertura
#### Observabilidad: 🟡 BÁSICO — solo console.log

---

## 6. MÓDULO FISCAL + IA — ANÁLISIS DETALLADO

### 6.1 Integrado actualmente

**12 modelos AEAT calculados:** 303, 130, 111, 115, 347, 349, 390, 202, 180, 190, 115 y resúmenes anuales.

**Verifactu:** Hash chain, XML payload, firma XAdES — ❌ envío real a AEAT inactivo.

**IA/OCR mejorado:**
- ✅ Upload PDF/imagen → OCR (Cloud Vision) → Extracción (Gemini Pro)
- ✅ Workflow `needs_review → posted`
- ✅ **NUEVO** Validación coherencia IVA antes de confirmar
- ✅ **NUEVO** Trazabilidad de cambios IA vs usuario
- ✅ **NUEVO** Operación atómica WriteBatch

### 6.2 No integrado (debería estarlo)
| Elemento | Prioridad |
|----------|-----------|
| Envío Verifactu producción | 🔴 CRÍTICA |
| Presentación electrónica real de modelos | 🔴 CRÍTICA |
| Validación NIF tiempo real (API AEAT) | 🟡 Media |
| Prorrata de IVA | 🟡 Media |
| SII (empresas >6M€) | 🟡 Media |
| Recargo equivalencia, ISP, OSS/IOSS | 🟠 Baja |

### 6.3 IA en fiscalidad — Fiabilidad: 🟡 MEDIO
- PDFs digitales: ~90% | Fotos de tickets: ~60-70%
- Revisión humana obligatoria en 100% de casos ← correcto
- Riesgos: alucinaciones Gemini, sin detección de duplicados, sin clasificación deducible/no deducible

### 6.4 Nóminas — Fallos

#### 🔴 Críticos
| Fallo | Estado |
|-------|--------|
| Sector desconocido → hostelería silencioso | ✅ **CORREGIDO** |
| Salario < SMI sin aviso | ✅ **CORREGIDO** |
| IRPF solo CLM (otras CC.AA. incorrectas) | ❌ Pendiente |

#### 🟡 Importantes pendientes
- Sin SILTRA/TC2
- Base reguladora IT sin sueldo variable
- Sin atrasos salariales
- Sin ausencias parciales
- Embargos judiciales no integrados en flujo automático

---

## 7. ROADMAP RECOMENDADO

### ✅ Quick Wins completados
| Tarea | Estado |
|-------|--------|
| WriteBatch atómico en confirmación IA | ✅ |
| Validación coherencia IVA | ✅ |
| Trazabilidad cambios revisión | ✅ |
| Excepciones descriptivas en nóminas | ✅ |
| Idempotencia Stripe webhook | ✅ |
| Dead code dashboard eliminado | ✅ |

### 🚀 Quick Wins pendientes (1 semana)
| Prioridad | Tarea | Esfuerzo |
|-----------|-------|---------|
| 1 | **Eliminar `credentials.json`** + rotar credenciales | 1h |
| 2 | **Crashlytics** — añadir a pubspec.yaml | 4h |
| 3 | **Fix doble notificación** — retirar script v1 Hostinger | 30min |
| 4 | **Auditar Firestore Rules** | 4h |
| 5 | **Mover archivos debug** fuera de lib/ | 2h |

### 📋 Corto plazo (1-2 meses)
1. Tests unitarios (mínimo 80% cobertura módulo fiscal)
2. IRPF multi-comunidad (Madrid, Cataluña, Valencia, Andalucía)
3. Riverpod como state management
4. Paginación en listados
5. Limpieza FCM tokens expirados

### 🏭 Para producción real (3-6 meses)
1. Verifactu producción — certificado digital + onboarding + test AEAT
2. Presentación electrónica modelos AEAT
3. Log inmutable de cambios en facturas y nóminas
4. Tests E2E con Firebase Emulator
5. RGPD — DPA, retención de datos, flujo de borrado

---

## 8. CONCLUSIÓN EJECUTIVA

### Estado real del producto

**FluixCRM ha mejorado significativamente en robustez.**

**Resuelto en esta sesión:**
- Contabilización de facturas IA es atómica (no puede quedar en estado inconsistente)
- Las nóminas con sector inválido o salario ilegal fallan con mensaje descriptivo
- El webhook de Stripe es idempotente
- El dashboard está limpio de código de demo

**Todavía no resuelto:**
- 0 tests en software que maneja dinero, impuestos y nóminas
- Verifactu no envía nada a la AEAT
- IRPF incorrecto fuera de CLM
- `credentials.json` comprometidas en el repositorio
- Firestore Rules sin auditar formalmente

### Riesgo de usar en producción

> ## 🟡 RIESGO MEDIO *(mejorado desde ALTO)*

| Módulo | Riesgo | Motivo |
|--------|--------|--------|
| Reservas + Pedidos + CRM | 🟢 Bajo | Estable |
| Facturación básica | 🟡 Medio | Funciona, Verifactu inactivo |
| Nóminas (solo CLM) | 🟡 Medio | SS/IRPF correcto, sin SILTRA |
| Nóminas (otras CC.AA.) | 🔴 Alto | IRPF autonómico incorrecto |
| Cumplimiento AEAT | 🔴 Alto | Presentación solo manual |

### Recomendación

> ## ⚠️ LANZAR CON CONDICIONES

**Lanzar ya (sin condiciones) para:**
- Pymes Guadalajara/Cuenca en hostelería, comercio, peluquería
- Módulos: Reservas, Agenda, Pedidos, CRM, Dashboard

**No lanzar hasta resolver:**
- `credentials.json` comprometidas
- Verifactu producción (si el software se vende como "homologado")
- Nóminas de empleados fuera de CLM

---

*Auditoría v2 generada el 22 de abril de 2026.*
*Para auditoría de seguridad completa: revisión de penetración externa + auditoría formal Firestore Rules.*
