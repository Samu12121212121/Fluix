# 📋 Guía: Formulario de Contacto Web → Firebase → Notificaciones en App

> **Stack**: WordPress / HTML estático · Firebase (Firestore + Auth anónima) · Cloud Functions · Flutter (Fluix CRM)

---

## 📌 Índice

1. [Cómo funciona el flujo completo](#1-cómo-funciona-el-flujo-completo)
2. [Estructura en Firestore](#2-estructura-en-firestore)
3. [Reglas de Firestore necesarias](#3-reglas-de-firestore-necesarias)
4. [Script HTML del formulario](#4-script-html-del-formulario)
5. [Instalación en WordPress](#5-instalación-en-wordpress)
6. [Instalación en HTML estático](#6-instalación-en-html-estático)
7. [Cloud Functions (notificaciones automáticas)](#7-cloud-functions-notificaciones-automáticas)
8. [Cómo ver y responder desde la app](#8-cómo-ver-y-responder-desde-la-app)
9. [Checklist antes de publicar](#9-checklist-antes-de-publicar)
10. [Solución de errores frecuentes](#10-solución-de-errores-frecuentes)

---

## 1. Cómo funciona el flujo completo

```
Visitante web
    │
    │  Rellena y envía formulario
    ▼
Script JS (formulario_contacto_web.html)
    │
    │  Autenticación anónima de Firebase
    │  Escribe en Firestore:
    │  empresas/{EMPRESA_ID}/contacto_web/{nuevoDocId}
    ▼
Firestore
    │
    │  onDocumentCreated dispara Cloud Function
    ▼
Cloud Function: onNuevoMensajeContacto
    │
    ├──► Push Notification → dispositivos del empresario (app Flutter)
    │
    └──► Email automático al empresario vía Resend
    
Empresario responde desde la app
    │
    │  Escribe respuesta en Firestore:
    │  respondido: true, respuesta: "texto...", fecha_respuesta: Timestamp
    ▼
Cloud Function: onMensajeContactoRespondido
    │
    └──► Email automático al visitante con la respuesta
```

---

## 2. Estructura en Firestore

### Colección: `empresas/{empresaId}/contacto_web/{mensajeId}`

```json
{
  "nombre":          "Ana García",
  "email":           "ana@ejemplo.com",
  "telefono":        "+34 612 345 678",
  "asunto":          "Presupuesto para evento",
  "mensaje":         "Hola, me gustaría pedir información...",
  "fecha":           "Timestamp",
  "leido":           false,
  "respondido":      false,
  "respuesta":       null,
  "fecha_respuesta": null,
  "origen":          "web"
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `nombre` | string | Nombre del visitante |
| `email` | string | Email del visitante |
| `telefono` | string | Teléfono (opcional) |
| `asunto` | string | Asunto del mensaje |
| `mensaje` | string | Texto completo del mensaje |
| `fecha` | Timestamp | Fecha y hora del envío |
| `leido` | bool | `false` = badge rojo en app |
| `respondido` | bool | `false` mientras no se responde |
| `respuesta` | string? | Texto de respuesta del empresario |
| `fecha_respuesta` | Timestamp? | Cuándo se respondió |
| `origen` | string | `"web"`, `"app"`, etc. |

---

## 3. Reglas de Firestore necesarias

En `firestore.rules`, dentro del bloque `match /empresas/{empresaId}`, añade:

```
match /contacto_web/{mensajeId} {
  // Los visitantes web (auth anónima) pueden crear mensajes
  allow create: if request.auth != null
    && request.resource.data.keys().hasAll(['nombre','email','mensaje','fecha'])
    && request.resource.data.nombre  is string
    && request.resource.data.email   is string
    && request.resource.data.mensaje is string;

  // Solo el empresario/admin puede leer, actualizar y eliminar
  allow read:   if esAdminOPropietario(empresaId) || esPlataformaAdmin();
  allow update: if esAdminOPropietario(empresaId) || esPlataformaAdmin();
  allow delete: if esAdminOPropietario(empresaId) || esPlataformaAdmin();
}
```

> ⚠️ `request.auth != null` acepta tanto usuarios autenticados como **usuarios anónimos** de Firebase. El script activa auth anónima antes de escribir.

**Despliega las reglas:**
```bash
firebase deploy --only firestore:rules
```

---

## 4. Script HTML del formulario

El archivo ya está listo en `wordpress-integration/formulario_contacto_web.html`.  
**No depende de ningún widget Flutter** — es HTML puro autocontenido que escribe directamente en Firestore.

### Lo único que tienes que editar

Abre el archivo y cambia solo este bloque (líneas ~74-82):

```js
var EMPRESA_ID = "TUz8GOnQ6OX8ejiov7c5GM9LFPl2";  // ← ID de la empresa en Firestore

var cfg = {
  apiKey:     "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
  authDomain: "planeaapp-4bea4.firebaseapp.com",
  projectId:  "planeaapp-4bea4"
};
```

> Dónde encontrar el `EMPRESA_ID`:  
> Firebase Console → Firestore Database → colección **empresas** → copia el ID del documento de la empresa

> Dónde encontrar el `cfg`:  
> Firebase Console → ⚙️ Configuración del proyecto → Tu aplicación web → Configuración del SDK

### Cómo funciona internamente

| Paso | Qué ocurre |
|---|---|
| Carga la página | Se hace `signInAnonymously()` → el botón pasa a "Enviar Mensaje" |
| Usuario pulsa Enviar | Valida campos, muestra errores inline (sin alert) |
| Validación OK | Escribe en `empresas/{EMPRESA_ID}/contacto_web/{autoId}` |
| Escritura exitosa | Muestra mensaje verde, limpia el formulario |
| Error de permisos | Muestra mensaje rojo con texto descriptivo |

### Documento que se guarda en Firestore

```json
{
  "nombre":          "Ana García",
  "email":           "ana@ejemplo.com",
  "telefono":        "+34 612 345 678",
  "asunto":          "Presupuesto para evento",
  "mensaje":         "Hola, me gustaría...",
  "origen":          "web",
  "leido":           false,
  "respondido":      false,
  "respuesta":       null,
  "fecha_respuesta": null,
  "fecha_creacion":  "Timestamp (serverTimestamp)"
}
```

### Uso en WordPress con Elementor

Añade un widget **HTML** con solo estas dos líneas (el SDK ya está en el archivo global):

```html
<!-- En la página de contacto de WordPress -->
<script src="/wp-content/uploads/fluix/formulario_contacto_web.html"></script>
```

O copia y pega el HTML completo en un widget HTML de Elementor.

---

## 5. Instalación en WordPress

### Opción A — Plugin "Insert Headers and Footers" (recomendado)

1. Instala el plugin **WPCode** (o "Insert Headers and Footers").
2. Ve a **Código → Añadir nuevo snippet → HTML**.
3. Pega el `<script>` de configuración de Firebase + el script de lógica (sección del `<script>` del punto 4).
4. Actívalo en las páginas donde quieras el formulario.
5. En la página/entrada donde quieras el formulario, añade un bloque **HTML personalizado** con:

```html
<div id="fluix-contacto"
     data-titulo="¿Tienes alguna pregunta?"
     data-asunto="Solicitud de información">
</div>
```

### Opción B — Elementor / Divi

1. Añade un widget **"HTML"** en el lugar deseado.
2. Pega **todo el contenido** del script (incluyendo las etiquetas `<script>` de Firebase).

> ⚠️ **Importante**: Los SDKs de Firebase solo deben cargarse **una vez** por página. Si tienes múltiples formularios en la misma página, comprueba que no se inicialice Firebase dos veces.

### Opción C — Shortcode personalizado

En `functions.php` de tu tema (o en un plugin hijo):

```php
function fluix_formulario_contacto($atts) {
    $atts = shortcode_atts([
        'titulo' => '¿Hablamos?',
        'asunto' => 'Consulta general',
    ], $atts);
    return '<div id="fluix-contacto" 
               data-titulo="' . esc_attr($atts['titulo']) . '" 
               data-asunto="' . esc_attr($atts['asunto']) . '">
            </div>';
}
add_shortcode('fluix_contacto', 'fluix_formulario_contacto');
```

Uso en el editor: `[fluix_contacto titulo="¿Hablamos?" asunto="Presupuesto"]`

---

## 6. Instalación en HTML estático

Copia el archivo completo `formulario_contacto_web.html` y colócalo en tu servidor, o bien integra el código en tu página existente:

```html
<!-- En el <head> de tu página -->
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js"></script>

<!-- Donde quieras el formulario -->
<div id="fluix-contacto" data-titulo="Contacto" data-asunto="Presupuesto"></div>

<!-- Antes del </body> -->
<script>
  /* pega aquí el bloque de configuración y lógica */
</script>
```

---

## 7. Cloud Functions (notificaciones automáticas)

Las siguientes Cloud Functions ya están implementadas en `functions/src/index.ts`.

### `onNuevoMensajeContacto`

Se dispara cuando se crea un nuevo documento en `empresas/{empresaId}/contacto_web/{mensajeId}`.

**Acciones automáticas:**
- 🔔 Envía **push notification** a todos los dispositivos del empresario.
- 📧 Envía **email al empresario** con los datos del mensaje (vía Resend).

### `onMensajeContactoRespondido`

Se dispara cuando `respondido` cambia de `false` a `true`.

**Acciones automáticas:**
- 📧 Envía **email al visitante** con la respuesta del empresario (vía Resend).

### Despliegue

```bash
# Solo las funciones de contacto
firebase deploy --only functions:onNuevoMensajeContacto,functions:onMensajeContactoRespondido

# O todas las funciones
firebase deploy --only functions
```

### Variables de entorno necesarias

En Firebase Functions config (o Secret Manager):

```bash
firebase functions:config:set resend.api_key="re_xxxxxxxxx"
```

O en `.env` si usas Firebase Functions v2:

```
RESEND_API_KEY=re_xxxxxxxxx
```

---

## 8. Cómo ver y responder desde la app

1. En la app, ve a **Contenido Web** (menú lateral o dashboard).
2. Selecciona la pestaña **"Mensajes"** (3ª pestaña, con badge rojo si hay no leídos).
3. Toca un mensaje para ver los detalles del remitente.
4. Escribe tu respuesta en el campo de texto.
5. Pulsa **"Enviar respuesta"**.

Al enviar la respuesta:
- El documento en Firestore se actualiza con `respondido: true` y el texto de la respuesta.
- La Cloud Function `onMensajeContactoRespondido` detecta el cambio.
- Se envía automáticamente un email al visitante con tu respuesta.

---

## 9. Checklist antes de publicar

### En Firebase Console
- [ ] **Authentication** → Proveedores de inicio de sesión → **Acceso anónimo: ACTIVADO**
- [ ] **Firestore Rules** desplegadas con permiso `create` para auth anónima en `contacto_web`
- [ ] **Cloud Functions** desplegadas y sin errores en los logs

### En el script HTML
- [ ] `EMPRESA_ID` actualizado con el ID real de la empresa en Firestore
- [ ] `firebaseConfig` con los datos reales del proyecto Firebase
- [ ] Probado en navegador con las DevTools abiertas (sin errores en consola)

### En la app Flutter
- [ ] El empresario tiene email configurado en su perfil (para recibir notificaciones por email)
- [ ] Notificaciones push activadas en el dispositivo

### En WordPress / web
- [ ] Los SDKs de Firebase se cargan **antes** del script del formulario
- [ ] No hay duplicación de `firebase.initializeApp()` en la misma página
- [ ] Formulario probado con datos reales → verificar en Firestore que llegan los documentos

---

## 10. Solución de errores frecuentes

### ❌ `Missing or insufficient permissions`

**Causa más común**: El usuario no tiene auth anónima activa **antes** de escribir en Firestore.

**Solución**: Asegúrate de que el script llama a `auth.signInAnonymously()` **antes** del `.add()`:

```js
await auth.signInAnonymously();  // ← SIEMPRE antes de escribir
await db.collection(...).add({...});
```

**Segunda causa**: Auth anónima no está activada en Firebase Console.
> Firebase Console → Authentication → Sign-in method → Anónimo → Activar

---

### ❌ `Firebase: No Firebase App '[DEFAULT]' has been created`

**Causa**: Los SDKs se cargan después del script, o `firebase.initializeApp()` no se ha llamado.

**Solución**: Verifica el orden de los `<script>` en el HTML. Los SDKs deben ir primero:

```html
<!-- 1º: SDKs -->
<script src="firebase-app-compat.js"></script>
<script src="firebase-auth-compat.js"></script>
<script src="firebase-firestore-compat.js"></script>

<!-- 2º: Tu script -->
<script> firebase.initializeApp({...}); </script>
```

---

### ❌ `Firebase App named '[DEFAULT]' already exists`

**Causa**: `firebase.initializeApp()` se llama dos veces (por ejemplo, dos formularios en la misma página).

**Solución**: Comprueba si ya existe antes de inicializar:

```js
if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}
```

---

### ❌ Las notificaciones push no llegan

**Verificar**:
1. El empresario tiene los permisos de notificaciones activados en el dispositivo.
2. Los tokens FCM se guardan correctamente en Firestore (colección `dispositivos` del empresario).
3. La Cloud Function se ejecutó sin errores (Firebase Console → Functions → Logs).

---

### ❌ El email no llega

**Verificar**:
1. La API Key de Resend está configurada correctamente en Firebase Functions.
2. El email del empresario existe en su perfil de Firestore.
3. Revisar los logs de la Cloud Function para ver el error exacto.

---

## 📁 Archivos relacionados en el proyecto

| Archivo | Descripción |
|---|---|
| `wordpress-integration/formulario_contacto_web.html` | Script HTML del formulario |
| `functions/src/index.ts` | Cloud Functions (`onNuevoMensajeContacto`, `onMensajeContactoRespondido`) |
| `functions/src/resend_service.ts` | Funciones de envío de email |
| `functions/src/templates/contacto_notificacion.html` | Template email → empresario |
| `functions/src/templates/contacto_respuesta.html` | Template email → visitante |
| `lib/features/dashboard/pantallas/tab_mensajes_contacto.dart` | Pantalla de mensajes en la app |
| `lib/features/dashboard/pantallas/pantalla_contenido_web.dart` | Pantalla Contenido Web (con tab Mensajes) |
| `firestore.rules` | Reglas de Firestore (sección `contacto_web`) |

---

*Última actualización: Abril 2026 — Fluix CRM v1.0.13*


