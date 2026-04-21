# 📱 Guía Completa: Notificaciones Push Estilo WhatsApp

## 🎯 Objetivo

Verificar que todas las notificaciones push funcionen correctamente en la app PlaneaG Flutter, con el mismo comportamiento que WhatsApp: aparecen inmediatamente, suenan, vibran y navegan correctamente.

## 📋 Checklist del Flujo Completo

### 1. ✅ Registro del Dispositivo (Client-side)

#### iOS
- [x] Permiso solicitado mediante `firebase_messaging`
- [x] Apple Push Notification Service (APNs) devuelve device token
- [x] Configurado en `Info.plist`: `UIBackgroundModes` → `remote-notification`

#### Android
- [x] Firebase Cloud Messaging (FCM) genera registration token
- [x] Permisos configurados en `AndroidManifest.xml`:
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.RECEIVE_BOOT_COMPLETED`
  - `android.permission.VIBRATE`

### 2. ✅ Envío del Token al Backend

```dart
// En NotificacionesService._actualizarTokenEnFirestore()
await _firestore.collection('usuarios').doc(uid).set({
  'token_dispositivo': token,
  'token_actualizado': FieldValue.serverTimestamp(),
  'plataforma': _obtenerPlataforma(),
}, SetOptions(merge: true));

// También en empresa/dispositivos
await _firestore
    .collection('empresas')
    .doc(empresaId)
    .collection('dispositivos')
    .doc(uid)
    .set({
  'token': token,
  'uid_usuario': uid,
  'plataforma': _obtenerPlataforma(),
  'ultima_actualizacion': FieldValue.serverTimestamp(),
  'activo': true,
});
```

**Asociación:**
- `usuario_id` → `token(s)`
- `plataforma` (iOS/Android)
- `empresa_id` para targeting

### 3. ✅ Backend: Gestión de Notificaciones

**Funciones Firebase implementadas:**
- `testPushNotification` - Prueba de notificación
- Triggers automáticos para nuevas reservas, pedidos, etc.

**Payload estructura:**
```json
{
  "notification": {
    "title": "Nuevo mensaje",
    "body": "Tienes un mensaje nuevo"
  },
  "data": {
    "tipo": "nueva_reserva",
    "empresa_id": "123",
    "timestamp": "1234567890"
  }
}
```

### 4. ✅ Envío a Servicios Push

#### iOS → APNs
```typescript
apns: {
  payload: {
    aps: {
      sound: "default",
      badge: 1,
    },
  },
}
```

#### Android → FCM
```typescript
android: {
  priority: "high",
  notification: {
    channelId: "fluixcrm_canal_principal",
    sound: "default",
  },
}
```

### 5. ✅ Entrega al Dispositivo

**Estados de la app:**
- **Foreground** → `FirebaseMessaging.onMessage.listen()`
- **Background** → `FirebaseMessaging.onMessageOpenedApp.listen()`
- **Terminated** → `FirebaseMessaging.instance.getInitialMessage()`

### 6. ✅ Manejo en la App

```dart
// Inicialización en dashboard
NotificacionesService().inicializar();

// Listeners configurados
FirebaseMessaging.onMessage.listen(_manejarMensajePrimerPlano);
FirebaseMessaging.onMessageOpenedApp.listen(_manejarTapNotificacion);
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 7. ✅ Tipos de Notificaciones

#### a) Display Notifications
- Se muestran automáticamente
- Configuradas con `NotificationDetails`
- Canales específicos para Android

#### b) Data-only Notifications
- Procesadas manualmente
- Útiles para silent push o datos

### 8. ✅ Configuración Crítica

#### iOS (`Info.plist`)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

