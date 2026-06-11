# 🏗️ ARQUITECTURA: SISTEMA DE PDFs DINÁMICOS SAAS

**Fecha**: 25 Mayo 2026  
**Estado**: Arquitectura Completa  
**Propósito**: Sistema multiempresa de generación de PDFs personalizables sin actualizar la app

---

## 🎯 **OBJETIVOS DEL SISTEMA**

### Problemas que resuelve:
- ❌ PDFs rígidos hardcodeados en `PdfService`  
- ❌ Cambios de diseño requieren actualizar la app  
- ❌ Cada empresa tiene diseño idéntico  
- ❌ No se pueden crear plantillas nuevas sin programar  

### Soluciones implementadas:
- ✅ Plantillas JSON almacenadas en Firestore  
- ✅ Editor visual tipo Canva dentro de la app  
- ✅ Motor de renderizado dinámico (Block Registry Pattern)  
- ✅ Multiempresa: cada empresa personaliza sus PDFs  
- ✅ Versionado de plantillas con rollback  
- ✅ Caching de plantillas para performance  

---

## 📁 **ESTRUCTURA DE CARPETAS**

```
lib/
├── domain/
│   └── modelos/
│       ├── factura.dart                    # Existente
│       ├── contabilidad.dart               # Existente
│       └── pdf_template.dart               # NUEVO: Modelo de plantilla
│
├── services/
│   ├── pdf/
│   │   ├── pdf_service.dart                # Existente (refactorizado)
│   │   ├── pdf_renderer.dart               # NUEVO: Motor de renderizado
│   │   ├── pdf_block_registry.dart         # NUEVO: Registro de bloques
│   │   ├── pdf_template_service.dart       # NUEVO: Gestión plantillas
│   │   ├── pdf_cache_service.dart          # NUEVO: Cache de plantillas
│   │   │
│   │   └── blocks/
│   │       ├── pdf_block_builder.dart      # NUEVO: Abstract base class
│   │       ├── header_block_builder.dart   # NUEVO: Bloque cabecera
│   │       ├── table_block_builder.dart    # NUEVO: Bloque tabla
│   │       ├── totals_block_builder.dart   # NUEVO: Bloque totales
│   │       ├── client_block_builder.dart   # NUEVO: Bloque datos cliente
│   │       ├── qr_block_builder.dart       # NUEVO: Bloque QR Verifactu
│   │       ├── text_block_builder.dart     # NUEVO: Bloque texto libre
│   │       ├── image_block_builder.dart    # NUEVO: Bloque imagen
│   │       └── stamp_block_builder.dart    # NUEVO: Sello PAGADA/PROFORMA
│   │
│   └── verifactu_service.dart              # Existente
│
├── features/
│   └── pdf_editor/
│       ├── pantallas/
│       │   ├── pdf_templates_list_screen.dart     # NUEVO: Lista plantillas
│       │   ├── pdf_template_editor_screen.dart    # NUEVO: Editor visual
│       │   └── pdf_template_preview_screen.dart   # NUEVO: Preview PDF
│       │
│       ├── widgets/
│       │   ├── template_toolbox.dart              # NUEVO: Caja de bloques
│       │   ├── template_canvas.dart               # NUEVO: Canvas A4
│       │   ├── block_inspector.dart               # NUEVO: Editor propiedades
│       │   ├── draggable_block_item.dart          # NUEVO: Bloque drag&drop
│       │   └── block_property_editor.dart         # NUEVO: Editor props específico
│       │
│       └── providers/
│           └── pdf_template_provider.dart         # NUEVO: Estado editor
│
└── utils/
    └── pdf_constants.dart                         # NUEVO: Constantes PDF (colores, fuentes, etc)
```

---

## 🗄️ **2. ESTRUCTURA FIRESTORE**

### **Colección: `empresas/{empresaId}/pdf_templates`**

