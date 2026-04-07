# 🔥 FLUIX SCRIPT UNIVERSAL — Guía completa

> **Archivo del script:** `web/fluix_script_universal.js`  
> **Versión:** 2.0 | Stack: Firebase Firestore + Vanilla JS  

---

## 🧠 Cómo funciona el sistema (visión global)

```
┌─────────────────────────────────────────────────────────┐
│  TÚ construyes la web (Hostinger, WordPress, HTML...)   │
│  Marcas los elementos editables con data-fluix="..."    │
│  Incluyes el script con data-empresa="ID_EMPRESA"       │
└────────────────────────┬────────────────────────────────┘
                         │ Fluix.sincronizar() — 1ª vez
                         ▼
┌─────────────────────────────────────────────────────────┐
│  FIRESTORE                                              │
│  empresas/{empresaId}/contenido_web/{seccionId}         │
│   ├── carta         → { tipo, items_carta: [...] }      │
│   ├── horarios      → { tipo, horarios: [...] }         │
│   ├── ofertas       → { tipo, ofertas: [...] }          │
│   └── texto_inicio  → { tipo, titulo, texto }           │
└──────────┬──────────────────────┬───────────────────────┘
           │ onSnapshot           │ onSnapshot
           ▼                      ▼
┌──────────────────┐   ┌──────────────────────────────────┐
│   WEB del        │   │   APP del empresario             │
│   cliente        │   │   ModuloContenidoWebSimplificado  │
│   (tiempo real)  │   │   → lista secciones editables    │
└──────────────────┘   └──────────────────────────────────┘
```

**El empresario edita en la app → Firebase se actualiza → la web cambia en segundos.**  
**Tú no vuelves a tocar la web nunca más.**

---

## 📋 Flujo de trabajo por empresa (paso a paso)

### PASO 1 — Hablas con el cliente
Preguntas qué quiere poder cambiar:
- *"¿Quieres editar los precios de la carta?"* → sección tipo `carta`
- *"¿Quieres poder actualizar los horarios?"* → sección tipo `horarios`
- *"¿Quieres subir ofertas?"* → sección tipo `ofertas`
- *"¿Quieres un formulario de reservas?"* → módulo `fluixcrm_reservas`
- *"¿Quieres recibir mensajes de contacto?"* → módulo `fluixcrm_contacto`

---

### PASO 2 — Marcas los elementos en el HTML

Sobre cada elemento que el cliente quiera editar, añades el atributo `data-fluix`:

```
data-fluix="SECCION_ID/ITEM_ID/CAMPO"
```

| Parte | Qué es | Ejemplo |
|---|---|---|
| `SECCION_ID` | Nombre del bloque de contenido | `carta`, `horarios`, `ofertas` |
| `ITEM_ID` | Nombre del elemento concreto | `paella_mixta`, `lunes`, `oferta_verano` |
| `CAMPO` | Qué dato es | `nombre`, `precio`, `descripcion`, `apertura`, `cierre` |

#### Ejemplos reales:

```html
<!-- CARTA DE RESTAURANTE -->
<strong data-fluix="carta/paella_mixta/nombre">Paella Mixta</strong>
<span   data-fluix="carta/paella_mixta/precio">15€</span>
<p      data-fluix="carta/paella_mixta/descripcion">Arroz con mariscos...</p>

<strong data-fluix="carta/croquetas/nombre">Croquetas Caseras</strong>
<span   data-fluix="carta/croquetas/precio">7€</span>
<p      data-fluix="carta/croquetas/descripcion">Con jamón ibérico...</p>

<!-- HORARIOS -->
<span data-fluix="horarios/lunes/apertura">09:00</span>
<span data-fluix="horarios/lunes/cierre">22:00</span>
<span data-fluix="horarios/domingo/apertura">Cerrado</span>

<!-- TEXTO / ANUNCIO -->
<h2 data-fluix="anuncio/principal/titulo">¡Abrimos en agosto!</h2>
<p  data-fluix="anuncio/principal/texto">Reserva ya tu mesa...</p>

<!-- OFERTAS -->
<h3   data-fluix="ofertas/menu_dia/titulo">Menú del día</h3>
<p    data-fluix="ofertas/menu_dia/descripcion">Primer plato, segundo y postre</p>
<span data-fluix="ofertas/menu_dia/precio">12.50€</span>

<!-- IMAGEN (en tag img directamente) -->
<img data-fluix="carta/paella_mixta/imagen" src="paella.jpg" alt="Paella">
```

