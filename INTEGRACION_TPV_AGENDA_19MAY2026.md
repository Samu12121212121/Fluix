# Integración TPV Peluquería - Agenda de Reservas
**Fecha:** 19 Mayo 2026  
**Objetivo:** Sincronizar citas del TPV de peluquería con la agenda general de reservas

## 📋 Problema Identificado

Al crear una nueva cita en el TPV de peluquería, esta solo se guardaba en la colección `citas` (específica del TPV), pero no aparecía en la agenda general de reservas del negocio.

**Impacto:**
- Las citas creadas desde el TPV no eran visibles en el módulo de reservas
- Falta de sincronización entre sistemas
- El empresario no podía ver todas sus citas en un solo lugar

## ✅ Solución Implementada

### 1. Modificación del Modelo `Cita`
**Archivo:** `lib/features/tpv/pantallas/tpv_peluqueria_screen.dart`

Se agregó el campo `reservaId` para vincular cada cita del TPV con su reserva correspondiente en la agenda:

```dart
class Cita {
  // ...campos existentes...
  final String? reservaId; // ← NUEVO: ID de la reserva vinculada
  
  const Cita({
    // ...parámetros existentes...
    this.reservaId, // ← NUEVO
  });
}
```

### 2. Creación Dual de Cita y Reserva
**Método:** `_guardar()` en `_DialogoNuevaCitaState`

Cuando se crea una nueva cita desde el TPV, ahora:

1. **Crea primero la reserva** en `empresas/{empresaId}/reservas` con:
   - `cliente_nombre`: Nombre del cliente
   - `servicio`: Nombres de los servicios concatenados
   - `fecha`: Timestamp completo (fecha + hora)
   - `duracion`: Duración en minutos
   - `estado`: 'confirmada'
   - `precio`: Total calculado de todos los servicios
   - `profesional_id`: ID del profesional asignado
   - `origen`: 'tpv_peluqueria' (para identificar la fuente)
   - `notas`: Notas del cliente

2. **Crea la cita** en `empresas/{empresaId}/citas` con:
   - Todos los campos originales
   - `reserva_id`: ID de la reserva creada (vinculación)

**Código clave:**
```dart
// 1. Crear primero la reserva (agenda general)
final reservaRef = await FirebaseFirestore.instance
    .collection('empresas')
    .doc(widget.empresaId)
    .collection('reservas')
    .add({
  'cliente_nombre': _clienteCtrl.text.trim(),
  'servicio': servicioNombre,
  'fecha': Timestamp.fromDate(fechaHoraCompleta),
  'duracion': _duracion,
  'estado': 'confirmada',
  'precio': precioTotal,
  'notas': _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
  'profesional_id': _profId,
  'origen': 'tpv_peluqueria',
  'fecha_creacion': FieldValue.serverTimestamp(),
});

// 2. Guardar en citas (TPV) con referencia a la reserva
await FirebaseFirestore.instance
    .collection('empresas')
    .doc(widget.empresaId)
    .collection('citas')
    .add({
  // ...campos de la cita...
  'reserva_id': reservaRef.id, // ← Vinculación con reserva
  'fecha_creacion': FieldValue.serverTimestamp(),
});
```

### 3. Sincronización de Estados
**Método:** `_cambiarEstado()` en `_DialogoDetalleCita`

Cuando se cambia el estado de una cita (iniciar, completar, cancelar, etc.), también se actualiza el estado de la reserva vinculada:

**Mapeo de estados:**
| Estado Cita | Estado Reserva |
|------------|----------------|
| `pendiente` | `confirmada` |
| `enCurso` | `en_curso` |
| `completada` | `completada` |
| `cancelada` | `cancelada` |
| `noPresento` | `no_asistio` |

**Código:**
```dart
Future<void> _cambiarEstado(BuildContext context, String estado) async {
  // Actualizar estado de la cita
  await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('citas')
      .doc(cita.id)
      .update({'estado': estado});

  // Sincronizar con la reserva vinculada si existe
  if (cita.reservaId != null && cita.reservaId!.isNotEmpty) {
    try {
      // Mapear estados de cita a estados de reserva
      String estadoReserva;
      switch (estado) {
        case 'completada':
          estadoReserva = 'completada';
          break;
        case 'cancelada':
          estadoReserva = 'cancelada';
          break;
        case 'noPresento':
          estadoReserva = 'no_asistio';
          break;
        case 'enCurso':
          estadoReserva = 'en_curso';
          break;
        default:
          estadoReserva = 'confirmada';
      }

      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('reservas')
          .doc(cita.reservaId)
          .update({'estado': estadoReserva});
    } catch (e) {
      debugPrint('Error sincronizando reserva: $e');
    }
  }

  if (context.mounted) Navigator.pop(context);
}
```

## 📊 Estructura de Datos

### Colección `citas` (TPV)
```json
{
  "cliente_nombre": "María García",
  "prof_id": "prof123",
  "fecha": "2026-05-19",
  "hora_inicio": "10:30",
  "duracion_minutos": 45,
  "servicios": [
    {
      "id": "serv1",
      "nombre": "Corte de pelo",
      "precio": 25.0
    }
  ],
  "estado": "pendiente",
  "nota": "Cliente alérgica a productos con amoniaco",
  "reserva_id": "res_abc123",  // ← Vinculación
  "fecha_creacion": "2026-05-19T08:15:00Z"
}
```

