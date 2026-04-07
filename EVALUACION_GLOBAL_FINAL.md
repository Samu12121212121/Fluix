# 🏢 EVALUACIÓN GLOBAL — FLUIX CRM v1.0
**Fecha:** 31 marzo 2026  
**Stack:** Flutter 3.x + Firebase (Firestore, Auth, Messaging, Storage, Functions) + Stripe  
**Target:** PYMES españolas (CLM) — Hostelería, Comercio, Peluquerías, Cárnicas, Veterinarios

---

## 📊 RESUMEN EJECUTIVO

| Módulo | Completitud | Estado |
|--------|:-----------:|--------|
| Dashboard | 90% | ✅ Funcional |
| Autenticación | 85% | ✅ Funcional (falta Apple Sign-In) |
| Reservas | 95% | ✅ Completo |
| Citas | 40% | ⚠️ Wrapper de Reservas ampliado |
| Clientes | 90% | ✅ Funcional |
| Servicios | 90% | ✅ Funcional |
| Facturación | 80% | ⚠️ Funcional, fiscal pendiente |
| Nóminas | 85% | ⚠️ Motor completo, UI por pulir |
| Pedidos | 90% | ✅ Funcional |
| Tareas | 75% | ⚠️ Kanban ok, calendario por pulir |
| Empleados | 70% | ⚠️ Widget monolítico 3k líneas |
| Valoraciones (Google) | 85% | ✅ Funcional con API |
| Estadísticas | 80% | ✅ Funcional |
| WhatsApp | 70% | ⚠️ Bot básico |
| Web (CMS) | 60% | ⚠️ Editor básico |
| Verifactu | 50% | 🔴 Cloud Function creada, sin testear |
| Modelos AEAT | 70% | ⚠️ 303/111/115/130/190/349 creados |
| Suscripciones | 60% | ⚠️ Gestión básica, Stripe pendiente |
| **GLOBAL** | **~75%** | **⚠️ MVP desplegable con trabajo** |

---

## 🔴 PRIORIDAD 1 — COMPLETADO EN ESTA SESIÓN

### ✅ 1. NIF vacío en facturación → ARREGLADO
- `facturacion_service.dart`: Eliminado `EmpresaConfig(nif: '')`, ahora usa `EmpresaConfigService().obtenerConfig(empresaId)`
- Obtiene NIF real de Firestore (empresa → configuración/fiscal)
- Validación fiscal integral con facturas del trimestre real

### ✅ 2. TODOs críticos → RESUELTOS
- `facturacion_service.dart:134` → NIF desde BD ✅
- `facturacion_service.dart:146` → Logger de advertencias ✅
- `facturacion_service.dart:167` → Query real de facturas del trimestre ✅
- `widget_contenido_web.dart:241` → Navegación a PantallaContenidoWeb ✅
- `widget_contenido_web.dart:246` → Generador de código JS embebible ✅
- `provider_dashboard.dart:32` → Carga de módulos desde Firestore ✅
- `provider_dashboard.dart:64` → Verificación de suscripción real ✅

### ✅ 3. Logger centralizado → IMPLEMENTADO
- Creado `lib/core/utils/logger_config.dart`
- 20+ `print()` reemplazados por `Logger()` en:
  - `convenio_firestore_service.dart` (15 prints)
  - `datos_prueba_fluixtech_service.dart` (15 prints)
  - `main.dart` (1 print)
  - `widget_contenido_web.dart` (2 prints)
  - `facturacion_service.dart` (nuevos logs)
  - `provider_dashboard.dart` (nuevos logs)

### ✅ 4. Firebase Crashlytics → CONFIGURADO
- `pubspec.yaml`: firebase_crashlytics + firebase_performance
- `main.dart`: `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`
- `runZonedGuarded` para errores asíncronos no manejados
- **Falta:** Ejecutar `flutter pub get` y configurar `google-services.json` para Crashlytics

### ✅ 5. widget_test.dart → CORREGIDO
- Eliminada referencia a `MyApp` (no existe)
- Test básico de carga sin Firebase real

### ✅ 6. Archivos duplicados → IDENTIFICADOS
- Script `limpiar_duplicados.bat` creado
- Archivos a eliminar:
  - `modulo_valoraciones_backup.dart` (sin imports)
  - `modulo_valoraciones_nuevo.dart` (sin imports)
  - `lib/screens/` (7 archivos, sin imports)
  - `lib/models/` (7 archivos, verificar imports primero)