#### Módulos fijos (siempre mismo nombre de div):

```html
<!-- Formulario de reservas — se rellena automáticamente -->
<div id="fluixcrm_reservas"></div>

<!-- Formulario de contacto — se rellena automáticamente -->
<div id="fluixcrm_contacto"></div>

<!-- Blog / noticias — se rellena automáticamente -->
<div id="fluixcrm_blog"></div>
```

---

### PASO 3 — Incluyes el script en la web

```html
<!-- Antes del </body> — solo 1 línea, el ID cambia por empresa -->
<script src="https://TU-HOSTING.com/fluix_script_universal.js"
        data-empresa="ID_DE_ESTA_EMPRESA">
</script>
```

> **El ID de empresa** lo encuentras en Firestore: `empresas/{este_id}`.  
> También en la app en Ajustes → Información de empresa.

---

### PASO 4 — Primera sincronización (una sola vez)

Abres la web del cliente en el navegador → `F12` → Consola:

```javascript
// Primero verifica que todo está bien detectado:
Fluix.escanear()

// Si todo OK, sube la estructura a Firebase:
Fluix.sincronizar()
```

Output esperado:
```
══════ CAMPOS DETECTADOS EN EL HTML ══════
📁 carta (tipo: carta)
   └─ paella_mixta: { id: 'paella_mixta', nombre: 'Paella Mixta', precio: 15, ... }
   └─ croquetas: { ... }
📁 horarios (tipo: horarios)
📁 anuncio (tipo: texto)
Total: 3 secciones
Listo para sincronizar → Fluix.sincronizar()
══════════════════════════════════════════

  ✅ carta (carta, 2 items)
  ✅ horarios (horarios, 7 items)
  ✅ anuncio (texto, 1 items)
🚀 Sincronización completa. El empresario ya puede editar desde la app.
```

---

### PASO 5 — El empresario edita desde la app

Abre la app → módulo **Contenido Web** → ve exactamente las secciones que tú creaste:

```
┌─────────────────────────────────┐
│ 🍽️  Carta              ✅ ON  │  ← toca → edita platos y precios
│ ⏰  Horarios           ✅ ON  │  ← toca → edita apertura/cierre
│ 📢  Anuncio principal  ✅ ON  │  ← toca → edita título y texto
└─────────────────────────────────┘
  Solo puede editar el contenido.
  No puede crear ni borrar secciones.
```

Cada vez que guarda un cambio → **la web se actualiza en 1-2 segundos** sin recargar.

---

## 🗂️ Tipos de sección disponibles

| Tipo | `SECCION_ID` recomendado | Campos que acepta | Lo que ve en la app |
|---|---|---|---|
| **Carta / Menú** | `carta`, `menu`, `bebidas`, `vinos` | `nombre`, `precio`, `descripcion`, `imagen` | Lista de platos editables |
| **Horarios** | `horarios` | `apertura`, `cierre`, `cerrado` | Tabla días/horas |
| **Texto / Anuncio** | `anuncio`, `bienvenida`, `sobre_nosotros` | `titulo`, `texto`, `imagen_url` | Campo de texto libre |
| **Ofertas** | `ofertas`, `promociones` | `titulo`, `descripcion`, `precio`, `precio_original`, `imagen` | Lista de ofertas on/off |
| **Galería** | Se gestiona desde app, no requiere `data-fluix` | Se sube desde app | Subida de imágenes |

> **El tipo se infiere automáticamente** por el nombre de la sección. Si el nombre contiene `carta/menu/plato/producto/bebida/vino` → tipo carta. Si contiene `horario/hora` → tipo horarios. Etc.  
> Si el nombre no encaja, puedes forzarlo añadiendo `data-fluix-tipo="carta"` al contenedor del bloque.

