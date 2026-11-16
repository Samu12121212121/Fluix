# 02 — Módulo Web + Editorial Nazarí

*Análisis de solo lectura — octubre 2026*

---

## Estado actual

El módulo web de Fluix CRM es un CMS headless que conecta Firestore con webs estáticas alojadas en Hostinger a través de un SDK JavaScript generado por la app. Para Editorial Nazarí (empresa ID `0PoomHYDUJf5w8tDFRLhFi9iURF3`, en adelante *EID*) actúa además como backend completo de tienda online (libros físicos + ebooks), gestión editorial (catálogo, autores, agenda, entrevistas, noticias) y canal de pedidos (Stripe, Bizum, transferencia).

### Arquitectura del CMS

`PantallaContenidoWeb` es el hub raíz (archivo único de ~2 650 líneas con 4 partes mediante `part`). Al arrancar descarga la colección `web_secciones` y, si la empresa tiene web detectada, ejecuta una detección HTTP para leer los atributos `data-fluix-*` presentes en el HTML y sincronizar las secciones activas. El SDK JavaScript (`fluix-sdk.js`) se genera en cliente y se sube a Firebase Storage; la web lo carga con un `<script src>`. Dos editores coexisten: `PantallaEditorWord` (WYSIWYG con `flutter_quill`, por defecto) y `PantallaEditorBlog` (3 paneles, modo avanzado).

### Colecciones relevantes en Firestore

| Colección | Propósito |
|---|---|
| `web_secciones` | Mapa visual de módulos (orden, tipo, activa) |
| `contenido_web` | Contenido de secciones (texto, carta, galería…) |
| `blog` | Entradas publicadas (todos los tipos) |
| `autores` | Fichas de autores Nazarí |
| `catalogo_web` | Catálogo de libros/productos |
| `eventos` | Agenda editorial |
| `seleccion_nazari` | Curaduría editorial |
| `pedidos_web_nazari` | Pedidos de tienda online |
| `descargas_ebook` | Tokens de descarga (7 días, 3 usos máx.) |
| `contacto_web` | Mensajes del formulario de contacto |
| `estadisticas/trafico_web` | Analytics propio |

### Cache estática (nazariCache.ts)

Cinco Cloud Functions (`onDocumentWritten`) regeneran archivos `.js` en Firebase Storage (`cache/*.js`) en cada cambio de colección: `catalogo-data.js`, `autores-data.js`, `blog-data.js`, `eventos-data.js`, `seleccion-data.js`, `pago-config.js`. La caché de Storage se configura a **86 400 s (24 h)** tanto en browser como en CDN. Existe un endpoint HTTP (`regenerarCacheNazari`) con clave API para regeneración forzada tras deploys.

### CDN (cdnPurge.ts)

Purge de Cloudflare opcional (requiere `cdn_config` con `cloudflare_zone` y `cloudflare_token`). Se activa en cada escritura en `eventos`, `blog` y `catalogo_web`. Si no existe la configuración CDN, las funciones devuelven sin hacer nada. No hay purge automático para `autores` ni `seleccion_nazari`.

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|---|---|---|
| **CRÍTICO** | La API key de Firebase (`AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU`) está hardcodeada en el SDK JavaScript que se sube a Storage y se sirve públicamente. Cualquiera puede leerla. Para proyectos Firebase en producción esto expone el projectId y permite lecturas de todas las colecciones con reglas `allow read: if true`. | `contenido_web_service.dart:556, 676` |
| **CRÍTICO** | `contenido_web` permite write a **staff** además de admin/propietario (`esStaffOSuperior`). Un empleado puede modificar el contenido público de la web sin control editorial. No hay flujo de revisión ni aprobación. | `firestore.rules:748-750` |
| **ALTO** | `estadisticas/trafico_web` tiene `allow write: if true` (sin isAuth). Cualquier agente externo puede inflado o corrupción de métricas. El comentario dice "script anónimo" pero la regla no exige token. | `firestore.rules:864-865` |
| **ALTO** | `blog` permite creación a usuarios anónimos si son de Nazarí (`empresaId == EID`). El campo `tipo` solo valida `['entrevista','noticia']` pero no hay validación de tamaño del cuerpo (`contenido`). Podría usarse para spam o inyección HTML si la web renderiza sin sanitización. | `firestore.rules:772-780` |
| **ALTO** | `verificarDescargaEbook` sirve el archivo directamente con `stream.pipe(res)` sin autenticación (solo token). Si el token se filtra, el ebook se puede descargar 3 veces desde cualquier IP. No hay limitación por IP ni rotación de tokens. | `nazariEbooks.ts:756-837` |
| **MEDIO** | `simularCompraEbook` es un endpoint HTTP sin autenticación declarada en la función (`cors: _NAZARI_CORS`). Solo está protegido implícitamente por conocer la URL, no por token. Permite entregar ebooks gratis a cualquier email si se conoce la URL. | `nazariEbooks.ts:958-1009` |
| **MEDIO** | El hash de versión del SDK se calcula como `contenido.length.toString()` en lugar de un hash criptográfico real. Dos versiones de distinto contenido pero misma longitud no se redesplegarán. | `contenido_web_service.dart:908` |
| **MEDIO** | La caché de JS estático se configura a `max-age=86400` (24 h). Tras publicar un cambio editorial urgente (precio incorrecto, evento cancelado), la web puede mostrar datos obsoletos hasta 24 horas sin purge manual. Solo hay purge CDN para Cloudflare; usuarios sin Cloudflare no tienen mecanismo de invalidación inmediata. | `nazariCache.ts:38` |
| **MEDIO** | El editor WYSIWYG (`PantallaEditorWord`) permite subir imágenes directamente a Storage sin validación de tipo MIME del lado servidor. La subida se hace con `maxWidth:1200, imageQuality:85` solo en el cliente. | `contenido_web_service.dart:247-258` |
| **BAJO** | `pantalla_contenido_web.dart` tiene 2 650 líneas (límite del proyecto: 500). El archivo `part` `pantalla_contenido_web_blog.dart` es otro fichero igual de extenso. Dificulta mantenimiento. | `pantalla_contenido_web.dart:1-2650` |
| **BAJO** | El cache `if (false) { ... }` en `detectarModulosWeb` (línea 418) desactiva permanentemente la caché de 24 h, forzando una petición HTTP al sitio web en cada apertura del módulo. Código muerto con efecto de rendimiento negativo. | `contenido_web_service.dart:418` |

