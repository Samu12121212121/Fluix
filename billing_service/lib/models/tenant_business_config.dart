// lib/models/tenant_business_config.dart

class TenantBusinessConfig {
  final String  tenantId;
  final String  emisorNif;
  final String  emisorNombre;
  final String  emisorDireccion;
  final String? emisorCp;
  final String? emisorMunicipio;
  final bool    sujetaRetencionIrpf;
  final bool    isNuevoAutonomo;
  final bool    recargoEquivalencia;
  final String  defaultProductCode;

  const TenantBusinessConfig({
    required this.tenantId,
    required this.emisorNif,
    required this.emisorNombre,
    this.emisorDireccion      = '',
    this.emisorCp,
    this.emisorMunicipio,
    this.sujetaRetencionIrpf  = false,
    this.isNuevoAutonomo      = false,
    this.recargoEquivalencia  = false,
    this.defaultProductCode   = 'SERVICIOS_GENERALES',
  });

  factory TenantBusinessConfig.fromRow(Map<String, dynamic> row) =>
      TenantBusinessConfig(
        tenantId:             row['tenant_id'] as String,
        emisorNif:            row['emisor_nif'] as String,
        emisorNombre:         row['emisor_nombre'] as String,
        emisorDireccion:      row['emisor_direccion'] as String? ?? '',
        emisorCp:             row['emisor_cp'] as String?,
        emisorMunicipio:      row['emisor_municipio'] as String?,
        sujetaRetencionIrpf:  row['sujeta_retencion_irpf'] as bool? ?? false,
        isNuevoAutonomo:      row['is_nuevo_autonomo'] as bool? ?? false,
        recargoEquivalencia:  row['recargo_equivalencia'] as bool? ?? false,
        defaultProductCode:   row['default_product_code'] as String? ?? 'SERVICIOS_GENERALES',
      );

  Map<String, dynamic> toJson() => {
    'tenant_id':               tenantId,
    'emisor_nif':              emisorNif,
    'emisor_nombre':           emisorNombre,
    'emisor_direccion':        emisorDireccion,
    'emisor_cp':               emisorCp,
    'emisor_municipio':        emisorMunicipio,
    'sujeta_retencion_irpf':   sujetaRetencionIrpf,
    'is_nuevo_autonomo':       isNuevoAutonomo,
    'recargo_equivalencia':    recargoEquivalencia,
    'default_product_code':    defaultProductCode,
  };
}

