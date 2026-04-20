# 🔗 URLs Oficiales Sede AEAT - Validación

## ✅ Estado de URLs (20 Abril 2026)

### Modelos Implementados en Fluix CRM

| Modelo | Descripción | Código Procedimiento | URL Completo | Estado |
|--------|-------------|---------------------|--------------|--------|
| 111 | Retenciones IRPF | GH01 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH01.shtml | ✅ Corregido |
| 115 | Retenciones arrendamientos | GH02 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH02.shtml | ✅ Corregido |
| 130 | Pago fraccionado IRPF autónomos | G601 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G601.shtml | ✅ Corregido |
| 190 | Resumen anual retenciones IRPF | GI10 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GI10.shtml | ✅ Corregido |
| 202 | Pago fraccionado IS sociedades | GE00 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GE00.shtml | ✅ Corregido |
| 303 | Autoliquidación IVA | G414 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G414.shtml | ✅ Corregido |
| 347 | Operaciones con terceros | GI27 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GI27.shtml | ✅ Corregido |
| 390 | Resumen anual IVA | G412 | https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G412.shtml | ✅ Corregido |
| 349 | Operaciones intracomunitarias | - | (pendiente) | ⚠️ Sin corregir |

---

## 📋 Mapeo Modelo → Código Procedimiento

```
111 → GH01.shtml
115 → GH02.shtml
130 → G601.shtml
190 → GI10.shtml
202 → GE00.shtml
303 → G414.shtml
347 → GI27.shtml
390 → G412.shtml
```

---

## 🧪 Validación Manual

Para validar que un URL funciona correctamente:

1. **Abrir el URL en un navegador**
2. **Verificar que carga la página de presentación del modelo**
3. **Confirmar que aparece:**
   - Título del modelo correcto
   - Formulario de presentación
   - Opción para certificado digital / Cl@ve PIN

### Ejemplo de Validación (Modelo 111)

```
URL: https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH01.shtml

✅ Debería mostrar:
- Título: "Modelo 111 - Retenciones e ingresos a cuenta..."
- Formulario de presentación
- Botón "Presentación"
```

---

## 🔄 Flujo de Presentación en Fluix

1. **Usuario calcula el modelo** en Fluix CRM
2. **Fluix genera PDF borrador** con los datos calculados
3. **Usuario hace clic en "Ir a Sede AEAT"**
4. **Se abre el navegador** con el URL correcto del procedimiento
5. **Usuario introduce datos** del borrador en el formulario oficial
6. **Usuario firma y envía** con certificado digital
7. **Usuario copia nº justificante** de vuelta a Fluix

---

## 📦 Archivo de Configuración

**Ubicación:** `lib/services/fiscal/sede_aeat_urls.dart`

**Uso en código:**

```dart
import 'package:planeag_flutter/services/fiscal/sede_aeat_urls.dart';

// Abrir Sede AEAT para Modelo 303
SedeAeatUrls.abrir(SedeAeatUrls.mod303);

// En PresentarAeatWidget
PresentarAeatWidget(
  modelo: '303',
  urlAeat: SedeAeatUrls.mod303,
  // ...
)
```

---

## 🎯 Pantallas que Usan los URLs

| Pantalla | Modelo | Constante Usada |
|----------|--------|----------------|
| `modelo111_screen.dart` | 111 | `SedeAeatUrls.mod111` |
| `modelo115_screen.dart` | 115 | `SedeAeatUrls.mod115` |
| `modelo130_screen.dart` | 130 | `SedeAeatUrls.mod130` |
| `modelo190_screen.dart` | 190 | `SedeAeatUrls.mod190` |
| `modelo202_screen.dart` | 202 | `SedeAeatUrls.mod202` |
| `modelo303_screen.dart` | 303 | `SedeAeatUrls.mod303` |
| `modelo347_screen.dart` | 347 | `SedeAeatUrls.mod347` |
| `modelo390_screen.dart` | 390 | `SedeAeatUrls.mod390` |

---

## ⚠️ Notas Importantes

### Variable `_base` No Utilizada

La constante `_base` en el archivo `sede_aeat_urls.dart` ya **NO se usa** para los modelos principales, ya que cada uno tiene su URL específico.

Solo se mantiene para el modelo 349 que aún no ha sido corregido.

### Modelo 349

El modelo 349 todavía usa el patrón antiguo:

```dart
static const mod349 = '$_base/modelo-349.html';
```

**TODO:** Averiguar el código de procedimiento correcto para el modelo 349.

---

## 📚 Referencias Oficiales

- **Sede Electrónica AEAT:** https://sede.agenciatributaria.gob.es
- **Listado de procedimientos:** https://sede.agenciatributaria.gob.es/Sede/procedimientoini/
- **Modelos y formularios:** https://sede.agenciatributaria.gob.es/Sede/procedimientos-servicios/modelos-formularios

---

## ✅ Checklist de Corrección

- [x] Modelo 111 - URL corregido a GH01.shtml
- [x] Modelo 115 - URL corregido a GH02.shtml
- [x] Modelo 130 - URL corregido a G601.shtml
- [x] Modelo 190 - URL corregido a GI10.shtml
- [x] Modelo 202 - URL corregido a GE00.shtml
- [x] Modelo 303 - URL corregido a G414.shtml
- [x] Modelo 347 - URL corregido a GI27.shtml
- [x] Modelo 390 - URL corregido a G412.shtml
- [x] Verificación sin errores de compilación
- [x] Documentación actualizada
- [ ] Modelo 349 - Pendiente de corrección

---

*Validación generada: 20 Abril 2026 - Fluix CRM v1.0*

