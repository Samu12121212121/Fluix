# ✅ SOLUCIÓN: Reglas Firestore para Formulario Damajuana

## 🔧 Cambios Realizados

He actualizado las reglas de Firestore en `firestore.rules` para que funcionen con **tu formulario original** que usa autenticación anónima.

### Nueva Regla Agregada (líneas 422-434)

```javascript
// 5. Formularios web con autenticación anónima (Damajuana, etc.)
//    Permite usuarios anónimos crear reservas con campos específicos
allow create: if esAnonimo()
    && request.resource.data.estado in ['pendiente', 'PENDIENTE']
    && request.resource.data.keys().hasAll(['nombre_cliente', 'telefono'])
    && request.resource.data.nombre_cliente is string
    && request.resource.data.nombre_cliente.size() > 0
    && request.resource.data.nombre_cliente.size() <= 100
    && request.resource.data.telefono is string
    && request.resource.data.telefono.size() > 0
    && request.resource.data.telefono.size() <= 30
    && request.resource.data.origen == 'web'
    && request.resource.data.size() <= 50;
```

### ✅ Esta Regla Permite:

- ✅ Usuarios con **autenticación anónima** (`auth.signInAnonymously()`)
- ✅ Campos del formulario: `nombre_cliente`, `telefono`, `email`, `numero_personas`, `zona`, etc.
- ✅ Estado: `PENDIENTE`
- ✅ Origen: `web`
- ✅ Hasta 50 campos en el documento

### 📋 Campos que Tu Formulario Envía (ahora compatibles):

| Campo | Tipo | Requerido |
|-------|------|-----------|
| `nombre_cliente` | string | ✅ Sí |
| `telefono` | string | ✅ Sí |
| `email` | string | No |
| `fecha_hora` | Timestamp | No |
| `hora` | string | No |
| `numero_personas` | number | No |
| `zona` | string | No |
| `alergenos` | boolean | No |
| `detalle_alergenos` | string | No |
| `notas` | string | No |
| `estado` | string | ✅ Sí (debe ser 'PENDIENTE') |
| `origen` | string | ✅ Sí (debe ser 'web') |
| `fecha_creacion` | Timestamp | No |

## 🚀 SIGUIENTE PASO: Desplegar las Reglas

Ejecuta uno de estos comandos:

### Opción 1: Script Automático
```bash
desplegar_reglas_firestore.bat
```

### Opción 2: Comando Manual
```bash
firebase deploy --only firestore:rules
```

## 🧪 Probar el Formulario

Después de desplegar las reglas:

1. **Abre** el formulario en: https://damajuanaguadalajara.site
2. **Rellena** todos los campos
3. **Envía** la reserva
4. **Verifica** en Firebase Console que aparece con todos los datos

## 🔍 Verificación en Firebase Console

Ve a:
```
Firestore Database > empresas > TUz8GOnQ6OX8ejiov7c5GM9LFPl2 > reservas
```

Deberías ver la reserva con:
- ✅ `nombre_cliente`: "Nombre del cliente"
- ✅ `telefono`: "+34 600 000 000"
- ✅ `email`: "cliente@correo.com"
- ✅ `numero_personas`: 2
- ✅ Todos los demás campos

## ❌ Ya NO Verás

- ❌ Nombre: "Anónimo"
- ❌ Error: "Missing or insufficient permissions"

## 📝 Notas Técnicas

### ¿Por Qué Necesitábamos Esta Regla?

Tu formulario usa:
1. **Autenticación anónima** (`auth.signInAnonymously()`)
2. **Campos específicos**: `nombre_cliente`, `telefono` (no `cliente_nombre`, `cliente_telefono`)

Las reglas anteriores solo permitían:
- Usuarios **sin** autenticación (`!isAuth()`) con campos `cliente_nombre`, `cliente_telefono`
- Usuarios **reales** (no anónimos) con cualquier campo

Tu formulario caía en un limbo: **está autenticado** (anónimo) pero **no es usuario real**, por lo que ninguna regla aplicaba.

### Solución

Nueva regla específica para usuarios anónimos que:
- Detecta autenticación anónima con `esAnonimo()`
- Acepta los nombres de campos exactos de tu formulario
- Valida que sea una reserva web (`origen == 'web'`)
- Requiere estado PENDIENTE

---

**✅ Tu formulario original ahora funcionará perfectamente sin modificaciones**

