# ✅ CHECKLIST VISUAL — Sprint 1 Semana

**Imprimir este documento y marcar con ✅ cada tarea completada**

---

## 📅 DÍA 1 — LUNES

### 🌅 MAÑANA (08:00 - 12:30)

#### Setup Inicial (1h)
- [ ] Crear branch: `feature/estabilizacion-1-semana`
- [ ] Crear carpeta: `lib/core/mixins/`
- [ ] Crear carpeta: `lib/core/config/`
- [ ] Crear carpeta: `test/integration/`
- [ ] Crear archivo: `safe_stream_mixin.dart` (copiar código)
- [ ] Crear archivo: `feature_flags.dart` (copiar código)
- [ ] Modificar: `main.dart` (añadir `_configurarFirestore()`)
- [ ] Compilar sin errores: `flutter build windows --debug`

---

#### Módulo 1: TPV Peluquería (2h)
- [ ] Abrir: `lib/features/tpv/pantallas/tpv_peluqueria_screen.dart`
- [ ] Añadir import: `safe_stream_mixin.dart`
- [ ] Añadir mixin a clase State
- [ ] Buscar: `StreamSubscription` (6 ocurrencias)
- [ ] Eliminar declaraciones StreamSubscription
- [ ] Buscar: `.listen(` (6 ocurrencias)
- [ ] Reemplazar por: `listenSafe(`
- [ ] Eliminar método: `dispose()` si solo cancela streams
- [ ] Compilar sin errores
- [ ] Ejecutar: `flutter run --release`
- [ ] Test manual: Abrir TPV → Cerrar → Repetir 20x
- [ ] Verificar memoria Task Manager: < 400MB ✅
- [ ] Commit: `feat(tpv): Migrar TPV Peluquería a SafeStreamMixin`

---

#### Módulo 2: Dashboard (1.5h)
- [ ] Abrir: `lib/features/dashboard/pantallas/pantalla_dashboard.dart`
- [ ] Añadir import: `safe_stream_mixin.dart`
- [ ] Añadir mixin (mantener TickerProviderStateMixin)
- [ ] Buscar: `StreamSubscription` (línea 76)
- [ ] Eliminar: `StreamSubscription? _notifSubscription;`
- [ ] Buscar: `_notifSubscription =` (línea 116)
- [ ] Reemplazar por: `listenSafe(`
- [ ] Buscar en dispose: `_notifSubscription?.cancel();`
- [ ] Eliminar esa línea
- [ ] Compilar sin errores
- [ ] Ejecutar: `flutter run --release`
- [ ] Test manual: Navegar dashboard → módulos → volver 20x
- [ ] Verificar memoria: < 400MB ✅
- [ ] Commit: `feat(dashboard): Migrar Dashboard a SafeStreamMixin`

---

### 🍕 ALMUERZO (12:30 - 13:30)

---

### 🌆 TARDE (13:30 - 16:30)

#### Módulo 3: Reservas (2h)
- [ ] Abrir: `modulo_reservas_screen.dart`
- [ ] Añadir mixin
- [ ] Reemplazar streams
- [ ] Compilar
- [ ] Test 20 ciclos
- [ ] Commit: `feat(reservas): Migrar Reservas a SafeStreamMixin`

**OPCIONAL**: Si sobra tiempo
- [ ] Abrir: `detalle_reserva_screen.dart`
- [ ] Aplicar mismo patrón

---

#### Testing Integración Día 1 (1h)
- [ ] Ejecutar en Windows: 30 min uso normal
- [ ] Ejecutar en Android: 30 min uso normal
- [ ] Memoria Windows: ___ MB (objetivo: < 400MB)
- [ ] Memoria Android: ___ MB
- [ ] Crashes: ___ (objetivo: 0)

---

#### 🎯 Decisión Go/No-Go Lunes
- [ ] ✅ 3 módulos migrados sin errores
- [ ] ✅ Testing OK en Windows y mobile
- [ ] ✅ Memoria estable
- [ ] ✅ 0 crashes en testing