---

## Diferencias por plataforma

| Aspecto | iOS | Android | Windows |
|---|---|---|---|
| Editor WYSIWYG (Quill) | Funciona; teclado sistema | Funciona; comportamiento back diferente | Funciona; sin `image_picker` de galería en escritorio (devuelve null silencioso) |
| Subida de imágenes | `ImageSource.gallery` disponible | `ImageSource.gallery` disponible | `image_picker` devuelve null en Windows; ningún fallback implementado |
| Blog preview (Markdown) | `flutter_markdown` correcto | Igual | Igual |
| Scroll de listas largas (catálogo 246 autores) | Smooth | Smooth | Puede flickear por `NeverScrollableScrollPhysics` en previews anidados |
| Enlace externo (ver en la web) | `url_launcher` funciona | `url_launcher` funciona | Requiere Chrome como browser predeterminado; sin fallback |
| CSV export (Analytics) | Copia al portapapeles | Igual | Igual; sin opción "Guardar archivo" en escritorio |

La subida de imágenes en Windows es el único fallo funcional activo: `subirImagenDesdeGaleria` llama a `image_picker` que en Windows no está soportado y devuelve null sin mostrar error al usuario.

---

## Nazarí: identidad de marca y cobertura funcional

Editorial Nazarí tiene un **tratamiento hardcoded** en el CMS: `_kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3'` aparece en al menos 5 lugares, con lógicas `if (empresaId == _kNazariId)` que alteran el comportamiento de la pantalla principal. El módulo les ofrece:

- **Catálogo**: ~246 libros en `catalogo_web`, con precio físico y precio digital separados (`precio_digital`, `precioEbook`), peso para cálculo de envío, preventa, imagen de portada.
- **Tienda online completa**: 3 métodos de pago (Stripe, Bizum directo, transferencia bancaria). El precio se valida siempre desde Firestore; el cliente no puede manipular el importe. Los pedidos se "mirroran" a `pedidos` para aparecer en el módulo Fluix.
- **Ebooks**: token de 40 hex, TTL 7 días, 3 descargas máx., entregados por email via Resend (`enviarDescargaEbook`). Sirven el binario directamente desde Cloud Function (sin Signed URL).
- **Agenda**: eventos con fecha, ciudad, tipo, imagen; detalle con navegación anterior/siguiente.
- **Blog (noticias + entrevistas)**: editor Word por defecto; editor clásico 3 paneles disponible. Paginación cada 100 entradas. Cache estática 24 h.
- **Autores**: 246 fichas; ordenación por `prioridad` + `orden` + apellido.
- **La Selección**: curación editorial con pack de suscripción; descuento configurable desde `configuracion/pack_seleccion`.
- **PDF / Plantillas**: sección separada visible en el hub Nazarí.

Lo que **falta** o está incompleto:
- No hay módulo de reseñas/valoraciones de libros individual (solo la valoración genérica de empresa).
- No hay gestión de stock para libros físicos (el `catalogo_web` no tiene campo `stock`).
- La preventa crea el pedido pero no tiene lógica de "convertir a pedido normal cuando se publique el libro".
- La purga CDN no cubre `autores-data.js` ni `seleccion-data.js`.

