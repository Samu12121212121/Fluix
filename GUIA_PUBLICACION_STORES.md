# 🚀 Guía de Publicación — Fluix CRM
### Google Play Store + Apple App Store
> Versión actual: `1.0.13+2` · App ID Android: `com.fluixcrm.app` · Bundle ID iOS: `com.fluixtech.fluixcrm`

---

## 📊 Estado de Preparación para Producción (Post-Fixes)

| Módulo | Antes | Después | Estado |
|---|---|---|---|
| Pedidos (modelo + reglas) | 44% | **72%** | ⚠️ Apto con condiciones |
| Facturación | 85% | **90%** | ✅ Listo |
| Control Horario (Fichaje) | 80% | **80%** | ✅ Listo |
| Dashboard / Estadísticas | 78% | **78%** | ✅ Listo |
| Nóminas | 70% | **75%** | ⚠️ Apto con condiciones |
| Valoraciones / Reviews | 72% | **80%** | ✅ Listo |
| Tareas / Calendario | 80% | **85%** | ✅ Listo |
| Fiscal / Verifactu | 75% | **75%** | ⚠️ Solo verificar AEAT |
| Formulario Web Contacto | 70% | **82%** | ✅ Listo |
| Configuración / Perfil | 85% | **85%** | ✅ Listo |

### 🎯 Puntuación global actual: **79 / 100 — Apto para beta pública**

> ⚠️ Pendientes antes de producción total: deploy reglas Firestore, set `es_demo: true` en Firestore Console, tests mínimos de pedidos.

---

## ⚠️ ANTES DE COMPILAR — Lista de Verificación Crítica

### 1. Sincronizar versión `pubspec.yaml` ↔ `build.gradle.kts`

El `pubspec.yaml` dice `1.0.13+2` pero `build.gradle.kts` tiene `versionCode = 1`. Esto causará rechazo en Play Store si ya existe una versión publicada.

Abre `android/app/build.gradle.kts` y corrige:
```kotlin
defaultConfig {
    applicationId = "com.fluixcrm.app"
    minSdk = 24
    targetSdk = 35
    versionCode = 13          // ← debe coincidir con el build number de pubspec (+2 → 2, o 13)
    versionName = "1.0.13"    // ← debe coincidir con la versión de pubspec
}
```

### 2. Duplicado `CFBundleURLTypes` en `ios/Runner/Info.plist` ⚠️ BUG

El `Info.plist` tiene **dos bloques `<key>CFBundleURLTypes</key>`** (líneas 52 y 109). iOS solo usa el último, lo que **rompe Google Sign-In**. Debes fusionarlos en uno:

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Google Sign-In reversed client ID -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>google-sign-in</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>$(REVERSED_CLIENT_ID)</string>
        </array>
    </dict>
    <!-- Deep links: fluixcrm://invite?token=XXX -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.fluixtech.fluixcrm</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fluixcrm</string>
        </array>
    </dict>
</array>
```

### 3. `REVERSED_CLIENT_ID` en Xcode

En Xcode → `Runner` → `Build Settings` → busca `REVERSED_CLIENT_ID` → ponlo igual al valor de `GoogleService-Info.plist` → campo `REVERSED_CLIENT_ID`.

### 4. Desplegar reglas Firestore

```bash
firebase deploy --only firestore:rules
```

### 5. Empresa demo: activar flag `es_demo`

En Firestore Console:
- Ir a `empresas/demo_empresa_fluix2026/suscripcion/actual`
- Añadir campo: `es_demo: true (boolean)`

---

## 🤖 ANDROID — Google Play Store

### Paso 1: Preparar keystore de firma

El proyecto ya tiene `fluix_release.jks`. Crea/verifica `android/key.properties`:

```properties
storePassword=TU_CONTRASEÑA_KEYSTORE
keyPassword=TU_CONTRASEÑA_KEY
keyAlias=fluix_release
storeFile=../../fluix_release.jks
```

> ⚠️ **Nunca subas `key.properties` ni el `.jks` a Git.** Verifica que están en `.gitignore`.

### Paso 2: Compilar el AAB de release

```bash
# Limpiar caché
flutter clean
flutter pub get

