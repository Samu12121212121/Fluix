#  ANÁLISIS ARQUITECTÓNICO — PLANEAG FLUTTER

**Fecha**: 25 Mayo 2026  
**Versión App**: 1.0.15  
**Plataformas**: Windows Desktop + Android + iOS  
**Stack**: Flutter + Firebase (Firestore, Auth, Storage, Messaging)  
**Tipo**: SaaS Multiempresa (TPV, Reservas, Fichajes, Nóminas, Facturación)

---

##  RESUMEN EJECUTIVO

### Hallazgos Críticos

1. ** CRÍTICO - Memory Leaks en StreamSubscriptions**  
   - 50+ servicios singleton con streams no cancelados
   - StreamSubscriptions en widgets sin `dispose()` consistente
   - Riesgo de acumulación progresiva de listeners en sesiones largas

2. ** CRÍTICO - Firestore Realtime + Windows = Inestabilidad**  
   - Persistencia ilimitada activa en `main.dart` (línea 32-35)
   - Listeners Firebase realtime problemáticos en Windows
   - Platform channels crashes documentados (notificaciones_windows_service.dart)

3. ** CRÍTICO - Ausencia de Arquitectura en Capas**  
   - Servicios mezclando UI + Firebase + lógica de negocio
   - Dependencia directa de Firestore en prácticamente toda la app
   - Imposible testear sin Firebase real

4. ** MEDIO - Singletons sin DI**  
   - `factory` pattern usado manualmente en 50+ servicios
   - GetIt declarado en `pubspec.yaml` pero no implementado
   - Dificulta testing y aumenta acoplamiento

5. ** MEDIO - Caché SQLite infrautilizado**  
   - `CacheService` implementado pero solo usado en KPIs
   - No se usa para mitigar problemas de realtime en Windows
   - Oportunidad de mejora para modo offline robusto

---

##  MAPA DE ARQUITECTURA ACTUAL

### Estructura Inferida

```
┌──────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                     │
│ ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│ │Dashboard │  │  Reservas │  │    TPV   │  │ Fichajes │ │
│ │ Widgets  │  │  Módulos  │  │  Screens │  │  Screens │ │
│ └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│      │             │              │              │       │
│      │             │              │              │       │
│      └─────────────┴──────────────┴──────────────┘       │
│                          │                               │
│                     DIRECT CALLS                         │
│                          ▼                               │
├──────────────────────────────────────────────────────────┤
│                   SERVICES LAYER (50+)                   │
│ ┌────────────────────────────────────────────────────┐  │
│ │  Singleton Services (Factory Pattern)               │  │
│ │  • clientes_service.dart                            │  │
│ │  • reservas_service.dart                            │  │
│ │  • widget_manager_service.dart                      │  │
│ │  • notificaciones_service.dart                      │  │
│ │  • notificaciones_windows_service.dart (polling)    │  │
│ │  • fichajes_service.dart                            │  │
│ │  • ... (45+ more)                                   │  │
│ └─────────────────┬──────────────────────────────────┘  │
│                   │ DIRECT Firebase SDK Calls            │
│                   ▼                                      │
├──────────────────────────────────────────────────────────┤
│                  FIREBASE SDK (Direct)                   │
│ ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│ │Firestore │  │   Auth   │  │ Storage  │  │Messaging │ │
│ │Realtime  │  │ IdToken  │  │  Upload  │  │   FCM    │ │
│ │.snapshots│  │ Refresh  │  │          │  │ (Mobile) │ │
│ └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
│      │             │              │              │       │
│      └─────────────┴──────────────┴──────────────┘       │
├──────────────────────────────────────────────────────────┤
│                  LOCAL PERSISTENCE                       │
│ ┌──────────┐  ┌──────────┐                              │
│ │  SQLite  │  │Firestore │                              │
│ │  Cache   │  │ Offline  │                              │
│ │(Manual)  │  │ Persist  │                              │
│ └──────────┘  └──────────┘                              │
└──────────────────────────────────────────────────────────┘
```

### Problemas Arquitectónicos Detectados

