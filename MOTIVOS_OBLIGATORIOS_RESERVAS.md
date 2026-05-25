# ✅ Motivos Obligatorios en Días Cerrados - 19 Mayo 2026

## 🎯 CAMBIO REALIZADO

Ahora **es obligatorio** especificar un motivo cuando marcas:
- ✅ Días cerrados específicos
- ✅ Intervalos de fechas cerradas

El motivo se muestra en el formulario web de reservas.

---

## 📝 QUÉ SE MODIFICÓ

### 1️⃣ **Días Cerrados Específicos**

**ANTES** (opcional):
```
┌─────────────────────────────────┐
│ Motivo del cierre               │
│                                 │
│ [Texto opcional]                │
│                                 │
│ [Sin motivo] [Guardar]          │
└─────────────────────────────────┘
```

**AHORA** (obligatorio):
```
┌─────────────────────────────────┐
│ 📝 Motivo del cierre            │
│                                 │
│ Este mensaje se mostrará en     │
│ el formulario web.              │
│                                 │
│ ℹ️ Motivo *                     │
│ [Vacaciones de verano]          │
│ * Campo obligatorio             │
│                                 │
│ [Cancelar] [Guardar]            │
└─────────────────────────────────┘

⚠️ No puedes guardar sin motivo
```

### 2️⃣ **Intervalos de Fechas**

**ANTES** (opcional):
```
Motivo (opcional)
[Vacaciones de verano]
```

**AHORA** (obligatorio):
```
ℹ️ Motivo *
[Vacaciones de verano]
* Se mostrará en el formulario web

⚠️ El botón Guardar está deshabilitado hasta que escribas un motivo
```

---

## 🗂️ ARCHIVOS MODIFICADOS

### `lib/features/reservas/pantallas/configuracion_reservas_screen.dart`

#### **Método `_agregarDiaCerrado()`** (línea ~367)

**Cambios:**
- ❌ Eliminado botón "Sin motivo"
- ✅ Campo marcado como obligatorio con `*`
- ✅ Validación: no se puede guardar si el motivo está vacío
- ✅ barrierDismissible: false (no se puede cerrar tocando fuera)
- ✅ Mensaje de ayuda: "Este mensaje se mostrará en el formulario web"
- ✅ Si cancela o no pone motivo, no se agregan los días

**Código clave:**
```dart
if (texto.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('⚠️ El motivo es obligatorio'),
      backgroundColor: Colors.orange,
    ),
  );
  return;
}

// Si cancela o no pone motivo, no se agregan los días
if (motivo == null || motivo.isEmpty) return;

// Siempre guardar el motivo
nuevosMotivos[s] = motivo;
```

#### **Clase `_DialogoIntervaloFechas`** (línea ~1871)

**Cambios:**
- ✅ Campo `Motivo *` (asterisco indica obligatorio)
- ✅ Texto de ayuda: "Se mostrará en el formulario web"
- ✅ El botón Guardar se habilita solo si hay: inicio + fin + motivo
- ✅ `onChanged: (_) => setState(() {})` para actualizar botón en tiempo real

**Código clave:**
```dart
final puedeGuardar = _inicio != null && 
                     _fin != null && 
                     _motivoCtrl.text.trim().isNotEmpty;

TextField(
  controller: _motivoCtrl,
  onChanged: (_) => setState(() {}), // Reactiva botón
  decoration: InputDecoration(
    labelText: 'Motivo *',
    helperText: '* Se mostrará en el formulario web',
  ),
)
```

### `lib/domain/modelos/seccion_web.dart`

#### **Clase `ConfigReservasWeb`** (línea ~678)

