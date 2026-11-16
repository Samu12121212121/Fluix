# 01 — Multiplataforma y Publicación

**Fluix CRM · v1.0.18 · Flutter ^3.11.1 · Firebase planeaapp-4bea4**
Análisis en modo solo lectura — 2026-10-26

---

## Estado actual (por plataforma)

### iOS

- **Bundle ID en ExportOptions.plist**: `com.fluixtech.crm` — coincide con `iosBundleId` en `firebase_options.dart` y con el provisioning profile `Fluix12`.
- **Bundle ID en GoogleService-Info.plist**: `com.fluixtech.app` — **distinto** al usado en compilación (`com.fluixtech.crm`). Firebase iOS usa `com.fluixtech.crm` en `firebase_options.dart`, por lo que el campo `BUNDLE_ID` del plist es informativo, no crítico, pero es inconsistente y puede confundir.
- **Deployment target**: `17.0` en Podfile y en `post_install`. iOS 17.0 fue lanzado en septiembre 2023. Cualquier usuario con iPhone en iOS 15 o 16 (dispositivos no actualizables o retrasados en actualización) no puede instalar la app. Según datos de mercado, en 2026 iOS 17+ cubre ~90% del parque activo, por lo que el impacto es bajo pero existe.
- **Firma**: manual, perfil `Fluix12`, team `3AMXPPGLN8` (SAMUEL CORCHO ORTEGA). Correcto para distribución App Store.
- **Entitlements**: `Runner.entitlements` tiene `aps-environment: development`; `RunnerRelease.entitlements` tiene `aps-environment: production`. Correcto.
- **Capabilities en Info.plist**: NSCameraUsageDescription, NSFaceIDUsageDescription, NSBluetoothAlwaysUsageDescription, NSBluetoothPeripheralUsageDescription, NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription — todas presentes y con strings descriptivos en español. Correcto para App Store Review.
- **Background modes**: `fetch` y `remote-notification` — necesarios para FCM. Correcto.
- **Deep links**: esquema `fluixcrm://` declarado en Info.plist. No se declara Universal Links (AASA), por lo que los deep links son solo de esquema propio, no verificados por dominio.
- **PrivacyInfo.xcprivacy**: presente con 4 API de privacidad (UserDefaults, FileTimestamp, DiskSpace, SystemBootTime). Esto satisface el requisito de Apple desde 2024.
- **App Check**: activado con `AppleProvider.deviceCheck` en release, excluido en debug y en desktop. Correcto.
- **Crashlytics**: activado solo en release móvil. Correcto.
- **FCM**: `firebase_messaging ^16.7.0`, `UIBackgroundModes remote-notification` configurado, `FlutterAppDelegate` sin SceneDelegate — se gestiona correctamente el callback de APNs.
- **CI/CD (Codemagic)**: workflow `ios-release` configurado. Usa `mac_mini_m2`, Flutter `3.41.3`, Xcode latest. Firma automática via App Store Connect API. Publica a TestFlight. **Nota**: la versión de Flutter en Codemagic (`3.41.3`) es posterior al constraint del proyecto (`^3.11.1`) — puede haber cambios de comportamiento no probados localmente.

### Android

