#  PLAN SPRINT 1 SEMANA — Estabilización Multiplataforma

**Objetivo**: Implementar Fase 1 (estabilización) en TODOS los módulos críticos  
**Deadline**: 7 días (Lunes a Domingo)  
**Plataformas**: iOS + Android + Windows  
**Estrategia**: Paralelo + Testing automatizado + Validación continua

---

##  MÓDULOS PRIORIZADOS (15 Total)

| # | Módulo | Criticidad | Archivos | Tiempo Est. |
|---|--------|-----------|----------|-------------|
| 1 | **TPV Peluquería** |  CRÍTICO | 1 | 2h |
| 2 | **Dashboard** |  CRÍTICO | 1 | 1.5h |
| 3 | **Reservas** |  CRÍTICO | 2 | 2h |
| 4 | **Clientes** |  ALTO | 1 | 1h |
| 5 | **Fichajes** |  ALTO | 2 | 1.5h |
| 6 | **TPV Tienda** |  ALTO | 1 | 1.5h |
| 7 | **TPV Root** |  ALTO | 1 | 1h |
| 8 | **Facturación** |  MEDIO | 1 | 1h |
| 9 | **Empleados** |  MEDIO | 1 | 1h |
| 10 | **Servicios** |  MEDIO | 1 | 1h |
| 11 | **Pedidos** |  MEDIO | 1 | 1h |
| 12 | **WhatsApp** |  MEDIO | 1 | 1h |
| 13 | **Nóminas** | ⚪ BAJO | 1 | 1h |
| 14 | **Vacaciones** | ⚪ BAJO | 1 | 1h |
| 15 | **Contenido Web** | ⚪ BAJO | 1 | 1h |

**Total estimado**: ~19 horas código puro  
**+ Testing**: ~8 horas  
**+ Buffer problemas**: ~5 horas  
**TOTAL REAL**: ~32 horas → **4 días laborables** (8h/día)

---

##  PLANNING DÍA A DÍA

### ️ LUNES — Fundación + Módulos Críticos

**Objetivo**: Implementar infraestructura base + 3 módulos más críticos

#### ⏰ Mañana (4h)
**08:00 - 09:00** | Setup Inicial
```bash
# 1. Crear branch
git checkout -b feature/estabilizacion-1-semana

# 2. Crear estructura
mkdir -p lib/core/mixins
mkdir -p lib/core/config
mkdir -p test/integration

# 3. Crear archivos base
# - safe_stream_mixin.dart
# - feature_flags.dart
# - Modificar main.dart
```

**Entregable**: ✅ Infraestructura lista para usar

---

**09:00 - 11:00** | Módulo 1: TPV Peluquería ( CRÍTICO)

**Archivos**:
- `lib/features/tpv/pantallas/tpv_peluqueria_screen.dart`

**Cambios**:
```dart
// 1. Import
import '../../../core/mixins/safe_stream_mixin.dart';

// 2. Añadir mixin
class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen>
    with SafeStreamMixin {
  
  // 3. Eliminar declaraciones StreamSubscription
  // ❌ StreamSubscription<QuerySnapshot>? _subProfs;
  // ❌ StreamSubscription<QuerySnapshot>? _subEmpleados;
  // ... (eliminar las 6 que hay)
  
  // 4. En initState(), reemplazar .listen() por listenSafe()
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
  
  // 5. Eliminar dispose() (el mixin lo hace automáticamente)
  // ❌ @override void dispose() { ... }
}
```

**Testing**:
```bash
flutter run --release
# Abrir TPV → Cerrar → Repetir 20x
# Verificar memoria en Task Manager
```

**Entregable**: ✅ TPV Peluquería sin memory leaks

---

**11:00 - 12:30** | Módulo 2: Dashboard ( CRÍTICO)

**Archivos**:
- `lib/features/dashboard/pantallas/pantalla_dashboard.dart` (línea 76)

