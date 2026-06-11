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
  final Map<String, dynamic> properties;
  
  const PdfBlock({
    required this.id,
    required this.type,
    required this.order,
    required this.visible,
    required this.properties,
  });
  
  factory PdfBlock.fromMap(Map<String, dynamic> map) {
    return PdfBlock(
      id: map['id'] as String,
      type: PdfBlockType.values.byName(map['type'] as String),
      order: map['order'] as int,
      visible: map['visible'] as bool? ?? true,
      properties: Map<String, dynamic>.from(map['props'] as Map<String, dynamic>? ?? {}),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'order': order,
      'visible': visible,
      'props': properties,
    };
  }
  
  PdfBlock copyWith({
    int? order,
    bool? visible,
    Map<String, dynamic>? properties,
  }) {
    return PdfBlock(
      id: id,
      type: type,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      properties: properties ?? this.properties,
    );
  }
  
  @override
  List<Object?> get props => [id, type, order, visible, properties];
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



