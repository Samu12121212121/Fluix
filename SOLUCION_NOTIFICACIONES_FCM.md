# 🔔 Solución Problema Notificaciones Push FCM

> **Fecha:** 20 Abril 2026  
> **Estado:** ✅ RESUELTO

---

## 🔍 Diagnóstico del Problema

### Síntomas observados:

1. ✅ Token FCM se guardaba en `empresas/{id}/dispositivos/{uid}` 
2. ❌ Token FCM **NO** se guardaba en `usuarios/{uid}/token_dispositivo`
3. ✅ Cloud Function recibía mensajes y mostraba "Notificación enviada"
4. ❌ El dispositivo NO mostraba la notificación push

### Logs observados:

```
D/FLTFireMsgReceiver(10018): broadcast received for message
D/FLTFireMsgReceiver(10018): broadcast received for message
D/FLTFireMsgReceiver(10018): broadcast received for message
```

**Conclusión:** FCM **SÍ estaba recibiendo** los mensajes, pero el handler no los procesaba.

---

## 🐛 Causa Raíz

### Problema 1: Token no se guardaba en `usuarios/{uid}`

**Archivo:** `lib/services/notificaciones_service.dart` línea 240

```dart
// ❌ ANTES (INCORRECTO):
await _firestore.collection('usuarios').doc(uid).update({
  'token_dispositivo': token,
  ...
});
```

**Por qué fallaba:**
- `.update()` falla si el campo no existe previamente
- Si el documento fue creado sin `token_dispositivo`, nunca se añadía
- Fallaba silenciosamente sin lanzar error visible

### Problema 2: Mensajes solo con `data` no mostraban notificación

Cuando la Cloud Function envía un mensaje con:
```typescript
{
  notification: { title: "...", body: "..." },
  data: { ... }
}
```

Si el plugin FCM no inicializa correctamente los canales, la notificación no se muestra aunque el mensaje llegue.

---

## ✅ Solución Aplicada

### 1. Cambiar `.update()` por `.set()` con `merge: true`

**Archivo:** `lib/services/notificaciones_service.dart`

```dart
// ✅ DESPUÉS (CORRECTO):
await _firestore.collection('usuarios').doc(uid).set({
  'token_dispositivo': token,
  'token_actualizado': FieldValue.serverTimestamp(),
  'plataforma': _obtenerPlataforma(),
}, SetOptions(merge: true));
```

**Beneficios:**
- Funciona aunque el campo no exista
- Crea el campo si es necesario
- No sobrescribe otros campos del documento

### 2. Try-catch separados para cada guardado

```dart
// 1. Guardar en usuarios
try {
  await _firestore.collection('usuarios').doc(uid).set({...}, SetOptions(merge: true));
  print('✅ Token FCM guardado en usuarios/$uid');
} catch (e) {
  print('❌ Error guardando token en usuarios/$uid: $e');
}

// 2. Guardar en dispositivos
try {
  await _firestore.collection('empresas')...set({...}, SetOptions(merge: true));
  print('✅ Token FCM guardado en empresas/$empresaId/dispositivos/$uid');
} catch (e) {
  print('❌ Error guardando token en dispositivos: $e');
}
```

**Beneficios:**
- Si falla uno, el otro sigue intentándose
- Logs específicos para debugging
- Trazabilidad completa

### 3. Widget de Debug FCM (solo en modo DEBUG)

**Archivo:** `lib/services/debug_fcm_widget.dart`

Widget flotante que permite:
- ✅ Ver token actual del dispositivo
- ✅ Ver token guardado en Firestore
- ✅ Comparar si coinciden
- ✅ Renovar el token manualmente
- ✅ Copiar token al portapapeles
- ✅ Probar notificación local

**Cómo usarlo:**
1. Ejecuta la app en modo DEBUG
2. En el dashboard, aparece un botón naranja flotante con icono 🐛
3. Pulsa para abrir/cerrar el panel de debug
4. Usa "Renovar" si los tokens no coinciden
5. Usa "Probar notificación local" para verificar que funcionan

---

## 📋 Verificación Post-Fix

