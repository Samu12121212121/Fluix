# 🎯 CONFIGURACIÓN PASO A PASO - SOLO 2 LÍNEAS QUE CAMBIAR

## 📋 **PASO 1: Obtener tu API Key de Firebase**

### **1.1 Ir a Firebase Console:**
1. Abre: https://console.firebase.google.com/
2. Clic en tu proyecto **"planeaapp-4bea4"**
3. Clic en el icono de **⚙️ Configuración** (arriba izquierda)
4. Clic en **"Configuración del proyecto"**

### **1.2 Copiar API Key:**
5. En la pestaña **"General"** (que se abre por defecto)
6. Busca la sección **"Tus apps"**
7. Clic en el icono **</>** (Web app)
8. Verás algo como esto:
```javascript
const firebaseConfig = {
  apiKey: "AIzaSyDpAGshzWcOWsJ1dRhBZybnhBjm8tY5234",  // ← ESTA ES TU API KEY
  authDomain: "planeaapp-4bea4.firebaseapp.com",
  projectId: "planeaapp-4bea4",
  // ... más líneas
};
```

**🔑 COPIA LA API KEY** (la que está después de `apiKey: "`)

---

## 📋 **PASO 2: Obtener tu Empresa ID**

### **2.1 Abrir la App Flutter:**
1. Ejecuta `flutter run` en tu terminal
2. Inicia sesión con: `admin@planeaguada.com` / `admin123`

### **2.2 Ver el ID en la consola:**
3. Ve a la pestaña **"Estadísticas"** en la app
4. En la consola del IDE (donde ejecutaste flutter run) busca líneas como:
```
🔍 Cargando datos para UID: abc123
✅ EmpresaId cargado: ulhYZOjxH35a663JdU3y  // ← ESTE ES TU EMPRESA ID
```

**🏢 COPIA EL EMPRESA ID** (la cadena larga después de "EmpresaId cargado:")

---

## 🔧 **PASO 3: Cambiar las 2 Líneas en el Script**

Busca estas **2 líneas** en tu script de WordPress y cámbialas:

### **LÍNEA 10-11 (Configuración Firebase):**
```javascript
// 🔥 Configuración Firebase
const firebaseConfig = {
    apiKey: "TU_API_KEY_REAL",  // ← LÍNEA 1: CAMBIAR POR TU API KEY
```

**CAMBIA POR:**
```javascript
// 🔥 Configuración Firebase  
const firebaseConfig = {
    apiKey: "AIzaSyDpAGshzWcOWsJ1dRhBZybnhBjm8tY5234",  // ← TU API KEY REAL
```

### **LÍNEA 18 (Empresa ID):**
```javascript
// 🏢 CONFIGURACIÓN
const EMPRESA_ID = "TU_EMPRESA_ID_DEL_CRM";  // ← LÍNEA 2: CAMBIAR POR TU ID
```

**CAMBIA POR:**
```javascript
// 🏢 CONFIGURACIÓN
const EMPRESA_ID = "ulhYZOjxH35a663JdU3y";  // ← TU EMPRESA ID REAL
```

---

## ✅ **EJEMPLO COMPLETO CON LOS CAMBIOS:**

```html
<script>
document.addEventListener("DOMContentLoaded", function() {
    console.log('🚀 Inicializando PlaneaGuada CRM...');

    // 🔥 Configuración Firebase
    const firebaseConfig = {
        apiKey: "AIzaSyDpAGshzWcOWsJ1dRhBZybnhBjm8tY5234", // ✅ CAMBIADO
        authDomain: "planeaapp-4bea4.firebaseapp.com",
        projectId: "planeaapp-4bea4",
        storageBucket: "planeaapp-4bea4.appspot.com",
        messagingSenderId: "1085482191658",
        appId: "1:1085482191658:web:c5461353b123ab92d62c53"
    };

    // 🏢 CONFIGURACIÓN
    const EMPRESA_ID = "ulhYZOjxH35a663JdU3y"; // ✅ CAMBIADO

    // ... resto del código igual (no tocar) ...
</script>
```

---

## 🧪 **PASO 4: Probar que Funciona**

### **4.1 Subir el Script:**
1. Copia el script completo con los cambios
2. WordPress → Apariencia → Editor de temas → footer.php
3. Pegar y guardar

### **4.2 Probar en tu Web:**
1. Visita tu página web
2. Abre consola del navegador (F12 → Console)
3. Deberías ver:
```
🚀 Inicializando PlaneaGuada CRM...
✅ Visita registrada: 2026-03-09
🎉 PlaneaGuada CRM iniciado correctamente
```

### **4.3 Probar en la App:**
1. Ve a la app → pestaña "Estadísticas"
2. Deberías ver las visitas incrementarse

---

## 🔍 **Si No Sabes Cuál Es Tu API Key o Empresa ID:**

### **API Key - Método Alternativo:**
Si no encuentras la API Key, usa la que ya tienes en tu código anterior:
```javascript
apiKey: "AIzaSyDpAGshzWcOWsJ1dRhBZybnhBjm8tY5234",
```

### **Empresa ID - Método Alternativo:**
Si no ves el ID en la consola, usa el que ya tenías:
```javascript
const EMPRESA_ID = "ulhYZOjxH35a663JdU3y";
```

---

## 🎯 **RESUMEN: SOLO 2 CAMBIOS**

**LÍNEA 1:** Cambiar `"TU_API_KEY_REAL"` por tu API Key real
**LÍNEA 2:** Cambiar `"TU_EMPRESA_ID_DEL_CRM"` por tu Empresa ID real

**¡Eso es todo! El resto del script no lo toques.** 🚀
