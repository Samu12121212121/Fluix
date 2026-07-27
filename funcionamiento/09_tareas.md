# Módulo: Tareas

## Qué hace

Sistema de gestión de tareas con vista Kanban/listado, asignación a empleados y equipos, seguimiento de tiempo, subtareas, adjuntos, tareas recurrentes automáticas, y notificaciones de vencimiento.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/tareas/pantallas/detalle_tarea_screen.dart` | Detalle con historial y cronómetro |
| `features/tareas/pantallas/formulario_tarea_screen.dart` | Crear/editar tarea |
| `features/tareas/pantallas/equipos_screen.dart` | Gestión de equipos de trabajo |
| `features/tareas/pantallas/reporte_tiempo_screen.dart` | Resumen de horas por empleado |
| `features/tareas/widgets/adjuntos_grid_widget.dart` | Grid de documentos adjuntos |
| `features/tareas/widgets/cliente_vinculado_widget.dart` | Cliente asociado a la tarea |
| `features/tareas/widgets/recurrencia_config_widget.dart` | Configurar recurrencia |
| `features/tareas/widgets/cronometro_tarea_widget.dart` | Cronómetro de tiempo trabajado |

---

## Modelo de datos

```dart
Tarea {
  id: String
  titulo: String
  descripcion: String?
  
  // Asignación
  asignadoId: String?          // empleadoId
  equipoId: String?
  creadorId: String
  
  // Clasificación
  tipo: TipoTarea              // normal, checklist, incidencia, proyecto
  prioridad: PrioridadTarea    // urgente, alta, media, baja
  estado: EstadoTarea          // pendiente, enProgreso, enRevision, completada, cancelada
  
  // Fechas
  fechaCreacion: DateTime
  fechaVencimiento: DateTime?
  fechaCompletado: DateTime?
  
  // Recurrencia
  esRecurrente: bool
  frecuencia: FrecuenciaRecurrencia?  // diaria, semanal, mensual
  diasSemana: List<int>?       // Para recurrencia semanal
  
  // Subtareas
  subtareas: List<Subtarea>
  
  // Vinculos
  clienteId: String?
  
  // Tiempo
  tiempoEstimadoMin: int?
  tiempoRealMin: int?
}

Subtarea {
  id: String
  titulo: String
  completada: bool
}

EntradaTiempo {
  usuarioId: String
  inicio: DateTime
  fin: DateTime?
  duracionMin: int
}

Equipo {
  id: String
  nombre: String
  responsableId: String
  miembrosIds: List<String>
}
```

---

## Cómo funciona internamente

### Flujo de una tarea
1. Se crea la tarea en `formulario_tarea_screen.dart` con título, descripción, asignado, prioridad y fecha de vencimiento
2. Si se asigna a un empleado, la Cloud Function `onTareaAsignada` envía una notificación push
3. El empleado puede cambiar el estado mediante drag en la vista Kanban o desde el detalle
4. En `detalle_tarea_screen.dart` se pueden añadir subtareas, adjuntos, comentarios y activar el cronómetro

### Tareas recurrentes
- Se configura en `recurrencia_config_widget.dart` (frecuencia: diaria, semanal, mensual)
- La Cloud Function `scheduledGenerarTareasRecurrentes` corre cada madrugada y crea nuevas instancias según la frecuencia
- Las instancias generadas son copias independientes de la tarea original

### Tracking de tiempo
- `cronometro_tarea_widget.dart` inicia/para el cronómetro
- Cada entrada de tiempo queda en `tareas/{id}/tiempo`
- `reporte_tiempo_screen.dart` muestra el tiempo trabajado por cada empleado en el período

### Equipos
- `equipos_screen.dart` gestiona los equipos (grupos de empleados)
- Las tareas se pueden asignar a un equipo en lugar de a un empleado concreto
- Todos los miembros del equipo ven la tarea asignada

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/tareas` | Tarea principal |
| `empresas/{empresaId}/tareas/{id}/adjuntos` | Documentos adjuntos |
| `empresas/{empresaId}/tareas/{id}/tiempo` | Entradas de tiempo trabajado |
| `empresas/{empresaId}/equipos` | Equipos de trabajo |

---

## Cloud Functions relacionadas

| Función | Cuándo se ejecuta |
|---------|------------------|
| `onTareaAsignada` | Trigger — notificación push al empleado asignado |
| `scheduledGenerarTareasRecurrentes` | Scheduled diario — crea nuevas instancias de tareas recurrentes |
| `scheduledRecordatoriosTareas` | Scheduled — alerta de tareas próximas a vencer |
| `scheduledTareasVencenHoy` | Scheduled diario — notificación de tareas que vencen hoy |
| `onNuevaSugerencia` | Trigger — sugerencia de tarea automática desde actividad del negocio |

---

## Conexión con otros módulos

- **Empleados** — las tareas se asignan a empleados; el módulo lee la lista de empleados
- **Clientes** — una tarea puede vincularse a un cliente (ej: "Llamar a Juan García")
- **Notificaciones** — los eventos de tareas generan notificaciones push