- **applicationId**: `com.fluixcrm.app` (build.gradle.kts:37)
- **namespace**: `com.fluixcrm.crm` (build.gradle.kts:21) — **inconsistencia confirmada**. El namespace define los paquetes R y BuildConfig internos, no el identificador de Play Store. Funciona en la práctica, pero es técnicamente incorrecto y puede causar confusión en herramientas de análisis, lint y en futuras migraciones.
- **google-services.json**: contiene dos entradas: `com.fluixcrm.ap` (incompleto, probablemente error tipográfico) y `com.fluixcrm.app`. La entrada correcta es la segunda. La primera es un artefacto sin consecuencias en runtime (Google Services elige la coincidencia exacta).
- **Firma release**: keystore `planeaguada-release.jks` en `android/planeaguada-release.jks`, referenciada desde `key.properties`. **Atención**: la contraseña del keystore está en texto plano en `key.properties`. Este fichero NO debe estar en git en producción — verificar `.gitignore`.
- **minSdk=24 / targetSdk=35**: correcto. Cubre Android 7.0+. targetSdk 35 (Android 15) requiere que la app sea compatible con los cambios de comportamiento de Android 15 (permisos de fotos granulares, restricciones de intents implícitos).
- **Permisos declarados**: INTERNET, RECEIVE_BOOT_COMPLETED, VIBRATE, POST_NOTIFICATIONS, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, BLUETOOTH x4.
- **CAMERA no declarado**: `mobile_scanner` requiere el permiso `android.permission.CAMERA`. No está en AndroidManifest.xml. La librería mobile_scanner lo incluye en su propio AndroidManifest y se fusiona en el merge, por lo que en la práctica funciona, pero no está explícito en el manifiesto del proyecto.
- **Bluetooth legacy**: `BLUETOOTH` y `BLUETOOTH_ADMIN` son permisos legacy (pre-Android 12). En Android 12+ (API 31+) se requieren `BLUETOOTH_CONNECT` y `BLUETOOTH_SCAN` — ambos presentes. Los legacy no causan errores pero añaden superficie de declaración innecesaria en API 31+.
- **Proguard/R8**: `isMinifyEnabled = true`, `isShrinkResources = true`. Correcto para release.
- **App Bundle (AAB)**: el workflow Codemagic usa `flutter build appbundle` — correcto para Play Store.
- **App Check**: `AndroidProvider.playIntegrity` en release. Correcto.
- **Crashlytics + Performance**: habilitados via gradle plugins (`com.google.firebase.crashlytics`, `com.google.firebase.firebase-perf`). Correcto.
- **Data Safety declaration**: no existe fichero de declaración en el repositorio. Play Console requiere rellenar el formulario manualmente — los permisos de localización, cámara (via merge), Bluetooth y biometría obligan a declarar recopilación de datos sensibles.
- **CI/CD (Codemagic)**: workflow `android-release` configurado. Publica en track `internal`. La variable `$GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` debe configurarse en Codemagic UI.

### Windows

- **Estado de distribución**: no existe ningún mecanismo de distribución definido. El build produce un directorio de binarios (`build/windows/runner/Release/`) sin empaquetado.
- **MSIX**: ausente. Sin MSIX no es posible distribuir en Microsoft Store ni hacer actualizaciones automáticas.
- **Firma de código**: ausente. Sin firma EV/OV, Windows Defender SmartScreen bloquea el ejecutable en instalaciones nuevas con advertencia "aplicación desconocida". Impacto directo en la experiencia del usuario empresarial.
- **Auto-update**: no hay Squirrel, MSIX Store update, ni ningún mecanismo equivalente. Las actualizaciones requieren redistribución manual.
- **Firebase en Windows**: usa las mismas credenciales web (`appId web`, `authDomain`) — la app registra Windows como plataforma web en Firebase. Funcional pero no tiene app nativa registrada en Firebase Console.
- **Crashlytics en Windows**: explícitamente desactivado en `main.dart` (líneas 59-80). Sin telemetría de crashes para la plataforma.
- **firebase_performance en Windows**: no hay guards explícitos — si el SDK no soporta Windows puede lanzar excepciones en runtime. Verificar compatibilidad.
- **App Check en Windows**: desactivado (mismo guard que Crashlytics). La app accede a Firestore desde Windows sin App Check — riesgo si las reglas de Firestore requieren App Check token.
- **sqflite en Windows**: `cache_service.dart` usa `sqflite` sin inicializar FFI (`sqfliteFfiInit` ausente en ese servicio). `offline_queue_service.dart` sí inicializa FFI correctamente. Esto puede causar crash en Windows al acceder al caché del dashboard.

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|---|---|---|
| CRITICO | namespace Android (`com.fluixcrm.crm`) distinto del applicationId (`com.fluixcrm.app`) — viola convención Gradle, puede romper referencias de recursos en AGP 8.x futuro | `android/app/build.gradle.kts:21,37` |
| CRITICO | `key.properties` con contraseña de keystore en texto plano — si está en git, la clave de firma de producción queda expuesta | `android/key.properties:1-4` |
| ALTO | Windows sin firma de código — SmartScreen bloquea el ejecutable; rechazado por políticas IT corporativas | `windows/CMakeLists.txt` (ausencia) |
| ALTO | Windows sin MSIX — sin canal de distribución ni actualización automática para la plataforma objetivo CRM | `windows/` (ausencia) |
| ALTO | `CacheService` usa `sqflite` sin inicializar FFI en Windows — crash en runtime al abrir el dashboard | `lib/services/cache_service.dart:38` |
| ALTO | App Check desactivado en Windows — accesos a Firestore sin token si las rules lo exigen | `lib/main.dart:85-94` |
| MEDIO | iOS deployment target 17.0 — excluye ~10% usuarios con iOS 15/16 (iPhone 6s/7 y usuarios no actualizados) | `ios/Podfile:2`, `ios/Podfile:45` |
| MEDIO | `mobile_scanner` sin soporte Windows — si se navega al TPV desde Windows, crash garantizado | `lib/features/tpv/pantallas/tpv_tienda_screen.dart:5774` |
| MEDIO | `blue_thermal_printer` sin soporte Windows — se usa directamente sin guard de plataforma en `impresora_bluetooth_service.dart` | `lib/services/tpv/impresora_bluetooth_service.dart` |
| MEDIO | CAMERA no declarado explícitamente en AndroidManifest — depende del merge automático de mobile_scanner; si cambia el plugin se pierde | `android/app/src/main/AndroidManifest.xml` |
| MEDIO | `google-services.json` tiene entrada con package `com.fluixcrm.ap` (incompleto) — artefacto confuso, puede romper si se añade otra configuración | `android/app/google-services.json:12` |
| MEDIO | `GoogleService-Info.plist` tiene BUNDLE_ID `com.fluixtech.app` pero la app se compila como `com.fluixtech.crm` — inconsistencia en configuración Firebase iOS | `ios/Runner/GoogleService-Info.plist:12` |
| MEDIO | Versión Flutter en Codemagic (`3.41.3`) no coincide con GitHub Actions (`3.24.0`) ni con el constraint del proyecto (`^3.11.1`) — builds no reproducibles entre entornos | `codemagic.yaml:15`, `.github/workflows/flutter_tests.yml:10` |
| BAJO | Deep links solo por esquema propio (`fluixcrm://`) sin Universal Links — vulnerable a hijacking por otra app que registre el mismo esquema | `ios/Runner/Info.plist:70-80`, `android/app/src/main/AndroidManifest.xml:46-51` |
| BAJO | `NSBluetoothPeripheralUsageDescription` es un key deprecated (iOS 13+) — puede generar advertencia en validación App Store aunque no bloquea | `ios/Runner/Info.plist:46` |
| INFO | Windows usa credenciales Firebase Web (no nativas) — funcional pero sin app registrada nativamente en Firebase Console para Windows | `lib/firebase_options.dart:79-87` |

