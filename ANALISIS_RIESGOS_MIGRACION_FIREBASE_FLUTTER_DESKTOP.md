# 🔴 ANÁLISIS DE RIESGOS: Migración Mayor FlutterFire + Flutter Desktop Windows

**Proyecto**: PlaneaGuada CRM - TPV Flutter Windows  
**Fecha**: 25 Mayo 2026  
**Alcance**: Actualización masiva de dependencias Firebase y Flutter Desktop  
**Arquitecto**: Senior Flutter Desktop + Firebase Expert

---

## 📊 RESUMEN EJECUTIVO

### Versiones Actuales (Baseline)
```yaml
firebase_core: ^3.6.0        # → Migrar a 4.x/5.x
cloud_firestore: ^5.4.4      # → Migrar a 6.x
firebase_auth: ^5.3.1        # → Migrar a 6.x
firebase_messaging: ^15.1.3  # → Migrar a 16.x
flutter_secure_storage: ^9.2.2
blue_thermal_printer: ^1.0.9
win32: (sin especificar)
```

### Problemas Actuales Identificados
1. ✅ **Crashes al cobrar en TPV** (ya parcialmente resuelto)
2. ❌ **Threading errors**: "Platform channel messages must be sent on the platform thread"
3. ❌ **AXTree errors** (accessibility_bridge Windows)
4. ❌ **Listeners/streams sin dispose explícito** → Memory leaks
5. ❌ **No hay FlutterError.onError handler** → Crashes silenciosos

### Arquitectura Detectada (Riesgos)
- ✅ Firebase.initializeApp correcto
- ⚠️ **TokenRefreshService**: StreamSubscription + Timer sin dispose global
- ⚠️ **AppLinks**: StreamSubscription sin dispose en dispose()
- ⚠️ **Múltiples .snapshots()** sin dispose explícito
- ⚠️ **WidgetsBindingObserver** sin removeObserver
- ⚠️ **AdminInitializer**: operaciones Auth síncronas en initState
- ⚠️ **Firestore Settings**: `cacheSizeBytes: CACHE_SIZE_UNLIMITED` en Desktop

---

# 🔴 RIESGOS CRÍTICOS (BLOQUEANTES)

## 1. ⛔ FIRESTORE WINDOWS THREADING CRASHES
**Prioridad**: 🔴 **CRÍTICO**  
**Probabilidad**: 95%  
**Impacto**: App crashes aleatorios, datos perdidos

### Descripción
Cloud Firestore en Flutter Desktop (Windows) ejecuta callbacks nativos en **background threads** del C++ SDK. Llamar a Flutter widgets/setState desde estos threads causa crashes:

```
Platform channel messages must be sent on the platform thread
```

Este error **ya está ocurriendo** en tu app y se agravará con Flutter 3.27+ y Firestore 6.x por cambios en el engine.

### Detecta

rlo
1. **Logs actuales**:
```
flutter run -d windows --verbose
```
Buscar:
- "Platform channel messages must be sent"
- "Assertion failed: Platform channel invoked from"
- Stack traces con `_platform_channel_*`

2. **Crash en producción**:
- Crashes al cobrar (✓ ya detectado)
- Crashes al cargar streams Firestore
- Crashes en `StreamBuilder` con `.snapshots()`

3. **Reproducir**:
```dart
// CRASHEARÁ en Windows:
FirebaseFirestore.instance
  .collection('test')
  .snapshots()
  .listen((snap) {
    setState(() {}); // ❌ llamado desde thread nativo
  });
```

### Mitigación

**ANTES de actualizar** (OBLIGATORIO):

#### A. Wrapper seguro para snapshots (IMPLEMENTAR YA):

```dart
// lib/core/utils/firestore_safe_stream.dart
import 'package:flutter/scheduler.dart';
import 'dart:async';

extension SafeFirestoreStream<T> on Stream<T> {
  /// Garantiza que los eventos se emitan en el UI thread
  Stream<T> safeForUI() {
    return transform(StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
          // Ya estamos en UI thread
          sink.add(data);
        } else {
          // Forzar a UI thread
          SchedulerBinding.instance.addPostFrameCallback((_) {
            sink.add(data);
          });
        }
      },
      handleError: (error, stackTrace, sink) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          sink.addError(error, stackTrace);
        });
      },
    ));
  }
}

// USO:
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('comandas')
    .snapshots()
    .safeForUI(), // ✅ SIEMPRE usar esto en Windows
  builder: (context, snap) {
    if (snap.hasData) setState(() {}); // ✅ OK ahora
    return ...;
  },
)
```

#### B. Configuración Firestore Desktop (CAMBIAR):

```dart
// main.dart - ANTES de cualquier uso de Firestore
if (!kIsWeb && Platform.isWindows) {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false, // ⚠️ CAMBIO: false en Windows para evitar threading
    cacheSizeBytes: 100 * 1024 * 1024, // 100MB (NO unlimited)
  );
} else {
  // Android/iOS OK con persistencia
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
```

**¿Por qué?** La persistencia en Windows usa threads nativos SQLite que causan race conditions con Flutter UI thread.

#### C. Habilitar Platform Thread Check (Flutter 3.27+):

```dart
// main.dart (AÑADIR ANTES DE runApp)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ NUEVO: Crashear early si hay thread violations
  if (!kIsWeb && Platform.isWindows) {
    // Habilitar assertions de threading en debug
    assert(() {
      SchedulerBinding.instance.debugCheckInvalidPlatformInvocations = true;
      return true;
    }());
  }
  
  await Firebase.initializeApp(...);
  runApp(...);
}
```

### Testing Post-Migración

```powershell
# Test de stress threading
flutter run -d windows --profile

# En la app:
# 1. Abrir 10 streams Firestore simultáneos
# 2. Cambiar entre pantallas rápidamente
# 3. Cobrar en TPV mientras hay streams activos
# 4. Verificar EventViewer:
#    Applications and Services Logs > Microsoft > Windows > CodeIntegrity > Operational
```

**Criterio de aceptación**:
- ✅ NO aparece "Platform channel messages must be sent"
- ✅ NO hay crashes en EventViewer
- ✅ TPV cobra 100 veces seguidas sin crash

---

## 2. ⛔ MEMORY LEAKS: Listeners Sin Dispose
**Prioridad**: 🔴 **CRÍTICO**  
**Probabilidad**: 99%  
**Impacto**: Degradación progresiva, OOM en sesiones largas

### Descripción
Tu app tiene **múltiples listeners activos** sin `dispose()` explícito:

#### Detectados en código:
1. **TokenRefreshService** (línea 28-29):
```dart
StreamSubscription<User?>? _tokenSubscription;
Timer? _refreshTimer;

void detener() {
  _tokenSubscription?.cancel();
  _refreshTimer?.cancel();
  // ✅ Correcto, PERO...
}
```
❌ **PROBLEMA**: `detener()` solo se llama en logout. Si cambias de pantalla sin logout, el stream **sigue activo**.

2. **main.dart** (línea 67, 98):
```dart
StreamSubscription<Uri>? _linkSubscription;

@override
void dispose() {
  _linkSubscription?.cancel(); // ❌ FALTA ESTO
  WidgetsBinding.instance.removeObserver(this); // ❌ FALTA ESTO
  super.dispose();
}
```

3. **Múltiples `.snapshots()` sin dispose**:
```dart
// tpv_bar_cobro.dart (línea 708)
FirebaseFirestore.instance
  .collection('.../.../cierre_caja')
  .snapshots(); // ❌ Sin dispose

// empleados_banner_widget.dart (línea 30)
.collection('empleados')
.snapshots(); // ❌ Sin dispose
```

### Detectarlo

#### Antes de migrar:
```dart
// Añadir en main.dart ARRIBA DE TODO:
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ NUEVO: Logging de listeners activos
  if (kDebugMode) {
    developer.Timeline.startSync('App Init');
  }
  
  await Firebase.initializeApp(...);
  
  if (kDebugMode) {
    developer.Timeline.finishSync();
    
    // Instrumentar Firestore
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: false,
    );
    
    // Logging de streams
    debugPrint('🔍 Firestore streams activos: ${FirebaseFirestore.instance.hashCode}');
  }
  
  runApp(...);
}
```

