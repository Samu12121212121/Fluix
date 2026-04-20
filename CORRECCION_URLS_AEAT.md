# ✅ Corrección URLs Sede AEAT

## 📋 Resumen

Se han corregido los enlaces a los procedimientos de presentación de modelos fiscales en la Sede Electrónica de la AEAT.

**Fecha:** 20 Abril 2026  
**Archivo modificado:** `lib/services/fiscal/sede_aeat_urls.dart`

---

## 🔗 URLs Corregidos

### Modelos Trimestrales

| Modelo | Descripción | URL Correcto |
|--------|-------------|--------------|
| **111** | Retenciones IRPF | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH01.shtml` |
| **115** | Retenciones arrendamientos | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH02.shtml` |
| **130** | Pago fraccionado IRPF autónomos | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G601.shtml` |
| **202** | Pago fraccionado IS sociedades | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GE00.shtml` |
| **303** | Autoliquidación IVA | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G414.shtml` |

### Modelos Anuales

| Modelo | Descripción | URL Correcto |
|--------|-------------|--------------|
| **190** | Resumen anual retenciones IRPF | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GI10.shtml` |
| **347** | Operaciones con terceros >3.005,06€ | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GI27.shtml` |
| **390** | Resumen anual IVA | `https://sede.agenciatributaria.gob.es/Sede/procedimientoini/G412.shtml` |

---

## ❌ URLs Antiguos (Incorrectos)

Los URLs antiguos usaban un patrón genérico que no funcionaba:

```dart
// ❌ ANTES (NO FUNCIONABAN)
static const _base = 'https://sede.agenciatributaria.gob.es/Sede/procedimientos-servicios/modelos-formularios/declaraciones';
static const mod111 = '$_base/modelo-111.html';
static const mod115 = '$_base/modelo-115.html';
// etc...
```

---

## ✅ URLs Nuevos (Correctos)

Cada modelo tiene su código de procedimiento específico:

```dart
// ✅ AHORA (URLs DIRECTOS A PROCEDIMIENTOS)
static const mod111 = 'https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH01.shtml';
static const mod115 = 'https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GH02.shtml';
// etc...
```

---

## 🔍 Verificación de Modelo 202

✅ **El modelo 202 YA EXISTE** y está completamente implementado:

### Archivos del Modelo 202

| Archivo | Ubicación | Estado |
|---------|-----------|--------|
| Modelo de datos | `lib/domain/modelos/modelo202.dart` | ✅ Existe |
| Pantalla | `lib/features/fiscal/pantallas/modelo202_screen.dart` | ✅ Existe |
| Calculadora | `lib/services/fiscal/mod202_calculator.dart` | ✅ Existe |
| Exportador | `lib/services/fiscal/mod202_exporter.dart` | ✅ Existe |

### Características del Modelo 202

- ✅ Cálculo automático según Art. 40 LIS
- ✅ 3 períodos: 1P (abril), 2P (octubre), 3P (diciembre)
- ✅ Modalidad A para pymes (18% de la base)
- ✅ Exportación a PDF
- ✅ Integración con widget `PresentarAeatWidget`
- ✅ Guardado de justificante AEAT

---

## 🧪 Cómo Probar

1. **Ir a la app Flutter**
2. **Acceder a:** Contabilidad → Modelos fiscales
3. **Seleccionar cualquier modelo** (111, 115, 130, 190, 202, 303, 347, 390)
4. **Clic en "Ir a Sede AEAT"**
5. **Verificar que abre la página correcta** del procedimiento específico

---

## 📝 Notas Técnicas

- Los nuevos URLs apuntan a `/procedimientoini/` que es la URL estable de la AEAT
- Cada modelo tiene su código de procedimiento único (GH01, GH02, G601, etc.)
- Los códigos de procedimiento son los oficiales de la Sede Electrónica
- No se requieren cambios en las pantallas, solo en `sede_aeat_urls.dart`

---

## ✅ Estado Final

| Componente | Estado |
|------------|--------|
| URLs Modelo 111 | ✅ Corregido |
| URLs Modelo 115 | ✅ Corregido |
| URLs Modelo 130 | ✅ Corregido |
| URLs Modelo 190 | ✅ Corregido |
| URLs Modelo 202 | ✅ Corregido |
| URLs Modelo 303 | ✅ Corregido |
| URLs Modelo 347 | ✅ Corregido |
| URLs Modelo 390 | ✅ Corregido |
| Lógica Modelo 202 | ✅ Ya existía |
| Sin errores de compilación | ✅ Verificado |

---

*Documentación generada: 20 Abril 2026 - Fluix CRM v1.0*