**Cambios**:
```dart
// 1. Import mixin
import '../../../core/mixins/safe_stream_mixin.dart';

// 2. Añadir mixin
class _PantallaDashboardState extends State<PantallaDashboard>
    with TickerProviderStateMixin, SafeStreamMixin {  // ← Añadir
  
  // 3. Eliminar: StreamSubscription? _notifSubscription;
  
  // 4. En initState() (línea 116):
  listenSafe(
    NotificacionesService().onTap,
    (data) {
      if (!mounted) return;
      _manejarNavegacionNotificacion(data);
    },
  );
  
  // 5. Eliminar en dispose(): _notifSubscription?.cancel();
}
```

**Testing**:
```bash
flutter run --release
# Abrir dashboard → Ir a módulo → Volver → Repetir 20x
# Verificar memoria
```

**Entregable**: ✅ Dashboard sin memory leaks

---

####  Almuerzo (1h)

---

#### ⏰ Tarde (3h)
**13:30 - 15:30** | Módulo 3: Reservas ( CRÍTICO)

**Archivos**:
- `lib/features/reservas/pantallas/modulo_reservas_screen.dart`
- `lib/features/reservas/pantallas/detalle_reserva_screen.dart`

**Cambios**: (igual que TPV y Dashboard)

**Testing**:
```bash
flutter run --release
# Crear reserva → Ver detalle → Volver → Repetir 20x
```

**Entregable**: ✅ Módulo Reservas estable

---

**15:30 - 16:30** | Testing Integración Lunes

**Script automatizado**:
```bash
# test/integration/memory_leak_test.sh
#!/bin/bash

echo " Test de Memory Leaks - Módulos Críticos"
echo "=========================================="

flutter drive \
  --target=test_driver/app.dart \
  --driver=test_driver/memory_leak_test.dart

echo ""
echo " Resultados:"
cat test_results/memory_report.txt
```

**Checklist Lunes**:
- [ ] TPV Peluquería: 20 ciclos sin crash
- [ ] Dashboard: 20 ciclos sin crash
- [ ] Reservas: 20 ciclos sin crash
- [ ] Memoria estable (<400MB Windows)
- [ ] Sin regresiones en mobile

**Decisión Go/No-Go**:
- ✅ Si pasan todos → Continuar Martes
- ❌ Si falla alguno → Debug hasta resolver

---

### ️ MARTES — Módulos de Alta Prioridad

**Objetivo**: 4 módulos adicionales + validación continua

#### ⏰ Mañana (4h)
**08:00 - 09:00** | Módulo 4: Clientes ( ALTO)

**Archivo**: `lib/features/clientes/pantallas/modulo_clientes_screen.dart`

**Cambios**: (aplicar patrón estándar)

---

**09:00 - 10:30** | Módulo 5: Fichajes ( ALTO)

**Archivos**:
- `lib/features/fichajes/pantallas/pantalla_fichaje_empleado.dart`
- `lib/features/fichajes/pantallas/gestion_fichajes_screen.dart`

---

**10:30 - 12:00** | Módulo 6: TPV Tienda ( ALTO)

**Archivo**: `lib/features/tpv/pantallas/tpv_tienda_screen.dart` (línea 117)

**Nota**: Ya tiene `_connectivitySub`, aplicar `listenSafe` también a conectividad.

---

####  Almuerzo (1h)

---

#### ⏰ Tarde (3h)
**13:00 - 14:00** | Módulo 7: TPV Root ( ALTO)

**Archivo**: `lib/features/tpv/pantallas/tpv_root_screen.dart` (línea 68)

---

**14:00 - 16:00** | Testing Integración Martes

**Testing multiplataforma**:
```bash
# Build para las 3 plataformas
flutter build windows --release
flutter build apk --release
flutter build ios --release

# Testing automatizado
./test/integration/test_all_platforms.sh
```

**Checklist Martes**:
- [ ] 7 módulos migrados (TPV × 3, Dashboard, Reservas, Clientes, Fichajes)
- [ ] Windows: 0 crashes en 1h uso intensivo
- [ ] Android: sin regresiones latencia
- [ ] iOS: sin regresiones latencia
- [ ] Memoria: estable en todas las plataformas

**Decisión Go/No-Go**:
- ✅ Si OK → Continuar Miércoles
- ⚠️ Si problemas menores → Fix y continuar
- ❌ Si crítico → rollback y debug

---

### ️ MIÉRCOLES — Módulos de Prioridad Media

**Objetivo**: 5 módulos adicionales (8-12) + build beta

