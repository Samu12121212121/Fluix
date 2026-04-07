 # 🔧 SCRIPT PARA CONFIGURAR EMPRESAS - ADMINISTRADOR WEB

## 🎯 **CÓMO CONFIGURAR EMPRESAS DESDE FIREBASE CONSOLE**

Como administrador web, puedes crear las secciones para las empresas desde Firebase Console:

### 📋 **PASO 1: Abrir Firebase Console**
1. Ve a https://console.firebase.google.com
2. Abre el proyecto: `planeaapp-4bea4`
3. Ve a `Firestore Database`

### 📋 **PASO 2: Configurar Dama Juana Guadalajara**

#### **Ruta en Firestore:**
```
empresas > ztZblwm1w71wNQtzHV7S > contenido_web
```

#### **Secciones a crear:**

##### **1. Sección: ofertas_mes**
```json
{
  "id": "ofertas_mes",
  "nombre": "Ofertas del Mes",
  "descripcion": "Promociones especiales y descuentos de temporada",
  "activa": false,
  "contenido": {
    "titulo": "Título pendiente de configurar",
    "texto": "Este contenido debe ser editado por el empresario.",
    "imagen_url": null
  },
  "fecha_creacion": "2026-03-09T10:00:00.000Z"
}
```

##### **2. Sección: servicios_destacados**
```json
{
  "id": "servicios_destacados",
  "nombre": "Servicios Destacados", 
  "descripcion": "Nuestros tratamientos de belleza más populares",
  "activa": false,
  "contenido": {
    "titulo": "Título pendiente de configurar",
    "texto": "Este contenido debe ser editado por el empresario.",
    "imagen_url": null
  },
  "fecha_creacion": "2026-03-09T10:00:00.000Z"
}
```

##### **3. Sección: pack_especiales**
```json
{
  "id": "pack_especiales",
  "nombre": "Packs Especiales",
  "descripcion": "Combinaciones de servicios con precio especial",
  "activa": false,
  "contenido": {
    "titulo": "Título pendiente de configurar", 
    "texto": "Este contenido debe ser editado por el empresario.",
    "imagen_url": null
  },
  "fecha_creacion": "2026-03-09T10:00:00.000Z"
}
```

##### **4. Sección: horarios_especiales**
```json
{
  "id": "horarios_especiales",
  "nombre": "Horarios Especiales",
  "descripcion": "Información sobre horarios festivos o cambios temporales",
  "activa": false,
  "contenido": {
    "titulo": "Título pendiente de configurar",
    "texto": "Este contenido debe ser editado por el empresario.",
    "imagen_url": null
  },
  "fecha_creacion": "2026-03-09T10:00:00.000Z"
}
```

---

## 🏗️ **PLANTILLAS POR TIPO DE NEGOCIO**

### 🍽️ **RESTAURANTE**
- `ofertas_del_dia` - Ofertas del Día
- `carta_platos` - Nuestra Carta
- `menu_degustacion` - Menú Degustación  
- `vinos_bodega` - Carta de Vinos
- `eventos_privados` - Eventos Privados

### 💇‍♀️ **PELUQUERÍA/ESTÉTICA**
- `ofertas_mes` - Ofertas del Mes
- `servicios_cabello` - Servicios de Cabello
- `tratamientos_faciales` - Tratamientos Faciales
- `manicura_pedicura` - Manicura y Pedicura
- `pack_novia` - Pack Novia

### 🛍️ **TIENDA/COMERCIO**
- `productos_destacados` - Productos Destacados
- `ofertas_temporada` - Ofertas de Temporada
- `nuevos_productos` - Nuevos Productos
- `marcas_exclusivas` - Marcas Exclusivas

### 🏥 **CLÍNICA/CONSULTA**
- `servicios_medicos` - Servicios Médicos
- `horarios_atencion` - Horarios de Atención
- `seguros_aceptados` - Seguros Aceptados
- `equipo_medico` - Nuestro Equipo

---

## 🎯 **PROCESO COMPLETO**

### **Para ti (Administrador):**
1. ✅ Decides qué secciones necesita cada empresa
2. ✅ Las creas en Firebase Console con el JSON de arriba
3. ✅ Notificas al empresario que ya puede editar contenido

### **Para el empresario:**
1. ✅ Ve las secciones que creaste en su app
2. ✅ Solo puede editar: título, texto, imagen
3. ✅ Puede activar/desactivar secciones
4. ✅ NO puede crear ni eliminar secciones

---

## 🌐 **CÓMO SE VE EN LA WEB**

ddame ### **HTML que debe tener fluixtech.com:**
```html
<!-- Ofertas del mes -->
<div id="planeaguada_ofertas_mes"></div>

<!-- Servicios destacados -->  
<div id="planeaguada_servicios_destacados"></div>

<!-- Packs especiales -->
<div id="planeaguada_pack_especiales"></div>

<!-- Horarios especiales -->
<div id="planeaguada_horarios_especiales"></div>
```

### **JavaScript a incluir:**
El empresario genera el código desde la app y se incluye en el footer.

---

## ✅ **CONTROL TOTAL**

### **Lo que TÚ controlas:**
- ✅ Qué secciones existen
- ✅ Cómo se llaman las secciones
- ✅ Qué descripción tienen
- ✅ Cuándo las creas o eliminas

### **Lo que el EMPRESARIO controla:**
- ✅ Título del contenido
- ✅ Texto del contenido  
- ✅ Imagen del contenido
- ✅ Activar/desactivar sección

---

## 🎉 **RESULTADO**

- **Control profesional**: Tú decides la estructura
- **Flexibilidad para el cliente**: Puede editar contenido fácilmente
- **Sin complicaciones**: Interface simple con solo 3 campos
- **Actualizaciones en tiempo real**: Los cambios aparecen inmediatamente en la web

¡El empresario tendrá control total del contenido pero dentro del marco que tú definas! 🚀
