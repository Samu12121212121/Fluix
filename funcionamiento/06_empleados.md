# Módulo: Empleados

## Qué hace

Gestión completa de la plantilla: alta/baja de empleados, datos personales y de nómina, documentos (contratos, CV), bajas laborales, embargos judiciales y permisos de acceso por rol.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/empleados/pantallas/formulario_empleado_form.dart` | Alta y edición de empleado |
| `features/empleados/pantallas/formulario_datos_nomina_form.dart` | Datos específicos para nómina |
| `features/empleados/pantallas/empleados_baja_screen.dart` | Gestión de bajas laborales |
| `features/empleados/widgets/avatar_empleado_widget.dart` | Avatar/foto del empleado |
| `features/empleados/widgets/baja_laboral_widget.dart` | Widget de baja activa |
| `features/empleados/widgets/selector_foto_widget.dart` | Selector de foto de perfil |
| `features/empleados/widgets/seccion_embargos_widget.dart` | Gestión de embargos judiciales |
| `lib/models/embargo_model.dart` | Modelo de embargo judicial |

---

## Modelo de datos: Empleado

```dart
Empleado {
  id: String
  usuarioId: String?             // Si tiene acceso a la app
  
  // Datos personales
  nombre: String
  apellidos: String
  email: String?
  telefono: String?
  nif: String
  fechaNacimiento: DateTime?
  numeroSeguridadSocial: String?
  
  // Datos laborales
  puesto: String
  fechaAlta: DateTime
  fechaBaja: DateTime?
  tipoContrato: TipoContrato
  jornadaHoras: double           // Horas semanales
  convenio: String?
  categoriaConvenio: String?
  
  // Retribución
  salarioBase: double
  complementos: double
  
  // Estado
  activo: bool
  enBajaLaboral: bool
  
  // Acceso app
  rol: String?                   // propietario, admin, staff
  modulosPermitidos: List<String>
  
  // Imagen
  fotoUrl: String?
}

enum TipoContrato {
  indefinido,
  temporal,
  practicas,
  formacion,
  parcial,
  obrayServicio
}

BajaLaboral {
  empleadoId: String
  tipo: TipoBaja               // enfermedad, maternidad, paternidad, accidente
  fechaInicio: DateTime
  fechaFin: DateTime?
  porcentajeSubsidio: double   // % que paga la SS
}

Embargo {
  empleadoId: String
  importeMensual: double       // o porcentaje sobre salario
  fechaInicio: DateTime
  fechaFin: DateTime?
  referencia: String           // Número de resolución judicial
}
```

---

## Cómo funciona internamente

### Alta de empleado
1. El usuario rellena `formulario_empleado_form.dart` con datos personales y laborales
2. En `formulario_datos_nomina_form.dart` se completan los datos de nómina (salario, convenio, tipo de contrato)
3. Al guardar, se crea el documento en `empresas/{empresaId}/empleados`
4. Si se le asigna acceso a la app, se envía invitación por email (módulo de invitaciones)

### Bajas laborales
- `empleados_baja_screen.dart` gestiona altas y bajas de IT (Incapacidad Temporal)
- Se registra fecha de inicio, tipo y porcentaje de subsidio
- El cálculo de nómina del mes detecta la baja y ajusta el importe proporcionalmente

### Embargos judiciales
- `seccion_embargos_widget.dart` muestra y gestiona los embargos activos del empleado
- Los embargos se aplican automáticamente en el cálculo de nómina
- Se calcula sobre el salario neto según la escala de embargabilidad del SMI

### Documentos
- Los documentos (contrato, CV, titulaciones) se suben a Firebase Storage
- Las referencias quedan en `empleados/{id}/documentos`
- Se pueden descargar desde la ficha del empleado

### Permisos de acceso
- Si el empleado tiene acceso a la app, se configura su rol y módulos visibles
- El campo `modulosPermitidos` es un array de strings que corresponden a los módulos habilitados
- El dashboard filtra los módulos según esta lista para usuarios con rol `staff`

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `empresas/{empresaId}/empleados` | Documento principal del empleado |
| `empresas/{empresaId}/empleados/{id}/documentos` | Documentos del empleado |
| `empresas/{empresaId}/empleados/{id}/renovaciones` | Alertas de renovación de contrato |

---

## Cloud Functions relacionadas

No hay Cloud Functions específicas de empleados, pero estos datos alimentan funciones de otros módulos:
- Los datos del empleado se usan en `generarNominaMensual` (nóminas)
- Las bajas afectan al cálculo en `calcularNominaEmpleado`
- Los embargos se aplican en `calcularDescuentoEmbargo`

---

## Conexión con otros módulos

- **Nóminas** — cada nómina referencia un empleado; datos de salario, contrato y SS vienen de aquí
- **Vacaciones** — cada solicitud de vacaciones referencia al empleado
- **Fichajes** — los fichajes se asocian al empleado
- **Finiquitos** — el finiquito calcula datos a partir del historial del empleado
- **Tareas** — las tareas se pueden asignar a empleados
- **Reservas** — en negocios de servicio (peluquería), los profesionales son empleados
- **Autenticación** — si el empleado tiene acceso a la app, se crea usuario en Firebase Auth