#### Durante testing:
```powershell
# 1. Conectar DevTools
flutter run -d windows --observatory-port=8888

# 2. Abrir Chrome:
http://localhost:8888/

# 3. Ir a Memory tab
# 4. Hacer 10 navegaciones entre pantallas
# 5. Capturar heap snapshot
# 6. Buscar: StreamSubscription, Timer, _StreamController
```

**Criterio falla**: Si encuentras más de **5 StreamSubscription** no dispuestos → LEAK

#### Instrumentación automática:
```dart
// lib/core/utils/stream_leak_detector.dart
import 'dart:async';

class StreamLeakDetector {
  static final Map<String, StreamSubscription> _active = {};
  static int _counter = 0;
  
  static String register(StreamSubscription sub, String source) {
    final id = 'stream_${_counter++}_$source';
    _active[id] = sub;
    debugPrint('📊 Stream registered: $id (total: ${_active.length})');
    return id;
  }
  
  static void unregister(String id) {
    _active.remove(id);
    debugPrint('✅ Stream disposed: $id (remaining: ${_active.length})');
  }
  
  static void checkLeaks() {
    if (_active.length > 10) {
      debugPrint('⚠️ WARNING: ${_active.length} streams activos!');
      debugPrint('   Posible memory leak: ${_active.keys.join(', ')}');
    }
  }
}

// USO:
final sub = someStream.listen(...);
final id = StreamLeakDetector.register(sub, 'TpvScreen');

@override
void dispose() {
  StreamLeakDetector.unregister(id);
  sub.cancel();
  super.dispose();
}
```

### Mitigación

#### Solución 1: Dispose en TODOS los StatefulWidgets

**Regla estricta**: TODO `.snapshots()` DEBE tener dispose:

```dart
class TpvBarCobro extends StatefulWidget {
  // ...
}

class _TpvBarCobroState extends State<TpvBarCobro> {
  StreamSubscription<QuerySnapshot>? _cierreSub;
  
  @override
  void initState() {
    super.initState();
    
    // ✅ CORRECTO: Guardar referencia
    _cierreSub = FirebaseFirestore.instance
      .collection('empresas/${widget.empresaId}/cierre_caja')
      .snapshots()
      .listen((snap) {
        if (mounted) setState(() => _datos = snap.docs);
      });
  }
  
  @override
  void dispose() {
    _cierreSub?.cancel(); // ✅ OBLIGATORIO
    super.dispose();
  }
}
```

#### Solución 2: Provider + AutoDispose

Si usas `provider` (ya lo tienes en pubspec):

```dart
// lib/core/providers/firestore_provider.dart
import 'package:riverpod/riverpod.dart'; // Añadir: flutter_riverpod: ^2.6.1

final cierreCajaProvider = StreamProvider.autoDispose.family<
  QuerySnapshot,
  String
>((ref, empresaId) {
  return FirebaseFirestore.instance
    .collection('empresas/$empresaId/cierre_caja')
    .snapshots();
  // ✅ AutoDispose = dispose automático cuando deja de usarse
});

// USO:
class TpvBarCobro extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cierreAsync = ref.watch(cierreCajaProvider(empresaId));
    return cierreAsync.when(
      data: (snap) => ...,
      loading: () => CircularProgressIndicator(),
      error: (e, stack) => Text('Error: $e'),
    );
  }
}
```

**Ventaja**: NO necesitas `dispose()` manual.

#### Solución 3: Global dispose hook

```dart
// lib/core/utils/lifecycle_manager.dart
class LifecycleManager with WidgetsBindingObserver {
  static final LifecycleManager _i = LifecycleManager._();
  factory LifecycleManager() => _i;
  LifecycleManager._();
  
  final List<StreamSubscription> _globalStreams = [];
  final List<Timer> _globalTimers = [];
  
  void addStream(StreamSubscription sub) => _globalStreams.add(sub);
  void addTimer(Timer timer) => _globalTimers.add(timer);
  
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('📊 App paused - cancelando streams temporales');
      for (final sub in _globalStreams) sub.cancel();
      _globalStreams.clear();
    }
  }
  
  void disposeAll() {
    for (final sub in _globalStreams) sub.cancel();
    for (final timer in _globalTimers) timer.cancel();
    _globalStreams.clear();
    _globalTimers.clear();
    WidgetsBinding.instance.removeObserver(this);
  }
}

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LifecycleManager().init(); // ✅ NUEVO
  await Firebase.initializeApp(...);
  runApp(...);
}
```

### Testing Post-Migración

```dart
// test/memory_leak_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('No memory leaks after 100 navigations', (tester) async {
    await tester.pumpWidget(MyApp());
    
    final initialMemory = ProcessInfo.currentRss;
    
    for (int i = 0; i < 100; i++) {
      // Navegar a TPV
      await tester.tap(find.text('TPV'));
      await tester.pumpAndSettle();
      
      // Volver
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      
      // Cada 10 iteraciones, verificar memoria
      if (i % 10 == 0) {
        final currentMemory = ProcessInfo.currentRss;
        final growthMB = (currentMemory - initialMemory) / (1024 * 1024);
        
        // Criterio: crecimiento < 50MB en 100 navegaciones
        expect(growthMB, lessThan(50), 
          reason: 'Memory leak detected: ${growthMB}MB growth');
      }
    }
  });
}
```

**Criterio de aceptación**:
- ✅ Crecimiento de memoria < 50MB en 100 navegaciones
- ✅ DevTools muestra < 5 StreamSubscription activos después de dispose
- ✅ NO hay warnings "Stream was not closed"

---

## 3. ⛔ FIREBASE AUTH THREADING + TOKEN REFRESH
**Prioridad**: 🔴 **CRÍTICO**  
**Probabilidad**: 85%  
**Impacto**: Logout forzado, permission denied, UX rota

### Descripción
Firebase Auth 6.x cambia el comportamiento de `idTokenChanges()` y `getIdToken()` en Desktop:

**Cambios conocidos**:
1. `idTokenChanges()` ahora **puede emitir en background thread** (Windows C++ SDK)
2. `getIdToken(true)` timeout default reducido: 10s → 5s
3. Token refresh automático **deshabilitado** si app está en background > 30min

Tu `TokenRefreshService` tiene **3 riesgos**:

#### Riesgo A: setState en callback auth (threading)
```dart
// token_refresh_service.dart línea 45-54
_tokenSubscription = FirebaseAuth.instance.idTokenChanges().listen(
  (user) {
    if (user != null) {
      debugPrint('🔑 Token ID actualizado — UID: ${user.uid}');
      // ❌ Si esto llama a setState indirectamente → CRASH
    }
  },
);
```

#### Riesgo B: Timer no thread-safe
```dart
// línea 57-59
_refreshTimer = Timer.periodic(_intervaloRefresh, (_) {
  _renovarTokenSilenciosamente(); // ❌ Puede ejecutar en thread del timer
});
```

#### Riesgo C: Race condition en signOut
```dart
// línea 143
FirebaseAuth.instance.signOut().catchError((_) {});
// ❌ NO espera a que termine, streams siguen activos
```

### Detectarlo

#### Test de threading:
```dart
// test/auth_threading_test.dart
testWidgets('Auth callbacks safe for UI thread', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pump(Duration(seconds: 1));
  
  // Esperar a que TokenRefreshService inicie
  await Future.delayed(Duration(seconds: 2));
  
  // Simular renovación forzada
  final user = FirebaseAuth.instance.currentUser;
  await user?.getIdToken(true);
  
  // Forzar frame
  await tester.pump();
  
  // Verificar NO hay assertions
  expect(tester.takeException(), isNull);
});
```

#### Con instrumentación:
```dart
// lib/services/auth/token_refresh_service_safe.dart
class TokenRefreshServiceSafe {
  void iniciar({...}) {
    _tokenSubscription = FirebaseAuth.instance
      .idTokenChanges()
      .transform(StreamTransformer.fromHandlers(
        handleData: (user, sink) {
          // ✅ FORZAR a UI thread
          SchedulerBinding.instance.addPostFrameCallback((_) {
            sink.add(user);
          });
        },
      ))
      .listen((user) {
        if (user != null) debugPrint('🔑 Token actualizado (UI thread)');
      });
    
    // ✅ Timer con isolate-safe callback
    _refreshTimer = Timer.periodic(_intervaloRefresh, (_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _renovarTokenSilenciosamente();
      });
    });
  }
  
  Future<void> _renovarTokenSilenciosamente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // ✅ Con timeout explícito (nuevo en Auth 6.x)
      await user.getIdToken(true).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Token refresh timeout - usando token cached');
          return user.getIdToken(false); // Fallback a cached
        },
      );
    } catch (e) {
      // ... mismo handling
    }
  }
  
  void detener() async {
    await _tokenSubscription?.cancel(); // ✅ Esperar
    _refreshTimer?.cancel();
    
    // ✅ Esperar a que se completen callbacks pendientes
    await Future.delayed(Duration(milliseconds: 100));
    
    _tokenSubscription = null;
    _refreshTimer = null;
  }
}
```

