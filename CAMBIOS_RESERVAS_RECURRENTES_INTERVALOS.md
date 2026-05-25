# 🎯 Cambios: Días Recurrentes e Intervalos en Reservas

## 📅 Fecha: 19 Mayo 2026

---

## ✅ PROBLEMAS RESUELTOS

### 1️⃣ **Time Picker No Respondía**
   - **Problema**: El selector de horas (9:00, 10:00, etc.) no permitía scroll para cambiar la hora
   - **Solución**: Cambiado `FixedExtentScrollPhysics()` a `BouncingScrollPhysics()` en líneas 1186 y 1222
   - **Resultado**: Ahora puedes mover la rueda para cambiar de 9 a 10 (o cualquier hora)

### 2️⃣ **Días Recurrentes Cerrados**
   - **Nueva funcionalidad**: Ahora puedes marcar "todos los martes cerrados" o "todos los domingos"
   - **Beneficio**: No necesitas añadir cada martes individualmente
   - **Ubicación**: Botón naranja "Recurrente" en tab Vacaciones

### 3️⃣ **Intervalos de Fechas**
   - **Nueva funcionalidad**: Selecciona un rango "del 13 al 15 de mayo" para vacaciones
   - **Beneficio**: No necesitas añadir día por día
   - **Ubicación**: Botón morado "Intervalo" en tab Vacaciones

---

## 📂 ARCHIVOS MODIFICADOS

### `lib/features/reservas/pantallas/configuracion_reservas_screen.dart`

#### **Modelo `ConfigReservas`** (líneas 11-106)

```dart
// NUEVOS CAMPOS:
final List<int> diasRecurrentesCerrados;      // [2, 5] = martes y viernes siempre cerrados  
final List<Map<String, String>> intervalosCerrados;  // [{inicio: "2026-05-13", fin: "2026-05-15", motivo: "Vacaciones"}]
```

#### **Método `estaCerrado()`** actualizado (líneas 88-109)
Ahora verifica:
1. Si es un día específico cerrado
2. Si es un día recurrente cerrado (ej: todos los martes)
3. Si está dentro de un intervalo cerrado

#### **Nuevos métodos** (líneas 428-502)
- `_agregarDiaRecurrente()` - Abre diálogo para seleccionar días de semana
- `_agregarIntervalo()` - Abre diálogo para seleccionar rango de fechas
- `_eliminarIntervalo(int index)` - Elimina un intervalo específico

#### **Tab Vacaciones rediseñado** (líneas 972-1093)
Ahora tiene **3 botones**:
- 🔵 **Día específico** (azul) - Como antes
- 🟠 **Recurrente** (naranja) - Nuevo
- 🟣 **Intervalo** (morado) - Nuevo

#### **Nuevos diálogos** (líneas 1747-2018)

**`_DialogoDiasRecurrentes`** (líneas 1747-1837)
- Muestra checkboxes de lunes a domingo
- Permite marcar múltiples días
- Guarda como lista de números (1=lunes, 7=domingo)

**`_DialogoIntervaloFechas`** (líneas 1843-2018)
- Dos botones: "Desde..." y "Hasta..."
- Campo de texto para motivo (opcional)
- Valida que fecha fin sea posterior a inicio

---

## 🔄 SINCRONIZACIÓN CON WEB

### `_sincronizarConfigWeb()` actualizado (líneas 233-250)

Ahora envía a Firestore `empresas/{id}/configuracion/reservas_web`:

```javascript
{
  fechas_bloqueadas: ["2026-05-29", ...],           // Días específicos
  motivos_cierre: {"2026-05-29": "Falta de personal"},
  dias_recurrentes_cerrados: [2, 5],                // NUEVO: martes y viernes
  intervalos_cerrados: [{                           // NUEVO: rangos
    inicio: "2026-05-13",
    fin: "2026-05-15",
    motivo: "Vacaciones de verano"
  }],
  duracion_slot_minutos: 30,
  horario_por_dia: {...},
  horarios_reserva_por_dia: {...}
}
```

---

## 🎨 INTERFAZ DE USUARIO

### Tab Vacaciones - Vista Actual

