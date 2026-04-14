# 🗺️ MAPA COMPLETO DEL SISTEMA DE CONTENIDO WEB

> Documento técnico para entender TODO el módulo antes de modificarlo.
> Última revisión: Abril 2026

---

## 📁 ARCHIVOS QUE FORMAN EL MÓDULO

| Archivo | Líneas | Qué hace |
|---------|--------|----------|
| `lib/domain/modelos/seccion_web.dart` | 654 | **Todos los modelos de datos**: `SeccionWeb`, `ContenidoSeccion`, `ItemCarta`, `ItemGaleria`, `ItemOferta`, `ItemHorario`, `SeoConfig`, `EntradaBlog`, `ConfigWebAvanzada`, y el enum `TipoSeccion` |
| `lib/services/contenido_web_service.dart` | 533 | **Servicio central**: CRUD Firestore, subida de imágenes a Storage, generación de código JS, blog, SEO, config avanzada |
| `lib/features/dashboard/pantallas/pantalla_contenido_web.dart` | 1597 | **UI principal**: Pantalla con tab "Secciones" + editor completo de cada tipo de sección |
| `lib/features/dashboard/pantallas/tab_seo_web.dart` | 504 | **Tab SEO**: Título, descripción, keywords, OG image, robots, Analytics, Pixel Facebook |
| `lib/features/dashboard/pantallas/tab_config_web.dart` | 621 | **Tab Config**: Dominio propio, formulario contacto, popup bienvenida, banner superior |

---

## 🏗️ ARQUITECTURA GENERAL

```
┌─────────────────────────────────────────────────────────┐
│            PantallaContenidoWeb (Scaffold)               │
│  ┌───────────────┬──────────────┬──────────────────┐    │
│  │  Tab Secciones │   Tab SEO    │   Tab Config     │    │
│  │  (_TabSecciones)│ (TabSeoWeb) │ (TabConfigWeb)   │    │
│  └───────┬───────┴──────┬───────┴────────┬─────────┘    │
│          │              │                │              │
│          ▼              ▼                ▼              │
│  ┌──────────────────────────────────────────────┐       │
│  │       ContenidoWebService (servicio)          │       │
│  └──────────────┬───────────────────────────────┘       │
│                 │                                        │
│        ┌────────┴────────┐                               │
│        ▼                 ▼                                │
│  Firestore           Firebase Storage                    │
│  (datos)             (imágenes)                          │
└─────────────────────────────────────────────────────────┘
```

---

## 🔑 ESTRUCTURA FIRESTORE

```
empresas/{empresaId}/
├── contenido_web/              ← Cada documento es una sección
│   ├── {seccionId_1}           ← SeccionWeb (ej: "carta_1681234567890")
│   ├── {seccionId_2}
│   └── ...
│
├── configuracion/
│   ├── contenido_web           ← { activo: bool } → on/off de la pestaña Web
│   ├── seo_web                 ← SeoConfig (título, desc, keywords, analytics...)
│   └── web_avanzada            ← ConfigWebAvanzada (popup, banner, contacto, dominio)
│
├── contacto_web/               ← Mensajes recibidos del formulario de contacto
│   └── {autoId}
│
└── blog/                       ← Entradas de blog/noticias
    └── {entradaId}
```

---

## 📊 MODELOS DE DATOS (seccion_web.dart)

### 1. `TipoSeccion` (enum) — Los 5 tipos de sección

| Valor | Nombre UI | Icono | Color | Para qué |
|-------|-----------|-------|-------|----------|
| `texto` | Texto / Anuncio | `Icons.article` | Azul `#1976D2` | Título + texto libre + imagen opcional |
| `carta` | Carta / Menú | `Icons.restaurant_menu` | Naranja `#E65100` | Lista de platos con nombre, descripción, precio, foto, disponible/no |
| `galeria` | Galería de fotos | `Icons.photo_library` | Morado `#7B1FA2` | Grid de imágenes |
| `ofertas` | Ofertas | `Icons.local_offer` | Verde `#2E7D32` | Ofertas con precio original, precio rebajado, fecha fin |
| `horarios` | Horarios | `Icons.schedule` | Teal `#00796B` | 7 días de la semana con apertura/cierre/cerrado |