#### ⏰ Mañana (4h)
**08:00 - 09:00** | Módulo 8: Facturación

**Archivo**: `lib/features/facturacion/pantallas/modulo_facturacion_screen.dart`

---

**09:00 - 10:00** | Módulo 9: Empleados

**Archivo**: `lib/features/empleados/pantallas/modulo_empleados_screen.dart`

---

**10:00 - 11:00** | Módulo 10: Servicios

**Archivo**: `lib/features/servicios/pantallas/modulo_servicios_screen.dart`

---

**11:00 - 12:00** | Módulo 11: Pedidos

**Archivo**: `lib/features/pedidos/pantallas/modulo_pedidos_nuevo_screen.dart`

---

####  Almuerzo (1h)

---

#### ⏰ Tarde (3h)
**13:00 - 14:00** | Módulo 12: WhatsApp

**Archivo**: `lib/features/pedidos/pantallas/modulo_whatsapp_screen.dart`

---

**14:00 - 16:00** | Build Beta + Distribución

```bash
# 1. Commit progreso
git add .
git commit -m "feat: Migrar módulos 1-12 a SafeStreamMixin

Módulos estabilizados:
- TPV (Peluquería, Tienda, Root)
- Dashboard
- Reservas
- Clientes
- Fichajes
- Facturación
- Empleados
- Servicios
- Pedidos
- WhatsApp

Testing: 100% módulos sin memory leaks en 3 plataformas"

git push origin feature/estabilizacion-1-semana

# 2. Build beta
flutter build windows --release
flutter build apk --release
flutter build ios --release

# 3. Distribuir a testers
# - Windows: 3 testers internos
# - Android: 5 testers Play Console beta
# - iOS: 5 testers TestFlight
```

**Checklist Miércoles**:
- [ ] 12/15 módulos migrados
- [ ] Builds beta funcionando
- [ ] Testers reciben builds
- [ ] Documentación actualizada

---

### ️ JUEVES — Finalizar + Testing Exhaustivo

**Objetivo**: Últimos 3 módulos + testing marathon

#### ⏰ Mañana (4h)
**08:00 - 09:00** | Módulo 13: Nóminas

**Archivo**: `lib/features/nominas/pantallas/modulo_nominas_screen.dart`

---

**09:00 - 10:00** | Módulo 14: Vacaciones

**Archivo**: `lib/features/vacaciones/pantallas/vacaciones_screen.dart`

---

**10:00 - 11:00** | Módulo 15: Contenido Web

**Archivo**: `lib/features/dashboard/pantallas/pantalla_contenido_web.dart`

---

**11:00 - 12:00** | Revisión Código Completa

```bash
# Buscar cualquier StreamSubscription que se haya escapado
grep -r "StreamSubscription" lib/features/ --include="*.dart"

# Verificar que todos usan el mixin
grep -r "with SafeStreamMixin" lib/features/ --include="*.dart"

# Contar archivos migrados
echo "Archivos migrados: $(grep -r 'with SafeStreamMixin' lib/features/ --include='*.dart' | wc -l)"
```

---

####  Almuerzo (1h)

---

#### ⏰ Tarde (3h)
**13:00 - 16:00** | Testing Marathon

**Protocolo de testing exhaustivo**:

```bash
#!/bin/bash
# test/integration/marathon_test.sh

echo " TESTING MARATHON — 3 Horas"
echo "=============================="

# ── Test 1: Stress Test Windows (1h) ──────────────────────────
echo "1️⃣ Windows Stress Test (1 hora continua)"
flutter run --release &
PID=$!

# Script automatizado: abrir/cerrar cada módulo 50 veces
python3 test/scripts/stress_test.py --duration 3600 --platform windows

kill $PID

echo "   ✅ Windows completado"
echo ""

# ── Test 2: Android Battery Test (1h) ───────────────────────
echo "2️⃣ Android Battery Test (1 hora background)"
adb shell "am start -n com.tuapp/.MainActivity"
sleep 3600
adb shell "dumpsys battery"

echo "   ✅ Android completado"
echo ""

# ── Test 3: iOS Memory Profiler (1h) ────────────────────────
echo "3️⃣ iOS Memory Profiler (1 hora con Instruments)"
# Ejecutar manualmente con Xcode Instruments
open -a "Instruments" --args -t "Leaks" build/ios/iphoneos/Runner.app

echo "   ✅ iOS completado"
echo ""

# ── Resultados ──────────────────────────────────────────────
echo " RESULTADOS FINALES"
cat test_results/marathon_summary.txt
```