### Logs esperados después de login:

```
I/flutter: 📱 Guardando token FCM tras login para UID: [uid]
I/flutter: ✅ Token FCM guardado en usuarios/[uid]
I/flutter: ✅ Token FCM guardado en empresas/[empresaId]/dispositivos/[uid]
```

### En Firebase Console:

**usuarios/{uid}:**
```json
{
  "token_dispositivo": "cqklNNz5TT...",
  "token_actualizado": Timestamp,
  "plataforma": "android"
}
```

**empresas/{empresaId}/dispositivos/{uid}:**
```json
{
  "token": "cqklNNz5TT...",
  "uid_usuario": "...",
  "plataforma": "android",
  "ultima_actualizacion": Timestamp,
  "activo": true
}
```

---

## 🍎 Configuración Específica para iOS

### Problema: Notificaciones funcionan en Android pero NO en iOS

**Síntoma:**
- ✅ Notificaciones locales funcionan
- ✅ Token FCM se obtiene y guarda
- ❌ Notificaciones remotas (push) NO llegan

### Requisitos iOS (más estrictos que Android)

#### 1. ⚠️ Dispositivo físico OBLIGATORIO

**Las notificaciones push NO FUNCIONAN en simulador iOS.**

- ❌ Simulador → No recibe notificaciones push
- ✅ iPhone/iPad físico → Sí recibe notificaciones

#### 2. Entitlements configurados

**Archivos modificados:**

`ios/Runner/Runner.entitlements`:
```xml
<dict>
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>development</string>
</dict>
```

`ios/Runner/RunnerRelease.entitlements`:
```xml
<dict>
    <!-- Push Notifications PRODUCCIÓN -->
    <key>aps-environment</key>
    <string>production</string>
</dict>
```

#### 3. Certificados APNs en Firebase

**CRÍTICO:** Sin certificados APNs, Firebase NO puede enviar notificaciones a iOS.

**Pasos:**