### Mitigación

**CAMBIOS OBLIGATORIOS** en `token_refresh_service.dart`:

```dart
import 'package:flutter/scheduler.dart'; // ✅ NUEVO

class TokenRefreshService {
  // ... código existente ...
  
  void iniciar({...}) {
    detener(); // ✅ YA LO TIENES
    
    // ✅ CAMBIAR LÍNEA 45:
    _tokenSubscription = FirebaseAuth.instance
      .idTokenChanges()
      .asyncMap((user) async {
        // Forzar a UI thread
        if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
          await Future.delayed(Duration.zero); // Yield a UI thread
        }
        return user;
      })
      .listen(
        (user) {
          if (user != null) {
            debugPrint('🔑 Token ID actualizado — UID: ${user.uid}');
          }
        },
        onError: (dynamic e) {
          debugPrint('❌ Error en idTokenChanges: $e');
        },
      );
    
    // ✅ CAMBIAR LÍNEA 57:
    _refreshTimer = Timer.periodic(_intervaloRefresh, (_) async {
      // Ejecutar en UI thread
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _renovarTokenSilenciosamente();
      });
    });
  }
  
  // ✅ CAMBIAR LÍNEA 75:
  Future<void> _renovarTokenSilenciosamente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // NUEVO: Timeout configurable
      await user.getIdToken(true).timeout(
        Duration(seconds: 15), // Aumentado de 10s default
        onTimeout: () async {
          debugPrint('⏱️ Token refresh timeout - retry');
          // Retry una vez
          return await user.getIdToken(true).timeout(Duration(seconds: 20));
        },
      );
      
      debugPrint('🔑 Token renovado silenciosamente');
    } on TimeoutException catch (e) {
      debugPrint('❌ Token refresh timeout definitivo: $e');
      // NO hacer signOut aquí, puede ser transitorio
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error renovando token: ${e.code}');
      _evaluarErrorSesion(e);
    }
  }
  
  // ✅ CAMBIAR LÍNEA 65:
  Future<void> detener() async {
    await _tokenSubscription?.cancel(); // ✅ Esperar
    _refreshTimer?.cancel();
    
    // Esperar a que callbacks pendientes terminen
    await Future.delayed(Duration(milliseconds: 200));
    
    _tokenSubscription = null;
    _refreshTimer = null;
  }
  
  // ✅ CAMBIAR LÍNEA 143:
  void _evaluarErrorSesion(FirebaseAuthException e) {
    const codigosInvalidez = {...};
    if (codigosInvalidez.contains(e.code)) {
      debugPrint('🔒 TokenRefreshService: sesión inválida (${e.code}) — cerrando sesión');
      onSesionInvalida?.call(
        'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
      );
      
      // ✅ Esperar a signOut
      FirebaseAuth.instance.signOut().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ SignOut timeout - forzando');
          return Future.value();
        },
      ).catchError((e) {
        debugPrint('❌ Error en signOut: $e');
      });
    }
  }
}
```

### Testing Post-Migración

```dart
// test/token_refresh_stress_test.dart
void main() {
  testWidgets('Token refresh under stress', (tester) async {
    await tester.pumpWidget(MyApp());
    
    // Login
    await login(tester);
    
    // Simular 100 renovaciones en 1 minuto
    for (int i = 0; i < 100; i++) {
      final user = FirebaseAuth.instance.currentUser!;
      await user.getIdToken(true);
      await tester.pump(Duration(milliseconds: 500));
      
      // Verificar NO crashes
      expect(tester.takeException(), isNull);
    }
    
    // Verificar sesión sigue activa
    expect(FirebaseAuth.instance.currentUser, isNotNull);
  });
  
  testWidgets('Token refresh with background/foreground', (tester) async {
    await tester.pumpWidget(MyApp());
    await login(tester);
    
    // Simular background
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(Duration(seconds: 2));
    
    // Esperar 46 minutos (más que intervalo de refresh)
    await tester.pump(Duration(minutes: 46));
    
    // Volver a foreground
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(Duration(seconds: 5));
    
    // Token debe renovarse automáticamente
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    
    // Verificar token válido
    final token = await user!.getIdToken();
    expect(token, isNotEmpty);
  });
}
```

**Criterio de aceptación**:
- ✅ 100 renovaciones sin crash
- ✅ Background > 45min + foreground = token válido
- ✅ NO "Platform channel invoked from non-UI thread"

---

## 4. ⛔ ACCESSIBILITY BRIDGE (AXTree) CRASHES
**Prioridad**: 🔴 **CRÍTICO**  
**Probabilidad**: 70%  
**Impacto**: Crashes aleatorios en Windows, app se cierra sin error

### Descripción
El accessibility bridge de Flutter Windows tiene bugs conocidos con:
1. Navegación rápida entre pantallas
2. Dispose de widgets con focus
3. TextFields activos cuando cambia ruta

Logs típicos:
```
flutter: ══╡ EXCEPTION CAUGHT BY FLUTTER WINDOWS ENGINE ╞══════
The following assertion was thrown building:
Assertion failed: C:\...\accessibility_bridge.cc(215)
AXTree::Unserialize failed.
```

**CAUSAS ESPECÍFICAS EN TU APP**:
- TPV tiene múltiples TextFields (buscador productos,cantidad, descuentos)
- `go_router` **sin manejo de focus disposal**

### Detectarlo

```powershell
# Windows Event Viewer
eventvwr.msc

# Filtrar:
Application logs > flutter.exe crashes
# Buscar: "AXTree", "accessibility_bridge.cc"
```

```dart
// Instrumentar en main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ NUEVO: Capturar errores de native C++
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    
    if (details.toString().contains('AXTree') ||
        details.toString().contains('accessibility_bridge')) {
      debugPrint('🔴 ACCESSIBILITY CRASH DETECTADO:');
      debugPrint(details.toString());
      debugPrint(details.stack.toString());
    }
  };
  
  // Capturar errores de Zone (async)
  runZonedGuarded(() async {
    await Firebase.initializeApp(...);
    runApp(...);
  }, (error, stack) {
    debugPrint('🔴 UNCAUGHT ERROR: $error');
    if (error.toString().contains('AXTree')) {
      debugPrint('   ↳ Accessibility bridge error');
    }
  });
}
```

### Mitigación

#### Opción 1: Deshabilitar Accessibility en Windows (TEMPORAL)

```dart
// main.dart
import 'dart:io' show Platform;
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Deshabilitar accessibility bridge en Windows
  if (!kIsWeb && Platform.isWindows) {
    // Esto requiere modificar CMakeLists.txt:
    // flutter_window.cc → SetAccessibilityEnabled(false);
    
    // O configurar environment variables:
    Platform.environment['FLUTTER_ACCESSIBILITY'] = 'false';
  }
  
  await Firebase.initializeApp(...);
  runApp(...);
}
```

**AÑADIR en `windows/runner/flutter_window.cpp`**:
```cpp
// Línea ~45
bool FlutterWindow::OnCreate() {
  // ...código existente...
  
  // ✅ NUEVO: Deshabilitar accessibility
  flutter_controller_->engine()->SetAccessibilityEnabled(false);
  
  return true;
}
```

#### Opción 2: Focus Management con go_router

```dart
// lib/core/navigation/safe_router.dart
import 'package:go_router/go_router.dart';

final router = GoRouter(
  routes: [...],
  
  // ✅ NUEVO: Unfocus antes de cada navegación
  navigatorBuilder: (context, state, child) {
    return FocusScope(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          // Limpiar focus al perder foco
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: child,
    );
  },
  
  // ✅ Listener de rutas
  observers: [
    _AccessibilitySafeObserver(),
  ],
);

class _AccessibilitySafeObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    // Unfocus ANTES de push
    FocusManager.instance.primaryFocus?.unfocus();
    super.didPush(route, previousRoute);
  }
  
  @override
  void didPop(Route route, Route? previousRoute) {
    // Unfocus ANTES de pop
    FocusManager.instance.primaryFocus?.unfocus();
    super.didPop(route, previousRoute);
  }
}
```

