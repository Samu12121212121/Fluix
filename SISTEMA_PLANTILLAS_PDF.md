# 🎨 Sistema de Plantillas PDF - Documentación Completa

## ✅ **LO QUE YA ESTÁ HECHO**

### **1. Arquitectura Completa Implementada**

```
lib/
├── services/
│   ├── pdf/
│   │   ├── pdf_template_service.dart     ✅ Servicio Firestore
│   │   ├── pdf_renderer.dart             ✅ Motor de renderizado
│   │   ├── pdf_block_registry.dart       ✅ Registro de bloques
│   │   └── blocks/
│   │       ├── pdf_block_builder.dart    ✅ Clase base
│   │       ├── header_block_builder.dart ✅ Cabecera
│   │       ├── client_block_builder.dart ✅ Datos cliente
│   │       ├── table_block_builder.dart  ✅ Tabla de líneas
│   │       ├── totals_block_builder.dart ✅ Totales
│   │       ├── qr_block_builder.dart     ✅ QR Verifactu
│   │       ├── text_block_builder.dart   ✅ Texto dinámico
│   │       └── stamp_block_builder.dart  ✅ Sellos (PAGADA, etc.)
│   └── pdf_service.dart                  ✅ Integración híbrida
│
├── domain/modelos/
│   └── pdf_template.dart                 ✅ 15+ modelos completos
│
└── features/
    └── pdf_editor/pantallas/
        └── pdf_templates_list_screen.dart ✅ Pantalla de gestión

Integración:
├── pantalla_dashboard.dart               ✅ Módulo agregado
└── scripts/
    └── agregar_modulo_plantillas_pdf.js  ✅ Script Firestore
```

---

## 🚀 **CÓMO ACTIVAR EL MÓDULO**

### **Opción A: Script Automático (Recomendado)**

```bash
cd scripts
node agregar_modulo_plantillas_pdf.js
```

Esto agregará el módulo a TODAS las empresas en Firestore.

### **Opción B: Manual en Firestore Console**

```javascript
// Ruta: empresas/{empresaId}/modulos/plantillas_pdf
{
  "id": "plantillas_pdf",
  "nombre": "Plantillas PDF",
  "icono": "article",
  "activo": true,        // ⚠️ IMPORTANTE: true para activar
  "orden": 100,
  "descripcion": "Personaliza el diseño de tus documentos PDF",
  "categoria": "facturacion",
  "rolesPermitidos": ["admin", "propietario"],
  "requiereSuscripcion": false
}
```

---

## 📱 **CÓMO FUNCIONA**

### **1. Creación de Plantillas**

```dart
// En Firestore: empresas/{empresaId}/pdf_templates/{templateId}
{
  "type": "factura",
  "name": "Plantilla Corporativa 2026",
  "version": 1,
  "is_active": true,       // ⚠️ Solo UNA plantilla activa por tipo
  "is_default": false,
  "page": {
    "format": "A4",
    "orientation": "portrait",
    "margins": {
      "top": 36,
      "right": 36,
      "bottom": 36,
      "left": 36
    }
  },
  "blocks": [
    {
      "id": "header_1",
      "type": "header",
      "order": 1,
      "visible": true,
      "props": {
        "title": "FACTURA",
        "title_size": 28,
        "title_bold": true,
        "title_color": "#1565C0",
        "show_logo": true,
        "show_company_data": true
      }
    },
    {
      "id": "client_1",
      "type": "client",
      "order": 2,
      "visible": true,
      "props": {
        "title": "FACTURAR A:",
        "show_name": true,
        "show_nif": true,
        "show_direccion": true
      }
    }
    // ... más bloques
  ]
}
```

### **2. Generación Automática de PDFs**

```dart
// El sistema es BACKWARD COMPATIBLE:
// ✅ Si existe plantilla personalizada → usa plantilla
// ✅ Si NO existe → usa diseño legacy (actual)

final bytes = await PdfService.generarFacturaPdfDinamico(
  factura,
  empresaId,
);
// ☝️ Automático, sin cambios en tu código existente
```

### **3. UI de Gestión**

```dart
// Ya está integrado en el dashboard:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PdfTemplatesListScreen(empresaId: empresaId),
  ),
);
```

---

## 🏗️ **TIPOS DE BLOQUES DISPONIBLES**

