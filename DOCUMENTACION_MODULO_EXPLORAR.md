# 🔍 Documentación del Módulo Explorar — Fluix CRM

## Descripción General

El módulo **Explorar** es la interfaz de cara al cliente final (B2C). Es una aplicación dentro de la aplicación que permite a los usuarios descubrir negocios locales, ver sus perfiles detallados, hacer reservas y gestionar sus favoritos.

**Paleta de colores del módulo:**
```dart
negro      = Color(0xFF0A0F23)  // Fondo azul marino
grisOscuro = Color(0xFF151932)  // Superficie
grisMedio  = Color(0xFF1E2139)  // Tarjeta
grisClaro  = Color(0xFF2A2E45)  // Borde/outline
accent     = Color(0xFF00FFC8)  // Cian brillante (primario)
accentRosa = Color(0xFFFF3296)  // Magenta (favoritos/alertas)
```

---

## Archivo Principal

**`lib/features/explorar_negocios/pantallas/pantalla_explorar.dart`** (1873 líneas)

---

## Estructura de Navegación

```
PantallaExplorar (Stateful)
├── IndexedStack (4 pestañas, preserva estado)
│   ├── [0] _TabExplorar       → Descubrir negocios
│   ├── [1] _TabBuscar         → Búsqueda por texto/categoría
│   ├── [2] _TabFavoritos      → Lista de favoritos guardados
│   └── [3] PantallaPerfilCliente → Perfil del usuario
└── _BottomBar (barra de navegación inferior)
    ├── 🔲 Explorar
    ├── 🔍 Buscar
    ├── ❤️ Favoritos
    └── 👤 Perfil
```

El `IndexedStack` preserva el estado de cada pestaña al cambiar entre ellas (no recarga).

---

## TAB 0 — Explorar (`_TabExplorar`)

**Función**: Pantalla principal de descubrimiento de negocios. Usa `CustomScrollView` con `SliverAppBar`.

### Componentes:

#### AppBar Sticky (SliverAppBar, floating + snap)
- **Logo** "Fluix" en cian, tamaño 28, fontWeight 800
- **Botón de filtros**: Icono `tune_rounded`
  - Si hay filtros activos: borde cian + fondo cian 20% opacidad
  - Al tocar: abre `FiltrosBottomSheet`
- **Campanita de notificaciones**: 
  - StreamBuilder que escucha `usuarios/{uid}/notificaciones WHERE leida==false`
  - Muestra badge rojo magenta con el número (máx 9+)
  - Al tocar: navega a `PantallaNotificacionesCliente`

#### Saludo contextual
- Buenos días / Buenas tardes / Buenas noches
- Según hora del sistema (< 12 = días, < 19 = tardes, resto = noches)

#### Chips de Categorías
- "Todo" / "🔥 Tendencias" / Restaurantes / Estéticas / Peluquerías / Carnicerías / Tatuajes
- Al seleccionar: filtra todas las secciones
- Tendencias usa gradiente rosa→naranja cuando está activo

#### Carrusel Flash Slots
- Widget `CarruselFlashSlots` embebido (descuentos/slots de última hora)

#### Sección "Ofertas especiales" 🔥
- Carrusel horizontal de tarjetas anchas (240px × 120px)
- Clase: `_CarruselOfertas` → `_TarjetaOferta`
- Fuente: `negocios_publicos WHERE activo=true` (con filtros opcionales)
- Badge naranja "OFERTA" + Badge Abierto/Cerrado + Corazón

#### Sección "Recomendados" ⭐
- Carrusel horizontal compacto (140px × 175px)
- Clase: `_CarruselCompacto` con `filtroRating: 4.0`
- Fuente: `negocios_publicos WHERE ratingGoogle >= 4.0`

#### Sección "Cerca de ti" 📍
- Mismo carrusel compacto pero ordenado por distancia
- Requiere permiso de ubicación
- Usa `GeolocalizacionService.obtenerPosicion()`
- Si tiene ubicación: muestra distancia en km (ej: "1.2 km")
- Si no tiene: muestra mensaje "Activa la ubicación para ver cercanos"