**Si NO pasa**: Debug hasta resolver, prioridad máxima.

---

## 📅 DÍA 2 — MARTES

### 🌅 MAÑANA (08:00 - 12:00)

#### Módulo 4: Clientes (1h)
- [ ] Abrir: `modulo_clientes_screen.dart`
- [ ] Añadir mixin
- [ ] Reemplazar streams
- [ ] Test 20 ciclos
- [ ] Commit

---

#### Módulo 5: Fichajes (1.5h)
- [ ] Abrir: `pantalla_fichaje_empleado.dart`
- [ ] Añadir mixin
- [ ] Reemplazar streams
- [ ] Test 20 ciclos
- [ ] Abrir: `gestion_fichajes_screen.dart`
- [ ] Añadir mixin
- [ ] Test 20 ciclos
- [ ] Commit

---

#### Módulo 6: TPV Tienda (1.5h)
- [ ] Abrir: `tpv_tienda_screen.dart` (línea 117)
- [ ] Añadir mixin
- [ ] Reemplazar `_connectivitySub` con listenSafe
- [ ] Buscar otros streams
- [ ] Test 20 ciclos
- [ ] Commit

---

### 🍕 ALMUERZO (12:00 - 13:00)

---

### 🌆 TARDE (13:00 - 16:00)

#### Módulo 7: TPV Root (1h)
- [ ] Abrir: `tpv_root_screen.dart` (línea 68)
- [ ] Añadir mixin
- [ ] Reemplazar connectivity stream
- [ ] Test 20 ciclos
- [ ] Commit

---

#### Build Multiplataforma (1h)
- [ ] `flutter build windows --release` ✅
- [ ] `flutter build apk --release` ✅
- [ ] `flutter build ios --release` ✅ (o en Mac)

---

#### Testing Integración Día 2 (1h)
- [ ] Windows: 1h uso intensivo sin crash ✅
- [ ] Android: instalar APK, 30min testing ✅
- [ ] iOS: instalar IPA, 30min testing ✅

---

#### 🎯 Decisión Go/No-Go Martes
- [ ] 7/15 módulos migrados ✅
- [ ] Builds OK en 3 plataformas ✅
- [ ] Windows: 0 crashes en 1h ✅
- [ ] Mobile: sin regresiones ✅

---

## 📅 DÍA 3 — MIÉRCOLES

### 🌅 MAÑANA (08:00 - 12:00)

#### Módulo 8: Facturación (1h)
- [ ] Abrir: `modulo_facturacion_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Módulo 9: Empleados (1h)
- [ ] Abrir: `modulo_empleados_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Módulo 10: Servicios (1h)
- [ ] Abrir: `modulo_servicios_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Módulo 11: Pedidos (1h)
- [ ] Abrir: `modulo_pedidos_nuevo_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

### 🍕 ALMUERZO (12:00 - 13:00)

---

### 🌆 TARDE (13:00 - 16:00)