| Bloque | Descripción | Props Principales |
|--------|-------------|-------------------|
| **header** | Cabecera con logo, fecha, nº factura | `title`, `title_size`, `title_color`, `show_logo` |
| **client** | Datos del cliente facturado | `show_name`, `show_nif`, `show_direccion` |
| **table** | Tabla de líneas de factura | `show_column_iva`, `show_column_total` |
| **totals** | Bloque de totales (subtotal, IVA, total) | `show_subtotal`, `show_iva`, `highlight_total` |
| **qr** | QR Verifactu | `size`, `position`, `visible_if` |
| **text** | Texto libre con plantillas | `content_template`, `visible_if` |
| **stamp** | Sellos de estado (PAGADA) | `text`, `color`, `rotation_angle` |

---

## 🎯 **EJEMPLOS DE USO**

### **Ejemplo 1: Plantilla Minimalista**

```json
{
  "name": "Minimalista Azul",
  "blocks": [
    {
      "type": "header",
      "props": {
        "title": "Factura",
        "title_size": 24,
        "title_color": "#2196F3",
        "show_logo": false
      }
    },
    {
      "type": "table",
      "props": {
        "header_color": "#E3F2FD",
        "alternate_rows": true
      }
    }
  ]
}
```

### **Ejemplo 2: Plantilla Corporativa**

```json
{
  "name": "Corporativa Premium",
  "blocks": [
    {
      "type": "header",
      "props": {
        "title": "FACTURA OFICIAL",
        "title_size": 32,
        "title_bold": true,
        "show_logo": true,
        "logo_size": 80
      }
    },
    {
      "type": "client",
      "props": {
        "background_color": "#F5F9FF",
        "border_color": "#1565C0",
        "border_radius": 8
      }
    },
    {
      "type": "stamp",
      "props": {
        "text": "VERIFICADA",
        "color": "#2E7D32",
        "rotation_angle": -15,
        "visible_if": "factura.estado == 'pagada'"
      }
    }
  ]
}
```

### **Ejemplo 3: Texto Dinámico**

```json
{
  "type": "text",
  "props": {
    "content_template": "Gracias por confiar en {empresa_nombre}. Plazo de pago: {factura.fechaPago}",
    "content_size": 9,
    "content_color": "#757575"
  }
}
```

---

## 🔧 **MIGRACIÓN DE PDFs LEGACY**

### **Paso 1: Crear Plantilla Equivalente**

La plantilla por defecto ya replica el diseño legacy actual:

```javascript
// Firestore: empresas/{empresaId}/pdf_templates/default_factura
const defaultTemplate = {
  type: "factura",
  name: "Plantilla por Defecto",
  is_active: true,
  is_default: true,
  page: { format: "A4", orientation: "portrait" },
  blocks: [
    { type: "header", order: 1, props: { /* idéntico al actual */ } },
    { type: "client", order: 2, props: { /* idéntico al actual */ } },
    { type: "table", order: 3, props: { /* idéntico al actual */ } },
    { type: "totals", order: 4, props: { /* idéntico al actual */ } },
    { type: "qr", order: 5, props: { /* idéntico al actual */ } }
  ]
};
```

### **Paso 2: Activar Generación Dinámica**

```dart
// ¡YA ESTÁ HECHO! El cambio es transparente:

// ANTES (legacy - sigue funcionando):
final bytes = await PdfService.generarFacturaPdfConDatos(factura, empresaId);

// AHORA (dinámico - detección automática):
// Si existe plantilla → usa plantilla
// Si NO existe → usa legacy (backward compatible)
```

### **Paso 3: Testing A/B**

```dart
// Probar plantilla sin activarla:
final template = await PdfTemplateService().getTemplate(
  empresaId: empresaId,
  templateId: 'test_template_123',
);

final bytes = await PdfRenderer().render(
  template: template,
  // ... resto de parámetros
);
```

---

## 🎨 **PERSONALIZACIÓN AVANZADA**

### **Colores de Marca**

```json
{
  "styles": {
    "brand_colors": {
      "primary": "#1565C0",
      "secondary": "#7B1FA2",
      "accent": "#2E7D32",
      "text": "#212121",
      "background": "#FFFFFF"
    }
  }
}
```

### **Tipografía**

```json
{
  "styles": {
    "typography": {
      "heading_size": 24,
      "body_size": 10,
      "small_size": 8,
      "line_height": 1.5
    }
  }
}
```

### **Condicionales**

```javascript
// Mostrar bloque solo si está pagada:
{
  "type": "stamp",
  "props": {
    "visible_if": "factura.estado == 'pagada'",
    "text": "PAGADA"
  }
}

// Mostrar QR solo si tiene Verifactu:
{
  "type": "qr",
  "props": {
    "visible_if": "factura.verifactu != null"
  }
}
```

---

