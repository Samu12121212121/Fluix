# Módulo: Reservas y Fichajes

---

## RESERVAS

### Qué hace

Sistema de reservas configurable para distintos tipos de negocio: restaurante (mesas), peluquería (servicios con profesional), o cualquier negocio con citas. Soporta reservas desde la app del negocio, web pública y clientes finales. Envía confirmaciones automáticas por email y recordatorios.

### Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/reservas_cliente/widgets/formulario_reserva_factory.dart` | Factory que elige formulario según tipo de negocio |
| `services/verifactu/` — no relacionado | — |
| `domain/repositorios/repositorio_reservas.dart` | Interfaz del repositorio |

### Modelo de datos

```dart
Reserva {
  id: String
  
  // Cliente
  clienteId: String?
  clienteNombre: String
  clienteEmail: String?
  clienteTelefono: String?
  
  // Detalles de la reserva
  fechaHora: DateTime
  duracionMin: int?
  comensales: int?             // Restaurante
  servicioId: String?          // Peluquería
  profesionalId: String?       // Peluquería
  mesaId: String?              // Restaurante
  
  // Estado
  estado: EstadoReserva        // pendiente, confirmada, cancelada, completada, noShow
  origen: OrigenReserva        // web, manual, telefono, app, whatsapp
  
  // Notas
  notasCliente: String?
  notasInternas: String?
  
  // Confirmación
  tokenConfirmacion: String?   // Para confirmar sin login
  recordatorioEnviado: bool
}

enum EstadoReserva { pendiente, confirmada, cancelada, completada, noShow }
enum OrigenReserva { web, manual, telefono, app, whatsapp }
```

### Cómo funciona

#### Reserva desde la app del negocio (manual)
1. El staff selecciona fecha/hora, número de comensales o servicio, y datos del cliente
2. Si el cliente existe en el CRM, se autocompletar
3. Se crea la reserva en estado `confirmada` directamente
4. Se envía confirmación por email automáticamente

#### Reserva pública (web/cliente final)
1. El cliente accede al widget de reservas embebido en la web del negocio
2. Usa `reservasPublicas` (Cloud Function) para crear la reserva sin autenticación
3. La reserva se crea en estado `pendiente`
4. El negocio recibe notificación push y confirma/rechaza
5. Al confirmar, el cliente recibe email de confirmación

#### Recordatorios automáticos
- `recordatorioReservaCliente` se ejecuta de madrugada y envía recordatorio a los clientes con reservas al día siguiente

#### Configuración de disponibilidad
- Se configura por empresa: horario de apertura, tiempo mínimo entre reservas, antelación mínima, servicios disponibles

### Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/reservas` | Reservas |
| `empresas/{empresaId}/servicios` | Servicios disponibles (peluquería) |
| `empresas/{empresaId}/mesas` | Mesas del restaurante |
| `empresas/{empresaId}/empleados` | Profesionales disponibles |
| `empresas/{empresaId}/configuracion/reservas` | Horarios, reglas, notificaciones |

### Cloud Functions de reservas

| Función | Cuándo |
|---------|--------|
| `onNuevaReserva` | Trigger — email + WhatsApp de confirmación |
| `onReservaConfirmada` | Trigger — notificación al cliente |
| `onReservaCancelada` | Trigger — email de cancelación |
| `recordatorioReservaCliente` | Scheduled noche — reminder 24h antes |
| `reservasPublicas` | HTTP — crear reserva desde web pública (sin auth) |
| `confirmarReserva` / `rechazarReserva` | Callable — cambiar estado desde la app |
| `expirarReservasPublicas` | Scheduled — limpiar reservas expiradas sin confirmar |
| `onNuevaReservaEmail` | Trigger — email de nueva reserva al negocio |

---

## FICHAJES

### Qué hace

Control horario digital con GPS: los empleados fichan entrada y salida desde la app, opcionalmente se valida la ubicación para evitar fichajes fuera del lugar de trabajo.

### Archivos principales

| Archivo | Carpeta |
|---------|---------|
| `features/fichaje/pantallas/` | Pantalla de fichaje del empleado |
| `services/fichaje_service.dart` | CRUD de fichajes |
| `services/geolocalizacion_service.dart` | Validación de ubicación GPS |

### Modelo de datos

```dart
Fichaje {
  id: String
  empleadoId: String
  fecha: DateTime
  
  horaEntrada: DateTime?
  ubicacionEntrada: GeoPoint?
  
  horaSalida: DateTime?
  ubicacionSalida: GeoPoint?
  
  horasTrabajadas: double?     // Calculado al salir
  jornada: String              // Tipo de jornada del día
  
  incidencia: String?          // Nota de incidencia
  validado: bool               // Validado por el responsable
}
```

### Cómo funciona

1. El empleado abre la app y pulsa "Fichar entrada"
2. El sistema registra timestamp + GPS (si está habilitado)
3. Si hay radio de geolocalización configurado, valida que el empleado está en el lugar de trabajo (dentro del radio en metros)
4. Al fichar salida, se calcula automáticamente `horasTrabajadas`
5. El responsable puede ver todos los fichajes del día y validarlos o añadir incidencias

### Integración con nóminas

El módulo de nóminas lee los fichajes del mes para:
- Calcular ausencias (días sin fichar)
- Validar horas extraordinarias
- Detectar retrasos o salidas anticipadas

### Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/fichajes` | Registros de entrada/salida |
| `empresas/{empresaId}/configuracion/fichaje` | Radio GPS, tolerancia, alertas |

### Conexión con otros módulos

- **Empleados** — los fichajes pertenecen a un empleado
- **Nóminas** — las ausencias del mes se calculan desde los fichajes
- **Vacaciones** — los días de vacaciones excluyen la obligación de fichar
