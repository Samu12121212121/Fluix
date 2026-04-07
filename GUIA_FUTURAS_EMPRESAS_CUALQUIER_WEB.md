# 📱 GUÍA PARA FUTURAS EMPRESAS - CUALQUIER TIPO DE WEB

## ✅ El script funciona con:
- ✅ WordPress
- ✅ Sitios HTML estáticos
- ✅ React, Vue, Angular
- ✅ Shopify, Wix
- ✅ Cualquier web moderna

---

## 🚀 PARA CUALQUIER EMPRESA NUEVA

### PASO 1: Obtén el ID de la empresa
```
En Firebase Console → Firestore → empresas → [TU_ID]
```

### PASO 2: Usa tu ID real
**NUNCA uses:**
- `ztZblwm1w71wNQtzHV7S` (es de otra empresa)

**SIEMPRE usa:**
- Tu ID de empresa real (desde Firestore)

### PASO 3: Copia el script con tu ID
```html
<!-- Reemplaza TU_ID_AQUI con tu ID real -->
const EMPRESA_ID = "TU_ID_AQUI"; ← REEMPLAZA ESTO

<!-- El resto del script es igual para todas las webs -->
```

### PASO 4: Pega en tu web
**Para WordPress:**
- Apariencia → Editor de temas → footer.php → antes de `</body>`

**Para HTML estático:**
- Abre tu archivo HTML
- Busca `</body>`
- Pega ANTES de `</body>`

**Para React/Vue/Angular:**
- En `public/index.html` antes de `</body>`

**Para Shopify/Wix:**
- Configuración → Código personalizado → antes de `</body>`

---

## 📊 DATOS QUE SE REGISTRAN (igual en todas las webs)

✅ Visitas web (total, por mes, por día)
✅ Páginas vistas
✅ Referrers (de dónde vienen)
✅ Llamadas telefónicas (si hay links `tel:`)
✅ Formularios de contacto (si hay formularios)
✅ Clicks en WhatsApp (si hay links de WhatsApp)

---

## 🔧 PERSONALIZACIÓN POR WEB

El script es el MISMO para todas, solo cambia:
```javascript
const EMPRESA_ID = "TU_ID_AQUI";      // ID de la empresa
const DOMINIO_WEB = "tudominio.com";  // Tu dominio
const NOMBRE_EMPRESA = "Tu Nombre";   // Tu nombre
```

Todo lo demás es igual.

---

## 📱 ALTERNATIVA: URL DINÁMICA

Si quieres que el script se genere automáticamente:

```
https://europe-west1-planeaapp-4bea4.cloudfunctions.net/generarScriptEmpresa?empresaId=TU_ID
```

Devuelve el script personalizado. Útil para:
- Clientes que crean su propia cuenta
- Sistemas que crean múltiples empresas
- Automatización

---

## ✨ RESUMEN

| Elemento | Todos igual | Personalizado |
|----------|------------|--------------|
| Script estructura | ✅ Sí | - |
| Lógica rastreo | ✅ Sí | - |
| EMPRESA_ID | - | ✅ Diferente |
| DOMINIO | - | ✅ Diferente |
| NOMBRE | - | ✅ Diferente |

---

**Resultado:** Cada empresa recibe su script único pero basado en el mismo código. 🚀

