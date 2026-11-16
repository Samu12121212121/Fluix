# Pantalla Explorar — Qué se ve, desde dónde se configura y qué falta

> **Referencia de código:** `lib/features/explorar_negocios/pantallas/pantalla_explorar.dart`

---

## Mapa de secciones (de arriba a abajo)

```
┌────────────────────────────────────────────────────┐
│  1. Hero / Banner (foto ciudad + buscador)         │
├────────────────────────────────────────────────────┤
│  2. Chips de categoría                             │
├────────────────────────────────────────────────────┤
│  3. Ofertas flash  ⚡                              │
├────────────────────────────────────────────────────┤
│  4. Ofertas especiales  🏷️ (si hay alguna)         │
├────────────────────────────────────────────────────┤
│  5. Recomendados  ⭐ (si hay rating ≥ 4.0)         │
├────────────────────────────────────────────────────┤
│  6. Cerca de ti  📍 (si hay permiso de ubicación)  │
├────────────────────────────────────────────────────┤
│  7. Todos los negocios  — grid 2 columnas          │
└────────────────────────────────────────────────────┘
```

---

## 1. Hero / Banner superior

**Qué muestra:** foto de ciudad a pantalla completa + gradiente oscuro + texto ciudad + buscador inline.

| Elemento | Estado actual | Dónde configurar |
|---|---|---|
| Foto de fondo | **Hardcoded** → `palacio_infantado.webp` | No se puede cambiar aún |
| Texto "GUADALAJARA" | **Hardcoded** en el código | No se puede cambiar aún |
| Subtítulo | **Hardcoded** "Descubre algo nuevo." | No se puede cambiar aún |
| Buscador | Funciona — filtra por nombre, descripción corta y categoría | Sin configuración necesaria |
| Botón filtros | Funciona — filtra por rating, distancia, abiertos | Sin configuración necesaria |

**Falta añadir:**
- [ ] Que la foto cambie según la ciudad del usuario (campo `ciudad` en perfil → lookup imagen)
- [ ] Que el texto "GUADALAJARA" sea dinámico según ciudad

---

## 2. Chips de categoría

**Qué muestra:** "Todo", "Tendencias 🔥", y una píldora por cada categoría del enum `CategoriaNegocio`.

| Chip | Criterio |
|---|---|
| Todo | Sin filtro |
| Tendencias 🔥 | `ratingFluix >= 4.3` |
| Restaurantes, Peluquerías, etc. | Categoría del negocio |

**Dónde se configura:**
- La categoría de cada negocio → **Mi App → cabecera principal** (selector de categoría junto al nombre).
- `ratingFluix` (para tendencias) → actualmente no tiene UI de edición para el admin, solo se puede poner directamente en Firestore.

**Falta añadir:**
- [ ] Editar `ratingFluix` desde Mi App (sección Reseñas o Estadísticas)
- [ ] El límite de top-5 por categoría es **temporal** (hardcoded `_kMaxPorCategoria = 5`) — hay que eliminarlo cuando haya más datos

---

## 3. Ofertas flash ⚡

**Qué muestra:** tarjetas oscuras con foto, servicio, precio con descuento y cuenta atrás. Desaparecen cuando expiran o se llenan.

**Origen de datos:** subcolección `flash_slots` dentro de cada `negocios_publicos/{id}/flash_slots`.

**Dónde se configura:**
> Dashboard de empresa → sidebar → icono ⚡ → **"Nueva oferta flash"** (`PantallaCrearFlashSlot`)

Campos que se rellenan al crear un flash slot:

| Campo | Descripción |
|---|---|
| Servicio | Se elige de la lista de servicios activos del negocio |
| Descuento | En % o en € fijo |
| Fecha y hora del hueco | Cuándo es la cita/servicio |
| Tiempo de visibilidad | Cuánto tiempo se muestra (1h, 2h, 4h, 8h, 24h) |
| Huecos disponibles | Cuántas reservas acepta (1–20) |
| Profesional | Opcional, asignar a un empleado concreto |

**Condición para aparecer en Explorar:** `estado == 'activo'` + `fecha_hora_expiracion > ahora` + `huecos_reservados < huecos_totales`

**Falta añadir:**
- [ ] Ver y gestionar los flash slots activos desde Mi App (no hay listado)
- [ ] Cancelar un flash slot desde Mi App
- [ ] Notificación push cuando se reserva un hueco

---

## 4. Ofertas especiales 🏷️

**Qué muestra:** carrusel horizontal de negocios que tienen algún mensaje promocional activo. Se colapsa si no hay ninguno.

**Condición para aparecer:** el negocio debe tener el campo `mensajePromocional` relleno.

**Dónde se configura:**
> Mi App → sección **"Diseño"** → campo "Mensaje promocional"

Ejemplo de valor: `"Esta semana: 20% en coloraciones"`

**Diferencia con flash:** es un mensaje genérico sin fecha de expiración ni plazas limitadas. Aparece mientras el campo esté relleno.

**Falta añadir:**
- [ ] Fecha de expiración para el mensaje (para que caduque solo)
- [ ] Imagen propia para la oferta (ahora usa la foto principal del negocio)

---

## 5. Recomendados ⭐

**Qué muestra:** carrusel de negocios con `ratingGoogle >= 4.0`, ordenados de mayor a menor rating.

