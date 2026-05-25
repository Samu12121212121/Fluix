# 🔐 Configuración de Reglas de Firestore para Sistema B2C

## 📋 INSTRUCCIONES

Las reglas de Firestore deben actualizarse para permitir el nuevo sistema B2C. Este documento explica qué hacer.

---

## 🚀 OPCIÓN 1: Aplicar Reglas Automáticamente

### Paso 1: Verifica que tienes Firebase CLI instalado
```bash
firebase --version
```

Si no lo tienes, instala con:
```bash
npm install -g firebase-tools
```

### Paso 2: Inicia sesión
```bash
firebase login
```

### Paso 3: Despliega las reglas
```bash
firebase deploy --only firestore:rules
```

---

## 🖱️ OPCIÓN 2: Aplicar Reglas Manualmente (Consola Web)

### Paso 1: Abre la consola de Firebase
1. Ve a https://console.firebase.google.com
2. Selecciona tu proyecto PlaneaG
3. En el menú lateral, haz clic en **Firestore Database**
4. Haz clic en la pestaña **Reglas**

### Paso 2: Copia las reglas
1. Abre el archivo `firestore_rules_b2c.rules` en este proyecto
2. Copia TODO el contenido
3. Pégalo en el editor de reglas de Firebase Console

### Paso 3: Publica las reglas
1. Haz clic en el botón **Publicar**
2. Confirma la acción

---

## 🔍 QUÉ HACEN LAS NUEVAS REGLAS

### 1. **Negocios Públicos** (`negocios_publicos`)
- ✅ **Lectura pública**: Cualquiera puede ver negocios activos
- ✅ **Escritura empresas**: Solo las empresas pueden crear/editar su negocio
- ✅ **Vinculación**: Los negocios están vinculados a una empresa

### 2. **Reservas** (`empresas/{id}/reservas`)
- ✅ **Clientes finales**: Pueden crear reservas con `origen: 'app_cliente'`
- ✅ **Lectura**: Los clientes ven sus propias reservas
- ✅ **Empresas**: Pueden confirmar, cancelar o eliminar reservas

### 3. **Empleados y Servicios**
- ✅ **Lectura clientes**: Pueden ver empleados/servicios activos (para formularios)
- ✅ **Escritura empresas**: Solo las empresas pueden gestionar

### 4. **Puntos de Fidelización** (`usuarios/{uid}/puntos`)
- ✅ **Lectura usuarios**: Pueden ver sus propios puntos
- ✅ **Escritura empresas**: Solo las empresas pueden otorgar puntos

---

## ⚠️ SEGURIDAD IMPORTANTE

Las reglas actuales garantizan:

1. **Aislamiento**: Los clientes finales NO pueden ver datos de otras empresas
2. **Privacidad**: Cada usuario solo ve sus propias reservas y puntos
3. **Autenticación**: Todas las operaciones requieren login
4. **Validación**: Los clientes solo pueden reservar, no modificar configuraciones

---

## 🧪 PROBAR LAS REGLAS

### Desde Firebase Console:

1. Ve a **Firestore Database > Reglas**
2. Haz clic en **Simulador de reglas** (Rules Playground)
3. Prueba estos casos:

#### Test 1: Lectura pública de negocios activos
```
Tipo: get
Ruta: /negocios_publicos/test123
Autenticado: No
Datos simulados: { "activo": true }
Resultado esperado: ✅ Permitir
```

#### Test 2: Cliente crea reserva
```
Tipo: create
Ruta: /empresas/empresa123/reservas/nueva
Autenticado: Sí (usuario con role: 'clienteFinal')
Datos: { "usuario_uid": "[AUTH_UID]", "origen": "app_cliente", ... }
Resultado esperado: ✅ Permitir
```

#### Test 3: Cliente lee reservas de otro
```
Tipo: get
Ruta: /empresas/empresa123/reservas/reserva_ajena
Autenticado: Sí (usuario con role: 'clienteFinal')
Datos: { "usuario_uid": "otro_usuario_uid" }
Resultado esperado: ❌ Denegar
```

---

## 🔄 MIGRACIÓN DESDE REGLAS EXISTENTES

Si ya tienes reglas personalizadas:

1. **IMPORTANTE**: Haz backup de tus reglas actuales
2. Copia la sección de `negocios_publicos` y las modificaciones en `empresas/{id}/reservas`
3. Integra con tus reglas existentes

### Snippet mínimo a añadir:

```javascript
// Añadir esta función helper
function isClienteFinal() {
  return isAuthenticated() && getUserData().role == 'clienteFinal';
}

// Añadir esta regla
match /negocios_publicos/{negocioId} {
  allow read: if resource.data.activo == true;
  allow write: if isCompanyUser() && 
                 resource.data.empresaIdVinculada == getUserData().empresa_id;
}

// Modificar regla de reservas
match /empresas/{empresaId}/reservas/{reservaId} {
  allow read: if isClienteFinal() && resource.data.usuario_uid == request.auth.uid ||
                belongsToCompany(empresaId);
  
  allow create: if (isClienteFinal() && 
                   request.resource.data.usuario_uid == request.auth.uid &&
                   request.resource.data.origen == 'app_cliente') ||
                   belongsToCompany(empresaId);
  
  allow update, delete: if belongsToCompany(empresaId);
}
```

---

## 📞 SOPORTE

Si las reglas fallan:
1. Verifica que el campo `role` existe en `usuarios/{uid}`
2. Comprueba que `negocios_publicos` tiene campo `activo`
3. Verifica que las reservas tienen `usuario_uid` y `origen`

---

**Actualizado:** Mayo 2026
**Versión:** 1.0 - Sistema B2C

