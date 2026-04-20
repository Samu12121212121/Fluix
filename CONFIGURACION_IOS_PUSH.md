# 🍎 Configuración Notificaciones Push - iOS

> **IMPORTANTE:** Las notificaciones push en iOS requieren más configuración que Android.

---

## ⚠️ Requisitos Previos

- ✅ Apple Developer Account (de pago, $99/año)
- ✅ Dispositivo iOS físico (iPhone/iPad)
- ✅ Xcode instalado
- ❌ **NO funciona en simulador**

---

## 📋 Checklist Completo iOS

### ✅ 1. Entitlements ya configurados

Los archivos siguientes **YA ESTÁN ACTUALIZADOS**:

**`ios/Runner/Runner.entitlements`:**
```xml
<key>aps-environment</key>
<string>development</string>
```

**`ios/Runner/RunnerRelease.entitlements`:**
```xml
<key>aps-environment</key>
<string>production</string>
```

### ⚙️ 2. Configurar Xcode (MANUAL)

**Paso 1:** Abre el proyecto en Xcode
```bash
cd ios
open Runner.xcworkspace  # ¡IMPORTANTE: .xcworkspace, NO .xcodeproj!
```

**Paso 2:** Configurar Signing & Capabilities

1. En Xcode, selecciona el target **"Runner"**
2. Ve a la pestaña **"Signing & Capabilities"**
3. Verifica que tienes configurado:
   - **Team**: Tu equipo de Apple Developer
   - **Bundle Identifier**: `com.fluixtech.crm`

**Paso 3:** Añadir Push Notifications Capability

1. Pulsa el botón **"+ Capability"**
2. Busca **"Push Notifications"**
3. Haz doble clic para añadirla
4. Debe aparecer en la lista de capabilities

**Paso 4:** Verificar Background Modes

1. Si no está, pulsa **"+ Capability"** → **"Background Modes"**
2. Marca la casilla:
   - ✅ **"Remote notifications"**

---

## 🔐 3. Crear Certificado APNs (Apple Developer Portal)

### Opción A: Authentication Key (Recomendado)

**Paso 1:** Crear APNs Key en Apple Developer

1. Ve a [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys)
2. Pulsa **"+"** para crear una nueva key
3. **Key Name**: "Firebase FCM APNs Key"
4. Marca la casilla: **Apple Push Notifications service (APNs)**
5. Pulsa **"Continue"** → **"Register"**
6. **Descarga el archivo `.p8`** (solo se puede descargar UNA vez)
7. Anota el **Key ID** (ejemplo: `AB12CD34EF`)
8. Anota tu **Team ID** (en Account → Membership)

**Paso 2:** Subir a Firebase

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Selecciona tu proyecto: **planeaapp-4bea4**
3. ⚙️ Project Settings → **Cloud Messaging**
4. Scroll hasta **Apple app configuration**
5. Sección **APNs Authentication Key**:
   - Pulsa **"Upload"**
   - Selecciona el archivo `.p8` descargado
   - **Key ID**: Introduce el Key ID anotado
   - **Team ID**: Introduce tu Team ID
6. Pulsa **"Upload"**

✅ Una vez subido, verás:
```
APNs Authentication Key
Key ID: AB12CD34EF
Team ID: XXXXXXXXXX
```

### Opción B: Certificado APNs (Método antiguo)

Solo si no puedes usar Authentication Key:

1. Apple Developer → Certificates
2. Create Certificate → Apple Push Notification service SSL
3. Selecciona App ID: `com.fluixtech.crm`
4. Genera CSR desde Keychain Access
5. Sube CSR y descarga certificado
6. Instala en Keychain
7. Exporta como `.p12`
8. Sube `.p12` a Firebase Console

---

## 🧪 4. Probar en Dispositivo Real

### Conectar iPhone/iPad

1. Conecta el dispositivo por cable USB
2. En Xcode, selecciona tu dispositivo en la barra superior
3. **Product → Run** (o ⌘R)
4. Acepta permisos si es la primera vez:
   - "Confiar en este ordenador"
   - "Permitir notificaciones" (la app lo pide)

### Verificar que el token se obtiene

1. Abre la app en el dispositivo
2. En Xcode, ve a **View → Debug Area → Activate Console**
3. Busca en los logs:
   ```
   📱 Token FCM: [token_muy_largo]
   ✅ Token FCM guardado en usuarios/...
   ✅ Token FCM guardado en empresas/.../dispositivos/...
   ```

4. **Copia el token** (lo necesitarás para probar)

---

## 📬 5. Enviar Notificación de Prueba

### Desde Firebase Console

1. Firebase Console → Cloud Messaging → **"Send your first message"**
2. **Notification text**: "Prueba iOS"
3. **Notification title**: "Test"
4. Pulsa **"Send test message"**
5. **FCM registration token**: Pega el token copiado
6. Pulsa **"Test"**

### Resultado esperado

- ⏱️ En 1-2 segundos debe aparecer la notificación en el iPhone
- Si la app está abierta: Se muestra dentro de la app
- Si la app está cerrada/en background: Aparece como banner/notificación del sistema

### Si NO llega