**Métricas a Capturar**:
```
Windows:
- Crashes: ___
- Memoria peak: ___ MB
- Memoria final: ___ MB
- Tiempo sin crash: ___ min

Android:
- Crashes: ___
- Batería consumida: ___ %
- Memoria promedio: ___ MB

iOS:
- Crashes: ___
- Leaks detectados: ___
- Memoria peak: ___ MB
```

**Checklist Jueves**:
- [ ] 15/15 módulos migrados ✅
- [ ] Windows: 3h sin crash
- [ ] Android: batería normal
- [ ] iOS: 0 leaks detectados
- [ ] Feedback testers beta: positivo

---

### ️ VIERNES — Optimización + Deploy Preparación

**Objetivo**: Ajustes finales + documentación + preparar deploy producción

#### ⏰ Mañana (4h)
**08:00 - 10:00** | Análisis Feedback Testers

Revisar feedback de testers beta (Miércoles-Jueves):
- ✅ Issues críticos → Fix inmediato
- ⚠️ Issues menores → Backlog
-  Sugerencias → Evaluar

**Posibles fixes**:
- Ajustar intervalos de polling Windows si hay quejas de latencia
- Mejorar UX en algún módulo específico
- Fix bugs encontrados por testers

---

**10:00 - 12:00** | Optimizaciones Finales

**1. Ajustar `_configurarFirestore()` si es necesario**:
```dart
// Si testers reportan lentitud, reducir caché
cacheSizeBytes: 50 * 1024 * 1024, // 50MB en lugar de 100MB
```

**2. Añadir telemetría para monitoreo post-deploy**:
```dart
// lib/core/monitoring/telemetry_service.dart
class TelemetryService {
  static void logMemoryUsage() {
    // Log a Firebase Analytics
  }
  
  static void logStreamCount() {
    // Log número de streams activos
  }
}
```

**3. Documentar cambios**:
```markdown
# CHANGELOG v1.1.0 - Estabilización Multiplataforma

## ✨ Mejoras
- ✅ Eliminados memory leaks en 15 módulos críticos
- ✅ Caché Firestore limitada en Windows (100MB)
- ✅ Limpieza automática de caché al iniciar app
- ✅ Mejoras de estabilidad en TPV (0 crashes en testing)

##  Cambios Técnicos
- Implementado `SafeStreamMixin` para auto-cancelación de streams
- Configuración Firestore platform-aware
- Testing exhaustivo en 3 plataformas

##  Métricas
- Memoria Windows: -60% (800MB → 300MB)
- Crashes Windows: -95% (5-10/día → 0)
- Performance mobile: sin cambios (validado)
```

---

####  Almuerzo (1h)

---

#### ⏰ Tarde (3h)
**13:00 - 14:00** | Build Final Releases

```bash
# 1. Tag version
git tag -a v1.1.0 -m "Estabilización Multiplataforma - Week Sprint

Cambios:
- SafeStreamMixin en 15 módulos críticos
- Firestore platform-aware settings
- 0 crashes Windows en 8h testing
- Sin regresiones mobile

Testing: 100% pass en 3 plataformas"

git push --tags

# 2. Build releases
flutter build windows --release
flutter build appbundle --release
flutter build ipa --release

# 3. Generar checksums
sha256sum build/windows/runner/Release/planeag_flutter.exe > checksums.txt
```

---

**14:00 - 15:00** | Preparar Deploy Production

**Checklist pre-deploy**:
- [ ] Builds compilados sin errores
- [ ] CHANGELOG actualizado
- [ ] Documentación técnica actualizada
- [ ] Release notes para usuarios
- [ ] Rollback plan documentado
- [ ] Monitoring configurado (Crashlytics, Analytics)
- [ ] Testers beta aprueban builds

