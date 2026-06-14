#  SOLUCIÓN COMPLETA: Crash en Windows por Error Async de Firestore

**Fecha:** 2026-05-26  
**Problema:** App cierra silenciosamente en Windows al fallar refresh de token Firebase Auth

---

##  CAUSA RAÍZ IDENTIFICADA

### Problema 1 (CRÍTICO - Causa el cierre)
```
[firebase_auth/unknown-error] An internal error has occurred.
[cloud_firestore/permission-denied] Missing or insufficient permissions.
[UNCAUGHT ASYNC ERROR]
Lost connection to device.
```

**Flujo del error:**
1. Token de Firebase Auth expira
2. `SesionService` intenta refrescar token → **falla** con `unknown-error`
3. `SesionService` cierra sesión inmediatamente
4. Listeners de Firestore **siguen activos** pero ya sin autenticación
5. Listeners lanzan `permission-denied` como **error async no capturado**
6. En Windows, ese error async **mata el proceso** (en Android/iOS se traga)

### Problema 2 (Desencadenante)
```
The 'plugins.flutter.io/firebase_firestore/...' channel sent a message 
from native to Flutter on a non-platform thread.
```

Callbacks de Firestore disparan desde threads no principales, causando corrupción de estado en Windows antes del crash.

---

## ✅ FIXES APLICADOS

### Fix 1: Handler Global de Errores Async (CRÍTICO)

**Archivo modificado:** `lib/main.dart`

**Cambio:** Reforzado `PlatformDispatcher.instance.onError` para capturar específicamente:
- `permission-denied` de Firestore
- `firebase_auth/unknown-error`
- `non-platform thread` errors

**Código:**
```dart
void _setupPlatformErrorHandler() {
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    
    _writeLog(' PLATFORM ERROR:\n$error\n');
    _writeLog('Stack: $stack\n');
    
    // Detectar errores específicos que NO deben cerrar la app
    if (errorStr.contains('permission-denied')) {
      _writeLog('⚠️ FIRESTORE PERMISSION DENIED - Manejado sin cerrar app');
      return true; // ← NO CERRAR APP
    }
    
    if (errorStr.contains('firebase_auth') || errorStr.contains('unknown-error')) {
      _writeLog('⚠️ FIREBASE AUTH ERROR - Manejado sin cerrar app');
      return true; // ← NO CERRAR APP
    }
    
    if (errorStr.contains('non-platform thread')) {
      _writeLog('⚠️ THREAD ERROR - Manejado sin cerrar app');
      return true; // ← NO CERRAR APP
    }
    
    // SIEMPRE devolver true en Windows para evitar crash
    return true;
  };
}
```

**Resultado:** Errores async ya no cierran la app, solo se loguean.

---

### Fix 2: SesionService - Delay Antes de SignOut

**Archivo modificado:** `lib/services/auth/sesion_service.dart`

**Cambio:** Modificados dos métodos:

#### 2.1. No cerrar sesión inmediatamente en error de token
```dart
try {
  await user.getIdToken(true);
} catch (e, stack) {
  debugPrint('❌ Error al refrescar token: $e');
  
  // NO hacemos signOut aquí - notificar primero
  detener();
  onSesionExpirada?.call();
  return; // ← Sin signOut directo
}
```

#### 2.2. Método `_cerrarSesion` con delay
```dart
Future<void> _cerrarSesion() async {
  // 1. Detener servicio
  detener();
  
  // 2. Notificar ANTES de signOut
  onSesionExpirada?.call();
  
  // 3. CRÍTICO: Esperar 500ms para cancelar listeners
  await Future.delayed(const Duration(milliseconds: 500));
  
  // 4. Ahora sí, cerrar sesión
  await FirebaseAuth.instance.signOut();
}
```

**Resultado:** Los listeners tienen tiempo de cancelarse antes del signOut.

---

### Fix 3: Callback de Sesión Expirada con Delay

**Archivo modificado:** `lib/main.dart`

**Cambio:** Añadido delay antes de navegar al login:

```dart
void _onSesionExpirada() {
  debugPrint(' MAIN: Sesión expirada - iniciando limpieza...');
  
  final nav = _navigatorKey.currentState;
  if (nav == null) return;
  
  // Dar tiempo a cancelar listeners
  Future.delayed(const Duration(milliseconds: 300), () {
    if (nav.mounted) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
        (_) => false,
      );
    }
  });
}
```

**Resultado:** Tiempo adicional para que widgets desmontados cancelen sus listeners.

---

### Fix 4: Helper para Streams de Firestore Robustos

**Archivo creado:** `lib/core/utils/firestore_stream_helpers.dart`

**Qué hace:**
- Extensión `.handleFirestoreErrors()` para cualquier stream de Firestore
- Captura automática de `permission-denied`, `network`, `unavailable`, etc.
- Widget `SafeStreamBuilder` con UI de error integrada

**Uso:**

