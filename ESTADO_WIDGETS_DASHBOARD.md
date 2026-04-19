# 📊 ESTADO DE WIDGETS DEL DASHBOARD - CONEXIÓN A DATOS REALES

## ✅ WIDGETS YA CONECTADOS A DATOS REALES

### 1. **ModuloReservas** ✅
- **Archivo**: `lib/features/dashboard/widgets/modulo_reservas.dart`
- **Conexión**: StreamBuilder desde Firestore
- **Colección**: `empresas/{empresaId}/reservas`
- **KPIs mostrados**:
  - Pendientes (estado = PENDIENTE)
  - Confirmadas (estado = CONFIRMADA)
  - Canceladas (estado = CANCELADA)
  - Total de reservas
- **Estado**: ✅ **CONECTADO** - Muestra datos en tiempo real

### 2. **ModuloValoraciones** ✅
- **Archivo**: `lib/features/dashboard/widgets/modulo_valoraciones.dart`
- **Conexión**: StreamBuilder desde Firestore
- **Colección**: `empresas/{empresaId}/valoraciones`
- **KPIs mostrados**:
  - Promedio de calificaciones
  - Total de reseñas
  - Distribución por estrellas (1-5)
- **Funcionalidades**:
  - Muestra reseñas con avatar, nombre, fecha
  - Permite responder a reseñas
  - Integración con Google Reviews
- **Estado**: ✅ **CONECTADO** - Muestra datos en tiempo real

### 3. **ModuloEstadisticas** ✅
- **Archivo**: `lib/features/dashboard/widgets/modulo_estadisticas.dart`
- **Conexión**: StreamBuilder desde cache de Firestore
- **Colección**: `empresas/{empresaId}/cache/estadisticas`
- **KPIs mostrados**:
  - **Beneficio Neto**: Ingresos - Gastos (solo si tiene facturación)
  - **Reservas Confirmadas**: Del mes actual
  - **Nuevos Clientes**: Del mes actual vs anterior
  - **Valoración Media**: Promedio de todas las reseñas
  - **Ingresos/Gastos**: Del mes actual
  - **Servicios Activos**: Total de servicios
  - **Empleados Activos**: Total de empleados
- **Sistema de Cache**: Se recalcula automáticamente cada 5 minutos
- **Estado**: ✅ **CONECTADO** - Muestra datos en tiempo real con cache inteligente

### 4. **KPIsRatingWidget** ✅
- **Archivo**: `lib/features/dashboard/widgets/kpis_rating_widget.dart`
- **Conexión**: Servicio RatingHistorialService
- **Datos mostrados**:
  - Rating medio calculado localmente
  - Total de reseñas guardadas
  - Reseñas sin responder
  - Cambio bruto mensual
- **Estado**: ✅ **CONECTADO** - Calcula KPIs desde datos reales

### 5. **ModuloCitas** ✅
- **Archivo**: `lib/features/dashboard/widgets/modulo_citas.dart`
- **Conexión**: StreamBuilder desde Firestore
- **Colección**: `empresas/{empresaId}/citas`
- **Estado**: ✅ **CONECTADO** - Muestra citas en tiempo real

---

## ⚠️ WIDGETS CON DATOS HARDCODEADOS (ACTUALIZADOS)

### 1. **TarjetasResumen** ✅ ACTUALIZADO
- **Archivo**: `lib/features/dashboard/widgets/tarjetas_resumen.dart`
- **Estado ANTERIOR**: ❌ Valores hardcodeados (25 clientes, 48 reservas, $2,450)
- **Estado ACTUAL**: ✅ **CONECTADO** - Ahora usa StreamBuilder
- **Colección**: `empresas/{empresaId}/estadisticas/resumen`
- **KPIs mostrados**:
  - Total Clientes (con crecimiento vs mes anterior)
  - Reservas Mes (con crecimiento)
  - Ingresos Mes (con crecimiento)
  - Valoración Promedio (de Google Reviews)
