# 📅 Integración: Configuración de Reservas en el Formulario Web

## Cómo funciona

El formulario HTML de reservas de la web lee **en tiempo real** la configuración guardada desde la app en:

```
empresas/{empresaId}/configuracion/reservas
```

Estructura del documento:
```json
{
  "dias_activos": [1, 2, 3, 4, 5],
  "horario": {
    "1": { "apertura": "09:00", "cierre": "20:00" },
    "2": { "apertura": "09:00", "cierre": "20:00" }
  },
  "dias_cerrados": ["2026-05-25", "2026-08-15"],
  "duracion_slot_minutos": 30
}
```

---

## Código JavaScript para el formulario web

Añade esto en tu formulario de reservas para bloquear automáticamente los días cerrados:

```javascript
// ── CONFIGURACIÓN DE RESERVAS — Fluix CRM ──────────────────────────────────

let configReservas = null;

async function cargarConfigReservas(db, empresaId) {
  try {
    const snap = await db
      .collection("empresas")
      .doc(empresaId)
      .collection("configuracion")
      .doc("reservas")
      .get();
    
    if (snap.exists) {
      configReservas = snap.data();
      console.log("✅ Config reservas cargada:", configReservas);
    }
  } catch (e) {
    console.warn("Fluix CRM: no se pudo cargar config reservas", e);
  }
}

/**
 * Devuelve true si la fecha (objeto Date) NO se puede reservar.
 * Úsalo para deshabilitar días en el date picker.
 */
function esDiaCerrado(fecha) {
  if (!configReservas) return false;
  
  const diasActivos = configReservas.dias_activos || [1, 2, 3, 4, 5];
  const diasCerrados = configReservas.dias_cerrados || [];
  
  // Comprobar día de la semana (getDay devuelve 0=domingo, ISO es 1=lunes..7=domingo)
  const diaSemanaJS = fecha.getDay(); // 0=domingo
  const diaSemanaISO = diaSemanaJS === 0 ? 7 : diaSemanaJS;
  
  if (!diasActivos.includes(diaSemanaISO)) return true;
  
  // Comprobar fechas especiales
  const yyyy = fecha.getFullYear();
  const mm = String(fecha.getMonth() + 1).padStart(2, "0");
  const dd = String(fecha.getDate()).padStart(2, "0");
  const fechaStr = `${yyyy}-${mm}-${dd}`;
  
  return diasCerrados.includes(fechaStr);
}

/**
 * Obtiene el horario de apertura/cierre para una fecha dada.
 * Devuelve null si el día está cerrado.
 */
function obtenerHorarioDia(fecha) {
  if (!configReservas || esDiaCerrado(fecha)) return null;
  
  const diaSemanaJS = fecha.getDay();
  const diaSemanaISO = diaSemanaJS === 0 ? 7 : diaSemanaJS;
  const horario = configReservas.horario?.[String(diaSemanaISO)];
  
  return horario || null; // { apertura: "09:00", cierre: "20:00" }
}

// ── EJEMPLO DE USO CON <input type="date"> ──────────────────────────────────

// En tu formulario:
// <input type="date" id="fecha_reserva" onchange="onFechaCambiada(this.value)">
// <div id="aviso_cerrado" style="display:none;color:red">⚠️ El negocio está cerrado ese día</div>

function onFechaCambiada(valorFecha) {
  if (!valorFecha) return;
  const fecha = new Date(valorFecha + "T12:00:00"); // usar mediodía para evitar problemas de zona horaria
  
  if (esDiaCerrado(fecha)) {
    document.getElementById("aviso_cerrado").style.display = "block";
    document.getElementById("btn_reservar").disabled = true;
  } else {
    document.getElementById("aviso_cerrado").style.display = "none";
    document.getElementById("btn_reservar").disabled = false;
    
    // Mostrar horario del día
    const horario = obtenerHorarioDia(fecha);
    if (horario) {
      console.log(`Horario: ${horario.apertura} – ${horario.cierre}`);
      // Actualizar el campo de hora con límites
      const inputHora = document.getElementById("hora_reserva");
      if (inputHora) {
        inputHora.min = horario.apertura;
        inputHora.max = horario.cierre;
      }
    }
  }
}

// ── FLATPICKR (si usas este selector de fechas) ─────────────────────────────
// Si usas flatpickr en tu web, puedes usar esDiaCerrado directamente:

/*
flatpickr("#fecha_reserva", {
  locale: "es",
  minDate: "today",
  maxDate: new Date().fp_incr(90), // 90 días hacia adelante
  disable: [
    function(date) {
      return esDiaCerrado(date);
    }
  ],
  onChange: function(selectedDates, dateStr, instance) {
    onFechaCambiada(dateStr);
  }
});
*/

// ── INICIALIZACIÓN ──────────────────────────────────────────────────────────
// Llama esto después de inicializar Firebase:
// await cargarConfigReservas(db, EMPRESA_ID);
```

---

## Flujo completo

```
App Flutter (propietario)
  → Pestaña "Config" en Reservas
  → Configura días abiertos, horarios y días cerrados
  → Guarda en Firestore: empresas/{id}/configuracion/reservas (acceso público ✅)
  
Web HTML (clientes)
  → Carga configuración al abrir el formulario
  → Bloquea automáticamente días cerrados en el date picker
  → El cliente NO puede seleccionar fechas no disponibles
  → Al enviar, la reserva llega a la app como PENDIENTE
  → El propietario recibe una notificación push 📱
```