---

## ⚙️ Referencia rápida del script

### Comandos de consola

```javascript
Fluix.sincronizar()   // Sube la estructura del HTML a Firebase (solo 1ª vez)
Fluix.escanear()      // Muestra qué campos detecta (sin subir nada)
Fluix.debug()         // Estado de conexión + resumen de campos
```

### Atributos HTML que usa el script

| Atributo | Dónde | Para qué |
|---|---|---|
| `data-empresa="ID"` | En el `<script>` | Identificar la empresa en Firebase |
| `data-fluix="sec/item/campo"` | En elementos editables | Vincular elemento ↔ dato de Firebase |
| `id="fluixcrm_reservas"` | En un `<div>` | Inyectar formulario de reservas |
| `id="fluixcrm_contacto"` | En un `<div>` | Inyectar formulario de contacto |
| `id="fluixcrm_blog"` | En un `<div>` | Inyectar listado de noticias |
| `id="fluixcrm_XXX"` | En un `<div>` | Render dinámico de sección XXX |

---

## 🌐 Dónde hospedar el script

Sube `fluix_script_universal.js` a **un solo sitio** y todos los clientes apuntan a él:

| Opción | URL resultante | Coste |
|---|---|---|
| Firebase Hosting | `https://planeaapp-4bea4.web.app/fluix.js` | Gratis |
| Tu Hostinger | `https://fluixtech.es/fluix.js` | Incluido en hosting |
| GitHub Pages | `https://tu-usuario.github.io/fluix/fluix.js` | Gratis |

**Ventaja**: Si actualizas el script (nueva funcionalidad, bug fix), **se actualiza en todas las webs de todos tus clientes automáticamente**.

---

## 🏪 Plantilla mínima de HTML para cliente nuevo

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nombre del Negocio</title>
</head>
<body>

  <!-- ═══ AQUÍ VA EL DISEÑO DEL CLIENTE ═══ -->
  <!-- Los elementos editables llevan data-fluix -->

  <h1 data-fluix="inicio/principal/titulo">Bienvenidos</h1>
  <p  data-fluix="inicio/principal/texto">Descripción del negocio</p>

  <!-- Formularios fijos -->
  <div id="fluixcrm_reservas"></div>
  <div id="fluixcrm_contacto"></div>

  <!-- ════════════════════════════════════ -->

  <!-- Script Fluix — cambia solo el data-empresa -->
  <script src="https://fluixtech.es/fluix.js"
          data-empresa="EMPRESA_ID_AQUI">
  </script>

</body>
</html>
```

---

## 🤖 Guía de implementación para IA

> Usa esta sección cuando pases un HTML a una IA para que añada los `data-fluix`.  
> Copia el bloque de instrucciones y pégalo antes del HTML.

---

### 📋 PROMPT PARA IA — AÑADIR data-fluix A UN HTML

```
Eres un asistente que integra el sistema Fluix CRM en webs.
Tu tarea es añadir atributos data-fluix a los elementos HTML que el cliente quiera
poder editar dinámicamente desde una app móvil.

REGLAS:
1. El atributo se añade directamente en el elemento que contiene el texto/precio/imagen.
2. Formato: data-fluix="SECCION_ID/ITEM_ID/CAMPO"
   - SECCION_ID: nombre del bloque (carta, horarios, ofertas, anuncio, etc.)
   - ITEM_ID: identificador del elemento concreto, en snake_case, sin espacios ni tildes
   - CAMPO: tipo de dato → nombre | precio | descripcion | apertura | cierre | titulo | texto | imagen
3. Reglas de naming:
   - Usa minúsculas y guiones bajos: paella_mixta, menu_dia, lunes
   - No uses tildes ni caracteres especiales en los IDs
   - El SECCION_ID debe ser descriptivo y único en la página
4. Imágenes: añade data-fluix en el <img> directamente con campo "imagen"
5. Precios: añade en el elemento que muestra el número (strong, span, h6)
6. NO modifiques el CSS ni la estructura HTML. Solo añade el atributo.
7. NO toques elementos decorativos, iconos, o clases del builder.
8. Al final del <body>, añade este script:
   <script src="https://fluixtech.es/fluix.js" data-empresa="EMPRESA_ID_PENDIENTE"></script>
