# 🔥 CONFIGURACIÓN FIREBASE NOTIFICACIONES PUSH

## ✅ Estado de Configuración

### Archivos Firebase ✅
- `android/app/google-services.json` - ✅ Presente
- `ios/Runner/GoogleService-Info.plist` - ✅ Presente
- `lib/firebase_options.dart` - ✅ Configurado

### Dependencias Flutter ✅
```yaml
firebase_messaging: ^15.1.3           # ✅ Versión actual
flutter_local_notifications: ^17.2.3  # ✅ Versión actual
permission_handler: ^11.3.1           # ✅ Para permisos Android 13+
```

### Permisos Android ✅
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Configuración iOS ✅
```xml
<!-- Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Servicios Implementados ✅
- `NotificacionesService` - ✅ Completo con listeners
- `PushNotificationsTester` - ✅ Herramienta de diagnóstico
- `DebugFCMWidget` - ✅ Widget de testing visual

### Funciones Firebase ✅
- `testPushNotification` - ✅ Implementada en functions/src/index.ts
- Triggers automáticos - ✅ Para reservas, tareas, etc.

## 🎯 TODO LISTO PARA PROBAR

**Tu app YA TIENE todas las notificaciones push configuradas.**

### Para Verificar:
1. `flutter run --debug`
2. Login → Dashboard
3. Botón naranja flotante 🐛 
4. "TEST COMPLETO" + "Test WhatsApp Style" + "Probar PUSH"

### Comportamiento Esperado:
- **Foreground**: Banner + sonido + vibración
- **Background**: Push notification → tap → navegar  
- **Terminated**: System notification → tap → open app

## 🚨 Si No Funciona

### 1. Verificar Permisos Usuario
**Android**: Configuración > Apps > PlaneaG > Notificaciones > Activar
**iOS**: Configuración > Notificaciones > PlaneaG > Permitir

### 2. Verificar Token FCM
Usar widget debug para ver si:
- Token se genera ✅
- Token se guarda en Firestore ✅  
- Token coincide entre dispositivo/servidor ✅

### 3. Verificar Firebase Functions
```bash
# Desplegar functions si es necesario
firebase deploy --only functions

# Ver logs
firebase functions:log --only testPushNotification
```

### 4. Verificar Conectividad
- Internet activo
- Firebase reachable
- Firestore rules permiten escritura

## 📱 Testing en Dispositivos

### Android
- **Emulador**: ✅ Funciona con Google Play Services
- **Dispositivo físico**: ✅ Funciona siempre
- **Debug**: ✅ google-services.json debug
- **Release**: ⚠️ Necesita keystore y google-services.json release

### iOS  
- **Simulator**: ❌ NO soporta push notifications
- **Dispositivo físico**: ✅ Funciona con certificado desarrollo
- **Debug**: ✅ Certificado desarrollo
- **Release**: ⚠️ Necesita certificado distribución App Store

## 🔧 Comandos Útiles

```bash
# Ejecutar con debug info
flutter run --debug --verbose

# Limpiar y rebuild
flutter clean && flutter pub get && flutter run

# Ver logs en tiempo real  
flutter logs

# Verificar Firebase CLI
firebase --version
firebase projects:list
```

## ✅ Checklist Final

- [ ] App corre sin errores
- [ ] Usuario logueado correctamente
- [ ] Widget debug aparece (botón naranja 🐛)
- [ ] "TEST COMPLETO" → todos ✅ o ℹ️
- [ ] "Test WhatsApp Style" → notificación aparece inmediatamente
- [ ] "Probar PUSH (Cloud)" → llega notificación desde servidor
- [ ] Al minimizar app → notificaciones push aparecen
- [ ] Al tocar notificación → app abre y navega
- [ ] Sonido y vibración funcionan

## 🎉 ¡SUCCESS!

**Si todos los checkmarks están ✅, tienes notificaciones push funcionando exactamente como WhatsApp.**

---

*Configuración verificada: 21 Abril 2026*
