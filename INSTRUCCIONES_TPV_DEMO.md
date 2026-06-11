# ✅ Instrucciones TPV Demo y Ticket de Ejemplo

## 🎯 Resumen de Cambios Completados

### 1. **Cuenta Demo con Permisos Completos** ✅
La cuenta demo (`demoFluix2026@gmail.com / FlFluix26`) tiene:
- ✅ Rol **admin** con acceso completo
- ✅ **17 servicios de peluquería** (cortes, tintes, tratamientos, estética, barbería)
- ✅ **17 productos para TPV bar/restaurante** (bebidas, tapas, principales, postres)
- ✅ **12 mesas** distribuidas en 3 zonas (Terraza, Salón, Barra)
- ✅ Empleados, nóminas, clientes, reservas y más datos de prueba

### 2. **Reglas de Color - Fuentes Actualizadas** ✅
Las reglas de color del TPV de peluquería ahora cargan desde:
- ✅ **Servicios**: `empresas/{empresaId}/servicios` (módulo de servicios)
- ✅ **Profesionales**: 
  - `empresas/{empresaId}/profesionales`
  - `empresas/{empresaId}/empleados` ← **NUEVO**
  - `usuarios` (con filtro por empresa_id)
- ✅ **Estados**: Lista predefinida (pendiente, confirmada, enCurso, completada, cancelada)

### 3. **Ticket de Ejemplo** ✅
Agregado botón 📄 en el TPV de peluquería para ver ticket de ejemplo:
- ✅ Genera ticket con 3 servicios ficticios (Corte + Tinte + Tratamiento)
- ✅ Muestra vista previa del PDF
- ✅ Permite imprimir directamente
- ✅ Usa configuración real del TPV (formato térmico/A4, plantillas, etc.)

---

## 📋 Instrucciones de Uso

### **Paso 1: Inicializar/Actualizar Datos de la Cuenta Demo**

1. Inicia sesión con la cuenta demo:
   - Email: `demoFluix2026@gmail.com`
   - Contraseña: `FlFluix26`

2. En el **Dashboard**, haz clic en el botón flotante:
   ```
   🪄 Generar datos demo
   ```

3. Confirma la acción. Esto creará/actualizará:
   - ✅ 3 empleados (María, Carlos, Ana) con datos completos
   - ✅ 15 nóminas (5 meses × 3 empleados)
   - ✅ 3 clientes con historial
   - ✅ **3 servicios de restaurante**
   - ✅ **17 servicios de peluquería/estética** ← Nuevo
   - ✅ **Productos y mesas para TPV Bar** ← Nuevo
   - ✅ 5 reservas futuras

   ⚠️ **Nota**: Esto BORRA datos demo anteriores automáticamente.

---

### **Paso 2: Ver Ticket de Ejemplo en TPV Peluquería**

1. Navega al **TPV de Peluquería**:
   - Desde el Dashboard → Módulo TPV → Peluquería

2. En el **AppBar** (barra superior), busca el botón **📄** (Receipt Long)

3. Haz clic en el botón. Verás:
   - Vista previa del ticket con:
     - Corte de Pelo Mujer - 25.00€
     - Tinte Completo - 45.00€
     - Tratamiento Keratina - 35.00€
     - **TOTAL: 105.00€**
   
4. Opciones disponibles:
   - **🖨️ Imprimir**: Abre el diálogo de impresión
   - **❌ Cerrar**: Cierra la vista previa

---

### **Paso 3: Configurar Reglas de Color en TPV Peluquería**

1. En el TPV de Peluquería, haz clic en el botón **🎨** (Palette) en el AppBar

2. En el diálogo de **Reglas de Color**:

   **Para Servicio:**
   - Selecciona tipo: `Servicio`
   - Elige un servicio de la lista (ahora incluye los 17 servicios de peluquería)
   - Selecciona un color
   - Haz clic en **Agregar**

   **Para Profesional:**
   - Selecciona tipo: `Profesional`
   - Elige un profesional/empleado de la lista (ahora incluye empleados de `empresas/{empresaId}/empleados`)
   - Selecciona un color
   - Haz clic en **Agregar**

   **Para Estado:**
   - Selecciona tipo: `Estado`
   - Elige un estado (pendiente, confirmada, enCurso, completada, cancelada)
   - Selecciona un color
   - Haz clic en **Agregar**

3. Las citas se colorearán automáticamente según estas reglas:
   - Prioridad: Servicio > Profesional > Estado

---

### **Paso 4: Realizar un Cobro Real en el TPV**

1. En el TPV de Peluquería:
   - Agrega servicios al ticket (panel derecho)
   - Haz clic en **Cobrar**
   - Selecciona método de pago (Efectivo/Tarjeta/Mixto)
   - Confirma el pago

2. El sistema:
   - ✅ Genera un número de ticket automático
   - ✅ Guarda la venta en Firestore
   - ✅ Genera factura automática (si está configurado)
   - ✅ Intenta imprimir en impresora Bluetooth (si está conectada)
   - ✅ Muestra confirmación con número de ticket

---

## 🔧 Configuración Adicional

### **Configuración del TPV**

Accede a la configuración del TPV con el botón **⚙️** (Settings) en el AppBar:

- **Tipo de Documento**: Ticket / Factura Simplificada / Factura Completa
- **Formato de Impresión**: Ticket 80mm / Ticket 58mm / A4
- **Facturación Automática**: ON/OFF
- **Plantillas PDF**: Selecciona plantillas personalizadas (si las has creado)