#### Módulo 12: WhatsApp (1h)
- [ ] Abrir: `modulo_whatsapp_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Build Beta + Distribución (2h)
- [ ] Commit final día 3
- [ ] Push a GitHub
- [ ] Build Windows beta
- [ ] Build Android APK beta
- [ ] Build iOS TestFlight beta
- [ ] Distribuir a testers:
  - [ ] Windows: 3 testers internos (email con APK)
  - [ ] Android: Play Console beta (5 testers)
  - [ ] iOS: TestFlight (5 testers)
- [ ] Crear formulario feedback Google Forms
- [ ] Enviar instrucciones a testers

---

#### 🎯 Decisión Go/No-Go Miércoles
- [ ] 12/15 módulos migrados ✅
- [ ] Builds beta distribuidos ✅
- [ ] Testers confirman recepción ✅
- [ ] Sin crashes en testing interno ✅

---

## 📅 DÍA 4 — JUEVES

### 🌅 MAÑANA (08:00 - 12:00)

#### Módulo 13: Nóminas (1h)
- [ ] Abrir: `modulo_nominas_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Módulo 14: Vacaciones (1h)
- [ ] Abrir: `vacaciones_screen.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Módulo 15: Contenido Web (1h)
- [ ] Abrir: `pantalla_contenido_web.dart`
- [ ] Aplicar patrón estándar
- [ ] Test + Commit

---

#### Revisión Final Código (1h)
- [ ] Buscar StreamSubscription restantes:
  ```bash
  grep -r "StreamSubscription" lib/features/ --include="*.dart"
  ```
- [ ] Contar archivos migrados:
  ```bash
  grep -r "with SafeStreamMixin" lib/features/ --include="*.dart" | wc -l
  ```
- [ ] Verificar: 15 archivos ✅
- [ ] Eliminar código comentado antiguo
- [ ] Formatear: `dart format lib/`
- [ ] Commit: `chore: Cleanup y formateo final`

---

### 🍕 ALMUERZO (12:00 - 13:00)

---

### 🌆 TARDE (13:00 - 16:00)

#### ⚡ Testing Marathon 3 Horas

**Hora 1: Windows Stress Test**
- [ ] Abrir app Windows
- [ ] Script stress_test.py ejecutando
- [ ] Monitoreo memoria cada 10 min:
  - [ ] 10min: ___ MB
  - [ ] 20min: ___ MB
  - [ ] 30min: ___ MB
  - [ ] 40min: ___ MB
  - [ ] 50min: ___ MB
  - [ ] 60min: ___ MB
- [ ] Crashes: ___ (objetivo: 0)
- [ ] Memoria final: ___ MB (objetivo: < 350MB)

---

**Hora 2: Android Battery + Memory Test**
- [ ] Instalar APK en dispositivo real
- [ ] Nota batería inicial: ____%
- [ ] Usar app normalmente 1 hora:
  - [ ] Crear 5 reservas
  - [ ] Hacer 3 ventas TPV
  - [ ] Ver clientes (10 min)
  - [ ] Revisar dashboard (10 min)
  - [ ] Ver facturación (10 min)
  - [ ] Repetir ciclo
- [ ] Nota batería final: ____%
- [ ] Consumo: ____% (objetivo: < 15%)
- [ ] Memoria promedio: ___ MB

---

**Hora 3: iOS Memory Profiler**
- [ ] Abrir Xcode Instruments
- [ ] Ejecutar con template "Leaks"
- [ ] Usar app 1 hora
- [ ] Leaks detectados: ___ (objetivo: 0)
- [ ] Memoria peak: ___ MB
- [ ] Capturas de pantalla guardadas ✅

---

#### Recopilar Feedback Testers Beta
- [ ] Revisar formulario Google Forms
- [ ] Respuestas recibidas: ___ / 13 testers
- [ ] Issues críticos: ___ (listar abajo)
- [ ] Issues menores: ___ (listar abajo)
- [ ] Sugerencias: ___ (listar abajo)

**Issues Críticos** (resolver mañana):
```
1. ___________________________________
2. ___________________________________
3. ___________________________________
```

**Issues Menores** (backlog):
```
1. ___________________________________
2. ___________________________________
```

---

#### 🎯 Decisión Go/No-Go Jueves
- [ ] 15/15 módulos migrados ✅
- [ ] Marathon test completado ✅
- [ ] Windows: 3h sin crash ✅
- [ ] Android: batería normal ✅
- [ ] iOS: 0 leaks ✅
- [ ] Feedback testers: >80% positivo ✅

**Si NO pasa**: Trabajar viernes AM en fixes críticos.

---

## 📅 DÍA 5 — VIERNES

### 🌅 MAÑANA (08:00 - 12:00)

#### Resolver Issues Críticos de Testers (2h)
- [ ] Issue #1: _____________________ ✅
- [ ] Issue #2: _____________________ ✅
- [ ] Issue #3: _____________________ ✅
- [ ] Re-test después de fixes ✅
- [ ] Commit fixes

---

#### Optimizaciones Finales (2h)
- [ ] Revisar ajustes `_configurarFirestore()` si necesario
- [ ] Añadir telemetría (opcional):
  ```dart
  // Firebase Analytics events
  analytics.logEvent(name: 'memory_usage', parameters: {...});
  ```
- [ ] Verificar que logs de debug estén solo en kDebugMode
- [ ] Optimizar imports (remove unused)
- [ ] Commit: `chore: Optimizaciones finales`

---

### 🍕 ALMUERZO (12:00 - 13:00)

---

### 🌆 TARDE (13:00 - 16:00)

#### Documentación (1h)
- [ ] Actualizar CHANGELOG.md
- [ ] Crear release notes usuario (español):
  ```
  Versión 1.1.0 - Mejoras de Estabilidad
  - Mejora significativa de estabilidad en Windows
  - Reducción de uso de memoria
  - Corrección de crashes ocasionales
  - Mejoras de performance general
  ```
- [ ] Crear release notes técnico (para equipo)
- [ ] Actualizar README si necesario
- [ ] Commit: `docs: Release notes v1.1.0`

---

#### Build Final Releases (1h)
- [ ] `git tag -a v1.1.0 -m "Release v1.1.0 - Estabilización"`
- [ ] `git push --tags`
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter build windows --release` ✅
- [ ] `flutter build appbundle --release` ✅
- [ ] `flutter build ipa --release` ✅
- [ ] Verificar ejecutables funcionan
- [ ] Generar checksums SHA256

