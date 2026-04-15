# 📊 FLUIX CRM — Script de Analíticas Web (Nivel 1)

## 🎯 Qué hace este script

El script `fluix-embed.js` ahora incluye un **módulo de analíticas completo** que registra automáticamente **5 métricas imprescindibles** de la web de tu cliente y las envía a Firestore para verlas en la app Flutter.

| Métrica | Qué captura | Dónde se ve en la app |
|---------|------------|----------------------|
| 👀 **Visitas** | Total, hoy, semana, mes, páginas vistas, referrer | Tab Analytics → KPIs + Gráfico |
| 📱 **Dispositivo** | Móvil / Desktop / Tablet | Tab Analytics → Dispositivos |
| 📍 **Ubicación** | País + Ciudad (aprox, sin guardar IP) | Tab Analytics → Top ubicaciones |
| ⏱️ **Tiempo en página** | Duración media + Tasa de rebote | Tab Analytics → Comportamiento |
| 🎯 **Eventos clave** | Click teléfono, WhatsApp, email, formularios, CTAs | Tab Analytics → Intención de compra |

---

## 🚀 Qué pegar en la web del cliente

### Lo mínimo (solo analíticas — 1 línea)

Pegar **antes de `</body>`** en el HTML del cliente:

```html
<script data-empresa="TUz8GOnQ6OX8ejiov7c5GM9LFPl2"
        src="https://planeaapp-4bea4.web.app/fluix-embed.js"></script>
```

Eso activa automáticamente: visitas, dispositivo, ubicación, tiempo en página, y tracking de clicks en teléfono/WhatsApp/formularios.

### Con widgets de contenido (carta, ofertas, etc.)

Si ya tienes widgets `.fluix-widget` para sincronizar contenido, **no necesitas `data-empresa` en el script** — el script lo coge del primer widget automáticamente:

```html
<!-- Tu widget existente — las analíticas se activan solas -->
<div class="fluix-widget"
     data-empresa="TUz8GOnQ6OX8ejiov7c5GM9LFPl2"
     data-seccion="carta">
</div>

<!-- El script (solo 1 vez, antes de </body>) -->
<script src="https://planeaapp-4bea4.web.app/fluix-embed.js"></script>
```

### Solo analíticas (sin widgets de contenido)

```html
<!-- Pegar antes de </body> — UNA sola línea -->
<script data-empresa="TUz8GOnQ6OX8ejiov7c5GM9LFPl2"
        src="https://planeaapp-4bea4.web.app/fluix-embed.js"></script>
```

### En Hostinger / WordPress

Pega esto en **Ajustes → Código personalizado → Código del footer** (o en el `footer.php` de tu tema):

```html
<script data-empresa="TUz8GOnQ6OX8ejiov7c5GM9LFPl2"
        src="https://planeaapp-4bea4.web.app/fluix-embed.js"></script>
```

---

## 🔐 ¿Es seguro poner el empresaId en el HTML?

**Sí.** Es el mismo modelo que usan Google Analytics, Facebook Pixel, Hotjar, etc.

### ¿Qué ve alguien que mira el código fuente de la web?

```
empresaId: TUz8GOnQ6OX8ejiov7c5GM9LFPl2
apiKey:    AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU
projectId: planeaapp-4bea4
```

### ¿Eso es peligroso?

**NO**, porque:

| Dato expuesto | ¿Qué puede hacer un atacante? | Protección |
|--------------|-------------------------------|-----------|
| `empresaId` | Solo sabe que esa empresa existe | No da acceso a nada por sí solo |
| `apiKey` | Solo identifica el proyecto Firebase | No es un secreto — Google lo diseñó así |
| `projectId` | Saber el nombre del proyecto | Público por diseño |

### ¿Qué **NO** puede hacer alguien con estos datos?