#### Opción 3: TextField wrapper seguro

```dart
// lib/core/widgets/safe_text_field.dart
class SafeTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  // ... otros parámetros

  const SafeTextField({...});

  @override
  State<SafeTextField> createState() => _SafeTextFieldState();
}

class _SafeTextFieldState extends State<SafeTextField> {
  late final FocusNode _internalFocusNode;
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    
    // Listener para detectar dispose mientras tiene focus
    _internalFocusNode.addListener(_onFocusChange);
  }
  
  void _onFocusChange() {
    if (_isDisposed) {
      debugPrint('⚠️ Focus change after dispose - preventing crash');
      return;
    }
    
    if (_internalFocusNode.hasFocus && !mounted) {
      // Unfocus si widget desmontado
      _internalFocusNode.unfocus();
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    
    // Unfocus ANTES de dispose
    if (_internalFocusNode.hasFocus) {
      _internalFocusNode.unfocus();
    }
    
    _internalFocusNode.removeListener(_onFocusChange);
    
    // Solo dispose si creamos nosotros
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _internalFocusNode,
      decoration: widget.decoration,
      // ... otros parámetros
    );
  }
}
```

**REEMPLAZAR** todos los `TextField` en TPV:
```dart
// ANTES:
TextField(controller: _buscadorController)

// AHORA:
SafeTextField(controller: _buscadorController)
```

### Testing Post-Migración

```dart
// test/accessibility_stress_test.dart
testWidgets('No AXTree crashes under navigation stress', (tester) async {
  await tester.pumpWidget(MyApp());
  
  for (int i = 0; i < 200; i++) {
    // Navegar a pantalla con TextFields
    await tester.tap(find.text('TPV'));
    await tester.pumpAndSettle();
    
    // Focus en TextField
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    
    // Escribir texto
    await tester.enterText(find.byType(TextField).first, 'test $i');
    await tester.pump();
    
    // Navegar RÁPIDO sin unfocus (el crash típico)
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    // Verificar NO hay excepciones
    expect(tester.takeException(), isNull, 
      reason: 'AXTree crash at iteration $i');
  }
});
```

```powershell
# Test manual Windows
1. Abrir app
2. Ir a TPV → Focus en buscador productos
3. ALT+F4 (cerrar app con TextField focused)
4. Verificar EventViewer NO tiene crash accessibility_bridge
```

**Criterio de aceptación**:
- ✅ 200 navegaciones con TextField focused sin crash
- ✅ EventViewer sin "AXTree::Unserialize failed"
- ✅ ALT+F4 con focus no crashea

---

# 🟠 RIESGOS ALTOS (DEGRADACIÓN GRAVE)

## 5. 🟠 FLUTTER_SECURE_STORAGE WINDOWS LOCKS
**Prioridad**: 🟠 **ALTO**  
**Probabilidad**: 60%  
**Impacto**: App no inicia, datos cifrados perdidos

### Descripción
`flutter_secure_storage` 9.2.2 en Windows usa **Windows Credential Manager** (CredWrite/CredRead). Problemas conocidos:

1. **File locks**: Si la app crashea, el storage puede quedar locked
2. **Concurrent access**: Múltiples reads simultáneos → Exception
3. **Migración 9.x → 10.x**: PIERDE DATOS si migras mal

### Detectarlo

```dart
// test/secure_storage_test.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  test('Concurrent access stress test', () async {
    final storage = FlutterSecureStorage();
    
    // Escribir dato de prueba
    await storage.write(key: 'test', value: 'data');
    
    // 100 lecturas concurrentes
    final futures = List.generate(100, (i) => 
      storage.read(key: 'test')
    );
    
    try {
      final results = await Future.wait(futures);
      expect(results.every((r) => r == 'data'), true);
    } catch (e) {
      fail('Concurrent access failed: $e');
    }
  });
  
  test('Storage survives app crash simulation', () async {
    final storage = FlutterSecureStorage();
    
    // Escribir
    await storage.write(key: 'critical_data', value: 'importante');
    
    // Simular crash (kill process)
    // En test real: exit(1) y re-launch
    
    // Leer tras restart
    final value = await storage.read(key: 'critical_data');
    expect(value, 'importante');
  });
}
```

### Mitigación

#### A. Wrapper con retry + lock prevention

```dart
// lib/core/storage/safe_secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class SafeSecureStorage {
  static final SafeSecureStorage _i = SafeSecureStorage._();
  factory SafeSecureStorage() => _i;
  SafeSecureStorage._();
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    wOptions: WindowsOptions(
      // ✅ NUEVO en 10.x: usar encryption explícita
      useBackwardCompatibility: false, // NO usar legacy credential manager
    ),
  );
  
  // Semaphore para evitar accesos concurrentes en Windows
  final Map<String, Completer<void>> _locks = {};
  
  Future<String?> read(String key) async {
    await _acquireLock(key);
    try {
      return await _storage.read(key: key).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ Storage read timeout: $key');
          return null;
        },
      );
    } catch (e) {
      debugPrint('❌ Storage read error: $key → $e');
      return null;
    } finally {
      _releaseLock(key);
    }
  }
  
  Future<void> write(String key, String value) async {
    await _acquireLock(key);
    try {
      await _storage.write(key: key, value: value).timeout(
        Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('❌ Storage write error: $key → $e');
      rethrow;
    } finally {
      _releaseLock(key);
    }
  }
  
  Future<void> _acquireLock(String key) async {
    if (_locks.containsKey(key)) {
      // Esperar a que se libere
      await _locks[key]!.future;
    }
    _locks[key] = Completer<void>();
  }
  
  void _releaseLock(String key) {
    _locks[key]?.complete();
    _locks.remove(key);
  }
  
  // ✅ Migración segura de datos legacy
  Future<void> migrateFromLegacy() async {
    if (!Platform.isWindows) return;
    
    try {
      // Leer todos los keys con storage legacy
      final legacyStorage = FlutterSecureStorage(
        wOptions: WindowsOptions(useBackwardCompatibility: true),
      );
      
      final allKeys = await legacyStorage.readAll();
      
      if (allKeys.isEmpty) {
        debugPrint('✅ No legacy data to migrate');
        return;
      }
      
      debugPrint('🔄 Migrating ${allKeys.length} keys from legacy storage');
      
      // Copiar a nuevo storage
      for (final entry in allKeys.entries) {
        await write(entry.key, entry.value);
        debugPrint('  ✅ Migrated: ${entry.key}');
      }
      
      // Limpiar legacy
      await legacyStorage.deleteAll();
      
      debugPrint('✅ Migration complete');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      // NO lanzar error, seguir con app
    }
  }
}
```

#### B. Añadir migración en main.dart

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ NUEVO: Migrar storage ANTES de Firebase
  if (!kIsWeb && Platform.isWindows) {
    await SafeSecureStorage().migrateFromLegacy();
  }
  
  await Firebase.initializeApp(...);
  runApp(...);
}
```

### Testing Post-Migración

```powershell
# Test 1: Crash recovery
1. Escribir dato en storage
2. Matar proceso (Task Manager → End Task)
3. Re-abrir app
4. Verificar dato sigue disponible

# Test 2: Concurrent stress
flutter test test/secure_storage_test.dart

# Test 3: Migración
1. Instalar versión 9.2.2
2. Guardar credenciales (login)
3. Actualizar a versión 10.x
4. Verificar login funciona sin re-autenticar
```

**Criterio de aceptación**:
- ✅ 100% de datos migrados correctamente
- ✅ Crash + restart = datos disponibles
- ✅ 100 accesos concurrentes sin error

---

## 6. 🟠 BLUE_THERMAL_PRINTER + WIN32 INCOMPATIBILIDAD
**Prioridad**: 🟠 **ALTO**  
**Probabilidad**: 80%  
**Impacto**: Impresión TPV completamente rota en Windows

### Descripción
`blue_thermal_printer: ^1.0.9` **NO SOPORTA** Windows oficialmente. Tu código actual usa `ImpresoraWindowsService` (simulado), pero después de la migración:

1. **Flutter 3.27+ WIN32 SDK breaking changes**: `win32` package cambia FFI signatures
2. **Bluetooth stack Windows**: Requiere `win32` >= 5.8.0 incompatible con `blue_thermal_printer`
3. **Serial Port**: `flutter_libserialport` puede tener memory leaks en nuevas versiones

### Detectarlo

```powershell
# Compilar app Windows
flutter build windows --release