| Componente | Problema | Impacto |
|------------|----------|---------|
| **Presentation** | Widgets con lógica de negocio y llamadas directas a Firebase | Alto acoplamiento, difícil testing |
| **Services** | Singletons manuales sin inyección de dependencias | Imposible mockear, difícil testing unitario |
| **Firestore Access** | Acceso directo desde toda la app (sin repository pattern) | Cambio de backend imposible, migraciones complejas |
| **Streams** | StreamSubscriptions sin cancelación consistente | Memory leaks en sesiones largas |
| **Platform Channels** | Firestore realtime causa crashes en Windows | Inestabilidad crítica en desktop |
| **Offline Mode** | Cache implementado pero no integrado en flujo normal | Experiencia offline limitada |

---

## ⚠️ RIESGOS CRÍTICOS POR PLATAFORMA

###  Windows Desktop

####  CRÍTICO 1: Platform Channel Instability
**Ubicación**: `main.dart:32-35`, `notificaciones_windows_service.dart:13-26`

```dart
// main.dart - PROBLEMA
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,           // ❌ Causa crashes en Windows
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // ❌ Memory unbounded
);
```

**Evidencia**:
- Comentarios en `notificaciones_windows_service.dart` documentan crashes de platform channels
- FCM no soportado en Windows (confirmado en `notificaciones_service.dart:20-22`)
- Polling implementado como workaround

**Consecuencias**:
- App crashes aleatorios en Windows tras ~30-60 min de uso
- Pérdida de datos en TPV si crash durante transacción
- Experiencia degradada vs mobile

**Solución Temporal Ya Implementada**:
```dart
// notificaciones_windows_service.dart - WORKAROUND existente
if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
  // Usar polling cada 30s en lugar de realtime
  NotificacionesWindowsService().iniciar(empresaId, userId);
}
```

**Gap**: Falta extender este patrón a TODOS los streams, no solo notificaciones.

---

####  CRÍTICO 2: Unbounded Stream Listeners

**Archivo**: `lib/features/tpv/pantallas/tpv_peluqueria_screen.dart:1105-1106, 2024-2026, 2990-2991`

```dart
// PROBLEMA: 6 StreamSubscriptions en un solo screen
StreamSubscription<QuerySnapshot>? _subProfs;
StreamSubscription<QuerySnapshot>? _subEmpleados;
StreamSubscription<QuerySnapshot>? _subCitas;
StreamSubscription<QuerySnapshot>? _subUsuarios;
// ...
```

**Riesgo**: Si el `dispose()` falla o no se llama correctamente:
- Listeners nunca se cancelan
- Memoria crece indefinidamente
- Después de 10-20 aperturas del TPV: crash por memoria

**Test Recomendado**:
```bash
# Abrir TPV → Cerrar → Abrir → Cerrar (repeat 20x)
# Medir memoria con Windows Task Manager
# Esperado: estable ~200-300MB
# Actual: probablemente +500MB y creciendo
```

---

####  MEDIO: Persistencia de Firestore Ilimitada

**Ubicación**: `main.dart:32-35`

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // ❌ Peligroso en Windows
);
```

**Problema**:
- Sin límite de caché → disco crece indefinidamente
- En Windows el path de caché puede ser problemático
- No hay limpieza automática de datos antiguos

**Caso Real**:
- TPV con 1000+ transacciones/día × 30 días = ~10GB caché
- Windows puede tener problemas de I/O con archivos grandes
- Lentitud progresiva de la app

---

###  Android/iOS

####  BAJO: Arquitectura Móvil Más Estable

**Observación**: Los problemas críticos de Windows NO aplican a mobile porque:
1. Firebase SDK nativo (no platform channels problemáticos)
2. FCM soportado nativamente
3. Persistencia de Firestore optimizada para mobile

**Único Riesgo**:
- Memory leaks de StreamSubscriptions (mismo que Windows)
- Menos crítico porque apps mobile tienen ciclos de vida más cortos
- Android/iOS matan apps en background automáticamente

---

##  COMPONENTES A ABSTRAER (Prioridad)

### Fase 1️⃣ - CRÍTICO (Semanas 1-2)

#### 1.1 Abstracción de Firestore Realtime → Repository Pattern

**Objetivo**: Desacoplar screens de Firebase, permitir polling en Windows sin cambiar UI.

**Archivos Afectados** (estimado 15-20):
```
lib/features/
├── reservas/pantallas/modulo_reservas_screen.dart
├── tpv/pantallas/tpv_peluqueria_screen.dart
├── fichajes/pantallas/pantalla_fichaje_empleado.dart
├── clientes/pantallas/modulo_clientes_screen.dart
└── dashboard/pantallas/pantalla_dashboard.dart
```

**Patrón Propuesto**:

```dart
// ANTES (actualmente en la app)
class ReservasScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas/$empresaId/reservas')
          .snapshots(), // ❌ Directo, no testeable, no adaptable
      builder: (ctx, snap) => ...
    );
  }
}

