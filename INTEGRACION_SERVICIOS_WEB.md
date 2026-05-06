# 📋 Integración de Servicios con Formularios Web

## 🎯 Objetivo

Este documento explica cómo integrar el sistema de servicios con los formularios web de reservas y cómo las estadísticas rastrean los servicios más solicitados.

---

## 📊 Estructura de Datos

### Servicio en Firestore

```javascript
empresas/{empresaId}/servicios/{servicioId}
{
  nombre: "Manicura completa",
  descripcion: "Manicura con esmaltado semipermanente",
  precio: 35.00,
  duracion_minutos: 60,
  categoria: "Uñas",
  activo: true,
  empleados_asignados: ["emp_001", "emp_002"], // IDs de empleados que pueden realizar el servicio
  imagenes: [],
  fecha_creacion: "2026-05-06T10:00:00Z"
}
```

### Reserva vinculada a Servicio

```javascript
empresas/{empresaId}/reservas/{reservaId}
{
  cliente_nombre: "María García",
  cliente_email: "maria@example.com",
  cliente_telefono: "+34600000000",
  fecha_hora: Timestamp,
  servicio_id: "servicio_123", // ✨ ID del servicio solicitado
  empleado_asignado: "emp_001", // Opcional: empleado específico
  estado: "pendiente",
  origen: "web",
  comentarios: "Prefiero colores pastel"
}
```

---

## 🌐 Integración con Formulario Web

### 1. Listar Servicios Disponibles

```javascript
// Cargar servicios activos desde Firebase
const db = firebase.firestore();
const empresaId = "tu_empresa_id";

const serviciosSnapshot = await db
  .collection('empresas')
  .doc(empresaId)
  .collection('servicios')
  .where('activo', '==', true)
  .orderBy('categoria')
  .orderBy('nombre')
  .get();

const servicios = serviciosSnapshot.docs.map(doc => ({
  id: doc.id,
  ...doc.data()
}));

// Agrupar por categoría para mostrar en el formulario
const serviciosPorCategoria = servicios.reduce((acc, servicio) => {
  const cat = servicio.categoria || 'General';
  if (!acc[cat]) acc[cat] = [];
  acc[cat].push(servicio);
  return acc;
}, {});
```

### 2. Mostrar Servicios en HTML

