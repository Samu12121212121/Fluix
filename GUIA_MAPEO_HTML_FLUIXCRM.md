# 🔗 GUÍA: Mapear HTML para que Fluix CRM lo reciba en tiempo real

## 🎯 ¿Qué significa "mapear HTML"?

El sistema **data-fluix** conecta tu web estática con Firestore.  
Añades atributos especiales (`data-fluix-*`) a tu HTML existente y el script:

1. **Lee** el HTML por primera vez → guarda el contenido en Firestore (**seed**)
2. **Escucha** los cambios de Firestore → actualiza el HTML automáticamente (**tiempo real**)

El empresario edita desde la app → la web cambia sin tocar código.

---

## 🚀 Instalación en 3 pasos

### Paso 1 — Añade el script antes del `</body>`

Ve a la app → módulo **Web** → botón **Obtener código** → copia el bloque `③`.

```html
<!-- Pegar justo antes de </body> en TODAS tus páginas -->
<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-auth-compat.js"></script>
<script>
  /* ← Aquí va el código generado por la app */
</script>
```

### Paso 2 — Crea una sección en la app

1. App → **Web** → **+** (Nueva sección)
2. Escribe un nombre, p. ej. `Carta`
3. Selecciona tipo **Sección genérica**
4. Guarda → la sección obtiene un ID automático, p. ej. `carta_restaurante`

### Paso 3 — Mapea tu HTML

Añade el atributo `data-fluix-seccion="<ID>"` al contenedor principal
y `data-fluix-item` / `data-fluix-campo` a sus hijos.

---

## 📐 Estructura de atributos

| Atributo | Se pone en | Descripción |
|---|---|---|
| `data-fluix-seccion="ID"` | Contenedor padre | Identifica la sección. El ID debe coincidir con el de la app |
| `data-fluix-titulo` | Cualquier elemento | El nombre de la sección (se actualiza con el nombre en la app) |
| `data-fluix-item="ID_ITEM"` | Cada fila/producto | Identifica un item dentro de la sección |
| `data-fluix-campo="nombre_campo"` | Dentro de un item | El dato concreto (nombre, precio, descripción, imagen…) |

---

## 🏷️ `data-fluix-item` — ¿qué es y cómo funciona?

Un **item** es cada elemento repetible dentro de una sección: un plato, un servicio,
una oferta, una habitación… Lo que sea que el empresario quiera editar individualmente.

### Reglas del ID de item

- Debe ser **único dentro de la sección** (no en toda la web)
- Sin espacios. Usa `_` o `-`
- Puede ser descriptivo o un código interno
- ✅ `pizza_margarita`, `item_001`, `servicio-corte`
- ❌ `Pizza Margarita`, `item/1`

### ¿Qué controla el script sobre un item?

| Acción en la app | Efecto en el HTML |
|---|---|
| Editar cualquier campo | Se reescribe el elemento `data-fluix-campo` correspondiente |
| Marcar como "No disponible" | `opacity: 0.5` + clase `fluix-no-disponible` |
| Volver a "Disponible" | Quita la opacidad y la clase |
| Eliminar el item | El bloque queda con `opacity: 0.5` (no se borra del HTML) |
| Reordenar items | El orden visual **no** cambia (el HTML es estático; solo cambian los valores) |

### Ejemplo visual

```html
<!-- Antes (web estática) -->
<div data-fluix-item="corte_mujer">
  <h3 data-fluix-campo="nombre">Corte mujer</h3>
  <b  data-fluix-campo="precio">25€</b>
</div>

<!-- Después de que el empresario cambie el precio a 28€ desde la app -->
<div data-fluix-item="corte_mujer">
  <h3 data-fluix-campo="nombre">Corte mujer</h3>
  <b  data-fluix-campo="precio">28€</b>   <!-- ← actualizado en tiempo real -->
</div>
```

---

## 🏷️ `data-fluix-campo` — ¿qué es y cómo funciona?

Un **campo** es un dato concreto de un item: su nombre, precio, descripción, imagen, URL…

### Los campos son completamente libres

No hay una lista fija. El nombre del campo en el HTML **es la clave** que se guarda
en Firestore y que aparece editable en la app.

```
HTML:  data-fluix-campo="precio_socio"
App:   muestra un campo de texto llamado "precio_socio"
```

### Campos más comunes (convención recomendada)