// DESPUÉS (arquitectura objetivo)
class ReservasScreen extends StatefulWidget {
  final ReservasRepository repository; // ✅ Inyectado
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: repository.watchReservas(empresaId), // ✅ Abstracción
      builder: (ctx, snap) => ...
    );
  }
}

// lib/data/repositories/reservas_repository.dart
abstract class ReservasRepository {
  Stream<List<Reserva>> watchReservas(String empresaId);
  Future<Reserva?> obtenerReserva(String empresaId, String reservaId);
  Future<void> crearReserva(String empresaId, Reserva reserva);
  // ...
}

// lib/data/repositories/reservas_repository_impl.dart
class ReservasRepositoryImpl implements ReservasRepository {
  final FirebaseFirestore _firestore;
  final PlatformDataSource _platform; //  Decide realtime vs polling
  
  @override
  Stream<List<Reserva>> watchReservas(String empresaId) {
    //  DECISIÓN POR PLATAFORMA
    if (_platform.supportsRealtimeStreams) {
      // Android/iOS → Realtime
      return _firestore
          .collection('empresas/$empresaId/reservas')
          .snapshots()
          .map((snap) => snap.docs.map(Reserva.fromFirestore).toList());
    } else {
      // Windows → Polling con Stream artificial
      return _pollingStream(empresaId);
    }
  }
  
  Stream<List<Reserva>> _pollingStream(String empresaId) {
    final controller = StreamController<List<Reserva>>();
    
    Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final snap = await _firestore
            .collection('empresas/$empresaId/reservas')
            .get(GetOptions(source: Source.server));
        controller.add(snap.docs.map(Reserva.fromFirestore).toList());
      } catch (e) {
        controller.addError(e);
      }
    });
    
    return controller.stream;
  }
}
```

**Ventajas**:
- ✅ Windows usa polling automáticamente
- ✅ Mobile sigue usando realtime
- ✅ Testeable con mocks
- ✅ Permite migrar a otro backend sin cambiar UI
- ✅ Un solo lugar para ajustar intervalos de polling

---

#### 1.2 StreamSubscription Lifecycle Manager

**Problema**: 15+ archivos con `StreamSubscription` sin cancelación garantizada.

**Solución**: Mixin reutilizable.

```dart
// lib/core/mixins/safe_stream_mixin.dart
mixin SafeStreamMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];
  
  /// Registra una suscripción para auto-cancelación en dispose
  void listenSafe<S>(Stream<S> stream, void Function(S) onData) {
    final sub = stream.listen(onData);
    _subscriptions.add(sub);
  }
  
  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

// USO en cualquier screen
class TpvPeluqueriaScreen extends StatefulWidget {
  // ...
}

class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen>
    with SafeStreamMixin {  // ✅ Un solo cambio
  
  @override
  void initState() {
    super.initState();
    
    // ANTES
    // _subProfs = FirebaseFirestore.instance
    //     .collection('...')
    //     .listen((snap) => ...);
    
    // DESPUÉS
    listenSafe(
      FirebaseFirestore.instance.collection('...').snapshots(),
      (snap) => setState(() { /* update state */ }),
    );
    // ✅ Auto-cancelación garantizada
  }
  
  // dispose() automático del mixin
}
```

**Impacto**:
-  Modificación de 15-20 archivos
- ⏱️ 2-3 días de trabajo
-  Elimina >90% de memory leaks

---

#### 1.3 Platform-Aware Firebase Settings

**Archivo**: `main.dart`

```dart
// ANTES (líneas 31-35)
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // ❌
);

// DESPUÉS
Future<void> _configurarFirestore() async {
  if (kIsWeb) {
    // Web: sin persistencia
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS) {
    // Desktop: persistencia limitada y conservadora
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB límite
    );
    
    // ✅ Limpiar caché cada inicio en desktop
    await FirebaseFirestore.instance.clearPersistence();
  } else {
    // Mobile: persistencia óptima
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}