---

## Diferencias por plataforma

### iOS

| Aspecto | Estado |
|---|---|
| Firma | Manual, perfil Fluix12, team 3AMXPPGLN8 |
| App Check | DeviceCheck (producción) |
| Crashlytics | Activo en release |
| FCM | Activo (remote-notification background mode) |
| Deep links | Esquema propio `fluixcrm://` + Google Sign-In URL scheme |
| Biometría (local_auth) | Face ID / Touch ID — soportado |
| Cámara (mobile_scanner) | Soportado |
| Bluetooth (blue_thermal_printer) | Soportado |
| GPS (geolocator) | Soportado |
| Audio (audioplayers) | Soportado (audioplayers_darwin) |
| PDF viewer (flutter_pdfview) | Soportado en móvil |
| CI/CD | Codemagic → TestFlight |

### Android

| Aspecto | Estado |
|---|---|
| Firma | Keystore planeaguada-release.jks, R8 activo |
| App Check | Play Integrity (producción) |
| Crashlytics | Activo via Gradle plugin |
| FCM | Activo, canal `planeaguada_canal_principal` |
| Deep links | Esquema propio `fluixcrm://`, autoVerify=true |
| Biometría (local_auth) | Huella / biometría Android — soportado |
| Cámara (mobile_scanner) | Soportado (permiso via merge) |
| Bluetooth (blue_thermal_printer) | Soportado |
| GPS (geolocator) | Soportado |
| Audio (audioplayers) | Soportado (audioplayers_android) |
| PDF viewer (flutter_pdfview) | Soportado en móvil |
| CI/CD | Codemagic → Play Store track internal |

### Windows

| Aspecto | Estado |
|---|---|
| Firma | Ausente (SmartScreen activo) |
| App Check | Desactivado explícitamente |
| Crashlytics | Desactivado explícitamente |
| FCM | No aplicable (FCM no soporta Windows nativo) |
| Deep links | No configurados para Windows |
| Biometría (local_auth) | local_auth_windows v1.0.11 — Windows Hello, soportado con caveats |
| Cámara (mobile_scanner) | NO soportado — crash si se navega al TPV |
| Bluetooth (blue_thermal_printer) | NO soportado — crash si se llama sin guard |
| GPS (geolocator) | geolocator_windows v0.2.5 — soportado |
| Audio (audioplayers) | audioplayers_windows — soportado |
| PDF viewer (flutter_pdfview) | NO soportado en Windows — solo se usa con guard `isMobile` |
| SQLite (sqflite) | FFI inicializado en offline_queue pero NO en cache_service — crash parcial |
| CI/CD | No configurado |

