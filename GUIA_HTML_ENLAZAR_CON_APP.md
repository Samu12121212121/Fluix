# 📄 Guía: Qué poner en el HTML para enlazarlo con la App

> Esta guía explica exactamente qué tienes que identificar y anotar de cualquier web (Hostinger, WordPress, HTML puro) para que los cambios hechos en la App se reflejen automáticamente en esa web.
> **Tú eres el único que toca el HTML. El empresario solo usa la App.**

---

## 🧠 Concepto clave

El sistema funciona con **atributos `data-*`** que se añaden a los elementos de texto de la web.  
El script de Fluix lee Firestore en tiempo real y cuando detecta un cambio, busca en la web el elemento con ese atributo y actualiza su texto.

---

## Paso 1 — Identifica la sección que quieres controlar

Busca el contenedor principal (una `<section>`, `<div>`, etc.) que engloba todos los elementos que quieres editar desde la app.

Ese contenedor necesita:

```html
<section id="MI_ID_UNICO">
  ...contenido...
</section>
```

Si ya tiene `id`, apúntalo. Si no tiene, ponle uno descriptivo (ej. `id="seccion-carta"`).

---

## Paso 2 — Identifica cada campo editable

Dentro de esa sección, busca cada texto que quieras editar (nombre de plato, precio, descripción, etc.).

Para cada elemento apunta su **`id`** (o añade uno si no lo tiene):

```html
<!-- Ejemplo: nombre del plato -->
<h6 id="mi-plato-nombre"><strong>Paella Mixta</strong></h6>

<!-- Ejemplo: precio -->
<h6 id="mi-plato-precio"><strong>15€</strong></h6>

<!-- Ejemplo: descripción -->
<p id="mi-plato-desc">Arroz con mariscos y verduras.</p>
```

---

## Paso 3 — Crea el mapa de campos

Una vez tienes los `id` de todos los elementos, construyes una tabla como esta:

| `id` en la web       | `item` (nombre interno)   | `campo`       |
|----------------------|---------------------------|---------------|
| `ai-7JVlSQ`          | `paella_mixta`            | `nombre`      |
| `ai-c9wmty`          | `paella_mixta`            | `descripcion` |
| `ai-PPa5hQ`          | `paella_mixta`            | `precio`      |
| `ai-SRuENI`          | `tortilla_espanola`       | `nombre`      |
| `ai-SVrip_`          | `tortilla_espanola`       | `precio`      |

- **`item`**: nombre interno sin espacios ni tildes (lo que verá la App para identificar el producto)
- **`campo`**: puede ser `nombre`, `precio`, `descripcion`, `titulo`, o cualquier clave que decidas

---

## Paso 4 — Qué datos necesitas para el script

Para rellenar el script de código que vas a pegar en la web necesitas:

| Dato              | Dónde encontrarlo                                         | Ejemplo                        |
|-------------------|-----------------------------------------------------------|--------------------------------|
| `empresaId`       | Firestore → colección `empresas` → ID del documento      | `ztZblwm1w71wNQtzHV7S`         |
| `seccionId`       | El nombre que darás a esta sección en la App             | `carta`, `ofertas`, `horarios` |
| `tipo`            | El tipo de contenido                                      | `carta`, `ofertas`, `horarios` |
| `blockId`         | El `id` del contenedor principal (Paso 1)                | `z1Oz3q`                       |
| El mapa de campos | La tabla del Paso 3                                      | Ver tabla arriba               |

---

## Tipos de `campo` soportados

| Campo         | Descripción                              |
|---------------|------------------------------------------|
| `nombre`      | Nombre del plato / producto / elemento   |
| `precio`      | Precio (lo formatea automáticamente con €)|
| `descripcion` | Descripción corta                         |
| `titulo`      | Título de una sección                     |
| `subtitulo`   | Subtítulo                                 |
| `texto`       | Cualquier texto libre                     |

---

## ¿Funciona en cualquier web?

✅ **Hostinger (AI Builder)** — Usa los `id` que el builder asigna automáticamente (ej. `ai-7JVlSQ`)  
✅ **WordPress (Elementor / Kubio / Divi)** — Añade un `id` al widget de texto y lo usas igual  
✅ **HTML estático** — Añade `id` a cualquier etiqueta de texto  
✅ **Múltiples secciones en la misma web** — Cada sección tiene su propio `blockId` y `seccionId`  
✅ **Múltiples webs** — Cada web tiene su propio script con su `empresaId` y su mapa  

---

## ⚠️ Reglas importantes

1. **No toques el diseño** — Solo añades atributos o `id`. El aspecto visual no cambia nunca.
2. **El empresario NO toca el HTML** — Él solo usa la App para cambiar contenido.
3. **Tú decides qué se puede editar** — Solo lo que aparece en el mapa puede modificarse.
4. **Una sección = un documento en Firestore** — La ruta es: `empresas/{empresaId}/contenido_web/{seccionId}`
5. **Primera vez**: después de pegar el script, abre la consola del navegador (F12) y ejecuta `Fluix.sincronizar()` para subir los datos iniciales a Firestore. Solo hay que hacerlo una vez.

---

## Ejemplo visual del flujo

```
Empresario edita "Paella Mixta" → "Paella Marinera" en la App
         ↓
Firestore actualiza: empresas/ztZ.../contenido_web/carta → items[paella_mixta].nombre = "Paella Marinera"
         ↓
El script en la web detecta el cambio en tiempo real (onSnapshot)
         ↓
Busca el elemento con data-fluix-item="paella_mixta" data-fluix-campo="nombre"
         ↓
Actualiza su innerText → la web muestra "Paella Marinera" sin recargar la página
```

---

## 📁 Archivos del sistema

| Archivo                         | Para qué sirve                                          |
|---------------------------------|---------------------------------------------------------|
| `fluix-embed.js`                | Script principal (alojado en Firebase Hosting)          |
| `PEGAR_EN_HOSTINGER.html`       | Código listo para copiar y pegar en el Custom Code      |
| `fluix-setup-hostinger.js`      | Versión alternativa que carga el embed externamente     |
| `CODIGO_COMPLETO_PARA_WEB.md`   | **El código completo comentado que pegas en cada web**  |