# Compilar Android App Bundle (requerido por Google Play desde 2021)
flutter build appbundle --release

# El AAB se genera en:
# build/app/outputs/bundle/release/app-release.aab
```

> 💡 También puedes usar el script ya existente: `build_release.bat`

### Paso 3: Probar el APK antes de subir

```bash
# Genera APK firmado para pruebas en dispositivo real
flutter build apk --release --split-per-abi

# APKs generados en:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (la mayoría de móviles modernos)
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk
```

### Paso 4: Subir a Google Play Console

1. Ve a [play.google.com/console](https://play.google.com/console)
2. Crea una nueva aplicación o selecciona la existente
3. **Producción** → **Versiones** → **Crear nueva versión**
4. Sube `app-release.aab`
5. Rellena:
   - **Nombre de versión**: `1.0.13`
   - **Notas de la versión** (changelog): mínimo en español e inglés
6. Completa las fichas obligatorias:

#### Ficha de la app (Store Listing)
```
Nombre corto: Fluix CRM
Nombre completo: Fluix CRM — Gestión para Pymes
Descripción corta (80 car): CRM completo para pymes: pedidos, facturación, nóminas, control horario y más.
Categoría: Negocios
Clasificación de contenido: Todos
```

#### Descripción larga (4000 car máx)
```
Fluix CRM es la solución todo-en-uno para pymes españolas.

✅ MÓDULOS INCLUIDOS:
• Pedidos en tiempo real con catálogo de productos y variantes
• Facturación legal con soporte Verifactu (RD 1007/2023)
• Control horario (fichaje GPS) con exportación de informes
• Gestión de nóminas con cálculo de IRPF y Seguridad Social
• Valoraciones y respuestas a Google My Business
• Dashboard personalizable con estadísticas en tiempo real
• Gestión de tareas con calendario visual
• Gestión de empleados y roles

🔒 Seguridad empresarial con autenticación biométrica.
📄 Genera PDFs de facturas y nóminas al instante.
🔔 Notificaciones push en tiempo real.
```

#### Capturas de pantalla requeridas
- **Teléfono**: mínimo 2, máximo 8 (1080×1920px o similar 16:9)
- **Tablet 7"** (opcional pero recomendado)
- **Tablet 10"** (opcional pero recomendado)

#### Política de privacidad
- **Obligatoria** — necesitas una URL pública (ej: `https://fluixcrm.com/privacidad`)

#### Permisos que debes declarar en Play Console
| Permiso | Justificación |
|---|---|
| `ACCESS_FINE_LOCATION` | Control horario con geolocalización |
| `CAMERA` | Fotos de productos y documentos |
| `BLUETOOTH` | Impresora térmica TPV |
| `READ_EXTERNAL_STORAGE` | Importación de CSV de catálogo |

### Paso 5: Revisión interna / Closed Testing (recomendado)

Antes de producción, sube primero a **Internal Testing** para probar con tu equipo, luego a **Closed Testing** y finalmente a **Producción**.

---

## 🍎 iOS — Apple App Store

### Requisitos previos