- ❌ **No puede LEER** estadísticas → las reglas exigen `perteneceAEmpresa()` (autenticado + mismo empresa_id)
- ❌ **No puede LEER** clientes, facturas, empleados, nóminas → todo requiere autenticación
- ❌ **No puede BORRAR** nada → las reglas de delete requieren autenticación
- ❌ **No puede ESCRIBIR** en ninguna otra colección → el fallback es `esAdminOPropietario()`

### ¿Qué **SÍ** puede hacer?

- ✅ Puede **escribir datos falsos de analytics** (inflar visitas, eventos)
- ✅ Puede **crear eventos_web** falsos (pero solo con campos validados: `tipo` string ≤50 chars)

> **Esto es exactamente lo mismo que pasa con Google Analytics.** Cualquiera puede mandar hits falsos al GA de otra persona. Es un riesgo aceptado en la industria porque:
> - Los datos de analytics **no son críticos** para el negocio
> - El atacante no gana nada inflando tus visitas
> - Detectar anomalías es fácil (picos de tráfico imposibles)

### Reglas de Firestore (ya actualizadas)

```javascript
// ANALYTICS WEB — escritura pública para el script JS
match /estadisticas/trafico_web {
  allow read: if perteneceAEmpresa(empresaId);   // Solo la app puede LEER
  allow create, update: if true;                  // El script web puede ESCRIBIR
  allow delete: if perteneceAEmpresa(empresaId);  // Solo la app puede BORRAR
}

match /estadisticas/trafico_web/historico_diario/{fecha} {
  allow read: if perteneceAEmpresa(empresaId);
  allow create, update: if true;
  allow delete: if perteneceAEmpresa(empresaId);
}

// EVENTOS WEB — solo create, con validación de campos
match /eventos_web/{eventoId} {
  allow read: if perteneceAEmpresa(empresaId);
  allow create: if true
    && request.resource.data.keys().hasAll(['tipo', 'fecha_iso'])
    && request.resource.data.tipo is string
    && request.resource.data.tipo.size() <= 50;
  allow update, delete: if esAdminOPropietario(empresaId);
}
```

### Resumen de seguridad

```
VISITANTE WEB (sin auth)          APP FLUTTER (con auth)
─────────────────────────         ─────────────────────────
✅ Escribir analytics             ✅ Leer analytics
✅ Crear eventos                  ✅ Leer eventos
❌ Leer datos de negocio          ✅ Leer/escribir todo
❌ Borrar nada                    ✅ Borrar analytics
❌ Modificar contenido            ✅ Modificar contenido
```

---

## 📋 El Script Completo

El script está en: **`public_web_visor/fluix-embed.js`**

Es un único archivo JavaScript que combina:
1. **Módulo de contenido** — sincroniza carta, ofertas, horarios, texto, galería
2. **Módulo de analíticas** — `FluixAnalytics` (lo nuevo)
3. **API pública** — `Fluix.sincronizar()`, `Fluix.debug()`, `Fluix.evento()`, `Fluix.analytics()`

### Estructura interna del script

```
fluix-embed.js (IIFE)
│
├── firebaseConfig              ← Configuración Firebase del proyecto
├── loadScript()                ← Carga dinámica del SDK
├── injectStyles()              ← CSS para widgets visuales
│
├── 📊 FluixAnalytics           ← NUEVO: Módulo de analíticas
│   ├── init()                  ← Punto de entrada (sesión, DNT)
│   ├── _registrarVisita()      ← Visitas + referrer + hoy/semana/mes
│   ├── _clasificarReferrer()   ← Google, directo, redes, otro
│   ├── _registrarPaginaVista() ← URLs visitadas
│   ├── _detectarDispositivo()  ← Móvil / Desktop / Tablet
│   ├── _obtenerUbicacion()     ← Ciudad + País (vía ipapi.co)
│   ├── _iniciarTiempoEnPagina()← Duración + tasa de rebote
│   ├── _iniciarEventosClave()  ← tel:, WhatsApp, forms, CTAs
│   └── _registrarEvento()      ← Escribe evento en Firestore
│
├── initFluixWidgets()          ← Inicialización (Firebase + Widgets + Analytics)
├── hydrateWidget()             ← Modo data-binding
├── renderWidget()              ← Modo auto-render
├── window.Fluix                ← API pública
│   ├── sincronizar()           ← Web → App
│   ├── debug()                 ← Diagnóstico
│   ├── evento()                ← NUEVO: Eventos personalizados
│   └── analytics()             ← NUEVO: Estado del módulo
│
└── checkAutoSync()             ← ?fluix_sync=true
```

