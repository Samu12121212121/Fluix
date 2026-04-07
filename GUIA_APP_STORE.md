# 🍎 Guía Completa — Subir Fluix CRM a la App Store

> **Fecha:** 7 de abril de 2026  
> **Estado actual:** Proyecto preparado en Windows, necesita pasos en Mac para iOS.

---

## ⚠️ REQUISITOS PREVIOS (obligatorio)

| Requisito | Estado | Coste |
|-----------|--------|-------|
| Cuenta Apple Developer | ❌ Necesitas crearla | **99 €/año** |
| Mac con Xcode 16+ | ❌ Necesitas acceso | Ver alternativas abajo |
| Bundle ID real (no `com.example.*`) | ❌ Hay que cambiarlo | Gratis |
| `GoogleService-Info.plist` para iOS | ❌ Falta descargarlo | Gratis |
| Política de privacidad pública | ✅ Ya tienes `POLITICA_PRIVACIDAD.md` | Necesitas URL pública |
| Permisos iOS en Info.plist | ✅ **Ya configurados** | — |
| Podfile iOS | ✅ **Ya creado** | — |
| Sign In with Apple configurado | ✅ Entitlement ya existe | — |
| Icono de la app | ✅ `assets/icons/app_icon.png` existe | — |

---

## PASO 1 — Crear cuenta Apple Developer (5 min + 48h de espera)

1. Ve a **[developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/)**
2. Inicia sesión con tu Apple ID (o crea uno)
3. Elige **Individual** (autónomo) o **Organization** (empresa con D-U-N-S)
   - Para Fluixtech S.L. → elige **Organization** (necesitas número D-U-N-S de Dun & Bradstreet)
   - Si quieres empezar rápido → elige **Individual** y migra después
4. Paga los **99 €/año**
5. Apple tarda **24-48 horas** en aprobar la cuenta

---

## PASO 2 — Cambiar el Bundle ID (CRÍTICO)

Apple **rechaza** cualquier app con `com.example.*`. Necesitas un Bundle ID real.

### 2A. Registrar el Bundle ID en Apple Developer

1. Ve a **[developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)**
2. Click **"+"** → **App IDs** → **App**
3. Rellena:
   - **Description:** `Fluix CRM`
   - **Bundle ID:** `com.fluixtech.crm` (tipo Explicit)
4. En **Capabilities**, activa:
   - ✅ Sign In with Apple
   - ✅ Push Notifications
   - ✅ Associated Domains (si usas deep links)
5. Click **Continue** → **Register**

### 2B. Actualizar el Bundle ID en el proyecto

**⚠️ IMPORTANTE:** Esto también requiere actualizar Firebase. Haz los pasos en orden.

#### Archivo: `ios/Runner.xcodeproj/project.pbxproj`
Busca y reemplaza TODAS las ocurrencias:
```
com.example.planeagFlutter  →  com.fluixtech.crm
```
(Son ~3 líneas con `PRODUCT_BUNDLE_IDENTIFIER`)

#### Archivo: `android/app/build.gradle.kts`
```kotlin
// Cambiar AMBOS:
namespace = "com.fluixtech.crm"
applicationId = "com.fluixtech.crm"
```

#### Archivo: `lib/firebase_options.dart`
```dart
// Línea 67 y 76:
iosBundleId: 'com.fluixtech.crm',
```

### 2C. Actualizar Firebase con el nuevo Bundle ID