## 📊 **ESTRUCTURA DE DATOS COMPLETA**

### **PdfTemplate**
```dart
class PdfTemplate {
  String id;
  PdfDocumentType type;      // factura, presupuesto, fichaje...
  String name;
  int version;
  bool isActive;             // ⚠️ Solo UNA activa por tipo
  bool isDefault;
  PdfPageConfig page;
  PdfStyles styles;
  List<PdfBlock> blocks;     // Lista de bloques ordenados
  PdfTemplateMetadata metadata;
}
```

### **PdfBlock**
```dart
class PdfBlock {
  String id;
  PdfBlockType type;
  int order;                 // Orden de renderizado
  bool visible;
  Map<String, dynamic> props; // Props específicos del bloque
}
```

### **Tipos de Documento Soportados**

```dart
enum PdfDocumentType {
  factura,          // ✅ Implementado
  rectificativa,    // ✅ Implementado
  presupuesto,      // ⏳ Próximamente
  fichaje,          // ⏳ Próximamente
  nomina,           // ⏳ Próximamente
  albar             // ⏳ Próximamente
}
```

---

## 🔒 **SEGURIDAD Y VALIDACIÓN**

### **Reglas de Firestore**

```javascript
match /empresas/{empresaId}/pdf_templates/{templateId} {
  // Solo admin/propietario puede CRUD
  allow read: if isAuthenticated() && belongsToEmpresa(empresaId);
  allow write: if isAuthenticated() && 
                  (hasRole('admin') || hasRole('propietario'));
  
  // Validar que solo haya UNA plantilla activa por tipo
  allow update: if validateSingleActiveTemplate(empresaId, resource.data.type);
}
```

### **Validación de Props**

```dart
// El sistema valida automáticamente:
// ✅ Tipos de datos (String, num, bool)
// ✅ Valores obligatorios
// ✅ Rangos numéricos
// ✅ Formatos de color (#RRGGBB)
```

---

## 🚀 **ROADMAP PRÓXIMAS FEATURES**

### ✅ **Fase 1: Core (COMPLETADO)**
- [x] Arquitectura de plantillas
- [x] 7 tipos de bloques
- [x] Servicio Firestore
- [x] Renderizado dinámico
- [x] Pantalla de gestión
- [x] Integración con dashboard

### ⏳ **Fase 2: Editor Visual (Próximo)**
- [ ] Drag & drop de bloques
- [ ] Preview en tiempo real
- [ ] Paleta de colores visual
- [ ] Duplicar plantillas
- [ ] Exportar/importar plantillas

### 🔮 **Fase 3: Avanzado (Futuro)**
- [ ] Plantillas compartidas (marketplace)
- [ ] Variables calculadas (`{total * 1.21}`)
- [ ] Bloques personalizados (custom widgets)
- [ ] Múltiples páginas
- [ ] Estilos CSS-like

---

## 🐛 **TROUBLESHOOTING**

### **"No se ve el módulo en el dashboard"**

```bash
# 1. Verificar que exista en Firestore:
empresas/{tu_empresa_id}/modulos/plantillas_pdf

# 2. Verificar que activo = true
{
  "activo": true  # ⚠️ DEBE SER true
}

# 3. Si no existe, ejecutar script:
node scripts/agregar_modulo_plantillas_pdf.js
```

### **"Sigue usando diseño legacy"**

```bash
# Verificar que existe plantilla activa:
empresas/{tu_empresa_id}/pdf_templates
# Debe haber al menos una con:
{
  "type": "factura",
  "is_active": true
}
```

### **"Error renderizando bloque"**

```dart
// Logs en PdfRenderer:
// Si un bloque falla, muestra:
"⚠️ Bloque 'xxx' no disponible"

// Y continúa renderizando el resto (fail-safe)
```

---

## 📞 **SUPPORT & CONTRIBUCIÓN**

- **Documentación**: Este archivo
- **Ejemplos**: Ver `pdf_template_service.dart` → `getDefaultTemplate()`
- **Issues**: Crear issue en el repo
- **Mejoras**: Pull request bienvenido

---

## 🎉 **RESUMEN**

```
✅ Sistema 100% funcional
✅ Backward compatible (sin romper nada)
✅ 7 tipos de bloques listos
✅ UI de gestión implementada
✅ Integrado en dashboard
✅ Scripts de setup listos

🚀 ¡LISTO PARA PRODUCCIÓN!
```

---

**Creado**: 25 Mayo 2026  
**Versión**: 1.0.0  
**Autor**: GitHub Copilot + FluixCRM Team