---

## 🔥 Estructura Firestore

El script escribe en estas ubicaciones (que la app Flutter ya lee):

### Documento principal: `empresas/{id}/estadisticas/trafico_web`

```json
{
  "visitas_hoy": 47,
  "visitas_semana": 312,
  "visitas_mes": 1240,
  "visitas_total": 8934,
  "fecha_actual": "2026-04-13",
  "fecha_inicio_semana": "2026-04-07",

  "paginas_mas_vistas": {
    "_": 523,
    "_servicios": 234,
    "_carta": 189,
    "_contacto": 98
  },

  "duracion_media_segundos": 45.3,
  "tasa_rebote": 38.2,

  "visitas_movil": 5621,
  "visitas_desktop": 2890,
  "visitas_tablet": 423,

  "ubicaciones": {
    "Guadalajara, Spain": 4521,
    "Madrid, Spain": 891,
    "Barcelona, Spain": 234
  },

  "paises": {
    "Spain": 7200,
    "Mexico": 234
  },

  "referrers": {
    "google": 3400,
    "directo": 2100,
    "instagram": 890,
    "facebook": 456,
    "whatsapp": 344,
    "otro": 200
  },

  "eventos": {
    "click_telefono": 234,
    "click_whatsapp": 189,
    "formulario_enviado": 45,
    "click_email": 23,
    "click_cta": 78,
    "click_mapa": 12,
    "total": 581
  },

  "ultima_actualizacion": "Timestamp"
}
```

### Subcolección diaria: `estadisticas/trafico_web/historico_diario/{YYYY-MM-DD}`

```json
{
  "fecha": "2026-04-13",
  "visitas": 47,
  "referrers": {
    "google": 20,
    "directo": 15,
    "instagram": 8
  }
}
```

### Eventos individuales: `empresas/{id}/eventos_web/{autoId}`

```json
{
  "tipo": "click_whatsapp",
  "datos": {
    "url": "https://wa.me/34600000000",
    "pagina": "/contacto"
  },
  "fecha": "Timestamp",
  "fecha_iso": "2026-04-13T14:30:00.000Z",
  "sesion": "S1744550400000"
}
```

---

## 📱 Qué se ve en la App Flutter

### Tab "Analytics" del módulo web (ya existente, ahora con datos reales):

| Sección | Widget | Datos |
|---------|--------|-------|
| KPIs | 4 tarjetas | Hoy, Esta semana, Este mes, Total |
| Gráfico | BarChart | Visitas últimos 30 días |
| Páginas | Lista con barras | Top 8 URLs más visitadas |
| Dispositivos | 3 barras | Móvil / Escritorio / Tablet con % |
| Comportamiento | 2 métricas | Duración media + Tasa de rebote |
| Ubicaciones | Lista | Top 6 ciudades |
| **📈 Origen tráfico** | **Lista con barras** | **Google, directo, redes... con %** |
| **🎯 Intención compra** | **Grid de chips** | **Llamadas, WhatsApp, formularios...** |

---

## ⚙️ Cómo funciona cada módulo

### 👀 1. Visitas

- Se registra **1 visita por sesión** (30 min de inactividad = sesión nueva)
- `sessionStorage` controla que no se cuente dos veces en la misma sesión
- Los contadores `visitas_hoy`, `visitas_semana`, `visitas_mes` se **resetean automáticamente** cuando cambia la fecha
- El **referrer** se clasifica en: `google`, `bing`, `yahoo`, `facebook`, `instagram`, `twitter`, `tiktok`, `linkedin`, `youtube`, `whatsapp`, `directo`, `otro`
- La navegación interna (misma web) **no cuenta** como referrer nuevo

