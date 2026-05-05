# 📧 Instrucciones para Desplegar Sistema de Contacto

## ✅ CORRECCIONES REALIZADAS

He añadido las funciones que faltaban en `resend_service.ts`:

1. **`enviarNotificacionContactoWeb()`** - Email al empresario cuando recibe mensaje del formulario web
2. **`enviarRespuestaContactoWeb()`** - Email de respuesta del empresario al visitante

También actualicé el import en `index.ts` para incluir estas funciones.

---

## 🚀 COMANDOS PARA DESPLEGAR

### **Paso 1: Compilar las Cloud Functions**

```powershell
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter\functions
npm run build
```

Esto:
- Compila TypeScript → JavaScript
- Copia los templates HTML (incluidos los 2 nuevos de contacto)

### **Paso 2: Verificar que se copiaron los templates**

```powershell
dir lib\templates\contacto*.html
```

Deberías ver:
- `contacto_interes_confirmacion.html`
- `contacto_interes_notificacion.html`
- `contacto_notificacion.html`
- `contacto_respuesta.html`

### **Paso 3: Desplegar Cloud Function**

```powershell
firebase deploy --only functions:enviarEmailsContactoInteres
```

---

## 📋 QUÉ HACE EL SISTEMA COMPLETO

Cuando alguien llena el formulario **"¿Estás interesado en trabajar con nosotros?"**:

### ✅ Se ejecuta automáticamente:

1. **Guarda el lead** en Firestore (`contactos_interesados`)

2. **Envía 2 emails vía Cloud Function**:
   - 📧 **Email 1** → Al usuario (confirmación verde profesional)
   - 📧 **Email 2** → A `sacoor80@gmail.com` (notificación roja urgente)

3. **Crea tarea** de alta prioridad en el módulo propietario

### ✅ En la interfaz:

- Muestra **spinner** mientras envía
- Cambia a **pantalla de éxito** con ✅ cuando termina
- Muestra **SnackBar verde** confirmando envío
- Si hay error → **SnackBar rojo** con detalles

### ✅ En consola (para debugging):

- `📋 Enviando formulario de contacto...`
- `📧 Enviando emails de contacto...`
- `✅ Emails enviados correctamente: {data}`
- `✅ Formulario enviado correctamente`

---

## 🔍 VERIFICACIÓN POST-DESPLIEGUE

Después de desplegar, verifica:

```powershell
# Ver logs en tiempo real
firebase functions:log --only enviarEmailsContactoInteres
```

Prueba el formulario desde la app y revisa:
1. ¿Se crea el documento en Firestore?
2. ¿Llega el email de confirmación al usuario?
3. ¿Llega el email de notificación a sacoor80@gmail.com?
4. ¿Se crea la tarea en el módulo propietario?

---

## ⚠️ SOLUCIÓN DE PROBLEMAS

### Si los emails no llegan:

1. Verifica que `RESEND_API_KEY` esté configurada:
   ```powershell
   firebase functions:secrets:access RESEND_API_KEY
   ```

2. Si no está configurada:
   ```powershell
   firebase functions:secrets:set RESEND_API_KEY
   # Pega tu API key de Resend cuando te lo pida
   ```

3. Verifica dominio en Resend dashboard → fluixtech.com debe estar verificado

### Si la tarea no se crea:

- Verifica que `ConstantesApp.empresaPropietariaId` sea correcto
- Revisa las reglas de Firestore (ya están correctas, permiten `origen='lead_contacto'`)

---

## 📝 RESUMEN DE ARCHIVOS MODIFICADOS

### ✅ Backend (Cloud Functions):

- `functions/src/resend_service.ts` → Añadidas 2 funciones nuevas
- `functions/src/index.ts` → Actualizado import

### ✅ Frontend (Flutter):

- `lib/services/contacto_service.dart` → Mejor logging de errores
- `lib/features/autenticacion/pantallas/form_contacto_interes.dart` → SnackBar + logging

### ✅ Templates (ya existían):

- `functions/src/templates/contacto_interes_confirmacion.html`
- `functions/src/templates/contacto_interes_notificacion.html`
- `functions/src/templates/contacto_notificacion.html`
- `functions/src/templates/contacto_respuesta.html`

---

## 🎯 ESTADO ACTUAL

- ✅ Código corregido (sin errores de compilación)
- ✅ Templates HTML listos
- ✅ Cloud Function implementada
- ⏳ **PENDIENTE**: Compilar y desplegar (ejecuta los comandos arriba)