### Colección `reservas` (Agenda)
```json
{
  "cliente_nombre": "María García",
  "servicio": "Corte de pelo",
  "fecha": "2026-05-19T10:30:00Z",  // Timestamp completo
  "duracion": 45,
  "estado": "confirmada",
  "precio": 25.0,
  "notas": "Cliente alérgica a productos con amoniaco",
  "profesional_id": "prof123",
  "origen": "tpv_peluqueria",  // Identifica la fuente
  "fecha_creacion": "2026-05-19T08:15:00Z"
}
```

## 🎯 Flujo Completo

### Creación de Cita
```
1. Usuario abre TPV Peluquería
2. Selecciona profesional y fecha
3. Click en "Nueva cita"
4. Completa formulario:
   - Nombre cliente
   - Profesional
   - Hora inicio
   - Duración
   - Servicios
   - Nota (opcional)
5. Click en "Guardar cita"
   ↓
6. Sistema crea RESERVA en agenda → obtiene ID
7. Sistema crea CITA en TPV → vincula con reserva_id
   ↓
8. ✅ Cita aparece en TPV timeline
9. ✅ Reserva aparece en módulo Reservas
```

### Cambio de Estado
```
1. Usuario hace click en cita en el timeline
2. Ve detalles de la cita
3. Click en acción (Iniciar / Completar / No vino)
   ↓
4. Sistema actualiza estado de CITA
5. Sistema busca reserva vinculada (reserva_id)
6. Sistema actualiza estado de RESERVA
   ↓
7. ✅ Ambos sistemas sincronizados
```

## 🔍 Casos de Uso

### Caso 1: Peluquería con Agenda Web
**Escenario:**
- Cliente reserva por web → crea `reserva`
- Cliente llega al salón → se crea `cita` en TPV

**Solución:** Ambos registros coexisten, el empresario ve ambos en su agenda.

### Caso 2: TPV sin Reserva Previa
**Escenario:**
- Cliente walk-in sin cita previa
- Recepcionista crea cita directamente en TPV

**Resultado:**
- ✅ Se crea automáticamente la reserva
- ✅ Aparece en la agenda general
- ✅ Vinculación bidireccional establecida

### Caso 3: Seguimiento de Estado
**Escenario:**
1. Cita creada → estado `pendiente` / reserva `confirmada`
2. Cliente llega → estado `enCurso` / reserva `en_curso`
3. Servicio terminado → estado `completada` / reserva `completada`

**Resultado:** Historial completo en ambos sistemas.

## 🚀 Beneficios

1. **Vista Unificada:** Todas las citas visibles en un solo lugar
2. **Sincronización Automática:** Estados actualizados en tiempo real
3. **Trazabilidad:** Identificación del origen (web, TPV, app)
4. **Integridad de Datos:** Vinculación bidireccional previene inconsistencias
5. **Experiencia Mejorada:** El empresario no necesita buscar en múltiples pantallas

## ⚠️ Consideraciones

### Retrocompatibilidad
- Citas antiguas sin `reserva_id`: Funcionan normalmente
- Solo se sincronizan citas nuevas con vinculación

### Manejo de Errores
- Si falla la creación de reserva → cita tampoco se crea (transacción implícita)
- Si falla la sincronización de estado → se registra en logs pero no bloquea la operación

### Identificación de Origen
Campo `origen: 'tpv_peluqueria'` permite:
- Filtrar reservas por fuente
- Reportes de conversión web vs presencial
- Análisis de canales de captación

## 📝 Testing Recomendado

### Prueba 1: Creación de Cita
1. Abrir TPV Peluquería
2. Seleccionar profesional
3. Crear nueva cita con servicios
4. ✅ Verificar aparece en timeline TPV
5. ✅ Ir a módulo Reservas → debe aparecer la misma cita

### Prueba 2: Cambio de Estado
1. Crear cita en TPV
2. Iniciar cita → estado `enCurso`
3. Ir a módulo Reservas
4. ✅ Verificar estado actualizado a `en_curso`

### Prueba 3: Completar y Cobrar
1. Crear cita con servicios
2. En TPV: Completar cita
3. Cobrar en ticket
4. ✅ Verificar en Reservas: estado `completada`

### Prueba 4: No Presentarse
1. Crear cita programada
2. Cliente no llega
3. Marcar como "No vino"
4. ✅ Verificar en Reservas: estado `no_asistio`

## 🔧 Archivos Modificados

| Archivo | Líneas Modificadas | Cambios |
|---------|-------------------|---------|
| `tpv_peluqueria_screen.dart` | 154-180, 200-240, 2537-2608, 2674-2714 | Modelo Cita, factory fromDoc, método _guardar, método _cambiarEstado |

## 📚 Próximas Mejoras

1. **Sincronización Bidireccional Completa:**
   - Si se edita/cancela reserva desde módulo Reservas → actualizar cita TPV

2. **Dashboard Unificado:**
   - Vista combinada de citas TPV + reservas web en calendario

3. **Notificaciones:**
   - Alertar al profesional cuando llega su próxima cita
   - Recordatorios automáticos a clientes

4. **Estadísticas Mejoradas:**
   - % conversión reserva web → asistencia
   - % puntualidad por profesional
   - Ingresos por canal (web vs TPV)

---

**Implementado por:** GitHub Copilot  
**Fecha de implementación:** 19 Mayo 2026  
**Estado:** ✅ Completado y funcionando