### 📱 2. Dispositivo

- Detecta por `userAgent`:
  - **Tablet**: iPad, Android sin "mobile", PlayBook, Silk
  - **Móvil**: iPhone, iPod, Android mobile, BlackBerry, Opera Mini, Windows Phone
  - **Desktop**: todo lo demás
- Se registra **1 vez por sesión**

### 📍 3. Ubicación

- Usa **ipapi.co** (gratis, 1000 req/día, sin API key)
- Si falla, usa **geojs.io** como backup (ilimitado)
- Solo guarda **ciudad + país** (nunca la IP)
- Se registra **1 vez por sesión**
- Formato en Firestore: `"Guadalajara, Spain": 4521`

### ⏱️ 4. Tiempo en página

- Mide el **tiempo visible real** (pausa cuando el tab está oculto)
- Usa `visibilitychange` + `beforeunload` + `pagehide` para máxima cobertura
- Calcula **media móvil ponderada** (últimas 100 visitas)
- **Tasa de rebote**: < 5 segundos Y solo 1 página vista = rebote
- Ignora visitas < 2 segundos (bots, preloads)

### 🎯 5. Eventos clave

Se capturan automáticamente por **delegación de eventos** en `document`:

| Evento | Se detecta cuando... |
|--------|---------------------|
| `click_telefono` | Click en `<a href="tel:...">` |
| `click_whatsapp` | Click en link con `wa.me`, `whatsapp.com` o `api.whatsapp` |
| `click_email` | Click en `<a href="mailto:...">` |
| `click_mapa` | Click en link a Google Maps, Apple Maps o Waze |
| `formulario_enviado` | Submit de cualquier `<form>` |
| `click_cta` | Click en botón con texto: reservar, comprar, pedir, solicitar, contactar, presupuesto, cita... |

**Cada evento se guarda en 2 lugares:**
1. **Contador global** en `trafico_web.eventos.click_telefono` → para ver totales rápido en la app
2. **Documento individual** en `eventos_web/{autoId}` → con detalle (página, sesión, timestamp)

---

## 🛠️ API pública (para la consola del navegador)

```javascript
// Ver estado de las analíticas
Fluix.analytics()

// Registrar un evento personalizado desde tu código
Fluix.evento('compra_realizada', {
    producto: 'Pack Premium',
    importe: 49.99,
    pagina: '/checkout'
})

// Diagnóstico completo (widgets + Firestore)
Fluix.debug()

// Sincronizar contenido web → app
Fluix.sincronizar()
```

---

## 🔒 Privacidad

- ✅ **No guarda IPs** — solo ciudad/país
- ✅ **Respeta Do Not Track** — si `navigator.doNotTrack === '1'`, no registra nada
- ✅ **Sin cookies** — usa `sessionStorage` (se borra al cerrar el navegador)
- ✅ **Sin datos personales** — no captura nombres, emails ni contraseñas de visitantes
- ✅ **Cumple RGPD** — datos agregados y anónimos

---

## 📁 Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `public_web_visor/fluix-embed.js` | Añadido módulo `FluixAnalytics` completo + API `Fluix.evento()` y `Fluix.analytics()` |
| `lib/services/analytics_web_service.dart` | Añadidos campos `referrers`, `eventos`, `paises` al modelo `MetricasTraficoWeb` |
| `lib/features/dashboard/pantallas/tab_analytics_web.dart` | Añadidos widgets `_buildReferrers()` y `_buildEventos()` al tab de analytics |

---

## 🧪 Cómo probar

### 1. Probar en local