---

## SEO

`TabSeoWeb` gestiona los siguientes campos, almacenados en `configuracion/seo` (vía `SeoConfig`):

- Título (`<title>`, máx. 70 car., contador visual: ideal 30–60)
- Meta descripción (máx. 170 car., ideal 120–160)
- Palabras clave (`meta keywords`)
- Imagen Open Graph (subida a Storage)
- Robots (`index,follow` | `noindex,nofollow` | etc.)
- Google Analytics ID (genera el snippet `gtag.js`)
- Facebook Pixel ID (genera el snippet fbq)
- Schema.org wizard (LocalBusiness, Restaurant, etc.) que genera JSON-LD
- Snippet de canonical: el SDK inyecta dinámicamente `<title>` y meta description por entrada de blog via `injectSeo()` en el Web SDK (línea 1107–1118 de `contenido_web_service.dart`)

**Limitaciones SEO detectadas:**
1. No hay campo canonical URL en `TabSeoWeb`; el canonical se inyecta dinámicamente por el SDK pero solo para páginas de detalle de evento/blog, no para la home ni páginas de categoría.
2. El sitemap no se genera en ninguna Cloud Function; no existe `sitemap.xml` gestionado desde Fluix.
3. Los meta tags del SDK se inyectan con JS (`injectSeo`), lo que significa que crawlers sin JavaScript (Googlebot legacy, algunos LLM crawlers) no los ven.
4. El campo `palabrasClave` se guarda como string separado por comas; no hay deduplicación ni límite de cantidad.

---

## Analytics

`TabAnalyticsWeb` consume `AnalyticsWebService.streamMetricas()` que lee `estadisticas/trafico_web` en tiempo real desde Firestore. Las métricas disponibles son:

- Visitas totales, hoy, semana, mes; desglose móvil/desktop/tablet
- Tasa de rebote, duración media de sesión
- Páginas más vistas, referrers, ubicaciones (país y ciudad)
- Histórico diario (subdoc `historico_diario/YYYY-MM-DD`)
- Eventos clave (intención de compra, tabla `eventos_web`)
- Selectores de período: 7d / 30d / 90d / 180d
- Export CSV (copia al portapapeles, sin descarga real)

**No hay integración con GA4**; el tracking es propio (script JS que escribe en Firestore con auth anónima). El campo `googleAnalyticsId` en `SeoConfig` solo genera el snippet de `gtag.js` pero Fluix no lee datos de GA4; los dashboards son paralelos e independientes. El selector de período (7d/30d/90d) **no filtra los datos reales**: el stream lee `trafico_web` que es un único doc acumulativo, no por período. El filtro de período solo afecta al gráfico de visitas diarias (subcolección). Los KPIs principales no se adaptan al período seleccionado — deuda técnica significativa.

---

## Rendimiento

| Área | Estado |
|---|---|
| Cache estática JS (Nazarí) | Bien. Triggers Firestore regeneran en cada cambio. TTL 24 h. |
| Cache del SDK (`fluix-sdk.js`) | `max-age=300` (5 min). Razonable para cambios frecuentes de contenido. |
| Lazy loading imágenes (web) | Implementado en galería (`loading="lazy"`). No en la carta ni en el catálogo del SDK legacy. |
| Paginación del blog | Implementada en cliente (100/página); las queries Firestore sin `startAfter` cargan todos los docs en memoria. Para volúmenes >500 entradas puede ser lento. |
| Índices Firestore | Las queries de blog usan `where('publicada','==',true).orderBy('fecha_publicacion','desc').limit(6)` en el SDK. Sin índice compuesto esto falla en producción salvo que exista. No hay `firestore.indexes.json` visible en el proyecto. |
| Detección de módulos | `if (false)` desactiva la caché, forzando HTTP al sitio en cada apertura. |
| Streams paralelos en hub | 3 suscripciones abiertas simultáneamente en `initState` (blog, noticias, entrevistas). Para Nazarí con 300+ entradas cada una son ~3 lectura masivas al arrancar. |

---

## Seguridad P0

1. **API key pública en Storage**: riesgo real. Mitigación: las reglas Firestore limitan qué puede hacer cualquier cliente anónimo, pero la key en Storage es pública y no se puede rotar fácilmente.
2. **`contenido_web` write staff**: el personal puede alterar el HTML/texto visible de la web. Considerar separar a solo admin/propietario o añadir estado "pendiente de aprobación".
3. **`simularCompraEbook`**: endpoint sin auth. Debería requerir `request.auth.token.admin == true` o equivalente.
4. **`blog` anónimo Nazarí**: regla de importación masiva que permite crear posts con usuario anónimo. Solo protegida por `empresaId == EID`. Si las reglas cambian accidentalmente, cualquiera puede publicar en el blog.
5. **Mensajes de contacto**: `contacto_web` tiene validación de campos obligatorios, límite de longitud (5 000 chars) y formato email con regex básica. Correcto para antispam básico, aunque sin rate limiting (Firestore no lo ofrece nativamente).

