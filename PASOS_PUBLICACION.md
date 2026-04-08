# 🚀 Pasos para Publicar Fluix CRM

**Última actualización:** 08/04/2026  
**Versión objetivo:** 1.0.0  
**Estado:** En preparación

---

## ⚠️ PRE-REQUISITOS (Resolver antes de cualquier cosa)

## ✅ Ya hecho automáticamente
- [x] `applicationId` cambiado a `com.planeaguada.crm`
- [x] `minSdk = 24`, `targetSdk = 35`
- [x] `versionCode = 1`, `versionName = 1.0.0`
- [x] Nombre de la app: **PlaneaGuada**
- [x] Permisos de notificaciones, internet, cámara configurados
- [x] Firebase configurado con `google-services.json`

---

## 📱 PARTE 1 — Probar en tu móvil físico HOY MISMO

### Android (el más rápido, sin cuenta de desarrollador)

**Paso 1:** Activa modo desarrollador en tu móvil Android
```
Ajustes → Acerca del teléfono → Toca "Número de compilación" 7 veces
Ajustes → Opciones de desarrollador → Depuración USB → Activar
```

**Paso 2:** Conecta el móvil al PC con USB y ejecuta:
```bash
flutter devices
```
Debe aparecer tu móvil en la lista.

**Paso 3:** Ejecuta en tu móvil:
```bash
flutter run --release
```

**Paso 4 (sin cable):** Para instalar sin cable, genera el APK:
```bash
flutter build apk --release
```
El APK estará en:
```
build/app/outputs/flutter-apk/app-release.apk
```
Pásalo por WhatsApp o Google Drive a tu móvil y ábrelo.

---

## 🍎 PARTE 2 — TestFlight (iOS, necesitas Mac + cuenta Apple Developer)

### Requisitos previos
- Mac con Xcode instalado
- Cuenta Apple Developer: **99€/año** en [developer.apple.com](https://developer.apple.com)
- iPhone con iOS 16+

### Pasos
```bash
# En el Mac, dentro del proyecto
flutter build ipa --release

# Luego abrir Xcode → Product → Archive → Distribute App → TestFlight
```

**Alternativa sin Mac:** Usar un servicio de CI/CD como Codemagic (tienen plan gratuito para iOS).

---

## 🏪 PARTE 3 — Play Store (Android, necesitas cuenta de desarrollador)

### Requisitos
- Cuenta Google Play Developer: **pago único de 25€**
- Keystore (firma digital) — se genera UNA VEZ y se guarda SIEMPRE

### Paso A — Generar Keystore (solo una vez en tu vida)
Ejecuta esto en PowerShell:
```powershell
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\android

keytool -genkey -v -keystore planeaguada-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias planeaguada
```
Te pedirá:
- Contraseña del keystore (guárdala, la necesitarás siempre)
- Nombre, organización, ciudad, país

**⚠️ IMPORTANTÍSIMO:** Guarda el archivo `.jks` y la contraseña. Si los pierdes no puedes actualizar la app nunca más.

### Paso B — Configurar la firma en el proyecto
Edita `android/key.properties` (crear si no existe):
```properties
storePassword=TU_CONTRASEÑA
keyPassword=TU_CONTRASEÑA
keyAlias=planeaguada
storeFile=../planeaguada-release.jks
```

Edita `android/app/build.gradle.kts` añadiendo:
```kotlin
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Paso C — Generar AAB para Play Store
```bash
flutter build appbundle --release
```
El archivo estará en:
```
build/app/outputs/bundle/release/app-release.aab
```

### Paso D — Subir a Play Store
1. Ve a [play.google.com/console](https://play.google.com/console)
2. Crea nueva app
3. Rellena: nombre, descripción, capturas de pantalla, icono
4. Ve a "Versiones" → "Pruebas internas" → Sube el `.aab`
5. Añade tus correos de probadores
6. Los probadores recibirán enlace de instalación por correo

---

## 🔄 Cómo actualizar la app (respuesta a tu pregunta)

### Cada vez que quieras actualizar:

**1. Sube el versionCode en `android/app/build.gradle.kts`:**
```kotlin
versionCode = 2        // ← sube 1 cada vez
versionName = "1.0.1"  // ← versión visible
```

**2. También en `pubspec.yaml`:**
```yaml
version: 1.0.1+2  # nombre+código
```

**3. Genera el nuevo AAB:**
```bash
flutter build appbundle --release
```

**4. Sube el AAB a Play Console:**
- Play Console → Tu app → Versiones → Pruebas internas → Nueva versión
- Sube el nuevo `.aab`
- Los usuarios se actualizan automáticamente en 24-48h

### En TestFlight (iOS):
- Mismo proceso pero subiendo el `.ipa` desde Xcode
- Los probadores reciben notificación automática

---

## 📋 Lista de cosas que faltan antes de publicar en producción

### Imprescindibles
- [ ] **Icono real de la app** — ahora usa el Flutter por defecto
- [ ] **Splash screen** con el logo de PlaneaGuada
- [ ] **Keystore** generado y configurado (Android)
- [ ] **Cuenta Apple Developer** (iOS, 99€/año)
- [ ] **Cuenta Play Developer** (Android, 25€ único)
- [ ] **Capturas de pantalla** para la Store (mínimo 2 por pantalla)
- [ ] **Política de privacidad** — URL pública obligatoria en ambas stores
- [ ] **Términos y condiciones** — URL pública

### Recomendables antes de abrir al público
- [ ] Probar con usuarios reales en TestFlight/Pruebas internas primero
- [ ] Probar en móviles Android con versiones 9, 10, 11, 12, 13
- [ ] Revisar que las reglas de Firestore están correctas
- [ ] Desactivar los datos de prueba automáticos (el botón del matraz)
- [ ] Configurar Firebase Crashlytics para detectar crashes

### Opcionales para el MVP
- [ ] Onboarding inicial para nuevas empresas
- [ ] Tutorial de bienvenida

---

## ⚡ Lo más rápido para probar HOY

**Si tienes Android:**
```bash
flutter build apk --release
# Pasa el APK a tu móvil por WhatsApp
```

**Si tienes iPhone + Mac:**
```bash
flutter build ipa --release
# Abre Xcode y distribuye a TestFlight
```

**Si tienes iPhone pero no Mac:**
1. Crear cuenta en [codemagic.io](https://codemagic.io) (gratuito)
2. Conectar el repositorio de GitHub
3. Ellos compilan el IPA en la nube y lo suben a TestFlight