> **El tipo se elige al crear y NO se puede cambiar después.** El nombre sí es editable.

### 2. `SeccionWeb` — El modelo principal

```dart
SeccionWeb {
  id: String               // ID del documento en Firestore (auto o vacío → Firestore genera)
  nombre: String            // Nombre visible: "Mi Carta", "Ofertas de Abril"
  descripcion: String       // Descripción (apenas se usa en la UI actual)
  activa: bool              // Toggle ON/OFF → controla si aparece en la web
  tipo: TipoSeccion         // texto | carta | galeria | ofertas | horarios
  contenido: ContenidoSeccion  // ← TODO el contenido según el tipo
  fechaCreacion: DateTime
  fechaActualizacion: DateTime?
}
```

### 3. `ContenidoSeccion` — Contiene los datos de TODOS los tipos a la vez

```dart
ContenidoSeccion {
  // ── Para tipo TEXTO ──
  titulo: String
  texto: String
  imagenUrl: String?

  // ── Para tipo CARTA ──
  itemsCarta: List<ItemCarta>

  // ── Para tipo GALERÍA ──
  imagenesGaleria: List<ItemGaleria>

  // ── Para tipo OFERTAS ──
  ofertas: List<ItemOferta>

  // ── Para tipo HORARIOS ──
  horarios: List<ItemHorario>
}
```

> **¡Importante!** Es un modelo "flat": SIEMPRE tiene todos los campos aunque solo use los del tipo correspondiente. Los demás quedan como listas vacías o strings vacíos.

### 4. Sub-modelos de contenido

#### `ItemCarta`
```
id, nombre, descripcion, precio (double), imagenUrl?, categoria ("General"), disponible (bool)
```

#### `ItemGaleria`
```
id, url (String), descripcion?
```

#### `ItemOferta`
```
id, titulo, descripcion, precioOriginal?, precioOferta?, imagenUrl?, fechaFin?, activa (bool)
```

#### `ItemHorario`
```
dia ("Lunes"..."Domingo"), apertura ("09:00"), cierre ("21:00"), cerrado (bool)
```
- `ItemHorario.porDefecto()` genera los 7 días con 09:00-21:00 y domingo cerrado.

### 5. `SeoConfig`
```
tituloSeo, descripcionSeo, palabrasClave, imagenOg?, googleAnalyticsId?, pixelFacebook?, robotsContent
```
- Se guarda en `configuracion/seo_web`

### 6. `EntradaBlog`
```
id, titulo, resumen, contenido (markdown), imagenUrl?, publicada (bool), fechaPublicacion, etiquetas, autor, visitas
```
- Se guarda en la colección `blog/`

### 7. `ConfigWebAvanzada`
```
dominioPropioUrl?
contactoActivo, contactoEmail?, contactoWhatsapp?, contactoTitulo?
popupActivo, popupTitulo?, popupTexto?, popupBotonTexto?, popupBotonUrl?, popupRetrasoSeg (default 5)
bannerActivo, bannerTexto?, bannerColor? (hex), bannerUrlDestino?
```
- Se guarda en `configuracion/web_avanzada`

---

## 🖥️ PANTALLA PRINCIPAL (pantalla_contenido_web.dart)

### Estructura de clases en el archivo:

```
PantallaContenidoWeb (StatefulWidget)
  └── TabController con 3 tabs:
      ├── Tab 0: _TabSecciones        ← Lista de secciones + FAB "Nueva sección"
      ├── Tab 1: TabSeoWeb            ← (archivo separado tab_seo_web.dart)
      └── Tab 2: TabConfigWeb         ← (archivo separado tab_config_web.dart)

_TabSecciones (StatelessWidget)
  ├── StreamBuilder escuchando svc.obtenerSecciones(empresaId)
  ├── _buildHeader()       → Gradiente con contador "X de Y secciones activas"
  ├── _buildVacio()        → Placeholder cuando no hay secciones
  └── Lista de _TarjetaSeccion

_TarjetaSeccion (StatelessWidget)
  ├── Cabecera: icono del tipo + nombre + Switch activa/inactiva
  ├── Preview del contenido (según tipo): _buildPreview()
  │   ├── texto    → título + texto + badge "imagen adjunta"
  │   ├── carta    → Chips con "nombre Xprecio€" (máx 4 + "+N más")
  │   ├── galeria  → Thumbnails 52x52 (máx 4 + "+N")
  │   ├── ofertas  → Lista con icono + título + precio oferta (máx 2)
  │   └── horarios → Indicador "Hoy: 09:00 – 21:00" + "X días configurados"
  └── Botones: [Editar] [Eliminar]
      └── Editar navega a PantallaEditorSeccion
      └── Eliminar abre diálogo de confirmación → svc.eliminarSeccion()

PantallaEditorSeccion (StatefulWidget)                   ← línea 595-1577
  ├── Si es NUEVA: selector de tipo (chips) + nombre auto-rellenado
  ├── Si es EDICIÓN: muestra tipo (fijo) + nombre editable
  └── Editor específico por tipo:
      ├── _buildEditorTexto()    → Título + Texto + Imagen (subir/cambiar/quitar)
      ├── _buildEditorCarta()    → Lista de ItemCarta con modal BottomSheet para editar cada uno
      ├── _buildEditorGaleria()  → Grid 3 columnas con botón "+" para subir fotos
      ├── _buildEditorOfertas()  → Lista de ItemOferta con modal BottomSheet
      └── _buildEditorHorarios() → 7 filas (Lun-Dom) con selectores de hora + toggle cerrado
```

### Flujo al guardar (_guardar, línea 1511):
1. Valida el formulario
2. Construye `ContenidoSeccion` con TODOS los campos (texto, carta, galería, ofertas, horarios)
3. Construye `SeccionWeb` con el contenido
4. Llama a `svc.guardarSeccion(empresaId, seccion)`
5. El servicio hace `set(data, merge: true)` en Firestore
6. El `StreamBuilder` de la lista detecta el cambio automáticamente

---

## 📡 SERVICIO (contenido_web_service.dart)

### Métodos principales:

| Método | Qué hace |
|--------|----------|
| `obtenerSecciones(empresaId)` | `Stream<List<SeccionWeb>>` — escucha la colección `contenido_web` en tiempo real, ordena por campo `orden` |
| `guardarSeccion(empresaId, seccion)` | `set(merge: true)` — crea o actualiza un documento |
| `actualizarContenido(empresaId, seccionId, contenido)` | Actualiza solo el campo `contenido` de una sección |
| `toggleSeccion(empresaId, seccionId, activa)` | Cambia solo el campo `activa` |
| `eliminarSeccion(empresaId, seccionId)` | Borra el documento |

### Imágenes:

| Método | Qué hace |
|--------|----------|
| `subirImagenDesdeGaleria(empresaId, carpeta)` | Abre ImagePicker, sube a Storage `empresas/{id}/{carpeta}/{timestamp}.jpg`, devuelve URL |
| `subirImagenSeccion(empresaId, seccionId)` | Sube imagen y actualiza `contenido.imagen_url` en Firestore |
| `subirImagenItemCarta(empresaId, seccionId, itemId)` | Sube imagen y actualiza el item dentro del array `items_carta` |
| `subirImagenItemOferta(empresaId, seccionId, itemId)` | Igual pero en array `ofertas` |

### Estado del módulo:

| Método | Qué hace |
|--------|----------|
| `obtenerEstadoContenidoWeb(empresaId)` | Stream `bool` — lee `configuracion/contenido_web → activo` |
| `activarContenidoWeb(empresaId)` | Pone `activo: true` |
| `desactivarContenidoWeb(empresaId)` | Pone `activo: false` |

### Generación de código JS:

| Método | Qué hace |
|--------|----------|
| `generarCodigoJavaScript(empresaId)` | Genera script **básico**: solo Firebase + listener de secciones + divs |
| `generarCodigoCompleto(empresaId)` | Genera script **completo**: SEO meta tags + Analytics + Pixel + Banner + Popup + Contacto + Reservas + Secciones + Blog |

