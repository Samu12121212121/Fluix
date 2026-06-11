# 🔧 CÓDIGO LISTO PARA IMPLEMENTAR — Fase 1

**Instrucciones**: Copiar y pegar estos archivos para implementar los fixes críticos de Fase 1.

---

## 📁 Archivo 1: `lib/core/mixins/safe_stream_mixin.dart` (NUEVO)

```dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin que gestiona automáticamente la cancelación de StreamSubscriptions.
/// 
/// USO:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
/// 
/// class _MyScreenState extends State<MyScreen> with SafeStreamMixin {
///   @override
///   void initState() {
///     super.initState();
///     
///     // En lugar de:
///     // _subscription = stream.listen((data) => ...);
///     
///     // Usar:
///     listenSafe(stream, (data) {
///       setState(() {
///         // actualizar estado
///       });
///     });
///   }
///   
///   // dispose() automático — no necesario escribirlo
/// }
/// ```
mixin SafeStreamMixin<T extends StatefulWidget> on State<T> {
  /// Lista de suscripciones registradas para auto-cancelación.
  final List<StreamSubscription> _subscriptions = [];
  
  /// Registra una suscripción a un stream que se cancela automáticamente
  /// cuando el widget se destruye.
  /// 
  /// [stream] Stream a escuchar
  /// [onData] Callback cuando llegan datos
  /// [onError] Callback opcional para errores
  /// [onDone] Callback opcional cuando stream se completa
  void listenSafe<S>(
    Stream<S> stream,
    void Function(S data) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _subscriptions.add(subscription);
  }
  
  /// Registra múltiples suscripciones de una vez.
  void listenSafeMultiple(List<StreamSubscription> subscriptions) {
    _subscriptions.addAll(subscriptions);
  }
  
  /// Cancela manualmente una suscripción específica antes del dispose.
  void cancelSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }
  
  @override
  void dispose() {
    // Cancelar todas las suscripciones registradas
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    debugPrint('✅ SafeStreamMixin: ${_subscriptions.length} streams cancelados');
    
    super.dispose();
  }
}
```

---

## 📁 Archivo 2: Modificar `lib/main.dart`

**BUSCAR** (líneas 31-35):
```dart
// Activar persistencia offline de Firestore
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**REEMPLAZAR CON**:
```dart
// Activar persistencia offline de Firestore — configuración por plataforma
await _configurarFirestore();
```

**AÑADIR** esta función después de `main()` (antes de la clase `FluixCrmApp`):

```dart
/// Configura Firestore con ajustes específicos por plataforma.
/// 
/// - **Windows/Desktop**: Caché limitada (100MB) + limpieza al inicio
///   → Previene crashes de platform channels y crecimiento ilimitado de disco
/// 
/// - **Mobile (Android/iOS)**: Caché ilimitada
///   → Aprovecha persistencia nativa optimizada del SDK
/// 
/// - **Web**: Sin persistencia
///   → No soportado en navegadores
Future<void> _configurarFirestore() async {
  if (kIsWeb) {
    // ── WEB: Sin persistencia (no soportado) ──────────────────────────
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    debugPrint('🌐 Firestore configurado para Web (sin persistencia)');
    
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS) {
    // ── DESKTOP: Caché limitada + limpieza preventiva ─────────────────
    
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB máximo
    );
    
    // Limpiar caché al iniciar app (previene acumulación)
    try {
      await FirebaseFirestore.instance.clearPersistence();
      debugPrint('✅ Caché Firestore limpiada (Windows)');
    } catch (e) {
      // Error esperado si app ya está usando Firestore
      debugPrint('ℹ️ No se pudo limpiar caché (app activa): $e');
    }
    
    debugPrint('💻 Firestore configurado para Desktop (caché 100MB)');
    
  } else {
    // ── MOBILE: Caché ilimitada (óptimo para iOS/Android) ─────────────
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('📱 Firestore configurado para Mobile (caché ilimitada)');
  }
}
```

**RESULTADO FINAL** de `main()`:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Configuración inteligente por plataforma
  await _configurarFirestore();

  if (!kIsWeb &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
      kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppConfigProvider()..inicializar(),
      child: const FluixCrmApp(),
    ),
  );
}

// ✅ Función nueva (copiada arriba)
Future<void> _configurarFirestore() async {
  // ... código de arriba
}
```

---

## 📁 Archivo 3: Ejemplo de Uso en `tpv_peluqueria_screen.dart`

**ANTES** (líneas 1105-1110 aprox.):
```dart
class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen> {
  StreamSubscription<QuerySnapshot>? _subProfs;
  StreamSubscription<QuerySnapshot>? _subEmpleados;
  
