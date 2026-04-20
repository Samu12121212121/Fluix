# 📋 Resumen de Cambios - Push Notifications iOS

## ✅ Cambios Aplicados (LISTOS)

### 1. Entitlements Actualizados

**Archivo: `ios/Runner/Runner.entitlements`**
- ✅ Añadido `aps-environment: development`
- ✅ Mantiene `com.apple.developer.applesignin`

**Archivo: `ios/Runner/RunnerRelease.entitlements`**
- ✅ Añadido `aps-environment: production`
- ✅ Listo para App Store

### 2. Documentación Creada

**Nuevos archivos:**
- `CONFIGURACION_IOS_PUSH.md` - Guía completa iOS
- `SOLUCION_NOTIFICACIONES_FCM.md` - Ya incluye sección iOS
- `check_ios_push.sh` - Script de verificación

---

## ⚙️ Pasos MANUALES Requeridos (PENDIENTES)

### 🔴 OBLIGATORIO 1: Configurar Xcode

**No se puede hacer desde Flutter CLI, debes usar Xcode:**

1. Abre el proyecto:
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. En Xcode:
   - Selecciona target **"Runner"**
   - Pestaña **"Signing & Capabilities"**
   - Pulsa **"+ Capability"**
   - Añade: **"Push Notifications"**
   - Verifica: **"Background Modes"** con "Remote notifications" marcado

### 🔴 OBLIGATORIO 2: Configurar APNs en Firebase

**Sin esto, las notificaciones NO llegarán:**

1. **Apple Developer Portal:**
   - Ve a: [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys)
   - Crea nueva key → Marca "Apple Push Notifications service"
   - Descarga el archivo `.p8`
   - Anota **Key ID** y **Team ID**

2. **Firebase Console:**
   - Ve a: [console.firebase.google.com/project/planeaapp-4bea4/settings/cloudmessaging](https://console.firebase.google.com/project/planeaapp-4bea4/settings/cloudmessaging)
   - Sección: **Apple app configuration**
   - Upload APNs Authentication Key
   - Sube el `.p8`, introduce Key ID y Team ID

---

## 🧪 Cómo Probar

### Paso 1: Build en dispositivo físico

⚠️ **IMPORTANTE:** NO funciona en simulador iOS.

```bash
# Conecta tu iPhone/iPad por USB
flutter run --release
```

### Paso 2: Verificar logs

Busca en la consola:
```
📱 Token FCM: [token_largo]
✅ Token FCM guardado en usuarios/...
✅ Token FCM guardado en empresas/.../dispositivos/...
```

### Paso 3: Usar widget de debug

1. En la app, pulsa el botón naranja 🐛
2. Verifica que el token coincide con Firestore
3. Copia el token

### Paso 4: Enviar notificación de prueba

1. Firebase Console → Cloud Messaging → "Send test message"
2. Pega el token copiado
3. Envía
4. Debe llegar en 1-2 segundos ✅

---

## 🐛 Si NO Llega la Notificación

### Checklist:

- [ ] ¿Estás en dispositivo físico? (NO simulador)
- [ ] ¿Añadiste "Push Notifications" capability en Xcode?
- [ ] ¿Subiste el certificado APNs a Firebase?
- [ ] ¿La app pidió permiso de notificaciones?
- [ ] ¿Aceptaste el permiso?
- [ ] ¿El token FCM se obtuvo correctamente?
- [ ] ¿Probaste con notificación local primero? (widget debug)

### Errores Comunes:

| Error | Causa | Solución |
|-------|-------|----------|
| Token se obtiene pero no llega | APNs no configurado | Subir `.p8` a Firebase |
| "APNs delivery failed" | Certificado incorrecto | Verificar Key ID y Team ID |
| No pide permiso | App ya instalada | Desinstalar y reinstalar |
| Solo funciona debug | Entitlements mal | Verificar `production` en Release |

---

## 📊 Archivos Modificados

| Archivo | Estado | Acción |
|---------|--------|--------|
| `ios/Runner/Runner.entitlements` | ✅ Modificado | Push Notifications añadido |
| `ios/Runner/RunnerRelease.entitlements` | ✅ Modificado | Push Notifications producción |
| `CONFIGURACION_IOS_PUSH.md` | ✅ Creado | Guía completa iOS |
| `SOLUCION_NOTIFICACIONES_FCM.md` | ✅ Actualizado | Sección iOS añadida |
| `check_ios_push.sh` | ✅ Creado | Script verificación |

---

## 🎯 Siguiente Paso CRÍTICO

**1. Abre Xcode y añade la capability:**

```bash
cd ios
open Runner.xcworkspace
```

Luego:
- Runner → Signing & Capabilities → + Capability → Push Notifications

**2. Configura APNs en Firebase:**

Ve a Firebase Console y sube el certificado `.p8`.

**Sin estos dos pasos, las notificaciones NO funcionarán.**

---

## 📚 Documentación de Referencia

- `CONFIGURACION_IOS_PUSH.md` - Guía paso a paso completa
- `SOLUCION_NOTIFICACIONES_FCM.md` - Troubleshooting general
- Script de verificación: `./check_ios_push.sh`

---

*Generado: 20 Abril 2026*