---

## Plugins sin soporte Windows — detalle

| Plugin | Versión | Soporte Windows | Workaround en código |
|---|---|---|---|
| `blue_thermal_printer` | 1.2.3 | NO — solo Android/iOS | `ImpresoraService` tiene guard `esMovil`/`esDesktop` pero `ImpressoraBluetooth` se instancia siempre |
| `mobile_scanner` | 6.0.11 | NO | Sin guard de plataforma en `tpv_tienda_screen.dart` — crash al abrir modal escáner |
| `local_auth` | 2.3.0 | SI via `local_auth_windows` | Funcional con Windows Hello, no requiere workaround |
| `audioplayers` | 6.6.0 | SI via `audioplayers_windows` | Sin workaround necesario |
| `geolocator` | 13.0.4 | SI via `geolocator_windows` | Sin workaround necesario |
| `flutter_pdfview` | 1.4.4 | NO | Guard `isMobile` en `nominas_empleado_widget.dart` — correcto, fallback a printing |
| `sqflite` | — | NO nativo | FFI inicializado en `offline_queue_service.dart` pero NO en `cache_service.dart` |

---

## Cumplimiento legal aplicable

### App Store Review Guidelines (iOS)

| Requisito | Estado |
|---|---|
| NSCameraUsageDescription | Presente con descripción |
| NSFaceIDUsageDescription | Presente con descripción |
| NSBluetoothAlwaysUsageDescription | Presente con descripción |
| NSLocationWhenInUseUsageDescription | Presente con descripción |
| NSPhotoLibraryUsageDescription | Presente con descripción |
| PrivacyInfo.xcprivacy | Presente con 4 API de privacidad |
| Sign In with Apple (si hay login social) | `sign_in_with_apple` declarado y entitlement configurado |
| Encryption (ITSAppUsesNonExemptEncryption) | `false` — correcto si no se usa cifrado propio |
| App Check | DeviceCheck activado en release |
| Background modes justificados | `fetch` + `remote-notification` justificados por FCM |

Pendiente: verificar que todas las APIs de privacidad usadas por SDKs de terceros (Firebase Analytics, Crashlytics) estén declaradas en `PrivacyInfo.xcprivacy`. Firebase Analytics accede a `SystemBootTime` y potencialmente a `NSPrivacyCollectedDataTypes` — actualmente `NSPrivacyCollectedDataTypes` está vacío, lo que puede ser incorrecto si Firebase Analytics recopila datos de uso.

### Google Play Policy (Android)

| Requisito | Estado |
|---|---|
| targetSdk 35 | Cumple (obligatorio para nuevas apps/actualizaciones en 2025) |
| POST_NOTIFICATIONS declarado | Presente |
| Permisos Bluetooth para Android 12+ | BLUETOOTH_CONNECT + BLUETOOTH_SCAN presentes |
| Data Safety declaration | PENDIENTE — no existe en repositorio, debe completarse en Play Console |
| App Bundle (AAB) | Correcto via Codemagic |
| Signing config release | Correcto |

La **Data Safety declaration** es obligatoria y debe declarar: geolocalización (fichajes), datos biométricos (local_auth), fotos (image_picker), identificadores de dispositivo (device_info_plus, firebase_analytics). La omisión puede resultar en rechazo o eliminación de la app.

### Windows / distribución directa

No aplica legislación de tienda. Sin embargo, la distribución de software sin firma de código en entornos corporativos puede violar políticas de seguridad del cliente final (GPO que bloquean ejecutables no firmados).

### RGPD / LOPDGDD (aplicable a todas las plataformas)

- La app procesa datos de empleados (geolocalización en fichajes, biometría) y datos de clientes de empresas. Estos datos son especialmente sensibles bajo el RGPD.
- Los fichajes con geolocalización requieren que la empresa informe al empleado y tenga base legal (generalmente contrato laboral + convenio colectivo).
- El uso de biometría para control de acceso requiere DPO y, en muchos casos, evaluación de impacto (DPIA) según art. 35 RGPD.
- La app no incluye mecanismos de portabilidad ni borrado de datos visible para el usuario final — pendiente de evaluar si es necesario.