#### Grid "Encuentra tu nuevo favorito" ✨
- Grid 2 columnas (SliverGrid), `childAspectRatio: 0.75`
- Clase: `_TarjetaGrid`
- Paginación: carga todos con `StreamBuilder` (en tiempo real)
- Filtros aplicados en cliente: categoría, rating, soloAbiertos

#### Botón "Ver todo →"
- Cada sección tiene enlace "Ver todo →" en cian
- Navega a `PantallaListadoCompleto(titulo, filtro, cat)`

---

## TAB 1 — Buscar (`_TabBuscar`)

**Función**: Búsqueda en tiempo real de negocios.

### Características:
- Stream **persistente**: carga hasta 200 negocios UNA vez, filtra en cliente
- **Buscador**: TextField oscuro con placeholder "Busca negocios o servicios..."
  - Spinner mientras carga datos
  - Botón X para limpiar
- **Chips de categorías**: Se muestran cuando no hay texto escrito
- **Filtrado**: Por `nombre`, `descripcion`, `categoria.label`, `direccion`, `tagline`
- **Modo categoría**: Al tocar chip, muestra todos los negocios de esa categoría

### Estados:
1. **Sin texto + sin categoría**: Muestra "Categorías populares" como lista
2. **Con texto o categoría**: Muestra resultados filtrados en lista
3. **Sin resultados**: Mensaje con icono `search_off_rounded`
4. **Error de red**: Muestra error + descripción

### Tarjeta de resultado (lista):
- Foto 56×56px (circular)
- Nombre + badge categoría + rating Google
- Descripción (1 línea truncada)
- Botón corazón favorito

---

## TAB 2 — Favoritos (`_TabFavoritos`)

**Función**: Lista de negocios guardados por el usuario.

### Estructura de datos (Firestore):
```
usuarios/{uid}/favoritos/{negocioId}
  negocio_id: string
  nombre: string
  foto_url: string
  categoria: string (enum name)
  rating: number?
  guardado_en: Timestamp
```

### Comportamiento:
- Si no está logueado: mensaje "Inicia sesión para guardar favoritos"
- Si está vacío: mensaje con emoji y "Pulsa el ❤️ en cualquier negocio para guardarlo aquí"
- Si hay error Firestore: muestra icono candado y descripción del error
- **Ordenación**: Por `guardado_en` descendente (cliente-side, sin índice compuesto)
- **Grid 2 columnas** (`childAspectRatio: 0.82`)
- Al tocar tarjeta: carga el negocio completo desde `negocios_publicos/{id}` y navega al detalle
- El corazón en la tarjeta: **elimina** directamente de favoritos (sin push animation)

---

## Sistema de Favoritos (`_FavService`)

```dart
_FavService.esFavorito(negocioId) → Future<bool>
_FavService.toggle(negocio, agregar) → Future<void>
```

- Guarda/borra en `usuarios/{uid}/favoritos/{negocioId}`
- **Error silencioso**: Errores de permisos se ignoran (no rompen la UI)
- El botón corazón (`_HeartButton`) tiene animación `elasticOut` al marcar favorito

---

## Sistema de Filtros (`FiltrosExplorar`)

Clase de value object inmutable con los filtros activos.

### Filtros disponibles:
| Filtro | Tipo | Default | Descripción |
|---|---|---|---|
| `precio` | RangeValues | 0–200 | Rango de precio (no implementado en query, solo UI) |
| `ratingMin` | int | 0 | Rating mínimo de Google (0 = sin filtro) |
| `radioKm` | int | 0 | Radio de búsqueda en km (reservado, no implementado) |
| `soloAbiertos` | bool | false | Solo negocios abiertos ahora |

### `FiltrosBottomSheet`:
- BottomSheet modal de fondo oscuro
- Slider de rango de precio
- 5 estrellas táctiles para rating mínimo
- Switch "Solo negocios abiertos ahora"
- Botones "Limpiar" (reset) y "Aplicar"

### Aplicación de filtros:
1. Los filtros de `ratingGoogle` y `tendencias` se aplican en la **query Firestore**
2. Los filtros `soloAbiertos` y precio se aplican en **cliente** (después de recibir datos)

---

## Detección de Abierto/Cerrado (`_HorarioHelper`)