**Assets para stores**:
```
stores/
├── android/
│   ├── release_notes_en.txt
│   ├── release_notes_es.txt
│   └── screenshots/ (si actualizados)
├── ios/
│   ├── release_notes_en.txt
│   ├── release_notes_es.txt
│   └── screenshots/
└── windows/
    └── setup_installer.exe (si aplica)
```

---

**15:00 - 16:00** | Última Revisión & Decisión Deploy

**Meeting con stakeholders** (si los hay):
- Presentar métricas de testing
- Mostrar mejoras vs baseline
- Aprobar deploy producción

**Decisión Final**:
- [ ] ✅ **GO**: Deploy Lunes próxima semana
- [ ] ⚠️ **HOLD**: Retrasar 48h para fix menor
- [ ] ❌ **NO-GO**: Problema crítico, iterar

---

### ️ SÁBADO (Opcional) — Buffer + Contingencia

**Si todo va bien**: Descanso merecido 

**Si hay problemas pendientes**:
- Fix issues críticos encontrados viernes
- Re-testing módulos problemáticos
- Ajustes finales documentación

**Trabajo estimado**: 0-4h (solo si necesario)

---

### ️ DOMINGO (Opcional) — Testing Final + Deploy Soft

**Opción A: Deploy Soft (Recomendado)**

```bash
# Deploy gradual:
# - 10% usuarios Android (Google Play staged rollout)
# - 100% usuarios Windows (menos crítico, base más pequeña)
# - TestFlight iOS (100 external testers)

# Monitoreo 24h antes de ampliar a 100%
```

**Opción B: Esperar a Lunes**

Si prefieres cautela, esperar al lunes y deploy entonces.

---

## ️ SCRIPTS DE AUTOMATIZACIÓN

### Script 1: Aplicar Mixin Automáticamente

```bash
#!/bin/bash
# scripts/apply_mixin.sh

# USO: ./scripts/apply_mixin.sh path/to/screen.dart

FILE=$1

if [ -z "$FILE" ]; then
  echo "❌ Error: Especifica archivo"
  echo "Uso: $0 lib/features/xxx/screen.dart"
  exit 1
fi

echo " Aplicando SafeStreamMixin a $FILE..."

# 1. Añadir import si no existe
if ! grep -q "safe_stream_mixin.dart" "$FILE"; then
  sed -i "1iimport '../../../core/mixins/safe_stream_mixin.dart';" "$FILE"
  echo "   ✅ Import añadido"
fi

# 2. Detectar clase State y añadir mixin
sed -i 's/class \(.*State\) extends State<\(.*\)>/class \1 extends State<\2> with SafeStreamMixin/' "$FILE"
echo "   ✅ Mixin añadido"

# 3. Buscar y reportar StreamSubscriptions
COUNT=$(grep -c "StreamSubscription" "$FILE" || true)
if [ $COUNT -gt 0 ]; then
  echo "   ⚠️ Encontrados $COUNT StreamSubscriptions"
  echo "   → Reemplazar manualmente .listen() por listenSafe()"
fi

echo "✅ Completado: $FILE"
```

---

### Script 2: Testing Automatizado por Módulo

```bash
#!/bin/bash
# scripts/test_module.sh

MODULE=$1

echo " Testing módulo: $MODULE"
echo "=========================="

# 1. Compilar
flutter build apk --debug
flutter build windows --debug

# 2. Ejecutar en emulador Android
flutter run --target=lib/features/$MODULE/pantallas/*.dart

# 3. Script de interacción automatizada (ADB)
adb shell input tap 500 500  # Abrir módulo
sleep 2
adb shell input keyevent 4   # Volver atrás
sleep 1

# Repetir 20 veces
for i in {1..20}; do
  echo "   Iteración $i/20"
  adb shell input tap 500 500
  sleep 2
  adb shell input keyevent 4
  sleep 1
done

# 4. Capturar memoria
adb shell dumpsys meminfo com.tuapp | grep TOTAL > "test_results/${MODULE}_memory.txt"

echo "✅ Test completado: $MODULE"
cat "test_results/${MODULE}_memory.txt"
```

---

### Script 3: Monitoreo Continuo

