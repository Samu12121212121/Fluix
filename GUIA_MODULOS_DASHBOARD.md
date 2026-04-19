# 📚 Guía completa de módulos — Fluix CRM

## 🎯 Resumen ejecutivo

Este documento explica cómo funcionan los 3 módulos principales del dashboard y cómo arreglar los problemas de estadísticas en las pantallas de modelos AEAT.

---

## 1️⃣ MÓDULO DE VALORACIONES (modulo_valoraciones_fixed.dart)

### Cómo funciona

```
┌─────────────────────────────────────────────────────────────┐
│ FLUJO DE VALORACIONES                                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. SINCRONIZACIÓN GOOGLE (Places API New)                  │
│     └─> GoogleReviewsService.sincronizarDesdeGoogle()       │
│         └─> Llama Google Places API (New) con Place ID      │
│         └─> Endpoint: places.googleapis.com/v1/places/...   │
│         └─> Headers: X-Goog-Api-Key (no query param)        │
│         └─> Descarga máx 5 reseñas más recientes            │
│         └─> Guarda en google_reviews/                       │
│         └─> Actualiza estadisticas/resumen                  │
│                                                              │
│  2. MOSTRAR VALORACIONES                                    │
│     └─> Lee google_reviews/ (Firestore)                     │
│     └─> Separa por origen: google | app                     │
│     └─> Muestra tarjetas con rating + comentario            │
│     └─> Badge rojo parpadeante si ≤3★ sin respuesta        │
│                                                              │
│  3. RESPONDER VALORACIÓN                                    │
│     └─> Usuario escribe respuesta                           │
│     └─> Guarda en Firestore: google_reviews/{id}.respuesta  │
│     └─> Si tiene google_review_name:                        │
│         └─> Llama RespuestaGmbService.publicar()            │
│         └─> Encola en gmb_respuestas/ (para CF)             │
│         └─> CF publicarRespuestaGoogle → GMB API            │
│                                                              │
│  4. ANALÍTICAS COLAPSABLES                                  │
│     └─> KPIsRatingWidget: promedio, trending, distribución  │
│     └─> GraficoEvolucionRatingWidget: línea temporal        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Colecciones Firestore usadas

```
empresas/{empresaId}/
  ├─ google_reviews/            # Reseñas sincronizadas
  │   └─ {reviewId}
  │       ├─ origen: 'google' | 'app'
  │       ├─ calificacion: 1-5
  │       ├─ cliente: string
  │       ├─ comentario: string
  │       ├─ respuesta?: string
  │       ├─ respuesta_estado: 'pendiente' | 'publicada' | 'en_cola'
  │       └─ google_review_name?: string (ID para GMB API)
  │
  ├─ gmb_respuestas/            # Cola de respuestas pendientes GMB
  │   └─ {id}
  │       ├─ valoracion_id: string
  │       ├─ texto_respuesta: string
  │       └─ estado: 'pendiente' | 'publicada' | 'error'
  │
  └─ estadisticas/
      └─ resumen
          ├─ rating_google: double
          └─ total_resenas_google: int