### Lógica de prioridad:
1. **Campo `horario`** (Map<String, Map>) — usado en B2C (formato `{Nombre_dia: {apertura, cierre, cerrado}}`)
2. **Campo `horarios`** (Map<int, HorarioDia>) — usado en B2B (formato `{1: HorarioDia}`)

### Soporte de turno partido:
- Detecta `apertura_tarde` y `cierre_tarde` para negocios con horario partido

### Badge `_BadgeHorario`:
- Verde oscuro con "Abierto" / Negro transparente con "Cerrado"
- Si no hay datos de horario: widget invisible (`SizedBox.shrink()`)

---

## Pantalla Detalle de Negocio (`DetalleNegocioScreen`)

**Archivo**: `lib/features/reservas_cliente/pantallas/detalle_negocio_screen.dart`

### Estructura actual (antes del rediseño):
- `SliverAppBar` expandible con foto (250px)
- Sección de header: nombre + badge categoría + rating Google
- Galería horizontal de fotos (si existe `fotosGaleria`)
- Descripción "Sobre nosotros"
- Servicios destacados (chips con borde cian)
- Características (chips rellenos)
- Horarios (grid 2 columnas)
- Información de contacto (dirección, teléfono)
- Redes sociales (Instagram, Facebook, WhatsApp, Web)
- Formulario de reserva (`FormularioReservaFactory` según categoría)

### Formulario de reserva por categoría:
El `FormularioReservaFactory` selecciona el formulario según `negocio.categoria`:
- `restaurantes` → Formulario con fecha, hora, personas, zona, alérgenos
- `peluquerias` / `esteticas` → Formulario con servicio, profesional, hora
- `tatuajes` → Formulario con descripción, zona del cuerpo
- Resto → Formulario genérico

---

## Pantalla Listado Completo (`PantallaListadoCompleto`)

Accesible vía "Ver todo →" desde las secciones.

### Parámetros:
- `titulo`: Título del AppBar
- `filtro`: `'ofertas'` | `'recomendados'` | `'cercanos'`
- `cat`: Categoría inicial (opcional)

### Características:
- AppBar con chips de categorías horizontales
- Stream en tiempo real de `negocios_publicos`
- Si `filtro == 'recomendados'`: ordena por `ratingGoogle` desc + filtra >= 4.0
- Grid 2 columnas (`childAspectRatio: 0.72`)

---

## Pantalla Notificaciones Cliente (`PantallaNotificacionesCliente`)

**Archivo**: `lib/features/explorar_negocios/pantallas/pantalla_notificaciones_cliente.dart`

### Estructura de datos:
```
usuarios/{uid}/notificaciones/{notifId}
  titulo: string
  cuerpo: string
  tipo: string  (reserva_confirmada | reserva_cancelada | reserva_pendiente | promo | info)
  creado_en: Timestamp
  leida: bool
```

### Características:
- Lista de 50 notificaciones más recientes
- Notificaciones no leídas: fondo cian muy transparente + punto cian + texto en negrita
- Al tocar: marca como leída
- Botón "Marcar leídas" en AppBar: marca todas en batch
- Formato de fecha relativo: "Ahora", "Hace 5 min", "Hace 2h", "Ayer", "Hace 3 días", "dd/mm/yyyy"

---

## Fuente de Datos (Firestore)

### Colección principal:
```
negocios_publicos/{negocioId}
  activo: bool           → Solo los activos aparecen en explorar
  nombre: string
  categoria: string      → enum (restaurantes, esteticas, peluquerias...)
  fotoUrl: string?
  ratingGoogle: double?
  ratingFluix: double?   → Calculado desde valoraciones de usuarios Fluix
  totalValoraciones: int?
  direccion: string?
  descripcion: string?
  descripcionDetallada: string?
  tagline: string?       → Frase corta mostrada en tarjeta grid
  precioMedio: string?   → ej: "10-20€ por persona"
  latitud: double?
  longitud: double?
  horario: Map           → {Lunes: {apertura, cierre, cerrado}}
  horarios: Map          → {1: {abierto, horaApertura, horaCierre}}
  fotosGaleria: List<String>?
  serviciosDestacados: List<String>?
  especialidades: List<String>?
  caracteristicas: List<String>?
  aceptaTarjeta: bool?
  tieneParking: bool?
  tieneWifi: bool?
  admiteMascotas: bool?
  tieneTerraza: bool?
  instagram: string?
  facebook: string?
  whatsapp: string?
  website: string?
  empresaIdVinculada: string  → Enlace con la empresa en Firestore
```