1. **Apple Developer Portal** ([developer.apple.com](https://developer.apple.com))
   - Certificates, Identifiers & Profiles
   - Keys → Create a new key
   - Selecciona "Apple Push Notifications service (APNs)"
   - Descarga el archivo `.p8`
   - Anota el **Key ID** y **Team ID**

2. **Firebase Console**
   - Project Settings → Cloud Messaging
   - Pestaña **Apple app configuration**
   - Upload APNs Authentication Key
   - Sube el archivo `.p8`
   - Introduce **Key ID** y **Team ID**

#### 4. Capability en Xcode

**Manualmente en Xcode:**

1. Abre `ios/Runner.xcworkspace` (NO .xcodeproj)
2. Selecciona target `Runner`
3. Pestaña **Signing & Capabilities**
4. Botón **+ Capability**
5. Añade **"Push Notifications"**
6. Añade **"Background Modes"**
   - Marca: "Remote notifications"

#### 5. Info.plist ya configurado ✅

El archivo `ios/Runner/Info.plist` ya tiene:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Verificación iOS

#### Logs esperados al abrir la app:

```
I/flutter: 📱 Token FCM: [token_largo_ios]
I/flutter: ✅ Token FCM guardado en usuarios/[uid]
I/flutter: ✅ Token FCM guardado en empresas/[id]/dispositivos/[uid]
```

#### Probar notificación desde Firebase Console:

1. Firebase Console → Cloud Messaging → Nueva campaña
2. Título: "Prueba iOS"
3. Texto: "Probando notificación push"
4. En **Target** → pega el token FCM del dispositivo
5. Enviar mensaje de prueba
6. **Debe llegar en 1-2 segundos si todo está correcto**

### Troubleshooting iOS

| Problema | Solución |
|----------|----------|
| Token se obtiene pero notificaciones no llegan | Certificados APNs no configurados en Firebase |
| Error "APNs delivery failed" en logs | Certificado APNs incorrecto o expirado |
| Notificaciones llegan tarde | iOS las agrupa en modo bajo consumo |
| Solo funciona en debug, no en release | Revisar que `RunnerRelease.entitlements` tiene `production` |
| No pide permiso de notificaciones | Desinstalar app, reinstalar, primera vez debe pedir permiso |

### Permisos iOS (se piden automáticamente)

El código en `NotificacionesService` ya solicita permisos:

```dart
await _messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

La primera vez que se abre la app, iOS muestra un diálogo:
```
"Fluix CRM" desea enviarte notificaciones
[No permitir] [Permitir]
```

**Si el usuario dijo "No permitir":**
1. Ajustes → Fluix CRM → Notificaciones → ACTIVAR

---

## 🚨 Si las notificaciones AÚN no llegan

### Checklist de verificación:

#### 1. Permisos de Android

```bash
# Verificar en el dispositivo:
Ajustes → Aplicaciones → Fluix CRM → Notificaciones → ACTIVADO ✅
```

En **Android 13+** el permiso se debe aceptar explícitamente la primera vez.

#### 2. Token válido

Usa el widget de debug para:
- Verificar que el token en el dispositivo coincide con Firestore
- Si no coinciden, pulsa "Renovar"
- Espera a que se actualice y prueba de nuevo

#### 3. Canal de notificaciones

El canal `fluixcrm_canal_principal` debe existir en el dispositivo. Si no:
```dart
// Desinstalar la app y reinstalar
// O manualmente desde:
Ajustes → Aplicaciones → Fluix CRM → Notificaciones → Canales
```

#### 4. Cloud Function envía correctamente

Ver logs en Firebase Console → Functions:
```typescript
console.log(`✅ Notificación enviada: ${result.successCount}/${tokens.length}`);
```

Si `successCount` es 0, el token es inválido.

#### 5. Formato del mensaje

La Cloud Function debe enviar:
```typescript
{
  notification: {
    title: "...",
    body: "..."
  },
  data: {
    tipo: "...",
    ...
  },
  android: {
    priority: "high",
    notification: {
      channelId: "fluixcrm_canal_principal"
    }
  }
}
```

---

## 🔬 Testing con el widget de debug

### Paso 1: Verificar token

1. Abre la app en modo DEBUG
2. Pulsa el botón naranja 🐛
3. Verifica que ambos tokens coinciden
4. Si no coinciden, pulsa "Renovar"

### Paso 2: Probar notificación local

1. Pulsa "Probar notificación local"
2. Debe aparecer una notificación inmediatamente
3. Si aparece → El plugin funciona ✅
4. Si NO aparece → Problema de permisos/canal ❌

### Paso 3: Probar notificación remota

1. Desde Firebase Console → Cloud Messaging → Nueva campaña
2. Pega el token copiado del widget
3. Envía mensaje de prueba
4. Debe llegar en ~1-2 segundos

---

## 📊 Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/services/notificaciones_service.dart` | Cambio `.update()` → `.set()` con merge, logs mejorados |
| `lib/services/debug_fcm_widget.dart` | **NUEVO** - Widget de debug para verificar tokens |
| `lib/features/dashboard/pantallas/pantalla_dashboard.dart` | Añadido widget de debug en modo DEBUG |
| `GUIA_COMPLETA_BOT_WHATSAPP.md` | **NUEVO** - Guía completa del bot de WhatsApp |
| `lib/features/dashboard/widgets/modulo_reservas.dart` | Corregidos warnings de deprecación (initialValue) |

---

## 💡 Lecciones aprendidas

1. **Usar `.set()` con `merge: true`** en lugar de `.update()` cuando el campo puede no existir
2. **Logs específicos** ayudan enormemente en debugging
3. **Try-catch separados** evitan que un error bloquee otros procesos
4. **Widget de debug** es invaluable para verificar estado en producción
5. **FCM puede recibir mensajes pero no mostrarlos** si faltan permisos/canales

---

## 📚 Referencias

- [Firebase Cloud Messaging - Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- [Android 13 Runtime Permissions](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [FCM Troubleshooting Guide](https://firebase.google.com/docs/cloud-messaging/concept-options#notifications_and_data_messages)

---

*Documentación generada: 20 Abril 2026 - FluixCRM v1.0*


