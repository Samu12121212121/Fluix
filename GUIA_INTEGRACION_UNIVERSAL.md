# 🌍 CÓMO INTEGRAR EN 100 WEBS DISTINTAS (Fácil y Rápido)

Tienes dos opciones para integrar Fluix CMS en las webs de tus clientes, dependiendo de si quieres **Incrustar Bloques** (recomendado) o **Sincronizar Diseño Existente**.

## OPCIÓN A: Incrustar Bloques (La más fácil y rápida) 🚀
Ideal para: Webs nuevas, o secciones que construyes desde cero con Fluix.
**Funciona igual en TODAS las webs.**

1. Pegas el Script Universal una vez (final del body).
2. Donde quieras que aparezca el contenido, pegas un `div` con el ID de la sección.

**Ejemplo:**
El cliente "Restaurante Pepe" quiere su carta y sus reservas.
```html
<!-- Donde quieras la carta: -->
<div id="fluixcrm_carta"></div>

<!-- Donde quieras un formulario de reservas: -->
<div id="fluixcrm_reservas"></div>

<!-- Al final de la página (una sola vez): -->
<script src="https://tu-dominio.com/js/fluix.js" data-id="ID_EMPRESA_PEPE"></script>
```
*Fluix se encarga de crear el diseño (lista, fotos, precios).*

---

## OPCIÓN B: Sincronización "Quirúrgica" (Diseños a medida) 🎨
Ideal para: Webs que ya existen y tienen un diseño super específico que NO quieres cambiar, solo quieres que cambie el precio o texto.

Usa el atributo `data-connect="SECCION:ITEM:CAMPO"`.

**Ejemplo:**
Tienes un diseño super loco con la "Paella Especial" en un banner gigante.
```html
<div class="mi-super-banner">
  <!-- Conectas el título -->
  <h1 data-connect="carta:paella_valenciana:nombre">Paella Especial</h1>

  <!-- Conectas la imagen de fondo o img -->
  <img src="foto-default.jpg" data-connect="carta:paella_valenciana:imagen">

  <!-- Conectas el precio -->
  <div class="precio-burbuja" data-connect="carta:paella_valenciana:precio">15€</div>
</div>

<script src="https://tu-dominio.com/js/fluix.js" data-id="ID_EMPRESA_PEPE"></script>
```

---

## RESUMEN PARA TUS 100 WEBS

1.  Usa siempre el **mismo archivo JS** (`fluix.js`) alojado en tu servidor.
2.  En cada web, cambias el `data-id="..."` por el ID del cliente.
3.  Si quieres ir rápido: Pega los `<div id="fluixcrm_...">`.
4.  Si quieres diseño a medida: Peta los atributos `data-connect="..."`.

¡No necesitas programar nada más!