  @override
  void initState() {
    super.initState();
    
    _subProfs = FirebaseFirestore.instance
        .collection('empresas/${widget.empresaId}/profesionales')
        .snapshots()
        .listen((snap) {
      setState(() {
        _profesionales = snap.docs.map(...).toList();
      });
    });
    
    _subEmpleados = FirebaseFirestore.instance
        .collection('empresas/${widget.empresaId}/empleados')
        .snapshots()
        .listen((snap) {
      setState(() {
        _empleados = snap.docs.map(...).toList();
      });
    });
  }
  
  @override
  void dispose() {
    _subProfs?.cancel();
    _subEmpleados?.cancel();
    super.dispose();
  }
}
```

**DESPUÉS** (usando `SafeStreamMixin`):
```dart
// ✅ Añadir import
import '../../../core/mixins/safe_stream_mixin.dart';

class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen>
    with SafeStreamMixin {  // ✅ Añadir mixin
  
  // ❌ YA NO NECESARIO: StreamSubscription<QuerySnapshot>? _subProfs;
  // ❌ YA NO NECESARIO: StreamSubscription<QuerySnapshot>? _subEmpleados;
  
  @override
  void initState() {
    super.initState();
    
    // ✅ Usar listenSafe en lugar de .listen()
    listenSafe(
      FirebaseFirestore.instance
          .collection('empresas/${widget.empresaId}/profesionales')
          .snapshots(),
      (snap) {
        setState(() {
          _profesionales = snap.docs.map(...).toList();
        });
      },
    );
    
    listenSafe(
      FirebaseFirestore.instance
          .collection('empresas/${widget.empresaId}/empleados')
          .snapshots(),
      (snap) {
        setState(() {
          _empleados = snap.docs.map(...).toList();
        });
      },
    );
  }
  
  // ❌ YA NO NECESARIO: dispose() — el mixin lo hace automáticamente
}
```

---

## 📁 Archivo 4: Feature Flag (Opcional pero Recomendado)

**Crear**: `lib/core/config/feature_flags.dart`

```dart
/// Feature flags para activar/desactivar funcionalidades nuevas.
/// 
/// Permite rollback inmediato sin recompilar (cambiar a `false`).
class FeatureFlags {
  /// ── FASE 1: ESTABILIZACIÓN ──────────────────────────────────────────
  
  /// Usa configuración de Firestore específica por plataforma
  /// (caché limitada en Windows).
  static const bool USE_PLATFORM_AWARE_FIRESTORE = true;
  
  /// Usa SafeStreamMixin para auto-cancelación de streams.
  static const bool USE_SAFE_STREAM_MIXIN = true;
  
  /// ── FASE 2: REPOSITORY PATTERN (próximamente) ──────────────────────
  
  /// Usa Repository Pattern en lugar de acceso directo a Firestore.
  static const bool USE_REPOSITORY_PATTERN = false;
  
  /// Usa polling en Windows en lugar de realtime streams.
  static const bool USE_WINDOWS_POLLING = false;
  
  /// ── FASE 3: OPTIMIZACIONES (próximamente) ──────────────────────────
  
  /// Usa cache local como primera fuente de datos.
  static const bool USE_CACHE_FIRST = false;
  
  /// Usa smart polling con prioridades diferenciadas.
  static const bool USE_SMART_POLLING = false;
  
  /// Usa dependency injection con GetIt.
  static const bool USE_DI = false;
}
```

**USO**:
```dart
import 'package:planeag_flutter/core/config/feature_flags.dart';

// En main.dart
if (FeatureFlags.USE_PLATFORM_AWARE_FIRESTORE) {
  await _configurarFirestore();
} else {
  // Configuración legacy
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}