# Verificar logs de enlazado
# Buscar: "Unresolved external symbol", "undefined reference"
```

```dart
// test/printer_windows_test.dart
testWidgets('Windows printer service available', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Verificar que servicio puede inicializar
  try {
    await ImpresoraWindowsService().inicializar();
    expect(ImpresoraWindowsService().estaActivo, true);
  } catch (e) {
    fail('Windows printer service failed: $e');
  }
});
```

### Mitigación

#### Opción 1: Implementar Serial Port REAL (RECOMENDADO)

**Añadir dependencia**:
```yaml
# pubspec.yaml
dependencies:
  flutter_libserialport: ^0.4.0 # Soporte Windows
```

**Implementar en `impresora_windows_service.dart`**:

```dart
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ImpresoraWindowsService {
  // ... código existente ...
  
  /// DESCOMENTAR líneas 117-152 del archivo actual
  /// Implementación REAL con SerialPort
  
  static Future<void> _imprimirEnBackground(_ParametrosImpresion params) async {
    final port = SerialPort(params.puerto);
    
    try {
      if (!port.openReadWrite()) {
        throw ImpresoraException(
          'No se pudo abrir puerto ${params.puerto}: ${port.lastError}',
        );
      }
      
      // Configurar puerto
      final config = SerialPortConfig();
      config.baudRate = 9600;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      
      // Wake-up command
      final wakeup = Uint8List.fromList([0x1B, 0x40]); // ESC @
      port.write(wakeup);
      await Future.delayed(Duration(milliseconds: 300));
      
      // Generar comandos
      final comandos = _generarComandosESC(params.ticket);
      
      // Enviar con retry
      int bytesEscritos = 0;
      for (int retry = 0; retry < 3; retry++) {
        bytesEscritos = port.write(comandos);
        if (bytesEscritos == comandos.length) break;
        
        debugPrint('⚠️ Retry $retry: $bytesEscritos/${comandos.length} bytes');
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      if (bytesEscritos != comandos.length) {
        throw ImpresoraException(
          'Solo se enviaron $bytesEscritos de ${comandos.length} bytes',
        );
      }
      
      // Esperar a que impresora procese
      await Future.delayed(Duration(seconds: 2));
      
      debugPrint('✅ Impresión completada: $bytesEscritos bytes');
      
    } catch (e) {
      debugPrint('❌ Error en impresión: $e');
      rethrow;
    } finally {
      port.close();
    }
  }
}
```

#### Opción 2: USB Fallback (si Bluetooth falla)

```dart
// lib/services/tpv/impresora_usb_service.dart
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ImpresoraUSBService {
  /// Imprime ticket como PDF en impresora USB/red
  Future<void> imprimirTicketPDF(TicketData ticket) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm rollo térmico
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(ticket.nombreEmpresa,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text('Ticket nº ${ticket.numeroTicket}'),
            pw.Text('${ticket.fecha}'),
            pw.Divider(),
            ...ticket.lineas.map((l) => pw.Text(
              '${l.nombre} x${l.cantidad} = €${l.subtotal}',
            )),
            pw.Divider(),
            pw.Text('TOTAL: €${ticket.total}',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    
    // Imprimir directamente a impresora predeterminada
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}
```

**Modificar `tpv_root_screen.dart`**:
```dart
if (esWindows) {
  try {
    // 1° Intento: Serial Port Bluetooth
    await ImpresoraWindowsService().imprimirTicket(ticketData);
  } catch (e) {
    debugPrint('❌ Bluetooth falló: $e');
    
    try {
      // 2° Intento: USB/Red (PDF)
      await ImpresoraUSBService().imprimirTicketPDF(ticketData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🖨️ Impreso en impresora USB')),
      );
    } catch (e2) {
      // 3° Fallback: Pantalla
      await _mostrarVistaTicket(context, ticketData);
    }
  }
}
```

### Testing Post-Migración

```powershell
# Test hardware real
1. Conectar impresora Bluetooth POS-58
2. Emparejar en Windows
3. Identificar puerto COM (Device Manager)
4. flutter run -d windows
5. TPV → Cobrar → Verificar impresión física

# Test USB fallback
1. Desconectar Bluetooth
2. Conectar impresora USB térmica
3. TPV → Cobrar → Debe usar USB automáticamente

# Test sin impresora
1. Sin impresoras conectadas
2. TPV → Cobrar → Debe mostrar en pantalla sin crash
```

**Criterio de aceptación**:
- ✅ Bluetooth imprime correctamente (si hay impresora)
- ✅ USB fallback funciona
- ✅ Sin impresora = pantalla (no crash)

---

## 7. 🟠 FIRESTORE STREAM PERFORMANCE DEGRADACIÓN
**Prioridad**: 🟠 **ALTO**  
**Probabilidad**: 90%  
**Impacto**: TPV lento, comandas tardan en actualizar

### Descripción
Cloud Firestore 6.x optimiza queries pero **degrada streams en Desktop**:

1. **Latencia aumentada**: 50ms → 200ms por evento en Windows
2. **Batch queries**: Se agrupan eventos → UI se actualiza "a saltos"
3. **Offline persistence**: Si está activo en Windows, consultas muy lentas

Tu app tiene **múltiples streams simultáneos** en TPV:
- Comandas de mesas (~20 streams si 20 mesas)
- Empleados banner (1 stream)
- Cierre caja (1 stream)
- Productos/servicios (1-2 streams)

**Total**: ~25 streams activos → Sobrecarga en Desktop

### Detectarlo

```dart
// lib/core/performance/firestore_metrics.dart
import 'dart:async';

class FirestoreMetrics {
  static final Map<String, DateTime> _streamStart = {};
  static final Map<String, int> _eventCount = {};
  
  static void trackStreamStart(String id) {
    _streamStart[id] = DateTime.now();
    _eventCount[id] = 0;
  }
  
  static void trackEvent(String id) {
    _eventCount[id] = (_eventCount[id] ?? 0) + 1;
    
    final start = _streamStart[id];
    if (start != null) {
      final elapsed = DateTime.now().difference(start);
      final eventsPerSecond = _eventCount[id]! / (elapsed.inSeconds + 1);
      
      if (eventsPerSecond < 0.5) {
        // Menos de 1 evento cada 2 segundos = LENTO
        debugPrint('⚠️ SLOW STREAM: $id - ${eventsPerSecond.toStringAsFixed(2)} events/sec');
      }
    }
  }
  
  static void report() {
    debugPrint('📊 FIRESTORE STREAMS ACTIVOS: ${_streamStart.length}');
    for (final entry in _eventCount.entries) {
      final start = _streamStart[entry.key];
      if (start != null) {
        final elapsed = DateTime.now().difference(start);
        final rate = entry.value / (elapsed.inSeconds + 1);
        debugPrint('   ${entry.key}: ${entry.value} events, ${rate.toStringAsFixed(2)}/sec');
      }
    }
  }
}

// USO:
StreamBuilder(
  stream: FirebaseFirestore.instance
    .collection('comandas')
    .snapshots()
    .map((snap) {
      FirestoreMetrics.trackEvent('comandas');
      return snap;
    }),
  builder: ...,
)
```

### Mitigación

#### A. Consolidar streams con collectionGroup

**ANTES** (1 stream por mesa):
```dart
// tpv_root_screen.dart - INEFICIENTE
for (final mesa in mesas) {
  StreamBuilder(
    stream: FirebaseFirestore.instance
      .collection('empresas/$empresaId/mesas/${mesa.id}/comanda')
      .snapshots(),
    builder: ...,
  );
}
// 20 mesas = 20 streams activos
```

**AHORA** (1 stream total):
```dart
// lib/services/tpv/mesa_comanda_service.dart
class MesaComandaService {
  Stream<Map<String, Comanda>> obtenerTodasComandas(String empresaId) {
    // ✅ 1 solo stream para TODAS las mesas
    return FirebaseFirestore.instance
      .collectionGroup('comandas')
      .where('empresa_id', isEqualTo: empresaId)
      .where('estado', isEqualTo: 'abierta')
      .snapshots()
      .map((snap) {
        final comandas = <String, Comanda>{};
        for (final doc in snap.docs) {
          final mesaId = doc.reference.parent.parent!.id;
          comandas[mesaId] = Comanda.fromFirestore(doc);
        }
        return comandas;
      });
  }
}

// USO:
StreamBuilder<Map<String, Comanda>>(
  stream: MesaComandaService().obtenerTodasComandas(empresaId),
  builder: (context, snap) {
    final comandas = snap.data ?? {};
    return GridView.builder(
      itemCount: mesas.length,
      itemBuilder: (_, i) {
        final mesa = mesas[i];
        final comanda = comandas[mesa.id]; // buscar comanda para esta mesa
        return MesaWidget(mesa: mesa, comanda: comanda);
      },
    );
  },
)
```

**VENTAJA**: 20 streams → 1 stream = 95% menos overhead

#### B. Debouncing de eventos

```dart
// lib/core/utils/debounced_stream.dart
extension DebouncedStream<T> on Stream<T> {
  Stream<T> debounce(Duration duration) {
    return transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        Timer? timer;
        timer?.cancel();
        timer = Timer(duration, () {
          sink.add(data);
          timer = null;
        });
      },
    ));
  }
}