```html
<form id="formularioReserva">
  <label for="servicio">Selecciona el servicio:</label>
  <select id="servicio" name="servicio_id" required>
    <option value="">-- Elige un servicio --</option>
  </select>
  
  <div id="infoServicio" style="display:none;">
    <p><strong>Duración:</strong> <span id="duracion"></span></p>
    <p><strong>Precio:</strong> <span id="precio"></span></p>
  </div>
  
  <!-- Selector de empleado (opcional) -->
  <div id="selectorEmpleado" style="display:none;">
    <label for="empleado">¿Prefieres a algún profesional?</label>
    <select id="empleado" name="empleado_asignado">
      <option value="">Cualquiera disponible</option>
    </select>
  </div>
  
  <input type="text" name="nombre" placeholder="Tu nombre" required>
  <input type="email" name="email" placeholder="Tu email" required>
  <input type="tel" name="telefono" placeholder="Tu teléfono" required>
  <input type="datetime-local" name="fecha_hora" required>
  <textarea name="comentarios" placeholder="Comentarios adicionales"></textarea>
  
  <button type="submit">Reservar</button>
</form>

<script>
// Llenar el selector con servicios
const selectServicio = document.getElementById('servicio');
Object.keys(serviciosPorCategoria).forEach(categoria => {
  const optgroup = document.createElement('optgroup');
  optgroup.label = categoria;
  
  serviciosPorCategoria[categoria].forEach(servicio => {
    const option = document.createElement('option');
    option.value = servicio.id;
    option.textContent = `${servicio.nombre} - €${servicio.precio}`;
    option.dataset.duracion = servicio.duracion_minutos;
    option.dataset.precio = servicio.precio;
    option.dataset.empleados = JSON.stringify(servicio.empleados_asignados || []);
    optgroup.appendChild(option);
  });
  
  selectServicio.appendChild(optgroup);
});

// Mostrar info del servicio al seleccionar
selectServicio.addEventListener('change', async function() {
  const option = this.options[this.selectedIndex];
  if (!option.value) {
    document.getElementById('infoServicio').style.display = 'none';
    document.getElementById('selectorEmpleado').style.display = 'none';
    return;
  }
  
  // Mostrar precio y duración
  document.getElementById('duracion').textContent = `${option.dataset.duracion} minutos`;
  document.getElementById('precio').textContent = `€${option.dataset.precio}`;
  document.getElementById('infoServicio').style.display = 'block';
  
  // Si hay empleados asignados, mostrar selector
  const empleadosIds = JSON.parse(option.dataset.empleados);
  if (empleadosIds.length > 0) {
    await cargarEmpleados(empleadosIds);
    document.getElementById('selectorEmpleado').style.display = 'block';
  }
});

// Cargar empleados asignados al servicio
async function cargarEmpleados(empleadosIds) {
  const selectEmpleado = document.getElementById('empleado');
  selectEmpleado.innerHTML = '<option value="">Cualquiera disponible</option>';
  
  for (const empId of empleadosIds) {
    const empDoc = await db.collection('empresas')
      .doc(empresaId)
      .collection('empleados')
      .doc(empId)
      .get();
    
    if (empDoc.exists) {
      const emp = empDoc.data();
      const option = document.createElement('option');
      option.value = empId;
      option.textContent = emp.nombre;
      selectEmpleado.appendChild(option);
    }
  }
}
</script>
```

### 3. Enviar Reserva con Servicio

```javascript
document.getElementById('formularioReserva').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const formData = new FormData(e.target);
  const fechaHora = new Date(formData.get('fecha_hora'));
  
  try {
    await db.collection('empresas')
      .doc(empresaId)
      .collection('reservas')
      .add({
        cliente_nombre: formData.get('nombre'),
        cliente_email: formData.get('email'),
        cliente_telefono: formData.get('telefono'),
        fecha_hora: firebase.firestore.Timestamp.fromDate(fechaHora),
        servicio_id: formData.get('servicio_id'), // ✨ Vinculación con servicio
        empleado_asignado: formData.get('empleado_asignado') || null,
        comentarios: formData.get('comentarios') || '',
        estado: 'pendiente',
        origen: 'web',
        fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()
      });
    
    alert('✅ ¡Reserva confirmada! Te contactaremos pronto.');
    e.target.reset();
  } catch (error) {
    console.error('Error:', error);
    alert('❌ Error al procesar la reserva. Inténtalo de nuevo.');
  }
});
```

---

## 📈 Estadísticas de Servicios

El sistema calcula automáticamente:

### 1. Servicio Más Popular
Basado en número de reservas recibidas (últimos 30 días):
```javascript
// Se calcula en EstadisticasService._calcularEstadisticasServicios()
{
  servicio_mas_popular: "Manicura completa",
  reservas_por_servicio: {
    "Manicura completa": 45,
    "Pedicura": 32,
    "Corte de cabello": 28
  }
}
```

### 2. Servicio Más Rentable
Basado en ingresos generados:
```javascript
{
  servicio_mas_rentable: "Coloración completa",
  ingresos_por_servicio: {
    "Coloración completa": 1890.00,
    "Manicura completa": 1575.00,
    "Pedicura": 960.00
  }
}
```

### 3. Rendimiento por Empleado
Si las reservas tienen `empleado_asignado`:
```javascript
{
  rendimiento_empleados: {
    "Ana García": {
      reservas: 28,
      servicios_realizados: ["Manicura", "Pedicura"],
      rol: "STAFF"
    }
  }
}
```

---

## 📥 Importación Masiva con CSV

### Formato del CSV