**Origen:** campo `ratingGoogle` en el documento de `negocios_publicos`.

**Dónde se configura:**
> No configurable directamente. El `ratingGoogle` se importa de Google Places o se introduce en Firestore manualmente.

**Falta añadir:**
- [ ] Importación automática del rating de Google (actualmente manual)
- [ ] Opción de usar `ratingFluix` también para este carrusel

---

## 6. Cerca de ti 📍

**Qué muestra:** carrusel ordenado por distancia al usuario. Solo aparece si el usuario da permiso de ubicación.

**Condición para aparecer:** el negocio debe tener `latitud` y `longitud` rellenados.

**Dónde se configura:**
> Mi App → sección **"Ubicación"** → campos latitud / longitud (o introducir dirección completa y auto-geocodificar)

**Falta añadir:**
- [ ] Geocodificación automática al guardar la dirección (ahora hay que meter lat/lng a mano)

---

## 7. Grid "Todos los negocios"

El grid más importante. Muestra todos los negocios activos que pasan los filtros mínimos.

### Condición para aparecer en el grid

Un negocio aparece solo si cumple **todo esto**:

1. `activo == true` → **Mi App → interruptor "Visible/Oculto"** en la cabecera
2. `tieneDatosMinimos` → necesita al menos **foto principal O descripción** rellenas
3. Pasar el filtro top-5 por categoría (puntuación de completitud, temporal)

### Campos visibles en cada tarjeta

| Lo que se ve | Campo Firestore | Dónde configurar en Mi App |
|---|---|---|
| **Foto principal** | `fotosGaleria[0]` (primera foto) | **Galería** → sube fotos, la primera es la portada |
| **Nombre** | `nombre` | **Identidad** → "Nombre del negocio" |
| **Rating** | `ratingGoogle` | No editable (Google) |
| **Reseñas** | `numResenas` | No editable (Google) |
| **Categoría** | `categoria` | Selector al crear / cabecera de Mi App |
| **Bio** | `descripcionCorta` si existe, si no `descripcion` | **Identidad** → "Descripción corta" (recomendado, máx. 1-2 líneas) |
| **Badge Abierto/Cerrado** | `horario` o `horarios` | **Horarios** → horario semanal |

### Puntuación de completitud (afecta la posición en el top-5)

Cuantos más campos rellenos, antes aparece el negocio dentro de su categoría:

| Campo | Puntos |
|---|---|
| Foto principal (`fotoUrl`) | +3 |
| Foto secundaria | +1 |
| Logo | +2 |
| Descripción detallada | +2 |
| Descripción corta | +1 |
| Tagline | +1 |
| Teléfono | +1 |
| WhatsApp | +1 |
| Email | +1 |
| Rating Fluix | +2 |
| Rating Google | +2 |
| URL pública | +1 |
| Subcategorías | +1 |
| **Total máximo** | **17 pts** |

---

## Resumen de secciones en Mi App que afectan al Explorar

| Sección Mi App | Qué cambia en Explorar |
|---|---|
| **Cabecera** (interruptor Visible/Oculto) | El negocio aparece o desaparece del grid |
| **Cabecera** (categoría) | En qué chip aparece el negocio |
| **Identidad** → Nombre | Nombre en la tarjeta |
| **Identidad** → Descripción corta | Bio bajo el rating en la tarjeta |
| **Identidad** → Descripción detallada | Bio de fallback si no hay descripción corta |
| **Galería** → primera foto subida | Foto de portada de la tarjeta |
| **Horarios** → horario semanal | Badge "Abierto / Cerrado" en la tarjeta |
| **Ubicación** → latitud / longitud | El negocio aparece en "Cerca de ti" |
| **Diseño** → Mensaje promocional | El negocio aparece en "Ofertas especiales" |
| **Flash Slots** (módulo aparte) | El negocio aparece en "Ofertas flash" |

---

## Lista priorizada de lo que falta

### Alta prioridad
- [ ] **`ratingGoogle` / `numResenas` auto-importados** — ahora hay que meterlos a mano en Firestore. Sin rating, el negocio no aparece en "Recomendados" y tiene menos puntuación.
- [ ] **Quitar el límite top-5 por categoría** (`_kMaxPorCategoria = 5` en `pantalla_explorar.dart:494`) — es temporal y oculta negocios válidos. Mientras no haya muchos datos, aumentarlo o eliminarlo.
- [ ] **Geocodificación automática** — al guardar dirección en "Ubicación", calcular lat/lng para que aparezca en "Cerca de ti".

### Media prioridad
- [ ] **Foto del hero configurable** — campo `ciudad` en perfil de cliente → lookup en tabla ciudad→imagen.
- [ ] **Gestión de flash slots activos desde Mi App** — ahora se crean pero no se pueden ver ni cancelar desde la interfaz.
- [ ] **Fecha de expiración en `mensajePromocional`** — para que las "Ofertas especiales" caduquen solas.
- [ ] **`ratingFluix` editable** desde Mi App → sección Reseñas o Estadísticas.

### Baja prioridad
- [ ] Sistema de boost/destacado — pagar para aparecer siempre en top de su categoría.
- [ ] Subcategorías visibles como chip en la tarjeta del grid.
- [ ] `serviciosDestacados` visibles en la tarjeta (el campo existe, fue quitado en el refactor de UI).
- [ ] Notificaciones push al reservar un flash slot.