```yaml
{
  id: "tpl_factura_default_v1",
  type: "factura",                    # factura | fichaje | presupuesto | rectificativa | nomina
  name: "Factura Clásica Azul",
  description: "Plantilla por defecto estilo corporativo",
  version: 1,
  is_active: true,                    # Solo una activa por tipo
  is_default: true,                   # Plantilla por defecto del sistema
  created_at: Timestamp,
  updated_at: Timestamp,
  created_by: "userId",
  
  # ── CONFIGURACIÓN DE PÁGINA ─────
  page: {
    format: "A4",                     # A4 | LETTER | A5
    orientation: "portrait",          # portrait | landscape
    margins: {
      top: 36,
      right: 36,
      bottom: 36,
      left: 36
    }
  },
  
  # ── ESTILOS GLOBALES ────────────
  styles: {
    brand_colors: {
      primary: "#1565C0",             # Azul principal
      secondary: "#00ACC1",           # Azul secundario
      accent: "#2E7D32",              # Verde (PAGADA)
      error: "#D32F2F",               # Rojo (VENCIDA)
      text_primary: "#000000",
      text_secondary: "#757575",
      background: "#FFFFFF",
      border: "#E0E0E0"
    },
    
    typography: {
      primary_font: "Helvetica",      # Roboto | Helvetica | Times
      heading_size: 16,
      body_size: 10,
      small_size: 8
    },
    
    spacing: {
      section_gap: 20,
      block_padding: 12,
      line_spacing: 6
    }
  },
  
  # ── BLOQUES DEL PDF ─────────────
  blocks: [
    {
      id: "block_header_001",
      type: "header",                 # header | table | totals | client | qr | text | image | stamp
      order: 0,                       # Orden de renderizado
      visible: true,
      
      props: {
        show_logo: true,
        logo_position: "left",        # left | center | right
        logo_width: 58,
        logo_height: 58,
        
        company_name_visible: true,
        company_name_size: 16,
        company_name_color: "#FFFFFF",
        
        fiscal_data_visible: true,    # NIF, dirección, teléfono
        fiscal_data_size: 9,
        fiscal_data_color: "#E0E0E0",
        
        invoice_number_visible: true,
        invoice_number_size: 14,
        invoice_number_color: "#00ACC1",
        
        dates_visible: true,          # fechas emisión, operación, vencimiento
        dates_size: 9,
        dates_color: "#E0E0E0",
        
        status_badge_visible: true,
        
        background_color: "#1565C0",  # Color fondo cabecera
        border_radius: 12,
        padding: 18
      }
    },
    
    {
      id: "block_client_001",
      type: "client",
      order: 1,
      visible: true,
      
      props: {
        title: "FACTURAR A:",
        title_size: 10,
        title_color: "#1565C0",
        title_bold: true,
        title_letter_spacing: 1.2,
        
        show_name: true,
        show_razon_social: true,     # Si es distinta del nombre
        show_nif: true,
        show_direccion: true,
        show_correo: true,
        
        name_size: 12,
        name_bold: true,
        
        fiscal_size: 10,
        fiscal_color: "#757575",
        
        background_color: "#F5F9FF",
        border_color: "#E0E0E0",
        border_radius: 8,
        padding: 12
      }
    },
    
    {
      id: "block_table_001",
      type: "table",
      order: 2,
      visible: true,
      
      props: {
        columns: [
          {
            key: "description",
            label: "DESCRIPCIÓN",
            flex: 5,
            align: "left"
          },
          {
            key: "quantity",
            label: "CANT",
            width: 36,
            align: "center"
          },
          {
            key: "unit_price",
            label: "P.UNIT",
            width: 60,
            align: "right"
          },
          {
            key: "discount",
            label: "DTO",
            width: 32,
            align: "center",
            visible_if: "has_discount"  # Condicional
          },
          {
            key: "tax_rate",
            label: "IVA",
            width: 30,
            align: "center"
          },
          {
            key: "subtotal",
            label: "BASE IMP.",
            width: 65,
            align: "right"
          }
        ],
        
        header_background_color: "#0D47A1",
        header_text_color: "#FFFFFF",
        header_font_size: 9,
        header_bold: true,
        header_padding: 8,
        header_border_radius_top: 8,
        
        row_font_size: 10,
        row_padding: 9,
        row_alternate_colors: true,   # true = zebra striping
        row_color_even: "#FFFFFF",
        row_color_odd: "#FAFBFC",
        row_border_color: "#E0E0E0",
        row_border_width: 0.5
      }
    },
    
    {
      id: "block_totals_001",
      type: "totals",
      order: 3,
      visible: true,
      
      props: {
        width: 240,                   # Ancho del bloque totales
        alignment: "right",           # left | center | right
        
        show_base_imponible: true,
        show_descuento_global: true,
        show_iva_breakdown: true,     # Desglose por tipo IVA
        show_recargo_equivalencia: true,
        show_irpf: true,
        show_total: true,
        
        label_font_size: 11,
        value_font_size: 11,
        label_color: "#757575",
        value_color: "#000000",
        
        total_label_font_size: 14,
        total_value_font_size: 16,
        total_color: "#1565C0",
        total_bold: true,
        
        divider_color: "#E0E0E0",
        divider_width: 1,
        
        row_spacing: 2,
        section_spacing: 10
      }
    },
    
    {
      id: "block_payment_001",
      type: "text",                   # Bloque genérico de texto
      order: 4,
      visible: true,
      
      props: {
        title: "FORMA DE PAGO",
        title_size: 9,
        title_bold: true,
        title_color: "#1565C0",
        title_letter_spacing: 1,
        
        content_template: "Método: {{metodo_pago}}\nIBAN: {{iban_empresa}}",
        content_size: 10,
        content_color: "#000000",
        
        background_color: "#F5F9FF",
        border_color: "#E0E0E0",
        border_radius: 8,
        padding: 10,
        
        visible_if: "factura.metodo_pago != null"
      }
    },
    
    {
      id: "block_qr_001",
      type: "qr",
      order: 5,
      visible: true,
      
      props: {
        source: "verifactu",          # verifactu | custom_url | custom_data
        
        title: "VERI*FACTU",
        title_size: 8,
        title_bold: true,
        title_color: "#0D47A1",
        
        subtitle: "Escanea el QR para verificar esta factura en la AEAT",
        subtitle_size: 7,
        subtitle_color: "#757575",
        
        qr_size: 57,
        qr_position: "right",         # left | right
        
        divider_visible: true,
        divider_color: "#E0E0E0",
        
        visible_if: "factura.verifactu != null"
      }
    },
    
    {
      id: "block_stamp_001",
      type: "stamp",
      order: 6,
      visible: true,
      
      props: {
        text: "PAGADA",
        font_size: 28,
        color: "#2E7D32",
        border_color: "#2E7D32",
        border_width: 3,
        border_radius: 6,
        padding_horizontal: 16,
        padding_vertical: 6,
        rotation_angle: -30,          # grados
        letter_spacing: 4,
        
        visible_if: "factura.estado == 'pagada'"
      }
    },
    
    {
      id: "block_stamp_002",
      type: "stamp",
      order: 7,
      visible: true,
      
      props: {
        text: "PROFORMA",
        font_size: 14,
        color: "#009688",
        border_color: "#009688",
        border_width: 2,
        border_radius: 4,
        padding_horizontal: 24,
        padding_vertical: 8,
        rotation_angle: 0,
        letter_spacing: 2,
        
        visible_if: "factura.es_proforma == true"
      }
    }
  ],
  
  # ── METADATOS ───────────────────
  metadata: {
    uses_logo: true,
    uses_qr: true,
    compatible_document_types: ["factura", "rectificativa"],
    tags: ["corporativo", "azul", "formal"],
    preview_url: "gs://planeag-d5cdd/templates/previews/tpl_factura_default_v1.png"
  }
}
```