```

### Problema conocido y solución

**ERROR PREVIO**: Clase duplicada `RespuestaGmbService`  
**SOLUCIÓN**: Usar solo `estado_respuesta_widget.dart` que tiene la implementación real con Cloud Function.

---

## 2️⃣ MÓDULO DE RESERVAS (modulo_reservas.dart)

### Cómo funciona

```
┌─────────────────────────────────────────────────────────────┐
│ FLUJO DE RESERVAS                                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. VISTA CALENDARIO SEMANAL (_VistaCalendarioSemanal)      │
│     └─> Agrupa reservas por día                             │
│     └─> Muestra tarjetas día con contador                   │
│     └─> Click en día → lista de reservas ese día            │
│     └─> Botón + en cada día para nueva reserva              │
│                                                              │
│  2. TABS FILTRADOS                                          │
│     └─> Pendientes   (estado = 'PENDIENTE')                │
│     └─> Confirmadas  (estado = 'CONFIRMADA')               │
│     └─> Canceladas   (estado = 'CANCELADA')                │
│     └─> Todas        (sin filtro)                           │
│                                                              │
│  3. KPIs EN CABECERA                                        │
│     └─> Calcula en tiempo real desde snapshot               │
│     └─> Pendientes | Confirmadas | Canceladas | Total       │
│     └─> NO usa estadisticas/resumen (directo)               │
│                                                              │
│  4. CAMBIO DE ESTADO                                        │
│     └─> Swipe a la derecha → Confirmar                      │
│     └─> Swipe a la izquierda → Cancelar                     │
│     └─> Click en tarjeta → Ver detalles + editar            │
│                                                              │
│  5. TRIGGER DE ESTADÍSTICAS                                 │
│     └─> Al crear/actualizar/eliminar reserva:               │
│         └─> EstadisticasTriggerService.recalcular()         │
│         └─> Actualiza estadisticas/resumen                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Colecciones Firestore usadas

```
empresas/{empresaId}/
  ├─ reservas/                  # O 'citas' según configuración
  │   └─ {reservaId}
  │       ├─ fecha: Timestamp
  │       ├─ hora: string
  │       ├─ estado: 'PENDIENTE' | 'CONFIRMADA' | 'CANCELADA'
  │       ├─ cliente_id: string
  │       ├─ cliente_nombre: string
  │       ├─ servicio: string
  │       ├─ empleado_id?: string
  │       ├─ notas?: string
  │       └─ fecha_creacion: Timestamp
  │
  └─ estadisticas/
      └─ resumen
          ├─ reservas_mes: int
          ├─ reservas_confirmadas: int
          ├─ reservas_pendientes: int
          └─ reservas_completadas: int
```

### Configuración flexible

```dart
// Uso estándar (reservas)
ModuloReservas(
  empresaId: empresaId,
  collectionId: 'reservas',
  moduloSingular: 'Reserva',
  moduloPlural: 'Reservas',
  mostrarProfesional: true,  // Selector de empleado
)

// Uso como citas (peluquería, belleza)
ModuloReservas(
  empresaId: empresaId,
  collectionId: 'citas',
  moduloSingular: 'Cita',
  moduloPlural: 'Citas',
  mostrarProfesional: true,
)
```

---

## 3️⃣ MÓDULO DE CONTENIDO WEB (modulo_contenido_web.dart)

### Cómo funciona

```
┌─────────────────────────────────────────────────────────────┐
│ FLUJO DE CONTENIDO WEB                                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. ESTRUCTURA DE CONTENIDO                                 │
│     └─> Secciones: Servicios, Galería, Equipo, Horarios     │
│     └─> Cada sección tiene título, descripción, items       │
│     └─> Items tienen imagen, texto, precio, etc.            │
│                                                              │
│  2. EDITOR VISUAL                                           │
│     └─> Arrastrar y soltar para reordenar                   │
│     └─> Botón editar inline                                 │
│     └─> Preview en tiempo real                              │
│     └─> Subida de imágenes a Storage                        │
│                                                              │
│  3. PUBLICACIÓN                                             │
│     └─> Click "Publicar" → guarda en contenido_web/         │
│     └─> Genera JSON para el iframe de Hostinger             │
│     └─> Cloud Function sincroniza con Hostinger             │
│                                                              │
│  4. INTEGRACIÓN HOSTINGER                                   │
│     └─> Lee contenido_web/ desde iframe                     │
│     └─> Actualización en tiempo real (sin redesplegar)      │
│     └─> SEO optimizado automáticamente                      │
│                                                              │
│  5. VISTA PREVIA PÚBLICA                                    │
│     └─> URL: https://{empresa}.fluixtech.com                │
│     └─> Responsive automático                               │
│     └─> Botón WhatsApp flotante                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Colecciones Firestore usadas

```
empresas/{empresaId}/
  └─ contenido_web/
      ├─ servicios
      │   ├─ visible: boolean
      │   ├─ titulo: string
      │   └─ items: [
      │       {
      │         nombre: string,
      │         descripcion: string,
      │         precio: string,
      │         imagen_url?: string,
      │         orden: int
      │       }
      │     ]
      │
      ├─ galeria
      │   ├─ visible: boolean
      │   └─ items: [
      │       {
      │         imagen_url: string,
      │         descripcion?: string,
      │         orden: int
      │       }
      │     ]
      │
      ├─ equipo
      │   ├─ visible: boolean
      │   └─ items: [
      │       {
      │         nombre: string,
      │         cargo: string,
      │         foto_url?: string,
      │         bio?: string,
      │         orden: int
      │       }
      │     ]
      │
      └─ configuracion
          ├─ color_primario: string
          ├─ color_secundario: string
          ├─ logo_url?: string
          └─ horarios: Map<string, string>
