// lib/models/business_config.dart

import 'dart:io';

class BusinessConfig {
  final String emisorNif;
  final String emisorNombre;
  final bool   recargoEquivalencia;
  final bool   sujetaRetencionIRPF;
  final bool   isNuevoAutonomo;
  final String defaultProductCode;
  final Map<String, VatRateCode> vatMappings;

  const BusinessConfig({
    required this.emisorNif,
    required this.emisorNombre,
    this.recargoEquivalencia   = false,
    this.sujetaRetencionIRPF   = false,
    this.isNuevoAutonomo        = false,
    this.defaultProductCode     = 'default',
    this.vatMappings            = const {},
  });

  factory BusinessConfig.fromEnv() {
    return BusinessConfig(
      emisorNif:           Platform.environment['EMISOR_NIF']    ?? 'B12345678',
      emisorNombre:        Platform.environment['EMISOR_NOMBRE'] ?? 'Mi Empresa S.L.',
      recargoEquivalencia: Platform.environment['RECARGO_EQUIVALENCIA'] == 'true',
      sujetaRetencionIRPF: Platform.environment['SUJETA_RETENCION_IRPF'] == 'true',
      isNuevoAutonomo:     Platform.environment['ES_NUEVO_AUTONOMO'] == 'true',
      defaultProductCode:  Platform.environment['DEFAULT_PRODUCT_CODE'] ?? 'default',
    );
  }
}

enum VatRateCode { general, reduced, superReduced, exempt }