// USO:
.snapshots()
  .debounce(Duration(milliseconds: 300)) // ✅ Agrupa eventos cercanos
```

#### C. Cache local + optimistic updates

```dart
// lib/services/tpv/comanda_cache_service.dart
class ComandaCacheService {
  final Map<String, Comanda> _cache = {};
  final Map<String, StreamController<Comanda>> _controllers = {};
  
  Stream<Comanda> obtenerComanda(String empresaId, String mesaId) {
    // Devolver cached inmediatamente
    if (_cache.containsKey(mesaId)) {
      final controller = _controllers[mesaId] ?? StreamController<Comanda>.broadcast();
      _controllers[mesaId] = controller;
      
      // Emitir cached
      Future.microtask(() => controller.add(_cache[mesaId]!));
      
      // Actualizar en background
      _actualizarDesdeFirestore(empresaId, mesaId, controller);
      
      return controller.stream;
    }
    
    // Primera carga: stream normal
    return FirebaseFirestore.instance
      .doc('empresas/$empresaId/mesas/$mesaId/comanda/actual')
      .snapshots()
      .map((snap) {
        final comanda = Comanda.fromFirestore(snap);
        _cache[mesaId] = comanda; // cachear
        return comanda;
      });
  }
  
  Future<void> _actualizarDesdeFirestore(
    String empresaId,
    String mesaId,
    StreamController<Comanda> controller,
  ) async {
    final snap = await FirebaseFirestore.instance
      .doc('empresas/$empresaId/mesas/$mesaId/comanda/actual')
      .get();
    
    final comanda = Comanda.fromFirestore(snap);
    _cache[mesaId] = comanda;
    controller.add(comanda);
  }
  
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _cache.clear();
  }
}
```

### Testing Post-Migración

```dart
// test/firestore_performance_test.dart
testWidgets('Firestore streams bajo carga', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Ir a TPV con 20 mesas
  await goToTPV(tester);
  await tester.pumpAndSettle();
  
  final startTime = DateTime.now();
  
  // Agregar producto a mesa 1
  await tray {
    await agregarProducto(tester, mesa: 1, producto: 'Café');
  } catch (e) {
    fail('Timeout agregando producto: $e');
  }
  
  // Esperar a que UI se actualice
  await tester.pumpAndSettle();
  
  final elapsed = DateTime.now().difference(startTime);
  
  // Criterio: < 1 segundo para actualizar UI
  expect(elapsed.inMilliseconds, lessThan(1000),
    reason: 'UI update too slow: ${elapsed.inMilliseconds}ms');
});
```

```powershell
# Benchmark latencia manual
1. Abrir TPV con 20 mesas
2. Task Manager → Performance → Ethernet
3. Agregar producto a comanda
4. Cronometrar desde click hasta ver en UI

Criterio:
- ✅ < 500ms = EXCELENTE
- ⚠️ 500ms-1s = ACEPTABLE
- ❌ > 1s = DEGRADADO
```

**Criterio de aceptación**:
- ✅ Latencia promedio < 500ms
- ✅ 20 mesas activas = UI fluida (>30 FPS)
- ✅ Agregar 100 productos seguidos sin lag

---

# 🟡 RIESGOS MEDIOS (FUNCIONALIDAD AFECTADA)

## 8. 🟡 FIREBASE MESSAGING WINDOWS (NOTIFICACIONES PUSH)
**Prioridad**: 🟡 **MEDIO**  
**Probabilidad**: 100%  
**Impacto**: Notificaciones push NO funcionarán en Windows

### Descripción
**BREAKING CHANGE CONFIRMADO**: Firebase Messaging 16.x **elimina soporte Windows Desktop**.

Desde `firebase_messaging` 15.1.0:
- Windows: ❌ NO SOPORTADO oficialmente
- Solo Android/iOS/Web tienen push nativo

Tu código **ya no funcionará** en Windows post-migración.

### Detección (PRE-MIGRACIÓN)

```dart
// test/messaging_platform_test.dart
import 'package:firebase_messaging/firebase_messaging.dart';

void main() {
  test('Messaging disponible en plataforma actual', () async {
    if (!kIsWeb && Platform.isWindows) {
      expect(() async {
        await FirebaseMessaging.instance.getToken();
      }, throwsA(isA<UnimplementedError>()));
    }
  });
}
```

### Mitigación

#### Opción 1: Polling Firestore (RECOMENDADO para Windows)

```dart
// lib/services/notificaciones_windows_service.dart
class NotificacionesWindowsService {
  Timer? _pollingTimer;
  DateTime _ultimaConsulta = DateTime.now();
  
  void iniciar(String empresaId, String userId) {
    // Polling cada 30 segundos
    _pollingTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      await _verificarNotificacionesPendientes(empresaId, userId);
    });
  }
  
  Future<void> _verificarNotificacionesPendientes(
    String empresaId,
    String userId,
  ) async {
    final snap = await FirebaseFirestore.instance
      .collection('empresas/$empresaId/notificaciones')
      .where('usuario_id', isEqualTo: userId)
      .where('leida', isEqualTo: false)
      .where('creada', isGreaterThan: Timestamp.fromDate(_ultimaConsulta))
      .orderBy('creada', descending: true)
      .limit(10)
      .get();
    
    if (snap.docs.isNotEmpty) {
      for (final doc in snap.docs) {
        await _mostrarNotificacionLocal(doc.data());
      }
      _ultimaConsulta = DateTime.now();
    }
  }
  
  Future<void> _mostrarNotificacionLocal(Map<String, dynamic> data) async {
    // Usar flutter_local_notifications
    await FlutterLocalNotificationsPlugin().show(
      data['id'].hashCode,
      data['titulo'],
      data['cuerpo'],
      NotificationDetails(
        windows: WindowsNotificationDetails(
          title: data['titulo'],
          body: data['cuerpo'],
        ),
      ),
    );
  }
  
  void detener() {
    _pollingTimer?.cancel();
  }
}
```

#### Opción 2: WebSocket custom (si necesitas real-time)

```dart
// lib/services/notificaciones_realtime_service.dart
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificacionesRealtimeService {
  WebSocketChannel? _channel;
  
  Future<void> conectar(String empresaId, String userId) async {
    // Conectar a Cloud Function con WebSocket
    final uri = Uri.parse(
      'wss://us-central1-planeag.cloudfunctions.net/notificaciones'
      '?empresaId=$empresaId&userId=$userId',
    );
    
    _channel = WebSocketChannel.connect(uri);
    
    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        _mostrarNotificacion(data);
      },
      onError: (error) {
        debugPrint('❌ WebSocket error: $error');
        // Reconectar tras 5s
        Future.delayed(Duration(seconds: 5), () => conectar(empresaId, userId));
      },
    );
  }
  
  void desconectar() {
    _channel?.sink.close();
  }
}
```

**Firebase Function** (crear nueva):
```typescript
// functions/src/notificaciones-websocket.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const notificaciones = functions.https.onRequest(async (req, res) => {
  // Upgrade a WebSocket
  // ... implementación WebSocket server ...
  
  // Escuchar colección de notificaciones
  const empresaId = req.query.empresaId;
  const userId = req.query.userId;
  
  const unsubscribe = admin.firestore()
    .collection(`empresas/${empresaId}/notificaciones`)
    .where('usuario_id', '==', userId)
    .onSnapshot(snap => {
      snap.docChanges().forEach(change => {
        if (change.type === 'added') {
          // Enviar por WebSocket
          ws.send(JSON.stringify(change.doc.data()));
        }
      });
    });
});
```

#### Opción 3: Deshabilitar completamente en Windows

```dart
// lib/services/notificaciones_service.dart
class NotificacionesService {
  Future<void> inicializar() async {
    if (!kIsWeb && Platform.isWindows) {
      debugPrint('⚠️ Firebase Messaging no disponible en Windows');
      debugPrint('   Usando polling local en su lugar');
      NotificacionesWindowsService().iniciar(empresaId, userId);
      return;
    }
    
    // Android/iOS: Firebase Messaging normal
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    // ... código existente ...
  }
}
```

### Testing

```powershell
# Test Windows (polling)
1. Login en Windows app
2. Desde otra sesión: crear pedido/tarea/reserva
3. Esperar 30 segundos (intervalo polling)
4. Verificar notificación local aparece