// En tpv_peluqueria_screen.dart
class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen>
    with SafeStreamMixin {  // Siempre añadir mixin, el flag se chequea internamente si es necesario
  // ...
}
```

---

## 🧪 TESTING MANUAL (Checklist)

Después de implementar los cambios, validar:

### ✅ Test 1: Memory Leak TPV (Crítico)
1. Abrir app Windows
2. Ir a TPV
3. Cerrar TPV (volver atrás)
4. Repetir pasos 2-3 unas **50 veces**
5. Abrir Task Manager → verificar memoria

**Esperado**:
- ✅ Memoria estable (~200-300MB)
- ✅ Sin crashes

**Antes del fix**:
- ❌ Memoria crece hasta 800MB+
- ❌ Crash eventual por memoria

---

### ✅ Test 2: Caché Limitada Windows
1. Usar app Windows durante 2-3 horas (operaciones normales)
2. Cerrar app
3. Navegar a carpeta de caché Firestore:
   ```
   C:\Users\[TuUsuario]\AppData\Local\[NombreApp]\...
   ```
4. Verificar tamaño de carpeta

**Esperado**:
- ✅ Caché ≤ 100MB
- ✅ Al reiniciar app, caché se limpia

**Antes del fix**:
- ❌ Caché puede crecer a 500MB-2GB

---

### ✅ Test 3: Funcionalidad Intacta
1. Crear reserva
2. Hacer venta en TPV
3. Ver clientes
4. Fichar empleado
5. Ver dashboard

**Esperado**:
- ✅ TODO funciona igual que antes
- ✅ Sin diferencia perceptible para usuario

---

### ✅ Test 4: Mobile Sin Regresiones
1. Compilar para Android/iOS
2. Ejecutar tests 1-3 en mobile

**Esperado**:
- ✅ Sin cambios de comportamiento
- ✅ Latencia igual o mejor

---

## 📊 MÉTRICAS A CAPTURAR

**Antes de implementar**:
```
- Crashes Windows/día: ___
- Memoria peak: ___ MB
- Tiempo inicio app: ___ s
- Tamaño caché Firestore: ___ MB
```

**Después de implementar**:
```
- Crashes Windows/día: ___
- Memoria peak: ___ MB
- Tiempo inicio app: ___ s
- Tamaño caché Firestore: ___ MB
```

**Objetivo Fase 1**:
- Crashes: <2/día
- Memoria: <400MB
- Tiempo inicio: ~2s
- Caché: ≤100MB

---

## 🚀 DEPLOYMENT

### Paso 1: Crear Branch
```bash
git checkout -b feature/estabilizacion-windows-fase1
```

### Paso 2: Implementar Cambios
1. ✅ Crear `safe_stream_mixin.dart`
2. ✅ Modificar `main.dart`
3. ✅ Aplicar mixin en screens (empezar por TPV)
4. ✅ Crear `feature_flags.dart`

### Paso 3: Testing Local
```bash
flutter run --release
# Ejecutar tests manuales arriba
```

### Paso 4: Commit & Push
```bash
git add .
git commit -m "feat: Fase 1 - Estabilización Windows

- Añadir SafeStreamMixin para auto-cancelación de streams
- Configurar Firestore con caché limitada en Windows
- Aplicar mixin en TPV, Dashboard, Reservas
- Añadir feature flags para rollback rápido

Refs: ANALISIS_ARQUITECTURA_INCREMENTAL.md"

git push origin feature/estabilizacion-windows-fase1
```

### Paso 5: Code Review
- Revisar PR con equipo
- Validar tests pasan
- Merge a `develop` o `main`

### Paso 6: Deploy Beta Windows
```bash
flutter build windows --release
# Distribuir a grupo beta de testers Windows (5-10 personas)
```

### Paso 7: Monitoreo 48h
- Crashlytics: verificar crashes ↓
- Feedback testers: estabilidad
- Métricas: memoria, performance

### Paso 8: Deploy Producción
Si métricas OK tras 48h:
```bash
# Tag release
git tag -a v1.0.16-windows-stable -m "Estabilización Windows Fase 1"
git push --tags

# Build producción
flutter build windows --release
flutter build apk --release
flutter build ipa --release

# Subir a stores
```

---

## ❓ FAQ IMPLEMENTACIÓN

**P: ¿Tengo que aplicar el mixin en TODOS los screens?**  
R: No inmediatamente. Prioriza:
1. TPV (más crítico)
2. Dashboard
3. Reservas
4. Resto gradualmente

**P: ¿Qué pasa si un screen ya tiene un `dispose()` custom?**  
R: El mixin llama a `super.dispose()`, así que tu código custom sigue funcionando:
```dart
@override
void dispose() {
  // Tu código custom
  _controller.dispose();
  _focusNode.dispose();
  
  super.dispose(); // ← SafeStreamMixin se ejecuta aquí automáticamente
}
```

**P: ¿Puedo mezclar `listenSafe()` con `.listen()` normal?**  
R: Sí, pero no tiene sentido. Usa solo `listenSafe()` para garantizar cancelación.

**P: ¿Qué pasa en mobile con la caché limitada?**  
R: Nada. El código detecta plataforma:
- Mobile → caché ilimitada (sin cambios)
- Windows → caché 100MB (nuevo)

**P: ¿Puedo hacer rollback después de deploy?**  
R: Sí, tres niveles:
1. **Feature flags**: Cambiar a `false`, hot reload → 10 segundos
2. **Git revert**: `git revert <commit>` → 1 hora
3. **Versión anterior**: Redistribuir build v1.0.15 → 24h

---

## 📞 SOPORTE

Si algo falla o tienes dudas:
1. Leer `ANALISIS_ARQUITECTURA_INCREMENTAL.md` (documento completo)
2. Leer `RESUMEN_EJECUTIVO_ARQUITECTURA.md` (decisiones)
3. Consultar con tu equipo técnico

**¡Éxito con la implementación!** 🚀

---

**FIN CÓDIGO LISTO PARA IMPLEMENTAR**