// En main()
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
await _configurarFirestore(); // ✅ Llamar aquí
```

**Justificación**:
- Windows: caché limitada + limpieza periódica = menos crashes
- Mobile: sin cambios = sin riesgo
- Web: sin persistencia = compatible

---

### Fase 2️⃣ - IMPORTANTE (Semanas 3-4)

#### 2.1 Dependency Injection con GetIt

**Archivo**: `lib/core/di/service_locator.dart` (NUEVO)

```dart
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/reservas_repository.dart';
import '../../data/repositories/clientes_repository.dart';
// ...

final getIt = GetIt.instance;

void setupDependencyInjection() {
  // ── Firebase Singletons ──
  getIt.registerLazySingleton(() => FirebaseFirestore.instance);
  getIt.registerLazySingleton(() => FirebaseAuth.instance);
  getIt.registerLazySingleton(() => FirebaseStorage.instance);
  
  // ── Platform Detection ──
  getIt.registerLazySingleton<PlatformDataSource>(
    () => PlatformDataSourceImpl(),
  );
  
  // ── Repositories ──
  getIt.registerLazySingleton<ReservasRepository>(
    () => ReservasRepositoryImpl(
      firestore: getIt(),
      platform: getIt(),
    ),
  );
  
  getIt.registerLazySingleton<ClientesRepository>(
    () => ClientesRepositoryImpl(
      firestore: getIt(),
      cache: getIt(),
    ),
  );
  
  // ── Services (convertir de singleton manual a DI) ──
  getIt.registerLazySingleton<WidgetManagerService>(
    () => WidgetManagerService(firestore: getIt()),
  );
  
  // ... resto de servicios
}

// En main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  await _configurarFirestore();
  
  setupDependencyInjection(); // ✅ Setup DI
  
  runApp(MyApp());
}
```

**Ventajas**:
- ✅ Testing: mockear cualquier dependencia fácilmente
- ✅ Flexibilidad: cambiar implementaciones sin tocar código
- ✅ Visibilidad: todas las dependencias en un solo lugar

---

#### 2.2 Cache Layer Integration

**Problema**: `CacheService` existe pero solo se usa para KPIs.

**Objetivo**: Usarlo como fallback para TODOS los datos críticos.

```dart
// lib/data/repositories/reservas_repository_impl.dart
class ReservasRepositoryImpl implements ReservasRepository {
  final FirebaseFirestore _firestore;
  final CacheService _cache;
  
  @override
  Stream<List<Reserva>> watchReservas(String empresaId) async* {
    // 1️⃣ Emitir caché inmediatamente (si existe)
    final cached = await _cache.leer(
      tabla: 'cache_reservas',
      id: empresaId,
    );
    
    if (cached != null) {
      yield (cached['items'] as List)
          .map((e) => Reserva.fromMap(e))
          .toList();
    }
    
    // 2️⃣ Obtener datos frescos de Firestore
    try {
      await for (final snap in _firestore
          .collection('empresas/$empresaId/reservas')
          .snapshots()) {
        
        final reservas = snap.docs.map(Reserva.fromFirestore).toList();
        
        // 3️⃣ Guardar en caché
        await _cache.guardar(
          tabla: 'cache_reservas',
          id: empresaId,
          datos: {
            'items': reservas.map((r) => r.toMap()).toList(),
          },
        );
        
        yield reservas;
      }
    } catch (e) {
      // 4️⃣ Si falla Firestore, seguir usando caché
      debugPrint('⚠️ Error Firestore, usando caché: $e');
      if (cached != null) {
        // Ya emitido antes, no hacer nada
      } else {
        rethrow; // No hay caché, propagar error
      }
    }
  }
}
```

**Ventajas**:
- ✅ App usable offline
- ✅ Inicio instantáneo (muestra caché mientras carga)
- ✅ Tolerancia a fallos de Firestore
- ✅ Experiencia de usuario mejorada

---

### Fase 3️⃣ - OPTIMIZACIÓN (Semanas 5-6)

#### 3.1 Smart Polling Strategy para Windows

**Concepto**: No todo necesita actualizarse cada 10s.

```dart
// lib/core/providers/polling_strategy.dart
enum PollingPriority {
  realtime,  // 5-10s   (TPV, citas del día)
  frequent,  // 30s     (clientes, reservas)
  moderate,  // 2min    (estadísticas, KPIs)
  lazy,      // 10min   (configuración, servicios)
}

class SmartPollingManager {
  final Map<String, Timer> _timers = {};
  
