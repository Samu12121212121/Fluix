# ⚡ TESTING RÁPIDO: Fix Crash Windows

## 🎯 ¿Qué se arregló?

**Problema:** App cierra silenciosamente cuando expira token de Firebase Auth  
**Causa:** Error `permission-denied` de Firestore no capturado mata proceso en Windows  
**Solución:** 3 fixes aplicados que capturan el error sin cerrar la app

---

## ✅ CAMBIOS APLICADOS

### 1. `main.dart` - Handler de errores reforzado
- ✅ Captura `permission-denied` sin cerrar app
- ✅ Captura `firebase_auth` errors sin cerrar app
- ✅ Captura `non-platform thread` errors sin cerrar app
- ✅ Callback `_onSesionExpirada` con delay de 300ms

### 2. `sesion_service.dart` - Delay antes de signOut
- ✅ Delay de 500ms antes de `FirebaseAuth.signOut()`
- ✅ Notifica cierre ANTES de hacer signOut
- ✅ No hace signOut directo en error de token

### 3. `firestore_stream_helpers.dart` - Helper nuevo
- ✅ Extensión `.handleFirestoreErrors()` para streams
- ✅ Widget `SafeStreamBuilder` con UI de error
- ✅ Captura automática de todos los errores Firestore

---

## 🚀 COMANDOS DE TESTING

### Test Básico (1 minuto)

```powershell
# 1. Limpiar y recompilar
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
flutter clean
flutter pub get

# 2. Ejecutar con logging
flutter run -d windows --verbose

# 3. Reproducir el crash:
#    - Abrir TPV → Caja Rápida
#    - Añadir productos
#    - Cobrar
#    - ¿Se cierra la app? NO ✅ | SÍ ❌
```

### Test Completo (5 minutos)

```powershell
# 1. Ejecutar guardando logs
flutter run -d windows --verbose > C:\Users\Samu\test_crash.txt 2>&1

# 2. Reproducir escenario completo:
#    a) Abrir app
#    b) Ir a TPV
#    c) Añadir productos al ticket
#    d) Esperar 2-3 minutos
#    e) Cobrar
#
# 3. ¿Qué debe pasar?
#    ✅ Si todo OK: Cobro completo sin crash
#    ✅ Si sesión expira: Error amigable, NO crash
#    ❌ Si crashea: Ver logs en test_crash.txt

# 4. Ver logs del crash handler
notepad C:\Users\Samu\Documents\fluixcrm_crash.log

# Buscar estas líneas (SI aparecen = fix funcionando):
# ⚠️ FIRESTORE PERMISSION DENIED - Manejado sin cerrar app
# ⚠️ FIREBASE AUTH ERROR - Manejado sin cerrar app
# 🔴 MAIN: Sesión expirada - iniciando limpieza...
```

---

## 📊 RESULTADOS ESPERADOS

### ✅ ÉXITO (App NO cierra)

**En consola verás:**
```
⚠️ FIRESTORE PERMISSION DENIED - Manejado sin cerrar app
→ Causa probable: sesión cerrada con listeners activos
🔴 MAIN: Sesión expirada - iniciando limpieza...
⏳ SesionService: esperando 500ms para cancelación de listeners...
🔓 SesionService: sesión cerrada correctamente
🔓 MAIN: Navegando a login tras limpieza
```

**En pantalla verás:**
- Error amigable "Sesión expirada" o similar
- Navegación suave al login
- **NO cierre abrupto de la app**

### ❌ FALLO (App sigue crasheando)

**En consola verás:**
```
[ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: ...
Lost connection to device.
```

**Acción:**
```powershell
# Compartir estos archivos:
notepad C:\Users\Samu\test_crash.txt
notepad C:\Users\Samu\Documents\fluixcrm_crash.log
```

---

## 🔍 CHECKLIST DE VERIFICACIÓN

Después del test, verifica:

- [ ] La app **NO se cierra** cuando expira la sesión
- [ ] Aparecen logs con "⚠️ FIRESTORE PERMISSION DENIED"
- [ ] Aparecen logs con "🔴 MAIN: Sesión expirada"
- [ ] La app navega al login suavemente
- [ ] El archivo `fluixcrm_crash.log` contiene los logs del error
- [ ] El cobro en TPV funciona correctamente si la sesión está activa

---

## 🎯 SI TODO FUNCIONA

**¡El fix está funcionando! 🎉**

Ahora puedes:
1. Continuar usando la app con normalidad
2. El crash de Windows está solucionado
3. Los errores de Firestore se manejan gracefully

---

## 🆘 SI SIGUE CRASHEANDO

**Paso 1:** Ejecuta esto y comparte el output:

```powershell
# Capturar crash completo
flutter run -d windows --verbose > C:\Users\Samu\crash_detallado.txt 2>&1

# Comparte estos 2 archivos:
# 1. C:\Users\Samu\crash_detallado.txt
# 2. C:\Users\Samu\Documents\fluixcrm_crash.log
```

**Paso 2:** Describe exactamente:
- ¿En qué pantalla estabas?
- ¿Qué acción hiciste justo antes del crash?
- ¿Cuánto tiempo llevaba la app abierta?

---

## 📝 NOTAS ADICIONALES

### ¿Cómo funciona el fix?

```
Token expira → SesionService detecta error → NO hace signOut inmediato
    ↓
Notifica a _onSesionExpirada → Delay 300ms
    ↓
SesionService delay 500ms → Widgets cancelen listeners
    ↓
SignOut en FirebaseAuth → Listeners ya cancelados
    ↓
Navegación al login → ✅ Sin crash
```

### ¿Qué captura el error handler?

- `permission-denied` → Sesión cerrada con listeners activos
- `firebase_auth/unknown-error` → Error refrescando token
- `non-platform thread` → Callbacks desde thread incorrecto
- Todos retornan `true` → **NO cierran la app**

---

**Ejecuta el test y comparte los resultados. Los fixes están aplicados y deberían solucionar el crash. 🚀**