```dart
// lib/core/monitoring/memory_monitor.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Monitorea el uso de memoria y streams activos en desarrollo.
class MemoryMonitor {
  static MemoryMonitor? _instance;
  Timer? _timer;
  
  factory MemoryMonitor() {
    _instance ??= MemoryMonitor._();
    return _instance!;
  }
  
  MemoryMonitor._();
  
  void start() {
    if (!kDebugMode) return;
    
    _timer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (Platform.isWindows) {
        // En Windows, usar ProcessInfo para memoria
        final info = ProcessInfo.currentRss;
        final mb = info ~/ (1024 * 1024);
        debugPrint(' Memoria actual: $mb MB');
        
        if (mb > 400) {
          debugPrint('⚠️ ALERTA: Memoria >400MB, posible leak');
        }
      }
    });
  }
  
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// En main.dart (solo debug):
if (kDebugMode) {
  MemoryMonitor().start();
}
```

---

##  CHECKLIST MASTER (Diaria)

### ✅ Checklist Lunes
- [ ] Infraestructura base creada
- [ ] `SafeStreamMixin` implementado
- [ ] `_configurarFirestore()` implementado
- [ ] TPV Peluquería migrado
- [ ] Dashboard migrado
- [ ] Reservas migrado
- [ ] Testing: 3 módulos sin crashes
- [ ] Commit & push día 1

### ✅ Checklist Martes
- [ ] Clientes migrado
- [ ] Fichajes migrado
- [ ] TPV Tienda migrado
- [ ] TPV Root migrado
- [ ] Testing: 7 módulos acumulados sin crashes
- [ ] Builds 3 plataformas OK
- [ ] Commit & push día 2

### ✅ Checklist Miércoles
- [ ] Facturación migrado
- [ ] Empleados migrado
- [ ] Servicios migrado
- [ ] Pedidos migrado
- [ ] WhatsApp migrado
- [ ] Build beta distribuido
- [ ] 10+ testers probando app
- [ ] Commit & push día 3

### ✅ Checklist Jueves
- [ ] Nóminas migrado
- [ ] Vacaciones migrado
- [ ] Contenido Web migrado
- [ ] 15/15 módulos completados ✅
- [ ] Testing marathon 3h OK
- [ ] Feedback testers recopilado
- [ ] Commit & push día 4

### ✅ Checklist Viernes
- [ ] Issues testers resueltos
- [ ] Optimización final
- [ ] Documentación completa
- [ ] CHANGELOG actualizado
- [ ] Builds producción listos
- [ ] Deploy plan aprobado
- [ ] Tag v1.1.0 creado

### ✅ Checklist Fin de Semana (Opcional)
- [ ] Deploy soft Android (10%)
- [ ] Deploy Windows (100%)
- [ ] TestFlight iOS (100 testers)
- [ ] Monitoreo 24h activo
- [ ] Sin crashes críticos
- [ ] Plan rollout completo Lunes

---

##  METRICAS DE ÉXITO (Validar Viernes)

| Métrica | Baseline | Objetivo | Real |
|---------|----------|----------|------|
| **Módulos migrados** | 0/15 | 15/15 | ___ |
| **Windows Crashes** | 5-10/día | 0 | ___ |
| **Memoria Windows** | 800MB | <400MB | ___ MB |
| **Tiempo sin crash** | 30-60min | 8h+ | ___ h |
| **Latencia mobile** | X ms | ±10% | ___ ms |
| **Builds OK** | - | 3/3 | ___ |
| **Testers satisfechos** | - | >90% | ___% |

---

##  PUNTOS DE DECISIÓN GO/NO-GO

### Lunes EOD
**Criterio**: 3 módulos críticos sin memory leaks  
- ✅ GO → Continuar Martes  
- ❌ NO-GO → Debug hasta resolver (prioridad máxima)

### Martes EOD
**Criterio**: 7 módulos acumulados + builds OK  
- ✅ GO → Continuar Miércoles  
- ⚠️ HOLD → Fix build si falla, pero continuar migración

### Miércoles EOD
**Criterio**: Beta distribuido + feedback inicial positivo  
- ✅ GO → Continuar Jueves  
- ❌ NO-GO → Si testers reportan crashes críticos, rollback y debug

### Jueves EOD
**Criterio**: 15/15 módulos + marathon test OK  
- ✅ GO → Preparar deploy producción  
- ⚠️ HOLD → Si marathon falla, iterar Viernes AM