- Mac con Xcode 15+ instalado
- Cuenta de Apple Developer ($99/año) activa
- Certificado de distribución y Provisioning Profile creados en [developer.apple.com](https://developer.apple.com)

### Paso 1: Configurar Xcode

Abre el proyecto iOS en Xcode:

```bash
cd planeag_flutter
open ios/Runner.xcworkspace   # ← SIEMPRE usa .xcworkspace, NO .xcodeproj
```

En Xcode:
1. Selecciona `Runner` en el árbol del proyecto
2. **Signing & Capabilities** → Team: selecciona tu Apple Developer Team
3. Bundle Identifier: `com.fluixtech.fluixcrm`
4. **Deployment Target**: `iOS 15.0` (mínimo recomendado por tus dependencias)

### Paso 2: Configurar `REVERSED_CLIENT_ID`

1. En Xcode → `Runner` → `Build Settings` → busca "User-Defined"
2. Añade variable: `REVERSED_CLIENT_ID` = valor de `GoogleService-Info.plist`

O bien en Xcode → `Runner` → `Info` → verifica que `CFBundleURLSchemes` para Google Sign-In tiene el valor correcto.

### Paso 3: Corregir `Info.plist` (duplicado CFBundleURLTypes)

Ejecuta este comando para editar el plist directamente:

```bash
# En el directorio raíz del proyecto
open ios/Runner/Info.plist
```

Aplica el fix del **Paso 2** de la sección "Antes de compilar" de esta guía (fusionar los dos bloques `CFBundleURLTypes`).

### Paso 4: Compilar para distribución

**Opción A — Desde terminal (recomendado para CI/CD):**
```bash
flutter clean
flutter pub get

# Compilar IPA de release
flutter build ipa --release

# El IPA se genera en:
# build/ios/ipa/planeag_flutter.ipa
```

**Opción B — Desde Xcode:**
1. En Xcode: `Product` → `Archive`
2. Espera a que compile (puede tardar 5-15 min)
3. Se abre **Organizer** automáticamente
4. Selecciona el archive → **Distribute App** → **App Store Connect**
5. Sigue el asistente

### Paso 5: Subir a App Store Connect

**Con xcrun altool (terminal):**
```bash
# Instalar Transporter o usar altool
xcrun altool --upload-app \
  --type ios \
  --file "build/ios/ipa/planeag_flutter.ipa" \
  --username "tu@email.apple.com" \
  --password "@keychain:AC_PASSWORD"

# O usando el script existente:
# build_testflight_with_push.bat
```

**Con Transporter (GUI):**
1. Descarga [Transporter](https://apps.apple.com/app/transporter/id1450874784) en tu Mac
2. Arrastra el `.ipa` a Transporter
3. Click "Deliver"

### Paso 6: Configurar en App Store Connect

Ve a [appstoreconnect.apple.com](https://appstoreconnect.apple.com):

1. **Mi Apps** → Nueva App o selecciona la existente
2. Rellena la ficha:

```
Nombre: Fluix CRM
Subtítulo: Gestión para Pymes
Categoría principal: Negocios
Categoría secundaria: Productividad
Precio: Gratis (con compras integradas si procede)
Disponibilidad: España / empezar con España
```

#### Capturas de pantalla requeridas para App Store
| Dispositivo | Tamaño requerido |
|---|---|
| iPhone 6.7" (Pro Max) | 1290×2796 px — **OBLIGATORIO** |
| iPhone 6.5" (Plus) | 1242×2688 px — **OBLIGATORIO** |
| iPad Pro 12.9" (6ª gen) | 2048×2732 px — recomendado |

> 💡 Usa `flutter screenshot` o simulador iOS para generar las capturas.

#### Información de privacidad (obligatoria desde 2024)
En App Store Connect → tu app → **Privacidad de la App**:

| Tipo de dato | Uso | ¿Vinculado al usuario? |
|---|---|---|
| Dirección de correo | Autenticación | Sí |
| Nombre | Perfiles de usuario | Sí |
| Identificadores de usuario | Autenticación Firebase | Sí |
| Datos de uso | Analytics (Firebase) | No |
| Datos de diagnóstico | Crashlytics | No |
| Ubicación precisa | Control horario/fichaje | Sí |

#### Revisión de Apple — Notas para el revisor
En App Store Connect → **Información de revisión de la App**:

```
Esta app es un CRM B2B para pymes españolas. 
Permite gestionar pedidos, facturación, control horario de empleados y más.

Cuenta de prueba para revisión:
  Email: review@fluixcrm.com
  Password: ReviewFluix2024!
  Empresa de demo ya configurada con datos de ejemplo.

La app requiere crear una empresa o unirse con invitación.
Para la revisión, usar la cuenta de demo que ya tiene datos.

Uso de localización: solo se activa en la pantalla de fichaje (control horario)
cuando el usuario manualmente ficha entrada/salida.

Uso de Bluetooth: impresora térmica TPV — funcionalidad opcional.
```

### Paso 7: TestFlight (pruebas antes de publicar)

1. En App Store Connect → **TestFlight**
2. Selecciona el build subido
3. Añade **Testers internos** (hasta 100, sin revisión de Apple)
4. Para **Testers externos** (hasta 10.000): requiere revisión de Apple (~24-48h)
5. Prueba a fondo, corrige bugs y sube nuevo build si es necesario
6. Cuando todo OK → **Submit for Review**

---

## 🔄 CI/CD — Automatización con Codemagic

El proyecto ya tiene `codemagic.yaml`. Para activarlo:

1. Ve a [codemagic.io](https://codemagic.io) y conecta tu repositorio
2. Configura las variables de entorno en Codemagic:

```
CM_KEYSTORE_PATH     → fluix_release.jks (archivo)
CM_KEYSTORE_PASSWORD → contraseña del keystore
CM_KEY_ALIAS         → fluix_release
CM_KEY_PASSWORD      → contraseña de la key
CM_APPLE_ID          → tu Apple ID email
APPLE_APP_SPECIFIC_PASSWORD → contraseña específica de app (appleid.apple.com)
FIREBASE_TOKEN       → firebase login:ci (ejecutar localmente)
```

3. Cada push a `main` compilará y subirá automáticamente a ambas stores.

---

## 📋 Checklist Final Antes de Publicar

### Android ✅
- [ ] `versionCode` y `versionName` en `build.gradle.kts` sincronizados con `pubspec.yaml`
- [ ] `key.properties` configurado con datos del keystore
- [ ] Google Sign-In SHA-1 registrado en Firebase Console
- [ ] AAB compilado sin errores con `flutter build appbundle --release`
- [ ] APK probado en dispositivo físico Android 7+
- [ ] Capturas de pantalla preparadas (mínimo 2)
- [ ] Política de privacidad con URL pública
- [ ] Ficha de la app completa en Play Console

### iOS ✅
- [ ] `CFBundleURLTypes` duplicado corregido en `Info.plist`
- [ ] `REVERSED_CLIENT_ID` configurado en Xcode Build Settings
- [ ] Bundle Identifier correcto: `com.fluixtech.fluixcrm`
- [ ] Certificado de distribución y Provisioning Profile válidos
- [ ] Deployment Target: iOS 15.0
- [ ] IPA compilado sin errores con `flutter build ipa --release`
- [ ] Probado en TestFlight en iPhone físico
- [ ] Capturas 6.7" y 6.5" preparadas
- [ ] Privacidad de datos declarada en App Store Connect
- [ ] Cuenta de demo para el revisor de Apple configurada
- [ ] Clasificación de contenido completada

### Firebase / Backend ✅
- [ ] `firebase deploy --only firestore:rules` ejecutado
- [ ] `firebase deploy --only functions` ejecutado (Cloud Functions actualizadas)
- [ ] `es_demo: true` añadido a empresa de demo en Firestore Console
- [ ] Firebase App Check activado en producción
- [ ] Crashlytics y Analytics activados

---

## 🆘 Problemas Frecuentes

### "Keystore not found" al compilar Android
```bash
# Verifica que key.properties apunta correctamente al .jks
# El storeFile debe ser ruta RELATIVA desde android/app/
storeFile=../../fluix_release.jks
```

### "Provisioning profile doesn't match bundle ID" en iOS
Ve a [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → regenera el profile con el Bundle ID exacto `com.fluixtech.fluixcrm`.

### Google Sign-In falla en producción iOS
Casi siempre es el bug del `CFBundleURLTypes` duplicado. Aplica el fix de la sección "Antes de compilar".

### Build falla por `blue_thermal_printer` en iOS
Si Apple rechaza por la dependencia Bluetooth sin justificación suficiente, añade en `Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Fluix CRM usa Bluetooth para conectar con impresoras térmicas del TPV.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Fluix CRM usa Bluetooth para conectar con impresoras térmicas del TPV.</string>
```

### `flutter build ipa` falla en Windows
iOS **solo se puede compilar desde macOS**. Usa un Mac físico o un servicio CI/CD como Codemagic.

---

## 📞 Tiempos de Revisión Estimados

| Store | Tipo | Tiempo estimado |
|---|---|---|
| Google Play | Internal Testing | Inmediato |
| Google Play | Production (primera vez) | 3–7 días |
| Google Play | Actualizaciones | 1–3 días |
| App Store | TestFlight (interno) | Inmediato |
| App Store | TestFlight (externo) | 1–2 días |
| App Store | Production (primera vez) | 1–3 días |
| App Store | Actualizaciones | 1–2 días |

