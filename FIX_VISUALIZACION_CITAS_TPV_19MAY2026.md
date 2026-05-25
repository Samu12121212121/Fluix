# Fix Visualización de Citas en Timeline TPV
**Fecha:** 19 Mayo 2026  
**Estado:** ✅ Implementado

## 🐛 Problema Identificado

Al crear una cita manualmente en el TPV de peluquería, la cita se guardaba correctamente en Firestore pero **NO aparecía visualmente en el timeline/agenda** del TPV.

### Causa Raíz:

El timeline del TPV filtra las citas por:
```dart
.where('prof_id', isEqualTo: widget.profId)  // Profesional actualmente seleccionado
.where('fecha', isEqualTo: widget.fechaStr)   // Fecha actual
```

**Problema:** Cuando se creaba una cita para un profesional diferente al que estaba seleccionado en ese momento, la cita se guardaba correctamente pero no aparecía porque el filtro de `prof_id` no coincidía.

### Escenarios Problemáticos:

1. **Sin profesional seleccionado:**
   - Usuario abre TPV → No hay profesional seleccionado
   - Crea cita para "Ana Pérez"
   - Timeline vacío → cita no visible

2. **Profesional diferente seleccionado:**
   - Usuario tiene seleccionado a "Juan García"
   - Crea cita para "María López"  
   - Timeline muestra solo citas de Juan → cita de María no visible

3. **Confusión del usuario:**
   - "¿Dónde está mi cita? ¡Acabo de crearla!"
   - Cita existe en BD, pero no se ve en pantalla

---

## ✅ Solución Implementada

### Cambio Automático de Profesional

Después de crear una cita, el sistema **automáticamente cambia la vista** al profesional de la cita recién creada.

### Código Modificado:

#### 1. Método `_mostrarDialogoNuevaCita()` (Línea 604)

**Antes:**
```dart
void _mostrarDialogoNuevaCita() {
  showDialog(
    context: context,
    builder: (_) => _DialogoNuevaCita(
      empresaId: widget.empresaId,
      fecha: _fechaStr,
      profIdInicial: _profIdSeleccionado,
    ),
  );
}
```

**Después:**
```dart
void _mostrarDialogoNuevaCita() async {
  final resultado = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _DialogoNuevaCita(
      empresaId: widget.empresaId,
      fecha: _fechaStr,
      profIdInicial: _profIdSeleccionado,
    ),
  );
  
  // ✅ Si se creó una cita, cambiar al profesional seleccionado
  if (resultado != null && resultado['profId'] != null) {
    final profId = resultado['profId'] as String;
    final profIdx = resultado['profIdx'] as int? ?? 0;
    
    if (mounted) {
      setState(() {
        _profIdSeleccionado = profId;
        _profColorIdx = profIdx;
      });
    }
  }
}
```

#### 2. Método `_guardar()` del Diálogo (Línea 2540)

**Modificación al final del método:**

```dart
if (mounted) {
  // ✅ Encontrar el índice del profesional en la lista para el color
  final profIdx = _profesionales.indexWhere((p) => p.id == _profId);
  
  // ✅ Devolver el profId y su índice para cambiar la vista
  Navigator.pop(context, {
    'profId': _profId,
    'profIdx': profIdx >= 0 ? profIdx : 0,
  });
}
```

---

## 🎯 Flujo Completo Nuevo

### Escenario 1: Sin profesional seleccionado

```
1. Usuario abre TPV de Peluquería
   Timeline: vacío (no hay profesional seleccionado)
   ↓
2. Click "Nueva cita"
   ↓
3. Formulario:
   - Cliente: "María García"
   - Profesional: "Ana Pérez" (selecciona del dropdown)
   - Hora: 10:30
   - Servicio: "Corte de pelo"
   ↓
4. Click "Guardar cita"
   ↓
5. Sistema:
   ✅ Crea RESERVA en 'reservas'
   ✅ Crea CITA en 'citas'
   ✅ Devuelve profId de "Ana Pérez"
   ↓
6. Pantalla automáticamente:
   ✅ Selecciona a "Ana Pérez" en la fila de profesionales
   ✅ Timeline actualizado con filtro prof_id="ana_perez"
   ✅ StreamBuilder recibe actualización
   ↓
7. ✅ CITA VISIBLE en timeline a las 10:30
```

### Escenario 2: Profesional diferente al seleccionado

```
1. Usuario tiene seleccionado "Juan García"
   Timeline: muestra citas de Juan
   ↓
2. Click "Nueva cita"
   ↓
3. Formulario:
   - Cliente: "Pedro López"
   - Profesional: "María Rodríguez" (diferente a Juan)
   - Hora: 15:00
   ↓
4. Click "Guardar cita"
   ↓
5. Sistema:
   ✅ Cambia automáticamente a "María Rodríguez"
   ✅ Timeline actualiza filtro
   ↓
6. ✅ CITA VISIBLE en timeline de María a las 15:00
```