#### Android (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="fluixcrm_canal_principal"/>
```

## 🧪 Herramientas de Testing

### 1. Widget de Debug FCM
- **Ubicación:** Botón flotante naranja en dashboard
- **Funciones:**
  - Ver token FCM actual
  - Renovar token
  - Probar notificación local
  - Probar push desde servidor
  - **NUEVO:** Test completo del flujo
  - **NUEVO:** Test estilo WhatsApp

### 2. PushNotificationsTester
Clase que verifica automáticamente:
- Autenticación de usuario ✅
- Permisos de notificación ✅
- Token FCM generado ✅
- Almacenamiento en Firestore ✅
- Canales de notificación (Android) ✅
- Configuración de background modes ✅
- Listeners activos ✅

## 🔧 Cómo Probar las Notificaciones

### Paso 1: Ejecutar el Script
```bash
./probar_notificaciones.bat
```

### Paso 2: Usar el Widget de Debug
1. Abrir la app
2. Loguearse
3. Ir al dashboard
4. Tocar botón naranja flotante (🐛)
5. Usar botones en este orden:
   - **"🧪 TEST COMPLETO"** → Diagnóstico completo
   - **"💬 Test WhatsApp Style"** → Notificación local estilo WhatsApp
   - **"🔥 Probar PUSH (Cloud)"** → Notificación desde servidor

### Paso 3: Verificar Comportamiento

#### ✅ App en Primer Plano (Foreground)
- **¿Aparece banner heads-up?** ✅
- **¿Suena la notificación?** ✅
- **¿Vibra el dispositivo?** ✅
- **¿Se ve en centro de notificaciones?** ✅

#### ✅ App en Background
- **¿Aparece notificación push?** ✅
- **¿Al tocar abre la app?** ✅
- **¿Navega a la sección correcta?** ✅

#### ✅ App Terminada (Killed)
- **¿Sistema muestra notificación?** ✅
- **¿Al tocar abre la app desde cero?** ✅
- **¿Procesa getInitialMessage?** ✅

## 🚨 Problemas Típicos y Soluciones

### ❌ Notificaciones NO aparecen

#### Solución 1: Verificar Permisos
```bash
# Android: Configuración > Apps > PlaneaG > Notificaciones > Activar todo
# iOS: Configuración > Notificaciones > PlaneaG > Permitir notificaciones
```

#### Solución 2: Token FCM
```dart
// Verificar en Debug Widget que el token:
// 1. Se genera correctamente
// 2. Se guarda en Firestore
// 3. Coincide entre dispositivo y servidor
```

#### Solución 3: Firebase Functions
```bash
# Verificar que las functions estén desplegadas
firebase deploy --only functions

# Ver logs de las functions
firebase functions:log --only testPushNotification
```

### ❌ Notificaciones aparecen pero NO suenan

#### Solución: Canales Android
```dart
// Verificar que el canal tenga:
playSound: true,
importance: Importance.max,
sound: RawResourceAndroidNotificationSound('notification'),
```

#### Solución: iOS
```dart
// Verificar DarwinNotificationDetails:
presentSound: true,
interruptionLevel: InterruptionLevel.active,
```

### ❌ App NO navega al tocar notificación

#### Solución: Listeners
```dart
// Verificar que estén configurados todos:
FirebaseMessaging.onMessageOpenedApp.listen(_manejarTapNotificacion);

// Y el payload tenga datos de navegación:
{
  'tipo': 'nueva_reserva',
  'reserva_id': '123',
  'empresa_id': '456'
}
```

## 📊 Métricas de Éxito

Una implementación exitosa debe cumplir:

1. **Token FCM** se genera en <2 segundos
2. **Notificación local** aparece inmediatamente
3. **Notificación push** aparece en <5 segundos
4. **Navegación** funciona en todos los estados de app
5. **Sonido/Vibración** funcionan como WhatsApp
6. **Permisos** solicitados correctamente
7. **Almacenamiento** en Firestore exitoso

## 🔄 Flujo de Debugging

```
1. Usuario reporta problema
       ↓
2. Ejecutar script probar_notificaciones.bat
       ↓
3. Usar Widget Debug FCM → "TEST COMPLETO"
       ↓
4. Identificar paso que falla
       ↓
5. Aplicar solución específica
       ↓
6. Repetir hasta que todos sean ✅
```

## 📞 Contacto

Si después de seguir esta guía las notificaciones no funcionan como WhatsApp, revisar:

1. **Configuración Firebase:** Proyecto correcto, claves actualizadas
2. **Permisos del sistema:** Usuario debe aceptar notificaciones
3. **Estado de red:** Conectividad a Firebase
4. **Logs del dispositivo:** `flutter logs` para ver errores

---

**🎉 ¡Una vez que todo funcione, tendrás notificaciones push exactamente como WhatsApp!**