| Nombre de campo | Tipo recomendado | Ejemplo de valor |
|---|---|---|
| `nombre` | Texto | `Pizza Margarita` |
| `descripcion` | Texto largo | `Tomate, mozzarella y albahaca` |
| `precio` | Número | `9.50` → se muestra `9.50€` |
| `precio_original` | Número | `15.00` → se muestra `15.00€` |
| `imagen` | URL | `https://...jpg` → se pone en `src` |
| `enlace` | URL | `https://...` → se pone en `href` de `<a>` |
| `etiqueta` | Texto | `Nuevo`, `Recomendado` |
| `duracion` | Texto | `45 min` |
| `categoria` | Texto | `Entrantes` |

> Puedes crear **cualquier campo** que necesites. La app lo mostrará como un
> campo de texto editable con el mismo nombre que escribiste en el HTML.

### El tag HTML importa

El script escribe el valor de forma inteligente según el elemento:

```html
<!-- img → actualiza src -->
<img data-fluix-campo="imagen" src="foto.jpg">

<!-- a → actualiza href -->
<a data-fluix-campo="enlace" href="https://...">Ver más</a>

<!-- campo "precio" en cualquier tag → añade € automáticamente -->
<span data-fluix-campo="precio">9.50€</span>
<!-- Si en la app escribes 12, el span mostrará: 12€ -->

<!-- cualquier otro tag → actualiza textContent -->
<p data-fluix-campo="descripcion">Texto inicial</p>
```

### Un item puede tener todos los campos que quieras

```html
<article data-fluix-item="habitacion_doble">
  <img    data-fluix-campo="imagen">
  <h3     data-fluix-campo="nombre">Habitación doble</h3>
  <p      data-fluix-campo="descripcion">Vista al mar, baño privado</p>
  <span   data-fluix-campo="precio">120€</span>
  <small  data-fluix-campo="capacidad">2 personas</small>
  <a      data-fluix-campo="enlace" href="#">Reservar</a>
  <span   data-fluix-campo="etiqueta">⭐ Más vendida</span>
</article>
```

Todos estos campos aparecerán en la app como campos editables para esa habitación.

---

## 🍽️ Ejemplo completo — Carta de un restaurante

### HTML mapeado

```html
<section data-fluix-seccion="carta_restaurante">
  <h2 data-fluix-titulo>Nuestra Carta</h2>

  <!-- Item 1 -->
  <article data-fluix-item="pizza_margarita">
    <img    data-fluix-campo="imagen"      src="pizza.jpg" alt="Pizza">
    <h3     data-fluix-campo="nombre">     Pizza Margarita</h3>
    <p      data-fluix-campo="descripcion">Tomate, mozzarella y albahaca fresca</p>
    <span   data-fluix-campo="precio">     9.50€</span>
  </article>

  <!-- Item 2 -->
  <article data-fluix-item="ensalada_cesar">
    <img    data-fluix-campo="imagen"      src="ensalada.jpg" alt="Ensalada">
    <h3     data-fluix-campo="nombre">     Ensalada César</h3>
    <p      data-fluix-campo="descripcion">Lechuga romana, parmesano y anchoas</p>
    <span   data-fluix-campo="precio">     8.00€</span>
  </article>
</section>
```

### Lo que hace el script automáticamente

1. **Primera carga** (seed): Lee `Pizza Margarita`, `9.50€`, etc. del HTML y los
   guarda en Firestore bajo `empresas/{empresaId}/contenido_web/carta_restaurante`.

2. **Desde ese momento**: Si en la app cambias el precio a `10.50€`, Firestore
   lo actualiza y el script reescribe el `<span>` en la web **sin recargar**.

3. **Ocultar item**: En la app activas "No disponible" en `pizza_margarita` →
   el `<article>` se pone con `opacity: 0.5` y clase `fluix-no-disponible`.

4. **Ocultar sección**: En la app desactivas la sección →
   el `<section>` queda `display: none`.

---

## 💇 Ejemplo — Servicios de peluquería

```html
<section data-fluix-seccion="servicios_pelu">
  <h2 data-fluix-titulo>Servicios</h2>

  <div data-fluix-item="corte_mujer">
    <h3   data-fluix-campo="nombre">Corte mujer</h3>
    <p    data-fluix-campo="descripcion">Incluye lavado y secado</p>
    <b    data-fluix-campo="precio">25€</b>
  </div>

  <div data-fluix-item="coloracion">
    <h3   data-fluix-campo="nombre">Coloración completa</h3>
    <p    data-fluix-campo="descripcion">Tinte + mechas</p>
    <b    data-fluix-campo="precio">65€</b>
  </div>
</section>
```