### **Impresora Bluetooth** (solo Android/iOS)

1. Haz clic en el botón **🖨️** (Print) en el AppBar
2. Escanea impresoras disponibles
3. Selecciona tu impresora térmica
4. Conecta
5. Los tickets se imprimirán automáticamente tras cada venta

---

## 📊 Servicios de Peluquería Disponibles en Demo

| Categoría | Servicio | Precio | Duración |
|-----------|----------|--------|----------|
| **Peluquería** | Corte de Pelo Mujer | 25.00€ | 45 min |
| **Peluquería** | Corte de Pelo Hombre | 15.00€ | 30 min |
| **Coloración** | Tinte Completo | 45.00€ | 90 min |
| **Coloración** | Mechas | 55.00€ | 120 min |
| **Coloración** | Balayage | 65.00€ | 150 min |
| **Tratamientos** | Permanente | 50.00€ | 90 min |
| **Tratamientos** | Alisado Brasileño | 80.00€ | 180 min |
| **Tratamientos** | Tratamiento Keratina | 35.00€ | 45 min |
| **Peinados** | Peinado Eventos | 30.00€ | 60 min |
| **Peinados** | Recogido | 40.00€ | 75 min |
| **Estética** | Manicura | 12.00€ | 30 min |
| **Estética** | Pedicura | 18.00€ | 45 min |
| **Estética** | Uñas Gel | 25.00€ | 60 min |
| **Estética** | Depilación Cejas | 8.00€ | 15 min |
| **Estética** | Depilación Piernas | 35.00€ | 60 min |
| **Barbería** | Corte + Arreglo Barba | 20.00€ | 40 min |
| **Barbería** | Afeitado Tradicional | 15.00€ | 30 min |

---

## 🐛 Solución de Problemas

### **No veo los servicios de peluquería**
- ✅ Asegúrate de haber ejecutado "Generar datos demo" desde el Dashboard
- ✅ Verifica que estás logueado como la cuenta demo o que tu empresa tiene servicios creados

### **El ticket de ejemplo no se muestra**
- ✅ Verifica que tienes conexión a internet (necesaria para cargar configuración desde Firestore)
- ✅ Comprueba la consola de debug para ver el error específico

### **Las reglas de color no funcionan**
- ✅ Asegúrate de haber guardado las reglas correctamente
- ✅ Refresca la vista del calendario (cambia de fecha y vuelve)
- ✅ Verifica que los nombres de servicios/profesionales coinciden exactamente

### **No puedo cobrar en el TPV**
- ✅ Verifica que tienes al menos una línea en el ticket
- ✅ Comprueba que el total es mayor que 0
- ✅ Asegúrate de tener permisos de admin (la cuenta demo los tiene)

---

## 📝 Notas Técnicas

### **Archivos Modificados**

1. **`lib/services/demo_cuenta_service.dart`**
   - ✅ Nueva función: `crearServiciosPeluqueriaDemo()` (17 servicios)
   - ✅ Modificado: `configurarDemoTpv()` ahora llama a la nueva función

2. **`lib/features/tpv/pantallas/tpv_peluqueria_screen.dart`**
   - ✅ Nuevo import: `tpv_document_renderer.dart`
   - ✅ Nueva función: `_mostrarTicketEjemplo()` (genera ticket de ejemplo)
   - ✅ Nuevo botón en AppBar: 📄 "Ver ticket de ejemplo"
   - ✅ Modificado: `_DialogoReglasColorState._cargar()` ahora carga empleados desde subcollection

3. **`lib/features/dashboard/pantallas/pantalla_dashboard.dart`**
   - ✅ Actualizado mensaje del diálogo "Generar datos demo" para incluir servicios de peluquería

### **Base de Datos**

La cuenta demo tiene estructura completa en:
- `empresas/demo_empresa_fluix2026/servicios` ← 17 servicios de peluquería
- `empresas/demo_empresa_fluix2026/catalogo` ← 17 productos de bar
- `empresas/demo_empresa_fluix2026/mesas` ← 12 mesas
- `empresas/demo_empresa_fluix2026/empleados` ← 3 empleados
- `empresas/demo_empresa_fluix2026/clientes` ← 3 clientes
- `empresas/demo_empresa_fluix2026/reservas` ← 5 reservas

---

## ✅ Lista de Verificación

- [x] Cuenta demo con rol admin
- [x] 17 servicios de peluquería en Firestore
- [x] Reglas de color cargan empleados desde `empleados` subcollection
- [x] Botón de ticket de ejemplo visible en TPV peluquería
- [x] Ticket genera PDF con 3 servicios ficticios
- [x] Vista previa de ticket funcional
- [x] Opción de impresión disponible
- [x] Dashboard muestra servicios de peluquería en la lista de datos demo

---

## 🚀 Próximos Pasos Sugeridos

1. **Crear más profesionales**: Agrega empleados reales en el módulo de Empleados
2. **Personalizar servicios**: Modifica precios y duraciones según tu negocio
3. **Configurar impresora**: Conecta tu impresora Bluetooth para impresión automática
4. **Crear plantillas PDF**: Diseña plantillas personalizadas para tus tickets
5. **Configurar reglas de color**: Define reglas para identificar rápidamente tipos de citas

---

**Fecha de actualización**: 26/05/2026  
**Versión**: 1.0.0

