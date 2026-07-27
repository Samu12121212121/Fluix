# Módulo: Vacaciones y Finiquitos

---

## VACACIONES

### Qué hace

Gestión del calendario de vacaciones de la plantilla: solicitudes, aprobación, saldo disponible, festivos locales y validación de cobertura mínima del equipo.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/vacaciones/pantallas/festivos_locales_screen.dart` | Editar festivos municipales |
| `features/vacaciones/widgets/calendario_vacaciones_widget.dart` | Vista calendario (table_calendar) |
| `features/vacaciones/widgets/saldo_vacaciones_widget.dart` | Saldo de días disponibles |
| `features/vacaciones/widgets/cobertura_semanal_widget.dart` | Cobertura mínima por semana |

### Modelo de datos

```dart
Vacacion {
  id: String
  empleadoId: String
  fechaInicio: DateTime
  fechaFin: DateTime
  diasUsados: int
  estado: EstadoVacacion     // solicitada, aprobada, rechazada
  motivoRechazo: String?
  fechaSolicitud: DateTime
}

VacacionesConfig {
  diasAnualesTotal: int        // Típicamente 22 días laborables
  carryoverMax: int            // Días que se pueden llevar al año siguiente
  periodicidadReset: String    // '01/01' o '01/09'
  coberturaMinimaEquipo: int   // Empleados mínimos presentes
}
```

### Cómo funciona

1. El empleado solicita vacaciones → se crea con estado `solicitada`
2. El propietario/admin recibe notificación y revisa la cobertura del equipo en esa semana
3. `cobertura_semanal_widget.dart` muestra cuántos empleados estarían de vacaciones simultáneamente
4. Se aprueba o rechaza con motivo
5. Al aprobar, se descuentan los días del saldo disponible
6. `scheduledCierreAnualVacaciones` corre el 31/12 y cierra el período
7. Los días no disfrutados se pasan al año siguiente (hasta el máximo de `carryoverMax`)

### Colecciones Firestore

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/vacaciones` | Período de vacaciones |
| `empresas/{empresaId}/configuracion/vacaciones` | Días anuales, carryover, reset |
| `empresas/{empresaId}/festivos_locales` | Festivos municipales propios |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `onVacacionEstadoCambiado` | Trigger — notificación al empleado al aprobar/rechazar |
| `scheduledCierreAnualVacaciones` | Scheduled 31/12 — cierre del período anual |
| `scheduledExpiracionCarryover` | Scheduled 31/12 — elimina días caducados de carryover |
| `importarFestivosEspana` | Callable — carga calendario festivos nacionales + autonómicos |

---

## FINIQUITOS

### Qué hace

Cálculo legal del finiquito (cese de relación laboral), generación del documento PDF y firma digital del empleado.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/finiquitos/pantallas/finiquitos_screen.dart` | Listado de finiquitos |
| `features/finiquitos/pantallas/finiquito_detalle.dart` | Detalle con datos del empleado |
| `features/finiquitos/pantallas/revision_finiquito_empleado_screen.dart` | Vista del empleado |
| `features/finiquitos/widgets/firma_finiquito_canvas.dart` | Canvas de firma |
| `services/finiquito_service.dart` | CRUD y cálculos legales |

### Modelo de datos

```dart
Finiquito {
  id: String
  empleadoId: String
  empleadoNombre: String
  fechaCese: DateTime
  motivoCese: MotivoFiniquito   // despido, renuncia, fin_contrato, mutuo_acuerdo
  
  // Cálculos
  salarioPendiente: double       // Días del mes trabajados antes del cese
  vacacionesPendientesDias: int
  vacacionesPendientesImporte: double
  parrillas: double             // Si convenio lo especifica
  indemnizacion: double         // Solo si aplica (despido)
  
  // Total
  totalFiniquito: double
  
  // Firma
  firmaEmpleado: String?
  fechaFirma: DateTime?
  
  estado: EstadoFiniquito       // borrador, firmado, pagado
}
```

### Cómo se calcula

| Concepto | Cálculo |
|----------|---------|
| Salario pendiente | Días trabajados en el mes del cese × (salario/30) |
| Vacaciones pendientes | Días pendientes × (salario/365) × 30.4 |
| Pagas extras | Si no están prorrateadas en nómina, se calcula la parte proporcional |
| Indemnización (despido) | 20 días × año de servicio (despido improcedente: 33 días) |

### Colecciones Firestore

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/finiquitos` | Documento de finiquito |
| `empresas/{empresaId}/empleados/{id}` | Datos del empleado para cálculos |
| `empresas/{empresaId}/nominas` | Historial de nóminas para verificar |
| `empresas/{empresaId}/vacaciones` | Días disfrutados para calcular pendientes |

### Cloud Functions

| Función | Cuándo |
|---------|--------|
| `enviarDocumentacionFiniquito` | Callable — envía PDF del finiquito por email |

### Conexión con otros módulos

- **Empleados** — la baja definitiva del empleado se marca al finalizar el proceso
- **Nóminas** — el historial de nóminas sirve para verificar los cálculos
- **Vacaciones** — los días pendientes de vacaciones se calculan desde el módulo de vacaciones