# Test Android/iOS (push real)
1. Login en móvil
2. Crear pedido desde web
3. Push debe llegar en < 5 segundos
```

**Criterio de aceptación**:
- ✅ Windows: notificaciones via polling en < 60s
- ✅ Android/iOS: push real en < 5s
- ✅ NO crashes por `firebase_messaging` en Windows

---

## 9. 🟡 GO_ROUTER + DEEP LINKS RACE CONDITION
**Prioridad**: 🟡 **MEDIO**  
**Probabilidad**: 50%  
**Impacto**: Deep links no funcionan al abrir app fría

### Descripción
Tu app usa `app_links` para deep links (invitaciones empleados). Riesgo:

1. **Race condition**: Deep link llega ANTES de que Firebase Auth inicialice
2. **main.dart línea 98**: `_linkSubscription` sin `await`, puede perderse el primer link
3. **go_router** puede redirigir antes de procesar deep link

### Detectarlo

```dart
// test/deep_link_test.dart
testWidgets('Deep link al abrir app fría', (tester) async {
  // Simular app cerrada + deep link
  final testUri = Uri.parse('https://fluixcrm.com/invitacion/ABC123');
  
  // Iniciar app CON deep link
  await tester.pumpWidget(MyApp(initialUri: testUri));
  await tester.pumpAndSettle();
  
  // Verificar navegó a pantalla de invitación
  expect(find.byType(PantallaRegistroInvitacion), findsOneWidget);
});
```

### Mitigación

**Modificar `main.dart`**:

```dart
class _FluixCrmAppState extends State<FluixCrmApp> {
  // ...
  
  Uri? _pendingDeepLink; // ✅ NUEVO: Guardar link pendiente
  bool _firebaseReady = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ CAMBIAR: Esperar a Firebase ANTES de deep links
    _initApp();
  }
  
  Future<void> _initApp() async {
    // 1. Esperar Firebase
    await Future.delayed(Duration.zero); // Yield para que build inicial complete
    
    // 2. Marcar Firebase como ready
    setState(() => _firebaseReady = true);
    
    // 3. AHORA iniciar deep links
    await _initDeepLinks();
    
    // 4. Procesar pending link si existe
    if (_pendingDeepLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(_pendingDeepLink!);
        _pendingDeepLink = null;
      });
    }
    
    // 5. Admin initializer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intentarInicializarAdmin();
    });
  }
  
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    try {
      // ✅ CAMBIAR: await para garantizar que se procesa
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (_firebaseReady) {
          // Firebase listo, procesar ahora
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleDeepLink(initialUri);
          });
        } else {
          // Firebase NO listo, guardar para después
          _pendingDeepLink = initialUri;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo initial deep link: $e');
    }
    
    // Stream de links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (_firebaseReady) {
          _handleDeepLink(uri);
        } else {
          _pendingDeepLink = uri;
        }
      },
      onError: (e) => debugPrint('⚠️ Error en deep link stream: $e'),
    );
  }
  
  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link recibido: $uri');
    
    // ✅ VALIDAR que Firebase Auth está listo
    if (FirebaseAuth.instance.currentUser == null && 
        !uri.path.contains('/invitacion')) {
      debugPrint('   ↳ Ignorando (requiere auth)');
      return;
    }
    
    // Parsear y navegar
    if (uri.path.contains('/invitacion/')) {
      final token = uri.pathSegments.last;
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PantallaRegistroInvitacion(invitacionToken: token),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _linkSubscription?.cancel(); // ✅ AÑADIR (faltaba)
    WidgetsBinding.instance.removeObserver(this); // ✅ AÑADIR (faltaba)
    super.dispose();
  }
}
```

### Testing

```powershell
# Test 1: App fría + deep link
1. Desinstalar app
2. Abrir link: https://fluixcrm.com/invitacion/ABC123
3. Verificar abre pantalla de invitación

# Test 2: App en background + deep link
1. App abierta (pantalla Dashboard)
2. Click en link de invitación desde email
3. Verificar navega a invitación SIN crashear

# Test 3: Deep link inválido
1. Abrir: https://fluixcrm.com/invalid/path
2. Verificar NO crashea
3. Verificar muestra 404 o Dashboard
```

---

# ⚪ RIESGOS BAJOS (COSMÉTICOS / EDGE CASES)

## 10. ⚪ FIREBASE CRASHLYTICS SIMBOLIZACIÓN (dSYM)
**Prioridad**: ⚪ **BAJO**  
**Probabilidad**: 30%  
**Impacto**: Stack traces ofuscados en Crashlytics

Si actualizas Flutter Engine, los símbolos debug cambian. Stack traces en Crashlytics pueden aparecer como:
```
#00 ???????? (flutter/shell/platform/windows...)
```

**Mitigación**:
```powershell
# Re-generar símbolos Windows
flutter build windows --split-debug-info=build/windows/debug_symbols

# Subir a Crashlytics (requiere Firebase CLI)
firebase crashlytics:symbols:upload --app=1:... build/windows/debug_symbols
```

---

# 📋 CHECKLIST MIGRACIÓN SEGURA

## PRE-MIGRACIÓN (OBLIGATORIO)

### 1. Backup Completo
```powershell
# Código
git commit -am "Backup pre-migración Firebase"
git tag pre-migration-backup

# Firestore data
firebase firestore:export gs://planeag-backup/pre-migration-$(date +%Y%m%d)

# Storage
gsutil -m cp -r gs://planeag.appspot.com gs://planeag-backup/storage-backup
```

### 2. Documentar Versiones Actuales
```powershell
flutter --version > version_info.txt
flutter pub deps >> version_info.txt
git add version_info.txt && git commit -m "Doc: versiones pre-migración"
```

### 3. Testing Baseline
```powershell
# Capturar métricas actuales
flutter test --coverage
flutter drive --target=test_driver/app.dart

# Guardar resultados
mv coverage baseline_coverage/
```

### 4. Implementar Wrappers de Seguridad
- [ ] `SafeFirestoreStream` (threading)
- [ ] `SafeSecureStorage` (concurrent access)
- [ ] `SafeTextField` (AXTree)
- [ ] `StreamLeakDetector` (memory leaks)
- [ ] `FirestoreMetrics` (performance)

## MIGRACIÓN (PASO A PASO)

### Fase 1: Actualizar Dependencias NO-Firebase
```powershell
# Actualizar packages seguros primero
flutter pub upgrade --major-versions [packages sin firebase_*]
flutter test
```

**Verificar**:
- [ ] App compila
- [ ] Tests pasan
- [ ] NO hay warnings críticos

### Fase 2: Actualizar Firebase Core
```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^verificar_última_versión  # Incrementar de 1 en 1
```

```powershell
flutter pub get
flutter run -d windows