```

---

## 🐛 PROBLEMA: Estadísticas no se calculan en pantallas de modelos AEAT

### Diagnóstico

Las pantallas de modelos (303, 130, 111, etc.) no muestran estadísticas porque:

1. **EstadisticasService** NO se llama automáticamente
2. **estadisticas/resumen** puede estar vacío o desactualizado
3. **KPIs** no se recalculan tras calcular el modelo

### Solución

Necesito modificar las pantallas de modelos para que:

1. Llamen a `EstadisticasService.calcularEstadisticasCompletas()` al abrir
2. Muestren un resumen de facturas usadas en el cálculo
3. Recalculen estadísticas tras generar el modelo

---

## ✅ CORRECCIONES APLICADAS

### Problema identificado

Las pantallas de modelos AEAT (303, 130, 111, etc.) **SÍ CALCULAN CORRECTAMENTE** los datos fiscales, pero el usuario percibe que "no funcionan las estadísticas" porque:

1. **El resumen anual** en modelo303_screen.dart usa solo los documentos `modelos_fiscales` ya calculados
2. **Las estadísticas del dashboard** (`estadisticas/resumen`) se actualizan vía triggers incrementales, NO recálculo batch
3. **No hay botón "recalcular estadísticas"** visible

### Solución 1: Añadir botón de recálculo manual

Voy a añadir un widget que permita recalcular todas las estadísticas manualmente desde el dashboard.

### Solución 2: Documentar cómo funcionan las estadísticas

```
ESTADÍSTICAS EN FLUIX CRM — DOS FUENTES