---

## 🏪 Ejemplo — Ofertas de cualquier negocio

```html
<section data-fluix-seccion="ofertas_mes">
  <h2 data-fluix-titulo>Ofertas del mes</h2>

  <div data-fluix-item="oferta_navidad">
    <img   data-fluix-campo="imagen"      src="oferta.jpg">
    <h3    data-fluix-campo="nombre">     Pack Navidad</h3>
    <p     data-fluix-campo="descripcion">Válido hasta el 31 de diciembre</p>
    <del   data-fluix-campo="precio_original">50€</del>
    <strong data-fluix-campo="precio">   35€</strong>
  </div>
</section>
```

> ⚠️ Los nombres de campos son **libres**: puedes usar `precio_original`, `duracion`,
> `categoria`, `etiqueta`… cualquier clave que pongas en el HTML se guardará en
> Firestore y podrás editarla desde la app.

---

## 📋 Campos especiales por tipo de etiqueta

El script detecta el tipo de tag y actúa diferente:

| Tag HTML | Campo | Qué actualiza el script |
|---|---|---|
| `<img>` | cualquiera | `src` de la imagen |
| `<a>` | cualquiera | `href` del enlace |
| `<span>`, `<p>`, `<h3>`… | `precio` | Añade `€` automáticamente |
| Cualquier otro | cualquiera | `textContent` del elemento |

---

## 🌐 Divs genéricos (sin seed)

Si no quieres hacer seed desde el HTML (prefieres crear el contenido
100% desde la app), usa divs vacíos y el script los rellenará al vuelo:

```html
<!-- Este div estará vacío hasta que lo actives en la app -->
<div id="fluixcrm_novedades"></div>
```

La app genera estos divs automáticamente al pulsar **"Obtener código" → bloque ②**.

---

## 🔄 Ciclo de vida completo

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. Empresario crea sección "carta" en la app con ID carta_rest    │
│ 2. Añades data-fluix-seccion="carta_rest" a tu <section> HTML     │
│ 3. El visitante abre la web                                       │
│    → Script hace auth anónima en Firebase                         │
│    → Busca doc contenido_web/carta_rest en Firestore              │
│    → Si no existe: SEED (lee HTML → guarda en Firestore)          │
│    → Si ya existe: salta el seed                                  │
│ 4. Script activa el listener en tiempo real                       │
│ 5. Empresario edita precio desde la app                           │
│    → Firestore se actualiza                                       │
│    → Script recibe el cambio                                      │
│    → Script reescribe el <span data-fluix-campo="precio">         │
│    → El visitante ve el nuevo precio SIN RECARGAR                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## ❓ Preguntas frecuentes

### ¿El ID de la sección puede ser cualquier texto?

Sí, pero sin espacios ni caracteres especiales. Usa `_` o `-` como separadores.
- ✅ `carta_restaurante`, `ofertas-mes`, `servicios2024`
- ❌ `Carta Restaurante`, `ofertas/mes`

### ¿Qué pasa si borro un item desde la app?

El item desaparece de Firestore. El script pone `opacity: 0.5` en ese `data-fluix-item`.
Si quieres que se **oculte del todo**, añade este CSS:

```css
.fluix-no-disponible { display: none; }
```

### ¿Funciona con WordPress?

Sí. Pega el script en **Apariencia → Editor → footer.php** justo antes de `</body>`,
o usa un plugin de "Insert Headers and Footers".

### ¿Funciona con Hostinger Website Builder?

Sí. Usa la opción "Código personalizado" → pie de página → pega el bloque `③`.

### ¿Los datos están seguros?

El script usa autenticación **anónima** de Firebase solo para leer. Las reglas
de Firestore solo permiten escritura al usuario autenticado con la app.
Los visitantes de la web **nunca pueden modificar** los datos.

### ¿Cuántas secciones puedo tener?

Ilimitadas. Cada `<section data-fluix-seccion="ID">` es un listener independiente.

---

## 🧪 Depuración — Consola del navegador

Abre DevTools (F12) → Consola. Verás mensajes de Fluix:

```
Fluix: autenticacion anonima OK
Fluix seed: carta_restaurante ya existe
Fluix: 2 seccion(es) conectadas
```

Si ves errores, comprueba:
1. Que el ID en el HTML coincide exactamente con el ID en la app
2. Que el script esté pegado **antes** del `</body>`
3. Que las reglas de Firestore permitan lectura anónima en `contenido_web`

---

*Generado automáticamente · Fluix CRM · 2026*