---

### **Colección: `empresas/{empresaId}/pdf_config`**

Documento único por empresa con configuración global:

```yaml
{
  id: "config",
  
  # Plantillas asignadas por tipo de documento
  assigned_templates: {
    factura: "tpl_factura_default_v1",
    rectificativa: "tpl_factura_default_v1",
    presupuesto: "tpl_presupuesto_moderno_v1",
    fichaje: "tpl_fichaje_simple_v1",
    nomina: "tpl_nomina_oficial_v1"
  },
  
  # Branding de la empresa (override de plantilla)
  branding: {
    logo_url: "https://storage.../logo.png",
    primary_color: "#1565C0",
    secondary_color: "#00ACC1",
    company_name: "Mi Empresa SL",
    nif: "B12345678",
    domicilio_fiscal: "Calle Mayor 1, 28001 Madrid",
    telefono: "+34 600 000 000",
    correo: "info@miempresa.com",
    iban: "ES12 1234 1234 1234 1234 1234"
  },
  
  # Cache settings
  cache: {
    enabled: true,
    ttl_seconds: 3600,              # 1 hora
    max_size_mb: 10
  },
  
  updated_at: Timestamp
}
```

---

### **Colección: `pdf_template_system`** (global, colección raíz)

Plantillas del sistema disponibles para todas las empresas:

```yaml
{
  id: "system_tpl_factura_clasica_v1",
  is_system_template: true,
  type: "factura",
  name: "Factura Clásica Azul",
  description: "Plantilla por defecto del sistema",
  preview_url: "gs://planeag-d5cdd/system_templates/preview_factura_clasica.png",
  
  # ... resto igual que plantilla empresa
}
```

---

## 🧩 **3. MODELOS DART**

### `lib/domain/modelos/pdf_template.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Tipos de documento soportados
enum PdfDocumentType {
  factura,
  rectificativa,
  presupuesto,
  fichaje,
  nomina,
  albar
}

/// Tipos de bloque disponibles
enum PdfBlockType {
  header,
  table,
  totals,
  client,
  qr,
  text,
  image,
  stamp,
  divider,
  spacer
}

/// Modelo de plantilla PDF
class PdfTemplate extends Equatable {
  final String id;
  final PdfDocumentType type;
  final String name;
  final String description;
  final int version;
  final bool isActive;
  final bool isDefault;
  final bool isSystemTemplate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  
  final PdfPageConfig page;
  final PdfStyles styles;
  final List<PdfBlock> blocks;
  final PdfTemplateMetadata metadata;
  
  const PdfTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.version,
    required this.isActive,
    required this.isDefault,
    this.isSystemTemplate = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    required this.page,
    required this.styles,
    required this.blocks,
    required this.metadata,
  });
  
  factory PdfTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfTemplate.fromMap(data, doc.id);
  }
  
  factory PdfTemplate.fromMap(Map<String, dynamic> map, String id) {
    return PdfTemplate(
      id: id,
      type: PdfDocumentType.values.byName(map['type'] as String),
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      version: map['version'] as int,
      isActive: map['is_active'] as bool? ?? true,
      isDefault: map['is_default'] as bool? ?? false,
      isSystemTemplate: map['is_system_template'] as bool? ?? false,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      updatedAt: (map['updated_at'] as Timestamp).toDate(),
      createdBy: map['created_by'] as String?,
      page: PdfPageConfig.fromMap(map['page'] as Map<String, dynamic>),
      styles: PdfStyles.fromMap(map['styles'] as Map<String, dynamic>),
      blocks: (map['blocks'] as List)
          .map((b) => PdfBlock.fromMap(b as Map<String, dynamic>))
          .toList(),
      metadata: PdfTemplateMetadata.fromMap(
          map['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'version': version,
      'is_active': isActive,
      'is_default': isDefault,
      'is_system_template': isSystemTemplate,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'created_by': createdBy,
      'page': page.toMap(),
      'styles': styles.toMap(),
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'metadata': metadata.toMap(),
    };
  }
  
  PdfTemplate copyWith({
    String? name,
    String? description,
    int? version,
    bool? isActive,
    bool? isDefault,
    PdfPageConfig? page,
    PdfStyles? styles,
    List<PdfBlock>? blocks,
    PdfTemplateMetadata? metadata,
  }) {
    return PdfTemplate(
      id: id,
      type: type,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      isSystemTemplate: isSystemTemplate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      page: page ?? this.page,
      styles: styles ?? this.styles,
      blocks: blocks ?? this.blocks,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [id, version, updatedAt];
}

// ── SUB-MODELOS ────────────────────────────────────────────────────────────────

class PdfPageConfig extends Equatable {
  final String format; // A4, LETTER, A5
  final String orientation; // portrait, landscape
  final PdfMargins margins;
  
  const PdfPageConfig({
    required this.format,
    required this.orientation,
    required this.margins,
  });
  
  factory PdfPageConfig.fromMap(Map<String, dynamic> map) {
    return PdfPageConfig(
      format: map['format'] as String? ?? 'A4',
      orientation: map['orientation'] as String? ?? 'portrait',
      margins: PdfMargins.fromMap(map['margins'] as Map<String, dynamic>? ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'format': format,
      'orientation': orientation,
      'margins': margins.toMap(),
    };
  }
  
  @override
  List<Object?> get props => [format, orientation, margins];
}

class PdfMargins extends Equatable {
  final double top;
  final double right;
  final double bottom;
  final double left;
  
  const PdfMargins({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });
  
  factory PdfMargins.fromMap(Map<String, dynamic> map) {
    return PdfMargins(
      top: (map['top'] as num?)?.toDouble() ?? 36.0,
      right: (map['right'] as num?)?.toDouble() ?? 36.0,
      bottom: (map['bottom'] as num?)?.toDouble() ?? 36.0,
      left: (map['left'] as num?)?.toDouble() ?? 36.0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'top': top,
      'right': right,
      'bottom': bottom,
      'left': left,
    };
  }
  
  @override
  List<Object?> get props => [top, right, bottom, left];
}

class PdfStyles extends Equatable {
  final PdfBrandColors brandColors;
  final PdfTypography typography;
  final PdfSpacing spacing;
  
  const PdfStyles({
    required this.brandColors,
    required this.typography,
    required this.spacing,
  });
  
  factory PdfStyles.fromMap(Map<String, dynamic> map) {
    return PdfStyles(
      brandColors: PdfBrandColors.fromMap(
          map['brand_colors'] as Map<String, dynamic>? ?? {}),
      typography: PdfTypography.fromMap(
          map['typography'] as Map<String, dynamic>? ?? {}),
      spacing: PdfSpacing.fromMap(
          map['spacing'] as Map<String, dynamic>? ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'brand_colors': brandColors.toMap(),
      'typography': typography.toMap(),
      'spacing': spacing.toMap(),
    };
  }
  
  @override
  List<Object?> get props => [brandColors, typography, spacing];
}

class PdfBrandColors extends Equatable {
  final String primary;
  final String secondary;
  final String accent;
  final String error;
  final String textPrimary;
  final String textSecondary;
  final String background;
  final String border;
  
  const PdfBrandColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.background,
    required this.border,
  });
  
  factory PdfBrandColors.fromMap(Map<String, dynamic> map) {
    return PdfBrandColors(
      primary: map['primary'] as String? ?? '#1565C0',
      secondary: map['secondary'] as String? ?? '#00ACC1',
      accent: map['accent'] as String? ?? '#2E7D32',
      error: map['error'] as String? ?? '#D32F2F',
      textPrimary: map['text_primary'] as String? ?? '#000000',
      textSecondary: map['text_secondary'] as String? ?? '#757575',
      background: map['background'] as String? ?? '#FFFFFF',
      border: map['border'] as String? ?? '#E0E0E0',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'primary': primary,
      'secondary': secondary,
      'accent': accent,
      'error': error,
      'text_primary': textPrimary,
      'text_secondary': textSecondary,
      'background': background,
      'border': border,
    };
  }
  
  @override
  List<Object?> get props => [
        primary,
        secondary,
        accent,
        error,
        textPrimary,
        textSecondary,
        background,
        border
      ];
}

class PdfTypography extends Equatable {
  final String primaryFont;
  final double headingSize;
  final double bodySize;
  final double smallSize;
  
  const PdfTypography({
    required this.primaryFont,
    required this.headingSize,
    required this.bodySize,
    required this.smallSize,
  });
  
  factory PdfTypography.fromMap(Map<String, dynamic> map) {
    return PdfTypography(
      primaryFont: map['primary_font'] as String? ?? 'Helvetica',
      headingSize: (map['heading_size'] as num?)?.toDouble() ?? 16.0,
      bodySize: (map['body_size'] as num?)?.toDouble() ?? 10.0,
      smallSize: (map['small_size'] as num?)?.toDouble() ?? 8.0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'primary_font': primaryFont,
      'heading_size': headingSize,
      'body_size': bodySize,
      'small_size': smallSize,
    };
  }
  
  @override
  List<Object?> get props => [primaryFont, headingSize, bodySize, smallSize];
}

class PdfSpacing extends Equatable {
  final double sectionGap;
  final double blockPadding;
  final double lineSpacing;
  
  const PdfSpacing({
    required this.sectionGap,
    required this.blockPadding,
    required this.lineSpacing,
  });
  
  factory PdfSpacing.fromMap(Map<String, dynamic> map) {
    return PdfSpacing(
      sectionGap: (map['section_gap'] as num?)?.toDouble() ?? 20.0,
      blockPadding: (map['block_padding'] as num?)?.toDouble() ?? 12.0,
      lineSpacing: (map['line_spacing'] as num?)?.toDouble() ?? 6.0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'section_gap': sectionGap,
      'block_padding': blockPadding,
      'line_spacing': lineSpacing,
    };
  }
  
  @override
  List<Object?> get props => [sectionGap, blockPadding, lineSpacing];
}

class PdfBlock extends Equatable {
  final String id;
  final PdfBlockType type;
  final int order;
  final bool visible;
  final Map<String, dynamic> props;
  
  const PdfBlock({
    required this.id,
    required this.type,
    required this.order,
    required this.visible,
    required this.props,
  });
  
  factory PdfBlock.fromMap(Map<String, dynamic> map) {
    return PdfBlock(
      id: map['id'] as String,
      type: PdfBlockType.values.byName(map['type'] as String),
      order: map['order'] as int,
      visible: map['visible'] as bool? ?? true,
      props: Map<String, dynamic>.from(map['props'] as Map<String, dynamic>? ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'order': order,
      'visible': visible,
      'props': props,
    };
  }
  
  PdfBlock copyWith({
    int? order,
    bool? visible,
    Map<String, dynamic>? props,
  }) {
    return PdfBlock(
      id: id,
      type: type,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      props: props ?? this.props,
    );
  }
  
  @override
  List<Object?> get props => [id, type, order, visible, props];
}

class PdfTemplateMetadata extends Equatable {
  final bool usesLogo;
  final bool usesQr;
  final List<String> compatibleDocumentTypes;
  final List<String> tags;
  final String? previewUrl;
  
  const PdfTemplateMetadata({
    required this.usesLogo,
    required this.usesQr,
    required this.compatibleDocumentTypes,
    required this.tags,
    this.previewUrl,
  });
  
  factory PdfTemplateMetadata.fromMap(Map<String, dynamic> map) {
    return PdfTemplateMetadata(
      usesLogo: map['uses_logo'] as bool? ?? false,
      usesQr: map['uses_qr'] as bool? ?? false,
      compatibleDocumentTypes: List<String>.from(
          map['compatible_document_types'] as List<dynamic>? ?? []),
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? []),
      previewUrl: map['preview_url'] as String?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'uses_logo': usesLogo,
      'uses_qr': usesQr,
      'compatible_document_types': compatibleDocumentTypes,
      'tags': tags,
      if (previewUrl != null) 'preview_url': previewUrl,
    };
  }
  
  @override
  List<Object?> get props =>
      [usesLogo, usesQr, compatibleDocumentTypes, tags, previewUrl];
}

/// Configuración PDF de una empresa
class PdfConfig extends Equatable {
  final Map<PdfDocumentType, String> assignedTemplates;
  final PdfBranding branding;
  final PdfCacheConfig cache;
  final DateTime updatedAt;
  
  const PdfConfig({
    required this.assignedTemplates,
    required this.branding,
    required this.cache,
    required this.updatedAt,
  });
  
  factory PdfConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfConfig.fromMap(data);
  }
  
  factory PdfConfig.fromMap(Map<String, dynamic> map) {
    final assignedRaw = map['assigned_templates'] as Map<String, dynamic>? ?? {};
    final assigned = <PdfDocumentType, String>{};
    assignedRaw.forEach((key, value) {
      try {
        assigned[PdfDocumentType.values.byName(key)] = value as String;
      } catch (_) {}
    });
    
    return PdfConfig(
      assignedTemplates: assigned,
      branding: PdfBranding.fromMap(
          map['branding'] as Map<String, dynamic>? ?? {}),
      cache: PdfCacheConfig.fromMap(map['cache'] as Map<String, dynamic>? ?? {}),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'assigned_templates': assignedTemplates.map((k, v) => MapEntry(k.name, v)),
      'branding': branding.toMap(),
      'cache': cache.toMap(),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
  
  @override
  List<Object?> get props => [assignedTemplates, branding, cache, updatedAt];
}

class PdfBranding extends Equatable {
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? companyName;
  final String? nif;
  final String? domicilioFiscal;
  final String? telefono;
  final String? correo;
  final String? iban;
  
  const PdfBranding({
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.companyName,
    this.nif,
    this.domicilioFiscal,
    this.telefono,
    this.correo,
    this.iban,
  });
  
  factory PdfBranding.fromMap(Map<String, dynamic> map) {
    return PdfBranding(
      logoUrl: map['logo_url'] as String?,
      primaryColor: map['primary_color'] as String?,
      secondaryColor: map['secondary_color'] as String?,
      companyName: map['company_name'] as String?,
      nif: map['nif'] as String?,
      domicilioFiscal: map['domicilio_fiscal'] as String?,
      telefono: map['telefono'] as String?,
      correo: map['correo'] as String?,
      iban: map['iban'] as String?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      if (logoUrl != null) 'logo_url': logoUrl,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (companyName != null) 'company_name': companyName,
      if (nif != null) 'nif': nif,
      if (domicilioFiscal != null) 'domicilio_fiscal': domicilioFiscal,
      if (telefono != null) 'telefono': telefono,
      if (correo != null) 'correo': correo,
      if (iban != null) 'iban': iban,
    };
  }
  
  @override
  List<Object?> get props => [
        logoUrl,
        primaryColor,
        secondaryColor,
        companyName,
        nif,
        domicilioFiscal,
        telefono,
        correo,
        iban
      ];
}

class PdfCacheConfig extends Equatable {
  final bool enabled;
  final int ttlSeconds;
  final double maxSizeMb;
  
  const PdfCacheConfig({
    required this.enabled,
    required this.ttlSeconds,
    required this.maxSizeMb,
  });
  
  factory PdfCacheConfig.fromMap(Map<String, dynamic> map) {
    return PdfCacheConfig(
      enabled: map['enabled'] as bool? ?? true,
      ttlSeconds: map['ttl_seconds'] as int? ?? 3600,
      maxSizeMb: (map['max_size_mb'] as num?)?.toDouble() ?? 10.0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'ttl_seconds': ttlSeconds,
      'max_size_mb': maxSizeMb,
    };
  }
  
  @override
  List<Object?> get props => [enabled, ttlSeconds, maxSizeMb];
}
```

Este modelo proporciona la base completa. ¿Continúo con el **PdfRenderer** y **BlockRegistry**?