```plaintext
┌─────────────────────────────────────────────────┐
│  Días cerrados / Vacaciones                     │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Día específico] [Recurrente] [Intervalo]      │
│     (azul)          (naranja)    (morado)       │
│                                                 │
│  ─── Cerrado todos los... ───                   │
│  [🔒 Martes  ×]  [🔒 Viernes  ×]               │
│                                                 │
│  ─── Intervalos cerrados ───                    │
│  📅 13 May - 15 May 2026                        │
│     Vacaciones de verano                [×]     │
│                                                 │
│  ─── Días específicos cerrados ───              │
│  📅 29                                          │
│     Viernes, 29 mayo                    [×]     │
│     Falta de personal                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🧪 CÓMO PROBAR

### 1. Time Picker (Hora de apertura/cierre)
```text
1. Configuración → Reservas → Tab "Horarios"
2. Toca el chip verde "09:00" del lunes
3. Desliza el dedo arriba/abajo en las horas
4. ✅ Debe cambiar de 9 a 10, 11, etc. sin problemas
```

### 2. Días Recurrentes
```text
1. Tab "Vacaciones"
2. Toca botón naranja "Recurrente"
3. Marca "Martes" y "Viernes"
4. Guardar
5. ✅ Aparecerán chips naranjas "Martes" "Viernes"
6. Guarda la configuración (botón arriba)
7. ✅ Verás "Configuración guardada y sincronizada con web"
```

### 3. Intervalos de Fechas
```text
1. Tab "Vacaciones"
2. Toca botón morado "Intervalo"
3. "Desde..." → Selecciona 13 mayo 2026
4. "Hasta..." → Selecciona 15 mayo 2026
5. Motivo: "Vacaciones de verano"
6. Guardar
7. ✅ Aparecerá tarjeta morada con el rango
8. Guarda la configuración
```

---

## 📊 MODELO DE DATOS

### Antes
```dart
class ConfigReservas {
  List<int> diasActivos;
  Map<String, Map<String, String>> horario;
  List<String> diasCerrados;              // Solo días específicos
  Map<String, String> motivosCierre;
  int duracionSlotMinutos;
  Map<String, List<String>> horariosReserva;
}
```

### Después
```dart
class ConfigReservas {
  List<int> diasActivos;
  Map<String, Map<String, String>> horario;
  List<String> diasCerrados;                          // Días específicos
  Map<String, String> motivosCierre;
  List<int> diasRecurrentesCerrados;                  // ✨ NUEVO
  List<Map<String, String>> intervalosCerrados;       // ✨ NUEVO
  int duracionSlotMinutos;
  Map<String, List<String>> horariosReserva;
}
```

---

## 🔄 LÓGICA DE VERIFICACIÓN

### `estaCerrado(DateTime fecha)`

```dart
bool estaCerrado(DateTime fecha) {
  // 1. ¿Es un día no activo? (ej: si solo abres lunes-viernes y es sábado)
  if (!diasActivos.contains(fecha.weekday)) return true;
  
  // 2. ¿Está en la lista de días específicos? (ej: 29 mayo 2026)
  if (diasCerrados.contains("2026-05-29")) return true;
  
  // 3. ✨ NUEVO: ¿Es un día recurrente cerrado? (ej: todos los martes)
  if (diasRecurrentesCerrados.contains(2)) return true;  // 2 = martes
  
  // 4. ✨ NUEVO: ¿Está dentro de un intervalo?
  for (final intervalo in intervalosCerrados) {
    if (fecha >= inicio && fecha <= fin) return true;
  }
  
  return false;
}
```

---

## 🚀 PRÓXIMOS PASOS RECOMENDADOS

### 1. Actualizar Formulario Web
El HTML debe leer y verificar los nuevos campos:

```javascript
// En el formulario de reservas web
const config = await firebase.firestore()
  .collection('empresas').doc(empresaId)
  .collection('configuracion').doc('reservas_web')
  .get();

const diasRecurrentesCerrados = config.data().dias_recurrentes_cerrados || [];
const intervalosCerrados = config.data().intervalos_cerrados || [];

// Verificar si fecha está cerrada
function estaCerrado(fecha) {
  // 1. Verificar días específicos
  if (fechasBloqueadas.includes(formatearFecha(fecha))) return true;
  
  // 2. ✨ Verificar días recurrentes
  if (diasRecurrentesCerrados.includes(fecha.getDay())) return true;
  
  // 3. ✨ Verificar intervalos
  for (const intervalo of intervalosCerrados) {
    const inicio = new Date(intervalo.inicio);
    const fin = new Date(intervalo.fin);
    if (fecha >= inicio && fecha <= fin) {
      return { cerrado: true, motivo: intervalo.motivo };
    }
  }
  
  return false;
}
```

### 2. Mensaje Mejorado en Web
```javascript
// Mostrar motivo según tipo de cierre
if (resultado.cerrado) {
  if (resultado.motivo) {
    mostrarError(`⛔ Cerrado: ${resultado.motivo}`);
  } else if (diasRecurrentesCerrados.includes(fecha.getDay())) {
    const nombreDia = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'][fecha.getDay()];
    mostrarError(`⛔ Cerrado todos los ${nombreDia}`);
  }
}
```

---

## 📝 RESUMEN EJECUTIVO

### ✅ Completado
- ✅ Time picker funcional (scroll suave)
- ✅ Días recurrentes cerrados (modelo + UI + lógica)
- ✅ Intervalos de fechas (modelo + UI + lógica)
- ✅ Sincronización con Firestore `reservas_web`
- ✅ Interfaz visual con 3 botones de colores
- ✅ Diálogos intuitivos para selección

### ⏳ Pendiente (Opcional)
- ⏳ Actualizar formulario web HTML (ejemplo proporcionado arriba)
- ⏳ Testing en producción con datos reales
- ⏳ Agregar límite de intervalos (ej: máximo 10)

---

## 🎉 RESULTADO FINAL

Antes necesitabas añadir manualmente:
- 29 mayo, 5 junio, 12 junio, 19 junio, 26 junio... (cada martes)

Ahora solo marcas:
- "Todos los martes" 🟠 (1 clic)

Antes necesitabas añadir:
- 13 mayo, 14 mayo, 15 mayo (3 días de vacaciones)

Ahora solo defines:
- Intervalo: 13-15 mayo, motivo: "Vacaciones" 🟣 (1 diálogo)

**¡3 veces más rápido! 🚀**

---

**Documentado el 19 de mayo de 2026**

