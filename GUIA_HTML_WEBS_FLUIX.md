# 🌐 Guía: Cómo conectar cualquier web a FluixCRM

> Con este sistema el empresario edita el contenido desde la app y la web se actualiza **en tiempo real** sin tocar el HTML.

---

## 🧠 Cómo funciona

```
  App FluixCRM  →  Firestore (Firebase)  →  Script en la web  →  Web actualizada
```

1. El empresario edita el texto/precio en la app
2. Se guarda en Firestore
3. El script que has pegado en la web escucha esos cambios (`onSnapshot`)
4. Los campos del HTML se actualizan solos, sin recargar la página

---

## 📌 Paso 1 — Identificar la sección de la web

Necesitas el **`id`** del bloque / contenedor principal de la sección que quieres conectar.

### En Hostinger (web con IA)
1. Publica la web
2. Abre la web publicada en el navegador
3. Pulsa **F12 → Inspector**
4. Haz clic en el bloque que quieres conectar
5. Busca el atributo `id="..."` en el elemento `<section>` o `<div>` padre

> Ejemplo: `<section id="z1Oz3q">` → tu `blockId` es `z1Oz3q`

### En WordPress / Kubio / Elementor
Igual: F12, haz clic en el bloque, busca el `id` del contenedor.

---

## 📌 Paso 2 — Identificar los elementos que quieres editar

Dentro de esa sección, encuentra el `id` de **cada elemento** de texto que quieras controlar desde la app.

```
Nombre del plato  →  <div id="ai-7JVlSQ"><strong>Paella Mixta</strong></div>
Precio            →  <div id="ai-PPa5hQ"><strong>12€</strong></div>
Descripción       →  <div id="ai-c9wmty"><p>Con marisco fresco...</p></div>
```

Para cada elemento anota:
- El **`id`** del contenedor (`ai-7JVlSQ`, etc.)
- A qué **item** pertenece (ej. `paella_mixta`)
- Qué **campo** representa (`nombre`, `precio`, `descripcion`)

---

## 📌 Paso 3 — Crear el MAPA de conexión

Con los datos del paso 2 rellenas el array `MAPA` del script:

```javascript
var MAPA = [
    { hostingerId: 'ai-7JVlSQ', item: 'paella_mixta',  campo: 'nombre'      },
    { hostingerId: 'ai-c9wmty', item: 'paella_mixta',  campo: 'descripcion' },
    { hostingerId: 'ai-PPa5hQ', item: 'paella_mixta',  campo: 'precio'      },
    { hostingerId: 'ai-SRuENI', item: 'gazpacho',      campo: 'nombre'      },
    { hostingerId: 'ai-3y3igJ', item: 'gazpacho',      campo: 'descripcion' },
    { hostingerId: 'ai-SVrip_', item: 'gazpacho',      campo: 'precio'      },
    // ... más elementos ...
];
```

### Campos disponibles según tipo de sección

| Tipo de sección | Campos disponibles |
|---|---|
| `carta` (carta de restaurante) | `nombre`, `precio`, `descripcion` |
| `ofertas` | `titulo`, `descripcion`, `precio_original`, `precio_oferta` |
| `texto` | `titulo`, `texto` |
| `horarios` | `dia`, `apertura`, `cierre` |
| `galeria` | (sin campos de texto, se gestionan imágenes) |

---

## 📌 Paso 4 — Pegar el script en la web

### En Hostinger
1. Ve al editor → **Páginas** → selecciona la página
2. Clic en **Agregar elemento** → **Código personalizado** (Custom Code)
3. Pega el script completo (ver `CODIGO_FLUIX_PARA_PEGAR.md`)
4. Publical la página

> ⚠️ **Importante**: usa el bloque "Custom Code" de **página**, no el de sección, para que cargue siempre.

### En WordPress
1. Ve a **Apariencia → Editor de temas → footer.php** (o usa un plugin como *Insert Headers and Footers*)
2. Pega el script antes de `</body>`

### En cualquier web HTML estática
Pega el script justo antes de `</body>` en el archivo `.html`.

---

## 📌 Paso 5 — Primera sincronización (solo la primera vez)

La primera vez hay que decirle al script qué hay en la web para que lo suba a Firestore.

1. Publica la página con el script pegado
2. Abre la web en el navegador
3. Pulsa **F12 → Consola**
4. Escribe y pulsa Enter:
```javascript
Fluix.sincronizar()
```
5. Verás: `Fluix: Sincronizado correctamente!`

**A partir de aquí** la app ya puede ver y editar el contenido. Ya no hace falta volver a sincronizar.

---

## 🔁 Funcionamiento continuo

Después de la sincronización inicial:

| Acción en la app | Resultado en la web |
|---|---|
| Editar nombre de un plato | Se cambia en tiempo real |
| Editar precio | Se cambia en tiempo real |
| Desactivar plato (disponible: NO) | El plato aparece al 40% de opacidad |
| Apagar el Switch de la sección | La sección entera desaparece de la web |
| Encender el Switch | La sección vuelve a aparecer |

---

## 🛠️ Herramientas de diagnóstico

Desde la consola del navegador (F12):

```javascript
// Ver estado del script y campos detectados
Fluix.debug()

// Volver a subir los datos de la web a Firestore (solo si es necesario)
Fluix.sincronizar()
```

---

## 🏢 ¿Funciona para varias empresas / webs?

Sí. Cada web tiene su propio `empresaId` y su propio `seccionId`. El script es independiente por página/sección. Puedes tener:

```
fluixtech.com         →  empresaId: 'ztZblwm1w71wNQtzHV7S'
restaurante-pepito.com →  empresaId: 'OTRO_ID_EMPRESA'
peluqueria-ana.com    →  empresaId: 'OTRO_ID_EMPRESA_2'
```

Cada empresa gestiona **solo su contenido** desde su cuenta en la app.

---

## ❓ Preguntas frecuentes

**¿Y si tengo más de una sección que quiero controlar?**
Pega un script separado por cada sección, con su propio `seccionId` y `blockId` diferente.

**¿Puedo usarlo en tiendas online?**
Sí. Funciona en cualquier web con HTML accesible. Para WooCommerce/Shopify necesitarías adaptar el MAPA a los IDs de esos elementos.

**¿Qué pasa si cambio el diseño en Hostinger?**
Los IDs de los elementos pueden cambiar. Tendrías que actualizar el MAPA en el script y volver a hacer `Fluix.sincronizar()`.

**¿Necesito tocar Firebase directamente?**
No. Todo se gestiona desde la app. Firebase es solo el intermediario.