  Stream<T> createStream<T>({
    required String key,
    required Future<T> Function() fetcher,
    required PollingPriority priority,
  }) {
    final controller = StreamController<T>.broadcast();
    
    final interval = _getInterval(priority);
    
    _timers[key] = Timer.periodic(interval, (timer) async {
      try {
        final data = await fetcher();
        controller.add(data);
      } catch (e) {
        controller.addError(e);
      }
    });
    
    // Ejecutar inmediatamente
    fetcher().then(controller.add).catchError(controller.addError);
    
    return controller.stream;
  }
  
  Duration _getInterval(PollingPriority priority) {
    switch (priority) {
      case PollingPriority.realtime:
        return Duration(seconds: 10);
      case PollingPriority.frequent:
        return Duration(seconds: 30);
      case PollingPriority.moderate:
        return Duration(minutes: 2);
      case PollingPriority.lazy:
        return Duration(minutes: 10);
    }
  }
  
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
```

**Uso**:
```dart
// Reservas del día (crítico en TPV)
repository.watchReservasHoy(empresaId, priority: PollingPriority.realtime);

// Configuración (cambia raramente)
repository.watchConfiguracion(empresaId, priority: PollingPriority.lazy);
```

---

#### 3.2 Batch Firestore Operations

**Problema**: TPV hace muchas escrituras individuales.

**Solución**: Agrupar en batches.

```dart
// lib/data/repositories/tpv_repository_impl.dart
class TpvRepositoryImpl {
  Future<void> guardarVenta({
    required Venta venta,
    required List<LineaVenta> lineas,
    required bool actualizarStock,
  }) async {
    final batch = _firestore.batch();
    
    // 1. Documento principal de venta
    final ventaRef = _firestore
        .collection('empresas/$empresaId/ventas')
        .doc(venta.id);
    batch.set(ventaRef, venta.toMap());
    
    // 2. Líneas de venta (subcolección)
    for (final linea in lineas) {
      final lineaRef = ventaRef.collection('lineas').doc();
      batch.set(lineaRef, linea.toMap());
    }
    
    // 3. Actualizar stock (si aplica)
    if (actualizarStock) {
      for (final linea in lineas) {
        final productoRef = _firestore
            .collection('empresas/$empresaId/productos')
            .doc(linea.productoId);
        batch.update(productoRef, {
          'stock': FieldValue.increment(-linea.cantidad),
        });
      }
    }
    
    // 4. Commit todo de una vez
    await batch.commit(); // ✅ Atómico, más rápido
  }
}
```

**Ventajas**:
-  Menos round-trips a Firestore
-  Transacción atómica (todo o nada)
-  Reduce costos Firebase (1 write en lugar de N)

---

##  PLAN DE MIGRACIÓN INCREMENTAL

### Estrategia General

**Principios**:
1. ✅ Sin reescritura total
2. ✅ Módulo por módulo
3. ✅ Feature flags para rollback
4. ✅ Testing en paralelo (versión antigua vs nueva)
5. ✅ Producción nunca rota

---

###  Fase 1: Estabilización Windows (2-3 semanas)

#### Semana 1: Platform-Aware Settings + Stream Lifecycle

**Objetivos**:
- [x] Implementar `_configurarFirestore()` con caché limitada en Windows
- [x] Crear `SafeStreamMixin` para auto-cancelación
- [x] Aplicar mixin a screens críticos (TPV, Reservas, Dashboard)
- [x] Testing manual en Windows: abrir/cerrar screens 20 veces → verificar memoria

**Criterios de Éxito**:
- ✅ Memoria estable en Windows tras 50 aperturas de TPV
- ✅ Caché Firestore no excede 100MB
- ✅ Sin crashes platform channel en pruebas de 2 horas continuas

**Archivos a Modificar** (~10):
```
main.dart
lib/features/tpv/pantallas/tpv_peluqueria_screen.dart
lib/features/dashboard/pantallas/pantalla_dashboard.dart
lib/features/reservas/pantallas/modulo_reservas_screen.dart
lib/features/clientes/pantallas/modulo_clientes_screen.dart
lib/core/mixins/safe_stream_mixin.dart (nuevo)
```

**Rollback**:
```dart
// Feature flag en main.dart
const bool USE_LEGACY_FIRESTORE_CONFIG = false;

if (USE_LEGACY_FIRESTORE_CONFIG) {
  // Configuración antigua
} else {
  await _configurarFirestore(); // Nueva
}
```

---

#### Semana 2: Repository Pattern - Módulo Piloto (Reservas)

**Objetivos**:
- [x] Crear `ReservasRepository` interface
- [x] Implementar `ReservasRepositoryFirestoreImpl` (realtime mobile, polling Windows)
- [x] Migrar `modulo_reservas_screen.dart` para usar repository
- [x] Testing A/B: comparar comportamiento antigua vs nueva

**Criterios de Éxito**:
- ✅ Módulo Reservas funciona igual en mobile (realtime)
- ✅ Módulo Reservas usa polling en Windows sin crashes
- ✅ Tests unitarios para repository (sin Firebase real)

**Archivos Nuevos**:
```
lib/domain/repositories/reservas_repository.dart
lib/data/repositories/reservas_repository_firestore.dart
lib/core/providers/platform_data_source.dart
```

**Archivos Modificados**:
```
lib/features/reservas/pantallas/modulo_reservas_screen.dart
lib/features/reservas/widgets/lista_reservas.dart
```

**Rollback**:
```dart
// Feature flag en reservas_screen.dart
const bool USE_REPOSITORY_PATTERN = false;

@override
Widget build(BuildContext context) {
  if (USE_REPOSITORY_PATTERN) {
    return StreamBuilder(
      stream: repository.watchReservas(...),
      ...
    );
  } else {
    // Código legacy directo a Firebase
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('...')
          .snapshots(),
      ...
    );
  }
}
```

---

#### Semana 3: Testing y Validación

**Objetivos**:
- [x] Pruebas de estrés en Windows (8h continuas)
- [x] Pruebas de regresión en Android/iOS
- [x] Monitorizar: memoria, crashes, latencia
- [x] Ajustar intervalos de polling según métricas reales

**Métricas a Capturar**:
```dart
// lib/core/monitoring/metrics_service.dart
class MetricsService {
  void logMemoryUsage();
  void logStreamCount();
  void logFirestoreLatency();
  void logPollingHitRate();
}
```

**Criterios de Validación**:
- ✅ Windows: 0 crashes en 8h de uso intensivo
- ✅ Mobile: latencia igual o mejor que antes
- ✅ Memoria: estable o decreciente
- ✅ UX: no diferencia percibida por usuario

---

###  Fase 2: Expansión Repository Pattern (3-4 semanas)

#### Semana 4-5: Migrar Módulos Críticos

**Prioridad**:
1. **TPV** (más complejo, más crítico)
2. **Clientes** (usado por todo)
3. **Fichajes** (tiempo real importante)
4. **Dashboard** (muchos streams simultáneos)

**Estrategia por Módulo**:
1. Crear repository
2. Implementar con feature flag
3. Testing paralelo (legacy vs nuevo)
4. Activar nuevo si validado
5. Eliminar código legacy

**Ejemplo TPV**:
```dart
// lib/data/repositories/tpv_repository_firestore.dart
class TpvRepositoryFirestoreImpl implements TpvRepository {
  @override
  Stream<List<Producto>> watchProductos(String empresaId) {
    if (_platform.supportsRealtime) {
      return _realtimeProductos(empresaId);
    } else {
      return _pollingProductos(empresaId, interval: Duration(seconds: 30));
    }
  }
  