### SEO y Config Avanzada:

| Método | Qué hace |
|--------|----------|
| `obtenerSeoConfig(empresaId)` | Stream de `SeoConfig` desde `configuracion/seo_web` |
| `guardarSeoConfig(empresaId, seo)` | Guarda la config SEO |
| `obtenerConfigAvanzada(empresaId)` | Stream de `ConfigWebAvanzada` desde `configuracion/web_avanzada` |
| `guardarConfigAvanzada(empresaId, config)` | Guarda popup/banner/contacto/dominio |

### Blog:

| Método | Qué hace |
|--------|----------|
| `obtenerBlog(empresaId)` | Stream de `List<EntradaBlog>` ordenado por fecha desc |
| `guardarEntradaBlog(empresaId, entrada)` | Crea/actualiza entrada |
| `eliminarEntradaBlog(empresaId, entradaId)` | Borra entrada |

---

## 🔍 TAB SEO (tab_seo_web.dart)

### Qué muestra la pantalla:

1. **Preview Google** — Simula cómo aparecerá en resultados de búsqueda (título azul + URL + descripción gris)
2. **Título de la página** — Input con contador de caracteres y semáforo (ideal 30-60)
3. **Meta descripción** — Textarea con contador (ideal 120-160)
4. **Palabras clave** — Input de keywords separados por comas
5. **Imagen OG** — Imagen para cuando comparten en redes (1200x630 recomendado). Se sube a Storage carpeta `seo/`
6. **Indexación** — Radio buttons: `index,follow` / `noindex,nofollow` / `index,nofollow`
7. **Google Analytics ID** — Input para `G-XXXXXXXXXX`
8. **Facebook Pixel ID** — Input para el pixel

### Flujo al guardar:
- Construye `SeoConfig` con los valores de los controllers
- Llama `svc.guardarSeoConfig(empresaId, cfg)`

---

## ⚙️ TAB CONFIG (tab_config_web.dart)

### Qué muestra la pantalla:

1. **Dominio propio** — Input para la URL de la web donde está instalado el script
2. **Formulario de contacto** — Switch + campos: título, email destino, WhatsApp (opcional)
   - Los mensajes se guardan en `contacto_web/` en Firestore
3. **Popup de bienvenida** — Switch + campos: título, texto, botón texto/URL, slider retraso (0-30s)
   - Incluye preview visual del popup
   - Se muestra solo 1 vez por sesión (`sessionStorage`)
4. **Banner superior** — Switch + campos: texto, URL destino, selector de color (7 opciones hex)
   - Incluye preview visual del banner

### Flujo al guardar:
- Construye `ConfigWebAvanzada` con todos los valores
- Llama `svc.guardarConfigAvanzada(empresaId, cfg)`

---

## 🌐 CÓDIGO JAVASCRIPT GENERADO

El método `generarCodigoCompleto()` produce un bloque HTML/JS dividido en 3 partes:

### ① Para `<head>` — SEO + Analytics
```html
<title>...</title>
<meta name="description" content="...">
<meta name="keywords" content="...">
<meta property="og:image" content="...">
<meta name="robots" content="index,follow">
<!-- Google Analytics (gtag.js) -->
<!-- Facebook Pixel -->
```

### ② Divs — Donde se inyecta el contenido
```html
<div id="fluixcrm_{seccionId}"></div>   ← Uno por sección activa
<div id="fluixcrm_contacto"></div>       ← Si contacto está activo
<div id="fluixcrm_blog"></div>           ← Siempre
<div id="fluixcrm_reservas"></div>       ← Formulario de reserva
```
> **Prefijo**: todos los divs usan `fluixcrm_` + el ID de la sección.