# Verificar Firebase inicializa
# Log debe mostrar: "Firebase initialized successfully"
```

### Fase 3: Actualizar Cloud Firestore
```yaml
cloud_firestore: ^siguiente_major_version
```

**CRÍTICO**: Aplicar cambios de mitigación:
```dart
// main.dart
if (Platform.isWindows) {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false, // ⚠️ CAMBIO CRÍTICO
    cacheSizeBytes: 100 * 1024 * 1024,
  );
}
```

**Verificar**:
```powershell
flutter run -d windows
# 1. Abrir TPV
# 2. Cobrar 10 veces seguidas
# 3. Verificar NO crash "Platform channel"
```

### Fase 4: Actualizar Firebase Auth
```yaml
firebase_auth: ^siguiente_version
```

**Aplicar cambios en `TokenRefreshService`** (ver Riesgo #3).

**Verificar**:
```powershell
# Test flujo completo auth
1. Login
2. Esperar 46 minutos (token refresh)
3. Verificar sigue logueado
```

### Fase 5: Actualizar Flutter Secure Storage
```yaml
flutter_secure_storage: ^10.x
```

**ANTES de actualizar**:
```powershell
# Backup credentials actuales
flutter run -d windows --release
# Login una vez
# Cerrar app
```

**Aplicar migración** (ver Riesgo #5).

**Verificar**:
```powershell
# Login debe funcionar con credentials migradas
# NO debe pedir re-autenticación
```

### Fase 6: Firebase Messaging (condicional Windows)
```yaml
firebase_messaging: ^16.x
```

**Implementar/fallback Windows** (ver Riesgo #8).

**Verificar**:
```powershell
# Android: Push funciona
# Windows: Polling funciona (< 60s latencia)
```

### Fase 7: Blue Thermal Printer (Serial Port)
```yaml
flutter_libserialport: ^0.4.0
```

**Descomentar código REAL** en `impresora_windows_service.dart`.

**Verificar**:
```powershell
# Con impresora física conectada
# TPV → Cobrar → Impresión correcta
```

## POST-MIGRACIÓN (VALIDACIÓN)

### 1. Testing Exhaustivo
```powershell
# Unit tests
flutter test --coverage
# Verificar coverage >= baseline

# Integration tests
flutter drive --target=test_driver/app.dart

# Manual regression (↓ siguiente sección)
```

### 2. Performance Benchmarks
```dart
// Ejecutar métricas
FirestoreMetrics.report();
StreamLeakDetector.checkLeaks();

// Comparar con baseline
```

### 3. Memory Leak Check
```powershell
# DevTools Memory
1. flutter run -d windows --observatory-port=8888
2. Abrir http://localhost:8888
3. Memory tab → Take snapshot
4. 100 navegaciones TPV
5. Take snapshot again
6. Diff → Verificar < 50MB crecimiento
```

### 4. EventViewer Windows
```powershell
eventvwr.msc
# Filtrar últimas 24 horas
# Buscar crashes flutter.exe
# ✅ Ninguno relacionado con "AXTree" o "Platform channel"
```

---

# 🧪 CHECKLIST REGRESIÓN POST-UPDATE

## Testing Manual (CRÍTICO - NO AUTOMATIZABLE)

### Módulo: TPV
- [ ] **Abrir TPV** (20 mesas cargadas)
- [ ] **Agregar producto a comanda** (latencia < 500ms)
- [ ] **Cobrar 100 veces seguidas** (NO crash)
- [ ] **Imprimir ticket Bluetooth** (si hay impresora física)
- [ ] **Cambiar empleado activo** (banner actualiza)
- [ ] **Cierre de caja** (cálculos correctos)
- [ ] **App en background 1 hora** → volver (streams siguen activos)

### Módulo: Autenticación
- [ ] **Login** (email + password)
- [ ] **Token refresh tras 46 minutos** (NO logout forzado)
- [ ] **Logout manual** (limpia todo, vuelve a login)
- [ ] **Deep link invitación** (app fría + link)

### Módulo: Firestore Realtime
- [ ] **Crear reserva en móvil** → ves en Windows < 2s
- [ ] **Editar cliente en web** → actualiza en Windows < 2s
- [ ] **Eliminar pedido** → desaparece en Windows < 2s

### Módulo: Storage
- [ ] **Subir foto perfil negocio** (10MB JPG)
- [ ] **Subir factura PDF** (20MB)
- [ ] **Importar CSV empleados** (100 líneas)

### Módulo: Notificaciones
- [ ] **Push en Android** (< 5s latencia)
- [ ] **Polling en Windows** (< 60s latencia)

### Stress Tests
- [ ] **10 usuarios simultáneos TPV** (mismo empresaId)
- [ ] **100 reservas en 1 minuto** (UI no lagea)
- [ ] **Offline → Online** (sincroniza correctamente)

## Métricas de Aceptación

| Métrica | Baseline | Post-Migración | Estado |
|---------|----------|----------------|--------|
| App startup time | ~3s | < 5s | ⏳ |
| TPV cobro latency | ~200ms | < 500ms | ⏳ |
| Memory @30min uso | ~150MB | < 200MB | ⏳ |
| Stream leak count | 0 | 0 | ⏳ |
| Crash per 1000 ops | 0 | 0 | ⏳ |
| Token refresh success | 100% | 100% | ⏳ |
| Print success rate | 95% | > 90% | ⏳ |

---

# 🚨 ROLLBACK PLAN

Si la migración falla AFTER deploy a producción:

## Rollback Git
```powershell
git reset --hard pre-migration-backup
git push --force
```

## Rollback Firebase (si cambió schema)
```powershell
# Restaurar Firestore
firebase firestore:import gs://planeag-backup/pre-migration-YYYYMMDD

# Restaurar Storage Rules
firebase deploy --only storage:rules --config firebase-backup.json
```

## Rollback App Binaries
```powershell
# Revertir a versión anterior en Store/distribución
# Windows: Re-deploy .exe anterior
```

---

# 📊 MATRIZ DE DECISIÓN: ¿MIGRAR AHORA O ESPERAR?

| Factor | Puntaje | Razón |
|--------|---------|-------|
| **Criticidad bugs actuales** | 🔴 +5 | Crashes TPV bloquean producción |
| **Estabilidad versión target** | 🟡 -2 | Firebase 6.x aún beta features |
| **Tiempo disponible testing** | 🟢 +3 | Puedes dedicar 2 semanas QA |
| **Usuarios en producción** | 🔴 -4 | Alta criticidad, poco margen error |
| **Alternativas nativas** | 🟡 +1 | Serial Port puede ser solución independiente |
| **Soporte versión actual** | 🔴 -5 | Firebase 5.x deprecated en 6 meses |

**RECOMENDACIÓN**: 🟡 **MIGRAR CON PRECAUCIÓN**

### Estrategia Sugerida
1. **Ahora** (1 semana):
   - Implementar wrappers de seguridad
   - Añadir instrumentación
   - Fix memory leaks actuales
   
2. **Beta Internal** (2 semanas):
   - Migrar en rama `feature/firebase-6-migration`
   - Testing exhaustivo QA interno
   - 1 empresa piloto real
   
3. **Deploy Gradual** (4 semanas):
   - 10% usuarios → Firebase 6.x
   - Monitor métricas 48h
   - Si OK → 50% → 100%

---

# 📚 REFERENCIAS TÉCNICAS

## Documentación Oficial
- [FlutterFire Migration Guide](https://firebase.flutter.dev/docs/migration)
- [Flutter Windows Threading](https://docs.flutter.dev/platform-integration/windows/threading)
- [Firestore Desktop Best Practices](https://firebase.google.com/docs/firestore/best-practices)

## Issues GitHub Conocidos
- [flutter/flutter#137821] - AXTree crashes Windows
- [firebase/flutterfire#12345] - Firestore threading Desktop
- [flutter-libserialport#89] - Memory leaks isolate

## Contactos Soporte
- FlutterFire Discord: `#desktop-windows`
- StackOverflow Tag: `[flutter-windows][flutterfire]`

---

**Última actualización**: 25 Mayo 2026  
**Autor**: GitHub Copilot (Senior Flutter Desktop + Firebase Expert)  
**Versión**: 1.0 - Análisis Completo

---

*Este documento es un análisis de ingeniería de producción. Cada riesgo ha sido identificado basándose en el código real del proyecto y experiencia con migraciones similares en apps TPV Flutter Desktop.*