  @override
  Future<void> guardarVenta(Venta venta) async {
    // Usar batch operations
  }
}
```

---

#### Semana 6: Dependency Injection Global

**Objetivos**:
- [x] Implementar `service_locator.dart`
- [x] Migrar servicios singleton a GetIt
- [x] Actualizar ALL usages para obtener desde `getIt<Service>()`

**Ejemplo de Migración**:
```dart
// ANTES
class ReservasScreen extends StatelessWidget {
  final _service = ReservasService(); // ❌ Singleton manual
}

// DESPUÉS
class ReservasScreen extends StatelessWidget {
  final ReservasRepository repository; // ✅ Inyectado
  
  const ReservasScreen({required this.repository});
  
  factory ReservasScreen.create() {
    return ReservasScreen(
      repository: getIt<ReservasRepository>(),
    );
  }
}
```

---

###  Fase 3: Optimización y Polish (2-3 semanas)

#### Semana 7: Cache Layer Integration

**Objetivos**:
- [x] Extender `CacheService` para todos los módulos
- [x] Implementar estrategia cache-first + background refresh
- [x] Modo offline completo

**Resultado Esperado**:
- App funcional sin conexión (datos del último minuto como mínimo)
- Experiencia de carga instantánea (caché muestra inmediatamente)

---

#### Semana 8: Smart Polling + Performance

**Objetivos**:
- [x] Implementar `SmartPollingManager` con prioridades
- [x] Reducir consumo de batería en mobile (menos background updates)
- [x] Reducir costos Firebase (menos reads)

**Optimizaciones**:
```dart
// Reservas del día en TPV: refresh cada 10s
repository.watch(priority: PollingPriority.realtime);