---

#### Preparar Deploy Producción (1h)
- [ ] Subir Windows build a servidor interno
- [ ] Preparar Android AAB para Play Console
- [ ] Preparar IPA para App Store Connect
- [ ] Screenshots actualizados (si necesario)
- [ ] Verificar permisos stores
- [ ] Crear draft de release en stores
- [ ] Configurar staged rollout:
  - [ ] Android: 10% inicial
  - [ ] iOS: release manual (no auto)
  - [ ] Windows: 100% (o soft launch grupo cerrado)

---

#### 🎯 Decisión DEPLOY Viernes EOD
- [ ] ✅ Builds finales compilados sin errores
- [ ] ✅ Testing completo pass
- [ ] ✅ Feedback testers positivo (>80%)
- [ ] ✅ Issues críticos resueltos
- [ ] ✅ Documentación completa
- [ ] ✅ Stakeholders aprueban

**Decisión**:
- [ ] 🟢 **GO**: Deploy Sábado/Domingo/Lunes
- [ ] 🟡 **HOLD**: Retrasar 48h para fix menor
- [ ] 🔴 **NO-GO**: Problema crítico, iterar próxima semana

---

## 📅 DÍA 6-7 — FIN DE SEMANA (Opcional)

### 🟢 Si decisión fue GO:

#### Sábado AM
- [ ] Deploy Android Play Console (10% rollout)
- [ ] Deploy Windows (grupo beta ampliado o 100%)
- [ ] Deploy iOS TestFlight (external testing, 100 users)
- [ ] Configurar alertas Crashlytics
- [ ] Configurar dashboard monitoreo

---

#### Sábado PM - Domingo
- [ ] Monitoreo pasivo cada 6 horas
- [ ] Revisar Crashlytics: crashes ___
- [ ] Revisar Analytics: usuarios activos ___
- [ ] Revisar Firebase Performance ___
- [ ] Check feedback stores: reviews ___

---

#### Domingo EOD — Decisión Rollout Completo
- [ ] 24h sin crashes críticos ✅
- [ ] Feedback usuarios positivo ✅
- [ ] Métricas dentro de lo esperado ✅
- [ ] **DECISIÓN**: Ampliar a 100% Lunes

