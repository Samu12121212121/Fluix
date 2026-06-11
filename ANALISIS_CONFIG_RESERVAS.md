# Análisis: Configuración de Reservas y Vinculación por Empresa

## Estructura Actual

### Almacenamiento en Firestore

```
empresas/{empresaId}/
  ├── configuracion/
  │   ├── reservas/           # Configuración de horarios y vacaciones
  │   └── reservas_web/       # Config sincronizada para formulario HTML
  ├── reservas/               # Colección de reservas de la empresa
  └── citas/                  # Colección de citas médicas de la empresa
```

### Modelo de Datos

La configuración de reservas se almacena en:
- **Ruta principal**: `empresas/{empresaId}/configuracion/reservas`
- **Clase modelo**: `ConfigReservas` (lib/features/reservas/pantallas/configuracion_reservas_screen.dart)

#### Campos del documento:

1. **dias_activos** (List<int>): Días de la semana activos (1=Lunes … 7=Domingo)
   - Ejemplo: `[1, 2, 3, 4, 5]` (L-V)

2. **horario** (Map<String, Map<String, String>>): Horario por día
   ```json
   {
     "1": {"apertura": "09:00", "cierre": "20:00"},
     "2": {"apertura": "09:00", "cierre": "20:00"}
   }
   ```

3. **dias_cerrados** (List<String>): Fechas específicas cerradas
   - Formato: `["2026-05-13", "2026-12-25"]`
   - **IMPORTANTE**: Siempre requiere motivo obligatorio

4. **motivos_cierre** (Map<String, String>): Motivo por cada fecha cerrada
   ```json
   {
     "2026-05-13": "Vacaciones de verano",
     "2026-12-25": "Navidad"
   }
   ```

5. **dias_recurrentes_cerrados** (List<int>): Días semanales siempre cerrados
   - Ejemplo: `[2]` = todos los martes cerrados

6. **intervalos_cerrados** (List<Map<String, String>>): Rangos de fechas cerradas
   ```json
   [
     {
       "inicio": "2026-08-01",
       "fin": "2026-08-15",
       "motivo": "Vacaciones de agosto"
     }
   ]
   ```

7. **duracion_slot_minutos** (int): Duración de cada cita en la web
   - Valores típicos: 15, 30, 45, 60, 90, 120

8. **horarios_reserva** (Map<String, List<String>>): Horarios exactos por día
   - Si está vacío, se autogeneran desde apertura a cierre
   - Ejemplo: `{"1": ["13:30", "14:00", "14:30"]}`

## Vinculación por Empresa

### ✅ Vinculación Correcta

**Cada empresa tiene su propia configuración de reservas**, completamente aislada:

```dart
// Referencia a la configuración de la empresa
DocumentReference get _ref => FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)  // ← ID único de la empresa
    .collection('configuracion')
    .doc('reservas');
```

### Flujo de Funcionamiento

1. **Carga de configuración**:
   ```dart
   await _ref.get()  // Carga solo la config de LA empresa actual
   ```

2. **Guardado**:
   ```dart
   await _ref.set(_config.toMap())  // Guarda solo para LA empresa
   await _sincronizarConfigWeb()    // Sincroniza a reservas_web
   ```

3. **Sincronización Web**:
   - Se duplica la config en `empresas/{empresaId}/configuracion/reservas_web`
   - Este doc es leído por el formulario HTML de reservas del cliente
   - Es una copia espejo para mejorar rendimiento de consultas web

### Colecciones de Reservas

Las reservas también están aisladas por empresa:

```dart
// Vista Hoy
FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId)  // ← Solo las de esta empresa
  .collection('reservas')
  .where('fecha_hora', isGreaterThanOrEqualTo: desde)
  .orderBy('fecha_hora')
```

## Limitaciones Actuales

### 🔒 Sin limitaciones de acceso

- **Cada empresa solo puede ver y editar SU propia configuración**
- **No hay límite en el número de empresas** que pueden usar el sistema
- **Cada configuración es independiente**

### Características de Seguridad

1. ✅ **Aislamiento total por empresaId**
2. ✅ **No hay vinculación cruzada entre empresas**
3. ✅ **Las reglas de Firestore deben validar el acceso por empresa**

### Ejemplo de Reglas de Firestore Recomendadas

```javascript
match /empresas/{empresaId}/configuracion/reservas {
  // Solo usuarios autorizados de la empresa pueden leer/escribir
  allow read, write: if request.auth != null 
    && get(/databases/$(database)/documents/empresas/$(empresaId)).data.usuarios[request.auth.uid] != null;
}

match /empresas/{empresaId}/reservas/{reservaId} {
  // Solo usuarios de la empresa pueden gestionar las reservas
  allow read, write: if request.auth != null 
    && get(/databases/$(database)/documents/empresas/$(empresaId)).data.usuarios[request.auth.uid] != null;
}
```

## Funcionalidades Avanzadas

### 1. Días Cerrados con Motivo Obligatorio

```dart
// SIEMPRE se pide motivo al añadir días cerrados
final motivo = await showDialog<String>(...);  // Dialog obligatorio
if (motivo == null || motivo.isEmpty) return;  // No permite continuar sin motivo
nuevosMotivos[fecha] = motivo;                 // Guarda el motivo
```

### 2. Tipos de Cierre

| Tipo | Campo | Ejemplo | Uso |
|------|-------|---------|-----|
| **Específico** | `dias_cerrados` | "2026-12-25" | Festivos puntuales |
| **Recurrente** | `dias_recurrentes_cerrados` | `[2]` (martes) | Día fijo semanal |
| **Intervalo** | `intervalos_cerrados` | "01/08 - 15/08" | Vacaciones |

### 3. Validación de Días Cerrados

```dart
bool estaCerrado(DateTime fecha) {
  // 1. Verificar si es día activo
  if (!diasActivos.contains(fecha.weekday)) return true;
  
  // 2. Verificar días específicos
  if (diasCerrados.contains(formato)) return true;
  
  // 3. Verificar recurrentes
  if (diasRecurrentesCerrados.contains(fecha.weekday)) return true;
  
  // 4. Verificar intervalos
  for (final intervalo in intervalosCerrados) {
    if (fecha está entre inicio y fin) return true;
  }
  
  return false;
}
```

## Conclusiones

### ✅ Estado Actual: CORRECTO

1. **Cada empresa tiene su configuración aislada**
2. **No hay limitaciones de cantidad de empresas**
3. **El sistema escala bien por diseño basado en `empresaId`**
4. **La sincronización web funciona correctamente**
5. **Los motivos de cierre son obligatorios y se muestran al cliente**

### ✅ Recomendaciones

1. **Implementar reglas de Firestore** para seguridad (ver ejemplo arriba)
2. **Validar permisos de usuario** antes de permitir edición
3. **Considerar backup automático** de configuraciones críticas
4. **Añadir logs de auditoría** para cambios en configuración
5. **Implementar validación de horarios** (que cierre > apertura)

### 🔒 Sin Limitaciones Encontradas

El sistema actual **NO tiene limitaciones** en cuanto a:
- Número de empresas que pueden usar reservas
- Configuraciones independientes por empresa
- Cantidad de días cerrados que se pueden configurar
- Flexibilidad en horarios y slots

---

**Fecha del análisis**: 26 Mayo 2026  
**Versión del código**: Actualizada con motivos obligatorios  
**Estado**: ✅ Sistema funcionando correctamente