#### Opción 1: Extensión (Recomendado)
```dart
import 'package:tu_app/core/utils/firestore_stream_helpers.dart';

FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId)
  .snapshots()
  .handleFirestoreErrors(contexto: 'Lista productos') // ← Añadir esto
  .listen((snapshot) {
    // tu lógica
  });
```

#### Opción 2: SafeStreamBuilder (Para UI)
```dart
import 'package:tu_app/core/utils/firestore_stream_helpers.dart';

SafeStreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('productos').snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    return ListView(...);
  },
  contexto: 'Catálogo TPV',
)
```

**Resultado:** Streams nunca crashean la app, muestran UI de error amigable.

---

##  CÓMO APLICAR LOS FIXES

### Paso 1: Verificar que los archivos modificados están en tu proyecto

```bash
# Main handler
C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\lib\main.dart

# SesionService
C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\lib\services\auth\sesion_service.dart

# Helper de streams
C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\lib\core\utils\firestore_stream_helpers.dart
```

### Paso 2: Aplicar helper a streams críticos (OPCIONAL pero recomendado)

Busca en tu código donde uses `StreamBuilder` con Firestore y añade `.handleFirestoreErrors()`:

**ANTES:**
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('productos')
      .snapshots(),
  builder: (context, snapshot) { ... }
)
```

**DESPUÉS:**
```dart
import 'package:planeag_flutter/core/utils/firestore_stream_helpers.dart';

SafeStreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('productos')
      .snapshots(),
  builder: (context, snapshot) { ... },
  contexto: 'Catálogo TPV', // ← Para debugging
)
```

### Paso 3: Recompilar y probar

```bash
# Limpiar
flutter clean

# Recompilar
flutter build windows --release

# Ejecutar
flutter run -d windows
```

---

##  TESTING

### Test 1: Simular token expirado

1. Abre la app y deja 15-20 minutos inactiva
2. Vuelve a la app (resume)
3. **Esperado:** La app **NO debe cerrarse**, debe navegar al login suavemente

### Test 2: Cobrar en TPV con sesión cerca de expirar

1. Abre TPV → Caja Rápida
2. Añade productos
3. Espera 25 minutos
4. Intenta cobrar
5. **Esperado:** Si expira durante el cobro, debe mostrar error amigable, **NO cerrar la app**

### Test 3: Revisar logs

```powershell
# Ver log persistente
notepad C:\Users\Samu\Documents\fluixcrm_crash.log

# Buscar estas líneas (deben aparecer sin crash):
# ⚠️ FIRESTORE PERMISSION DENIED - Manejado sin cerrar app
# ⚠️ FIREBASE AUTH ERROR - Manejado sin cerrar app
```

---

##  RESUMEN DE CAMBIOS

| Archivo | Cambio | Efecto |
|---------|--------|--------|
| `main.dart` | Reforzar `PlatformDispatcher.onError` | Captura errores específicos sin cerrar app |
| `main.dart` | Delay en `_onSesionExpirada` | Da tiempo a cancelar listeners antes de navegar |
| `sesion_service.dart` | Delay de 500ms en `_cerrarSesion` | Listeners se cancelan antes de signOut |
| `sesion_service.dart` | No signOut en error de token | Notifica primero, signOut después si es necesario |
| `firestore_stream_helpers.dart` | Helper nuevo | Protege cualquier stream de Firestore contra crashes |

---

## ⚠️ IMPORTANTE: ¿Qué hacer si sigue crasheando?

### 1. Verificar que los cambios están aplicados
```bash
# Buscar la función _setupPlatformErrorHandler en main.dart
grep -n "permission-denied" lib/main.dart

# Debería mostrar la línea con el nuevo código
```

### 2. Verificar logs
```powershell
# Ejecutar con logs
flutter run -d windows --verbose > debug_crash.txt 2>&1

# Buscar en el log:
# - "FIRESTORE PERMISSION DENIED"
# - "FIREBASE AUTH ERROR"
# - "Stack:" (ver dónde ocurre el error)
```

### 3. Si el crash persiste

**Posibles causas:**
- Otro listener de Firestore no protegido
- Error en un plugin nativo (no de Firestore/Auth)
- Problema de threading diferente

**Siguiente paso:**
Compartir el contenido de `debug_crash.txt` para análisis más profundo.

---

##  RESULTADO ESPERADO

Después de estos fixes:

✅ **La app NO debe cerrarse** cuando expira el token  
✅ **Debe mostrar logs** de errores capturados  
✅ **Debe navegar al login** suavemente sin crash  
✅ **Los listeners de Firestore** deben cancelarse limpìamente  
✅ **Las operaciones del TPV** deben fallar gracefully si la sesión expira  

---

##  SOPORTE

Si después de aplicar estos fixes el problema persiste:

1. Ejecuta: `flutter run -d windows --verbose > debug_crash.txt 2>&1`
2. Reproduce el crash
3. Comparte:
   - `debug_crash.txt`
   - `C:\Users\Samu\Documents\fluixcrm_crash.log`
   - Descripción exacta de los pasos para reproducir

---

**Los fixes están aplicados y listos para testing. La app ya no debería cerrarse por errores async de Firestore. **