---

### 🟡 Si decisión fue HOLD:

#### Sábado
- [ ] Fix issue menor identificado
- [ ] Re-build
- [ ] Re-test
- [ ] Deploy Domingo

---

### 🔴 Si decisión fue NO-GO:

#### Fin de Semana
- [ ] Descanso
- [ ] Análisis post-mortem: ¿qué falló?
- [ ] Plan revisado para próxima semana
- [ ] Meeting equipo Lunes AM

---

## 📊 MÉTRICAS FINALES (Completar Viernes EOD)

| Métrica | Baseline | Objetivo | ✅ Real |
|---------|----------|----------|---------|
| Módulos migrados | 0/15 | 15/15 | ___ / 15 |
| Windows crashes/día | 5-10 | 0 | ___ |
| Memoria Windows peak | 800MB | <400MB | ___ MB |
| Tiempo sin crash | 30-60min | 8h+ | ___ h |
| Android batería 1h | - | <15% | ___% |
| iOS memory leaks | ? | 0 | ___ |
| Builds exitosos | - | 3/3 | ___ / 3 |
| Testers satisfechos | - | >90% | ___% |
| Lines código cambiado | - | ~500 | ___ |
| Tiempo total invertido | - | 32-40h | ___ h |

---

## ✅ CHECKLIST ARTEFACTOS FINALES

### Código
- [ ] Branch: `feature/estabilizacion-1-semana` ✅
- [ ] Commits: ~20 (1-2 por módulo) ✅
- [ ] Tag: `v1.1.0` ✅
- [ ] Merged to: `main` o `develop` ✅

### Builds
- [ ] `planeag_flutter_windows_v1.1.0.exe` ✅
- [ ] `planeag_flutter_android_v1.1.0.aab` ✅
- [ ] `planeag_flutter_ios_v1.1.0.ipa` ✅
- [ ] Checksums SHA256 ✅

### Documentación
- [ ] `CHANGELOG.md` actualizado ✅
- [ ] Release notes español ✅
- [ ] Release notes English (si necesario) ✅
- [ ] Documentación técnica ✅

### Testing
- [ ] Evidencia testing Windows (video/screenshots) ✅
- [ ] Evidencia testing Android ✅
- [ ] Evidencia testing iOS ✅
- [ ] Informe memoria Instruments ✅
- [ ] Feedback testers compilado ✅

### Deploy
- [ ] Play Console: draft listo ✅
- [ ] App Store Connect: build subido ✅
- [ ] Windows: ejecutable en servidor ✅
- [ ] Rollback plan documentado ✅

---

## 🎉 CELEBRACIÓN

**Si completaste todo lo anterior, ¡FELICIDADES!**

Has logrado:
- ✅ Estabilizar app en 3 plataformas
- ✅ Eliminar memory leaks críticos
- ✅ Reducir memoria 60%
- ✅ Deploy producción listo
- ✅ Base sólida para futuras mejoras

**Próximos pasos** (opcional, Fase 2):
- Repository Pattern (2-3 semanas)
- Dependency Injection (1-2 semanas)
- Cache Layer avanzado (1 semana)

---

## 📝 NOTAS PERSONALES

Usa este espacio para anotar observaciones, problemas encontrados, o ideas para mejoras futuras:

```
DÍA 1: ___________________________________________
_________________________________________________
_________________________________________________

DÍA 2: ___________________________________________
_________________________________________________
_________________________________________________

DÍA 3: ___________________________________________
_________________________________________________
_________________________________________________

DÍA 4: ___________________________________________
_________________________________________________
_________________________________________________

DÍA 5: ___________________________________________
_________________________________________________
_________________________________________________
```

---

**FIN DEL CHECKLIST**

**Última actualización**: 25 Mayo 2026  
**Versión**: 1.0  
**Estado**: ⏳ Pendiente / 🟢 En progreso / ✅ Completado