9. Si hay un bloque de reservas o contacto, añade el div correspondiente:
   <div id="fluixcrm_reservas"></div>
   <div id="fluixcrm_contacto"></div>

CAMPOS DISPONIBLES:
- Plato/producto: nombre | precio | descripcion | imagen
- Horario: apertura | cierre (el ITEM_ID es el día: lunes, martes... en minúsculas)
- Texto: titulo | texto | imagen
- Oferta: titulo | descripcion | precio | precio_original | imagen

El cliente quiere editar: [DESCRIBE AQUÍ LO QUE EL CLIENTE QUIERE EDITAR]

HTML a modificar:
[PEGA AQUÍ EL HTML]
```

---

### Ejemplo de uso con el prompt:

```
El cliente quiere editar: los precios y nombres de la carta (paella, croquetas, gazpacho),
los horarios de lunes a domingo, y el texto de bienvenida de la página principal.

HTML a modificar:
[pegar el HTML del Hostinger aquí]
```

La IA devolverá el HTML con todos los `data-fluix` en su sitio.  
Tú solo necesitas:
1. Subir el HTML modificado al Hostinger del cliente
2. Cambiar `EMPRESA_ID_PENDIENTE` por el ID real de Firestore
3. Abrir la web → consola → `Fluix.sincronizar()`

---

## ❓ Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| La web no se actualiza | Firebase no conectado | `Fluix.debug()` en consola |
| `Fluix is not defined` | El script no cargó | Verifica la URL del script en el `<script src>` |
| `data-empresa requerido` | Falta el atributo | `<script src="..." data-empresa="ID">` |
| `Fluix.escanear()` devuelve 0 campos | No hay `data-fluix` en el HTML | Verifica que añadiste los atributos |
| El empresario no ve las secciones en la app | `sincronizar()` no se ejecutó | Abre la web → F12 → `Fluix.sincronizar()` |
| Los precios se muestran como "NaN€" | El texto del precio tiene formato raro | Verificar que el elemento tiene solo el número (ej: `15€` o `15`) |
| La sección aparece y desaparece | `activa: false` en Firestore | El empresario la desactivó en la app |
| Las imágenes no se actualizan | URL de Storage no pública | Verificar reglas de Firebase Storage |

---

## 📁 Estructura en Firestore que crea el script

```
empresas/
  {empresaId}/
    contenido_web/
      carta/
        tipo: "carta"
        nombre: "Carta"
        activa: true
        orden: 0
        contenido:
          titulo: "Carta"
          items_carta: [
            { id: "paella_mixta", nombre: "Paella Mixta", precio: 15,
              descripcion: "...", imagen_url: "", disponible: true },
            { id: "croquetas", ... }
          ]
      horarios/
        tipo: "horarios"
        contenido:
          horarios: [
            { dia: "Lunes", apertura: "09:00", cierre: "22:00", cerrado: false },
            ...
          ]
      anuncio/
        tipo: "texto"
        contenido:
          titulo: "Bienvenidos"
          texto: "..."
          imagen_url: ""
    reservas/          ← Las crea el formulario de reservas
    contacto_web/      ← Las crea el formulario de contacto
    blog/              ← Las gestiona el empresario desde la app
    estadisticas/      ← Visitas registradas automáticamente
```

---

## 🔄 Workflow completo resumido

```
1. Cliente te dice qué quiere editar
         ↓
2. Pasas el HTML a la IA con el prompt de esta guía
         ↓
3. IA devuelve el HTML con data-fluix añadidos
         ↓
4. Subes el HTML al Hostinger del cliente
         ↓
5. Añades el <script> con data-empresa="ID_REAL"
         ↓
6. Abres la web → F12 → Fluix.sincronizar()
         ↓
7. El cliente ya puede editar desde la app
         ↓
8. Cada cambio del cliente → web actualizada en tiempo real
         ↓
9. TÚ no vuelves a tocar esa web nunca más ✅
```

---

*Generado para Fluix CRM | fluixtech.es*