### ✅ 7. Seguridad credentials.json → AMPLIADO
- `.gitignore` actualizado con: `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `google-services.json`, `service-account*.json`, etc.

### ✅ 8. modulo_valoraciones_fixed.dart → REPARADO
- Clase `_Cabecera` completamente reescrita sin brackets anidados problemáticos
- Método `_promedioLocal()` y `_badge()` correctamente dentro de la clase
- SnackBar en `_TarjetaResena` corregido (`responderReseña` → `responderResena`)

### ✅ 9. analysis_options.yaml → ESTRICTO
- `avoid_print: true` (warning)
- `prefer_const_constructors`, `prefer_final_fields`, etc.
- Exclusiones para generados (`*.g.dart`, `*.freezed.dart`)

---

## 🟡 PRIORIDAD 2 — PARCIALMENTE COMPLETADO

### ✅ 10. SplashScreen limpio (FutureBuilders refactorizados)
- Creado `lib/core/router/splash_router.dart`
- Un solo `Future.wait()` para usuario + empresa + suscripción
- Sin parpadeos, pantalla de carga elegante
- **Falta:** Conectarlo en `main.dart` como home

### ✅ 11. Inyección de dependencias con get_it
- Creado `lib/core/di/service_locator.dart`
- Registra: FacturacionService, NominasService, PedidosService, EmpresaConfigService, PermisosService
- **Falta:** Ejecutar `flutter pub get`, migrar uso en pantallas

### ✅ 12. provider_dashboard.dart → IMPLEMENTACIÓN REAL
- `cargarDatos()` lee de `empresas/{id}/configuracion/modulos`
- `toggleModulo()` persiste en Firestore
- `verificarSuscripcion()` verifica estado y fecha_fin

### ⬜ 13. Tests unitarios fiscales
- `test/validador_nif_cif_test.dart` ya existía
- **Falta:** Tests de IRPF, SS, SEPA XML, Modelos AEAT

### ⬜ 14. Detección de conectividad
- `connectivity_plus` añadido a pubspec.yaml
- **Falta:** Implementar banner offline y reintentos

### ⬜ 15. go_router
- Está en pubspec pero NO se usa
- **Falta:** Migrar toda la navegación (tarea grande)

---

## 🟢 PRIORIDAD 3 — PENDIENTE

### ⬜ 16. Responsive breakpoints → No implementado
### ⬜ 17. CI/CD GitHub Actions → No implementado
### ⬜ 18. Organizar 50+ .md → No implementado
### ⬜ 19. Limpiar dependencias no usadas → Parcial (evaluado)

---

## 📋 ESTADO DETALLADO POR MÓDULO

### 1. Dashboard (90% ✅)
**Tiene:**
- Grid de módulos activables/desactivables
- Widget de valoraciones, reservas, citas, estadísticas
- Vista simulada (Propietario puede ver como Admin/Usuario)
- Carga de datos desde Firestore (real, no simulado)
- Módulo propietario con gestión

**Falta:**
- Conectar SplashRouter como punto de entrada
- Mejorar responsive en tablet/desktop

### 2. Facturación (80% ⚠️)
**Tiene:**
- CRUD completo de facturas (crear, editar, anular, duplicar)
- Series por tipo (F-, PRF-, RECT-)
- Numeración auto-incremental con transacción Firestore
- Facturas rectificativas (Art. 15 RD 1619/2012)
- Proformas convertibles a factura
- Detección automática de facturas vencidas
- Resumen mensual/trimestral para impuestos
- Cálculo Mod 303 (IVA repercutido - soportado)
- Cálculo Mod 111 (retenciones IRPF)
- Criterio IVA devengo vs caja
- Facturas intracomunitarias filtradas
- Historial por cliente con facturación últimos 6 meses
- Factura desde pedido
- NIF real desde EmpresaConfigService

**Falta:**
- ❌ Envío de facturas por email (no implementado)
- ❌ Verifactu end-to-end (Cloud Function creada pero no desplegada)
- ❌ QR real en PDF con datos Verifactu
- ❌ Mod 115 (alquileres), 130 (pagos fraccionados), 390 (resumen anual) — lógica creada pero no integrada en UI
- ❌ Mod 349 (intracomunitario) — exporter creado
- ❌ Exportación fichero AEAT (posicional 500 chars)

### 3. Nóminas (85% ⚠️)
**Tiene:**
- Motor de cálculo completo (SS 2026 + IRPF CLM)
- 5 convenios colectivos en Firestore (Hostelería, Comercio, Peluquería, Cárnicas, Veterinarios)
- Bases de cotización con topes (min/max 2026)
- MEI 0.9%, FP, desempleo, contingencias comunes
- IRPF con tramos CLM + deducciones autonómicas
- Finiquito (Art. 49-53 ET)
- Embargos judiciales
- Horas extra (fuerza mayor vs normales)
- Antigüedad por trienios/quinquenios
- Vacaciones y ausencias
- PDF nómina formato BOE
- SEPA XML (pain.001.001.03) para remesas bancarias
- Mod 111 exporter
- Mod 190 exporter

**Falta:**
- ❌ UI del módulo necesita refactoring (widget muy grande)
- ❌ Exportación real de ficheros AEAT (probado solo en lógica)
- ❌ Convenios de otras provincias
- ❌ Contratos en prácticas con bonificaciones

### 4. Clientes (90% ✅)
**Tiene:** CRUD, etiquetas, filtros, búsqueda, historial de facturas, total gastado
**Falta:** Segmentación avanzada, export CSV

### 5. Citas (40% ⚠️)
**Tiene:** Estructura básica replicada de Reservas
**Falta:**
- ❌ Profesionales y servicios propios
- ❌ Vista calendario dedicada
- ❌ Recordatorios push
- ❌ Confirmación por cliente

### 6. Tareas (75% ⚠️)
**Tiene:** Vista Kanban funcional, lista de tareas, subtareas/checklist
**Falta:**
- ❌ Vista calendario con `table_calendar` (CalendarBuilders API error)
- ❌ Notificaciones de asignación

### 7. Empleados (70% ⚠️)
**Tiene:** CRUD completo, datos de nómina, roles
**Falta:**
- ❌ Refactoring del widget monolítico (3,021 líneas)
- ❌ Foto de perfil del empleado
- ❌ Historial de cambios

### 8. Cloud Functions (60% ⚠️)
**Tiene:**
- `firmarXMLVerifactu.ts` (XAdES-BES con node-forge)
- `remitirVerifactu.ts` (SOAP AEAT con mTLS)
- `recordatoriosCitas.js` (push reminders)
- Stripe webhooks

**Falta:**
- ❌ Deploy fallido (errores TypeScript, initializeApp)
- ❌ Tests de Cloud Functions
- ❌ Secret Manager para certificado Verifactu

### 9. Suscripciones / Gestión de Cuentas (60% ⚠️)
**Tiene:**
- Pantalla gestionar_cuentas_screen.dart
- Modelo: crear cuenta → asignar plan → pago web (evita Apple 30%)
- Verificación de suscripción en dashboard

**Falta:**
- ❌ Integración Stripe para cobros reales
- ❌ Email de bienvenida al crear cuenta
- ❌ Pantalla de pago web (landing)
- ❌ Apple Sign-In

---

## 🚀 PASOS PARA DESPLEGAR (en orden)

### Paso 1: Compilación limpia
```bash
flutter pub get
flutter analyze
# Arreglar warnings restantes
```

### Paso 2: Eliminar duplicados
```bash
limpiar_duplicados.bat
```

### Paso 3: Configurar Firebase
- Verificar `google-services.json` (Android) tiene Crashlytics habilitado
- Verificar `GoogleService-Info.plist` (iOS) tiene Crashlytics
- Habilitar Crashlytics en Firebase Console

### Paso 4: Deploy Cloud Functions
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```
> ⚠️ Resolver errores TypeScript primero (initializeApp, Stripe version)

