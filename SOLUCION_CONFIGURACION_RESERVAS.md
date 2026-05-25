# 🎯 SOLUCIÓN: Configuración de Reservas - 19 Mayo 2026

## ✅ PROBLEMAS RESUELTOS

### 1️⃣ **Horarios Editables** 
- ✅ Los horarios YA son editables (toca el chip de hora verde/rojo)
- ✅ Se abre un selector tipo ruleta para cambiar hora y minutos
- ✅ Los minutos van de 5 en 5 (0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55)

### 2️⃣ **Duración de Cita → Slots Automáticos**
- ✅ Ya estaba implementado en la app
- ✅ AHORA también funciona en el formulario web
- ✅ Los horarios se generan automáticamente según la duración configurada
- Ejemplo: Si configuras 15 minutos, se generan slots cada 15 min (13:30, 13:45, 14:00...)
- Ejemplo: Si configuras 30 minutos, se generan slots cada 30 min (13:30, 14:00, 14:30...)

### 3️⃣ **Días de Vacaciones con Motivo**
- ✅ Los motivos YA se guardaban en la app
- ✅ AHORA se sincronizan automáticamente con el formulario web
- ✅ El formulario web muestra el motivo del cierre (ej: "⛔ Falta de personal")

### 4️⃣ **Sincronización App ↔ Web**
- ✅ Antes: Configuraciones separadas y desconectadas
- ✅ AHORA: Al guardar en la app, se sincroniza automáticamente con `reservas_web`
- ✅ El formulario HTML lee los horarios, slots y motivos desde Firestore

---

## 🔧 CAMBIOS REALIZADOS

### **1. Modelo `ConfigReservasWeb` extendido** 
📁 `lib/domain/modelos/seccion_web.dart`

**Campos nuevos:**
```dart
- motivosCierre: Map<String, String>       // "2026-05-29" → "Falta de personal"
- duracionSlotMinutos: int                 // 15, 30, 45, 60...
- horarioPorDia: Map<String, Map>          // "1" → {apertura: "09:00", cierre: "20:00"}
- horariosReservaPorDia: Map<String, List> // "1" → ["13:30", "14:00", "14:30"]
```

### **2. Sincronización automática**
📁 `lib/features/reservas/pantallas/configuracion_reservas_screen.dart`

- Al guardar configuración, se sincroniza con `reservas_web`
- Mensaje de confirmación: "✅ Configuración guardada y sincronizada con web"

### **3. Formulario HTML dinámico**
📁 `public_web_visor/formulario_reservas_dinamico.html`

**Mejoras:**
- ✅ Lee `duracion_slot_minutos` y genera horarios automáticamente
- ✅ Lee `horario_por_dia` para saber apertura/cierre de cada día
- ✅ Lee `horarios_reserva_por_dia` si hay slots personalizados
- ✅ Lee `motivos_cierre` y los muestra (ej: "⛔ Falta de personal")
- ✅ Calcula el día de la semana ISO correcto (1=Lunes, 7=Domingo)

---

## 🚀 QUÉ HACER AHORA

### **PASO 1: Recompilar y probar**
```bash
flutter pub get
flutter run
```

### **PASO 2: Re-guardar configuración existente**
1. Abre la app
2. Ve a **Configuración de Reservas**
3. Haz un cambio mínimo (cambia duración de slot y vuelve a poner la original)
4. Toca **Guardar**
5. Verás el mensaje: "✅ Configuración guardada y sincronizada con web"

> ⚠️ **IMPORTANTE**: Esto es necesario para que los días de vacaciones que ya agregaste (como el 29 de mayo) se sincronicen con `reservas_web` y aparezcan con su motivo en la web.

### **PASO 3: Actualizar el HTML de la web**
Reemplaza el HTML del formulario de reservas de la web de Lamajona con el nuevo archivo:
📁 `public_web_visor/formulario_reservas_dinamico.html`

O copia **solo la sección JavaScript** del nuevo archivo (línea 260 en adelante).

---

## 📊 FUNCIONAMIENTO

### **En la App:**
1. Configuras horarios (ej: Lunes 10:00 - 22:00)
2. Configuras duración de cita (ej: 30 minutos)
3. Añades día cerrado (ej: 29 mayo - "Falta de personal")
4. **Guardas** → Se sincroniza automáticamente con `reservas_web`

### **En el Formulario Web:**
1. Lee la configuración desde `reservas_web`
2. Genera horarios cada 30 minutos (10:00, 10:30, 11:00...)
3. Bloquea el 29 de mayo con el mensaje "⛔ Falta de personal"
4. Usa los slots personalizados si los configuraste

---

## 🎨 EJEMPLO VISUAL

### **App - Configuración:**
```
Lunes
  ⏰ Apertura: 10:00
  ⏰ Cierre: 22:00

Duración de cita: 30 minutos

Días cerrados:
  📅 29 Mayo 2026
  📝 Motivo: Falta de personal
```

### **Web - Formulario:**
```
Selecciona fecha: 20/05/2026 (Lunes)
Horarios disponibles:
  ○ 10:00  ○ 10:30  ○ 11:00  ○ 11:30
  ○ 12:00  ○ 12:30  ○ 13:00  ...

Selecciona fecha: 29/05/2026
❌ ⛔ Falta de personal
```

---

## 🔍 DIAGNÓSTICO

### **Si los horarios no aparecen en la web:**
1. Abre la consola del navegador (F12)
2. Busca: `✅ Configuración cargada:`
3. Verifica que `horarioPorDia` tenga datos
4. Verifica que `duracionSlotMinutos` sea correcto

### **Si el motivo no aparece:**
1. Verifica en Firebase Console:
   - `empresas/{id}/configuracion/reservas_web`
   - Debe tener el campo: `motivos_cierre: {"2026-05-29": "Falta de personal"}`
2. Si no está, re-guarda la configuración desde la app (Paso 2 arriba)

---

## 📝 NOTAS TÉCNICAS

### **Día de la semana ISO:**
- 1 = Lunes
- 2 = Martes
- 3 = Miércoles
- 4 = Jueves
- 5 = Viernes
- 6 = Sábado
- 7 = Domingo

### **Formato de fechas:**
- Firestore: `"2026-05-29"` (YYYY-MM-DD)
- JavaScript: `new Date(Date.UTC(2026, 4, 29, 12, 0, 0))` (mes 0-indexed)

### **Colecciones Firestore:**
```
empresas/{id}/
  ├─ configuracion/
  │   ├─ reservas           ← Configuración de la app
  │   └─ reservas_web       ← Configuración del formulario web (SINCRONIZADA)
  └─ reservas/              ← Reservas de clientes
```

---

## ✨ MEJORAS FUTURAS (Opcional)

1. **Bloquear horas específicas por día:**
   - Ejemplo: Lunes no disponible de 14:00 a 16:00

2. **Capacidad diferente por hora:**
   - Ejemplo: 13:00-15:00 → 4 mesas, 21:00-23:00 → 2 mesas

3. **Mensajes personalizados por día cerrado:**
   - En lugar de un solo mensaje, diferentes para festivos, vacaciones, etc.

---

**🎉 ¡LISTO! Ahora la configuración de reservas está 100% sincronizada entre app y web.**

