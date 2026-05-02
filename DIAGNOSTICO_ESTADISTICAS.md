# 🔍 Diagnóstico: Estadísticas no muestran datos

## Problema
Las secciones **"Métricas de Negocio"** y **"Rendimiento del Negocio"** aparecen vacías o con valores en 0.

## Causa raíz
Las estadísticas dependen del documento de cache en Firestore:

```
/empresas/{empresaId}/cache/estadisticas
```

Este documento se genera automáticamente la primera vez que abres el módulo de estadísticas, y luego se actualiza cada hora. Si está vacío o no existe, verás valores 0.

## Campos que debe contener el cache

### KPIs Principales
- `ingresos_facturas_mes` (double)
- `gastos_pagados_mes` (double)
- `beneficio_neto_mes` (double)
- `reservas_confirmadas` (int)
- `reservas_mes` (int)
- `reservas_mes_anterior` (int)
- `nuevos_clientes_mes` (int)
- `nuevos_clientes_mes_anterior` (int)
- `total_clientes` (int)
- `valoracion_promedio` (double)

### Métricas de Negocio
- `reservas_completadas` (int)
- `reservas_pendientes` (int)
- `clientes_activos` (int)
- `total_servicios_activos` (int)
- `total_empleados_activos` (int)
- `pedidos_mes` (int)

### Rendimiento
- `tasa_conversion` (double) — %
- `tasa_cancelacion` (double) — %
- `valor_medio_reserva` (double) — €
- `servicio_mas_popular` (string)
- `servicio_mas_rentable` (string)
- `empleado_mas_activo` (string)
- `empleados_propietarios` (int)
- `empleados_admin` (int)
- `empleados_staff` (int)

## Cómo diagnosticar

### 0. Reservas no aparecen en "Próximos 3 Días" ⚠️
**Síntoma:** Tienes reservas confirmadas hoy pero el widget muestra "0 eventos".

**Causa más común:** El widget busca reservas por el campo `fecha_hora`, pero tus reservas tienen el campo `fecha` en su lugar.

**Diagnóstico rápido:**
1. Ve a Firebase Console → `empresas/{tuEmpresaId}/reservas`
2. Abre cualquier reserva de hoy
3. Verifica que tenga el campo `fecha_hora` como `Timestamp`
4. Si solo tiene `fecha` (string o Timestamp), **ese es el problema**

**Solución:**
- **Opción 1 (recomendada):** Migra todas las reservas para usar `fecha_hora`:
  ```javascript
  // Script a ejecutar en Firebase Console
  db.collection('empresas/{tuEmpresaId}/reservas').get().then(snap => {
    snap.forEach(doc => {
      if (!doc.data().fecha_hora && doc.data().fecha) {
        doc.ref.update({ fecha_hora: doc.data().fecha });
      }
    });
  });
  ```

- **Opción 2 (temporal):** Si no puedes migrar ahora, el widget ahora tiene fallback a `fecha`, así que debería funcionar con la última actualización.

**Índice requerido:**
Si ves el error "The query requires an index", es porque falta el índice de Firestore para `fecha_hora`. Copia el enlace de la consola de errores y créalo automáticamente (tarda ~2 minutos).

### 1. Ver el cache en Firebase Console
```
Firestore → empresas → {tu empresaId} → cache → estadisticas
```

**Si el documento existe:**
- Verifica que tenga los campos listados arriba
- Revisa la fecha de `ultima_actualizacion` y `fecha_calculo` (debe ser reciente)

**Si el documento NO existe:**
- El cálculo automático falló. Comprueba que tu empresa tenga datos en las colecciones de origen:
  - `transacciones` (para ingresos/gastos)
  - `reservas` (para reservas)
  - `clientes` (para clientes)
  - `facturas` (si tienes Pack Gestión)
  - `pedidos` (si tienes Pack Tienda)

### 2. Forzar recálculo manual
En la app:
1. Ve al módulo de **Estadísticas**
2. Pulsa el botón de **refresh** (icono ↻) en la esquina superior derecha
3. Espera unos segundos
4. Verifica que aparece el mensaje: "✅ Estadísticas actualizadas"

### 3. Ver logs en la consola
Si ejecutas la app desde Android Studio/Xcode, verás logs como:
```
📊 Calculando estadísticas en background para {empresaId}...
✅ Estadísticas calculadas y guardadas en cache
```

O errores:
```
❌ Error calculando estadísticas en background: {detalle del error}
```

## Soluciones

### Caso 1: Tu empresa es nueva y no tienes datos aún
**Solución:** Las estadísticas se calculan a partir de datos reales. Necesitas al menos:
- Algunas reservas creadas
- Clientes en la base de datos
- Transacciones (si tienes facturación)

**Recomendación:** Usa el generador de datos de prueba si estás en desarrollo:
1. Ve a **Propietario** (solo FluixTech)
2. Pulsa "Generar datos de prueba"
3. Espera a que termine
4. Vuelve a Estadísticas y pulsa refresh