---

## Deuda técnica

1. **namespace vs applicationId Android**: la inconsistencia `com.fluixcrm.crm` / `com.fluixcrm.app` es deuda activa. Aunque funciona hoy, genera confusión y puede romper con cambios futuros de AGP.
2. **Windows sin estrategia de distribución**: la plataforma está compilada pero no tiene pipeline de empaquetado, firma, distribución ni actualización. Es una plataforma a medias.
3. **Tres versiones de Flutter sin alinear**: proyecto (`^3.11.1`), Codemagic (`3.41.3`), GitHub Actions (`3.24.0`). Cada entorno puede producir builds distintos.
4. **`CacheService` sin FFI en Windows**: `offline_queue_service.dart` sí lo resuelve bien, pero `cache_service.dart` no. El patrón correcto está implementado, falta aplicarlo consistentemente.
5. **`mobile_scanner` sin guard en Windows**: el escáner de cámara del TPV no tiene protección de plataforma. En Windows, abrir el modal de escáner producirá un crash de plugin no implementado.
6. **`blue_thermal_printer` instanciación incondicional**: `ImpressoraBluetooth._instance` se crea al importar el servicio, incluso en Windows donde el plugin no existe. Si el plugin lanza en init, la app crashea en startup.
7. **Deep links sin Universal Links**: usar solo esquema propio (`fluixcrm://`) es menos seguro que Universal Links / App Links. Cualquier app puede registrar el mismo esquema.
8. **`google-services.json` con entrada `com.fluixcrm.ap`**: artefacto de configuración sin limpiar.
9. **`PrivacyInfo.xcprivacy` posiblemente incompleto**: `NSPrivacyCollectedDataTypes` vacío puede no ser correcto dado el uso de Firebase Analytics.
10. **GitHub Actions usa flutter 3.24.0**: versión anterior que no coincide con el desarrollo activo. Las pruebas CI pueden pasar en una versión y fallar en producción.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|---|---|---|
| P1 — Bloqueante producción | Verificar que `key.properties` está en `.gitignore` y no se ha subido al repositorio con contraseñas | S |
| P1 — Bloqueante producción | Añadir guard de plataforma en `mobile_scanner` (TPV tienda y escáner QR) para Windows: mostrar alternativa o deshabilitar el botón | S |
| P1 — Bloqueante producción | Inicializar FFI en `cache_service.dart` para Windows (copiar el patrón de `offline_queue_service.dart`) | S |
| P2 — Riesgo alto | Alinear `namespace` con `applicationId` en `build.gradle.kts`: cambiar namespace a `com.fluixcrm.app` o documentar explícitamente por qué difieren | S |
| P2 — Riesgo alto | Completar Data Safety declaration en Play Console (geolocalización, biometría, fotos, identificadores) | S |
| P2 — Riesgo alto | Evaluar y añadir guard para `blue_thermal_printer` en Windows para evitar crash en startup si el plugin falla al inicializar | S |
| P3 — Distribución Windows | Implementar empaquetado MSIX con herramienta `msix` (pub.dev) para habilitar distribución y auto-update | M |
| P3 — Distribución Windows | Obtener certificado de firma de código (OV/EV) y configurar en pipeline CI para Windows | M |
| P3 — Distribución Windows | Crear workflow Codemagic o GitHub Actions para Windows (build → sign → package MSIX) | M |
| P4 — Calidad CI | Alinear versión Flutter en `codemagic.yaml`, `.github/workflows/flutter_tests.yml` y entorno local a una única versión estable | S |
| P4 — Calidad CI | Limpiar entrada duplicada `com.fluixcrm.ap` en `google-services.json` | S |
| P4 — Calidad iOS | Revisar `PrivacyInfo.xcprivacy`: añadir tipos de datos recopilados por Firebase Analytics y Crashlytics en `NSPrivacyCollectedDataTypes` | S |
| P4 — Calidad iOS | Sincronizar `BUNDLE_ID` en `GoogleService-Info.plist` con el bundle ID real (`com.fluixtech.crm`) | S |
| P5 — Seguridad | Evaluar migración a Universal Links (iOS) y App Links (Android) para deep links verificados por dominio | L |
| P5 — Compliance RGPD | Realizar DPIA para el módulo de fichajes con geolocalización y biometría; documentar base legal | L |

---

*Análisis solo lectura. Sin modificación de código ni commits.*