1. Ve a **[console.firebase.google.com](https://console.firebase.google.com)** → proyecto `planeaapp-4bea4`
2. Click ⚙️ → **Configuración del proyecto** → **Tus apps**
3. Si la app iOS tiene bundle ID `com.example.planeagFlutter`:
   - Click **"Añadir app"** → iOS
   - Bundle ID: `com.fluixtech.crm`
   - Apodo: `Fluix CRM iOS`
   - Descarga el **`GoogleService-Info.plist`**
4. Copia ese archivo a:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
5. Haz lo mismo para Android si cambias el applicationId:
   - Descarga nuevo `google-services.json` → `android/app/google-services.json`

---

## PASO 3 — Opción A: Compilar en un Mac (lo normal)

Si tienes acceso a un Mac (propio, amigo, alquilado en MacStadium):

```bash
# 1. Clonar el proyecto en el Mac
git clone <tu-repo> && cd planeag_flutter

# 2. Instalar dependencias
flutter pub get
cd ios && pod install && cd ..

# 3. Abrir en Xcode para configurar firma
open ios/Runner.xcworkspace
```

En Xcode:
1. Selecciona **Runner** en el navegador izquierdo
2. Tab **Signing & Capabilities**
3. Marca **"Automatically manage signing"**
4. **Team:** selecciona tu cuenta Apple Developer
5. **Bundle Identifier:** `com.fluixtech.crm`
6. Xcode generará automáticamente los certificados y provisioning profiles

```bash
# 4. Compilar el IPA
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# El .ipa estará en:
# build/ios/ipa/planeag_flutter.ipa
```

---

## PASO 3 — Opción B: Compilar sin Mac (usando Codemagic)

**Esta es tu mejor opción desde Windows.**

### Paso 3B.1 — Subir proyecto a GitHub
```powershell
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
git add -A
git commit -m "Preparar para App Store"
git remote add origin https://github.com/TU_USUARIO/fluix-crm.git
git push -u origin main
```

### Paso 3B.2 — Configurar Codemagic

1. Ve a **[codemagic.io](https://codemagic.io)** y crea cuenta gratis
2. Conecta tu repositorio de GitHub
3. Selecciona **Flutter App**
4. En la configuración:
   - **Build platform:** iOS
   - **Build mode:** Release
   - **Xcode version:** Latest stable
5. En **Code signing → iOS**:
   - Sube tu **Apple Distribution Certificate** (`.p12`)
   - O usa **Automatic code signing** con tus credenciales Apple Developer
   - App Store Connect API key (recomendado):
     1. [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
     2. Genera una API Key con rol **App Manager**
     3. Sube el `.p8`, Issuer ID y Key ID a Codemagic
6. En **Distribution → App Store Connect**:
   - Activa "Publish to App Store Connect"
   - Esto subirá el IPA automáticamente

### Paso 3B.3 — Compilar
- Click **Start new build**
- Codemagic compila en la nube (Mac virtual)
- En ~15 min tienes el IPA subido a App Store Connect

---

## PASO 4 — Subir a App Store Connect

### Si compilaste en Mac local:
```bash
# Opción 1: Usar Transporter (app gratuita de Apple)
# Descargar de Mac App Store → arrastra el .ipa

# Opción 2: Desde Xcode
# Product → Archive → Distribute App → App Store Connect
```

### Si usaste Codemagic:
El IPA ya está subido automáticamente. Continúa al paso 5.

---

## PASO 5 — Configurar la ficha en App Store Connect

1. Ve a **[appstoreconnect.apple.com](https://appstoreconnect.apple.com)**
2. Click **"Mis apps"** → **"+"** → **"App nueva"**
3. Rellena:

| Campo | Valor |
|-------|-------|
| **Nombre** | Fluix CRM |
| **Idioma principal** | Español (España) |
| **Bundle ID** | com.fluixtech.crm (seleccionar del dropdown) |
| **SKU** | fluixcrm001 |
| **Acceso** | Acceso completo |

4. Tab **"Información de la app"**:
   - **Categoría principal:** Negocios
   - **Categoría secundaria:** Productividad
   - **URL de la política de privacidad:** `https://fluixtech.com/privacidad`

5. Tab **"Precios y disponibilidad"**:
   - **Precio:** Gratis (o el plan que quieras)
   - **Disponibilidad:** España (añadir más países si quieres)

---

## PASO 6 — Preparar la versión para revisión

### 6A. Capturas de pantalla (OBLIGATORIO)

Apple exige capturas para **al menos 2 tamaños**:

| Dispositivo | Resolución | Requerido |
|-------------|------------|-----------|
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 | ✅ Sí |
| iPhone 6.5" (11 Pro Max) | 1284 × 2778 | ✅ Sí |
| iPad 12.9" (si soportas iPad) | 2048 × 2732 | Opcional |

**Cómo hacer capturas:**
- Usa el simulador de Xcode o capturas de tu iPhone
- Mínimo **3 capturas** por tamaño (recomendado 5-6)
- Pantallas sugeridas: Login, Dashboard, Nóminas, Facturas, Calendario

### 6B. Textos de la Store

```
Nombre: Fluix CRM
Subtítulo: Gestión empresarial para pymes (máx 30 caracteres)

Descripción (máx 4000 caracteres):
---
Fluix CRM es la herramienta todo-en-uno para gestionar tu negocio.

✅ Nóminas automáticas con cálculo de SS e IRPF (normativa española 2026)
✅ Facturación completa: emitidas, recibidas, rectificativas
✅ Control horario con fichaje GPS
✅ Gestión de clientes, reservas y pedidos
✅ Modelos fiscales: 111, 115, 130, 190, 303, 390
✅ Calendario de vacaciones y ausencias
✅ Dashboard personalizable con KPIs en tiempo real
✅ Firma de documentos y finiquitos
✅ Remesas SEPA para pagos de nóminas
✅ Compatible con Verifactu (RD 1007/2023)

Diseñado para autónomos, comercios, hostelería, peluquerías y pymes españolas.

Datos seguros en la nube con Firebase. Cumple RGPD y LOPDGDD.
---

Palabras clave: crm, nominas, facturas, pymes, gestion, negocio, irpf, seguridad social
```

### 6C. Clasificación de contenido

- Ve a **"Clasificación de edades"**
- Contesta NO a todo (violencia, drogas, etc.)
- Resultado: **4+** (apto para todos)

### 6D. Información de revisión de Apple

Apple prueba la app manualmente. Necesitas darles:

| Campo | Valor |
|-------|-------|
| **Nombre del contacto** | Tu nombre |
| **Teléfono** | Tu teléfono |
| **Email** | Tu email |
| **Credenciales de demo** | Email y contraseña de una cuenta de prueba funcional |
| **Notas para el revisor** | "App de gestión empresarial (CRM) para pymes españolas. Use las credenciales de demo para ver el dashboard con datos de ejemplo." |

**⚠️ IMPORTANTE:** Crea una cuenta de demo con datos de ejemplo ANTES de enviar a revisión. Si el revisor no puede probar la app, la rechazan.

---

## PASO 7 — Enviar a revisión

1. En App Store Connect → tu app → **"Versión 1.0"**
2. En la sección **"Build"**, selecciona el IPA que subiste
3. Rellena todos los campos obligatorios (capturas, descripción, etc.)
4. Click **"Añadir para revisión"**
5. Click **"Enviar para revisión"**

### Tiempos de revisión:
- **Primera vez:** 24-48 horas (a veces hasta 7 días)
- **Actualizaciones:** 24 horas normalmente
- **Motivos comunes de rechazo:**
  - Falta política de privacidad → ✅ Ya la tienes
  - Falta Sign In with Apple → ✅ Ya lo tienes
  - App crashea → Testea bien antes
  - Capturas no coinciden con la app real
  - No proporcionaste credenciales de demo

---

## 📋 CHECKLIST FINAL ANTES DE ENVIAR

```
[ ] Cuenta Apple Developer activa (99 €/año pagados)
[ ] Bundle ID cambiado de com.example.* → com.fluixtech.crm
[ ] GoogleService-Info.plist descargado y en ios/Runner/
[ ] firebase_options.dart actualizado con nuevo iosBundleId
[ ] Compilación exitosa (flutter build ipa --release)
[ ] Versión en pubspec.yaml: 1.0.0+1
[ ] Icono real de la app (no el Flutter por defecto)
[ ] 3-6 capturas de pantalla por tamaño requerido
[ ] Descripción de la app redactada
[ ] Política de privacidad en URL pública (fluixtech.com/privacidad)
[ ] Cuenta de demo creada para el revisor de Apple
[ ] Sign In with Apple funcional
[ ] Probada en iPhone real (o simulador) sin crashes
```

---

## 🏪 ¿Y Google Play Store?

Ya tienes la guía en `PASOS_PUBLICACION.md`. El resumen:

```powershell
# 1. Cambiar applicationId en android/app/build.gradle.kts
#    com.example.planeag_flutter → com.fluixtech.crm

# 2. Generar AAB firmado
flutter build appbundle --release

# 3. Subir a Play Console (play.google.com/console)
#    - Crear app → Rellenar ficha → Subir AAB → Pruebas internas
```

**Coste:** 25 € (pago único, para siempre)

---

## ⏱️ RESUMEN DE TIEMPOS

| Paso | Tiempo |
|------|--------|
| Crear Apple Developer Account | 5 min + 48h espera |
| Configurar Bundle ID + Firebase | 30 min |
| Compilar con Codemagic (primera vez) | 1-2 horas (setup) |
| Rellenar App Store Connect | 1-2 horas |
| Revisión de Apple | 24h - 7 días |
| **Total hasta publicación** | **~3-5 días** |

---

## 🚨 ERRORES FRECUENTES Y SOLUCIONES

### "Missing Push Notification Entitlement"
→ Ya configurado en `Runner.entitlements`. Si da error, activa Push Notifications en el Apple Developer Portal para tu App ID.

### "Missing Purpose String in Info.plist"
→ ✅ Ya añadidos todos los `NSUsageDescription` necesarios.

### "App uses non-public APIs"
→ Asegúrate de usar `flutter build ipa --release` (no debug).

### "Sign In with Apple not working"
→ Verifica que el App ID en Apple Developer tiene "Sign In with Apple" activado.

