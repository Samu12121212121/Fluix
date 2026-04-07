# 🔧 TROUBLESHOOTING - Login PlaneaGuada CRM

## 🚨 **Problema: No Puedo Iniciar Sesión**

### ✅ **Solución Paso a Paso:**

#### **1. Verificar Credenciales**
```
📧 Email: admin@planeaguada.com
🔑 Password: admin123
```

#### **2. Limpiar Datos y Reiniciar**
```bash
# En terminal, ejecuta estos comandos:
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
flutter clean
flutter pub get
flutter run
```

#### **3. Verificar en la Consola de Debug**
Cuando ejecutes la app, verás en la consola logs como:
```
🔧 Iniciando creación de usuario administrador...
📧 Email: admin@planeaguada.com
🔑 Password: admin123
✅ Usuario Firebase Auth creado con UID: [algún_id]
✅ Empresa creada en Firestore
✅ Usuario creado en Firestore con empresa_id: [empresa_id]
```

#### **4. Si Sale Error "email-already-in-use"**
✅ **Esto es NORMAL** - significa que el usuario ya existe. Simplemente usa las credenciales.

#### **5. Si el Dashboard Muestra "No se encontró empresa"**
1. **Haz clic en "Reintentar"**
2. Si persiste, **cierra sesión y vuelve a entrar**
3. La app intentará crear automáticamente la empresa

---

## 🎯 **Flujo de Login Correcto:**

### **Paso 1:** Abrir la App
- Verás la pantalla de login con las credenciales en el cuadro azul

### **Paso 2:** Usar Credenciales
- Clic en **"Usar credenciales"** (se llenan automáticamente)
- Clic en **"Iniciar Sesión"**

### **Paso 3:** Pantalla de Dashboard
- Verás **"Bienvenido, admin"** en la tarjeta azul
- **3 pestañas**: Valoraciones, Reservas, Estadísticas

---

## 🐛 **Errores Comunes y Soluciones:**

### **Error: "FirebaseAuthException: user-not-found"**
**Causa:** Usuario no creado correctamente
**Solución:** 
```bash
flutter clean
flutter pub get
flutter run
```

### **Error: "No se encontró empresa asociada"**
**Causa:** Datos de Firestore no sincronizados
**Solución:** 
- Clic en **"Reintentar"** en el dashboard
- La app creará automáticamente la empresa

### **Error: Pantalla blanca o cargando infinito**
**Causa:** Error de conexión a Firebase
**Solución:**
1. Verificar conexión a internet
2. Reiniciar app: `Ctrl+C` en terminal, luego `flutter run`

### **Error: "Target of URI doesn't exist"**
**Causa:** Archivos no compilados correctamente
**Solución:**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔍 **Debug Avanzado:**

### **Si Aún No Funciona, Revisar Logs:**

1. **Ejecutar con verbose:**
```bash
flutter run -v
```

2. **Buscar en los logs:**
```
✅ Usuario Firebase Auth creado con UID: [tu_uid]
✅ Empresa creada en Firestore  
✅ Usuario creado en Firestore con empresa_id: [empresa_id]
🔍 Cargando datos para UID: [tu_uid]
✅ Documento usuario encontrado: {datos...}
✅ EmpresaId cargado: [empresa_id]
```

3. **Si no aparecen estos logs:**
   - El usuario no se está creando
   - Verifica que tienes conexión a internet
   - Firebase podría estar bloqueado

---

## 📱 **Estado Final Esperado:**

### **Login Exitoso Muestra:**
- **Tarjeta azul**: "Bienvenido, admin" + email
- **3 pestañas funcionales**:
  - **⭐ Valoraciones**: 15 reseñas demo
  - **📅 Reservas**: Tabla con reservas pendientes
  - **📊 Estadísticas**: KPIs + gráfico visitas

### **Datos Demo Cargados:**
- **15 valoraciones** estilo Google Reviews
- **8 reservas** con estados pendiente/confirmada  
- **Estadísticas** con 30 días de visitas web
- **4 servicios** (Corte, Tinte, Facial, Manicura)

---

## ⚡ **Solución Rápida:**

**Si no funciona nada:**
```bash
# 1. Parar la app (Ctrl+C)
# 2. Limpiar todo
flutter clean
flutter pub get

# 3. Ejecutar de nuevo  
flutter run

# 4. En la app:
#    - Clic "Usar credenciales"
#    - Clic "Iniciar Sesión"  
#    - Si sale "No se encontró empresa": clic "Reintentar"
```

---

## 📞 **Si Persisten los Problemas:**

1. **Copia los logs de la consola** cuando ejecutes `flutter run`
2. **Toma captura** de cualquier error en pantalla
3. **Verifica** que tienes conexión estable a internet

**La app debería funcionar al 100% siguiendo estos pasos.** 🚀