---

## Cumplimiento legal (LSSI, cookies, RGPD web)

| Aspecto | Estado |
|---|---|
| Banner de cookies | Implementado en el SDK (`gdprActivo`, `gdprTexto`, `gdprPoliticaUrl`). Se guarda consentimiento en `localStorage`. | 
| Política de privacidad | Link configurable en el banner pero no hay verificación de que exista. |
| Formulario de contacto | Requiere nombre, email y mensaje. No incluye checkbox de aceptación de política de privacidad en el template HTML generado. **Incumplimiento RGPD art. 7.** |
| Ebooks / pedidos | El checkout Stripe recoge email y dirección. No hay casilla de consentimiento explícita antes de la compra en el script generado. |
| Reservas web (formulario embebido) | Sin casilla de consentimiento. El formulario pide nombre, teléfono y fecha pero no informa de quién trata los datos. |
| Derecho de supresión | No hay ningún mecanismo en el módulo para borrar pedidos web o mensajes de contacto desde la interfaz del cliente final. |
| IVA reducido ebooks | El ebook se factura con `porcentaje_iva: 4` (IVA superreducido libros, correcto en España). |

---

## Deuda técnica

1. `pantalla_contenido_web.dart` supera 2 600 líneas (límite: 500). Aunque usa `part`, la clase `_PantallaContenidoWebState` sola supera 1 100 líneas.
2. `contenido_web_service.dart` tiene 3 500+ líneas. Mezcla secciones, imágenes, blog, SDK, caché y SEO.
3. El SDK JavaScript está hardcodeado como `String` de Dart de >300 líneas. Debería ser un asset externo.
4. `if (false)` en la lógica de caché de módulos (`detectarModulosWeb`) es código muerto con efecto negativo (ver riesgos).
5. El hash del SDK se calcula como `contenido.length.toString()`. Rompe la invalidación de caché.
6. Selector de período en Analytics no filtra KPIs principales; solo afecta al gráfico diario.
7. Ausencia de `firestore.indexes.json` — las queries compuestas del blog pueden generar errores en producción si los índices no están creados manualmente en la consola.
8. `pantalla_contenido_web.dart:229-230` tiene un guard `if (empresaId == _kNazariId) return;` antes de la lógica de seed de secciones, lo que significa que si el EID de Nazarí cambia (improbable pero posible), el seed roto pasa silenciosamente.
9. Logs de debug con `print()` en producción en `contenido_web_service.dart` (líneas 25-28, 48-57). Exponen rutas internas de Firestore.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|---|---|---|
| P0 | Agregar checkbox de consentimiento RGPD al template de formulario de contacto y reservas web generado por el SDK | S |
| P0 | Proteger `simularCompraEbook` con verificación de token de administrador | S |
| P0 | Restringir write de `contenido_web` a admin/propietario (eliminar `esStaffOSuperior`) o añadir estado de publicación pendiente | S |
| P1 | Corregir el hash del SDK de `contenido.length` a SHA-256 real | S |
| P1 | Eliminar `if (false)` en `detectarModulosWeb` y restaurar la caché de 24 h | S |
| P1 | Añadir purga CDN a `autores-data.js` y `seleccion-data.js` en `nazariCache.ts` | S |
| P1 | Crear `firestore.indexes.json` con los índices compuestos del blog | S |
| P2 | Implementar filtrado real por período en los KPIs de Analytics | M |
| P2 | Desacoplar `contenido_web_service.dart` en servicios separados (blog, secciones, SEO, SDK) | L |
| P2 | Añadir lazy loading a imágenes de carta y catálogo en el SDK JavaScript | S |
| P2 | Añadir validación de tipo MIME en servidor para imágenes subidas | M |
| P2 | Implementar paginación server-side para el blog (Firestore `startAfter`) | M |
| P3 | Añadir campo canonical URL en `TabSeoWeb` | S |
| P3 | Generar sitemap.xml automático via Cloud Function (trigger en `blog` + `eventos`) | M |
| P3 | Resolver subida de imágenes en Windows (usar `file_picker` como fallback) | S |
| P3 | Añadir gestión de stock básica en catálogo Nazarí (`campo_stock`, alerta agotado) | M |
| P3 | Añadir lógica de "convertir preventa a pedido normal" cuando el libro se publique | M |
| P3 | Dividir `pantalla_contenido_web.dart` en widgets independientes por módulo | L |
| P3 | Eliminar `print()` de debug en `contenido_web_service.dart` | S |