Crea un archivo `test_analytics.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Test Fluix Analytics</title></head>
<body>
    <h1>Mi Web de Prueba</h1>

    <!-- Links de prueba para eventos -->
    <a href="tel:+34600000000">📞 Llamar</a>
    <a href="https://wa.me/34600000000">💬 WhatsApp</a>
    <a href="mailto:info@miweb.com">📧 Email</a>
    <a href="https://maps.google.com/?q=Guadalajara">📍 Mapa</a>

    <form>
        <input type="text" placeholder="Nombre">
        <button type="submit">Reservar</button>
    </form>

    <!-- Widget de contenido (opcional) -->
    <div class="fluix-widget"
         data-empresa="TUz8GOnQ6OX8ejiov7c5GM9LFPl2"
         data-seccion="carta">
    </div>

    <!-- Script -->
    <script src="fluix-embed.js"></script>
</body>
</html>
```

### 2. Verificar en consola del navegador (F12)

```
📊 Fluix Analytics: Módulo iniciado para TUz8GOnQ6OX8ejiov7c5GM9LFPl2
📊 Visita registrada
📍 Ubicación: Guadalajara, Spain
```

### 3. Verificar en Firestore

Ve a la consola de Firebase → Firestore → `empresas/{id}/estadisticas/trafico_web` y verás los datos apareciendo.

### 4. Verificar en la App Flutter

Abre la app → Dashboard → Módulo Web → Tab "Analytics". Verás:
- KPIs con datos reales
- Gráfico de barras con visitas
- Desglose de dispositivos
- Mapa de ubicaciones
- **NUEVO: Origen del tráfico** (Google, directo, redes...)
- **NUEVO: Intención de compra** (llamadas, WhatsApp, formularios...)

### 5. Probar eventos personalizados

En la consola del navegador:
```javascript
Fluix.evento('boton_especial_clickado', { seccion: 'hero', variante: 'A' })
// → 🎯 Evento: boton_especial_clickado
```

### 6. Ver estado del módulo
```javascript
Fluix.analytics()
// → Empresa: TUz8GOnQ6OX8ejiov7c5GM9LFPl2
// → Sesión: S1744550400000
// → Páginas esta sesión: 3
// → Sesión nueva: true
// → DNT: Inactivo
```

---

## ❓ FAQ

### ¿Cuántas peticiones a ipapi.co consume?
**1 por sesión nueva** (no por página). Con 1000 visitas/día únicas, usarías ~1000 de las 1000 gratuitas. Si necesitas más, puedes:
- Cambiar a `geojs.io` (ilimitado, menos preciso)
- Comentar la línea `self._obtenerUbicacion()` en `init()`

### ¿Se cuentan visitas dobles si el usuario navega por la web?
No. La **visita** se cuenta 1 vez por sesión (30 min). Las **páginas vistas** sí se cuentan cada vez.

### ¿Qué pasa si el visitante tiene Do Not Track activado?
No se registra absolutamente nada. El módulo se detiene y muestra un log en consola.

### ¿Afecta al rendimiento de la web?
No de forma perceptible. Las escrituras a Firestore son asíncronas y no bloquean el renderizado. La geolocalización se hace en background.

### ¿Se puede usar sin los widgets de contenido?
Sí. Pon `data-empresa="TU_ID"` en la etiqueta `<script>` y las analíticas funcionan sin necesidad de divs `.fluix-widget`.

### ¿Cómo añado más tipos de eventos CTA?
En el script, busca el array `keywords` dentro de `_iniciarEventosClave()` y añade más palabras:
```javascript
var keywords = ['reservar', 'comprar', 'pedir', 'solicitar', 'contactar',
                'presupuesto', 'cita', 'booking', 'buy', 'order', 'añadir',
                'tu_nueva_palabra'];
```

---

## 🗺️ Roadmap — Niveles futuros

### Nivel 2 (próximamente)
- 🔄 Flujo de navegación (qué páginas visitan en orden)
- 📊 Conversiones (visitante → contacto → cliente)
- 🕐 Horas punta (a qué hora visitan más)

### Nivel 3
- 🤖 Detección de bots (excluir tráfico no humano)
- 📈 Comparativa mes a mes
- 🔔 Alertas (notificación push si hay pico de tráfico)