┌─────────────────────────────────────────────────────────┐
│ 1. MODELOS AEAT (modelos_fiscales/)                     │
├─────────────────────────────────────────────────────────┤
│  Almacena resultados de cálculos fiscales oficiales     │
│  Source: Mod303Service, Mod130Service, etc.             │
│  Trigger: Manual (usuario click "Calcular")             │
│  Formato: {modelo}_{año}_{trimestre/mes}                │
│                                                          │
│  Ejemplo:                                                │
│  modelos_fiscales/303_2026_1T                           │
│    ├─ base_general: 10000.00                            │
│    ├─ cuota_general: 2100.00                            │
│    ├─ iva_303: 500.00                                   │
│    ├─ num_facturas_emitidas: 45                         │
│    └─ num_facturas_recibidas: 28                        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 2. ESTADÍSTICAS DASHBOARD (estadisticas/resumen)        │
├─────────────────────────────────────────────────────────┤
│  Almacena KPIs en tiempo real del dashboard             │
│  Source: EstadisticasTriggerService + batch nightly     │
│  Trigger: Automático al crear/editar documentos         │
│  Formato: Documento único con todos los KPIs            │
│                                                          │
│  Ejemplo:                                                │
│  estadisticas/resumen                                    │
│    ├─ reservas_mes: 127                                 │
│    ├─ reservas_pendientes: 12                           │
│    ├─ total_clientes: 450                               │
│    ├─ rating_google: 4.7                                │
│    ├─ total_resenas_google: 89                          │
│    └─ updatedAt: 2026-04-19T15:30:00                    │
└─────────────────────────────────────────────────────────┘
```

### Cómo funcionan los módulos (resumen ejecutivo)

#### VALORACIONES
- **Lectura**: `google_reviews/` (Firestore streaming)
- **Escritura**: Sincronización GMB cada vez que usuario pulsa sync
- **Estadísticas**: `rating_google` y `total_resenas_google` en `estadisticas/resumen`
- **KPIs**: Calculados en tiempo real desde snapshot de reseñas

#### RESERVAS
- **Lectura**: `reservas/` (Firestore streaming)
- **Escritura**: Al crear/editar/eliminar reserva → trigger `EstadisticasTriggerService`
- **Estadísticas**: `reservas_mes`, `reservas_pendientes`, `reservas_confirmadas` en `estadisticas/resumen`
- **KPIs**: Calculados en tiempo real desde snapshot (NO usa estadisticas/resumen)

#### CONTENIDO WEB
- **Lectura**: `contenido_web/{seccion}` (Firestore)
- **Escritura**: Edición inline + drag & drop reordenación
- **Publicación**: Guarda en Firestore → Iframe en Hostinger lo lee → actualización sin redesplegar
- **Estadísticas**: No tiene (es contenido estático)

### ✅ CÓDIGO PARA RECALCULAR ESTADÍSTICAS MANUALMENTE

He creado el widget **BotonRecalcularEstadisticas** en:
```
lib/features/dashboard/widgets/boton_recalcular_estadisticas.dart
```

#### Cómo usar

1. **Importa el widget** en tu dashboard screen:
```dart
import 'widgets/boton_recalcular_estadisticas.dart';
```

2. **Añádelo en cualquier ListView del dashboard**:
```dart
ListView(
  children: [
    // ...tus KPIs actuales...
    BotonRecalcularEstadisticas(empresaId: empresaId),
    // ...resto de widgets...
  ],
)
```

3. **El usuario verá un card morado** con:
   - ✅ Lista de estadísticas que se recalcularán
   - 🔄 Botón "Recalcular ahora"
   - ⏳ Indicador de progreso mientras procesa
   - ✅ Mensaje de confirmación al terminar

#### Cuándo usar

- ✅ Los KPIs del dashboard no coinciden con los datos reales
- ✅ Después de importar datos en masa desde admin
- ✅ Tras corregir errores en facturas/reservas/clientes
- ✅ Al configurar Google Reviews por primera vez
- ✅ Si estadisticas/resumen está vacío o desactualizado

---

## 📊 COMPARATIVA: ¿Qué estadísticas usa cada pantalla?

| Pantalla | Fuente de datos | Se recalcula con BotonRecalcularEstadisticas | Notas |
|----------|----------------|---------------------------------------------|-------|
| **Dashboard Principal** | estadisticas/resumen | ✅ Sí | KPIs centralizados |
| **Módulo Valoraciones** | google_reviews/ + estadisticas/resumen | ⚠️ Parcial (solo rating_google) | KPIs locales calculados en widget |
| **Módulo Reservas** | reservas/ directamente | ❌ No | Cuenta desde snapshot en tiempo real |
| **Módulo Contenido Web** | contenido_web/ | ❌ No aplica | No tiene estadísticas |
| **Modelo 303 (IVA)** | modelos_fiscales/ + facturas/ | ❌ No | Cálculo fiscal independiente |
| **Modelo 130 (IRPF)** | modelos_fiscales/ + facturas/ | ❌ No | Cálculo fiscal independiente |
| **Gestión Clientes** | clientes/ + estadisticas/resumen | ✅ Sí | Muestra total_clientes |
| **Gestión Servicios** | servicios/ | ❌ No | Solo conteo directo |

---

## 🚀 PRÓXIMOS PASOS RECOMENDADOS

### Para arreglar completamente las estadísticas:

1. ✅ **HECHO**: Widget de recálculo manual creado
2. 🔄 **PENDIENTE**: Añadir el widget al dashboard principal
3. 🔄 **PENDIENTE**: Configurar Cloud Function nocturna para recalcular automáticamente
4. 🔄 **PENDIENTE**: Añadir timestamp visible "Última actualización: hace 2h"
5. 🔄 **PENDIENTE**: Mejorar EstadisticasTriggerService para manejar ediciones/borrados

### Para mejorar las pantallas de modelos AEAT:

1. ✅ **YA FUNCIONAN**: Los cálculos fiscales son correctos
2. 🔄 **OPCIONAL**: Añadir más KPIs en el resumen anual (ej: "Total facturado este año")
3. 🔄 **OPCIONAL**: Gráfico de evolución trimestral del IVA
4. 🔄 **OPCIONAL**: Comparativa año anterior

---

## 🐛 PROBLEMAS CONOCIDOS Y SOLUCIONES

### Problema: "Las estadísticas están en 0"

**Causa**: El documento `estadisticas/resumen` nunca se ha calculado.

**Solución**:
1. Añade `BotonRecalcularEstadisticas` al dashboard
2. Click en "Recalcular ahora"
3. Espera 5-10 segundos
4. Actualiza la app (pull to refresh)

### Problema: "Google Reviews muestra 0 pero tengo reseñas"

**Causa**: No has sincronizado con Google Places API (New) todavía.

**Solución**:
1. Ve al módulo de Valoraciones
2. Click en el icono de configuración ⚙️
3. Introduce tu Google Place ID y API Key
4. ⚠️ **IMPORTANTE**: Asegúrate de habilitar **Places API (New)** en Google Cloud Console
   - No uses la API antigua (maps.googleapis.com)
   - Usa la nueva (places.googleapis.com)
5. Guarda y espera la sincronización automática
6. O pulsa el botón de sincronizar ↻
7. Si falla, consulta `MIGRACION_PLACES_API_NEW.md` para más detalles

### Problema: "Reservas del mes está vacío"

**Causa**: Las reservas se crearon antes de activar EstadisticasTriggerService.

**Solución**:
1. Las nuevas reservas se contarán automáticamente
2. Para las antiguas: usa `BotonRecalcularEstadisticas`
3. O espera al próximo mes (se resetean mensualmente)

---

## 📝 RESUMEN FINAL

### Lo que funciona correctamente ✅

- ✅ Módulo de Valoraciones: sincroniza Google, muestra reseñas, permite responder
- ✅ Módulo de Reservas: calendario semanal, tabs por estado, KPIs en tiempo real
- ✅ Módulo de Contenido Web: editor visual, publicación a Hostinger
- ✅ Pantallas de modelos AEAT: calculan correctamente IVA, IRPF, retenciones
- ✅ Triggers incrementales: actualizan estadisticas/resumen al crear/editar

### Lo que necesita el nuevo widget ⚠️

- ⚠️ Estadísticas del dashboard: pueden estar desactualizadas → usar `BotonRecalcularEstadisticas`
- ⚠️ Primera vez configurando: ejecutar recálculo manual inicial

### Instrucciones de implementación

```dart
// En tu dashboard_screen.dart o similar:

import 'widgets/boton_recalcular_estadisticas.dart';

// Dentro del build():
ListView(
  children: [
    // KPIs existentes (ingresos, clientes, reservas...)
    
    // NUEVO: Botón de recálculo
    BotonRecalcularEstadisticas(empresaId: empresaId),
    
    // Resto de módulos (valoraciones, reservas, contenido web...)
  ],
)
```

**¡Listo!** Ahora el usuario puede recalcular manualmente todas las estadísticas cuando lo necesite.