### ③ Para antes de `</body>` — Script dinámico
- Inicializa Firebase JS SDK (v9 compat)
- Función `render(id, html, show)` — inyecta HTML en el div correspondiente o lo oculta
- **Banner**: se inyecta dinámicamente como primer hijo del `<body>`
- **Popup**: aparece tras X segundos (solo 1 vez por sesión)
- **Contacto**: formulario que graba en `contacto_web/` en Firestore
- **Reservas**: formulario que graba en `reservas/` en Firestore con estado "PENDIENTE" y origen "web"
- **Listener en tiempo real**: `onSnapshot` en `contenido_web/` que renderiza cada sección según su tipo:
  - `texto` → `<h3>` + `<p>` + `<img>` opcional
  - `carta` → divs con flex (imagen 70x70 + nombre + precio + descripción), filtra `disponible !== false`
  - `galeria` → grid CSS `auto-fill, minmax(200px, 1fr)` con `aspect-ratio: 1`
  - `ofertas` → cards con imagen + título + descripción + precio tachado + precio oferta, filtra `activa`
  - `horarios` → tabla HTML con día + horario (verde) o "Cerrado" (rojo)
- **Blog**: `onSnapshot` en `blog/` limitado a 6 entradas publicadas, grid de artículos
- **Eliminación**: `docChanges` detecta `type === "removed"` y oculta el div

---

## 🔄 FLUJO COMPLETO DE UNA SECCIÓN

```
1. Usuario abre tab "Secciones"
2. StreamBuilder escucha empresas/{id}/contenido_web
3. Lista de _TarjetaSeccion con preview
4. Pulsa "Nueva sección" → PantallaEditorSeccion (seccion: null)
5. Elige tipo (texto/carta/galeria/ofertas/horarios)
6. Rellena contenido según el tipo
7. Pulsa "Guardar"
8. _guardar() construye SeccionWeb con ContenidoSeccion
9. svc.guardarSeccion() → Firestore set(merge: true)
10. StreamBuilder recibe el cambio → UI se actualiza
11. La web (si tiene el script) recibe el onSnapshot → render()
```

---

## ⚡ ACTIVACIÓN / DESACTIVACIÓN DEL MÓDULO

La pestaña "Web" del dashboard aparece/desaparece dinámicamente:

```
empresas/{empresaId}/configuracion/contenido_web → { activo: true/false }
```

- `obtenerEstadoContenidoWeb()` devuelve un `Stream<bool>`
- El dashboard escucha ese stream y recrea el TabController con 4 o 5 pestañas
- Botón de toggle en el AppBar (icono web verde/blanco) y en la propia vista web

---

## 🖼️ SUBIDA DE IMÁGENES — Rutas en Firebase Storage

| Contexto | Ruta en Storage |
|----------|----------------|
| Imagen de sección tipo texto | `empresas/{id}/secciones/{seccionId}/{timestamp}.jpg` |
| Imagen de item de carta | `empresas/{id}/carta/{seccionId}/{itemId}/{timestamp}.jpg` |
| Imagen de oferta | `empresas/{id}/ofertas/{seccionId}/{itemId}/{timestamp}.jpg` |
| Foto de galería | `empresas/{id}/galeria/{timestamp}.jpg` |
| Imagen OG (SEO) | `empresas/{id}/seo/{timestamp}.jpg` |

- Todas se suben a max 1200x1200px, calidad 85%
- Se usa `ImagePicker` con `source: ImageSource.gallery`

---

## 🗂️ RESUMEN RÁPIDO "¿DÓNDE TOCO PARA...?"