### Escenario 3: Mismo profesional seleccionado

```
1. Usuario tiene seleccionado "Ana Pérez"
   ↓
2. Crea cita para "Ana Pérez" (mismo profesional)
   ↓
3. Sistema:
   ✅ Mantiene selección en Ana
   ✅ Timeline ya está filtrado correctamente
   ↓
4. ✅ CITA VISIBLE inmediatamente (sin cambios)
```

---

## 📊 Datos Técnicos

### Estructura del Resultado del Diálogo:

```dart
// Devuelve al cerrar el diálogo tras crear exitosamente:
{
  'profId': 'abc123xyz',  // ID de Firestore del profesional
  'profIdx': 2            // Índice en el array para el color
}
```

### Actualización del Estado:

```dart
setState(() {
  _profIdSeleccionado = profId;  // Cambia el filtro del StreamBuilder
  _profColorIdx = profIdx;        // Actualiza el color del timeline
});
```

### Listener del StreamBuilder (_AgendaTab):

```dart
_sub = FirebaseFirestore.instance
    .collection('empresas')
    .doc(widget.empresaId)
    .collection('citas')
    .where('prof_id', isEqualTo: widget.profId)  // ← Se actualiza automáticamente
    .where('fecha', isEqualTo: widget.fechaStr)
    .snapshots()
    .listen((snap) {
      // ✅ Recibe la nueva cita inmediatamente
    });
```

---

## 🧪 Testing

### Caso 1: Crear cita sin profesional seleccionado
1. ✅ Abrir TPV → No seleccionar profesional
2. ✅ Crear cita para "Ana"
3. ✅ Verificar que Ana se selecciona automáticamente
4. ✅ Verificar cita visible en timeline

### Caso 2: Crear cita para profesional diferente
1. ✅ Seleccionar "Juan"
2. ✅ Crear cita para "María"
3. ✅ Verificar cambio automático a María
4. ✅ Verificar cita visible en timeline de María

### Caso 3: Crear cita para mismo profesional
1. ✅ Seleccionar "Ana"
2. ✅ Crear cita para "Ana"
3. ✅ Verificar que permanece en Ana
4. ✅ Verificar cita visible inmediatamente

### Caso 4: Cancelar diálogo
1. ✅ Abrir diálogo "Nueva cita"
2. ✅ Click "Cancelar" sin guardar
3. ✅ Verificar que no cambia profesional seleccionado
4. ✅ Verificar que timeline permanece igual

---

## 🔧 Archivos Modificados

| Archivo | Líneas | Cambio |
|---------|--------|--------|
| `tpv_peluqueria_screen.dart` | 604-623 | `_mostrarDialogoNuevaCita()` ahora `async` y espera resultado |
| `tpv_peluqueria_screen.dart` | 2607-2618 | `_guardar()` devuelve Map con profId e índice |

---

## ✅ Beneficios de la Solución

### Experiencia de Usuario Mejorada:

1. **Feedback Inmediato:**
   - ✅ Cita visible inmediatamente tras crearla
   - ✅ No requiere buscar manualmente al profesional

2. **Contexto Automático:**
   - ✅ Vista actualizada al profesional relevante
   - ✅ Usuario siempre ve el resultado de su acción

3. **Reducción de Confusión:**
   - ✅ "Mi cita está ahí" vs "¿Dónde está mi cita?"
   - ✅ Confirmación visual instantánea

4. **Flujo Natural:**
   - ✅ Crear cita → Ver cita → Continuar trabajando
   - ✅ Sin pasos adicionales del usuario

### Funcionamiento Técnico:

```
Crear Cita → Guardar en BD → Devolver profesionalId → 
Actualizar Estado → StreamBuilder Detecta Cambio → 
Consulta con Nuevo prof_id → Timeline Actualizado ✅
```

---

## 🎯 Casos Edge Manejados

| Caso | Comportamiento |
|------|----------------|
| Profesional no existe en lista | Usa índice 0 (primer color) |
| Usuario cancela diálogo | No cambia selección actual |
| Error al guardar cita | Muestra SnackBar, no cambia vista |
| Primera cita del día | Selecciona profesional automáticamente |
| Múltiples profesionales | Cambia al correcto cada vez |

---

## 📝 Notas de Implementación

### Por Qué Devolver Índice (`profIdx`):

El índice se usa para:
- Asignar el color del profesional en el timeline
- Mantener consistencia visual
- Evitar búsqueda adicional en el array de colores

### Future.delayed en Listeners:

```dart
Future.delayed(Duration.zero, () {
  if (mounted) setState(() => _profesionales = merged);
});
```

**Razón:** Fix para Windows desktop donde Firestore listener puede ejecutarse en thread nativo.

---

**Implementado por:** GitHub Copilot  
**Fecha:** 19 Mayo 2026  
**Estado:** ✅ Funcionando perfectamente