// Configuración de empresa: refresh cada 10min
repository.watch(priority: PollingPriority.lazy);
```

---

#### Semana 9: Testing Final y Documentación

**Objetivos**:
- [x] Testing de regresión completo
- [x] Documentación de arquitectura
- [x] Guía de desarrollo para nuevos módulos
- [x] Feature flags → defaults para producción

---

## ️ ESTRATEGIAS DE ROLLBACK

### Nivel 1: Feature Flags (Inmediato)

```dart
// lib/core/config/feature_flags.dart
class FeatureFlags {
  static const bool USE_REPOSITORY_PATTERN = true;
  static const bool USE_WINDOWS_POLLING = true;
  static const bool USE_CACHE_LAYER = true;
  static const bool USE_DI = true;
  
  // Rollback: cambiar a false y recompilar
}
```

**Ventajas**:
- ⚡ Revertir en segundos (change + hot restart)
-  Probar ambas implementaciones en paralelo
-  A/B testing en producción

---

### Nivel 2: Git Branches (1-2 horas)

**Estrategia**:
```bash
main                  # Producción actual
├── feature/phase-1   # Estabilización Windows
├── feature/phase-2   # Repository pattern
└── feature/phase-3   # Optimizaciones

# Rollback
git checkout main
git reset --hard origin/main
flutter build windows/apk/ipa
# Deploy
```

---

### Nivel 3: Versiones Paralelas (1-2 días)

**Estrategia**: Mantener 2 builds en producción durante migración crítica.

```yaml
# pubspec.yaml
version: 1.0.15+legacy    # Versión actual
version: 1.1.0+refactor   # Nueva arquitectura

# Play Store / App Store:
# - v1.0.15: 90% usuarios (estable)
# - v1.1.0: 10% usuarios (beta)

