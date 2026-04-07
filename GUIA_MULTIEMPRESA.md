# 🌎 GUÍA MULTIEMPRESA (100+ CLIENTES)

Ahora que tienes muchas webs, **NO** necesitas crear ni pegar un script de 300 líneas para cada una.

## CÓMO FUNCIONA AHORA (Solución Profesional)

1.  Subes el archivo `fluix_script_universal.js` **una sola vez** a un servidor (tu propio Hosting, GitHub Pages, o Firebase Hosting).
2.  En la web de tus clientes, SOLO pegas **una línea** cambiando su ID.

---

## PASO 1: Alojar el Script Maestro

Si no tienes dónde alojar el archivo `.js`, puedes usar Firebase Hosting (que ya tienes configurado).
O simplemente, si todavía trabajas en local, usa la solución manual de abajo.

Supongamos que subes el archivo a: `https://tu-dominio.com/js/fluix.js`

---

## PASO 2: Qué pegar en la web del cliente

En Hostinger/WordPress de CADA cliente, solo pegas esto:

### Cliente 1 (Restaurante Pepe)
```html
<script src="https://tu-dominio.com/js/fluix.js" data-id="ID_EMPRESA_PEPE"></script>
<div id="fluixcrm_reservas"></div>
```

### Cliente 2 (Bar Manolo)
```html
<script src="https://tu-dominio.com/js/fluix.js" data-id="ID_EMPRESA_MANOLO"></script>
<div id="fluixcrm_reservas"></div>
```

¡Y listo! Todas usarán el mismo código. Si mejoras el código, se actualizan las 100 webs a la vez.

---

## ⚠️ NOTA IMPORTANTE SOBRE HOSTINGER

Si tus 100 webs son **CLONES** (usan la misma plantilla de Hostinger donde la paella siempre es el ID `ai-7JVlSQ`), entonces el script funcionará perfecto.

Si cada web es **DIFERENTE** (diseño distinto), entonces la función de "Sincronizar Carta por IDs" (`ai-7JVlSQ`) **NO** funcionará, porque esos IDs cambian.

Para webs diferentes, usa las **Secciones Dinámicas**:
1. Crea la sección "Vinos" en la App.
2. Pega `<div id="fluixcrm_vinos"></div>` en la web del cliente.
3. El contenido aparecerá ahí mágicamente (sin depender de la plantilla de Hostinger).

---

## RESUMEN

- **¿100 Scripts manuales?** ❌ NO.
- **¿100 Líneas de integración?** ✅ SÍ (solo cambiando el ID).