### Subcolecciones relevantes:
```
negocios_publicos/{id}/valoraciones/{valId}
  estrellas: int
  comentario: string
  clienteNombre: string
  creadaEn: Timestamp
  origen: "fluix" | "google"
```

---

## Otros Widgets Auxiliares

### `_TarjetaGrid` (grid principal, 2 columnas)
- Foto cuadrada `AspectRatio: 1.05`
- Nombre (2 líneas)
- Tagline en itálica (opcional)
- Estrellas renderizadas 1-5
- Badge de categoría
- Badge de precio medio
- Corazón + Badge Abierto/Cerrado en overlay

### `_TarjetaCompacta` (carrusel 140px)
- Foto 100px de altura
- Nombre, rating, badge categoría
- Distancia (si disponible)
- Corazón + Badge en overlay

### `_TarjetaOferta` (carrusel 240px)
- Foto full-bleed con gradiente oscuro
- Badge verde "OFERTA"
- Nombre + rating

### `_SkeletonCarrusel`
- Shimmer loading mientras cargan los negocios
- Usa paquete `shimmer`

---

## Geolocalización

**Servicio**: `GeolocalizacionService` (`lib/services/geolocalizacion_service.dart`)

```dart
GeolocalizacionService.obtenerPosicion() → Future<{ok, posicion}>
GeolocalizacionService.distanciaKm(lat1, lon1, lat2, lon2) → double
GeolocalizacionService.formatearDistancia(km) → "1.2 km" | "850 m"
```

- Solicita permisos automáticamente al cargar `_TabExplorar`
- Si el usuario rechaza: sección "Cerca de ti" muestra mensaje informativo
- La distancia se calcula en cliente con fórmula Haversine

---

## Datos del Modelo `NegocioPublico`

**Archivo**: `lib/models/negocio_publico_model.dart`

El modelo es el punto de entrada para toda la información del negocio. Campos principales agrupados:

| Grupo | Campos |
|---|---|
| **Identidad** | `id`, `nombre`, `categoria`, `activo` |
| **Fotos** | `fotoUrl`, `fotoSecundariaUrl`, `fotosGaleria` |
| **Ratings** | `ratingGoogle`, `ratingFluix`, `numResenas`, `totalValoraciones` |
| **Textos** | `descripcion`, `descripcionDetallada`, `tagline`, `precioMedio` |
| **Contacto** | `telefono`, `email`, `emailPublico`, `web`, `website`, `googleMapsUrl` |
| **Redes Sociales** | `instagram`, `facebook`, `whatsapp` |
| **Amenidades** | `aceptaTarjeta`, `tieneParking`, `tieneWifi`, `admiteMascotas`, `tieneTerraza`, `accesibleSillaRuedas` |
| **Horarios** | `horario` (B2C Map<String>), `horarios` (B2B Map<int>) |
| **Servicios** | `serviciosDestacados`, `especialidades`, `caracteristicas` |
| **Reservas** | `reservasOnline`, `camposPersonalizados`, `formularioTitulo`, `formularioBoton`, `duracionPromedio` |
| **Geo** | `latitud`, `longitud` |
| **Empresa** | `empresaIdVinculada`, `emailNotificaciones` |

---

## Flujo de Reserva desde Explorar

```
Cliente ve negocio → Abre DetalleNegocioScreen
  → FormularioReservaFactory.crearFormulario(categoria, negocio)
  → Usuario rellena formulario
  → Se crea documento en empresas/{empresaIdVinculada}/reservas/{id}
     · estado: "PENDIENTE"
     · origen: "app_cliente"
  → Cloud Function onNuevaReserva → Push a empresa + Email empresa
  → Si empresa confirma → onReservaConfirmada → Email al cliente
```

---

*Documentación generada — Fluix CRM v2026*