Ver sección [Troubleshooting](#-troubleshooting).

---

## 🔔 6. Verificar en la App con Debug Widget

**Desde la app (solo modo DEBUG):**

1. Abre la app
2. Pulsa el botón naranja flotante 🐛
3. Se abre el panel de debug
4. Verifica:
   - ✅ Token actual del dispositivo
   - ✅ Token en Firestore
   - ✅ Ambos coinciden

5. Prueba **"Probar notificación local"**
   - Si funciona → El plugin está OK
   - Si no funciona → Revisar permisos

---

## 🐛 Troubleshooting

### Problema 1: "APNs delivery failed"

**Logs de Firebase Functions:**
```
Failed to send message to [token]: 
Requested entity was not found. Error code: APNS_AUTH_ERROR
```

**Solución:**
- Certificado APNs mal configurado o expirado
- Vuelve a subir el `.p8` a Firebase Console
- Verifica que Key ID y Team ID son correctos

---

### Problema 2: Token se obtiene pero notificaciones no llegan

**Verificar:**

1. **Certificado APNs subido a Firebase**
   ```
   Firebase Console → Cloud Messaging → Apple app configuration
   → Debe haber APNs Authentication Key configurado
   ```

2. **Bundle ID correcto**
   ```
   Xcode → Runner → General → Bundle Identifier
   → Debe ser: com.fluixtech.crm
   ```

3. **Entitlements en el build**
   ```bash
   cd ios
   xcodebuild -showBuildSettings | grep ENTITLEMENTS
   → Debe mostrar: Runner.entitlements
   ```

---

### Problema 3: Solo funciona en debug, no en release

**Causa:** `RunnerRelease.entitlements` tiene `development` en lugar de `production`.

**Solución:**

Verifica que `ios/Runner/RunnerRelease.entitlements` tenga:
```xml
<key>aps-environment</key>
<string>production</string>  <!-- NO development -->
```

---

### Problema 4: No pide permiso de notificaciones

**Causa:** iOS cachea la respuesta del usuario.

**Solución:**

1. Desinstala la app completamente del dispositivo
2. Reinicia el iPhone
3. Reinstala desde Xcode
4. La primera vez **debe** mostrar el diálogo de permiso

Si sigue sin pedir:
```
Ajustes → General → Restablecer → Restablecer localización y privacidad
```

---

### Problema 5: "Missing Push Notification Entitlement"

**Al subir a App Store Connect:**

```
Missing Push Notification Entitlement - Your app includes an API 
for Apple's Push Notification service, but the aps-environment 
entitlement is missing from the app's signature.
```

**Solución:**

1. Abre Xcode
2. Selecciona target "Runner"
3. Signing & Capabilities
4. Verifica que "Push Notifications" esté añadido
5. Limpia el build:
   ```bash
   cd ios
   rm -rf build/
   flutter clean
   flutter build ios --release
   ```

---

## 📊 Logs Importantes

### Logs normales (OK):

```
📱 Token FCM: eN7mF...
✅ Token FCM guardado en usuarios/TUz8GOnQ6OX8ejiov7c5GM9LFPl2
✅ Token FCM guardado en empresas/TUz8GOnQ6OX8ejiov7c5GM9LFPl2/dispositivos/...
```

### Logs de error:

```
❌ Error guardando token en usuarios/...: [firebase_auth/permission-denied]
→ Reglas de Firestore bloquean la escritura

⚠️ No hay usuario autenticado para guardar token FCM
→ El usuario no hizo login antes de inicializar notificaciones

❌ Error obteniendo token FCM: [missing-apns-token]
→ Entitlements no configurados o no estás en dispositivo físico
```

---

## 📱 Diferencias iOS vs Android

| Aspecto | Android | iOS |
|---------|---------|-----|
| **Simulador** | ✅ Funciona | ❌ NO funciona |
| **Certificados** | Solo `google-services.json` | Requiere APNs en Firebase |
| **Permisos** | Se piden en segundo plano | Diálogo explícito |
| **Capabilities** | Automático | Manual en Xcode |
| **Entitlements** | No requiere | Obligatorio `.entitlements` |
| **Background** | Más permisivo | Más restrictivo |

---

## ✅ Checklist Final

Antes de considerar que está funcionando:

- [ ] Certificado APNs subido a Firebase
- [ ] Capability "Push Notifications" añadida en Xcode
- [ ] Background Mode "Remote notifications" activado
- [ ] Entitlements configurados (development + production)
- [ ] App probada en dispositivo físico (NO simulador)
- [ ] Usuario aceptó permisos de notificaciones
- [ ] Token FCM se obtiene y guarda correctamente
- [ ] Notificación local funciona (widget de debug)
- [ ] Notificación remota de prueba desde Firebase llega

---

## 🎯 Próximos Pasos

Una vez que todo funcione:

1. **TestFlight**: Probar en modo TestFlight (producción)
2. **App Store**: Subir a App Store Connect
3. **Monitoreo**: Configurar analytics de notificaciones
4. **Optimización**: Personalizar sonidos y badges

---

## 📚 Referencias

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [APNs Overview](https://developer.apple.com/documentation/usernotifications)
- [FCM iOS Client](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Background Modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)

---

*Documentación iOS - FluixCRM - Abril 2026*