Crea un archivo `servicios.csv` con este formato:

```csv
nombre,descripcion,precio,duracion_minutos,categoria
Manicura completa,Manicura con esmaltado semipermanente,35.00,60,Uñas
Pedicura spa,Pedicura con masaje y exfoliación,45.00,75,Uñas
Corte de cabello,Corte y peinado profesional,25.00,45,Cabello
Coloración completa,Tinte completo con tratamiento,85.00,120,Cabello
Masaje relajante,Masaje corporal de 60 minutos,50.00,60,Masajes
Tratamiento facial,Limpieza facial profunda,40.00,50,Estética
Depilación piernas,Depilación completa de piernas,30.00,40,Depilación
Mechas californianas,Mechas naturales con decoloración,95.00,150,Cabello
Extensiones de pestañas,Aplicación de extensiones pelo a pelo,70.00,90,Pestañas
Maquillaje profesional,Maquillaje para eventos,55.00,45,Maquillaje
```

### Pasos para Importar

1. Ve al módulo **Servicios** en la app
2. Toca el botón de **importar CSV** (icono de documento)
3. Selecciona tu archivo `.csv`
4. La app procesará e importará todos los servicios automáticamente

**Nota:** Los empleados se pueden asignar después desde el formulario de edición de cada servicio.

---

## 🔧 Integración con Cloud Functions

Si usas Cloud Functions para procesar reservas web:

```typescript
// functions/src/index.ts
export const onNuevaReservaWeb = functions.firestore
  .document('empresas/{empresaId}/reservas/{reservaId}')
  .onCreate(async (snap, context) => {
    const reserva = snap.data();
    const empresaId = context.params.empresaId;
    
    // Si la reserva tiene servicio_id, obtener detalles del servicio
    if (reserva.servicio_id) {
      const servicioDoc = await admin.firestore()
        .collection('empresas')
        .doc(empresaId)
        .collection('servicios')
        .doc(reserva.servicio_id)
        .get();
      
      if (servicioDoc.exists) {
        const servicio = servicioDoc.data();
        
        // Enviar notificación con info del servicio
        await enviarPushAEmpresa(empresaId, {
          title: '🎯 Nueva reserva web',
          body: `${reserva.cliente_nombre} - ${servicio.nombre}`,
          tipo: 'nueva_reserva',
          servicio_nombre: servicio.nombre,
          servicio_precio: servicio.precio,
          empresa_id: empresaId
        });
        
        // Actualizar estadísticas de servicio
        await admin.firestore()
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .doc(reserva.servicio_id)
          .update({
            total_reservas: admin.firestore.FieldValue.increment(1),
            ultima_reserva: admin.firestore.FieldValue.serverTimestamp()
          });
      }
    }
  });
```

---

## ✅ Checklist de Implementación

- [x] Modelo `Servicio` con campo `empleados_asignados`
- [x] Modelo `Reserva` con campos `servicio_id` y `empleado_asignado`
- [x] Pantalla de gestión de servicios con CRUD
- [x] Importación masiva desde CSV
- [x] Selector de empleados en formulario de servicio
- [x] Estadísticas de servicios más populares y rentables
- [ ] Formulario web actualizado con selector de servicios
- [ ] Cloud Function para notificaciones de reservas con servicio
- [ ] Dashboard con gráficas de servicios más solicitados

---

## 📚 Recursos Adicionales

- **Firestore Rules:** Asegúrate de que los servicios sean de lectura pública para formularios web
- **Testing:** Prueba con datos de ejemplo antes de desplegar en producción
- **Performance:** Considera indexar `servicio_id` en reservas para consultas rápidas

```javascript
// firestore.rules
match /empresas/{empresaId}/servicios/{servicioId} {
  allow read: if true; // Lectura pública para formularios web
  allow write: if esAdminOPropietario(empresaId);
}
```

---

**Documentación actualizada:** 06/05/2026  
**Versión:** 1.0