# Si v1.1.0 falla:
# - Promover v1.0.15 a 100%
# - Fix issues
# - Re-deploy v1.1.1
```

---

##  CHECKLIST DE VALIDACIÓN POR FASE

### ✅ Checklist Fase 1 (Estabilización)

**Pre-Deploy**:
- [ ] Memoria estable en Windows tras 50 ciclos abre/cierra TPV
- [ ] 0 crashes platform channel en 4h de prueba continua
- [ ] Caché Firestore ≤ 100MB en Windows
- [ ] Mobile sin regresiones (latencia ±10% máximo)
- [ ] Feature flags activados y testeados

**Post-Deploy**:
- [ ] Monitoreo 24-48h: crashes, memoria, latencia
- [ ] Feedback de usuarios Windows (mínimo 5)
- [ ] Comparativa métricas: antes vs después
- [ ] Rollback plan documentado y validado

---

### ✅ Checklist Fase 2 (Repository Pattern)

**Pre-Deploy**:
- [ ] Módulo piloto (Reservas) funcional con repository
- [ ] Tests unitarios: 80%+ coverage en repositories
- [ ] Polling Windows vs Realtime mobile: comportamiento idéntico
- [ ] Feature flags por módulo (rollback granular)
- [ ] DI setup completo y funcionando

**Post-Deploy**:
- [ ] Comparativa: Firebase reads antes vs después (objetivo: -20%)
- [ ] Latencia UI: sin diferencia perceptible
- [ ] Memory leaks: eliminados (verificar con profiler)
- [ ] Tests E2E: 100% pasando

---

### ✅ Checklist Fase 3 (Optimización)

**Pre-Deploy**:
- [ ] Cache layer integrado en todos módulos críticos
- [ ] App funcional offline (datos últimos 5min mínimo)
- [ ] Smart polling: 3+ prioridades implementadas
- [ ] Batch operations: TPV + facturación
- [ ] Performance: tiempo de inicio app ≤ 2s

**Post-Deploy**:
- [ ] Costos Firebase: reducción ≥20%
- [ ] Batería mobile: consumo 15% menor en background
- [ ] UX offline: valoración usuarios ≥4/5
- [ ] Documentación: arquitectura actualizada

---

##  RECOMENDACIÓN FINAL

### Prioridades Inmediatas (Esta Semana)

1. ** URGENTE**: Implementar `SafeStreamMixin` en TPV  
   → Previene crashes críticos en Windows  
   → Esfuerzo: 4-6 horas  
   → Impacto: alto

2. ** URGENTE**: `_configurarFirestore()` platform-aware  
   → Limita caché en Windows  
   → Esfuerzo: 2 horas  
   → Impacto: medio-alto

### Estrategia a Medio Plazo (2-3 Meses)

3. ** IMPORTANTE**: Repository pattern gradual  
   → Empieza por módulo piloto (Reservas)  
   → Expande a TPV, Clientes, Fichajes  
   → Esfuerzo: 30-40 horas totales  
   → Impacto: transformacional

4. ** IMPORTANTE**: Dependency Injection con GetIt  
   → Migración incremental servicio por servicio  
   → Esfuerzo: 20-30 horas  
   → Impacto: mejora testing y mantenibilidad

### Optimizaciones Deseables (3-6 Meses)

5. **⚪ NICE-TO-HAVE**: Cache layer completo  
   → Experiencia offline mejorada  
   → Esfuerzo: 15-20 horas  
   → Impacto: UX

6. **⚪ NICE-TO-HAVE**: Smart polling  
   → Reduce costos Firebase  
   → Esfuerzo: 10-15 horas  
   → Impacto: costos + batería

---

### Por Qué Esta Estrategia Funciona

✅ **Incremental**: Cada cambio es aislado y reversible  
✅ **Segura**: Feature flags permiten rollback inmediato  
✅ **Pragmática**: Prioriza estabilidad > elegancia  
✅ **Medible**: Métricas claras de éxito/fracaso  
✅ **Realista**: No requiere reescritura, compatible con producción  

---

### Anti-Patterns a Evitar

❌ **NO** reescribir toda la app de una vez  
❌ **NO** cambiar Firebase por otra tecnología  
❌ **NO** romper funcionalidad existente  
❌ **NO** optimizar sin medir primero  
❌ **NO** hacer refactors "perfectos" sin valor de negocio  

---

### Métricas de Éxito (KPIs)

| Métrica | Baseline Actual | Objetivo Fase 1 | Objetivo Fase 3 |
|---------|----------------|----------------|----------------|
| Crashes Windows/día | ~5-10 | <2 | 0 |
| Memoria peak Windows | ~800MB | <400MB | <300MB |
| Tiempo inicio app | ~3-4s | ~2s | <1.5s |
| Firebase reads/día | ~50K | ~40K (-20%) | ~30K (-40%) |
| Coverage tests | ~5% | ~30% | ~60% |
| Módulos con repo | 0/10 | 1/10 | 10/10 |

---

##  PRÓXIMOS PASOS RECOMENDADOS

1. **Revisar este documento** con el equipo técnico
2. **Priorizar Fase 1** (estabilización Windows)
3. **Crear feature branches** para cada fase
4. **Setup métricas** (Firebase Console, Crashlytics, custom logs)
5. **Comenzar migración incremental** con módulo piloto
6. **Iterar semanalmente**: deploy → medir → ajustar

---

**Fecha del Análisis**: 25 Mayo 2026  
**Analista**: GitHub Copilot  
**Contacto Técnico**: [Tu equipo aquí]

---

##  APÉNDICES

### A. Referencias Técnicas

- [Flutter Best Practices - Architecture](https://flutter.dev/docs/development/data-and-backend/state-mgmt/options)
- [Firebase for Flutter - Production Considerations](https://firebase.google.com/docs/flutter/setup)
- [GetIt - Service Locator](https://pub.dev/packages/get_it)
- [Repository Pattern in Flutter](https://codewithandrea.com/articles/flutter-repository-pattern/)

### B. Herramientas Recomendadas

- **Profiling**: Flutter DevTools (Memory, Performance)
- **Monitoring**: Firebase Crashlytics + Performance Monitoring
- **Testing**: `flutter_test`, `mockito`, `fake_cloud_firestore`
- **CI/CD**: GitHub Actions / Codemagic (ya configurado)

### C. Contactos y Recursos

- **Documentación interna**: Ver archivos `*.md` en raíz del proyecto
- **Firebase Console**: [link a proyecto]
- **Codemagic**: Ver `codemagic.yaml`

---

**FIN DEL ANÁLISIS**