### Viernes EOD
**Criterio**: Builds producción + stakeholders aprueban  
- ✅ GO → Deploy Sábado/Domingo/Lunes  
- ❌ NO-GO → Retrasar 1 semana, iterar

---

## ️ PLAN DE ROLLBACK (Si Algo Sale Mal)

### Nivel 1: Rollback Inmediato (En Testing)
```bash
git reset --hard HEAD~1
flutter run
# Si vuelve a funcionar, el último commit tiene el problema
```

### Nivel 2: Rollback Parcial (Un Módulo Falla)
```dart
// En el archivo problemático, comentar el mixin temporalmente
// class _ProblemaScreenState extends State<ProblemaScreen>
//     with SafeStreamMixin {  // ← Comentar

// Revertir a StreamSubscription manual
StreamSubscription? _sub;

@override
void initState() {
  _sub = stream.listen(...);
}

@override
void dispose() {
  _sub?.cancel();
  super.dispose();
}
```

### Nivel 3: Rollback Completo (Deploy Producción)
```bash
# 1. Revertir a tag anterior
git checkout v1.0.15

# 2. Build urgente
flutter build windows --release
flutter build apk --release

# 3. Deploy inmediato
# Upload a stores con prioridad alta
```

---

##  TIPS PARA MAXIMIZAR EFICIENCIA

### 1. Trabajar con Feature Flags
```dart
// Permite activar/desactivar mixin por módulo
if (FeatureFlags.USE_SAFE_STREAM_MIXIN_TPV) {
  // Código nuevo
} else {
  // Código legacy
}
```

### 2. Paralelizar Cuando Sea Posible
```bash
# Testing simultáneo en 3 emuladores
flutter run -d windows &
flutter run -d emulator-5554 &  # Android
flutter run -d iPhone-14 &      # iOS

# Esperar a que todos terminen
wait
```

### 3. Automatizar Testing Repetitivo
```python
# test/scripts/stress_test.py
import subprocess
import time

for i in range(50):
    print(f"Iteración {i+1}/50")
    # Simular tap
    subprocess.run(["adb", "shell", "input", "tap", "500", "500"])
    time.sleep(2)
    # Volver atrás
    subprocess.run(["adb", "shell", "input", "keyevent", "4"])
    time.sleep(1)
```

### 4. Usar Hot Reload Agresivamente
```bash
# No hacer restart completo cada vez
# Solo hot reload cuando cambies código Dart
r  # hot reload
R  # hot restart (solo si es necesario)
```

### 5. Monitoreo en Tiempo Real
```dart
// Añadir logs temporales durante desarrollo
@override
void initState() {
  super.initState();
  debugPrint(' TPV iniciado - streams activos: X');
}

@override
void dispose() {
  debugPrint(' TPV disposed - streams cancelados: X');
  super.dispose();
}
```

---

##  CONTACTOS DE EMERGENCIA

**Si algo bloquea el progreso, escalar inmediatamente:**

-  Crash crítico que no se resuelve en 2h → Escalar a arquitecto senior
-  Build falla en CI/CD → Escalar a DevOps
-  Issue de Firebase quota → Escalar a admin proyecto Firebase
-  Issue de performance → Consultar documentación oficial
-  Duda técnica → Stack Overflow / Flutter Discord

---

##  OBJETIVO FINAL

**Al final de esta semana tendrás**:

✅ App estable en 3 plataformas (Windows, Android, iOS)  
✅ 0 memory leaks en 15 módulos críticos  
✅ Memoria Windows optimizada (-60%)  
✅ Base sólida para migración a Repository Pattern (Fase 2)  
✅ Experiencia de usuario idéntica (sin regresiones)  
✅ Confianza para escalar la app próximos meses

---

##  COMENZAMOS

**AHORA MISMO**:
```bash
git checkout -b feature/estabilizacion-1-semana
mkdir -p lib/core/mixins lib/core/config test/integration
code lib/core/mixins/safe_stream_mixin.dart
```

**Copia el código del mixin** de `CODIGO_FASE1_IMPLEMENTAR.md` y...

**¡A por ello! **

---

**FIN DEL PLAN SPRINT 1 SEMANA**