- **Mejoras implementadas**:
  - Cálculo automático de % de crecimiento
  - Formato de moneda en euros (€)
  - Indicador de carga mientras actualiza
  - Valores reactivos en tiempo real

---

## 📋 KPIs RÁPIDOS - ¿QUÉ DATOS USAN?

### KPIs del ModuloEstadisticas

Los KPIs principales se calculan desde `estadisticas/resumen` que se genera automáticamente:

#### **Origen de los Datos**:

1. **Beneficio Neto** (solo con módulo Facturación)
   - **Fuente**: `facturas` (estado = PAGADA) - `gastos` (estado = pagado)
   - **Cálculo**: Ingresos reales - Gastos pagados del mes
   - **Actualización**: Cada 5 minutos (cache automático)

2. **Reservas Confirmadas**
   - **Fuente**: `reservas` (estado = CONFIRMADA, fecha del mes actual)
   - **Cálculo**: COUNT de reservas confirmadas
   - **Comparación**: vs mes anterior (% crecimiento)

3. **Nuevos Clientes**
   - **Fuente**: `clientes` (fecha_registro del mes actual)
   - **Cálculo**: COUNT de clientes nuevos
   - **Comparación**: vs mes anterior (% crecimiento)

4. **Valoración Media**
   - **Fuente**: `valoraciones` (todas las reseñas)
   - **Cálculo**: AVERAGE de campo calificacion/estrellas
   - **Incluye**: Google Reviews + reseñas manuales

5. **Ingresos Mes** (con módulo Facturación)
   - **Fuente**: `facturas` (estado = PAGADA, fecha del mes)
   - **Cálculo**: SUM de total de facturas pagadas

6. **Gastos Mes** (con módulo Facturación)
   - **Fuente**: `gastos` (estado = pagado, fecha del mes)
   - **Cálculo**: SUM de importe de gastos pagados

### KPIs de TarjetasResumen (Ahora Actualizado)

1. **Total Clientes**
   - **Fuente**: `estadisticas/resumen` → `total_clientes`
   - **Origen Real**: COUNT de colección `clientes`

2. **Reservas Mes**
   - **Fuente**: `estadisticas/resumen` → `reservas_mes`
   - **Origen Real**: COUNT de `reservas` del mes actual

3. **Ingresos Mes**
   - **Fuente**: `estadisticas/resumen` → `ingresos_mes`
   - **Origen Real**: SUM de `facturas` pagadas (si tiene facturación)

4. **Valoración Promedio**
   - **Fuente**: `estadisticas/resumen` → `valoracion_promedio` o `rating_google`
   - **Origen Real**: AVERAGE de `valoraciones`

### KPIs de ModuloReservas

1. **Pendientes**
   - **Fuente**: `reservas` (estado = PENDIENTE)
   - **Cálculo**: En tiempo real con WHERE clause

2. **Confirmadas**
   - **Fuente**: `reservas` (estado = CONFIRMADA)
   - **Cálculo**: En tiempo real con WHERE clause

3. **Canceladas**
   - **Fuente**: `reservas` (estado = CANCELADA)
   - **Cálculo**: En tiempo real con WHERE clause

4. **Total**
   - **Fuente**: `reservas` (todos los estados)
   - **Cálculo**: COUNT total

### KPIs de ModuloValoraciones

1. **Promedio de Estrellas**
   - **Fuente**: `valoraciones` (campo calificacion/estrellas)
   - **Cálculo**: En tiempo real, promedio de todas las reseñas

2. **Total Reseñas**
   - **Fuente**: `valoraciones`
   - **Cálculo**: COUNT total

3. **Distribución por Estrellas**
   - **Fuente**: `valoraciones`
   - **Cálculo**: COUNT agrupado por calificación (1-5 estrellas)

---

## 🔄 SISTEMA DE ACTUALIZACIÓN

### Datos en Tiempo Real (StreamBuilder)
- **ModuloReservas**: Actualización instantánea
- **ModuloValoraciones**: Actualización instantánea
- **TarjetasResumen**: Actualización instantánea
- **KPIsRatingWidget**: Se recalcula al iniciar