| Quiero... | Archivo(s) a tocar |
|-----------|-------------------|
| Añadir un nuevo tipo de sección (ej: "Testimonios") | `seccion_web.dart` (enum + extension) + `pantalla_contenido_web.dart` (switch en preview + switch en editor + widget del nuevo editor) + `contenido_web_service.dart` (renderizado JS en `generarCodigoCompleto`) |
| Cambiar cómo se ve la tarjeta/preview de una sección | `pantalla_contenido_web.dart` → `_buildPreview()` (línea ~381) |
| Cambiar el formulario de edición de un tipo | `pantalla_contenido_web.dart` → `_buildEditorTexto/Carta/Galeria/Ofertas/Horarios` |
| Añadir un campo a ItemCarta (ej: alérgenos) | `seccion_web.dart` → `ItemCarta` (campo + fromMap + toMap + copyWith) + el editor en `pantalla_contenido_web.dart` + el renderizado JS en `contenido_web_service.dart` |
| Cambiar cómo se genera el JavaScript | `contenido_web_service.dart` → `generarCodigoCompleto()` (línea ~309) |
| Cambiar la configuración SEO | `tab_seo_web.dart` + `seccion_web.dart` → `SeoConfig` |
| Cambiar popup/banner/contacto | `tab_config_web.dart` + `seccion_web.dart` → `ConfigWebAvanzada` |
| Cambiar cómo se activa/desactiva el módulo | `contenido_web_service.dart` → métodos `activar/desactivarContenidoWeb` + dashboard que los consume |
| Cambiar las reglas de Firestore | `firestore.rules` |
| Tocar el blog | `contenido_web_service.dart` → `obtenerBlog/guardarEntradaBlog/eliminarEntradaBlog` + `seccion_web.dart` → `EntradaBlog` |

---

## ⚠️ COSAS A TENER EN CUENTA ANTES DE CAMBIAR

1. **ContenidoSeccion es flat** — Si añades un nuevo tipo, el modelo `ContenidoSeccion` crece con una nueva lista/campo. Todos los tipos comparten el mismo objeto.

2. **El tipo es inmutable** — Una vez creada la sección, el `TipoSeccion` no se puede cambiar. Si cambias el enum, las secciones existentes con tipos eliminados caerán al `default: texto`.

3. **El JS se genera dinámicamente** — El código JavaScript que se genera está hardcodeado como strings en `contenido_web_service.dart`. Si cambias la estructura de datos de un tipo, también hay que actualizar el JS generado.

4. **IDs de divs** — El prefijo es `fluixcrm_` + el ID de documento de Firestore. Si cambias cómo se generan los IDs, las webs existentes dejarán de funcionar.

5. **Firebase config hardcodeada** — El `apiKey` y `projectId` están escritos directamente en el JS generado (línea ~269 y ~375 del servicio).

6. **Imágenes no se borran de Storage** — Al eliminar una sección o cambiar imagen, el archivo anterior NO se borra de Storage. Solo se reemplaza la referencia en Firestore.

7. **El switch de preview por tipo** — La función `_buildPreview` en `_TarjetaSeccion` tiene un `switch` exhaustivo sobre `TipoSeccion`. Si añades un nuevo tipo, Dart te obligará a cubrir el caso.

8. **El orden no tiene UI** — Hay un campo `orden` en Firestore que se usa para ordenar, pero no hay drag & drop implementado en la UI actual para reordenar secciones.

---

## 📐 NÚMEROS DE LÍNEA CLAVE (pantalla_contenido_web.dart)

| Línea | Qué hay |
|-------|---------|
| 1-72 | `PantallaContenidoWeb` — Scaffold con TabBar de 3 tabs |
| 78-248 | `_TabSecciones` — StreamBuilder + lista + FAB |
| 254-588 | `_TarjetaSeccion` — Card de cada sección con preview y botones |
| 595-665 | `PantallaEditorSeccion` — Declaración + initState (carga datos existentes) |
| 668-807 | `build()` del editor — Selector de tipo + nombre + editor por tipo |
| 809-817 | `_buildEditorPorTipo()` — Switch que decide qué editor mostrar |
| 819-877 | `_buildEditorTexto()` — Título + Texto + Imagen |
| 879-962 | `_buildEditorCarta()` — Lista de platos con modal |
| 964-1035 | `_buildEditorGaleria()` — Grid de fotos |
| 1037-1117 | `_buildEditorOfertas()` — Lista de ofertas con modal |
| 1119-1203 | `_buildEditorHorarios()` — 7 filas de horarios |
| 1249-1422 | `_editarItemCarta()` — BottomSheet modal para editar plato |
| 1424-1509 | `_editarOferta()` — BottomSheet modal para editar oferta |
| 1511-1560 | `_guardar()` — Construye SeccionWeb y llama al servicio |