### Paso 5: Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Paso 6: Build Android Release
```bash
flutter build apk --release
# O para bundle:
flutter build appbundle --release
```
> ⚠️ Keystore ya generado en `fluix_release.jks`

### Paso 7: Configurar App Distribution
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_APP_ID --groups testers
```

---

## 🔧 ARCHIVOS CLAVE MODIFICADOS EN ESTA SESIÓN

| Archivo | Cambio |
|---------|--------|
| `lib/services/facturacion_service.dart` | NIF real, código desordenado arreglado, Logger |
| `lib/features/dashboard/widgets/widget_contenido_web.dart` | TODOs resueltos, JS generator, Logger |
| `lib/features/dashboard/providers/provider_dashboard.dart` | Implementación real Firestore |
| `lib/features/dashboard/widgets/modulo_valoraciones_fixed.dart` | ñ→n, _Cabecera reescrita, SnackBar fix |
| `lib/main.dart` | Crashlytics, Logger, runZonedGuarded |
| `lib/services/convenio_firestore_service.dart` | Logger (15 prints) |
| `lib/services/datos_prueba_fluixtech_service.dart` | Logger (15 prints) |
| `lib/core/utils/logger_config.dart` | **NUEVO** — Logger centralizado |
| `lib/core/router/splash_router.dart` | **NUEVO** — SplashScreen sin FutureBuilder anidados |
| `lib/core/di/service_locator.dart` | **NUEVO** — get_it DI |
| `test/widget_test.dart` | Corregido (MyApp → smoke test) |
| `pubspec.yaml` | +crashlytics, +performance, +connectivity_plus, +get_it, +mockito |
| `analysis_options.yaml` | Reglas estrictas (avoid_print, prefer_const, etc.) |
| `.gitignore` | +jks, +keystore, +p12, +pem, +google-services.json |
| `limpiar_duplicados.bat` | **NUEVO** — Script limpieza |

---

## ⚡ ACCIÓN INMEDIATA REQUERIDA

1. **Ejecutar en terminal:**
   ```bash
   cd planeag_flutter
   flutter pub get
   ```

2. **Verificar compilación:**
   ```bash
   flutter analyze
   ```

3. **Ejecutar limpieza:**
   ```bash
   limpiar_duplicados.bat
   ```

4. **Probar la app:**
   ```bash
   flutter run
   ```

---

## 📝 NOTAS PARA SESIÓN SIGUIENTE

- **Email:** Configurar email para facturas y bienvenida (recordar: "acuerdate de este punto")
- **Apple Sign-In:** Necesario para publicar en App Store
- **Citas módulo:** Expandir de wrapper a módulo completo
- **go_router:** Migración de Navigator.push → go_router (P2)
- **Responsive:** LayoutBuilder para tablet/desktop (P3)
- **Tests:** Ampliar cobertura de tests unitarios fiscales
- **Empleados:** Refactorizar widget de 3k líneas en sub-widgets