### Datos con Cache (Optimización de Performance)
- **ModuloEstadisticas**: 
  - Cache se recalcula automáticamente cada 5 minutos
  - También se puede forzar actualización manual (botón refresh)
  - Si cache tiene > 1 hora, se marca como obsoleto y recalcula en background
  - Sistema evita recálculos innecesarios para mejorar performance

---

## ✅ VERIFICACIÓN DE CONEXIÓN A DATOS REALES

### Checklist de Verificación

- [x] **ModuloReservas**: Conectado a `empresas/{empresaId}/reservas`
- [x] **ModuloValoraciones**: Conectado a `empresas/{empresaId}/valoraciones`
- [x] **ModuloEstadisticas**: Conectado a `empresas/{empresaId}/cache/estadisticas`
- [x] **KPIsRatingWidget**: Usa RatingHistorialService (datos reales)
- [x] **TarjetasResumen**: ✅ ACTUALIZADO - Conectado a `empresas/{empresaId}/estadisticas/resumen`
- [x] **ModuloCitas**: Conectado a `empresas/{empresaId}/citas`

### ¿Cómo Verificar que Funcionan?

1. **Crear una reserva de prueba**:
   - Ve al dashboard → Reservas
   - Añade una nueva reserva
   - Verifica que aparece instantáneamente en los KPIs

2. **Añadir una valoración**:
   - Ve al dashboard → Valoraciones
   - Añade una reseña manual
   - Verifica que el promedio se actualiza

3. **Ver estadísticas**:
   - Ve al dashboard → Estadísticas
   - Verifica que muestra datos reales
   - Si es la primera vez, espera 30-60 segundos mientras se calculan

4. **Forzar recálculo**:
   - En Estadísticas, pulsa el botón de refresh (⟳)
   - Verifica que se actualiza con mensaje "✅ Estadísticas actualizadas"

---

## 🎯 CONCLUSIÓN

### Estado General
✅ **TODOS LOS WIDGETS PRINCIPALES ESTÁN CONECTADOS A DATOS REALES**

### Widgets Actualizados en esta Sesión
1. ✅ **TarjetasResumen** - Migrado de hardcoded a StreamBuilder
2. ✅ **Google Reviews Service** - Migrado a Places API (New)

### Datos que Faltan o Requieren Configuración

1. **Google Reviews**:
   - ⚠️ Requiere configurar API Key y Place ID por empresa
   - Ver: `CONFIGURACION_GOOGLE_API.md`

2. **Facturación/Finanzas**:
   - ⚠️ KPI de Beneficio Neto solo aparece si el módulo está contratado
   - Se muestra tarjeta bloqueada si no está activo

3. **WordPress Analytics**:
   - ℹ️ Requiere configurar script de analytics en la web
   - Ver sección "Tráfico Web" en ModuloEstadisticas

---

## 📚 Archivos Relacionados

- `lib/features/dashboard/widgets/modulo_reservas.dart` - Widget de reservas
- `lib/features/dashboard/widgets/modulo_valoraciones.dart` - Widget de valoraciones
- `lib/features/dashboard/widgets/modulo_estadisticas.dart` - Widget de estadísticas
- `lib/features/dashboard/widgets/tarjetas_resumen.dart` - Tarjetas de resumen (actualizado)
- `lib/features/dashboard/widgets/kpis_rating_widget.dart` - KPIs de rating
- `lib/services/estadisticas_service.dart` - Servicio de cálculo de estadísticas
- `lib/services/estadisticas_cache_service.dart` - Sistema de cache automático
- `lib/services/google_reviews_service.dart` - Integración con Google Reviews (actualizado)
- `lib/services/rating_historial_service.dart` - Historial de ratings

---

**Fecha**: 19 Abril 2026  
**Estado**: ✅ Todos los widgets conectados a datos reales  
**Última actualización**: TarjetasResumen migrado de hardcoded a StreamBuilder