### Caso 2: El servicio de cache tiene un error
**Síntoma:** El botón de refresh da error o se queda en "Calculando..." infinitamente.

**Solución temporal — Ver logs para depurar:**
1. Ejecuta la app desde el IDE
2. Ve a Estadísticas
3. Pulsa refresh
4. Copia los logs del error y envíalos al equipo de Fluixtech

**Solución definitiva:** Verificar el código de `EstadisticasCacheService` en `lib/services/estadisticas_cache_service.dart`:
- Método `_calcularYGuardarEstadisticas`
- Método `_calcularKpisPrincipales`
- Método `_calcularMetricasBasicas`
- Método `_calcularTendencias`

### Caso 3: El cache existe pero tiene valores en 0
**Causa:** Las consultas de Firestore no encuentran datos con las condiciones actuales (fecha, estado, etc.).

**Ejemplo típico:**
- Tienes reservas, pero ninguna con estado `CONFIRMADA` → `reservas_confirmadas: 0`
- Tienes clientes, pero ninguno con `fecha_registro` este mes → `nuevos_clientes_mes: 0`

**Solución:** Revisa tus datos en Firestore y asegúrate de que los estados y fechas son correctos.

## Estructura esperada en Firestore

### Colección `reservas`
```javascript
{
  fecha_hora: Timestamp,  // ⚠️ IMPORTANTE: El campo correcto es 'fecha_hora', NO 'fecha'
  estado: "CONFIRMADA" | "PENDIENTE" | "COMPLETADA" | "CANCELADA",
  nombre_cliente: "Cliente X",
  servicio_nombre: "Corte de pelo",
  precio: 25.0,
  empleado_nombre: "Juan Pérez",
  telefono_cliente: "+34600000000",
  // ...otros campos
}
```

**⚠️ Campo crítico:** Las reservas DEBEN tener `fecha_hora` como `Timestamp`. Si tienes el campo `fecha` en su lugar, el widget "Próximos 3 Días" no las encontrará.

**Cómo verificar:** Ve a Firebase Console → `empresas/{tuEmpresaId}/reservas` y comprueba que todas las reservas tienen el campo `fecha_hora`.

**Índice requerido en Firestore:**
```
Collection: reservas
Fields indexed: fecha_hora (Ascending), __name__ (Ascending)
```

Si ves el error "The query requires an index", copia el enlace que aparece en la consola y créalo automáticamente.

### Colección `clientes`
```javascript
{
  nombre: "Cliente X",
  telefono: "+34600000000",
  fecha_registro: "2026-05-01T10:00:00Z",  // ISO string
  activo: true,
  // ...otros campos
}
```

### Colección `transacciones` (si tienes facturación)
```javascript
{
  fecha: Timestamp,
  monto: 100.0,
  tipo: "ingreso" | "gasto",
  // ...otros campos
}
```

### Colección `facturas` (Pack Gestión)
```javascript
{
  fecha_emision: Timestamp,
  estado: "PAGADA" | "PENDIENTE" | "VENCIDA",
  total: 150.0,
  // ...otros campos
}
```

## Próximos pasos si el problema persiste

1. **Comparte capturas de pantalla** de:
   - La sección de Estadísticas (mostrando los 0s)
   - Firebase Console → cache/estadisticas (el documento)
   - Firebase Console → reservas (una reserva de ejemplo)

2. **Comparte los logs** de la consola cuando pulsas refresh

3. **Verifica permisos** en `firestore.rules`:
   - Tu usuario debe poder leer/escribir en `/empresas/{empresaId}/cache`

## Cambios realizados hoy (1 Mayo 2026)

✅ **Widget "Próximos 3 Días"** ahora incluye:
- Reservas (siempre)
- Pedidos (si tienes Pack Tienda)
- **Pedidos de WhatsApp** (si tienes Add-on WhatsApp) — NUEVO
- Tareas (si tienes Add-on Tareas)

✅ **FIX CRÍTICO — Campo fecha_hora en reservas:**
- El widget ahora busca por `fecha_hora` (en lugar de `fecha`)
- Tiene fallback a `fecha` para compatibilidad con reservas antiguas
- Esto soluciona el problema de "reservas que no aparecen"

✅ **Widget "Citas del Día"** eliminado completamente (ya estaba unificado con Reservas)

✅ **Upsert de clientes** al confirmar reserva:
- Si el cliente existe (por teléfono) → incrementa `total_reservas`, actualiza `ultima_visita`
- Si no existe → crea nuevo cliente con origen `'reserva'`

---

**⚠️ IMPORTANTE:** Si tus reservas no aparecen en "Próximos 3 Días", lee la sección "0. Reservas no aparecen" arriba para diagnosticar y solucionar.

---

**Última actualización:** 1 Mayo 2026  
**Versión:** Flutter 3.x • Firebase 10.x