**Campos agregados:**
```dart
/// Motivos de cierre por fecha: "YYYY-MM-DD" → "Vacaciones de verano"
final Map<String, String> motivosCierre;

/// Días recurrentes cerrados: [2, 6] = martes y sábados
final List<int> diasRecurrentesCerrados;

/// Intervalos cerrados con motivo
final List<Map<String, String>> intervalosCerrados;

/// Duración de cada slot (para generar horarios)
final int duracionSlotMinutos;

/// Horario por día: {"1": {"apertura": "09:00", "cierre": "20:00"}}
final Map<String, Map<String, String>> horarioPorDia;

/// Horarios específicos por día: {"1": ["09:00", "09:30", ...]}
final Map<String, List<String>> horariosReservaPorDia;
```

**Por qué es importante:**
- ✅ El formulario web lee `ConfigReservasWeb` desde Firestore
- ✅ Ahora puede mostrar los motivos de cierre
- ✅ Puede verificar días recurrentes e intervalos
- ✅ Puede generar horarios dinámicamente según `duracionSlotMinutos`

---

## 🧪 CÓMO PROBARLO

### 1. **Agregar día cerrado sin motivo**

```
1. Configuración → Reservas → Tab "Vacaciones"
2. Toca "Día específico" (azul)
3. Selecciona una fecha en el calendario
4. En el diálogo de motivo:
   - Deja el campo vacío
   - Toca "Guardar"
   
✅ RESULTADO: Aparece mensaje "⚠️ El motivo es obligatorio"
              No se cierra el diálogo
```

### 2. **Agregar día cerrado CON motivo**

```
1. Selecciona una fecha
2. Escribe: "Festivo local"
3. Toca "Guardar"

✅ RESULTADO: Se cierra el diálogo
              Aparece la fecha con el motivo visible
```

### 3. **Agregar intervalo sin motivo**

```
1. Toca "Intervalo" (morado)
2. Selecciona: Desde 1 ago → Hasta 31 ago
3. Deja el motivo vacío

✅ RESULTADO: El botón "Guardar" está DESHABILITADO (gris)
              No puedes guardar
```

### 4. **Agregar intervalo CON motivo**

```
1. Mismo intervalo (1-31 agosto)
2. Escribe: "Vacaciones de verano"
3. Botón "Guardar" se habilita
4. Toca "Guardar"

✅ RESULTADO: Aparece tarjeta morada con:
              "1 Ago - 31 Ago 2026"
              "Vacaciones de verano"
```

---

## 🌐 SINCRONIZACIÓN WEB

### Firestore: `empresas/{id}/configuracion/reservas_web`

**Estructura guardada:**
```javascript
{
  // Días específicos cerrados
  "fechas_bloqueadas": ["2026-05-29", "2026-12-25"],
  
  // ✨ NUEVO: Motivos por fecha
  "motivos_cierre": {
    "2026-05-29": "Festivo local",
    "2026-12-25": "Navidad"
  },
  
  // ✨ NUEVO: Días recurrentes (todos los martes = 2)
  "dias_recurrentes_cerrados": [2, 7],  // Martes y domingos
  
  // ✨ NUEVO: Intervalos con motivo
  "intervalos_cerrados": [
    {
      "inicio": "2026-08-01",
      "fin": "2026-08-31",
      "motivo": "Vacaciones de verano"
    }
  ],
  
  // Configuración de horarios
  "duracion_slot_minutos": 30,
  "horario_por_dia": {
    "1": {"apertura": "09:00", "cierre": "20:00"}
  },
  
  // Otros campos
  "activo": true,
  "aforo_maximo_por_franja": 2
}
```

---

## 💻 CÓMO USAR EN EL FORMULARIO WEB

### JavaScript para verificar si un día está cerrado:

```javascript
// Obtener config desde Firestore
const config = await firebase.firestore()
  .collection('empresas')
  .doc(empresaId)
  .collection('configuracion')
  .doc('reservas_web')
  .get();

const data = config.data();

// Función para verificar si una fecha está cerrada
function estaCerrado(fecha) {
  const fechaStr = formatearFecha(fecha); // "2026-05-29"
  
  // 1. Verificar días específicos
  if (data.fechas_bloqueadas.includes(fechaStr)) {
    return {
      cerrado: true,
      motivo: data.motivos_cierre[fechaStr] || 'Cerrado'
    };
  }
  
  // 2. ✨ Verificar días recurrentes
  const diaSemana = fecha.getDay(); // 0=domingo, 1=lunes, etc.
  const diaISO = diaSemana === 0 ? 7 : diaSemana; // Convertir a ISO (1=lunes)
  
  if (data.dias_recurrentes_cerrados?.includes(diaISO)) {
    const nombreDia = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][diaISO];
    return {
      cerrado: true,
      motivo: `Cerrado todos los ${nombreDia}`
    };
  }
  
  // 3. ✨ Verificar intervalos
  if (data.intervalos_cerrados) {
    for (const intervalo of data.intervalos_cerrados) {
      const inicio = new Date(intervalo.inicio);
      const fin = new Date(intervalo.fin);
      
      if (fecha >= inicio && fecha <= fin) {
        return {
          cerrado: true,
          motivo: intervalo.motivo || 'Cerrado por vacaciones'
        };
      }
    }
  }
  
  return { cerrado: false };
}

// Usar en el formulario
const resultado = estaCerrado(new Date('2026-08-15'));
if (resultado.cerrado) {
  mostrarMensaje(`⛔ ${resultado.motivo}`);
  deshabilitarSelector();
}
```

### HTML para mostrar el mensaje:

```html
<div id="mensaje-cerrado" style="display: none; color: red; padding: 10px; background: #ffebee; border-radius: 4px; margin-top: 10px;">
  <strong>⛔ No disponible</strong><br>
  <span id="motivo-cierre"></span>
</div>

<script>
function mostrarMensajeCerrado(motivo) {
  document.getElementById('mensaje-cerrado').style.display = 'block';
  document.getElementById('motivo-cierre').textContent = motivo;
}

// Al seleccionar fecha
inputFecha.addEventListener('change', (e) => {
  const fechaSeleccionada = new Date(e.target.value);
  const resultado = estaCerrado(fechaSeleccionada);
  
  if (resultado.cerrado) {
    mostrarMensajeCerrado(resultado.motivo);
  } else {
    document.getElementById('mensaje-cerrado').style.display = 'none';
  }
});
</script>
```

---

## 📊 EJEMPLOS DE USO

### Restaurante:
```
Día cerrado: 25 diciembre 2026
Motivo: "Cerrado por Navidad - Felices fiestas"

→ En la web aparece:
  ⛔ No disponible
  Cerrado por Navidad - Felices fiestas
```

### Peluquería:
```
Intervalo: 1-31 agosto 2026
Motivo: "Vacaciones del personal"

→ En la web (cualquier día de agosto):
  ⛔ No disponible  
  Vacaciones del personal
```

### Hotel:
```
Días recurrentes: Todos los lunes (1)
Motivo mostrado: "Cerrado todos los lunes"

→ En la web (cualquier lunes):
  ⛔ No disponible
  Cerrado todos los lunes
```

---

## ✅ RESUMEN

**Antes:**
- Motivos opcionales
- Se podía agregar día cerrado sin explicación
- La web no sabía por qué estaba cerrado

**Ahora:**
- ✅ Motivos obligatorios
- ✅ No se puede guardar sin motivo
- ✅ Validación en tiempo real
- ✅ Mensaje claro para el usuario
- ✅ Sincronización automática con Firestore
- ✅ El formulario web puede mostrar el motivo

---

## 🎉 BENEFICIOS

1. **Mejor experiencia de usuario en la web**
   - Saben por qué no pueden reservar
   - Mensajes personalizados ("Vacaciones", "Festivo", etc.)

2. **Profesionalidad**
   - No solo "cerrado", sino "Cerrado por reformas" o "Vacaciones de verano"

3. **Transparencia**
   - Los clientes entienden el motivo del cierre

4. **Menos consultas**
   - Al ver el motivo, no llaman preguntando por qué está cerrado

---

**Documentado el 19 de mayo de 2026**

